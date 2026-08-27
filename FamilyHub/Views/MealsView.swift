import MapKit
import SwiftUI
import UIKit

struct MealsView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @State private var pickLaunch: DinnerLaunch?
    @State private var confirmClearAll = false
    @State private var tourFocus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Meal", tail: "Planning")
                .coachSpot("mealHeader")
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HubPanel(symbol: "fork.knife", title: "Next 2 Weeks", trailing: {
                        Button("Clear all") { confirmClearAll = true }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.22), in: Capsule())
                    }) {
                        weekGrid
                    }
                    .coachSpot("mealWeek")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .onChange(of: tourFocus) { _, id in
                guard !id.isEmpty else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
            }
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .hubTour("meals", steps: HubTours.meals) { id in
            tourFocus = id
        }
        .fullScreenCover(item: $pickLaunch) { item in
            DinnerLaunchView(item: item) {
                pickLaunch = nil
            }
            .environmentObject(store)
            .environmentObject(router)
        }
        .hubConfirm(
            "Clear all meals?",
            isPresented: $confirmClearAll,
            message: "This removes every dinner on the next 2 weeks.",
            confirm: "Clear all",
            confirmColor: AppTheme.chore,
            cancel: "Cancel"
        ) {
            for day in week { store.clearDinner(on: day) }
        }
    }

    private var weekGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(week, id: \.self) { day in
                MealDayCard(day: day) {
                    pickLaunch = DinnerLaunch(day: day, pick: store.dinner(on: day) == nil)
                }
            }
        }
    }

    private var week: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }
}

private struct MealDayCard: View {
    @EnvironmentObject private var store: HubStore
    let day: Date
    var onOpen: () -> Void

