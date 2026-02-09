import SwiftUI

struct DayCard: View {
    let day: Day

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(day.name)
                .font(.headline)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1)) // Цветной фон для хедера

            VStack(spacing: 12) {
                ForEach(day.lessons) { lesson in
                    LessonRow(lesson: lesson)
                    if lesson.id != day.lessons.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
}

