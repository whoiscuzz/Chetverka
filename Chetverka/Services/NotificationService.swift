import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func scheduleHomeworkNotifications(for weeks: [Week]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let now = Date()
        let calendar = Calendar.current

        for week in weeks {
            for day in week.days {
                // Ensure the day's date can be parsed
                guard let lessonDate = day.date.toDate(withFormat: "yyyy-MM-dd") else { continue }

                for lesson in day.lessons {
                    guard let hw = lesson.hw, !hw.isEmpty else { continue }

                    // Assuming lessons are at a fixed time for notification purposes,
                    // or we can just use the start of the day.
                    // For simplicity, let's schedule for 9 AM on the day before the lesson.
                    guard let notificationDate = calendar.date(byAdding: .day, value: -1, to: lessonDate) else { continue }
                    
                    // Only schedule if notification date is in the future
                    if notificationDate > now {
                        let content = UNMutableNotificationContent()
                        content.title = "Напоминание о домашнем задании"
                        content.body = """
                            Предмет: \(lesson.subject)
                            Домашнее задание: \(hw)
                            """
                        content.sound = .default

                        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

                        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request) { error in
                            if let error = error {
                                print("Error scheduling notification: \(error.localizedDescription)")
                            } else {
                                print("Scheduled homework notification for \(lesson.subject) on \(notificationDate)")
                            }
                        }
                    }
                }
            }
        }
    }
}

// Extension to convert String to Date, assuming you have a utility for this or need one.
// If you already have a similar extension, this can be removed.
extension String {
    func toDate(withFormat format: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        dateFormatter.locale = Locale(identifier: "ru_RU")
        return dateFormatter.date(from: self)
    }
}
