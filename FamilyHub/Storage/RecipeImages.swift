import Foundation
import UIKit

enum RecipeThumbs {
    static func url(for name: String) -> URL? {
        guard let raw = table[name] else { return nil }
        return URL(string: raw)
    }

    static func smallURL(for name: String) -> URL? {
        guard let url = url(for: name) else { return nil }
        if url.host?.contains("themealdb.com") == true {
            return url.appendingPathComponent("small")
        }
        return url
    }

    private static let table: [String: String] = [
        "Buttermilk Fried Chicken": "https://www.themealdb.com/images/media/meals/sypxpx1515365095.jpg",
        "Classic Cheeseburgers": "https://www.themealdb.com/images/media/meals/44bzep1761848278.jpg",
        "BBQ Baby Back Ribs": "https://www.themealdb.com/images/media/meals/om5hsl1764364721.jpg",
        "Pulled Pork Sandwiches": "https://www.themealdb.com/images/media/meals/tzsy461763769901.jpg",
        "Texas Brisket": "https://www.themealdb.com/images/media/meals/ursuup1487348423.jpg",
        "Buffalo Chicken Wings": "https://www.themealdb.com/images/media/meals/feh9k21784665694.jpg",
        "Meatloaf with Ketchup Glaze": "https://www.themealdb.com/images/media/meals/ypuxtw1511297463.jpg",
        "Chicken Pot Pie": "https://www.themealdb.com/images/media/meals/sytuqu1511553755.jpg",
        "Tuna Noodle Casserole": "https://www.themealdb.com/images/media/meals/yypwwq1511304979.jpg",
        "Green Bean Casserole": "https://www.themealdb.com/images/media/meals/vptwyt1511450962.jpg",
        "Macaroni and Cheese": "https://www.themealdb.com/images/media/meals/kpiu4t1782242131.jpg",
        "Chili con Carne": "https://www.themealdb.com/images/media/meals/uwxqwy1483389553.jpg",
        "Sloppy Joes": "https://www.themealdb.com/images/media/meals/atd5sh1583188467.jpg",
        "Cheesesteaks": "https://www.themealdb.com/images/media/meals/vussxq1511882648.jpg",
        "Club Sandwich": "https://www.themealdb.com/images/media/meals/djdg8l1784578885.jpg",
        "BLT": "https://www.themealdb.com/images/media/meals/dxs5t71782678369.jpg",
        "Grilled Cheese and Tomato Soup": "https://www.themealdb.com/images/media/meals/tvvxpv1511191952.jpg",
        "Chicken and Dumplings": "https://www.themealdb.com/images/media/meals/wyxwsp1486979827.jpg",
        "Shrimp and Grits": "https://www.themealdb.com/images/media/meals/bx07m71764792853.jpg",
        "Jambalaya": "https://www.themealdb.com/images/media/meals/iuws3q1783801530.jpg",
        "Gumbo": "https://www.themealdb.com/images/media/meals/04axct1763793018.jpg",
        "Red Beans and Rice": "https://www.themealdb.com/images/media/meals/9tddhg1764443699.jpg",
        "Po' Boy": "https://www.themealdb.com/images/media/meals/grhn401765687086.jpg",
        "Clam Chowder": "https://www.themealdb.com/images/media/meals/rvtvuw1511190488.jpg",
        "Lobster Rolls": "https://www.themealdb.com/images/media/meals/3m8yae1763257951.jpg",
        "Crab Cakes": "https://www.themealdb.com/images/media/meals/jyvy8u1783800448.jpg",
        "Fish Fry": "https://www.themealdb.com/images/media/meals/5jdtie1763289302.jpg",
        "Beef Stew": "https://www.themealdb.com/images/media/meals/a4kgf21763075288.jpg",
        "Pot Roast": "https://www.themealdb.com/images/media/meals/ssrrrs1503664277.jpg",
        "Roast Chicken": "https://www.themealdb.com/images/media/meals/cj56fs1762340001.jpg",
        "Sheet Pan Fajitas": "https://www.themealdb.com/images/media/meals/tvtxpq1511464705.jpg",
        "Beef Tacos": "https://www.themealdb.com/images/media/meals/ypxvwv1505333929.jpg",
        "Chicken Enchiladas": "https://www.themealdb.com/images/media/meals/qtuwxu1468233098.jpg",
        "Chicken Quesadillas": "https://www.themealdb.com/images/media/meals/se5vhk1764114880.jpg",
        "Nachos Supreme": "https://www.themealdb.com/images/media/meals/o2cd4r1764113576.jpg",
        "Burrito Bowls": "https://www.themealdb.com/images/media/meals/tbj1bs1764118062.jpg",
        "Pork Carnitas": "https://www.themealdb.com/images/media/meals/f0cdwk1782688162.jpg",
        "Breakfast-for-Dinner Pancakes": "https://www.themealdb.com/images/media/meals/sywswr1511383814.jpg",
        "French Toast": "https://www.themealdb.com/images/media/meals/8rfd4q1764112993.jpg",
        "Biscuits and Sausage Gravy": "https://www.themealdb.com/images/media/meals/st1ifa1583267248.jpg",
        "Chicken Fried Steak": "https://www.themealdb.com/images/media/meals/lmwaf61783805434.jpg",
        "Pork Chops and Applesauce": "https://www.themealdb.com/images/media/meals/ymk7gt1783803106.jpg",
        "Stuffed Peppers": "https://www.themealdb.com/images/media/meals/diuub11782687570.jpg",
        "Shepherd's Pie American": "https://www.themealdb.com/images/media/meals/wrssvt1511556563.jpg",
        "Lasagna": "https://www.themealdb.com/images/media/meals/wtsvxx1511296896.jpg",
        "Spaghetti and Meatballs": "https://www.themealdb.com/images/media/meals/sutysw1468247559.jpg",
        "Baked Ziti": "https://www.themealdb.com/images/media/meals/jvjnoh1780086318.jpg",
        "Chicken Alfredo": "https://www.themealdb.com/images/media/meals/0jv5gx1661040802.jpg",
        "Pesto Pasta with Chicken": "https://www.themealdb.com/images/media/meals/q47rkb1762324620.jpg",
        "BBQ Chicken Pizza": "https://www.themealdb.com/images/media/meals/x0lk931587671540.jpg",
        "Pepperoni Pizza Night": "https://www.themealdb.com/images/media/meals/adxcbq1619787919.jpg",
        "Cornbread Chili Bake": "https://www.themealdb.com/images/media/meals/xvsurr1511719182.jpg",
        "Hamburgers Helper Style Skillet": "https://www.themealdb.com/images/media/meals/k420tj1585565244.jpg",
        "Teriyaki Chicken Bowls": "https://www.themealdb.com/images/media/meals/xxyupu1468262513.jpg",
        "Honey Garlic Salmon": "https://www.themealdb.com/images/media/meals/1548772327.jpg",
        "Cajun Salmon": "https://www.themealdb.com/images/media/meals/c0gmo31766594751.jpg",
        "Fish Tacos": "https://www.themealdb.com/images/media/meals/uvuyxu1503067369.jpg",
        "Shrimp Scampi": "https://www.themealdb.com/images/media/meals/wxywrq1468235067.jpg",
        "Beef Stir Fry": "https://www.themealdb.com/images/media/meals/stnxzp1784835840.jpg",
        "Orange Chicken": "https://www.themealdb.com/images/media/meals/s73ytv1765567838.jpg",
        "General Tso's at Home": "https://www.themealdb.com/images/media/meals/ax643t1784731109.jpg",
        "Loaded Baked Potatoes": "https://www.themealdb.com/images/media/meals/1550441882.jpg",
        "Veggie Chili": "https://www.themealdb.com/images/media/meals/pa03n41777540582.jpg",
        "Black Bean Burgers": "https://www.themealdb.com/images/media/meals/p277uc1764109195.jpg",
        "Caesar Salad with Grilled Chicken": "https://www.themealdb.com/images/media/meals/1549542994.jpg",
        "Cobb Salad": "https://www.themealdb.com/images/media/meals/ejht7k1780092390.jpg",
        "BBQ Pulled Chicken": "https://www.themealdb.com/images/media/meals/13fg4j1764441982.jpg",
        "Smoked Sausage and Peppers": "https://www.themealdb.com/images/media/meals/jgl9qq1764437635.jpg",
        "Bratwurst and Sauerkraut": "https://www.themealdb.com/images/media/meals/y4t9zg1777628842.jpg",
        "Chicago Dogs": "https://www.themealdb.com/images/media/meals/dokbyt1779645030.jpg",
        "Coney Dogs": "https://www.themealdb.com/images/media/meals/qt4i0n1763256454.jpg",
        "Philly Roast Pork Sandwich": "https://www.themealdb.com/images/media/meals/sbx7n71587673021.jpg",
        "Italian Beef": "https://www.themealdb.com/images/media/meals/jc6oub1763196663.jpg",
        "Pork Tenderloin Sandwich": "https://www.themealdb.com/images/media/meals/jp09191782856005.jpg",
        "Open Face Hot Turkey Sandwich": "https://www.themealdb.com/images/media/meals/kgfh3q1763075438.jpg",
        "Chicken and Rice Casserole": "https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg",
        "Hashbrown Casserole": "https://www.themealdb.com/images/media/meals/zub3s91764110535.jpg",
        "Funeral Potatoes": "https://www.themealdb.com/images/media/meals/02s6gc1763799560.jpg",
        "Corn Casserole": "https://www.themealdb.com/images/media/meals/5pmn0g1779813285.jpg",
        "Thanksgiving Turkey": "https://www.themealdb.com/images/media/meals/yk78uc1763075719.jpg",
        "Sausage Stuffing": "https://www.themealdb.com/images/media/meals/flrajf1762341295.jpg",
        "Sweet Potato Casserole": "https://www.themealdb.com/images/media/meals/020z181619788503.jpg",
        "Ham with Pineapple": "https://www.themealdb.com/images/media/meals/dlmh401760524897.jpg",
        "Corned Beef and Cabbage": "https://www.themealdb.com/images/media/meals/bjtjyl1779552068.jpg",
        "Prime Rib": "https://www.themealdb.com/images/media/meals/e2kcut1782591669.jpg",
        "Cedar Plank Salmon": "https://www.themealdb.com/images/media/meals/urtpqw1487341253.jpg",
        "Surf and Turf": "https://www.themealdb.com/images/media/meals/sr7chd1780264758.jpg",
        "Meatball Subs": "https://www.themealdb.com/images/media/meals/bnhfa71784662834.jpg",
        "Chicken Parmesan": "https://www.themealdb.com/images/media/meals/5vhbzt1782239221.jpg",
        "Eggplant Parmesan": "https://www.themealdb.com/images/media/meals/fg7d641784666908.jpg",
        "Stuffed Shells": "https://www.themealdb.com/images/media/meals/j223gc1784579841.jpg",
        "Baked Chicken Tenders": "https://www.themealdb.com/images/media/meals/wyrqqq1468233628.jpg",
        "BBQ Meatloaf": "https://www.themealdb.com/images/media/meals/ytme8t1764111401.jpg",
        "Dr Pepper Pulled Pork": "https://www.themealdb.com/images/media/meals/qqwhw51780093126.jpg",
        "Smash Burgers": "https://www.themealdb.com/images/media/meals/lgmnff1763789847.jpg",
        "Turkey Burgers": "https://www.themealdb.com/images/media/meals/6v583k1780093743.jpg",
        "Blackened Catfish": "https://www.themealdb.com/images/media/meals/4xcfai1763765676.jpg",
        "Hush Puppies and Fried Fish": "https://www.themealdb.com/images/media/meals/r7mcjm1780261264.jpg",
        "Collard Greens with Ham": "https://www.themealdb.com/images/media/meals/5tf8j11782236249.jpg",
        "Baked Beans": "https://www.themealdb.com/images/media/meals/4o4wh11761848573.jpg",
        "Coleslaw": "https://www.themealdb.com/images/media/meals/ywwrsp1511720277.jpg",
        "Potato Salad": "https://www.themealdb.com/images/media/meals/vxuyrx1511302687.jpg",
        "Macaroni Salad": "https://www.themealdb.com/images/media/meals/ryppsv1511815505.jpg",
        "Corn on the Cob": "https://www.themealdb.com/images/media/meals/m0p0j81765568742.jpg",
        "Garlic Mashed Potatoes": "https://www.themealdb.com/images/media/meals/pkopc31683207947.jpg",
        "Brown Gravy Pork Chops": "https://www.themealdb.com/images/media/meals/z0ageb1583189517.jpg",
        "Salisbury Steak": "https://www.themealdb.com/images/media/meals/vtqxtu1511784197.jpg",
        "Chicken and Stuffing Bake": "https://www.themealdb.com/images/media/meals/41cxjh1683207682.jpg",
        "Tater Tot Hotdish": "https://www.themealdb.com/images/media/meals/uyqrrv1511553350.jpg",
        "Frito Pie": "https://www.themealdb.com/images/media/meals/dxpc7j1764370714.jpg",
        "Walking Tacos": "https://www.themealdb.com/images/media/meals/1529444830.jpg",
        "Seven Layer Dip Night": "https://www.themealdb.com/images/media/meals/t2b8bn1779737789.jpg",
        "White Chicken Chili": "https://www.themealdb.com/images/media/meals/1nalo51765188375.jpg",
        "Chicken Noodle Soup": "https://www.themealdb.com/images/media/meals/cgl60b1683206581.jpg",
        "Tomato Basil Soup and Grilled Cheese": "https://www.themealdb.com/images/media/meals/pbzcrx1763765096.jpg",
        "Broccoli Cheddar Soup": "https://www.themealdb.com/images/media/meals/k07k271782502861.jpg",
        "French Onion Soup": "https://www.themealdb.com/images/media/meals/bc8v651619789840.jpg",
        "Crockpot Chicken Tacos": "https://www.themealdb.com/images/media/meals/svprys1511176755.jpg",
        "Crockpot Beef Tips": "https://www.themealdb.com/images/media/meals/vvpprx1487325699.jpg",
        "Weeknight Tacos Two Ways": "https://www.themealdb.com/images/media/meals/ra2k8a1764365055.jpg",
        "Hawaiian Haystacks": "https://www.themealdb.com/images/media/meals/qwicc91764368097.jpg",
        "Chicken Divan": "https://www.themealdb.com/images/media/meals/xlqqhw1764369924.jpg",
        "King Ranch Chicken": "https://www.themealdb.com/images/media/meals/zadvgb1699012544.jpg",
        "Chicken Tetrazzini": "https://www.themealdb.com/images/media/meals/gjjlzc1782496055.jpg",
        "Beef Stroganoff American": "https://www.themealdb.com/images/media/meals/byolko1782500400.jpg",
        "Swedish Meatballs American Table": "https://www.themealdb.com/images/media/meals/nmxec11782498644.jpg",
        "Pigs in a Blanket Dinner": "https://www.themealdb.com/images/media/meals/9ya6o71780262651.jpg",
        "Breakfast Burritos": "https://www.themealdb.com/images/media/meals/urzj1d1587670726.jpg",
        "Huevos Rancheros": "https://www.themealdb.com/images/media/meals/md8w601593348504.jpg",
        "Chicken and Waffles": "https://www.themealdb.com/images/media/meals/0wmns51784837949.jpg",
        "Steak and Potatoes": "https://www.themealdb.com/images/media/meals/fl4brj1764361323.jpg",
        "Pork Ribs Oven": "https://www.themealdb.com/images/media/meals/4pqimk1683207418.jpg",
        "Beer Can Chicken": "https://www.themealdb.com/images/media/meals/lhqev81565090111.jpg",
        "Grilled BBQ Chicken": "https://www.themealdb.com/images/media/meals/xrxz7h1782592711.jpg",
        "Cedar BBQ Salmon Burgers": "https://www.themealdb.com/images/media/meals/x0mreq1784577446.jpg",
        "Turkey Club Wrap": "https://www.themealdb.com/images/media/meals/81ahfr1784394567.jpg",
        "Chicken Caesar Wrap": "https://www.themealdb.com/images/media/meals/rpvptu1511641092.jpg",
        "Buffalo Chicken Sandwiches": "https://www.themealdb.com/images/media/meals/0206h11699013358.jpg",
        "Crispy Chicken Sandwich": "https://www.themealdb.com/images/media/meals/e756bf1761848342.jpg",
        "BBQ Pulled Jackfruit": "https://www.themealdb.com/images/media/meals/de0sns1779555283.jpg",
        "Mushroom Cheesesteaks": "https://www.themealdb.com/images/media/meals/skzd0x1780091674.jpg",
        "Baked Ziti Sausage": "https://www.themealdb.com/images/media/meals/804v1j1764367088.jpg",
        "Sausage, Peppers, and Onions": "https://www.themealdb.com/images/media/meals/tkwxmv1777540463.jpg",
        "Weeknight Roast Salmon and Veg": "https://www.themealdb.com/images/media/meals/qywups1511796761.jpg",
        "Honey Mustard Chicken Thighs": "https://www.themealdb.com/images/media/meals/naqyel1608588563.jpg",
        "Lemon Pepper Chicken": "https://www.themealdb.com/images/media/meals/uuqvwu1504629254.jpg",
        "Garlic Butter Steak Bites": "https://www.themealdb.com/images/media/meals/z267f71764364072.jpg",
        "Cheeseburger Pasta Skillet": "https://www.themealdb.com/images/media/meals/h68o161782679437.jpg",
        "Taco Pasta": "https://www.themealdb.com/images/media/meals/sl7cr91782588539.jpg",
        "Pizza Pasta Bake": "https://www.themealdb.com/images/media/meals/dg7tad1782588053.jpg",
        "Ranch Chicken Bacon Bake": "https://www.themealdb.com/images/media/meals/xqwwpy1483908697.jpg",
        "Mississippi Pot Roast": "https://www.themealdb.com/images/media/meals/hqaejl1695738653.jpg",
        "Mississippi Chicken": "https://www.themealdb.com/images/media/meals/6utn1w1782237402.jpg",
        "Coke Ham": "https://www.themealdb.com/images/media/meals/z672jx1780263633.jpg",
        "Root Beer Pulled Pork": "https://www.themealdb.com/images/media/meals/dk70uv1784670127.jpg",
        "Sunday Gravy with Sausage and Meatballs": "https://www.themealdb.com/images/media/meals/qqpwsy1511796276.jpg",
        "Baked Mostaccioli": "https://www.themealdb.com/images/media/meals/6vi2cv1763075785.jpg",
        "Chicken Cordon Bleu Bake": "https://www.themealdb.com/images/media/meals/g33c901763365484.jpg",
        "Reuben Skillet": "https://www.themealdb.com/images/media/meals/1549542877.jpg",
        "Patty Melt": "https://www.themealdb.com/images/media/meals/6awyvm1782685205.jpg",
        "Tuna Melts": "https://www.themealdb.com/images/media/meals/y75q5j1782685779.jpg",
        "Salmon Patties": "https://www.themealdb.com/images/media/meals/tkxquw1628771028.jpg",
        "Chicken Bog": "https://www.themealdb.com/images/media/meals/60oc3k1699009846.jpg",
        "Hoppin' John": "https://www.themealdb.com/images/media/meals/brmxra1782681940.jpg",
        "Chicken Bog Bowl": "https://www.themealdb.com/images/media/meals/16zbeu1763789342.jpg",
        "Mashed Potatoes": "https://www.themealdb.com/images/media/meals/9kecho1784575366.jpg",
        "Roasted Potatoes": "https://www.themealdb.com/images/media/meals/73o3vq1765317873.jpg",
        "French Fries": "https://www.themealdb.com/images/media/meals/ussyxw1515364536.jpg",
        "Sweet Potato Fries": "https://www.themealdb.com/images/media/meals/jg4r991779916649.jpg",
        "Scalloped Potatoes": "https://www.themealdb.com/images/media/meals/wympxc1779734808.jpg",
        "Creamed Corn": "https://www.themealdb.com/images/media/meals/h7zrys1779736460.jpg",
        "Roasted Broccoli": "https://www.themealdb.com/images/media/meals/wpputp1511812960.jpg",
        "Roasted Carrots": "https://www.themealdb.com/images/media/meals/8b2msz1763074897.jpg",
        "Asparagus": "https://www.themealdb.com/images/media/meals/z1hz7z1765316430.jpg",
        "Sauteed Green Beans": "https://www.themealdb.com/images/media/meals/xjii2g1784836867.jpg",
        "Cornbread": "https://www.themealdb.com/images/media/meals/vrspxv1511722107.jpg",
        "Garlic Bread": "https://www.themealdb.com/images/media/meals/t3r3ka1560461972.jpg",
        "Dinner Rolls": "https://www.themealdb.com/images/media/meals/fnfnhi1784671116.jpg",
        "Biscuits": "https://www.themealdb.com/images/media/meals/2mrghf1782773422.jpg",
        "House Salad": "https://www.themealdb.com/images/media/meals/lrfdwz1764438393.jpg",
        "Caesar Salad": "https://www.themealdb.com/images/media/meals/q21suk1782772956.jpg",
        "Wedge Salad": "https://www.themealdb.com/images/media/meals/wkhwqr1782774765.jpg",
        "Fruit Salad": "https://www.themealdb.com/images/media/meals/vc08jn1628769553.jpg",
        "Onion Rings": "https://www.themealdb.com/images/media/meals/gpz67p1560458984.jpg",
        "Tater Tots": "https://www.themealdb.com/images/media/meals/fm01ky1764366365.jpg",
        "Rice Pilaf": "https://www.themealdb.com/images/media/meals/oal8x31764119345.jpg",
        "White Rice": "https://www.themealdb.com/images/media/meals/7i6csk1780094394.jpg",
        "Stuffing": "https://www.themealdb.com/images/media/meals/vqpwrv1511723001.jpg",
        "Cranberry Sauce": "https://www.themealdb.com/images/media/meals/fk80jp1763280767.jpg",
        "Applesauce": "https://www.themealdb.com/images/media/meals/uuuspp1511297945.jpg",
        "Gravy": "https://www.themealdb.com/images/media/meals/syqypv1486981727.jpg",
        "Collard Greens": "https://www.themealdb.com/images/media/meals/mp9z0i1782238092.jpg",
        "Fried Okra": "https://www.themealdb.com/images/media/meals/wruvqv1511880994.jpg",
        "Hush Puppies": "https://www.themealdb.com/images/media/meals/1529446352.jpg",
        "Deviled Eggs": "https://www.themealdb.com/images/media/meals/qxytrx1511304021.jpg",
        "Pickles": "https://www.themealdb.com/images/media/meals/qrqywr1503066605.jpg",
        "Baked Macaroni": "https://www.themealdb.com/images/media/meals/wuyd2h1765655837.jpg",
        "Creamed Spinach": "https://www.themealdb.com/images/media/meals/xrrtss1511555269.jpg",
        "Brussels Sprouts": "https://www.themealdb.com/images/media/meals/uuns781783804024.jpg",
        "Cucumber Salad": "https://www.themealdb.com/images/media/meals/tyywsw1505930373.jpg",
        "Three Bean Salad": "https://www.themealdb.com/images/media/meals/hob03q1780264260.jpg",
        "Corn Salad": "https://www.themealdb.com/images/media/meals/nz0lg71784671684.jpg",
        "Texas Toast": "https://www.themealdb.com/images/media/meals/er4d081765186828.jpg",
        "Cheddar Biscuits": "https://www.themealdb.com/images/media/meals/qpxvuq1511798906.jpg",
        "Slaw Mix": "https://www.themealdb.com/images/media/meals/uwvxpv1511557015.jpg",
        "Potato Wedges": "https://www.themealdb.com/images/media/meals/k29viq1585565980.jpg",
        "Elote": "https://www.themealdb.com/images/media/meals/t5rgav1784659936.jpg",
        "Refried Beans": "https://www.themealdb.com/images/media/meals/hcg6l91763596970.jpg",
        "Spanish Rice": "https://www.themealdb.com/images/media/meals/4hzyvq1763792564.jpg",
    ]
}

enum RecipePhotoLoader {
    private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 20 * 1024 * 1024
        return cache
    }()
    private static let gate = PhotoGate(limit: 2)
    private static let folder: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RecipeThumbsV1", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func cached(name: String) -> UIImage? {
        let key = name as NSString
        if let hit = memory.object(forKey: key) { return hit }
        let file = folder.appendingPathComponent(slug(name) + ".jpg")
        guard let data = try? Data(contentsOf: file), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key)
        return image
    }

    static func image(name: String) async -> UIImage? {
        if let hit = cached(name: name) { return hit }
        guard let url = RecipeThumbs.smallURL(for: name) ?? RecipeThumbs.url(for: name) else { return nil }
        return await gate.run {
            if let hit = cached(name: name) { return hit }
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            request.setValue("HUB/1.0", forHTTPHeaderField: "User-Agent")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode ?? 200 < 400,
                  let image = UIImage(data: data),
                  image.size.width > 40
            else { return nil }
            memory.setObject(image, forKey: name as NSString)
            if let jpeg = image.jpegData(compressionQuality: 0.82) {
                try? jpeg.write(to: folder.appendingPathComponent(slug(name) + ".jpg"), options: .atomic)
            }
            return image
        }
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
