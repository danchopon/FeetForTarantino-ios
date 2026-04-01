import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WatchlistView()
                .tabItem { Label("Watchlist", systemImage: "film") }
                .tag(0)

            RecommendationsView()
                .tabItem { Label("For You", systemImage: "sparkles") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(2)

            SearchView(isTabSelected: selectedTab == 3)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
