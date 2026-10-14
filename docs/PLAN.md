# BattleTech Dice Mat — Plan & Research Notes

## 1. The problem (from the Discord thread)

> "The most important thing is the ordered roll in 2s, but by color. Since as you
> saw last night they spawned in disjointed from their respective colors."

In a BattleTech game on Tabletop Simulator (TTS) you often roll several 2D6 at
once, for example one to-hit roll per weapon in a volley. With loose dice, the
pairs scatter across the table and nobody can tell which two dice belong
together or which weapon a pair was for. The group asked for something like the
40K dice mats, built specifically for BattleTech.

**Goal:** a single portable, importable TTS object (a "dice mat") that:

1. rolls physical dice **in pairs (2D6)**, with **each pair in its own color**,
2. after the roll, **gathers each pair back into its own numbered, color-coded
   slot**, in order, so a pair can never get mixed up with another, and
3. resolves the result against BattleTech's tables (to-hit, hit location,
   cluster hits, critical hits, and so on) so nobody has to look them up.

## 2. How BattleTech uses dice (research summary)

Classic BattleTech (*Total Warfare*, *A Game of Armored Combat*) uses
**only six-sided dice**. Almost every check is **2D6 added together**. A few
tables use **1D6**.

| Roll | Dice | How it works |
|---|---|---|
| Initiative | 2D6 per side | Highest total wins; reroll ties. |
| **To-hit (weapon attack)** | 2D6 | Hit if the total is **≥ the modified target number (TN)**. TN = Gunnery skill + range modifier (+0 short / +2 medium / +4 long) + attacker movement (+0 stood still / +1 walked / +2 ran / +3 jumped) + target movement modifier (TMM) + terrain, heat and other modifiers. If the TN is 13 or more, the attack can't hit. |
| **Hit location** | 2D6 | Look up the total on the 'Mech Hit Location Table, in the column for the attack direction (Front/Rear, Left side, Right side). A 2 means a possible critical hit (through-armor crit); a 12 is the head. |
| **Cluster hits** | 2D6 | For missiles and LB-X/Ultra/Rotary autocannons. The total, read in the column for the weapon's size (LRM-15 uses column 15), says how many missiles or shots hit. Artemis IV gives +2 to the roll and AMS gives −4. |
| **Determining critical hits** | 2D6 | 2–7: no crit. 8–9: 1 crit. 10–11: 2 crits. 12: head or limb blown off, or 3 crits if it's a torso. |
| Critical slot | 1D6 + 1D6 | In a 12-slot location, the first die picks the upper half (1–3) or lower half (4–6); the second die picks the slot. |
| Punch location | 1D6 | Punch Location Table (by attack direction). |
| Kick location | 1D6 | Kick Location Table (legs). |
| Piloting skill roll (PSR) | 2D6 | Pass if the total is ≥ Piloting skill + modifiers (falls, damage, skids…). |
| Heat: shutdown / ammo explosion avoidance | 2D6 | Pass on ≥ the number shown on the heat scale. |
| Pilot consciousness | 2D6 | Needs 3 / 5 / 7 / 10 / 11 after the 1st–5th pilot hit. |

### 'Mech Hit Location Table (2D6)

| 2D6 | Left Side | Front / Rear | Right Side |
|---|---|---|---|
| 2*  | Left Torso  | Center Torso | Right Torso |
| 3   | Left Leg    | Right Arm    | Right Leg   |
| 4   | Left Arm    | Right Arm    | Right Arm   |
| 5   | Left Arm    | Right Leg    | Right Arm   |
| 6   | Left Leg    | Right Torso  | Right Leg   |
| 7   | Left Torso  | Center Torso | Right Torso |
| 8   | Center Torso| Left Torso   | Center Torso|
| 9   | Right Torso | Left Leg     | Left Torso  |
| 10  | Right Arm   | Left Arm     | Left Arm    |
| 11  | Right Leg   | Left Arm     | Left Leg    |
| 12  | Head        | Head         | Head        |

\* A 2 means a possible critical hit: roll on the Determining Critical Hits table.

### Punch / Kick Location Tables (1D6)

| 1D6 | Punch Left | Punch Front/Rear | Punch Right |
|---|---|---|---|
| 1 | Left Torso | Left Arm | Right Torso |
| 2 | Left Torso | Left Torso | Right Torso |
| 3 | Center Torso | Center Torso | Center Torso |
| 4 | Left Arm | Right Torso | Right Arm |
| 5 | Left Arm | Right Arm | Right Arm |
| 6 | Head | Head | Head |

Kick: from the left side it always hits the Left Leg, and from the right side
the Right Leg. From the front or rear, 1–3 hits the Right Leg and 4–6 the Left Leg.

### Cluster Hits Table (2D6 × weapon size, 2–20)

