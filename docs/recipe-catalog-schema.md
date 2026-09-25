# HUB recipe catalog schema

This is the catalog the app loads. Publish `recipe-pack.json` at the root of our Cloudflare R2 bucket. The app also ships `FamilyHub/Resources/SeedRecipes.json` in this same shape for first launch and offline use.

Codable types: `RecipePack` and `RecipePackItem` in `FamilyHub/Models/RecipePack.swift`. `RecipePack.validate()` is the check. A pack that fails is not cached.

## File

```json
{
  "version": 1,
  "recipes": [
    {
      "id": "hub-tacos",
      "name": "Weeknight tacos",
      "category": "Tex-Mex",
      "cuisine": "Mexican",
      "ingredients": ["1 lb ground beef", "8 corn tortillas"],
      "instructions": "Brown the beef. Warm the tortillas.",
      "imageURL": "https://recipes.example.r2.dev/images/hub-tacos.jpg",
      "diets": ["glutenFree"],
      "trendingRank": 1,
      "sourceName": "Wikibooks Cookbook",
      "license": "CC BY-SA 4.0",
      "changes": "Ingredient lines shortened for the card",
      "sourceURL": "https://en.wikibooks.org/wiki/Cookbook:Weeknight_Tacos"
    }
  ]
}
```

## Fields

| Field | Rule |
|---|---|
| `version` | Integer. `1` is the only version the app reads today. |
| `recipes` | Array. Ids must be unique. |
| `id` | Not empty. Stable across republishes. |
| `name` | Not empty. The dish name. Shown on the name tile when there is no photo. |
| `category` | Free text. Meal style, such as Tex-Mex or Weeknight. |
| `cuisine` | Free text. Search-by-cuisine matches this. |
| `ingredients` | Array of strings. One line per ingredient. Diet tags are trusted when present. An empty list does not pass a diet filter. |
| `instructions` | The method, as one string. |
| `imageURL` | Empty, or `https` on our bucket for a photo of this exact dish. Empty shows the name tile. Do not put Unsplash, TheMealDB, or a Wikimedia file URL here. Those are rejected. |
| `diets` | Zero or more of the tokens below. |
| `trendingRank` | Omitted, `null`, or an integer `1` or higher. Lower numbers come first on Trending now. `null` means not trending. |
| `sourceName` | Not empty. The work the text came from. |
| `license` | Not empty. The license name, such as `CC BY-SA 4.0` or `HUB original`. |
| `changes` | What we changed. Use `None` when the text is unchanged. |
| `sourceURL` | Page for the source. Empty string when there is no page. |

The recipe screen shows one line: `sourceName · license · changes`.

## Diet tokens

`vegan`, `vegetarian`, `pescatarian`, `keto`, `paleo`, `glutenFree`, `dairyFree`, `nutFree`, `eggFree`, `soyFree`, `halal`, `kosher`, `lowSodium`, `lowCarb`, `diabeticFriendly`.

`halal` and `kosher` mean the ingredients look compatible. They are not a certification.

`glutenFree`, `dairyFree`, `nutFree`, `eggFree`, and `soyFree` are ingredient screens. The app tells people to check labels.

## Photos

Only a real photo of that dish, hosted on our bucket. No stock photo, no map, no generated stand-in. When the pipeline has no such photo, set `imageURL` to `""`.
