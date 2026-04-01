import Foundation
import Observation

@Observable
class RecommendationsViewModel {
    var recommendation: Recommendation?
    var query: String = ""
    var isLoading = false
    var errorMessage: String?
    var addedIds: Set<Int> = []
    var addingIds: Set<Int> = []
    var addErrorMessage: String?

    private let service = MovieService()

    func fetchRecommendations(chatId: Int64) async {
        isLoading = true
        errorMessage = nil
        recommendation = nil

        do {
            recommendation = try await service.fetchRecommendations(chatId: chatId, query: query)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func addToWatchlist(_ suggestion: Suggestion, chatId: Int64) async {
        addingIds.insert(suggestion.id)
        addErrorMessage = nil
        let movie = Movie(
            title: suggestion.title,
            tmdbId: suggestion.tmdbId,
            year: suggestion.year.flatMap { Int($0) },
            rating: suggestion.rating,
            posterPath: suggestion.posterPath
        )
        do {
            try await service.addMovie(chatId: chatId, movie: movie)
            addedIds.insert(suggestion.id)
        } catch {
            addErrorMessage = error.localizedDescription
        }
        addingIds.remove(suggestion.id)
    }
}
