import * as cheerio from "cheerio";
import { Day, DiaryResponse, Lesson, LessonAttachment, LoginResponse, Profile, QuarterGradesTable, Week } from "./types";

type WeekPayloadDay = { name: string; lessons: Lesson[] };
type WeekPayload = { ok: boolean; nextWeek?: string; prevWeek?: string; days: WeekPayloadDay[] };
type HttpTextResponse = { ok: boolean; status: number; text: string; location: string | null; url: string };

const base = "https://schools.by";
const fallbackBase = "https://4minsk.schools.by";
const loginUrl = `${base}/login`;
const defaultStartWeek = "2026-01-12";
const defaultQuarterId = "90";
const adminPupilIds = new Set(["1106490"]);

export class SchoolsByClient {
  private readonly cookies = new Map<string, string>();

  async clearSession(): Promise<void> {
    this.cookies.clear();
  }

  async login(username: string, password: string): Promise<LoginResponse> {
    const sessionId = await this.performDirectLogin(username, password);
    this.cookies.set("sessionid", sessionId);

    const [pupilId, activeBase] = await this.resolvePupilId(sessionId);
    const profilePayload = await this.resolveProfilePayload(pupilId, activeBase);
    const [fullName, className] = parseTitle(profilePayload.title);

    const profile: Profile = {
      fullName: fullName.trim() || "Ученик",
      className,
      avatarUrl: absoluteUrl(profilePayload.avatarUrl, profilePayload.base),
      classTeacher: profilePayload.classTeacher || undefined,
      role: adminPupilIds.has(pupilId) ? "admin" : "user",
    };

    return { sessionId, pupilId, profile };
  }

  async fetchDiary(pupilId: string, sessionId?: string): Promise<DiaryResponse> {
    if (sessionId) this.cookies.set("sessionid", sessionId);

    const diaryContext = await this.resolveDiaryContext(pupilId, base);
    const quarterId = diaryContext.quarterId ?? defaultQuarterId;
    const startWeek = diaryContext.weekId ?? (await this.discoverStartWeek(pupilId, quarterId, diaryContext.base)) ?? defaultStartWeek;
    const activeBase = diaryContext.base;

    const visited = new Set<string>();
    const pending = [startWeek];
    const weeksMap = new Map<string, Week>();

    let guard = 0;
    while (pending.length && guard < 160) {
      guard += 1;
      const weekId = pending.shift()!;
      if (visited.has(weekId)) continue;
      visited.add(weekId);

      const payload = await this.loadWeekPayload(pupilId, quarterId, weekId, activeBase);
      if (!payload.ok) continue;

      const days: Day[] = payload.days.map((source, i) => ({
        date: addDays(weekId, i),
        name: source.name,
        lessons: source.lessons,
      }));

      weeksMap.set(weekId, { monday: weekId, days });
      for (const candidate of [payload.nextWeek, payload.prevWeek]) {
        if (!candidate || !isoWeek(candidate) || visited.has(candidate) || pending.includes(candidate)) continue;
        pending.push(candidate);
      }
    }

    //error
    const weeks = [...weeksMap.values()].sort((a, b) => a.monday.localeCompare(b.monday));
    return { weeks };
  }

  async fetchQuarterGrades(pupilId: string, sessionId?: string): Promise<QuarterGradesTable> {
    if (sessionId) this.cookies.set("sessionid", sessionId);
    const primaryLoaded = await this.loadWithHostFallback(`/m/pupil/${pupilId}/dnevnik/last-page`, base);
    let activeBase = primaryLoaded.base;
    let table = parseQuarterGradesTable(primaryLoaded.response.text);
    if (table.rows.length) return table;

    const diaryContext = await this.resolveDiaryContext(pupilId, activeBase);
    activeBase = diaryContext.base;

    const diaryLoaded = await this.loadWithHostFallback(`/m/pupil/${pupilId}/dnevnik`, activeBase);
    const $ = cheerio.load(diaryLoaded.response.text);
    const path = $("a[href*='last-page']").first().attr("href");
    if (path) {
      const lastPage = await this.loadWithHostFallback(path, activeBase);
      table = parseQuarterGradesTable(lastPage.response.text);
    }
    return table;
  }

