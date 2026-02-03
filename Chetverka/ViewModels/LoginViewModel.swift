import Foundation
import Combine

final class LoginViewModel: ObservableObject {

    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var isAuthenticated = false

    private var cancellables = Set<AnyCancellable>()

    private let loginURL = URL(string: "http://192.168.0.113:8000/login")!

    func login() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Логин и пароль не могут быть пустыми."
            return
        }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "username": username,
            "password": password
        ]

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            errorMessage = "Не удалось подготовить данные для отправки."
            isLoading = false
            return
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    self?.errorMessage = "Ошибка сети: \(error.localizedDescription)"
                case .finished:
                    break
                }
            } receiveValue: { [weak self] data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.errorMessage = "Неверный ответ от сервера."
                    return
                }

                if (200...299).contains(httpResponse.statusCode) {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    
                    guard let response = try? decoder.decode(LoginResponse.self, from: data) else {
                        self?.errorMessage = "Не удалось разобрать ответ от сервера."
                        return
                    }
                    
                    // Сохраняем ID в Keychain
                    let sessionSaved = KeychainService.shared.save(key: "sessionid", value: response.sessionid)
                    let pupilSaved = KeychainService.shared.save(key: "pupilid", value: response.pupilid)
                    
                    // Сохраняем профиль в UserDefaults
                    var profileSaved = false
                    if let profileData = try? JSONEncoder().encode(response.profile) {
                        UserDefaults.standard.set(profileData, forKey: "userProfile")
                        profileSaved = true
                    }
                    
                    if sessionSaved && pupilSaved && profileSaved {
                        self?.isAuthenticated = true
                    } else {
                        self?.errorMessage = "Не удалось сохранить все данные сессии."
                    }
                    
                } else {
                    // Ошибка входа (например, 401)
                    self?.errorMessage = "Неверный логин или пароль."
                }
            }
            .store(in: &cancellables)
    }
}
