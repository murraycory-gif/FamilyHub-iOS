import Foundation
import UIKit

enum RecipeImages {
    private static var memory: [String: UIImage] = [:]
    private static let lock = NSLock()
    private static let version = "v6"
    private static let gate = Gate(limit: 6)

    static func cachedImage(url: URL?, name: String) -> UIImage? {
        cached(cacheKey(name))
    }

    static func prefetch(_ recipes: [CatalogRecipe]) {
        let unique = Dictionary(grouping: recipes, by: \.name).compactMap(\.value.first)
        Task {
            for recipe in unique.prefix(12) {
                _ = await photo(url: recipe.thumb, name: recipe.name)
            }
        }
    }

    static func photo(url: URL?, name: String) async -> UIImage? {
        let dish = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = cacheKey(dish)
        if let cached = cached(key) { return cached }
        return await gate.run {
            if let cached = cached(key) { return cached }
            if let url, isMealDB(url), let image = await download(url.absoluteString, timeout: 5) {
                store(image, key: key)
                return image
            }
            guard !dish.isEmpty else { return nil }
            for term in searchTerms(dish) {
                if let image = await mealDB(term) {
                    store(image, key: key)
                    return image
                }
            }
            for term in searchTerms(dish) {
                if let image = await wikipediaFood(term) {
                    store(image, key: key)
                    return image
                }
            }
            return nil
        }
    }

    private static func searchTerms(_ name: String) -> [String] {
        var terms: [String] = []
        let mapped = alias(name)
        terms.append(mapped)
        if mapped != name { terms.append(name) }
        let short = mapped
            .split(separator: " ")
            .map(String.init)
            .filter { !dropWords.contains($0.lowercased()) }
            .joined(separator: " ")
        if short.count >= 4, !terms.contains(short) { terms.append(short) }
        return terms
    }

    private static let dropWords: Set<String> = [
        "classic", "homemade", "with", "and", "the", "for", "dinner", "night",
        "american", "table", "style", "skillet", "bake", "two", "ways", "at", "home"
    ]

