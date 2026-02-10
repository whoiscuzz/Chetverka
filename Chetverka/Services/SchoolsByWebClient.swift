import Foundation
import WebKit

private protocol AnyOptional {
    static func makeNil() -> Any
}

enum SchoolsByError: Error, LocalizedError {
    case invalidCredentials
    case missingCSRFToken
    case missingSessionCookie
    case missingPupilId
    case navigationFailed(String)
    case javascriptFailed(String)
    case parsingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Неверный логин или пароль."
        case .missingCSRFToken:
            return "Не удалось получить CSRF токен."
        case .missingSessionCookie:
            return "Не удалось получить sessionid. Возможно, вход заблокирован."
        case .missingPupilId:
            return "Не удалось определить pupilid."
        case .navigationFailed(let message):
            return "Ошибка загрузки страницы: \(message)"
        case .javascriptFailed(let message):
            return "Ошибка выполнения скрипта: \(message)"
        case .parsingFailed(let message):
            return "Ошибка парсинга: \(message)"
        }
    }
}

@MainActor
final class SchoolsByWebClient {
    static let shared = SchoolsByWebClient()

    // Mirrors the Python backend constants so the iOS client produces the same data.
    private let base = URL(string: "https://4minsk.schools.by")!
    private let fallbackBase = URL(string: "https://schools.by")!
    private let loginURL = URL(string: "https://schools.by/login")!
    private let startWeek = "2026-01-12"
    private let quarterId = "90"
    private let adminPupilIDs: Set<String> = ["1106490"]

    private let runner: WebViewRunner

    private init() {
        self.runner = WebViewRunner()
    }

    func clearSession() async {
        await runner.clearWebsiteData()
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        try await runner.load(loginURL)

        // Fast check for CSRF token presence before trying to submit.
        let csrf: String? = try await runner.evaluateJS("""
            (() => {
              const el = document.querySelector('input[name="csrfmiddlewaretoken"]');
              return el ? el.value : null;
            })()
        """)
        guard csrf != nil else { throw SchoolsByError.missingCSRFToken }

        let usernameB64 = Data(username.utf8).base64EncodedString()
        let passwordB64 = Data(password.utf8).base64EncodedString()

        async let waitNav: Void = runner.waitForNextNavigation()
        _ = try await runner.evaluateJS("""
            (() => {
              const u = atob('\(usernameB64)');
              const p = atob('\(passwordB64)');
              const uEl = document.querySelector('input[name="username"]');
              const pEl = document.querySelector('input[name="password"]');
              const form = (uEl && uEl.form) ? uEl.form : document.querySelector('form');
              if (!uEl || !pEl || !form) return 'MISSING_FIELDS';
              uEl.value = u;
              pEl.value = p;
              form.submit();
              return 'OK';
            })()
        """) as String
        try await waitNav

        // After submit, session cookie must exist.
        let session = await runner.getCookieValue(named: "sessionid", domainContains: "schools.by")
        if session == nil || session?.isEmpty == true {
            let invalidMessagePresent: Bool = (try? await runner.evaluateJS("""
                (() => {
                  const body = document.body?.textContent ?? '';
                  return body.includes('Пожалуйста, введите правильные имя пользователя и пароль');
                })()
            """)) ?? false
            if invalidMessagePresent {
                throw SchoolsByError.invalidCredentials
            }
            throw SchoolsByError.missingSessionCookie
        }
        let sessionUnwrapped = session!

        // Extract pupilid from the mobile main page (same as Python).
        try await runner.load(base.appendingPathComponent("m/"))
        let href: String? = try await runner.evaluateJS("""
            (() => {
              const a = document.querySelector('a.u_name');
              return a ? a.getAttribute('href') : null;
            })()
        """)
        guard let pupilid = href.flatMap(Self.extractPupilId(fromHref:)), !pupilid.isEmpty else {
            throw SchoolsByError.missingPupilId
        }

        // Scrape profile data from pupil page.
        let profileURL = URL(string: "\(base.absoluteString)/pupil/\(pupilid)/")!
        try await runner.load(profileURL)
        let profileJSON: String = try await runner.evaluateJS("""
            (() => {
              const title = document.querySelector('div.title_box h1')?.textContent?.trim() ?? '';
              const avatar = document.querySelector('div.profile-photo__box img')?.getAttribute('src') ?? null;
              let teacher = null;
              const lines = Array.from(document.querySelectorAll('div.pp_line_new'));
              for (const line of lines) {
                const t = line.textContent || '';
                if (t.includes('Классный руководитель:')) {
                  teacher = t.replace('Классный руководитель:', '').trim();
                  break;
                }
              }
              return JSON.stringify({ title, avatarUrl: avatar, classTeacher: teacher });
            })()
        """)

        struct ProfilePayload: Decodable {
            let title: String
            let avatarUrl: String?
            let classTeacher: String?
        }
        guard let payloadData = profileJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ProfilePayload.self, from: payloadData)
        else {
            throw SchoolsByError.parsingFailed("profile JSON decode")
        }

