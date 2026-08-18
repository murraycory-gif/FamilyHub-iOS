import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var weather = WeatherLoader()
    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragOriginIndex: Int?
    @State private var showPlaceSheet = false
    @State private var isCustomizing = false
    @State private var showAddWidget = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                widgets
                familySection
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("HUB")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isCustomizing ? "Done" : "Customize") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCustomizing.toggle()
                    }
                }
            }
        }
        .task(id: store.weatherPlace?.id) {
            if let place = store.weatherPlace {
                await weather.load(place: place)
            }
        }
        .sheet(isPresented: $showPlaceSheet) {
            WeatherPlaceSheet(weather: weather) { place in
                store.setWeatherPlace(place)
            }
        }
        .sheet(isPresented: $showAddWidget) {
            AddWidgetSheet { kind in
                store.addHubWidget(kind)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(AppTheme.textTertiary)
            Text("\(store.householdName) household")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.4)
                .foregroundStyle(AppTheme.text)
        }
    }

    private var widgets: some View {
        VStack(spacing: 12) {
            if pairCamerasAndWeather {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(pairedTopWidgets) { widget in
                        widgetChrome(widget, index: store.hubWidgets.firstIndex(where: { $0.id == widget.id }) ?? 0) {
                            widgetBody(widget)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                ForEach(Array(remainingWidgets.enumerated()), id: \.element.id) { index, widget in
                    widgetChrome(widget, index: store.hubWidgets.firstIndex(where: { $0.id == widget.id }) ?? index) {
                        widgetBody(widget)
                    }
                }
            } else {
                ForEach(Array(store.hubWidgets.enumerated()), id: \.element.id) { index, widget in
                    widgetChrome(widget, index: index) {
                        widgetBody(widget)
                    }
                }
            }

            if isCustomizing {
                Button {
                    showAddWidget = true
                } label: {
                    Label("Add to HUB", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(store.unusedHubWidgets().isEmpty)
            }
        }
    }

    private var pairCamerasAndWeather: Bool {
        sizeClass == .regular
            && store.hubWidgets.contains(where: { $0.kind == .cameras })
            && store.hubWidgets.contains(where: { $0.kind == .weather })
    }

    private var pairedTopWidgets: [HubWidget] {
        store.hubWidgets.filter { $0.kind == .cameras || $0.kind == .weather }
            .sorted { lhs, rhs in
                if lhs.kind == .cameras { return true }
                if rhs.kind == .cameras { return false }
                return false
            }
    }

    private var remainingWidgets: [HubWidget] {
        store.hubWidgets.filter { $0.kind != .cameras && $0.kind != .weather }
    }

    @ViewBuilder
    private func widgetBody(_ widget: HubWidget) -> some View {
        switch widget.kind {
        case .cameras:
            CamerasPlaceholderCard()
        case .weather:
            weatherStrip
        case .snapshot:
            householdStats
        }
    }

    private func widgetChrome<Content: View>(_ widget: HubWidget, index: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isCustomizing {
                HStack(spacing: 8) {
                    Image(systemName: widget.kind.symbol)
                    Text(widget.kind.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        store.moveHubWidget(id: widget.id, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(index == 0)
                    Button {
                        store.moveHubWidget(id: widget.id, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(index == store.hubWidgets.count - 1)
                    Button(role: .destructive) {
                        store.removeHubWidget(widget.id)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ice)
                .padding(.horizontal, 4)
            }
            content()
        }
    }

    private var weatherStrip: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Weather")
                            .font(.headline.weight(.semibold))
                        Button {
                            showPlaceSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                Text(store.weatherPlace?.label ?? "Set location")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(AppTheme.ice)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if weather.isLoading { ProgressView() }
                }

                if let errorMessage = weather.errorMessage, weather.days.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                        ForEach(weather.days) { day in
                            VStack(spacing: 4) {
                                Text(day.weekday.uppercased())
                                    .font(.system(size: 9, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundStyle(AppTheme.textTertiary)
                                Image(systemName: day.symbolName)
                                    .font(.body)
                                    .foregroundStyle(AppTheme.ice)
                                    .symbolRenderingMode(.hierarchical)
                                    .frame(height: 18)
                                Text("\(day.high)°")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(AppTheme.text)
                                Text("\(day.low)°")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppTheme.navySoft)
                            )
                        }
                    }
                }
            }
        }
    }

    private var householdStats: some View {
        HStack(spacing: 10) {
            householdStat("Open chores", "\(store.openAssignments().count)", "checkmark.circle")
            householdStat("Reminders", "\(store.reminders.filter { !$0.isCompleted }.count)", "bell")
            householdStat("To-dos", "\(store.todos.filter { !$0.isCompleted }.count)", "square.and.pencil")
        }
    }

    private func householdStat(_ title: String, _ value: String, _ symbol: String) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(AppTheme.ice)
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.text)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(title: "Family")
                Spacer()
                Text("Hold a card, then slide")
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
                    ForEach(store.members) { member in
                        MemberHomeCard(member: member)
                            .frame(width: width, height: 210)
                            .offset(x: draggingID == member.id ? dragTranslation : 0)
                            .scaleEffect(draggingID == member.id ? 1.02 : 1)
                            .zIndex(draggingID == member.id ? 10 : 0)
                            .highPriorityGesture(reorderGesture(for: member, cardWidth: width))
                    }
                }
            }
            .scrollDisabled(draggingID != nil)
        }
        .frame(height: 210)
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

    private func cardWidth(in available: CGFloat) -> CGFloat {
        if sizeClass == .regular {
            return min(300, max(240, (available - 12) / 2.4))
        }
        return max(230, available - 48)
    }
}

