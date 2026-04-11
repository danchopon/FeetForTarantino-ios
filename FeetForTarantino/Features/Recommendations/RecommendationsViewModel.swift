import Foundation
import Observation
import FoundationModels

// MARK: - On-device generation types (iOS 26+)

@available(iOS 26, *)
@Generable
private struct AIMovieList {
    @Guide(description: "Intent: 'similar' if user mentions a specific film title, 'mood' if user describes a vibe or genre, 'history' if no specific request")
    var intent: String

    @Guide(description: "If intent is 'similar', the referenced film title. Otherwise empty string.")
    var sourceMovie: String

    @Guide(description: "Five movie recommendations", .count(5))
    var suggestions: [AIMovieSuggestion]
}

@available(iOS 26, *)
@Generable
private struct AIMovieSuggestion {
    @Guide(description: "Movie title in English")
    var title: String

    @Guide(description: "Four-digit release year, e.g. '2010'")
    var year: String

    @Guide(description: "One to two sentences: specific reason why this film fits the request, referencing films from the watch history where relevant")
    var reason: String
}

// MARK: - ViewModel

@Observable
class RecommendationsViewModel {
    var recommendation: Recommendation?
    var query: String = ""
    var isLoading = false
    var errorMessage: String?
    var addedIds: Set<Int> = []
    var addingIds: Set<Int> = []
    var addErrorMessage: String?

    private var currentSessionToken: String = ""
    private var currentUserName: String = "iOS"

    private var service: MovieService { MovieService(sessionToken: currentSessionToken) }

    func fetchRecommendations(chatId: Int64, sessionToken: String, userName: String) async {
        currentSessionToken = sessionToken
        currentUserName = userName
        isLoading = true
        errorMessage = nil
        recommendation = nil

        let svc = MovieService(sessionToken: sessionToken)
        do {
            if #available(iOS 26, *), foundationModelsAvailable {
                do {
                    recommendation = try await fetchWithFoundationModels(chatId: chatId, service: svc)
                } catch {
                    recommendation = try await svc.fetchRecommendations(chatId: chatId, query: query)
                }
            } else {
                recommendation = try await svc.fetchRecommendations(chatId: chatId, query: query)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - On-device (Foundation Models)

    @available(iOS 26, *)
    private var foundationModelsAvailable: Bool {
        guard case .available = SystemLanguageModel.default.availability else { return false }
        return SystemLanguageModel.default.supportsLocale(Locale.current)
    }

    @available(iOS 26, *)
    private func fetchWithFoundationModels(chatId: Int64, service: MovieService) async throws -> Recommendation {
        async let watchedResult = service.fetchMovies(chatId: chatId, status: "watched")
        async let watchlistResult = service.fetchMovies(chatId: chatId, status: "to_watch")
        let watched = (try? await watchedResult) ?? []
        let watchlist = (try? await watchlistResult) ?? []

        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        var promptParts: [String] = []

        if trimmedQuery.isEmpty {
            if !watched.isEmpty {
                let lines = watched.prefix(20).map { m -> String in
                    var line = "- \(m.title)"
                    if let y = m.year { line += " (\(y))" }
                    if let g = m.genres, !g.isEmpty { line += " [\(g)]" }
                    if let r = m.rating { line += " ⭐\(String(format: "%.1f", r))" }
                    return line
                }.joined(separator: "\n")
                promptParts.append("Already watched (DO NOT suggest):\n\(lines)")
            } else {
                promptParts.append("Watch history: empty (new group)")
            }

            if !watchlist.isEmpty {
                let titles = watchlist.prefix(15).map { "- \($0.title)" }.joined(separator: "\n")
                promptParts.append("Already in watchlist (DO NOT suggest):\n\(titles)")
            }
        }

        promptParts.append(
            "User request: \(trimmedQuery.isEmpty ? "(no specific request — recommend based on history)" : trimmedQuery)"
        )

        let session = LanguageModelSession(instructions: """
            You are a smart movie recommendation assistant for a group chat.

            Analyze the user's request and watch history, then suggest exactly 5 movies.

            Detect the intent:
            - "similar" — user mentions a specific movie title (e.g. "like Inception", "something like Prestige")
            - "mood" — user describes a vibe, genre, or theme (e.g. "dark thriller", "something funny", "sci-fi with a great plot")
            - "history" — empty request or asks for recommendations without specifics

            Rules:
            - DO NOT suggest movies already in the watched list or watchlist
            - For "similar" intent: recommend movies similar in style, theme, or director to the mentioned film
            - For "mood" intent: match the described vibe, reference specific watched films when relevant
            - For "history" intent: analyze patterns in watch history (genres, ratings, directors) and suggest accordingly
            - Reasons must be specific and personal (e.g. "You liked Prisoners — same director and tense atmosphere")
            """)

        let response = try await session.respond(
            to: promptParts.joined(separator: "\n\n"),
            generating: AIMovieList.self
        )
        let aiList = response.content

        let existing = Set((watched + watchlist).map { $0.title.lowercased() })
        let filtered = aiList.suggestions.filter { !existing.contains($0.title.lowercased()) }

        let suggestions = await enrichedSuggestions(from: filtered, service: service)

        return Recommendation(
            intent: aiList.intent,
            sourceMovie: aiList.sourceMovie.isEmpty ? nil : aiList.sourceMovie,
            suggestions: suggestions
        )
    }

    @available(iOS 26, *)
    private func enrichedSuggestions(from aiSuggestions: [AIMovieSuggestion], service: MovieService) async -> [Suggestion] {
        await withTaskGroup(of: (Int, Suggestion).self) { group in
            for (index, ai) in aiSuggestions.enumerated() {
                group.addTask {
                    let match = try? await service.search(query: ai.title, page: 1).results.first
                    let suggestion = Suggestion(
                        title: match?.title ?? ai.title,
                        year: match?.year.map(String.init) ?? ai.year,
                        rating: match?.rating,
                        overview: match?.overview,
                        posterPath: match?.posterPath,
                        tmdbId: match?.tmdbId,
                        reason: ai.reason
                    )
                    return (index, suggestion)
                }
            }

            var indexed: [(Int, Suggestion)] = []
            for await item in group { indexed.append(item) }
            return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Add to watchlist

    func addToWatchlist(_ suggestion: Suggestion, chatId: Int64, addedBy: String) async {
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
            try await service.addMovie(chatId: chatId, movie: movie, addedBy: addedBy)
            addedIds.insert(suggestion.id)
        } catch {
            addErrorMessage = error.localizedDescription
        }
        addingIds.remove(suggestion.id)
    }
}
