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

    private func streamWorld() async {
        await streamAreas([
            "American", "Canadian", "Mexican", "British", "Italian", "Chinese", "Indian",
            "French", "Japanese", "Thai", "Greek", "Spanish", "Jamaican", "Moroccan",
            "Irish", "Vietnamese", "Turkish", "Polish", "Portuguese", "Filipino"
        ])
    }

    private func streamAreas(_ areas: [String]) async {
        await withTaskGroup(of: [CatalogRecipe].self) { group in
            for area in areas {
                group.addTask { (try? await MealDB.filter(area: area)) ?? [] }
            }
            var seen = Set(recipes.map(\.id))
            seen.formUnion(Set(localRecipes.map(\.id)))
            for await batch in group {
                let extra = batch.filter { seen.insert($0.id).inserted }
                if !extra.isEmpty {
                    recipes.append(contentsOf: extra)
                }
            }
        }
    }
}

enum MealDB {
    private static let root = "https://www.themealdb.com/api/json/v1/1"

    static func letters(_ alphabet: String, excluding: Set<String> = []) async throws -> [CatalogRecipe] {
        var seen = excluding
        var result: [CatalogRecipe] = []
        for letter in alphabet {
            let batch = (try? await get("search.php?f=\(letter)")) ?? []
            for meal in batch where seen.insert(meal.id).inserted {
                result.append(meal)
            }
        }
        return result
    }

    static func featured() async throws -> [CatalogRecipe] {
        try await letters("abcdefghijklmnopqrstuvwxyz")
    }

    static func search(_ query: String) async throws -> [CatalogRecipe] {
        try await get("search.php?s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
    }

    static func filter(category: String) async throws -> [CatalogRecipe] {
        let encoded = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category
        return try await get("filter.php?c=\(encoded)")
    }

    static func filter(area: String) async throws -> [CatalogRecipe] {
        let encoded = area.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? area
        return try await get("filter.php?a=\(encoded)").map { item in
            var copy = item
            if copy.area.isEmpty { copy.area = area }
            return copy
        }
    }

    static func lookup(_ id: String) async throws -> CatalogRecipe? {
        try await get("lookup.php?i=\(id)").first
    }

    static func random() async throws -> CatalogRecipe? {
        try await get("random.php").first
    }

    static func filterIngredient(_ name: String) async throws -> [CatalogRecipe] {
        let encoded = name.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return try await get("filter.php?i=\(encoded)")
    }

    static func categories() async throws -> [String] {
        struct Wrap: Decodable { var categories: [Item]? }
        struct Item: Decodable { var strCategory: String }
        guard let url = URL(string: "\(root)/categories.php") else { return [] }
        let data = try await HubHTTP.data(from: url)
        return try JSONDecoder().decode(Wrap.self, from: data).categories?.map(\.strCategory) ?? []
    }

    private static func get(_ path: String) async throws -> [CatalogRecipe] {
        struct Wrap: Decodable { var meals: [Meal]? }
        guard let url = URL(string: "\(root)/\(path)") else { return [] }
        var request = URLRequest(url: url, timeoutInterval: 12)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw RecipeProviderError.offline
        }
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 429 { throw RecipeProviderError.quota }
            if !(200...299).contains(http.statusCode) { throw RecipeProviderError.unavailable }
        }
        return (try? JSONDecoder().decode(Wrap.self, from: data).meals?.compactMap(CatalogRecipe.init)) ?? []
    }
}

private struct Meal: Decodable {
    var idMeal: String
    var strMeal: String
    var strCategory: String?
    var strArea: String?
    var strInstructions: String?
    var strMealThumb: String?
    var strSource: String?
    var strYoutube: String?
    var strIngredient1: String?; var strIngredient2: String?; var strIngredient3: String?
    var strIngredient4: String?; var strIngredient5: String?; var strIngredient6: String?
    var strIngredient7: String?; var strIngredient8: String?; var strIngredient9: String?
    var strIngredient10: String?; var strIngredient11: String?; var strIngredient12: String?
    var strIngredient13: String?; var strIngredient14: String?; var strIngredient15: String?
    var strIngredient16: String?; var strIngredient17: String?; var strIngredient18: String?
    var strIngredient19: String?; var strIngredient20: String?
    var strMeasure1: String?; var strMeasure2: String?; var strMeasure3: String?
    var strMeasure4: String?; var strMeasure5: String?; var strMeasure6: String?
    var strMeasure7: String?; var strMeasure8: String?; var strMeasure9: String?
    var strMeasure10: String?; var strMeasure11: String?; var strMeasure12: String?
    var strMeasure13: String?; var strMeasure14: String?; var strMeasure15: String?
    var strMeasure16: String?; var strMeasure17: String?; var strMeasure18: String?
    var strMeasure19: String?; var strMeasure20: String?
}

private extension CatalogRecipe {
    init?(_ meal: Meal) {
        id = meal.idMeal
        name = meal.strMeal
        category = meal.strCategory ?? ""
        area = meal.strArea ?? ""
        thumb = meal.strMealThumb.flatMap { raw in
            URL(string: raw.replacingOccurrences(of: "http://", with: "https://"))
        }
        instructions = meal.strInstructions ?? ""
        sourceURL = meal.strSource.flatMap(URL.init(string:))
        youtubeURL = meal.strYoutube.flatMap(URL.init(string:))
        sourceName = "TheMealDB"
        let pairs: [(String?, String?)] = [
            (meal.strIngredient1, meal.strMeasure1), (meal.strIngredient2, meal.strMeasure2),
            (meal.strIngredient3, meal.strMeasure3), (meal.strIngredient4, meal.strMeasure4),
            (meal.strIngredient5, meal.strMeasure5), (meal.strIngredient6, meal.strMeasure6),
            (meal.strIngredient7, meal.strMeasure7), (meal.strIngredient8, meal.strMeasure8),
            (meal.strIngredient9, meal.strMeasure9), (meal.strIngredient10, meal.strMeasure10),
            (meal.strIngredient11, meal.strMeasure11), (meal.strIngredient12, meal.strMeasure12),
            (meal.strIngredient13, meal.strMeasure13), (meal.strIngredient14, meal.strMeasure14),
            (meal.strIngredient15, meal.strMeasure15), (meal.strIngredient16, meal.strMeasure16),
            (meal.strIngredient17, meal.strMeasure17), (meal.strIngredient18, meal.strMeasure18),
            (meal.strIngredient19, meal.strMeasure19), (meal.strIngredient20, meal.strMeasure20),
        ]
        ingredients = pairs.compactMap { ingredient, measure in
            let name = ingredient?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return nil }
            let amount = measure?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return amount.isEmpty ? name : "\(amount) \(name)"
        }
    }
}
