import SwiftUI

private enum MovieNightSection: String, CaseIterable {
    case browse  = "Browse"
    case basket  = "Basket"
    case tonight = "Tonight"
}

struct MovieNightView: View {
    @State private var viewModel = MovieNightViewModel()
    @State private var section: MovieNightSection = .browse
    @State private var showClearGroupConfirm = false
    @State private var showSpinWheel = false
    @Environment(ChatStore.self) private var chatStore
    @Environment(PresenceManager.self) private var presenceManager
    @Environment(WebSocketManager.self) private var wsManager

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
                ToolbarItem(placement: .navigationBarLeading) { groupPicker }
            }
            .task(id: chatStore.selectedChat?.chatId) {
                guard let id = chatId else { return }
                async let m: Void = chatStore.fetchMembers(for: id)
                async let d: Void = viewModel.loadAll(chatId: id, userId: selectedUser?.userId)
                _ = await (m, d)
            }
            .onChange(of: wsManager.basketEventCount) { _, _ in
                guard let id = chatId, let userId = selectedUser?.userId else { return }
                Task { await viewModel.refreshMyBasket(chatId: id, userId: userId) }
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
                RandomPickSheet(movie: movie)
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

    // MARK: - Main layout

    private var mainContent: some View {
        VStack(spacing: 0) {
            userPickerStrip
                .padding(.top, 12)
                .padding(.bottom, 8)

            Picker("Section", selection: $section) {
                ForEach(MovieNightSection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            switch section {
            case .browse:  browseSection
            case .basket:  basketSection
            case .tonight: tonightSection
            }
        }
        .refreshable {
            guard let id = chatId else { return }
            async let m: Void = chatStore.fetchMembers(for: id)
            async let d: Void = viewModel.loadAll(chatId: id, userId: selectedUser?.userId)
            _ = await (m, d)
        }
    }

    // MARK: - User picker strip

    private var userPickerStrip: some View {
        Group {
            if members.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading members…")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(members) { user in
                            userPill(user)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func userPill(_ user: TelegramUser) -> some View {
        let isSelected = selectedUser?.userId == user.userId
        let isOnline = presenceManager.onlineUserIds.contains(user.userId)
        let basketCount = viewModel.basketCountByUser[user.userId] ?? 0

        return VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(isSelected ? user.avatarColor : user.avatarColor.opacity(0.2))
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

                    // Online dot (bottom-right)
                    if isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                            .offset(x: 2, y: 2)
                    }
                }
                // Basket count badge
                .overlay(alignment: .topTrailing) {
                    if basketCount > 0 {
                        Text("\(basketCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(user.avatarColor))
                            .offset(x: 4, y: -4)
                    }
                }

                Text(user.firstName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
        }
    }

    // MARK: - Browse section

    private var browseSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading {
                    ProgressView().padding(.top, 40)
                } else if viewModel.toWatchMovies.isEmpty {
                    ContentUnavailableView("Nothing to watch",
                        systemImage: "film.stack",
                        description: Text("Add movies from the Search tab"))
                        .padding(.top, 40)
                } else {
                    ForEach(Array(viewModel.toWatchMovies.enumerated()), id: \.element.id) { index, movie in
                        browseRow(movie: movie, position: index + 1)
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func browseRow(movie: Movie, position: Int) -> some View {
        let inMyBasket  = viewModel.isInMyBasket(movie)
        let inAnyBasket = viewModel.allBasket.contains { $0.movie.id == movie.id }

        return HStack(spacing: 12) {
            // Position badge
            Text("#\(position)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32)

            AsyncImage(url: movie.posterURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 38, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title).font(.subheadline).lineLimit(2)
                if let year = movie.year {
                    Text(String(year)).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if inAnyBasket && !inMyBasket {
                Image(systemName: "basket.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 4)
            }

            Button {
                guard let id = chatId, let user = selectedUser else { return }
                Task { await viewModel.addToBasket(movieNum: position, chatId: id,
                                                   userId: user.userId, userName: user.firstName) }
            } label: {
                Image(systemName: inMyBasket ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title2)
                    .foregroundStyle(inMyBasket ? .green : .accentColor)
            }
            .disabled(inMyBasket || selectedUser == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Basket section

    private var basketSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // My Picks — horizontal poster strip
                if let user = selectedUser, let id = chatId {
                    myPicksStrip(user: user, chatId: id)
                        .padding(.top, 12)
                } else {
                    Text("Select who you are above to manage your picks.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding()
                }

                Divider().padding(.vertical, 8)

                // All picks grouped by user
                allPicksList

                // Clear buttons
                if let user = selectedUser, let id = chatId {
                    clearButtons(user: user, chatId: id)
                        .padding(.top, 8)
                }
            }
        }
    }

    private func myPicksStrip(user: TelegramUser, chatId: Int64) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My Picks").font(.headline).padding(.leading)
                Text("(\(viewModel.myBasket.count))").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }

            if viewModel.myBasket.isEmpty {
                Text("No picks yet — browse the watchlist to add movies.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .onTapGesture { section = .browse }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(viewModel.myBasket) { movie in
                            myPickPoster(movie: movie, user: user, chatId: chatId)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func myPickPoster(movie: Movie, user: TelegramUser, chatId: Int64) -> some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: movie.posterURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
                    .overlay(Image(systemName: "film").foregroundStyle(.secondary))
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                Task { await viewModel.removeMyBasket(chatId: chatId, userId: user.userId) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.4)).padding(2))
            }
            .offset(x: 4, y: -4)
        }
        .overlay(alignment: .bottom) {
            Text(movie.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                .frame(width: 80)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                )
        }
    }

    private var allPicksList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("All Picks").font(.headline).padding(.leading)
                Text("(\(viewModel.allBasket.count))").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 4)

            if viewModel.allBasket.isEmpty {
                Text("No picks from anyone yet.")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            } else {
                ForEach(viewModel.basketByUser, id: \.userId) { group in
                    Text(group.name)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal).padding(.top, 8)

                    ForEach(group.movies) { movie in
                        HStack(spacing: 10) {
                            AsyncImage(url: movie.posterURL) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Rectangle().fill(Color.secondary.opacity(0.2))
                            }
                            .frame(width: 36, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(movie.title).font(.subheadline).lineLimit(1)
                                if let year = movie.year {
                                    Text(String(year)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal).padding(.vertical, 6)

                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
    }

    private func clearButtons(user: TelegramUser, chatId: Int64) -> some View {
        HStack(spacing: 12) {
            if !viewModel.myBasket.isEmpty {
                Button(role: .destructive) {
                    Task { await viewModel.removeMyBasket(chatId: chatId, userId: user.userId) }
                } label: {
                    Text("Clear my picks")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            if !viewModel.allBasket.isEmpty {
                Button(role: .destructive) {
                    showClearGroupConfirm = true
                } label: {
                    Text("Clear all picks")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 24)
    }

    // MARK: - Tonight section

    private var tonightSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Winner card (if a movie was picked)
                if let movie = viewModel.pickedMovie {
                    winnerCard(movie)
                }

                // Action cards
                actionCard(
                    title: "Random from Watchlist",
                    subtitle: "Pick any unwatched movie",
                    icon: "dice.fill",
                    color: .blue,
                    disabled: false
                ) {
                    guard let id = chatId else { return }
                    Task { await viewModel.pickRandom(chatId: id) }
                }

                actionCard(
                    title: "Random from Basket",
                    subtitle: viewModel.allBasket.isEmpty ? "Add picks first" : "\(viewModel.allBasket.count) movie\(viewModel.allBasket.count == 1 ? "" : "s") in basket",
                    icon: "basket.fill",
                    color: .orange,
                    disabled: viewModel.allBasket.isEmpty
                ) {
                    guard let id = chatId else { return }
                    Task { await viewModel.pickBasketRandom(chatId: id) }
                }

                actionCard(
                    title: "Spin the Wheel",
                    subtitle: viewModel.wheelItems.isEmpty ? "Add picks first" : "Weighted by votes",
                    icon: "circle.grid.cross.fill",
                    color: .purple,
                    disabled: viewModel.wheelItems.isEmpty
                ) {
                    showSpinWheel = true
                }

                Divider().padding(.horizontal)

                // Poll area
                pollArea
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private func actionCard(title: String, subtitle: String, icon: String, color: Color,
                            disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(disabled ? Color.secondary.opacity(0.15) : color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(disabled ? .secondary : color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(disabled ? .secondary : .primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .disabled(disabled || viewModel.isLoadingAction)
    }

    private var pollArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Poll").font(.headline).padding(.leading)
                Spacer()
                Button {
                    guard let id = chatId else { return }
                    Task { await viewModel.createPoll(chatId: id) }
                } label: {
                    Label(viewModel.pollMovies.isEmpty ? "Create Poll" : "Refresh",
                          systemImage: "list.bullet.clipboard")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .padding(.trailing)
                .disabled(viewModel.isLoadingAction)
            }

            if viewModel.pollMovies.isEmpty {
                Text("Pick 3 random movies to vote on.")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            } else {
                ForEach(viewModel.pollMovies) { movie in
                    HStack(spacing: 10) {
                        AsyncImage(url: movie.posterURL) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color.secondary.opacity(0.2))
                        }
                        .frame(width: 36, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(movie.title).font(.subheadline).lineLimit(1)
                            if let year = movie.year {
                                Text(String(year)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal).padding(.vertical, 6)
                    Divider().padding(.leading, 56)
                }

                Button {
                    guard let id = chatId else { return }
                    Task { await viewModel.pickPollRandom(chatId: id) }
                } label: {
                    Label("Pick one randomly", systemImage: "dice")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(viewModel.isLoadingAction)
            }
        }
    }

    private func winnerCard(_ movie: Movie) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: movie.posterURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 60, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Label("Tonight's Pick", systemImage: "star.fill")
                    .font(.caption).foregroundStyle(.yellow).fontWeight(.semibold)
                Text(movie.title).font(.headline).lineLimit(2)
                if let year = movie.year {
                    Text(String(year)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Group picker

    private var groupPicker: some View {
        Menu {
            ForEach(chatStore.chats) { chat in
                Button { chatStore.select(chat) } label: {
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
                .font(.system(size: 56)).foregroundStyle(.secondary)
            Text("No groups connected").font(.title3).fontWeight(.semibold)
            Text("Send /app in your Telegram group\nto connect it")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Random Pick Sheet

private struct RandomPickSheet: View {
    let movie: Movie
    @Environment(\.dismiss) private var dismiss

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
                        Text(movie.title).font(.title3).fontWeight(.bold).multilineTextAlignment(.center)
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
                        Text(overview).font(.body).foregroundStyle(.secondary).padding(.horizontal)
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
