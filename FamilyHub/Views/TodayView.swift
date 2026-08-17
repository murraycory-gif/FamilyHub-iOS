import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var weather = WeatherLoader()
    @State private var draggingID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragOriginIndex: Int?
    @State private var showPlaceSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 14)

            weatherStrip
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

            householdStats
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

            HStack {
                SectionLabel(title: "Family")
                Spacer()
                Text("Hold a card, then slide")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)

            memberStrip
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Hub")
        .navigationBarTitleDisplayMode(.large)
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

    private var weatherStrip: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This week")
                            .font(.headline)
                        Button {
                            showPlaceSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                Text(store.weatherPlace?.label ?? "Set location")
                                    .font(.subheadline.weight(.semibold))
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.bold))
                            }
                            .foregroundStyle(AppTheme.navy)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if weather.isLoading {
                        ProgressView()
                    }
                }

                if let errorMessage = weather.errorMessage, weather.days.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(weather.days) { day in
                                VStack(spacing: 6) {
                                    Text(day.weekday.uppercased())
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Image(systemName: day.symbolName)
                                        .font(.title3)
                                        .foregroundStyle(AppTheme.navy)
                                        .symbolRenderingMode(.hierarchical)
                                        .frame(height: 22)
                                    Text("\(day.high)°")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text("\(day.low)°")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                .frame(width: 58)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppTheme.navySoft.opacity(0.65))
                                )
                            }
                        }
                    }
                }
            }
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
            let width = cardWidth(in: geo.size.width)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(store.members) { member in
                        MemberHomeCard(member: member)
                            .frame(width: width, height: geo.size.height)
                            .offset(x: draggingID == member.id ? dragTranslation : 0)
                            .scaleEffect(draggingID == member.id ? 1.03 : 1)
                            .shadow(
                                color: draggingID == member.id ? AppTheme.navy.opacity(0.18) : .clear,
                                radius: 18,
                                y: 8
                            )
                            .zIndex(draggingID == member.id ? 10 : 0)
                            .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: draggingID)
                            .highPriorityGesture(reorderGesture(for: member, cardWidth: width))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .scrollDisabled(draggingID != nil)
            .scrollClipDisabled()
        }
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
                    let step = cardWidth + 16
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
                    Image(systemName: "line.3.horizontal")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .accessibilityHidden(true)
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

// MARK: - Location picker

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
                        if locating {
                            ProgressView()
                        } else {
                            Image(systemName: "location.fill")
                        }
                        Text("Use current location")
                            .font(.headline)
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
                    Text("Search Chicago, 60614, or any city. The place you pick is saved for the household.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(weather.searchResults) { place in
                        Button {
                            onPick(place)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.label)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.text)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.textTertiary)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func useCurrent() async {
        locating = true
        locateError = nil
        defer { locating = false }
        do {
            let place = try await weather.placeFromCurrentLocation()
            onPick(place)
            dismiss()
        } catch {
            locateError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .environmentObject(HubStore())
}
