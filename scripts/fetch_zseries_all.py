#!/usr/bin/env python3
import argparse
import sys
import time
from pathlib import Path
import requests
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from app import create_app
from app.main.config import MachineType
from app.main.recipe_import import ZSeriesDataSyncURI, ZSeriesMetaSyncURI, Z_AUTH_TOKEN
from app.main.recipe_parser import ZSeriesRecipeImport
from flask import current_app


def fetch_list(session: requests.Session, token: str, kind: int, max_count: int, offset: int):
    uri = ZSeriesMetaSyncURI(token)
    r = session.post(uri, verify=False, json={"Kind": kind, "MaxCount": max_count, "Offset": offset})
    if r.status_code != 200:
        raise RuntimeError(f"Failed list at offset {offset}: {r.status_code} {r.text}")
    return r.json()


def fetch_detail(session: requests.Session, token: str, rid: str):
    uri = ZSeriesDataSyncURI(token, rid)
    r = session.get(uri, verify=False)
    if r.status_code != 200:
        raise RuntimeError(f"Failed detail {rid}: {r.status_code} {r.text}")
    return r.json()


def main():
    parser = argparse.ArgumentParser(description="Fetch ALL Z-series recipes and import to local library")
    parser.add_argument("--token", required=True, help="Z-series token (Product ID)")
    parser.add_argument("--max", type=int, default=200, help="Page size per request (default 200)")
    parser.add_argument("--sleep", type=float, default=0.1, help="Delay between requests")
    args = parser.parse_args()

    app = create_app(debug=False)
    with app.app_context():
        session = requests.Session()
        session.headers = requests.structures.CaseInsensitiveDict({
            "host": "www.picobrew.com",
            "Authorization": Z_AUTH_TOKEN,
            "Content-Type": "application/json",
        })

        total = 0
        offset = 0
        imported = 0
        seen_ids = set()
        while True:
            try:
                listing = fetch_list(session, args.token, kind=1, max_count=args.max, offset=offset)
            except Exception as e:
                print(f"[zseries-all] list error at offset {offset}: {e}")
                break
            recipes = listing.get("Recipes") or []
            if not recipes:
                break
            print(f"[zseries-all] batch offset={offset} count={len(recipes)}")
            for rec in recipes:
                rid = rec.get("ID")
                if rid is None or rid in seen_ids:
                    continue
                seen_ids.add(rid)
                try:
                    session.headers = requests.structures.CaseInsensitiveDict({
                        "host": "www.picobrew.com",
                        "Authorization": Z_AUTH_TOKEN,
                    })
                    detail = fetch_detail(session, args.token, str(rid))
                    ZSeriesRecipeImport(detail)
                    imported += 1
                except Exception as e:
                    print(f"[zseries-all] detail error for {rid}: {e}")
                time.sleep(args.sleep)
            total += len(recipes)
            offset += len(recipes)
            time.sleep(args.sleep)
        print(f"[zseries-all] done: listed={total} imported={imported}")


if __name__ == "__main__":
    sys.exit(main())

