import SwiftUI

struct WatchlistView: View {
    @State private var viewModel = WatchlistViewModel()
    @State private var isGridLayout = false
    @Environment(ChatStore.self) private var chatStore

    var body: some View {
        NavigationStack {
            Group {
                if chatStore.chats.isEmpty {
                    emptyState
                } else if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding()
                } else {
                    movieList
                }
            }
            .navigationTitle(chatStore.selectedChat?.name ?? "Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    groupPicker
                }
                if !chatStore.chats.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isGridLayout.toggle()
                        } label: {
                            Image(systemName: isGridLayout ? "list.bullet" : "square.grid.2x2")
                        }
                    }
                }
            }
            .task(id: chatStore.selectedChat?.chatId) {
                guard let chat = chatStore.selectedChat else { return }
                await viewModel.fetchMovies(chatId: chat.chatId)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No groups connected")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Send /app in your Telegram group\nto connect it")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var movieList: some View {
        ScrollView {
            if isGridLayout {
                LazyVGrid(
                    columns: [.init(.flexible()), .init(.flexible())],
                    spacing: 12
                ) {
                    ForEach(viewModel.movies) { movie in
                        MovieCardTile(movie: movie)
                    }
                }
                .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.movies) { movie in
                        MovieCardRow(movie: movie)
                        Divider()
                            .padding(.leading, 124)
                    }
                }
            }
        }
    }

    private var groupPicker: some View {
        Menu {
            ForEach(chatStore.chats) { chat in
                Button {
                    chatStore.select(chat)
                } label: {
                    if chat.id == chatStore.selectedChat?.id {
                        Label(chat.name, systemImage: "checkmark")
                    } else {
                        Text(chat.name)
                    }
                }
            }
        } label: {
            Label("Groups", systemImage: "person.3")
        }
    }
}
