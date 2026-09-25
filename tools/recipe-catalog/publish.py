#!/usr/bin/env python3
"""Upload catalog artifacts to Cloudflare R2. Defaults to a dry run.

Environment (no secrets in source):
  R2_BUCKET            bucket name
  R2_PREFIX            optional key prefix, default "recipe-catalog"
  R2_ACCOUNT_ID        Cloudflare account id (S3 endpoint)
  R2_ACCESS_KEY_ID     R2 access key (or AWS_ACCESS_KEY_ID)
  R2_SECRET_ACCESS_KEY R2 secret (or AWS_SECRET_ACCESS_KEY)
  AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY are also read if R2_* keys are unset

Wrangler alternative, after `npx wrangler login` or CLOUDFLARE_API_TOKEN:
  npx wrangler r2 object put "$R2_BUCKET/recipe-catalog/catalog.json" --file tools/recipe-catalog/out/catalog.json --remote

This script does not upload unless --upload is passed. A real upload was not run
for the catalog build.
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_OUT = ROOT / "out"


DIET_TOKENS = {
    "vegan": "vegan",
    "vegetarian": "vegetarian",
    "pescatarian": "pescatarian",
    "keto": "keto",
    "paleo": "paleo",
    "gluten-free": "glutenFree",
    "dairy-free": "dairyFree",
    "egg-free": "eggFree",
    "soy-free": "soyFree",
    "halal": "halal",
    "kosher": "kosher",
    "low-sodium": "lowSodium",
    "low-carb": "lowCarb",
}


def diet_labels(recipe: dict) -> list[str]:
    compatible = {
        item.get("id")
        for item in recipe.get("dietLabels") or []
        if item.get("status") == "compatible"
    }
    labels = [token for key, token in DIET_TOKENS.items() if key in compatible]
    if "peanut-free" in compatible and "tree-nut-free" in compatible:
        labels.append("nutFree")
    return labels


def write_recipe_pack(out: Path, public_base: str) -> Path:
    """Write recipe-pack.json in the app's schema. Photos are bucket paths, never Wikimedia URLs."""
    catalog_path = out / "catalog.json"
    catalog = json.loads(catalog_path.read_text()) if catalog_path.is_file() else {"recipes": []}
    base = public_base.rstrip("/")
    recipes = []
    for index, recipe in enumerate(catalog.get("recipes") or [], start=1):
        images = recipe.get("images") or []
        hosted = ""
        if images:
            hosted = str(images[0].get("hostedPath") or "")
        file_name = Path(hosted).name if hosted else ""
        image_url = f"{base}/images/{file_name}" if base and file_name else ""
        if "wikimedia" in image_url.lower() or "unsplash" in image_url.lower():
            image_url = ""
        source = recipe.get("source") or {}
        ingredients = []
        for item in recipe.get("ingredients") or []:
            if isinstance(item, str):
                ingredients.append(item)
            elif isinstance(item, dict):
                ingredients.append(str(item.get("text") or item.get("item") or ""))
        steps = recipe.get("steps") or []
        if isinstance(steps, str):
            instructions = steps
        else:
            instructions = "\n".join(str(step) for step in steps)
        rank = index if index <= 12 else None
        recipes.append({
            "id": recipe.get("id") or f"hub-{index}",
            "name": recipe.get("title") or recipe.get("name") or "Recipe",
            "category": recipe.get("mealType") or recipe.get("category") or "",
            "cuisine": recipe.get("cuisine") or "",
            "ingredients": [line for line in ingredients if line],
            "instructions": instructions,
            "imageURL": image_url,
            "diets": diet_labels(recipe),
            "trendingRank": rank,
            "sourceName": "Wikibooks Cookbook",
            "license": source.get("license") or "CC BY-SA 4.0",
            "changes": source.get("changesMade") or "None",
            "sourceURL": source.get("pageURL") or "",
        })
    pack = {"version": 1, "recipes": recipes}
    dest = out / "recipe-pack.json"
    dest.write_text(json.dumps(pack, indent=2) + "\n")
    return dest


def objects(out: Path, prefix: str) -> list[tuple[Path, str]]:
    found: list[tuple[Path, str]] = []
    pack = out / "recipe-pack.json"
    if pack.is_file():
        key = f"{prefix}/recipe-pack.json".lstrip("/") if prefix else "recipe-pack.json"
        found.append((pack, key))
    image_dir = out / "images"
    if image_dir.is_dir():
        for path in sorted(image_dir.glob("*")):
            if path.is_file():
                key = f"{prefix}/images/{path.name}".lstrip("/") if prefix else f"images/{path.name}"
                found.append((path, key))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--dry-run", action="store_true", default=True)
    parser.add_argument("--upload", action="store_true", help="Perform the upload. Omit for a dry run.")
    args = parser.parse_args()
    dry_run = not args.upload

    bucket = os.environ.get("R2_BUCKET", "").strip()
    prefix = os.environ.get("R2_PREFIX", "").strip().strip("/")
    public_base = os.environ.get("R2_PUBLIC_BASE", "").strip()
    write_recipe_pack(args.out, public_base)
    account = os.environ.get("R2_ACCOUNT_ID", "").strip()
    access = os.environ.get("R2_ACCESS_KEY_ID") or os.environ.get("AWS_ACCESS_KEY_ID") or ""
    secret = os.environ.get("R2_SECRET_ACCESS_KEY") or os.environ.get("AWS_SECRET_ACCESS_KEY") or ""

    planned = objects(args.out, prefix)
    if not planned:
        print(f"No artifacts in {args.out}", file=sys.stderr)
        return 1

    print(f"{'DRY RUN' if dry_run else 'UPLOAD'} {len(planned)} objects" + (f" -> r2://{bucket}" if bucket else ""))
    for path, key in planned:
        print(f"  {path.stat().st_size:8d}  {key}")

    if dry_run:
        print("Dry run only. No upload was performed.")
        print("Exact upload command:")
        print(
            "  R2_BUCKET=your-bucket R2_ACCOUNT_ID=your-account "
            "R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=... "
            "python3 tools/recipe-catalog/publish.py --upload"
        )
        return 0

    if not bucket or not account or not access or not secret:
        print("Missing R2_BUCKET, R2_ACCOUNT_ID, and access keys.", file=sys.stderr)
        return 2

    import boto3
    from botocore.config import Config

    client = boto3.client(
        "s3",
        endpoint_url=f"https://{account}.r2.cloudflarestorage.com",
        aws_access_key_id=access,
        aws_secret_access_key=secret,
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )
    for path, key in planned:
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        client.upload_file(str(path), bucket, key, ExtraArgs={"ContentType": content_type})
        print(f"uploaded {key}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
