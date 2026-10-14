#!/usr/bin/env python3
"""Build the importable Tabletop Simulator Saved Object for the BattleTech Dice Mat.

Embeds src/battletech_dice_mat.lua into a TTS Saved Object JSON:

    python3 tools/build_saved_object.py

Output: dist/BattleTech Dice Mat.json (+ a 256x256 .png thumbnail made from docs/preview.png)
Copy both into the "Saves/Saved Objects" folder of your TTS data directory:
    Windows: %USERPROFILE%\\Documents\\My Games\\Tabletop Simulator\\Saves\\Saved Objects
    macOS:   ~/Library/Tabletop Simulator/Saves/Saved Objects
    Linux:   ~/.local/share/Tabletop Simulator/Saves/Saved Objects
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "battletech_dice_mat.lua"
DIST = ROOT / "dist"
NAME = "BattleTech Dice Mat"

DESCRIPTION = (
    "Portable BattleTech dice roller in the style of the Hutber 40K dice table. "
    "Pick a color, +2D6 per weapon, ROLL IN 2s BY COLOR: every color gets its own row and "
    "its dice are paired in 2s. READ AS shows to-hit, hit location, cluster hits or crit checks. "
    "Click HELP on the mat for instructions."
)


def build():
    lua = SRC.read_text(encoding="utf-8")
    mat = {
        "GUID": "b7d401",
        "Name": "BlockSquare",
        "Transform": {
            "posX": 0.0, "posY": 2.0, "posZ": 0.0,
            "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0,
            "scaleX": 25.5, "scaleY": 0.25, "scaleZ": 16.15,
        },
        "Nickname": NAME,
        "Description": DESCRIPTION,
        "GMNotes": "",
        "ColorDiffuse": {"r": 0.105, "g": 0.115, "b": 0.125},
        "LayoutGroupSortIndex": 0,
        "Value": 0,
        # Unlocked so it settles onto whatever table/map it is spawned on;
        # players lock it (L) once it is where they want it.
        "Locked": False,
        "Grid": False,
        "Snap": False,
        "IgnoreFoW": False,
        "MeasureMovement": False,
        "DragSelectable": True,
        "Autoraise": True,
        "Sticky": False,
        "Tooltip": True,
        "GridProjection": False,
        "HideWhenFaceDown": False,
        "Hands": False,
        "LuaScript": lua,
        "LuaScriptState": "",
        "XmlUI": "",
    }
    saved = {
        "SaveName": NAME,
        "Date": "",
        "VersionNumber": "",
        "GameMode": "",
        "GameType": "",
        "GameComplexity": "",
        "Tags": [],
        "Gravity": 0.5,
        "PlayArea": 0.5,
        "Table": "",
        "Sky": "",
        "Note": "",
        "TabStates": {},
        "LuaScript": "",
        "LuaScriptState": "",
        "XmlUI": "",
        "ObjectStates": [mat],
    }
    DIST.mkdir(exist_ok=True)
    out = DIST / (NAME + ".json")
    out.write_text(json.dumps(saved, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", out.relative_to(ROOT))
    preview = ROOT / "docs" / "preview.png"
    if preview.exists():
        thumb = DIST / (NAME + ".png")
        write_thumbnail(preview, thumb)
        print("wrote", thumb.relative_to(ROOT))


def write_thumbnail(src, dst, size=256):
    """Saved Object thumbnails are square (TTS writes 256x256): letterbox the preview."""
    from PIL import Image

    img = Image.open(src).convert("RGB")
    img.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGB", (size, size), (27, 29, 32))
    canvas.paste(img, ((size - img.width) // 2, (size - img.height) // 2))
    canvas.save(dst, optimize=True)


if __name__ == "__main__":
    build()
