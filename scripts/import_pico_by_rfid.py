#!/usr/bin/env python3
import argparse
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from app import create_app
from app.main.config import MachineType
from app.main.recipe_import import import_recipes


def main():
    parser = argparse.ArgumentParser(description="Import Pico (Pico S/C/Pro) recipe by RFID for a device UID")
    parser.add_argument("--uid", required=True, help="Pico device UID (32-char)")
    parser.add_argument("--rfid", required=True, help="PicoPak RFID (14-char) to import")
    args = parser.parse_args()

    app = create_app(debug=False)
    with app.app_context():
        import_recipes(args.uid, None, args.rfid, MachineType.PICOBREW)
        print("Pico import completed.")

if __name__ == "__main__":
    main()

