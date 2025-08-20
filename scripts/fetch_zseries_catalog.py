#!/usr/bin/env python3
import argparse
import sys
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from app import create_app
from app.main.recipe_import import import_recipes_z


def main():
    parser = argparse.ArgumentParser(description="Fetch Z-series recipe catalog using device token")
    parser.add_argument("--token", required=True, help="Z-series token (Product ID)")
    args = parser.parse_args()

    app = create_app(debug=False)
    with app.app_context():
        import_recipes_z(args.token)
        print("Z-series catalog import completed.")


if __name__ == "__main__":
    sys.exit(main())

