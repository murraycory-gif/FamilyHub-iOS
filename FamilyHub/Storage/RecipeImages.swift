import Foundation
import UIKit

enum RecipeImages {
    private static var memory: [String: UIImage] = [:]
    private static let lock = NSLock()
    private static let version = "v3"

    static func photo(url: URL?, name: String) async -> UIImage? {
        let dish = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = cacheKey(dish, url)
        if let cached = cached(key) { return cached }

        if let url, !isUnsplash(url), let image = await download(url.absoluteString, timeout: 4) {
            store(image, key: key)
            return image
        }
        guard !dish.isEmpty else { return nil }
        if let image = await wikipedia(dish) {
            store(image, key: key)
            return image
        }
        if let image = await mealDB(dish) {
            store(image, key: key)
            return image
        }
        if let image = await commons(dish) {
            store(image, key: key)
            return image
        }
        return nil
    }

    private static func cacheKey(_ name: String, _ url: URL?) -> String {
        let base = name.isEmpty ? (url?.absoluteString ?? "none") : name
        return "\(version)-\(base.lowercased())"
    }

    private static func isUnsplash(_ url: URL) -> Bool {
        (url.host ?? "").contains("unsplash.com")
    }

    private static func wikipedia(_ name: String) async -> UIImage? {
        for title in wikiTitles(name) {
            let slug = title.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
            guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(slug)"),
                  let json = await json(url, agent: true)
            else { continue }
            let pageTitle = (json["title"] as? String) ?? title
            let kind = json["type"] as? String
            if kind == "disambiguation" { continue }
            guard fits(pageTitle, dish: name) else { continue }
            if let thumb = json["thumbnail"] as? [String: Any],
               let source = thumb["source"] as? String,
               let image = await download(source) {
                return image
            }
            if let original = json["originalimage"] as? [String: Any],
               let source = original["source"] as? String,
               let image = await download(source) {
                return image
            }
        }
        var comps = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        comps.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: "\(name) food dish"),
            URLQueryItem(name: "srlimit", value: "5"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let searchURL = comps.url,
              let searchJSON = await json(searchURL, agent: true),
              let queryObj = searchJSON["query"] as? [String: Any],
              let hits = queryObj["search"] as? [[String: Any]]
        else { return nil }
        for hit in hits {
            guard let title = hit["title"] as? String, fits(title, dish: name) else { continue }
            let slug = title.replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
            if let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(slug)"),
               let page = await json(url, agent: true),
               let thumb = page["thumbnail"] as? [String: Any],
               let source = thumb["source"] as? String,
               let image = await download(source) {
                return image
            }
        }
        return nil
    }

    private static func mealDB(_ name: String) async -> UIImage? {
        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let url = URL(string: "https://www.themealdb.com/api/json/v1/1/search.php?s=\(query)"),
              let json = await json(url),
              let meals = json["meals"] as? [[String: Any]]
        else { return nil }
        for meal in meals.prefix(6) {
            let title = meal["strMeal"] as? String ?? ""
            guard fits(title, dish: name) else { continue }
            if let thumb = meal["strMealThumb"] as? String, let image = await download(thumb) {
                return image
            }
        }
        return nil
    }

