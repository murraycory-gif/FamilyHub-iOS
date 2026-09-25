"""Download a Commons file and store a JPEG at most 1200px and 250 KB."""

from __future__ import annotations

import io
from pathlib import Path

from PIL import Image, ImageOps

MAX_EDGE = 1200
MAX_BYTES = 250 * 1024


def compress_image(data: bytes, dest: Path) -> dict:
    with Image.open(io.BytesIO(data)) as incoming:
        image = ImageOps.exif_transpose(incoming)
        if image.mode not in ("RGB",):
            image = image.convert("RGB")
        image.thumbnail((MAX_EDGE, MAX_EDGE), Image.Resampling.LANCZOS)
        width, height = image.size
        quality = 85
        payload = b""
        while quality >= 40:
            buffer = io.BytesIO()
            image.save(buffer, format="JPEG", quality=quality, optimize=True, progressive=True)
            payload = buffer.getvalue()
            if len(payload) <= MAX_BYTES:
                break
            quality -= 5
        if len(payload) > MAX_BYTES:
            scale = (MAX_BYTES / len(payload)) ** 0.5 * 0.92
            resized = image.resize(
                (max(1, int(width * scale)), max(1, int(height * scale))),
                Image.Resampling.LANCZOS,
            )
            width, height = resized.size
            buffer = io.BytesIO()
            resized.save(buffer, format="JPEG", quality=55, optimize=True, progressive=True)
            payload = buffer.getvalue()
        if len(payload) > MAX_BYTES:
            raise ValueError(f"image still {len(payload)} bytes after compression")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(payload)
    return {"width": width, "height": height, "bytes": len(payload), "path": dest.as_posix()}
