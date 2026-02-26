import Foundation

struct NewsItem: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let body: String
    let createdAt: String
    let isPublished: Bool?
    let authorName: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case body
        case createdAt = "created_at"
        case isPublished = "is_published"
        case authorName = "author_name"
        case imageURL = "image_url"
    }

    var date: Date? {
        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatterWithFraction.date(from: createdAt) {
            return d
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }

    var formattedDate: String {
        guard let date else { return createdAt }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CreateNewsPayload: Encodable {
    let title: String
    let body: String
    let isPublished: Bool
    let authorName: String
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case body
        case isPublished = "is_published"
        case authorName = "author_name"
        case imageURL = "image_url"
    }
}
