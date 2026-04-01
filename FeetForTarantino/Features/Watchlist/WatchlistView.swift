import SwiftUI

struct WatchlistView: View {
    @State private var viewModel = WatchlistViewModel()
    @State private var isGridLayout = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Enter Chat ID", text: $viewModel.chatIdInput)
                    .keyboardType(.default)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.fetchMovies() }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding()
                }

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
            .navigationTitle("Watchlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isGridLayout.toggle()
                    } label: {
                        Image(systemName: isGridLayout ? "list.bullet" : "square.grid.2x2")
                    }
                }
            }
        }
    }
}
