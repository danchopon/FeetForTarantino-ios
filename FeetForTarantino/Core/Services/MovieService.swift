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

    // MARK: - Logging wrappers (DEBUG only)

    /// Decode helper — logs the endpoint and raw body on DecodingError.
    private func decode<T: Decodable>(_ type: T.Type, from data: Data, source: URL) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            #if DEBUG
            print("[NET] ✗ DECODE ERROR \(source.path): \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                let preview = raw.count > 600 ? raw.prefix(600) + "…" : Substring(raw)
                print("      Raw body: \(preview)")
            }
            #endif
            throw error
        }
    }

    /// GET – returns raw data.
    private func fetch(_ url: URL) async throws -> Data {
        let start = Date()
        let (data, response) = try await URLSession.shared.data(from: url)
        #if DEBUG
        logResponse(method: "GET", url: url, requestBody: nil, data: data, response: response, duration: -start.timeIntervalSinceNow)
        #endif
        return data
    }

    /// POST / PATCH / DELETE – returns (data, response).
    @discardableResult
    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        #if DEBUG
        logResponse(method: request.httpMethod ?? "?", url: request.url, requestBody: request.httpBody, data: data, response: response, duration: -start.timeIntervalSinceNow)
        #endif
        return (data, response)
    }

#if DEBUG
    private func logResponse(method: String, url: URL?, requestBody: Data?, data: Data, response: URLResponse, duration: TimeInterval) {
        let urlString = url?.absoluteString ?? "?"
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let ms = Int(duration * 1000)
        let size = data.count < 1024
            ? "\(data.count) B"
            : String(format: "%.1f KB", Double(data.count) / 1024)

        var lines = ["[NET] → \(method) \(urlString)"]
        if let body = requestBody, let str = String(data: body, encoding: .utf8) {
            lines.append("      \(str)")
        }
        lines.append("[NET] ← \(status)  \(ms)ms  \(size)")
        if let str = String(data: data, encoding: .utf8), !str.isEmpty {
            let preview = str.count > 800 ? str.prefix(800) + "…" : Substring(str)
            lines.append("      \(preview)")
        }
        print(lines.joined(separator: "\n"))
    }