The table is built into the script (`CLUSTER_ROWS`). Spot checks against
published values: a 7 on LRM-20 is 12 hits, a 9 on LRM-20 is 16, and a 7 gives
1/3/3/4/6/9/12 in the 2/4/5/6/10/15/20 columns. Weapon sizes above 20 (MRM-30/40)
are split into chunks of 20 or less and marked "approx".

### What this means for the dice

* The basic unit is the **pair of d6** (2D6). Every pair needs its own color
  that stays the same through to-hit, then hit location, then cluster rolls, so
  a hit can always be traced back to the weapon (pair) that made it.
* Some tables use **1D6**. The mat can roll single dice per slot for
  punch and kick locations.
* Results need to stay **in order** (slot 1, 2, 3 …), with each pair kept together.

## 3. Design

### The object
* One self-contained **object script** on a flat mat (a scaled `BlockSquare`,
  so it doesn't depend on any external images). Saved as a TTS **Saved Object**
  JSON, so players can drop it into any BattleTech table (including the big BT
  mod with 50+ maps) through *Objects → Saved Objects*.
* Everything is drawn with scripted buttons and inputs. The layout is computed
  from the mat's measured size, so it still works if someone rescales the mat.

### Slots (up to 12 color-locked pairs)
Each slot is one row: a color swatch with its number, a **Weapon** name box, a **TN** box,
a **Cluster size** box, a color pad where the pair of dice lands, a result read-out, and
a per-slot re-roll button.
Colors, in order: Red, Blue, Green, Yellow, Orange, Purple, Cyan, Pink, White,
Brown, Lime, Grey.

### Roll modes (top button row)
| Button | Dice per slot | Which slots | Result |
|---|---|---|---|
| TO-HIT | 2 | all active | total vs TN gives HIT or MISS (TN 13+ = impossible) |
| LOCATION | 2 ('Mech) or 1 (Punch/Kick) | slots that hit (if HITS ONLY is on) | location for the chosen FACING, with a TAC flag on a 2 |
| CLUSTER | 2 | slots that hit and have a cluster size of 2 or more | hits from the table, with ±CL MOD (Artemis/AMS) |
| CRIT CHECK | 2 | all active | 0 / 1 / 2 / 3 crits (12 = head/limb blown off) |
| CRIT SLOT | 2 | all active | slot 1–12 (die A picks the half, die B the slot) |
| 2D6 / PSR | 2 | all active | total (vs TN if one is set) gives PASS or FAIL |
| CLEAR | – | – | removes the mat's dice and clears results |

### Roll pipeline (the actual fix for "disjointed colors")
1. Make sure each slot has its dice: spawn `Die_6`s (tinted with the slot color,
   tagged, named "BT Pair 3 (Yellow) A"), or reuse the existing ones by GUID.
2. Drop each pair from just above **its own slot** with a random spin, then `roll()`.
3. Wait until every die is at rest (`resting`), with a timeout as a fallback.
4. Read each die's `getValue()`. Then **lock each die and smooth-move it into its
   slot**, turned so the face that was read sits square and face up.
   Every pair ends up side by side, in order, on its color pad.
5. Resolve the result on the matching table, update the slot labels, and print a
   color-coded summary to chat (`[hex]#3 YELLOW[-] Medium Laser: 4 + 5 = 9 vs TN 8 -> HIT`).

### Multiplayer and persistence
* All logic runs on the host (TTS object scripts do). Clicks from any seat are
  sent to the host, so there's no desync.
* `onSave`/`onLoad` keep the pair count, settings, per-slot names, TNs and cluster sizes,
  the last results, and the dice GUIDs, so a reload keeps the mat in sync.
* A busy flag blocks overlapping rolls. Deleting the mat removes its dice.

### Robustness choices
* Layout scale is measured from `getBoundsNormalized()` and the button sizes are
  corrected for non-uniform object scale.
* Dice are resized to a fixed physical size after they spawn (measured, not guessed).
* **MIRROR** button: TTS's local X axis convention is a common source of
  left/right flips. If the slots appear in the wrong order, one click flips the
  layout. The setting is saved.

## 4. Deliverables
| Path | What |
|---|---|
| `src/battletech_dice_mat.lua` | The object script (source of truth) |
| `tools/build_saved_object.py` | Builds the importable Saved Object JSON from the Lua |
| `dist/BattleTech Dice Mat.json` | Ready-to-import TTS Saved Object |
| `tests/` | Mock TTS API plus Lua 5.2 tests (tables, layout, full roll pipeline, save/load) |
| `README.md` | Install and usage guide |

## 5. Possible next steps
* Vehicle, ProtoMech and quad 'Mech hit location tables.
* A to-hit TN calculator (gunnery, range, movement, TMM) for each slot.
* Automatic location rolls for each cluster (5-damage groups for LRMs, one per missile for SRMs).
