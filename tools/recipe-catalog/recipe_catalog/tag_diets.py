"""Deterministic diet and allergen tags from ingredient text.

Labels are ingredient-list inferences, not certifications and not nutrition
analysis. Low-sodium and lower-sugar stay untagged unless nutrition data exists.
"""

from __future__ import annotations

import re
from typing import Iterable

NUT_DISCLAIMER = (
    "Check labels: recipes can pick up peanuts or tree nuts from shared "
    "equipment, garnishes, or 'may contain' warnings that are not in the ingredient list."
)

HALAL_NOTE = "Ingredients compatible, not certified."
KOSHER_NOTE = "Ingredients compatible, not certified."

# Phrase exclusions are checked before the positive term so "butter beans"
# does not count as dairy and "nutmeg" / "coconut" do not count as tree nuts.
_EXCEPTIONS: dict[str, tuple[str, ...]] = {
    "dairy": (
        "butter bean",
        "butter beans",
        "butterbean",
        "butterbeans",
        "butternut",
        "butter lettuce",
        "buttercup squash",
        "cocoa butter",
        "apple butter",
        "peanut butter",
        "almond butter",
        "cashew butter",
        "sunflower butter",
        "pumpkin seed butter",
        "soy butter",
        "shea butter",
        "coconut butter",
        "nut butter",
        "coconut milk",
        "almond milk",
        "oat milk",
        "soy milk",
        "rice milk",
        "cashew milk",
        "hemp milk",
        "coconut cream",
        "cream of tartar",
        "cream of mushroom",  # still may contain dairy; handled only when "cream of mushroom soup" says nondairy — keep dairy if "cream" remains after this phrase is masked only when the line is the canned soup without dairy words. Safer: do NOT except cream of mushroom.
    ),
    "egg": (
        "eggplant",
        "egg plant",
        "eggplants",
    ),
    "gluten": (
        "gluten-free",
        "gluten free",
        "corn flour",
        "rice flour",
        "almond flour",
        "coconut flour",
        "buckwheat flour",
        "chickpea flour",
        "besan",
        "cornstarch",
        "corn starch",
        "potato starch",
        "tapioca starch",
        "arrowroot",
        "buckwheat",
        "corn tortilla",
        "rice noodle",
        "rice noodles",
    ),
    "soy": (),
    "peanut": (),
    "tree_nut": (
        "nutmeg",
        "coconut",
        "coconuts",
        "butternut",
        "water chestnut",
        "water chestnuts",
        "chestnut mushroom",
        "donut",
        "doughnut",
    ),
    "meat": (),
    "fish": (),
    "pork": (),
    "alcohol": (),
    "shellfish": (),
    "legume": (
        "green bean",
        "green beans",
        "snap pea",
        "snap peas",
        "snow pea",
        "snow peas",
    ),
    "grain": (
        "cornstarch",
        "corn starch",
        "cream of tartar",
    ),
    "sugar": (
        "sugar snap",
        "bell pepper",  # not sugar
    ),
    "keto_carb": (
        "cauliflower rice",
        "almond flour",
        "coconut flour",
    ),
}

# Remove the false cream-of-mushroom exception — it can be dairy soup.
_EXCEPTIONS["dairy"] = tuple(
    p for p in _EXCEPTIONS["dairy"] if p != "cream of mushroom"
)

