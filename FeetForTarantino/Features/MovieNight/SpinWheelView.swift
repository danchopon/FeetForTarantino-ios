import SwiftUI

struct SpinWheelView: View {
    let items: [WheelItem]

    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var winner: WheelItem?
    @State private var spinDuration: Double = 5
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Winner banner
                ZStack {
                    if let w = winner {
                        winnerBanner(w)
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.4), value: winner?.id)
                .frame(minHeight: 64)

                Spacer(minLength: 8)

                // Wheel + pointer
                ZStack(alignment: .top) {
                    WheelCanvas(items: items)
                        .rotationEffect(.degrees(rotation))
                        .frame(width: 290, height: 290)
                        .padding(.top, 24)

                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.primary)
                }
                .frame(height: 330)

                Spacer(minLength: 12)

                // Spin duration
                VStack(spacing: 6) {
                    Text("Duration: \(Int(spinDuration)) sec")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Slider(value: $spinDuration, in: 2...10, step: 1)
                        .padding(.horizontal, 32)
                        .disabled(isSpinning)
                }

                Spacer(minLength: 20)

                // Buttons
                HStack(spacing: 16) {
                    Button(action: resetWheel) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSpinning)

                    Button(action: spin) {
                        Label(isSpinning ? "Spinning…" : "Spin!", systemImage: "rays")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSpinning || items.isEmpty)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Spin the Wheel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Spin logic

    private func spin() {
        guard !isSpinning, !items.isEmpty else { return }
        isSpinning = true
        winner = nil

        // Pick winner weighted by percentage
        let rand = Double.random(in: 0..<1)
        var cumulative = 0.0
        var picked = items[0]
        for item in items {
            cumulative += item.percentage
            if rand < cumulative { picked = item; break }
        }

        // Calculate the mid-angle of the picked slice in wheel-space
        // Wheel-space: 0° = top (12 o'clock), increases clockwise
        var startDeg = 0.0
        for item in items {
            if item.id == picked.id { break }
            startDeg += item.percentage * 360
        }
        let midDeg = startDeg + picked.percentage * 180

        // We want midDeg to appear at the pointer (top = 0° in wheel-space).
        // When wheel is rotated by R, the angle at the top is: (360 - R % 360) % 360
        // So we need: (360 - finalRot % 360) % 360 == midDeg
        //             finalRot % 360 == (360 - midDeg).truncatingRemainder(dividingBy: 360)
        let targetMod = (360 - midDeg).truncatingRemainder(dividingBy: 360)
        let currentMod = rotation.truncatingRemainder(dividingBy: 360)
        var delta = targetMod - currentMod
        if delta <= 0 { delta += 360 }

        let extraSpins = ceil(spinDuration * 1.2) * 360
        let finalRotation = rotation + delta + extraSpins

        withAnimation(.timingCurve(0.15, 0.9, 0.25, 1.0, duration: spinDuration)) {
            rotation = finalRotation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration + 0.15) {
            winner = picked
            isSpinning = false
        }
    }

    private func resetWheel() {
        withAnimation(.spring(duration: 0.5)) {
            rotation = 0
        }
        winner = nil
    }

    // MARK: - Winner banner

    private func winnerBanner(_ item: WheelItem) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.color)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tonight's pick")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption)
                Text("\(item.votes) vote\(item.votes == 1 ? "" : "s")")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
        }
        .padding(12)
        .background(item.color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Wheel Canvas

struct WheelCanvas: View {
    let items: [WheelItem]

    var body: some View {
        Canvas { ctx, size in
            guard !items.isEmpty else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            var currentAngle = -Double.pi / 2  // start from top (12 o'clock)

            for item in items {
                let sliceAngle = 2 * Double.pi * item.percentage
                let endAngle = currentAngle + sliceAngle

                // Fill slice
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                            startAngle: .radians(currentAngle),
                            endAngle: .radians(endAngle),
                            clockwise: false)
                path.closeSubpath()
                ctx.fill(path, with: .color(item.color))

                // Stroke border
                ctx.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 1.5)

                // Text label at slice midpoint
                let midAngle = currentAngle + sliceAngle / 2
                let labelDist = radius * 0.62
                let labelX = center.x + labelDist * Foundation.cos(midAngle)
                let labelY = center.y + labelDist * Foundation.sin(midAngle)

                let pct = Int(item.percentage * 100)

                if item.percentage > 0.06 {
                    let pctText = ctx.resolve(
                        Text("\(pct)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    )
                    ctx.draw(pctText, at: CGPoint(x: labelX, y: item.percentage > 0.12 ? labelY - 7 : labelY))

                    if item.percentage > 0.12 {
                        let shortTitle = String(item.title.prefix(9))
                        let titleText = ctx.resolve(
                            Text(shortTitle)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        )
                        ctx.draw(titleText, at: CGPoint(x: labelX, y: labelY + 7))
                    }
                }

                currentAngle = endAngle
            }

            // Center cap
            let capR: CGFloat = 12
            let capPath = Path(ellipseIn: CGRect(
                x: center.x - capR, y: center.y - capR,
                width: capR * 2, height: capR * 2
            ))
            ctx.fill(capPath, with: .color(Color(.systemBackground)))
            ctx.stroke(capPath, with: .color(.white.opacity(0.6)), lineWidth: 1)
        }
    }
}
