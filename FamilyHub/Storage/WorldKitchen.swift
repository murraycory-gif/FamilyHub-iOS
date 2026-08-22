import Foundation

enum WorldKitchen {
    static let recipes: [CatalogRecipe] = raw.enumerated().map { index, item in
        CatalogRecipe(
            id: "world-\(index + 1)",
            name: item.0,
            category: item.1,
            area: item.1,
            thumb: nil,
            instructions: item.3,
            ingredients: item.2,
            sourceURL: nil,
            youtubeURL: nil
        )
    }

    private static let raw: [(String, String, [String], String)] = [
        ("Margherita Pizza", "Italian", ["Pizza dough", "San Marzano tomatoes", "Fresh mozzarella", "Basil", "Olive oil"], "Stretch dough. Sauce, torn mozzarella. 500°F 10 minutes. Basil and oil."),
        ("Spaghetti Carbonara", "Italian", ["1 lb spaghetti", "6 oz guanciale", "4 egg yolks", "Pecorino", "Black pepper"], "Crisp guanciale. Pasta. Off heat toss yolks, cheese, pepper, pasta water."),
        ("Chicken Parmesan", "Italian", ["4 chicken cutlets", "Marinara", "Mozzarella", "Parmesan", "Breadcrumbs"], "Bread and pan fry cutlets. Sauce and cheese. Broil until melted."),
        ("Lasagna Bolognese", "Italian", ["Bolognese", "Béchamel", "Lasagna noodles", "Parmesan"], "Layer sauce, noodles, béchamel. 375°F 45 minutes. Rest 15."),
        ("Risotto Milanese", "Italian", ["Arborio rice", "Saffron", "Onion", "White wine", "Parmesan", "Stock"], "Toast rice, wine, ladle stock stirring 18 minutes. Butter and cheese."),
        ("Osso Buco", "Italian", ["Veal shanks", "Onion, carrot, celery", "White wine", "Tomatoes", "Gremolata"], "Brown shanks. Braise with veg and wine 2 hours. Gremolata."),
        ("Chicken Tikka Masala", "Indian", ["Chicken thighs", "Yogurt", "Tikka spices", "Tomato cream sauce"], "Marinate chicken, broil. Simmer in spiced tomato cream. Rice."),
        ("Butter Chicken", "Indian", ["Chicken", "Butter", "Tomato", "Cream", "Garam masala"], "Simmer sauce. Add cooked chicken. Serve with naan."),
        ("Chana Masala", "Indian", ["Chickpeas", "Onion", "Tomato", "Garam masala", "Ginger garlic"], "Sauté onion and spices. Chickpeas and tomato 20 minutes."),
        ("Vegetable Biryani", "Indian", ["Basmati", "Mixed veg", "Biryani spices", "Yogurt", "Fried onions"], "Layer par-cooked rice and veg. Steam 20 minutes."),
        ("Pad Thai", "Thai", ["Rice noodles", "Shrimp or tofu", "Tamarind sauce", "Egg", "Peanuts", "Bean sprouts"], "Soak noodles. Hot wok sauce, egg, protein, noodles, sprouts, peanuts."),
        ("Green Curry Chicken", "Thai", ["Green curry paste", "Coconut milk", "Chicken", "Thai basil", "Eggplant"], "Fry paste, coconut milk, chicken 12 minutes. Basil. Rice."),
        ("Tom Yum Soup", "Thai", ["Shrimp", "Lemongrass", "Lime", "Chili", "Mushrooms"], "Boil aromatics. Shrimp last 2 minutes. Lime and chili."),
        ("Sushi Bowls", "Japanese", ["Sushi rice", "Salmon or tofu", "Avocado", "Cucumber", "Nori", "Soy"], "Season rice. Bowl toppings. Soy and sesame."),
        ("Chicken Teriyaki", "Japanese", ["Chicken thighs", "Soy", "Mirin", "Sugar", "Ginger"], "Pan cook chicken. Reduce teriyaki, glaze. Rice."),
        ("Ramen Night", "Japanese", ["Ramen noodles", "Broth", "Soft egg", "Pork or mushrooms", "Scallion"], "Heat broth. Noodles. Toppings."),
        ("Beef Tacos al Pastor", "Mexican", ["Pork or beef", "Achiote", "Pineapple", "Tortillas", "Onion", "Cilantro"], "Marinate, grill, chop. Pineapple. Tortillas."),
        ("Chicken Mole", "Mexican", ["Chicken", "Mole sauce", "Sesame", "Rice"], "Simmer chicken in mole 25 minutes. Sesame. Rice."),
        ("Carne Asada", "Mexican", ["Flank steak", "Citrus", "Garlic", "Cumin", "Tortillas"], "Marinate, grill high heat. Slice. Tortillas."),
        ("Pozole Rojo", "Mexican", ["Pork", "Hominy", "Red chile", "Cabbage", "Radish", "Lime"], "Simmer pork and chile. Hominy. Toppings."),
        ("Coq au Vin", "French", ["Chicken", "Red wine", "Bacon", "Mushrooms", "Onion"], "Brown chicken and bacon. Wine braise 45 minutes. Mushrooms."),
        ("Steak Frites", "French", ["Steak", "Butter", "Fries", "Parsley"], "Sear steak. Butter baste. Hot fries."),
        ("Ratatouille", "French", ["Zucchini", "Eggplant", "Tomato", "Pepper", "Herbs"], "Sauté veg separately, combine tomato 20 minutes."),
        ("Croque Monsieur", "French", ["Bread", "Ham", "Gruyere", "Béchamel"], "Sandwich, béchamel, cheese. Broil gold."),
        ("Chicken Souvlaki", "Greek", ["Chicken", "Lemon", "Oregano", "Pita", "Tzatziki"], "Marinate, grill skewers. Pita and tzatziki."),
        ("Moussaka", "Greek", ["Eggplant", "Lamb", "Tomato", "Béchamel"], "Layer eggplant, meat, béchamel. 350°F 40 minutes."),
        ("Greek Lemon Chicken", "Greek", ["Chicken", "Lemon", "Oregano", "Potatoes", "Olive oil"], "Roast chicken and potatoes 425°F 50 minutes."),
        ("Paella", "Spanish", ["Bomba rice", "Saffron", "Chicken", "Shrimp", "Peas"], "Sofrito, rice, stock, don't stir. Protein last. Socarrat."),
        ("Garlic Shrimp", "Spanish", ["Shrimp", "Garlic", "Olive oil", "Chili", "Paprika"], "Sizzle garlic oil, shrimp 2 minutes. Bread."),
        ("Beef Empanadas", "Spanish", ["Empanada dough", "Ground beef", "Onion", "Cumin", "Olives"], "Fill, crimp, bake 400°F 20 minutes."),
        ("Jerk Chicken", "Jamaican", ["Chicken", "Jerk paste", "Lime", "Allspice"], "Rub, grill or roast 400°F 40 minutes."),
        ("Moroccan Chicken Tagine", "Moroccan", ["Chicken", "Preserved lemon", "Olives", "Cumin", "Cinnamon"], "Low simmer 45 minutes. Couscous."),
        ("Beef Pho", "Vietnamese", ["Rice noodles", "Beef broth", "Star anise", "Beef slices", "Herbs"], "Simmer broth. Noodles. Thin beef, herbs, lime."),
        ("Banh Mi", "Vietnamese", ["Baguette", "Pork or tofu", "Pickled carrot", "Cilantro", "Mayo"], "Fill baguette. Pickles and herbs."),
        ("Korean Beef Bowls", "Korean", ["Ground beef", "Soy", "Garlic", "Ginger", "Rice", "Kimchi"], "Brown beef with sauce 8 minutes. Rice and kimchi."),
        ("Bibimbap", "Korean", ["Rice", "Veg", "Egg", "Gochujang", "Beef"], "Bowl rice, veg, egg, sauce. Mix."),
        ("Falafel Plates", "Mediterranean", ["Chickpeas", "Herbs", "Spices", "Pita", "Tahini"], "Pulse, fry balls. Pita and tahini."),
        ("Chicken Shawarma", "Mediterranean", ["Chicken", "Shawarma spices", "Yogurt", "Pita"], "Roast spiced chicken. Pita, salad, sauce."),
        ("Shakshuka", "Mediterranean", ["Tomatoes", "Peppers", "Eggs", "Cumin", "Feta"], "Simmer sauce, crack eggs, cover 6 minutes."),
        ("Lamb Kofta", "Mediterranean", ["Ground lamb", "Onion", "Cumin", "Parsley", "Yogurt"], "Form, grill. Yogurt sauce."),
        ("Mapo Tofu", "Chinese", ["Tofu", "Pork", "Doubanjiang", "Sichuan pepper"], "Sauce, tofu 5 minutes. Rice."),
        ("Kung Pao Chicken", "Chinese", ["Chicken", "Peanuts", "Chili", "Soy", "Vinegar"], "Hot wok chicken, sauce, peanuts. Rice."),
        ("Beef and Broccoli", "Chinese", ["Flank steak", "Broccoli", "Oyster sauce", "Garlic"], "High heat steak, broccoli, sauce. Rice."),
        ("Sweet and Sour Chicken", "Chinese", ["Chicken", "Pineapple", "Pepper", "Sweet sour sauce"], "Crisp chicken, toss sauce. Rice."),
        ("Fish and Chips", "British", ["Cod", "Beer batter", "Fries", "Mushy peas"], "Fry fish 350°F. Chips. Peas."),
        ("Shepherd's Pie", "British", ["Lamb", "Veg", "Gravy", "Mashed potatoes"], "Meat base, mash top, broil."),
        ("Chicken Tikka Wraps", "Indian", ["Tikka chicken", "Naan", "Onion", "Cilantro", "Yogurt"], "Warm naan, fill chicken and sauce."),
        ("Tacos al Carbon", "Mexican", ["Skirt steak", "Lime", "Tortillas", "Salsa"], "Grill steak, chop, tortillas."),
        ("Cacio e Pepe", "Italian", ["Tonarelli", "Pecorino", "Black pepper"], "Pasta water, cheese, pepper emulsion."),
        ("Gnocchi with Sage Butter", "Italian", ["Potato gnocchi", "Butter", "Sage", "Parmesan"], "Boil gnocchi. Sage brown butter. Toss.")
    ]
}

