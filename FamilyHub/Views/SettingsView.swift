import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var weather = WeatherLoader()
    @State private var open: Set<String> = [
        "profiles", "device", "invite", "calendars", "bills", "allowance", "weather", "notify"
    ]
    @State private var tourFocus = ""
    @State private var testNote: String?
    @State private var confirmReply = ""
    @State private var pendingDelete: FamilyMember?
    @State private var showAddProfile = false
    @State private var editing: FamilyMember?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "HUB", tail: "Settings")
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsFold(
                        symbol: "person.3.fill",
                        title: "Profiles",
                        subtitle: store.members.map(\.name).joined(separator: ", "),
                        isOpen: open.contains("profiles")
                    ) {
                        toggle("profiles")
                    } content: {
                        profilesBox
                    }
                    .coachSpot("setProfiles")
                    SettingsFold(
                        symbol: "ipad",
                        title: "This iPad",
                        subtitle: store.signedInMember()?.name ?? "Pick who is using this iPad",
                        isOpen: open.contains("device")
                    ) {
                        toggle("device")
                    } content: {
                        signedInRow
                    }
                    SettingsFold(
                        symbol: "person.badge.plus",
                        title: "Invite",
                        subtitle: "Code \(store.joinCode)",
                        isOpen: open.contains("invite")
                    ) {
                        toggle("invite")
                    } content: {
                        inviteBox
                    }
                    SettingsFold(
                        symbol: "calendar.badge.plus",
                        title: "Calendars",
                        subtitle: "\(store.calendarSources.filter(\.isEnabled).count) connected",
                        isOpen: open.contains("calendars")
                    ) {
                        toggle("calendars")
                    } content: {
                        NavigationLink {
                            CalendarSourcesView()
                        } label: {
                            settingsRow(
                                symbol: "calendar.badge.plus",
                                title: "Open calendars",
                                detail: "iCloud, Google, Outlook, and other calendars"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .coachSpot("setCalendars")
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
            case "setProfiles": open.insert("profiles")
            case "setCalendars": open.insert("calendars")
            case "setBills": open.insert("bills")
            case "setAllow": open.insert("allowance")
            case "setWeather": open.insert("weather")
            case "setNotify": open.insert("notify")
            default: break
            }
        }
        .sheet(isPresented: $showAddProfile) {
            EditMemberSheet(member: nil)
        }
        .sheet(item: $editing) { member in
            EditMemberSheet(member: member)
        }
        .hubConfirm(
            "Delete \(pendingDelete?.name ?? "this profile")?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            message: "This removes them from the HUB. Calendars stay on the device.",
            confirm: "Delete",
            confirmColor: AppTheme.chore,
            cancel: "Keep"
        ) {
            if let id = pendingDelete?.id { store.deleteMember(id) }
            pendingDelete = nil
        }
    }

    private func toggle(_ id: String) {
        if open.contains(id) { open.remove(id) } else { open.insert(id) }
    }

    private var profilesBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(store.members) { member in
                HStack(spacing: 12) {
                    MemberAvatar(member: member, size: 56)
                        .overlay(Circle().stroke(Color(hex: member.colorHex), lineWidth: 3))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text(member.id == store.ownerID ? "Owner · \(member.role.label)" : member.role.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                    }
                    Spacer()
                    Button("Edit") { editing = member }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.blueSoft, in: Capsule())
                    .buttonStyle(.plain)
                    if store.members.count > 1 {
                        Button {
                            pendingDelete = member
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(AppTheme.chore, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(AppTheme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: member.colorHex), lineWidth: 3)
                )
            }
            Button { showAddProfile = true } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add a profile")
                    Spacer()
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
                .padding(14)
                .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
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

            Text("How they go out")
                .font(.headline.weight(.bold))
            Text("This iPad is a lock-screen ping. Text: HUB opens Messages — you tap Send — then type YES here. Apple will not let an app send SMS by itself.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                ForEach(NotifyChannel.allCases) { option in
                    chip(option.label, on: store.notifyPrefs.channel == option) {
                        var next = store.notifyPrefs
                        next.channel = option
                        store.setNotifyPrefs(next)
                        if option.usesDevice { askNotifyPermission() }
                    }
                }
                Spacer(minLength: 0)
            }

            if store.notifyPrefs.channel.usesText {
                Text("Phone number")
                    .font(.headline.weight(.bold))
                TextField("555-123-4567", text: Binding(
                    get: { store.notifyPrefs.extraPhone },
                    set: {
                        var next = store.notifyPrefs
                        if next.extraPhone != $0 {
                            HubPinger.shared.phoneVerified = false
                            HubPinger.shared.pendingCode = ""
                        }
                        next.extraPhone = $0
                        store.setNotifyPrefs(next)
                    }
                ))
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)
                .font(.title3.weight(.semibold))
                if HubPinger.shared.phoneVerified {
                    Text("Connected to \(store.notifyPrefs.extraPhone)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                } else {
                    Button("Connect text") {
                        HubPinger.shared.startConnect(store)
                        confirmReply = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            testNote = HubPinger.shared.lastError ?? "Send that text, then type YES."
                        }
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(AppTheme.blue, in: Capsule())
                    if !HubPinger.shared.pendingCode.isEmpty {
                        TextField("Type YES or the code", text: $confirmReply)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3.weight(.semibold))
                        Button("Confirm") {
                            if HubPinger.shared.confirmConnect(store, reply: confirmReply) {
                                testNote = "Number connected."
                                confirmReply = ""
                            } else {
                                testNote = HubPinger.shared.lastError
                            }
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.blue, in: Capsule())
                    }
                }
            }

            if store.notifyPrefs.channel.usesDevice {
                Button("Send a test ping") {
                    HubPinger.shared.sendTest(store)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        testNote = HubPinger.shared.lastError ?? "Check this iPad’s lock screen."
                    }
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.blue, in: Capsule())
            }
            if let testNote {
                Text(testNote)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

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
            Text("Who is using this iPad")
                .font(.headline.weight(.bold))
            Text("Pick the profile for this device. HUB Profiles is the whole family. This is only who is holding this iPad.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(store.members) { member in
                    let on = store.signedInMemberID == member.id
                    Button {
                        store.setSignedIn(member.id)
                    } label: {
                        HStack(spacing: 8) {
                            MemberAvatar(member: member, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(member.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(on ? .white : AppTheme.text)
                                    .lineLimit(1)
                                Text(member.id == store.ownerID ? "Owner" : member.role.label)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(on ? .white.opacity(0.85) : AppTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                            if on {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(10)
                        .background(on ? AppTheme.blue : AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
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
                HubTileBanner(symbol: symbol, title: title) {
                    HStack(spacing: 8) {
                        Text(subtitle)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(0.9)
                        Image(systemName: "chevron.down")
                            .font(.headline.weight(.bold))
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                }
            }
            .buttonStyle(.plain)
            if isOpen {
                content
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.blueSoft)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
        .animation(.easeInOut(duration: 0.2), value: isOpen)
    }
}
