import SwiftUI

struct HubOrbitMark: View {
    var size: CGFloat = 72
    var animated: Bool = true

    private struct BodyDot: Identifiable {
        let id: Int
        let color: Color
        let start: Double
        let speed: Double
        let tilt: Double
        let radius: CGFloat
    }

    private let dots: [BodyDot] = [
        .init(id: 0, color: Color(hex: "4DE2FF"), start: 0.05, speed: 1.15, tilt: -18, radius: 0.42),
        .init(id: 1, color: Color(hex: "FFC14A"), start: 0.22, speed: 1.55, tilt: 28, radius: 0.36),
        .init(id: 2, color: Color(hex: "FF4ED2"), start: 0.48, speed: 0.95, tilt: 12, radius: 0.44),
        .init(id: 3, color: Color(hex: "5CFF7A"), start: 0.70, speed: 1.35, tilt: -8, radius: 0.40),
        .init(id: 4, color: Color(hex: "7AB8FF"), start: 0.88, speed: 1.75, tilt: 35, radius: 0.32),
        .init(id: 5, color: Color(hex: "FF8AD8"), start: 0.33, speed: 1.05, tilt: -30, radius: 0.38),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: animated ? 1 / 24 : 60, paused: !animated)) { timeline in
            let t = animated ? timeline.date.timeIntervalSinceReferenceDate : 0.8
            canvas(t)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("HUB Circle")
    }

    private func canvas(_ t: TimeInterval) -> some View {
        let pull = 0.88 + 0.12 * sin(t * 1.15)
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "00A8FF").opacity(0.35), Color(hex: "06101C").opacity(0.0)],
                        center: .center,
                        startRadius: size * 0.02,
                        endRadius: size * 0.5
                    )
                )
            ForEach(0..<3, id: \.self) { ring in
                Ellipse()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: "00A8FF").opacity(0.15),
                                Color(hex: "7AB8FF").opacity(0.55),
                                Color(hex: "FF4ED2").opacity(0.25),
                                Color(hex: "00A8FF").opacity(0.15),
                            ],
                            center: .center
                        ),
                        lineWidth: max(1, size * 0.018)
                    )
                    .frame(width: size * (0.78 - CGFloat(ring) * 0.12), height: size * (0.52 - CGFloat(ring) * 0.06))
                    .rotationEffect(.degrees(Double(ring) * 32 + t * 8))
            }
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color(hex: "4DE2FF"), Color(hex: "0066C2")],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.2
                    )
                )
                .frame(width: size * 0.30, height: size * 0.30)
                .shadow(color: Color(hex: "00A8FF").opacity(0.9), radius: size * 0.08)

            ForEach(dots) { spec in
                let angle = (spec.start + t / spec.speed) * .pi * 2
                let radius = size * spec.radius * pull
                let x = cos(angle) * radius
                let y = sin(angle) * radius * 0.62
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [spec.color.opacity(0), spec.color.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: size * 0.22, height: max(2, size * 0.03))
                        .rotationEffect(.radians(angle + .pi / 2))
                        .offset(x: x * 0.82, y: y * 0.82)
                    Circle()
                        .fill(spec.color)
                        .frame(width: max(5, size * 0.08), height: max(5, size * 0.08))
                        .shadow(color: spec.color, radius: 4)
                        .offset(x: x, y: y)
                }
                .rotationEffect(.degrees(spec.tilt))
            }
        }
    }
}

struct HubWordmark: View {
    var onDark: Bool = false
    var hubSize: CGFloat = 28
    var circleSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HUB")
                .font(.system(size: hubSize, weight: .heavy))
                .foregroundStyle(onDark ? Color.white : AppTheme.text)
                .tracking(1.2)
            Rectangle()
                .fill((onDark ? Color.white : AppTheme.blue).opacity(0.55))
                .frame(width: hubSize * 1.55, height: 1.5)
            Text("Circle")
                .font(.system(size: circleSize, weight: .regular))
                .foregroundStyle(onDark ? Color.white.opacity(0.82) : AppTheme.blue)
                .tracking(3.2)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

struct HubBrandLockup: View {
    var markSize: CGFloat = 52
    var animated: Bool = true
    var hubSize: CGFloat = 26
    var circleSize: CGFloat = 16
    var onDark: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            HubOrbitMark(size: markSize, animated: animated)
            HubWordmark(onDark: onDark, hubSize: hubSize, circleSize: circleSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HUB Circle")
    }
}
