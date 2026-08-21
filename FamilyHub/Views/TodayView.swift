import MapKit
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
    @State private var showDayMenu = false
    @State private var showProfileMenu = false
    @StateObject private var weather = WeatherLoader()
    @State private var showWeatherOutlook = false
    @State private var showWeatherPlace = false
    @State private var showAddShopping = false
    @State private var shoppingDraft = ""
    @State private var showDinner = false

    var body: some View {
        GeometryReader { geo in
            let familyH = max(geo.size.height * 0.46, sizeClass == .regular ? 340 : 280)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    HStack(alignment: .top, spacing: 12) {
                        agenda
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity)
                        VStack(spacing: 12) {
                            weatherTile
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            shoppingTile
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        dinnerHomeTile
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                    .simultaneousGesture(daySwipe)
                }
                .padding(.horizontal, 24)
                .padding(.top, 2)
                .padding(.bottom, 8)
                familySection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                    .frame(height: familyH)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .sheet(isPresented: $showDayMenu) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(upcomingDays, id: \.self) { day in
                            Button {
                                selectedDay = day
                                showDayMenu = false
                            } label: {
                                filterChoiceRow(
                                    title: menuDayLabel(day),
                                    detail: day.formatted(.dateTime.month(.abbreviated).day().weekday(.wide)),
                                    selected: Calendar.current.isDate(day, inSameDayAs: selectedDay)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        DatePicker("Day", selection: $selectedDay, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.top, 8)
                            .tint(AppTheme.blue)
                    }
                    .padding(20)
                }
                .background(AppTheme.bg.ignoresSafeArea())
                .navigationTitle("Pick a day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showDayMenu = false }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showProfileMenu) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 8) {
                        Button {
                            profile = .family
                            showProfileMenu = false
                        } label: {
                            filterChoiceRow(title: "Whole family", detail: store.householdName, selected: profile == .family)
                        }
                        .buttonStyle(.plain)
                        ForEach(store.members) { member in
                            Button {
                                profile = .member(member.id)
                                showProfileMenu = false
                            } label: {
                                filterChoiceRow(
                                    title: member.name,
                                    detail: member.role.label,
                                    selected: profile == .member(member.id),
                                    color: Color(hex: member.colorHex)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .background(AppTheme.bg.ignoresSafeArea())
                .navigationTitle("Who’s Hub")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showProfileMenu = false }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showDinner) {
            TonightDinnerView(day: selectedDay)
                .environmentObject(store)
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
            let label = store.weatherPlace?.label ?? ""
            if label.isEmpty || label == "Chicago" || label == "Current location" {
                if let here = try? await weather.placeFromCurrentLocation() {
                    store.setWeatherPlace(here)
                }
            }
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

    private var homeTileH: CGFloat { sizeClass == .regular ? 168 : 148 }

    private var greetingLead: String { "Good" }

    private var greetingTail: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Morning" }
        if hour < 17 { return "Afternoon" }
        return "Evening"
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(greetingLead)
                    .foregroundStyle(AppTheme.text)
                Text(greetingTail)
                    .foregroundStyle(AppTheme.blue)
            }
            .font(.system(size: 34, weight: .bold))
            Spacer(minLength: 12)
            dateButton
            profileButton
        }
    }

    private var dateButton: some View {
        Button { showDayMenu = true } label: {
            filterBanner(symbol: "calendar", title: shortDayName)
        }
        .buttonStyle(.plain)
    }

    private var profileButton: some View {
        Button { showProfileMenu = true } label: {
            filterBanner(symbol: "person.3.fill", title: shortProfileName)
        }
        .buttonStyle(.plain)
    }

    private func filterBanner(symbol: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
            Text(title)
                .font(.headline.weight(.bold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func filterChoiceRow(title: String, detail: String = "", selected: Bool, color: Color = AppTheme.blue) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 6, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(selected ? AppTheme.blueSoft : AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? AppTheme.blue : AppTheme.cardBorder, lineWidth: selected ? 3 : 1)
        )
        .contentShape(Rectangle())
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
        VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(
                symbol: "calendar",
                title: Calendar.current.isDateInToday(selectedDay) ? "On Today's Agenda" : "On the Agenda"
            ) {
                Text(profileTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
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
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(AppTheme.blueSoft)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
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
        return VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "cart.fill", title: "Shopping List") {
                Button {
                    shoppingDraft = ""
                    showAddShopping = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 24, height: 24)
                        .background(.white, in: Circle())
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
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.blueSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }

    private var nextEventTile: some View {
        let item = dayItems.first
        return Button {
            if let item, item.kind == .event, let uuid = UUID(uuidString: String(item.id.dropFirst(2))) {
                router.openCalendar(filter: dayFilter, day: selectedDay, eventID: uuid)
            } else {
                router.openCalendar(filter: dayFilter, day: selectedDay)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(dayHeadline)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer(minLength: 0)
                if let item {
                    Text(item.timeLabel)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                    Text(item.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                    Text(assigneeName(for: item))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(assigneeColor(for: item))
                } else {
                    Text("Free")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                    Text(emptyDayCopy)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(daySwipe)
    }

    private var dinnerHomeTile: some View {
        let plan = store.dinner(on: selectedDay)
        let recipe = plan.flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) }
        let title = store.dinnerTitle(on: selectedDay)
        return Button { showDinner = true } label: {
            VStack(spacing: 0) {
                HubTileBanner(symbol: "fork.knife", title: "What's For Dinner")
                VStack(spacing: 10) {
                    dinnerPhoto(plan: plan, recipe: recipe)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.blue, lineWidth: 2)
                        )
                    Text(dinnerEyebrow(plan))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                    Text(title ?? "Nothing planned")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    Text(dinnerHint(plan, recipe: recipe))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.blueSoft)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(daySwipe)
    }

    @ViewBuilder
    private func dinnerPhoto(plan: DinnerPlan?, recipe: Recipe?) -> some View {
        if let recipe, let url = URL(string: recipe.imageURL), recipe.imageURL.isEmpty == false {
            RecipePhoto(url: url)
        } else if let plan, let lat = plan.placeLatitude, let lon = plan.placeLongitude {
            PlaceSnapshot(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        } else {
            ZStack {
                AppTheme.blue
                Image(systemName: plan?.placeName != nil ? "mappin.and.ellipse" : "fork.knife")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func homeStatTile(title: String, value: String, detail: String = "", symbol: String, color: Color, soft: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(color)
                Spacer(minLength: 0)
                Text(value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.text)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(color)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(soft)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
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
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(assigneeColor(for: item))
                .frame(width: 6)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.timeLabel)
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.blue)
                Text(item.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Text(assigneeName(for: item))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(assigneeColor(for: item))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(assigneeColor(for: item).opacity(0.16), in: Capsule())
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
        let plan = store.dinner(on: selectedDay)
        let recipe = plan.flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) }
        let photoURL = recipe.flatMap { URL(string: $0.imageURL) }
        return Button { showDinner = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "FFEDD5"))
                    if let photoURL {
                        RecipePhoto(url: photoURL)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: plan?.placeName != nil ? "mappin.and.ellipse" : "fork.knife")
                            .foregroundStyle(Color(hex: "C2410C"))
                    }
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(dinnerEyebrow(plan))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: "C2410C"))
                    Text(store.dinnerTitle(on: selectedDay) ?? "Nothing planned — tap to pick dinner")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                    Text(dinnerHint(plan, recipe: recipe))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "FFF7ED"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(daySwipe)
    }

    private func dinnerEyebrow(_ plan: DinnerPlan?) -> String {
        if plan?.placeKind == "delivery" {
            return Calendar.current.isDateInToday(selectedDay) ? "Delivery tonight" : "Delivery"
        }
        if plan?.placeKind == "takeout" {
            return Calendar.current.isDateInToday(selectedDay) ? "Take out tonight" : "Take out"
        }
        if plan?.placeName != nil {
            return Calendar.current.isDateInToday(selectedDay) ? "Eating out tonight" : "Eating out"
        }
        return Calendar.current.isDateInToday(selectedDay) ? "Dinner tonight" : "Dinner"
    }

    private func dinnerHint(_ plan: DinnerPlan?, recipe: Recipe?) -> String {
        if recipe != nil { return "Tap for ingredients and steps" }
        if plan?.placeName != nil { return "Tap for address and directions" }
        if plan != nil { return "Tap to see the plan" }
        return "Tap to plan dinner"
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
        VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "house.fill", title: "HUB")
            memberStrip
                .padding(12)
        }
        .background(AppTheme.blueSoft)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
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

            DayStatusRow(
                chores: store.openAssignments(for: nil).filter { $0.status == .pending && Calendar.current.isDate($0.dueOn, inSameDayAs: day) }.count,
                reminders: store.reminders.filter { !$0.isCompleted && ($0.dueAt.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false) }.count,
                todos: store.todos.filter { !$0.isCompleted && ($0.dueAt.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false) }.count
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)

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

    private var chores: [ChoreAssignment] {
        store.openAssignments(for: member.id).filter { $0.status == .pending && Calendar.current.isDate($0.dueOn, inSameDayAs: day) }
    }
    private var reminders: [ReminderItem] {
        store.openReminders(for: member.id).filter { item in
            item.dueAt.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
        }
    }
    private var todos: [TodoItem] {
        store.openTodos(for: member.id).filter { item in
            item.dueAt.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
        }
    }
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

            DayStatusRow(chores: chores.count, reminders: reminders.count, todos: todos.count)
                .padding(.horizontal, 12)
                .padding(.top, 10)

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

private struct DayStatusRow: View {
    let chores: Int
    let reminders: Int
    let todos: Int

    var body: some View {
        HStack(spacing: 8) {
            box(AppTheme.chore, AppTheme.choreSoft, "checkmark.circle.fill", chores, "Chores")
            box(AppTheme.reminder, AppTheme.reminderSoft, "bell.fill", reminders, "Remind")
            box(AppTheme.todo, AppTheme.todoSoft, "square.and.pencil", todos, "To-dos")
        }
    }

    private func box(_ color: Color, _ soft: Color, _ symbol: String, _ count: Int, _ title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text("\(count)")
                .monospacedDigit()
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
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

struct BannerLook: Identifiable {
    let id: String
    let title: String
    var group: String = "Scenes"
    var imageName: String { id }
}

struct BannerStudio: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let current: Data?
    var onSave: (Data?) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var cropPayload: PhotoCropPayload?
    @State private var preview: Data?

    private let looks: [BannerLook] = [
        .init(id: "BannerDusk", title: "Dusk", group: "Scenes"),
        .init(id: "BannerDawn", title: "Dawn", group: "Scenes"),
        .init(id: "BannerOcean", title: "Ocean", group: "Scenes"),
        .init(id: "BannerLagoon", title: "Lagoon", group: "Scenes"),
        .init(id: "BannerForest", title: "Forest", group: "Scenes"),
        .init(id: "BannerMeadow", title: "Meadow", group: "Scenes"),
        .init(id: "BannerSunset", title: "Sunset", group: "Scenes"),
        .init(id: "BannerNight", title: "Night", group: "Scenes"),
        .init(id: "BannerAurora", title: "Aurora", group: "Scenes"),
        .init(id: "BannerStorm", title: "Storm", group: "Scenes"),
        .init(id: "BannerIce", title: "Ice", group: "Scenes"),
        .init(id: "BannerPeony", title: "Peony", group: "Flowers"),
        .init(id: "BannerRoses", title: "Roses", group: "Flowers"),
        .init(id: "BannerDaisies", title: "Daisies", group: "Flowers"),
        .init(id: "BannerWildflower", title: "Wildflower", group: "Flowers"),
        .init(id: "BannerTropical", title: "Tropical", group: "Flowers"),
        .init(id: "BannerBlush", title: "Blush", group: "Flowers"),
        .init(id: "BannerRose", title: "Rose field", group: "Flowers"),
        .init(id: "BannerSportsCar", title: "Sports car", group: "Wheels"),
        .init(id: "BannerTruck", title: "Truck", group: "Wheels"),
        .init(id: "BannerDirtBike", title: "Dirt bike", group: "Wheels"),
        .init(id: "BannerBike", title: "Bike", group: "Wheels"),
        .init(id: "BannerMoto", title: "Moto", group: "Wheels"),
        .init(id: "BannerChevron", title: "Chevron", group: "Designs"),
        .init(id: "BannerGeo", title: "Geo", group: "Designs"),
        .init(id: "BannerDots", title: "Dots", group: "Designs"),
        .init(id: "BannerStripe", title: "Stripe", group: "Designs"),
        .init(id: "BannerWave", title: "Wave", group: "Designs"),
        .init(id: "BannerRoyal", title: "Royal", group: "Designs"),
        .init(id: "BannerCarbon", title: "Carbon", group: "Designs"),
        .init(id: "BannerGold", title: "Gold", group: "Designs"),
        .init(id: "BannerInk", title: "Ink", group: "Designs"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    uploadBar
                    ForEach(["Scenes", "Flowers", "Wheels", "Designs"], id: \.self) { group in
                        Text(group)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(looks.filter { $0.group == group }) { look in
                                Button { applyLook(look) } label: {
                                    lookCard(look)
                                }
                                .buttonStyle(.plain)
                            }
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
            }
            .padding(16)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }

    private var uploadBar: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 14) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Upload your photo")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text("Then move and zoom so it fits the banner")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(16)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 3)
                )
            }
            .buttonStyle(.plain)
            if preview != nil {
                HStack(spacing: 10) {
                    Button { openAdjust() } label: {
                        Label("Move & zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    Button { preview = nil } label: {
                        Label("Clear", systemImage: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(AppTheme.blueSoft, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
        }
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

struct BannerCropper: View {
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

