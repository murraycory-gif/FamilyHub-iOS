import MapKit
import SwiftUI
import PhotosUI
import UIKit

enum HubProfile: Hashable {
    case family
    case member(UUID)
}

struct TodayView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var profile: HubProfile = .family
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var showDayMenu = false
    @State private var pendingDay: Date?
    @State private var showProfileMenu = false
    @State private var pendingProfile: HubProfile?
    @StateObject private var weather = WeatherLoader()
    @State private var showWeatherOutlook = false
    @State private var outlookDay = Date()
    @State private var showWeatherPlace = false
    @State private var showAddShopping = false
    @State private var shoppingDraft = ""
    @State private var showDinnerLaunch: DinnerLaunch?
    @State private var agendaEvent: CalendarEvent?
    @State private var pickSlot: Int?
    @State private var showAddFlight = false
    @State private var flightDay = Date()
    @State private var showAddPackage = false
    @State private var showAddMember = false
    @State private var pageIndex: Int? = 0

    private var accent: Color {
        switch profile {
        case .family:
            return AppTheme.blue
        case .member(let id):
            if let hex = store.member(id: id)?.colorHex { return Color(hex: hex) }
            return AppTheme.blue
        }
    }

    var body: some View {
        GeometryReader { geo in
            let compact = sizeClass == .compact
            let portrait = geo.size.height > geo.size.width
            let padX: CGFloat = compact ? 14 : 22
            let familyH = familyStripHeight(portrait: portrait, compact: compact, screen: geo.size.height)
            VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                header(compact: compact, portrait: portrait)
                dayPager(portrait: portrait, compact: compact)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                familySection(
                    portrait: portrait,
                    compact: compact
                )
                .frame(height: familyH)
            }
            .animation(nil, value: selectedDay)
            .padding(.horizontal, padX)
            .padding(.top, compact ? 2 : 4)
            .padding(.bottom, compact ? 8 : 12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .environment(\.hubAccent, accent)
        .onAppear {
            let start = Calendar.current.startOfDay(for: selectedDay)
            selectedDay = start
            pageIndex = indexOfDay(start)
        }
        .onChange(of: pageIndex) { _, idx in
            guard let idx else { return }
            let day = dayAt(idx)
            if dayStamp(day) != dayStamp(selectedDay) {
                selectedDay = day
            }
        }
        .sheet(isPresented: $showDayMenu, onDismiss: commitPendingDay) {
            daySheet
        }
        .sheet(isPresented: $showProfileMenu, onDismiss: commitPendingProfile) {
            profileSheet
        }
        .fullScreenCover(item: $showDinnerLaunch) { item in
            DinnerLaunchView(item: item) {
                showDinnerLaunch = nil
                router.open(.today)
            }
            .environmentObject(store)
            .environmentObject(router)
        }
        .fullScreenCover(isPresented: $showWeatherOutlook) {
            WeatherOutlookView(day: outlookDay)
                .environmentObject(store)
                .environmentObject(weather)
        }
        .sheet(isPresented: $showWeatherPlace) {
            WeatherPlacePicker()
                .environmentObject(store)
                .environmentObject(weather)
        }
        .sheet(item: $agendaEvent) { event in
            EventDetailSheet(event: event)
        }
        .sheet(isPresented: Binding(
            get: { pickSlot != nil },
            set: { if $0 == false { pickSlot = nil } }
        )) {
            HubWidgetPickSheet(current: pickSlot.flatMap { visibleWidgets(for: selectedDay)[safe: $0] }) { kind in
                if let slot = pickSlot {
                    store.setHubWidget(at: slot, kind: kind)
                    if kind == .flights {
                        flightDay = selectedDay
                        showAddFlight = true
                    }
                    if kind == .packages, store.packages.filter({ !$0.isDelivered }).isEmpty {
                        showAddPackage = true
                    }
                }
                pickSlot = nil
            }
        }
        .sheet(isPresented: $showAddFlight) {
            AddFlightSheet(day: flightDay)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAddPackage) {
            AddPackageSheet()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showAddMember) {
            EditMemberSheet(member: nil)
                .environmentObject(store)
        }
        .task {
            await refreshWeatherFromHere()
            while !Task.isCancelled {
                await weather.load(place: store.weatherPlace ?? .chicago, units: store.units)
                try? await Task.sleep(for: .seconds(10 * 60))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshWeatherFromHere() }
            }
        }
        .onChange(of: store.weatherPlace?.id) { _, _ in
            if let place = store.weatherPlace {
                Task { await weather.load(place: place, units: store.units) }
            }
        }
        .onChange(of: store.units) { _, _ in
            if let place = store.weatherPlace {
                Task { await weather.load(place: place, units: store.units) }
            }
        }
        .alert("Add to shopping list", isPresented: $showAddShopping) {
            TextField("Item", text: $shoppingDraft)
            Button("Add") {
                store.addShoppingItem(shoppingDraft)
                shoppingDraft = ""
            }
            Button("Cancel", role: .cancel) { shoppingDraft = "" }
        }
    }

    private func refreshWeatherFromHere() async {
        if store.weatherFollowsMe, let here = try? await weather.placeFromCurrentLocation() {
            store.setWeatherPlace(here, followMe: true)
        }
        if let place = store.weatherPlace {
            await weather.load(place: place, units: store.units)
        }
    }

    private var homeTileH: CGFloat { sizeClass == .regular ? 168 : 148 }

    @ViewBuilder
    private func dashboard(for day: Date, portrait: Bool, compact: Bool) -> some View {
        let tiles = visibleWidgets(for: day)
        let top = tiles[safe: 0] ?? .weather
        let low = tiles[safe: 1] ?? .shopping
        let tall = tiles[safe: 2] ?? .dinner
        let extra = tiles[safe: 3]
        let gap: CGFloat = compact ? 8 : 12
        if portrait {
            VStack(spacing: gap) {
                HStack(alignment: .top, spacing: gap) {
                    agenda(for: day)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack(spacing: gap) {
                        widgetSlot(top, day: day, index: 0)
                        widgetSlot(low, day: day, index: 1)
                    }
                    .frame(maxWidth: .infinity)
                }
                if let extra {
                    HStack(spacing: gap) {
                        widgetSlot(tall, day: day, index: 2)
                        widgetSlot(extra, day: day, index: 3)
                    }
                    .frame(height: compact ? 132 : 176)
                } else {
                    widgetSlot(tall, day: day, index: 2, offerAddUnder: true)
                        .frame(maxWidth: .infinity)
                        .frame(height: compact ? 132 : 176)
                }
            }
        } else {
            HStack(alignment: .top, spacing: gap) {
                agenda(for: day)
                    .frame(maxWidth: compact ? 220 : .infinity, maxHeight: .infinity)
                VStack(spacing: gap) {
                    widgetSlot(top, day: day, index: 0)
                    widgetSlot(low, day: day, index: 1)
                }
                .frame(maxWidth: .infinity)
                if let extra {
                    VStack(spacing: gap) {
                        widgetSlot(tall, day: day, index: 2, offerExpand: true)
                        widgetSlot(extra, day: day, index: 3)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    widgetSlot(tall, day: day, index: 2, offerAddUnder: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func visibleWidgets(for day: Date) -> [HubWidgetKind] {
        var kinds = store.hubWidgets.map(\.kind).filter { HubWidgetKind.choosable.contains($0) }
        if kinds.isEmpty {
            kinds = [.weather, .shopping, .dinner]
        }
        for extra in HubWidgetKind.choosable where kinds.count < 3 && !kinds.contains(extra) {
            kinds.append(extra)
        }
        let needsShopping = store.shoppingItems.contains {
            $0.isChecked == false && $0.sourceDay.map { Calendar.current.isDate($0, inSameDayAs: day) } == true
        }
        if needsShopping, kinds.contains(.shopping) == false {
            if kinds.count < 4 {
                kinds.append(.shopping)
            } else if kinds.indices.contains(1), kinds[1] != .flights {
                kinds[1] = .shopping
            }
        }
        let dayHasFlight = !FlightParse.flights(on: day, events: store.events, extra: store.flights).isEmpty
        if dayHasFlight, kinds.contains(.flights) == false {
            if kinds.count < 4 {
                kinds.append(.flights)
            } else if let i = kinds.firstIndex(of: .shopping) {
                kinds[i] = .flights
            } else if kinds.indices.contains(1) {
                kinds[1] = .flights
            }
        }
        let dayHasBills = store.billsDue(on: day).isEmpty == false
        if dayHasBills, kinds.contains(.bills) == false {
            if kinds.count < 4 {
                kinds.append(.bills)
            } else if let i = kinds.firstIndex(of: .packages) {
                kinds[i] = .bills
            }
        }
        let leavingSoon = store.events.contains {
            Calendar.current.isDate($0.startAt, inSameDayAs: day) &&
            $0.allDay == false &&
            $0.startAt.timeIntervalSinceNow < 3 * 3600 &&
            $0.startAt.timeIntervalSinceNow > -15 * 60
        }
        if leavingSoon, kinds.contains(.leaving) == false, kinds.count < 4 {
            kinds.append(.leaving)
        }
        if store.packages.contains(where: { $0.isDelivered == false }), kinds.contains(.packages) == false, kinds.count < 4 {
            kinds.append(.packages)
        }
        let birthdaySoon = store.members.contains { member in
            guard let when = member.nextBirthday(from: day) else { return false }
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: day), to: when).day ?? 99
            return days <= 14
        }
        if birthdaySoon, kinds.contains(.birthdays) == false, kinds.count < 4 {
            kinds.append(.birthdays)
        }
        let choresDue = store.assignments.contains {
            Calendar.current.isDate($0.dueOn, inSameDayAs: day) && $0.status == .pending
        }
        if choresDue, kinds.contains(.scoreboard) == false, kinds.count < 4 {
            kinds.append(.scoreboard)
        }
        if store.whiteboardNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
           kinds.contains(.whiteboard) == false, kinds.count < 4 {
            kinds.append(.whiteboard)
        }
        return Array(kinds.prefix(4))
    }

    @ViewBuilder
    private func widgetSlot(
        _ kind: HubWidgetKind,
        day: Date,
        index: Int,
        offerAddUnder: Bool = false,
        offerExpand: Bool = false
    ) -> some View {
        widgetTile(kind, day: day, live: Calendar.current.isDate(day, inSameDayAs: selectedDay))
            .overlay(alignment: .topTrailing) {
                Button { pickSlot = index } label: {
                    Text("Change")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.trailing, 10)
            }
            .overlay(alignment: .bottom) {
                if offerAddUnder {
                    Button {
                        store.addWidgetUnderRight()
                    } label: {
                        Label("Add one under", systemImage: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 10)
                } else if offerExpand {
                    Button {
                        store.makeRightWidgetBigger()
                    } label: {
                        Label("Make bigger", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 10)
                }
            }
    }

    @ViewBuilder
    private func widgetTile(_ kind: HubWidgetKind, day: Date, live: Bool) -> some View {
        switch kind {
        case .weather:
            weatherTile(for: day, live: live)
        case .shopping:
            shoppingTile
        case .dinner:
            dinnerHomeTile(for: day)
        case .flights:
            FlightWidget(day: day, onAdd: {
                flightDay = day
                showAddFlight = true
            })
        case .packages:
            PackageWidget(onAdd: { showAddPackage = true })
        case .bills:
            BillsWidget(day: day)
        case .leaving:
            LeavingWidget(day: day)
        case .scoreboard:
            ScoreboardWidget(day: day)
        case .whiteboard:
            WhiteboardWidget()
        case .birthdays:
            BirthdayWidget(day: day)
        default:
            shoppingTile
        }
    }

    private var greetingLead: String { "Good" }

    private var greetingTail: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Morning" }
        if hour < 17 { return "Afternoon" }
        return "Evening"
    }

    private func filterPanel(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HubTileBanner(
                symbol: showDayMenu ? "calendar" : "person.3.fill",
                title: showDayMenu ? "Pick a day" : "Who’s Hub"
            ) {
                Button {
                    showDayMenu = false
                    showProfileMenu = false
                } label: {
                    Text("Done")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                VStack(spacing: 8) {
                    if showDayMenu {
                        ForEach(Array(upcomingDays.enumerated()), id: \.offset) { _, day in
                            Button {
                                applyDay(day)
                            } label: {
                                filterChoiceRow(
                                    title: menuDayLabel(day),
                                    detail: Date.hubLongDay(day),
                                    selected: Calendar.current.isDate(day, inSameDayAs: selectedDay)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Button {
                            applyProfile(.family)
                        } label: {
                            filterChoiceRow(title: "Whole family", detail: store.householdName, selected: profile == .family)
                        }
                        .buttonStyle(.plain)
                        ForEach(store.members) { member in
                            Button {
                                applyProfile(.member(member.id))
                            } label: {
                                filterChoiceRow(
                                    title: member.name,
                                    detail: member.role.label,
                                    selected: profile == .member(member.id),
                                    color: Color(hex: member.colorHex)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: width, height: height)
        .background(AppTheme.bg)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
    }

    private var header: some View {
        header(compact: sizeClass == .compact, portrait: true)
    }

    private func header(compact: Bool, portrait: Bool) -> some View {
        Group {
            if compact && portrait {
                VStack(alignment: .leading, spacing: 8) {
                    greeting
                    HStack(spacing: 8) {
                        dateButton(compact: true)
                        profileButton(compact: true)
                    }
                }
            } else {
                HStack(alignment: .center, spacing: compact ? 8 : 12) {
                    greeting
                    Spacer(minLength: 8)
                    dateButton(compact: compact)
                    profileButton(compact: compact)
                }
            }
        }
    }

    private var greeting: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(greetingLead)
                .foregroundStyle(AppTheme.text)
            Text(greetingTail)
                .foregroundStyle(accent)
        }
        .font(.system(size: sizeClass == .compact ? 26 : 34, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var dateButton: some View { dateButton(compact: false) }

    private func dateButton(compact: Bool) -> some View {
        Button { showDayMenu = true } label: {
            filterBanner(symbol: "calendar", title: shortDayName, compact: compact)
        }
        .buttonStyle(.plain)
    }

    private var profileButton: some View { profileButton(compact: false) }

    private func profileButton(compact: Bool) -> some View {
        Button { showProfileMenu = true } label: {
            filterBanner(symbol: "person.3.fill", title: shortProfileName, compact: compact)
        }
        .buttonStyle(.plain)
    }

    private func filterBanner(symbol: String, title: String, compact: Bool = false) -> some View {
        HStack(spacing: compact ? 5 : 8) {
            Image(systemName: symbol)
                .font((compact ? Font.subheadline : Font.body).weight(.bold))
            Text(title)
                .font((compact ? Font.subheadline : Font.headline).weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 12)
        .background(accent, in: RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous))
    }

    private func filterChoiceRow(title: String, detail: String = "", selected: Bool, color: Color = AppTheme.blue) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 6, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(selected ? AppTheme.blueSoft : AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? AppTheme.blue : AppTheme.cardBorder, lineWidth: selected ? 3 : 1)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var profileAvatar: some View {
        switch profile {
        case .family:
            ZStack {
                Circle().fill(AppTheme.blueSoft)
                Image(systemName: "person.3.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 28, height: 28)
        case .member(let id):
            if let member = store.member(id: id) {
                MemberAvatar(member: member, size: 28)
            }
        }
    }

    private var shortProfileName: String {
        switch profile {
        case .family: return "Family"
        case .member(let id): return store.member(id: id)?.name ?? "Family"
        }
    }

    private var profileTitle: String {
        switch profile {
        case .family: return "\(store.householdName) family"
        case .member(let id): return store.member(id: id)?.name ?? "Family"
        }
    }

    private var profileSubtitle: String {
        switch profile {
        case .family: return "Whole household"
        case .member(let id): return store.member(id: id)?.role.label ?? "Member"
        }
    }

    private func openDinner() {
        let day = Calendar.current.startOfDay(for: selectedDay)
        let pick = store.dinner(on: day) == nil
        DispatchQueue.main.async {
            showDinnerLaunch = DinnerLaunch(day: day, pick: pick)
        }
    }

    private var hubDayCount: Int { 14 }

    private func dayAt(_ index: Int) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: min(max(0, index), hubDayCount - 1), to: start) ?? start
    }

    private func indexOfDay(_ day: Date) -> Int {
        let start = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: day)
        let n = Calendar.current.dateComponents([.day], from: start, to: target).day ?? 0
        return min(max(0, n), hubDayCount - 1)
    }

    private func dayStamp(_ date: Date) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970)
    }

    private func dayPager(portrait: Bool, compact: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(0..<hubDayCount, id: \.self) { index in
                    dashboard(for: dayAt(index), portrait: portrait, compact: compact)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageIndex)
        .clipped()
    }

    private var upcomingDays: [Date] {
        (0..<hubDayCount).map { dayAt($0) }
    }

    private func menuDayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return Date.hubLongDay(day)
    }

    private func applyDay(_ day: Date) {
        pendingDay = Calendar.current.startOfDay(for: day)
        showDayMenu = false
    }

    private func applyProfile(_ next: HubProfile) {
        pendingProfile = next
        showProfileMenu = false
    }

    private func commitPendingDay() {
        if let day = pendingDay {
            selectedDay = day
            pageIndex = indexOfDay(day)
        }
        pendingDay = nil
    }

    private func commitPendingProfile() {
        if let next = pendingProfile {
            profile = next
        }
        pendingProfile = nil
    }

    private var daySheet: some View {
        VStack(spacing: 0) {
            sheetChrome("Pick a day") { showDayMenu = false }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(upcomingDays.enumerated()), id: \.offset) { _, day in
                        Button {
                            applyDay(day)
                        } label: {
                            filterChoiceRow(
                                title: menuDayLabel(day),
                                detail: Date.hubLongDay(day),
                                selected: Calendar.current.isDate(day, inSameDayAs: selectedDay)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg)
        .presentationDetents([.medium, .large])
    }

    private var profileSheet: some View {
        VStack(spacing: 0) {
            sheetChrome("Profile") { showProfileMenu = false }
            ScrollView {
                VStack(spacing: 8) {
                    Button {
                        applyProfile(.family)
                    } label: {
                        filterChoiceRow(title: "Whole family", detail: store.householdName, selected: profile == .family)
                    }
                    .buttonStyle(.plain)
                    ForEach(store.members) { member in
                        Button {
                            applyProfile(.member(member.id))
                        } label: {
                            filterChoiceRow(
                                title: member.name,
                                detail: member.role.label,
                                selected: profile == .member(member.id),
                                color: Color(hex: member.colorHex)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg)
        .presentationDetents([.medium, .large])
    }

    private func sheetChrome(_ title: String, close: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: "calendar")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Button("Done", action: close)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(accent)
    }

    private var shortDayName: String {
        if Calendar.current.isDateInToday(selectedDay) { return "Today" }
        if Calendar.current.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        return Date.hubShortDay(selectedDay)
    }

    private var agenda: some View { agenda(for: selectedDay) }

    private func agenda(for day: Date) -> some View {
        let items = itemsOn(day)
        return VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(
                symbol: "calendar",
                title: Calendar.current.isDateInToday(day) ? "On Today's Agenda" : "On the Agenda"
            ) {
                Text(profileTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(headline(for: day))
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text("\(items.count)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.textTertiary)
                }
                if items.isEmpty {
                    Text(emptyDayCopy)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(Array(uniqueItems(items).prefix(16).enumerated()), id: \.offset) { _, item in
                                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                                    Button { openAgendaItem(item) } label: {
                                        dayRow(item, now: timeline.date)
                                    }
                                    .buttonStyle(HubPressStyle())
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.tableFill)
        }
        .background(AppTheme.card)
        .hubLift(accent: accent)
        .frame(maxHeight: .infinity)
    }

    private var weatherTile: some View { weatherTile(for: selectedDay, live: true) }

    private func weatherTile(for day: Date, live: Bool = false) -> some View {
        HubWeatherTile(
            placeLabel: store.weatherPlace?.label ?? "Chicago",
            now: weather.now,
            day: weather.forecastDay(on: day),
            hours: weather.hoursForTile(on: day, count: 5),
            isToday: Calendar.current.isDateInToday(day),
            isLoading: weather.isLoading,
            live: live && Calendar.current.isDate(day, inSameDayAs: selectedDay),
            onOpen: {
                outlookDay = day
                showWeatherOutlook = true
            },
            onChangePlace: { showWeatherPlace = true }
        )
    }

    private var shoppingTile: some View {
        let open = store.shoppingItems.filter { !$0.isChecked }
        return VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "cart.fill", title: "Shopping List") {
                HStack(spacing: 8) {
                    if open.isEmpty == false {
                        Text("\(open.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white, in: Capsule())
                    }
                    Button {
                        shoppingDraft = ""
                        showAddShopping = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(accent)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add to shopping list")
                }
            }
            Group {
                if open.isEmpty {
                    Button {
                        router.open(.shopping)
                    } label: {
                        VStack(spacing: 6) {
                            Spacer(minLength: 0)
                            Text("Nothing to get")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Tap to open the list")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HubPressStyle())
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(open.prefix(8)) { item in
                                Button {
                                    router.open(.shopping)
                                } label: {
                                    HubAgendaCallout(
                                        rail: accent,
                                        eyebrow: "To get",
                                        title: item.name,
                                        badge: "Shopping",
                                        accent: accent
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.tableFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .hubLift(accent: accent)
    }

    private var nextEventTile: some View {
        let item = dayItems.first
        return Button {
            if let item, item.kind == .event, let uuid = UUID(uuidString: String(item.id.dropFirst(2))) {
                router.openCalendar(filter: dayFilter, day: selectedDay, eventID: uuid)
            } else {
                router.openCalendar(filter: dayFilter, day: selectedDay)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(dayHeadline)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer(minLength: 0)
                if let item {
                    Text(item.timeLabel)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(accent)
                    Text(item.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                    Text(assigneeName(for: item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(assigneeColor(for: item))
                } else {
                    Text("Free")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(accent)
                    Text(emptyDayCopy)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var dinnerHomeTile: some View { dinnerHomeTile(for: selectedDay) }

    private func dinnerHomeTile(for day: Date) -> some View {
        let plan = store.dinner(on: day)
        let recipe = plan.flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) }
        let title = store.dinnerTitle(on: day)
        return VStack(spacing: 0) {
            HubTileBanner(symbol: "fork.knife", title: "What's For Dinner") {
                if plan != nil {
                    Button {
                        store.clearDinner(on: day)
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.white.opacity(0.22), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete dinner")
                }
            }
            Button { openDinner() } label: {
                ZStack(alignment: .bottom) {
                    dinnerPhoto(plan: plan, recipe: recipe, title: title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dinnerEyebrow(plan))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(title ?? "Nothing planned")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        if let side = store.dinnerSide(on: day) {
                            Text("with \(side.name)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(1)
                        }
                        Text(dinnerHint(plan, recipe: recipe))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(AppTheme.card)
        .hubLift(accent: accent)
    }

    @ViewBuilder
    private func dinnerPhoto(plan: DinnerPlan?, recipe: Recipe?, title: String?) -> some View {
        DinnerDayPhoto(plan: plan, recipe: recipe, title: title, quality: .hero)
    }

    private func homeStatTile(title: String, value: String, detail: String = "", symbol: String, color: Color, soft: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(color)
                Spacer(minLength: 0)
                Text(value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.text)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(soft)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func headline(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return Date.hubLongDay(day)
    }

    private var dayHeadline: String { headline(for: selectedDay) }

    private var emptyDayCopy: String {
        switch profile {
        case .family:
            return "Nothing on the family calendar for this day."
        case .member(let id):
            let name = store.member(id: id)?.name ?? "They"
            return "\(name) is free this day."
        }
    }

    private var dayFilter: DayFilter {
        switch profile {
        case .family: return .family
        case .member(let id): return .member(id)
        }
    }

    private var focusedMemberID: UUID? {
        if case .member(let id) = profile { return id }
        return nil
    }

    private var dayItems: [HubDayItem] { itemsOn(selectedDay) }

    private func itemsOn(_ day: Date) -> [HubDayItem] {
        var items: [HubDayItem] = []
        for event in store.events(on: day, filter: dayFilter) {
            items.append(.event(event))
        }
        let calRange = CalendarMath.dayRange(day)
        for reminder in store.reminders where !reminder.isCompleted {
            if reminder.isBills {
                guard profile == .family else { continue }
            } else {
                guard matchesProfile(reminder.memberID) else { continue }
            }
            if let due = reminder.dueAt, let range = calRange, CalendarMath.occurs(due, in: range) {
                items.append(.reminder(reminder))
            }
        }
        for todo in store.todos where !todo.isCompleted {
            guard matchesProfile(todo.memberID) else { continue }
            if let due = todo.dueAt, let range = calRange, CalendarMath.occurs(due, in: range) {
                items.append(.todo(todo))
            }
        }
        for assignment in store.openAssignments(for: focusedMemberID) {
            if let range = calRange, CalendarMath.occurs(assignment.dueOn, in: range) {
                let title = store.chore(id: assignment.choreID)?.title ?? "Chore"
                items.append(.chore(assignment, title: title))
            }
        }
        return items
            .filter { $0.sortDate.timeIntervalSince1970.isFinite }
            .sorted {
                let a = $0.sortDate.timeIntervalSince1970
                let b = $1.sortDate.timeIntervalSince1970
                return (a.isFinite ? a : 0) < (b.isFinite ? b : 0)
            }
    }

    private func uniqueItems(_ items: [HubDayItem]) -> [HubDayItem] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    private func matchesProfile(_ memberID: UUID?) -> Bool {
        switch profile {
        case .family: return true
        case .member(let id): return memberID == nil || memberID == id
        }
    }

    private func openAgendaItem(_ item: HubDayItem) {
        switch item.kind {
        case .event:
            if let id = UUID(uuidString: String(item.id.dropFirst(2))),
               let event = store.events.first(where: { $0.id == id }) {
                agendaEvent = event
            }
        case .reminder:
            router.open(.lists, list: .reminders)
        case .todo:
            router.open(.lists, list: .todos)
        case .chore:
            router.open(.chores)
        }
    }

    private func dayRow(_ item: HubDayItem, now: Date = Date()) -> some View {
        let passed = item.hasPassed(now: now)
        let rail = passed ? Color(white: 0.62) : assigneeColor(for: item)
        let ink = passed ? AppTheme.textTertiary : AppTheme.text
        let timeColor = passed ? AppTheme.textTertiary : accent
        return HStack(alignment: .center, spacing: 14) {
            Capsule()
                .fill(rail)
                .frame(width: 5)
                .padding(.vertical, 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.timeLabel)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(timeColor)
                Text(item.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ink)
                    .lineLimit(2)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Text(assigneeName(for: item))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(rail)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(rail.opacity(0.14), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(passed ? Color(hex: "F3F4F6") : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .opacity(passed ? 0.72 : 1)
    }

    private func assigneeName(for item: HubDayItem) -> String {
        if item.detail == "Bills Due" { return "Bills Due" }
        if let id = item.memberID, let member = store.member(id: id) {
            return member.name
        }
        return "Family"
    }

    private func assigneeColor(for item: HubDayItem) -> Color {
        if item.detail == "Bills Due" { return AppTheme.reminder }
        if let id = item.memberID, let member = store.member(id: id) {
            return Color(hex: member.colorHex)
        }
        return AppTheme.blue
    }

    private var dinnerCard: some View {
        let plan = store.dinner(on: selectedDay)
        let recipe = plan.flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) }
        let photoURL = recipe.flatMap { URL(string: $0.imageURL) }
        return Button { openDinner() } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "FFEDD5"))
                    if let photoURL {
                        RecipePhoto(url: photoURL, searchName: recipe?.name ?? "")
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: plan?.placeName != nil ? "mappin.and.ellipse" : "fork.knife")
                            .foregroundStyle(Color(hex: "C2410C"))
                    }
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(dinnerEyebrow(plan))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "C2410C"))
                    Text(store.dinnerTitle(on: selectedDay) ?? "Nothing planned — tap to pick dinner")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                    Text(dinnerHint(plan, recipe: recipe))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "FFF7ED"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func dinnerEyebrow(_ plan: DinnerPlan?) -> String {
        if plan?.placeKind == "delivery" {
            return Calendar.current.isDateInToday(selectedDay) ? "Delivery tonight" : "Delivery"
        }
        if plan?.placeKind == "takeout" {
            return Calendar.current.isDateInToday(selectedDay) ? "Take out tonight" : "Take out"
        }
        if plan?.placeName != nil {
            return Calendar.current.isDateInToday(selectedDay) ? "Eating out tonight" : "Eating out"
        }
        return Calendar.current.isDateInToday(selectedDay) ? "Dinner tonight" : "Dinner"
    }

    private func dinnerHint(_ plan: DinnerPlan?, recipe: Recipe?) -> String {
        if recipe != nil { return "Tap for ingredients and steps" }
        if plan?.placeName != nil { return "Tap for address and directions" }
        if plan != nil { return "Tap to see the plan" }
        return "Tap to plan dinner"
    }

    private var callouts: some View {
        HStack(spacing: 10) {
            Button { router.open(.chores) } label: {
                callout("Open chores", "\(focusedChores.count)", "checkmark.circle.fill", AppTheme.chore, AppTheme.choreSoft)
            }
            .buttonStyle(.plain)
            Button { router.open(.lists, list: .reminders) } label: {
                callout("Reminders", "\(focusedReminders.count)", "bell.fill", AppTheme.reminder, AppTheme.reminderSoft)
            }
            .buttonStyle(.plain)
            Button { router.open(.lists, list: .todos) } label: {
                callout("To-dos", "\(focusedTodos.count)", "square.and.pencil", AppTheme.todo, AppTheme.todoSoft)
            }
            .buttonStyle(.plain)
        }
    }

    private var focusedChores: [ChoreAssignment] { store.openAssignments(for: focusedMemberID) }
    private var focusedReminders: [ReminderItem] {
        store.reminders.filter { !$0.isCompleted && matchesProfile($0.memberID) }
    }
    private var focusedTodos: [TodoItem] {
        store.todos.filter { !$0.isCompleted && matchesProfile($0.memberID) }
    }

    private func callout(_ title: String, _ value: String, _ symbol: String, _ color: Color, _ soft: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.text)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(soft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func familyStripHeight(portrait: Bool, compact: Bool, screen: CGFloat) -> CGFloat {
        if compact {
            return portrait ? max(260, screen * 0.40) : max(150, screen * 0.48)
        }
        if portrait {
            return max(400, screen * 0.40)
        }
        return max(440, screen * 0.50)
    }

    private func familyVisibleCount(portrait: Bool, compact: Bool) -> Int {
        let members = max(1, store.members.count)
        let target = compact ? (portrait ? 2 : 3) : (portrait ? 3 : 4)
        return min(members, target)
    }

    private func familySection(portrait: Bool, compact: Bool) -> some View {
        let visible = familyVisibleCount(portrait: portrait, compact: compact)
        let gap: CGFloat = compact ? 8 : 12
        return VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "house.fill", title: "HUB") {
                Button { showAddMember = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                        if compact == false {
                            Text("Add Hub Member")
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, compact ? 8 : 10)
                    .padding(.vertical, 6)
                    .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Hub Member")
            }
            GeometryReader { inner in
                let pad: CGFloat = compact ? 8 : 12
                let cardW = max(132, floor((inner.size.width - pad * 2 - gap * CGFloat(max(0, visible - 1))) / CGFloat(visible)))
                let cardH = max(120, inner.size.height - pad * 2)
                let photoH = min(cardH * 0.46, compact ? 78 : 168)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: gap) {
                        ForEach(store.members) { member in
                            MemberHomeCard(
                                member: member,
                                selected: profile == .member(member.id),
                                day: selectedDay,
                                photoHeight: photoH,
                                onSelect: { profile = .member(member.id) },
                                onEvent: { event in
                                    router.openCalendar(filter: .member(member.id), day: selectedDay, eventID: event.id)
                                }
                            )
                            .frame(width: cardW, height: cardH)
                        }
                    }
                    .padding(pad)
                }
            }
        }
        .background(AppTheme.card)
        .hubLift(accent: accent)
    }
}

private struct HubDayItem: Identifiable {
    enum Kind { case event, reminder, todo, chore }
    var id: String
    var kind: Kind
    var title: String
    var detail: String
    var timeLabel: String
    var sortDate: Date
    var endAt: Date? = nil
    var allDay: Bool = false
    var memberID: UUID?

    var kindLabel: String {
        switch kind {
        case .event: return "Event"
        case .reminder: return "Reminder"
        case .todo: return "To-do"
        case .chore: return "Chore"
        }
    }

    func hasPassed(now: Date = Date()) -> Bool {
        if allDay {
            return Calendar.current.startOfDay(for: now) > Calendar.current.startOfDay(for: sortDate)
        }
        return (endAt ?? sortDate) < now
    }

    static func event(_ event: CalendarEvent) -> HubDayItem {
        HubDayItem(
            id: "e-\(event.id)",
            kind: .event,
            title: String(event.title.prefix(80)),
            detail: String(event.location.prefix(80)),
            timeLabel: event.allDay ? "All day" : Date.hubClock(event.startAt),
            sortDate: event.startAt,
            endAt: event.endAt,
            allDay: event.allDay,
            memberID: event.memberID
        )
    }

    static func reminder(_ item: ReminderItem) -> HubDayItem {
        HubDayItem(
            id: "r-\(item.id)",
            kind: .reminder,
            title: item.title,
            detail: item.isBills ? "Bills Due" : "",
            timeLabel: item.dueAt.map(Date.hubClock) ?? "Due",
            sortDate: item.dueAt ?? Date(),
            memberID: item.memberID
        )
    }

    static func todo(_ item: TodoItem) -> HubDayItem {
        HubDayItem(
            id: "t-\(item.id)",
            kind: .todo,
            title: item.title,
            detail: item.notes,
            timeLabel: item.dueAt.map(Date.hubClock) ?? "Due",
            sortDate: item.dueAt ?? Date(),
            memberID: item.memberID
        )
    }

    static func chore(_ assignment: ChoreAssignment, title: String) -> HubDayItem {
        HubDayItem(
            id: "c-\(assignment.id)",
            kind: .chore,
            title: title,
            detail: "",
            timeLabel: "Due",
            sortDate: assignment.dueOn,
            memberID: assignment.memberID
        )
    }
}

private struct FamilyFocusCard: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.hubAccent) private var accent
    let selected: Bool
    let day: Date
    var photoHeight: CGFloat = 118
    var onSelect: () -> Void
    var onEvent: (CalendarEvent) -> Void
    @State private var showStudio = false

    private var events: [CalendarEvent] {
        store.events(on: day, filter: .family)
    }

    private var billsDue: Int {
        guard let range = CalendarMath.dayRange(day) else { return 0 }
        return store.reminders.filter {
            $0.isBills && !$0.isCompleted && ($0.dueAt.map { CalendarMath.occurs($0, in: range) } ?? false)
        }.count
    }

    var body: some View {
        AmazonPersonCard(
            image: HubPhoto.image(key: "family", data: store.familyPhotoData),
            emoji: nil,
            fallback: "person.3.fill",
            name: "Family",
            eventCount: events.count,
            ring: accent,
            selected: selected,
            photoHeight: photoHeight,
            onCamera: { showStudio = true },
            onSelect: onSelect
        ) {
            DayStatusRow(
                chores: {
                    guard let range = CalendarMath.dayRange(day) else { return 0 }
                    return store.openAssignments(for: nil).filter { $0.status == .pending && CalendarMath.occurs($0.dueOn, in: range) }.count
                }(),
                bills: billsDue,
                todos: {
                    guard let range = CalendarMath.dayRange(day) else { return 0 }
                    return store.todos.filter { !$0.isCompleted && ($0.dueAt.map { CalendarMath.occurs($0, in: range) } ?? false) }.count
                }(),
                onChores: { router.open(.chores) },
                onBills: { router.open(.lists, list: .reminders) },
                onTodos: { router.open(.lists, list: .todos) }
            )
            EventScroll(events: events, onEvent: onEvent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $showStudio) {
            BannerStudio(title: "Family", current: store.familyPhotoData) { data in
                store.setFamilyPhoto(data)
            }
        }
    }
}

private struct MemberHomeCard: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    let member: FamilyMember
    var selected = false
    let day: Date
    var photoHeight: CGFloat = 118
    var onSelect: () -> Void
    var onEvent: (CalendarEvent) -> Void
    @State private var showStudio = false

    private var chores: [ChoreAssignment] {
        guard let range = CalendarMath.dayRange(day) else { return [] }
        return store.openAssignments(for: member.id).filter {
            $0.status == .pending && CalendarMath.occurs($0.dueOn, in: range)
        }
    }
    private var todos: [TodoItem] {
        guard let range = CalendarMath.dayRange(day) else { return [] }
        return store.openTodos(for: member.id).filter { item in
            item.dueAt.map { CalendarMath.occurs($0, in: range) } ?? false
        }
    }
    private var events: [CalendarEvent] {
        store.events(on: day, filter: .member(member.id))
    }
    private var accent: Color { Color(hex: member.colorHex) }
    private var firstName: String {
        member.name.split(separator: " ").first.map(String.init) ?? member.name
    }

    var body: some View {
        AmazonPersonCard(
            image: HubPhoto.image(key: member.id.uuidString, data: store.photo(for: member)),
            emoji: member.displayEmoji,
            fallback: nil,
            name: firstName,
            eventCount: events.count,
            ring: accent,
            selected: selected,
            photoHeight: photoHeight,
            onCamera: { showStudio = true },
            onSelect: onSelect
        ) {
            DayStatusRow(
                chores: chores.count,
                todos: todos.count,
                onChores: { router.open(.chores) },
                onTodos: { router.open(.lists, list: .todos) }
            )
            EventScroll(events: events, onEvent: onEvent)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .sheet(isPresented: $showStudio) {
            BannerStudio(title: firstName, current: store.photo(for: member)) { data in
                store.setMemberPhoto(member.id, data: data)
            }
        }
    }
}

private struct AmazonPersonCard<Content: View>: View {
    let image: UIImage?
    let emoji: String?
    let fallback: String?
    let name: String
    let eventCount: Int
    let ring: Color
    let selected: Bool
    var photoHeight: CGFloat = 118
    var onCamera: () -> Void
    var onSelect: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: photoHeight)
                .overlay {
                    ZStack {
                        ring
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else if let emoji {
                            Text(emoji).font(.system(size: 58))
                        } else {
                            Image(systemName: fallback ?? "person.fill")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .clipped()
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [.white.opacity(0.28), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .frame(height: 36)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55), .black.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 88)
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(name.isEmpty ? "Profile" : name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .shadow(color: .black.opacity(0.7), radius: 8, y: 1)
                            Text(eventCount == 1 ? "1 EVENT" : "\(eventCount) EVENTS")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ring, in: Capsule())
                                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        }
                        Spacer(minLength: 0)
                        Button(action: onCamera) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.black.opacity(0.45), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelect() }

            HStack(alignment: .top, spacing: 0) {
                Capsule()
                    .fill(ring)
                    .frame(width: 5)
                    .padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(AppTheme.tableFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .hubLift(accent: ring, selected: selected)
    }
}

@ViewBuilder
private func posterBanner<Trailing: View>(
    image: UIImage?,
    colors: [Color],
    fallback: String? = nil,
    emoji: String? = nil,
    name: String,
    chips: [String],
    @ViewBuilder trailing: () -> Trailing
) -> some View {
    Color.clear
        .frame(height: 158)
        .background {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let fallback {
                        Image(systemName: fallback)
                            .font(.system(size: 52))
                            .foregroundStyle(.white.opacity(0.35))
                    } else if let emoji {
                        Text(emoji).font(.system(size: 58))
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                .frame(height: 100)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text(name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 8)
                            trailing()
                        }
                        if !chips.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                                    posterChip(chip)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
        }
        .clipped()
}

private struct DayStatusRow: View {
    let chores: Int
    var bills: Int? = nil
    let todos: Int
    var onChores: () -> Void
    var onBills: (() -> Void)? = nil
    var onTodos: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            box(AppTheme.chore, AppTheme.choreSoft, "checkmark.circle.fill", chores, "Chores", onChores)
            if let bills, let onBills {
                box(AppTheme.reminder, AppTheme.reminderSoft, "dollarsign.circle.fill", bills, "Bills Due", onBills)
            }
            box(AppTheme.todo, AppTheme.todoSoft, "square.and.pencil", todos, "To-dos", onTodos)
        }
    }

    private func box(_ color: Color, _ soft: Color, _ symbol: String, _ count: Int, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(soft)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(HubPressStyle())
    }
}

private func posterChip(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.22), in: Capsule())
}

@ViewBuilder
private func personHeader(
    image: UIImage?,
    emoji: String?,
    fallback: String?,
    name: String,
    eventCount: Int,
    ring: Color,
    onCamera: @escaping () -> Void
) -> some View {
    HStack(spacing: 12) {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let emoji {
                Circle().fill(ring.opacity(0.18))
                Text(emoji).font(.system(size: 28))
            } else {
                Circle().fill(ring.opacity(0.18))
                Image(systemName: fallback ?? "person.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ring)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .overlay(Circle().stroke(ring, lineWidth: 3))

        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(eventCount == 1 ? "1 event" : "\(eventCount) events")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        Spacer(minLength: 0)
        Button(action: onCamera) {
            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ring)
                .frame(width: 34, height: 34)
                .background(ring.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.top, 12)
    .padding(.bottom, 8)
}

private struct EventScroll: View {
    @Environment(\.hubAccent) private var accent
    let events: [CalendarEvent]
    var onEvent: (CalendarEvent) -> Void

    private func uniqueEvents(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var seen = Set<String>()
        return events.filter { event in
            guard event.startAt.timeIntervalSince1970.isFinite else { return false }
            let key = event.externalID.flatMap { $0.isEmpty ? nil : $0 } ?? event.id.uuidString
            return seen.insert(key).inserted
        }
    }

    var body: some View {
        let rows = uniqueEvents(events)
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Up next")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .textCase(.uppercase)
                if rows.isEmpty {
                    Text("Free this day")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, event in
                        Button {
                            onEvent(event)
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Capsule()
                                    .fill(accent)
                                    .frame(width: 4, height: 28)
                                Text(event.allDay ? "All day" : Date.hubClock(event.startAt))
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(accent)
                                    .frame(width: 58, alignment: .leading)
                                Text(String(event.title.prefix(48)))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(1)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(HubPressStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct BannerLook: Identifiable {
    let id: String
    let title: String
    var group: String = "Scenes"
    var imageName: String { id }
}

struct BannerStudio: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubAccent) private var accent
    let title: String
    let current: Data?
    var onSave: (Data?) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var cropPayload: PhotoCropPayload?
    @State private var preview: Data?

    private let looks: [BannerLook] = [
        .init(id: "BannerDusk", title: "Dusk", group: "Scenes"),
        .init(id: "BannerDawn", title: "Dawn", group: "Scenes"),
        .init(id: "BannerOcean", title: "Ocean", group: "Scenes"),
        .init(id: "BannerLagoon", title: "Lagoon", group: "Scenes"),
        .init(id: "BannerForest", title: "Forest", group: "Scenes"),
        .init(id: "BannerMeadow", title: "Meadow", group: "Scenes"),
        .init(id: "BannerSunset", title: "Sunset", group: "Scenes"),
        .init(id: "BannerNight", title: "Night", group: "Scenes"),
        .init(id: "BannerAurora", title: "Aurora", group: "Scenes"),
        .init(id: "BannerStorm", title: "Storm", group: "Scenes"),
        .init(id: "BannerIce", title: "Ice", group: "Scenes"),
        .init(id: "BannerPeony", title: "Peony", group: "Flowers"),
        .init(id: "BannerRoses", title: "Roses", group: "Flowers"),
        .init(id: "BannerDaisies", title: "Daisies", group: "Flowers"),
        .init(id: "BannerWildflower", title: "Wildflower", group: "Flowers"),
        .init(id: "BannerTropical", title: "Tropical", group: "Flowers"),
        .init(id: "BannerBlush", title: "Blush", group: "Flowers"),
        .init(id: "BannerRose", title: "Rose field", group: "Flowers"),
        .init(id: "BannerSportsCar", title: "Sports car", group: "Wheels"),
        .init(id: "BannerTruck", title: "Truck", group: "Wheels"),
        .init(id: "BannerDirtBike", title: "Dirt bike", group: "Wheels"),
        .init(id: "BannerBike", title: "Bike", group: "Wheels"),
        .init(id: "BannerMoto", title: "Moto", group: "Wheels"),
        .init(id: "BannerChevron", title: "Chevron", group: "Designs"),
        .init(id: "BannerGeo", title: "Geo", group: "Designs"),
        .init(id: "BannerDots", title: "Dots", group: "Designs"),
        .init(id: "BannerStripe", title: "Stripe", group: "Designs"),
        .init(id: "BannerWave", title: "Wave", group: "Designs"),
        .init(id: "BannerRoyal", title: "Royal", group: "Designs"),
        .init(id: "BannerCarbon", title: "Carbon", group: "Designs"),
        .init(id: "BannerGold", title: "Gold", group: "Designs"),
        .init(id: "BannerInk", title: "Ink", group: "Designs"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    uploadBar
                    ForEach(["Scenes", "Flowers", "Wheels", "Designs"], id: \.self) { group in
                        Text(group)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(looks.filter { $0.group == group }) { look in
                                Button { applyLook(look) } label: {
                                    lookCard(look)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(accent)
                }
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline.weight(.bold))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(preview)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(accent)
                }
            }
            .onAppear { preview = current }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        cropPayload = PhotoCropPayload(image: image)
                    }
                }
            }
            .fullScreenCover(item: $cropPayload) { payload in
                BannerCropper(
                    image: payload.image,
                    onCancel: { cropPayload = nil },
                    onCrop: { data in
                        preview = data
                        cropPayload = nil
                    }
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let preview, let image = UIImage(data: preview) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [AppTheme.navy, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 1)
            }
            .padding(16)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }

    private var uploadBar: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 14) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Upload your photo")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text("Then move and zoom so it fits the banner")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(16)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent, lineWidth: 3)
                )
            }
            .buttonStyle(.plain)
            if preview != nil {
                HStack(spacing: 10) {
                    Button { openAdjust() } label: {
                        Label("Move & zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    Button { preview = nil } label: {
                        Label("Clear", systemImage: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(AppTheme.blueSoft, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func lookCard(_ look: BannerLook) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(look.imageName)
                .resizable()
                .scaledToFill()
            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
            Text(look.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(12)
        }
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    private func labelChip(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.22), in: Capsule())
    }

    private func applyLook(_ look: BannerLook) {
        if let image = UIImage(named: look.imageName) {
            preview = image.jpegData(compressionQuality: 0.92)
        }
    }

    private func openAdjust() {
        if let preview, let image = UIImage(data: preview) {
            cropPayload = PhotoCropPayload(image: image)
        }
    }
}

struct BannerCropper: View {
    let image: UIImage
    var onCancel: () -> Void
    var onCrop: (Data) -> Void

    @State private var scale: CGFloat = 1
    @State private var pinchStart: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var holeWidth: CGFloat = 720

    private let aspect: CGFloat = 16.0 / 9.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let width = min(geo.size.width - 32, 720)
                let height = width / aspect
                VStack(spacing: 18) {
                    ZStack {
                        Color.black.opacity(0.92)
                        imageLayer(width: width, height: height)
                            .frame(width: width, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(.white.opacity(0.9), lineWidth: 3)
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: dragStart.width + value.translation.width,
                                    height: dragStart.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                clamp(width: width, height: height)
                                dragStart = offset
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(pinchStart * value, 1), 4)
                            }
                            .onEnded { _ in
                                pinchStart = scale
                                clamp(width: width, height: height)
                            }
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drag to place · pinch or slide to zoom")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Slider(value: Binding(
                            get: { scale },
                            set: { scale = $0; clamp(width: width, height: height) }
                        ), in: 1...4)
                        .tint(AppTheme.blue)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                }
                .onAppear { holeWidth = width }
                .onChange(of: width) { _, value in holeWidth = value }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Move banner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use photo") { if let data = render() { onCrop(data) } }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func imageLayer(width: CGFloat, height: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: width, height: height)
    }

    private func clamp(width: CGFloat, height: CGFloat) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let fit = max(width / size.width, height / size.height)
        let current = fit * scale
        let maxX = max((size.width * current - width) / 2, 0)
        let maxY = max((size.height * current - height) / 2, 0)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
        dragStart = offset
        pinchStart = scale
    }

    private func render() -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let outW: CGFloat = 1200
        let outH = outW / aspect
        let k = outW / max(holeWidth, 1)
        let fit = max(outW / size.width, outH / size.height)
        let current = fit * scale
        let drawW = size.width * current
        let drawH = size.height * current
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH))
        let cropped = renderer.image { _ in
            image.draw(in: CGRect(
                x: (outW - drawW) / 2 + offset.width * k,
                y: (outH - drawH) / 2 + offset.height * k,
                width: drawW,
                height: drawH
            ))
        }
        return cropped.jpegData(compressionQuality: 0.9)
    }
}


#Preview {
    NavigationStack {
        TodayView()
    }
    .environmentObject(HubStore())
    .environmentObject(HubRouter())
}

