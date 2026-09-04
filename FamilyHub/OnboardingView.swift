import PhotosUI
import SwiftUI
import UserNotifications

struct OnboardingView: View {
    var onFinished: () -> Void

    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var ingest: CalendarIngestor
    @Environment(\.horizontalSizeClass) private var sizeClass
    @FocusState private var focused: Field?
    @State private var page = 0
    @State private var path: Path = .create
    @State private var ownerName = ""
    @State private var household = ""
    @State private var joinInput = ""
    @State private var joinError: String?
    @State private var personName = ""
    @State private var personRole: MemberRole = .child
    @State private var pendingPhoto: Data?
    @State private var photoTarget: PhotoTarget?
    @State private var photoItem: PhotosPickerItem?
    @State private var cropPayload: PhotoCropPayload?
    @State private var city = ""
    @State private var prefs = HubNotifyPrefs.off
    @StateObject private var weather = WeatherLoader()

    enum Path { case create, join }
    enum Field { case owner, house, person, city, join }
    enum PhotoTarget: Identifiable {
        case owner
        case member(UUID)
        case draft
        var id: String {
            switch self {
            case .owner: return "owner"
            case .member(let id): return id.uuidString
            case .draft: return "draft"
            }
        }
    }

    private var lastPage: Int { path == .join ? 2 : 6 }
    private var compact: Bool { sizeClass == .compact }
    private var deviceWord: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "phone"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            progress
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Group {
                switch displayedPage {
                case 0: gate
                case 1:
                    if path == .join { joinPage } else { youPage }
                case 2:
                    if path == .join { joinReady } else { familyPage }
                case 3: placePage
                case 4: calendarPage
                case 5: pingsPage
                default: readyPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button(primaryTitle) { advance() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(AppTheme.bg.opacity(0.96))
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { focused = nil }
        .onAppear {
            household = store.householdName
            ownerName = store.signedInMember()?.name ?? ""
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            if photoTarget == nil {
                photoTarget = page == 1 ? .owner : .draft
            }
            Task { await loadPickedPhoto(item) }
        }
        .fullScreenCover(item: $cropPayload) { payload in
            PhotoCropper(
                image: payload.image,
                onCancel: { cropPayload = nil; photoItem = nil },
                onCrop: { data in
                    applyCrop(data)
                    cropPayload = nil
                    photoItem = nil
                }
            )
        }
    }

    private var displayedPage: Int { page }

    private var header: some View {
        HStack {
            if page > 0 {
                Button("Back") {
                    focused = nil
                    withAnimation { page -= 1 }
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 64, alignment: .leading)
            } else {
                Color.clear.frame(width: 64, height: 1)
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
                    .frame(width: 64, alignment: .trailing)
            } else {
                Color.clear.frame(width: 64, height: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var primaryTitle: String {
        if page == 0 { return "Continue" }
        if path == .join { return page == lastPage ? "Open HUB" : "Join this HUB" }
        return page == lastPage ? "Open my HUB" : "Next"
    }

    private var progress: some View {
        HStack(spacing: 5) {
            ForEach(0...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? AppTheme.blue : AppTheme.blueSoft)
                    .frame(height: 5)
            }
        }
    }

    private func advance() {
        focused = nil
        if page == 0 { withAnimation { page = 1 }; return }
        if path == .join {
            if page == 1 {
                guard tryJoin() else { return }
            }
            if page < lastPage { withAnimation { page += 1 } } else { finish() }
            return
        }
        if page == 1 { saveYou() }
        if page == 2 { store.setHouseholdName(clean(household).isEmpty ? ownerName : household) }
        if page < lastPage { withAnimation { page += 1 } } else { finish() }
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveYou() {
        let name = clean(ownerName)
        guard !name.isEmpty else { return }
        let member: FamilyMember
        if store.members.isEmpty {
            member = store.addQuickMember(name: name, role: .parent, asOwner: true)
        } else if var me = store.signedInMember() {
            me.name = name
            me.role = .parent
            store.updateMember(me)
            store.setOwner(me.id)
            member = me
        } else {
            member = store.addQuickMember(name: name, role: .parent, asOwner: true)
        }
        if let pendingPhoto {
            store.setMemberPhoto(member.id, data: pendingPhoto)
        }
        if clean(household).isEmpty {
            household = "\(name.components(separatedBy: " ").first ?? name) family"
        }
    }

    private func addPerson() {
        let name = clean(personName)
        guard !name.isEmpty else { return }
        let member = store.addQuickMember(name: name, role: personRole)
        if let pendingPhoto {
            store.setMemberPhoto(member.id, data: pendingPhoto)
        }
        personName = ""
        pendingPhoto = nil
        personRole = .child
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
        joinError = "That code is not this HUB. Open HUB on the owner’s device and copy the code."
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

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run { cropPayload = PhotoCropPayload(image: image) }
    }

    private func applyCrop(_ data: Data) {
        switch photoTarget {
        case .owner, .none:
            pendingPhoto = data
            if let me = store.signedInMember() {
                store.setMemberPhoto(me.id, data: data)
            }
        case .member(let id):
            store.setMemberPhoto(id, data: data)
        case .draft:
            pendingPhoto = data
        }
        photoTarget = nil
    }

    private var ownerPreview: UIImage? {
        if let pendingPhoto { return UIImage(data: pendingPhoto) }
        if let me = store.signedInMember(), let data = store.photo(for: me) {
            return UIImage(data: data)
        }
        return nil
    }

    private var gate: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("HubMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 88 : 120, height: compact ? 88 : 120)
                Text("Build your HUB")
                    .font(.system(size: compact ? 30 : 36, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Calendars, dinner, chores, and the people in your house — one place.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                pathCard("Create this HUB", "You’re the owner. Invite the family after setup.", "house.fill", path == .create) {
                    path = .create
                }
                pathCard("Join a family HUB", "Someone already built one. Enter their code.", "person.badge.plus", path == .join) {
                    path = .join
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
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
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline.weight(.bold)).foregroundStyle(AppTheme.text)
                    Text(detail)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(on ? AppTheme.blue : AppTheme.cardBorder, lineWidth: on ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var youPage: some View {
        setupCard("This is you", "Add your name and the photo that shows on the Hub.") {
            VStack(spacing: 16) {
                ownerPhotoButton
                VStack(alignment: .leading, spacing: 8) {
                    Text("First name")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Your name", text: $ownerName)
                        .textFieldStyle(.plain)
                        .font(.title3.weight(.semibold))
                        .padding(14)
                        .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .focused($focused, equals: .owner)
                        .submitLabel(.next)
                        .onSubmit { focused = nil }
                }
                Text("You’ll be the parent / owner. Change that later in Profiles if you need to.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var ownerPhotoButton: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(AppTheme.blueSoft)
                    if let ownerPreview {
                        Image(uiImage: ownerPreview)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.blue, lineWidth: 3))
                Text(ownerPreview == nil ? "Add photo" : "Move and scale")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onTapGesture { photoTarget = .owner }
    }

    private var familyPage: some View {
        setupCard("Your family", "Name the house, then add each person. Tap a circle to set the photo they will see on the Hub.") {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Household name", text: $household)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .padding(14)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($focused, equals: .house)

                ForEach(store.members) { member in
                    personRow(member)
                }

                draftAddRow
            }
        }
    }

    private func personRow(_ member: FamilyMember) -> some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                MemberAvatar(member: member, size: 56)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(AppTheme.blue, in: Circle())
                    }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded { photoTarget = .member(member.id) })

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name).font(.headline.weight(.bold))
                Text(member.id == store.ownerID ? "Owner · \(member.role.label)" : member.role.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            if store.members.count > 1 && member.id != store.ownerID {
                Button {
                    store.deleteMember(member.id)
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(AppTheme.chore)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var draftAddRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        Circle().fill(AppTheme.blueSoft)
                        if let pendingPhoto, let image = UIImage(data: pendingPhoto) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "plus")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.blue, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { photoTarget = .draft })

                TextField("Add someone", text: $personName)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .padding(.vertical, 10)
                    .focused($focused, equals: .person)
                    .submitLabel(.done)
                    .onSubmit { addPerson() }
            }
            HStack {
                Picker("Role", selection: $personRole) {
                    ForEach(MemberRole.allCases) { role in
                        Text(role.label).tag(role)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.blue)
                Spacer()
                Button("Add") { addPerson() }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(clean(personName).isEmpty ? AppTheme.blue.opacity(0.4) : AppTheme.blue, in: Capsule())
                    .disabled(clean(personName).isEmpty)
            }
        }
        .padding(12)
        .background(AppTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.blue.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var placePage: some View {
        setupCard("Home base", "Weather follows this \(deviceWord) unless you pin a city.") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    focused = nil
                    Task {
                        if let here = try? await weather.placeFromCurrentLocation() {
                            store.setWeatherPlace(here, followMe: true)
                            city = here.label
                        }
                    }
                } label: {
                    Label("Use where I am now", systemImage: "location.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                TextField("City or ZIP", text: $city)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($focused, equals: .city)
                    .onChange(of: city) { _, value in
                        Task { await weather.search(query: value) }
                    }

                ForEach(weather.searchResults.prefix(5)) { place in
                    Button {
                        store.setWeatherPlace(place, followMe: false)
                        city = place.label
                        focused = nil
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(AppTheme.blue)
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
                    Text("Units").font(.headline.weight(.bold))
                    Spacer()
                    unitChip("US", store.units == .us) { store.setUnits(.us) }
                    unitChip("Metric", store.units == .metric) { store.setUnits(.metric) }
                }
            }
        }
    }

    private func unitChip(_ title: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline.weight(.bold))
            .foregroundStyle(on ? .white : AppTheme.blue)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(on ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
    }

    private var calendarPage: some View {
        setupCard("Calendars", "HUB reads the calendars on this \(deviceWord) and writes new events back.") {
            VStack(alignment: .leading, spacing: 12) {
                if ingest.isAuthorized {
                    ForEach(store.calendarSources.prefix(8)) { source in
                        HStack {
                            Image(systemName: source.brand.symbol).foregroundStyle(AppTheme.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.title).font(.headline)
                                if CalendarSource.looksLikeBills(source.title) {
                                    Text("Looks like bills")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.reminder)
                                }
                            }
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
                        Text("No calendars yet. Add iCloud, Google, or Outlook in Settings.")
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text("Bills calendar")
                        .font(.headline.weight(.bold))
                        .padding(.top, 6)
                    Text("Pick one so due dates stay off the family calendar.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    BillsCalendarPicker(compact: true)
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
        setupCard("Pings", "Everything starts off. Turn on only what you want HUB to send.") {
            VStack(spacing: 8) {
                pingRow("Sunrise brief", "Morning rundown of the house.", $prefs.morningBrief)
                pingRow("Before events", "A tap before a calendar event.", $prefs.eventPings)
                pingRow("Dinner lock-in", "Tonight’s meal is set or still empty.", $prefs.dinnerPing)
                pingRow("Chore check", "A chore is due or waiting.", $prefs.chorePing)
                pingRow("Bills Due", "A bill on your bills calendar is coming up.", $prefs.billsPing)
                pingRow("Shopping nudge", "Items are on the list before you leave.", $prefs.shoppingPing)
            }
        }
    }

    private func pingRow(_ title: String, _ detail: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(AppTheme.textSecondary)
            }
        }
        .tint(AppTheme.blue)
        .padding(12)
        .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var readyPage: some View {
        setupCard("Your HUB is live", "Share the code. Family who join see calendars, meals, chores, and shopping.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Family join code")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text(store.joinCode)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.blue)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                ShareLink(item: "Join our family HUB. Code: \(store.joinCode). Open HUB Circle and tap Join.") {
                    Label("Share code", systemImage: "square.and.arrow.up.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var joinPage: some View {
        setupCard("Enter the family code", "Six characters from the owner. Then tap your profile.") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("ABC123", text: $joinInput)
                    .textInputAutocapitalization(.characters)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(14)
                    .background(AppTheme.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($focused, equals: .join)
                if let joinError {
                    Text(joinError).foregroundStyle(AppTheme.chore).font(.subheadline.weight(.semibold))
                }
                if joinInput.replacingOccurrences(of: " ", with: "").uppercased() == store.joinCode.uppercased() {
                    Text("Who are you?")
                        .font(.headline)
                    ForEach(store.members) { member in
                        Button {
                            store.setSignedIn(member.id)
                        } label: {
                            HStack {
                                MemberAvatar(member: member, size: 56)
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
        setupCard("You’re in", "This \(deviceWord) follows \(store.signedInMember()?.name ?? "your") profile. Dinner, chores, and calendars stay in the shared HUB.") {
            Text("Open HUB to see today’s board.")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func setupCard<Content: View>(_ title: String, _ detail: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: compact ? 26 : 32, weight: .bold))
                Text(detail)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                content()
            }
            .padding(compact ? 16 : 22)
            .frame(maxWidth: 640, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 2.5)
            )
            .padding(.horizontal, compact ? 16 : 24)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}
