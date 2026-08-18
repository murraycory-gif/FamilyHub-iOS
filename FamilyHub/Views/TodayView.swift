import SwiftUI
import PhotosUI
import UIKit

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
    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragOriginIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let familyH = max(geo.size.height * 0.40, sizeClass == .regular ? 300 : 250)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    agenda
                    dinnerCard
                    callouts
                }
                .padding(.horizontal, 24)
                .padding(.top, 2)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity, alignment: .top)
                familySection
                    .padding(.horizontal, 24)
                    .frame(height: familyH)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profileSubtitle.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(AppTheme.textTertiary)
            Text(profileTitle)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.3)
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
            cleanPill(icon: { profileAvatar }) {
                Text(shortProfileName)
            }
        }
    }

    private func pillButton(symbol: String, caption: String, title: String) -> some View {
        cleanPill(icon: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
        }) {
            Text(title)
        }
    }

    private func cleanPill<Icon: View, Label: View>(
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder label: () -> Label
    ) -> some View {
        HStack(spacing: 8) {
            icon()
            label()
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.card, in: Capsule(style: .continuous))
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
            .frame(width: 28, height: 28)
        case .member(let id):
            if let member = store.member(id: id) {
                MemberAvatar(member: member, size: 28)
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

    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -24 {
                    shiftSelectedDay(1)
                } else if value.translation.width > 24 {
                    shiftSelectedDay(-1)
                }
            }
    }

    private func shiftSelectedDay(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) {
            selectedDay = Calendar.current.startOfDay(for: next)
        }
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
        .simultaneousGesture(daySwipe)
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
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.blue)
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title).font(.body.weight(.semibold))
                    Text(item.kindLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if profile == .family {
                Text(assigneeName(for: item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(assigneeColor(for: item))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(assigneeColor(for: item).opacity(0.14), in: Capsule())
            }
        }
        .padding(.vertical, 8)
    }

    private func assigneeName(for item: HubDayItem) -> String {
        if let id = item.memberID, let member = store.member(id: id) {
            return member.name
        }
        return "Family"
    }

    private func assigneeColor(for item: HubDayItem) -> Color {
        if let id = item.memberID, let member = store.member(id: id) {
            return Color(hex: member.colorHex)
        }
        return AppTheme.blue
    }

    private var dinnerCard: some View {
        Button { router.openMeals(day: selectedDay) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "FFEDD5"))
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Color(hex: "C2410C"))
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Calendar.current.isDateInToday(selectedDay) ? "Dinner tonight" : "Dinner")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "C2410C"))
                    Text(store.dinnerTitle(on: selectedDay) ?? "Nothing planned — tap to open Meals")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(hex: "FFF7ED"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(daySwipe)
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
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.text)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(soft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title: "Family")
                Spacer()
                Text("Tap a person for their calendar · hold to move")
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
                    FamilyFocusCard(selected: profile == .family, day: selectedDay) {
                        router.openCalendar(filter: .family)
                    }
                        .frame(width: width, height: geo.size.height)

                    ForEach(store.members) { member in
                        Button {
                            router.openCalendar(filter: .member(member.id))
                        } label: {
                            MemberHomeCard(member: member, selected: profile == .member(member.id), day: selectedDay)
                        }
                        .buttonStyle(.plain)
                        .frame(width: width, height: geo.size.height)
                        .offset(x: draggingID == member.id ? dragTranslation : 0)
                        .scaleEffect(draggingID == member.id ? 1.02 : 1)
                        .zIndex(draggingID == member.id ? 10 : 0)
                        .simultaneousGesture(reorderGesture(for: member, cardWidth: width))
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
    let day: Date
    var onOpenCalendar: () -> Void
    @State private var photoItem: PhotosPickerItem?

    private var events: [CalendarEvent] {
        store.events(on: day, filter: .family)
    }

    var body: some View {
        HStack(spacing: 0) {
            AppTheme.blue.frame(width: 5)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        familyAvatar
                    }
                    .buttonStyle(.plain)
                    .zIndex(2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                        Text("Everyone · tap photo to change")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                dayEventList(events)
                Spacer(minLength: 0)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture { onOpenCalendar() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? AppTheme.blue : AppTheme.cardBorder, lineWidth: selected ? 2 : 1)
        )
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    store.setFamilyPhoto(data)
                }
            }
        }
    }

    private var familyAvatar: some View {
        ZStack {
            if let data = store.familyPhotoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(AppTheme.navySoft)
                Image(systemName: "person.3.fill")
                    .foregroundStyle(AppTheme.blue)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(3)
                .background(AppTheme.blue, in: Circle())
        }
    }
}

private struct MemberHomeCard: View {
    @EnvironmentObject private var store: HubStore
    let member: FamilyMember
    var selected = false
    let day: Date

    private var chores: [ChoreAssignment] { store.openAssignments(for: member.id) }
    private var reminders: [ReminderItem] { store.openReminders(for: member.id) }
    private var todos: [TodoItem] { store.openTodos(for: member.id) }
    private var events: [CalendarEvent] {
        store.events(on: day, filter: .member(member.id))
    }
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
                dayEventList(events)
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

@ViewBuilder
private func dayEventList(_ events: [CalendarEvent]) -> some View {
    if events.isEmpty {
        Text("Free this day")
            .font(.caption)
            .foregroundStyle(AppTheme.textTertiary)
    } else {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 6) {
                        Text(event.allDay ? "All day" : event.startAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.blue)
                            .frame(width: 58, alignment: .leading)
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(2)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .environmentObject(HubStore())
    .environmentObject(HubRouter())
}
