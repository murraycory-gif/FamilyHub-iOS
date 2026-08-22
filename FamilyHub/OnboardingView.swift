import SwiftUI
import UserNotifications

struct OnboardingView: View {
    var onFinished: () -> Void

    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var ingest: CalendarIngestor
    @State private var page = 0
    @State private var path: Path = .create
    @State private var ownerName = ""
    @State private var household = ""
    @State private var joinInput = ""
    @State private var joinError: String?
    @State private var personName = ""
    @State private var personRole: MemberRole = .child
    @State private var city = ""
    @State private var prefs = HubNotifyPrefs.off
    @StateObject private var weather = WeatherLoader()

    enum Path { case create, join }

    private var lastPage: Int { path == .join ? 2 : 7 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                }
                Spacer()
                Text("HUB setup")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                if page > 0 && page < lastPage && path == .create {
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            progress
                .padding(.horizontal, 24)
                .padding(.top, 12)

            TabView(selection: $page) {
                gate.tag(0)
                if path == .join {
                    joinPage.tag(1)
                    joinReady.tag(2)
                } else {
                    youPage.tag(1)
                    housePage.tag(2)
                    peoplePage.tag(3)
                    placePage.tag(4)
                    calendarPage.tag(5)
                    pingsPage.tag(6)
                    readyPage.tag(7)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            Button(primaryTitle) { advance() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            household = store.householdName
            ownerName = store.signedInMember()?.name ?? ""
        }
    }

    private var primaryTitle: String {
        if page == 0 { return "Continue" }
        if path == .join { return page == lastPage ? "Open HUB" : "Join this HUB" }
        return page == lastPage ? "Open my HUB" : "Next"
    }

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(0...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? AppTheme.blue : AppTheme.blueSoft)
                    .frame(height: 6)
            }
        }
    }

    private func advance() {
        if page == 0 { withAnimation { page = 1 }; return }
        if path == .join {
            if page == 1 {
                guard tryJoin() else { return }
            }
            if page < lastPage { withAnimation { page += 1 } } else { finish() }
            return
        }
        if page == 1 { saveYou() }
        if page == 2 { store.setHouseholdName(household.isEmpty ? ownerName : household) }
        if page < lastPage { withAnimation { page += 1 } } else { finish() }
    }

    private func saveYou() {
        let name = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if store.members.isEmpty {
            _ = store.addQuickMember(name: name, role: .parent, asOwner: true)
        } else if let me = store.signedInMember() {
            var updated = me
            updated.name = name
            store.updateMember(updated)
            store.setOwner(me.id)
        }
        if household.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            household = "\(name.components(separatedBy: " ").first ?? name) family"
        }
    }

    private func tryJoin() -> Bool {
        let code = joinInput.replacingOccurrences(of: " ", with: "").uppercased()
        guard code.count == 6 else {
            joinError = "Ask the owner for the 6-character HUB code."
            return false
        }
        if code == store.joinCode.uppercased() {
            joinError = nil
            return true
        }
        joinError = "That code is not this HUB. Open HUB on the owner’s iPad or use the same Apple ID."
        return false
    }

    private func finish() {
        if !household.isEmpty { store.setHouseholdName(household) }
        store.setNotifyPrefs(prefs)
        if prefs.anyOn {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        ingest.scheduleSync(quiet: true)
        onFinished()
    }

    private var gate: some View {
        VStack(spacing: 22) {
            Spacer()
            Image("HubMark")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
            Text("Build your HUB")
                .font(.system(size: 36, weight: .bold))
            Text("One shared home for calendars, dinner, chores, and the people in your house.")
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            VStack(spacing: 12) {
                pathCard("Create this HUB", "You’re the owner. Invite everyone else after setup.", "house.fill", path == .create) {
                    path = .create
                }
                pathCard("Join a family HUB", "The owner already built one. Use their code.", "person.badge.plus", path == .join) {
                    path = .join
                }
            }
            .padding(.horizontal, 8)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func pathCard(_ title: String, _ detail: String, _ symbol: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(on ? AppTheme.blue : AppTheme.blueSoft)
                    Image(systemName: symbol)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(on ? .white : AppTheme.blue)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title3.weight(.bold)).foregroundStyle(AppTheme.text)
                    Text(detail).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(on ? AppTheme.blue : AppTheme.cardBorder, lineWidth: on ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var youPage: some View {
        setupCard("This is you", "The owner profile signs in on this iPad and can invite the rest of the family.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your first name").font(.headline)
                TextField("Alex", text: $ownerName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                Text("You’ll be set as Parent / owner. You can change that later in HUB Profiles.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var housePage: some View {
        setupCard("Name the household", "This shows on the Hub, invites, and the family strip.") {
            TextField("The Rivera house", text: $household)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
        }
    }

    private var peoplePage: some View {
        setupCard("Who lives here", "Each person gets their own profile, color, and calendar. Pets too.") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(store.members) { member in
                    HStack(spacing: 12) {
                        MemberAvatar(member: member, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name).font(.headline)
                            Text(member.id == store.ownerID ? "Owner · \(member.role.label)" : member.role.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                HStack(spacing: 8) {
                    TextField("Add someone", text: $personName)
                        .textFieldStyle(.roundedBorder)
                    Picker("Role", selection: $personRole) {
                        ForEach(MemberRole.allCases) { role in
                            Text(role.label).tag(role)
                        }
                    }
                    .labelsHidden()
                    Button("Add") {
                        let name = personName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        _ = store.addQuickMember(name: name, role: personRole)
                        personName = ""
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.blue, in: Capsule())
                }
            }
        }
    }

    private var placePage: some View {
        setupCard("Home base", "Weather and nearby food use this. Change it anytime in Settings.") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("City or ZIP", text: $city)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: city) { _, value in
                        Task { await weather.search(query: value) }
                    }
                ForEach(weather.searchResults.prefix(5)) { place in
                    Button {
                        store.setWeatherPlace(place)
                        city = place.label
                    } label: {
                        HStack {
                            Image(systemName: "location.fill").foregroundStyle(AppTheme.blue)
                            Text(place.label).foregroundStyle(AppTheme.text)
                            Spacer()
                            if store.weatherPlace?.id == place.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                HStack {
                    Text("Units")
                    Spacer()
                    Button("US") { store.setUnits(.us) }
                        .foregroundStyle(store.units == .us ? .white : AppTheme.blue)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(store.units == .us ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
                    Button("Metric") { store.setUnits(.metric) }
                        .foregroundStyle(store.units == .metric ? .white : AppTheme.blue)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(store.units == .metric ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
                }
                .font(.headline.weight(.bold))
            }
        }
    }

    private var calendarPage: some View {
        setupCard("Bring in calendars", "HUB reads the calendars on this iPad and writes new events back.") {
            VStack(alignment: .leading, spacing: 12) {
                if ingest.isAuthorized {
                    ForEach(store.calendarSources.prefix(8)) { source in
                        HStack {
                            Image(systemName: source.brand.symbol).foregroundStyle(AppTheme.blue)
                            Text(source.title).font(.headline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { source.isEnabled },
                                set: { store.setSourceEnabled(source.id, enabled: $0) }
                            ))
                            .labelsHidden()
                            .tint(AppTheme.blue)
                        }
                        .padding(12)
                        .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if store.calendarSources.isEmpty {
                        Text("No calendars found yet. Add iCloud, Google, or Outlook in Apple Settings.")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    Button {
                        Task {
                            await ingest.requestAccess()
                            store.upsertCalendarSources(ingest.available)
                        }
                    } label: {
                        Label("Allow calendar access", systemImage: "calendar.badge.plus")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.blue)
                }
            }
            .onAppear {
                ingest.refreshStatus()
                if ingest.isAuthorized { store.upsertCalendarSources(ingest.available) }
            }
        }
    }

    private var pingsPage: some View {
        setupCard("Choose your pings", "Nothing is on until you flip it. Pick only what you want HUB to tap you about.") {
            VStack(spacing: 10) {
                pingRow("Sunrise brief", "A short morning rundown of the household.", $prefs.morningBrief)
                pingRow("Before events", "A tap before something on the family calendar.", $prefs.eventPings)
                pingRow("Dinner lock-in", "When tonight’s meal is set or still empty.", $prefs.dinnerPing)
                pingRow("Chore check", "When a chore is due or waiting on approval.", $prefs.chorePing)
                pingRow("Shopping nudge", "When the list has items before you leave the house.", $prefs.shoppingPing)
            }
        }
    }

    private func pingRow(_ title: String, _ detail: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
            }
        }
        .tint(AppTheme.blue)
        .padding(14)
        .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var readyPage: some View {
        setupCard("Your HUB is live", "Invite the family with a code. Everyone who joins sees calendars, meals, chores, and shopping.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Family join code")
                    .font(.headline)
                Text(store.joinCode)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("Share this from Settings → Household. Each person picks their own profile after they join.")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var joinPage: some View {
        setupCard("Enter the family code", "Six characters from the owner. Then pick which profile is you.") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("ABC123", text: $joinInput)
                    .textInputAutocapitalization(.characters)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                if let joinError {
                    Text(joinError).foregroundStyle(AppTheme.chore).font(.subheadline.weight(.semibold))
                }
                if joinInput.replacingOccurrences(of: " ", with: "").uppercased() == store.joinCode.uppercased() {
                    Text("Pick your profile")
                        .font(.headline)
                    ForEach(store.members) { member in
                        Button {
                            store.setSignedIn(member.id)
                        } label: {
                            HStack {
                                MemberAvatar(member: member, size: 40)
                                Text(member.name).font(.headline).foregroundStyle(AppTheme.text)
                                Spacer()
                                if store.signedInMemberID == member.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.blue)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var joinReady: some View {
        setupCard("You’re in", "This iPad now follows \(store.signedInMember()?.name ?? "your") profile. Calendars, dinner, and chores stay in the shared HUB.") {
            Text("Open HUB to see today’s board. The first visit walks you through the main pieces.")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func setupCard<Content: View>(_ title: String, _ detail: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                Text(detail)
                    .font(.title3)
                    .foregroundStyle(AppTheme.textSecondary)
                content()
            }
            .padding(22)
            .frame(maxWidth: 720, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 3)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
    }
}
