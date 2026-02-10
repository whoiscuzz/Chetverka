import Foundation

struct Profile: Codable, Identifiable {
    var id: String { fullName }
    let fullName: String
    let className: String?
    let avatarUrl: String?
    let classTeacher: String?
    let role: String?

    var isAdmin: Bool {
        role?.lowercased() == "admin"
    }
}

struct LoginResponse: Codable {
    let sessionid: String
    let pupilid: String
    let profile: Profile
}
