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
    /// Optional — iOS `List(selection:)` requires `Binding<Selection?>`.
    @State private var section: HubSection? = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    private var currentSection: HubSection { section ?? .today }

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebar
                } detail: {
                    detail
                }
                .navigationSplitViewStyle(.prominentDetail)
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
        .background(AppTheme.bg.ignoresSafeArea())
        .onChange(of: section) { _, _ in
            guard sizeClass == .regular else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                columnVisibility = .detailOnly
            }
        }
    }

    private var tabSelection: Binding<HubSection> {
        Binding(
            get: { currentSection },
            set: { section = $0 }
        )
    }

    private var sidebar: some View {
        List(HubSection.allCases, id: \.self, selection: $section) { item in
            Label(item.title, systemImage: item.symbol)
                .tag(Optional(item))
        }
        .navigationTitle("FamilyHub")
        .listStyle(.sidebar)
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

    @ViewBuilder
    private var detail: some View {
        NavigationStack {
            view(for: currentSection)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                        .accessibilityLabel("Open menu")
                    }
                }
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
