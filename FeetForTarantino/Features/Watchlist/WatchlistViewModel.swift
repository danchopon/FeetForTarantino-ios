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
    var stats: Stats?
    var isLoading = false
    var errorMessage: String?
    var statusFilter: StatusFilter = .toWatch

    private(set) var currentChatId: Int64?
    private var currentSessionToken: String = ""
    private var currentUserName: String = "iOS"

    private var service: MovieService { MovieService(sessionToken: currentSessionToken) }

    func fetchMovies(chatId: Int64, sessionToken: String, userName: String) async {
        currentChatId = chatId
        currentSessionToken = sessionToken
        currentUserName = userName
        isLoading = true
        errorMessage = nil

        async let moviesResult = service.fetchMovies(chatId: chatId, status: statusFilter.apiValue)
        async let statsResult = service.fetchStats(chatId: chatId)

        do {
            movies = try await moviesResult
        } catch {
            errorMessage = error.localizedDescription
        }
        stats = try? await statsResult

        isLoading = false
    }

    func markWatched(_ movie: Movie) async {
        guard let chatId = currentChatId else { return }
        do {
            try await service.markWatched(movieId: movie.id, chatId: chatId, watchedBy: currentUserName)
            movies.removeAll { $0.id == movie.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMovie(_ movie: Movie) async {
        guard let chatId = currentChatId else { return }
        do {
            try await service.deleteMovie(movieId: movie.id, chatId: chatId)
            movies.removeAll { $0.id == movie.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
