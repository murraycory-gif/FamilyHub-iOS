"""Wikimedia Commons commercial-reuse screen.

Allowed: CC0, public domain, CC BY, CC BY-SA (any version).
A dual-licensed file is allowed when one of those licenses is offered.
NC, ND, fair use, GFDL-only, and unknown licenses are rejected.
"""

from __future__ import annotations

import re

_TAG = re.compile(r"<[^>]+>")

_REJECT_MARKERS = (
    "noncommercial",
    "non-commercial",
    "non commercial",
    "-nc",
    " nc ",
    "noderiv",
    "no derivatives",
    "no derivative",
    "-nd",
    " nd ",
    "fair use",
    "all rights reserved",
    "copyrighted",
)


def _plain(value: str) -> str:
    text = _TAG.sub(" ", value or "")
    text = text.replace("_", " ").replace("–", "-")
    return re.sub(r"\s+", " ", text).lower().strip()


def license_is_commercially_reusable(*parts: str) -> tuple[bool, str]:
    """Return (allowed, short label). Label is empty when rejected."""
    blob = " ".join(_plain(part) for part in parts if part)
    if not blob:
        return False, ""
    padded = f" {blob} "
    if any(marker in padded or marker in blob for marker in _REJECT_MARKERS):
        # A dual license such as "cc by-sa 4.0 or cc by-nc" must still be rejected
        # if we cannot tell them apart cleanly. Split on common separators and
        # accept only when every alternative is either empty or allowed, OR at
        # least one alternative is an allowed license with no NC/ND of its own.
        alternatives = re.split(r"\s+(?:\||/| or | and )\s+", blob)
        allowed = [alt for alt in alternatives if _alternative_ok(alt)]
        if not allowed:
            return False, ""
        return True, _label(allowed[0])
    if _alternative_ok(blob):
        return True, _label(blob)
    return False, ""


def _alternative_ok(text: str) -> bool:
    padded = f" {text} "
    if any(marker in padded or marker in text for marker in _REJECT_MARKERS):
        return False
    if any(token in text for token in ("cc0", "cc-zero", "cc zero", "public domain", "pdm")):
        return True
    if re.search(r"\bpd\b", text) or text.strip() in {"pd", "publicdomain"}:
        return True
    # CC BY or CC BY-SA, any version, without NC/ND (already rejected above).
    if re.search(r"\bcc(?:-| )by(?:-| )sa\b", text):
        return True
    if re.search(r"\bcc(?:-| )by\b", text):
        return True
    if "attribution-share alike" in text or "attribution share alike" in text:
        return True
    if "attribution" in text and "share alike" in text:
        return True
    if re.search(r"\battribution\b", text) and "noncommercial" not in text and "no deriv" not in text:
        # "Attribution 2.0" style UsageTerms.
        if "share" not in text or "share alike" in text:
            return True
    return False


def _label(text: str) -> str:
    if any(token in text for token in ("cc0", "cc-zero", "cc zero")):
        return "CC0"
    if "public domain" in text or re.search(r"\bpd\b", text):
        return "Public domain"
    version = ""
    match = re.search(r"(\d+(?:\.\d+)?)", text)
    if match:
        version = " " + match.group(1)
    if re.search(r"\bcc(?:-| )by(?:-| )sa\b", text) or "share alike" in text:
        return f"CC BY-SA{version}".strip()
    if re.search(r"\bcc(?:-| )by\b", text) or "attribution" in text:
        return f"CC BY{version}".strip()
    return "Public domain"
