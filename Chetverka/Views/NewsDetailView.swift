import SwiftUI

struct NewsDetailView: View {
    let item: NewsItem

    private var validImageURL: URL? {
        guard let raw = item.imageURL, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

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

                if let validImageURL {
                    AsyncImage(url: validImageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            ZStack {
                                Color.secondary.opacity(0.15)
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

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
                authorName: "fimacuzz",
                imageURL: "https://images.unsplash.com/photo-1509062522246-3755977927d7"
            )
        )
    }
}
