import Foundation

struct PresenceResponse: Codable {
    let onlineUserIds: [Int]

    enum CodingKeys: String, CodingKey {
        case onlineUserIds = "online_user_ids"
    }
}
