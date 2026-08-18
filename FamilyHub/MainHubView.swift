import SwiftUI

enum HubSection: String, CaseIterable, Identifiable, Hashable {
    case today, calendar, chores, lists, meals, family

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "HUB"
        case .calendar: return "Calendar"
        case .chores: return "Chores"
        case .lists: return "Lists"
        case .meals: return "Meals"
        case .family: return "Family"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "house.fill"
        case .calendar: return "calendar"
        case .chores: return "checkmark.circle.fill"
        case .lists: return "list.bullet.rectangle"
        case .meals: return "fork.knife"
        case .family: return "person.3.fill"
        }
    }
}

final class HubRouter: ObservableObject {
    @Published var section: HubSection? = .today
    @Published var listKind: ListKind = .reminders
    @Published var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    @Published var calendarFilter: DayFilter = .family

    @Published var mealsDay = Date()

    func open(_ section: HubSection, list: ListKind? = nil) {
        if let list { listKind = list }
        self.section = section
    }

    func openMeals(day: Date = Date()) {
        mealsDay = day
        section = .meals
    }

    func openCalendar(filter: DayFilter) {
        calendarFilter = filter
        section = .calendar
    }

    func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
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
                .background(HideSystemSidebarToggle())
            } else {
                TabView(selection: tabSelection) {
                    ForEach(HubSection.allCases) { item in
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
        .onChange(of: router.section) { _, _ in
            guard sizeClass == .regular else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                router.columnVisibility = .detailOnly
            }
        }
    }

    private var tabSelection: Binding<HubSection> {
        Binding(
            get: { currentSection },
            set: { router.section = $0 }
        )
    }

    private var sidebar: some View {
        List(HubSection.allCases, id: \.self, selection: $router.section) { item in
            Label(item.title, systemImage: item.symbol)
                .tag(Optional(item))
        }
        .listStyle(.sidebar)
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
        .background(HideSystemSidebarToggle())
    }

    @ViewBuilder
    private var detail: some View {
        NavigationStack {
            view(for: currentSection)
        }
        .toolbar(removing: .sidebarToggle)
        .background(HideSystemSidebarToggle())
    }

    @ViewBuilder
    private func view(for section: HubSection) -> some View {
        switch section {
        case .today: TodayView().hubChrome()
        case .calendar: CalendarHubView().hubChrome(showBack: true)
        case .chores: ChoresView().hubChrome(showBack: true)
        case .lists: ListsView().hubChrome(showBack: true)
        case .meals: MealsView().hubChrome(showBack: true)
        case .family: FamilyView().hubChrome(showBack: true)
        }
    }
}

#Preview {
    MainHubView()
        .environmentObject(HubStore())
}
