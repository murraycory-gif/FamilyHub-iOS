import Foundation
import UIKit

enum RecipeImages {
    private static var memory: [String: UIImage] = [:]
    private static let lock = NSLock()
    private static let version = "v5"

    static func cachedImage(url: URL?, name: String) -> UIImage? {
        cached(cacheKey(name))
    }

    static func prefetch(_ recipes: [CatalogRecipe]) {
        let batch = Array(recipes.prefix(48))
        Task.detached(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for recipe in batch {
                    group.addTask {
                        _ = await photo(url: recipe.thumb, name: recipe.name)
                    }
                }
            }
        }
    }

    static func photo(url: URL?, name: String) async -> UIImage? {
        let dish = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = cacheKey(dish)
        if let cached = cached(key) { return cached }

        if let url, isMealDB(url), let image = await download(url.absoluteString, timeout: 4) {
            store(image, key: key)
            return image
        }

        guard !dish.isEmpty else { return nil }
        let title = alias(dish)
        if let image = await mealDB(title) {
            store(image, key: key)
            return image
        }
        if title != dish, let image = await mealDB(dish) {
            store(image, key: key)
            return image
        }
        return nil
    }

    private static func cacheKey(_ name: String) -> String {
        let slug = name.lowercased().map { $0.isLetter || $0.isNumber ? Character(String($0)) : "-" }
        var compact = String(slug)
        while compact.contains("--") { compact = compact.replacingOccurrences(of: "--", with: "-") }
        compact = compact.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(version)-\(compact.isEmpty ? "dish" : compact)"
    }

    private static func isMealDB(_ url: URL) -> Bool {
        (url.host ?? "").contains("themealdb.com")
    }

    private static func mealDB(_ name: String) async -> UIImage? {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let url = URL(string: "https://www.themealdb.com/api/json/v1/1/search.php?s=\(query)"),
              let json = await json(url),
              let meals = json["meals"] as? [[String: Any]]
        else { return nil }
        for meal in meals.prefix(6) {
            let title = meal["strMeal"] as? String ?? ""
            guard fits(title, dish: name) || meals.count == 1 else { continue }
            if let thumb = meal["strMealThumb"] as? String, let image = await download(thumb, timeout: 4) {
                return image
            }
        }
        if let thumb = meals.first?["strMealThumb"] as? String {
            return await download(thumb, timeout: 4)
        }
        return nil
    }

    private static func alias(_ name: String) -> String {
        let map = [
            "Classic Cheeseburgers": "Cheeseburger",
            "Buttermilk Fried Chicken": "Fried chicken",
            "BBQ Baby Back Ribs": "Pork ribs",
            "Pulled Pork Sandwiches": "Pulled pork",
            "Texas Brisket": "Brisket",
            "Buffalo Chicken Wings": "Buffalo wing",
            "Meatloaf with Ketchup Glaze": "Meatloaf",
            "Macaroni and Cheese": "Macaroni and cheese",
            "Chili con Carne": "Chili con carne",
            "French Fries": "French fries",
            "Sweet Potato Fries": "Sweet potato fry",
            "Mashed Potatoes": "Mashed potato",
            "Garlic Mashed Potatoes": "Mashed potato",
            "Loaded Baked Potatoes": "Baked potato",
            "Roasted Potatoes": "Roast potato",
            "Potato Salad": "Potato salad",
            "Coleslaw": "Coleslaw",
            "Corn on the Cob": "Corn on the cob",
            "Green Bean Casserole": "Green bean casserole",
            "House Salad": "Green salad",
            "Tater Tots": "Tater tots",
            "Onion Rings": "Onion ring",
            "Dinner Rolls": "Dinner roll",
            "Garlic Bread": "Garlic bread",
            "Deviled Eggs": "Deviled egg",
            "Chicken Pot Pie": "Chicken pot pie",
            "Sloppy Joes": "Sloppy joe",
            "Cheesesteaks": "Cheesesteak",
            "Lobster Rolls": "Lobster roll",
            "Club Sandwich": "Club sandwich",
            "Grilled Cheese and Tomato Soup": "Grilled cheese",
            "Shrimp and Grits": "Shrimp and grits",
            "Red Beans and Rice": "Red beans and rice",
            "Clam Chowder": "Clam chowder",
            "Beef Tacos": "Taco",
            "Chicken Enchiladas": "Enchilada",
            "Chicken Quesadillas": "Quesadilla",
            "Pork Carnitas": "Carnitas",
            "Breakfast-for-Dinner Pancakes": "Pancake",
            "French Toast": "French toast",
            "Biscuits and Sausage Gravy": "Biscuits and gravy",
            "Chicken Fried Steak": "Chicken fried steak",
            "Shepherd's Pie American": "Shepherd's pie",
            "Spaghetti and Meatballs": "Spaghetti",
            "Pepperoni Pizza Night": "Pepperoni pizza",
            "BBQ Chicken Pizza": "BBQ pizza",
            "Honey Garlic Salmon": "Salmon",
            "Fish Tacos": "Fish taco",
            "Orange Chicken": "Orange chicken",
            "Cornbread": "Cornbread",
            "Caesar Salad": "Caesar salad",
            "Wedge Salad": "Wedge salad",
            "Fruit Salad": "Fruit salad",
            "Macaroni Salad": "Macaroni salad",
            "Baked Beans": "Baked beans",
            "Creamed Corn": "Creamed corn",
            "Roasted Broccoli": "Broccoli",
            "Roasted Carrots": "Roasted carrot",
            "Asparagus": "Asparagus",
            "Hush Puppies": "Hushpuppy",
            "Cranberry Sauce": "Cranberry sauce",
            "Collard Greens": "Collard greens",
            "Fried Okra": "Fried okra",
            "Brussels Sprouts": "Brussels sprout",
            "Elote": "Elote",
            "Refried Beans": "Refried beans",
            "Spanish Rice": "Spanish rice",
            "Cobb Salad": "Cobb salad",
            "Scalloped Potatoes": "Potato gratin",
            "Potato Wedges": "Potato wedge",
            "White Rice": "Rice",
            "Rice Pilaf": "Pilaf",
            "Stuffing": "Stuffing",
            "Applesauce": "Apple sauce",
            "Pickles": "Pickle",
            "Texas Toast": "Garlic bread",
            "Cheddar Biscuits": "Biscuit",
            "Biscuits": "Biscuit",
            "Sauteed Green Beans": "Green beans",
            "Creamed Spinach": "Creamed spinach",
            "Cucumber Salad": "Cucumber salad",
            "Three Bean Salad": "Bean salad",
            "Corn Salad": "Corn salad",
            "Baked Macaroni": "Macaroni",
            "Sheet Pan Fajitas": "Fajita",
            "Nachos Supreme": "Nachos",
            "Burrito Bowls": "Burrito",
            "Po' Boy": "Po boy",
            "Jambalaya": "Jambalaya",
            "Gumbo": "Gumbo",
            "Crab Cakes": "Crab cake",
            "Fish Fry": "Fried fish",
            "Beef Stew": "Beef stew",
            "Pot Roast": "Pot roast",
            "Roast Chicken": "Roast chicken",
            "Tuna Noodle Casserole": "Tuna casserole",
            "Chicken and Dumplings": "Chicken and dumplings",
            "BLT": "BLT",
            "Pork Chops and Applesauce": "Pork chop",
            "Stuffed Peppers": "Stuffed pepper",
            "Lasagna": "Lasagne",
            "Baked Ziti": "Baked ziti",
            "Chicken Alfredo": "Fettuccine Alfredo",
            "Teriyaki Chicken Bowls": "Teriyaki chicken",
            "Cajun Salmon": "Cajun salmon",
            "Shrimp Scampi": "Shrimp scampi",
            "Beef Stir Fry": "Beef stir fry",
            "General Tso's at Home": "General Tso chicken",
            "Hamburgers Helper Style Skillet": "Hamburger",
            "Cornbread Chili Bake": "Chili",
            "Pesto Pasta with Chicken": "Pesto pasta"
        ]
        return map[name] ?? name
    }

    private static func fits(_ candidate: String, dish: String) -> Bool {
        let a = tokens(dish)
        let b = tokens(candidate)
        if a.isEmpty { return candidate.lowercased().contains(dish.lowercased()) }
        return !a.isDisjoint(with: b)
    }

    private static func tokens(_ name: String) -> Set<String> {
        let stop: Set<String> = [
            "classic", "homemade", "buttermilk", "loaded", "sauteed", "roasted", "baked",
            "grilled", "southern", "texas", "house", "with", "and", "the", "for", "dinner",
            "style", "american", "night", "supreme", "helper", "skillet", "easy", "quick"
        ]
        return Set(
            name.lowercased()
                .split { !$0.isLetter }
                .map(String.init)
                .filter { $0.count >= 3 && !stop.contains($0) }
        )
    }

    private static func cached(_ key: String) -> UIImage? {
        lock.lock()
        let memoryHit = memory[key]
        lock.unlock()
        if let memoryHit { return memoryHit }
        let file = folder.appendingPathComponent("\(key).jpg")
        guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
        lock.lock()
        memory[key] = image
        lock.unlock()
        return image
    }

    private static func store(_ image: UIImage, key: String) {
        lock.lock()
        memory[key] = image
        lock.unlock()
        if let data = image.jpegData(compressionQuality: 0.82) {
            try? data.write(to: folder.appendingPathComponent("\(key).jpg"), options: .atomic)
        }
    }

    private static var folder: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecipePhotosV5", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func json(_ url: URL) async -> [String: Any]? {
        guard let data = await data(url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func download(_ raw: String, timeout: TimeInterval = 8) async -> UIImage? {
        guard let url = URL(string: raw) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("HUB/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
              let image = UIImage(data: data),
              image.size.width > 40
        else { return nil }
        return image
    }

    private static func data(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("FamilyHub/1.0 (recipe photos)", forHTTPHeaderField: "User-Agent")
        return try? await URLSession.shared.data(for: request).0
    }
}
