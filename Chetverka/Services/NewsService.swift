import Foundation

enum NewsServiceError: Error, LocalizedError {
    case missingConfig
    case missingAdminCredentials
    case invalidAdminCredentials
    case blockedByRLS
    case invalidResponse
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "Не настроен News API. Добавь NEWS_API_BASE_URL и NEWS_API_KEY в Info.plist."
        case .missingAdminCredentials:
            return "Не настроены ADMIN_EMAIL и ADMIN_PASSWORD для скрытой публикации."
        case .invalidAdminCredentials:
            return "Неверные admin-логин/пароль для публикации."
        case .blockedByRLS:
            return "Публикация заблокирована политикой Supabase (RLS). Добавь своего пользователя в admin_users."
        case .invalidResponse:
            return "Некорректный ответ сервера новостей."
        case .server(let status, let message):
            return "Ошибка сервера (\(status)): \(message)"
        }
    }
}

struct NewsService {
    static let shared = NewsService()

    private let session: URLSession = .shared
    private let fallbackBaseURL = "https://cfxymbnlgfbpgxsysrah.supabase.co"
    private let fallbackApiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmeHltYm5sZ2ZicGd4c3lzcmFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA3NTMxOTQsImV4cCI6MjA4NjMyOTE5NH0.T8pk05YEcFbpgh5sR2gMKW8ek0qWKL84rekvOgxwbFo"
    private let fallbackAdminEmail = "qwen123dmf@pm.me"
    private let fallbackAdminPassword = "g9U2Q7$kUhCDp7xmCbcRVw#px!r"

    private var baseURL: String? {
        configValue(for: ["NEWS_API_BASE_URL", "INFOPLIST_KEY_NEWS_API_BASE_URL"]) ?? fallbackBaseURL
    }

    private var apiKey: String? {
        configValue(for: ["NEWS_API_KEY", "INFOPLIST_KEY_NEWS_API_KEY"]) ?? fallbackApiKey
    }

    private var adminEmail: String? {
        configValue(for: ["ADMIN_EMAIL", "INFOPLIST_KEY_ADMIN_EMAIL"]) ?? fallbackAdminEmail
    }

    private var adminPassword: String? {
        configValue(for: ["ADMIN_PASSWORD", "INFOPLIST_KEY_ADMIN_PASSWORD"]) ?? fallbackAdminPassword
    }

    func fetchPublished() async throws -> [NewsItem] {
        guard let request = makeFetchRequest() else {
            throw NewsServiceError.missingConfig
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NewsServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            if body.lowercased().contains("row-level security policy") {
                throw NewsServiceError.blockedByRLS
            }
            throw NewsServiceError.server(status: http.statusCode, message: body)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([NewsItem].self, from: data)
    }

    func publish(title: String, body: String, authorName: String) async throws -> NewsItem {
        guard let request = try await makePublishRequest(title: title, body: body, authorName: authorName) else {
            throw NewsServiceError.missingConfig
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NewsServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            if body.lowercased().contains("invalid_credentials") {
                throw NewsServiceError.invalidAdminCredentials
            }
            throw NewsServiceError.server(status: http.statusCode, message: body)
        }

        let decoder = JSONDecoder()
        // Supabase with Prefer:return=representation returns array.
        if let items = try? decoder.decode([NewsItem].self, from: data), let first = items.first {
            return first
        }
        if let item = try? decoder.decode(NewsItem.self, from: data) {
            return item
        }
        throw NewsServiceError.invalidResponse
    }

    private func makeFetchRequest() -> URLRequest? {
        guard let baseURL, let apiKey else { return nil }
        guard var components = URLComponents(string: "\(baseURL)/rest/v1/news") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,title,body,created_at,is_published,author_name"),
            URLQueryItem(name: "is_published", value: "eq.true"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func makePublishRequest(title: String, body: String, authorName: String) async throws -> URLRequest? {
        guard let baseURL, let apiKey else { return nil }
        guard let accessToken = try await fetchAdminAccessToken(baseURL: baseURL, apiKey: apiKey) else {
            throw NewsServiceError.missingAdminCredentials
        }
        guard let url = URL(string: "\(baseURL)/rest/v1/news") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let payload = CreateNewsPayload(
            title: title,
            body: body,
            isPublished: true,
            authorName: authorName
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func fetchAdminAccessToken(baseURL: String, apiKey: String) async throws -> String? {
        guard let email = adminEmail, let password = adminPassword else {
            return nil
        }

        guard let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")

        let payload = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NewsServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            if body.lowercased().contains("invalid_credentials") {
                throw NewsServiceError.invalidAdminCredentials
            }
            throw NewsServiceError.server(status: http.statusCode, message: body)
        }
        struct AuthPayload: Decodable { let access_token: String }
        return try JSONDecoder().decode(AuthPayload.self, from: data).access_token
    }

    private func configValue(for keys: [String]) -> String? {
        for key in keys {
            if let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                let cleaned = raw
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }
        return nil
    }
}
