import Foundation
import WidgetKit

struct NextLessonWidgetPayload: Codable {
    let lessonTitle: String
    let cabinet: String
    let updatedAt: Date
}

enum NextLessonWidgetStore {
    static let appGroupID = "group.school.Chetverka"
    private static let key = "lock_widget_next_lesson"

    static func save(lessonTitle: String, cabinet: String) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let payload = NextLessonWidgetPayload(
            lessonTitle: lessonTitle,
            cabinet: cabinet,
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "NextLessonLockWidget")
    }
}
