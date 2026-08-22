import SwiftUI

struct CoachRectsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct CoachStep: Identifiable, Equatable {
    var id: String
    var symbol: String
    var title: String
    var detail: String
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

    func hubTour(_ page: String, steps: [CoachStep]) -> some View {
        modifier(HubTourModifier(page: page, steps: steps))
    }
}

private struct HubTourModifier: ViewModifier {
    let page: String
    let steps: [CoachStep]
    @AppStorage("familyhub.tours.v1") private var completed = ""

    private var done: Set<String> {
        Set(completed.split(separator: ",").map(String.init))
    }

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: "hubCoach")
            .overlayPreferenceValue(CoachRectsKey.self) { rects in
                if !done.contains(page) {
                    HubCoachLayer(rects: rects, steps: steps) {
                        mark()
                    }
                }
            }
    }

    private func mark() {
        var next = done
        next.insert(page)
        completed = next.sorted().joined(separator: ",")
    }
}

struct HubCoachLayer: View {
    let rects: [String: CGRect]
    let steps: [CoachStep]
    var onDone: () -> Void
    @State private var step = 0

    var body: some View {
        let current = steps[min(step, max(steps.count - 1, 0))]
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
                if !steps.isEmpty {
                    callout(for: hole, in: geo.size, step: current)
                }
            }
        }
        .allowsHitTesting(true)
    }

    private func padded(_ rect: CGRect?) -> CGRect {
        guard let rect, rect.width > 8, rect.height > 8 else { return .null }
        return rect.insetBy(dx: -8, dy: -8)
    }

    private func callout(for hole: CGRect, in size: CGSize, step: CoachStep) -> some View {
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

enum HubTours {
    static let hub: [CoachStep] = [
        .init(id: "hub", symbol: "house.fill", title: "This is the Hub", detail: "The whole board. Agenda, weather, dinner, and family live on this one screen."),
        .init(id: "agenda", symbol: "calendar", title: "On Today's Agenda", detail: "Today’s events for whoever is selected. Bills Due reminders show here for the family, not on each person’s calendar."),
        .init(id: "weather", symbol: "cloud.sun.fill", title: "Weather", detail: "Tap for the full forecast. Location and units are in Settings."),
        .init(id: "dinner", symbol: "fork.knife", title: "What's For Dinner", detail: "Tap to plan tonight. Saved family recipes, TikTok links, and sides live here."),
        .init(id: "family", symbol: "person.3.fill", title: "Family cards", detail: "Tap a person to color the board. Tap an event on their card to open the calendar.")
    ]

    static let calendar: [CoachStep] = [
        .init(id: "calHeader", symbol: "calendar", title: "Family Calendar", detail: "Filter who you are looking at, or tap Add to put something on the calendar."),
        .init(id: "calGrid", symbol: "square.grid.2x2", title: "The month", detail: "Color dots are whose event it is. Tap a day to see everything on that date."),
        .init(id: "calList", symbol: "list.bullet", title: "That day’s events", detail: "Tap an event for the full details. Changes sync back to the linked calendar.")
    ]

    static let chores: [CoachStep] = [
        .init(id: "chorePay", symbol: "dollarsign.circle", title: "Allowance", detail: "Each kid’s balance lives here. Approved chores add to it."),
        .init(id: "choreBoard", symbol: "checkmark.circle.fill", title: "Assigned", detail: "Kids check work off. You approve it, then it can hit their allowance."),
        .init(id: "choreCatalog", symbol: "list.bullet", title: "Chore catalog", detail: "Build the list of jobs and tap Assign to hand one out.")
    ]

    static let lists: [CoachStep] = [
        .init(id: "listKind", symbol: "list.bullet.rectangle", title: "Reminders and to-dos", detail: "Flip between reminders and to-dos. Bills Due from your bills calendar lives here, not on the family calendar."),
        .init(id: "listBody", symbol: "checkmark.square", title: "The list", detail: "Tap an item to complete it. Use + to add one for anyone in the house.")
    ]

    static let shopping: [CoachStep] = [
        .init(id: "shopHeader", symbol: "cart.fill", title: "Shopping list", detail: "Clear all when you are done. Dinner ingredients land here when you add them."),
        .init(id: "shopAdd", symbol: "plus", title: "Add something", detail: "Type it and hit return. Tap a row to check it off at the store.")
    ]

    static let meals: [CoachStep] = [
        .init(id: "mealHeader", symbol: "fork.knife", title: "Meal Planning", detail: "Two weeks of dinners. Tonight, tomorrow, and the rest of the plan."),
        .init(id: "mealWeek", symbol: "square.grid.2x2.fill", title: "Pick a day", detail: "Tap a day to plan it. Swipe a filled day to clear it. Recipes you save stay in Family Recipes.")
    ]

    static let settings: [CoachStep] = [
        .init(id: "setHouse", symbol: "gearshape.fill", title: "Household", detail: "Open this box for HUB Profiles, calendars, who is signed in, and the family join code."),
        .init(id: "setBills", symbol: "dollarsign.circle.fill", title: "Bills Due", detail: "If you have a bills calendar, pick it here. Those dates become Bills Due reminders and stay off family calendars."),
        .init(id: "setWeather", symbol: "cloud.sun.fill", title: "Weather", detail: "Set the city and every measurement HUB should use.")
    ]

    static let family: [CoachStep] = [
        .init(id: "famHeader", symbol: "person.3.fill", title: "HUB Profiles", detail: "Everyone in the house. Each person has a color, photo, and their own profile."),
        .init(id: "famPeople", symbol: "person.crop.circle", title: "The people", detail: "Tap a person to open their profile. Add someone with the plus on a card.")
    ]
}
