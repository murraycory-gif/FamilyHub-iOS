import Foundation
import UIKit

enum RecipeThumbs {
    static func url(for name: String) -> URL? {
        guard let raw = table[name] else { return nil }
        return URL(string: raw)
    }

    static func smallURL(for name: String) -> URL? {
        sized(name, width: 900)
    }

    static func heroURL(for name: String) -> URL? {
        sized(name, width: 1600)
    }

    private static func sized(_ name: String, width: Int) -> URL? {
        guard var raw = table[name] else { return nil }
        if raw.contains("images.unsplash.com"), let r = raw.range(of: "w=") {
            let start = r.upperBound
            let digits = raw[start...].prefix(while: { $0.isNumber })
            raw.replaceSubrange(start..<raw.index(start, offsetBy: digits.count), with: String(width))
        }
        return URL(string: raw)
    }

    private static let table: [String: String] = [
        "Buttermilk Fried Chicken": "https://images.unsplash.com/photo-1562967916-eb82221dfb92?auto=format&fit=crop&w=1200&q=80",
        "Classic Cheeseburgers": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=1200&q=80",
        "BBQ Baby Back Ribs": "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=1200&q=80",
        "Pulled Pork Sandwiches": "https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=1200&q=80",
        "Texas Brisket": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Buffalo Chicken Wings": "https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?auto=format&fit=crop&w=1200&q=80",
        "Meatloaf with Ketchup Glaze": "https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=1200&q=80",
        "Chicken Pot Pie": "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=80",
        "Tuna Noodle Casserole": "https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?auto=format&fit=crop&w=1200&q=80",
        "Green Bean Casserole": "https://images.unsplash.com/photo-1574484284002-952d92456975?auto=format&fit=crop&w=1200&q=80",
        "Macaroni and Cheese": "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=1200&q=80",
        "Chili con Carne": "https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=1200&q=80",
        "Sloppy Joes": "https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=1200&q=80",
        "Cheesesteaks": "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1200&q=80",
        "Club Sandwich": "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1200&q=80",
        "BLT": "https://images.unsplash.com/photo-1574484284002-952d92456975?auto=format&fit=crop&w=1200&q=80",
        "Grilled Cheese and Tomato Soup": "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&w=1200&q=80",
        "Chicken and Dumplings": "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=1200&q=80",
        "Shrimp and Grits": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80",
        "Jambalaya": "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=80",
        "Gumbo": "https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?auto=format&fit=crop&w=1200&q=80",
        "Red Beans and Rice": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Po' Boy": "https://images.unsplash.com/photo-1612874742237-6526221588e3?auto=format&fit=crop&w=1200&q=80",
        "Clam Chowder": "https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=1200&q=80",
        "Lobster Rolls": "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=1200&q=80",
        "Crab Cakes": "https://images.unsplash.com/photo-1572449043416-55f4685c9bb7?auto=format&fit=crop&w=1200&q=80",
        "Fish Fry": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80",
        "Beef Stew": "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&w=1200&q=80",
        "Pot Roast": "https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=1200&q=80",
        "Roast Chicken": "https://images.unsplash.com/photo-1598103442097-8b74394b95c6?auto=format&fit=crop&w=1200&q=80",
        "Sheet Pan Fajitas": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=80",
        "Beef Tacos": "https://images.unsplash.com/photo-1613514785940-daed07799d9b?auto=format&fit=crop&w=1200&q=80",
        "Chicken Enchiladas": "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=1200&q=80",
        "Chicken Quesadillas": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=80",
        "Nachos Supreme": "https://images.unsplash.com/photo-1613514785940-daed07799d9b?auto=format&fit=crop&w=1200&q=80",
        "Burrito Bowls": "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=1200&q=80",
        "Pork Carnitas": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=80",
        "Breakfast-for-Dinner Pancakes": "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=1200&q=80",
        "French Toast": "https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&w=1200&q=80",
        "Biscuits and Sausage Gravy": "https://images.unsplash.com/photo-1484723091739-30a097e8f929?auto=format&fit=crop&w=1200&q=80",
        "Chicken Fried Steak": "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=1200&q=80",
        "Pork Chops and Applesauce": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Stuffed Peppers": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Shepherd's Pie American": "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=1200&q=80",
        "Lasagna": "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=1200&q=80",
        "Spaghetti and Meatballs": "https://images.unsplash.com/photo-1563379926898-05f4575a45d8?auto=format&fit=crop&w=1200&q=80",
        "Baked Ziti": "https://images.unsplash.com/photo-1574894709920-11b28e7367e3?auto=format&fit=crop&w=1200&q=80",
        "Chicken Alfredo": "https://images.unsplash.com/photo-1619895092538-128341789043?auto=format&fit=crop&w=1200&q=80",
        "Pesto Pasta with Chicken": "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=1200&q=80",
        "BBQ Chicken Pizza": "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1200&q=80",
        "Pepperoni Pizza Night": "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?auto=format&fit=crop&w=1200&q=80",
        "Cornbread Chili Bake": "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=80",
        "Hamburgers Helper Style Skillet": "https://images.unsplash.com/photo-1571091718767-18b5b1457add?auto=format&fit=crop&w=1200&q=80",
        "Teriyaki Chicken Bowls": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Honey Garlic Salmon": "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=1200&q=80",
        "Cajun Salmon": "https://images.unsplash.com/photo-1572449043416-55f4685c9bb7?auto=format&fit=crop&w=1200&q=80",
        "Fish Tacos": "https://images.unsplash.com/photo-1613514785940-daed07799d9b?auto=format&fit=crop&w=1200&q=80",
        "Shrimp Scampi": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80",
        "Beef Stir Fry": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Orange Chicken": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "General Tso's at Home": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Loaded Baked Potatoes": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Veggie Chili": "https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?auto=format&fit=crop&w=1200&q=80",
        "Black Bean Burgers": "https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?auto=format&fit=crop&w=1200&q=80",
        "Caesar Salad with Grilled Chicken": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80",
        "Cobb Salad": "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=1200&q=80",
        "BBQ Pulled Chicken": "https://images.unsplash.com/photo-1632778149955-e80f8ceca2e8?auto=format&fit=crop&w=1200&q=80",
        "Smoked Sausage and Peppers": "https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=1200&q=80",
        "Bratwurst and Sauerkraut": "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=1200&q=80",
        "Chicago Dogs": "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1200&q=80",
        "Coney Dogs": "https://images.unsplash.com/photo-1574484284002-952d92456975?auto=format&fit=crop&w=1200&q=80",
        "Philly Roast Pork Sandwich": "https://images.unsplash.com/photo-1612874742237-6526221588e3?auto=format&fit=crop&w=1200&q=80",
        "Italian Beef": "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1200&q=80",
        "Pork Tenderloin Sandwich": "https://images.unsplash.com/photo-1574484284002-952d92456975?auto=format&fit=crop&w=1200&q=80",
        "Open Face Hot Turkey Sandwich": "https://images.unsplash.com/photo-1612874742237-6526221588e3?auto=format&fit=crop&w=1200&q=80",
        "Chicken and Rice Casserole": "https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=1200&q=80",
        "Hashbrown Casserole": "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&w=1200&q=80",
        "Funeral Potatoes": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Corn Casserole": "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=1200&q=80",
        "Thanksgiving Turkey": "https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=1200&q=80",
        "Sausage Stuffing": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Sweet Potato Casserole": "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=80",
        "Ham with Pineapple": "https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=1200&q=80",
        "Corned Beef and Cabbage": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Prime Rib": "https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=1200&q=80",
        "Cedar Plank Salmon": "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=1200&q=80",
        "Surf and Turf": "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=1200&q=80",
        "Meatball Subs": "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=1200&q=80",
        "Chicken Parmesan": "https://images.unsplash.com/photo-1527477396000-e27163b481c2?auto=format&fit=crop&w=1200&q=80",
        "Eggplant Parmesan": "https://images.unsplash.com/photo-1563379926898-05f4575a45d8?auto=format&fit=crop&w=1200&q=80",
        "Stuffed Shells": "https://images.unsplash.com/photo-1574894709920-11b28e7367e3?auto=format&fit=crop&w=1200&q=80",
        "Baked Chicken Tenders": "https://images.unsplash.com/photo-1562967916-eb82221dfb92?auto=format&fit=crop&w=1200&q=80",
        "BBQ Meatloaf": "https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=1200&q=80",
        "Dr Pepper Pulled Pork": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Smash Burgers": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=1200&q=80",
        "Turkey Burgers": "https://images.unsplash.com/photo-1606755962773-d324e0a13086?auto=format&fit=crop&w=1200&q=80",
        "Blackened Catfish": "https://images.unsplash.com/photo-1572449043416-55f4685c9bb7?auto=format&fit=crop&w=1200&q=80",
        "Hush Puppies and Fried Fish": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Collard Greens with Ham": "https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=1200&q=80",
        "Baked Beans": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Coleslaw": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80",
        "Potato Salad": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
        "Macaroni Salad": "https://images.unsplash.com/photo-1619895092538-128341789043?auto=format&fit=crop&w=1200&q=80",
        "Corn on the Cob": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Garlic Mashed Potatoes": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Brown Gravy Pork Chops": "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=1200&q=80",
        "Salisbury Steak": "https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=1200&q=80",
        "Chicken and Stuffing Bake": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Tater Tot Hotdish": "https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?auto=format&fit=crop&w=1200&q=80",
        "Frito Pie": "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=1200&q=80",
        "Walking Tacos": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=80",
        "Seven Layer Dip Night": "https://images.unsplash.com/photo-1613514785940-daed07799d9b?auto=format&fit=crop&w=1200&q=80",
        "White Chicken Chili": "https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=1200&q=80",
        "Chicken Noodle Soup": "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&w=1200&q=80",
        "Tomato Basil Soup and Grilled Cheese": "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=1200&q=80",
        "Broccoli Cheddar Soup": "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=80",
        "French Onion Soup": "https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?auto=format&fit=crop&w=1200&q=80",
        "Crockpot Chicken Tacos": "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=1200&q=80",
        "Crockpot Beef Tips": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Weeknight Tacos Two Ways": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=80",
        "Hawaiian Haystacks": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Chicken Divan": "https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?auto=format&fit=crop&w=1200&q=80",
        "King Ranch Chicken": "https://images.unsplash.com/photo-1598103442097-8b74394b95c6?auto=format&fit=crop&w=1200&q=80",
        "Chicken Tetrazzini": "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=1200&q=80",
        "Beef Stroganoff American": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Swedish Meatballs American Table": "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=1200&q=80",
        "Pigs in a Blanket Dinner": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Breakfast Burritos": "https://images.unsplash.com/photo-1613514785940-daed07799d9b?auto=format&fit=crop&w=1200&q=80",
        "Huevos Rancheros": "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&w=1200&q=80",
        "Chicken and Waffles": "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=1200&q=80",
        "Steak and Potatoes": "https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=1200&q=80",
        "Pork Ribs Oven": "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=1200&q=80",
        "Beer Can Chicken": "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=1200&q=80",
        "Grilled BBQ Chicken": "https://images.unsplash.com/photo-1632778149955-e80f8ceca2e8?auto=format&fit=crop&w=1200&q=80",
        "Cedar BBQ Salmon Burgers": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=1200&q=80",
        "Turkey Club Wrap": "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1200&q=80",
        "Chicken Caesar Wrap": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80",
        "Buffalo Chicken Sandwiches": "https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=1200&q=80",
        "Crispy Chicken Sandwich": "https://images.unsplash.com/photo-1527477396000-e27163b481c2?auto=format&fit=crop&w=1200&q=80",
        "BBQ Pulled Jackfruit": "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=1200&q=80",
        "Mushroom Cheesesteaks": "https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=1200&q=80",
        "Baked Ziti Sausage": "https://images.unsplash.com/photo-1563379926898-05f4575a45d8?auto=format&fit=crop&w=1200&q=80",
        "Sausage, Peppers, and Onions": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Weeknight Roast Salmon and Veg": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80",
        "Honey Mustard Chicken Thighs": "https://images.unsplash.com/photo-1562967916-eb82221dfb92?auto=format&fit=crop&w=1200&q=80",
        "Lemon Pepper Chicken": "https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?auto=format&fit=crop&w=1200&q=80",
        "Garlic Butter Steak Bites": "https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=1200&q=80",
        "Cheeseburger Pasta Skillet": "https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=1200&q=80",
        "Taco Pasta": "https://images.unsplash.com/photo-1574894709920-11b28e7367e3?auto=format&fit=crop&w=1200&q=80",
        "Pizza Pasta Bake": "https://images.unsplash.com/photo-1619895092538-128341789043?auto=format&fit=crop&w=1200&q=80",
        "Ranch Chicken Bacon Bake": "https://images.unsplash.com/photo-1598103442097-8b74394b95c6?auto=format&fit=crop&w=1200&q=80",
        "Mississippi Pot Roast": "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=1200&q=80",
        "Mississippi Chicken": "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=1200&q=80",
        "Coke Ham": "https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=1200&q=80",
        "Root Beer Pulled Pork": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Sunday Gravy with Sausage and Meatballs": "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=1200&q=80",
        "Baked Mostaccioli": "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=1200&q=80",
        "Chicken Cordon Bleu Bake": "https://images.unsplash.com/photo-1632778149955-e80f8ceca2e8?auto=format&fit=crop&w=1200&q=80",
        "Reuben Skillet": "https://images.unsplash.com/photo-1574484284002-952d92456975?auto=format&fit=crop&w=1200&q=80",
        "Patty Melt": "https://images.unsplash.com/photo-1571091718767-18b5b1457add?auto=format&fit=crop&w=1200&q=80",
        "Tuna Melts": "https://images.unsplash.com/photo-1612874742237-6526221588e3?auto=format&fit=crop&w=1200&q=80",
        "Salmon Patties": "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=1200&q=80",
        "Chicken Bog": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Hoppin' John": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Chicken Bog Bowl": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Mashed Potatoes": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Roasted Potatoes": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "French Fries": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Sweet Potato Fries": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Scalloped Potatoes": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Creamed Corn": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Roasted Broccoli": "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=1200&q=80",
        "Roasted Carrots": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80",
        "Asparagus": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
        "Sauteed Green Beans": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80",
        "Cornbread": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Garlic Bread": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Dinner Rolls": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Biscuits": "https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&w=1200&q=80",
        "House Salad": "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=1200&q=80",
        "Caesar Salad": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80",
        "Wedge Salad": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
        "Fruit Salad": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80",
        "Onion Rings": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Tater Tots": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Rice Pilaf": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "White Rice": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Stuffing": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Cranberry Sauce": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Applesauce": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Gravy": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Collard Greens": "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=1200&q=80",
        "Fried Okra": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Hush Puppies": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Deviled Eggs": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Pickles": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Baked Macaroni": "https://images.unsplash.com/photo-1563379926898-05f4575a45d8?auto=format&fit=crop&w=1200&q=80",
        "Creamed Spinach": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80",
        "Brussels Sprouts": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
        "Cucumber Salad": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80",
        "Three Bean Salad": "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=1200&q=80",
        "Corn Salad": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80",
        "Texas Toast": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Cheddar Biscuits": "https://images.unsplash.com/photo-1484723091739-30a097e8f929?auto=format&fit=crop&w=1200&q=80",
        "Slaw Mix": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
        "Potato Wedges": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Elote": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Refried Beans": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Spanish Rice": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Margherita Pizza": "https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=1200&q=80",
        "Spaghetti Carbonara": "https://images.unsplash.com/photo-1574894709920-11b28e7367e3?auto=format&fit=crop&w=1200&q=80",
        "Lasagna Bolognese": "https://images.unsplash.com/photo-1619895092538-128341789043?auto=format&fit=crop&w=1200&q=80",
        "Risotto Milanese": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Osso Buco": "https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?auto=format&fit=crop&w=1200&q=80",
        "Chicken Tikka Masala": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Butter Chicken": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Chana Masala": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Vegetable Biryani": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Pad Thai": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Green Curry Chicken": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Tom Yum Soup": "https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=1200&q=80",
        "Sushi Bowls": "https://images.unsplash.com/photo-1572449043416-55f4685c9bb7?auto=format&fit=crop&w=1200&q=80",
        "Chicken Teriyaki": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Ramen Night": "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&w=1200&q=80",
        "Beef Tacos al Pastor": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=80",
        "Chicken Mole": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Carne Asada": "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=1200&q=80",
        "Pozole Rojo": "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=1200&q=80",
        "Coq au Vin": "https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=1200&q=80",
        "Steak Frites": "https://images.unsplash.com/photo-1432139509613-5c4255815697?auto=format&fit=crop&w=1200&q=80",
        "Ratatouille": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80",
        "Croque Monsieur": "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=1200&q=80",
        "Chicken Souvlaki": "https://images.unsplash.com/photo-1527477396000-e27163b481c2?auto=format&fit=crop&w=1200&q=80",
        "Moussaka": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Greek Lemon Chicken": "https://images.unsplash.com/photo-1562967916-eb82221dfb92?auto=format&fit=crop&w=1200&q=80",
        "Paella": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Garlic Shrimp": "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=1200&q=80",
        "Beef Empanadas": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Jerk Chicken": "https://images.unsplash.com/photo-1626645738196-c2a7c87a8f58?auto=format&fit=crop&w=1200&q=80",
        "Moroccan Chicken Tagine": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Beef Pho": "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=80",
        "Banh Mi": "https://images.unsplash.com/photo-1574484284002-952d92456975?auto=format&fit=crop&w=1200&q=80",
        "Korean Beef Bowls": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Bibimbap": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Falafel Plates": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Chicken Shawarma": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Shakshuka": "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&w=1200&q=80",
        "Lamb Kofta": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Mapo Tofu": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Kung Pao Chicken": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Beef and Broccoli": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Sweet and Sour Chicken": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Fish and Chips": "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=1200&q=80",
        "Shepherd's Pie": "https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?auto=format&fit=crop&w=1200&q=80",
        "Chicken Tikka Wraps": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Tacos al Carbon": "https://images.unsplash.com/photo-1613514785940-daed07799d9b?auto=format&fit=crop&w=1200&q=80",
        "Cacio e Pepe": "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=1200&q=80",
        "Gnocchi with Sage Butter": "https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=1200&q=80",
        "Naan": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Basmati Rice": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Hummus": "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=1200&q=80",
        "Tzatziki": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80",
        "Tabbouleh": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
        "Couscous": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Polenta": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
        "Garlic Naan": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Spring Rolls": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Kimchi": "https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=1200&q=80",
        "Miso Soup": "https://images.unsplash.com/photo-1529042410759-befb1204b468?auto=format&fit=crop&w=1200&q=80",
        "Edamame": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80",
        "Sesame Cucumber Salad": "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=1200&q=80",
        "Mexican Rice": "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        "Pico de Gallo": "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=1200&q=80",
        "Guacamole": "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=80",
        "Patatas Bravas": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80",
        "Focaccia": "https://images.unsplash.com/photo-1476224203421-9ac39bcb3327?auto=format&fit=crop&w=1200&q=80",
        "Caprese": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80",
        "French Green Beans": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
        "Greek Salad": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=1200&q=80",
        "Labneh": "https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=1200&q=80",
        "Pickled Vegetables": "https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1200&q=80",
        "Coconut Rice": "https://images.unsplash.com/photo-1516684669134-de6f7c473a2a?auto=format&fit=crop&w=1200&q=80",
        "Mango Salsa": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80",
    ]
}

