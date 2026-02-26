package by.schools.chetverka.data.schoolsby

import android.annotation.SuppressLint
import android.content.Context
import android.net.http.SslError
import android.util.Log
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import by.schools.chetverka.data.api.DayDto
import by.schools.chetverka.data.api.DiaryResponse
import by.schools.chetverka.data.api.LessonAttachment
import by.schools.chetverka.data.api.LessonDto
import by.schools.chetverka.data.api.LoginResponse
import by.schools.chetverka.data.api.ProfileDto
import by.schools.chetverka.data.api.WeekDto
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class SchoolsByWebClient(appContext: Context) {
    private val tag = "SchoolsByWebClient"

    private val context = appContext.applicationContext

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val base = "https://4minsk.schools.by"
    private val altBase = "https://schools.by"
    private val loginUrl = "https://schools.by/login"
    private val defaultStartWeek = "2026-01-12"
    private val defaultQuarterId = "90"

    private val runner by lazy { WebViewRunner(context, json) }

    suspend fun clearSession() {
        runner.clearWebsiteData()
    }

    suspend fun login(username: String, password: String): LoginResponse {
        runner.load(loginUrl)

        val csrf = runner.evalString(
            """
            (() => {
              const el = document.querySelector('input[name="csrfmiddlewaretoken"]');
              return el ? el.value : null;
            })()
            """.trimIndent()
        )
        if (csrf.isNullOrBlank()) throw SchoolsByWebError.MissingCsrfToken

        val u = json.encodeToString(username)
        val p = json.encodeToString(password)

        runner.evalAndWaitNavigation(
            """
            (() => {
              const uVal = $u;
              const pVal = $p;
              const uEl = document.querySelector('input[name="username"]');
              const pEl = document.querySelector('input[name="password"]');
              const form = (uEl && uEl.form) ? uEl.form : document.querySelector('form');
              if (!uEl || !pEl || !form) return;
              uEl.value = uVal;
              pEl.value = pVal;
              form.submit();
            })()
            """.trimIndent()
        )

        val sessionId = runner.getCookieValue(url = "https://schools.by", cookieName = "sessionid")
        if (sessionId.isNullOrBlank()) {
            val invalid = runner.evalBoolean(
                """
                (() => {
                  const body = document.body?.textContent ?? '';
                  return body.includes('Пожалуйста, введите правильные имя пользователя и пароль');
                })()
                """.trimIndent()
            ) ?: false

            if (invalid) throw SchoolsByWebError.InvalidCredentials
            throw SchoolsByWebError.MissingSessionCookie
        }

        val (pupilId, activeBase) = resolvePupilIdFromPage(sessionId)
            ?: throw SchoolsByWebError.MissingPupilId

        runner.load("$activeBase/pupil/$pupilId/")
        val profilePayloadJson = runner.evalString(
            """
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
            """.trimIndent()
        )
        if (profilePayloadJson.isNullOrBlank()) throw SchoolsByWebError.ParsingFailed("profile payload")

        val profilePayload = runCatching {
            json.decodeFromString<ProfilePayload>(profilePayloadJson)
        }.getOrElse { throw SchoolsByWebError.ParsingFailed("profile JSON decode") }

        val (fullName, className) = parseTitle(profilePayload.title)
        val profile = ProfileDto(
            fullName = fullName,
            className = className,
            avatarUrl = profilePayload.avatarUrl,
            classTeacher = profilePayload.classTeacher
        )

        return LoginResponse(
            sessionid = sessionId,
            pupilid = pupilId,
            profile = profile
        )
    }

    suspend fun fetchDiary(sessionId: String?, pupilId: String): DiaryResponse {
        if (!sessionId.isNullOrBlank()) {
            runner.ensureSessionCookie(value = sessionId)
        }

        val diaryContext = resolveDiaryContext(pupilId)
        val quarterId = diaryContext.quarterId ?: defaultQuarterId
        val discoveredWeeks = discoverQuarterWeekCandidates(pupilId, quarterId)
        val startWeek = diaryContext.weekId ?: discoveredWeeks.firstOrNull() ?: defaultStartWeek
        Log.i(tag, "fetchDiary pupilId=$pupilId quarterId=$quarterId startWeek=$startWeek")

        val visited = mutableSetOf<String>()
        val pendingWeeks = ArrayDeque<String>()
        pendingWeeks.add(startWeek)
        discoveredWeeks
            .asSequence()
            .filterNot { it == startWeek }
            .forEach(pendingWeeks::add)
        val weeksByMonday = linkedMapOf<String, WeekDto>()

        var safetyCounter = 0
        while (pendingWeeks.isNotEmpty()) {
            val currentWeek = pendingWeeks.removeFirst()
            if (visited.contains(currentWeek)) continue
            visited += currentWeek
            safetyCounter += 1
            if (safetyCounter > 80) break

            val payload = loadWeekPayloadWithFallback(
                pupilId = pupilId,
                quarterId = quarterId,
                weekId = currentWeek
            ) ?: throw SchoolsByWebError.ParsingFailed("week payload for week=$currentWeek")
            val resolvedWeek = payload.currentWeek
                ?.takeIf { it.matches(ISO_WEEK_REGEX) }
                ?: addDaysOrNull(payload.nextWeek, -7)
                ?: addDaysOrNull(payload.prevWeek, 7)
                ?: currentWeek
            Log.i(
                tag,
                "week payload requested=$currentWeek resolved=$resolvedWeek next=${payload.nextWeek} prev=${payload.prevWeek} links=${payload.weekLinks.size} days=${payload.days.size}"
            )

            if (!payload.ok) {
                if (weeksByMonday.isEmpty()) {
                    throw SchoolsByWebError.ParsingFailed(
                        "diary unavailable for quarter=$quarterId, requestedWeek=$currentWeek resolvedWeek=$resolvedWeek"
                    )
                }
                Log.w(tag, "week payload not ok, skip requestedWeek=$currentWeek resolvedWeek=$resolvedWeek quarter=$quarterId")
                continue
            }
            if (payload.days.isEmpty()) {
                Log.w(tag, "week payload empty days, skip requestedWeek=$currentWeek resolvedWeek=$resolvedWeek")
                continue
            }

            val days = payload.days.mapIndexed { index, d ->
                DayDto(
                    date = addDays(resolvedWeek, index),
                    name = d.name,
                    lessons = d.lessons.map { lp ->
                        LessonDto(
                            subject = lp.subject,
                            mark = lp.mark,
                            hw = lp.hw,
                            attachments = lp.attachments
                                ?.map { a -> LessonAttachment(name = a.name, url = a.url, type = a.type) }
                                ?.takeIf { it.isNotEmpty() }
                        )
                    }
                )
            }

            weeksByMonday[resolvedWeek] = WeekDto(monday = resolvedWeek, days = days)
            payload.nextWeek
                ?.takeIf { it.matches(ISO_WEEK_REGEX) && !visited.contains(it) && !pendingWeeks.contains(it) }
                ?.let(pendingWeeks::add)
            payload.prevWeek
                ?.takeIf { it.matches(ISO_WEEK_REGEX) && !visited.contains(it) && !pendingWeeks.contains(it) }
                ?.let(pendingWeeks::add)
            payload.weekLinks
                .asSequence()
                .filter { it.matches(ISO_WEEK_REGEX) }
                .filterNot { visited.contains(it) || pendingWeeks.contains(it) }
                .forEach(pendingWeeks::add)
        }

        if (weeksByMonday.size <= 3) {
            Log.w(tag, "fetchDiary got only ${weeksByMonday.size} weeks from nav; fallback quarter scan enabled")
            for (offset in 1..20) {
                val backward = addDays(startWeek, -7 * offset)
                val forward = addDays(startWeek, 7 * offset)
                for (candidate in listOf(backward, forward)) {
                    if (!candidate.matches(ISO_WEEK_REGEX)) continue
                    if (weeksByMonday.containsKey(candidate)) continue

                    val payload = loadWeekPayloadWithFallback(
                        pupilId = pupilId,
                        quarterId = quarterId,
                        weekId = candidate
                    ) ?: continue
                    if (!payload.ok || payload.days.isEmpty()) continue
                    val resolvedWeek = payload.currentWeek
                        ?.takeIf { it.matches(ISO_WEEK_REGEX) }
                        ?: addDaysOrNull(payload.nextWeek, -7)
                        ?: addDaysOrNull(payload.prevWeek, 7)
                        ?: candidate
                    if (weeksByMonday.containsKey(resolvedWeek)) continue

                    val days = payload.days.mapIndexed { index, d ->
                        DayDto(
                            date = addDays(resolvedWeek, index),
                            name = d.name,
                            lessons = d.lessons.map { lp ->
                                LessonDto(
                                    subject = lp.subject,
                                    mark = lp.mark,
                                    hw = lp.hw,
                                    attachments = lp.attachments
                                        ?.map { a -> LessonAttachment(name = a.name, url = a.url, type = a.type) }
                                        ?.takeIf { it.isNotEmpty() }
                                )
                            }
                        )
                    }
                    weeksByMonday[resolvedWeek] = WeekDto(monday = resolvedWeek, days = days)
                }
            }
        }

        val weeks = weeksByMonday.values.toList()
        if (weeks.isEmpty()) {
            throw SchoolsByWebError.ParsingFailed(
                "diary empty after parse quarter=$quarterId startWeek=$startWeek visited=${visited.size}"
            )
        }
        Log.i(tag, "fetchDiary parsed weeks=${weeks.size}")
        return DiaryResponse(weeks = weeks.sortedBy { it.monday })
    }

    private suspend fun resolvePupilIdFromPage(sessionId: String): Pair<String, String>? {
        val bases = listOf(base, altBase)
        for (host in bases) {
            runner.ensureSessionCookie(value = sessionId)
            if (runCatching { runner.load("$host/m/") }.isFailure) continue
            delay(1000)
            val href = runner.evalString(
                """
                (() => {
                  const direct = document.querySelector('a.u_name, a.user_name, a.profile-link');
                  if (direct) {
                    const h = direct.getAttribute('href');
                    if (h && /\/pupil\/\d+/.test(h)) return h;
                  }
                  const allAnchors = Array.from(document.querySelectorAll('a[href]'));
                  for (const a of allAnchors) {
                    const href = a.getAttribute('href') || '';
                    if (/\/pupil\/\d+/.test(href)) return href;
                  }
                  const html = document.documentElement?.innerHTML || '';
                  const match = html.match(/\/pupil\/(\d+)/);
                  return match ? '/pupil/' + match[1] : null;
                })()
                """.trimIndent()
            )
            val id = href?.let(::extractPupilId)
            if (!id.isNullOrBlank()) return id to host
        }
        return null
    }

    private fun extractPupilId(href: String): String? {
        val idx = href.indexOf("/pupil/")
        if (idx < 0) return null
        val tail = href.substring(idx + "/pupil/".length)
        val digits = tail.takeWhile { it.isDigit() }
        return digits.ifBlank { null }
    }

    private fun parseTitle(fullTitle: String): Pair<String, String?> {
        val trimmed = fullTitle.trim()
        val fullName = trimmed.split(",").firstOrNull()?.trim().orEmpty().ifBlank { trimmed }

        val regex = Regex(""",\s*(.*?)\s*класс""", RegexOption.IGNORE_CASE)
        val className = regex.find(trimmed)?.groupValues?.getOrNull(1)?.trim()?.ifBlank { null }
        return fullName to className
    }

    private fun addDays(isoDate: String, days: Int): String {
        val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd", Locale.US)
        val baseDate = runCatching { LocalDate.parse(isoDate, formatter) }.getOrNull() ?: return isoDate
        return baseDate.plusDays(days.toLong()).format(formatter)
    }

    private fun addDaysOrNull(isoDate: String?, days: Int): String? {
        if (isoDate.isNullOrBlank()) return null
        val formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd", Locale.US)
        val baseDate = runCatching { LocalDate.parse(isoDate, formatter) }.getOrNull() ?: return null
        return baseDate.plusDays(days.toLong()).format(formatter)
    }

    private suspend fun resolveDiaryContext(pupilId: String): DiaryContext {
        runner.load("$base/m/pupil/$pupilId/dnevnik")
        val paths = readDiaryPathsFromCurrentPage(pupilId)
        return buildDiaryContext(paths)
    }

    private suspend fun readDiaryPathsFromCurrentPage(pupilId: String): List<String> {
        val payloadJson = runner.evalString(
            """
            (() => {
              const paths = [];
              const push = (value) => {
                if (!value) return;
                const normalized = String(value).trim();
                if (!normalized) return;
                paths.push(normalized);
              };
              push(window.location.pathname);
              const quarterSelect =
                document.querySelector('select[name="quarter_id"]') ||
                document.querySelector('select[name="quarter"]') ||
                document.querySelector('select#quarter_id');
              const selectedQuarter =
                quarterSelect?.value ||
                quarterSelect?.querySelector('option:checked')?.value ||
                null;
              if (selectedQuarter && /^\d+$/.test(String(selectedQuarter).trim())) {
                push(`/m/pupil/$pupilId/dnevnik/quarter/${'$'}{String(selectedQuarter).trim()}`);
              }
              const nextWeekId = document.querySelector('a.next')?.getAttribute('next_week_id');
              if (nextWeekId && /^\d{4}-\d{2}-\d{2}$/.test(nextWeekId)) {
                push(`/m/pupil/$pupilId/dnevnik/week/${'$'}{nextWeekId}`);
              }
              const weekLinks = Array.from(document.querySelectorAll('a[href*="/dnevnik/quarter/"], a[href*="/dnevnik/week/"]'));
              for (const link of weekLinks) {
                push(link.getAttribute('href'));
              }
              const html = document.documentElement?.innerHTML || '';
              const quarterMatches = Array.from(html.matchAll(/\/dnevnik\/quarter\/(\d+)/g));
              for (const m of quarterMatches) {
                const quarter = m?.[1];
                if (quarter) push(`/m/pupil/$pupilId/dnevnik/quarter/${'$'}{quarter}`);
              }
              return JSON.stringify({ paths: Array.from(new Set(paths)) });
            })()
            """.trimIndent()
        ) ?: return emptyList()

        val payload = runCatching {
            json.decodeFromString<DiaryPathPayload>(payloadJson)
        }.getOrNull() ?: return emptyList()

        return payload.paths
    }

    private fun buildDiaryContext(paths: List<String>): DiaryContext {
        for (path in paths) {
            val parsed = extractQuarterAndWeek(path) ?: continue
            return DiaryContext(quarterId = parsed.first, weekId = parsed.second)
        }
        for (path in paths) {
            val quarter = extractQuarterOnly(path) ?: continue
            return DiaryContext(quarterId = quarter, weekId = null)
        }
        return DiaryContext(quarterId = null, weekId = null)
    }

    private fun extractQuarterAndWeek(path: String): Pair<String, String>? {
        val match = QUARTER_WEEK_REGEX.find(path) ?: return null
        return match.groupValues[1] to match.groupValues[2]
    }

    private fun extractQuarterOnly(path: String): String? {
        val match = QUARTER_ONLY_REGEX.find(path) ?: return null
        return match.groupValues.getOrNull(1)
    }

    private fun extractWeekId(path: String): String? {
        val match = WEEK_ONLY_REGEX.find(path) ?: return null
        return match.groupValues.getOrNull(1)
    }

    private suspend fun discoverQuarterWeekCandidates(pupilId: String, quarterId: String): List<String> {
        runner.load("$base/m/pupil/$pupilId/dnevnik/quarter/$quarterId")
        val payloadJson = runner.evalString(
            """
            (() => {
              const normalize = (s) => (s || '').trim();
              const collectWeek = (href) => {
                const value = normalize(href);
                if (!value) return null;
                const match = value.match(/\/week\/(\d{4}-\d{2}-\d{2})/);
                return match ? match[1] : null;
              };
              const weekLinks = [];
              for (const a of Array.from(document.querySelectorAll('a[href*="/week/"]'))) {
                const week = collectWeek(a.getAttribute('href'));
                if (week) weekLinks.push(week);
              }
              const weekSelect =
                document.querySelector('select[name="week_id"]') ||
                document.querySelector('select[name="week"]') ||
                document.querySelector('select#week_id');
              if (weekSelect) {
                for (const option of Array.from(weekSelect.querySelectorAll('option'))) {
                  const week =
                    collectWeek(option.getAttribute('value')) ||
                    collectWeek(option.textContent);
                  if (week) weekLinks.push(week);
                }
              }
              const html = document.documentElement?.innerHTML || '';
              const htmlWeeks = Array.from(html.matchAll(/\/week\/(\d{4}-\d{2}-\d{2})/g)).map((m) => m?.[1]).filter(Boolean);
              for (const week of htmlWeeks) weekLinks.push(week);
              const path = window.location.pathname || null;
              const nextWeek = normalize(document.querySelector('a.next')?.getAttribute('next_week_id')) || null;
              const prevWeek = normalize(document.querySelector('a.prev')?.getAttribute('prev_week_id')) || null;
              return JSON.stringify({ path, nextWeek, prevWeek, weekLinks: Array.from(new Set(weekLinks)) });
            })()
            """.trimIndent()
        ) ?: return emptyList()

        val payload = runCatching {
            json.decodeFromString<WeekDiscoveryPayload>(payloadJson)
        }.getOrNull() ?: return emptyList()

        val result = linkedSetOf<String>()
        extractWeekId(payload.path.orEmpty())?.let(result::add)
        payload.weekLinks.sorted().forEach(result::add)
        addDaysOrNull(payload.nextWeek, -7)?.let(result::add)
        addDaysOrNull(payload.prevWeek, 7)?.let(result::add)
        return result.toList()
    }

    private suspend fun loadWeekPayloadWithFallback(
        pupilId: String,
        quarterId: String,
        weekId: String
    ): WeekPayload? {
        val candidates = listOf(
            "$base/m/pupil/$pupilId/dnevnik/week/$weekId",
            "$base/m/pupil/$pupilId/dnevnik/quarter/$quarterId/week/$weekId",
            "$altBase/m/pupil/$pupilId/dnevnik/week/$weekId",
            "$altBase/m/pupil/$pupilId/dnevnik/quarter/$quarterId/week/$weekId"
        )

        var lastParsed: WeekPayload? = null
        for (url in candidates) {
            val loaded = runCatching { runner.load(url) }.isSuccess
            if (!loaded) continue
            val payloadJson = runner.evalString(DIARY_WEEK_JS) ?: continue
            val payload = runCatching {
                json.decodeFromString<WeekPayload>(payloadJson)
            }.getOrNull() ?: continue
            lastParsed = payload

            if (payload.ok && payload.days.isNotEmpty()) {
                return payload
            }
        }
        return lastParsed
    }

    @Serializable
    private data class ProfilePayload(
        val title: String,
        val avatarUrl: String? = null,
        val classTeacher: String? = null
    )

    @Serializable
    private data class WeekPayload(
        val ok: Boolean,
        val currentWeek: String? = null,
        val nextWeek: String? = null,
        val prevWeek: String? = null,
        val weekLinks: List<String> = emptyList(),
        val days: List<DayPayload> = emptyList()
    ) {
        @Serializable
        data class DayPayload(
            val name: String,
            val lessons: List<LessonPayload> = emptyList()
        ) {
            @Serializable
            data class LessonPayload(
                val subject: String,
                val mark: String? = null,
                val hw: String? = null,
                val attachments: List<AttachmentPayload>? = null
            ) {
                @Serializable
                data class AttachmentPayload(
                    val name: String,
                    val url: String? = null,
                    val type: String? = null
                )
            }
        }
    }

    @Serializable
    private data class DiaryPathPayload(
        val paths: List<String> = emptyList()
    )

    @Serializable
    private data class WeekDiscoveryPayload(
        val path: String? = null,
        val nextWeek: String? = null,
        val prevWeek: String? = null,
        val weekLinks: List<String> = emptyList()
    )

    private data class DiaryContext(
        val quarterId: String?,
        val weekId: String?
    )

    private companion object {
        private val ISO_WEEK_REGEX = Regex("""^\d{4}-\d{2}-\d{2}$""")
        private val QUARTER_WEEK_REGEX = Regex("""/dnevnik/quarter/(\d+)/week/(\d{4}-\d{2}-\d{2})""", RegexOption.IGNORE_CASE)
        private val QUARTER_ONLY_REGEX = Regex("""/dnevnik/quarter/(\d+)""", RegexOption.IGNORE_CASE)
        private val WEEK_ONLY_REGEX = Regex("""/week/(\d{4}-\d{2}-\d{2})""", RegexOption.IGNORE_CASE)

        // Returns JSON.stringify({ok,nextWeek,prevWeek,weekLinks,days:[{name,lessons:[{subject,mark,hw}]}]})
        private val DIARY_WEEK_JS = """
            (() => {
              const readWeekFromValue = (value) => {
                const normalized = (value || '').toString().trim();
                if (!normalized) return null;
                if (/^\d{4}-\d{2}-\d{2}$/.test(normalized)) return normalized;
                const match = normalized.match(/\/week\/(\d{4}-\d{2}-\d{2})/);
                return match ? match[1] : null;
              };
              const readWeekFromLink = (selector) => {
                const link = document.querySelector(selector);
                if (!link) return null;
                return (
                  readWeekFromValue(link.getAttribute('next_week_id')) ||
                  readWeekFromValue(link.getAttribute('prev_week_id')) ||
                  readWeekFromValue(link.getAttribute('data-week')) ||
                  readWeekFromValue(link.getAttribute('href'))
                );
              };
              const block = document.querySelector('div.db_days:not([style])') || document.querySelector('div.db_days');
              const next = readWeekFromLink('a.next');
              const prev = readWeekFromLink('a.prev');
              const weekLinks = Array.from(
                new Set(
                  [
                    ...Array.from(document.querySelectorAll('a[href*="/week/"], a.next, a.prev'))
                      .map((a) =>
                        readWeekFromValue(a.getAttribute('href')) ||
                        readWeekFromValue(a.getAttribute('next_week_id')) ||
                        readWeekFromValue(a.getAttribute('prev_week_id')) ||
                        readWeekFromValue(a.getAttribute('data-week'))
                      )
                      .filter(Boolean),
                    ...Array.from(
                      (
                        document.querySelector('select[name="week_id"]') ||
                        document.querySelector('select[name="week"]') ||
                        document.querySelector('select#week_id')
                      )?.querySelectorAll('option') || []
                    )
                      .map((o) => readWeekFromValue(o.getAttribute('value')) || readWeekFromValue(o.textContent))
                      .filter(Boolean),
                    ...Array.from(
                      (document.documentElement?.innerHTML || '').matchAll(/\/week\/(\d{4}-\d{2}-\d{2})/g)
                    )
                      .map((m) => m?.[1])
                      .filter(Boolean)
                  ]
                )
              );
              const selectedFromWeekSelect =
                readWeekFromValue(
                  (
                    document.querySelector('select[name="week_id"]') ||
                    document.querySelector('select[name="week"]') ||
                    document.querySelector('select#week_id')
                  )?.value
                );
              const pathWeek = readWeekFromValue(window.location.pathname || '');
              const current =
                pathWeek ||
                selectedFromWeekSelect;
              if (!block) return JSON.stringify({ ok: false, currentWeek: current, nextWeek: next, prevWeek: prev, weekLinks, days: [] });

              const days = Array.from(block.querySelectorAll('div.db_day'));
              const resultDays = [];
              for (const day of days) {
                const table = day.querySelector('table.db_table');
                if (!table) { resultDays.push({ name: '?', lessons: [] }); continue; }
                const dayName = table.querySelector('th.lesson')?.textContent?.trim() ?? '?';
                const rows = Array.from(table.querySelectorAll('tbody tr'));
                const lessons = [];
                for (const tr of rows) {
                  const lessonRaw =
                    tr.querySelector('td.lesson span')?.textContent ??
                    tr.querySelector('td.lesson a')?.textContent ??
                    tr.querySelector('td.lesson')?.textContent ??
                    '';
                  let subject = lessonRaw.replace(/\s+/g, ' ').trim();
                  subject = subject.replace(/^\d+[\.\)]\s*/, '');
                  const hwRaw =
                    tr.querySelector('div.ht-text')?.textContent ??
                    tr.querySelector('td.ht')?.textContent ??
                    null;
                  const hw = hwRaw ? hwRaw.replace(/\s+/g, ' ').trim() : null;
                  const markRaw =
                    tr.querySelector('td.mark strong')?.textContent ??
                    tr.querySelector('td.mark span')?.textContent ??
                    tr.querySelector('td.mark')?.textContent ??
                    null;
                  const normalizedMark = markRaw ? markRaw.replace(/\s+/g, ' ').trim() : null;
                  const mark = (normalizedMark && normalizedMark !== '-' && normalizedMark !== '—') ? normalizedMark : null;

                  const attachments = [];
                  const pushAttachment = (name, href, type) => {
                    const normalizedName = (name || '').replace(/\s+/g, ' ').trim();
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
                  const dedup = [];
                  const seen = new Set();
                  for (const item of attachments) {
                    const key = `${'$'}{item.url}|${'$'}{item.name}`;
                    if (seen.has(key)) continue;
                    seen.add(key);
                    dedup.push(item);
                  }

                  if (!subject && !hw && !mark) continue;
                  lessons.push({ subject, mark, hw, attachments: dedup });
                }
                resultDays.push({ name: dayName, lessons });
              }
              return JSON.stringify({ ok: true, currentWeek: current, nextWeek: next, prevWeek: prev, weekLinks, days: resultDays });
            })()
        """.trimIndent()
    }
}