#endif

    // MARK: - URL builder

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

    // MARK: - Presence

    func sendHeartbeat(chatId: Int64, userId: Int) async throws {
        let url = try makeURL(path: "/presence/heartbeat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "chat_id": chatId,
            "user_id": userId
        ])
        try await perform(request)
    }

    func fetchOnlineUsers(chatId: Int64) async throws -> [Int] {
        let url = try makeURL(path: "/presence", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        let data = try await fetch(url)
        return try decode(PresenceResponse.self, from: data, source: url).onlineUserIds
    }

    // MARK: - Movies

    func fetchMovies(chatId: Int64, status: String? = nil) async throws -> [Movie] {
        var queryItems = [URLQueryItem(name: "chat_id", value: String(chatId))]
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        let url = try makeURL(path: "/movies", queryItems: queryItems)
        let data = try await fetch(url)
        return try decode([Movie].self, from: data, source: url)
    }

    func search(query: String, page: Int = 1) async throws -> SearchResponse {
        let url = try makeURL(path: "/search", queryItems: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page))
        ])
        let data = try await fetch(url)
        return try decode(SearchResponse.self, from: data, source: url)
    }

    func fetchRecommendations(chatId: Int64, query: String = "") async throws -> Recommendation {
        let url = try makeURL(path: "/recommendations", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId)),
            URLQueryItem(name: "q", value: query)
        ])
        let data = try await fetch(url)
        return try decode(Recommendation.self, from: data, source: url)
    }

    func fetchStats(chatId: Int64) async throws -> Stats {
        let url = try makeURL(path: "/stats", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        let data = try await fetch(url)
        return try decode(Stats.self, from: data, source: url)
    }

    func deleteMovie(movieId: Int, chatId: Int64) async throws {
        let url = try makeURL(path: "/movies/\(movieId)", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let (_, response) = try await perform(request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            throw MovieServiceError.notFound
        }
    }

    func markWatched(movieId: Int, chatId: Int64) async throws {
        let watchedBy = UserDefaults.standard.string(forKey: "username").flatMap { $0.isEmpty ? nil : $0 } ?? "iOS"
        let url = try makeURL(path: "/movies/\(movieId)/watched", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["watched_by": watchedBy])
        let (_, response) = try await perform(request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 400 {
            throw MovieServiceError.notFound
        }
    }

    func fetchUsers(chatId: Int64) async throws -> [TelegramUser] {
        let url = try makeURL(path: "/users", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        let data = try await fetch(url)
        return try decode([TelegramUser].self, from: data, source: url)
    }

    func fetchRandom(chatId: Int64) async throws -> Movie {
        let url = try makeURL(path: "/random", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        let data = try await fetch(url)
        return try decode(Movie.self, from: data, source: url)
    }

    func fetchBasket(chatId: Int64) async throws -> [BasketEntry] {
        let url = try makeURL(path: "/basket", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        let data = try await fetch(url)
        return try decode(BasketResponse.self, from: data, source: url).entries
    }

    func fetchMyBasket(chatId: Int64, userId: Int) async throws -> [Movie] {
        let url = try makeURL(path: "/basket/my", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId)),
            URLQueryItem(name: "user_id", value: String(userId))
        ])
        let data = try await fetch(url)
        let entries = try decode([BasketMovieEntry].self, from: data, source: url)
        return entries.compactMap { $0.movie }
    }

    func addToBasket(chatId: Int64, userId: Int, userName: String, movieNums: [Int]) async throws {
        let url = try makeURL(path: "/basket/add")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "chat_id": chatId,
            "user_id": userId,
            "user_name": userName,
            "movie_nums": movieNums
        ])
        try await perform(request)
    }

    func removeFromBasket(chatId: Int64, userId: Int) async throws {
        let url = try makeURL(path: "/basket/remove", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId)),
            URLQueryItem(name: "user_id", value: String(userId))
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // movie_nums=null clears the entire user's basket
        request.httpBody = try JSONSerialization.data(withJSONObject: ["movie_nums": NSNull()])
        try await perform(request)
    }

    func clearBasket(chatId: Int64) async throws {
        let url = try makeURL(path: "/basket/clear", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try await perform(request)
    }

    func fetchBasketRandom(chatId: Int64) async throws -> Movie {
        let url = try makeURL(path: "/basket/random", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId))
        ])
        let data = try await fetch(url)
        return try decode(Movie.self, from: data, source: url)
    }

    func fetchPoll(chatId: Int64, n: Int = 3) async throws -> [Movie] {
        let url = try makeURL(path: "/poll", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId)),
            URLQueryItem(name: "n", value: String(n))
        ])
        let data = try await fetch(url)
        return try decode([Movie].self, from: data, source: url)
    }

    func pickPollRandom(chatId: Int64, movieNums: [Int]) async throws -> Movie {
        let numsString = movieNums.map(String.init).joined(separator: ",")
        let url = try makeURL(path: "/poll/rpick", queryItems: [
            URLQueryItem(name: "chat_id", value: String(chatId)),
            URLQueryItem(name: "movie_nums", value: numsString)
        ])
        let data = try await fetch(url)
        return try decode(Movie.self, from: data, source: url)
    }

    func addMovie(chatId: Int64, movie: Movie) async throws {
        let url = try makeURL(path: "/movies")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let username = UserDefaults.standard.string(forKey: "username").flatMap { $0.isEmpty ? nil : $0 } ?? "iOS"
        var body: [String: Any] = [
            "chat_id": chatId,
            "title": movie.title,
            "added_by": username
        ]
        if let tmdbId = movie.tmdbId { body["tmdb_id"] = tmdbId }
        if let year = movie.year { body["year"] = year }
        if let rating = movie.rating { body["rating"] = rating }
        if let posterPath = movie.posterPath { body["poster_path"] = posterPath }
        if let genres = movie.genres { body["genres"] = genres }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await perform(request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 409 {
            throw MovieServiceError.alreadyExists
        }
    }
}
