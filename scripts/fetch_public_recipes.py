#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

# Default entry URL for PicoBrew community recipes
DEFAULT_START_URL = "https://www.picobrew.com/publicrecipes/publicrecipes"


def log(msg: str):
    print(f"[fetch_public_recipes] {msg}", flush=True)


def safe_filename(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]", "_", name)[:200]


def is_same_domain(base: str, link: str) -> bool:
    bu = urlparse(base)
    lu = urlparse(link)
    return (lu.netloc == "" or lu.netloc == bu.netloc)


def extract_links(html: str, base_url: str):
    soup = BeautifulSoup(html, "html.parser")
    hrefs = []
    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        full = urljoin(base_url, href)
        # Filter to same domain and paths that look like public recipe pages
        if (is_same_domain(base_url, full)
                and (
                    "/publicrecipes/recipe" in full
                    or "/publicrecipes/details" in full
                    or ("/publicrecipes" in full and full.rstrip("/") != DEFAULT_START_URL.rstrip("/"))
                )):
            hrefs.append(full)
    return list(dict.fromkeys(hrefs))  # dedupe, preserve order


def fetch_all(start_url: str, out_dir: Path, delay: float = 0.5, timeout: int = 20):
    session = requests.Session()
    # Site currently presents an expired certificate; allow insecure with verify=False
    verify = False

    crawled = set()
    to_visit = [start_url]
    recipes = []

    out_dir.mkdir(parents=True, exist_ok=True)

    while to_visit:
        url = to_visit.pop(0)
        if url in crawled:
            continue
        crawled.add(url)

        try:
            log(f"GET {url}")
            resp = session.get(url, timeout=timeout, verify=verify)
            if resp.status_code != 200:
                log(f"WARN: status {resp.status_code} for {url}")
                continue
            html = resp.text
        except Exception as e:
            log(f"ERROR: {e} for {url}")
            continue

        # Save page if it appears to be a recipe detail page (heuristic)
        # Heuristics: contains keywords or specific structures; fall back to saving all under publicrecipes path
        is_detail = any(s in url for s in ["/publicrecipes/recipe", "/publicrecipes/details"]) or ("/publicrecipes/" in url and url.rstrip("/") != DEFAULT_START_URL.rstrip("/"))
        if is_detail:
            # Derive filename from URL path
            parsed = urlparse(url)
            slug = safe_filename(parsed.path.strip("/").replace("/", "_"))
            if not slug:
                slug = f"recipe_{len(recipes)+1}"
            html_path = out_dir / f"{slug}.html"
            html_path.write_text(html, encoding="utf-8")
            recipes.append({
                "url": url,
                "file": html_path.name,
                "title": BeautifulSoup(html, "html.parser").title.string.strip() if BeautifulSoup(html, "html.parser").title else slug,
            })

        # Extract more links (pagination and details)
        links = extract_links(html, url)
        for link in links:
            if link not in crawled and link not in to_visit:
                to_visit.append(link)

        time.sleep(delay)

    # Write index
    index = {
        "start_url": start_url,
        "count": len(recipes),
        "recipes": recipes,
    }
    (out_dir / "index.json").write_text(json.dumps(index, indent=2), encoding="utf-8")
    log(f"Saved {len(recipes)} pages to {out_dir}")


def main():
    parser = argparse.ArgumentParser(description="Fetch PicoBrew community public recipes")
    parser.add_argument("--start-url", default=DEFAULT_START_URL, help="Starting URL for community recipes")
    parser.add_argument("--out-dir", default=str(Path("app/recipes/public_html").resolve()), help="Output directory for saved HTML and index.json")
    parser.add_argument("--delay", type=float, default=0.5, help="Delay between requests (seconds)")
    parser.add_argument("--timeout", type=int, default=20, help="Request timeout (seconds)")
    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    fetch_all(args.start_url, out_dir, delay=args.delay, timeout=args.timeout)


if __name__ == "__main__":
    sys.exit(main())

