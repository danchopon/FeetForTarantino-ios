import SwiftUI

@main
struct FeetForTarantinoApp: App {
    @State private var chatStore = ChatStore()
    @State private var presenceManager = PresenceManager()
    @State private var webSocketManager = WebSocketManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
            UserDefaults.standard.removeObject(forKey: "saved_chats")
            UserDefaults.standard.removeObject(forKey: "chat_sessions")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chatStore)
                .environment(presenceManager)
                .environment(webSocketManager)
                .onOpenURL { url in chatStore.handle(url) }
                .onChange(of: scenePhase) { _, phase in
                    restartPresenceIfNeeded(phase: phase)
                }
                .onChange(of: chatStore.selectedChat?.chatId) { _, _ in
                    restartPresenceIfNeeded(phase: scenePhase)
                }
                .alert(
                    "Link Expired",
                    isPresented: Binding(
                        get: { chatStore.exchangeError != nil },
                        set: { if !$0 { chatStore.exchangeError = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { chatStore.exchangeError = nil }
                } message: {
                    Text(chatStore.exchangeError ?? "")
                }
        }
    }

    private func restartPresenceIfNeeded(phase: ScenePhase) {
        guard phase == .active,
              let chat = chatStore.selectedChat,
              let session = chatStore.sessions[chat.chatId]
        else {
            presenceManager.stop()
            webSocketManager.disconnect()
            return
        }
        let token = chatStore.sessionToken(for: chat.chatId)
        guard !token.isEmpty else {
            presenceManager.stop()
            webSocketManager.disconnect()
            return
        }
        presenceManager.start(chatId: chat.chatId, userId: session.userId, sessionToken: token)
        webSocketManager.connect(chatId: chat.chatId, sessionToken: token)
    }
}
