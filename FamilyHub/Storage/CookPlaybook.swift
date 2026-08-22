import Foundation

enum CookPlaybook {
    enum Family: String {
        case fries, rings, mash, roastVeg, salad, bread, grillMeat, casserole
        case soup, rice, beans, corn, pasta, eggs, dessert, general
    }

    static func methods(name: String, category: String = "", instructions: String = "") -> [CookMethod] {
        let family = detect(name: name, category: category)
        var allowed = Set(family.methods)
        if family == .general {
            let blob = instructions.lowercased()
            if blob.contains("grill") { allowed.insert(.grill) }
            if blob.contains("air fry") { allowed.insert(.airFryer) }
            if blob.contains("slow cook") || blob.contains("crock") { allowed.insert(.slowCooker) }
            if blob.contains("pressure") || blob.contains("instant") { allowed.insert(.instantPot) }
            if blob.contains("broil") { allowed.insert(.broiler) }
            if blob.contains("smoke") { allowed.insert(.smoker) }
            if blob.contains("deep fry") { allowed.insert(.deepFry) }
        }
        let order = CookMethod.allCases.filter { allowed.contains($0) }
        return order.isEmpty ? [.oven, .stovetop, .airFryer] : order
    }

    static func directions(name: String, method: CookMethod, recipeSteps: String) -> String {
        let family = detect(name: name, category: "")
        if let specific = template(family: family, method: method, name: name) {
            return specific
        }
        if originalFits(method, recipeSteps) {
            return method.howTo + "\n\n" + recipeSteps
        }
        return method.howTo + "\n\nUse this method for \(name). Cook until hot through and safe to eat."
    }

    static func suggested(name: String, category: String = "", instructions: String = "") -> CookMethod {
        methods(name: name, category: category, instructions: instructions).first ?? .oven
    }

    private static func detect(name: String, category: String) -> Family {
        let t = (name + " " + category).lowercased()
        if t.contains("fries") || t.contains("tater") || t.contains("tot") || t.contains("wedge") { return .fries }
        if t.contains("onion ring") || t.contains("hush puppy") || t.contains("fried okra") { return .rings }
        if t.contains("mash") || t.contains("mashed") { return .mash }
        if t.contains("salad") || t.contains("slaw") || t.contains("pickle") { return .salad }
        if t.contains("soup") || t.contains("chili") || t.contains("stew") || t.contains("gravy") { return .soup }
        if t.contains("rice") || t.contains("pilaf") { return .rice }
        if t.contains("bean") { return .beans }
        if t.contains("corn") || t.contains("elote") { return .corn }
        if t.contains("mac") || t.contains("pasta") || t.contains("noodle") { return .pasta }
        if t.contains("biscuit") || t.contains("roll") || t.contains("bread") || t.contains("toast") || t.contains("cornbread") { return .bread }
        if t.contains("casserole") || t.contains("scallop") || t.contains("bake") { return .casserole }
        if t.contains("egg") || t.contains("deviled") { return .eggs }
        if t.contains("burger") || t.contains("steak") || t.contains("chop") || t.contains("chicken") || t.contains("rib") || t.contains("hot dog") || t.contains("brisket") || t.contains("turkey") || t.contains("pork") { return .grillMeat }
        if t.contains("broccoli") || t.contains("carrot") || t.contains("asparagus") || t.contains("brussels") || t.contains("green bean") || t.contains("veg") { return .roastVeg }
        return .general
    }

    private static func originalFits(_ method: CookMethod, _ steps: String) -> Bool {
        let t = steps.lowercased()
        switch method {
        case .grill: return t.contains("grill")
        case .oven: return t.contains("bake") || t.contains("oven") || t.contains("roast")
        case .stovetop: return t.contains("skillet") || t.contains("pan") || t.contains("boil") || t.contains("simmer") || t.contains("saute")
        case .airFryer: return t.contains("air fry")
        case .deepFry: return t.contains("fry") && t.contains("oil")
        case .slowCooker: return t.contains("slow") || t.contains("crock")
        case .instantPot: return t.contains("pressure") || t.contains("instant")
        case .smoker: return t.contains("smoke")
        case .broiler: return t.contains("broil")
        case .microwave: return t.contains("microwave")
        }
    }

