import SwiftUI

struct RecommendationsView: View {
    @State private var viewModel = RecommendationsViewModel()
    @Environment(ChatStore.self) private var chatStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    TextField("Mood, genre, or \"like Inception\"…", text: $viewModel.query)
                        .submitLabel(.search)
                        .onSubmit { fetchIfReady() }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemBackground))
                        )

                    Button(action: fetchIfReady) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .padding(14)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(chatStore.selectedChat == nil || viewModel.isLoading)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                if chatStore.chats.isEmpty {
                    emptyState
                } else if viewModel.isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Asking AI…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                } else if let rec = viewModel.recommendation {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            intentHeader(rec)
                                .padding(.horizontal)
                                .padding(.bottom, 12)

                            ForEach(rec.suggestions) { suggestion in
                                SuggestionCard(
                                    suggestion: suggestion,
                                    isAdded: viewModel.addedIds.contains(suggestion.id),
                                    isAdding: viewModel.addingIds.contains(suggestion.id)
                                ) {
                                    guard let chatId = chatStore.selectedChat?.chatId else { return }
                                    Task { await viewModel.addToWatchlist(suggestion, chatId: chatId) }
                                }
                                Divider()
                                    .padding(.leading, 104)
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Tap ✦ to get AI recommendations\nbased on your group's history")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                }
            }
            .navigationTitle("For You")
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

    @ViewBuilder
    private func intentHeader(_ rec: Recommendation) -> some View {
        switch rec.intent {
        case "similar":
            if let source = rec.sourceMovie {
                Label("Similar to \(source)", systemImage: "film.stack")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case "mood":
            Label("Based on your mood", systemImage: "theatermasks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        default:
            Label("Based on your watch history", systemImage: "clock.arrow.circlepath")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No groups connected")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Send /app in your Telegram group\nto connect it")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private func fetchIfReady() {
        guard let chatId = chatStore.selectedChat?.chatId else { return }
        Task { await viewModel.fetchRecommendations(chatId: chatId) }
    }
}

private struct SuggestionCard: View {
    let suggestion: Suggestion
    let isAdded: Bool
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: suggestion.posterURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .overlay(Image(systemName: "film").foregroundStyle(.secondary))
            }
            .frame(width: 80, height: 120)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(suggestion.title)
                    .font(.headline)
                    .lineLimit(2)

                if let year = suggestion.year {
                    Text(year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let rating = suggestion.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                        Text(String(format: "%.1f", rating)).font(.subheadline)
                    }
                }

                if let reason = Optional(suggestion.reason), !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.top, 2)
                }

                Spacer()

                Group {
                    if isAdding {
                        ProgressView().frame(height: 30)
                    } else if isAdded {
                        Label("Added", systemImage: "checkmark")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    } else {
                        Button(action: onAdd) {
                            Label("Add", systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
