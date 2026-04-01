import Foundation
import Observation

@Observable
class WatchlistViewModel {
    var movies: [Movie] = []
    var isLoading = false
    var errorMessage: String?
    var chatIdInput: String = ""

    private let service = MovieService()

    func fetchMovies() async {
        guard let chatId = Int64(chatIdInput) else {
            errorMessage = "Invalid chat ID"
            return
        }

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
