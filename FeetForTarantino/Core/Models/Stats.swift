import Foundation

struct Stats: Codable {
    let toWatch: Int
    let watched: Int

    enum CodingKeys: String, CodingKey {
        case toWatch = "to_watch"
        case watched
    }
}
