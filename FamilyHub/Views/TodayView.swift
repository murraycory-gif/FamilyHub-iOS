import SwiftUI

enum HubProfile: Hashable {
    case family
    case member(UUID)
}

struct TodayView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var profile: HubProfile = .family
    @State private var selectedDay = Date()
    @State private var showMoreDates = false
    @State private var showDinnerPicker = false
    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragOriginIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let familyH = max(geo.size.height * 0.40, sizeClass == .regular ? 300 : 260)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    agenda
                    dinnerCard
                    callouts
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity, alignment: .top)
                familySection
                    .padding(.horizontal, 24)
                    .frame(height: familyH)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("HUB")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 10) {
                    dateButton
                    profileButton
                }
            }
        }
        .sheet(isPresented: $showMoreDates) {
            NavigationStack {
                DatePicker("Day", selection: $selectedDay, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Pick a day")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showMoreDates = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDinnerPicker) {
            DinnerPickerSheet(day: selectedDay)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(profileSubtitle.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(AppTheme.textTertiary)
            Text(profileTitle)
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateButton: some View {
        Menu {
            ForEach(upcomingDays, id: \.self) { day in
                Button {
                    selectedDay = day
                } label: {
                    if Calendar.current.isDate(day, inSameDayAs: selectedDay) {
                        Label(menuDayLabel(day), systemImage: "checkmark")
                    } else {
                        Text(menuDayLabel(day))
                    }
                }
            }
            Divider()
            Button("More dates…") { showMoreDates = true }
        } label: {
            pillButton(
                symbol: "calendar",
                caption: "Day",
                title: shortDayName
            )
        }
    }

    private var profileButton: some View {
        Menu {
            Button {
                profile = .family
            } label: {
                Label("Whole family", systemImage: profile == .family ? "checkmark" : "person.3.fill")
            }
            ForEach(store.members) { member in
                Button {
                    profile = .member(member.id)
                } label: {
                    if profile == .member(member.id) {
                        Label(member.name, systemImage: "checkmark")
                    } else {
                        Text(member.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                profileAvatar
                VStack(alignment: .leading, spacing: 2) {
                    Text("Profile")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text(shortProfileName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                }
                Image(systemName: "chevron.down")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .background(AppTheme.card, in: Capsule(style: .continuous))
            .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
        }
    }

    private func pillButton(symbol: String, caption: String, title: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(AppTheme.blueSoft)
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
            }
            Image(systemName: "chevron.down")
                .font(.body.weight(.bold))
                .foregroundStyle(AppTheme.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 52)
        .background(AppTheme.card, in: Capsule(style: .continuous))
        .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var profileAvatar: some View {
        switch profile {
        case .family:
            ZStack {
                Circle().fill(AppTheme.blueSoft)
                Image(systemName: "person.3.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
            }
            .frame(width: 36, height: 36)
        case .member(let id):
            if let member = store.member(id: id) {
                MemberAvatar(member: member, size: 36)
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

    private var upcomingDays: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    private func menuDayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var shortDayName: String {
        if Calendar.current.isDateInToday(selectedDay) { return "Today" }
        if Calendar.current.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        return selectedDay.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var agenda: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 8) {
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
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
                .foregroundStyle(AppTheme.blue)
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
        .padding(.vertical, 8)
    }

    private var dinnerCard: some View {
        Button { showDinnerPicker = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "FFEDD5"))
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Color(hex: "C2410C"))
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Calendar.current.isDateInToday(selectedDay) ? "Dinner tonight" : "Dinner")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "C2410C"))
                    Text(store.dinnerTitle(on: selectedDay) ?? "Nothing planned — tap to choose")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(12)
            .background(Color(hex: "FFF7ED"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
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
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.text)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(soft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func cardWidth(in available: CGFloat) -> CGFloat {
        let count = store.members.count + 1
        let spacing = CGFloat(count - 1) * 12
        if count <= 5 {
            return max(160, (available - spacing) / CGFloat(count))
        }
        return max(200, available / 2.6)
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
            AppTheme.blue.frame(width: 5)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(AppTheme.navySoft)
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(AppTheme.blue)
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
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
                .stroke(selected ? AppTheme.blue : AppTheme.cardBorder, lineWidth: selected ? 2 : 1)
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
                            .foregroundStyle(AppTheme.text)
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
                .foregroundStyle(AppTheme.blue)
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
    .environmentObject(HubRouter())
}
