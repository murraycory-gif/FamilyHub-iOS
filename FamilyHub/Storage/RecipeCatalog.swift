import Foundation

struct CatalogRecipe: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var category: String
    var area: String
    var thumb: URL?
    var instructions: String
    var ingredients: [String]
    var sourceURL: URL?
    var youtubeURL: URL?
    var sourceName: String = ""
    var dietTags: [DietFlag] = []
    var trendingRank: Int? = nil

    func asHubRecipe(kind: RecipeKind = .recipe) -> Recipe {
        Recipe.make(
            name: name,
            kind: kind,
            notes: [category, area].filter { !$0.isEmpty }.joined(separator: " · "),
            ingredients: ingredients,
            instructions: instructions,
            imageURL: thumb?.absoluteString ?? "",
            catalogID: id
        )
    }
}

@MainActor
final class RecipeCatalog: ObservableObject {
    @Published var recipes: [CatalogRecipe] = []
    @Published var trending: [CatalogRecipe] = []
    @Published var searchKind: RecipeSearchKind = .dish
    @Published var diets: Set<DietFlag> = []
    private let provider: any RecipeProviding = RecipeSources.make()
    var sourceTitle: String { provider.displayName }
    @Published var categories: [String] = [
        "All", "Easy", "Quick", "American", "World", "BBQ", "Southern", "Tex-Mex",
        "Italian", "Mexican", "Asian", "Mediterranean", "Diner", "Comfort", "Weeknight", "Holiday"
    ]
    @Published var query = ""
    @Published var category = "American"
    @Published var isLoading = false
    @Published var message: String?

    func load() async {
        applyFilter()
        await loadTrending()
    }

    func loadTrending() async {
        do {
            trending = try await provider.trending()
        } catch let error as RecipeProviderError {
            trending = []
            message = note(for: error)
        } catch {
            message = note(for: .offline)
        }
    }

    func loadMore() async {}

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if searchKind == .diet || trimmed.isEmpty {
            applyFilter()
            if searchKind == .diet {
                recipes = (trending + recipes).filter { DietMatch.allows($0, flags: diets) }
                recipes = uniqued(recipes)
            }
            if recipes.isEmpty { message = diets.isEmpty ? "No recipes in that category yet." : "No recipes match these diets." }
            return
        }
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let remote: [CatalogRecipe]
            switch searchKind {
            case .dish: remote = try await provider.searchDish(trimmed)
            case .ingredient: remote = try await provider.searchIngredient(trimmed)
            case .cuisine: remote = try await provider.searchCuisine(trimmed)
            case .diet: remote = []
            }
            let needle = trimmed.lowercased()
            var merged = remote
            for item in localRecipes where matches(item, needle) {
                merged.append(item)
            }
            recipes = uniqued(merged).filter { DietMatch.allows($0, flags: diets) }
            if recipes.isEmpty { message = "No recipes for that search." }
        } catch let error as RecipeProviderError {
            let needle = trimmed.lowercased()
            recipes = localRecipes.filter { matches($0, needle) && DietMatch.allows($0, flags: diets) }
            message = recipes.isEmpty ? note(for: error) : "\(note(for: error)) Showing saved recipes."
        } catch {
            message = note(for: .offline)
        }
    }

    private func note(for error: RecipeProviderError) -> String {
        switch error {
        case .offline: return "Can't reach \(provider.displayName). Check the connection."
        case .quota: return "\(provider.displayName) is at its free limit. Try again later."
        case .unavailable: return "\(provider.displayName) didn't answer."
        }
    }

    func detail(id: String) async -> CatalogRecipe? {
        if let local = localRecipes.first(where: { $0.id == id }) {
            return local
        }
        if let existing = recipes.first(where: { $0.id == id }), !existing.instructions.isEmpty {
            return existing
        }
        return try? await provider.lookup(id: id)
    }

    private var localRecipes: [CatalogRecipe] { AmericanKitchen.recipes + WorldKitchen.recipes }

    private func applyFilter() {
        message = nil
        let local = localRecipes
        switch category {
        case "All":
            recipes = local
        case "American":
            recipes = local.filter { $0.area == "American" }
        case "World":
            recipes = local.filter { $0.area != "American" }
        case "Easy":
            recipes = local.filter { MealEase.tags(name: $0.name, category: $0.category).contains("Easy") }
        case "Quick":
            recipes = local.filter { MealEase.tags(name: $0.name, category: $0.category).contains("Quick") }
        case "Asian":
            recipes = local.filter { Self.asian.contains($0.category) || Self.asian.contains($0.area) }
        case "Mediterranean":
            recipes = local.filter { Self.med.contains($0.category) || Self.med.contains($0.area) }
        default:
            recipes = local.filter { $0.category == category || $0.area == category }
        }
        recipes = uniqued(recipes)
        if recipes.isEmpty { message = "No recipes in that category yet." }
    }

    private func uniqued(_ items: [CatalogRecipe]) -> [CatalogRecipe] {
        var seen = Set<String>()
        return items.filter { item in
            let key = item.id.isEmpty ? item.name.lowercased() : item.id
            return seen.insert(key).inserted
        }
    }

    private static let asian = ["Chinese", "Japanese", "Thai", "Indian", "Korean", "Vietnamese", "Filipino"]
    private static let med = ["Greek", "French", "Spanish", "Moroccan", "Mediterranean"]

    private func matches(_ item: CatalogRecipe, _ needle: String) -> Bool {
        item.name.lowercased().contains(needle)
            || item.category.lowercased().contains(needle)
            || item.area.lowercased().contains(needle)
            || item.ingredients.joined(separator: " ").lowercased().contains(needle)
    }
}
