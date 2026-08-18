import SwiftUI

struct CalendarHubView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @EnvironmentObject private var ingest: CalendarIngestor
    @State private var monthAnchor = Date()
    @State private var selectedDay = Date()
    @State private var filter: DayFilter = .family
    @State private var showAdd = false
    @State private var showSources = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                monthHeader
                filterRow
                weekdayHeader
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(CalendarMath.monthDays(containing: monthAnchor), id: \.self) { day in
                        dayCell(day)
                    }
                }
                dayList
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    HubIconButton(symbol: "calendar.badge.plus", label: "Calendars") {
                        showSources = true
                    }
                    HubIconButton(symbol: "plus", label: "Add") {
                        showAdd = true
                    }
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddEventSheet(day: selectedDay)
        }
        .sheet(isPresented: $showSources) {
            CalendarSourcesView()
        }
        .onAppear {
            applyRoute()
        }
        .onChange(of: router.calendarFilter) { _, _ in applyRoute() }
        .onChange(of: router.calendarDay) { _, _ in applyRoute() }
        .onChange(of: router.focusedEventID) { _, _ in applyRoute() }
    }

    private func applyRoute() {
        filter = router.calendarFilter
        selectedDay = router.calendarDay
        monthAnchor = router.calendarDay
    }

    private var monthHeader: some View {
        HStack {
            HubIconButton(symbol: "chevron.left", label: "Previous month") { shiftMonth(-1) }
            Spacer()
            Text(monthAnchor.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppTheme.text)
            Spacer()
            HubIconButton(symbol: "chevron.right", label: "Next month") { shiftMonth(1) }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Family", color: AppTheme.forest, selected: filter == .family) {
                    filter = .family
                }
                ForEach(store.members) { member in
                    FilterChip(
                        title: member.name,
                        color: Color(hex: member.colorHex),
                        selected: filter == .member(member.id)
                    ) {
                        filter = .member(member.id)
                    }
                }
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                Text(day.prefix(2))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let inMonth = cal.isDate(day, equalTo: monthAnchor, toGranularity: .month)
        let selected = cal.isDate(day, inSameDayAs: selectedDay)
        let today = cal.isDateInToday(day)
        let count = store.events(on: day, filter: filter).count

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.subheadline.weight(selected || today ? .bold : .regular))
                Circle()
                    .fill(count > 0 ? AppTheme.forest : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? AppTheme.forestSoft : Color.clear)
            )
            .foregroundStyle(inMonth ? AppTheme.text : AppTheme.textTertiary)
        }
        .buttonStyle(.plain)
    }

    private var dayList: some View {
        let events = store.events(on: selectedDay, filter: filter)
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: selectedDay.formatted(.dateTime.weekday(.wide).month().day()))
            if events.isEmpty {
                HubCard { Text("Nothing on this day.").foregroundStyle(AppTheme.textSecondary) }
            } else {
                ForEach(events) { event in
                    HubCard {
                        HStack(alignment: .top, spacing: 12) {
                            MemberDot(member: event.memberID.flatMap(store.member(id:)), size: 12)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(event.title).font(.headline)
                                    if event.isImported, let source = event.sourceID.flatMap(store.source(id:)) {
                                        Text(source.brand.title)
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(AppTheme.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .overlay(Capsule().stroke(AppTheme.cardBorder, lineWidth: 1))
                                    }
                                }
                                Text(event.allDay ? "All day" : event.startAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                if !event.location.isEmpty {
                                    Text(event.location)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                ingest.deleteEvent(event)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(event.id == router.focusedEventID ? AppTheme.blue : Color.clear, lineWidth: 2)
                    )
                }
            }
        }
    }

    private func shiftMonth(_ value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: monthAnchor) {
            monthAnchor = next
        }
    }
}

struct AddEventSheet: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var ingest: CalendarIngestor
    @Environment(\.dismiss) private var dismiss
    let day: Date

    @State private var title = ""
    @State private var location = ""
    @State private var start = Date()
    @State private var allDay = false
    @State private var memberID: UUID?
    @State private var destinationID: String?
    @State private var errorText: String?

    private var destinations: [DiscoveredCalendar] { ingest.writableCalendars() }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Location", text: $location)
                Toggle("All day", isOn: $allDay)
                DatePicker("Starts", selection: $start, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                Picker("Who", selection: $memberID) {
                    Text("Whole family").tag(UUID?.none)
                    ForEach(store.members) { member in
                        Text(member.name).tag(Optional(member.id))
                    }
                }
                if !destinations.isEmpty {
                    Picker("Save to", selection: $destinationID) {
                        Text("Choose calendar").tag(String?.none)
                        ForEach(destinations) { calendar in
                            Text("\(calendar.title) · \(calendar.account)").tag(Optional(calendar.eventKitID))
                        }
                    }
                }
                if let errorText {
                    Text(errorText).foregroundStyle(AppTheme.chore)
                }
            }
            .navigationTitle("New event")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
                destinationID = defaultDestination()
            }
            .onChange(of: memberID) { _, _ in
                destinationID = defaultDestination()
            }
        }
    }

    private func defaultDestination() -> String? {
        if let memberID,
           let match = store.calendarSources.first(where: {
               $0.memberID == memberID && $0.isEnabled && $0.eventKitID != nil
           })?.eventKitID {
            return match
        }
        if let enabled = store.calendarSources.first(where: { $0.isEnabled && $0.eventKitID != nil })?.eventKitID {
            return enabled
        }
        return destinations.first?.eventKitID
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let calendarID = destinationID ?? defaultDestination()
        var sourceID: UUID?
        var externalID: String?
        if let calendarID {
            do {
                externalID = try ingest.saveToDevice(
                    calendarID: calendarID,
                    title: trimmed,
                    start: start,
                    end: nil,
                    allDay: allDay,
                    location: location,
                    notes: ""
                )
                sourceID = store.calendarSources.first(where: { $0.eventKitID == calendarID })?.id
            } catch {
                errorText = error.localizedDescription
                return
            }
        }
        store.addEvent(.make(
            title: trimmed,
            startAt: start,
            allDay: allDay,
            location: location,
            memberID: memberID,
            sourceID: sourceID,
            externalID: externalID
        ))
        ingest.scheduleSync(quiet: true)
        dismiss()
    }
}
