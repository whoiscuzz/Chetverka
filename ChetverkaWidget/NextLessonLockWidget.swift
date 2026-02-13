import WidgetKit
import SwiftUI

private struct NextLessonWidgetPayload: Codable {
    let lessonTitle: String
    let lessonDate: String
    let cabinet: String
    let updatedAt: Date
}

private struct NextLessonWidgetEntry: TimelineEntry {
    let date: Date
    let lessonTitle: String
    let lessonDate: String
    let cabinet: String
}

private struct NextLessonProvider: TimelineProvider {
    private let appGroupID = "group.school.Chetverka"
    private let key = "lock_widget_next_lesson"

    func placeholder(in context: Context) -> NextLessonWidgetEntry {
        NextLessonWidgetEntry(
            date: .now,
            lessonTitle: "Математика",
            lessonDate: "сегодня",
            cabinet: "каб. 322"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextLessonWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextLessonWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry() -> NextLessonWidgetEntry {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: key),
              let payload = try? JSONDecoder().decode(NextLessonWidgetPayload.self, from: data) else {
            return NextLessonWidgetEntry(
                date: .now,
                lessonTitle: "Нет данных",
                lessonDate: "Открой приложение",
                cabinet: "Не указан"
            )
        }

        return NextLessonWidgetEntry(
            date: payload.updatedAt,
            lessonTitle: payload.lessonTitle,
            lessonDate: payload.lessonDate,
            cabinet: payload.cabinet
        )
    }
}

private struct NextLessonLockView: View {
    var entry: NextLessonProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.lessonTitle)
                .font(.caption)
                .bold()
                .lineLimit(1)

            Text("\(entry.lessonDate) · \(entry.cabinet)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}

struct NextLessonLockWidget: Widget {
    private let kind = "NextLessonLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextLessonProvider()) { entry in
            NextLessonLockView(entry: entry)
        }
        .configurationDisplayName("Следующий урок")
        .description("Кабинет и ближайший урок на экране блокировки.")
        .supportedFamilies([.accessoryRectangular])
    }
}
