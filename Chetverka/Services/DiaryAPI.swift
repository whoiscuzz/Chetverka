//
//  DiaryAPI.swift
//  Chetverka
//
//  Created by whoiscuzz on 25.01.26.
//

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
    
    private let baseURL = "http://192.168.0.113:8000"

    func loadDiary(sessionid: String, pupilid: String, completion: @escaping (Result<DiaryResponse, DiaryLoadError>) -> Void) {
        
        guard var urlComponents = URLComponents(string: "\(baseURL)/parse") else {
            completion(.failure(.invalidURL))
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "sessionid", value: sessionid),
            URLQueryItem(name: "pupilid", value: pupilid)
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.noData)) // Or a more specific error
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Попробуем декодировать ошибку от FastAPI
                if let data = data, let apiError = try? JSONDecoder().decode(ApiError.self, from: data) {
                    completion(.failure(.apiError(apiError.detail)))
                } else {
                    completion(.failure(.httpError(statusCode: httpResponse.statusCode)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let diaryResponse = try JSONDecoder().decode(DiaryResponse.self, from: data)
                completion(.success(diaryResponse))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
}