enum WorldSides {
    static let recipes: [CatalogRecipe] = raw.enumerated().map { index, item in
        CatalogRecipe(
            id: "wside-\(index + 1)",
            name: item.0,
            category: item.1,
            area: item.1,
            thumb: nil,
            instructions: item.3,
            ingredients: item.2,
            sourceURL: nil,
            youtubeURL: nil
        )
    }

    private static let raw: [(String, String, [String], String)] = [
        ("Naan", "World", ["Flour", "Yogurt", "Yeast", "Ghee"], "Dough rise. Skillet blister. Ghee."),
        ("Basmati Rice", "World", ["Basmati", "Salt", "Butter"], "Rinse. 1:1.5 water. Steam 15."),
        ("Hummus", "World", ["Chickpeas", "Tahini", "Lemon", "Garlic"], "Blend smooth. Olive oil."),
        ("Tzatziki", "World", ["Yogurt", "Cucumber", "Garlic", "Dill"], "Grate cucumber, mix yogurt."),
        ("Tabbouleh", "World", ["Parsley", "Bulgur", "Tomato", "Lemon"], "Chop fine. Lemon and oil."),
        ("Couscous", "World", ["Couscous", "Stock", "Butter"], "Pour hot stock. Rest 5. Fluff."),
        ("Polenta", "World", ["Cornmeal", "Stock", "Parmesan", "Butter"], "Whisk simmer 20 minutes."),
        ("Garlic Naan", "World", ["Naan dough", "Garlic butter"], "Cook naan. Brush garlic butter."),
        ("Spring Rolls", "World", ["Rice paper", "Veg", "Herbs", "Noodles"], "Soak paper, roll fillings."),
        ("Kimchi", "World", ["Jar kimchi"], "Serve cold with the plate."),
        ("Miso Soup", "World", ["Dashi", "Miso", "Tofu", "Scallion"], "Don't boil miso. Tofu and scallion."),
        ("Edamame", "World", ["Edamame", "Salt"], "Boil 5 minutes. Salt."),
        ("Sesame Cucumber Salad", "World", ["Cucumber", "Rice vinegar", "Sesame"], "Slice, dress, chill."),
        ("Mexican Rice", "World", ["Rice", "Tomato sauce", "Onion", "Cumin"], "Toast rice. Sauce and water 18 minutes."),
        ("Pico de Gallo", "World", ["Tomato", "Onion", "Jalapeño", "Lime", "Cilantro"], "Chop, salt, lime."),
        ("Guacamole", "World", ["Avocado", "Lime", "Onion", "Cilantro"], "Mash chunky. Lime."),
        ("Patatas Bravas", "World", ["Potatoes", "Bravas sauce", "Aioli"], "Roast cubes. Sauce."),
        ("Focaccia", "World", ["Dough", "Olive oil", "Rosemary"], "Dimple, oil, 425°F 20 minutes."),
        ("Caprese", "World", ["Tomato", "Mozzarella", "Basil", "Balsamic"], "Slice, salt, oil, balsamic."),
        ("French Green Beans", "World", ["Haricots verts", "Butter", "Shallot"], "Blanch, sauté shallot."),
        ("Greek Salad", "World", ["Cucumber", "Tomato", "Feta", "Olive", "Oregano"], "Chunk, dress olive oil."),
        ("Labneh", "World", ["Yogurt", "Olive oil", "Za'atar"], "Strain yogurt. Oil and za'atar."),
        ("Pickled Vegetables", "World", ["Veg", "Vinegar", "Sugar", "Salt"], "Heat brine. Pour over veg. Chill."),
        ("Coconut Rice", "World", ["Rice", "Coconut milk", "Salt"], "Cook rice in coconut milk."),
        ("Mango Salsa", "World", ["Mango", "Lime", "Jalapeño", "Cilantro"], "Dice, toss lime.")
    ]
}

enum MealEase {
    static func tags(name: String, category: String) -> [String] {
        var tags = [category]
        let n = name.lowercased()
        let quick = [
            "taco", "quesadilla", "grilled cheese", "blt", "nacho", "burger", "sandwich",
            "pasta", "scampi", "stir", "fajita", "pancake", "toast", "salad", "soup",
            "chili", "sloppy", "macaroni", "burrito", "pizza", "ramen", "fried rice",
            "wrap", "carbonara", "cacio", "shawarma", "shakshuka", "teriyaki", "pad thai",
            "hummus", "edamame", "pico", "guacamole", "caprese", "miso"
        ]
        if category == "Weeknight" || quick.contains(where: { n.contains($0) }) {
            tags.append("Quick")
            tags.append("Easy")
        } else if category == "Diner" || n.contains("sheet pan") || n.contains("one pot") {
            tags.append("Easy")
        }
        return tags
    }
}
