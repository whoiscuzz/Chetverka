import Foundation
import Combine
 
final class LoginViewModel: ObservableObject {

    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var isAuthenticated = false

    func login() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Логин и пароль не могут быть пустыми."
            return
        }

        isLoading = true
        errorMessage = nil

        let u = username
        let p = password

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isLoading = false }

            do {
                let response = try await SchoolsByWebClient.shared.login(username: u, password: p)

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
                    self.isAuthenticated = true
                } else {
                    self.errorMessage = "Не удалось сохранить все данные сессии."
                }
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
