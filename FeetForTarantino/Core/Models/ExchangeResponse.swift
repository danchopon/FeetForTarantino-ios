import Foundation

struct ExchangeResponse: Codable {
    let sessionToken: String
    let expiresIn: Int
    let userId: Int
    let userName: String
    let chatId: Int64
    let chatName: String

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case expiresIn = "expires_in"
        case userId = "user_id"
        case userName = "user_name"
        case chatId = "chat_id"
        case chatName = "chat_name"
    }
}
