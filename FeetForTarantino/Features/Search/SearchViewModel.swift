import Foundation
import Observation

@Observable
class SearchViewModel {
    var results: [Movie] = []
    var query: String = ""
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?

    private var currentPage = 1
    private var totalPages = 1
    private let service = MovieService()

    var canLoadMore: Bool { currentPage < totalPages && !isLoadingMore && !isLoading }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        currentPage = 1
        results = []

        do {
            let response = try await service.search(query: trimmed, page: 1)
            results = response.results
            totalPages = response.totalPages
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadNextPageIfNeeded(currentItem: Movie) async {
        guard canLoadMore, currentItem.id == results.last?.id else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1

        do {
            let response = try await service.search(query: query, page: nextPage)
            results.append(contentsOf: response.results)
            currentPage = nextPage
        } catch {
            // Silently fail — user can scroll back to retry
        }

        isLoadingMore = false
    }
}
