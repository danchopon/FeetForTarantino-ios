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

struct MovieService {
    func fetchMovies(chatId: Int64) async throws -> [Movie] {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = 8000
        components.path = "/movies"
        components.queryItems = [URLQueryItem(name: "chat_id", value: String(chatId))]

        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Movie].self, from: data)
    }

    func search(query: String, page: Int = 1) async throws -> SearchResponse {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = 8000
        components.path = "/search"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page))
        ]

        guard let url = components.url else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }
}
