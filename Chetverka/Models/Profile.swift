import Foundation

struct Profile: Codable, Identifiable {
    var id: String { fullName } // Assuming fullName is unique enough for Identifiable
    let fullName: String
    let className: String?
    let avatarUrl: String?
    let classTeacher: String?
}

// MARK: - Wrapper for the entire login response
struct LoginResponse: Codable {
    let sessionid: String
    let pupilid: String
    let profile: Profile
}
