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
2. after the roll, **lays every color out in its own row, paired in 2s inside that color,**
   in order, so a pair can never get mixed up with another color, and
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

## 3. Design (v2: Hutber-style)

### What we learned from the Hutber 40K dice table
The reference UX is the dice table in Hutber's 40K competitive map base
(Lua source: `github.com/hutber/hutber-tts`, `TTSLUA/customDiceTable.ttslua` and
`kustom40kDiceRollerMk3.ttslua`):

* **Flow:** pick a die color, then click `+1d6 … +25d6` to spawn dice onto the mat,
  then click `Roll all dice`. A roller box re-rolls them **instantly** (`math.random`,
  with no physics wait) and lays them out in rows by value. Each row has its own Del/Roll buttons.
  Clearing the mat needs a right-click.
* **Its "In 2s" button** (`groupSizeOnNextRoll = 2`) pairs dice **in the order
  they went into the roller box**, not by color. That's why the BattleTech
  group's pairs "spawned disjointed from their respective colors".

v1 of this mat (12 numbered slots, each with weapon/TN/cluster boxes) solved the color
problem but was much heavier than the Hutber table. v2 keeps the Hutber feel and fixes
the pairing.

### The v2 mat
* **Controls (top):** a DICE COLOR picker (10 colors) and `+1D6 +2D6 +4D6 +6D6 +10D6`.
  Below them: one big **ROLL IN 2s BY COLOR** button, then ROLL SORTED, READ AS, a number box
  (TN or cluster SIZE), DELETE MISSES, and CLEAR (right-click).
* **Result area:** one row per color, in palette order. Dice are paired in 2s
  **within** their color, so colors are never mixed. A color label sits at the start of
  each row, and a result box under each pair. Clicking a result box re-rolls that pair.
  Up to 7 rows × 9 pairs.
* **Rolling:** every d6 lying on the mat (not held by a player) is collected,
  including dice brought from other mods, which are grouped by tint. The values are rolled by the script and
  each die is placed and turned to show its value, square to the mat. Positions stay
  the same from roll to roll. Dice are rolled in reading order (color by color, pair
  by pair).
* **READ AS** (doesn't re-roll, just relabels): SUM, TO-HIT vs TN, LOC FRONT/LEFT/RIGHT/REAR
  (with the TAC and HEAD flags), CLUSTER with a size, CRIT CHECK.
* **Attack flow:** TO-HIT, then DELETE MISSES, then READ AS LOC, then ROLL again.
  Hits keep their weapon colors all the way through.

### Multiplayer and persistence
* Object scripts run on the host, so every click goes through one authority.
* Saved: dice color, READ AS, TN, size, mirror. On load, the labels re-attach to the dice
  still on the mat.

### Robustness choices
* Layout scale is measured from `getBoundsNormalized()` and button sizes are
  corrected for non-uniform scale. Dice are resized to a fixed physical size.
* **MIRROR** flips the layout if TTS's local X axis convention makes it read backwards.

## 4. Deliverables
| Path | What |
|---|---|
| `src/battletech_dice_mat.lua` | The object script (source of truth) |
| `tools/build_saved_object.py` | Builds the importable Saved Object JSON from the Lua |
| `dist/BattleTech Dice Mat.json` | Ready-to-import TTS Saved Object |
| `tests/` | Mock TTS API plus Lua 5.2 tests (tables, layout, color pairing, BT flow, save/load) |
| `README.md` | Install and usage guide |

## 5. Possible next steps
* Vehicle, ProtoMech and quad 'Mech hit location tables.
* A to-hit TN calculator (gunnery, range, movement, TMM) for each slot.
* Automatic location rolls for each cluster (5-damage groups for LRMs, one per missile for SRMs).
* Punch/kick (1D6) location tables. v1 had them, but they don't fit the pairs layout.