// MARK: - Cameras placeholder

private struct CamerasPlaceholderCard: View {
    private let cams = [
        ("Front door", "door.left.hand.closed"),
        ("Garage", "car.fill"),
        ("Backyard", "leaf.fill"),
        ("Driveway", "light.beacon.max.fill"),
    ]

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Cameras")
                        .font(.headline.weight(.semibold))
                    Spacer()
                    Text("STANDBY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.ice)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            Capsule().stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(cams, id: \.0) { name, symbol in
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.black.opacity(0.55))
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.ice.opacity(0.7))
                                VStack {
                                    HStack {
                                        Circle().fill(AppTheme.ice.opacity(0.35)).frame(width: 6, height: 6)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(8)
                            }
                            .frame(height: 78)
                            Text(name.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Add widget

private struct AddWidgetSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    var onAdd: (HubWidgetKind) -> Void

    var body: some View {
        NavigationStack {
            List {
                if store.unusedHubWidgets().isEmpty {
                    Text("Every HUB tile is already on the screen. Remove one to add it back.")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(store.unusedHubWidgets()) { kind in
                        Button {
                            onAdd(kind)
                            dismiss()
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title).font(.headline)
                                    Text(kind.detail)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            } icon: {
                                Image(systemName: kind.symbol)
                                    .foregroundStyle(AppTheme.ice)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to HUB")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Compact person card

private struct MemberHomeCard: View {
    @EnvironmentObject private var store: HubStore
    let member: FamilyMember

    private var chores: [ChoreAssignment] { store.openAssignments(for: member.id) }
    private var reminders: [ReminderItem] { store.openReminders(for: member.id) }
    private var todos: [TodoItem] { store.openTodos(for: member.id) }
    private var events: [CalendarEvent] { Array(store.todayEvents(for: member.id).prefix(2)) }
    private var accent: Color { Color(hex: member.colorHex) }

    var body: some View {
        HStack(spacing: 0) {
            accent.frame(width: 5)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    MemberAvatar(member: member, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(member.name)
                            .font(.system(size: 16, weight: .semibold))
                            .tracking(-0.2)
                        Text(member.role.label)
                            .font(.caption2.weight(.semibold))
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
                if events.isEmpty {
                    Text("Free today")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                } else {
                    ForEach(events) { event in
                        HStack(spacing: 6) {
                            Text(event.allDay ? "All day" : event.startAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(AppTheme.navy)
                                .frame(width: 48, alignment: .leading)
                            Text(event.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func personStat(_ value: Int, _ title: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ice)
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
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

struct WeatherPlaceSheet: View {
    @ObservedObject var weather: WeatherLoader
    var onPick: (WeatherPlace) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var locating = false
    @State private var locateError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    TextField("City or ZIP code", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .onSubmit { Task { await weather.search(query: query) } }
                    Button("Search") {
                        Task { await weather.search(query: query) }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button {
                    Task { await useCurrent() }
                } label: {
                    HStack {
                        if locating { ProgressView() } else { Image(systemName: "location.fill") }
                        Text("Use current location").font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                if let locateError {
                    Text(locateError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if weather.searchResults.isEmpty {
                    Text("Search a city or ZIP. The place you pick is saved for the household.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(weather.searchResults) { place in
                        Button {
                            onPick(place)
                            dismiss()
                        } label: {
                            HStack {
                                Text(place.label).font(.headline).foregroundStyle(AppTheme.text)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(12)
                            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer()
            }
            .padding(20)
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Weather location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func useCurrent() async {
        locating = true
        locateError = nil
        defer { locating = false }
        do {
            onPick(try await weather.placeFromCurrentLocation())
            dismiss()
        } catch {
            locateError = error.localizedDescription
        }
    }
}
