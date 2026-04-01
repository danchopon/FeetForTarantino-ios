import SwiftUI

struct SearchView: View {
    let isTabSelected: Bool

    @State private var viewModel = SearchViewModel()
    @Environment(ChatStore.self) private var chatStore
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding()
                    Spacer()
                } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                    Spacer()
                    Text("No results")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.results) { movie in
                                SearchResultCard(
                                    movie: movie,
                                    isAdded: viewModel.addedMovieIds.contains(movie.id),
                                    isAdding: viewModel.addingMovieIds.contains(movie.id)
                                ) {
                                    guard let chatId = chatStore.selectedChat?.chatId else {
                                        viewModel.addErrorMessage = "No group selected. Connect a Telegram group first."
                                        return
                                    }
                                    Task { await viewModel.addMovie(movie, chatId: chatId) }
                                }
                                .onAppear {
                                    Task { await viewModel.loadNextPageIfNeeded(currentItem: movie) }
                                }
                                Divider()
                                    .padding(.leading, 104)
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: isFocused) { _, focused in
                        // X button visibility is driven by isFocused — nothing else needed
                        _ = focused
                    }
                }
            }
            .navigationTitle("Search")
            .alert("Error", isPresented: Binding(
                get: { viewModel.addErrorMessage != nil },
                set: { if !$0 { viewModel.addErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.addErrorMessage ?? "")
            }
        }
        .onChange(of: isTabSelected) { _, isSelected in
            if isSelected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isFocused = true
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                TextField("Search movies…", text: $viewModel.query)
                    .focused($isFocused)
                    .keyboardType(.default)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if isFocused {
                Button(action: { isFocused = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
