import SwiftUI

// MARK: - Shimmer band modifier

struct ShimmerBand: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    TimelineView(.animation) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        let phase = CGFloat((t.truncatingRemainder(dividingBy: 1.4)) / 1.4)
                        let bandWidth = geo.size.width * 0.45
                        let offset = phase * (geo.size.width + bandWidth) - bandWidth

                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.35), location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: bandWidth)
                        .offset(x: offset)
                    }
                }
                .clipped()
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerBand())
    }
}

// MARK: - Style

enum ShimmerStyle {
    /// For You / Recommendations — horizontal, 80×120 poster, title, year, rating, 3-line description, add button
    case recommendations
    /// Search — horizontal, 80×120 poster, title, year, rating, add button
    case search
    /// Watchlist list — horizontal, 100×150 poster, title, year, rating, addedBy, runtime
    case watchlistRow
    /// Watchlist 2-column grid — vertical, full-width 2:3 poster, title, year + rating row
    case watchlistTile
    /// Watchlist large grid — horizontal, 110×165 poster, title, year + rating row, director, 4-line overview
    case watchlistLarge
}

// MARK: - ShimmerCard

struct ShimmerCard: View {
    let style: ShimmerStyle

    var body: some View {
        switch style {
        case .recommendations: recommendationsCard
        case .search:          searchCard
        case .watchlistRow:    watchlistRowCard
        case .watchlistTile:   watchlistTileCard
        case .watchlistLarge:  watchlistLargeCard
        }
    }

    // MARK: Recommendations

    private var recommendationsCard: some View {
        HStack(alignment: .top, spacing: 12) {
            poster(width: 80, height: 120, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 0) {
                titleLine(height: 14)
                Spacer().frame(height: 10)
                pill(width: 50, height: 12)   // year
                Spacer().frame(height: 8)
                pill(width: 40, height: 12)   // rating
                Spacer().frame(height: 10)
                descriptionLines(count: 3, lastWidth: 90)
                Spacer(minLength: 0)
                Spacer().frame(height: 10)
                addButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Search

    private var searchCard: some View {
        HStack(alignment: .top, spacing: 12) {
            poster(width: 80, height: 120, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 0) {
                titleLine(height: 14)
                Spacer().frame(height: 10)
                pill(width: 50, height: 12)   // year
                Spacer().frame(height: 8)
                pill(width: 40, height: 12)   // rating
                Spacer(minLength: 0)
                Spacer().frame(height: 10)
                addButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: Watchlist row

    private var watchlistRowCard: some View {
        HStack(alignment: .top, spacing: 12) {
            poster(width: 100, height: 150, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 5) {
                titleLine(height: 16)
                pill(width: 50, height: 13)   // year
                pill(width: 40, height: 13)   // rating
                pill(width: 80, height: 11)   // addedBy
                pill(width: 60, height: 11)   // runtime
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Watchlist tile (vertical)

    private var watchlistTileCard: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.15))
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .shimmer()
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                pill(width: .infinity, height: 11)   // title

                HStack(spacing: 6) {
                    pill(width: 35, height: 10)   // year
                    pill(width: 30, height: 10)   // rating
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Watchlist large

    private var watchlistLargeCard: some View {
        HStack(alignment: .top, spacing: 14) {
            poster(width: 110, height: 165, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 0) {
                titleLine(height: 16)
                Spacer().frame(height: 8)

                HStack(spacing: 8) {
                    pill(width: 50, height: 13)   // year
                    pill(width: 40, height: 13)   // rating
                }

                Spacer().frame(height: 8)
                pill(width: 80, height: 11)       // director
                Spacer().frame(height: 6)
                descriptionLines(count: 4, lastWidth: 100)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: Shared sub-views

    private func poster(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.secondary.opacity(0.15))
            .frame(width: width, height: height)
            .shimmer()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func titleLine(height: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.15))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .shimmer()
            .clipShape(Capsule())
    }

    private func pill(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.12))
            .frame(width: width == .infinity ? nil : width, height: height)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
            .shimmer()
            .clipShape(Capsule())
    }

    private func descriptionLines(count: Int, lastWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: count == 4 ? 4 : 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: i == count - 1 ? lastWidth : nil, height: 11)
                    .frame(maxWidth: i == count - 1 ? nil : .infinity)
                    .shimmer()
                    .clipShape(Capsule())
            }
        }
    }

    private var addButton: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.12))
            .frame(width: 72, height: 29)
            .shimmer()
            .clipShape(Capsule())
    }
}
