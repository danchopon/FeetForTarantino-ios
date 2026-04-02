import Foundation

/// One flat basket entry (user + movie), used throughout the app UI.
struct BasketEntry: Identifiable {
    let userId: Int
    let userName: String
    let movieNum: Int
    let movie: Movie

    var id: String { "\(userId)-\(movieNum)" }

    var displayName: String { userName }
}

// MARK: - API response shapes

/// One item inside a user's movie list: position + resolved movie.
struct BasketMovieEntry: Codable {
    let movieNum: Int
    let movie: Movie?   // null when position is out of range

    enum CodingKeys: String, CodingKey {
        case movieNum = "movie_num"
        case movie
    }
}

/// One user's entry inside GET /basket → by_user array.
struct BasketUserGroup: Codable {
    let userId: Int
    let userName: String
    let movies: [BasketMovieEntry]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userName = "user_name"
        case movies
    }
}

/// Top-level GET /basket response: {"by_user": [...], "unique_count": N}
struct BasketResponse: Codable {
    let byUser: [BasketUserGroup]
    let uniqueCount: Int

    enum CodingKeys: String, CodingKey {
        case byUser = "by_user"
        case uniqueCount = "unique_count"
    }

    /// Flatten into BasketEntry, skipping positions that resolved to nil.
    var entries: [BasketEntry] {
        byUser.flatMap { group in
            group.movies.compactMap { entry in
                guard let movie = entry.movie else { return nil }
                return BasketEntry(userId: group.userId, userName: group.userName,
                                   movieNum: entry.movieNum, movie: movie)
            }
        }
    }
}
