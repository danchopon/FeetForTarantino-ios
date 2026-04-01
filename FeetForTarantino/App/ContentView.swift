import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WatchlistView()
                .tabItem {
                    Label("Watchlist", systemImage: "film")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            RecommendationsView()
                .tabItem {
                    Label("For You", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
