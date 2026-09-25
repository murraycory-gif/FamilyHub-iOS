"""Normalize a Wikibooks Cookbook page into catalog fields."""

from __future__ import annotations

import re
from html import unescape

_LINK = re.compile(r"\[\[([^|\]]+)\|([^\]]+)\]\]")
_LINK_BARE = re.compile(r"\[\[([^\]]+)\]\]")
_TEMPLATE = re.compile(r"\{\{[^{}]*\}\}")
_TAG = re.compile(r"<[^>]+>")
_BOLD = re.compile(r"'{2,}")
_REF = re.compile(r"<ref[^>]*>.*?</ref>", re.I | re.S)

_CUISINES = {
    "united states": "American",
    "america": "American",
    "american": "American",
    "usa": "American",
    "italy": "Italian",
    "italian": "Italian",
    "mexico": "Mexican",
    "mexican": "Mexican",
    "france": "French",
    "french": "French",
    "china": "Chinese",
    "chinese": "Chinese",
    "japan": "Japanese",
    "japanese": "Japanese",
    "thailand": "Thai",
    "thai": "Thai",
    "india": "Indian",
    "indian": "Indian",
    "greece": "Greek",
    "greek": "Greek",
    "spain": "Spanish",
    "spanish": "Spanish",
    "korea": "Korean",
    "korean": "Korean",
    "vietnam": "Vietnamese",
    "vietnamese": "Vietnamese",
    "germany": "German",
    "german": "German",
    "morocco": "Moroccan",
    "moroccan": "Moroccan",
    "middle east": "Middle Eastern",
    "mediterranean": "Mediterranean",
    "britain": "British",
    "british": "British",
    "england": "British",
    "ireland": "Irish",
    "irish": "Irish",
    "poland": "Polish",
    "polish": "Polish",
    "portugal": "Portuguese",
    "caribbean": "Caribbean",
    "jamaica": "Jamaican",
    "ethiopia": "Ethiopian",
    "turkey": "Turkish",
    "turkish": "Turkish",
    "lebanon": "Lebanese",
    "philippines": "Filipino",
    "indonesia": "Indonesian",
    "sweden": "Swedish",
    "russia": "Russian",
    "brazil": "Brazilian",
    "peru": "Peruvian",
    "jewish": "Jewish",
    "southern": "American",
    "tex-mex": "Tex-Mex",
    "cajun": "Cajun",
    "creole": "Creole",
}

_MEAL_RULES = (
    ("dessert", ("dessert", "cake", "cookie", "pie", "sweet", "pudding", "ice cream", "candy", "brownie", "pastry")),
    ("breakfast", ("breakfast", "brunch", "pancake", "waffle", "oatmeal")),
    ("soup", ("soup", "stew", "chili")),
    ("salad", ("salad",)),
    ("snack", ("appetizer", "snack", "dip")),
    ("side", ("side dish", "side")),
    ("drink", ("drink", "beverage", "cocktail", "smoothie", "tea", "coffee")),
    ("bread", ("bread", "muffin")),
)


def clean_wiki(text: str) -> str:
    text = unescape(text or "")
    text = _REF.sub("", text)
    text = text.replace("<br/>", " ").replace("<br />", " ").replace("<br>", " ")
    text = _TAG.sub(" ", text)
    previous = None
    while previous != text:
        previous = text
        text = _TEMPLATE.sub("", text)
    text = _LINK.sub(lambda m: m.group(2), text)
    text = _LINK_BARE.sub(lambda m: m.group(1).split(":")[-1], text)
    text = _BOLD.sub("", text)
    text = text.replace("|", " ")
    text = re.sub(r"\s+", " ", text).strip(" \n\t*")
    return text.strip()


def _field(wikitext: str, name: str) -> str:
    match = re.search(rf"\|\s*{name}\s*=\s*(.*?)(?=\n\||\n\}})", wikitext, re.I | re.S)
    return match.group(1).strip() if match else ""


def summary_image(wikitext: str) -> str:
    image = _field(wikitext, "image")
    match = re.search(r"(?:File|Image):([^|\]]+)", image, re.I)
    if match:
        return "File:" + match.group(1).strip().replace("_", " ")
    return ""


def _section(wikitext: str, titles: tuple[str, ...]) -> str:
    pattern = r"^==+\s*(?:" + "|".join(re.escape(t) for t in titles) + r")[^==\n]*==+\s*$"
    match = re.search(pattern, wikitext, re.I | re.M)
    if not match:
        return ""
    rest = wikitext[match.end():]
    nxt = re.search(r"^==+[^=].*==+\s*$", rest, re.M)
    return rest[: nxt.start()] if nxt else rest


def ingredients_from(wikitext: str) -> list[dict]:
    block = _section(wikitext, ("Ingredients", "Ingredient"))
    items = []
    for line in block.splitlines():
        raw = line.strip()
        if not raw.startswith("*"):
            continue
        text = clean_wiki(raw.lstrip("*").strip())
        if not text or text.lower().startswith("see "):
            continue
        items.append(_structure_ingredient(text))
    return items


