import Foundation

enum NewsServiceError: Error, LocalizedError {
    case missingConfig
    case invalidResponse
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingConfig:
            return "Не настроен News API. Добавь NEWS_API_BASE_URL и NEWS_API_KEY в Info.plist."
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

    private var baseURL: String? {
        Bundle.main.object(forInfoDictionaryKey: "NEWS_API_BASE_URL") as? String
    }

    private var apiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "NEWS_API_KEY") as? String
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
            throw NewsServiceError.server(status: http.statusCode, message: body)
        }

        let decoder = JSONDecoder()
        return try decoder.decode([NewsItem].self, from: data)
    }

    func publish(title: String, body: String, authorName: String) async throws -> NewsItem {
        guard let request = try makePublishRequest(title: title, body: body, authorName: authorName) else {
            throw NewsServiceError.missingConfig
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NewsServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
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

    private func makePublishRequest(title: String, body: String, authorName: String) throws -> URLRequest? {
        guard let baseURL, let apiKey else { return nil }
        guard let url = URL(string: "\(baseURL)/rest/v1/news") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = CreateNewsPayload(
            title: title,
            body: body,
            isPublished: true,
            authorName: authorName
        )
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }
}
