import SwiftUI

enum HubSection: String, CaseIterable, Identifiable, Hashable {
    case today, calendar, chores, lists, shopping, meals
    case profiles, device, invite, calendars, bills, allowance, weather, widgets, notify
    case settings, family, looks

    var id: String { rawValue }

    static var menu: [HubSection] {
        sectionItems + [.profiles]
    }

    static var sectionItems: [HubSection] {
        [.today, .calendar, .chores, .lists, .shopping, .meals]
    }

    static var settingsItems: [HubSection] {
        [.profiles, .device, .invite, .calendars, .bills, .weather, .widgets, .notify]
    }

    var title: String {
        switch self {
        case .today: return "HUB"
        case .calendar: return "Calendar"
        case .chores: return "Chores"
        case .lists: return "Lists"
        case .shopping: return "Shopping"
        case .meals: return "Meals"
        case .settings: return "Settings"
        case .family, .profiles: return "Profiles"
        case .looks: return "Looks"
        case .device: return "This iPad"
        case .invite: return "Invite"
        case .calendars: return "Calendars"
        case .bills: return "Bills Due"
        case .allowance: return "Allowance"
        case .weather: return "Weather"
        case .widgets: return "Widgets"
        case .notify: return "Notifications"
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
        }
    }
}

final class HubRouter: ObservableObject {
    @Published var section: HubSection? = .today
    @Published var listKind: ListKind = .reminders
    @Published var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @Published var showMenu = false

    @Published var calendarFilter: DayFilter = .family
    @Published var calendarDay = Date()
    @Published var focusedEventID: UUID?
    @Published var mealsDay = Date()

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
                .navigationSplitViewStyle(.prominentDetail)
                .toolbar(removing: .sidebarToggle)
            } else {
                TabView(selection: tabSelection) {
                    ForEach(HubSection.menu) { item in
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
            guard sizeClass == .regular else { return }
            router.columnVisibility = .detailOnly
        }
    }

    private var tabSelection: Binding<HubSection> {
        Binding(
            get: { currentSection },
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
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(AppTheme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HubNavLogo()
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
            .toolbar(removing: .sidebarToggle)
    }

    @ViewBuilder
    private func view(for section: HubSection) -> some View {
        switch section {
        case .today: TodayView().hubChrome()
        case .calendar: CalendarHubView().hubChrome(showBack: true)
        case .allowance, .chores: ChoresView().hubChrome(showBack: true)
        case .lists: ListsView().hubChrome(showBack: true)
        case .shopping: ShoppingListView().hubChrome(showBack: true)
        case .meals: MealsView().hubChrome(showBack: true)
        case .settings, .family, .profiles: ProfilesSettingsView().hubChrome(showBack: true)
        case .looks: HubLooksView().hubChrome(showBack: true)
        case .device: DeviceSettingsView().hubChrome(showBack: true)
        case .invite: InviteSettingsView().hubChrome(showBack: true)
        case .calendars: CalendarSourcesView().hubChrome(showBack: true)
        case .bills: BillsSettingsView().hubChrome(showBack: true)
        case .weather: WeatherSettingsView().hubChrome(showBack: true)
        case .widgets: HubWidgetPicker().hubChrome(showBack: true)
        case .notify: NotifySettingsView().hubChrome(showBack: true)
        }
    }
}

#Preview {
    MainHubView()
        .environmentObject(HubStore())
}
