import SwiftUI

struct MovieCardLarge: View {
    let movie: Movie

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: movie.posterURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .overlay(Image(systemName: "film").foregroundStyle(.secondary))
            }
            .frame(width: 110, height: 165)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let year = movie.year {
                        Text(String(year))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let rating = movie.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline)
                        }
                    }
                }

                if let director = movie.director {
                    Label(director, systemImage: "camera")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let overview = movie.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
