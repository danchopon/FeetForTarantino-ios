import Foundation

struct Movie: Codable, Identifiable {
    // Present on watchlist items (from /movies), nil on search results
    private let dbId: Int?
    let chatId: Int?
    let status: String?
    let addedBy: String?
    let addedAt: String?
    let watchedBy: String?
    let watchedAt: String?
    let genres: String?

    // Present on both watchlist and search results
    let title: String
    let tmdbId: Int?
    let year: Int?
    let rating: Double?
    let posterPath: String?

    /// Stable identity: prefer DB id, fall back to TMDB id, then title hash.
    var id: Int { dbId ?? tmdbId ?? title.hashValue }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500" + path)
    }

    enum CodingKeys: String, CodingKey {
        case dbId = "id"
        case chatId = "chat_id"
        case title
        case status
        case addedBy = "added_by"
        case addedAt = "added_at"
        case watchedBy = "watched_by"
        case watchedAt = "watched_at"
        case tmdbId = "tmdb_id"
        case year
        case rating
        case posterPath = "poster_path"
        case genres
    }

    init(title: String, tmdbId: Int? = nil, year: Int? = nil, rating: Double? = nil, posterPath: String? = nil, genres: String? = nil) {
        self.dbId = nil
        self.chatId = nil
        self.title = title
        self.tmdbId = tmdbId
        self.year = year
        self.rating = rating
        self.posterPath = posterPath
        self.genres = genres
        self.status = nil
        self.addedBy = nil
        self.addedAt = nil
        self.watchedBy = nil
        self.watchedAt = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dbId       = try c.decodeIfPresent(Int.self,    forKey: .dbId)
        chatId     = try c.decodeIfPresent(Int.self,    forKey: .chatId)
        title      = try c.decode(String.self,           forKey: .title)
        status     = try c.decodeIfPresent(String.self, forKey: .status)
        addedBy    = try c.decodeIfPresent(String.self, forKey: .addedBy)
        addedAt    = try c.decodeIfPresent(String.self, forKey: .addedAt)
        watchedBy  = try c.decodeIfPresent(String.self, forKey: .watchedBy)
        watchedAt  = try c.decodeIfPresent(String.self, forKey: .watchedAt)
        tmdbId     = try c.decodeIfPresent(Int.self,    forKey: .tmdbId)
        rating     = try c.decodeIfPresent(Double.self, forKey: .rating)
        posterPath = try c.decodeIfPresent(String.self, forKey: .posterPath)
        genres     = try c.decodeIfPresent(String.self, forKey: .genres)
        // year may arrive as Int (watchlist) or String (search/TMDB)
        if let intYear = try? c.decodeIfPresent(Int.self, forKey: .year) {
            year = intYear
        } else if let strYear = try? c.decodeIfPresent(String.self, forKey: .year) {
            year = Int(strYear)
        } else {
            year = nil
        }
    }
}
