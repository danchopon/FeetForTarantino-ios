import SwiftUI

struct RecommendationsView: View {
    @State private var viewModel = RecommendationsViewModel()
    @Environment(ChatStore.self) private var chatStore
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            contentArea
                .animation(.easeInOut(duration: 0.4), value: viewModel.isLoading)
                .animation(.easeInOut(duration: 0.4), value: viewModel.recommendation != nil)
                .navigationTitle("For You")
                .safeAreaInset(edge: .bottom) {
                    bottomInputBar
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
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if chatStore.chats.isEmpty {
            emptyState
        } else if viewModel.isLoading {
            shimmerLoadingCards
                .transition(.opacity)
        } else if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { inputFocused = false }
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
            .scrollDismissesKeyboard(.interactively)
            .transition(.opacity)
        } else {
            idlePlaceholder
        }
    }

    private var shimmerLoadingCards: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    ShimmerCard(style: .recommendations)
                    Divider()
                        .padding(.leading, 104)
                }
            }
            .padding(.top, 4)
        }
        .disabled(true)
        .allowsHitTesting(false)
    }

    private var idlePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text("What are you in the mood for?")
                .font(.title3.weight(.medium))
            Text("Describe a vibe, genre, or film")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = false }
    }

    // MARK: - Bottom input bar

    private var bottomInputBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)

                TextField("Mood, genre, film…", text: $viewModel.query)
                    .focused($inputFocused)
                    .submitLabel(.done)
                    .onSubmit { fetchIfReady() }
                    .disabled(viewModel.isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(glowBorder)
            .shadow(
                color: viewModel.isLoading ? .purple.opacity(0.35) : .clear,
                radius: 10
            )
            .animation(.easeInOut(duration: 0.4), value: viewModel.isLoading)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(.background)
    }

    @ViewBuilder
    private var glowBorder: some View {
        if viewModel.isLoading {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let angle = (t.truncatingRemainder(dividingBy: 2.5) / 2.5) * 360
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        AngularGradient(
                            colors: [.purple, .blue, .cyan, .teal, .pink, .purple],
                            center: .center,
                            startAngle: .degrees(angle),
                            endAngle: .degrees(angle + 360)
                        ),
                        lineWidth: 2
                    )
            }
            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        }
    }

    private func fetchIfReady() {
        guard let chatId = chatStore.selectedChat?.chatId,
              !viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        inputFocused = false
        Task { await viewModel.fetchRecommendations(chatId: chatId) }
    }

    // MARK: - Helpers

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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


// MARK: - SuggestionCard

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
