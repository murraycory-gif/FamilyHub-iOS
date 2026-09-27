import SwiftUI

enum HubSection: String, CaseIterable, Identifiable, Hashable {
    case today, calendar, chores, lists, shopping, meals
    case profiles, device, invite, calendars, bills, allowance, weather, widgets, notify, credits
    case settings, family, looks, layouts, privacy, plus, more

    var id: String { rawValue }

    static var menu: [HubSection] {
        sectionItems + [.profiles]
    }

    static var sectionItems: [HubSection] {
        var items: [HubSection] = [.today, .calendar, .chores, .lists, .shopping, .meals]
        if HubFlags.circlePlus { items.append(.plus) }
        return items
    }

    /// iPhone tab bar stays at five. Everything else lives under More.
    /// Circle, Calendar, Chores, Meals, and More. Shopping opens from Circle or More, so Chores is not an extra hop.
    static var phoneTabs: [HubSection] {
        [.today, .calendar, .chores, .meals, .more]
    }

    static var moreItems: [HubSection] {
        var items: [HubSection] = [.shopping, .lists]
        if HubFlags.circlePlus { items.append(.plus) }
        items.append(contentsOf: settingsItems)
        return items
    }

    static var settingsItems: [HubSection] {
        SettingsCatalog.groups.flatMap(\.rows).map(\.section)
    }