    private static func cacheKey(_ name: String) -> String {
        let slug = name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : Character("-") }
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
        for meal in meals.prefix(8) {
            let title = meal["strMeal"] as? String ?? ""
            guard fits(title, dish: name) || meals.count == 1 else { continue }
            if let thumb = meal["strMealThumb"] as? String, let image = await download(thumb, timeout: 5) {
                return image
            }
        }
        if name.split(separator: " ").count >= 2,
           let thumb = meals.first?["strMealThumb"] as? String {
            return await download(thumb, timeout: 5)
        }
        return nil
    }

    private static func wikipediaFood(_ title: String) async -> UIImage? {
        let candidates = ["\(title) (food)", "\(title) dish", title]
        for raw in candidates {
            let slug = raw.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
            guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(slug)"),
                  let json = await json(url, agent: true)
            else { continue }
            if json["type"] as? String == "disambiguation" { continue }
            let page = ((json["title"] as? String) ?? "").lowercased()
            let desc = ((json["description"] as? String) ?? "").lowercased()
            if junk(page) || junk(desc) { continue }
            for key in ["originalimage", "thumbnail"] {
                if let thumb = json[key] as? [String: Any],
                   let source = thumb["source"] as? String,
                   !source.lowercased().contains(".svg"),
                   let image = await download(source, timeout: 5),
                   image.size.width > 160 {
                    return image
                }
            }
        }
        return nil
    }

    private static func junk(_ text: String) -> Bool {
        ["logo", "diagram", "chart", "map of", "flag", "cut of", "family tree",
         "album", "film", "tv series", "stadium", "baseball", "nfl", "mlb"].contains { text.contains($0) }
    }

    private static func alias(_ name: String) -> String {
        let map = [
            "Classic Cheeseburgers": "Cheeseburger",
            "Buttermilk Fried Chicken": "Fried chicken",
            "BBQ Baby Back Ribs": "Pork ribs",
            "Pulled Pork Sandwiches": "Pulled pork sandwich",
            "Texas Brisket": "Brisket",
            "Buffalo Chicken Wings": "Buffalo wing",
            "Meatloaf with Ketchup Glaze": "Meatloaf",
            "Chicken Pot Pie": "Chicken pot pie",
            "Macaroni and Cheese": "Macaroni and cheese",
            "Chili con Carne": "Chili con carne",
            "Cajun Salmon": "Blackened salmon",
            "Chicago Dogs": "Chicago-style hot dog",
            "Coney Dogs": "Coney Island hot dog",
            "Thanksgiving Turkey": "Roast turkey",
            "Prime Rib": "Prime rib",
            "Beer Can Chicken": "Roast chicken",
            "Funeral Potatoes": "Cheesy potato casserole",
            "Hashbrown Casserole": "Hash brown casserole",
            "Corn Casserole": "Corn pudding",
            "Sweet Potato Casserole": "Sweet potato casserole",
            "Sausage Stuffing": "Stuffing",
            "Ham with Pineapple": "Ham",
            "Open Face Hot Turkey Sandwich": "Hot brown",
            "Philly Roast Pork Sandwich": "Roast pork sandwich",
            "Pork Tenderloin Sandwich": "Pork tenderloin sandwich",
            "Italian Beef": "Italian beef",
            "Veggie Chili": "Vegetarian chili",
            "Black Bean Burgers": "Veggie burger",
            "Caesar Salad with Grilled Chicken": "Caesar salad",
            "BBQ Pulled Chicken": "Pulled chicken",
            "Smoked Sausage and Peppers": "Sausage and peppers",
            "Bratwurst and Sauerkraut": "Bratwurst",
            "Chicken and Rice Casserole": "Chicken rice casserole",
            "Cedar Plank Salmon": "Grilled salmon",
            "Surf and Turf": "Surf and turf",
            "Meatball Subs": "Meatball sandwich",
            "Chicken Parmesan": "Chicken parmesan",
            "Eggplant Parmesan": "Eggplant parmesan",
            "Stuffed Shells": "Stuffed shells",
            "Baked Chicken Tenders": "Chicken nugget",
            "BBQ Meatloaf": "Meatloaf",
            "Dr Pepper Pulled Pork": "Pulled pork",
            "Smash Burgers": "Hamburger",
            "Turkey Burgers": "Turkey burger",
            "Blackened Catfish": "Catfish",
            "Hush Puppies and Fried Fish": "Fried catfish",
            "Collard Greens with Ham": "Collard greens",
            "Brown Gravy Pork Chops": "Pork chop",
            "Salisbury Steak": "Salisbury steak",
            "Chicken and Stuffing Bake": "Chicken stuffing",
            "Tater Tot Hotdish": "Tater tot casserole",
            "Frito Pie": "Frito pie",
            "Walking Tacos": "Taco",
            "Seven Layer Dip Night": "Seven-layer dip",
            "White Chicken Chili": "Chicken chili",
            "Chicken Noodle Soup": "Chicken noodle soup",
            "Tomato Basil Soup and Grilled Cheese": "Tomato soup",
            "Broccoli Cheddar Soup": "Broccoli soup",
            "French Onion Soup": "French onion soup",
            "Crockpot Chicken Tacos": "Chicken taco",
            "Crockpot Beef Tips": "Beef stew",
            "Weeknight Tacos Two Ways": "Taco",
            "Hawaiian Haystacks": "Chicken gravy",
            "Chicken Divan": "Chicken divan",
            "King Ranch Chicken": "King Ranch chicken",
            "Chicken Tetrazzini": "Chicken tetrazzini",
            "Beef Stroganoff American": "Beef Stroganoff",
            "Swedish Meatballs American Table": "Swedish meatball",
            "Pigs in a Blanket Dinner": "Pigs in a blanket",
            "Breakfast Burritos": "Breakfast burrito",
            "Huevos Rancheros": "Huevos rancheros",
            "Chicken and Waffles": "Chicken and waffles",
            "Steak and Potatoes": "Steak",
            "Pork Ribs Oven": "Pork ribs",
            "Grilled BBQ Chicken": "Barbecue chicken",
            "Cedar BBQ Salmon Burgers": "Salmon burger",
            "Turkey Club Wrap": "Club sandwich",
            "Chicken Caesar Wrap": "Caesar salad",
            "Buffalo Chicken Sandwiches": "Buffalo wing",
            "Crispy Chicken Sandwich": "Fried chicken sandwich",
            "BBQ Pulled Jackfruit": "Pulled pork",
            "Mushroom Cheesesteaks": "Cheesesteak",
            "Baked Ziti Sausage": "Baked ziti",
            "Sausage, Peppers, and Onions": "Sausage and peppers",
            "Weeknight Roast Salmon and Veg": "Baked salmon",
            "Honey Mustard Chicken Thighs": "Roast chicken",
            "Lemon Pepper Chicken": "Lemon chicken",
            "Garlic Butter Steak Bites": "Steak",
            "Cheeseburger Pasta Skillet": "Cheeseburger",
            "Taco Pasta": "Taco",
            "Pizza Pasta Bake": "Pizza",
            "Ranch Chicken Bacon Bake": "Chicken bacon",
            "Mississippi Pot Roast": "Pot roast",
            "Mississippi Chicken": "Roast chicken",
            "Coke Ham": "Ham",
            "Root Beer Pulled Pork": "Pulled pork",
            "Sunday Gravy with Sausage and Meatballs": "Spaghetti and meatballs",
            "Baked Mostaccioli": "Baked ziti",
            "Chicken Cordon Bleu Bake": "Chicken Cordon Bleu",
            "Reuben Skillet": "Reuben sandwich",
            "Patty Melt": "Patty melt",
            "Tuna Melts": "Tuna melt",
            "Salmon Patties": "Salmon cake",
            "Chicken Bog": "Chicken rice",
            "Hoppin' John": "Hoppin' John",
            "Chicken Bog Bowl": "Chicken rice",
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
            "Tater Tots": "Tater tots",
            "Onion Rings": "Onion ring",
            "Dinner Rolls": "Dinner roll",
            "Garlic Bread": "Garlic bread",
            "Deviled Eggs": "Deviled egg",
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
            "BBQ Chicken Pizza": "Pizza",
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
            "Shrimp Scampi": "Shrimp scampi",
            "Beef Stir Fry": "Beef stir fry",
            "General Tso's at Home": "General Tso's chicken",
            "Hamburgers Helper Style Skillet": "Hamburger",
            "Cornbread Chili Bake": "Chili",
            "Pesto Pasta with Chicken": "Pesto pasta",
            "Tuna Noodle Casserole": "Tuna casserole"
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
            .appendingPathComponent("RecipePhotosV6", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func json(_ url: URL, agent: Bool = false) async -> [String: Any]? {
        guard let data = await data(url, agent: agent) else { return nil }
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
              image.size.width > 80
        else { return nil }
        return image
    }

    private static func data(_ url: URL, agent: Bool = false) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        if agent {
            request.setValue("FamilyHub/1.0 (recipe photos; ios family hub)", forHTTPHeaderField: "User-Agent")
        }
        return try? await URLSession.shared.data(for: request).0
    }
}

private actor Gate {
    private var running = 0
    private let limit: Int
    init(limit: Int) { self.limit = limit }

    func run<T>(_ work: () async -> T) async -> T {
        while running >= limit {
            await Task.yield()
        }
        running += 1
        defer { running -= 1 }
        return await work()
    }
}
