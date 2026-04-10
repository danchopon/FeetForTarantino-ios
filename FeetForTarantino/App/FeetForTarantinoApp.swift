import SwiftUI

@main
struct FeetForTarantinoApp: App {
    @State private var chatStore = ChatStore()

    init() {
        if ProcessInfo.processInfo.arguments.contains("UI-Testing") {
            UserDefaults.standard.removeObject(forKey: "saved_chats")
            UserDefaults.standard.removeObject(forKey: "selected_user_ids")
            UserDefaults.standard.removeObject(forKey: "username")
        }
    }
    @State private var presenceManager = PresenceManager()
    @State private var webSocketManager = WebSocketManager()
    @Environment(\.scenePhase) private var scenePhase

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
        }
    }

    private func restartPresenceIfNeeded(phase: ScenePhase) {
        guard phase == .active,
              let chat = chatStore.selectedChat,
              let userId = chatStore.selectedUser(for: chat.chatId)?.userId
        else {
            presenceManager.stop()
            webSocketManager.disconnect()
            return
        }
        presenceManager.start(chatId: chat.chatId, userId: userId)
        webSocketManager.connect(chatId: chat.chatId)
    }
}
