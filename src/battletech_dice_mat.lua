--[[
================================================================================
  BATTLETECH DICE MAT  -  portable, color-locked 2D6 roller for Tabletop Simulator
================================================================================
  Object script. Put it on any flat object (the shipped Saved Object uses a
  scaled BlockSquare) and the whole mat UI builds itself.

  What it solves: in BattleTech you roll many 2D6 at once (one per weapon).
  Loose dice scatter and pairs lose their colors. This mat:
    * gives every pair (slot) its own fixed color,
    * physically rolls each pair from above its own slot,
    * waits for the dice to settle, reads them, then snaps every pair back
      into its numbered slot, in order, face up,
    * resolves the result on the BattleTech tables (to-hit, hit location,
      cluster hits, crit check, crit slot, PSR / generic 2D6),
    * prints a color-coded summary to chat.

  Multiplayer: object scripts run on the host only, so every click from any
  seat is processed by one authority. State (settings, slot names/TNs, last
  results, dice GUIDs) is saved with onSave/onLoad.
================================================================================
]]

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local VERSION = "1.0.0"
local MAX_SLOTS = 12
local SLOTS_PER_COLUMN = 6

-- The layout is designed on a DESIGN_W x DESIGN_D grid and scaled to the
-- object's measured size, so the mat can be resized freely.
local DESIGN_W, DESIGN_D = 30, 19

-- Scripted button/input size units per world unit (at button scale 1 on an
-- object of scale 1). Tune this if text looks too big/small on your build.
local BUTTON_UNITS = 500

local DIE_SIZE = 1.0          -- die edge length, in design units
local DIE_SPACING = 1.4       -- distance between the two dice of a pair
local DROP_HEIGHT = 2.5       -- design units above the mat dice are thrown from
local SETTLE_DELAY = 0.75     -- seconds before we start checking for rest
local ROLL_TIMEOUT = 10       -- seconds before we read dice even if still moving
local SPAWN_TIMEOUT = 5       -- seconds to wait for dice to finish spawning
local DICE_TAG = "BTDiceMat"

local SLOT_COLORS = {
    { name = "Red",    rgb = { 0.90, 0.16, 0.16 } },
    { name = "Blue",   rgb = { 0.25, 0.50, 1.00 } },
    { name = "Green",  rgb = { 0.15, 0.72, 0.28 } },
    { name = "Yellow", rgb = { 1.00, 0.88, 0.10 } },
    { name = "Orange", rgb = { 1.00, 0.52, 0.05 } },
    { name = "Purple", rgb = { 0.66, 0.40, 0.95 } },
    { name = "Cyan",   rgb = { 0.15, 0.85, 0.90 } },
    { name = "Pink",   rgb = { 1.00, 0.50, 0.78 } },
    { name = "White",  rgb = { 0.96, 0.96, 0.96 } },
    { name = "Brown",  rgb = { 0.72, 0.47, 0.25 } },
    { name = "Lime",   rgb = { 0.70, 1.00, 0.30 } },
    { name = "Grey",   rgb = { 0.60, 0.60, 0.60 } },
}

local MAT_TEXT      = { 0.92, 0.92, 0.88 }
local MAT_TEXT_DIM  = { 0.60, 0.62, 0.60 }
local PANEL_COLOR   = { 0.16, 0.17, 0.18 }
local RESULT_GOOD   = { 0.12, 0.42, 0.18 }
local RESULT_BAD    = { 0.50, 0.12, 0.12 }
local RESULT_INFO   = { 0.20, 0.24, 0.32 }
local RESULT_NONE   = { 0.13, 0.14, 0.15 }

-- Attack direction (which side of the target the attack comes from).
local FACINGS = { "FRONT", "LEFT", "RIGHT", "REAR" }
-- Location table in use for the LOCATION button.
local LOC_TABLES = { "MECH", "PUNCH", "KICK" }

local LOC_NAMES = {
    HD = "Head", CT = "Center Torso", LT = "Left Torso", RT = "Right Torso",
    LA = "Left Arm", RA = "Right Arm", LL = "Left Leg", RL = "Right Leg",
}

-- 'Mech Hit Location Table (2D6). Index = 2D6 total. A 2 is a possible
-- through-armor critical (TAC).
local MECH_LOCATION = {
    FRONT = { [2]="CT", [3]="RA", [4]="RA", [5]="RL", [6]="RT", [7]="CT",
              [8]="LT", [9]="LL", [10]="LA", [11]="LA", [12]="HD" },
    LEFT  = { [2]="LT", [3]="LL", [4]="LA", [5]="LA", [6]="LL", [7]="LT",
              [8]="CT", [9]="RT", [10]="RA", [11]="RL", [12]="HD" },
    RIGHT = { [2]="RT", [3]="RL", [4]="RA", [5]="RA", [6]="RL", [7]="RT",
              [8]="CT", [9]="LT", [10]="LA", [11]="LL", [12]="HD" },
}
MECH_LOCATION.REAR = MECH_LOCATION.FRONT

-- Punch Location Table (1D6).
local PUNCH_LOCATION = {
    FRONT = { "LA", "LT", "CT", "RT", "RA", "HD" },
    LEFT  = { "LT", "LT", "CT", "LA", "LA", "HD" },
    RIGHT = { "RT", "RT", "CT", "RA", "RA", "HD" },
}
PUNCH_LOCATION.REAR = PUNCH_LOCATION.FRONT

-- Kick Location Table (1D6).
local KICK_LOCATION = {
    FRONT = { "RL", "RL", "RL", "LL", "LL", "LL" },
    LEFT  = { "LL", "LL", "LL", "LL", "LL", "LL" },
    RIGHT = { "RL", "RL", "RL", "RL", "RL", "RL" },
}
KICK_LOCATION.REAR = KICK_LOCATION.FRONT

