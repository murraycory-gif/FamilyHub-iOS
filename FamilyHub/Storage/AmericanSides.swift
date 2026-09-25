import Foundation

enum AmericanSides {
    static let recipes: [CatalogRecipe] = raw.enumerated().map { index, item in
        CatalogRecipe(
            id: "side-\(index + 1)",
            name: item.0,
            category: item.1,
            area: "American",
            thumb: URL(string: item.2),
            instructions: item.4,
            ingredients: item.3,
            sourceURL: nil,
            youtubeURL: nil
        )
    } + WorldSides.recipes

    static let categories = ["All", "Easy", "Quick", "Potato", "Veg", "Salad", "Bread", "BBQ", "Classic", "World"]

    private static let raw: [(String, String, String, [String], String)] = [
        ("Mashed Potatoes", "Potato", "", ["3 lb russet potatoes", "1 stick butter", "1 cup warm milk", "Salt and pepper"], "Boil potatoes until tender. Drain. Mash with butter and milk. Salt and pepper."),
        ("Garlic Mashed Potatoes", "Potato", "", ["3 lb potatoes", "6 garlic cloves", "Butter", "Cream", "Salt"], "Boil potatoes with garlic. Mash with butter and cream."),
        ("Loaded Baked Potatoes", "Potato", "", ["4 russets", "Butter", "Sour cream", "Cheddar", "Bacon", "Chives"], "Bake 425°F 50 minutes. Split, load toppings."),
        ("Roasted Potatoes", "Potato", "", ["2 lb baby potatoes", "Olive oil", "Rosemary", "Salt"], "Toss with oil and rosemary. Roast 425°F 35 minutes."),
        ("French Fries", "Potato", "", ["4 russets", "Oil", "Salt"], "Cut fries. Soak, dry. Fry 325°F then 375°F. Salt."),
        ("Sweet Potato Fries", "Potato", "", ["3 sweet potatoes", "Oil", "Salt", "Paprika"], "Cut, toss oil and spice. 425°F 25 minutes, flip once."),
        ("Scalloped Potatoes", "Potato", "", ["3 lb potatoes, sliced", "2 cups cream", "Garlic", "Gruyere"], "Layer potatoes, cream, cheese. Bake 350°F 1 hour."),
        ("Potato Salad", "Potato", "", ["3 lb potatoes", "Mayo", "Mustard", "Celery", "Eggs", "Pickle relish"], "Boil potatoes. Mix mayo dressing. Fold in eggs and celery. Chill."),
        ("Macaroni and Cheese", "Classic", "", ["1 lb elbows", "4 cups cheddar", "Butter", "Milk", "Flour"], "Roux, milk, cheese. Mix pasta. Bake 20 minutes if you want a crust."),
        ("Baked Beans", "BBQ", "", ["2 cans navy beans", "Bacon", "Brown sugar", "Molasses", "Mustard", "Onion"], "Cook bacon and onion. Stir in rest. Bake 350°F 45 minutes."),
        ("Coleslaw", "Salad", "", ["1 bag coleslaw mix", "Mayo", "Vinegar", "Sugar", "Celery seed"], "Whisk dressing. Toss cabbage. Chill 30 minutes."),
        ("Corn on the Cob", "Veg", "", ["6 ears corn", "Butter", "Salt"], "Boil 6 minutes or grill in husk 15. Butter and salt."),
        ("Creamed Corn", "Veg", "", ["4 cups corn", "Butter", "Cream", "Sugar", "Salt"], "Simmer corn with cream and butter 10 minutes."),
        ("Green Bean Casserole", "Classic", "", ["Green beans", "Cream of mushroom", "Fried onions"], "Mix beans and soup. Bake 25 minutes. Top onions 5 more."),
        ("Roasted Broccoli", "Veg", "", ["2 heads broccoli", "Olive oil", "Garlic", "Lemon", "Salt"], "425°F 20 minutes. Lemon at the end."),
        ("Roasted Carrots", "Veg", "", ["2 lb carrots", "Olive oil", "Honey", "Thyme"], "Toss, roast 400°F 25 minutes."),
        ("Asparagus", "Veg", "", ["2 bunches asparagus", "Olive oil", "Salt", "Lemon"], "Roast 425°F 12 minutes."),
        ("Sauteed Green Beans", "Veg", "", ["1.5 lb green beans", "Garlic", "Butter", "Almonds"], "Blanch, then sauté garlic and butter. Almonds."),
        ("Cornbread", "Bread", "", ["1 cup cornmeal", "1 cup flour", "1 cup buttermilk", "Egg", "Butter", "Sugar"], "Mix, pour 8-inch pan. 400°F 20 minutes."),
        ("Garlic Bread", "Bread", "", ["French loaf", "Butter", "Garlic", "Parsley"], "Spread, 400°F 10 minutes."),
        ("Dinner Rolls", "Bread", "", ["Yeast dough", "Butter"], "Bake 375°F 15 minutes. Brush butter."),
        ("Biscuits", "Bread", "", ["2 cups flour", "1 tbsp baking powder", "Stick butter", "3/4 cup buttermilk"], "Cut in butter, add buttermilk. 425°F 12 minutes."),
        ("House Salad", "Salad", "", ["Lettuce", "Tomato", "Cucumber", "Croutons", "Ranch or vinaigrette"], "Toss greens and veg. Dress at the table."),
        ("Caesar Salad", "Salad", "", ["Romaine", "Parmesan", "Croutons", "Caesar dressing"], "Toss romaine, cheese, croutons, dressing."),
        ("Wedge Salad", "Salad", "", ["Iceberg", "Blue cheese", "Bacon", "Tomato"], "Quarter lettuce. Dressing, bacon, tomato."),
        ("Macaroni Salad", "Salad", "", ["Elbows", "Mayo", "Celery", "Egg", "Pickle"], "Cook pasta. Fold dressing. Chill."),
        ("Fruit Salad", "Salad", "", ["Berries", "Melon", "Grapes", "Honey", "Mint"], "Toss fruit with honey and mint."),
        ("Onion Rings", "Classic", "", ["2 large onions", "Buttermilk", "Flour", "Oil"], "Soak, dredge, fry 350°F gold."),
        ("Tater Tots", "Potato", "", ["Bag of tots", "Salt"], "Bake per bag, extra crisp 5 minutes."),
        ("Rice Pilaf", "Classic", "", ["2 cups rice", "Onion", "Butter", "4 cups broth"], "Toast rice in butter. Add broth. Cover 18 minutes."),
        ("White Rice", "Classic", "", ["2 cups rice", "Water", "Salt"], "Rinse. 1:2 rice to water. Simmer 15. Rest 5."),
        ("Stuffing", "Classic", "", ["Bread cubes", "Celery", "Onion", "Broth", "Sage"], "Sauté veg. Mix bread and broth. Bake 350°F 30 minutes."),
        ("Cranberry Sauce", "Classic", "", ["12 oz cranberries", "1 cup sugar", "1 cup water", "Orange zest"], "Simmer 10 minutes until berries pop. Chill."),
        ("Applesauce", "Classic", "", ["6 apples", "Sugar", "Cinnamon", "Water"], "Simmer apples 20 minutes. Mash."),
        ("Gravy", "Classic", "", ["Pan drippings", "Flour", "Stock", "Salt"], "Roux with drippings. Whisk stock. Simmer 5."),
        ("Collard Greens", "Veg", "", ["2 bunches collards", "Ham hock or bacon", "Onion", "Vinegar"], "Simmer with smoked meat 45 minutes."),
        ("Fried Okra", "Veg", "", ["1 lb okra", "Cornmeal", "Oil", "Salt"], "Slice, dredge cornmeal, fry 350°F."),
        ("Hush Puppies", "Bread", "", ["Cornmeal", "Flour", "Buttermilk", "Onion", "Oil"], "Mix batter. Drop in 350°F oil until gold."),
        ("Deviled Eggs", "Classic", "", ["12 eggs", "Mayo", "Mustard", "Paprika"], "Boil, mash yolks with mayo and mustard. Pipe, paprika."),
        ("Pickles", "Classic", "", ["Jar dill pickles"], "Serve cold with the plate."),
        ("Baked Macaroni", "Classic", "", ["Elbows", "Cheddar", "Breadcrumbs", "Butter"], "Cheese sauce, pasta, breadcrumb top. 375°F 25 minutes."),
        ("Creamed Spinach", "Veg", "", ["2 lb spinach", "Cream", "Garlic", "Nutmeg"], "Wilt spinach. Cream and garlic. Simmer thick."),
        ("Brussels Sprouts", "Veg", "", ["2 lb sprouts", "Oil", "Bacon", "Balsamic"], "Halve, roast 425°F 25 minutes. Bacon and splash balsamic."),
        ("Cucumber Salad", "Salad", "", ["Cucumbers", "Onion", "Vinegar", "Sugar", "Dill"], "Slice, salt, dress vinegar. Chill."),
        ("Three Bean Salad", "Salad", "", ["Green, kidney, garbanzo", "Onion", "Vinaigrette"], "Drain beans. Toss dressing. Chill."),
        ("Corn Salad", "Salad", "", ["Corn", "Tomato", "Cilantro", "Lime", "Feta"], "Char corn. Toss with tomato, lime, feta."),
        ("Texas Toast", "Bread", "", ["Thick bread", "Garlic butter"], "Broil 2 minutes a side."),
        ("Cheddar Biscuits", "Bread", "", ["Biscuit dough", "Cheddar", "Garlic butter"], "Fold cheese. Bake. Brush garlic butter."),
        ("Slaw Mix", "BBQ", "", ["Cabbage", "Carrot", "Vinegar slaw dressing"], "Toss and chill. Bright with BBQ."),
        ("Potato Wedges", "Potato", "", ["Russets", "Oil", "Paprika", "Salt"], "Wedges, 425°F 35 minutes."),
        ("Elote", "Veg", "", ["Corn", "Mayo", "Cotija", "Chili", "Lime"], "Grill corn. Mayo, cheese, chili, lime."),
        ("Refried Beans", "Classic", "", ["Pinto beans", "Onion", "Lard or oil", "Salt"], "Mash beans in skillet with onion."),
        ("Spanish Rice", "Classic", "", ["Rice", "Tomato sauce", "Onion", "Cumin"], "Toast rice. Sauce and water. Simmer 18."),
        ("Cobb Salad", "Salad", "", ["Lettuce", "Egg", "Bacon", "Avocado", "Tomato", "Blue cheese"], "Row toppings on greens. Dressing on the side.")
    ]
}

@MainActor
final class SideCatalog: ObservableObject {
    @Published var recipes: [CatalogRecipe] = AmericanSides.recipes
    @Published var categories = AmericanSides.categories
    @Published var category = "All"
    @Published var query = ""

    func load() async {
        applyFilter()
    }

    func search() async {
        applyFilter()
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return }
        recipes = AmericanSides.recipes.filter {
            $0.name.lowercased().contains(needle) || $0.category.lowercased().contains(needle)
        }
    }

    private func applyFilter() {
        switch category {
        case "All":
            recipes = AmericanSides.recipes
        case "Easy", "Quick":
            recipes = AmericanSides.recipes.filter {
                MealEase.tags(name: $0.name, category: $0.category).contains(category)
            }
        case "World":
            recipes = AmericanSides.recipes.filter { $0.area != "American" || $0.category == "World" }
        default:
            recipes = AmericanSides.recipes.filter { $0.category == category }
        }
    }
}
