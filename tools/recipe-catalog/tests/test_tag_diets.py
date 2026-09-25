import unittest

from recipe_catalog.tag_diets import NUT_DISCLAIMER, tag_ingredients


def compatible(ingredients):
    return set(tag_ingredients(ingredients)["compatible"])


def contains(ingredients):
    return tag_ingredients(ingredients)["contains"]


class DietTagTests(unittest.TestCase):
    def test_butter_beans_are_not_dairy(self):
        flags = contains(["2 cups butter beans", "1 tbsp olive oil", "salt"])
        self.assertFalse(flags["dairy"])
        self.assertIn("dairy-free", compatible(["2 cups butter beans", "olive oil", "salt"]))
        self.assertIn("vegan", compatible(["butter beans", "olive oil", "garlic"]))

    def test_buttermilk_and_butter_are_dairy(self):
        self.assertTrue(contains(["1 cup buttermilk"])["dairy"])
        self.assertTrue(contains(["2 tbsp butter"])["dairy"])
        self.assertNotIn("dairy-free", compatible(["butter", "flour"]))
        self.assertNotIn("vegan", compatible(["butter beans", "butter"]))

    def test_coconut_is_not_a_tree_nut_or_dairy(self):
        flags = contains(["1 cup coconut milk", "2 tbsp coconut oil", "shredded coconut"])
        self.assertFalse(flags["treeNut"])
        self.assertFalse(flags["dairy"])
        self.assertIn("tree-nut-free", compatible(["coconut milk", "lime", "salt"]))
        self.assertIn("dairy-free", compatible(["coconut milk", "lime"]))

    def test_nutmeg_is_not_a_tree_nut(self):
        flags = contains(["1 tsp nutmeg", "1 tsp cinnamon", "pumpkin"])
        self.assertFalse(flags["treeNut"])
        self.assertIn("tree-nut-free", compatible(["nutmeg", "pumpkin", "olive oil"]))

    def test_almonds_are_tree_nuts_and_peanut_butter_is_not_dairy(self):
        self.assertTrue(contains(["1/2 cup almonds"])["treeNut"])
        self.assertFalse(contains(["2 tbsp peanut butter"])["dairy"])
        self.assertTrue(contains(["2 tbsp peanut butter"])["peanut"])
        self.assertNotIn("peanut-free", compatible(["peanut butter", "celery"]))
        self.assertIn("dairy-free", compatible(["peanut butter", "celery"]))

    def test_eggplant_is_not_egg(self):
        flags = contains(["1 eggplant", "olive oil", "garlic"])
        self.assertFalse(flags["egg"])
        self.assertIn("egg-free", compatible(["eggplant", "olive oil"]))
        self.assertIn("vegan", compatible(["eggplant", "tomato", "olive oil"]))

    def test_eggs_block_vegan_and_egg_free(self):
        self.assertTrue(contains(["4 eggs"])["egg"])
        labels = compatible(["4 eggs", "spinach"])
        self.assertNotIn("vegan", labels)
        self.assertIn("vegetarian", labels)
        self.assertNotIn("egg-free", labels)

    def test_cream_of_tartar_is_not_dairy(self):
        self.assertFalse(contains(["1/4 tsp cream of tartar", "egg whites"])["dairy"])

    def test_honey_is_vegetarian_not_vegan(self):
        labels = compatible(["1 tbsp honey", "oats", "apple"])
        self.assertIn("vegetarian", labels)
        self.assertNotIn("vegan", labels)

    def test_chicken_is_not_pescatarian_salmon_is(self):
        self.assertNotIn("pescatarian", compatible(["chicken breast", "salt"]))
        self.assertNotIn("vegetarian", compatible(["chicken breast"]))
        fish = compatible(["salmon fillet", "lemon", "olive oil"])
        self.assertIn("pescatarian", fish)
        self.assertNotIn("vegetarian", fish)
        self.assertNotIn("vegan", fish)

    def test_gluten_free_flour_swap_and_wheat(self):
        self.assertFalse(contains(["1 cup almond flour", "eggs"])["gluten"])
        self.assertTrue(contains(["1 cup almond flour"])["treeNut"])
        self.assertIn("gluten-free", compatible(["almond flour", "egg", "butter"]))
        self.assertTrue(contains(["2 cups all-purpose flour"])["gluten"])
        self.assertNotIn("gluten-free", compatible(["all-purpose flour", "sugar"]))

    def test_soy_sauce_and_tamari(self):
        self.assertTrue(contains(["2 tbsp soy sauce"])["soy"])
        self.assertTrue(contains(["2 tbsp soy sauce"])["gluten"])
        self.assertFalse(contains(["2 tbsp gluten-free tamari"])["gluten"])
        self.assertTrue(contains(["2 tbsp gluten-free tamari"])["soy"])

    def test_nut_labels_carry_check_labels_disclaimer(self):
        result = tag_ingredients(["olive oil", "garlic", "rice"])
        by_id = {item["id"]: item for item in result["labels"]}
        self.assertEqual(by_id["peanut-free"]["disclaimer"], NUT_DISCLAIMER)
        self.assertEqual(by_id["tree-nut-free"]["disclaimer"], NUT_DISCLAIMER)
        peanuts = tag_ingredients(["peanuts", "rice"])
        peanut_row = next(item for item in peanuts["labels"] if item["id"] == "peanut-free")
        self.assertEqual(peanut_row["status"], "not_compatible")
        self.assertNotIn("disclaimer", peanut_row)

    def test_halal_and_kosher_are_not_certified(self):
        result = tag_ingredients(["chickpeas", "olive oil", "lemon", "garlic"])
        by_id = {item["id"]: item for item in result["labels"]}
        self.assertEqual(by_id["halal"]["status"], "ingredients_compatible_not_certified")
        self.assertEqual(by_id["kosher"]["status"], "ingredients_compatible_not_certified")
        self.assertIn("not certified", by_id["halal"]["note"].lower())
        pork = tag_ingredients(["bacon", "eggs"])
        pork_ids = {item["id"]: item for item in pork["labels"]}
        self.assertEqual(pork_ids["halal"]["status"], "not_compatible")
        self.assertEqual(pork_ids["kosher"]["status"], "not_compatible")

    def test_wine_vinegar_is_not_alcohol_but_wine_is(self):
        self.assertFalse(contains(["1 tbsp red wine vinegar", "olive oil"])["alcohol"])
        self.assertTrue(contains(["1/2 cup red wine"])["alcohol"])
        wine = tag_ingredients(["red wine", "mushrooms", "olive oil"])
        halal = next(item for item in wine["labels"] if item["id"] == "halal")
        self.assertEqual(halal["status"], "not_compatible")

    def test_low_sodium_and_lower_sugar_need_nutrition(self):
        plain = tag_ingredients(["apple", "cinnamon"])
        ids = {item["id"] for item in plain["labels"]}
        self.assertNotIn("low-sodium", ids)
        self.assertNotIn("lower-sugar", ids)
        with_data = tag_ingredients(
            ["apple"],
            nutrition={"sodiumMg": 10, "sugarG": 4},
        )
        tagged = {item["id"]: item["status"] for item in with_data["labels"]}
        self.assertEqual(tagged["low-sodium"], "compatible")
        self.assertEqual(tagged["lower-sugar"], "compatible")
        high = tag_ingredients(["apple"], nutrition={"sodiumMg": 800, "sugarG": 30})
        high_status = {item["id"]: item["status"] for item in high["labels"]}
        self.assertEqual(high_status["low-sodium"], "not_compatible")
        self.assertEqual(high_status["lower-sugar"], "not_compatible")

    def test_paleo_and_keto_reject_sugar_and_beans(self):
        beans = compatible(["butter beans", "olive oil"])
        self.assertNotIn("paleo", beans)
        self.assertNotIn("keto", beans)
        steak = compatible(["ribeye steak", "olive oil", "salt", "rosemary"])
        self.assertIn("keto", steak)
        self.assertIn("paleo", steak)


if __name__ == "__main__":
    unittest.main()
