import Foundation

struct CatalogRecipe: Identifiable, Hashable {
    var id: String
    var name: String
    var category: String
    var area: String
    var thumb: URL?
    var instructions: String
    var ingredients: [String]
    var sourceURL: URL?
    var youtubeURL: URL?

    func asHubRecipe() -> Recipe {
        Recipe.make(
            name: name,
            kind: .recipe,
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
    @Published var categories: [String] = []
    @Published var query = ""
    @Published var category = "All"
    @Published var isLoading = false
    @Published var message: String?

    func load() async {
        if categories.isEmpty {
            categories = ["All"] + ((try? await MealDB.categories()) ?? [])
        }
        isLoading = true
        message = nil
        do {
            recipes = try await MealDB.letters("abc")
            if recipes.isEmpty { message = "No recipes right now." }
        } catch {
            message = "Could not load recipes right now."
        }
        isLoading = false
        Task { await loadMore() }
    }

    func loadMore() async {
        let have = Set(recipes.map(\.id))
        let extra = (try? await MealDB.letters("defghijklmnopqrstuvwxyz", excluding: have)) ?? []
        if !extra.isEmpty { recipes.append(contentsOf: extra) }
    }

    func search() async {
        isLoading = true
        message = nil
        defer { isLoading = false }
        do {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                recipes = try await MealDB.search(trimmed)
            } else if category != "All" {
                recipes = try await MealDB.filter(category: category)
            } else if recipes.isEmpty {
                recipes = try await MealDB.letters("abc")
            }
            if recipes.isEmpty { message = "No recipes for that search." }
        } catch {
            message = "Could not load recipes right now."
        }
    }

    func detail(id: String) async -> CatalogRecipe? {
        try? await MealDB.lookup(id)
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
        let short = try await get("filter.php?c=\(encoded)")
        var full: [CatalogRecipe] = []
        for item in short.prefix(16) {
            if let detail = try? await lookup(item.id) {
                full.append(detail)
            } else {
                full.append(item)
            }
        }
        return full
    }

    static func lookup(_ id: String) async throws -> CatalogRecipe? {
        try await get("lookup.php?i=\(id)").first
    }

    static func categories() async throws -> [String] {
        struct Wrap: Decodable { var categories: [Item]? }
        struct Item: Decodable { var strCategory: String }
        let url = URL(string: "\(root)/categories.php")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Wrap.self, from: data).categories?.map(\.strCategory) ?? []
    }

    private static func get(_ path: String) async throws -> [CatalogRecipe] {
        struct Wrap: Decodable { var meals: [Meal]? }
        let url = URL(string: "\(root)/\(path)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Wrap.self, from: data).meals?.compactMap(CatalogRecipe.init) ?? []
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
