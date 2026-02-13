import Foundation

struct NextLessonWidgetPayload: Codable {
    let lessonTitle: String
    let lessonDate: String
    let cabinet: String
    let updatedAt: Date
}

enum NextLessonWidgetStore {
    static let appGroupID = "group.school.Chetverka"
    private static let key = "lock_widget_next_lesson"

    static func save(lessonTitle: String, lessonDate: String, cabinet: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let payload = NextLessonWidgetPayload(
            lessonTitle: lessonTitle,
            lessonDate: lessonDate,
            cabinet: cabinet,
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
    }
}
