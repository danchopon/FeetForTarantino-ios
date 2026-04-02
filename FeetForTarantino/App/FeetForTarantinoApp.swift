import SwiftUI

@main
struct FeetForTarantinoApp: App {
    @State private var chatStore = ChatStore()
    @AppStorage("appearance") private var appearance = "system"

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(chatStore)
                .preferredColorScheme(preferredScheme)
                .onOpenURL { url in chatStore.handle(url) }
        }
    }
}
