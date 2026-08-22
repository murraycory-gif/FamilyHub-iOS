import MapKit
import SwiftUI
import UIKit

struct MealsView: View {
    @EnvironmentObject private var store: HubStore
    @State private var pickDay: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                title
                HubPanel(symbol: "fork.knife", title: "Next 2 Weeks") {
                    weekGrid
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .fullScreenCover(item: pickDayBinding) { day in
            TonightDinnerView(day: day.date)
                .environmentObject(store)
        }
    }

    private var title: some View {
        HStack(spacing: 10) {
            Text("Meal")
                .foregroundStyle(AppTheme.text)
            Text("Planning")
                .foregroundStyle(AppTheme.blue)
        }
        .font(.system(size: 36, weight: .bold))
    }

    private var weekGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(week, id: \.self) { day in
                Button { pickDay = day } label: {
                    dayCard(day)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayCard(_ day: Date) -> some View {
        let title = store.dinnerTitle(on: day)
        let plan = store.dinner(on: day)
        let recipe = plan.flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) }
        return HStack(spacing: 12) {
            dayThumb(plan: plan, recipe: recipe)
            VStack(alignment: .leading, spacing: 8) {
                Text(dayLabel(day))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                Text(title ?? "Nothing planned")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(title == nil ? AppTheme.textSecondary : AppTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(kindLabel(plan))
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
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(title == nil ? AppTheme.cardBorder : AppTheme.blue, lineWidth: title == nil ? 1 : 3)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }

    private func dayThumb(plan: DinnerPlan?, recipe: Recipe?) -> some View {
        Group {
            if let recipe, let url = URL(string: recipe.imageURL), !recipe.imageURL.isEmpty {
                RecipePhoto(url: url, searchName: recipe.name)
            } else if let plan, let name = plan.placeName {
                PlaceHeroPhoto(
                    name: name,
                    address: plan.placeAddress,
                    coordinate: plan.placeLatitude.flatMap { lat in
                        plan.placeLongitude.map { CLLocationCoordinate2D(latitude: lat, longitude: $0) }
                    },
                    website: plan.placeURL.flatMap(URL.init(string:))
                )
            } else {
                ZStack {
                    AppTheme.blueSoft
                    Image(systemName: plan?.placeName != nil ? "mappin.and.ellipse" : "fork.knife")
                        .foregroundStyle(AppTheme.blue)
                }
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func kindLabel(_ plan: DinnerPlan?) -> String {
        guard let plan else { return "Tap to plan" }
        if plan.placeKind == "delivery" { return "Delivery" }
        if plan.placeKind == "takeout" { return "Take out" }
        if plan.placeName != nil { return "Eating out" }
        if let id = plan.recipeID, let recipe = store.recipe(id: id) {
            return recipe.kind.label
        }
        if !plan.note.isEmpty { return "Custom meal" }
        return "Planned"
    }

    private var week: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<14).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Tonight" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var pickDayBinding: Binding<DatedDay?> {
        Binding(
            get: { pickDay.map(DatedDay.init) },
            set: { pickDay = $0?.date }
        )
    }
}

private struct DatedDay: Identifiable {
    var date: Date
    var id: TimeInterval { Calendar.current.startOfDay(for: date).timeIntervalSince1970 }
}

struct TonightDinnerView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let day: Date
    @State private var showChange = false
    @State private var addedToList = false

    private var plan: DinnerPlan? { store.dinner(on: day) }
    private var recipe: Recipe? {
        plan.flatMap { $0.recipeID }.flatMap { store.recipe(id: $0) }
    }

    var body: some View {
        if plan == nil {
            MealChoiceSheet(day: day)
        } else {
            NavigationStack { content }
                .fullScreenCover(isPresented: $showChange) {
                    MealChoiceSheet(day: day)
                        .environmentObject(store)
                }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let recipe {
                    cookView(recipe)
                } else if let plan, plan.placeName != nil {
                    eatOutView(plan)
                } else {
                    noteView
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }.foregroundStyle(AppTheme.blue)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Change") { showChange = true }.foregroundStyle(AppTheme.blue)
            }
        }
    }

    private func cookView(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let url = URL(string: recipe.imageURL), !recipe.imageURL.isEmpty {
                RecipePhoto(url: url, searchName: recipe.name)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            Text(isToday ? "Dinner tonight" : "Dinner")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
            Text(recipe.name)
                .font(.system(size: 34, weight: .bold))
            if !recipe.ingredients.isEmpty {
                Text("What you need")
                    .font(.title3.weight(.bold))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recipe.ingredients, id: \.self) { line in
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
                Button {
                    for line in recipe.ingredients { store.addShoppingItem(line) }
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
            }
            if !recipe.instructions.isEmpty {
                Text("How to make it")
                    .font(.title3.weight(.bold))
                Text(recipe.instructions)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var path: [MealPath] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Text("What's For")
                            .foregroundStyle(AppTheme.text)
                        Text("Dinner")
                            .foregroundStyle(AppTheme.blue)
                    }
                    .font(.system(size: 36, weight: .bold))
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
                        NavigationLink(value: MealPath.eatOut(.sitdown)) {
                            DinnerChoiceCard(
                                title: "Eating out",
                                detail: "Sit down near you",
                                symbol: "fork.knife",
                                photo: URL(string: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=60")
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: MealPath.eatOut(.takeout)) {
                            DinnerChoiceCard(
                                title: "Take out",
                                detail: "Pick it up and bring it home",
                                symbol: "bag.fill",
                                photo: URL(string: "https://images.unsplash.com/photo-1561758033-d89a9ad46330?auto=format&fit=crop&w=800&q=60")
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: MealPath.eatOut(.delivery)) {
                            DinnerChoiceCard(
                                title: "Delivery",
                                detail: "Brought to your door",
                                symbol: "bicycle",
                                photo: URL(string: "https://images.unsplash.com/photo-1526367790999-0150786686a2?auto=format&fit=crop&w=800&q=60")
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: MealPath.family) {
                            DinnerChoiceCard(
                                title: "Family recipes",
                                detail: "Scan a card or type one in",
                                symbol: "book.closed.fill",
                                photo: URL(string: "https://images.unsplash.com/photo-1556910103-1c02745aae4d?auto=format&fit=crop&w=800&q=60")
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: MealPath.recipes) {
                            DinnerChoiceCard(
                                title: "Recipes",
                                detail: "A huge American cookbook",
                                symbol: "fork.knife.circle.fill",
                                photo: URL(string: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=60")
                            )
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: MealPath.manual) {
                            DinnerChoiceCard(
                                title: "Enter a meal",
                                detail: "Type it yourself",
                                symbol: "square.and.pencil",
                                photo: URL(string: "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&w=800&q=60")
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(AppTheme.blue)
                }
            }
            .navigationDestination(for: MealPath.self) { item in
                switch item {
                case .eatOut(let mode): EatOutPicker(day: day, mode: mode) { dismiss() }
                case .family: FamilyRecipePicker(day: day) { dismiss() }
                case .recipes: CatalogRecipePicker(day: day) { dismiss() }
                case .manual: ManualMealSheet(day: day) { dismiss() }
                }
            }
        }
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
    let photo: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipePhoto(url: photo, searchName: title)
                .frame(maxWidth: .infinity)
                .frame(height: 148)
                .clipped()
                .allowsHitTesting(false)
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

private enum MealPath: Hashable {
    case eatOut(PlaceMode)
    case family, recipes, manual
}

private struct EatOutPicker: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var places = PlacesSearch()
    let day: Date
    var mode: PlaceMode = .sitdown
    var onDone: () -> Void
    @State private var areaQuery = ""
    @State private var opened: NearbyPlace?
    @StateObject private var completer = AreaCompleter()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text(mode == .delivery ? "Delivery" : mode == .takeout ? "Take" : "Eating")
                        .foregroundStyle(AppTheme.text)
                    if mode != .delivery {
                        Text(mode == .takeout ? "Out" : "Out")
                            .foregroundStyle(AppTheme.blue)
                    }
                }
                .font(.system(size: 36, weight: .bold))
                Text(mode == .delivery ? "Places that can come to you. Near \(places.areaName)." : mode == .takeout ? "Pick it up near \(places.areaName)." : "Sit down near \(places.areaName).")
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textTertiary)
                    TextField("McDonald’s, pizza, tacos…", text: $areaQuery)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            completer.clear()
                            Task { await places.searchMaps(areaQuery) }
                        }
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
                }
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                HStack(spacing: 8) {
                    Button {
                        areaQuery = ""
                        completer.clear()
                        Task { await places.useHere() }
                    } label: {
                        Label("Here", systemImage: "location.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Text("Or a city / zip")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                if !completer.suggestions.isEmpty {
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
                if places.isLoading { ProgressView() }
                if let message = places.message {
                    Text(message).foregroundStyle(AppTheme.textSecondary)
                }
                LazyVStack(spacing: 14) {
                    ForEach(places.places) { place in
                        Button { opened = place } label: {
                            HStack(spacing: 14) {
                                PlaceThumb(mode: place.mode)
                                    .frame(width: 88, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(place.name)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(AppTheme.text)
                                        .lineLimit(2)
                                    Text(place.mode.title)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppTheme.blue)
                                    if !place.address.isEmpty {
                                        Text(place.address)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    if let distance = place.distanceLabel {
                                        Text(distance)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(AppTheme.cardBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $opened) { place in
            PlaceInfoView(place: place, day: day, mode: mode, onDone: onDone)
        }
        .task {
            places.mode = mode
            await places.useHere()
            if let here = places.userLocation { completer.setRegion(here) }
        }
    }
}

private struct FamilyRecipePicker: View {
    @EnvironmentObject private var store: HubStore
    let day: Date
    var onDone: () -> Void
    @State private var showAdd = false
    @State private var showScan = false
    @State private var opened: Recipe?

    private var familyRecipes: [Recipe] {
        store.recipes.filter { $0.kind == .family }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        Text("Family")
                            .foregroundStyle(AppTheme.text)
                        Text("Recipes")
                            .foregroundStyle(AppTheme.blue)
                    }
                    .font(.system(size: 36, weight: .bold))
                    Spacer()
                    Button { showScan = true } label: {
                        Label("Scan", systemImage: "doc.text.viewfinder")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Button { showAdd = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(AppTheme.blue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.blueSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text("Scan a recipe card or cookbook page. We’ll pull the name, ingredients, and steps.")
                    .foregroundStyle(AppTheme.textSecondary)
                if familyRecipes.isEmpty {
                    Button { showScan = true } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.blue)
                            Text("Scan your first recipe")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Text("Photo a handwritten card, a printed page, or a cookbook.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppTheme.blue, lineWidth: 3)
                        )
                    }
                    .buttonStyle(.plain)
                }
                ForEach(familyRecipes) { recipe in
                    Button { opened = recipe } label: {
                        mealRow(title: recipe.name, detail: recipe.kind.label)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $opened) { recipe in
            FamilyRecipeDetail(recipe: recipe, day: day, onDone: onDone)
        }
        .sheet(isPresented: $showAdd) { AddFamilyRecipeSheet() }
        .fullScreenCover(isPresented: $showScan) { ScanRecipeSheet() }
    }
}

private struct FamilyRecipeDetail: View {
    @EnvironmentObject private var store: HubStore
    let recipe: Recipe
    let day: Date
    var onDone: () -> Void

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
                if !recipe.ingredients.isEmpty {
                    Text("Ingredients")
                        .font(.title3.weight(.bold))
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(recipe.ingredients, id: \.self) { line in
                            Text("· \(line)")
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                if !recipe.instructions.isEmpty {
                    Text("Directions")
                        .font(.title3.weight(.bold))
                    Text(recipe.instructions)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                Button {
                    store.setDinner(on: day, recipeID: recipe.id)
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
    }
}

private struct CatalogRecipePicker: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var catalog = RecipeCatalog()
    let day: Date
    var onDone: () -> Void
    @State private var opened: CatalogRecipe?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("All")
                        .foregroundStyle(AppTheme.text)
                    Text("Recipes")
                        .foregroundStyle(AppTheme.blue)
                }
                .font(.system(size: 36, weight: .bold))
                Text("American dinners load instantly. Search or tap a style.")
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textTertiary)
                    TextField("Burger, chili, tacos, fried chicken…", text: $catalog.query)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await catalog.search() } }
                    if catalog.isLoading { ProgressView() }
                }
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                if let message = catalog.message {
                    Text(message).foregroundStyle(AppTheme.textSecondary)
                }
                ForEach(catalog.recipes) { recipe in
                    Button {
                        Task { opened = await catalog.detail(id: recipe.id) ?? recipe }
                    } label: {
                        HStack(spacing: 14) {
                            RecipePhoto(url: recipe.thumb, searchName: recipe.name)
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(2)
                                Text([recipe.category, recipe.area].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $opened) { recipe in
            CatalogRecipeDetail(recipe: recipe, day: day, onDone: onDone)
        }
        .task { await catalog.load() }
    }
}

private struct CatalogRecipeDetail: View {
    @EnvironmentObject private var store: HubStore
    let recipe: CatalogRecipe
    let day: Date
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RecipePhoto(url: recipe.thumb, searchName: recipe.name)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text(recipe.name)
                    .font(.system(size: 32, weight: .bold))
                Text([recipe.category, recipe.area].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                if !recipe.ingredients.isEmpty {
                    Text("Ingredients")
                        .font(.title3.weight(.bold))
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(recipe.ingredients, id: \.self) { line in
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
                if !recipe.instructions.isEmpty {
                    Text("Directions")
                        .font(.title3.weight(.bold))
                    Text(recipe.instructions)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                Button {
                    if let existing = store.recipes.first(where: { $0.catalogID == recipe.id && !recipe.id.isEmpty }) {
                        store.setDinner(on: day, recipeID: existing.id)
                    } else {
                        let saved = recipe.asHubRecipe()
                        store.addRecipe(saved)
                        store.setDinner(on: day, recipeID: saved.id)
                    }
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
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RecipePhoto: View {
    let url: URL?
    var searchName: String = ""
    @State private var image: UIImage?
    @State private var finished = false

    var body: some View {
        Color.clear
            .overlay {
                ZStack {
                    AppTheme.blueSoft
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if !finished && (url != nil || !searchName.isEmpty) {
                        ProgressView()
                    } else {
                        Image(systemName: "fork.knife").foregroundStyle(AppTheme.blue)
                    }
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .task(id: "\(url?.absoluteString ?? "")-\(searchName)") {
                image = await RecipeImages.photo(url: url, name: searchName)
                finished = true
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

struct PlacePhoto: View {
    let coordinate: CLLocationCoordinate2D
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            AppTheme.blueSoft
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ProgressView()
            }
        }
        .task(id: "\(coordinate.latitude),\(coordinate.longitude)") {
            await load()
        }
    }

    private func load() async {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 350, longitudinalMeters: 350)
        options.size = CGSize(width: 600, height: 400)
        options.showsBuildings = true
        if let snapshot = try? await MKMapSnapshotter(options: options).start() {
            image = snapshot.image
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Enter")
                        .foregroundStyle(AppTheme.text)
                    Text("Meal")
                        .foregroundStyle(AppTheme.blue)
                }
                .font(.system(size: 36, weight: .bold))
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
                            ForEach(recipe.ingredients, id: \.self) { line in
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
                        ForEach(recipe.ingredients, id: \.self) { line in
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
