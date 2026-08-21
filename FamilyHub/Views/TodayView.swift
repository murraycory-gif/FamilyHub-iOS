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
    @StateObject private var weather = WeatherLoader()
    @State private var showWeatherOutlook = false
    @State private var showWeatherPlace = false
    @State private var showAddShopping = false
    @State private var shoppingDraft = ""

    var body: some View {
        GeometryReader { geo in
            let familyH = max(geo.size.height * 0.40, sizeClass == .regular ? 300 : 250)
            let available = max(geo.size.width - 48, 600)
            let unit = (available - 24) / 4
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    HStack(alignment: .top, spacing: 12) {
                        agenda
                            .frame(width: unit * 2)
                            .frame(maxHeight: .infinity)
                        weatherTile
                            .frame(width: unit)
                            .frame(maxHeight: .infinity)
                        shoppingTile
                            .frame(width: unit)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
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
        .fullScreenCover(isPresented: $showWeatherOutlook) {
            WeatherOutlookView(day: selectedDay)
                .environmentObject(store)
                .environmentObject(weather)
        }
        .sheet(isPresented: $showWeatherPlace) {
            WeatherPlacePicker()
                .environmentObject(store)
                .environmentObject(weather)
        }
        .task {
            while !Task.isCancelled {
                await weather.load(place: store.weatherPlace ?? .chicago)
                try? await Task.sleep(for: .seconds(10 * 60))
            }
        }
        .onChange(of: store.weatherPlace?.id) { _, _ in
            if let place = store.weatherPlace {
                Task { await weather.load(place: place) }
            }
        }
        .alert("Add to shopping list", isPresented: $showAddShopping) {
            TextField("Item", text: $shoppingDraft)
            Button("Add") {
                store.addShoppingItem(shoppingDraft)
                shoppingDraft = ""
            }
            Button("Cancel", role: .cancel) { shoppingDraft = "" }
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

    private var weatherTile: some View {
        HubWeatherTile(
            placeLabel: store.weatherPlace?.label ?? "Chicago",
            now: weather.now,
            day: weather.forecastDay(on: selectedDay),
            hours: weather.hoursOn(selectedDay),
            isToday: Calendar.current.isDateInToday(selectedDay),
            isLoading: weather.isLoading,
            onOpen: { showWeatherOutlook = true },
            onChangePlace: { showWeatherPlace = true }
        )
    }

    private var shoppingTile: some View {
        let open = store.shoppingItems.filter { !$0.isChecked }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shopping")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Button {
                    shoppingDraft = ""
                    showAddShopping = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.blue, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add to shopping list")
            }

            Button {
                router.open(.shopping)
            } label: {
                Group {
                    if open.isEmpty {
                        VStack(spacing: 6) {
                            Spacer(minLength: 0)
                            Image(systemName: "cart")
                                .font(.title2)
                                .foregroundStyle(AppTheme.blue)
                            Text("Nothing to get")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Tap to open the list")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(open.prefix(8)) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: "circle")
                                            .foregroundStyle(AppTheme.blue)
                                        Text(item.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.text)
                                            .lineLimit(1)
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
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
                Text("Tap a person for their day · tap an event for calendar")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            memberStrip
        }
    }

    private var memberStrip: some View {
        GeometryReader { geo in
            let width = cardWidth(in: geo.size)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    FamilyFocusCard(selected: profile == .family, day: selectedDay) {
                        profile = .family
                    } onEvent: { event in
                        router.openCalendar(filter: .family, day: selectedDay, eventID: event.id)
                    }
                    .frame(width: width, height: geo.size.height)

                    ForEach(store.members) { member in
                        MemberHomeCard(
                            member: member,
                            selected: profile == .member(member.id),
                            day: selectedDay,
                            onSelect: { profile = .member(member.id) },
                            onEvent: { event in
                                router.openCalendar(filter: .member(member.id), day: selectedDay, eventID: event.id)
                            }
                        )
                        .frame(width: width, height: geo.size.height)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func cardWidth(in size: CGSize) -> CGFloat {
        let visible: CGFloat = size.width >= size.height ? 4 : 3
        return max(140, (size.width - 12 * (visible - 1)) / visible)
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
    var onSelect: () -> Void
    var onEvent: (CalendarEvent) -> Void
    @State private var showStudio = false

    private var events: [CalendarEvent] {
        store.events(on: day, filter: .family)
    }

    var body: some View {
        VStack(spacing: 0) {
            posterBanner(
                image: store.familyPhotoData.flatMap { UIImage(data: $0) },
                colors: [AppTheme.navy, AppTheme.blue],
                fallback: "person.3.fill",
                name: "Family",
                chips: ["\(events.count) \(events.count == 1 ? "event" : "events")"]
            ) {
                Button { showStudio = true } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.white.opacity(0.24), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }

            posterEvents(events, onEvent: onEvent)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: selected ? 5 : 4)
        )
        .shadow(color: AppTheme.blue.opacity(selected ? 0.28 : 0.1), radius: selected ? 16 : 8, y: 6)
        .sheet(isPresented: $showStudio) {
            BannerStudio(title: "Family", current: store.familyPhotoData) { data in
                store.setFamilyPhoto(data)
            }
        }
    }
}

private struct MemberHomeCard: View {
    @EnvironmentObject private var store: HubStore
    let member: FamilyMember
    var selected = false
    let day: Date
    var onSelect: () -> Void
    var onEvent: (CalendarEvent) -> Void
    @State private var showStudio = false

    private var chores: [ChoreAssignment] { store.openAssignments(for: member.id) }
    private var reminders: [ReminderItem] { store.openReminders(for: member.id) }
    private var todos: [TodoItem] { store.openTodos(for: member.id) }
    private var events: [CalendarEvent] {
        store.events(on: day, filter: .member(member.id))
    }
    private var accent: Color { Color(hex: member.colorHex) }
    private var firstName: String {
        member.name.split(separator: " ").first.map(String.init) ?? member.name
    }

    var body: some View {
        VStack(spacing: 0) {
            posterBanner(
                image: store.photo(for: member).flatMap { UIImage(data: $0) },
                colors: [accent, accent.opacity(0.55)],
                fallback: nil,
                emoji: member.displayEmoji,
                name: firstName,
                chips: {
                    var items = ["\(events.count) \(events.count == 1 ? "event" : "events")"]
                    if chores.count > 0 { items.append("\(chores.count) chores") }
                    if reminders.count > 0 { items.append("\(reminders.count) remind") }
                    if todos.count > 0 { items.append("\(todos.count) to-dos") }
                    return items
                }()
            ) {
                Button { showStudio = true } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.white.opacity(0.24), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }

            posterEvents(events, onEvent: onEvent)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent, lineWidth: selected ? 5 : 4)
        )
        .shadow(color: accent.opacity(selected ? 0.3 : 0.12), radius: selected ? 16 : 8, y: 6)
        .sheet(isPresented: $showStudio) {
            BannerStudio(title: firstName, current: store.photo(for: member)) { data in
                store.setMemberPhoto(member.id, data: data)
            }
        }
    }
}

@ViewBuilder
private func posterBanner<Trailing: View>(
    image: UIImage?,
    colors: [Color],
    fallback: String? = nil,
    emoji: String? = nil,
    name: String,
    chips: [String],
    @ViewBuilder trailing: () -> Trailing
) -> some View {
    Color.clear
        .frame(height: 158)
        .background {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let fallback {
                        Image(systemName: fallback)
                            .font(.system(size: 52))
                            .foregroundStyle(.white.opacity(0.35))
                    } else if let emoji {
                        Text(emoji).font(.system(size: 58))
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                .frame(height: 100)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            Text(name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 8)
                            trailing()
                        }
                        if !chips.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                                    posterChip(chip)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
        }
        .clipped()
}
private func posterChip(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.22), in: Capsule())
}

@ViewBuilder
private func posterEvents(_ events: [CalendarEvent], onEvent: @escaping (CalendarEvent) -> Void) -> some View {
    if events.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
            Text("Up next")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            Text("Free this day")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
    } else if let featured = events.first {
        VStack(alignment: .leading, spacing: 10) {
            Text("Up next")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            Button {
                onEvent(featured)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(featured.allDay ? "All day" : featured.startAt.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.blue)
                    Text(featured.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            ForEach(Array(events.dropFirst())) { event in
                Button {
                    onEvent(event)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text(event.allDay ? "All day" : event.startAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.blue)
                            .frame(width: 58, alignment: .leading)
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct BannerLook: Identifiable {
    let id: String
    let title: String
    var imageName: String { id }
}

private struct BannerStudio: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let current: Data?
    var onSave: (Data?) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var cropPayload: PhotoCropPayload?
    @State private var preview: Data?

    private let looks: [BannerLook] = [
        .init(id: "BannerDusk", title: "Dusk"),
        .init(id: "BannerDawn", title: "Dawn"),
        .init(id: "BannerOcean", title: "Ocean"),
        .init(id: "BannerLagoon", title: "Lagoon"),
        .init(id: "BannerForest", title: "Forest"),
        .init(id: "BannerMeadow", title: "Meadow"),
        .init(id: "BannerSunset", title: "Sunset"),
        .init(id: "BannerCoral", title: "Coral"),
        .init(id: "BannerEmber", title: "Ember"),
        .init(id: "BannerCitrus", title: "Citrus"),
        .init(id: "BannerGold", title: "Gold"),
        .init(id: "BannerBlush", title: "Blush"),
        .init(id: "BannerRose", title: "Rose"),
        .init(id: "BannerGrape", title: "Grape"),
        .init(id: "BannerDuskViolet", title: "Violet"),
        .init(id: "BannerRoyal", title: "Royal"),
        .init(id: "BannerAurora", title: "Aurora"),
        .init(id: "BannerIce", title: "Ice"),
        .init(id: "BannerMint", title: "Mint"),
        .init(id: "BannerNight", title: "Night"),
        .init(id: "BannerInk", title: "Ink"),
        .init(id: "BannerStorm", title: "Storm"),
        .init(id: "BannerSlate", title: "Slate"),
        .init(id: "BannerCarbon", title: "Carbon"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    Text("Looks")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(looks) { look in
                            Button { applyLook(look) } label: {
                                lookCard(look)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.blue)
                }
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline.weight(.bold))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(preview)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.blue)
                }
            }
            .onAppear { preview = current }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        cropPayload = PhotoCropPayload(image: image)
                    }
                }
            }
            .fullScreenCover(item: $cropPayload) { payload in
                BannerCropper(
                    image: payload.image,
                    onCancel: { cropPayload = nil },
                    onCrop: { data in
                        preview = data
                        cropPayload = nil
                    }
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let preview, let image = UIImage(data: preview) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [AppTheme.navy, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 1)
                HStack(spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        labelChip("photo.on.rectangle", "Photo")
                    }
                    Button { openAdjust() } label: { labelChip("arrow.up.left.and.arrow.down.right", "Move") }
                    if preview != nil {
                        Button { preview = nil } label: { labelChip("xmark", "Clear") }
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }

    private func lookCard(_ look: BannerLook) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(look.imageName)
                .resizable()
                .scaledToFill()
            LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
            Text(look.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(12)
        }
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    private func labelChip(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.22), in: Capsule())
    }

    private func applyLook(_ look: BannerLook) {
        if let image = UIImage(named: look.imageName) {
            preview = image.jpegData(compressionQuality: 0.92)
        }
    }

    private func openAdjust() {
        if let preview, let image = UIImage(data: preview) {
            cropPayload = PhotoCropPayload(image: image)
        }
    }
}

private struct BannerCropper: View {
    let image: UIImage
    var onCancel: () -> Void
    var onCrop: (Data) -> Void

    @State private var scale: CGFloat = 1
    @State private var pinchStart: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var holeWidth: CGFloat = 720

    private let aspect: CGFloat = 16.0 / 9.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let width = min(geo.size.width - 32, 720)
                let height = width / aspect
                VStack(spacing: 18) {
                    ZStack {
                        Color.black.opacity(0.92)
                        imageLayer(width: width, height: height)
                            .frame(width: width, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(.white.opacity(0.9), lineWidth: 3)
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: dragStart.width + value.translation.width,
                                    height: dragStart.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                clamp(width: width, height: height)
                                dragStart = offset
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(pinchStart * value, 1), 4)
                            }
                            .onEnded { _ in
                                pinchStart = scale
                                clamp(width: width, height: height)
                            }
                    )
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drag to place · pinch or slide to zoom")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Slider(value: Binding(
                            get: { scale },
                            set: { scale = $0; clamp(width: width, height: height) }
                        ), in: 1...4)
                        .tint(AppTheme.blue)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                }
                .onAppear { holeWidth = width }
                .onChange(of: width) { _, value in holeWidth = value }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Move banner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use photo") { if let data = render() { onCrop(data) } }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func imageLayer(width: CGFloat, height: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: width, height: height)
    }

    private func clamp(width: CGFloat, height: CGFloat) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let fit = max(width / size.width, height / size.height)
        let current = fit * scale
        let maxX = max((size.width * current - width) / 2, 0)
        let maxY = max((size.height * current - height) / 2, 0)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
        dragStart = offset
        pinchStart = scale
    }

    private func render() -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let outW: CGFloat = 1200
        let outH = outW / aspect
        let k = outW / max(holeWidth, 1)
        let fit = max(outW / size.width, outH / size.height)
        let current = fit * scale
        let drawW = size.width * current
        let drawH = size.height * current
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH))
        let cropped = renderer.image { _ in
            image.draw(in: CGRect(
                x: (outW - drawW) / 2 + offset.width * k,
                y: (outH - drawH) / 2 + offset.height * k,
                width: drawW,
                height: drawH
            ))
        }
        return cropped.jpegData(compressionQuality: 0.9)
    }
}


#Preview {
    NavigationStack {
        TodayView()
    }
    .environmentObject(HubStore())
    .environmentObject(HubRouter())
}

