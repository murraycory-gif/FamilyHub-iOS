import SwiftUI

struct OnboardingView: View {
    var onFinished: () -> Void

    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var ingest: CalendarIngestor
    @State private var page = 0
    @State private var household = "Murray"

    private let lastPage = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                        .font(.headline)
                        .foregroundStyle(AppTheme.blue)
                }
                Spacer()
                if page < lastPage {
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            TabView(selection: $page) {
                welcome.tag(0)
                householdPage.tag(1)
                walkthroughPage.tag(2)
                calendarPage.tag(3)
                readyPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == lastPage ? "Open HUB" : "Continue") {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear { household = store.householdName }
    }

    private func finish() {
        store.setHouseholdName(household)
        ingest.scheduleSync(quiet: true)
        onFinished()
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            Image("HubMark")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            Text("Welcome to HUB")
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.4)
                .multilineTextAlignment(.center)
            Text("One place for the family calendar, dinner, chores, and the day ahead.")
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
                .font(.system(size: 32, weight: .semibold))
            Text("Name the household. You can add or edit people anytime in Family.")
                .foregroundStyle(AppTheme.textSecondary)
            TextField("Household name", text: $household)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(store.members) { member in
                    HStack(spacing: 12) {
                        MemberAvatar(member: member, size: 36)
                        Text(member.name).font(.headline)
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

    private var walkthroughPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("How HUB works")
                .font(.system(size: 32, weight: .semibold))
            Text("A short walkthrough will live here. For now, tap through the steps you’ll see in the video.")
                .foregroundStyle(AppTheme.textSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.navy)
                VStack(spacing: 14) {
                    Image("HubGlyph")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                    Text("Walkthrough video")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Placeholder — we’ll drop the real clip here")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)

            VStack(alignment: .leading, spacing: 10) {
                walkStep(1, "Meet the HUB — family cards, dinner, and the day list")
                walkStep(2, "Connect iCloud, Google, or Outlook so calendars stay live")
                walkStep(3, "Assign chores. Kids check them off for allowance")
            }
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var calendarPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect calendars")
                .font(.system(size: 32, weight: .semibold))
            Text("HUB pulls from the calendars already on this iPad and writes new events back to them.")
                .foregroundStyle(AppTheme.textSecondary)

            if ingest.isAuthorized {
                if store.calendarSources.isEmpty {
                    Text("No calendars found. Add iCloud, Google, or Outlook in Settings → Calendar → Accounts.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(store.calendarSources) { source in
                                HStack(spacing: 12) {
                                    Image(systemName: source.brand.symbol)
                                        .foregroundStyle(AppTheme.blue)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.title).font(.headline)
                                        Text(source.account.isEmpty ? source.brand.title : source.account)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { source.isEnabled },
                                        set: { enabled in
                                            store.setSourceEnabled(source.id, enabled: enabled)
                                            ingest.scheduleSync(quiet: true)
                                        }
                                    ))
                                    .labelsHidden()
                                    .tint(AppTheme.blue)
                                }
                                .padding(14)
                                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
            } else {
                Button {
                    Task {
                        await ingest.requestAccess()
                        store.upsertCalendarSources(ingest.available)
                    }
                } label: {
                    Label("Allow calendar access", systemImage: "calendar.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.blue)
            }
            if let message = ingest.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .onAppear {
            ingest.refreshStatus()
            if ingest.isAuthorized {
                store.upsertCalendarSources(ingest.available)
            }
        }
    }

    private var readyPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("You’re set")
                .font(.system(size: 32, weight: .semibold))
            Text("Assign chores, they check them off, you approve, and it hits their allowance.")
                .foregroundStyle(AppTheme.textSecondary)
            featureRow("calendar", "Live family calendars")
            featureRow("fork.knife", "Dinner for the day")
            featureRow("checkmark.circle", "Chores and allowance")
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func walkStep(_ number: Int, _ title: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.blue)
                .frame(width: 28, height: 28)
                .background(AppTheme.blueSoft, in: Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)
        }
    }

    private func featureRow(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.blue)
                .frame(width: 28)
            Text(title).font(.headline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
