import XCTest
@testable import FamilyHub

final class DietFilterTests: XCTestCase {
    func testVeganRejectsDairyAndMeat() {
        let pasta = recipe("Pasta", ingredients: ["200g pasta", "tomato", "basil"])
        let cheese = recipe("Alfredo", ingredients: ["pasta", "cream", "parmesan cheese"])
        let beef = recipe("Steak", ingredients: ["beef steak", "salt"])
        XCTAssertTrue(DietMatch.allows(pasta, flags: [.vegan]))
        XCTAssertFalse(DietMatch.allows(cheese, flags: [.vegan]))
        XCTAssertFalse(DietMatch.allows(beef, flags: [.vegan]))
    }

    func testMultiSelectRequiresEveryFlag() {
        let stew = recipe("Stew", ingredients: ["chicken", "potato", "salt"])
        XCTAssertFalse(DietMatch.allows(stew, flags: [.glutenFree, .nutFree, .lowCarb]))
        let salad = recipe("Salad", ingredients: ["lettuce", "tomato", "olive oil"])
        XCTAssertTrue(DietMatch.allows(salad, flags: [.glutenFree, .nutFree, .dairyFree, .vegan]))
    }

    func testEmptyIngredientsDoNotPassARestriction() {
        let bare = recipe("Mystery", ingredients: [])
        XCTAssertFalse(DietMatch.allows(bare, flags: [.nutFree]))
        XCTAssertTrue(DietMatch.allows(bare, flags: []))
    }

    func testHalalRejectsPork() {
        let bacon = recipe("Bacon", ingredients: ["bacon", "egg"])
        XCTAssertFalse(DietMatch.allows(bacon, flags: [.halal]))
    }

    private func recipe(_ name: String, ingredients: [String]) -> CatalogRecipe {
        CatalogRecipe(
            id: name,
            name: name,
            category: "Test",
            area: "American",
            thumb: nil,
            instructions: "",
            ingredients: ingredients,
            sourceURL: nil,
            youtubeURL: nil
        )
    }
}
