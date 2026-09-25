import Foundation

struct RecipePack: Codable, Equatable {
    var version: Int
    var recipes: [RecipePackItem]

    func validate() -> [String] {
        var problems: [String] = []
        if version < 1 { problems.append("version must be 1 or newer") }
        var seen = Set<String>()
        for recipe in recipes {
            problems.append(contentsOf: recipe.validate().map { "\(recipe.id): \($0)" })
            if seen.insert(recipe.id).inserted == false {
                problems.append("\(recipe.id): duplicate id")
            }
        }
        return problems
    }
}

struct RecipePackItem: Codable, Equatable {
    var id: String
    var name: String
    var category: String
    var cuisine: String
    var ingredients: [String]
    var instructions: String
    var imageURL: String
    var diets: [DietFlag]
    var trendingRank: Int?
    var sourceName: String

    func validate() -> [String] {
        var problems: [String] = []
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { problems.append("id is empty") }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { problems.append("name is empty") }
        if sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { problems.append("sourceName is empty") }
        if let trendingRank, trendingRank < 1 { problems.append("trendingRank must be 1 or higher") }
        let image = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if image.isEmpty == false, image.hasPrefix("https://") == false {
            problems.append("imageURL must be an https URL on our catalog")
        }
        return problems
    }

    func asCatalogRecipe() -> CatalogRecipe {
        CatalogRecipe(
            id: id,
            name: name,
            category: category,
            area: cuisine,
            thumb: URL(string: imageURL),
            instructions: instructions,
            ingredients: ingredients,
            sourceURL: nil,
            youtubeURL: nil,
            sourceName: sourceName,
            dietTags: diets,
            trendingRank: trendingRank
        )
    }
}