        let (fullName, className) = Self.parseTitle(payload.title)
        let profile = Profile(
            fullName: fullName,
            className: className,
            avatarUrl: payload.avatarUrl,
            classTeacher: payload.classTeacher,
            role: adminPupilIDs.contains(pupilid) ? "admin" : "user"
        )

        return LoginResponse(sessionid: sessionUnwrapped, pupilid: pupilid, profile: profile)
    }

    func fetchDiary(pupilid: String, sessionid: String? = nil) async throws -> DiaryResponse {
        if let sessionid {
            await runner.ensureSessionCookieIfNeeded(value: sessionid)
        }

        var activeBase = base
        var visited = Set<String>()
        var week: String? = startWeek
        var weeks: [Week] = []

        var safetyCounter = 0
        while let w = week, !visited.contains(w) {
            visited.insert(w)
            safetyCounter += 1
            if safetyCounter > 80 { break }

            let url = URL(string: "\(activeBase.absoluteString)/m/pupil/\(pupilid)/dnevnik/quarter/\(quarterId)/week/\(w)")!
            do {
                try await runner.load(url)
            } catch {
                if Self.isHostLookupError(error), activeBase != fallbackBase {
                    // DNS fallback: retry the same week via schools.by once.
                    activeBase = fallbackBase
                    continue
                }
                throw error
            }

            let js: String = """
                (() => {
                  const block = document.querySelector('div.db_days:not([style])');
                  const next = document.querySelector('a.next')?.getAttribute('next_week_id') ?? null;
                  if (!block) return JSON.stringify({ ok: false, nextWeek: next, days: [] });

                  const days = Array.from(block.querySelectorAll('div.db_day'));
                  const resultDays = [];
                  for (const day of days) {
                    const table = day.querySelector('table.db_table');
                    if (!table) { resultDays.push({ name: '?', lessons: [] }); continue; }
                    const dayName = table.querySelector('th.lesson')?.textContent?.trim() ?? '?';
                    const rows = Array.from(table.querySelectorAll('tbody tr'));
                    const lessons = [];
                    for (const tr of rows) {
                      const lessonRaw = tr.querySelector('td.lesson span')?.textContent ?? '';
                      let subject = lessonRaw.replace(/\\s+/g, ' ').trim();
                      subject = subject.replace(/^\\d+[\\.\\)]\\s*/, '');
                      const hw = tr.querySelector('div.ht-text')?.textContent?.replace(/\\s+/g, ' ').trim() ?? null;
                      const mark = tr.querySelector('td.mark strong')?.textContent?.trim() ?? null;

                      const attachments = [];
                      const pushAttachment = (name, href, type) => {
                        const normalizedName = (name || '').replace(/\\s+/g, ' ').trim();
                        const normalizedHref = (href || '').trim();
                        if (!normalizedHref) return;
                        attachments.push({
                          name: normalizedName || 'Файл',
                          url: normalizedHref,
                          type: type || null
                        });
                      };

                      const toggle = tr.querySelector('a.attachments_dropdown_toggle[href]');
                      if (toggle) {
                        pushAttachment('Файлы к уроку', toggle.getAttribute('href'), 'lesson_attribute');
                      }

                      const menuLinks = Array.from(tr.querySelectorAll('.attachments_dropdown_menu a[href]'));
                      for (const a of menuLinks) {
                        pushAttachment(a.textContent, a.getAttribute('href'), 'lesson_attachment');
                      }

                      const hwLinks = Array.from(tr.querySelectorAll('div.ht-text a[href]'));
                      for (const a of hwLinks) {
                        pushAttachment(a.textContent, a.getAttribute('href'), 'hw_link');
                      }

                      // Deduplicate by url+name.
                      const dedup = [];
                      const seen = new Set();
                      for (const item of attachments) {
                        const key = `${item.url}|${item.name}`;
                        if (seen.has(key)) continue;
                        seen.add(key);
                        dedup.push(item);
                      }

                      if (!subject && !hw && !mark) continue;
                      lessons.push({ subject, mark, hw, attachments: dedup });
                    }
                    resultDays.push({ name: dayName, lessons });
                  }
                  return JSON.stringify({ ok: true, nextWeek: next, days: resultDays });
                })()
            """

            struct WeekPayload: Decodable {
                struct DayPayload: Decodable {
                    struct LessonPayload: Decodable {
                        struct AttachmentPayload: Decodable {
                            let name: String
                            let url: String?
                            let type: String?
                        }
                        let subject: String
                        let mark: String?
                        let hw: String?
                        let attachments: [AttachmentPayload]?
                    }
                    let name: String
                    let lessons: [LessonPayload]
                }
                let ok: Bool
                let nextWeek: String?
                let days: [DayPayload]
            }

            let payloadJSON: String = try await runner.evaluateJS(js)
            guard let data = payloadJSON.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(WeekPayload.self, from: data)
            else {
                throw SchoolsByError.parsingFailed("week JSON decode")
            }

            if !payload.ok {
                // Mirrors Python behavior: stop if week block is missing (empty week / session expired / block).
                if weeks.isEmpty {
                    throw SchoolsByError.missingSessionCookie
                }
                break
            }

            let days: [Day] = payload.days.enumerated().map { idx, d in
                let date = Self.addDays(isoDate: w, days: idx)
                let lessons: [Lesson] = d.lessons.map { lp in
                    let attachments = (lp.attachments ?? []).map { a in
                        LessonAttachment(
                            name: a.name,
                            url: Self.absoluteURLString(from: a.url, base: activeBase),
                            type: a.type
                        )
                    }
                    return Lesson(subject: lp.subject, mark: lp.mark, hw: lp.hw, attachments: attachments.isEmpty ? nil : attachments)
                }
                return Day(date: date, name: d.name, lessons: lessons)
            }
            let resolvedDays = try await resolveAttachmentLinks(in: days, activeBase: activeBase)
            weeks.append(Week(monday: w, days: resolvedDays))

            week = payload.nextWeek
        }

        return DiaryResponse(weeks: weeks)
    }

    func fetchQuarterGrades(pupilid: String, sessionid: String? = nil) async throws -> QuarterGradesTable {
        if let sessionid {
            await runner.ensureSessionCookieIfNeeded(value: sessionid)
        }

        let url = URL(string: "\(base.absoluteString)/m/pupil/\(pupilid)/dnevnik/last-page")!
        try await runner.load(url)

        let payloadJSON: String = try await runner.evaluateJS("""
            (() => {
              const normalize = (s) => (s || '').replace(/\\s+/g,' ').trim();
              const container = document.querySelector('.wrap_lmtables[id^=\"daybook-last-page-container-\"]');
              if (!container) return JSON.stringify({ columns: [], rows: [] });

              const leftTable = container.querySelector('table.ltable');
              const rightTable = container.querySelector('table.mtable[id^=\"daybook-last-page-table-\"]');
              if (!leftTable || !rightTable) return JSON.stringify({ columns: [], rows: [] });

              const qCols = Array.from(rightTable.querySelectorAll('thead tr:nth-child(2) td.qdates'))
                .map(td => normalize(td.textContent))
                .map(v => v || null)
                .filter(Boolean);
              const avgLabel = normalize(rightTable.querySelector('thead tr:nth-child(1) td.avg')?.textContent || '');
              const yearLabel = normalize(rightTable.querySelector('thead tr:nth-child(1) td.ymark')?.textContent || '');
              const columns = [
                ...qCols,
                avgLabel || 'Средняя',
                yearLabel || 'Годовая'
              ];

              const leftRows = Array.from(leftTable.querySelectorAll('tbody tr'));
              const rightRows = Array.from(rightTable.querySelectorAll('tbody tr'));
              const rowCount = Math.min(leftRows.length, rightRows.length);

              const rows = [];
              for (let i = 0; i < rowCount; i++) {
                const ltr = leftRows[i];
                const rtr = rightRows[i];

                const subjectNode = ltr.querySelector('td.ttl');
                let subject = normalize(subjectNode ? subjectNode.textContent : '');
                subject = subject.replace(/^\\d+[\\.)]?\\s*/, '').trim();
                if (!subject) continue;

                const gradeCells = Array.from(rtr.querySelectorAll('td'));
                const grades = gradeCells.map(td => {
                  const value = normalize(td.textContent);
                  return value === '' ? null : value;
                });

                // Keep exactly as many columns as in header.
                const aligned = columns.map((_, idx) => (idx < grades.length ? grades[idx] : null));
                rows.push({ subject, grades: aligned });
              }

              return JSON.stringify({ columns, rows });
            })()
        """)

        guard let data = payloadJSON.data(using: .utf8),
              let table = try? JSONDecoder().decode(QuarterGradesTable.self, from: data)
        else {
            throw SchoolsByError.parsingFailed("quarter grades JSON decode")
        }

        return table
    }

    // MARK: - Helpers

    private static func extractPupilId(fromHref href: String) -> String? {
        // Example: "/pupil/123456"
        guard let range = href.range(of: "/pupil/") else { return nil }
        let tail = href[range.upperBound...]
        let digits = tail.prefix { $0.isNumber }
        return digits.isEmpty ? nil : String(digits)
    }

    private static func parseTitle(_ fullTitle: String) -> (fullName: String, className: String?) {
        let trimmed = fullTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName = trimmed.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? trimmed

        // Extract ", <CLASS> класс"
        let pattern = #",\s*(.*?)\s*класс"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
           match.numberOfRanges >= 2,
           let r = Range(match.range(at: 1), in: trimmed) {
            let className = String(trimmed[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (fullName, className.isEmpty ? nil : className)
        }

        return (fullName, nil)
    }

    private static func addDays(isoDate: String, days: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: isoDate),
              let shifted = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: date)
        else { return isoDate }
        return formatter.string(from: shifted)
    }

    private static func absoluteURLString(from raw: String?, base: URL) -> String? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return raw
        }
        if raw.hasPrefix("//") {
            return "https:\(raw)"
        }
        if let url = URL(string: raw, relativeTo: base)?.absoluteURL.absoluteString {
            return url
        }
        return raw
    }

    private static func isHostLookupError(_ error: Error) -> Bool {
        if let e = error as? SchoolsByError {
            switch e {
            case .navigationFailed(let message):
                let lower = message.lowercased()
                return lower.contains("-1003")
                    || lower.contains("cannotfindhost")
                    || lower.contains("could not be found")
                    || lower.contains("не удалось найти")
                    || lower.contains("имя хоста")
            default:
                return false
            }
        }
        return false
    }

    private func resolveAttachmentLinks(in days: [Day], activeBase: URL) async throws -> [Day] {
        var resolvedDays: [Day] = []
        resolvedDays.reserveCapacity(days.count)

        for day in days {
            var resolvedLessons: [Lesson] = []
            resolvedLessons.reserveCapacity(day.lessons.count)

            for lesson in day.lessons {
                let attachments = try await resolveAttachments(lesson.attachments ?? [], activeBase: activeBase)
                let resolvedLesson = Lesson(
                    subject: lesson.subject,
                    mark: lesson.mark,
                    hw: lesson.hw,
                    attachments: attachments.isEmpty ? nil : attachments
                )
                resolvedLessons.append(resolvedLesson)
            }

            resolvedDays.append(Day(date: day.date, name: day.name, lessons: resolvedLessons))
        }

        return resolvedDays
    }

    private func resolveAttachments(_ attachments: [LessonAttachment], activeBase: URL) async throws -> [LessonAttachment] {
        var resolved: [LessonAttachment] = []
        resolved.reserveCapacity(attachments.count)

        for attachment in attachments {
            guard attachment.type == "lesson_attribute",
                  let rawURL = attachment.url,
                  let url = URL(string: rawURL),
                  rawURL.contains("/attachments/LessonAttribute/"),
                  rawURL.hasSuffix("/list")
            else {
                resolved.append(attachment)
                continue
            }

            do {
                let direct = try await fetchDirectAttachments(from: url, activeBase: activeBase)
                if direct.isEmpty {
                    resolved.append(attachment)
                } else {
                    resolved.append(contentsOf: direct)
                }
            } catch {
                // Keep original list page link when expanding attachments fails.
                resolved.append(attachment)
            }
        }

        return Self.deduplicatedAttachments(resolved)
    }

    private func fetchDirectAttachments(from url: URL, activeBase: URL) async throws -> [LessonAttachment] {
        try await runner.load(url)

        let payloadJSON: String = try await runner.evaluateJS("""
            (() => {
              const normalize = (s) => (s || '').replace(/\\s+/g, ' ').trim();
              const links = Array.from(document.querySelectorAll(
                '#saved_attachments_list a[href], .attachments_container a[href], a[href*="/attachment/"][href*="/download"]'
              ));
              const result = links.map((a) => ({
                name: normalize(a.textContent) || 'Файл',
                url: normalize(a.getAttribute('href'))
              })).filter((item) => item.url);
              return JSON.stringify(result);
            })()
        """)

        struct DirectAttachmentPayload: Decodable {
            let name: String
            let url: String
        }

        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode([DirectAttachmentPayload].self, from: data)
        else {
            throw SchoolsByError.parsingFailed("direct attachments JSON decode")
        }

        return payload.map { item in
            LessonAttachment(
                name: item.name,
                url: Self.absoluteURLString(from: item.url, base: activeBase),
                type: "lesson_attachment"
            )
        }
    }

    private static func deduplicatedAttachments(_ attachments: [LessonAttachment]) -> [LessonAttachment] {
        var seen = Set<String>()
        var result: [LessonAttachment] = []
        result.reserveCapacity(attachments.count)

        for attachment in attachments {
            let key = "\(attachment.url ?? "")|\(attachment.name)|\(attachment.type ?? "")"
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            result.append(attachment)
        }

        return result
    }
}

