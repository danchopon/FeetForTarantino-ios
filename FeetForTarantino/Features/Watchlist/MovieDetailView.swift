import SwiftUI

struct MovieDetailView: View {
    let movie: Movie

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AsyncImage(url: movie.posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay(
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        )
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 420)
                .clipped()
                .ignoresSafeArea(.all, edges: .top)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let year = movie.year {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 16) {
                        if let rating = movie.rating {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .fontWeight(.semibold)
                                Text("/ 10")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }

                        if let runtime = movie.formattedRuntime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                Text(runtime)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let director = movie.director {
                        Label(director, systemImage: "camera")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let overview = movie.overview {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Overview")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(overview)
                                .font(.body)
                        }
                    }

                    Divider()

                    if let status = movie.status {
                        LabeledContent("Status") {
                            Text(status == "to_watch" ? "To Watch" : "Watched")
                                .foregroundStyle(status == "to_watch" ? .blue : .green)
                                .fontWeight(.medium)
                        }
                    }

                    if let addedBy = movie.addedBy {
                        LabeledContent("Added by") {
                            Text(addedBy)
                        }
                    }

                    if let addedAt = movie.addedAt {
                        LabeledContent("Added") {
                            Text(formattedDate(addedAt))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let watchedBy = movie.watchedBy {
                        LabeledContent("Watched by") {
                            Text(watchedBy)
                        }
                    }

                    if let watchedAt = movie.watchedAt {
                        LabeledContent("Watched") {
                            Text(formattedDate(watchedAt))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        }
        return isoString
    }
}
