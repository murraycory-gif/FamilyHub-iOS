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
                weekGrid
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
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                    .textCase(.uppercase)
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
        .frame(maxWidth: .infinity, minHeight: 148, maxHeight: 148, alignment: .topLeading)
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
                RecipePhoto(url: url)
            } else if let lat = plan?.placeLatitude, let lon = plan?.placeLongitude {
                PlacePhoto(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
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
        if plan.placeKind == "takeout" { return "Eat out · Takeout" }
        if plan.placeName != nil { return "Eat out" }
        if let id = plan.recipeID, let recipe = store.recipe(id: id) {
            return recipe.kind.label
        }
        if !plan.note.isEmpty { return "Custom meal" }
        return "Planned"
    }

    private var week: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
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
                RecipePhoto(url: url)
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
        VStack(alignment: .leading, spacing: 16) {
            if let lat = plan.placeLatitude, let lon = plan.placeLongitude {
                PlacePhoto(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            Text(isToday ? "Eating out tonight" : "Eating out")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
            Text(plan.placeName ?? "Restaurant")
                .font(.system(size: 34, weight: .bold))
            Text(plan.placeKind == "takeout" ? "Takeout" : "Sit down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppTheme.blueSoft, in: Capsule())

            VStack(spacing: 0) {
                if let address = plan.placeAddress, !address.isEmpty {
                    infoRow("mappin.and.ellipse", address)
                }
                if let phone = plan.placePhone, !phone.isEmpty {
                    infoRow("phone.fill", phone)
                }
            }
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            HStack(spacing: 10) {
                if let phone = plan.placePhone, !phone.isEmpty,
                   let tel = URL(string: "tel:\(phone.filter(\.isNumber))") {
                    actionPill("Call", "phone.fill") { openURL(tel) }
                }
                if let raw = plan.placeURL, let url = URL(string: raw) {
                    actionPill("Menu", "menucard") { openURL(url) }
                }
                if let address = plan.placeAddress, !address.isEmpty,
                   let maps = URL(string: "http://maps.apple.com/?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address)") {
                    actionPill("Directions", "arrow.triangle.turn.up.right.diamond.fill") { openURL(maps) }
                }
            }
        }
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
                    Text(dayTitle)
                        .font(.system(size: 32, weight: .bold))
                    if let title = store.dinnerTitle(on: day) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tonight’s pick")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.blue)
                                Text(title)
                                    .font(.title3.weight(.bold))
                            }
                            Spacer()
                            Button("Clear") { store.clearDinner(on: day) }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.chore)
                        }
                        .padding(16)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppTheme.blue, lineWidth: 3)
                        )
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                        choice("takeoutbag.and.cup.and.straw.fill", "Eat out", "Restaurants near you") { path.append(.eatOut) }
                        choice("book.closed.fill", "Family recipes", "Yours, typed or saved") { path.append(.family) }
                        choice("fork.knife.circle.fill", "Recipes", "Huge cookbook") { path.append(.recipes) }
                        choice("square.and.pencil", "Enter a meal", "Type it yourself") { path.append(.manual) }
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
                case .eatOut: EatOutPicker(day: day) { dismiss() }
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

    private func choice(_ symbol: String, _ title: String, _ detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160, alignment: .topLeading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private enum MealPath: Hashable {
    case eatOut, family, recipes, manual
}

private struct EatOutPicker: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var places = PlacesSearch()
    let day: Date
    var onDone: () -> Void
    @State private var areaQuery = ""
    @State private var opened: NearbyPlace?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Eat out")
                    .font(.system(size: 28, weight: .bold))
                Text("Near \(places.areaName). Tap a place for the menu and details.")
                    .foregroundStyle(AppTheme.textSecondary)
                HStack(spacing: 8) {
                    Button {
                        areaQuery = ""
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
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textTertiary)
                        TextField("City or zip", text: $areaQuery)
                            .textFieldStyle(.plain)
                            .onSubmit { Task { await places.searchArea(areaQuery) } }
                    }
                    .padding(10)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if places.isLoading { ProgressView() }
                if let message = places.message {
                    Text(message).foregroundStyle(AppTheme.textSecondary)
                }
                ForEach(places.places) { place in
                    Button { opened = place } label: {
                        HStack(spacing: 14) {
                            PlacePhoto(coordinate: place.coordinate)
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
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $opened) { place in
            PlaceInfoView(place: place, day: day, onDone: onDone)
        }
        .task { await places.useHere() }
    }
}

private struct FamilyRecipePicker: View {
    @EnvironmentObject private var store: HubStore
    let day: Date
    var onDone: () -> Void
    @State private var showAdd = false
    @State private var opened: Recipe?

    private var familyRecipes: [Recipe] {
        store.recipes.filter { $0.kind == .family || $0.kind == .cooked || $0.catalogID.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Family recipes")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                    Button { showAdd = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Text("Your household recipes. Add one by typing it in.")
                    .foregroundStyle(AppTheme.textSecondary)
                if familyRecipes.isEmpty {
                    Text("No family recipes yet.")
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
                    RecipePhoto(url: url)
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
                Text("Recipes")
                    .font(.system(size: 28, weight: .bold))
                Text("Tap a recipe to see the photo, ingredients, and steps.")
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textTertiary)
                    TextField("Chicken, tacos, pasta…", text: $catalog.query)
                        .textFieldStyle(.plain)
                        .onSubmit { Task { await catalog.search() } }
                    if catalog.isLoading { ProgressView() }
                }
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                if let message = catalog.message {
                    Text(message).foregroundStyle(AppTheme.textSecondary)
                }
                ForEach(catalog.recipes) { recipe in
                    Button {
                        Task { opened = await catalog.detail(id: recipe.id) ?? recipe }
                    } label: {
                        HStack(spacing: 14) {
                            RecipePhoto(url: recipe.thumb)
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
                RecipePhoto(url: recipe.thumb)
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

final class RecipeImageCache {
    static let shared = RecipeImageCache()
    private var map: [URL: UIImage] = [:]
    func image(for url: URL) -> UIImage? { map[url] }
    func set(_ image: UIImage, for url: URL) { map[url] = image }
}

struct RecipePhoto: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            AppTheme.blueSoft
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else if url != nil {
                ProgressView()
            } else {
                Image(systemName: "fork.knife").foregroundStyle(AppTheme.blue)
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else { return }
        if let cached = RecipeImageCache.shared.image(for: url) {
            image = cached
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let loaded = UIImage(data: data) else { return }
        RecipeImageCache.shared.set(loaded, for: url)
        image = loaded
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
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PlacePhoto(coordinate: place.coordinate)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Map(initialPosition: .region(MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 600, longitudinalMeters: 600))) {
                    Marker(place.name, coordinate: place.coordinate)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text(place.name)
                    .font(.system(size: 32, weight: .bold))
                Text(place.mode.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                VStack(spacing: 0) {
                    if !place.address.isEmpty { row("mappin.and.ellipse", place.address) }
                    if let distance = place.distanceLabel { row("location", distance) }
                    if !place.phone.isEmpty { row("phone.fill", place.phone) }
                    if let url = place.url { row("safari", url.host ?? "Website") }
                }
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                HStack(spacing: 10) {
                    if !place.phone.isEmpty, let tel = URL(string: "tel:\(place.phone.filter(\.isNumber))") {
                        pill("Call", "phone.fill") { openURL(tel) }
                    }
                    if let url = place.url {
                        pill(place.mode == .takeout ? "Menu / order" : "Menu", "menucard") { openURL(url) }
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
                        kind: place.mode.rawValue,
                        latitude: place.coordinate.latitude,
                        longitude: place.coordinate.longitude
                    )
                    onDone()
                } label: {
                    Text("Set as dinner")
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

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(AppTheme.blue).frame(width: 24)
            Text(text)
            Spacer()
        }
        .padding(16)
    }

    private func pill(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.blue, in: Capsule())
        }
        .buttonStyle(.plain)
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
                Text("Enter a meal")
                    .font(.system(size: 28, weight: .bold))
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
