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

            MovieNightView()
                .tabItem { Label("Movie Night", systemImage: "popcorn") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(3)

            SearchView(isTabSelected: selectedTab == 4)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
}
