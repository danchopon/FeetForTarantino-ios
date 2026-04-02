import SwiftUI

@main
struct FeetForTarantinoApp: App {
    @State private var chatStore = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chatStore)
                .onOpenURL { url in chatStore.handle(url) }
        }
    }
}
