import Foundation
import Observation
import SwiftUI

@Observable
final class ChatStore {
    private(set) var chats: [SavedChat] = []
    var selectedChat: SavedChat?

    /// In-memory cache: chatId → admins fetched from /users
    private(set) var members: [Int64: [TelegramUser]] = [:]
    /// Persisted: chatId → the userId the current device user identified themselves as
    private var selectedUserIds: [Int64: Int] = [:]

    private let defaultsKey = "saved_chats"
    private let userIdsKey = "selected_user_ids"

    private let service = MovieService()

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

        if let userIdStr = components.queryItems?.first(where: { $0.name == "user_id" })?.value,
           let userId = Int(userIdStr) {
            selectedUserIds[chatId] = userId
            saveUserIds()
        }
        if let userName = components.queryItems?.first(where: { $0.name == "user_name" })?.value?.removingPercentEncoding,
           !userName.isEmpty {
            UserDefaults.standard.set(userName, forKey: "username")
        }
    }

    func select(_ chat: SavedChat) {
        selectedChat = chat
    }

    func addManually(chatId: Int64, name: String) {
        guard !chats.contains(where: { $0.chatId == chatId }) else { return }
        chats.append(SavedChat(chatId: chatId, name: name))
        if selectedChat == nil { selectedChat = chats.first }
        save()
    }

    func remove(at offsets: IndexSet) {
        let removedIds = offsets.map { chats[$0].id }
        chats.remove(atOffsets: offsets)
        if let selected = selectedChat, removedIds.contains(selected.id) {
            selectedChat = chats.first
        }
        save()
    }

    // MARK: - Member / Identity management

    func fetchMembers(for chatId: Int64) async {
        guard let fetched = try? await service.fetchUsers(chatId: chatId) else { return }
        members[chatId] = fetched
    }

    func selectedUser(for chatId: Int64) -> TelegramUser? {
        guard let userId = selectedUserIds[chatId] else { return nil }
        return members[chatId]?.first(where: { $0.userId == userId })
    }

    func selectUser(_ user: TelegramUser, for chatId: Int64) {
        selectedUserIds[chatId] = user.userId
        saveUserIds()
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([SavedChat].self, from: data) {
            chats = decoded
        }
        if let data = UserDefaults.standard.data(forKey: userIdsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            selectedUserIds = Dictionary(uniqueKeysWithValues: decoded.compactMap {
                guard let key = Int64($0.key) else { return nil }
                return (key, $0.value)
            })
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(chats) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func saveUserIds() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: selectedUserIds.map { (String($0.key), $0.value) })
        guard let data = try? JSONEncoder().encode(stringKeyed) else { return }
        UserDefaults.standard.set(data, forKey: userIdsKey)
    }
}
