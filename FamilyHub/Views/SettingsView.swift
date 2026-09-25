import SwiftUI
import UserNotifications

struct SettingsPageShell<Content: View>: View {
    let tail: String
    let symbol: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Circle", tail: tail)
            ScrollView {
                HubPanel(symbol: symbol, title: title) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
    }
}

struct AppearancePicker: View {
    @EnvironmentObject private var store: HubStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Display")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("Light, dark, or match the iPhone / iPad setting.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 8) {
                ForEach(HubAppearance.allCases) { mode in
                    Button {
                        store.setAppearance(mode)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.symbol)
                                .font(.title3.weight(.bold))
                            Text(mode.label)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(store.appearance == mode ? .white : AppTheme.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(store.appearance == mode ? AppTheme.blue : AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct SettingsView: View {
    var body: some View { ProfilesSettingsView() }
}

struct ProfilesSettingsView: View {
    @EnvironmentObject private var store: HubStore
    @State private var pendingDelete: FamilyMember?
    @State private var showAddProfile = false
    @State private var editing: FamilyMember?
    @State private var showPrivacy = false

    var body: some View {
        SettingsPageShell(tail: "Profiles", symbol: "person.3.fill", title: "Circle Profiles") {
            VStack(alignment: .leading, spacing: 16) {
                AppearancePicker()
                Text("Who is using this device")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text("This is only who is holding this iPad or iPhone. Profiles below are the whole family.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(store.members) { member in
                        let on = store.signedInMemberID == member.id
                        Button {
                            store.setSignedIn(member.id)
                        } label: {
                            HStack(spacing: 10) {
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
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                                }
                            }
                            .padding(12)
                            .background(on ? AppTheme.blue : AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(on ? AppTheme.blue : AppTheme.cardBorder, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                        }
                        .buttonStyle(HubPressStyle())
                    }
                }
                Text("Family profiles")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .padding(.top, 6)
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
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
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
                Button { showPrivacy = true } label: {
                    Label("Privacy policy", systemImage: "hand.raised.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                }
                .buttonStyle(.plain)
                Text(HubPrivacy.summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .hubTour("settings", steps: HubTours.settings.filter { $0.id == "setProfiles" })
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView() }
        .sheet(isPresented: $showAddProfile) { EditMemberSheet(member: nil) }
        .sheet(item: $editing) { member in EditMemberSheet(member: member) }
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
            if let member = pendingDelete { store.deleteMember(member.id) }
            pendingDelete = nil
        }
    }
}

enum HubPrivacy {
    static let summary = "Household data stays in your private iCloud. HUB does not sell it or send it to a server we run."
    static let hostedURL = URL(string: "https://hubcircle.pages.dev/privacy.html")!
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("HUB stores the household on this device and in your private iCloud. The developer does not receive names, photos, calendars, or location.")
                    Text("While HUB is open, location is used only to show local weather and to search MapKit for nearby restaurants. HUB does not track location in the background.")
                    Text("Place photos come only from Apple Look Around. Recipe images load from our own catalog host.")
                    Text("Family photos and recipe scans stay on this device. Calendar events are read on this device to fill the family board.")
                    Text("Invite codes are random. Older 6-character codes are replaced automatically after the first private sync. Sharing a HUB uses Apple’s share sheet.")
                    Link("Full privacy policy", destination: HubPrivacy.hostedURL)
                        .font(.headline.weight(.bold))
                }
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.text)
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Privacy policy")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DeviceSettingsView: View {
    @EnvironmentObject private var store: HubStore

    var body: some View {
        SettingsPageShell(tail: "This iPad", symbol: "ipad", title: "Who is using this iPad") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pick the profile for this device. Profiles is the whole family. This is only who is holding this iPad.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(store.members) { member in
                        let on = store.signedInMemberID == member.id
                        Button {
                            store.setSignedIn(member.id)
                        } label: {
                            HStack(spacing: 10) {
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
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                                }
                            }
                            .padding(12)
                            .background(on ? AppTheme.blue : AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(on ? AppTheme.blue : AppTheme.cardBorder, lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                        }
                        .buttonStyle(HubPressStyle())
                    }
                }
            }
        }
    }
}

struct InviteSettingsView: View {
    @EnvironmentObject private var store: HubStore
    @AppStorage("familyhub.onboarding.completed.v4") private var onboardingCompleted = false
    @AppStorage("familyhub.tours.v2") private var tours = ""
    @State private var publishNote: String?
    @State private var confirmReset = false
    @State private var confirmCleanup = false
    @State private var eraseError: String?
    @State private var showEraseRetry = false
    @State private var cloudShare: HouseholdShareItem?

    var body: some View {
        SettingsPageShell(tail: "Invite", symbol: "person.badge.plus", title: "Invite to this HUB") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Share this HUB with Apple’s share sheet. Family accepts the invite in Messages or Mail. The house stays in your private iCloud, not a public record.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(store.joinCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                HStack {
                    ShareLink(item: "Join our family HUB. Code: \(store.joinCode). Open HUB → Join a family HUB.") {
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
                Button {
                    Task {
                        do {
                            cloudShare = HouseholdShareItem(share: try await store.prepareHouseholdShare())
                            publishNote = "Choose who can open this HUB."
                        } catch {
                            publishNote = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Share this HUB")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
                if let publishNote {
                    Text(publishNote)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Text("Danger zone")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.chore)
                    .padding(.top, 8)
                Button("Remove old shared records") { confirmCleanup = true }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.chore)
                Button("Start as a new download") { confirmReset = true }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.chore)
            }
        }
        .hubConfirm(
            "Remove old shared records?",
            isPresented: $confirmCleanup,
            message: "This deletes the current hub code and every earlier hub code this device has issued from iCloud. Your house stays on this device. Family will need you to publish again before they can rejoin. This does not run on its own.",
            confirm: "Remove",
            confirmColor: AppTheme.chore,
            cancel: "Cancel"
        ) {
            Task { publishNote = await store.removeOldSharedRecords() }
        }
        .hubConfirm(
            "Erase this HUB on this device?",
            isPresented: $confirmReset,
            message: "HUB deletes the private iCloud record and the share first. This device is cleared only after iCloud confirms. If iCloud fails, nothing here is erased and you can retry. Photos that live only on this device will not come back.",
            confirm: "Erase",
            confirmColor: AppTheme.chore,
            cancel: "Cancel"
        ) {
            Task {
                if let error = await store.eraseHousehold() {
                    eraseError = error
                    showEraseRetry = true
                } else {
                    tours = ""
                    onboardingCompleted = false
                }
            }
        }
        .alert("Erase did not finish", isPresented: $showEraseRetry) {
            Button("Retry") {
                Task {
                    if let error = await store.eraseHousehold() {
                        eraseError = error
                        showEraseRetry = true
                    } else {
                        tours = ""
                        onboardingCompleted = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(eraseError ?? "iCloud did not confirm the delete. This HUB is still on this device.")
        }
        .sheet(item: $cloudShare) { share in
            HouseholdShareSheet(share: share.share)
        }
    }
}

struct BillsSettingsView: View {
    var body: some View {
        SettingsPageShell(tail: "Bills Due", symbol: "dollarsign.circle.fill", title: "Bills calendar") {
            BillsCalendarPicker()
        }
        .hubTour("settings", steps: HubTours.settings.filter { $0.id == "setBills" })
    }
}

struct AllowanceSettingsPage: View {
    var body: some View {
        SettingsPageShell(tail: "Allowance", symbol: "banknote.fill", title: "Kid balances") {
            AllowanceSettingsView()
        }
        .hubTour("settings", steps: HubTours.settings.filter { $0.id == "setAllow" })
    }
}

struct WeatherSettingsForm: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var weather = WeatherLoader()
    @State private var showPlace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                Button { showPlace = true } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.blueSoft)
                            Image(systemName: "location.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                        }
                        .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.weatherPlace?.label ?? "Set location")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Text("City, ZIP, or current location")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                    .padding(14)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                }
                .buttonStyle(.plain)

                Text("Measurements")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                HStack {
                    unitChip("US", on: store.units == .us) { store.setUnits(.us) }
                    unitChip("Metric", on: store.units == .metric) { store.setUnits(.metric) }
                    Spacer()
                }
                measureRow("Temperature") {
                    ForEach(TemperatureUnit.allCases) { option in
                        unitChip(option.name, on: store.units.temperature == option) {
                            var next = store.units
                            next.temperature = option
                            store.setUnits(next)
                        }
                    }
                }
                measureRow("Wind") {
                    ForEach(WindUnit.allCases) { option in
                        unitChip(option.label, on: store.units.wind == option) {
                            var next = store.units
                            next.wind = option
                            store.setUnits(next)
                        }
                    }
                }
                measureRow("Rain") {
                    ForEach(PrecipUnit.allCases) { option in
                        unitChip(option.name, on: store.units.precipitation == option) {
                            var next = store.units
                            next.precipitation = option
                            store.setUnits(next)
                        }
                    }
                }
                measureRow("Distance") {
                    ForEach(DistanceUnit.allCases) { option in
                        unitChip(option.name, on: store.units.distance == option) {
                            var next = store.units
                            next.distance = option
                            store.setUnits(next)
                        }
                    }
                }
                measureRow("Speed") {
                    ForEach(SpeedUnit.allCases) { option in
                        unitChip(option.label, on: store.units.speed == option) {
                            var next = store.units
                            next.speed = option
                            store.setUnits(next)
                        }
                    }
                }
                measureRow("Weight") {
                    ForEach(WeightUnit.allCases) { option in
                        unitChip(option.name, on: store.units.weight == option) {
                            var next = store.units
                            next.weight = option
                            store.setUnits(next)
                        }
                    }
                }
                measureRow("Volume") {
                    ForEach(VolumeUnit.allCases) { option in
                        unitChip(option.name, on: store.units.volume == option) {
                            var next = store.units
                            next.volume = option
                            store.setUnits(next)
                        }
                    }
                }
                measureRow("Length") {
                    ForEach(LengthUnit.allCases) { option in
                        unitChip(option.name, on: store.units.length == option) {
                            var next = store.units
                            next.length = option
                            store.setUnits(next)
                        }
                    }
                }
                measureRow("Time") {
                    ForEach(TimeFormatUnit.allCases) { option in
                        unitChip(option.name, on: store.units.time == option) {
                            var next = store.units
                            next.time = option
                            store.setUnits(next)
                        }
                    }
                }
            }
        .hubTour("settings", steps: HubTours.settings.filter { $0.id == "setWeather" })
        .sheet(isPresented: $showPlace) {
            WeatherPlacePicker()
                .environmentObject(store)
                .environmentObject(weather)
        }
    }
}

private extension WeatherSettingsForm {
    func measureRow<V: View>(_ title: String, @ViewBuilder chips: () -> V) -> some View {
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

    func unitChip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
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
}

struct CreditsSettingsView: View {
    private var recipes: [RecipePackItem] { RecipePackStore.seed().recipes }

    var body: some View {
        SettingsPageShell(tail: "Credits", symbol: "doc.text", title: "Credits and licenses") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Each recipe shows Source · License · Changes. Photos are that dish, hosted with the catalog. A recipe with no photo shows its name.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Halal and kosher tags mean the ingredients look compatible. They are not a certification. Allergen tags mean check the labels on what you buy.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(recipes, id: \.id) { recipe in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text(recipe.asCatalogRecipe().attributionLine)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        if recipe.sourceURL.isEmpty == false {
                            Text(recipe.sourceURL)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}

struct NotifySettingsView: View {
    @EnvironmentObject private var store: HubStore
    @State private var testNote: String?

    var body: some View {
        SettingsPageShell(tail: "Notifications", symbol: "bell.fill", title: "Notifications") {
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
                            next.channel = .device
                            store.setNotifyPrefs(next)
                            askNotifyPermission()
                        } else {
                            store.setNotifyPrefs(.off)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allow notifications").font(.headline.weight(.bold))
                        Text("Pings stay on this device. Flip each one below and set the time.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .tint(AppTheme.blue)
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 5, y: 2)

                Button("Send a test ping") {
                    HubPinger.shared.sendTest(store)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        testNote = HubPinger.shared.lastError ?? "Check the lock screen."
                    }
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppTheme.blue, in: Capsule())
                if let testNote {
                    Text(testNote)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text("What and when").font(.headline.weight(.bold)).padding(.top, 8)
                notifyRow(
                    "Sunrise brief",
                    "Morning rundown of the house.",
                    \.morningBrief,
                    time: \.morningAt
                )
                notifyRow(
                    "Before events",
                    "Ping before something on the calendar.",
                    \.eventPings,
                    lead: true
                )
                notifyRow(
                    "Dinner reminder",
                    "Ask what’s for dinner if nothing is set.",
                    \.dinnerPing,
                    time: \.dinnerAt
                )
                notifyRow(
                    "Chore check",
                    "Open chores for the day.",
                    \.chorePing,
                    time: \.choreAt
                )
                notifyRow(
                    "Bills Due",
                    "Bills on the calendar today.",
                    \.billsPing,
                    time: \.billsAt
                )
                notifyRow(
                    "Shopping list",
                    "If the list still has items.",
                    \.shoppingPing,
                    time: \.shoppingAt
                )
            }
        }
        .hubTour("settings", steps: HubTours.settings.filter { $0.id == "setNotify" })
    }

    private func notifyRow(
        _ title: String,
        _ detail: String,
        _ key: WritableKeyPath<HubNotifyPrefs, Bool>,
        time: WritableKeyPath<HubNotifyPrefs, Int>? = nil,
        lead: Bool = false
    ) -> some View {
        let on = store.notifyPrefs[keyPath: key]
        return VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { store.notifyPrefs[keyPath: key] },
                set: { value in
                    var next = store.notifyPrefs
                    next[keyPath: key] = value
                    store.setNotifyPrefs(next)
                    if value { askNotifyPermission() }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline.weight(.bold))
                    Text(detail).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.textSecondary)
                }
            }
            .tint(AppTheme.blue)
            if on, let time {
                HStack {
                    Text("Time")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { HubNotifyPrefs.date(from: store.notifyPrefs[keyPath: time]) },
                            set: { date in
                                var next = store.notifyPrefs
                                next[keyPath: time] = HubNotifyPrefs.minutes(from: date)
                                store.setNotifyPrefs(next)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(AppTheme.blue)
                }
            }
            if on, lead {
                HStack {
                    Text("Warn me")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { store.notifyPrefs.eventLeadMinutes },
                        set: { value in
                            var next = store.notifyPrefs
                            next.eventLeadMinutes = value
                            store.setNotifyPrefs(next)
                        }
                    )) {
                        Text("15 min before").tag(15)
                        Text("30 min before").tag(30)
                        Text("1 hour before").tag(60)
                        Text("2 hours before").tag(120)
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.blue)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }

    private func askNotifyPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
