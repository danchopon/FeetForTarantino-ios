import Foundation
import Observation
import SwiftUI

struct WheelItem: Identifiable {
    let id: Int
    let title: String
    let votes: Int
    let percentage: Double
    let color: Color
}

private let wheelPalette: [Color] = [
    Color(red: 0.94, green: 0.33, blue: 0.31),
    Color(red: 0.98, green: 0.57, blue: 0.20),
    Color(red: 0.95, green: 0.81, blue: 0.25),
    Color(red: 0.30, green: 0.75, blue: 0.40),
    Color(red: 0.25, green: 0.62, blue: 0.92),
    Color(red: 0.55, green: 0.36, blue: 0.80),
    Color(red: 0.90, green: 0.40, blue: 0.65),
    Color(red: 0.20, green: 0.72, blue: 0.72),
    Color(red: 0.40, green: 0.50, blue: 0.85),
    Color(red: 0.20, green: 0.80, blue: 0.78)
]

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

    private var currentSessionToken: String = ""

    private var service: MovieService { MovieService(sessionToken: currentSessionToken) }

    // MARK: - Load

    func loadAll(chatId: Int64, userId: Int?, sessionToken: String) async {
        currentSessionToken = sessionToken
        let svc = MovieService(sessionToken: sessionToken)
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let movies = svc.fetchMovies(chatId: chatId, status: "to_watch")
            async let basket = svc.fetchBasket(chatId: chatId)
            toWatchMovies = try await movies
            allBasket = try await basket
            if let userId {
                myBasket = (try? await svc.fetchMyBasket(chatId: chatId, userId: userId)) ?? []
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

    func addToBasket(movieNum: Int, chatId: Int64, userId: Int, userName: String) async {
        isLoadingAction = true
        defer { isLoadingAction = false }
        do {
            try await service.addToBasket(chatId: chatId, userId: userId, userName: userName, movieNums: [movieNum])
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
        let nums = pollMovies.compactMap { poll in
            toWatchMovies.firstIndex(where: { $0.id == poll.id }).map { $0 + 1 }
        }
        guard !nums.isEmpty else {
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

    // MARK: - Wheel items

    var wheelItems: [WheelItem] {
        if !allBasket.isEmpty {
            var movieOrder: [Int] = []
            var movieDict: [Int: (Movie, Int)] = [:]
            for entry in allBasket {
                if movieDict[entry.movie.id] == nil {
                    movieOrder.append(entry.movie.id)
                    movieDict[entry.movie.id] = (entry.movie, 0)
                }
                movieDict[entry.movie.id]?.1 += 1
            }
            let items = movieOrder.compactMap { movieDict[$0] }
            let total = items.reduce(0) { $0 + $1.1 }
            return items.enumerated().map { index, item in
                WheelItem(id: item.0.id, title: item.0.title, votes: item.1,
                          percentage: total > 0 ? Double(item.1) / Double(total) : 1.0 / Double(items.count),
                          color: wheelPalette[index % wheelPalette.count])
            }
        }
        if !pollMovies.isEmpty {
            let pct = 1.0 / Double(pollMovies.count)
            return pollMovies.enumerated().map { index, movie in
                WheelItem(id: movie.id, title: movie.title, votes: 1,
                          percentage: pct,
                          color: wheelPalette[index % wheelPalette.count])
            }
        }
        return []
    }

    // MARK: - Helpers

    var basketCountByUser: [Int: Int] {
        allBasket.reduce(into: [:]) { counts, entry in
            counts[entry.userId, default: 0] += 1
        }
    }

    func isInMyBasket(_ movie: Movie) -> Bool {
        myBasket.contains(where: { $0.id == movie.id })
    }

    var basketByUser: [(userId: Int, name: String, movies: [Movie])] {
        var order: [Int] = []
        var dict: [Int: (name: String, movies: [Movie])] = [:]
        for entry in allBasket {
            if dict[entry.userId] == nil {
                order.append(entry.userId)
                dict[entry.userId] = (entry.userName, [])
            }
            dict[entry.userId]?.movies.append(entry.movie)
        }
        return order.compactMap { id in
            guard let val = dict[id] else { return nil }
            return (userId: id, name: val.name, movies: val.movies)
        }
    }
}
