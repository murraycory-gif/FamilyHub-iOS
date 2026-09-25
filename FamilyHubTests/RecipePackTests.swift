import XCTest
@testable import FamilyHub

final class RecipePackTests: XCTestCase {
    func testSeedPackIsValid() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("FamilyHub/Resources/SeedRecipes.json")
        let data = try Data(contentsOf: url)
        let pack = try JSONDecoder().decode(RecipePack.self, from: data)
        XCTAssertEqual(pack.validate(), [])
        XCTAssertEqual(pack.version, 1)
        XCTAssertGreaterThanOrEqual(pack.recipes.count, 3)
        XCTAssertTrue(pack.recipes.contains { $0.trendingRank == 1 })
        XCTAssertTrue(pack.recipes.allSatisfy { $0.imageURL.isEmpty || $0.imageURL.hasPrefix("https://") })
    }

    func testRejectsBadImageAndDuplicateID() throws {
        let raw = """
        {"version":1,"recipes":[
          {"id":"a","name":"A","category":"","cuisine":"","ingredients":[],"instructions":"","imageURL":"http://cdn.example/a.jpg","diets":[],"trendingRank":0,"sourceName":""},
          {"id":"a","name":"B","category":"","cuisine":"","ingredients":[],"instructions":"","imageURL":"","diets":[],"sourceName":"HUB"}
        ]}
        """
        let pack = try JSONDecoder().decode(RecipePack.self, from: Data(raw.utf8))
        let problems = pack.validate()
        XCTAssertTrue(problems.contains { $0.contains("https") })
        XCTAssertTrue(problems.contains { $0.contains("trendingRank") })
        XCTAssertTrue(problems.contains { $0.contains("sourceName") })
        XCTAssertTrue(problems.contains { $0.contains("duplicate") })
    }

    func testTaggedDietUsesPackTags() {
        let item = RecipePackItem(
            id: "beans",
            name: "Rice and beans",
            category: "Weeknight",
            cuisine: "American",
            ingredients: ["rice", "black beans"],
            instructions: "Simmer.",
            imageURL: "",
            diets: [.vegan, .nutFree],
            trendingRank: nil,
            sourceName: "HUB"
        )
        let recipe = item.asCatalogRecipe()
        XCTAssertTrue(DietMatch.allows(recipe, flags: [.vegan, .nutFree]))
        XCTAssertFalse(DietMatch.allows(recipe, flags: [.keto]))
    }
}
