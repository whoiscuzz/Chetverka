import SwiftUI

struct LessonRow: View {
    let lesson: Lesson

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            Image(systemName: icon(for: lesson.safeSubject))
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

    /// Определяет иконку для предмета по его названию
    private func icon(for subject: String) -> String {
        switch subject {
        case _ where subject.contains("математика"):
            return "function"
        case _ where subject.contains("алгебра"):
            return "x.squareroot"
        case _ where subject.contains("геометрия"):
            return "triangle.fill"
        case _ where subject.contains("литература"):
            return "book.fill"
        case _ where subject.contains("русский"):
            return "textformat.abc"
        case _ where subject.contains("белорусский"):
            return "textformat.abc.dotted"
        case _ where subject.contains("иностранный"),
             _ where subject.contains("английский"):
            return "globe"
        case _ where subject.contains("физика"):
            return "atom"
        case _ where subject.contains("химия"):
            return "testtube.2"
        case _ where subject.contains("биология"):
            return "leaf.fill"
        case _ where subject.contains("география"):
            return "map.fill"
        case _ where subject.contains("история"):
            return "scroll.fill"
        case _ where subject.contains("обществоведение"):
            return "person.2.fill"
        case _ where subject.contains("информатика"):
            return "desktopcomputer"
        case _ where subject.contains("физкультура"),
             _ where subject.contains("физическая культура"):
            return "figure.walk"
        case _ where subject.contains("труд"),
             _ where subject.contains("трудовое"):
            return "wrench.and.screwdriver.fill"
        case _ where subject.contains("музыка"):
            return "music.note"
        case _ where subject.contains("изо"),
             _ where subject.contains("искусство"):
            return "paintpalette.fill"
        default:
            return "book.closed.fill"
        }
    }
}

