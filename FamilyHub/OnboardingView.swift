import SwiftUI

struct OnboardingView: View {
    var onFinished: () -> Void

    @EnvironmentObject private var store: HubStore
    @State private var page = 0
    @State private var household = "Murray"

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                householdPage.tag(1)
                choresPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == 2 ? "Open HUB" : "Continue") {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    store.setHouseholdName(household)
                    onFinished()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear { household = store.householdName }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppTheme.ice)
            }
            Text("The household, in one place")
                .font(.system(size: 32, weight: .semibold))
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.text)
            Text("Family calendar, reminders, to-dos, and a chore board your kids can check off for allowance.")
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer()
        }
    }

    private var householdPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Your family")
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.text)
            Text("Rename the household now. You can add or edit people anytime in Family.")
                .foregroundStyle(AppTheme.textSecondary)
            TextField("Household name", text: $household)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.members) { member in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: member.colorHex))
                            .frame(width: 12, height: 12)
                        Text(member.name)
                            .font(.headline)
                        Text(member.role.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var choresPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Chores that pay")
                .font(.system(size: 32, weight: .semibold, design: .serif))
            Text("Assign a chore, they check it off, you approve, and it hits their allowance. Sample kids are Alex and Sam — swap in your sons in Family.")
                .foregroundStyle(AppTheme.textSecondary)
            featureRow("calendar", "Family and per-person calendars")
            featureRow("checklist", "Reminders and to-dos")
            featureRow("dollarsign.circle", "Allowance ledger per kid")
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func featureRow(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.forest)
                .frame(width: 28)
            Text(title)
                .font(.headline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