-- Cluster Hits Table. Row = modified 2D6 roll, column = weapon size 2..20.
local CLUSTER_ROWS = {
    [2]  = { 1, 1, 1, 1, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6 },
    [3]  = { 1, 1, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6 },
    [4]  = { 1, 1, 2, 2, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 8, 8, 9 },
    [5]  = { 1, 2, 2, 3, 3, 4, 4, 5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12 },
    [6]  = { 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12 },
    [7]  = { 1, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12 },
    [8]  = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12 },
    [9]  = { 2, 2, 3, 4, 5, 6, 6, 7, 8, 9, 10, 11, 11, 12, 13, 14, 14, 15, 16 },
    [10] = { 2, 3, 3, 4, 5, 6, 6, 7, 8, 9, 10, 11, 11, 12, 13, 14, 14, 15, 16 },
    [11] = { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
    [12] = { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
}
local CLUSTER_MIN, CLUSTER_MAX = 2, 20
local CLUSTER_MOD_MIN, CLUSTER_MOD_MAX = -4, 4

local MODES = {
    tohit    = { label = "TO-HIT" },
    location = { label = "LOCATION" },
    cluster  = { label = "CLUSTER" },
    crit     = { label = "CRIT CHECK" },
    critslot = { label = "CRIT SLOT" },
    generic  = { label = "2D6 / PSR" },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local state            -- persisted (see _default_state)
local busy = false     -- a roll is in progress (runtime only)
local M = {}           -- layout metrics (runtime only)
local ui = { btn = {}, input = {} }
local button_count, input_count = 0, 0

local function _new_slot()
    return {
        name = "", tn = "", cluster = "",
        dice = { "", "" },  -- die GUIDs ("" = none)
        mode = "",          -- mode of the last result
        hit = "",           -- "hit" / "miss" / "" (last to-hit outcome)
        result = "",        -- label text shown on the mat
        tone = "none",      -- good / bad / info / none
    }
end

local function _default_state()
    local s = {
        version = 1,
        pairs = 4,
        facing = 1,
        loc_table = 1,
        cluster_mod = 0,
        hits_only = true,
        mirror = false,
        hit_known = false,
        slots = {},
    }
    for i = 1, MAX_SLOTS do s.slots[i] = _new_slot() end
    return s
end

--------------------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------------------
local function _clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function _int_str(n)
    return tostring(math.floor(n + 0.5))
end

local function _signed(n)
    if n > 0 then return "+" .. _int_str(n) end
    return _int_str(n)
end

local function _trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _hex(rgb)
    return string.format("%02x%02x%02x",
        math.floor(rgb[1] * 255 + 0.5),
        math.floor(rgb[2] * 255 + 0.5),
        math.floor(rgb[3] * 255 + 0.5))
end

local function _scaled(rgb, f, a)
    return { rgb[1] * f, rgb[2] * f, rgb[3] * f, a or 1 }
end

local function _text_on(rgb)
    local lum = 0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]
    if lum > 0.55 then return { 0.05, 0.05, 0.05 } end
    return { 1, 1, 1 }
end

local function _player_name(color)
    local ok, name = pcall(function()
        local p = Player[color]
        return p and p.steam_name
    end)
    if ok and name and name ~= "" then return name end
    return tostring(color or "Someone")
end

local function _slot_tag(i)
    local c = SLOT_COLORS[i]
    return "[" .. _hex(c.rgb) .. "]#" .. i .. " " .. string.upper(c.name) .. "[-]"
end

--------------------------------------------------------------------------------
-- Rules (pure functions, also used by the test-suite)
--------------------------------------------------------------------------------
function cluster_hits(size, roll)
    size = math.floor(tonumber(size) or 0)
    roll = _clamp(math.floor(tonumber(roll) or 2), 2, 12)
    if size <= 0 then return 0, false end
    if size == 1 then return 1, false end
    if size <= CLUSTER_MAX then
        return CLUSTER_ROWS[roll][size - 1], false
    end
    -- Larger launchers (MRM-30/40...): split into chunks of <= 20 and sum.
    local total, left = 0, size
    while left > 0 do
        local chunk = math.min(left, CLUSTER_MAX)
        if chunk == 1 then
            total = total + 1
        else
            total = total + CLUSTER_ROWS[roll][chunk - 1]
        end
        left = left - chunk
    end
    return total, true
end

function mech_location(facing, total)
    local col = MECH_LOCATION[facing] or MECH_LOCATION.FRONT
    return col[total]
end

function crit_check(total)
    if total <= 7 then return 0, "No critical hit" end
    if total <= 9 then return 1, "1 critical hit" end
    if total <= 11 then return 2, "2 critical hits" end
    return 3, "Head/limb blown off; torso: 3 crits"
end

function crit_slot(die_a, die_b)
    if die_a <= 3 then return die_b end
    return die_b + 6
end

-- Every resolver returns { label = "<2 lines for the mat>", chat = "<detail>",
-- tone = good/bad/info/none, hit = "hit"/"miss"/nil }.
local function _resolve_tohit(slot, v)
    local total = v[1] + v[2]
    local dice = v[1] .. " + " .. v[2] .. " = " .. total
    local tn = tonumber(slot.tn)
    if not tn then
        return { label = total .. "\nno TN set", chat = dice .. " (no TN set)", tone = "info", hit = "" }
    end
    if tn >= 13 then
        return { label = total .. " vs " .. _int_str(tn) .. "\nIMPOSSIBLE",
                 chat = dice .. " vs TN " .. _int_str(tn) .. " -> IMPOSSIBLE (TN 13+)", tone = "bad", hit = "miss" }
    end
    if total >= tn then
        return { label = total .. " vs " .. _int_str(tn) .. "\nHIT",
                 chat = dice .. " vs TN " .. _int_str(tn) .. " -> HIT", tone = "good", hit = "hit" }
    end
    return { label = total .. " vs " .. _int_str(tn) .. "\nMISS",
             chat = dice .. " vs TN " .. _int_str(tn) .. " -> MISS", tone = "bad", hit = "miss" }
end

local function _resolve_location(slot, v)
    local facing = FACINGS[state.facing]
    local tbl = LOC_TABLES[state.loc_table]
    if tbl == "MECH" then
        local total = v[1] + v[2]
        local code = mech_location(facing, total)
        local name = LOC_NAMES[code]
        local rear = (facing == "REAR" and (code == "CT" or code == "LT" or code == "RT"))
        local short = string.upper(name) .. (rear and " (R)" or "")
        local extra = ""
        if total == 2 then extra = " + TAC CHECK" end
        return {
            label = total .. ": " .. code .. (rear and "(R)" or "") .. "\n" .. (total == 2 and "TAC CHECK!" or (code == "HD" and "HEAD HIT!" or name)),
            chat = v[1] .. " + " .. v[2] .. " = " .. total .. " -> " .. short .. extra .. "  [" .. facing .. "]",
            tone = (total == 2 or code == "HD") and "bad" or "info",
        }
    end
    local list = (tbl == "PUNCH") and PUNCH_LOCATION or KICK_LOCATION
    local col = list[facing] or list.FRONT
    local code = col[v[1]]
    local name = LOC_NAMES[code]
    local rear = (facing == "REAR" and (code == "CT" or code == "LT" or code == "RT"))
    return {
        label = tbl .. " " .. v[1] .. "\n" .. string.upper(name) .. (rear and " (R)" or ""),
        chat = tbl .. " 1D6 " .. v[1] .. " -> " .. string.upper(name) .. (rear and " (REAR)" or "") .. "  [" .. facing .. "]",
        tone = (code == "HD") and "bad" or "info",
    }
end

local function _resolve_cluster(slot, v)
    local total = v[1] + v[2]
    local size = math.floor(tonumber(slot.cluster) or 0)
    local mod = state.cluster_mod
    local roll = _clamp(total + mod, 2, 12)
    local hits, approx = cluster_hits(size, roll)
    local roll_txt = (mod ~= 0) and (total .. _signed(mod) .. "=" .. roll) or tostring(total)
    return {
        label = roll_txt .. "\n" .. hits .. " / " .. size .. " HIT" .. (approx and "~" or ""),
        chat = v[1] .. " + " .. v[2] .. " = " .. total .. ((mod ~= 0) and (" (" .. _signed(mod) .. " -> " .. roll .. ")") or "")
            .. " on cluster " .. size .. " -> " .. hits .. " of " .. size .. " hit" .. (approx and " (approx: >20 split)" or ""),
        tone = "info",
    }
end

local function _resolve_crit(slot, v)
    local total = v[1] + v[2]
    local n, txt = crit_check(total)
    local short = (n == 0) and "NO CRIT" or ((n == 3) and "3 / BLOWN OFF" or (n .. " CRIT" .. (n > 1 and "S" or "")))
    return {
        label = total .. "\n" .. short,
        chat = v[1] .. " + " .. v[2] .. " = " .. total .. " -> " .. txt,
        tone = (n == 0) and "info" or "bad",
    }
end

local function _resolve_critslot(slot, v)
    local s = crit_slot(v[1], v[2])
    local half = (v[1] <= 3) and "upper" or "lower"
    return {
        label = "SLOT " .. s .. "\n(6-slot loc: " .. v[2] .. ")",
        chat = "A " .. v[1] .. " (" .. half .. "), B " .. v[2] .. " -> slot " .. s .. " of 12  (6-slot location: slot " .. v[2] .. ")",
        tone = "info",
    }
end

local function _resolve_generic(slot, v)
    local total = v[1] + v[2]
    local dice = v[1] .. " + " .. v[2] .. " = " .. total
    local tn = tonumber(slot.tn)
    if not tn then
        return { label = tostring(total) .. "\n2D6", chat = dice, tone = "info" }
    end
    if total >= tn then
        return { label = total .. " vs " .. _int_str(tn) .. "\nPASS", chat = dice .. " vs " .. _int_str(tn) .. " -> PASS", tone = "good" }
    end
    return { label = total .. " vs " .. _int_str(tn) .. "\nFAIL", chat = dice .. " vs " .. _int_str(tn) .. " -> FAIL", tone = "bad" }
end

local RESOLVERS = {
    tohit = _resolve_tohit,
    location = _resolve_location,
    cluster = _resolve_cluster,
    crit = _resolve_crit,
    critslot = _resolve_critslot,
    generic = _resolve_generic,
}

local function _dice_for_mode(mode)
    if mode == "location" and LOC_TABLES[state.loc_table] ~= "MECH" then return 1 end
    return 2
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------
-- Design ("viewer") coordinates: vx to the right, vz away from the player,
-- origin at the mat centre. Converted to object-local coordinates here.
local function _measure()
    local s = self.getScale()
    M.sx, M.sy, M.sz = s.x, s.y, s.z
    local ok, b = pcall(function() return self.getBoundsNormalized() end)
    local k
    if ok and b and b.size and b.size.x > 0 and b.size.z > 0 then
        k = math.min(b.size.x / DESIGN_W, b.size.z / DESIGN_D)
        local pos = self.getPosition()
        M.top = ((b.center.y - pos.y) + b.size.y / 2) / M.sy
    else
        k = math.min(M.sx / DESIGN_W, M.sz / DESIGN_D)
        M.top = 0.5
    end
    M.k = k
end

local function _local(vx, vz, lift)
    local mx = state.mirror and -1 or 1
    return { mx * vx * M.k / M.sx, M.top + (lift or 0.02) / M.sy, -vz * M.k / M.sz }
end

local function _world(vx, vz, lift)
    return self.positionToWorld(_local(vx, vz, lift))
end

local function _ui_scale()
    return { M.k / M.sx, M.k / M.sy, M.k / M.sz }
end

local function _slot_origin(i)
    local col = (i <= SLOTS_PER_COLUMN) and 0 or 1
    local row = (i - 1) % SLOTS_PER_COLUMN
    local left = (col == 0) and -14.6 or 0.4
    local vz = 2.2 - row * 2.05
    return left, vz
end

local function _die_vx(i, d, ndice)
    local left = _slot_origin(i)
    local cx = left + 7.6
    if ndice == 1 then return cx end
    return cx + ((d == 1) and -DIE_SPACING / 2 or DIE_SPACING / 2)
end

--------------------------------------------------------------------------------
-- UI construction helpers
--------------------------------------------------------------------------------
local function _add_button(key, p)
    self.createButton({
        click_function = p.fn or "noop",
        function_owner = self,
        label = p.label or "",
        position = _local(p.vx, p.vz, p.lift or 0.03),
        rotation = { 0, 0, 0 },
        scale = _ui_scale(),
        width = (p.w or 0) * BUTTON_UNITS,
        height = (p.h or 0) * BUTTON_UNITS,
        font_size = (p.font or 0.5) * BUTTON_UNITS,
        color = p.color or PANEL_COLOR,
        font_color = p.font_color or MAT_TEXT,
        hover_color = p.hover_color,
        tooltip = p.tooltip or "",
    })
    ui.btn[key] = button_count
    button_count = button_count + 1
end

local function _add_label(key, vx, vz, text, font, color)
    _add_button(key, { vx = vx, vz = vz, w = 0, h = 0, label = text, font = font, font_color = color or MAT_TEXT })
end

local function _add_input(key, p)
    self.createInput({
        input_function = p.fn,
        function_owner = self,
        label = p.placeholder or "",
        value = p.value or "",
        position = _local(p.vx, p.vz, 0.03),
        rotation = { 0, 0, 0 },
        scale = _ui_scale(),
        width = p.w * BUTTON_UNITS,
        height = p.h * BUTTON_UNITS,
        font_size = (p.font or 0.4) * BUTTON_UNITS,
        alignment = 3,
        validation = p.validation or 1,
        tab = 2,
        color = { 0.85, 0.85, 0.82 },
        font_color = { 0.05, 0.05, 0.05 },
        tooltip = p.tooltip or "",
    })
    ui.input[key] = input_count
    input_count = input_count + 1
end

local function _edit_button(key, params)
    local idx = ui.btn[key]
    if idx == nil then return end
    params.index = idx
    self.editButton(params)
end

local function _tone_color(tone)
    if tone == "good" then return RESULT_GOOD end
    if tone == "bad" then return RESULT_BAD end
    if tone == "info" then return RESULT_INFO end
    return RESULT_NONE
end

--------------------------------------------------------------------------------
-- UI refresh (cheap edits, no rebuild)
--------------------------------------------------------------------------------
local function _refresh_settings()
    _edit_button("pairs_value", { label = tostring(state.pairs) })
    _edit_button("facing", { label = FACINGS[state.facing] })
    _edit_button("loc_table", { label = LOC_TABLES[state.loc_table] .. ((state.loc_table == 1) and " 2D6" or " 1D6") })
    _edit_button("clmod_value", { label = _signed(state.cluster_mod) })
    _edit_button("hits_only", {
        label = state.hits_only and "ON" or "OFF",
        color = state.hits_only and RESULT_GOOD or RESULT_NONE,
    })
end

local function _refresh_slot(i)
    local s = state.slots[i]
    local c = SLOT_COLORS[i]
    local active = i <= state.pairs
    _edit_button("swatch_" .. i, {
        color = active and c.rgb or _scaled(c.rgb, 0.3),
        font_color = active and _text_on(c.rgb) or MAT_TEXT_DIM,
    })
    _edit_button("pad_" .. i, { color = active and _scaled(c.rgb, 0.55, 1) or _scaled(c.rgb, 0.18, 1) })
    _edit_button("result_" .. i, {
        label = active and s.result or "",
        color = active and _tone_color(s.tone) or RESULT_NONE,
    })
end

local function _refresh_all()
    _refresh_settings()
    for i = 1, MAX_SLOTS do _refresh_slot(i) end
end

local function _set_status(text)
    _edit_button("status", { label = text })
end

--------------------------------------------------------------------------------
-- UI build (once on load, and on MIRROR)
--------------------------------------------------------------------------------
local function _build_ui()
    self.clearButtons()
    self.clearInputs()
    ui = { btn = {}, input = {} }
    button_count, input_count = 0, 0
    _measure()

    -- Title
    _add_label("title", -6.5, 8.55, "BATTLETECH  DICE  MAT", 1.0)
    _add_label("subtitle", -6.5, 7.6, "ordered 2D6 pairs - every pair keeps its color", 0.42, MAT_TEXT_DIM)
    _add_button("help", { vx = 10.6, vz = 8.4, w = 2.2, h = 0.9, label = "HELP", font = 0.42,
        fn = "btn_help", tooltip = "Print instructions to your chat" })
    _add_button("mirror", { vx = 13.3, vz = 8.4, w = 2.6, h = 0.9, label = "MIRROR", font = 0.42,
        fn = "btn_mirror", tooltip = "Flip the layout left/right if slot 1 is not on the left" })

    -- Roll buttons
    local rolls = {
        { "tohit", "TO-HIT", { 0.62, 0.14, 0.14 }, "Roll to-hit for every active pair (vs TN)" },
        { "location", "LOCATION", { 0.18, 0.32, 0.62 }, "Roll hit location (for pairs that hit if HITS ONLY is on)" },
        { "cluster", "CLUSTER", { 0.45, 0.26, 0.62 }, "Roll cluster hits for pairs that hit and have a CLUSTER size" },
        { "crit", "CRIT CHECK", { 0.62, 0.38, 0.10 }, "Determining Critical Hits: 8-9 = 1, 10-11 = 2, 12 = 3 / blown off" },
        { "critslot", "CRIT SLOT", { 0.50, 0.42, 0.12 }, "Which critical slot: die A 1-3 upper / 4-6 lower, die B = slot" },
        { "generic", "2D6 / PSR", { 0.14, 0.45, 0.30 }, "Plain 2D6 per pair: PSR, initiative, shutdown, ammo, consciousness (vs TN if set)" },
        { "clear", "CLEAR", { 0.30, 0.30, 0.30 }, "Remove this mat's dice and clear all results" },
    }
    for n, r in ipairs(rolls) do
        _add_button("roll_" .. r[1], { vx = -12.15 + (n - 1) * 4.05, vz = 6.25, w = 3.75, h = 1.25,
            label = r[2], font = 0.48, color = r[3], font_color = { 1, 1, 1 },
            fn = "btn_" .. r[1], tooltip = r[4] })
    end

    -- Settings row
    local z = 4.7
    _add_label("pairs_label", -13.4, z, "PAIRS", 0.4, MAT_TEXT_DIM)
    _add_button("pairs_dec", { vx = -11.8, vz = z, w = 0.9, h = 0.9, label = "-", font = 0.6, fn = "btn_pairs_dec", tooltip = "Fewer pairs" })
    _add_label("pairs_value", -10.8, z, tostring(state.pairs), 0.6)
    _add_button("pairs_inc", { vx = -9.8, vz = z, w = 0.9, h = 0.9, label = "+", font = 0.6, fn = "btn_pairs_inc", tooltip = "More pairs (or click a slot number)" })

    _add_label("facing_label", -7.9, z, "ATTACK FROM", 0.36, MAT_TEXT_DIM)
    _add_button("facing", { vx = -5.4, vz = z, w = 2.4, h = 0.9, label = "", font = 0.4, fn = "btn_facing",
        tooltip = "Side of the target the attack comes from (location table column). Right-click cycles back." })

    _add_label("loc_table_label", -3.2, z, "TABLE", 0.36, MAT_TEXT_DIM)
    _add_button("loc_table", { vx = -1.0, vz = z, w = 2.8, h = 0.9, label = "", font = 0.38, fn = "btn_loc_table",
        tooltip = "Location table: MECH (2D6), PUNCH (1D6) or KICK (1D6)" })

    _add_label("clmod_label", 1.6, z, "CL MOD", 0.36, MAT_TEXT_DIM)
    _add_button("clmod_dec", { vx = 3.1, vz = z, w = 0.8, h = 0.9, label = "-", font = 0.6, fn = "btn_clmod_dec", tooltip = "Cluster roll modifier down (AMS -4)" })
    _add_label("clmod_value", 4.05, z, "", 0.5)
    _add_button("clmod_inc", { vx = 5.0, vz = z, w = 0.8, h = 0.9, label = "+", font = 0.6, fn = "btn_clmod_inc", tooltip = "Cluster roll modifier up (Artemis IV +2)" })

    _add_label("hits_only_label", 7.1, z, "HITS ONLY", 0.36, MAT_TEXT_DIM)
    _add_button("hits_only", { vx = 9.0, vz = z, w = 1.5, h = 0.9, label = "", font = 0.4, fn = "btn_hits_only",
        tooltip = "LOCATION / CLUSTER only roll pairs that hit on the last TO-HIT" })

    _add_label("status", 12.6, z, "Ready", 0.38, MAT_TEXT_DIM)

    -- Column headers
    for col = 0, 1 do
        local left = (col == 0) and -14.6 or 0.4
        _add_label("hdr_a" .. col, left + 3.35, 3.45, "WEAPON  /  TN  /  CLUSTER", 0.3, MAT_TEXT_DIM)
        _add_label("hdr_b" .. col, left + 7.6, 3.45, "DICE", 0.3, MAT_TEXT_DIM)
        _add_label("hdr_c" .. col, left + 11.5, 3.45, "RESULT", 0.3, MAT_TEXT_DIM)
    end

    -- Slots
    for i = 1, MAX_SLOTS do
        local s = state.slots[i]
        local c = SLOT_COLORS[i]
        local left, vz = _slot_origin(i)
        _add_button("swatch_" .. i, { vx = left + 0.65, vz = vz, w = 1.1, h = 1.8, label = tostring(i), font = 0.6,
            color = c.rgb, font_color = _text_on(c.rgb), fn = "slot_select_" .. i,
            tooltip = c.name .. " pair - click to use " .. i .. " pair" .. (i > 1 and "s" or "") })
        _add_input("name_" .. i, { vx = left + 3.35, vz = vz + 0.45, w = 4.1, h = 0.75, font = 0.36,
            placeholder = c.name .. " weapon", value = s.name, fn = "slot_name_" .. i,
            tooltip = "Weapon / roll name for the " .. c.name .. " pair" })
        _add_input("tn_" .. i, { vx = left + 2.3, vz = vz - 0.45, w = 2.0, h = 0.75, font = 0.36,
            placeholder = "TN", value = s.tn, fn = "slot_tn_" .. i, validation = 2,
            tooltip = "Target number (to-hit / PSR). Blank = just show the total." })
        _add_input("cl_" .. i, { vx = left + 4.4, vz = vz - 0.45, w = 2.0, h = 0.75, font = 0.36,
            placeholder = "CLUS", value = s.cluster, fn = "slot_cluster_" .. i, validation = 2,
            tooltip = "Cluster size for missiles / LB-X (e.g. 15 for LRM-15). Blank = not a cluster weapon." })
        _add_button("pad_" .. i, { vx = left + 7.6, vz = vz, w = 3.0, h = 1.9, label = "", lift = 0.005,
            color = c.rgb, tooltip = c.name .. " pair lands here" })
        _add_button("result_" .. i, { vx = left + 11.5, vz = vz, w = 4.5, h = 1.8, label = "", font = 0.42,
            color = RESULT_NONE, font_color = { 1, 1, 1 }, tooltip = "Last result for the " .. c.name .. " pair" })
        _add_button("reroll_" .. i, { vx = left + 14.15, vz = vz, w = 0.62, h = 1.2, label = "R", font = 0.36,
            fn = "slot_reroll_" .. i, tooltip = "Re-roll only the " .. c.name .. " pair (same roll type)" })
    end

    _refresh_all()
end

--------------------------------------------------------------------------------
-- Dice management
--------------------------------------------------------------------------------
local function _get_die(i, d)
    local guid = state.slots[i].dice[d]
    if guid == nil or guid == "" then return nil end
    local obj = getObjectFromGUID(guid)
    if obj == nil then return nil end
    if obj.isDestroyed and obj.isDestroyed() then return nil end
    if obj.hasTag and not obj.hasTag(DICE_TAG) then return nil end
    return obj
end

local function _destroy_die(i, d)
    local die = _get_die(i, d)
    if die then die.destruct() end
    state.slots[i].dice[d] = ""
end

local function _destroy_slot_dice(i)
    _destroy_die(i, 1)
    _destroy_die(i, 2)
end

local function _random_rotation()
    return { math.random(0, 359), math.random(0, 359), math.random(0, 359) }
end

local function _setup_die(die, i, d)
    local c = SLOT_COLORS[i]
    die.setColorTint(c.rgb)
    die.setName("BT Pair " .. i .. " (" .. c.name .. ") " .. ((d == 1) and "A" or "B"))
    die.setDescription("Belongs to the BattleTech Dice Mat (" .. self.getGUID() .. "), slot " .. i .. ".")
    if die.addTag then die.addTag(DICE_TAG) end
end

local function _normalize_die_size(die)
    local ok, b = pcall(function() return die.getBoundsNormalized() end)
    if not ok or not b or not b.size then return end
    local size = math.max(b.size.x, b.size.y, b.size.z)
    if size <= 0 then return end
    local cur = die.getScale().x
    local f = cur * (DIE_SIZE * M.k) / size
    die.setScale({ f, f, f })
end

local function _ensure_dice(slot_ids, ndice, done)
    local pending = 0
    local loop_done = false
    local called = false
    local function finish()
        if called then return end
        called = true
        done()
    end
    local function one_ready()
        pending = pending - 1
        if pending <= 0 and loop_done then finish() end
    end

    for _, i in ipairs(slot_ids) do
        local _, vz = _slot_origin(i)
        for d = 1, 2 do
            local die = _get_die(i, d)
            if d > ndice then
                if die then _destroy_die(i, d) end
            elseif die then
                die.setColorTint(SLOT_COLORS[i].rgb)
            else
                pending = pending + 1
                local slot_i, die_d = i, d
                spawnObject({
                    type = "Die_6",
                    position = _world(_die_vx(i, d, ndice), vz, DROP_HEIGHT * M.k + 1),
                    rotation = _random_rotation(),
                    scale = { 1, 1, 1 },
                    sound = false,
                    callback_function = function(obj)
                        state.slots[slot_i].dice[die_d] = obj.getGUID()
                        _setup_die(obj, slot_i, die_d)
                        _normalize_die_size(obj)
                        one_ready()
                    end,
                })
            end
        end
    end
    loop_done = true
    if pending <= 0 then
        finish()
    else
        Wait.time(finish, SPAWN_TIMEOUT)
    end
end

local function _face_rotation(die, value)
    local ok, rvs = pcall(function() return die.getRotationValues() end)
    if not ok or type(rvs) ~= "table" then return nil end
    local yaw = self.getRotation().y
    for _, rv in ipairs(rvs) do
        if tonumber(rv.value) == tonumber(value) then
            local r = rv.rotation
            return { r.x, (r.y + yaw) % 360, r.z }
        end
    end
    return nil
end

local function _park_die(die, i, d, ndice, value)
    local _, vz = _slot_origin(i)
    die.setLock(true)
    local half = DIE_SIZE * M.k / 2
    local ok, b = pcall(function() return die.getBoundsNormalized() end)
    if ok and b and b.size and b.size.y > 0 then half = b.size.y / 2 end
    die.setPositionSmooth(_world(_die_vx(i, d, ndice), vz, half + 0.02), false, true)
    local rot = value and _face_rotation(die, value)
    if rot then die.setRotationSmooth(rot, false, true) end
end

--------------------------------------------------------------------------------
-- Roll pipeline
--------------------------------------------------------------------------------
local function _all_settled(ctx)
    for _, i in ipairs(ctx.slots) do
        for d = 1, ctx.ndice do
            local die = _get_die(i, d)
            if die and (not die.resting or (die.held_by_color ~= nil and die.held_by_color ~= "")) then
                return false
            end
        end
    end
    return true
end

local function _finish_roll(ctx)
    if ctx.finished then return end
    ctx.finished = true

    local resolver = RESOLVERS[ctx.mode]
    local lines = {}
    local hits, rolled = {}, 0

    for _, i in ipairs(ctx.slots) do
        local s = state.slots[i]
        local v, lost = {}, false
        for d = 1, ctx.ndice do
            local die = _get_die(i, d)
            local value = die and tonumber(die.getValue())
            if value == nil then lost = true else value = math.floor(value) end
            v[d] = value or 0
            if die then _park_die(die, i, d, ctx.ndice, value) end
        end

        local r
        if lost then
            r = { label = "DIE LOST\nre-roll", chat = "a die was lost - press R to re-roll", tone = "none" }
        else
            r = resolver(s, v)
        end
        s.mode = ctx.mode
        s.result = r.label
        s.tone = r.tone or "none"
        if ctx.mode == "tohit" and not lost then
            s.hit = r.hit or ""
            if r.hit == "hit" then hits[#hits + 1] = SLOT_COLORS[i].name end
        end
        rolled = rolled + 1
        local name = _trim(s.name)
        lines[#lines + 1] = _slot_tag(i) .. " " .. ((name ~= "") and (name .. ": ") or "") .. r.chat
        _refresh_slot(i)
    end

    if ctx.mode == "tohit" and not ctx.single then
        state.hit_known = true
    end

    local header = "== " .. _player_name(ctx.player) .. ": " .. MODES[ctx.mode].label
    if ctx.mode == "location" then
        header = header .. " (" .. LOC_TABLES[state.loc_table] .. ", from " .. FACINGS[state.facing] .. ")"
    elseif ctx.mode == "cluster" and state.cluster_mod ~= 0 then
        header = header .. " (mod " .. _signed(state.cluster_mod) .. ")"
    end
    header = header .. " - " .. rolled .. ((ctx.ndice == 1) and " die" or " pair") .. (rolled ~= 1 and "s" or "") .. " =="
    printToAll(header, { 1, 1, 1 })
    for _, line in ipairs(lines) do printToAll(line, { 0.9, 0.9, 0.9 }) end
    if ctx.mode == "tohit" and not ctx.single then
        printToAll("Hits: " .. #hits .. " / " .. rolled .. ((#hits > 0) and (" (" .. table.concat(hits, ", ") .. ")") or ""), { 1, 1, 1 })
    end

    busy = false
    _set_status("Ready")
end

local function _start_roll(mode, slot_ids, player_color, single)
    if busy then
        printToColor("BattleTech Dice Mat: a roll is still in progress.", player_color, { 1, 0.6, 0.2 })
        return false
    end
    if #slot_ids == 0 then return false end
    busy = true
    _set_status("Rolling...")

    local ctx = { mode = mode, slots = slot_ids, ndice = _dice_for_mode(mode), player = player_color, single = single }
    if mode == "tohit" and not single then
        for i = 1, MAX_SLOTS do state.slots[i].hit = "" end
    end

    _ensure_dice(slot_ids, ctx.ndice, function()
        for _, i in ipairs(slot_ids) do
            local _, vz = _slot_origin(i)
            for d = 1, ctx.ndice do
                local die = _get_die(i, d)
                if die then
                    die.setLock(false)
                    local jx = (math.random() - 0.5) * 0.4
                    local jz = (math.random() - 0.5) * 0.4
                    die.setPosition(_world(_die_vx(i, d, ctx.ndice) + jx, vz + jz, DROP_HEIGHT * M.k))
                    die.setRotation(_random_rotation())
                    die.roll()
                end
            end
        end
        Wait.time(function()
            Wait.condition(
                function() _finish_roll(ctx) end,
                function() return _all_settled(ctx) end,
                ROLL_TIMEOUT,
                function() _finish_roll(ctx) end
            )
        end, SETTLE_DELAY)
    end)
    return true
end

local function _eligible_slots(mode)
    local ids = {}
    for i = 1, state.pairs do
        local s = state.slots[i]
        local ok = true
        if (mode == "location" or mode == "cluster") and state.hits_only and state.hit_known and s.hit == "miss" then
            ok = false
        end
        if mode == "cluster" and (tonumber(s.cluster) or 0) < 2 then
            ok = false
        end
        if ok then ids[#ids + 1] = i end
    end
    return ids
end

local function _roll_mode(mode, player_color)
    local ids = _eligible_slots(mode)
    if #ids == 0 then
        local msg
        if mode == "cluster" then
            msg = "No pair to roll: set a CLUSTER size (2+, e.g. 15 for an LRM-15) on the pairs that hit."
        else
            msg = "No hits to resolve - every pair missed. Turn HITS ONLY off to roll anyway."
        end
        printToColor("BattleTech Dice Mat: " .. msg, player_color, { 1, 0.6, 0.2 })
        return
    end
    _start_roll(mode, ids, player_color, false)
end

local function _clear_all()
    for i = 1, MAX_SLOTS do
        _destroy_slot_dice(i)
        local s = state.slots[i]
        s.result, s.tone, s.hit, s.mode = "", "none", "", ""
    end
    state.hit_known = false
    _refresh_all()
end

local function _set_pairs(n)
    n = _clamp(n, 1, MAX_SLOTS)
    if n == state.pairs then return end
    state.pairs = n
    for i = n + 1, MAX_SLOTS do
        _destroy_slot_dice(i)
        local s = state.slots[i]
        s.result, s.tone, s.hit, s.mode = "", "none", "", ""
    end
    _refresh_all()
end

--------------------------------------------------------------------------------
-- Initialization / events
--------------------------------------------------------------------------------
local function _load_state(saved_data)
    state = _default_state()
    if saved_data == nil or saved_data == "" then return end
    local ok, data = pcall(function() return JSON.decode(saved_data) end)
    if not ok or type(data) ~= "table" then return end
    for _, key in ipairs({ "pairs", "facing", "loc_table", "cluster_mod" }) do
        if tonumber(data[key]) then state[key] = math.floor(tonumber(data[key])) end
    end
    for _, key in ipairs({ "hits_only", "mirror", "hit_known" }) do
        if type(data[key]) == "boolean" then state[key] = data[key] end
    end
    state.pairs = _clamp(state.pairs, 1, MAX_SLOTS)
    state.facing = _clamp(state.facing, 1, #FACINGS)
    state.loc_table = _clamp(state.loc_table, 1, #LOC_TABLES)
    state.cluster_mod = _clamp(state.cluster_mod, CLUSTER_MOD_MIN, CLUSTER_MOD_MAX)
    if type(data.slots) == "table" then
        for i = 1, MAX_SLOTS do
            local src, dst = data.slots[i], state.slots[i]
            if type(src) == "table" then
                for _, key in ipairs({ "name", "tn", "cluster", "mode", "hit", "result", "tone" }) do
                    if src[key] ~= nil then dst[key] = tostring(src[key]) end
                end
                if type(src.dice) == "table" then
                    dst.dice = { tostring(src.dice[1] or ""), tostring(src.dice[2] or "") }
                end
            end
        end
    end
end

function onLoad(saved_data)
    _load_state(saved_data)
    _build_ui()
    -- Dice from a previous session: re-tint, and make sure leftovers beyond the
    -- active pair count are cleaned up.
    for i = 1, MAX_SLOTS do
        for d = 1, 2 do
            local die = _get_die(i, d)
            if not die then
                state.slots[i].dice[d] = ""
            elseif i > state.pairs then
                _destroy_die(i, d)
            end
        end
    end
end

function onSave()
    return JSON.encode(state)
end

function onDestroy()
    if not state then return end
    for i = 1, MAX_SLOTS do
        for d = 1, 2 do
            local die = _get_die(i, d)
            if die then die.destruct() end
        end
    end
end

--------------------------------------------------------------------------------
-- UI handlers (must be global: TTS calls them by name)
--------------------------------------------------------------------------------
function noop() end

function btn_tohit(_, color) _roll_mode("tohit", color) end
function btn_location(_, color) _roll_mode("location", color) end
function btn_cluster(_, color) _roll_mode("cluster", color) end
function btn_crit(_, color) _roll_mode("crit", color) end
function btn_critslot(_, color) _roll_mode("critslot", color) end
function btn_generic(_, color) _roll_mode("generic", color) end

function btn_clear(_, color)
    if busy then
        printToColor("BattleTech Dice Mat: wait for the roll to finish.", color, { 1, 0.6, 0.2 })
        return
    end
    _clear_all()
end

function btn_pairs_dec(_, color)
    if busy then return end
    _set_pairs(state.pairs - 1)
end

function btn_pairs_inc(_, color)
    if busy then return end
    _set_pairs(state.pairs + 1)
end

function btn_facing(_, color, alt)
    local step = alt and -1 or 1
    state.facing = ((state.facing - 1 + step) % #FACINGS) + 1
    _refresh_settings()
end

function btn_loc_table(_, color, alt)
    local step = alt and -1 or 1
    state.loc_table = ((state.loc_table - 1 + step) % #LOC_TABLES) + 1
    _refresh_settings()
end

function btn_clmod_dec() state.cluster_mod = _clamp(state.cluster_mod - 1, CLUSTER_MOD_MIN, CLUSTER_MOD_MAX); _refresh_settings() end
function btn_clmod_inc() state.cluster_mod = _clamp(state.cluster_mod + 1, CLUSTER_MOD_MIN, CLUSTER_MOD_MAX); _refresh_settings() end

function btn_hits_only()
    state.hits_only = not state.hits_only
    _refresh_settings()
end

function btn_mirror(_, color)
    if busy then return end
    state.mirror = not state.mirror
    _build_ui()
    -- Move parked dice to their mirrored slots.
    for i = 1, state.pairs do
        local n = (_get_die(i, 2) ~= nil) and 2 or 1
        for d = 1, n do
            local die = _get_die(i, d)
            if die then _park_die(die, i, d, n, nil) end
        end
    end
end

local HELP_TEXT = table.concat({
    "[b]BattleTech Dice Mat v" .. VERSION .. "[/b]",
    "1) Set PAIRS (or click a slot number). Every pair has its own color.",
    "2) Optional: type a weapon name, a TN (target number) and a CLUSTER size (e.g. 15 for LRM-15) per slot.",
    "3) TO-HIT rolls every pair; each lands back in its own colored slot, in order. Result = HIT/MISS vs TN.",
    "4) LOCATION rolls only the pairs that hit (HITS ONLY), using the ATTACK FROM column. TABLE: MECH 2D6, PUNCH/KICK 1D6.",
    "5) CLUSTER rolls the Cluster Hits Table for hitting pairs with a cluster size. CL MOD: Artemis IV +2, AMS -4.",
    "6) CRIT CHECK: 8-9 = 1, 10-11 = 2, 12 = 3 / limb or head blown off. CRIT SLOT: die A 1-3 upper / 4-6 lower half, die B = slot.",
    "7) 2D6 / PSR: plain 2D6 per pair (PSR, initiative, shutdown, ammo explosion, consciousness), PASS/FAIL vs TN if set.",
    "R = re-roll just that pair. CLEAR removes the mat's dice. MIRROR flips the layout if slot 1 is not on your left.",
}, "\n")

function btn_help(_, color)
    printToColor(HELP_TEXT, color, { 0.9, 0.9, 0.9 })
end

for i = 1, MAX_SLOTS do
    _G["slot_select_" .. i] = function(_, color)
        if busy then return end
        _set_pairs(i)
    end
    _G["slot_reroll_" .. i] = function(_, color)
        if i > state.pairs then return end
        local s = state.slots[i]
        local mode = (s.mode ~= "" and RESOLVERS[s.mode]) and s.mode or "generic"
        _start_roll(mode, { i }, color, true)
    end
    _G["slot_name_" .. i] = function(_, color, value)
        state.slots[i].name = tostring(value or "")
    end
    _G["slot_tn_" .. i] = function(_, color, value)
        state.slots[i].tn = _trim(value)
    end
    _G["slot_cluster_" .. i] = function(_, color, value)
        state.slots[i].cluster = _trim(value)
    end
end

--------------------------------------------------------------------------------
-- Public API (callable from other scripts via mat.call("api_roll", {...}))
--------------------------------------------------------------------------------
-- params: { mode = "tohit"|"location"|"cluster"|"crit"|"critslot"|"generic", color = "White" }
function api_roll(params)
    params = params or {}
    local mode = params.mode or "generic"
    if not RESOLVERS[mode] then return false end
    _roll_mode(mode, params.color or "White")
    return true
end

-- Returns a copy of the current per-slot results.
function api_get_results()
    local out = {}
    for i = 1, state.pairs do
        local s = state.slots[i]
        out[i] = { color = SLOT_COLORS[i].name, name = s.name, mode = s.mode, hit = s.hit, result = s.result }
    end
    return out
end
