import SwiftUI

struct LessonRow: View {
    let lesson: Lesson

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            Image(systemName: Lesson.icon(for: lesson.safeSubject))
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 25, alignment: .center)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(lesson.subject)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    if let mark = lesson.markInt {
                        MarkBadge(mark: mark)
                    }
                }

                if let hw = lesson.hw, !hw.isEmpty {
                    Text(hw)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }


}

