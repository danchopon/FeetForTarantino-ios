import Foundation
import Observation
import SwiftUI

@Observable
final class ChatStore {
    private(set) var chats: [SavedChat] = []
    var selectedChat: SavedChat?

    private let defaultsKey = "saved_chats"

    init() {
        load()
        selectedChat = chats.first
    }

    func handle(_ url: URL) {
        guard url.scheme == "https",
              url.host == "danchopon.github.io",
              url.path == "/feetfortarantino/chat",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idItem = components.queryItems?.first(where: { $0.name == "id" }),
              let nameItem = components.queryItems?.first(where: { $0.name == "name" }),
              let chatId = Int64(idItem.value ?? ""),
              let name = nameItem.value?.removingPercentEncoding
        else { return }
        
        if !chats.contains(where: { $0.chatId == chatId }) {
            chats.append(SavedChat(chatId: chatId, name: name))
            save()
        }
        selectedChat = chats.first(where: { $0.chatId == chatId })
    }

    func select(_ chat: SavedChat) {
        selectedChat = chat
    }

    func remove(at offsets: IndexSet) {
        let removedIds = offsets.map { chats[$0].id }
        chats.remove(atOffsets: offsets)
        if let selected = selectedChat, removedIds.contains(selected.id) {
            selectedChat = chats.first
        }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([SavedChat].self, from: data)
        else { return }
        chats = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(chats) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
