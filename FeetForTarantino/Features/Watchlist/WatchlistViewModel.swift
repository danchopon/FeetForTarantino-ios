import Foundation
import Observation

@Observable
class WatchlistViewModel {
    var movies: [Movie] = []
    var isLoading = false
    var errorMessage: String?

    private let service = MovieService()

    func fetchMovies(chatId: Int64) async {
        isLoading = true
        errorMessage = nil

        do {
            movies = try await service.fetchMovies(chatId: chatId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
