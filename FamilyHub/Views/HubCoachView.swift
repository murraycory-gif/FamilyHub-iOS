import SwiftUI

struct CoachAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
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
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { active ? [id: $0] : [:] }
            .id(id)
    }

    func hubTour(_ page: String, steps: [CoachStep], onStep: ((String) -> Void)? = nil) -> some View {
        modifier(HubTourModifier(page: page, steps: steps, onStep: onStep))
    }
}

private struct HubTourModifier: ViewModifier {
    let page: String
    let steps: [CoachStep]
    var onStep: ((String) -> Void)?
    @AppStorage("familyhub.tours.v2") private var completed = ""

    private var done: Set<String> {
        Set(completed.split(separator: ",").map(String.init))
    }

    func body(content: Content) -> some View {
        content
            .overlayPreferenceValue(CoachAnchorKey.self) { anchors in
                GeometryReader { geo in
                    if !done.contains(page), !steps.isEmpty {
                        let rects = Dictionary(uniqueKeysWithValues: anchors.map { ($0.key, geo[$0.value]) })
                        HubCoachLayer(
                            rects: rects,
                            canvas: geo.size,
                            safe: geo.safeAreaInsets,
                            steps: steps,
                            onStep: onStep
                        ) {
                            mark()
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(!done.contains(page))
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
    let canvas: CGSize
    let safe: EdgeInsets
    let steps: [CoachStep]
    var onStep: ((String) -> Void)?
    var onDone: () -> Void
    @State private var step = 0
    @State private var showBubble = false

    var body: some View {
        let current = steps[min(step, steps.count - 1)]
        let hole = padded(rects[current.id])
        ZStack(alignment: .topLeading) {
            SpotlightDim(hole: hole)
                .onTapGesture { advance() }
            if hole != .null {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 3)
                    .frame(width: hole.width, height: hole.height)
                    .offset(x: hole.minX, y: hole.minY)
                    .allowsHitTesting(false)
            }
            if showBubble {
                callout(for: hole, step: current)
            }
        }
        .onAppear { focus(current.id) }
        .onChange(of: step) { _, _ in
            focus(steps[min(step, steps.count - 1)].id)
        }
    }

    private func focus(_ id: String) {
        showBubble = false
        onStep?(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.2)) { showBubble = true }
        }
    }

    private func padded(_ rect: CGRect?) -> CGRect {
        guard let rect, rect.width > 8, rect.height > 8 else { return .null }
        return rect.insetBy(dx: -4, dy: -4)
    }

    private func callout(for hole: CGRect, step: CoachStep) -> some View {
        let width = min(340, max(260, canvas.width - safe.leading - safe.trailing - 48))
        let bubbleH: CGFloat = 200
        let place = placement(hole: hole, width: width, height: bubbleH)

        return VStack(spacing: 0) {
            if place.arrow == .up {
                CoachArrow()
                    .fill(AppTheme.card)
                    .frame(width: 22, height: 12)
                    .offset(x: place.arrowX - width / 2)
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
                        .lineLimit(1)
                }
                Text(step.detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
            if place.arrow == .down {
                CoachArrow()
                    .fill(AppTheme.card)
                    .frame(width: 22, height: 12)
                    .rotationEffect(.degrees(180))
                    .offset(x: place.arrowX - width / 2)
            }
        }
        .offset(x: place.x, y: place.y)
        .animation(.easeInOut(duration: 0.25), value: self.step)
    }

    private struct Place {
        var x: CGFloat
        var y: CGFloat
        var arrow: Arrow
        var arrowX: CGFloat
        enum Arrow { case up, down, none }
    }

    private func placement(hole: CGRect, width: CGFloat, height: CGFloat) -> Place {
        let top = safe.top + 12
        let bottom = canvas.height - safe.bottom - 12
        let left = safe.leading + 12
        let right = canvas.width - safe.trailing - 12
        func clampX(_ raw: CGFloat) -> CGFloat { min(max(left, raw), max(left, right - width)) }
        func clampY(_ raw: CGFloat) -> CGFloat { min(max(top, raw), max(top, bottom - height)) }
        func arrowX(for x: CGFloat) -> CGFloat {
            guard hole != .null else { return width / 2 }
            return min(max(24, hole.midX - x), width - 24)
        }

        if hole == .null {
            return Place(x: clampX((canvas.width - width) / 2), y: clampY(canvas.height * 0.28), arrow: .none, arrowX: width / 2)
        }

        let spaceBelow = bottom - hole.maxY
        let spaceAbove = hole.minY - top
        let spaceLeft = hole.minX - left
        let spaceRight = right - hole.maxX

        if spaceBelow >= height + 16 {
            let x = clampX(hole.midX - width / 2)
            return Place(x: x, y: hole.maxY + 10, arrow: .up, arrowX: arrowX(for: x))
        }
        if spaceAbove >= height + 16 {
            let x = clampX(hole.midX - width / 2)
            return Place(x: x, y: hole.minY - height - 10, arrow: .down, arrowX: arrowX(for: x))
        }
        if spaceLeft >= width + 16 {
            return Place(x: hole.minX - 16 - width, y: clampY(hole.midY - height / 2), arrow: .none, arrowX: width / 2)
        }
        if spaceRight >= width + 16 {
            return Place(x: hole.maxX + 16, y: clampY(hole.midY - height / 2), arrow: .none, arrowX: width / 2)
        }
        let y = hole.midY > (top + bottom) / 2 ? top : bottom - height
        return Place(x: clampX(hole.midX - width / 2), y: clampY(y), arrow: .none, arrowX: width / 2)
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
            context.fill(path, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
        }
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
        .init(id: "agenda", symbol: "calendar", title: "On Today's Agenda", detail: "Today’s events and Bills Due for the family. Swipe this top row to change days."),
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
        .init(id: "listKind", symbol: "list.bullet.rectangle", title: "Reminders and to-dos", detail: "Flip between reminders and to-dos. Bills Due from your bills calendar lives here."),
        .init(id: "listBody", symbol: "checkmark.square", title: "The list", detail: "Tap an item to complete it. Use + to add one for anyone in the house.")
    ]

    static let shopping: [CoachStep] = [
        .init(id: "shopHeader", symbol: "cart.fill", title: "Shopping list", detail: "Clear all when you are done. Dinner ingredients land here when you add them."),
        .init(id: "shopAdd", symbol: "plus", title: "Add something", detail: "Type it and hit return. Tap a row to check it off at the store.")
    ]

    static let meals: [CoachStep] = [
        .init(id: "mealHeader", symbol: "fork.knife", title: "Meal Planning", detail: "Two weeks of dinners. Tonight, tomorrow, and the rest of the plan."),
        .init(id: "mealWeek", symbol: "square.grid.2x2.fill", title: "Pick a day", detail: "Tap a day to plan it. Swipe a filled day to clear it.")
    ]

    static let settings: [CoachStep] = [
        .init(id: "setProfiles", symbol: "person.3.fill", title: "Profiles", detail: "Everyone in the house. Add, edit, or delete a person here."),
        .init(id: "setCalendars", symbol: "calendar.badge.plus", title: "Calendars", detail: "Connect iCloud, Google, or Outlook. Bills calendars live in Bills Due."),
        .init(id: "setBills", symbol: "dollarsign.circle.fill", title: "Bills Due", detail: "Pick your bills calendar here. Those dates become Bills Due reminders."),
        .init(id: "setAllow", symbol: "banknote.fill", title: "Allowance", detail: "Kid balances and payouts live here, not on HUB Profiles."),
        .init(id: "setWeather", symbol: "cloud.sun.fill", title: "Weather", detail: "Set the city and every measurement HUB should use."),
        .init(id: "setNotify", symbol: "bell.fill", title: "Notifications", detail: "Turn pings on or off. Enter a phone number to connect texts.")
    ]

    static let family: [CoachStep] = [
        .init(id: "famHeader", symbol: "person.3.fill", title: "HUB Profiles", detail: "Everyone in the house. Each person has a color, photo, and their own profile."),
        .init(id: "famPeople", symbol: "person.crop.circle", title: "The people", detail: "Tap a person to open their profile. Add someone with the plus on a card.")
    ]

    static let weather: [CoachStep] = [
        .init(id: "wxHero", symbol: "cloud.sun.fill", title: "Full forecast", detail: "Swipe between days. Hours, highs, and details for the day you picked."),
        .init(id: "wxDays", symbol: "calendar", title: "Coming days", detail: "Tap a day or swipe to move through the week.")
    ]

    static let dinnerPick: [CoachStep] = [
        .init(id: "pickTitle", symbol: "fork.knife", title: "What's For Dinner", detail: "Eating out, family recipes, the cookbook, or type a meal. Pick one path."),
        .init(id: "pickGrid", symbol: "square.grid.2x2", title: "Your options", detail: "Family recipes save scans and TikTok links. Recipes is the full cookbook.")
    ]

    static let recipes: [CoachStep] = [
        .init(id: "recHeader", symbol: "fork.knife.circle.fill", title: "All Recipes", detail: "Search and filter. Tap a dish for ingredients, cook method, and add for dinner.")
    ]

    static let sides: [CoachStep] = [
        .init(id: "sideHeader", symbol: "leaf.fill", title: "Pick a side", detail: "Same layout as recipes. Skip if you don’t want a side tonight.")
    ]

    static let eatOut: [CoachStep] = [
        .init(id: "eatHeader", symbol: "fork.knife", title: "Places nearby", detail: "Uses your city or ZIP. Tap a place for hours, menu, and to set it as dinner.")
    ]

    static let tonight: [CoachStep] = [
        .init(id: "tonHeader", symbol: "fork.knife", title: "Dinner is set", detail: "Ingredients and steps. Delete or Change Meal live in the header.")
    ]

    static let calendars: [CoachStep] = [
        .init(id: "srcBills", symbol: "dollarsign.circle.fill", title: "Bills Due", detail: "Pick the bills calendar so those dates become reminders, not family events."),
        .init(id: "srcList", symbol: "calendar.badge.plus", title: "Connected calendars", detail: "Turn on iCloud, Google, or Outlook calendars and assign them to a person.")
    ]
}
