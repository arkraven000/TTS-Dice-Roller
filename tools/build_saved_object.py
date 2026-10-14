#!/usr/bin/env python3
"""Build the importable Tabletop Simulator Saved Object for the BattleTech Dice Mat.

Embeds src/battletech_dice_mat.lua into a TTS Saved Object JSON:

    python3 tools/build_saved_object.py

Output: dist/BattleTech Dice Mat.json (+ .png thumbnail if docs/preview.png exists)
Copy both into:  Documents/My Games/Tabletop Simulator/Saves/Saved Objects/
"""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src" / "battletech_dice_mat.lua"
DIST = ROOT / "dist"
NAME = "BattleTech Dice Mat"

DESCRIPTION = (
    "Portable BattleTech dice roller. Rolls color-locked 2D6 pairs and gathers each pair "
    "back into its own numbered slot, in order. Resolves to-hit, hit location "
    "(Mech/Punch/Kick), cluster hits, crit checks, crit slots and PSR/2D6 rolls. "
    "Click HELP on the mat for instructions."
)


def build():
    lua = SRC.read_text(encoding="utf-8")
    mat = {
        "GUID": "b7dm01",
        "Name": "BlockSquare",
        "Transform": {
            "posX": 0.0, "posY": 1.2, "posZ": 0.0,
            "rotX": 0.0, "rotY": 180.0, "rotZ": 0.0,
            "scaleX": 25.5, "scaleY": 0.25, "scaleZ": 16.15,
        },
        "Nickname": NAME,
        "Description": DESCRIPTION,
        "GMNotes": "",
        "ColorDiffuse": {"r": 0.105, "g": 0.115, "b": 0.125},
        "LayoutGroupSortIndex": 0,
        "Value": 0,
        "Locked": True,
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
        "Tags": ["BTDiceMatBoard"],
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
        shutil.copyfile(preview, thumb)
        print("wrote", thumb.relative_to(ROOT))


if __name__ == "__main__":
    build()
