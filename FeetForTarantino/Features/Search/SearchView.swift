import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

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
                                SearchResultCard(movie: movie) {
                                    // Add to watchlist — coming soon
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
        }
    }
}
