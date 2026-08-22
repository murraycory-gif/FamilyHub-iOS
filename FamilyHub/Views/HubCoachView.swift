import SwiftUI

struct CoachRectsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func coachSpot(_ id: String, active: Bool = true) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: CoachRectsKey.self,
                    value: active ? [id: geo.frame(in: .named("hubCoach"))] : [:]
                )
            }
        }
    }
}

struct HubCoachLayer: View {
    let rects: [String: CGRect]
    var onDone: () -> Void
    @State private var step = 0

    private let steps: [(id: String, symbol: String, title: String, detail: String)] = [
        ("hub", "house.fill", "This is the Hub", "The whole board. Agenda, weather, dinner, and family live on this one screen."),
        ("agenda", "calendar", "On Today's Agenda", "Today’s events for whoever is selected. Swipe this top row to change days."),
        ("weather", "cloud.sun.fill", "Weather", "Tap for the full forecast. Location and units are in Settings."),
        ("dinner", "fork.knife", "What's For Dinner", "Tap to plan tonight. Saved family recipes, TikTok links, and sides live here."),
        ("family", "person.3.fill", "Family cards", "Tap a person to color the board. Tap an event on their card to open the calendar.")
    ]

    var body: some View {
        let current = steps[min(step, steps.count - 1)]
        let hole = padded(rects[current.id])
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                SpotlightDim(hole: hole)
                    .ignoresSafeArea()
                    .onTapGesture { advance() }
                if hole != .null {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 3)
                        .frame(width: hole.width, height: hole.height)
                        .position(x: hole.midX, y: hole.midY)
                        .allowsHitTesting(false)
                }
                callout(for: hole, in: geo.size, step: current)
            }
        }
        .allowsHitTesting(true)
    }

    private func padded(_ rect: CGRect?) -> CGRect {
        guard let rect, rect.width > 8, rect.height > 8 else { return .null }
        return rect.insetBy(dx: -8, dy: -8)
    }

    private func callout(for hole: CGRect, in size: CGSize, step: (id: String, symbol: String, title: String, detail: String)) -> some View {
        let width = min(380, size.width - 32)
        let putBelow: Bool = {
            guard hole != .null else { return true }
            let below = size.height - hole.maxY
            return below >= 210 || below >= hole.minY
        }()
        let x: CGFloat = {
            guard hole != .null else { return 16 }
            return min(max(16, hole.midX - width / 2), size.width - width - 16)
        }()
        let arrowX: CGFloat = {
            guard hole != .null else { return width / 2 }
            return min(max(24, hole.midX - x), width - 24)
        }()
        let y: CGFloat = {
            guard hole != .null else { return 80 }
            if putBelow { return min(hole.maxY + 10, size.height - 220) }
            return max(12, hole.minY - 200)
        }()

        return VStack(spacing: 0) {
            if putBelow {
                CoachArrow()
                    .fill(AppTheme.card)
                    .frame(width: 22, height: 12)
                    .offset(x: arrowX - width / 2)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { index in
                        Capsule()
                            .fill(index <= self.step ? AppTheme.blue : AppTheme.blueSoft)
                            .frame(height: 5)
                    }
                }
                HStack(spacing: 10) {
                    Image(systemName: step.symbol)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text(step.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                }
                Text(step.detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    Button("Skip") { onDone() }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Button(self.step == steps.count - 1 ? "Got it" : "Next") { advance() }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(AppTheme.blue, in: Capsule())
                }
            }
            .padding(16)
            .frame(width: width, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 3)
            )
            if !putBelow {
                CoachArrow()
                    .fill(AppTheme.card)
                    .frame(width: 22, height: 12)
                    .rotationEffect(.degrees(180))
                    .offset(x: arrowX - width / 2)
            }
        }
        .offset(x: x, y: y)
        .animation(.easeInOut(duration: 0.25), value: self.step)
    }

    private func advance() {
        if step >= steps.count - 1 { onDone() } else { withAnimation { step += 1 } }
    }
}

private struct SpotlightDim: View {
    let hole: CGRect

    var body: some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            if hole != .null {
                path.addPath(Path(roundedRect: hole, cornerRadius: 22))
            }
            context.fill(path, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
        }
        .allowsHitTesting(true)
    }
}

private struct CoachArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
