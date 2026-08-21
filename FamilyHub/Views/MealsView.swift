import MapKit
import SwiftUI

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
        .sheet(item: pickDayBinding) { day in
            MealChoiceSheet(day: day.date)
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
        return VStack(alignment: .leading, spacing: 8) {
            Text(dayLabel(day))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.blue)
                .textCase(.uppercase)
            Text(title ?? "Nothing planned")
                .font(.title3.weight(.bold))
                .foregroundStyle(title == nil ? AppTheme.textSecondary : AppTheme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(kindLabel(plan))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
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

private struct MealChoiceSheet: View {
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
        .presentationDetents([.large])
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Eat out")
                    .font(.system(size: 28, weight: .bold))
                Text("Takeout and sit-down near you.")
                    .foregroundStyle(AppTheme.textSecondary)
                if places.isLoading { ProgressView() }
                if let message = places.message {
                    Text(message).foregroundStyle(AppTheme.textSecondary)
                }
                ForEach(places.places) { place in
                    Button {
                        store.setDinnerPlace(
                            on: day,
                            name: place.name,
                            address: place.address,
                            phone: place.phone,
                            url: place.url?.absoluteString ?? "",
                            kind: place.mode.rawValue
                        )
                        onDone()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: place.mode == .takeout ? "takeoutbag.and.cup.and.straw.fill" : "fork.knife")
                                .font(.title2)
                                .foregroundStyle(AppTheme.blue)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                Text(place.mode.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.blue)
                                if !place.address.isEmpty {
                                    Text(place.address)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
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
        .task { await places.loadAll() }
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
                Text("Tap a recipe to see ingredients and steps.")
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
                        Task {
                            opened = await catalog.detail(id: recipe.id) ?? recipe
                        }
                    } label: {
                        HStack(spacing: 14) {
                            RecipePhoto(url: recipe.thumb)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
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
                    .frame(height: 260)
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
                                Text(line).font(.body)
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
                        .font(.body)
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

private struct RecipePhoto: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                ZStack {
                    AppTheme.blueSoft
                    Image(systemName: "fork.knife").foregroundStyle(AppTheme.blue)
                }
            default:
                ZStack {
                    AppTheme.blueSoft
                    ProgressView()
                }
            }
        }
    }
}
    @EnvironmentObject private var store: HubStore
    @StateObject private var catalog = RecipeCatalog()
    let day: Date
    var onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recipes")
                    .font(.system(size: 28, weight: .bold))
                Text("Search a big cookbook. Tap one to set dinner.")
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
                        if let existing = store.recipes.first(where: { $0.catalogID == recipe.id && !recipe.id.isEmpty }) {
                            store.setDinner(on: day, recipeID: existing.id)
                        } else {
                            let saved = recipe.asHubRecipe()
                            store.addRecipe(saved)
                            store.setDinner(on: day, recipeID: saved.id)
                        }
                        onDone()
                    } label: {
                        HStack(spacing: 14) {
                            AsyncImage(url: recipe.thumb) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                AppTheme.blueSoft
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
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
        .task { await catalog.load() }
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
