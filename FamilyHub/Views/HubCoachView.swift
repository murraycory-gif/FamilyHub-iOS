import SwiftUI

struct HubCoachView: View {
    var onDone: () -> Void
    @State private var step = 0

    private let steps: [(String, String, String)] = [
        ("house.fill", "This is the Hub", "The board for today. Agenda, weather, dinner, and the family strip all live here."),
        ("calendar", "On Today’s Agenda", "Family events for the day you picked. Swipe the top of the Hub to change days."),
        ("fork.knife", "What’s for dinner", "Tap to plan tonight. Recipes, sides, eating out, and the shopping list hook in here."),
        ("person.3.fill", "Family cards", "Tap a person to color the board for them. Tap an event on their card to open the calendar."),
        ("gearshape.fill", "Invite the house", "Settings → Household has HUB Profiles and the family join code so everyone can sign in as themselves.")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.46).ignoresSafeArea()
            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { index in
                        Capsule()
                            .fill(index <= step ? Color.white : Color.white.opacity(0.28))
                            .frame(height: 6)
                    }
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.blue)
                    Image(systemName: steps[step].0)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)
                Text(steps[step].1)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.center)
                Text(steps[step].2)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button("Skip tour") { onDone() }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Button(step == steps.count - 1 ? "Got it" : "Next") {
                        if step == steps.count - 1 { onDone() } else { withAnimation { step += 1 } }
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(AppTheme.blue, in: Capsule())
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 3)
            )
            .padding(28)
        }
    }
}
