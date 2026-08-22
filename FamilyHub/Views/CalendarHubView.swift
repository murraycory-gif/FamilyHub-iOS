import MapKit
import SwiftUI

struct CalendarHubView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @EnvironmentObject private var ingest: CalendarIngestor
    @State private var monthAnchor = Date()
    @State private var selectedDay = Date()
    @State private var filter: DayFilter = .family
    @State private var showAdd = false
    @State private var showWho = false
    @State private var detail: CalendarEvent?
    @State private var tourFocus = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    HubStickyHeader(lead: "Family", tail: "Calendar") {
                        Button { showWho = true } label: {
                            HubFilterBanner(symbol: "person.3.fill", title: whoTitle)
                        }
                        .buttonStyle(.plain)
                        Button { showAdd = true } label: {
                            HubFilterBanner(symbol: "plus", title: "Add", chevron: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .coachSpot("calHeader")
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                monthHeader
                                colorLegend
                                weekdayHeader
                                monthGrid
                                    .coachSpot("calGrid")
                                dayList
                                    .coachSpot("calList")
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        .onAppear { scrollToFocus(proxy) }
                        .onChange(of: router.focusedEventID) { _, _ in scrollToFocus(proxy) }
                        .onChange(of: tourFocus) { _, id in
                            guard !id.isEmpty else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation { proxy.scrollTo(id, anchor: .center) }
                            }
                        }
                    }
                }
                if showWho {
                    whoOverlay(width: min(560, geo.size.width - 72), height: min(640, geo.size.height - 80))
                }
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .hubTour("calendar", steps: HubTours.calendar) { id in
            tourFocus = id
        }
        .sheet(isPresented: $showAdd) {
            AddEventSheet(day: selectedDay)
        }
        .sheet(item: $detail) { event in
            EventDetailSheet(event: event)
        }
        .onAppear { applyRoute() }
        .onChange(of: router.calendarFilter) { _, _ in applyRoute() }
        .onChange(of: router.calendarDay) { _, _ in applyRoute() }
        .onChange(of: router.focusedEventID) { _, _ in applyRoute() }
    }

    private func applyRoute() {
        filter = router.calendarFilter
        selectedDay = router.calendarDay
        monthAnchor = router.calendarDay
        if let id = router.focusedEventID,
           let event = store.events.first(where: { $0.id == id }) {
            detail = event
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HubPageTitle(lead: "Family", tail: "Calendar")
            Spacer(minLength: 12)
            Button { showWho = true } label: {
                HubFilterBanner(symbol: "person.3.fill", title: whoTitle)
            }
            .buttonStyle(.plain)
            Button { showAdd = true } label: {
                HubFilterBanner(symbol: "plus", title: "Add", chevron: false)
            }
            .buttonStyle(.plain)
        }
    }

    private var whoTitle: String {
        switch filter {
        case .family: return "Family"
        case .member(let id): return store.member(id: id)?.name.split(separator: " ").first.map(String.init) ?? "Family"
        }
    }

    private func whoOverlay(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea().onTapGesture { showWho = false }
            VStack(spacing: 0) {
                HubTileBanner(symbol: "person.3.fill", title: "Who's calendar")
                ScrollView {
                    VStack(spacing: 10) {
                        whoRow(title: "Whole family", detail: store.householdName, selected: filter == .family, color: AppTheme.blue) {
                            filter = .family
                            showWho = false
                        }
                        ForEach(store.members) { member in
                            whoRow(
                                title: member.name,
                                detail: member.role.label,
                                selected: filter == .member(member.id),
                                color: Color(hex: member.colorHex)
                            ) {
                                filter = .member(member.id)
                                showWho = false
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .frame(width: width, height: height)
            .background(AppTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(AppTheme.blue, lineWidth: 3))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
        }
    }

    private func whoRow(title: String, detail: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 6, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title2.weight(.bold)).foregroundStyle(AppTheme.text)
                    Text(detail).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(AppTheme.blue)
                }
            }
            .padding(16)
            .background(selected ? AppTheme.blueSoft : AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? AppTheme.blue : AppTheme.cardBorder, lineWidth: selected ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var monthHeader: some View {
        HubTileBanner(symbol: "calendar", title: monthAnchor.formatted(.dateTime.month(.wide).year())) {
            HStack(spacing: 8) {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 28, height: 28)
                        .background(.white, in: Circle())
                }
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 28, height: 28)
                        .background(.white, in: Circle())
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var colorLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                legendChip(store.householdName.isEmpty ? "Family" : store.householdName, AppTheme.blue)
                ForEach(store.members) { member in
                    legendChip(member.name.split(separator: " ").first.map(String.init) ?? member.name, Color(hex: member.colorHex))
                }
            }
        }
    }

    private func legendChip(_ name: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color, lineWidth: 2)
        )
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(CalendarMath.monthDays(containing: monthAnchor), id: \.self) { day in
                dayCell(day)
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 2)
        )
    }

    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let inMonth = cal.isDate(day, equalTo: monthAnchor, toGranularity: .month)
        let selected = cal.isDate(day, inSameDayAs: selectedDay)
        let today = cal.isDateInToday(day)
        let events = store.events(on: day, filter: filter)

        return Button {
            selectedDay = day
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Spacer(minLength: 0)
                    Text("\(cal.component(.day, from: day))")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(today ? .white : (inMonth ? AppTheme.text : AppTheme.textTertiary))
                        .frame(width: 34, height: 34)
                        .background {
                            if today {
                                Circle().fill(AppTheme.blue)
                            } else if selected {
                                Circle().fill(AppTheme.blueSoft)
                            }
                        }
                    Spacer(minLength: 0)
                }
                ForEach(events.prefix(3)) { event in
                    Text(event.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(eventColor(event))
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(eventColor(event).opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                if events.count > 3 {
                    Text("+\(events.count - 3)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .top)
            .background(selected && !today ? AppTheme.blueSoft.opacity(0.45) : Color.clear)
            .overlay(Rectangle().stroke(AppTheme.cardBorder.opacity(0.45), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .opacity(inMonth ? 1 : 0.45)
    }

    private func eventColor(_ event: CalendarEvent) -> Color {
        if let member = event.memberID.flatMap(store.member(id:)) {
            return Color(hex: member.colorHex)
        }
        return AppTheme.blue
    }

    private var dayList: some View {
        let events = store.events(on: selectedDay, filter: filter)
        return VStack(alignment: .leading, spacing: 12) {
            Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.title2.weight(.bold))
            if events.isEmpty {
                Text("No events")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(events) { event in
                    Button { detail = event } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                if event.allDay {
                                    Text("all")
                                    Text("day")
                                } else {
                                    Text(event.startAt.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()))
                                    Text(event.startAt.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))).suffix(2))
                                }
                            }
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 44, alignment: .trailing)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(eventColor(event))
                                .frame(width: 4)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                if !event.location.isEmpty {
                                    Text(event.location)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                if let member = event.memberID.flatMap(store.member(id:)) {
                                    Text(member.name)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(eventColor(event))
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(14)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(event.id == router.focusedEventID ? AppTheme.blue : AppTheme.cardBorder, lineWidth: event.id == router.focusedEventID ? 3 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .id(event.id)
                }
            }
        }
    }

    private func scrollToFocus(_ proxy: ScrollViewProxy) {
        guard let id = router.focusedEventID else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { proxy.scrollTo(id, anchor: .center) }
        }
    }

    private func shiftMonth(_ value: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: value, to: monthAnchor) {
            monthAnchor = next
        }
    }
}

