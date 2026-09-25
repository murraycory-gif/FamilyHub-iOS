"""Throttled MediaWiki client for Wikibooks and Wikimedia Commons."""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request

USER_AGENT = (
    "HUBCircleRecipeCatalog/1.0 "
    "(https://github.com/murraycory-gif/FamilyHub-iOS; HUB Circle own recipe catalog; "
    "contact: catalog@import.hubcircle.local)"
)

WIKIBOOKS = "https://en.wikibooks.org/w/api.php"
COMMONS = "https://commons.wikimedia.org/w/api.php"


class MediaWiki:
    def __init__(self, delay: float = 0.35) -> None:
        self.delay = delay
        self._last = 0.0

    def get(self, endpoint: str, params: dict) -> dict:
        wait = self.delay - (time.monotonic() - self._last)
        if wait > 0:
            time.sleep(wait)
        query = urllib.parse.urlencode({**params, "format": "json"})
        request = urllib.request.Request(
            f"{endpoint}?{query}",
            headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.load(response)
        self._last = time.monotonic()
        return payload

    def download(self, url: str) -> bytes:
        import urllib.error
        delay = self.delay
        for attempt in range(5):
            wait = delay - (time.monotonic() - self._last)
            if wait > 0:
                time.sleep(wait)
            request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            try:
                with urllib.request.urlopen(request, timeout=90) as response:
                    data = response.read()
                self._last = time.monotonic()
                return data
            except urllib.error.HTTPError as exc:
                self._last = time.monotonic()
                if exc.code != 429 or attempt == 4:
                    raise
                time.sleep(15 * (attempt + 1))
                delay = max(delay, 1.0)
        raise RuntimeError("download failed")


def category_pages(client: MediaWiki, title: str) -> list[dict]:
    pages: list[dict] = []
    cont: dict[str, str] = {}
    while True:
        data = client.get(WIKIBOOKS, {
            "action": "query",
            "list": "categorymembers",
            "cmtitle": title,
            "cmlimit": "500",
            "cmtype": "page",
            **cont,
        })
        pages.extend(data.get("query", {}).get("categorymembers", []))
        if "continue" not in data:
            return pages
        cont = {"cmcontinue": data["continue"]["cmcontinue"]}


def page_batch(client: MediaWiki, titles: list[str]) -> list[dict]:
    data = client.get(WIKIBOOKS, {
        "action": "query",
        "prop": "revisions|images|categories|info",
        "rvprop": "content",
        "rvslots": "main",
        "inprop": "url",
        "imlimit": "20",
        "cllimit": "50",
        "titles": "|".join(titles),
        "redirects": "1",
    })
    pages = list(data.get("query", {}).get("pages", {}).values())
    # Follow image continuation only when a page hit the cap. Rare for recipes.
    return pages


def commons_info(client: MediaWiki, titles: list[str]) -> dict[str, dict]:
    found: dict[str, dict] = {}
    for start in range(0, len(titles), 20):
        chunk = titles[start:start + 20]
        data = client.get(COMMONS, {
            "action": "query",
            "prop": "imageinfo",
            "iiprop": "url|extmetadata|mime|size",
            "iiextmetadatafilter": "LicenseShortName|LicenseUrl|UsageTerms|Artist|License|Credit",
            "titles": "|".join(chunk),
        })
        for page in data.get("query", {}).get("pages", {}).values():
            title = page.get("title") or ""
            info = (page.get("imageinfo") or [None])[0]
            if title and info:
                found[title] = info
            elif title:
                found[title] = {}
    return found