_UNITS = (
    "tablespoons", "tablespoon", "tbsp", "teaspoons", "teaspoon", "tsp",
    "cups", "cup", "pints", "pint", "quarts", "quart", "gallons", "gallon",
    "ounces", "ounce", "oz", "pounds", "pound", "lb", "lbs",
    "grams", "gram", "kilograms", "kilogram", "kg", "ml", "liters", "liter", "litres", "litre",
    "cloves", "clove", "pinches", "pinch", "cans", "can", "packages", "package",
    "slices", "slice", "sticks", "stick", "heads", "head", "bunches", "bunch",
    "sprigs", "sprig", "fillets", "fillet",
)


def _structure_ingredient(text: str) -> dict:
    note = ""
    without_paren = text
    paren = re.search(r"\(([^)]*)\)", text)
    if paren:
        note = paren.group(1).strip()
        without_paren = (text[: paren.start()] + " " + text[paren.end():]).strip()
        without_paren = re.sub(r"\s+", " ", without_paren)
    match = re.match(
        r"^(?P<qty>\d+\s+\d/\d|\d+/\d|\d+(?:\.\d+)?|a|an)?\s*(?P<rest>.*)$",
        without_paren,
        re.I,
    )
    qty = (match.group("qty") or "").strip() if match else ""
    rest = (match.group("rest") or without_paren).strip() if match else without_paren
    unit = ""
    item = rest
    lower = rest.lower()
    for candidate in _UNITS:
        if lower.startswith(candidate + " ") or lower == candidate:
            unit = candidate
            item = rest[len(candidate):].strip()
            break
    item = re.sub(r"^(of)\s+", "", item, flags=re.I)
    return {
        "text": text,
        "quantity": qty,
        "unit": unit,
        "item": item,
        "note": note,
    }


def steps_from(wikitext: str) -> list[str]:
    block = _section(wikitext, ("Procedure (brief)", "Procedure", "Instructions", "Method", "Directions", "Preparation"))
    # Prefer the brief procedure when both exist: the caller passes full text,
    # and Procedure (brief) is listed first in the title group only if we try it.
    brief = _section(wikitext, ("Procedure (brief)",))
    if brief.strip():
        block = brief
    steps = []
    for line in block.splitlines():
        raw = line.strip()
        if not raw.startswith("#") or raw.startswith("#*"):
            continue
        text = clean_wiki(raw.lstrip("#").strip())
        if text:
            steps.append(text)
    return steps


def _minutes(time_text: str) -> int | None:
    plain = clean_wiki(time_text).lower()
    if not plain:
        return None
    total = 0
    found = False
    for count, unit in re.findall(r"(\d+(?:\.\d+)?)\s*(hours?|hrs?|minutes?|mins?)", plain):
        found = True
        value = float(count)
        if unit.startswith("h"):
            total += int(round(value * 60))
        else:
            total += int(round(value))
    return total or None if found else None


def cuisine_from(wikitext: str, categories: list[str]) -> str:
    for match in re.finditer(r"Cuisine of ([^|\]]+)", wikitext, re.I):
        name = clean_wiki(match.group(1)).lower()
        if name in _CUISINES:
            return _CUISINES[name]
    # Pipe display: [[Cookbook:Cuisine of the United States|United States]]
    for match in re.finditer(r"\[\[Cookbook:Cuisine of [^|\]]+\|([^\]]+)\]\]", wikitext, re.I):
        name = match.group(1).strip().lower()
        if name in _CUISINES:
            return _CUISINES[name]
    for category in categories:
        low = category.lower()
        for key, label in _CUISINES.items():
            if key in low and ("cuisine" in low or "recipe" in low):
                return label
    return ""


def meal_type_from(wikitext: str, categories: list[str]) -> str:
    summary = clean_wiki(_field(wikitext, "category")).lower()
    blob = " ".join([summary, *[c.lower() for c in categories]])
    for meal, words in _MEAL_RULES:
        if any(word in blob for word in words):
            return meal
    if "main" in blob or "entree" in blob or "entrée" in blob:
        return "dinner"
    return "dinner"


def is_draft(title: str, categories: list[str], namespace: int) -> bool:
    if namespace in {2, 3}:
        return True
    blob = " ".join([title, *categories]).lower()
    return "draft" in blob or "sandbox" in blob or "/user" in title.lower()


def recipe_title(page_title: str) -> str:
    name = page_title.split(":", 1)[-1]
    return name.replace("_", " ").strip()


def changes_note() -> str:
    return (
        "Normalized the ingredient list and steps, resized and compressed the dish photo "
        "for HUB Circle hosting, and added deterministic diet and allergen tags from the ingredient list. "
        "The recipe wording was lightly cleaned."
    )


def attribution_line(page_url: str, changes: str) -> str:
    return (
        f"Source: {page_url} · "
        "License: CC BY-SA 4.0 · "
        f"Changes: {changes}"
    )