    private static func template(family: Family, method: CookMethod, name: String) -> String? {
        switch family {
        case .fries:
            switch method {
            case .oven: return "Cut into fries. Soak 20 minutes, dry well, toss with oil and salt. Spread on a sheet pan. Bake 425°F 25–35 minutes, flipping once, until golden and crisp."
            case .airFryer: return "Toss fries with a little oil and salt. Air fry 380°F 12–18 minutes. Shake twice. Cook until crisp. Don’t crowd the basket."
            case .deepFry: return "Heat oil to 325°F. Fry in small batches until pale, 3–4 minutes. Drain. Raise oil to 375°F and fry again until golden. Salt while hot."
            default: return nil
            }
        case .rings:
            switch method {
            case .deepFry: return "Dredge in flour or batter. Heat oil to 350°F. Fry in small batches until golden, 2–3 minutes. Drain and salt."
            case .airFryer: return "Spray breaded pieces with oil. Air fry 400°F 8–12 minutes, flipping once, until crisp."
            case .oven: return "Bread, spray with oil, bake 425°F 15–20 minutes on a rack, flipping once, until crisp."
            default: return nil
            }
        case .mash:
            switch method {
            case .stovetop: return "Peel and cube. Cover with cold salted water. Boil until tender, 15–20 minutes. Drain well. Mash with butter and warm milk. Salt and pepper."
            case .instantPot: return "Cubed potatoes + 1 cup water. High pressure 8 minutes, quick release. Drain. Mash with butter and milk."
            case .oven: return "Bake whole potatoes 400°F 50–60 minutes until soft. Scoop, mash with butter and milk. Optional: brown the top under the broiler 2 minutes."
            case .microwave: return "Cube, cover, microwave 8–12 minutes until tender, stirring once. Mash with butter and milk."
            default: return nil
            }
        case .roastVeg:
            switch method {
            case .oven: return "Toss with oil, salt, and pepper. Roast 425°F 18–25 minutes until browned and tender. Finish with lemon or vinegar."
            case .airFryer: return "Toss with oil and salt. Air fry 390°F 10–16 minutes, shaking once, until browned."
            case .stovetop: return "Heat oil in a wide skillet. Sear, then add a splash of water and cover 4–6 minutes until tender. Uncover to evaporate."
            case .grill: return "Toss with oil. Grill over medium-high in a basket or on foil, turning, until charred and tender."
            case .microwave: return "Add a splash of water, cover, microwave 4–7 minutes until just tender. Season."
            default: return nil
            }
        case .salad:
            switch method {
            case .stovetop: return "If a component needs heat (bacon, croutons, dressing reduction), cook that in a skillet first. Cool, then toss with the rest. Don’t heat leafy greens."
            default: return nil
            }
        case .bread:
            switch method {
            case .oven: return "Bake on a sheet or in a pan at 375–400°F until browned and cooked through. Brush with butter while hot."
            case .grill: return "Slice, butter, grill over medium until toasted and marked. Watch close — bread burns fast."
            case .broiler: return "Butter the cut side. Broil 1–3 minutes until golden. Don’t walk away."
            case .airFryer: return "Air fry 350°F 4–8 minutes until toasted."
            case .stovetop: return "Toast in a dry or buttered skillet over medium, flipping once."
            default: return nil
            }
        case .grillMeat:
            switch method {
            case .grill: return "Preheat grill medium-high. Oil the grates. Sear both sides, then finish over indirect heat if thick. Rest 5 minutes. Cook to a safe temperature."
            case .stovetop: return "Preheat a heavy skillet until hot. Oil. Sear both sides. Lower heat to finish through. Rest 5 minutes."
            case .oven: return "Sear in an oven-safe pan, then roast 400°F until the center is done. Rest 5 minutes."
            case .airFryer: return "Pat dry, oil, season. Air fry 375°F, flipping once, until the center is done. Rest 5 minutes."
            case .broiler: return "Rack 6 inches from broiler. Broil, flipping once, until browned and done. Rest 5 minutes."
            case .smoker: return "Smoke 225–250°F until tender and at a safe temperature. Rest before slicing."
            default: return nil
            }
        case .casserole:
            switch method {
            case .oven: return "Assemble in a baking dish. Bake 350–375°F until bubbling and browned on top, usually 25–45 minutes."
            case .slowCooker: return "Grease the crock. Add the mix. Cook LOW 4–6 hours or HIGH 2–3 hours until hot and set."
            case .stovetop: return "Cook in a wide covered skillet on medium-low until bubbling and the starch is tender. Brown the top under a broiler if you want crust."
            default: return nil
            }
        case .soup:
            switch method {
            case .stovetop: return "Sweat aromatics, add liquid and the rest. Simmer until flavors come together and everything is tender. Salt at the end."
            case .slowCooker: return "Add everything to the crock. LOW 6–8 hours or HIGH 3–4 hours. Don’t lift the lid early."
            case .instantPot: return "Sauté aromatics. Add liquid. High pressure 10–20 minutes depending on the meat. Natural release 10 minutes."
            default: return nil
            }
        case .rice:
            switch method {
            case .stovetop: return "Rinse. 1 part rice to 2 parts water. Simmer covered 15–18 minutes. Rest 5 minutes, fluff."
            case .instantPot: return "1:1 rice to water. High pressure 4 minutes (white) or 22 minutes (brown). Natural release 10 minutes."
            case .oven: return "Rice + boiling liquid in a covered dish. 375°F 25–35 minutes. Rest 5, fluff."
            case .microwave: return "Rice + water in a large bowl. Microwave covered ~18 minutes, rest 5, fluff."
            default: return nil
            }
        case .beans:
            switch method {
            case .stovetop: return "Simmer with onion, fat, and seasoning until thick and creamy, 20–45 minutes for canned, longer for dry."
            case .slowCooker: return "Canned: LOW 3–4 hours. Dry beans: soaked, LOW 8 hours with enough liquid."
            case .oven: return "Mix in a baking dish. Bake 350°F 40–50 minutes until bubbly and thick."
            case .instantPot: return "Canned: pressure 5 minutes. Dry: unsoaked 30–40 minutes high pressure with plenty of liquid."
            default: return nil
            }
        case .corn:
            switch method {
            case .grill: return "Husk or peel back silk. Oil. Grill medium-high 10–12 minutes, turning, until charred in spots. Butter and salt."
            case .stovetop: return "Boil 6 minutes or steam 8. Drain. Butter and salt."
            case .oven: return "Wrap in foil with butter. 400°F 20–25 minutes."
            case .microwave: return "In husk, microwave 3–4 minutes per ear. Let stand 1 minute. Husk, butter, salt."
            case .airFryer: return "Oil the ears. Air fry 400°F 8–12 minutes, turning once."
            default: return nil
            }
        case .pasta:
            switch method {
            case .stovetop: return "Boil salted water. Cook pasta until just tender. Drain, sauce in the pan, toss. Cheese off heat if it would break."
            case .oven: return "Boil pasta shy of done. Mix with sauce and cheese. Bake 375°F 20–25 minutes until bubbling."
            case .slowCooker: return "Only for recipes built for it. Pasta goes in at the end on HIGH 15–25 minutes so it doesn’t turn to mush."
            default: return nil
            }
        case .eggs:
            switch method {
            case .stovetop: return "For hard-cooked: cover with water, boil, then off heat 10–12 minutes. Ice bath. For scramble/fry: medium skillet, don’t overcook."
            case .oven: return "Baked eggs or a casserole: 350°F until just set in the center."
            case .instantPot: return "Eggs on a rack, 1 cup water. High pressure 5 minutes, 5 minute natural, ice bath."
            default: return nil
            }
        case .dessert, .general:
            return nil
        }
    }
}

private extension CookPlaybook.Family {
    var methods: [CookMethod] {
        switch self {
        case .fries: return [.oven, .airFryer, .deepFry]
        case .rings: return [.deepFry, .airFryer, .oven]
        case .mash: return [.stovetop, .instantPot, .oven, .microwave]
        case .roastVeg: return [.oven, .airFryer, .stovetop, .grill, .microwave]
        case .salad: return [.stovetop]
        case .bread: return [.oven, .grill, .broiler, .airFryer, .stovetop]
        case .grillMeat: return [.grill, .stovetop, .oven, .airFryer, .broiler, .smoker]
        case .casserole: return [.oven, .slowCooker, .stovetop]
        case .soup: return [.stovetop, .slowCooker, .instantPot]
        case .rice: return [.stovetop, .instantPot, .oven, .microwave]
        case .beans: return [.stovetop, .slowCooker, .oven, .instantPot]
        case .corn: return [.grill, .stovetop, .oven, .microwave, .airFryer]
        case .pasta: return [.stovetop, .oven, .slowCooker]
        case .eggs: return [.stovetop, .oven, .instantPot]
        case .dessert, .general: return [.oven, .stovetop, .airFryer, .grill]
        }
    }
}
