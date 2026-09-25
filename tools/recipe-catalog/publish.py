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
import mimetypes
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_OUT = ROOT / "out"


def objects(out: Path, prefix: str) -> list[tuple[Path, str]]:
    names = ["catalog.json", "trending.json", "credits.json", "import-report.json"]
    found: list[tuple[Path, str]] = []
    for name in names:
        path = out / name
        if path.is_file():
            found.append((path, f"{prefix}/{name}".lstrip("/")))
    image_dir = out / "images"
    if image_dir.is_dir():
        for path in sorted(image_dir.glob("*")):
            if path.is_file():
                found.append((path, f"{prefix}/images/{path.name}".lstrip("/")))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--dry-run", action="store_true", default=True)
    parser.add_argument("--upload", action="store_true", help="Perform the upload. Omit for a dry run.")
    args = parser.parse_args()
    dry_run = not args.upload

    bucket = os.environ.get("R2_BUCKET", "").strip()
    prefix = os.environ.get("R2_PREFIX", "recipe-catalog").strip().strip("/")
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
