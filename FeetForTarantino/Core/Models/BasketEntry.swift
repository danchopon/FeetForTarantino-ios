import Foundation

/// One flat basket entry (user + movie), used throughout the app.
struct BasketEntry: Identifiable {
    let userId: Int
    let username: String?
    let firstName: String?
    let movie: Movie

    var id: String { "\(userId)-\(movie.id)" }

    var displayName: String {
        if let username { return "@\(username)" }
        if let firstName { return firstName }
        return "User \(userId)"
    }
}

// MARK: - API response shapes

/// One per-user group inside GET /basket response.
struct BasketUserGroup: Codable {
    let userId: Int
    let username: String?
    let firstName: String?
    let movies: [Movie]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case firstName = "first_name"
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

    /// Flatten into individual BasketEntry values preserving insertion order.
    var entries: [BasketEntry] {
        byUser.flatMap { group in
            group.movies.map { movie in
                BasketEntry(userId: group.userId, username: group.username,
                            firstName: group.firstName, movie: movie)
            }
        }
    }
}
