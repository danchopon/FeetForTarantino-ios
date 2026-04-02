import Foundation
import Observation

@Observable
final class MovieNightViewModel {
    var toWatchMovies: [Movie] = []
    var myBasket: [Movie] = []
    var allBasket: [BasketEntry] = []
    var pollMovies: [Movie] = []
    var pickedMovie: Movie?

    var isLoading = false
    var isLoadingAction = false
    var errorMessage: String?

    private let service = MovieService()

    // MARK: - Load

    func loadAll(chatId: Int64, userId: Int?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let movies = service.fetchMovies(chatId: chatId, status: "to_watch")
            async let basket = service.fetchBasket(chatId: chatId)
            toWatchMovies = try await movies
            allBasket = try await basket
            if let userId {
                myBasket = (try? await service.fetchMyBasket(chatId: chatId, userId: userId)) ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshMyBasket(chatId: Int64, userId: Int) async {
        myBasket = (try? await service.fetchMyBasket(chatId: chatId, userId: userId)) ?? []
        allBasket = (try? await service.fetchBasket(chatId: chatId)) ?? allBasket
    }

    // MARK: - Basket actions

    func addToBasket(movieNum: Int, chatId: Int64, userId: Int) async {
        isLoadingAction = true
        defer { isLoadingAction = false }
        do {
            try await service.addToBasket(chatId: chatId, userId: userId, movieNum: movieNum)
            await refreshMyBasket(chatId: chatId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeMyBasket(chatId: Int64, userId: Int) async {
        do {
            try await service.removeFromBasket(chatId: chatId, userId: userId)
            myBasket = []
            allBasket = allBasket.filter { $0.userId != userId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearBasket(chatId: Int64) async {
        do {
            try await service.clearBasket(chatId: chatId)
            myBasket = []
            allBasket = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Pick actions

    func pickRandom(chatId: Int64) async {
        isLoadingAction = true
        defer { isLoadingAction = false }
        do {
            pickedMovie = try await service.fetchRandom(chatId: chatId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pickBasketRandom(chatId: Int64) async {
        isLoadingAction = true
        defer { isLoadingAction = false }
        do {
            pickedMovie = try await service.fetchBasketRandom(chatId: chatId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Poll actions

    func createPoll(chatId: Int64) async {
        isLoadingAction = true
        defer { isLoadingAction = false }
        do {
            pollMovies = try await service.fetchPoll(chatId: chatId, n: 3)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pickPollRandom(chatId: Int64) async {
        guard !pollMovies.isEmpty else { return }
        // movie_nums are 1-indexed positions in the to_watch list
        // pollMovies are already resolved movies; we pass their positions from toWatchMovies
        let nums = pollMovies.compactMap { poll in
            toWatchMovies.firstIndex(where: { $0.id == poll.id }).map { $0 + 1 }
        }
        guard !nums.isEmpty else {
            // fallback: just pick one from pollMovies locally
            pickedMovie = pollMovies.randomElement()
            return
        }
        isLoadingAction = true
        defer { isLoadingAction = false }
        do {
            pickedMovie = try await service.pickPollRandom(chatId: chatId, movieNums: nums)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    func isInMyBasket(_ movie: Movie) -> Bool {
        myBasket.contains(where: { $0.id == movie.id })
    }

    /// Groups allBasket entries by userId for display.
    var basketByUser: [(userId: Int, name: String, movies: [Movie])] {
        var order: [Int] = []
        var dict: [Int: (name: String, movies: [Movie])] = [:]
        for entry in allBasket {
            if dict[entry.userId] == nil {
                order.append(entry.userId)
                dict[entry.userId] = (entry.displayName, [])
            }
            dict[entry.userId]?.movies.append(entry.movie)
        }
        return order.compactMap { id in
            guard let val = dict[id] else { return nil }
            return (userId: id, name: val.name, movies: val.movies)
        }
    }
}
