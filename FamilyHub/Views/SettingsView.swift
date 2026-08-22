import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var weather = WeatherLoader()
    @State private var open: Set<String> = ["household"]
    @State private var tourFocus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "HUB", tail: "Settings")
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsFold(
                        symbol: "gearshape.fill",
                        title: "Household",
                        subtitle: "Profiles and calendars",
                        isOpen: open.contains("household")
                    ) {
                        toggle("household")
                    } content: {
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
                            signedInRow
                            inviteBox
                        }
                    }
                    .coachSpot("setHouse")
                    SettingsFold(
                        symbol: "dollarsign.circle.fill",
                        title: "Bills Due",
                        subtitle: store.calendarSources.first(where: { $0.use == .billsDue })?.title ?? "Pick a bills calendar",
                        isOpen: open.contains("bills")
                    ) {
                        toggle("bills")
                    } content: {
                        BillsCalendarPicker()
                    }
                    .coachSpot("setBills")
                    SettingsFold(
                        symbol: "banknote.fill",
                        title: "Allowance",
                        subtitle: store.kids().isEmpty ? "Kid balances and payouts" : store.kids().map { "\($0.name) \(Money.cents($0.allowanceBalanceCents))" }.joined(separator: " · "),
                        isOpen: open.contains("allowance")
                    ) {
                        toggle("allowance")
                    } content: {
                        AllowanceSettingsView()
                    }
                    .coachSpot("setAllow")
                    SettingsFold(
                        symbol: "cloud.sun.fill",
                        title: "Weather",
                        subtitle: store.weatherPlace?.label ?? "Location and units",
                        isOpen: open.contains("weather")
                    ) {
                        toggle("weather")
                    } content: {
                        VStack(alignment: .leading, spacing: 14) {
                            NavigationLink {
                                WeatherPlacePicker()
                                    .environmentObject(store)
                                    .environmentObject(weather)
                            } label: {
                                settingsRow(
                                    symbol: "location.fill",
                                    title: store.weatherPlace?.label ?? "Set location",
                                    detail: "City, ZIP, or current location"
                                )
                            }
                            .buttonStyle(.plain)
                            Text("Measurements")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                                .padding(.top, 4)
                            HStack {
                                Button("US") { store.setUnits(.us) }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(store.units == .us ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
                                    .foregroundStyle(store.units == .us ? .white : AppTheme.blue)
                                    .font(.headline.weight(.bold))
                                Button("Metric") { store.setUnits(.metric) }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(store.units == .metric ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
                                    .foregroundStyle(store.units == .metric ? .white : AppTheme.blue)
                                    .font(.headline.weight(.bold))
                                Spacer()
                            }
                            measureRow("Temperature") {
                                ForEach(TemperatureUnit.allCases) { option in
                                    chip(option.name, on: store.units.temperature == option) {
                                        var next = store.units
                                        next.temperature = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Wind") {
                                ForEach(WindUnit.allCases) { option in
                                    chip(option.label, on: store.units.wind == option) {
                                        var next = store.units
                                        next.wind = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Rain") {
                                ForEach(PrecipUnit.allCases) { option in
                                    chip(option.name, on: store.units.precipitation == option) {
                                        var next = store.units
                                        next.precipitation = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Distance") {
                                ForEach(DistanceUnit.allCases) { option in
                                    chip(option.name, on: store.units.distance == option) {
                                        var next = store.units
                                        next.distance = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Speed") {
                                ForEach(SpeedUnit.allCases) { option in
                                    chip(option.label, on: store.units.speed == option) {
                                        var next = store.units
                                        next.speed = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Weight") {
                                ForEach(WeightUnit.allCases) { option in
                                    chip(option.name, on: store.units.weight == option) {
                                        var next = store.units
                                        next.weight = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Volume") {
                                ForEach(VolumeUnit.allCases) { option in
                                    chip(option.name, on: store.units.volume == option) {
                                        var next = store.units
                                        next.volume = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Length") {
                                ForEach(LengthUnit.allCases) { option in
                                    chip(option.name, on: store.units.length == option) {
                                        var next = store.units
                                        next.length = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Time") {
                                ForEach(TimeFormatUnit.allCases) { option in
                                    chip(option.name, on: store.units.time == option) {
                                        var next = store.units
                                        next.time = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                        }
                    }
                    .coachSpot("setWeather")
                    SettingsFold(
                        symbol: "bell.fill",
                        title: "Notifications",
                        subtitle: store.notifyPrefs.anyOn ? "On" : "Off",
                        isOpen: open.contains("notify")
                    ) {
                        toggle("notify")
                    } content: {
                        notifyBox
                    }
                    .coachSpot("setNotify")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .onChange(of: tourFocus) { _, id in
                guard !id.isEmpty else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
            }
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .hubTour("settings", steps: HubTours.settings) { id in
            tourFocus = id
            switch id {
            case "setHouse": open = ["household"]
            case "setBills": open = ["bills"]
            case "setAllow": open = ["allowance"]
            case "setWeather": open = ["weather"]
            case "setNotify": open = ["notify"]
            default: break
            }
        }
    }

    private func toggle(_ id: String) {
        if open.contains(id) { open.remove(id) } else { open.insert(id) }
    }

    private var notifyBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { store.notifyPrefs.anyOn },
                set: { on in
                    if on {
                        var next = store.notifyPrefs
                        if !next.anyOn {
                            next.eventPings = true
                            next.dinnerPing = true
                            next.chorePing = true
                            next.billsPing = true
                        }
                        store.setNotifyPrefs(next)
                        askNotifyPermission()
                    } else {
                        store.setNotifyPrefs(.off)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allow notifications")
                        .font(.headline.weight(.bold))
                    Text("Master switch. Flip individual pings below.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .tint(AppTheme.blue)
            .padding(14)
            .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            notifyRow("Sunrise brief", "Morning rundown of the household.", \.morningBrief)
            notifyRow("Before events", "A tap before something on the family calendar.", \.eventPings)
            notifyRow("Dinner lock-in", "When tonight’s meal is set or still empty.", \.dinnerPing)
            notifyRow("Chore check", "When a chore is due or waiting on approval.", \.chorePing)
            notifyRow("Bills Due", "When a bill from your bills calendar is coming up.", \.billsPing)
            notifyRow("Shopping nudge", "When the list has items before you leave the house.", \.shoppingPing)
        }
    }

    private func notifyRow(_ title: String, _ detail: String, _ key: WritableKeyPath<HubNotifyPrefs, Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { store.notifyPrefs[keyPath: key] },
            set: { on in
                var next = store.notifyPrefs
                next[keyPath: key] = on
                store.setNotifyPrefs(next)
                if on { askNotifyPermission() }
            }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline.weight(.bold))
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .tint(AppTheme.blue)
        .padding(14)
        .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func askNotifyPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private var signedInRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This iPad is signed in as")
                .font(.headline.weight(.bold))
            ForEach(store.members) { member in
                Button {
                    store.setSignedIn(member.id)
                } label: {
                    HStack(spacing: 12) {
                        MemberAvatar(member: member, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Text(member.id == store.ownerID ? "Owner" : member.role.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        if store.signedInMemberID == member.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.blue)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var inviteBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invite to this HUB")
                .font(.headline.weight(.bold))
            Text("Family uses this code, then picks their own profile. They see the same calendars, meals, and chores.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(store.joinCode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.blue)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack {
                ShareLink(item: "Join our family HUB. Code: \(store.joinCode)") {
                    Label("Share code", systemImage: "square.and.arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.blue, in: Capsule())
                }
                Button("New code") { store.refreshJoinCode() }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                Spacer()
            }
        }
        .padding(14)
        .background(AppTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func measureRow<V: View>(_ title: String, @ViewBuilder chips: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                chips()
                Spacer(minLength: 0)
            }
        }
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(on ? .white : AppTheme.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(on ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
        }
        .buttonStyle(.plain)
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
        .padding(14)
        .background(AppTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

private struct SettingsFold<Content: View>: View {
    let symbol: String
    let title: String
    let subtitle: String
    let isOpen: Bool
    var onToggle: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.blue)
                        Image(systemName: symbol)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen {
                content
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
        .animation(.easeInOut(duration: 0.2), value: isOpen)
    }
}
