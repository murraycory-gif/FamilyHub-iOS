import Foundation

enum DietFlag: String, Codable, CaseIterable, Identifiable, Hashable {
    case vegan
    case vegetarian
    case pescatarian
    case keto
    case paleo
    case glutenFree
    case dairyFree
    case nutFree
    case eggFree
    case soyFree
    case halal
    case kosher
    case lowSodium
    case lowCarb
    case diabeticFriendly

    var id: String { rawValue }

    var note: String? {
        switch self {
        case .halal, .kosher:
            return "Ingredients compatible, not certified"
        case .glutenFree, .dairyFree, .nutFree, .eggFree, .soyFree:
            return "Check labels"
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .vegan: return "Vegan"
        case .vegetarian: return "Vegetarian"
        case .pescatarian: return "Pescatarian"
        case .keto: return "Keto"
        case .paleo: return "Paleo"
        case .glutenFree: return "Gluten-free"
        case .dairyFree: return "Dairy-free"
        case .nutFree: return "Nut-free"
        case .eggFree: return "Egg-free"
        case .soyFree: return "Soy-free"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        case .lowSodium: return "Low-sodium"
        case .lowCarb: return "Low-carb"
        case .diabeticFriendly: return "Diabetic-friendly"
        }
    }
}

enum DietMatch {
    /// A recipe must satisfy every selected flag. Flags are inferred from its ingredient list.
    /// An empty ingredient list does not pass a restriction.
    static func allows(_ recipe: CatalogRecipe, flags: Set<DietFlag>) -> Bool {
        if flags.isEmpty { return true }
        if recipe.dietTags.isEmpty == false {
            return flags.allSatisfy { recipe.dietTags.contains($0) }
        }
        let blob = recipe.ingredients.joined(separator: " ").lowercased()
        if blob.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return flags.allSatisfy { allows(blob, flag: $0) }
    }

    static func allows(_ blob: String, flag: DietFlag) -> Bool {
        let hasMeat = contains(blob, meat)
        let hasFish = contains(blob, fish)
        let hasDairy = contains(blob, dairy)
        let hasEgg = contains(blob, egg)
        switch flag {
        case .vegan:
            return !hasMeat && !hasFish && !hasDairy && !hasEgg && !contains(blob, honey)
        case .vegetarian:
            return !hasMeat && !hasFish
        case .pescatarian:
            return !hasMeat
        case .keto, .lowCarb:
            return !contains(blob, starch)
        case .paleo:
            return !contains(blob, starch) && !hasDairy && !contains(blob, legumes) && !contains(blob, sugar)
        case .glutenFree:
            return !contains(blob, gluten)
        case .dairyFree:
            return !hasDairy
        case .nutFree:
            return !contains(blob, nuts)
        case .eggFree:
            return !hasEgg
        case .soyFree:
            return !contains(blob, soy)
        case .halal:
            return !contains(blob, pork) && !contains(blob, alcohol)
        case .kosher:
            let porkFree = !contains(blob, pork) && !contains(blob, shellfish)
            let mixed = hasMeat && hasDairy
            return porkFree && !mixed
        case .lowSodium:
            return !contains(blob, salty)
        case .diabeticFriendly:
            return !contains(blob, sugar)
        }
    }

    private static func contains(_ blob: String, _ words: [String]) -> Bool {
        words.contains { blob.contains($0) }
    }

    private static let meat = ["beef", "pork", "chicken", "turkey", "lamb", "bacon", "ham", "sausage", "pepperoni", "steak", "veal", "duck", "goat", "prosciutto", "chorizo", "meatball"]
    private static let pork = ["pork", "bacon", "ham", "prosciutto", "lard", "pepperoni", "chorizo"]
    private static let fish = ["fish", "salmon", "tuna", "shrimp", "prawn", "cod", "anchovy", "sardine", "crab", "lobster", "scallop", "clam", "mussel", "oyster"]
    private static let shellfish = ["shrimp", "prawn", "crab", "lobster", "scallop", "clam", "mussel", "oyster"]
    private static let dairy = ["milk", "cheese", "butter", "cream", "yogurt", "ghee", "whey"]
    private static let egg = ["egg"]
    private static let honey = ["honey"]
    private static let gluten = ["flour", "bread", "pasta", "noodle", "wheat", "barley", "rye", "breadcrumb", "couscous", "soy sauce", "pita", "tortilla"]
    private static let nuts = ["peanut", "almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia"]
    private static let soy = ["soy", "tofu", "tempeh", "edamame", "miso"]
    private static let starch = ["rice", "pasta", "potato", "bread", "sugar", "flour", "noodle", "tortilla", "bean", "corn", "couscous"]
    private static let legumes = ["bean", "lentil", "peanut", "chickpea", "soy", "tofu"]
    private static let sugar = ["sugar", "honey", "syrup", "candy", "chocolate", "jam", "molasses"]
    private static let alcohol = ["wine", "beer", "rum", "vodka", "whiskey", "bourbon", "liqueur", "brandy"]
    private static let salty = ["salt", "soy sauce", "bacon", "ham", "bouillon", "broth", "olive"]
}
