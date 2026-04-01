import Foundation

struct SavedChat: Codable, Identifiable, Hashable {
    let id: UUID
    let chatId: Int64
    let name: String

    init(chatId: Int64, name: String) {
        self.id = UUID()
        self.chatId = chatId
        self.name = name
    }
}
