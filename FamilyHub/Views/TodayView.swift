import SwiftUI

enum HubProfile: Hashable {
    case family
    case member(UUID)
}

struct TodayView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var profile: HubProfile = .family
    @State private var selectedDay = Date()
    @State private var weekStart = Calendar.current.startOfDay(for: Date())
    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragOriginIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let familyH = familyHeight(in: geo.size.height)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    dayStrip
                    agenda
                    callouts
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 12)
                familySection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .frame(height: familyH)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("HUB")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(profileSubtitle.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(AppTheme.textTertiary)
            Text(profileTitle)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(AppTheme.text)
        }
    }

    private var profileTitle: String {
        switch profile {
        case .family:
            return "\(store.householdName) family"
        case .member(let id):
            return store.member(id: id)?.name ?? "Family"
        }
    }

    private var profileSubtitle: String {
        switch profile {
        case .family:
            return "Whole household"
        case .member(let id):
            return store.member(id: id)?.role.label ?? "Member"
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 8) {
            Button { shiftWeek(-7) } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ice)
                    .frame(width: 28, height: 44)
            }
            .buttonStyle(.plain)

            ForEach(visibleDays, id: \.self) { day in
                let selected = Calendar.current.isDate(day, inSameDayAs: selectedDay)
                let today = Calendar.current.isDateInToday(day)
                Button {
                    selectedDay = day
                } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(selected ? AppTheme.bg : AppTheme.textTertiary)
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(selected ? AppTheme.bg : AppTheme.text)
                        Circle()
                            .fill(today && !selected ? AppTheme.ice : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? AppTheme.navy : AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: selected ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
            }

            Button { shiftWeek(7) } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ice)
                    .frame(width: 28, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var visibleDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func shiftWeek(_ days: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: days, to: weekStart) {
            weekStart = next
            selectedDay = next
        }
    }

    private var agenda: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(dayHeadline)
                        .font(.headline)
                    Spacer()
                    Text("\(dayItems.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.textTertiary)
                }

                if dayItems.isEmpty {
                    Text(emptyDayCopy)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(dayItems) { item in
                                dayRow(item)
                                if item.id != dayItems.last?.id {
                                    Divider().overlay(AppTheme.cardBorder)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 140, maxHeight: 280)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var dayHeadline: String {
        if Calendar.current.isDateInToday(selectedDay) { return "Today" }
        if Calendar.current.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        return selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

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

    private var dayItems: [HubDayItem] {
        var items: [HubDayItem] = []
        let cal = Calendar.current
        for event in store.events(on: selectedDay, filter: dayFilter) {
            items.append(.event(event))
        }
        for reminder in store.reminders where !reminder.isCompleted {
            guard matchesProfile(reminder.memberID) else { continue }
            if let due = reminder.dueAt, cal.isDate(due, inSameDayAs: selectedDay) {
                items.append(.reminder(reminder))
            }
        }
        for todo in store.todos where !todo.isCompleted {
            guard matchesProfile(todo.memberID) else { continue }
            if let due = todo.dueAt, cal.isDate(due, inSameDayAs: selectedDay) {
                items.append(.todo(todo))
            }
        }
        for assignment in store.openAssignments(for: focusedMemberID) {
            if cal.isDate(assignment.dueOn, inSameDayAs: selectedDay) {
                let title = store.chore(id: assignment.choreID)?.title ?? "Chore"
                items.append(.chore(assignment, title: title))
            }
        }
        return items.sorted { $0.sortDate < $1.sortDate }
    }

    private func matchesProfile(_ memberID: UUID?) -> Bool {
        switch profile {
        case .family: return true
        case .member(let id): return memberID == nil || memberID == id
        }
    }

    private func dayRow(_ item: HubDayItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.timeLabel)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.ice)
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title).font(.subheadline.weight(.semibold))
                    Text(item.kindLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if let member = item.memberID.flatMap(store.member(id:)) {
                MemberDot(member: member, size: 8)
            }
        }
        .padding(.vertical, 10)
    }

    private var callouts: some View {
        HStack(spacing: 10) {
            callout("Open chores", "\(focusedChores.count)", "checkmark.circle")
            callout("Reminders", "\(focusedReminders.count)", "bell")
            callout("To-dos", "\(focusedTodos.count)", "square.and.pencil")
        }
    }

    private var focusedChores: [ChoreAssignment] { store.openAssignments(for: focusedMemberID) }
    private var focusedReminders: [ReminderItem] {
        store.reminders.filter { !$0.isCompleted && matchesProfile($0.memberID) }
    }
    private var focusedTodos: [TodoItem] {
        store.todos.filter { !$0.isCompleted && matchesProfile($0.memberID) }
    }

    private func callout(_ title: String, _ value: String, _ symbol: String) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol).foregroundStyle(AppTheme.ice)
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title: "Family")
                Spacer()
                Text("Tap to focus · hold to move")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            memberStrip
        }
    }

    private var memberStrip: some View {
        GeometryReader { geo in
            let width = cardWidth(in: geo.size.width)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    FamilyFocusCard(selected: profile == .family)
                        .frame(width: width, height: geo.size.height)
                        .onTapGesture { profile = .family }

                    ForEach(store.members) { member in
                        MemberHomeCard(member: member, selected: profile == .member(member.id))
                            .frame(width: width, height: geo.size.height)
                            .offset(x: draggingID == member.id ? dragTranslation : 0)
                            .scaleEffect(draggingID == member.id ? 1.02 : 1)
                            .zIndex(draggingID == member.id ? 10 : 0)
                            .onTapGesture { profile = .member(member.id) }
                            .highPriorityGesture(reorderGesture(for: member, cardWidth: width))
                    }
                }
            }
            .scrollDisabled(draggingID != nil)
        }
    }

    private func familyHeight(in total: CGFloat) -> CGFloat {
        sizeClass == .regular ? max(220, min(280, total * 0.32)) : 220
    }

    private func cardWidth(in available: CGFloat) -> CGFloat {
        let count = store.members.count + 1
        if sizeClass == .regular && count <= 5 {
            return (available - CGFloat(count - 1) * 12) / CGFloat(count)
        }
        return max(200, available / 2.4)
    }

    private func reorderGesture(for member: FamilyMember, cardWidth: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .sequenced(before: DragGesture(minimumDistance: 2))
            .onChanged { value in
                guard case .second(true, let drag) = value, let drag else { return }
                if draggingID == nil {
                    draggingID = member.id
                    dragOriginIndex = store.members.firstIndex(where: { $0.id == member.id })
                }
                dragTranslation = drag.translation.width
            }
            .onEnded { _ in
                if let origin = dragOriginIndex {
                    let step = cardWidth + 12
                    let shift = Int((dragTranslation / step).rounded())
                    let target = min(max(origin + shift, 0), max(store.members.count - 1, 0))
                    if target != origin {
                        store.moveMemberLive(from: origin, to: target)
                    }
                    store.persistMembers()
                }
                draggingID = nil
                dragTranslation = 0
                dragOriginIndex = nil
            }
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
    var memberID: UUID?

    var kindLabel: String {
        switch kind {
        case .event: return "Event"
        case .reminder: return "Reminder"
        case .todo: return "To-do"
        case .chore: return "Chore"
        }
    }

    static func event(_ event: CalendarEvent) -> HubDayItem {
        HubDayItem(
            id: "e-\(event.id)",
            kind: .event,
            title: event.title,
            detail: event.location,
            timeLabel: event.allDay ? "All day" : event.startAt.formatted(date: .omitted, time: .shortened),
            sortDate: event.startAt,
            memberID: event.memberID
        )
    }

    static func reminder(_ item: ReminderItem) -> HubDayItem {
        HubDayItem(
            id: "r-\(item.id)",
            kind: .reminder,
            title: item.title,
            detail: "",
            timeLabel: item.dueAt?.formatted(date: .omitted, time: .shortened) ?? "Due",
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
            timeLabel: item.dueAt?.formatted(date: .omitted, time: .shortened) ?? "Due",
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
    let selected: Bool

    var body: some View {
        HStack(spacing: 0) {
            AppTheme.ice.frame(width: 5)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(AppTheme.navySoft)
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(AppTheme.ice)
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Everyone")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                Text("All calendars, events, and lists")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? AppTheme.ice : AppTheme.cardBorder, lineWidth: selected ? 2 : 1)
        )
    }
}

private struct MemberHomeCard: View {
    @EnvironmentObject private var store: HubStore
    let member: FamilyMember
    var selected = false

    private var chores: [ChoreAssignment] { store.openAssignments(for: member.id) }
    private var reminders: [ReminderItem] { store.openReminders(for: member.id) }
    private var todos: [TodoItem] { store.openTodos(for: member.id) }
    private var accent: Color { Color(hex: member.colorHex) }

    var body: some View {
        HStack(spacing: 0) {
            accent.frame(width: 5)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    MemberAvatar(member: member, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.system(size: 18, weight: .semibold))
                        Text(member.role.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "line.3.horizontal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                HStack(spacing: 6) {
                    personStat(chores.count, "Chores")
                    personStat(reminders.count, "Remind")
                    personStat(todos.count, "To-dos")
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? accent : AppTheme.cardBorder, lineWidth: selected ? 2 : 1)
        )
    }

    private func personStat(_ value: Int, _ title: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ice)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.navySoft)
        )
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .environmentObject(HubStore())
}
