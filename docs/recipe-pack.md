# HUB recipe pack

The dinner catalog is our pack. The app does not call a recipe API.

## File

`recipe-pack.json` at the root of the Cloudflare R2 bucket. The app reads it from `RecipeSources.r2CatalogBase` (nil until the bucket URL is set) and caches the bytes on device. First launch and offline use `FamilyHub/Resources/SeedRecipes.json`, which is the same schema.

## Schema

```json
{
  "version": 1,
  "recipes": [
    {
      "id": "hub-tacos",
      "name": "Weeknight tacos",
      "category": "Tex-Mex",
      "cuisine": "Mexican",
      "ingredients": ["1 lb ground beef"],
      "instructions": "Brown the beef.",
      "imageURL": "https://recipes.example.r2.dev/images/hub-tacos.jpg",
      "diets": ["glutenFree"],
      "trendingRank": 1,
      "sourceName": "HUB"
    }
  ]
}
```

| Field | Rule |
|---|---|
| `version` | Integer, 1 or newer. |
| `id` | Unique, not empty. |
| `name` | Not empty. |
| `category`, `cuisine` | Free text. Cuisine is what search-by-cuisine matches. |
| `ingredients`, `instructions` | Ingredient lines and the method. |
| `imageURL` | Empty, or an `https` URL on our bucket. The card shows that image. An empty URL shows the dish name. |
| `diets` | Zero or more of `vegan`, `vegetarian`, `pescatarian`, `keto`, `paleo`, `glutenFree`, `dairyFree`, `nutFree`, `eggFree`, `soyFree`, `halal`, `kosher`, `lowSodium`, `lowCarb`, `diabeticFriendly`. A selected filter matches only when the tag is present. |
| `trendingRank` | Omitted, null, or an integer 1 or higher. Lower numbers appear first on Trending now. |
| `sourceName` | Not empty. Shown on the recipe as the source. |

`RecipePack.validate()` checks these rules. A pack that fails validation is not cached.
