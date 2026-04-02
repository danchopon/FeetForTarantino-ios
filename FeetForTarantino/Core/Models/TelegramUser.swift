import Foundation
import SwiftUI

struct TelegramUser: Codable, Identifiable {
    let userId: Int
    let firstName: String
    let lastName: String?
    let username: String?
    let isBot: Bool

    var id: Int { userId }

    var displayName: String {
        if let username { return "@\(username)" }
        if let lastName { return "\(firstName) \(lastName)" }
        return firstName
    }

    // MARK: - Avatar

    private static let animalIcons = [
        "hare.fill", "tortoise.fill", "bird.fill", "fish.fill",
        "ant.fill", "ladybug.fill", "pawprint.fill", "leaf.fill",
        "flame.fill", "drop.fill"
    ]
    private static let avatarColors: [Color] = [
        Color(red: 0.94, green: 0.33, blue: 0.31),
        Color(red: 0.98, green: 0.57, blue: 0.20),
        Color(red: 0.30, green: 0.75, blue: 0.40),
        Color(red: 0.25, green: 0.62, blue: 0.92),
        Color(red: 0.55, green: 0.36, blue: 0.80),
        Color(red: 0.90, green: 0.40, blue: 0.65),
        Color(red: 0.20, green: 0.72, blue: 0.72),
        Color(red: 0.40, green: 0.50, blue: 0.85),
        Color(red: 0.95, green: 0.72, blue: 0.20),
        Color(red: 0.20, green: 0.80, blue: 0.78)
    ]

    var avatarIcon: String { Self.animalIcons[abs(userId) % Self.animalIcons.count] }
    var avatarColor: Color { Self.avatarColors[abs(userId) % Self.avatarColors.count] }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case isBot = "is_bot"
    }
}
