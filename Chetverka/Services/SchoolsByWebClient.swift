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

    // Primary host + DNS fallback for unstable school subdomains.
    private let base = URL(string: "https://schools.by")!
    private let fallbackBase = URL(string: "https://4minsk.schools.by")!
    private let loginURL = URL(string: "https://schools.by/login")!
    private let defaultStartWeek = "2026-01-12"
    private let defaultQuarterId = "90"
    private let adminPupilIDs: Set<String> = ["1106490"]

    private let runner: WebViewRunner

    private init() {
        self.runner = WebViewRunner()
    }

    func clearSession() async {
        await runner.clearWebsiteData()
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        // Primary path: direct HTTP login (same strategy as Python script),
        // then inject session cookie into WKWebView.
        let sessionUnwrapped = try await performDirectLogin(username: username, password: password)
        await runner.ensureSessionCookieIfNeeded(value: sessionUnwrapped)

        // Extract pupilid via direct HTTP first (stable), then fallback to WebView DOM.
        let (pupilid, activeBase) = try await resolvePupilId(sessionid: sessionUnwrapped)

        // Scrape profile data from pupil page with fallback host if selectors are empty.
        let profileContext = try await resolveProfilePayload(pupilid: pupilid, preferredBase: activeBase)
        let payload = profileContext.payload

        let (fullNameRaw, className) = Self.parseTitle(payload.title)
        let fullName = fullNameRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ученик" : fullNameRaw
        let profile = Profile(
            fullName: fullName,
            className: className,
            avatarUrl: Self.absoluteURLString(from: payload.avatarUrl, base: profileContext.base),
            classTeacher: payload.classTeacher,
            role: adminPupilIDs.contains(pupilid) ? "admin" : "user"
        )

        return LoginResponse(sessionid: sessionUnwrapped, pupilid: pupilid, profile: profile)
    }

    private func performDirectLogin(username: String, password: String) async throws -> String {
        print("SchoolsByWebClient: --- performDirectLogin START ---")

        var getRequest = URLRequest(url: loginURL)
        getRequest.httpMethod = "GET"
        getRequest.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        getRequest.setValue("ru-RU,ru;q=0.9,en-US;q=0.8", forHTTPHeaderField: "Accept-Language")

        let (getData, getResponse) = try await URLSession.shared.data(for: getRequest)
        guard let getHTTP = getResponse as? HTTPURLResponse, (200...299).contains(getHTTP.statusCode) else {
            print("SchoolsByWebClient: GET login page failed with status \(String(describing: (getResponse as? HTTPURLResponse)?.statusCode))")
            throw SchoolsByError.navigationFailed("login page GET failed")
        }

        let loginHTML = String(data: getData, encoding: .utf8) ?? ""
        print("SchoolsByWebClient: Login page HTML snippet (first 500 chars): \(loginHTML.prefix(500))")

        guard let csrf = Self.firstRegexCapture(
            in: loginHTML,
            pattern: #"name=["']csrfmiddlewaretoken["'][^>]*value=["']([^"']+)["']"#
        ) else {
            print("SchoolsByWebClient: Failed to extract CSRF token from login page.")
            throw SchoolsByError.missingCSRFToken
        }
        print("SchoolsByWebClient: Extracted CSRF token: \(csrf.prefix(10))...")
        let csrfCookie = Self.cookieValue(named: "csrftoken", fromResponse: getHTTP) ?? csrf

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "csrfmiddlewaretoken", value: csrf),
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "function-cookie", value: "on"),
            URLQueryItem(name: "static_cookie", value: "on"),
            URLQueryItem(name: "advertising_cookie", value: "on"),
            URLQueryItem(name: "|123", value: "|123")
        ]

        guard let bodyQuery = components.percentEncodedQuery else {
            print("SchoolsByWebClient: Failed to encode login POST body.")
            throw SchoolsByError.parsingFailed("failed to encode login body")
        }

        var postRequest = URLRequest(url: loginURL)
        postRequest.httpMethod = "POST"
        postRequest.httpBody = Data(bodyQuery.utf8)
        postRequest.httpShouldHandleCookies = true
        postRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        postRequest.setValue("https://schools.by", forHTTPHeaderField: "Origin")
        postRequest.setValue("https://schools.by/login", forHTTPHeaderField: "Referer")
        postRequest.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        postRequest.setValue("ru-RU,ru;q=0.9,en-US;q=0.8", forHTTPHeaderField: "Accept-Language")
        postRequest.setValue(csrf, forHTTPHeaderField: "X-CSRFToken")
        postRequest.setValue(
            "csrftoken=\(csrfCookie); function-cookie=on; static_cookie=on; advertising_cookie=on",
            forHTTPHeaderField: "Cookie"
        )

        let (postData, postResponse) = try await URLSession.shared.data(for: postRequest)
        guard let postHTTP = postResponse as? HTTPURLResponse, (200...399).contains(postHTTP.statusCode) else {
            print("SchoolsByWebClient: POST login failed with status \(String(describing: (postResponse as? HTTPURLResponse)?.statusCode)). Response headers: \(String(describing: (postResponse as? HTTPURLResponse)?.allHeaderFields))")
            throw SchoolsByError.navigationFailed("login POST failed")
        }
        print("SchoolsByWebClient: POST login response headers: \(postHTTP.allHeaderFields)")

        let postHTML = String(data: postData, encoding: .utf8) ?? ""
        if postHTML.contains("Пожалуйста, введите правильные имя пользователя и пароль") {
            print("SchoolsByWebClient: Login POST response indicates invalid credentials.")
            throw SchoolsByError.invalidCredentials
        }

        if let setCookie = postHTTP.value(forHTTPHeaderField: "Set-Cookie"),
           let fromHeader = Self.cookieValue(named: "sessionid", fromSetCookieHeader: setCookie),
           !fromHeader.isEmpty {
            print("SchoolsByWebClient: SessionID found in Set-Cookie header: \(fromHeader.prefix(10))...")
            return fromHeader
        }

        let urlCookieCandidates = [
            URL(string: "https://schools.by"),
            URL(string: "https://4minsk.schools.by"),
            loginURL
        ].compactMap { $0 }
        for cookieURL in urlCookieCandidates {
            let cookies = HTTPCookieStorage.shared.cookies(for: cookieURL) ?? []
            if let sessionCookie = cookies.first(where: { $0.name == "sessionid" && !$0.value.isEmpty }) {
                print("SchoolsByWebClient: SessionID found in HTTPCookieStorage for \(cookieURL.host ?? ""): \(sessionCookie.value.prefix(10))...")
                return sessionCookie.value
            }
        }

        // Some flows set session cookie only after a follow-up authenticated page request.
        if let warmupSession = try await warmupAndReadSessionCookie(csrfCookie: csrfCookie) {
            print("SchoolsByWebClient: SessionID found after warmup: \(warmupSession.prefix(10))...")
            return warmupSession
        }

        // Fallback: try actual WebView form submit if direct URLSession flow was blocked.
        if let webViewSession = try await performWebViewLoginFallback(username: username, password: password) {
            print("SchoolsByWebClient: SessionID found via WebView fallback: \(webViewSession.prefix(10))...")
            return webViewSession
        }

        print("SchoolsByWebClient: No sessionID found after direct login attempts and fallback.")
        throw SchoolsByError.missingSessionCookie
    }

    private func performWebViewLoginFallback(username: String, password: String) async throws -> String? {
        print("SchoolsByWebClient: --- performWebViewLoginFallback START ---")
        try await runner.load(loginURL)
        let usernameB64 = Data(username.utf8).base64EncodedString()
        let passwordB64 = Data(password.utf8).base64EncodedString()

        let jsResult = try await runner.evaluateJS("""
            (() => {
              const u = atob('\(usernameB64)');
              const p = atob('\(passwordB64)');
              const userInput = document.querySelector('input[name="username"], input#id_username');
              const passInput = document.querySelector('input[name="password"], input#id_password, input[type="password"]');
              const form = (userInput && userInput.form) || (passInput && passInput.form) || document.querySelector('form[action="/login"], form[action=""], form');
              if (!userInput || !passInput || !form) return 'NO_FORM';
              userInput.value = u;
              passInput.value = p;
              const submit = form.querySelector('input[type="submit"], button[type="submit"]');
              if (submit) submit.click(); else form.submit();
              return 'OK';
            })()
        """) as String
        print("SchoolsByWebClient: WebView JS evaluation result: \(jsResult)")

        let deadline = Date().addingTimeInterval(12)
        while Date() < deadline {
            if let cookie = await runner.getCookieValue(named: "sessionid", domainContains: "schools.by"),
               !cookie.isEmpty {
                print("SchoolsByWebClient: SessionID found in WebView cookie: \(cookie.prefix(10))...")
                print("SchoolsByWebClient: --- performWebViewLoginFallback END (SUCCESS) ---")
                return cookie
            }
            print("SchoolsByWebClient: Waiting for sessionid in WebView...")
            try await Task.sleep(nanoseconds: 300_000_000)
        }
        print("SchoolsByWebClient: SessionID not found in WebView after timeout.")
        print("SchoolsByWebClient: --- performWebViewLoginFallback END (FAILURE) ---")
        return nil
    }

    private static func firstRegexCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(location: 0, length: (text as NSString).length)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        let valueRange = match.range(at: 1)
        guard valueRange.location != NSNotFound else { return nil }
        return (text as NSString).substring(with: valueRange)
    }

    private static func cookieValue(named name: String, fromSetCookieHeader header: String) -> String? {
        let parts = header.components(separatedBy: ",")
        for part in parts {
            let pairs = part.components(separatedBy: ";")
            for pair in pairs {
                let clean = pair.trimmingCharacters(in: .whitespacesAndNewlines)
                let prefix = "\(name)="
                if clean.hasPrefix(prefix) {
                    return String(clean.dropFirst(prefix.count))
                }
            }
        }
        return nil
    }

    private static func cookieValue(named name: String, fromResponse response: HTTPURLResponse) -> String? {
        for (headerNameRaw, headerValueRaw) in response.allHeaderFields {
            guard let headerName = headerNameRaw as? String,
                  headerName.lowercased() == "set-cookie",
                  let headerValue = headerValueRaw as? String else {
                continue
            }
            if let value = cookieValue(named: name, fromSetCookieHeader: headerValue) {
                return value
            }
        }
        return nil
    }

    private func warmupAndReadSessionCookie(csrfCookie: String) async throws -> String? {
        let warmupURLs = [
            URL(string: "https://schools.by/m/"),
            URL(string: "https://4minsk.schools.by/m/")
        ].compactMap { $0 }

        for url in warmupURLs {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.httpShouldHandleCookies = true
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("ru-RU,ru;q=0.9,en-US;q=0.8", forHTTPHeaderField: "Accept-Language")
            request.setValue(
                "csrftoken=\(csrfCookie); function-cookie=on; static_cookie=on; advertising_cookie=on",
                forHTTPHeaderField: "Cookie"
            )

            _ = try? await URLSession.shared.data(for: request)

            let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
            if let sessionCookie = cookies.first(where: { $0.name == "sessionid" && !$0.value.isEmpty }) {
                return sessionCookie.value
            }
        }
        return nil
    }

    private func resolvePupilId(sessionid: String) async throws -> (String, URL) {
        print("SchoolsByWebClient: resolvePupilId called with sessionid: \(sessionid.prefix(10))...")
        if let fromHTTP = try await fetchPupilIdViaHTTP(sessionid: sessionid) {
            print("SchoolsByWebClient: PupilID resolved via HTTP: \(fromHTTP.0) from host \(fromHTTP.1.host ?? "").")
            return fromHTTP
        }

        let activeBase = try await loadWithHostFallback(path: "/m/")
        let href: String? = try await runner.evaluateJS("""
            (() => {
              const direct = document.querySelector('a.u_name, a.user_name, a.profile-link');
              if (direct) {
                const h = direct.getAttribute('href');
                if (h) return h;
              }
              const allAnchors = Array.from(document.querySelectorAll('a[href]'));
              for (const a of allAnchors) {
                const href = a.getAttribute('href') || '';
                if (/\\/pupil\\/\\d+/.test(href)) return href;
              }
              const html = document.documentElement?.innerHTML || '';
              const match = html.match(/\\/pupil\\/(\\d+)/);
              return match ? match[0] : null;
            })()
        """)
        guard let pupilid = href.flatMap(Self.extractPupilId(fromHref:)), !pupilid.isEmpty else {
            print("SchoolsByWebClient: Failed to resolve PupilID via WebView DOM.")
            throw SchoolsByError.missingPupilId
        }
        print("SchoolsByWebClient: PupilID resolved via WebView DOM: \(pupilid) from host \(activeBase.host ?? "").")
        return (pupilid, activeBase)
    }

    private func fetchPupilIdViaHTTP(sessionid: String) async throws -> (String, URL)? {
        for host in [base, fallbackBase] {
            guard let url = URL(string: "/m/", relativeTo: host)?.absoluteURL else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            request.setValue("sessionid=\(sessionid)", forHTTPHeaderField: "Cookie")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) else {
                continue
            }

            let html = String(data: data, encoding: .utf8) ?? ""
            if let href = Self.firstRegexCapture(in: html, pattern: #"(\/pupil\/\d+[^"']*)"#),
               let pupilid = Self.extractPupilId(fromHref: href), !pupilid.isEmpty {
                return (pupilid, host)
            }
        }
        return nil
    }

    func fetchDiary(pupilid: String, sessionid: String? = nil) async throws -> DiaryResponse {
        print("SchoolsByWebClient: fetchDiary called for pupilid: \(pupilid), sessionid: \(sessionid?.prefix(10) ?? "nil")...")
        if let sessionid {
            await runner.ensureSessionCookieIfNeeded(value: sessionid)
        }

        var activeBase = base
        let diaryContext = try await resolveDiaryContext(pupilid: pupilid, preferredBase: activeBase)
        activeBase = diaryContext.base
        let discoveredWeek = try await discoverStartWeek(
            pupilid: pupilid,
            quarterId: diaryContext.quarterId ?? defaultQuarterId,
            activeBase: diaryContext.base
        )
        let startWeek = diaryContext.weekId ?? discoveredWeek ?? defaultStartWeek
        let quarterId = diaryContext.quarterId ?? defaultQuarterId
        print("SchoolsByWebClient: Using diary context quarterId=\(quarterId), startWeek=\(startWeek), base=\(activeBase.absoluteString)")

        var visited = Set<String>()
        var pendingWeeks: [String] = [startWeek]
        var weeksByMonday: [String: Week] = [:]

        var safetyCounter = 0
        while let w = pendingWeeks.first {
            pendingWeeks.removeFirst()
            if visited.contains(w) {
                continue
            }
            visited.insert(w)
            safetyCounter += 1
            if safetyCounter > 160 {
                print("SchoolsByWebClient: fetchDiary safety counter exceeded for pupilid: \(pupilid). Breaking loop.")
                break
            }

            let url = URL(string: "\(activeBase.absoluteString)/m/pupil/\(pupilid)/dnevnik/quarter/\(quarterId)/week/\(w)")!
            print("SchoolsByWebClient: Fetching diary for week \(w) at URL: \(url.absoluteString)")
            do {
                try await runner.load(url)
            } catch {
                if Self.isHostLookupError(error), activeBase != fallbackBase {
                    print("SchoolsByWebClient: Host lookup error for \(url.absoluteString). Falling back to \(fallbackBase.absoluteString).")
                    activeBase = fallbackBase
                    continue
                }
                print("SchoolsByWebClient: Failed to load diary page \(url.absoluteString) with error: \(error.localizedDescription)")
                throw error
            }

            let js: String = """
                (() => {
                  const block = document.querySelector('div.db_days:not([style])');
                  const next = document.querySelector('a.next')?.getAttribute('next_week_id') ?? null;
                  const prev = document.querySelector('a.prev')?.getAttribute('prev_week_id') ?? null;
                  if (!block) return JSON.stringify({ ok: false, nextWeek: next, prevWeek: prev, days: [] });

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
                      const cabinet = tr.querySelector('span.cabinet')?.textContent?.replace(/\\s+/g, ' ').trim() ?? null;

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

                      if (!subject && !hw && !mark && !cabinet) continue;
                      lessons.push({ subject, mark, hw, cabinet, attachments: dedup });
                    }
                    resultDays.push({ name: dayName, lessons });
                  }
                  return JSON.stringify({ ok: true, nextWeek: next, prevWeek: prev, days: resultDays });
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
                        let cabinet: String?
                        let attachments: [AttachmentPayload]?
                    }
                    let name: String
                    let lessons: [LessonPayload]
                }
                let ok: Bool
                let nextWeek: String?
                let prevWeek: String?
                let days: [DayPayload]
            }

            let payloadJSON: String = try await runner.evaluateJS(js)
            guard let data = payloadJSON.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(WeekPayload.self, from: data)
            else {
                print("SchoolsByWebClient: Failed to decode week payload for week \(w).")
                throw SchoolsByError.parsingFailed("week JSON decode")
            }
            print("SchoolsByWebClient: Diary for week \(w) payload.ok: \(payload.ok). Next week: \(payload.nextWeek ?? "nil"), prev week: \(payload.prevWeek ?? "nil")")

            if !payload.ok {
                // "ok=false" often means wrong quarter/week or changed layout, not necessarily missing session cookie.
                if weeksByMonday.isEmpty {
                    print("SchoolsByWebClient: Diary block missing and no weeks fetched. Throwing parsingFailed with context.")
                    throw SchoolsByError.parsingFailed("Дневник недоступен для quarter=\(quarterId), week=\(w). sessionid получен, но блок дневника не найден.")
                }
                print("SchoolsByWebClient: Diary block missing for week \(w). Continuing with other discovered weeks.")
                continue
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
                    return Lesson(
                        subject: lp.subject,
                        mark: lp.mark,
                        hw: lp.hw,
                        cabinet: lp.cabinet,
                        attachments: attachments.isEmpty ? nil : attachments
                    )
                }
                return Day(date: date, name: d.name, lessons: lessons)
            }
            let resolvedDays = try await resolveAttachmentLinks(in: days, activeBase: activeBase)
            weeksByMonday[w] = Week(monday: w, days: resolvedDays)

            for candidate in [payload.nextWeek, payload.prevWeek].compactMap({ $0 }) {
                if !visited.contains(candidate) && !pendingWeeks.contains(candidate) {
                    pendingWeeks.append(candidate)
                }
            }
        }

        let weeks = weeksByMonday.values.sorted { $0.monday < $1.monday }
        print("SchoolsByWebClient: Successfully fetched \(weeks.count) weeks of diary data.")
        return DiaryResponse(weeks: weeks)
    }

    func fetchQuarterGrades(pupilid: String, sessionid: String? = nil) async throws -> QuarterGradesTable {
        if let sessionid {
            await runner.ensureSessionCookieIfNeeded(value: sessionid)
        }

        var activeBase = try await loadWithHostFallback(path: "/m/pupil/\(pupilid)/dnevnik/last-page")
        var table = try await parseQuarterGradesTable()
        if !table.rows.isEmpty {
            return table
        }

        let diaryContext = try await resolveDiaryContext(pupilid: pupilid, preferredBase: activeBase)
        activeBase = diaryContext.base
        _ = try await loadWithHostFallback(path: "/m/pupil/\(pupilid)/dnevnik", preferredBase: activeBase)
        if let discoveredPath = try await discoverLastPagePathFromCurrentDiaryPage() {
            _ = try await loadWithHostFallback(path: discoveredPath, preferredBase: activeBase)
            table = try await parseQuarterGradesTable()
        }

        return table
    }

    // MARK: - Helpers

    private struct DiaryContext {
        let base: URL
        let quarterId: String?
        let weekId: String?
    }

    private struct ProfilePayload: Decodable {
        let title: String
        let avatarUrl: String?
        let classTeacher: String?
    }

    private struct DiaryPathPayload: Decodable {
        let paths: [String]
    }

    private struct WeekDiscoveryPayload: Decodable {
        let path: String?
        let nextWeek: String?
        let prevWeek: String?
        let weekLinks: [String]
    }

    private func parseQuarterGradesTable() async throws -> QuarterGradesTable {
        let payloadJSON: String = try await runner.evaluateJS("""
            (() => {
              const normalize = (s) => (s || '').replace(/\\s+/g,' ').trim();
              const container =
                document.querySelector('.wrap_lmtables[id^=\"daybook-last-page-container-\"]') ||
                document.querySelector('.wrap_lmtables') ||
                document;

              const leftTable = container.querySelector('table.ltable') || document.querySelector('table.ltable');
              const rightTable = container.querySelector('table.mtable[id^=\"daybook-last-page-table-\"]') ||
                                 container.querySelector('table.mtable') ||
                                 document.querySelector('table.mtable');

              if (leftTable && rightTable) {
                const qCols = Array.from(rightTable.querySelectorAll('thead tr:nth-child(2) td.qdates'))
                  .map(td => normalize(td.textContent))
                  .filter(Boolean);
                const avgLabel = normalize(rightTable.querySelector('thead tr:nth-child(1) td.avg')?.textContent || '');
                const yearLabel = normalize(rightTable.querySelector('thead tr:nth-child(1) td.ymark')?.textContent || '');
                const columns = [...qCols, avgLabel || 'Средняя', yearLabel || 'Годовая'];

                const leftRows = Array.from(leftTable.querySelectorAll('tbody tr'));
                const rightRows = Array.from(rightTable.querySelectorAll('tbody tr'));
                const rowCount = Math.min(leftRows.length, rightRows.length);

                const rows = [];
                for (let i = 0; i < rowCount; i++) {
                  const ltr = leftRows[i];
                  const rtr = rightRows[i];

                  const subjectNode = ltr.querySelector('td.ttl') || ltr.querySelector('td');
                  let subject = normalize(subjectNode ? subjectNode.textContent : '');
                  subject = subject.replace(/^\\d+[\\.)]?\\s*/, '').trim();
                  if (!subject) continue;

                  const gradeCells = Array.from(rtr.querySelectorAll('td'));
                  const grades = gradeCells.map(td => {
                    const value = normalize(td.textContent);
                    return value === '' ? null : value;
                  });

                  const aligned = columns.map((_, idx) => (idx < grades.length ? grades[idx] : null));
                  rows.push({ subject, grades: aligned });
                }

                if (rows.length) return JSON.stringify({ columns, rows });
              }

              // Generic fallback for changed markup.
              const tables = Array.from(document.querySelectorAll('table'));
              let best = null;
              let bestScore = -1;
              for (const table of tables) {
                const rows = Array.from(table.querySelectorAll('tbody tr'));
                if (rows.length < 2) continue;
                let score = 0;
                for (const tr of rows.slice(0, 5)) {
                  const tds = Array.from(tr.querySelectorAll('td'));
                  if (tds.length >= 2) score += 1;
                  const hasGradeLike = tds.slice(1).some(td => /^([1-9]|10|н\\/а|осв|зач|незач|-)?$/i.test(normalize(td.textContent)));
                  if (hasGradeLike) score += 1;
                }
                if (score > bestScore) {
                  bestScore = score;
                  best = table;
                }
              }

              if (!best) return JSON.stringify({ columns: [], rows: [] });

              const headerCells = Array.from(best.querySelectorAll('thead tr:last-child th, thead tr:last-child td'));
              let columns = headerCells.slice(1).map(c => normalize(c.textContent)).filter(Boolean);
              const bodyRows = Array.from(best.querySelectorAll('tbody tr'));
              const rows = [];
              for (const tr of bodyRows) {
                const tds = Array.from(tr.querySelectorAll('td'));
                if (tds.length < 2) continue;
                const subject = normalize(tds[0].textContent).replace(/^\\d+[\\.)]?\\s*/, '').trim();
                if (!subject) continue;
                const grades = tds.slice(1).map(td => {
                  const value = normalize(td.textContent);
                  return value ? value : null;
                });
                rows.push({ subject, grades });
              }

              if (!rows.length) return JSON.stringify({ columns: [], rows: [] });
              const maxLen = rows.reduce((m, r) => Math.max(m, r.grades.length), 0);
              if (!columns.length && maxLen > 0) {
                columns = Array.from({ length: maxLen }, (_, i) => `Q${i + 1}`);
              }

              const normalizedRows = rows.map(r => ({
                subject: r.subject,
                grades: columns.map((_, idx) => (idx < r.grades.length ? r.grades[idx] : null))
              }));

              return JSON.stringify({ columns, rows: normalizedRows });
            })()
        """)

        guard let data = payloadJSON.data(using: .utf8),
              let table = try? JSONDecoder().decode(QuarterGradesTable.self, from: data)
        else {
            throw SchoolsByError.parsingFailed("quarter grades JSON decode")
        }
        return table
    }

    private func discoverLastPagePathFromCurrentDiaryPage() async throws -> String? {
        let path: String? = try await runner.evaluateJS("""
            (() => {
              const candidates = Array.from(document.querySelectorAll('a[href]'))
                .map(a => (a.getAttribute('href') || '').trim())
                .filter(href => href.includes('/dnevnik/') && href.includes('last-page'));
              return candidates.length ? candidates[0] : null;
            })()
        """)
        guard let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return path
    }

    private func resolveProfilePayload(pupilid: String, preferredBase: URL) async throws -> (payload: ProfilePayload, base: URL) {
        let primaryBase = try await loadWithHostFallback(path: "/pupil/\(pupilid)/", preferredBase: preferredBase)
        var primaryPayload = try await readProfilePayloadFromCurrentPage()
        if primaryPayload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _ = try? await loadWithHostFallback(path: "/m/", preferredBase: primaryBase)
            if let fallbackName = try? await readMenuDisplayNameFromCurrentPage(), !fallbackName.isEmpty {
                primaryPayload = ProfilePayload(title: fallbackName, avatarUrl: primaryPayload.avatarUrl, classTeacher: primaryPayload.classTeacher)
            }
        }
        if !primaryPayload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (primaryPayload, primaryBase)
        }

        if primaryBase != fallbackBase {
            do {
                let fallbackResolvedBase = try await loadWithHostFallback(path: "/pupil/\(pupilid)/", preferredBase: fallbackBase)
                var fallbackPayload = try await readProfilePayloadFromCurrentPage()
                if fallbackPayload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    _ = try? await loadWithHostFallback(path: "/m/", preferredBase: fallbackResolvedBase)
                    if let fallbackName = try? await readMenuDisplayNameFromCurrentPage(), !fallbackName.isEmpty {
                        fallbackPayload = ProfilePayload(title: fallbackName, avatarUrl: fallbackPayload.avatarUrl, classTeacher: fallbackPayload.classTeacher)
                    }
                }
                if !fallbackPayload.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return (fallbackPayload, fallbackResolvedBase)
                }
            } catch {
                // Keep primary payload if fallback host is unavailable.
            }
        }

        return (primaryPayload, primaryBase)
    }

    private func readProfilePayloadFromCurrentPage() async throws -> ProfilePayload {
        let profileJSON: String = try await runner.evaluateJS("""
            (() => {
              const normalize = (s) => (s || '').replace(/\\s+/g, ' ').trim();
              const title =
                normalize(document.querySelector('div.title_box h1')?.textContent) ||
                normalize(document.querySelector('h1')?.textContent) ||
                normalize(document.querySelector('a.u_name, a.user_name, a.profile-link')?.textContent) ||
                '';

              const avatar =
                document.querySelector('div.profile-photo__box img')?.getAttribute('src') ||
                document.querySelector('img.profile-photo, img.avatar, img.userpic')?.getAttribute('src') ||
                null;

              let teacher = null;
              const lines = Array.from(document.querySelectorAll('div.pp_line_new'));
              for (const line of lines) {
                const t = line.textContent || '';
                if (t.includes('Классный руководитель:')) {
                  teacher = t.replace('Классный руководитель:', '').trim();
                  break;
                }
              }
              if (!teacher) {
                const body = normalize(document.body?.textContent || '');
                const m = body.match(/Классный\\s+руководитель:\\s*([^\\n\\r]+)/i);
                if (m && m[1]) teacher = normalize(m[1]);
              }
              return JSON.stringify({ title, avatarUrl: avatar, classTeacher: teacher });
            })()
        """)

        guard let payloadData = profileJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ProfilePayload.self, from: payloadData)
        else {
            throw SchoolsByError.parsingFailed("profile JSON decode")
        }
        return payload
    }

    private func readMenuDisplayNameFromCurrentPage() async throws -> String? {
        let title: String? = try await runner.evaluateJS("""
            (() => {
              const normalize = (s) => (s || '').replace(/\\s+/g, ' ').trim();
              return normalize(document.querySelector('a.u_name, a.user_name, a.profile-link')?.textContent) || null;
            })()
        """)
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return title
    }

    private func loadWithHostFallback(path: String, preferredBase: URL? = nil) async throws -> URL {
        let primaryBase = preferredBase ?? base
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        let primaryURL = URL(string: normalizedPath, relativeTo: primaryBase)!.absoluteURL
        do {
            try await runner.load(primaryURL)
            return primaryBase
        } catch {
            if Self.isHostLookupError(error), primaryBase != fallbackBase {
                let fallbackURL = URL(string: normalizedPath, relativeTo: fallbackBase)!.absoluteURL
                try await runner.load(fallbackURL)
                return fallbackBase
            }
            throw error
        }
    }

    private func resolveDiaryContext(pupilid: String, preferredBase: URL) async throws -> DiaryContext {
        let primaryBase = try await loadWithHostFallback(path: "/m/pupil/\(pupilid)/dnevnik", preferredBase: preferredBase)
        let primaryPaths = try await readDiaryPathsFromCurrentPage(pupilid: pupilid)
        let primaryContext = Self.buildDiaryContext(from: primaryPaths, base: primaryBase)
        if primaryContext.quarterId != nil || primaryContext.weekId != nil {
            return primaryContext
        }

        // If schools.by loaded but did not expose diary routing, retry on explicit fallback host.
        if primaryBase != fallbackBase {
            do {
                let fallbackContextBase = try await loadWithHostFallback(
                    path: "/m/pupil/\(pupilid)/dnevnik",
                    preferredBase: fallbackBase
                )
                let fallbackPaths = try await readDiaryPathsFromCurrentPage(pupilid: pupilid)
                let fallbackContext = Self.buildDiaryContext(from: fallbackPaths, base: fallbackContextBase)
                if fallbackContext.quarterId != nil || fallbackContext.weekId != nil {
                    return fallbackContext
                }
            } catch {
                // Keep primary context if fallback host is unreachable.
            }
        }

        return primaryContext
    }

    private func readDiaryPathsFromCurrentPage(pupilid: String) async throws -> [String] {
        let payloadJSON: String = try await runner.evaluateJS("""
            (() => {
              const paths = [];
              const push = (value) => {
                if (!value) return;
                const normalized = String(value).trim();
                if (!normalized) return;
                paths.push(normalized);
              };

              push(window.location.pathname);
              const nextWeekId = document.querySelector('a.next')?.getAttribute('next_week_id');
              if (nextWeekId && /^\\d{4}-\\d{2}-\\d{2}$/.test(nextWeekId)) {
                push(`/m/pupil/\(pupilid)/dnevnik/week/${nextWeekId}`);
              }

              const weekLinks = Array.from(document.querySelectorAll('a[href*="/dnevnik/quarter/"][href*="/week/"]'));
              for (const link of weekLinks) {
                push(link.getAttribute('href'));
              }

              const unique = Array.from(new Set(paths));
              return JSON.stringify({ paths: unique });
            })()
        """)

        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(DiaryPathPayload.self, from: data)
        else {
            return []
        }
        return payload.paths
    }

    private static func buildDiaryContext(from paths: [String], base: URL) -> DiaryContext {
        for path in paths {
            if let parsed = extractQuarterAndWeek(fromDiaryPath: path) {
                return DiaryContext(base: base, quarterId: parsed.quarterId, weekId: parsed.weekId)
            }
        }
        // Quarter pages are often available as /dnevnik/quarter/<id> without explicit /week/<monday>.
        for path in paths {
            if let quarterOnly = extractQuarterOnly(fromDiaryPath: path) {
                return DiaryContext(base: base, quarterId: quarterOnly, weekId: nil)
            }
        }
        return DiaryContext(base: base, quarterId: nil, weekId: nil)
    }

    private static func extractQuarterAndWeek(fromDiaryPath path: String) -> (quarterId: String, weekId: String)? {
        let pattern = #"/dnevnik/quarter/(\d+)/week/(\d{4}-\d{2}-\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(location: 0, length: (path as NSString).length)
        guard let match = regex.firstMatch(in: path, options: [], range: range),
              match.numberOfRanges >= 3,
              let quarterRange = Range(match.range(at: 1), in: path),
              let weekRange = Range(match.range(at: 2), in: path)
        else {
            return nil
        }
        return (quarterId: String(path[quarterRange]), weekId: String(path[weekRange]))
    }

    private static func extractQuarterOnly(fromDiaryPath path: String) -> String? {
        let pattern = #"/dnevnik/quarter/(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(location: 0, length: (path as NSString).length)
        guard let match = regex.firstMatch(in: path, options: [], range: range),
              match.numberOfRanges >= 2,
              let quarterRange = Range(match.range(at: 1), in: path)
        else {
            return nil
        }
        return String(path[quarterRange])
    }

    private static func extractWeekId(fromDiaryPath path: String) -> String? {
        let pattern = #"/week/(\d{4}-\d{2}-\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(location: 0, length: (path as NSString).length)
        guard let match = regex.firstMatch(in: path, options: [], range: range),
              match.numberOfRanges >= 2,
              let weekRange = Range(match.range(at: 1), in: path)
        else {
            return nil
        }
        return String(path[weekRange])
    }

    private func discoverStartWeek(pupilid: String, quarterId: String, activeBase: URL) async throws -> String? {
        let _ = try await loadWithHostFallback(
            path: "/m/pupil/\(pupilid)/dnevnik/quarter/\(quarterId)",
            preferredBase: activeBase
        )

        let payloadJSON: String = try await runner.evaluateJS("""
            (() => {
              const normalize = (s) => (s || '').trim();
              const collectWeeksFromHref = (href) => {
                const value = normalize(href);
                if (!value) return null;
                const match = value.match(/\\/week\\/(\\d{4}-\\d{2}-\\d{2})/);
                return match ? match[1] : null;
              };

              const weekLinks = [];
              const links = Array.from(document.querySelectorAll('a[href*=\"/week/\"]'));
              for (const a of links) {
                const week = collectWeeksFromHref(a.getAttribute('href'));
                if (week) weekLinks.push(week);
              }

              const path = window.location.pathname || null;
              const nextWeek = normalize(document.querySelector('a.next')?.getAttribute('next_week_id')) || null;
              const prevWeek = normalize(document.querySelector('a.prev')?.getAttribute('prev_week_id')) || null;

              return JSON.stringify({ path, nextWeek, prevWeek, weekLinks: Array.from(new Set(weekLinks)) });
            })()
        """)

        guard let data = payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(WeekDiscoveryPayload.self, from: data)
        else {
            return nil
        }

        if let path = payload.path,
           let weekFromPath = Self.extractWeekId(fromDiaryPath: path) {
            return weekFromPath
        }

        if let fromLinks = payload.weekLinks.sorted().first {
            return fromLinks
        }

        if let nextWeek = payload.nextWeek,
           let currentFromNext = Self.addDays(isoDateOrNil: nextWeek, days: -7) {
            return currentFromNext
        }

        if let prevWeek = payload.prevWeek,
           let currentFromPrev = Self.addDays(isoDateOrNil: prevWeek, days: 7) {
            return currentFromPrev
        }

        return nil
    }

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

    private static func addDays(isoDateOrNil: String?, days: Int) -> String? {
        guard let isoDate = isoDateOrNil,
              let date = Self.parseISODate(isoDate),
              let shifted = Calendar(identifier: .gregorian).date(byAdding: .day, value: days, to: date)
        else {
            return nil
        }
        return Self.isoDateString(shifted)
    }

    private static func parseISODate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func isoDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
                    cabinet: lesson.cabinet,
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
    private let navigationTimeoutNs: UInt64 = 30_000_000_000

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

        try await withNavigationTimeout { [self] in
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                self.navigationContinuation = cont
                self.webView.load(request)
            }
        }
    }

    func waitForNextNavigation() async throws {
        if navigationContinuation != nil {
            throw SchoolsByError.navigationFailed("concurrent navigation wait")
        }
        try await withNavigationTimeout { [self] in
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                self.navigationContinuation = cont
            }
        }
    }

    func evaluateJS<T>(_ script: String) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    cont.resume(throwing: SchoolsByError.javascriptFailed(error.localizedDescription))
                    return
                }
                if value is NSNull, let optionalType = T.self as? AnyOptional.Type {
                    cont.resume(returning: optionalType.makeNil() as! T)
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
        print("SchoolsByWebClient: ensureSessionCookieIfNeeded called with value: \(value.prefix(10))...")
        let existing = await getCookieValue(named: "sessionid", domainContains: "schools.by")
        if existing == value {
            print("SchoolsByWebClient: SessionID \(value.prefix(10))... already present and matching in WebView.")
            return
        } else if let existing {
            print("SchoolsByWebClient: Existing sessionID \(existing.prefix(10))... in WebView differs from new value \(value.prefix(10))... . Updating.")
        } else {
            print("SchoolsByWebClient: No existing sessionID found in WebView. Setting new sessionID \(value.prefix(10))...")
        }

        let props: [HTTPCookiePropertyKey: Any] = [
            .name: "sessionid",
            .value: value,
            .domain: ".schools.by",
            .path: "/",
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 30) // Best-effort; real expiry is server-defined.
        ]
        guard let cookie = HTTPCookie(properties: props) else {
            print("SchoolsByWebClient: Failed to create HTTPCookie for sessionID \(value.prefix(10))...")
            return
        }

        let store = webView.configuration.websiteDataStore.httpCookieStore
        await withCheckedContinuation { cont in
            store.setCookie(cookie) {
                print("SchoolsByWebClient: SessionID \(value.prefix(10))... set in WebView cookie store.")
                cont.resume()
            }
        }
    }

    private func withNavigationTimeout<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask { [navigationTimeoutNs] in
                try await Task.sleep(nanoseconds: navigationTimeoutNs)
                throw SchoolsByError.navigationFailed("timeout")
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

extension Optional: AnyOptional {
    fileprivate static func makeNil() -> Any {
        Self.none as Any
    }
}
