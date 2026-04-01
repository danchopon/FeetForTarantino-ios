import Foundation
import Observation

@Observable
class WatchlistViewModel {
    enum StatusFilter: String, CaseIterable {
        case all, toWatch, watched

        var label: String {
            switch self {
            case .all: return "All"
            case .toWatch: return "To Watch"
            case .watched: return "Watched"
            }
        }

        var apiValue: String? {
            switch self {
            case .all: return nil
            case .toWatch: return "to_watch"
            case .watched: return "watched"
            }
        }
    }

    var movies: [Movie] = []
    var isLoading = false
    var errorMessage: String?
    var statusFilter: StatusFilter = .toWatch

    private(set) var currentChatId: Int64?
    private let service = MovieService()

    func fetchMovies(chatId: Int64) async {
        currentChatId = chatId
        isLoading = true
        errorMessage = nil

        do {
            movies = try await service.fetchMovies(chatId: chatId, status: statusFilter.apiValue)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func markWatched(_ movie: Movie) async {
        guard let chatId = currentChatId else { return }
        do {
            try await service.markWatched(movieId: movie.id, chatId: chatId)
            movies.removeAll { $0.id == movie.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
