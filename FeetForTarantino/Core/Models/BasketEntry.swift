import Foundation

/// One basket entry: a movie nominated by a specific user.
/// Response shape for GET /basket?chat_id=X
struct BasketEntry: Codable, Identifiable {
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

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case firstName = "first_name"
        case movie
    }
}
