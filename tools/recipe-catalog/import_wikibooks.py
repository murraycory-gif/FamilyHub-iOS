#!/usr/bin/env python3
"""Import Wikibooks Cookbook recipes into the HUB Circle catalog.

Uses the MediaWiki API only (en.wikibooks.org Category:Recipes, photos from
Wikimedia Commons). No third-party recipe runtime. Throttled, with a
descriptive User-Agent. Skips user drafts. Keeps about --limit recipes that
have a commercially reusable dish photo (CC0, PD, CC BY, CC BY-SA).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from datetime import datetime, timezone
from html import unescape
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from recipe_catalog import SCHEMA_VERSION
from recipe_catalog.images import compress_image
from recipe_catalog.licenses import license_is_commercially_reusable
from recipe_catalog.mediawiki import (
    COMMONS,
    WIKIBOOKS,
    MediaWiki,
    category_pages,
    commons_info,
    page_batch,
)
from recipe_catalog.parse import (
    attribution_line,
    changes_note,
    cuisine_from,
    ingredients_from,
    is_draft,
    meal_type_from,
    recipe_title,
    steps_from,
    summary_image,
    _field,
    _minutes,
    clean_wiki,
)
from recipe_catalog.tag_diets import apply_tags

PHOTO_CATEGORY = "Category:Recipes with images"
TEXT_LICENSE = "CC BY-SA 4.0"
TEXT_LICENSE_URL = "https://creativecommons.org/licenses/by-sa/4.0/"
SKIP_FILE = re.compile(
    r"(icon|logo|commons-logo|wikibooks|2o5dots|nuvola|crystal|svg$|implement|utensil|oven\.|knife|beater)",
    re.I,
)
SEASONAL_WORDS = (
    "apple", "pumpkin", "squash", "sweet potato", "cinnamon", "stew", "chili",
    "chilli", "soup", "pie", "mushroom", "pear", "cranberry", "caramel",
    "nutmeg", "harvest", "roast", "cider", "pecan", "maple",
)


def slug(title: str) -> str:
    text = unicodedata.normalize("NFKD", title)
    text = text.encode("ascii", "ignore").decode("ascii").lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text or "recipe"


def artist_text(raw: str) -> str:
    text = re.sub(r"<[^>]+>", " ", unescape(raw or ""))
    text = re.sub(r"\s+", " ", text).strip()
    return text[:300]


def candidate_files(page: dict, wikitext: str) -> list[str]:
    preferred = summary_image(wikitext)
    names = []
    if preferred:
        names.append(preferred if preferred.startswith("File:") else f"File:{preferred}")
    for image in page.get("images") or []:
        title = image.get("title") or ""
        if title and title not in names:
            names.append(title)
    kept = []
    for name in names:
        if not re.search(r"\.(jpe?g|png|webp)$", name, re.I):
            continue
        if SKIP_FILE.search(name):
            continue
        kept.append(name)
    return kept


def history_url(title: str) -> str:
    quoted = title.replace(" ", "_")
    return f"https://en.wikibooks.org/w/index.php?title={quoted}&action=history"


def build_recipe(page: dict, photo: dict, image_meta: dict) -> dict | None:
    title = page["title"]
    wikitext = page["wikitext"]
    categories = [c.get("title", "") for c in page.get("categories") or []]
    ingredients = ingredients_from(wikitext)
    steps = steps_from(wikitext)
    if len(ingredients) < 2 or len(steps) < 1:
        return None
    display = recipe_title(title)
    page_url = page.get("fullurl") or f"https://en.wikibooks.org/wiki/{title.replace(' ', '_')}"
    changes = changes_note()
    recipe_id = f"wikibooks-{slug(display)}"
    hosted = f"images/{recipe_id}.jpg"
    info = photo["info"]
    meta = info.get("extmetadata") or {}
    license_name = image_meta["license"]
    recipe = {
        "id": recipe_id,
        "title": display,
        "cuisine": cuisine_from(wikitext, categories),
        "mealType": meal_type_from(wikitext, categories),
        "servings": clean_wiki(_field(wikitext, "servings")),
        "totalTimeMinutes": _minutes(_field(wikitext, "time")),
        "totalTimeText": clean_wiki(_field(wikitext, "time")),
        "ingredients": ingredients,
        "steps": steps,
        "images": [
            {
                "hostedPath": hosted,
                "width": image_meta["width"],
                "height": image_meta["height"],
                "bytes": image_meta["bytes"],
                "attribution": {
                    "author": artist_text((meta.get("Artist") or {}).get("value", "")),
                    "license": license_name,
                    "licenseURL": (meta.get("LicenseUrl") or {}).get("value", ""),
                    "sourceURL": f"https://commons.wikimedia.org/wiki/{photo['file'].replace(' ', '_')}",
                    "commonsFile": photo["file"],
                },
            }
        ],
        "source": {
            "pageURL": page_url,
            "pageTitle": title,
            "license": TEXT_LICENSE,
            "licenseURL": TEXT_LICENSE_URL,
            "authorHistoryURL": history_url(title),
            "changesMade": changes,
        },
        "attributionLine": attribution_line(page_url, changes),
    }
    return apply_tags(recipe)


def content_hash(recipes: list[dict]) -> str:
    payload = json.dumps(recipes, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def write_trending(path: Path, recipes: list[dict]) -> None:
    ranked = sorted(recipes, key=lambda item: item["title"].lower())
    editor = [item["id"] for item in ranked[:12]]
    seasonal = []
    for item in ranked:
        blob = " ".join([
            item["title"],
            " ".join(step for step in item["steps"][:2]),
            " ".join(ing.get("item", "") for ing in item["ingredients"]),
        ]).lower()
        if any(word in blob for word in SEASONAL_WORDS):
            seasonal.append({"id": item["id"], "tags": ["fall", "october"]})
    document = {
        "schemaVersion": SCHEMA_VERSION,
        "generatedFor": "2026-10",
        "season": "fall",
        "editorPicks": editor,
        "seasonal": seasonal,
    }
    path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_credits(path: Path, recipes: list[dict]) -> None:
    photos = []
    lines = []
    for recipe in recipes:
        image = recipe["images"][0]
        attr = image["attribution"]
        photos.append({
            "recipeId": recipe["id"],
            "recipeTitle": recipe["title"],
            "hostedPath": image["hostedPath"],
            "author": attr.get("author") or "Wikimedia Commons contributor",
            "license": attr.get("license"),
            "licenseURL": attr.get("licenseURL"),
            "sourceURL": attr.get("sourceURL"),
        })
        lines.append({
            "recipeId": recipe["id"],
            "title": recipe["title"],
            "line": recipe["attributionLine"],
            "sourceURL": recipe["source"]["pageURL"],
            "license": recipe["source"]["license"],
            "licenseURL": recipe["source"]["licenseURL"],
            "authorHistoryURL": recipe["source"]["authorHistoryURL"],
            "changesMade": recipe["source"]["changesMade"],
        })
    document = {
        "schemaVersion": SCHEMA_VERSION,
        "text": {
            "work": "Wikibooks Cookbook",
            "site": "https://en.wikibooks.org",
            "category": "Category:Recipes",
            "license": TEXT_LICENSE,
            "licenseURL": TEXT_LICENSE_URL,
            "note": (
                "Recipe text is from the Wikibooks Cookbook and is available under "
                "CC BY-SA 4.0. Each recipe keeps a link to its page and its author history."
            ),
        },
        "photos": photos,
        "recipes": lines,
    }
    path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=200)
    parser.add_argument("--out", type=Path, default=ROOT / "out")
    parser.add_argument("--delay", type=float, default=0.35)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    out: Path = args.out
    image_dir = out / "images"
    image_dir.mkdir(parents=True, exist_ok=True)
    client = MediaWiki(delay=args.delay)

    accepted: list[dict] = []
    seen_titles: set[str] = set()
    if args.resume and (out / "catalog.json").is_file():
        previous = json.loads((out / "catalog.json").read_text(encoding="utf-8"))
        accepted = list(previous.get("recipes") or [])
        seen_titles = {item.get("source", {}).get("pageTitle", "") for item in accepted}
        print(f"Resuming with {len(accepted)} recipes", flush=True)

    print(f"Listing {PHOTO_CATEGORY} (pages that sit in Category:Recipes and have a photo)…", flush=True)
    members = category_pages(client, PHOTO_CATEGORY)
    members = [
        m for m in members
        if m.get("ns") == 102 and not is_draft(m["title"], [], m["ns"]) and m["title"] not in seen_titles
    ]
    print(f"{len(members)} cookbook pages to screen", flush=True)
    rejected_license = 0
    skipped_draft = 0
    skipped_incomplete = 0
    problems: list[str] = []
    seen_ids: set[str] = {item["id"] for item in accepted}

    for start in range(0, len(members), 8):
        if len(accepted) >= args.limit:
            break
        chunk = members[start:start + 8]
        try:
            pages = page_batch(client, [item["title"] for item in chunk])
        except Exception as exc:  # noqa: BLE001
            problems.append(f"page batch failed at {start}: {exc}")
            continue
        prepared = []
        files: list[str] = []
        for page in pages:
            if page.get("missing") is not None:
                continue
            title = page.get("title") or ""
            categories = [c.get("title", "") for c in page.get("categories") or []]
            namespace = page.get("ns", 0)
            if is_draft(title, categories, namespace):
                skipped_draft += 1
                continue
            if "Category:Recipes" not in categories:
                skipped_incomplete += 1
                continue
            if title in seen_titles:
                continue
            revision = ((page.get("revisions") or [{}])[0].get("slots") or {}).get("main") or {}
            wikitext = revision.get("*") or revision.get("content") or ""
            if not wikitext:
                skipped_incomplete += 1
                continue
            page["wikitext"] = wikitext
            names = candidate_files(page, wikitext)
            if not names:
                skipped_incomplete += 1
                continue
            page["candidates"] = names
            prepared.append(page)
            files.extend(names[:4])
        unique_files = list(dict.fromkeys(files))
        try:
            infos = commons_info(client, unique_files) if unique_files else {}
        except Exception as exc:  # noqa: BLE001
            problems.append(f"commons batch failed at {start}: {exc}")
            continue
        for page in prepared:
            if len(accepted) >= args.limit:
                break
            chosen = None
            for name in page["candidates"][:4]:
                info = infos.get(name) or {}
                if not info or not str(info.get("mime", "")).startswith("image/"):
                    rejected_license += 1
                    continue
                if (info.get("width") or 0) < 400 or (info.get("size") or 0) < 12000:
                    continue
                meta = info.get("extmetadata") or {}
                ok, label = license_is_commercially_reusable(
                    (meta.get("LicenseShortName") or {}).get("value", ""),
                    (meta.get("UsageTerms") or {}).get("value", ""),
                    (meta.get("License") or {}).get("value", ""),
                    (meta.get("LicenseUrl") or {}).get("value", ""),
                )
                if not ok:
                    rejected_license += 1
                    continue
                chosen = {"file": name, "info": info, "license": label}
                break
            if not chosen:
                continue
            url = (chosen["info"].get("url") or "").split("?")[0]
            if not url:
                problems.append(f"no download url for {page['title']}")
                continue
            try:
                blob = client.download(url)
                recipe_id = f"wikibooks-{slug(recipe_title(page['title']))}"
                if recipe_id in seen_ids:
                    recipe_id = f"{recipe_id}-{page.get('pageid')}"
                meta = compress_image(blob, image_dir / f"{recipe_id}.jpg")
                meta["license"] = chosen["license"]
            except Exception as exc:  # noqa: BLE001
                problems.append(f"image failed for {page.get('title')}: {exc}")
                continue
            recipe = build_recipe(page, chosen, meta)
            if recipe is None:
                skipped_incomplete += 1
                dest = image_dir / f"{recipe_id}.jpg"
                if dest.exists():
                    dest.unlink()
                continue
            recipe["id"] = recipe_id
            recipe["images"][0]["hostedPath"] = f"images/{recipe_id}.jpg"
            if recipe_id in seen_ids:
                continue
            seen_ids.add(recipe_id)
            accepted.append(recipe)
            print(f"[{len(accepted)}] {recipe['title']}", flush=True)

    accepted.sort(key=lambda item: item["id"])
    digest = content_hash(accepted)
    catalog = {
        "schemaVersion": SCHEMA_VERSION,
        "catalogId": "hub-circle-wikibooks",
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "contentHash": f"sha256:{digest}",
        "source": {
            "name": "Wikibooks Cookbook",
            "site": "https://en.wikibooks.org",
            "category": "Category:Recipes",
            "photoCategory": PHOTO_CATEGORY,
            "api": WIKIBOOKS,
            "commonsApi": COMMONS,
            "license": TEXT_LICENSE,
            "licenseURL": TEXT_LICENSE_URL,
        },
        "recipeCount": len(accepted),
        "recipes": accepted,
    }
    out.mkdir(parents=True, exist_ok=True)
    (out / "catalog.json").write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_trending(out / "trending.json", accepted)
    write_credits(out / "credits.json", accepted)
    report = {
        "recipeCount": len(accepted),
        "imageCount": len(accepted),
        "rejectedByLicenseScreen": rejected_license,
        "skippedDrafts": skipped_draft,
        "skippedIncomplete": skipped_incomplete,
        "contentHash": catalog["contentHash"],
        "problems": problems,
        "tagCounts": tag_counts(accepted),
    }
    (out / "import-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if accepted else 1


def tag_counts(recipes: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for recipe in recipes:
        for label in recipe.get("dietLabels") or []:
            if label.get("status") == "not_compatible":
                continue
            counts[label["id"]] = counts.get(label["id"], 0) + 1
    return dict(sorted(counts.items()))


if __name__ == "__main__":
    raise SystemExit(main())
