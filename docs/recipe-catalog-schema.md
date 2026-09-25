# HUB Circle recipe catalog schema

Schema version **1.0.0**. Machine-readable copy: [`tools/recipe-catalog/schema/recipe-catalog-1.0.0.schema.json`](../tools/recipe-catalog/schema/recipe-catalog-1.0.0.schema.json).

No app-side `RecipeProvider` schema was in `docs/` or the models when this catalog was defined. `CatalogRecipe` in the app is still the older MealDB-shaped struct (`id`, `name`, `category`, `area`, `thumb`, `instructions`, `ingredients`, `sourceURL`). A provider can map this catalog onto that struct:

| Catalog field | App `CatalogRecipe` |
| --- | --- |
| `id` | `id` |
| `title` | `name` |
| `mealType` | `category` |
| `cuisine` | `area` |
| `images[0].hostedPath` | `thumb` (resolve against the R2 public base) |
| `steps` joined with newlines | `instructions` |
| `ingredients[].text` | `ingredients` |
| `source.pageURL` | `sourceURL` |

## Document

`catalog.json` is a single JSON object:

- `schemaVersion` — `"1.0.0"`.
- `catalogId` — stable id for this catalog (`hub-circle-wikibooks`).
- `generatedAt` — UTC timestamp. Not part of the content hash.
- `contentHash` — `sha256:` plus the hex SHA-256 of the canonical `recipes` array (`sort_keys`, compact separators, UTF-8).
- `source` — Wikibooks Cookbook provenance and the text license (CC BY-SA 4.0).
- `recipeCount` — length of `recipes`.
- `recipes` — array of recipe objects, sorted by `id`.

## Recipe

- `id` — `wikibooks-` plus a slug of the title.
- `title` — dish name, without the `Cookbook:` prefix.
- `cuisine` — string, empty when the page does not say.
- `mealType` — one of `breakfast`, `soup`, `salad`, `snack`, `side`, `drink`, `bread`, `dessert`, `dinner`.
- `servings` — string as written (`"8"` or `"8–10"`).
- `totalTimeMinutes` — integer minutes when the summary states a time, otherwise `null`.
- `totalTimeText` — original time string.
- `ingredients` — objects `{text, quantity, unit, item, note}`. `text` is the display line. The other fields are best-effort structure.
- `steps` — ordered strings.
- `images` — one dish photo. `hostedPath` is relative to the catalog root (`images/<id>.jpg`, max edge 1200px, under 250 KB). `attribution` holds the Commons author, license, license URL, and file page URL.
- `source.pageURL` — Wikibooks page.
- `source.license` / `licenseURL` — CC BY-SA 4.0 for the text.
- `source.authorHistoryURL` — page history (the author list).
- `source.changesMade` — what HUB Circle changed.
- `attributionLine` — the single line `Source: … · License: CC BY-SA 4.0 · Changes: …`.
- `dietLabels` — see below. `dietCompatible` lists label ids whose status is not `not_compatible`.
- `nutrition` — omitted. Low-sodium and lower-sugar are not tagged without it.

## Diet labels

Each entry is `{id, status, disclaimer?, note?}`.

`status` is `compatible`, `not_compatible`, or `ingredients_compatible_not_certified` (halal and kosher only, and only when the ingredient screen passes).

Ids: `vegan`, `vegetarian`, `pescatarian`, `gluten-free`, `dairy-free`, `egg-free`, `soy-free`, `peanut-free`, `tree-nut-free`, `keto`, `paleo`, `halal`, `kosher`.

`peanut-free` and `tree-nut-free` include a check-labels disclaimer when compatible. Coconut and nutmeg are not treated as tree nuts. Butter beans are not dairy.

## Sidecars

- `trending.json` — `editorPicks` (ids) and `seasonal` entries tagged `fall` and `october`.
- `credits.json` — text license block, per-photo attribution, and the per-recipe Source · License · Changes line.

Photos must be CC0, public domain, CC BY, or CC BY-SA. NC, ND, fair use, GFDL-only, and unknown licenses are dropped.
