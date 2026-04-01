import SwiftUI

struct MovieCardRow: View {
    let movie: Movie

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .overlay(Image(systemName: "film").foregroundStyle(.secondary))
            }
            .frame(width: 100, height: 150)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                if let year = movie.year {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let rating = movie.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", rating))
                            .font(.subheadline)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
