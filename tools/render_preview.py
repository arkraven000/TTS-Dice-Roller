#!/usr/bin/env python3
"""Render a top-down preview of the mat (as the White seat sees it) to docs/preview.png.

Runs the real Lua script against the mock TTS API, plays an example volley,
then draws every scripted button/input and each parked die.

    python3 tools/render_preview.py
"""
import json
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))
from run_tests import make_runtime  # noqa: E402

PX = 64  # pixels per world unit
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
BUTTON_UNITS = 500

EXAMPLE = r"""
onLoad("")
MOCK.run()
local function spawn(color, n)
  MOCK.click("pick_color_" .. color)
  MOCK.click("spawn_" .. (n or 2))
  MOCK.run()
end
-- a typical volley: 3 lasers (Red), an LRM (Blue), 2 SRMs (Green), a PPC (Yellow)
spawn(1, 6); spawn(2, 2); spawn(3, 4); spawn(4, 2)
MOCK.click("pick_color_1")
MOCK.click("btn_read_as")                 -- TO-HIT
input_number(self, "White", "8", false)
MOCK.forced_values = { 4, 5,  2, 3,  6, 6,  5, 4,  3, 3,  6, 2,  1, 4 }
MOCK.click("btn_roll_pairs", "Red")
MOCK.run()
"""


def rgb(c, default=(255, 255, 255)):
    if c is None:
        return default
    vals = [c[k] for k in (1, 2, 3)] if c[1] is not None else [c["r"], c["g"], c["b"]]
    return tuple(int(max(0, min(1, v)) * 255 + 0.5) for v in vals)


def main():
    lua = make_runtime()
    lua.execute(EXAMPLE)
    g = lua.globals()
    mat = g.self
    b = mat.getBoundsNormalized()
    w_world, d_world = b["size"]["x"], b["size"]["z"]
    W, H = int(w_world * PX), int(d_world * PX)
    img = Image.new("RGB", (W, H), (27, 29, 32))
    draw = ImageDraw.Draw(img)
    s = mat.getScale()

    def to_px(pos):
        p = g.MOCK.button_world(pos)
        return (p["x"] + w_world / 2) * PX, (d_world / 2 - p["z"]) * PX

    def font(size_world):
        return ImageFont.truetype(FONT, max(8, int(size_world * PX * 0.78)))

    def text(cx, cy, label, size_world, color):
        f = font(size_world)
        draw.multiline_text((cx, cy), label, font=f, fill=color, anchor="mm", align="center", spacing=2)

    for btn in mat._buttons.values():
        sc = btn.scale
        cx, cy = to_px(btn.position)
        fw = btn.font_size / BUTTON_UNITS * sc[1] * s["x"]
        if btn.width > 0:
            hw = btn.width / BUTTON_UNITS * sc[1] * s["x"] * PX / 2
            hh = btn.height / BUTTON_UNITS * sc[3] * s["z"] * PX / 2
            draw.rounded_rectangle((cx - hw, cy - hh, cx + hw, cy + hh), radius=6, fill=rgb(btn.color))
        if btn.label:
            text(cx, cy, btn.label, fw, rgb(btn.font_color, (0, 0, 0)))

    # In TTS an input keeps what the player typed; the mock only stores it in state.
    state = json.loads(g.onSave())
    for inp in mat._inputs.values():
        if inp.input_function == "input_number" and state["mode"] == 2:
            inp.value = state["tn"]
        sc = inp.scale
        cx, cy = to_px(inp.position)
        hw = inp.width / BUTTON_UNITS * sc[1] * s["x"] * PX / 2
        hh = inp.height / BUTTON_UNITS * sc[3] * s["z"] * PX / 2
        draw.rectangle((cx - hw, cy - hh, cx + hw, cy + hh), fill=(217, 217, 209), outline=(90, 90, 90))
        fw = inp.font_size / BUTTON_UNITS * sc[1] * s["x"]
        if inp.value:
            text(cx, cy, inp.value, fw, (15, 15, 15))
        else:
            text(cx, cy, inp.label, fw, (140, 140, 140))

    pips = {1: [(0, 0)], 2: [(-1, -1), (1, 1)], 3: [(-1, -1), (0, 0), (1, 1)],
            4: [(-1, -1), (1, -1), (-1, 1), (1, 1)], 5: [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
            6: [(-1, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (1, 1)]}
    for die in g.MOCK.dice().values():
        p = die._pos
        cx, cy = (p["x"] + w_world / 2) * PX, (d_world / 2 - p["z"]) * PX
        half = die.getBoundsNormalized()["size"]["x"] * PX / 2
        tint = die._tint
        col = tuple(int(tint[k] * 255) for k in ("x", "y", "z"))
        draw.rounded_rectangle((cx - half, cy - half, cx + half, cy + half), radius=int(half * 0.3),
                               fill=col, outline=(10, 10, 10), width=2)
        r, off = half * 0.14, half * 0.5
        for dx, dy in pips[int(die._value)]:
            x, y = cx + dx * off, cy + dy * off
            draw.ellipse((x - r, y - r, x + r, y + r), fill=(15, 15, 15))

    out = ROOT / "docs" / "preview.png"
    img.save(out)
    print("wrote", out.relative_to(ROOT), img.size)

    chat = [m["msg"] for m in g.MOCK.chat.values()]
    (ROOT / "docs" / "preview_chat.txt").write_text("\n".join(chat) + "\n")
    print("\n".join(chat))


if __name__ == "__main__":
    main()
