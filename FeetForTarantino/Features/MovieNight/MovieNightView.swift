import SwiftUI

struct MovieNightView: View {
    @State private var viewModel = MovieNightViewModel()
    @Environment(ChatStore.self) private var chatStore
    @State private var showClearGroupConfirm = false
    @State private var showSpinWheel = false

    private var chatId: Int64? { chatStore.selectedChat?.chatId }
    private var selectedUser: TelegramUser? {
        guard let id = chatId else { return nil }
        return chatStore.selectedUser(for: id)
    }
    private var members: [TelegramUser] {
        guard let id = chatId else { return [] }
        return (chatStore.members[id] ?? []).filter { !$0.isBot }
    }

    var body: some View {
        NavigationStack {
            Group {
                if chatStore.chats.isEmpty {
                    emptyState
                } else {
                    mainContent
                }
            }
            .navigationTitle("Movie Night")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    groupPicker
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    actionsMenu
                }
            }
            .task(id: chatStore.selectedChat?.chatId) {
                guard let id = chatId else { return }
                async let members: Void = chatStore.fetchMembers(for: id)
                async let data: Void = viewModel.loadAll(chatId: id, userId: selectedUser?.userId)
                _ = await (members, data)
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $viewModel.pickedMovie) { movie in
                RandomPickSheet(movie: movie, chatId: chatId)
            }
            .sheet(isPresented: $showSpinWheel) {
                SpinWheelView(items: viewModel.wheelItems)
            }
            .confirmationDialog("Clear group basket?", isPresented: $showClearGroupConfirm, titleVisibility: .visible) {
                Button("Clear", role: .destructive) {
                    guard let id = chatId else { return }
                    Task { await viewModel.clearBasket(chatId: id) }
                }
            } message: {
                Text("This removes all picks from all members.")
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                userPickerSection
                    .padding(.top, 12)

                if let user = selectedUser, let id = chatId {
                    myPicksSection(user: user, chatId: id)
                    allPicksSection(chatId: id)
                }

                watchlistBrowseSection

                if !viewModel.pollMovies.isEmpty {
                    pollSection
                }
            }
        }
        .refreshable {
            guard let id = chatId else { return }
            async let m: Void = chatStore.fetchMembers(for: id)
            async let d: Void = viewModel.loadAll(chatId: id, userId: selectedUser?.userId)
            _ = await (m, d)
        }
    }

    // MARK: - Who am I

    private var userPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Who am I?")

            if members.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading members…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(members) { user in
                            userPill(user)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func userPill(_ user: TelegramUser) -> some View {
        let isSelected = selectedUser?.userId == user.userId
        return Button {
            guard let id = chatId else { return }
            chatStore.selectUser(user, for: id)
            Task { await viewModel.loadAll(chatId: id, userId: user.userId) }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? user.avatarColor : user.avatarColor.opacity(0.25))
                        .frame(width: 52, height: 52)

                    Image(systemName: user.avatarIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? .white : user.avatarColor)
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(user.avatarColor, lineWidth: 2.5)
                            .frame(width: 56, height: 56)
                    }
                }

                Text(user.firstName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - My Picks

    private func myPicksSection(user: TelegramUser, chatId: Int64) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader("My Picks (\(viewModel.myBasket.count))")
                Spacer()
                if !viewModel.myBasket.isEmpty {
                    Button(role: .destructive) {
                        Task { await viewModel.removeMyBasket(chatId: chatId, userId: user.userId) }
                    } label: {
                        Text("Clear mine")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.trailing)
                }
            }

            if viewModel.myBasket.isEmpty {
                Text("No picks yet. Add from the watchlist below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            } else {
                ForEach(viewModel.myBasket) { movie in
                    basketMovieRow(movie)
                    Divider().padding(.leading, 60)
                }
                Spacer(minLength: 12)
            }
        }
    }

    // MARK: - All Picks

    private func allPicksSection(chatId: Int64) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionHeader("All Picks (\(viewModel.allBasket.count))")
                Spacer()
                if !viewModel.allBasket.isEmpty {
                    Button(role: .destructive) {
                        showClearGroupConfirm = true
                    } label: {
                        Text("Clear all")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding(.trailing)
                }
            }

            if viewModel.allBasket.isEmpty {
                Text("No group picks yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            } else {
                ForEach(viewModel.basketByUser, id: \.userId) { group in
                    Text(group.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    ForEach(group.movies) { movie in
                        basketMovieRow(movie)
                        Divider().padding(.leading, 60)
                    }
                }
                Spacer(minLength: 12)
            }
        }
    }

    // MARK: - Browse Watchlist

    private var watchlistBrowseSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Add from Watchlist")

            if viewModel.isLoading {
                ProgressView().padding()
            } else if viewModel.toWatchMovies.isEmpty {
                Text("Nothing to watch yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            } else {
                ForEach(Array(viewModel.toWatchMovies.enumerated()), id: \.element.id) { index, movie in
                    browseMovieRow(movie: movie, position: index + 1)
                    Divider().padding(.leading, 60)
                }
                Spacer(minLength: 12)
            }
        }
    }

    private func browseMovieRow(movie: Movie, position: Int) -> some View {
        let inBasket = viewModel.isInMyBasket(movie)
        return HStack(spacing: 10) {
            AsyncImage(url: movie.posterURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 40, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.subheadline)
                    .lineLimit(2)
                if let year = movie.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                guard let id = chatId, let user = selectedUser else { return }
                Task { await viewModel.addToBasket(movieNum: position, chatId: id, userId: user.userId) }
            } label: {
                Image(systemName: inBasket ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundStyle(inBasket ? .green : .accentColor)
            }
            .disabled(inBasket || selectedUser == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Poll

    private var pollSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Tonight's Poll (\(viewModel.pollMovies.count))")

            ForEach(viewModel.pollMovies) { movie in
                basketMovieRow(movie)
                Divider().padding(.leading, 60)
            }

            Button {
                guard let id = chatId else { return }
                Task { await viewModel.pickPollRandom(chatId: id) }
            } label: {
                Label("Pick one randomly", systemImage: "dice")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }

    // MARK: - Reusable rows

    private func basketMovieRow(_ movie: Movie) -> some View {
        HStack(spacing: 10) {
            AsyncImage(url: movie.posterURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 40, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let year = movie.year {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let rating = movie.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption2)
                            Text(String(format: "%.1f", rating)).font(.caption)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Toolbar

    private var actionsMenu: some View {
        Menu {
            Button {
                guard let id = chatId else { return }
                Task { await viewModel.pickRandom(chatId: id) }
            } label: {
                Label("Random from watchlist", systemImage: "dice")
            }

            Button {
                guard let id = chatId else { return }
                Task { await viewModel.pickBasketRandom(chatId: id) }
            } label: {
                Label("Random from basket", systemImage: "basket")
            }
            .disabled(viewModel.allBasket.isEmpty)

            Divider()

            Button {
                guard let id = chatId else { return }
                Task { await viewModel.createPoll(chatId: id) }
            } label: {
                Label("Create poll (3 movies)", systemImage: "list.bullet.clipboard")
            }

            Divider()

            Button {
                showSpinWheel = true
            } label: {
                Label("Spin the Wheel", systemImage: "circle.grid.cross")
            }
            .disabled(viewModel.wheelItems.isEmpty)
        } label: {
            Image(systemName: "dice")
        }
        .disabled(viewModel.isLoadingAction)
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "popcorn")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No groups connected")
                .font(.title3).fontWeight(.semibold)
            Text("Send /app in your Telegram group\nto connect it")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
            .padding(.bottom, 4)
    }
}

// MARK: - Random Pick Sheet

private struct RandomPickSheet: View {
    let movie: Movie
    let chatId: Int64?
    @Environment(\.dismiss) private var dismiss
    @Environment(ChatStore.self) private var chatStore
    @State private var isAdding = false
    @State private var isAdded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AsyncImage(url: movie.posterURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.secondary.opacity(0.2))
                            .overlay(Image(systemName: "film").foregroundStyle(.secondary))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    VStack(spacing: 6) {
                        Text(movie.title)
                            .font(.title3).fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 12) {
                            if let year = movie.year {
                                Text(String(year)).foregroundStyle(.secondary)
                            }
                            if let rating = movie.rating {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating))
                                }
                            }
                            if let runtime = movie.formattedRuntime {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock").foregroundStyle(.secondary)
                                    Text(runtime).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal)

                    if let overview = movie.overview {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Tonight's Pick")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
