import SwiftUI

enum LayoutMode: String, CaseIterable {
    case list, grid2, grid1

    var icon: String {
        switch self {
        case .list:  return "list.bullet"
        case .grid2: return "square.grid.2x2"
        case .grid1: return "rectangle.grid.1x2"
        }
    }

    var label: String {
        switch self {
        case .list:  return "List"
        case .grid2: return "2-Column Grid"
        case .grid1: return "Large Grid"
        }
    }
}

struct WatchlistView: View {
    @State private var viewModel = WatchlistViewModel()
    @State private var layoutMode: LayoutMode = .list
    @Environment(ChatStore.self) private var chatStore
    @Environment(WebSocketManager.self) private var wsManager

    var body: some View {
        NavigationStack {
            Group {
                if chatStore.chats.isEmpty {
                    emptyState
                } else if viewModel.isLoading {
                    VStack {
                        filterPicker
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let error = viewModel.errorMessage {
                    VStack {
                        filterPicker
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                            .padding()
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        filterPicker
                        statsBar
                        movieList
                    }
                }
            }
            .navigationTitle(chatStore.selectedChat?.name ?? "Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    groupPicker
                }
                if !chatStore.chats.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Picker("Layout", selection: $layoutMode) {
                                ForEach(LayoutMode.allCases, id: \.self) { mode in
                                    Label(mode.label, systemImage: mode.icon).tag(mode)
                                }
                            }
                        } label: {
                            Image(systemName: layoutMode.icon)
                        }
                    }
                }
            }
            .task(id: chatStore.selectedChat?.chatId) {
                guard let chat = chatStore.selectedChat else { return }
                await viewModel.fetchMovies(
                    chatId: chat.chatId,
                    sessionToken: chatStore.sessionToken(for: chat.chatId),
                    userName: chatStore.sessions[chat.chatId]?.userName ?? "iOS"
                )
            }
            .onChange(of: viewModel.statusFilter) { _, _ in
                guard let chat = chatStore.selectedChat else { return }
                Task {
                    await viewModel.fetchMovies(
                        chatId: chat.chatId,
                        sessionToken: chatStore.sessionToken(for: chat.chatId),
                        userName: chatStore.sessions[chat.chatId]?.userName ?? "iOS"
                    )
                }
            }
            .onChange(of: wsManager.movieEventCount) { _, _ in
                guard let chat = chatStore.selectedChat else { return }
                Task {
                    await viewModel.fetchMovies(
                        chatId: chat.chatId,
                        sessionToken: chatStore.sessionToken(for: chat.chatId),
                        userName: chatStore.sessions[chat.chatId]?.userName ?? "iOS"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var statsBar: some View {
        if let stats = viewModel.stats {
            HStack(spacing: 20) {
                Label("\(stats.toWatch) to watch", systemImage: "bookmark")
                Label("\(stats.watched) watched", systemImage: "eye")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
    }

    private var filterPicker: some View {
        Picker("Status", selection: $viewModel.statusFilter) {
            ForEach(WatchlistViewModel.StatusFilter.allCases, id: \.self) { filter in
                Text(filter.label).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
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
        switch layoutMode {
        case .list:
            AnyView(
                List {
                    ForEach(viewModel.movies) { movie in
                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                            MovieCardRow(movie: movie)
                        }
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if movie.status == "to_watch" {
                                Button {
                                    Task { await viewModel.markWatched(movie) }
                                } label: {
                                    Label("Watched", systemImage: "eye")
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteMovie(movie) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            )
        case .grid2:
            AnyView(
                ScrollView {
                    LazyVGrid(
                        columns: [.init(.flexible()), .init(.flexible())],
                        spacing: 12
                    ) {
                        ForEach(viewModel.movies) { movie in
                            NavigationLink(destination: MovieDetailView(movie: movie)) {
                                MovieCardTile(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            )
        case .grid1:
            AnyView(
                List {
                    ForEach(viewModel.movies) { movie in
                        NavigationLink(destination: MovieDetailView(movie: movie)) {
                            MovieCardLarge(movie: movie)
                        }
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if movie.status == "to_watch" {
                                Button {
                                    Task { await viewModel.markWatched(movie) }
                                } label: {
                                    Label("Watched", systemImage: "eye")
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteMovie(movie) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            )
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