enum RecipePhotoLoader {
    enum Quality { case card, hero }

    private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()
    private static let gate = PhotoGate(limit: 2)
    private static let folder: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecipeThumbsV3", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func cached(name: String, quality: Quality = .card) -> UIImage? {
        let key = cacheKey(name, quality) as NSString
        if let hit = memory.object(forKey: key) { return hit }
        let file = folder.appendingPathComponent(slug(cacheKey(name, quality)) + ".jpg")
        guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key)
        return image
    }

    static func image(name: String, quality: Quality = .card) async -> UIImage? {
        if let hit = cached(name: name, quality: quality) { return hit }
        let remote = quality == .hero ? RecipeThumbs.heroURL(for: name) : RecipeThumbs.smallURL(for: name)
        guard let url = remote else { return nil }
        return await gate.run {
            if let hit = cached(name: name, quality: quality) { return hit }
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("HUB/1.0", forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
                  let image = UIImage(data: data),
                  image.size.width > 80
            else { return nil }
            let key = cacheKey(name, quality) as NSString
            memory.setObject(image, forKey: key)
            if let jpeg = image.jpegData(compressionQuality: 0.92) {
                try? jpeg.write(to: folder.appendingPathComponent(slug(cacheKey(name, quality)) + ".jpg"), options: .atomic)
            }
            return image
        }
    }

    private static func cacheKey(_ name: String, _ quality: Quality) -> String {
        quality == .hero ? name + "#hero" : name
    }

    private static func slug(_ name: String) -> String {
        let raw = name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : Character("-") }
        var compact = String(raw)
        while compact.contains("--") { compact = compact.replacingOccurrences(of: "--", with: "-") }
        return compact.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private actor PhotoGate {
    private var running = 0
    private let limit: Int
    init(limit: Int) { self.limit = limit }
    func run<T>(_ work: () async -> T) async -> T {
        while running >= limit {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        running += 1
        defer { running -= 1 }
        return await work()
    }
}
