import Foundation
import Observation
import SwiftUI

struct ChatSession: Codable {
    let userId: Int
    let userName: String
    let chatId: Int64
    let chatName: String
}

@Observable
final class ChatStore {
    private(set) var chats: [SavedChat] = []
    var selectedChat: SavedChat?

    /// In-memory cache: chatId → members fetched from /users
    private(set) var members: [Int64: [TelegramUser]] = [:]
    /// Session data per chat (non-sensitive; session_token is in Keychain)
    private(set) var sessions: [Int64: ChatSession] = [:]

    var isExchanging = false
    var exchangeError: String?

    private let defaultsKey = "saved_chats"
    private let sessionsKey = "chat_sessions"

    init() {
        load()
        selectedChat = chats.first
    }

    func handle(_ url: URL) {
        guard url.scheme == "https",
              url.host == "danchopon.github.io",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }

        switch url.path {
        case "/feetfortarantino/auth":
            guard let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
                  !token.isEmpty else { return }
            Task { await exchangeToken(token) }

        case "/feetfortarantino/chat":
            guard let idValue = components.queryItems?.first(where: { $0.name == "id" })?.value,
                  let chatId = Int64(idValue),
                  let name = components.queryItems?.first(where: { $0.name == "name" })?.value?.removingPercentEncoding
            else { return }
            if !chats.contains(where: { $0.chatId == chatId }) {
                chats.append(SavedChat(chatId: chatId, name: name))
                saveChats()
            }
            selectedChat = chats.first(where: { $0.chatId == chatId })

        default:
            return
        }
    }

    @MainActor
    func exchangeToken(_ token: String) async {
        isExchanging = true
        exchangeError = nil
        do {
            let response = try await MovieService().exchangeToken(token)
            KeychainService.save(token: response.sessionToken, forChatId: response.chatId)
            let session = ChatSession(
                userId: response.userId,
                userName: response.userName,
                chatId: response.chatId,
                chatName: response.chatName
            )
            sessions[response.chatId] = session
            saveSessions()

            if !chats.contains(where: { $0.chatId == response.chatId }) {
                chats.append(SavedChat(chatId: response.chatId, name: response.chatName))
                saveChats()
            }
            selectedChat = chats.first(where: { $0.chatId == response.chatId })
        } catch MovieServiceError.tokenExpired {
            exchangeError = "This link has expired. Tap /app in Telegram again."
        } catch {
            exchangeError = error.localizedDescription
        }
        isExchanging = false
    }

    func sessionToken(for chatId: Int64) -> String {
        KeychainService.load(forChatId: chatId) ?? ""
    }

    func select(_ chat: SavedChat) {
        selectedChat = chat
    }

    func remove(at offsets: IndexSet) {
        let removedChats = offsets.map { chats[$0] }
        chats.remove(atOffsets: offsets)
        for chat in removedChats {
            sessions.removeValue(forKey: chat.chatId)
            KeychainService.delete(forChatId: chat.chatId)
        }
        if let selected = selectedChat, removedChats.contains(where: { $0.id == selected.id }) {
            selectedChat = chats.first
        }
        saveChats()
        saveSessions()
    }

    // MARK: - Member / Identity management

    func fetchMembers(for chatId: Int64) async {
        guard let token = KeychainService.load(forChatId: chatId) else { return }
        let service = MovieService(sessionToken: token)
        guard let fetched = try? await service.fetchUsers(chatId: chatId) else { return }
        members[chatId] = fetched
    }

    func selectedUser(for chatId: Int64) -> TelegramUser? {
        guard let session = sessions[chatId] else { return nil }
        return TelegramUser(
            userId: session.userId,
            firstName: session.userName,
            lastName: nil,
            username: nil,
            isBot: false
        )
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([SavedChat].self, from: data) {
            chats = decoded
        }
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([String: ChatSession].self, from: data) {
            sessions = Dictionary(uniqueKeysWithValues: decoded.compactMap {
                guard let key = Int64($0.key) else { return nil }
                return (key, $0.value)
            })
        }
    }

    private func saveChats() {
        guard let data = try? JSONEncoder().encode(chats) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func saveSessions() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: sessions.map { (String($0.key), $0.value) })
        guard let data = try? JSONEncoder().encode(stringKeyed) else { return }
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }
}