sealed class SchoolsByWebError(message: String) : Exception(message) {
    data object InvalidCredentials : SchoolsByWebError("Неверный логин или пароль.")
    data object MissingCsrfToken : SchoolsByWebError("Не удалось получить CSRF токен.")
    data object MissingSessionCookie : SchoolsByWebError("Не удалось получить sessionid. Возможно, вход заблокирован.")
    data object MissingPupilId : SchoolsByWebError("Не удалось определить pupilid.")
    data class NavigationFailed(val detail: String) : SchoolsByWebError("Ошибка загрузки страницы: $detail")
    data class JavascriptFailed(val detail: String) : SchoolsByWebError("Ошибка выполнения скрипта: $detail")
    data class ParsingFailed(val detail: String) : SchoolsByWebError("Ошибка парсинга: $detail")
}

private class WebViewRunner(
    context: Context,
    private val json: Json
) {
    private val appContext = context.applicationContext
    private val cookieManager = CookieManager.getInstance().apply { setAcceptCookie(true) }

    private var webView: WebView? = null
    private var navContinuation: Continuation<Unit>? = null
    private val navigationMutex = Mutex()

    @SuppressLint("SetJavaScriptEnabled")
    private suspend fun ensureWebView(): WebView = withContext(Dispatchers.Main.immediate) {
        webView?.let { return@withContext it }
        val wv = WebView(appContext)
        wv.settings.javaScriptEnabled = true
        wv.settings.domStorageEnabled = true
        wv.settings.loadsImagesAutomatically = false
        wv.settings.userAgentString =
            "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36"

        wv.webViewClient = object : WebViewClient() {
            override fun onPageCommitVisible(view: WebView?, url: String?) {
                resumeNavigationSuccess()
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                resumeNavigationSuccess()
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                if (request?.isForMainFrame == true) {
                    resumeNavigationError(
                        SchoolsByWebError.NavigationFailed(error?.description?.toString() ?: "unknown")
                    )
                }
            }

            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
                handler?.cancel()
                resumeNavigationError(SchoolsByWebError.NavigationFailed("ssl error"))
            }
        }

        webView = wv
        wv
    }

    suspend fun load(url: String) {
        // Best-effort retry once for transient issues.
        var last: Throwable? = null
        repeat(2) { attempt ->
            try {
                navigate {
                    it.loadUrl(url)
                }
                return
            } catch (t: Throwable) {
                last = t
                if (attempt == 0) return@repeat
            }
        }
        throw last ?: SchoolsByWebError.NavigationFailed("unknown")
    }

    suspend fun evalAndWaitNavigation(script: String) {
        navigate { wv ->
            wv.evaluateJavascript(script, null)
        }
    }

    suspend fun evalString(script: String): String? {
        val raw = evalRaw(script) ?: return null
        if (raw == "null") return null

        // WebView returns JSON-encoded strings (with quotes).
        return runCatching { json.decodeFromString<String>(raw) }.getOrNull() ?: raw
    }

    suspend fun evalBoolean(script: String): Boolean? {
        val raw = evalRaw(script) ?: return null
        return when (raw) {
            "true" -> true
            "false" -> false
            "null" -> null
            else -> null
        }
    }

    private suspend fun evalRaw(script: String): String? {
        val wv = ensureWebView()
        return withContext(Dispatchers.Main.immediate) {
            suspendCancellableCoroutine { cont ->
                wv.evaluateJavascript(script) { value ->
                    cont.resume(value)
                }
            }
        }
    }

    suspend fun getCookieValue(url: String, cookieName: String): String? {
        val raw = withContext(Dispatchers.Main.immediate) { cookieManager.getCookie(url) } ?: return null
        // "a=b; sessionid=...; c=d"
        return raw.split(";")
            .map { it.trim() }
            .firstOrNull { it.startsWith("$cookieName=") }
            ?.substringAfter("=")
            ?.takeIf { it.isNotBlank() }
    }

    suspend fun ensureSessionCookie(value: String) {
        ensureWebView()
        withContext(Dispatchers.Main.immediate) {
            cookieManager.setCookie(
                "https://schools.by",
                "sessionid=$value; Domain=.schools.by; Path=/; Secure"
            )
            cookieManager.flush()
        }
    }

    suspend fun clearWebsiteData() {
        val wv = ensureWebView()
        withContext(Dispatchers.Main.immediate) {
            suspendCancellableCoroutine { cont ->
                cookieManager.removeAllCookies {
                    cont.resume(Unit)
                }
            }
            cookieManager.flush()
            wv.clearHistory()
            wv.clearCache(true)
        }
    }

    private suspend fun navigate(trigger: (WebView) -> Unit) {
        navigationMutex.withLock {
            val wv = ensureWebView()
            try {
                withTimeout(75_000L) {
                    withContext(Dispatchers.Main.immediate) {
                        suspendCancellableCoroutine<Unit> { cont ->
                            navContinuation = cont
                            trigger(wv)
                        }
                    }
                }
            } catch (t: TimeoutCancellationException) {
                navContinuation = null
                throw SchoolsByWebError.NavigationFailed("timeout")
            }
        }
    }

    private fun resumeNavigationSuccess() {
        val cont = navContinuation ?: return
        navContinuation = null
        cont.resume(Unit)
    }

    private fun resumeNavigationError(error: Throwable) {
        val cont = navContinuation ?: return
        navContinuation = null
        cont.resumeWithException(error)
    }
}
