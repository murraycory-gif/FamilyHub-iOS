import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: HubStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                stats
                upcoming
                todayChores
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text("\(store.householdName) household")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.text)
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            statCard("Open chores", "\(store.openAssignments().count)", "checkmark.circle")
            statCard("Reminders", "\(store.reminders.filter { !$0.isCompleted }.count)", "bell")
            statCard("To-dos", "\(store.todos.filter { !$0.isCompleted }.count)", "square.and.pencil")
        }
    }

    private func statCard(_ title: String, _ value: String, _ symbol: String) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(AppTheme.forest)
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var upcoming: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Upcoming")
            let items = store.upcomingItems()
            if items.isEmpty {
                HubCard { EmptyHint(symbol: "sparkles", title: "All clear", detail: "Nothing coming up.") }
            } else {
                ForEach(items) { item in
                    HubCard {
                        HStack(spacing: 12) {
                            Image(systemName: symbol(for: item.kind))
                                .foregroundStyle(AppTheme.forest)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.headline)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            if item.sortDate != .distantFuture {
                                Text(item.sortDate, style: .time)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            MemberDot(member: item.memberID.flatMap(store.member(id:)))
                        }
                    }
                }
            }
        }
    }

    private var todayChores: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Due today")
            let due = store.openAssignments().filter { Calendar.current.isDateInToday($0.dueOn) }
            if due.isEmpty {
                HubCard { Text("No chores due today.").foregroundStyle(AppTheme.textSecondary) }
            } else {
                ForEach(due) { assignment in
                    if let chore = store.chore(id: assignment.choreID),
                       let kid = store.member(id: assignment.memberID) {
                        HubCard {
                            HStack {
                                MemberAvatar(member: kid, size: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chore.title).font(.headline)
                                    Text("\(kid.name) · \(Money.cents(chore.rewardCents))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                Text(assignment.status.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.clay)
                            }
                        }
                    }
                }
            }
        }
    }

    private func symbol(for kind: UpcomingKind) -> String {
        switch kind {
        case .event: return "calendar"
        case .reminder: return "bell"
        case .todo: return "checkmark.square"
        case .chore: return "hands.sparkles"
        }
    }
}
