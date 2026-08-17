import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 16)

            householdStats
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            SectionLabel(title: "Family")
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            memberStrip
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text("\(store.householdName) household")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.text)
        }
    }

    private var householdStats: some View {
        HStack(spacing: 12) {
            householdStat("Open chores", "\(store.openAssignments().count)", "checkmark.circle")
            householdStat("Reminders", "\(store.reminders.filter { !$0.isCompleted }.count)", "bell")
            householdStat("To-dos", "\(store.todos.filter { !$0.isCompleted }.count)", "square.and.pencil")
        }
    }

    private func householdStat(_ title: String, _ value: String, _ symbol: String) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(AppTheme.navy)
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(AppTheme.text)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var memberStrip: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(store.members) { member in
                        MemberHomeCard(member: member)
                            .frame(width: cardWidth(in: geo.size.width), height: geo.size.height)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private func cardWidth(in available: CGFloat) -> CGFloat {
        if sizeClass == .regular {
            return min(420, max(320, (available - 48 - 16) / 2.15))
        }
        return max(280, available - 64)
    }
}

// MARK: - Per-person home card

private struct MemberHomeCard: View {
    @EnvironmentObject private var store: HubStore
    let member: FamilyMember

    private var chores: [ChoreAssignment] { store.openAssignments(for: member.id) }
    private var reminders: [ReminderItem] { store.openReminders(for: member.id) }
    private var todos: [TodoItem] { store.openTodos(for: member.id) }
    private var events: [CalendarEvent] { store.todayEvents(for: member.id) }
    private var accent: Color { Color(hex: member.colorHex) }

    var body: some View {
        HStack(spacing: 0) {
            accent
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    MemberAvatar(member: member, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundStyle(AppTheme.text)
                        Text(member.role.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    personStat(chores.count, "Chores")
                    personStat(reminders.count, "Reminders")
                    personStat(todos.count, "To-dos")
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: "Today")
                    if events.isEmpty {
                        Text("Nothing on the calendar")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textTertiary)
                            .padding(.top, 4)
                        Spacer(minLength: 0)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(events) { event in
                                    eventRow(event)
                                }
                            }
                        }
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .shadow(color: AppTheme.navy.opacity(0.08), radius: 16, y: 6)
    }

    private func personStat(_ value: Int, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(AppTheme.navy)
                .monospacedDigit()
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.navySoft)
        )
    }

    private func eventRow(_ event: CalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.allDay ? "All day" : event.startAt.formatted(date: .omitted, time: .shortened))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.navy)
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
                if !event.location.isEmpty {
                    Text(event.location)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.bg)
        )
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .environmentObject(HubStore())
}
