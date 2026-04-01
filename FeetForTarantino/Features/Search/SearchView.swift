import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @Environment(ChatStore.self) private var chatStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Search movies…", text: $viewModel.query)
                    .keyboardType(.default)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search() }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemBackground))
                    )
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
    }
}
