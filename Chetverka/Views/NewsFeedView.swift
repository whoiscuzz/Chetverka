import SwiftUI

struct NewsFeedView: View {
    @EnvironmentObject private var newsViewModel: NewsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if newsViewModel.items.isEmpty {
                    if let error = newsViewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Не удалось загрузить новости")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Повторить") {
                                Task { await newsViewModel.reload() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(16)
                    } else if newsViewModel.isLoading {
                        PlaceholderCard(text: "Загружаем новости...", icon: "dot.radiowaves.left.and.right")
                    } else {
                        PlaceholderCard(text: "Пока новостей нет.", icon: "newspaper")
                    }
                } else {
                    ForEach(newsViewModel.items) { item in
                        NavigationLink {
                            NewsDetailView(item: item)
                        } label: {
                            NewsCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Новости")
        .refreshable {
            await newsViewModel.reload()
        }
        .task {
            await newsViewModel.loadIfNeeded()
        }
    }
}

#Preview {
    NavigationView {
        NewsFeedView()
            .environmentObject(NewsViewModel())
    }
}
