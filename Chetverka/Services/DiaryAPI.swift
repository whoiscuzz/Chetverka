import Foundation

enum DiaryLoadError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noData
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный URL-адрес."
        case .networkError(let error):
            return "Ошибка сети: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "Сервер ответил с ошибкой: \(statusCode)."
        case .decodingError:
            return "Не удалось разобрать данные от сервера."
        case .noData:
            return "Сервер не вернул данные."
        case .apiError(let detail):
            return detail
        }
    }
}

struct DiaryAPI {

    func loadDiary(sessionid: String, pupilid: String, completion: @escaping (Result<DiaryResponse, DiaryLoadError>) -> Void) {
        // sessionid kept for backward compatibility (cache keys / app flow).
        // Actual requests are made from the device to schools.by via WKWebView.
        Task { @MainActor in
            do {
                let response = try await SchoolsByWebClient.shared.fetchDiary(pupilid: pupilid, sessionid: sessionid)
                completion(.success(response))
            } catch {
                completion(.failure(.apiError((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)))
            }
        }
    }
}
