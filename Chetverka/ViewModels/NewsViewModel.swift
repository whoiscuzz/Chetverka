import Foundation
import Combine

@MainActor
final class NewsViewModel: ObservableObject {
    @Published private(set) var items: [NewsItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var hasLoadedOnce = false

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await NewsService.shared.fetchPublished()
            hasLoadedOnce = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func publish(title: String, body: String, authorName: String) async throws {
        let created = try await NewsService.shared.publish(title: title, body: body, authorName: authorName)
        items.insert(created, at: 0)
        hasLoadedOnce = true
    }
}
