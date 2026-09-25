import SwiftUI

enum HubSection: String, CaseIterable, Identifiable, Hashable {
    case today, calendar, chores, lists, shopping, meals
    case profiles, device, invite, calendars, bills, allowance, weather, widgets, notify, credits
    case settings, family, looks, plus, more

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
    static var phoneTabs: [HubSection] {
        [.today, .calendar, .meals, .shopping, .more]
    }

    static var moreItems: [HubSection] {
        var items: [HubSection] = [.chores, .lists]
        if HubFlags.circlePlus { items.append(.plus) }
        items.append(contentsOf: settingsItems)
        return items
    }

    static var settingsItems: [HubSection] {
        [.profiles, .invite, .calendars, .widgets, .notify, .looks, .credits]
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
        case .family, .profiles: return "Profiles"
        case .looks: return "Display"
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
        case .looks: return "square.grid.2x2.fill"
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

/// Which screen a section opens. Settings and This iPad both land on Profiles, which is in the More menu.
enum HubDetailScreen: Equatable {
    case today, calendar, chores, lists, shopping, meals, plus, more
    case profiles, looks, invite, calendars, widgets, notify, credits

    var showsPrivacyPolicy: Bool { self == .profiles }
}

extension HubSection {
    var detailScreen: HubDetailScreen {
        switch self {
        case .today: return .today
        case .calendar: return .calendar
        case .allowance, .chores: return .chores
        case .lists: return .lists
        case .shopping: return .shopping
        case .meals: return .meals
        case .plus: return .plus
        case .more: return .more
        case .settings, .family, .profiles, .device: return .profiles
        case .looks: return .looks
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
    @Published var chromeHex: String = "06101C"

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
            Section("Settings") {
                ForEach(HubSection.settingsItems) { item in
                    sidebarRow(item)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(AppTheme.bg)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(AppTheme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HubNavLogo(onDark: false)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HubIconButton(symbol: "sidebar.left", label: "Menu") {
                    router.toggleSidebar()
                }
            }
        }
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

    private func sidebarRow(_ item: HubSection) -> some View {
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
                Text(item.title)
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
        case .looks: HubLooksView().hubChrome(showBack: true)
        case .invite: InviteSettingsView().hubChrome(showBack: true)
        case .calendars: CalendarSourcesView().hubChrome(showBack: true)
        case .widgets: HubWidgetPicker().hubChrome(showBack: true)
        case .notify: NotifySettingsView().hubChrome(showBack: true)
        case .credits: CreditsSettingsView().hubChrome(showBack: true)
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
        if let pushed {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        router.section = .more
                    } label: {
                        Label("More", systemImage: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                destination(pushed)
            }
            .background(AppTheme.bg.ignoresSafeArea())
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HubStickyHeader(lead: "More", tail: "")
                List {
                    Section("House") {
                        ForEach(HubSection.moreItems.filter { HubSection.settingsItems.contains($0) == false }) { item in
                            moreRow(item)
                        }
                    }
                    Section("Settings") {
                        ForEach(HubSection.settingsItems) { item in
                            moreRow(item)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(AppTheme.bg.ignoresSafeArea())
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

    @ViewBuilder
    private func destination(_ section: HubSection) -> some View {
        switch section.detailScreen {
        case .chores: ChoresView()
        case .lists: ListsView()
        case .plus: CirclePlusView()
        case .profiles: ProfilesSettingsView()
        case .looks: HubLooksView()
        case .invite: InviteSettingsView()
        case .calendars: CalendarSourcesView()
        case .widgets: HubWidgetPicker()
        case .notify: NotifySettingsView()
        case .credits: CreditsSettingsView()
        default: EmptyView()
        }
    }
}

#Preview {
    MainHubView()
        .environmentObject(HubStore())
}
