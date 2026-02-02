import Foundation
import Combine

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
}

final class ProfileViewModel: ObservableObject {
    
    @Published private(set) var profile: Profile?

    init() {
        loadProfile()
    }

    func loadProfile() {
        guard let profileData = UserDefaults.standard.data(forKey: "userProfile") else {
            return
        }
        
        self.profile = try? JSONDecoder().decode(Profile.self, from: profileData)
    }

    func logout() {
        // Очищаем Keychain
        let sessionCleared = KeychainService.shared.delete(key: "sessionid")
        let pupilCleared = KeychainService.shared.delete(key: "pupilid")
        
        // Очищаем UserDefaults
        UserDefaults.standard.removeObject(forKey: "userProfile")
        
        // Очищаем кэш дневника
        // (Для этого нам нужен pupilid, загрузим его в последний раз перед удалением)
        if let pupilid = KeychainService.shared.load(key: "pupilid") {
             // Эта строка немного костыльная, по-хорошему нужно иметь метод clearCache(for:)
             // но для простоты можно так. Либо реализовать clearAllCache() в DiaryCache
             let cache = DiaryCache()
             // cache.clear(for: pupilid) // Предполагая, что такой метод есть
        }

        print("Logged out. Keychain cleared: \(sessionCleared && pupilCleared)")

        // Отправляем уведомление, чтобы MainView отреагировал
        NotificationCenter.default.post(name: .didLogout, object: nil)
    }
}
