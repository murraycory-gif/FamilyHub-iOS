import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HubPageTitle(lead: "HUB", tail: "Settings")
                HubPanel(symbol: "gearshape.fill", title: "Household") {
                    VStack(spacing: 10) {
                        NavigationLink {
                            FamilyView()
                        } label: {
                            settingsRow(
                                symbol: "person.3.fill",
                                title: "HUB Profiles",
                                detail: "People, photos, birthdays, and contacts"
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            CalendarSourcesView()
                        } label: {
                            settingsRow(
                                symbol: "calendar.badge.plus",
                                title: "Calendars",
                                detail: "iCloud, Google, Outlook, and other calendars"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
    }

    private func settingsRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.blueSoft)
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.blue)
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }
}