    var title: String {
        switch self {
        case .today: return "Circle"
        case .calendar: return "Calendar"
        case .chores: return "Chores"
        case .lists: return "Lists"
        case .shopping: return "Shopping"
        case .meals: return "Meals"
        case .plus: return "Circle+"
        case .settings: return "Settings"
        case .family, .profiles: return "People"
        case .looks: return "Appearance"
        case .layouts: return "Layout ideas"
        case .privacy: return "Privacy"
        case .device: return "This iPad"
        case .invite: return "Invite"
        case .calendars: return "Calendars"
        case .bills: return "Bills Due"
        case .allowance: return "Allowance"
        case .weather: return "Weather"
        case .widgets: return "Widgets"
        case .notify: return "Notifications"
        case .credits: return "Credits"
        case .more: return "More"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "house.fill"
        case .calendar: return "calendar"
        case .chores: return "checkmark.circle.fill"
        case .lists: return "list.bullet.rectangle"
        case .shopping: return "cart.fill"
        case .meals: return "fork.knife"
        case .plus: return "sparkles"
        case .settings: return "gearshape.fill"
        case .family, .profiles: return "person.3.fill"
        case .looks: return "circle.lefthalf.filled"
        case .layouts: return "square.grid.2x2.fill"
        case .privacy: return "hand.raised.fill"
        case .device: return "ipad"
        case .invite: return "person.badge.plus"
        case .calendars: return "calendar.badge.plus"
        case .bills: return "dollarsign.circle.fill"
        case .allowance: return "banknote.fill"
        case .weather: return "cloud.sun.fill"
        case .widgets: return "square.grid.2x2.fill"
        case .notify: return "bell.fill"
        case .credits: return "doc.text"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

enum HubFlags {
    /// Circle+ (geofence notes, custody coloring, recap captions) is not ready to ship.
    static let circlePlus = false
}

/// Settings is one list of short rows. Each row opens one screen. Nothing sits a level deeper than that.
enum SettingsCatalog {
    struct Row: Identifiable, Equatable {
        var section: HubSection
        var title: String
        var subtitle: String
        var symbol: String
        var id: String { section.rawValue }
    }

    struct Group: Identifiable, Equatable {
        var title: String
        var rows: [Row]
        var id: String { title }
    }

    static let groups: [Group] = [
        Group(title: "Family", rows: [
            Row(section: .profiles, title: "People", subtitle: "Names, photos, and who is holding this device", symbol: "person.3.fill"),
            Row(section: .invite, title: "Invite", subtitle: "Share this Circle with the family", symbol: "person.badge.plus"),
        ]),
        Group(title: "Notifications", rows: [
            Row(section: .notify, title: "Notifications", subtitle: "Reminders on this device", symbol: "bell.fill"),
        ]),
        Group(title: "Appearance", rows: [
            Row(section: .looks, title: "Appearance", subtitle: "Light, dark, or match this device", symbol: "circle.lefthalf.filled"),
        ]),
        Group(title: "Account and privacy", rows: [
            Row(section: .privacy, title: "Privacy", subtitle: "What stays in your iCloud", symbol: "hand.raised.fill"),
        ]),
        Group(title: "Help", rows: [
            Row(section: .credits, title: "Help and credits", subtitle: "Licenses and where recipes come from", symbol: "questionmark.circle.fill"),
        ]),
        Group(title: "More", rows: [
            Row(section: .calendars, title: "Calendars", subtitle: "Which calendars HUB reads", symbol: "calendar.badge.plus"),
            Row(section: .widgets, title: "Home boxes", subtitle: "Weather, shopping, and the other tiles", symbol: "square.grid.2x2.fill"),
            Row(section: .layouts, title: "Layout ideas", subtitle: "Other home layouts to try", symbol: "rectangle.grid.2x2"),
            Row(section: .allowance, title: "Allowance", subtitle: "Kid balances", symbol: "banknote.fill"),
        ]),
    ]

    static func row(for section: HubSection) -> Row? {
        groups.flatMap(\.rows).first { $0.section == section }
    }
}

/// Which screen a section opens. Settings and This iPad both land on Profiles, which is in the More menu.
enum HubDetailScreen: Equatable {
    case today, calendar, chores, lists, shopping, meals, plus, more
    case profiles, looks, layouts, privacy, invite, calendars, widgets, notify, credits, allowance

    var showsPrivacyPolicy: Bool { self == .profiles || self == .privacy }
}

extension HubSection {
    var detailScreen: HubDetailScreen {
        switch self {
        case .today: return .today
        case .calendar: return .calendar
        case .chores: return .chores
        case .allowance: return .allowance
        case .lists: return .lists
        case .shopping: return .shopping
        case .meals: return .meals
        case .plus: return .plus
        case .more: return .more
        case .settings, .family, .profiles, .device: return .profiles
        case .looks: return .looks
        case .layouts: return .layouts
        case .privacy: return .privacy
        case .invite: return .invite
        case .calendars: return .calendars
        case .bills, .weather, .widgets: return .widgets
        case .notify: return .notify
        case .credits: return .credits
        }
    }
}

final class HubRouter: ObservableObject {
    @Published var section: HubSection? = .today
    @Published var listKind: ListKind = .reminders
    @Published var columnVisibility: NavigationSplitViewVisibility = .all
    @Published var showMenu = false

    @Published var calendarFilter: DayFilter = .family
    @Published var calendarDay = Date()
    @Published var focusedEventID: UUID?
    @Published var mealsDay = Date()
    @Published var chromeHex: String = HubPalette.darkBackground

    func open(_ section: HubSection, list: ListKind? = nil) {
        if let list { listKind = list }
        self.section = section
    }

    func openMeals(day: Date = Date()) {
        mealsDay = day
        section = .meals
    }

    func openCalendar(filter: DayFilter, day: Date = Date(), eventID: UUID? = nil) {
        calendarFilter = filter
        calendarDay = Calendar.current.startOfDay(for: day)
        focusedEventID = eventID
        section = .calendar
    }

    func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }

    func openMenu(regular: Bool) {
        if regular {
            toggleSidebar()
        } else {
            showMenu = true
        }
    }
}

struct MainHubView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var router = HubRouter()

    private var currentSection: HubSection { router.section ?? .today }

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView(columnVisibility: $router.columnVisibility) {
                    sidebar
                } detail: {
                    detail
                }
                .navigationSplitViewStyle(.balanced)
                .environment(\.hubUsesSystemSidebar, true)
            } else {
                TabView(selection: tabSelection) {
                    ForEach(HubSection.phoneTabs) { item in
                        NavigationStack {
                            view(for: item)
                        }
                        .tabItem { Label(item.title, systemImage: item.symbol) }
                        .tag(item)
                    }
                }
                .environment(\.hubUsesTabBar, true)
            }
        }
        .environmentObject(router)
        .background(AppTheme.bg.ignoresSafeArea())
        .sheet(isPresented: $router.showMenu) {
            NavigationStack {
                sidebar
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            HubIconButton(symbol: "xmark", label: "Close") {
                                router.showMenu = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .onChange(of: router.section) { _, _ in
            router.showMenu = false
        }
    }

    private var tabSelection: Binding<HubSection> {
        Binding(
            get: { HubSection.phoneTabs.contains(currentSection) ? currentSection : .more },
            set: { router.section = $0 }
        )
    }

    private var sidebar: some View {
        List {
            Section("Sections") {
                ForEach(HubSection.sectionItems) { item in
                    sidebarRow(item)
                }
            }
            ForEach(SettingsCatalog.groups) { group in
                Section(group.title) {
                    ForEach(group.rows) { row in
                        sidebarRow(row.section, title: row.title)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
        .navigationBarTitleDisplayMode(.large)
        .navigationTitle("Circle")
        .toolbarBackground(AppTheme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text(store.householdName.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
    }

    private func sidebarRow(_ item: HubSection, title: String? = nil) -> some View {
        let selected = currentSection == item
        return Button {
            router.open(item)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.blueSoft)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.blue.opacity(0.18), lineWidth: 1)
                    Image(systemName: item.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.blue)
                }
                .frame(width: 28, height: 28)
                Text(title ?? item.title)
                    .font(.body.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? AppTheme.blue : AppTheme.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? AppTheme.blueSoft.opacity(0.85) : Color.clear)
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }

    @ViewBuilder
    private var detail: some View {
        view(for: currentSection)
    }

    @ViewBuilder
    private func view(for section: HubSection) -> some View {
        switch section.detailScreen {
        case .today: TodayView().hubChrome()
        case .calendar: CalendarHubView().hubChrome(showBack: true)
        case .chores: ChoresView().hubChrome(showBack: true)
        case .lists: ListsView().hubChrome(showBack: true)
        case .shopping: ShoppingListView().hubChrome(showBack: true)
        case .meals: MealsView().hubChrome(showBack: true)
        case .plus:
            if HubFlags.circlePlus {
                CirclePlusView().hubChrome(showBack: true)
            } else {
                MoreHubView()
            }
        case .more: MoreHubView()
        case .profiles: ProfilesSettingsView().hubChrome(showBack: true)
        case .looks: AppearanceSettingsView().hubChrome(showBack: true)
        case .layouts: HubLooksView().hubChrome(showBack: true)
        case .privacy: PrivacySettingsPage().hubChrome(showBack: true)
        case .invite: InviteSettingsView().hubChrome(showBack: true)
        case .calendars: CalendarSourcesView().hubChrome(showBack: true)
        case .widgets: HubWidgetPicker().hubChrome(showBack: true)
        case .notify: NotifySettingsView().hubChrome(showBack: true)
        case .credits: CreditsSettingsView().hubChrome(showBack: true)
        case .allowance: AllowanceSettingsPage().hubChrome(showBack: true)
        }
    }
}

struct MoreHubView: View {
    @EnvironmentObject private var router: HubRouter

    private var pushed: HubSection? {
        guard let section = router.section, HubSection.phoneTabs.contains(section) == false, section != .more else { return nil }
        return section
    }

    var body: some View {
        List {
            Section("House") {
                ForEach(HubSection.moreItems.filter { HubSection.settingsItems.contains($0) == false }) { item in
                    moreRow(item)
                }
            }
            ForEach(SettingsCatalog.groups) { group in
                Section(group.title) {
                    ForEach(group.rows) { row in
                        settingsRow(row)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: Binding(
            get: { pushed != nil },
            set: { if $0 == false { router.section = .more } }
        )) {
            if let pushed {
                destination(pushed)
                    .navigationTitle(SettingsCatalog.row(for: pushed)?.title ?? pushed.title)
                    .navigationBarTitleDisplayMode(.large)
            }
        }
    }

    private func moreRow(_ item: HubSection) -> some View {
        Button {
            router.open(item)
        } label: {
            Label(item.title, systemImage: item.symbol)
                .foregroundStyle(AppTheme.text)
        }
    }

    private func settingsRow(_ row: SettingsCatalog.Row) -> some View {
        Button {
            router.open(row.section)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: row.symbol)
                    .foregroundStyle(AppTheme.blue)
            }
        }
    }

    @ViewBuilder
    private func destination(_ section: HubSection) -> some View {
        switch section.detailScreen {
        case .chores: ChoresView()
        case .shopping: ShoppingListView()
        case .lists: ListsView()
        case .plus: CirclePlusView()
        case .profiles: ProfilesSettingsView()
        case .looks: AppearanceSettingsView()
        case .layouts: HubLooksView()
        case .privacy: PrivacySettingsPage()
        case .invite: InviteSettingsView()
        case .calendars: CalendarSourcesView()
        case .widgets: HubWidgetPicker()
        case .notify: NotifySettingsView()
        case .credits: CreditsSettingsView()
        case .allowance: AllowanceSettingsPage()
        default: EmptyView()
        }
    }
}

#Preview {
    MainHubView()
        .environmentObject(HubStore())
}
