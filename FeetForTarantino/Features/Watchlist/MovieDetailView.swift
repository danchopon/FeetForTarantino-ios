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
                .frame(height: 360)
                .clipped()

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
        .navigationTitle(movie.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formattedDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }
        return isoString
    }
}
