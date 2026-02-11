import SwiftUI

struct NewsDetailView: View {
    let item: NewsItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(item.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let author = item.authorName, !author.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Text(item.body)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle("Новость")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        NewsDetailView(
            item: NewsItem(
                id: 1,
                title: "Изменение расписания",
                body: "Полный текст новости. Здесь может быть длинное объявление, подробности и важные даты.",
                createdAt: "2026-02-11T15:00:00Z",
                isPublished: true,
                authorName: "Администрация"
            )
        )
    }
}
