import Foundation

struct TelegramUser: Codable, Identifiable {
    let userId: Int
    let firstName: String
    let lastName: String?
    let username: String?
    let isBot: Bool
    let photoUrl: String?

    var id: Int { userId }

    var displayName: String {
        if let username { return "@\(username)" }
        if let lastName { return "\(firstName) \(lastName)" }
        return firstName
    }

    /// Full URL to the photo proxy endpoint on the local server.
    func photoURL(chatId: Int64) -> URL? {
        URL(string: "http://localhost:8000/users/\(userId)/photo?chat_id=\(chatId)")
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case isBot = "is_bot"
        case photoUrl = "photo_url"
    }
}