    private var plan: DinnerPlan? { store.dinner(on: day) }
    private var title: String? { store.dinnerTitle(on: day) }
    private var recipe: Recipe? { plan.flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) } }
    private var planned: Bool { plan != nil }

    var body: some View {
        Button(action: onOpen) {
            card
        }
        .buttonStyle(.plain)
    }

    private var card: some View {
        HStack(spacing: 12) {
            thumb
            VStack(alignment: .leading, spacing: 8) {
                Text(dayLabel)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                Text(title ?? "Nothing planned")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(title == nil ? AppTheme.textSecondary : AppTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(kindLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 164, maxHeight: 164, alignment: .topLeading)
        .background(AppTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(title == nil ? AppTheme.cardBorder : AppTheme.blue, lineWidth: title == nil ? 1 : 3)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }

    private var thumb: some View {
        ZStack {
            AppTheme.blueSoft
            Image(systemName: planned ? "fork.knife" : "plus")
                .foregroundStyle(AppTheme.blue)
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dayLabel: String {
        if Calendar.current.isDateInToday(day) { return "Tonight" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var kindLabel: String {
        guard let plan else { return "Tap to plan" }
        if plan.placeKind == "delivery" { return "Delivery" }
        if plan.placeKind == "takeout" { return "Take out" }
        if plan.placeName != nil { return "Eating out" }
        if let id = plan.recipeID, let recipe = store.recipe(id: id) {
            if let side = store.dinnerSide(on: day) {
                return "\(recipe.kind.label) · with \(side.name)"
            }
            return recipe.kind.label
        }
        if !plan.note.isEmpty { return "Custom meal" }
        return "Planned"
    }
}

struct DinnerLaunch: Identifiable {
    let id = UUID()
    let day: Date
    let pick: Bool
}

struct DinnerLaunchView: View {
    let item: DinnerLaunch
    var onClose: () -> Void

    var body: some View {
        MealChoiceSheet(day: item.day, onComplete: onClose)
    }
}

struct TonightDinnerView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let day: Date
    @State private var addedToList = false
    @State private var skipShopping = false

    private var plan: DinnerPlan? { store.dinner(on: day) }
    private var recipe: Recipe? {
        plan.flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "What's For", tail: "Dinner") {
                HubHeaderPill(title: "Close") {
                    dismiss()
                    router.open(.today)
                }
                if plan != nil {
                    HubHeaderPill(title: "Delete", color: AppTheme.chore) {
                        store.clearDinner(on: day)
                        dismiss()
                        router.open(.today)
                    }
                    HubHeaderPill(title: "Change Meal") {
                        dismiss()
                        router.openMeals(day: day)
                    }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    dinnerBody
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private var dinnerBody: some View {
        if plan == nil {
            Text("Nothing planned")
                .font(.system(size: 34, weight: .bold))
            Button("Plan dinner") {
                dismiss()
                router.openMeals(day: day)
            }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.blue, in: Capsule())
        } else if let recipe {
            cookView(recipe, heading: "Main", side: false)
            if let side = store.dinnerSide(on: day) {
                cookView(side, heading: "Side", side: true)
            }
        } else if let plan, plan.placeName != nil {
            eatOutView(plan)
        } else {
            noteView
            if let side = store.dinnerSide(on: day) {
                cookView(side, heading: "Side", side: true)
            }
        }
    }

    private func cookView(_ recipe: Recipe, heading: String, side: Bool) -> some View {
        let method = store.dinnerCookMethod(on: day, side: side) ?? CookPlaybook.suggested(name: recipe.name, instructions: recipe.instructions)
        return VStack(alignment: .leading, spacing: 16) {
            RecipePhoto(url: URL(string: recipe.imageURL), searchName: recipe.name)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text(heading)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
            Text(recipe.name)
                .font(.system(size: 34, weight: .bold))
            Text("How you’ll cook it")
                .font(.title3.weight(.bold))
            CookMethodPicker(
                method: Binding(
                    get: { store.dinnerCookMethod(on: day, side: side) ?? method },
                    set: { store.setDinnerCookMethod(on: day, method: $0, side: side) }
                ),
                name: recipe.name,
                instructions: recipe.instructions
            )
            CookDirectionsCard(
                method: store.dinnerCookMethod(on: day, side: side) ?? method,
                name: recipe.name,
                steps: recipe.instructions
            )
            if !recipe.ingredients.isEmpty {
                Text("What you need")
                    .font(.title3.weight(.bold))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(AppTheme.blue).frame(width: 6, height: 6).padding(.top, 8)
                            Text(line)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                if !skipShopping {
                    Button {
                        for line in recipe.ingredients { store.addShoppingItem(line, fromDinner: day, recipeID: recipe.id) }
                        addedToList = true
                    } label: {
                        Text(addedToList ? "Added to shopping" : "Add ingredients to shopping")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(addedToList ? AppTheme.todo : AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    if !addedToList {
                        Button("Skip shopping") { skipShopping = true }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            if !recipe.notes.isEmpty {
                Text(recipe.notes)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private func eatOutView(_ plan: DinnerPlan) -> some View {
        PlaceDetailView(
            name: plan.placeName ?? "Restaurant",
            address: plan.placeAddress,
            phone: plan.placePhone,
            website: plan.placeURL.flatMap(URL.init(string:)),
            coordinate: plan.placeLatitude.flatMap { lat in
                plan.placeLongitude.map { CLLocationCoordinate2D(latitude: lat, longitude: $0) }
            },
            kindTitle: plan.placeKind == "delivery" ? "Delivery Tonight" : plan.placeKind == "takeout" ? "Take Out" : "Eating Out"
        )
    }

    private var noteView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isToday ? "Dinner tonight" : "Dinner")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
            Text(plan?.note ?? store.dinnerTitle(on: day) ?? "Dinner")
                .font(.system(size: 34, weight: .bold))
        }
    }

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    private func infoRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(AppTheme.blue).frame(width: 24)
            Text(text).font(.body)
            Spacer()
        }
        .padding(16)
    }

    private func actionPill(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.blue, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct MealChoiceSheet: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    let day: Date
    var onComplete: () -> Void = {}
    @State private var route: MealPath?

    var body: some View {
        if let item = route {
            routeView(item)
        } else {
            choiceGrid
        }
    }

    private var choiceGrid: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "What's For", tail: "Dinner") {
                HubHeaderPill(title: "Close") {
                    router.open(.today)
                    onComplete()
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(dayTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                    if let title = store.dinnerTitle(on: day) {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.todo)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Locked in")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.todo)
                                Text(title)
                                    .font(.title3.weight(.bold))
                            }
                            Spacer()
                            Button("Change") { store.clearDinner(on: day) }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                        }
                        .padding(18)
                        .background(AppTheme.todoSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        choice(.eatOut(.sitdown), title: "Eating out", detail: "Sit down near you", symbol: "fork.knife", image: "DinnerEatOut")
                        choice(.eatOut(.takeout), title: "Take out", detail: "Pick it up and bring it home", symbol: "bag.fill", image: "DinnerTakeout")
                        choice(.eatOut(.delivery), title: "Delivery", detail: "Brought to your door", symbol: "bicycle", image: "DinnerDelivery")
                        choice(.family, title: "Family recipes", detail: "Scan, type, or paste a TikTok link", symbol: "book.closed.fill", image: "DinnerFamily")
                        choice(.recipes, title: "Recipes", detail: "American and world cookbook", symbol: "fork.knife.circle.fill", image: "DinnerRecipes")
                        choice(.manual, title: "Enter a meal", detail: "Type it yourself", symbol: "square.and.pencil", image: "DinnerManual")
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    private func choice(_ item: MealPath, title: String, detail: String, symbol: String, image: String) -> some View {
        Button {
            DispatchQueue.main.async { route = item }
        } label: {
            DinnerChoiceCard(title: title, detail: detail, symbol: symbol, imageName: image)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func routeView(_ item: MealPath) -> some View {
        switch item {
        case .eatOut(let mode):
            EatOutPicker(day: day, mode: mode) { finish() }
        case .family:
            FamilyRecipePicker(day: day) { go(.sides) }
        case .recipes:
            CatalogRecipePicker(day: day) { go(.sides) }
        case .manual:
            ManualMealSheet(day: day) { go(.sides) }
        case .sides:
            SidePicker(day: day) { go(.review) }
        case .review:
            DinnerReviewView(day: day, onDone: finish)
        }
    }

    private func go(_ item: MealPath) {
        DispatchQueue.main.async { route = item }
    }

    private func finish() {
        DispatchQueue.main.async { onComplete() }
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day) { return "Tonight" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

private struct DinnerChoiceCard: View {
    let title: String
    let detail: String
    let symbol: String
    let imageName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let ui = UIImage(named: imageName) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 148)
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                AppTheme.blueSoft
                    .frame(maxWidth: .infinity)
                    .frame(height: 148)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.blue, in: Circle())
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
        }
        .frame(maxWidth: .infinity, minHeight: 248, maxHeight: 248)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}

private enum MealPath: Hashable, Identifiable {
    case eatOut(PlaceMode)
    case family, recipes, manual, sides, review

    var id: String {
        switch self {
        case .eatOut(let mode): return "eat-\(mode.rawValue)"
        case .family: return "family"
        case .recipes: return "recipes"
        case .manual: return "manual"
        case .sides: return "sides"
        case .review: return "review"
        }
    }
}

private struct EatOutPicker: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var places = PlacesSearch()
    let day: Date
    var mode: PlaceMode = .sitdown
    var onDone: () -> Void
    @State private var areaQuery = ""
    @State private var opened: NearbyPlace?
    @State private var chip = "Nearby"
    @StateObject private var completer = AreaCompleter()

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]
    private let chips = ["Nearby", "Pizza", "Burgers", "Tacos", "Chicken", "Chinese", "Italian", "Mexican", "Fast food", "Coffee"]

    private var headerLead: String {
        switch mode {
        case .delivery: return "Food"
        case .takeout: return "Take"
        case .sitdown: return "Eating"
        }
    }

    private var headerTail: String {
        mode == .delivery ? "Delivery" : "Out"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: headerLead, tail: headerTail)
                .coachSpot("eatHeader")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                    Text("Tap a place.")
                        .foregroundStyle(AppTheme.textSecondary)
                    searchBar
                    chipRow
                    if !completer.suggestions.isEmpty {
                        suggestionList
                    }
                    if places.isLoading { ProgressView() }
                    if let message = places.message {
                        Text(message).foregroundStyle(AppTheme.textSecondary)
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(places.places) { place in
                            Button { opened = place } label: {
                                placeTile(place)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $opened) { place in
            PlaceInfoView(place: place, day: day, mode: mode, onDone: onDone)
        }
        .task {
            places.mode = mode
            await places.useHere()
            if let here = places.userLocation { completer.setRegion(here) }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textTertiary)
            TextField("McDonald’s, pizza, tacos…", text: $areaQuery)
                .textFieldStyle(.plain)
                .onSubmit { runSearch(areaQuery) }
                .onChange(of: areaQuery) { _, value in
                    completer.update(value)
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.isEmpty == false else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        guard areaQuery == value else { return }
                        await places.searchMaps(value)
                    }
                }
            if places.isLoading { ProgressView() }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.self) { item in
                    FilterChip(title: item, color: AppTheme.blue, selected: chip == item) {
                        chip = item
                        areaQuery = item == "Nearby" ? "" : item
                        completer.clear()
                        Task {
                            if item == "Nearby" {
                                await places.useHere()
                            } else {
                                await places.searchMaps(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(completer.suggestions) { item in
                Button {
                    areaQuery = item.title
                    completer.clear()
                    Task { await places.searchMaps(item.query) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(AppTheme.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func runSearch(_ raw: String) {
        completer.clear()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if trimmed.isEmpty {
                await places.useHere()
            } else {
                await places.searchMaps(trimmed)
            }
        }
    }
}

private struct FamilyRecipePicker: View {
    @EnvironmentObject private var store: HubStore
    let day: Date
    var onDone: () -> Void
    @State private var showAdd = false
    @State private var showScan = false
    @State private var showLink = false
    @State private var opened: Recipe?
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]

    private var familyRecipes: [Recipe] {
        let all = store.recipes.filter { $0.kind == .family }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(needle) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Family", tail: "Recipes") {
                HStack(spacing: 8) {
                    Button { showScan = true } label: {
                        Label("Scan", systemImage: "doc.text.viewfinder")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button { showLink = true } label: {
                        Label("Link", systemImage: "link")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button { showAdd = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.blueSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                    Text("Tap a family recipe.")
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textTertiary)
                        TextField("Grandma’s chili, cookies…", text: $query)
                            .textFieldStyle(.plain)
                    }
                    .padding(14)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if familyRecipes.isEmpty {
                        Text(query.isEmpty ? "Nothing saved yet. Scan, link, or add one." : "No match.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(familyRecipes) { recipe in
                            Button { opened = recipe } label: {
                                savedRecipeTile(recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) { AddFamilyRecipeSheet().environmentObject(store) }
        .fullScreenCover(isPresented: $showScan) { ScanRecipeSheet().environmentObject(store) }
        .fullScreenCover(isPresented: $showLink) { ImportSocialRecipeView().environmentObject(store) }
    }

    private func saveAction(symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.blue)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text(detail)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }

    private func savedRecipeTile(_ recipe: Recipe) -> some View {
        ZStack(alignment: .bottomLeading) {
            RecipePhoto(url: URL(string: recipe.imageURL), searchName: recipe.name)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text("FAMILY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.blue, in: Capsule())
                Text(recipe.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
    }

    private func sourceLabel(_ recipe: Recipe) -> String {
        let notes = recipe.notes.lowercased()
        if notes.contains("tiktok") { return "TikTok" }
        if notes.contains("youtube") { return "YouTube" }
        if notes.contains("instagram") { return "Instagram" }
        if notes.contains("pinterest") { return "Pinterest" }
        if notes.contains("from ") { return recipe.kind.label }
        return "Saved"
    }
}

private struct FamilyRecipeDetail: View {
    @EnvironmentObject private var store: HubStore
    let recipe: Recipe
    let day: Date
    var onDone: () -> Void
    @State private var servings = 4
    @State private var method = CookMethod.oven

    private var scaled: [String] { IngredientScale.lines(recipe.ingredients, servings: servings) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = URL(string: recipe.imageURL), !recipe.imageURL.isEmpty {
                    RecipePhoto(url: url, searchName: recipe.name)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                Text(recipe.name)
                    .font(.system(size: 32, weight: .bold))
                Text(recipe.kind.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                if !recipe.notes.isEmpty {
                    Text(recipe.notes)
                }
                ServingsStepper(servings: $servings)
                if !scaled.isEmpty {
                    Text("Ingredients for \(servings) \(servings == 1 ? "person" : "people")")
                        .font(.title3.weight(.bold))
                    ingredientList(scaled)
                }
                Text("How you’ll cook it")
                    .font(.title3.weight(.bold))
                CookMethodPicker(method: $method, name: recipe.name, category: recipe.kind.label, instructions: recipe.instructions)
                CookDirectionsCard(method: method, name: recipe.name, steps: recipe.instructions)
                Button {
                    store.setDinner(on: day, recipeID: recipe.id, servings: servings, cookMethod: method)
                    onDone()
                } label: {
                    Text("Add for dinner")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { method = CookPlaybook.suggested(name: recipe.name, instructions: recipe.instructions) }
    }
}

private struct CatalogRecipePicker: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var catalog = RecipeCatalog()
    let day: Date
    var onDone: () -> Void
    @State private var opened: CatalogRecipe?

    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]

    var body: some View {
        if let recipe = opened {
            VStack(alignment: .leading, spacing: 0) {
                HubStickyHeader(lead: "Recipe", tail: "") {
                    HubHeaderPill(title: "Back") { opened = nil }
                }
                CatalogRecipeDetail(recipe: recipe, day: day, onDone: {
                    opened = nil
                    onDone()
                })
            }
            .background(AppTheme.bg.ignoresSafeArea())
        } else {
            recipeList
        }
    }

    private var recipeList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "All", tail: "Recipes") {
                HubHeaderPill(title: "Close") { onDone() }
            }
            searchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            chips
                .padding(.horizontal, 20)
            if let message = catalog.message {
                Text(message)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 20)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(catalog.recipes.prefix(60).enumerated()), id: \.offset) { _, recipe in
                        Button {
                            let picked = recipe
                            DispatchQueue.main.async { opened = picked }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    AppTheme.blueSoft
                                    Image(systemName: "fork.knife")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(AppTheme.blue)
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.name)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(AppTheme.text)
                                        .lineLimit(2)
                                    Text(recipe.category)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.blue)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            Task { await catalog.load() }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textTertiary)
            TextField("Burger, chili, tacos…", text: $catalog.query)
                .textFieldStyle(.plain)
                .onSubmit { Task { await catalog.search() } }
            if catalog.isLoading { ProgressView() }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(catalog.categories, id: \.self) { item in
                    FilterChip(title: item, color: AppTheme.blue, selected: catalog.category == item) {
                        catalog.category = item
                        Task { await catalog.search() }
                    }
                }
            }
        }
    }
}

private struct CatalogRecipeDetail: View {
    @EnvironmentObject private var store: HubStore
    let recipe: CatalogRecipe
    let day: Date
    var onDone: () -> Void
    @State private var servings = 4
    @State private var method = CookMethod.oven

    private var scaled: [String] { IngredientScale.lines(recipe.ingredients, servings: servings) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    AppTheme.blueSoft
                    Image(systemName: "fork.knife")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text(recipe.name)
                    .font(.system(size: 32, weight: .bold))
                Text([recipe.category, recipe.area].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                ServingsStepper(servings: $servings)
                if !scaled.isEmpty {
                    Text("Ingredients for \(servings) \(servings == 1 ? "person" : "people")")
                        .font(.title3.weight(.bold))
                    ingredientList(scaled)
                }
                Text("How you’ll cook it")
                    .font(.title3.weight(.bold))
                CookMethodPicker(method: $method, name: recipe.name, category: recipe.category, instructions: recipe.instructions)
                CookDirectionsCard(method: method, name: recipe.name, steps: recipe.instructions)
                Button {
                    if let existing = store.recipes.first(where: { $0.catalogID == recipe.id && !recipe.id.isEmpty }) {
                        store.setDinner(on: day, recipeID: existing.id, servings: servings, cookMethod: method)
                    } else {
                        let saved = recipe.asHubRecipe()
                        store.addRecipe(saved)
                        store.setDinner(on: day, recipeID: saved.id, servings: servings, cookMethod: method)
                    }
                    let done = onDone
                    DispatchQueue.main.async { done() }
                } label: {
                    Text("Add for dinner")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { method = CookPlaybook.suggested(name: recipe.name, instructions: recipe.instructions) }
    }
}

private struct SidePicker: View {
    @EnvironmentObject private var store: HubStore
    let day: Date
    var onDone: () -> Void
    @StateObject private var catalog = SideCatalog()
    @State private var opened: CatalogRecipe?
    private let columns = [GridItem(.adaptive(minimum: 240), spacing: 16)]

    var body: some View {
        if let recipe = opened {
            VStack(alignment: .leading, spacing: 0) {
                HubStickyHeader(lead: "Side", tail: "") {
                    HubHeaderPill(title: "Back") { opened = nil }
                }
                SideDetail(recipe: recipe, day: day, onDone: {
                    let done = onDone
                    DispatchQueue.main.async { done() }
                })
            }
            .background(AppTheme.bg.ignoresSafeArea())
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HubStickyHeader(lead: "All", tail: "Sides") {
                    HubHeaderPill(title: "Skip side") {
                        store.setDinnerSide(on: day, recipeID: nil)
                        DispatchQueue.main.async { onDone() }
                    }
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(catalog.recipes.prefix(60).enumerated()), id: \.offset) { _, recipe in
                            Button {
                                let picked = recipe
                                DispatchQueue.main.async { opened = picked }
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        AppTheme.blueSoft
                                        Image(systemName: "leaf.fill")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(AppTheme.blue)
                                    }
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recipe.name)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(AppTheme.text)
                                            .lineLimit(2)
                                        Text(recipe.category)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.blue)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .onAppear { Task { await catalog.load() } }
        }
    }
}

private struct SideDetail: View {
    @EnvironmentObject private var store: HubStore
    let recipe: CatalogRecipe
    let day: Date
    var onDone: () -> Void
    @State private var method = CookMethod.oven

    private var servings: Int { store.dinner(on: day)?.servings ?? 4 }
    private var scaled: [String] { IngredientScale.lines(recipe.ingredients, servings: servings) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    AppTheme.blueSoft
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text(recipe.name)
                    .font(.system(size: 32, weight: .bold))
                Text("Side · \(recipe.category) · \(servings) \(servings == 1 ? "person" : "people")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                if !scaled.isEmpty {
                    Text("Ingredients")
                        .font(.title3.weight(.bold))
                    ingredientList(scaled)
                }
                Text("How you’ll cook it")
                    .font(.title3.weight(.bold))
                CookMethodPicker(method: $method, name: recipe.name, category: recipe.category, instructions: recipe.instructions)
                CookDirectionsCard(method: method, name: recipe.name, steps: recipe.instructions)
                Button {
                    if let existing = store.recipes.first(where: { $0.catalogID == recipe.id && $0.kind == .side }) {
                        store.setDinnerSide(on: day, recipeID: existing.id, cookMethod: method)
                    } else {
                        let saved = recipe.asHubRecipe(kind: .side)
                        store.addRecipe(saved)
                        store.setDinnerSide(on: day, recipeID: saved.id, cookMethod: method)
                    }
                    onDone()
                } label: {
                    Text("Add side for dinner")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { method = CookPlaybook.suggested(name: recipe.name, instructions: recipe.instructions) }
    }
}

private struct DinnerReviewView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    let day: Date
    var onDone: () -> Void
    @State private var picked: Set<String> = []

    private var servings: Int { store.dinner(on: day)?.servings ?? 4 }
    private var main: Recipe? { store.dinner(on: day).flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) } }
    private var side: Recipe? { store.dinnerSide(on: day) }
    private var mainLines: [String] { IngredientScale.lines(main?.ingredients ?? [], servings: servings) }
    private var sideLines: [String] { IngredientScale.lines(side?.ingredients ?? [], servings: servings) }
    private var allKeys: [String] {
        mainLines.map { "main|\($0)" } + sideLines.map { "side|\($0)" }
    }
    private var people: String { "\(servings) \(servings == 1 ? "person" : "people")" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Dinner", tail: "Is set")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(people). Tap an ingredient to add or skip it.")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    HStack(alignment: .top, spacing: 14) {
                        dishCard(title: "Main", recipe: main, lines: mainLines, prefix: "main", methodSide: false)
                        dishCard(title: "Side", recipe: side, lines: sideLines, prefix: "side", methodSide: true)
                    }
                }
                .padding(20)
            }
            VStack(spacing: 10) {
                if allKeys.isEmpty {
                    Button("Done — go to Hub", action: goToHub)
                        .buttonStyle(HubFillButton())
                } else {
                    Button("Add everything to shopping", action: addAllAndFinish)
                        .buttonStyle(HubFillButton())
                    Button("Add \(picked.count) selected") {
                        addPicked()
                        goToHub()
                    }
                    .buttonStyle(HubOutlineButton())
                    .disabled(picked.isEmpty)
                    .opacity(picked.isEmpty ? 0.45 : 1)
                    Button("Skip shopping", action: goToHub)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .padding(.top, 8)
            .background(AppTheme.bg)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { picked = Set(allKeys) }
    }

    private func dishCard(title: String, recipe: Recipe?, lines: [String], prefix: String, methodSide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                AppTheme.blueSoft
                Image(systemName: "fork.knife")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.blue)
            Text(recipe?.name ?? (methodSide ? "No side" : store.dinnerTitle(on: day) ?? "Dinner"))
                .font(.title3.weight(.bold))
                .lineLimit(2)
            if let method = store.dinnerCookMethod(on: day, side: methodSide) {
                Text(method.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
            if lines.isEmpty {
                Text("No ingredients")
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    let key = "\(prefix)|\(line)"
                    Button {
                        if picked.contains(key) { picked.remove(key) } else { picked.insert(key) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: picked.contains(key) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(picked.contains(key) ? AppTheme.todo : AppTheme.blue)
                            Text(line)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }

    private func addAllAndFinish() {
        picked = Set(allKeys)
        addPicked()
        goToHub()
    }

    private func addPicked() {
        let mainID = main?.id
        let sideID = side?.id
        for key in picked {
            if key.hasPrefix("main|") {
                store.addShoppingItem(String(key.dropFirst(5)), fromDinner: day, recipeID: mainID)
            } else if key.hasPrefix("side|") {
                store.addShoppingItem(String(key.dropFirst(5)), fromDinner: day, recipeID: sideID)
            }
        }
    }

    private func goToHub() {
        router.open(.today)
        onDone()
    }
}

private struct HubFillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.blue, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct HubOutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .foregroundStyle(AppTheme.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.blueSoft, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.blue, lineWidth: 2))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct ServingsStepper: View {
    @Binding var servings: Int

    var body: some View {
        HStack(spacing: 16) {
            Text("Servings")
                .font(.title3.weight(.bold))
            Spacer()
            Button {
                servings = max(1, servings - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.blue, in: Circle())
            }
            .buttonStyle(.plain)
            Text("\(servings)")
                .font(.system(size: 28, weight: .bold))
                .frame(minWidth: 44)
            Text(servings == 1 ? "person" : "people")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                servings = min(20, servings + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.blue, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }
}

private struct CookMethodPicker: View {
    @Binding var method: CookMethod
    var name: String
    var category: String = ""
    var instructions: String = ""

    private var allowed: [CookMethod] {
        CookPlaybook.methods(name: name, category: category, instructions: instructions)
    }
    private let columns = [GridItem(.adaptive(minimum: 118), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(allowed) { item in
                Button {
                    method = item
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: item.symbol)
                            .font(.title2.weight(.bold))
                        Text(item.label)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(method == item ? .white : AppTheme.blue)
                    .frame(maxWidth: .infinity, minHeight: 78)
                    .background(method == item ? AppTheme.blue : AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.blue, lineWidth: method == item ? 0 : 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            DispatchQueue.main.async { clamp() }
        }
        .onChange(of: name) { _, _ in clamp() }
    }

    private func clamp() {
        if !allowed.contains(method) {
            method = allowed.first ?? .oven
        }
    }
}

private struct CookDirectionsCard: View {
    let method: CookMethod
    var name: String
    var steps: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: method.symbol)
                    .foregroundStyle(AppTheme.blue)
                Text("Cook it — \(method.label)")
                    .font(.title3.weight(.bold))
            }
            Text(CookPlaybook.directions(name: name, method: method, recipeSteps: steps))
                .font(.body.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }
}

private func ingredientList(_ lines: [String]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(AppTheme.blue).frame(width: 6, height: 6).padding(.top, 8)
                Text(line)
            }
        }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(AppTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
}

enum IngredientScale {
    static let base = 4

    static func lines(_ lines: [String], servings: Int, base: Int = base) -> [String] {
        guard base > 0, servings != base else { return lines }
        let factor = Double(servings) / Double(base)
        return lines.map { scale($0, by: factor) }
    }

    static func scale(_ line: String, by factor: Double) -> String {
        var result = line
        let pattern = #"(\d+\s+\d+/\d+|\d+/\d+|\d+\.\d+|\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches.reversed() {
                guard let range = Range(match.range, in: line) else { continue }
                let raw = String(line[range])
                let value = parse(raw) * factor
                result.replaceSubrange(range, with: format(value, like: raw))
            }
        }
        return result
    }

    private static func parse(_ raw: String) -> Double {
        let parts = raw.split(separator: " ")
        if parts.count == 2, let whole = Double(parts[0]) {
            return whole + fraction(String(parts[1]))
        }
        if raw.contains("/") { return fraction(raw) }
        return Double(raw) ?? 0
    }

    private static func fraction(_ raw: String) -> Double {
        let bits = raw.split(separator: "/")
        guard bits.count == 2, let n = Double(bits[0]), let d = Double(bits[1]), d != 0 else { return Double(raw) ?? 0 }
        return n / d
    }

    private static func format(_ value: Double, like original: String) -> String {
        if original.contains("/") || abs(value.rounded() - value) > 0.05 {
            let rounded = (value * 4).rounded() / 4
            let whole = Int(rounded)
            let frac = rounded - Double(whole)
            let bit = frac < 0.12 ? "" : frac < 0.38 ? " 1/4" : frac < 0.63 ? " 1/2" : frac < 0.88 ? " 3/4" : ""
            if bit.isEmpty { return "\(max(whole, 0) == 0 && value < 1 ? formatDecimal(value) : "\(max(whole, 1))")" }
            if whole == 0 { return bit.trimmingCharacters(in: .whitespaces) }
            return "\(whole)\(bit)"
        }
        let n = max(1, Int(value.rounded()))
        return "\(n)"
    }

    private static func formatDecimal(_ value: Double) -> String {
        String(format: value < 1 ? "%.2f" : "%.1f", value)
    }
}

private func placeTile(_ place: NearbyPlace) -> some View {
    ZStack(alignment: .bottomLeading) {
        PlacePhoto(place: place)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
        VStack(alignment: .leading, spacing: 6) {
            Text(place.mode.title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.blue, in: Capsule())
            Text(place.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if let distance = place.distanceLabel {
                Text(distance)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(12)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 210)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(AppTheme.blue, lineWidth: 3)
    )
    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
}

private func recipeTile(_ recipe: CatalogRecipe) -> some View {
    ZStack(alignment: .bottomLeading) {
        RecipePhoto(url: recipe.thumb, searchName: recipe.name)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        LinearGradient(colors: [.clear, .black.opacity(0.78)], startPoint: .center, endPoint: .bottom)
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.category.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.blue, in: Capsule())
            Text(recipe.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(12)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 210)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(AppTheme.blue, lineWidth: 3)
    )
    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
}

struct RecipePhoto: View {
    let url: URL?
    var searchName: String = ""
    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .overlay {
                ZStack {
                    AppTheme.blueSoft
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.blue.opacity(0.45))
                    }
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .onAppear {
                if image == nil {
                    image = RecipeImages.cachedImage(url: url, name: searchName)
                }
            }
            .task(id: "\(url?.absoluteString ?? "")-\(searchName)") {
                if image == nil {
                    image = RecipeImages.cachedImage(url: url, name: searchName)
                }
                if image == nil {
                    image = await RecipeImages.photo(url: url, name: searchName)
                }
            }
    }
}

struct PlacePhoto: View {
    let place: NearbyPlace
    @State private var image: UIImage?

    private var fallback: String {
        switch place.mode {
        case .delivery: return "DinnerDelivery"
        case .takeout: return "DinnerTakeout"
        default: return "DinnerEatOut"
        }
    }

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(fallback)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: place.id) {
                if let found = await PlaceImages.photo(
                    name: place.name,
                    address: place.address,
                    coordinate: place.coordinate,
                    website: place.url
                ) {
                    image = found
                }
            }
    }
}

struct PlaceThumb: View {
    var mode: PlaceMode

    var body: some View {
        ZStack {
            AppTheme.blueSoft
            Image(systemName: mode.symbol)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.blue)
        }
    }
}

private struct PlaceInfoView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.openURL) private var openURL
    let place: NearbyPlace
    let day: Date
    var mode: PlaceMode
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            PlaceDetailView(
                name: place.name,
                address: place.address,
                phone: place.phone,
                website: place.url,
                coordinate: place.coordinate,
                kindTitle: mode.title,
                distance: place.distanceLabel,
                confirmTitle: "Set as dinner"
            ) {
                store.setDinnerPlace(
                    on: day,
                    name: place.name,
                    address: place.address,
                    phone: place.phone,
                    url: place.url?.absoluteString ?? "",
                    kind: mode.rawValue,
                    latitude: place.coordinate.latitude,
                    longitude: place.coordinate.longitude
                )
                onDone()
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ManualMealSheet: View {
    @EnvironmentObject private var store: HubStore
    let day: Date
    var onDone: () -> Void
    @State private var name = ""
    @State private var notes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Enter", tail: "Meal")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Image("DinnerManual")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppTheme.blue, lineWidth: 3)
                        )
                    TextField("What’s for dinner?", text: $name)
                        .font(.title3)
                        .padding(14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Button {
                        store.setDinner(on: day, recipeID: nil, note: name.trimmingCharacters(in: .whitespaces))
                        onDone()
                    } label: {
                        Text("Set dinner")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AddFamilyRecipeSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var ingredients = ""
    @State private var instructions = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Recipe name", text: $name)
                        .font(.title3)
                        .padding(14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    TextField("Ingredients", text: $ingredients, axis: .vertical)
                        .lineLimit(4...8)
                        .padding(14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    TextField("Directions", text: $instructions, axis: .vertical)
                        .lineLimit(4...10)
                        .padding(14)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Family recipe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addRecipe(.make(
                            name: name.trimmingCharacters(in: .whitespaces),
                            kind: .family,
                            ingredients: ingredients.split(separator: "\n").map(String.init),
                            instructions: instructions
                        ))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private func mealRow(title: String, detail: String) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline.weight(.bold)).foregroundStyle(AppTheme.text)
            if !detail.isEmpty {
                Text(detail).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.textSecondary)
            }
        }
        Spacer()
        Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.textTertiary)
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
    .background(AppTheme.card)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(AppTheme.cardBorder, lineWidth: 1)
    )
}

private struct AddRecipeSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: RecipeKind = .recipe
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $kind) {
                    ForEach(RecipeKind.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                TextField("Notes", text: $notes)
            }
            .navigationTitle("Add meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addRecipe(.make(name: name.trimmingCharacters(in: .whitespaces), kind: kind, notes: notes))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct CatalogRecipeSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let recipe: CatalogRecipe
    let day: Date

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let url = recipe.thumb {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            AppTheme.blueSoft.frame(height: 220)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(recipe.name).font(.system(size: 28, weight: .semibold))
                        Text([recipe.category, recipe.area].filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(AppTheme.textSecondary)
                        if !recipe.ingredients.isEmpty {
                            SectionLabel(title: "Ingredients")
                            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, line in
                                Text("· \(line)").font(.body)
                            }
                        }
                        if !recipe.instructions.isEmpty {
                            SectionLabel(title: "Directions")
                            Text(recipe.instructions)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button("Save to my recipes") {
                            store.addRecipe(recipe.asHubRecipe())
                            dismiss()
                        }
                        Button("Make this dinner") {
                            let item = recipe.asHubRecipe()
                            store.addRecipe(item)
                            store.setDinner(on: day, recipeID: item.id)
                            dismiss()
                        }
                    } label: {
                        Text("Use")
                    }
                }
            }
        }
    }
}

private struct SavedRecipeSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let day: Date

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.name).font(.system(size: 28, weight: .semibold))
                    Text(recipe.kind.label).foregroundStyle(AppTheme.textSecondary)
                    if !recipe.notes.isEmpty { Text(recipe.notes) }
                    if !recipe.ingredients.isEmpty {
                        SectionLabel(title: "Ingredients")
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, line in
                            Text("· \(line)")
                        }
                    }
                    if !recipe.instructions.isEmpty {
                        SectionLabel(title: "Directions")
                        Text(recipe.instructions)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Make dinner") {
                        store.setDinner(on: day, recipeID: recipe.id)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PlaceDetailSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let place: NearbyPlace
    let day: Date

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Map(initialPosition: .region(region)) {
                        Marker(place.name, coordinate: place.coordinate)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 0))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(place.name).font(.system(size: 28, weight: .semibold))
                        Text(place.mode.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                        if !place.address.isEmpty {
                            infoRow("mappin.and.ellipse", place.address)
                        }
                        if let distance = place.distanceLabel {
                            infoRow("location", distance)
                        }
                        if !place.phone.isEmpty {
                            infoRow("phone", place.phone)
                        }
                        if let url = place.url {
                            infoRow("safari", url.host ?? "Website")
                        }

                        HStack(spacing: 10) {
                            if !place.phone.isEmpty, let tel = URL(string: "tel:\(place.phone.filter { $0.isNumber || $0 == "+" })") {
                                pill("Call", "phone.fill") { openURL(tel) }
                            }
                            if let url = place.url {
                                pill(place.mode == .takeout ? "Menu / order" : "Menu & info", "menucard") { openURL(url) }
                            }
                            pill("Directions", "arrow.triangle.turn.up.right.diamond.fill") {
                                let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
                                item.name = place.name
                                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                            }
                        }

                        Button {
                            store.setDinnerPlace(
                                on: day,
                                name: place.name,
                                address: place.address,
                                phone: place.phone,
                                url: place.url?.absoluteString ?? "",
                                kind: place.mode.rawValue
                            )
                            dismiss()
                        } label: {
                            Text("Set as dinner")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 28)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func infoRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(AppTheme.blue).frame(width: 20)
            Text(text).font(.body)
        }
    }

    private func pill(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