struct EventDetailSheet: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var ingest: CalendarIngestor
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let event: CalendarEvent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HubPageTitle(lead: "Event", tail: "Details")
                    Text(event.title)
                        .font(.system(size: 32, weight: .bold))
                    if !event.statusLabel.isEmpty, event.statusLabel.lowercased() != "confirmed" {
                        Text(event.statusLabel)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(event.statusLabel.lowercased() == "canceled" ? AppTheme.chore : AppTheme.reminder)
                    }
                    HubPanel(symbol: "clock.fill", title: "When") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.startAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                                .font(.headline)
                            Text(event.allDay ? "All day" : timeRange)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                            if !event.recurrenceLabel.isEmpty {
                                Text(event.recurrenceLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            if !event.alertLabel.isEmpty {
                                Text(event.alertLabel)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    if !event.location.isEmpty || event.latitude != nil {
                        HubPanel(symbol: "mappin.and.ellipse", title: "Location") {
                            VStack(alignment: .leading, spacing: 10) {
                                if !event.location.isEmpty {
                                    Text(event.location).font(.headline)
                                }
                                if let lat = event.latitude, let lon = event.longitude {
                                    Map(initialPosition: .region(MKCoordinateRegion(
                                        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                        latitudinalMeters: 600,
                                        longitudinalMeters: 600
                                    ))) {
                                        Marker(event.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                    }
                                    .frame(height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                Button("Directions") {
                                    if let lat = event.latitude, let lon = event.longitude {
                                        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
                                        item.name = event.title
                                        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                                    } else if let maps = URL(string: "http://maps.apple.com/?q=\(event.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? event.location)") {
                                        openURL(maps)
                                    }
                                }
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                            }
                        }
                    }
                    HubPanel(symbol: "person.fill", title: "Who") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.memberID.flatMap(store.member(id:))?.name ?? store.householdName)
                                .font(.headline)
                            if !event.organizer.isEmpty {
                                Text("Organizer: \(event.organizer)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            ForEach(event.attendees, id: \.self) { person in
                                Text(person)
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    if event.isImported, let source = event.sourceID.flatMap(store.source(id:)) {
                        HubPanel(symbol: "calendar", title: "Calendar") {
                            VStack(alignment: .leading, spacing: 4) {
                                if !event.calendarName.isEmpty {
                                    Text(event.calendarName).font(.headline)
                                }
                                Text("\(source.brand.title) · \(source.account)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    if !event.url.isEmpty, let link = URL(string: event.url) {
                        HubPanel(symbol: "link", title: "Link") {
                            Button(event.url) { openURL(link) }
                                .font(.headline)
                                .foregroundStyle(AppTheme.blue)
                                .lineLimit(2)
                        }
                    }
                    if !event.notes.isEmpty {
                        HubPanel(symbol: "note.text", title: "Notes") {
                            Text(event.notes)
                        }
                    }
                    Button(role: .destructive) {
                        ingest.deleteEvent(event)
                        dismiss()
                    } label: {
                        Label("Delete event", systemImage: "trash")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.chore, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(AppTheme.blue)
                }
            }
        }
    }

    private var timeRange: String {
        let start = event.startAt.formatted(date: .omitted, time: .shortened)
        if let end = event.endAt {
            return "\(start) – \(end.formatted(date: .omitted, time: .shortened))"
        }
        return start
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
        HubSheetStack(
            lead: "New",
            tail: "Event",
            confirm: "Add",
            confirmEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty,
            onCancel: { dismiss() },
            onConfirm: save
        ) {
            HubField(label: "Title") {
                TextField("What's happening?", text: $title)
            }
            HubField(label: "Location") {
                TextField("Where?", text: $location)
            }
            HubField(label: "When") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("All day", isOn: $allDay).tint(AppTheme.blue)
                    DatePicker("Starts", selection: $start, displayedComponents: allDay ? [.date] : [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
            HubField(label: "Who") {
                Picker("Who", selection: $memberID) {
                    Text("Whole family").tag(UUID?.none)
                    ForEach(store.members) { member in
                        Text(member.name).tag(Optional(member.id))
                    }
                }
                .labelsHidden()
            }
            if !destinations.isEmpty {
                HubField(label: "Save to") {
                    Picker("Calendar", selection: $destinationID) {
                        Text("Choose calendar").tag(String?.none)
                        ForEach(destinations) { calendar in
                            Text("\(calendar.title) · \(calendar.account)").tag(Optional(calendar.eventKitID))
                        }
                    }
                    .labelsHidden()
                }
            }
            if let errorText {
                Text(errorText).foregroundStyle(AppTheme.chore).font(.subheadline.weight(.semibold))
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
