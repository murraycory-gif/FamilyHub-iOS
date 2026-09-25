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
    /// Public base of our recipe pack. Set Info.plist `HUBCatalogBaseURL` when the bucket is public. Empty uses the bundled seed only.
    static var r2CatalogBase: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "HUBCatalogBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.isEmpty == false else { return nil }
        return URL(string: raw)
    }
    static let packPath = "recipe-pack.json"

    static func make() -> any RecipeProviding {
        HubCatalogProvider()
    }
}

struct HubCatalogProvider: RecipeProviding {
    let id = "hub"
    let displayName = "HUB"

    func trending() async throws -> [CatalogRecipe] {
        let pack = try await catalog()
        return pack.filter { $0.trendingRank != nil }.sorted { ($0.trendingRank ?? 999) < ($1.trendingRank ?? 999) }
    }

    func searchDish(_ query: String) async throws -> [CatalogRecipe] {
        try await match(query) { recipe, needle in
            recipe.name.lowercased().contains(needle)
        }
    }

    func searchIngredient(_ query: String) async throws -> [CatalogRecipe] {
        try await match(query) { recipe, needle in
            recipe.ingredients.joined(separator: " ").lowercased().contains(needle)
        }
    }

    func searchCuisine(_ query: String) async throws -> [CatalogRecipe] {
        try await match(query) { recipe, needle in
            recipe.area.lowercased().contains(needle) || recipe.category.lowercased().contains(needle)
        }
    }

    func lookup(id: String) async throws -> CatalogRecipe? {
        try await catalog().first { $0.id == id }
    }

    private func match(_ query: String, _ test: (CatalogRecipe, String) -> Bool) async throws -> [CatalogRecipe] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return try await catalog().filter { test($0, needle) }
    }

    private func catalog() async throws -> [CatalogRecipe] {
        var byID: [String: CatalogRecipe] = [:]
        for recipe in RecipePackStore.seed().recipes.map({ $0.asCatalogRecipe() }) {
            byID[recipe.id] = recipe
        }
        if let cached = RecipePackStore.cached() {
            for recipe in cached.recipes.map({ $0.asCatalogRecipe() }) {
                byID[recipe.id] = recipe
            }
        }
        if let remote = try? await RecipePackStore.refresh() {
            for recipe in remote.recipes.map({ $0.asCatalogRecipe() }) {
                byID[recipe.id] = recipe
            }
        }
        return Array(byID.values)
    }
}

enum RecipePackStore {
    static func seed() -> RecipePack {
        guard let url = Bundle.main.url(forResource: "SeedRecipes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let pack = try? JSONDecoder().decode(RecipePack.self, from: data),
              pack.validate().isEmpty
        else { return RecipePack(version: 1, recipes: []) }
        return pack
    }

    static func cached() -> RecipePack? {
        guard let url = cacheFile, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RecipePack.self, from: data)
    }

    static func refresh() async throws -> RecipePack? {
        guard let base = RecipeSources.r2CatalogBase else { return nil }
        guard let url = URL(string: RecipeSources.packPath, relativeTo: base)?.absoluteURL else { return nil }
        let request = URLRequest(url: url, timeoutInterval: 12)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw RecipeProviderError.offline
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw RecipeProviderError.unavailable
        }
        let pack = try JSONDecoder().decode(RecipePack.self, from: data)
        let problems = pack.validate()
        if problems.isEmpty == false { throw RecipeProviderError.unavailable }
        if let file = cacheFile { try? data.write(to: file, options: .atomic) }
        return pack
    }

    private static var cacheFile: URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("RecipePackV1", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("recipe-pack.json")
    }
}