_TERMS: dict[str, tuple[str, ...]] = {
    "dairy": (
        "butter",
        "buttermilk",
        "milk",
        "cream",
        "cheese",
        "cheddar",
        "parmesan",
        "mozzarella",
        "ricotta",
        "ghee",
        "whey",
        "casein",
        "yogurt",
        "yoghurt",
        "half-and-half",
        "half and half",
        "sour cream",
        "creme fraiche",
        "crème fraîche",
        "kefir",
        "paneer",
        "condensed milk",
        "evaporated milk",
        "ice cream",
        "custard",
        "mascarpone",
        "lactose",
    ),
    "egg": (
        "egg",
        "eggs",
        "egg yolk",
        "egg white",
        "mayonnaise",
        "mayo",
        "aioli",
        "meringue",
        "albumen",
    ),
    "gluten": (
        "wheat",
        "all-purpose flour",
        "all purpose flour",
        "plain flour",
        "bread flour",
        "cake flour",
        "self-raising flour",
        "self rising flour",
        "flour",
        "barley",
        "rye",
        "spelt",
        "semolina",
        "couscous",
        "farro",
        "bulgur",
        "seitan",
        "panko",
        "breadcrumb",
        "breadcrumbs",
        "bread",
        "pasta",
        "noodle",
        "noodles",
        "soy sauce",
        "orzo",
        "tortilla",
        "pita",
        "cracker",
    ),
    "soy": (
        "soy",
        "soya",
        "tofu",
        "tempeh",
        "edamame",
        "miso",
        "tamari",
    ),
    "peanut": (
        "peanut",
        "peanuts",
        "groundnut",
        "groundnuts",
    ),
    "tree_nut": (
        "almond",
        "walnut",
        "pecan",
        "cashew",
        "pistachio",
        "hazelnut",
        "macadamia",
        "brazil nut",
        "pine nut",
        "chestnut",
        "praline",
        "marzipan",
        "nutella",
    ),
    "meat": (
        "beef",
        "steak",
        "pork",
        "bacon",
        "ham",
        "prosciutto",
        "pancetta",
        "lard",
        "chicken",
        "turkey",
        "duck",
        "goose",
        "lamb",
        "mutton",
        "veal",
        "venison",
        "sausage",
        "chorizo",
        "pepperoni",
        "salami",
        "gelatin",
        "gelatine",
        "suet",
        "chicken stock",
        "beef stock",
        "chicken broth",
        "beef broth",
        "meat",
        "anchovy",  # not meat for pescatarian; meat list is land animals. Remove anchovy from meat.
    ),
    "fish": (
        "fish",
        "salmon",
        "tuna",
        "cod",
        "anchovy",
        "anchovies",
        "sardine",
        "shrimp",
        "prawn",
        "crab",
        "lobster",
        "clam",
        "mussel",
        "oyster",
        "scallop",
        "squid",
        "calamari",
        "fish sauce",
        "oyster sauce",
        "worcestershire",
        "seafood",
    ),
    "pork": (
        "pork",
        "bacon",
        "ham",
        "prosciutto",
        "pancetta",
        "lard",
        "chorizo",
        "pepperoni",
        "salami",
        "gelatin",
        "gelatine",
    ),
    "alcohol": (
        "wine",
        "beer",
        "rum",
        "whiskey",
        "whisky",
        "vodka",
        "brandy",
        "liqueur",
        "marsala",
        "sherry",
        "sake",
        "mirin",
        "bourbon",
        "cognac",
        "tequila",
        "champagne",
        "port wine",
        "red wine",
        "white wine",
        "cooking wine",
    ),
    "shellfish": (
        "shrimp",
        "prawn",
        "crab",
        "lobster",
        "clam",
        "mussel",
        "oyster",
        "scallop",
        "crawfish",
        "crayfish",
        "shellfish",
    ),
    "animal": (
        "honey",
        "gelatin",
        "gelatine",
        "lard",
        "suet",
        "rennet",
        "chicken",
        "beef",
        "pork",
        "bacon",
        "fish",
        "anchovy",
        "stock",
        "broth",
    ),
    "legume": (
        "bean",
        "beans",
        "lentil",
        "lentils",
        "chickpea",
        "peanut",
        "peanuts",
        "soy",
        "soya",
        "tofu",
        "tempeh",
        "edamame",
        "peas",
        "pea",
        "hummus",
    ),
    "grain": (
        "wheat",
        "flour",
        "rice",
        "oat",
        "oats",
        "barley",
        "rye",
        "corn",
        "maize",
        "bread",
        "pasta",
        "quinoa",
        "couscous",
        "tortilla",
        "noodle",
    ),
    "refined_sugar": (
        "sugar",
        "brown sugar",
        "powdered sugar",
        "confectioners",
        "corn syrup",
        "molasses",
        "cane sugar",
    ),
    "keto_carb": (
        "sugar",
        "honey",
        "flour",
        "rice",
        "potato",
        "potatoes",
        "bread",
        "pasta",
        "noodle",
        "oat",
        "oats",
        "corn",
        "beans",
        "lentil",
        "chickpea",
        "banana",
        "maple syrup",
        "molasses",
        "tortilla",
        "quinoa",
        "couscous",
        "breadcrumb",
    ),
}

# Land-animal meat only. Fish stays on the fish list so pescatarian can pass.
_TERMS["meat"] = tuple(t for t in _TERMS["meat"] if t != "anchovy")

# "wine vinegar" and "rice wine vinegar" are not drinking alcohol for this screen.
_EXCEPTIONS["alcohol"] = (
    "wine vinegar",
    "red wine vinegar",
    "white wine vinegar",
    "rice wine vinegar",
    "balsamic vinegar",
)

_WORD = re.compile(r"[a-z0-9]+(?:'[a-z]+)?", re.I)


def _norm(text: str) -> str:
    text = text.lower().replace("’", "'")
    text = text.replace("-", " ")
    return re.sub(r"\s+", " ", text).strip()


def _mask(text: str, phrases: Iterable[str]) -> str:
    masked = f" {text} "
    for phrase in sorted(phrases, key=len, reverse=True):
        p = _norm(phrase)
        if not p:
            continue
        masked = masked.replace(f" {p} ", " ")
    return masked


def _has_term(text: str, group: str) -> bool:
    raw = _norm(text)
    masked = _mask(raw, _EXCEPTIONS.get(group, ()))
    # Also drop parenthetical metric conversions so "g" never matches.
    padded = f" {masked} "
    for term in sorted(_TERMS[group], key=len, reverse=True):
        t = _norm(term)
        if f" {t} " in padded:
            return True
        # plural already listed for many terms; also match a trailing s on single words
        if " " not in t and f" {t}s " in padded:
            return True
    return False


