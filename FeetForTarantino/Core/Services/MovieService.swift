import Foundation

struct SearchResponse: Codable {
    let results: [Movie]
    let totalPages: Int
    let page: Int

    enum CodingKeys: String, CodingKey {
        case results
        case totalPages = "total_pages"
        case page
    }
}

enum MovieServiceError: LocalizedError {
    case alreadyExists
    case notFound

    var errorDescription: String? {
        switch self {
        case .alreadyExists: return "Movie already in watchlist"
        case .notFound: return "Movie not found"
        }
    }
}

struct MovieService {
    private func makeURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = 8000
        components.path = path
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    func fetchMovies(chatId: Int64, status: String? = nil) async throws -> [Movie] {
        var queryItems = [URLQueryItem(name: "chat_id", value: String(chatId))]
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        let url = try makeURL(path: "/movies", queryItems: queryItems)
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Movie].self, from: data)
    }

    func search(query: String, page: Int = 1) async throws -> SearchResponse {
        let url = try makeURL(path: "/search", queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page))
        ])
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }

    func fetchRecommendations(chatId: Int64, query: String = "") async throws -> Recommendation {
        let url = try makeURL(path: "/recommendations", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId)),
            URLQueryItem(name: "q", value: query)
        ])
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Recommendation.self, from: data)
    }

    func fetchStats(chatId: Int64) async throws -> Stats {
        let url = try makeURL(path: "/stats", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Stats.self, from: data)
    }

    func deleteMovie(movieId: Int, chatId: Int64) async throws {
        let url = try makeURL(path: "/movies/\(movieId)", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            throw MovieServiceError.notFound
        }
    }

    func markWatched(movieId: Int, chatId: Int64, watchedBy: String = "iOS") async throws {
        let url = try makeURL(path: "/movies/\(movieId)/watched", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["watched_by": watchedBy])
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 400 {
            throw MovieServiceError.notFound
        }
    }

    func addMovie(chatId: Int64, movie: Movie) async throws {
        let url = try makeURL(path: "/movies")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "chat_id": chatId,
            "title": movie.title,
            "added_by": "iOS"
        ]
        if let tmdbId = movie.tmdbId { body["tmdb_id"] = tmdbId }
        if let year = movie.year { body["year"] = year }
        if let rating = movie.rating { body["rating"] = rating }
        if let posterPath = movie.posterPath { body["poster_path"] = posterPath }
        if let genres = movie.genres { body["genres"] = genres }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 409 {
            throw MovieServiceError.alreadyExists
        }
    }
}
