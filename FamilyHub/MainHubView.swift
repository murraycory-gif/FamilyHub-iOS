import SwiftUI

enum HubSection: String, CaseIterable, Identifiable, Hashable {
    case today, calendar, chores, lists, family

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .calendar: return "Calendar"
        case .chores: return "Chores"
        case .lists: return "Lists"
        case .family: return "Family"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.max.fill"
        case .calendar: return "calendar"
        case .chores: return "checkmark.circle.fill"
        case .lists: return "list.bullet.rectangle"
        case .family: return "person.3.fill"
        }
    }
}

struct MainHubView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var section: HubSection = .today

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detail
                }
            } else {
                TabView(selection: $section) {
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
        .background(AppTheme.bg.ignoresSafeArea())
    }

    private var sidebar: some View {
        List(selection: $section) {
            Section {
                ForEach(HubSection.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                }
            } header: {
                Text(store.householdName.uppercased())
            }
        }
        .navigationTitle("FamilyHub")
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detail: some View {
        NavigationStack {
            view(for: section)
        }
    }

    @ViewBuilder
    private func view(for section: HubSection) -> some View {
        switch section {
        case .today: TodayView()
        case .calendar: CalendarHubView()
        case .chores: ChoresView()
        case .lists: ListsView()
        case .family: FamilyView()
        }
    }
}

#Preview {
    MainHubView()
        .environmentObject(HubStore())
}
