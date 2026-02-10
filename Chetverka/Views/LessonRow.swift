import SwiftUI

struct LessonRow: View {
    let lesson: Lesson
    @Environment(\.openURL) private var openURL

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

                if let attachments = lesson.attachments, !attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(attachments.prefix(3))) { attachment in
                            attachmentRow(attachment)
                        }

                        if attachments.count > 3 {
                            Text("+ еще \(attachments.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func attachmentRow(_ attachment: LessonAttachment) -> some View {
        let title = attachment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Файл" : attachment.name
        if let raw = attachment.url, let url = URL(string: raw) {
            Button {
                openURL(url)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "paperclip")
                    Text(title)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "paperclip")
                Text(title)
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

}