@MainActor
private final class WebViewRunner: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private var navigationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init()

        self.webView.navigationDelegate = self
        self.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }

    func load(_ url: URL) async throws {
        try await load(URLRequest(url: url))
    }

    func load(_ request: URLRequest) async throws {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                try await loadOnce(request)
                return
            } catch {
                lastError = error
                // Best-effort retry for transient webview/network failures.
                if attempt == 0 {
                    continue
                }
            }
        }
        throw lastError ?? SchoolsByError.navigationFailed("unknown")
    }

    private func loadOnce(_ request: URLRequest) async throws {
        // If there is already a pending navigation wait, fail fast to avoid mixing flows.
        if navigationContinuation != nil {
            throw SchoolsByError.navigationFailed("concurrent navigation")
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            navigationContinuation = cont
            webView.load(request)
        }
    }

    func waitForNextNavigation() async throws {
        if navigationContinuation != nil {
            throw SchoolsByError.navigationFailed("concurrent navigation wait")
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            navigationContinuation = cont
        }
    }

    func evaluateJS<T>(_ script: String) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    cont.resume(throwing: SchoolsByError.javascriptFailed(error.localizedDescription))
                    return
                }
                if let casted = value as? T {
                    cont.resume(returning: casted)
                    return
                }
                if value == nil, let optionalType = T.self as? AnyOptional.Type {
                    cont.resume(returning: optionalType.makeNil() as! T)
                    return
                }
                cont.resume(throwing: SchoolsByError.javascriptFailed("unexpected JS result type"))
            }
        }
    }

    func getCookieValue(named name: String, domainContains: String) async -> String? {
        let cookies = await getAllCookies()
        return cookies.first(where: { $0.name == name && $0.domain.contains(domainContains) })?.value
    }

    func clearWebsiteData() async {
        // Delete cookies.
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await getAllCookies()
        for cookie in cookies {
            await withCheckedContinuation { cont in
                store.delete(cookie) {
                    cont.resume()
                }
            }
        }

        // Delete storage/cache for this webview.
        let dataStore = webView.configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { cont in
            dataStore.removeData(ofTypes: types, modifiedSince: Date(timeIntervalSince1970: 0)) {
                cont.resume()
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationContinuation?.resume()
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        navigationContinuation?.resume(throwing: SchoolsByError.navigationFailed("\(error.localizedDescription) [\(nsError.code)]"))
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        navigationContinuation?.resume(throwing: SchoolsByError.navigationFailed("\(error.localizedDescription) [\(nsError.code)]"))
        navigationContinuation = nil
    }

    // MARK: - Cookies

    private func getAllCookies() async -> [HTTPCookie] {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        return await withCheckedContinuation { cont in
            store.getAllCookies { cookies in
                cont.resume(returning: cookies)
            }
        }
    }

    func ensureSessionCookieIfNeeded(value: String) async {
        let existing = await getCookieValue(named: "sessionid", domainContains: "schools.by")
        if existing == value { return }

        let props: [HTTPCookiePropertyKey: Any] = [
            .name: "sessionid",
            .value: value,
            .domain: ".schools.by",
            .path: "/",
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 30) // Best-effort; real expiry is server-defined.
        ]
        guard let cookie = HTTPCookie(properties: props) else { return }

        let store = webView.configuration.websiteDataStore.httpCookieStore
        await withCheckedContinuation { cont in
            store.setCookie(cookie) {
                cont.resume()
            }
        }
    }
}

extension Optional: AnyOptional {
    fileprivate static func makeNil() -> Any {
        Self.none as Any
    }
}