def _joined(ingredients: Iterable[str]) -> str:
    return " \n ".join(_norm(part) for part in ingredients if part and part.strip())


def tag_ingredients(ingredients: Iterable[str], *, nutrition: dict | None = None) -> dict:
    """Return diet and allergen labels for one recipe.

    `nutrition`, when present, may include numeric `sodiumMg` and `sugarG`
    per serving. Without it, low-sodium and lower-sugar are omitted.
    """
    text = _joined(ingredients)
    has = lambda group: _has_term(text, group)  # noqa: E731

    dairy = has("dairy")
    egg = has("egg")
    gluten = has("gluten")
    soy = has("soy")
    peanut = has("peanut")
    tree_nut = has("tree_nut")
    meat = has("meat")
    fish = has("fish")
    pork = has("pork")
    alcohol = has("alcohol")
    shellfish = has("shellfish")
    honey = " honey " in f" {_norm(text)} "
    gelatin = has("pork") and ("gelatin" in text or "gelatine" in text)
    animal_product = meat or fish or dairy or egg or honey or " gelatin " in f" {text} " or " gelatine " in f" {text} " or " rennet " in f" {text} " or " lard " in f" {text} "

    # Vegetarian allows dairy, eggs, honey. Pescatarian also allows fish.
    vegetarian = not meat and not fish
    vegan = vegetarian and not dairy and not egg and not honey and " gelatin " not in f" {text} " and " gelatine " not in f" {text} " and " rennet " not in f" {text} " and " lard " not in f" {text} "
    pescatarian = not meat

    gluten_free = not gluten
    dairy_free = not dairy
    egg_free = not egg
    soy_free = not soy
    peanut_free = not peanut
    tree_nut_free = not tree_nut

    keto = not has("keto_carb")
    paleo = (
        not has("grain")
        and not has("legume")
        and not dairy
        and not soy
        and not peanut
        and not has("refined_sugar")
    )

    # Kosher ingredient screen: no pork, no shellfish, no meat+dairy mix, no unstated gelatin.
    meat_and_dairy = meat and dairy
    kosher_ok = not pork and not shellfish and not meat_and_dairy and not gelatin
    # Halal ingredient screen: no pork, no alcohol, no unstated gelatin.
    halal_ok = not pork and not alcohol and not gelatin

    labels: list[dict] = []

    def add(tag_id: str, ok: bool, *, disclaimer: str | None = None, note: str | None = None, status: str | None = None) -> None:
        if status is None:
            status = "compatible" if ok else "not_compatible"
        entry = {"id": tag_id, "status": status}
        if ok and disclaimer:
            entry["disclaimer"] = disclaimer
        if note:
            entry["note"] = note
        labels.append(entry)

    add("vegan", vegan)
    add("vegetarian", vegetarian)
    add("pescatarian", pescatarian)
    add("gluten-free", gluten_free)
    add("dairy-free", dairy_free)
    add("egg-free", egg_free)
    add("soy-free", soy_free)
    add("peanut-free", peanut_free, disclaimer=NUT_DISCLAIMER if peanut_free else None)
    add("tree-nut-free", tree_nut_free, disclaimer=NUT_DISCLAIMER if tree_nut_free else None)
    add("keto", keto)
    add("paleo", paleo)
    add(
        "halal",
        halal_ok,
        status="ingredients_compatible_not_certified" if halal_ok else "not_compatible",
        note=HALAL_NOTE if halal_ok else None,
    )
    add(
        "kosher",
        kosher_ok,
        status="ingredients_compatible_not_certified" if kosher_ok else "not_compatible",
        note=KOSHER_NOTE if kosher_ok else None,
    )

    if nutrition:
        sodium = nutrition.get("sodiumMg")
        sugar = nutrition.get("sugarG")
        if isinstance(sodium, (int, float)):
            add("low-sodium", sodium <= 140)
        if isinstance(sugar, (int, float)):
            add("lower-sugar", sugar <= 5)

    compatible = [item["id"] for item in labels if item["status"] != "not_compatible"]
    return {
        "labels": labels,
        "compatible": compatible,
        "contains": {
            "dairy": dairy,
            "egg": egg,
            "gluten": gluten,
            "soy": soy,
            "peanut": peanut,
            "treeNut": tree_nut,
            "meat": meat,
            "fish": fish,
            "pork": pork,
            "alcohol": alcohol,
            "shellfish": shellfish,
            "animalProduct": animal_product,
        },
    }


def apply_tags(recipe: dict) -> dict:
    ingredients = recipe.get("ingredients") or []
    texts: list[str] = []
    for item in ingredients:
        if isinstance(item, str):
            texts.append(item)
        elif isinstance(item, dict):
            texts.append(str(item.get("text") or item.get("item") or ""))
    nutrition = recipe.get("nutrition") if isinstance(recipe.get("nutrition"), dict) else None
    tagged = tag_ingredients(texts, nutrition=nutrition)
    recipe = dict(recipe)
    recipe["dietLabels"] = tagged["labels"]
    recipe["dietCompatible"] = tagged["compatible"]
    return recipe
