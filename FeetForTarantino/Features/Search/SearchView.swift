import SwiftUI

struct SearchView: View {
    let isTabSelected: Bool

    @State private var viewModel = SearchViewModel()
    @Environment(ChatStore.self) private var chatStore
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Search")
                .searchable(
                    text: $viewModel.query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search movies…"
                )
                .searchFocused($isFocused)
                .onSubmit(of: .search) {
                    Task { await viewModel.search() }
                }
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

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.subheadline)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
            Text("No results")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
    }
}
