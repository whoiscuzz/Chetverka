package by.schools.chetverka.data.schoolsby

import android.annotation.SuppressLint
import android.content.Context
import android.net.http.SslError
import android.webkit.SslErrorHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import by.schools.chetverka.data.api.DayDto
import by.schools.chetverka.data.api.DiaryResponse
import by.schools.chetverka.data.api.LessonDto
import by.schools.chetverka.data.api.LoginResponse
import by.schools.chetverka.data.api.ProfileDto
import by.schools.chetverka.data.api.WeekDto
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.Serializable
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class SchoolsByWebClient(appContext: Context) {

    private val context = appContext.applicationContext

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val base = "https://4minsk.schools.by"
    private val loginUrl = "https://schools.by/login"
    private val startWeek = "2026-01-12"
    private val quarterId = "90"

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

        runner.load("$base/m/")
        val href = runner.evalString(
            """
            (() => {
              const a = document.querySelector('a.u_name');
              return a ? a.getAttribute('href') : null;
            })()
            """.trimIndent()
        )
        val pupilId = href?.let(::extractPupilId)
        if (pupilId.isNullOrBlank()) throw SchoolsByWebError.MissingPupilId

        runner.load("$base/pupil/$pupilId/")
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

        val visited = mutableSetOf<String>()
        var week: String? = startWeek
        val weeks = mutableListOf<WeekDto>()

        var safetyCounter = 0
        while (week != null && !visited.contains(week)) {
            val currentWeek = week ?: break
            visited += currentWeek
            safetyCounter += 1
            if (safetyCounter > 80) break

            val url = "$base/m/pupil/$pupilId/dnevnik/quarter/$quarterId/week/$currentWeek"
            runner.load(url)
            val payloadJson = runner.evalString(DIARY_WEEK_JS)
            if (payloadJson.isNullOrBlank()) throw SchoolsByWebError.ParsingFailed("week payload")

            val payload = runCatching {
                json.decodeFromString<WeekPayload>(payloadJson)
            }.getOrElse { throw SchoolsByWebError.ParsingFailed("week JSON decode") }

            if (!payload.ok) {
                if (weeks.isEmpty()) throw SchoolsByWebError.MissingSessionCookie
                break
            }

            val days = payload.days.mapIndexed { index, d ->
                DayDto(
                    date = addDays(currentWeek, index),
                    name = d.name,
                    lessons = d.lessons.map { lp ->
                        LessonDto(subject = lp.subject, mark = lp.mark, hw = lp.hw)
                    }
                )
            }

            weeks += WeekDto(monday = currentWeek, days = days)
            week = payload.nextWeek
        }

        return DiaryResponse(weeks = weeks)
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

    @Serializable
    private data class ProfilePayload(
        val title: String,
        val avatarUrl: String? = null,
        val classTeacher: String? = null
    )

    @Serializable
    private data class WeekPayload(
        val ok: Boolean,
        val nextWeek: String? = null,
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
                val hw: String? = null
            )
        }
    }

    private companion object {
        // Returns JSON.stringify({ok,nextWeek,days:[{name,lessons:[{subject,mark,hw}]}]})
        private val DIARY_WEEK_JS = """
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
                  let subject = lessonRaw.replace(/\s+/g, ' ').trim();
                  subject = subject.replace(/^\d+[\.\)]\s*/, '');
                  const hw = tr.querySelector('div.ht-text')?.textContent?.replace(/\s+/g, ' ').trim() ?? null;
                  const mark = tr.querySelector('td.mark strong')?.textContent?.trim() ?? null;
                  if (!subject && !hw && !mark) continue;
                  lessons.push({ subject, mark, hw });
                }
                resultDays.push({ name: dayName, lessons });
              }
              return JSON.stringify({ ok: true, nextWeek: next, days: resultDays });
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
            override fun onPageFinished(view: WebView?, url: String?) {
                navContinuation?.resume(Unit)
                navContinuation = null
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                navContinuation?.resumeWithException(
                    SchoolsByWebError.NavigationFailed(error?.description?.toString() ?: "unknown")
                )
                navContinuation = null
            }

            override fun onReceivedSslError(view: WebView?, handler: SslErrorHandler?, error: SslError?) {
                handler?.cancel()
                navContinuation?.resumeWithException(SchoolsByWebError.NavigationFailed("ssl error"))
                navContinuation = null
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
        val wv = ensureWebView()
        withContext(Dispatchers.Main.immediate) {
            if (navContinuation != null) throw SchoolsByWebError.NavigationFailed("concurrent navigation")
        }

        try {
            withTimeout(35_000L) {
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
