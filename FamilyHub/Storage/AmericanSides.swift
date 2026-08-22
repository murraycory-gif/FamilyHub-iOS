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
    }

    static let categories = ["All", "Potato", "Veg", "Salad", "Bread", "BBQ", "Classic"]

    private static let raw: [(String, String, String, [String], String)] = [
        ("Mashed Potatoes", "Potato", "https://images.unsplash.com/photo-1604908177522-04083420eb68?auto=format&fit=crop&w=800&q=80", ["3 lb russet potatoes", "1 stick butter", "1 cup warm milk", "Salt and pepper"], "Boil potatoes until tender. Drain. Mash with butter and milk. Salt and pepper."),
        ("Garlic Mashed Potatoes", "Potato", "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80", ["3 lb potatoes", "6 garlic cloves", "Butter", "Cream", "Salt"], "Boil potatoes with garlic. Mash with butter and cream."),
        ("Loaded Baked Potatoes", "Potato", "https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?auto=format&fit=crop&w=800&q=80", ["4 russets", "Butter", "Sour cream", "Cheddar", "Bacon", "Chives"], "Bake 425°F 50 minutes. Split, load toppings."),
        ("Roasted Potatoes", "Potato", "https://images.unsplash.com/photo-1518013431117-eb1465fa5752?auto=format&fit=crop&w=800&q=80", ["2 lb baby potatoes", "Olive oil", "Rosemary", "Salt"], "Toss with oil and rosemary. Roast 425°F 35 minutes."),
        ("French Fries", "Potato", "https://images.unsplash.com/photo-1541592106381-b31e9677c0e5?auto=format&fit=crop&w=800&q=80", ["4 russets", "Oil", "Salt"], "Cut fries. Soak, dry. Fry 325°F then 375°F. Salt."),
        ("Sweet Potato Fries", "Potato", "https://images.unsplash.com/photo-1596097635121-14b63b7a0c23?auto=format&fit=crop&w=800&q=80", ["3 sweet potatoes", "Oil", "Salt", "Paprika"], "Cut, toss oil and spice. 425°F 25 minutes, flip once."),
        ("Scalloped Potatoes", "Potato", "https://images.unsplash.com/photo-1604908554027-c1c1f4c5c1d2?auto=format&fit=crop&w=800&q=80", ["3 lb potatoes, sliced", "2 cups cream", "Garlic", "Gruyere"], "Layer potatoes, cream, cheese. Bake 350°F 1 hour."),
        ("Potato Salad", "Potato", "https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=800&q=80", ["3 lb potatoes", "Mayo", "Mustard", "Celery", "Eggs", "Pickle relish"], "Boil potatoes. Mix mayo dressing. Fold in eggs and celery. Chill."),
        ("Macaroni and Cheese", "Classic", "https://images.unsplash.com/photo-1543339494-b4cd4f7ba686?auto=format&fit=crop&w=800&q=80", ["1 lb elbows", "4 cups cheddar", "Butter", "Milk", "Flour"], "Roux, milk, cheese. Mix pasta. Bake 20 minutes if you want a crust."),
        ("Baked Beans", "BBQ", "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=800&q=80", ["2 cans navy beans", "Bacon", "Brown sugar", "Molasses", "Mustard", "Onion"], "Cook bacon and onion. Stir in rest. Bake 350°F 45 minutes."),
        ("Coleslaw", "Salad", "https://images.unsplash.com/photo-1625938145312-c3e4d0d1d0d0?auto=format&fit=crop&w=800&q=80", ["1 bag coleslaw mix", "Mayo", "Vinegar", "Sugar", "Celery seed"], "Whisk dressing. Toss cabbage. Chill 30 minutes."),
        ("Corn on the Cob", "Veg", "https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=800&q=80", ["6 ears corn", "Butter", "Salt"], "Boil 6 minutes or grill in husk 15. Butter and salt."),
        ("Creamed Corn", "Veg", "https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=800&q=80", ["4 cups corn", "Butter", "Cream", "Sugar", "Salt"], "Simmer corn with cream and butter 10 minutes."),
        ("Green Bean Casserole", "Classic", "https://images.unsplash.com/photo-1604908554401-1c4c1c4c1d2?auto=format&fit=crop&w=800&q=80", ["Green beans", "Cream of mushroom", "Fried onions"], "Mix beans and soup. Bake 25 minutes. Top onions 5 more."),
        ("Roasted Broccoli", "Veg", "https://images.unsplash.com/photo-1459411621453-7b03977f4bfc?auto=format&fit=crop&w=800&q=80", ["2 heads broccoli", "Olive oil", "Garlic", "Lemon", "Salt"], "425°F 20 minutes. Lemon at the end."),
        ("Roasted Carrots", "Veg", "https://images.unsplash.com/photo-1447175008436-170170755cc7?auto=format&fit=crop&w=800&q=80", ["2 lb carrots", "Olive oil", "Honey", "Thyme"], "Toss, roast 400°F 25 minutes."),
        ("Asparagus", "Veg", "https://images.unsplash.com/photo-1515543237350-b3eea1ecce68?auto=format&fit=crop&w=800&q=80", ["2 bunches asparagus", "Olive oil", "Salt", "Lemon"], "Roast 425°F 12 minutes."),
        ("Sauteed Green Beans", "Veg", "https://images.unsplash.com/photo-1567375698348-5d9d5ae99de0?auto=format&fit=crop&w=800&q=80", ["1.5 lb green beans", "Garlic", "Butter", "Almonds"], "Blanch, then sauté garlic and butter. Almonds."),
        ("Cornbread", "Bread", "https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=800&q=80", ["1 cup cornmeal", "1 cup flour", "1 cup buttermilk", "Egg", "Butter", "Sugar"], "Mix, pour 8-inch pan. 400°F 20 minutes."),
        ("Garlic Bread", "Bread", "https://images.unsplash.com/photo-1573140247632-f0beb4dfe3c5?auto=format&fit=crop&w=800&q=80", ["French loaf", "Butter", "Garlic", "Parsley"], "Spread, 400°F 10 minutes."),
        ("Dinner Rolls", "Bread", "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80", ["Yeast dough", "Butter"], "Bake 375°F 15 minutes. Brush butter."),
        ("Biscuits", "Bread", "https://images.unsplash.com/photo-1586985289688-ca3cf47d3e6e?auto=format&fit=crop&w=800&q=80", ["2 cups flour", "1 tbsp baking powder", "Stick butter", "3/4 cup buttermilk"], "Cut in butter, add buttermilk. 425°F 12 minutes."),
        ("House Salad", "Salad", "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80", ["Lettuce", "Tomato", "Cucumber", "Croutons", "Ranch or vinaigrette"], "Toss greens and veg. Dress at the table."),
        ("Caesar Salad", "Salad", "https://images.unsplash.com/photo-1550304943-4f24f54ddde9?auto=format&fit=crop&w=800&q=80", ["Romaine", "Parmesan", "Croutons", "Caesar dressing"], "Toss romaine, cheese, croutons, dressing."),
        ("Wedge Salad", "Salad", "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=800&q=80", ["Iceberg", "Blue cheese", "Bacon", "Tomato"], "Quarter lettuce. Dressing, bacon, tomato."),
        ("Macaroni Salad", "Salad", "https://images.unsplash.com/photo-1626200419199-391ae4be7c41?auto=format&fit=crop&w=800&q=80", ["Elbows", "Mayo", "Celery", "Egg", "Pickle"], "Cook pasta. Fold dressing. Chill."),
        ("Fruit Salad", "Salad", "https://images.unsplash.com/photo-1564093497595-593b96d80180?auto=format&fit=crop&w=800&q=80", ["Berries", "Melon", "Grapes", "Honey", "Mint"], "Toss fruit with honey and mint."),
        ("Onion Rings", "Classic", "https://images.unsplash.com/photo-1639024471283-03518883512d?auto=format&fit=crop&w=800&q=80", ["2 large onions", "Buttermilk", "Flour", "Oil"], "Soak, dredge, fry 350°F gold."),
        ("Tater Tots", "Potato", "https://images.unsplash.com/photo-1585109649139-366815a0d713?auto=format&fit=crop&w=800&q=80", ["Bag of tots", "Salt"], "Bake per bag, extra crisp 5 minutes."),
        ("Rice Pilaf", "Classic", "https://images.unsplash.com/photo-1536304993881-ff6e9eefa2a6?auto=format&fit=crop&w=800&q=80", ["2 cups rice", "Onion", "Butter", "4 cups broth"], "Toast rice in butter. Add broth. Cover 18 minutes."),
        ("White Rice", "Classic", "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=800&q=80", ["2 cups rice", "Water", "Salt"], "Rinse. 1:2 rice to water. Simmer 15. Rest 5."),
        ("Stuffing", "Classic", "https://images.unsplash.com/photo-1574672280600-4accfa5b6f98?auto=format&fit=crop&w=800&q=80", ["Bread cubes", "Celery", "Onion", "Broth", "Sage"], "Sauté veg. Mix bread and broth. Bake 350°F 30 minutes."),
        ("Cranberry Sauce", "Classic", "https://images.unsplash.com/photo-1606851094544-4c0c0c0c0c0c?auto=format&fit=crop&w=800&q=80", ["12 oz cranberries", "1 cup sugar", "1 cup water", "Orange zest"], "Simmer 10 minutes until berries pop. Chill."),
        ("Applesauce", "Classic", "https://images.unsplash.com/photo-1568702846914-96b305d2bb92?auto=format&fit=crop&w=800&q=80", ["6 apples", "Sugar", "Cinnamon", "Water"], "Simmer apples 20 minutes. Mash."),
        ("Gravy", "Classic", "https://images.unsplash.com/photo-1574484284002-952d92456975?auto=format&fit=crop&w=800&q=80", ["Pan drippings", "Flour", "Stock", "Salt"], "Roux with drippings. Whisk stock. Simmer 5."),
        ("Collard Greens", "Veg", "https://images.unsplash.com/photo-1505576391880-b3f9d713dc4f?auto=format&fit=crop&w=800&q=80", ["2 bunches collards", "Ham hock or bacon", "Onion", "Vinegar"], "Simmer with smoked meat 45 minutes."),
        ("Fried Okra", "Veg", "https://images.unsplash.com/photo-1604908177522-04083420eb68?auto=format&fit=crop&w=800&q=80", ["1 lb okra", "Cornmeal", "Oil", "Salt"], "Slice, dredge cornmeal, fry 350°F."),
        ("Hush Puppies", "Bread", "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?auto=format&fit=crop&w=800&q=80", ["Cornmeal", "Flour", "Buttermilk", "Onion", "Oil"], "Mix batter. Drop in 350°F oil until gold."),
        ("Deviled Eggs", "Classic", "https://images.unsplash.com/photo-1635321593217-40050ad13c74?auto=format&fit=crop&w=800&q=80", ["12 eggs", "Mayo", "Mustard", "Paprika"], "Boil, mash yolks with mayo and mustard. Pipe, paprika."),
        ("Pickles", "Classic", "https://images.unsplash.com/photo-1599599810694-b5b37304c041?auto=format&fit=crop&w=800&q=80", ["Jar dill pickles"], "Serve cold with the plate."),
        ("Baked Macaroni", "Classic", "https://images.unsplash.com/photo-1619895092538-128341789043?auto=format&fit=crop&w=800&q=80", ["Elbows", "Cheddar", "Breadcrumbs", "Butter"], "Cheese sauce, pasta, breadcrumb top. 375°F 25 minutes."),
        ("Creamed Spinach", "Veg", "https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=800&q=80", ["2 lb spinach", "Cream", "Garlic", "Nutmeg"], "Wilt spinach. Cream and garlic. Simmer thick."),
        ("Brussels Sprouts", "Veg", "https://images.unsplash.com/photo-1438111062589-814648b01743?auto=format&fit=crop&w=800&q=80", ["2 lb sprouts", "Oil", "Bacon", "Balsamic"], "Halve, roast 425°F 25 minutes. Bacon and splash balsamic."),
        ("Cucumber Salad", "Salad", "https://images.unsplash.com/photo-1444312645910-ffa973776743?auto=format&fit=crop&w=800&q=80", ["Cucumbers", "Onion", "Vinegar", "Sugar", "Dill"], "Slice, salt, dress vinegar. Chill."),
        ("Three Bean Salad", "Salad", "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80", ["Green, kidney, garbanzo", "Onion", "Vinaigrette"], "Drain beans. Toss dressing. Chill."),
        ("Corn Salad", "Salad", "https://images.unsplash.com/photo-1505253716362-afaea1d3d1af?auto=format&fit=crop&w=800&q=80", ["Corn", "Tomato", "Cilantro", "Lime", "Feta"], "Char corn. Toss with tomato, lime, feta."),
        ("Texas Toast", "Bread", "https://images.unsplash.com/photo-1484723091739-30a097e8f929?auto=format&fit=crop&w=800&q=80", ["Thick bread", "Garlic butter"], "Broil 2 minutes a side."),
        ("Cheddar Biscuits", "Bread", "https://images.unsplash.com/photo-1586985289688-ca3cf47d3e6e?auto=format&fit=crop&w=800&q=80", ["Biscuit dough", "Cheddar", "Garlic butter"], "Fold cheese. Bake. Brush garlic butter."),
        ("Slaw Mix", "BBQ", "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=800&q=80", ["Cabbage", "Carrot", "Vinegar slaw dressing"], "Toss and chill. Bright with BBQ."),
        ("Potato Wedges", "Potato", "https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?auto=format&fit=crop&w=800&q=80", ["Russets", "Oil", "Paprika", "Salt"], "Wedges, 425°F 35 minutes."),
        ("Elote", "Veg", "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?auto=format&fit=crop&w=800&q=80", ["Corn", "Mayo", "Cotija", "Chili", "Lime"], "Grill corn. Mayo, cheese, chili, lime."),
        ("Refried Beans", "Classic", "https://images.unsplash.com/photo-1547592166-23acba4d3d14?auto=format&fit=crop&w=800&q=80", ["Pinto beans", "Onion", "Lard or oil", "Salt"], "Mash beans in skillet with onion."),
        ("Spanish Rice", "Classic", "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=800&q=80", ["Rice", "Tomato sauce", "Onion", "Cumin"], "Toast rice. Sauce and water. Simmer 18."),
        ("Cobb Salad", "Salad", "https://images.unsplash.com/photo-1546793665-c74683f339c1?auto=format&fit=crop&w=800&q=80", ["Lettuce", "Egg", "Bacon", "Avocado", "Tomato", "Blue cheese"], "Row toppings on greens. Dressing on the side.")
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
        guard !needle.isEmpty else {
            await streamMore()
            return
        }
        recipes = AmericanSides.recipes.filter {
            $0.name.lowercased().contains(needle) || $0.category.lowercased().contains(needle)
        }
        if let remote = try? await MealDB.search(needle) {
            let extra = remote.filter { item in
                let blob = (item.name + item.category).lowercased()
                return blob.contains("side") || blob.contains("salad") || blob.contains("potato") || blob.contains("rice") || blob.contains("slaw")
            }
            var seen = Set(recipes.map(\.id))
            for item in extra where seen.insert(item.id).inserted {
                recipes.append(item)
            }
        }
    }

    private func applyFilter() {
        if category == "All" {
            recipes = AmericanSides.recipes
        } else {
            recipes = AmericanSides.recipes.filter { $0.category == category }
        }
    }

    private func streamMore() async {
        let remote = (try? await MealDB.filter(category: "Side")) ?? []
        let starters = (try? await MealDB.filter(category: "Starter")) ?? []
        var seen = Set(recipes.map(\.id))
        for item in remote + starters where seen.insert(item.id).inserted {
            recipes.append(item)
        }
    }
}
