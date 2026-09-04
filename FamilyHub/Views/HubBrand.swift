import SwiftUI

struct HubOrbitMark: View {
    var size: CGFloat = 72
    var animated: Bool = true

    private let dots: [(Color, Double, Double)] = [
        (Color(hex: "00D4FF"), 0.00, 1.20),
        (Color(hex: "FFC14A"), 0.28, 1.55),
        (Color(hex: "FF3EC8"), 0.55, 0.95),
        (Color(hex: "3DFF7A"), 0.80, 1.80),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: animated ? 1 / 24 : 60, paused: !animated)) { timeline in
            let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 0.35
            canvas(t)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("HUB Circle")
    }

    private func canvas(_ t: TimeInterval) -> some View {
        let pull = 0.84 + 0.16 * sin(t * 1.4)
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.blue.opacity(0.55), AppTheme.blue.opacity(0.08), .clear],
                        center: .center,
                        startRadius: size * 0.08,
                        endRadius: size * 0.52
                    )
                )
            Circle()
                .stroke(AppTheme.blue.opacity(0.22), lineWidth: max(1, size * 0.018))
                .frame(width: size * 0.92, height: size * 0.92)
            Circle()
                .stroke(AppTheme.blue.opacity(0.38), lineWidth: max(1, size * 0.02))
                .frame(width: size * 0.68, height: size * 0.68)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.95), AppTheme.blue, AppTheme.blueDeep],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.22
                    )
                )
                .frame(width: size * 0.34, height: size * 0.34)
                .shadow(color: AppTheme.blue.opacity(0.45), radius: size * 0.06)

            ForEach(Array(dots.enumerated()), id: \.offset) { _, spec in
                let angle = (spec.1 + t / spec.2) * .pi * 2
                let radius = size * 0.36 * pull
                Circle()
                    .fill(spec.0)
                    .frame(width: max(5, size * 0.09), height: max(5, size * 0.09))
                    .shadow(color: spec.0.opacity(0.7), radius: 3)
                    .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            }
        }
    }
}

struct HubWordmark: View {
    var stacked: Bool = true
    var hubSize: CGFloat = 28
    var circleSize: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: -2) {
            Text("HUB")
                .font(.system(size: hubSize, weight: .heavy))
                .foregroundStyle(AppTheme.text)
                .tracking(0.6)
            Text("Circle")
                .font(.system(size: circleSize, weight: .medium))
                .foregroundStyle(AppTheme.blue)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

struct HubBrandLockup: View {
    var markSize: CGFloat = 52
    var animated: Bool = true
    var hubSize: CGFloat = 26
    var circleSize: CGFloat = 18

    var body: some View {
        HStack(spacing: 10) {
            HubOrbitMark(size: markSize, animated: animated)
            HubWordmark(hubSize: hubSize, circleSize: circleSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HUB Circle")
    }
}
