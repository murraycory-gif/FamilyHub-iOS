# HUB Circle recipe catalog

Own catalog pipeline. Recipe text comes from the Wikibooks Cookbook (`Category:Recipes` on en.wikibooks.org, CC BY-SA 4.0) through the MediaWiki API. Dish photos come from Wikimedia Commons and are kept only when the file license is CC0, public domain, CC BY, or CC BY-SA. Nothing here calls a third-party recipe runtime.

Schema version 1.0.0 is documented in [`docs/recipe-catalog-schema.md`](../../docs/recipe-catalog-schema.md) and [`schema/recipe-catalog-1.0.0.schema.json`](schema/recipe-catalog-1.0.0.schema.json).

## Build

```bash
pip install -r tools/recipe-catalog/requirements.txt
python3 tools/recipe-catalog/import_wikibooks.py --limit 200
```

The import sets a descriptive User-Agent, waits between requests, and skips user drafts. Output lands in `tools/recipe-catalog/out/`:

- `catalog.json` — versioned catalog plus `contentHash`
- `images/*.jpg` — 1200px max, under 250 KB
- `trending.json` — editor picks and fall/October tags
- `credits.json` — text license, photo credits, and each recipe's Source · License · Changes line
- `import-report.json` — counts from the last run

```bash
python3 -m unittest discover -s tools/recipe-catalog/tests -v
```

Run that from the repo root with `PYTHONPATH=tools/recipe-catalog`.

## Publish

Dry run (no network upload):

```bash
python3 tools/recipe-catalog/publish.py --dry-run
```

Real upload, using environment variables only:

```bash
R2_BUCKET=your-bucket R2_ACCOUNT_ID=your-account \
  R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=... \
  python3 tools/recipe-catalog/publish.py --upload
```

Wrangler equivalent for the JSON catalog:

```bash
npx wrangler r2 object put "$R2_BUCKET/recipe-catalog/catalog.json" \
  --file tools/recipe-catalog/out/catalog.json --remote
```

A real upload is not part of the build.