  private async performDirectLogin(username: string, password: string): Promise<string> {
    const getResponse = await this.request(loginUrl);
    if (!getResponse.ok) throw new Error("Не удалось открыть страницу входа.");

    const csrf = firstCapture(getResponse.text, /name=["']csrfmiddlewaretoken["'][^>]*value=["']([^"']+)["']/i);
    if (!csrf) throw new Error("Не удалось получить CSRF токен.");
    const csrfCookie = this.cookies.get("csrftoken") ?? csrf;

    const body = new URLSearchParams({
      csrfmiddlewaretoken: csrf,
      username,
      password,
      "function-cookie": "on",
      "static_cookie": "on",
      "advertising_cookie": "on",
      "|123": "|123",
    });

    let postResponse = await this.request(loginUrl, {
      method: "POST",
      redirect: "manual",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Origin: base,
        Referer: loginUrl,
        "X-CSRFToken": csrf,
        Cookie: this.cookieHeader({
          csrftoken: csrfCookie,
          "function-cookie": "on",
          "static_cookie": "on",
          "advertising_cookie": "on",
        }),
      },
      body: body.toString(),
    });

    // schools.by may return sessionid on 302/303 responses.
    // Follow redirects manually to collect cookies from each hop.
    let redirectGuard = 0;
    while (!this.cookies.get("sessionid") && postResponse.location && postResponse.status >= 300 && postResponse.status < 400 && redirectGuard < 8) {
      redirectGuard += 1;
      postResponse = await this.request(absoluteUrl(postResponse.location, base) ?? base, {
        method: "GET",
        redirect: "manual",
      });
    }

    if (!postResponse.ok) throw new Error(`Ошибка входа (${postResponse.status}).`);
    if (postResponse.text.includes("Пожалуйста, введите правильные имя пользователя и пароль")) {
      throw new Error("Неверный логин или пароль.");
    }

    const sessionId = this.cookies.get("sessionid");
    if (!sessionId) throw new Error("Не удалось получить sessionid.");
    return sessionId;
  }

  private async resolvePupilId(sessionId: string): Promise<[string, string]> {
    for (const host of [base, fallbackBase]) {
      const response = await this.request(`${host}/m/`, {
        headers: { Cookie: this.cookieHeader({ sessionid: sessionId }) },
      });
      if (!response.ok) continue;
      const href = firstCapture(response.text, /(\/pupil\/\d+[^"']*)/i);
      const pupilId = href ? firstCapture(href, /\/pupil\/(\d+)/) : null;
      if (pupilId) return [pupilId, host];
    }
    throw new Error("Не удалось определить pupilid.");
  }

  private async resolveProfilePayload(pupilId: string, preferredBase: string): Promise<{ title: string; avatarUrl?: string; classTeacher?: string; base: string }> {
    const hosts = [...new Set([preferredBase, base, fallbackBase])];

    for (const host of hosts) {
      try {
        const html = await this.getHtml(`${host}/pupil/${pupilId}/`);
        let payload = parseProfilePayload(html);
        if (payload.title.trim()) return { ...payload, base: host };

        const menu = await this.request(`${host}/m/`);
        if (menu.ok) {
          const $menu = cheerio.load(menu.text);
          const fallbackName = normalizeSpaces($menu("a.u_name, a.user_name, a.profile-link").first().text());
          payload = { ...payload, title: fallbackName };
        }
        if (payload.title.trim()) return { ...payload, base: host };
      } catch {
        // profile endpoints are unstable; continue with fallback host
      }
    }

    const menuFallback = await this.request(`${preferredBase}/m/`);
    if (menuFallback.ok) {
      const $menu = cheerio.load(menuFallback.text);
      const fallbackName = normalizeSpaces($menu("a.u_name, a.user_name, a.profile-link").first().text());
      if (fallbackName) return { title: fallbackName, base: preferredBase };
    }

    return { title: "", base: preferredBase };
  }

  private async resolveDiaryContext(pupilId: string, preferredBase: string): Promise<{ base: string; quarterId?: string; weekId?: string }> {
    const primaryLoaded = await this.loadWithHostFallback(`/m/pupil/${pupilId}/dnevnik`, preferredBase);
    const primaryPaths = this.readDiaryPathsFromHtml(primaryLoaded.response.text, pupilId, primaryLoaded.response.url);
    const primaryContext = this.buildDiaryContext(primaryPaths, primaryLoaded.base);
    if (primaryContext.quarterId || primaryContext.weekId) return primaryContext;

    if (primaryLoaded.base !== fallbackBase) {
      try {
        const fallbackLoaded = await this.loadWithHostFallback(`/m/pupil/${pupilId}/dnevnik`, fallbackBase);
        const fallbackPaths = this.readDiaryPathsFromHtml(fallbackLoaded.response.text, pupilId, fallbackLoaded.response.url);
        const fallbackContext = this.buildDiaryContext(fallbackPaths, fallbackLoaded.base);
        if (fallbackContext.quarterId || fallbackContext.weekId) return fallbackContext;
      } catch {
        // keep primary context if fallback host is unavailable
      }
    }

    return primaryContext;
  }

  private async discoverStartWeek(pupilId: string, quarterId: string, activeBase: string): Promise<string | null> {
    const loaded = await this.loadWithHostFallback(`/m/pupil/${pupilId}/dnevnik/quarter/${quarterId}`, activeBase);
    const $ = cheerio.load(loaded.response.text);

    const currentPath = pathFromUrl(loaded.response.url);
    const weekFromPath = currentPath ? this.extractWeekId(currentPath) : null;
    if (weekFromPath) return weekFromPath;

    const fromLinks = new Set<string>();
    $("a[href*='/week/']").each((_, el) => {
      const href = $(el).attr("href");
      const week = href?.match(/\/week\/(\d{4}-\d{2}-\d{2})/)?.[1];
      if (week) fromLinks.add(week);
    });
    if (fromLinks.size) return [...fromLinks].sort()[0];

    const nextWeek = $("a.next").attr("next_week_id");
    if (nextWeek && isoWeek(nextWeek)) return addDays(nextWeek, -7);
    const prevWeek = $("a.prev").attr("prev_week_id");
    if (prevWeek && isoWeek(prevWeek)) return addDays(prevWeek, 7);
    return null;
  }

  private async loadWithHostFallback(path: string, preferredBase: string, init?: RequestInit): Promise<{ base: string; response: HttpTextResponse }> {
    let normalizedPath = path.startsWith("/") ? path : `/${path}`;
    const raw = path.trim();
    if (raw.startsWith("http://") || raw.startsWith("https://")) {
      const absoluteResponse = await this.request(raw, init);
      if (absoluteResponse.ok) {
        const absoluteBase = (() => {
          try {
            const parsed = new URL(absoluteResponse.url || raw);
            return `${parsed.protocol}//${parsed.host}`;
          } catch {
            return preferredBase;
          }
        })();
        return { base: absoluteBase, response: absoluteResponse };
      }
      normalizedPath = pathFromUrl(raw) ?? normalizedPath;
    }

    const hosts = [...new Set([preferredBase, base, fallbackBase])];

    let lastResponse: HttpTextResponse | null = null;
    for (const host of hosts) {
      const response = await this.request(absoluteUrl(normalizedPath, host) ?? `${host}${normalizedPath}`, init);
      if (response.ok) return { base: host, response };
      lastResponse = response;
    }

    if (lastResponse) throw new Error(`Ошибка загрузки страницы (${lastResponse.status}).`);
    throw new Error("Ошибка загрузки страницы.");
  }

  private readDiaryPathsFromHtml(html: string, pupilId: string, responseUrl: string): string[] {
    const $ = cheerio.load(html);
    const paths = new Set<string>();

    const currentPath = pathFromUrl(responseUrl);
    if (currentPath) paths.add(currentPath);

    const nextWeek = $("a.next").attr("next_week_id");
    if (nextWeek && isoWeek(nextWeek)) {
      paths.add(`/m/pupil/${pupilId}/dnevnik/week/${nextWeek}`);
    }

    $("a[href*='/dnevnik/quarter/'][href*='/week/']").each((_, el) => {
      const href = $(el).attr("href")?.trim();
      if (!href) return;
      const normalized = pathFromUrl(href) ?? href;
      if (normalized) paths.add(normalized);
    });

    return [...paths];
  }

  private buildDiaryContext(paths: string[], currentBase: string): { base: string; quarterId?: string; weekId?: string } {
    for (const path of paths) {
      const parsed = this.extractQuarterAndWeek(path);
      if (parsed) return { base: currentBase, quarterId: parsed.quarterId, weekId: parsed.weekId };
    }
    for (const path of paths) {
      const quarterId = this.extractQuarterOnly(path);
      if (quarterId) return { base: currentBase, quarterId };
    }
    return { base: currentBase };
  }

  private extractQuarterAndWeek(path: string): { quarterId: string; weekId: string } | null {
    const match = path.match(/\/dnevnik\/quarter\/(\d+)\/week\/(\d{4}-\d{2}-\d{2})/i);
    if (!match) return null;
    return { quarterId: match[1], weekId: match[2] };
  }

  private extractQuarterOnly(path: string): string | null {
    return path.match(/\/dnevnik\/quarter\/(\d+)/i)?.[1] ?? null;
  }

  private extractWeekId(path: string): string | null {
    return path.match(/\/week\/(\d{4}-\d{2}-\d{2})/i)?.[1] ?? null;
  }

  private async loadWeekPayload(pupilId: string, quarterId: string, weekId: string, activeBase: string): Promise<WeekPayload> {
    const url = `${activeBase}/m/pupil/${pupilId}/dnevnik/quarter/${quarterId}/week/${weekId}`;
    const response = await this.request(url);
    if (!response.ok) return { ok: false, days: [] };
    const $ = cheerio.load(response.text);

    const weekBlock = pickWeekBlock($, weekId);
    const root = weekBlock ?? $.root();
    const nextWeek = readWeekFromNode(root.find("a.next").first());
    const prevWeek = readWeekFromNode(root.find("a.prev").first());
    const daysRoot = (weekBlock?.find("div.db_days").first() ?? $("div.db_days").first());
    if (!daysRoot.length) return { ok: false, nextWeek, prevWeek, days: [] };

    const days: WeekPayloadDay[] = [];
    daysRoot.find("div.db_day").each((_, dayEl) => {
      const dayNode = $(dayEl);
      const table = dayNode.find("table.db_table").first();
      if (!table.length) {
        days.push({ name: "?", lessons: [] });
        return;
      }

      const dayName = normalizeSpaces(table.find("th.lesson").first().text() || "?");
      const lessons: Lesson[] = [];
      table.find("tbody tr").each((__, rowEl) => {
        const row = $(rowEl);
        let subject = normalizeSpaces(
          row.find("td.lesson span").first().text() ||
            row.find("td.lesson a").first().text() ||
            row.find("td.lesson").first().text(),
        );
        subject = subject.replace(/^\d+[\.\)]\s*/, "");

        const hw = nullable(normalizeSpaces(row.find("div.ht-text").first().text() || row.find("td.ht").first().text()));
        const mark = extractBestMark($, row);
        const cabinet = nullable(normalizeSpaces(row.find("span.cabinet").first().text()));

        const attachments: LessonAttachment[] = [];
        const toggleHref = row.find("a.attachments_dropdown_toggle[href]").first().attr("href");
        if (toggleHref) {
          attachments.push({ name: "Файлы к уроку", url: absoluteUrl(toggleHref, activeBase), type: "lesson_attribute" });
        }
        row.find(".attachments_dropdown_menu a[href]").each((___, a) => {
          const link = $(a);
          const href = link.attr("href");
          if (!href) return;
          attachments.push({ name: normalizeSpaces(link.text()) || "Файл", url: absoluteUrl(href, activeBase), type: "lesson_attachment" });
        });
        row.find("div.ht-text a[href]").each((___, a) => {
          const link = $(a);
          const href = link.attr("href");
          if (!href) return;
          attachments.push({ name: normalizeSpaces(link.text()) || "Файл", url: absoluteUrl(href, activeBase), type: "hw_link" });
        });

        if (!subject && !hw && !mark && !cabinet) return;
        lessons.push({ subject, mark: mark ?? undefined, hw: hw ?? undefined, cabinet: cabinet ?? undefined, attachments: dedupAttachments(attachments) });
      });

      days.push({ name: dayName, lessons });
    });

    const resolvedDays: WeekPayloadDay[] = [];
    for (const day of days) {
      const lessons: Lesson[] = [];
      for (const lesson of day.lessons) {
        lessons.push({
          ...lesson,
          attachments: await this.resolveAttachments(lesson.attachments ?? [], activeBase),
        });
      }
      resolvedDays.push({ ...day, lessons });
    }

    return { ok: true, nextWeek, prevWeek, days: resolvedDays };
  }

  private async resolveAttachments(attachments: LessonAttachment[], activeBase: string): Promise<LessonAttachment[]> {
    const resolved: LessonAttachment[] = [];
    for (const item of attachments) {
      const mustExpand =
        item.type === "lesson_attribute" &&
        !!item.url &&
        item.url.includes("/attachments/LessonAttribute/") &&
        item.url.endsWith("/list");
      if (!mustExpand || !item.url) {
        resolved.push(item);
        continue;
      }
      try {
        const html = await this.getHtml(absoluteUrl(item.url, activeBase)!);
        const $ = cheerio.load(html);
        const direct: LessonAttachment[] = [];
        $("#saved_attachments_list a[href], .attachments_container a[href], a[href*='/attachment/'][href*='/download']").each((_, el) => {
          const link = $(el);
          const href = link.attr("href");
          if (!href) return;
          direct.push({
            name: normalizeSpaces(link.text()) || "Файл",
            url: absoluteUrl(href, activeBase),
            type: "lesson_attachment",
          });
        });
        if (direct.length) resolved.push(...direct);
        else resolved.push(item);
      } catch {
        resolved.push(item);
      }
    }
    return dedupAttachments(resolved);
  }

  private async request(url: string, init?: RequestInit): Promise<HttpTextResponse> {
    const response = await fetch(url, {
      ...init,
      headers: {
        "User-Agent": "Mozilla/5.0",
        "Accept-Language": "ru-RU,ru;q=0.9,en-US;q=0.8",
        Cookie: this.cookieHeader(),
        ...(init?.headers ?? {}),
      },
    });
    this.storeCookies(response);
    const text = await response.text();
    return {
      ok: response.status >= 200 && response.status <= 399,
      status: response.status,
      text,
      location: response.headers.get("location"),
      url: response.url,
    };
  }

  private async getHtml(url: string): Promise<string> {
    const response = await this.request(url);
    if (!response.ok) throw new Error(`Ошибка загрузки страницы (${response.status}).`);
    return response.text;
  }

  private storeCookies(response: Response): void {
    const getter = (response.headers as Headers & { getSetCookie?: () => string[] }).getSetCookie;
    const rawCookies = getter ? getter.call(response.headers) : splitSetCookie(response.headers.get("set-cookie"));
    for (const raw of rawCookies) {
      const first = raw.split(";")[0]?.trim();
      if (!first) continue;
      const i = first.indexOf("=");
      if (i <= 0) continue;
      const name = first.slice(0, i).trim();
      const value = first.slice(i + 1).trim();
      if (!name) continue;
      this.cookies.set(name, value);
    }
  }

  private cookieHeader(extra?: Record<string, string>): string {
    const all = new Map(this.cookies);
    for (const [key, value] of Object.entries(extra ?? {})) {
      all.set(key, value);
    }
    return [...all.entries()].map(([k, v]) => `${k}=${v}`).join("; ");
  }
}

function parseQuarterGradesTable(html: string): QuarterGradesTable {
  const $ = cheerio.load(html);
  let container: cheerio.Cheerio<any> = $.root();
  const byId = $(".wrap_lmtables[id^='daybook-last-page-container-']").first();
  if (byId.length) {
    container = byId;
  } else {
    const wrap = $(".wrap_lmtables").first();
    if (wrap.length) container = wrap;
  }

  const leftTable = container.find("table.ltable").first();
  const rightTable = container.find("table.mtable[id^='daybook-last-page-table-']").first().length
    ? container.find("table.mtable[id^='daybook-last-page-table-']").first()
    : container.find("table.mtable").first();

  if (leftTable.length && rightTable.length) {
    const qCols = rightTable
      .find("thead tr:nth-child(2) td.qdates")
      .toArray()
      .map((td) => normalizeSpaces($(td).text()))
      .filter(Boolean);
    const avg = normalizeSpaces(rightTable.find("thead tr:nth-child(1) td.avg").first().text()) || "Средняя";
    const year = normalizeSpaces(rightTable.find("thead tr:nth-child(1) td.ymark").first().text()) || "Годовая";
    const columns = [...qCols, avg, year];

    const leftRows = leftTable.find("tbody tr").toArray();
    const rightRows = rightTable.find("tbody tr").toArray();
    const rows = [];
    for (let i = 0; i < Math.min(leftRows.length, rightRows.length); i += 1) {
      const ltr = $(leftRows[i]);
      const rtr = $(rightRows[i]);
      let subject = normalizeSpaces(ltr.find("td.ttl").first().text() || ltr.find("td").first().text());
      subject = subject.replace(/^\d+[\.\)]?\s*/, "").trim();
      if (!subject) continue;
      const gradeCells = rtr.find("td").toArray().map((td) => nullable(normalizeSpaces($(td).text())));
      const aligned = columns.map((_, idx) => (idx < gradeCells.length ? gradeCells[idx] : null));
      rows.push({ subject, grades: aligned });
    }
    return { columns, rows };
  }

  return { columns: [], rows: [] };
}

function parseProfilePayload(html: string): { title: string; avatarUrl?: string; classTeacher?: string } {
  const $ = cheerio.load(html);
  const title = normalizeSpaces(
    $("div.title_box h1").first().text() ||
      $("h1").first().text() ||
      $("a.u_name, a.user_name, a.profile-link").first().text(),
  );
  const avatar = $("div.profile-photo__box img").first().attr("src") || $("img.profile-photo, img.avatar, img.userpic").first().attr("src");
  let classTeacher: string | undefined;
  $("div.pp_line_new").each((_, el) => {
    const text = normalizeSpaces($(el).text());
    if (text.includes("Классный руководитель:")) {
      classTeacher = normalizeSpaces(text.replace("Классный руководитель:", ""));
    }
  });
  return { title, avatarUrl: avatar, classTeacher };
}

function readWeekFromNode(node: cheerio.Cheerio<any>): string | undefined {
  if (!node.length) return undefined;
  for (const key of ["next_week_id", "prev_week_id", "send_to", "href", "data-week"]) {
    const value = node.attr(key);
    const week = weekFromRef(value);
    if (week) return week;
  }
  return undefined;
}

function weekFromRef(value?: string): string | undefined {
  if (!value) return undefined;
  const trimmed = value.trim();
  if (isoWeek(trimmed)) return trimmed;
  return trimmed.match(/\/week\/(\d{4}-\d{2}-\d{2})/)?.[1];
}

function pickWeekBlock($: cheerio.CheerioAPI, weekId: string): cheerio.Cheerio<any> | null {
  const blocks = $("[id^='db_week_']");
  if (!blocks.length) return null;
  for (const item of blocks.toArray()) {
    const id = $(item).attr("id") ?? "";
    if (id.endsWith(`_${weekId}`)) return $(item);
  }
  for (const item of blocks.toArray()) {
    const style = ($(item).attr("style") ?? "").toLowerCase();
    if (!style.includes("display: none")) return $(item);
  }
  return $(blocks[0]);
}

function extractBestMark($: cheerio.CheerioAPI, row: cheerio.Cheerio<any>): string | null {
  const markCell = row.find("td.mark").first();
  if (!markCell.length) return null;

  const candidates: string[] = [];
  markCell.find(".mark_box, strong, b, em, span, div").each((_, el) => {
    const text = normalizeSpaces($(el).text());
    if (text) candidates.push(text);
  });
  if (!candidates.length) {
    const raw = normalizeSpaces(markCell.text());
    if (raw) candidates.push(raw);
  }

  const tokens = candidates
    .flatMap((item) => item.split(/[\s,;]+/))
    .map((item) => item.trim())
    .filter((item) => item && item !== "-" && item !== "???");
  if (!tokens.length) return null;

  let best = tokens[0];
  let bestValue = -1;
  for (const token of tokens) {
    const value = parseMarkValue(token);
    if (value === null) continue;
    if (value >= bestValue) {
      best = token;
      bestValue = value;
    }
  }
  return nullable(best);
}

function parseMarkValue(raw: string): number | null {
  const value = raw.trim().replace(",", ".");
  if (!value) return null;
  if (value.includes("/")) {
    const [a, b] = value.split("/");
    const left = Number(a);
    const right = Number(b);
    if (!Number.isNaN(left) && !Number.isNaN(right)) return (left + right) / 2;
  }
  const direct = Number(value);
  if (!Number.isNaN(direct)) return direct;
  const numbers = value.match(/\d+(\.\d+)?/g)?.map(Number).filter((n) => !Number.isNaN(n)) ?? [];
  if (!numbers.length) return null;
  return Math.max(...numbers);
}

function dedupAttachments(items: LessonAttachment[]): LessonAttachment[] {
  const seen = new Set<string>();
  const result: LessonAttachment[] = [];
  for (const item of items) {
    const key = `${item.url ?? ""}|${item.name}|${item.type ?? ""}`;
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(item);
  }
  return result;
}

function parseTitle(value: string): [string, string | undefined] {
  const trimmed = value.trim();
  const fullName = trimmed.split(",")[0]?.trim() || trimmed;
  const className = trimmed.match(/,\s*(.*?)\s*класс/i)?.[1]?.trim();
  return [fullName, className || undefined];
}

function firstCapture(text: string, pattern: RegExp): string | null {
  return text.match(pattern)?.[1] ?? null;
}

function normalizeSpaces(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function nullable(value: string): string | null {
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function absoluteUrl(raw: string | undefined, baseUrl: string): string | undefined {
  if (!raw || !raw.trim()) return undefined;
  const value = raw.trim();
  if (value.startsWith("http://") || value.startsWith("https://")) return value;
  if (value.startsWith("//")) return `https:${value}`;
  return new URL(value, baseUrl).toString();
}

function pathFromUrl(raw: string | undefined): string | null {
  if (!raw) return null;
  try {
    return new URL(raw).pathname;
  } catch {
    return null;
  }
}

function addDays(isoDate: string, days: number): string {
  const date = new Date(isoDate);
  if (Number.isNaN(date.getTime())) return isoDate;
  date.setDate(date.getDate() + days);
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function isoWeek(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function splitSetCookie(raw: string | null): string[] {
  if (!raw) return [];
  return raw.split(/,(?=\s*[^;=]+=[^;]+)/);
}