    private static func commons(_ name: String) async -> UIImage? {
        var comps = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        comps.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "\(name) food"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "8"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url"),
            URLQueryItem(name: "iiurlwidth", value: "800"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = comps.url, let json = await json(url, agent: true),
              let queryObj = json["query"] as? [String: Any],
              let pages = queryObj["pages"] as? [String: [String: Any]]
        else { return nil }
        for page in pages.values {
            let title = page["title"] as? String ?? ""
            guard fits(title, dish: name) || fits(name, dish: name) else { continue }
            if let infos = page["imageinfo"] as? [[String: Any]] {
                let source = (infos.first?["thumburl"] as? String) ?? (infos.first?["url"] as? String)
                if let source, let image = await download(source) { return image }
            }
        }
        return nil
    }

    private static func wikiTitles(_ name: String) -> [String] {
        var titles = [alias(name), name, "\(name) (food)"]
        let trimmed = name
            .replacingOccurrences(of: "Classic ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Homemade ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " at Home", with: "", options: .caseInsensitive)
        if trimmed != name { titles.append(trimmed) }
        if name.hasSuffix("s") { titles.append(String(name.dropLast())) }
        return Array(NSOrderedSet(array: titles).array) as? [String] ?? titles
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
            "House Salad": "Salad",
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
            "Clam Chowder": "New England clam chowder",
            "Beef Tacos": "Taco",
            "Chicken Enchiladas": "Enchilada",
            "Chicken Quesadillas": "Quesadilla",
            "Pork Carnitas": "Carnitas",
            "Breakfast-for-Dinner Pancakes": "Pancake",
            "French Toast": "French toast",
            "Biscuits and Sausage Gravy": "Biscuits and gravy",
            "Chicken Fried Steak": "Chicken-fried steak",
            "Shepherd's Pie American": "Shepherd's pie",
            "Spaghetti and Meatballs": "Spaghetti and meatballs",
            "Pepperoni Pizza Night": "Pepperoni pizza",
            "BBQ Chicken Pizza": "Pizza",
            "Honey Garlic Salmon": "Salmon",
            "Fish Tacos": "Fish taco",
            "Orange Chicken": "Orange chicken",
            "Loaded Baked Potatoes": "Baked potato",
            "Cornbread": "Cornbread",
            "Caesar Salad": "Caesar salad",
            "Wedge Salad": "Wedge salad",
            "Fruit Salad": "Fruit salad",
            "Macaroni Salad": "Macaroni salad",
            "Baked Beans": "Baked beans",
            "Creamed Corn": "Creamed corn",
            "Roasted Broccoli": "Broccoli",
            "Roasted Carrots": "Carrot",
            "Asparagus": "Asparagus",
            "Hush Puppies": "Hushpuppy",
            "Cranberry Sauce": "Cranberry sauce",
            "Collard Greens": "Collard greens",
            "Fried Okra": "Okra",
            "Brussels Sprouts": "Brussels sprout",
            "Elote": "Elote",
            "Refried Beans": "Refried beans",
            "Spanish Rice": "Spanish rice",
            "Cobb Salad": "Cobb salad",
            "Scalloped Potatoes": "Gratin",
            "Potato Wedges": "Potato wedge",
            "White Rice": "Cooked rice",
            "Rice Pilaf": "Pilaf",
            "Stuffing": "Stuffing",
            "Applesauce": "Apple sauce",
            "Gravy": "Gravy",
            "Pickles": "Pickled cucumber",
            "Texas Toast": "Texas toast",
            "Cheddar Biscuits": "Biscuit (bread)",
            "Biscuits": "Biscuit (bread)",
            "Sauteed Green Beans": "Green bean",
            "Creamed Spinach": "Creamed spinach",
            "Cucumber Salad": "Cucumber salad",
            "Three Bean Salad": "Three bean salad",
            "Corn Salad": "Corn salad",
            "Slaw Mix": "Coleslaw",
            "Baked Macaroni": "Macaroni casserole",
            "Sheet Pan Fajitas": "Fajita",
            "Nachos Supreme": "Nachos",
            "Burrito Bowls": "Burrito",
            "Po' Boy": "Po' boy",
            "Jambalaya": "Jambalaya",
            "Gumbo": "Gumbo",
            "Crab Cakes": "Crab cake",
            "Fish Fry": "Fish fry",
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
            "Teriyaki Chicken Bowls": "Teriyaki",
            "Cajun Salmon": "Salmon",
            "Shrimp Scampi": "Shrimp scampi",
            "Beef Stir Fry": "Stir frying",
            "General Tso's at Home": "General Tso's chicken",
            "Hamburgers Helper Style Skillet": "Hamburger",
            "Cornbread Chili Bake": "Chili con carne",
            "Pesto Pasta with Chicken": "Pesto",
            "Chicken Fried Steak": "Chicken-fried steak"
        ]
        return map[name] ?? name
    }

    private static func fits(_ candidate: String, dish: String) -> Bool {
        let a = tokens(dish)
        let b = tokens(candidate)
        if a.isEmpty { return candidate.lowercased().contains(dish.lowercased()) }
        return !a.intersection(b).isEmpty
    }

    private static func tokens(_ name: String) -> Set<String> {
        let stop: Set<String> = [
            "classic", "homemade", "buttermilk", "loaded", "sauteed", "roasted", "baked",
            "grilled", "southern", "texas", "house", "with", "and", "the", "for", "dinner",
            "style", "american", "night", "supreme", "helper", "skillet", "file", "jpg",
            "png", "photo", "image", "food", "dish", "recipe"
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
        let file = folder.appendingPathComponent(key.hashed)
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
            try? data.write(to: folder.appendingPathComponent(key.hashed), options: .atomic)
        }
    }

    private static var folder: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecipePhotosV3", isDirectory: true)
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
              image.size.width > 40
        else { return nil }
        return image
    }

    private static func data(_ url: URL, agent: Bool = true) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        if agent { request.setValue("HUB/1.0 (family hub recipe photos)", forHTTPHeaderField: "User-Agent") }
        return try? await URLSession.shared.data(for: request).0
    }
}

private extension String {
    var hashed: String {
        String(abs(hashValue))
    }
}
