# TTS-Dice-Roller — BattleTech Dice Mat

A portable dice roller for **BattleTech games on Tabletop Simulator**. It rolls
**2D6 in color-locked pairs**, then gathers every pair back into **its own
numbered, colored slot, in order**. Pairs can't scatter or get mixed up. The mat
also checks each roll against the BattleTech tables for you.

![Mat preview after a 6-weapon to-hit volley](docs/preview.png)

*Preview of a to-hit roll for 6 weapons (rendered by running the real
script against a mock of the TTS API).*

## Install (Saved Object)

1. Download [`dist/BattleTech Dice Mat.json`](dist/BattleTech%20Dice%20Mat.json)
   (and the optional `.png` thumbnail next to it).
2. Copy both files into
   `Documents/My Games/Tabletop Simulator/Saves/Saved Objects/`.
3. In TTS: **Objects → Saved Objects → BattleTech Dice Mat**. It drops into any
   table, including the BattleTech mods with all the maps.

The mat is a locked, scaled block with everything drawn by its script, so it
doesn't need any external images. To move it, unlock it first (right-click →
Toggle Lock). To change its size, use the scale tool; the layout adjusts the
next time the mat loads (or after you press MIRROR twice).

**Without the saved object:** paste [`src/battletech_dice_mat.lua`](src/battletech_dice_mat.lua)
into the script of any flat object (right-click → Scripting → Lua Editor) and
click *Save & Play*.

## How to use it

| Control | What it does |
|---|---|
| **PAIRS − / +** or click a **slot number** | How many 2D6 pairs to roll (1–12). Each slot has a fixed color: Red, Blue, Green, Yellow, Orange, Purple, Cyan, Pink, White, Brown, Lime, Grey. |
| **Weapon / TN / CLUS** boxes | Per slot: a name, the target number, and a cluster size (e.g. `15` for an LRM-15). All optional. |
| **TO-HIT** | Rolls every pair. Each pair is thrown above its slot, settles, then snaps back into the slot face-up. Shows **HIT/MISS** against the TN (TN 13+ = impossible). |
| **LOCATION** | 'Mech hit location for the **ATTACK FROM** side (Front / Left / Right / Rear). With **HITS ONLY** on, only the pairs that hit are rolled, in the same colors. A 2 flags a **TAC check**. A 12 is a **head hit**. |
| **TABLE** | `MECH 2D6`, `PUNCH 1D6` or `KICK 1D6` (punch and kick roll one die per slot). |
| **CLUSTER** | Cluster Hits Table for pairs that hit and have a CLUS size. **CL MOD**: Artemis IV +2, AMS −4 (capped at 2–12). |
| **CRIT CHECK** | Determining Critical Hits: 8–9 = 1, 10–11 = 2, 12 = 3 (or head/limb blown off). |
| **CRIT SLOT** | Die A 1–3 = upper half, 4–6 = lower half. Die B = the slot (or the slot number on its own for a 6-slot location). |
| **2D6 / PSR** | A plain 2D6 per pair: piloting skill rolls, initiative, shutdown, ammo explosion, consciousness. PASS/FAIL if a TN is set. |
| **R** (per slot) | Re-rolls just that pair with the same roll type. |
| **CLEAR** | Removes the mat's dice and resets the results. |
| **HELP** | Prints the instructions in your chat. |
| **MIRROR** | Flips the layout left/right (see Troubleshooting). |

Each roll also prints a color-coded summary to chat, in slot order:

```
== Player: TO-HIT - 6 pairs ==
#1 RED Medium Laser: 4 + 5 = 9 vs TN 7 -> HIT
#2 BLUE LRM 15: 6 + 4 = 10 vs TN 9 -> HIT
#3 GREEN SRM 6: 2 + 3 = 5 vs TN 8 -> MISS
...
Hits: 4 / 6 (Red, Blue, Yellow, Purple)
```

### A typical weapon attack

1. Set PAIRS to the number of weapons you're firing. Enter each weapon's TN, and a cluster size for missiles.
2. **TO-HIT**: every pair lands in its own slot, and you see HIT/MISS for each.
3. Set **ATTACK FROM**, then press **LOCATION**. Only the weapons that hit roll again,
   in the same colors, so the blue result is always the blue weapon.
4. **CLUSTER** for the missile slots that hit tells you how many missiles landed.
5. If a location shows **TAC CHECK** or internal structure takes damage, use **CRIT CHECK** and then **CRIT SLOT**.

## Multiplayer and saving

* The script runs on the host, so clicks from every seat go through one
  authority and nobody desyncs. The chat header shows who rolled.
* Settings, slot names, TNs, cluster sizes, the last results and the dice GUIDs are
  saved with the game. After a reload the mat finds its dice again.
* Only one roll can run at a time. Clicking during a roll gives a warning.
* Each mat tracks its own dice (tagged `BTDiceMat`), so every player can
  have their own mat.
* Other scripts can call `mat.call("api_roll", {mode="tohit", color="Red"})` and
  `mat.call("api_get_results")`.

## Troubleshooting

* **Slot 1 isn't on the left / the columns look swapped:** press **MIRROR**. The
  setting is saved. **Text is upside down:** rotate the mat 180°.
* **Buttons look too big or too small:** change `BUTTON_UNITS` at the top of the
  script. It's the number of button units per world unit.
* **A die fell off the table:** the slot shows `DIE LOST`. Press **R** to
  re-roll it; a new die spawns.

## Development

```bash
pip install lupa pillow
python3 tests/run_tests.py            # runs the script under Lua 5.2 against a mock TTS API
python3 tools/render_preview.py       # regenerates docs/preview.png
python3 tools/build_saved_object.py   # regenerates dist/BattleTech Dice Mat.json (+ thumbnail)
```

* `src/battletech_dice_mat.lua` is the source of truth. Run the build script after editing it;
  the tests fail if the `dist/` JSON is out of date.
* `tests/` covers the rules tables (cluster, location, crit), whether the layout fits
  on the mat without overlaps, the full roll pipeline (ordering, colors, parking,
  HITS ONLY, 1D6 modes, re-rolls, lost dice, timeouts), save/load, mirroring, and
  rotated or rescaled mats.
* [`docs/PLAN.md`](docs/PLAN.md) has the research notes (how BattleTech uses its
  dice) and the design.
