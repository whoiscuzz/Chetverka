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
        let sessionCleared = KeychainService.shared.delete(key: "sessionid")
        let pupilCleared = KeychainService.shared.delete(key: "pupilid")

        UserDefaults.standard.removeObject(forKey: "userProfile")

        if let pupilid = KeychainService.shared.load(key: "pupilid") {

             let cache = DiaryCache()

        }

        print("Logged out. Keychain cleared: \(sessionCleared && pupilCleared)")


        NotificationCenter.default.post(name: .didLogout, object: nil)
    }
}
