import Foundation

struct Recommendation: Codable {
    let intent: String
    let sourceMovie: String?
    let suggestions: [Suggestion]

    enum CodingKeys: String, CodingKey {
        case intent
        case sourceMovie = "source_movie"
        case suggestions
    }
}

struct Suggestion: Codable, Identifiable {
    let title: String
    let year: String?
    let rating: Double?
    let overview: String?
    let posterPath: String?
    let tmdbId: Int?
    let reason: String

    var id: Int { tmdbId ?? title.hashValue }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500" + path)
    }

    enum CodingKeys: String, CodingKey {
        case title, year, rating, overview, reason
        case posterPath = "poster_path"
        case tmdbId = "tmdb_id"
    }
}
