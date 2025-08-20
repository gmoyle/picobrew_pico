#!/usr/bin/env python3
import argparse
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from app import create_app
from app.main.config import MachineType
from app.main.recipe_import import import_recipes


def main():
    parser = argparse.ArgumentParser(description="Import Zymatic recipes for a user via GUID and Product ID")
    parser.add_argument("--guid", required=True, help="User profile GUID (accountId)")
    parser.add_argument("--product-id", required=True, help="Zymatic Product ID")
    args = parser.parse_args()

    app = create_app(debug=False)
    with app.app_context():
        import_recipes(args.product_id, args.guid, None, MachineType.ZYMATIC)
        print("Zymatic import completed.")

if __name__ == "__main__":
    main()

