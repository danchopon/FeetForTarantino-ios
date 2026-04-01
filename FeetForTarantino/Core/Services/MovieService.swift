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

    func fetchMovies(chatId: Int64) async throws -> [Movie] {
        let url = try makeURL(path: "/movies", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
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
