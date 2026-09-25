import Foundation

enum RecipeSearchKind: String, CaseIterable, Identifiable {
    case dish
    case ingredient
    case cuisine
    case diet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dish: return "Dish"
        case .ingredient: return "Ingredient"
        case .cuisine: return "Cuisine"
        case .diet: return "Diet"
        }
    }

    var placeholder: String {
        switch self {
        case .dish: return "Search a dish…"
        case .ingredient: return "Search an ingredient…"
        case .cuisine: return "Search a cuisine…"
        case .diet: return "Diets apply from the chips below"
        }
    }
}

enum RecipeProviderError: Error {
    case offline
    case quota
    case unavailable
}

protocol RecipeProviding: Sendable {
    var id: String { get }
    var displayName: String { get }
    func trending() async throws -> [CatalogRecipe]
    func searchDish(_ query: String) async throws -> [CatalogRecipe]
    func searchIngredient(_ query: String) async throws -> [CatalogRecipe]
    func searchCuisine(_ query: String) async throws -> [CatalogRecipe]
    func lookup(id: String) async throws -> CatalogRecipe?
}

enum RecipeSources {
    /// Swap this when the owner's provider choice lands. Callers only see `RecipeProviding`.
    static func make() -> any RecipeProviding {
        MealDBRecipeProvider()
    }
}

struct MealDBRecipeProvider: RecipeProviding {
    let id = "themealdb"
    let displayName = "TheMealDB"

    func trending() async throws -> [CatalogRecipe] {
        if let cached = RecipeProviderCache.load(key: "trending"), cached.fresh {
            return cached.recipes
        }
        do {
            var seen = Set<String>()
            var result: [CatalogRecipe] = []
            for _ in 0..<8 {
                if let meal = try await MealDB.random(), seen.insert(meal.id).inserted {
                    result.append(tagged(meal))
                }
            }
            RecipeProviderCache.save(result, key: "trending")
            return result
        } catch {
            if let cached = RecipeProviderCache.load(key: "trending") { return cached.recipes }
            throw error
        }
    }

    func searchDish(_ query: String) async throws -> [CatalogRecipe] {
        try await cached("dish-\(query.lowercased())") { try await MealDB.search(query).map(tagged) }
    }

    func searchIngredient(_ query: String) async throws -> [CatalogRecipe] {
        try await cached("ingredient-\(query.lowercased())") {
            let listed = try await MealDB.filterIngredient(query)
            var full: [CatalogRecipe] = []
            for item in listed.prefix(12) {
                if let detail = try await MealDB.lookup(item.id) {
                    full.append(tagged(detail))
                } else {
                    full.append(tagged(item))
                }
            }
            return full
        }
    }

    func searchCuisine(_ query: String) async throws -> [CatalogRecipe] {
        try await cached("cuisine-\(query.lowercased())") {
            try await MealDB.filter(area: query).map(tagged)
        }
    }

    func lookup(id: String) async throws -> CatalogRecipe? {
        let key = "id-\(id)"
        if let cached = RecipeProviderCache.load(key: key)?.recipes.first { return cached }
        let found = try await MealDB.lookup(id).map(tagged)
        if let found { RecipeProviderCache.save([found], key: key) }
        return found
    }

    private func tagged(_ recipe: CatalogRecipe) -> CatalogRecipe {
        var copy = recipe
        if copy.sourceName.isEmpty { copy.sourceName = displayName }
        return copy
    }

    private func cached(_ key: String, load: () async throws -> [CatalogRecipe]) async throws -> [CatalogRecipe] {
        if let hit = RecipeProviderCache.load(key: key), hit.fresh { return hit.recipes }
        do {
            let batch = try await load()
            RecipeProviderCache.save(batch, key: key)
            return batch
        } catch {
            if let hit = RecipeProviderCache.load(key: key) { return hit.recipes }
            throw error
        }
    }
}

enum RecipeProviderCache {
    struct Entry: Codable {
        var savedAt: Date
        var recipes: [CatalogRecipe]
        var fresh: Bool {
            Date().timeIntervalSince(savedAt) < 60 * 60 * 12
        }
    }

    static func load(key: String) -> Entry? {
        guard let url = file(key), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    static func save(_ recipes: [CatalogRecipe], key: String) {
        guard let url = file(key) else { return }
        let entry = Entry(savedAt: Date(), recipes: recipes)
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func file(_ key: String) -> URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("RecipeProviderV1", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var hash: UInt64 = 5381
        for byte in key.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
        return folder.appendingPathComponent(String(hash, radix: 16) + ".json")
    }
}
