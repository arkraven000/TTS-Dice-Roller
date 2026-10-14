--[[
================================================================================
  BATTLETECH DICE MAT v2  -  "In 2s, by color" for Tabletop Simulator
================================================================================
  Object script. Put it on any flat object (the shipped Saved Object uses a
  scaled BlockSquare) and the mat builds itself.

  Same feel as the Hutber / 40K dice table:
    1. pick a DICE COLOR, click +2D6 (once per weapon)
    2. click ROLL IN 2s BY COLOR  ->  instant roll, every color gets its own
       row, dice are paired in 2s inside their color, each pair shows its total
    3. right-click CLEAR to wipe the mat

  The fix for "they spawned disjointed from their colors": pairs are always
  built *within* one color - two different colors are never paired together.
  Dice you drop on the mat yourself (e.g. from the BT mod) are picked up too
  and grouped by their tint.

  READ AS turns every pair total into a BattleTech result: TO-HIT vs TN, hit
  location (front/left/right/rear), cluster hits for a launcher size, or a
  critical-hit check. Click a pair's result to re-roll just that pair.

  Multiplayer: object scripts run on the host only; all clicks are processed
  by one authority. Settings persist through onSave/onLoad.
================================================================================
]]

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local VERSION = "2.0.0"

-- Layout is designed on a DESIGN_W x DESIGN_D grid, scaled to the mat's size.
local DESIGN_W, DESIGN_D = 30, 19
-- Scripted button size units per world unit (button scale 1, object scale 1).
local BUTTON_UNITS = 500

local DIE_SIZE = 1.0          -- die edge, design units
local DIE_GAP = 0.12          -- gap between the two dice of a pair
local GROUP_GAP = 0.9         -- gap between pairs
local SINGLE_GAP = 0.2        -- gap between dice in SORTED mode
local ROW_FIRST_Z = 3.0       -- design z of the first result row (dice centre)
local ROW_H = 1.85            -- row pitch
local MAX_ROWS = 7
local AREA_LEFT = -12.2       -- first die edge in a row
local AREA_RIGHT = 14.7       -- last die edge in a row
local ROW_LABEL_X = -13.55
local GROUP_LABEL_DZ = -0.82  -- result label offset below the pair
local MAX_GROUP_LABELS = 63   -- 9 pairs x 7 rows
local MAX_DICE = 96
local DICE_TAG = "BTDiceMat"

local PALETTE = {
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
}
local SPAWN_AMOUNTS = { 1, 2, 4, 6, 10 }

local MAT_TEXT     = { 0.92, 0.92, 0.88 }
local MAT_TEXT_DIM = { 0.60, 0.62, 0.60 }
local PANEL_COLOR  = { 0.20, 0.21, 0.23 }
local TONE_COLORS = {
    good = { 0.12, 0.45, 0.20 },
    bad  = { 0.55, 0.13, 0.13 },
    info = { 0.20, 0.25, 0.34 },
    none = { 0.17, 0.18, 0.20 },
}

-- READ AS modes. `input` names what the number box means in that mode.
local MODES = {
    { key = "sum",      label = "SUM" },
    { key = "tohit",    label = "TO-HIT",    input = "tn" },
    { key = "loc",      label = "LOC FRONT", facing = "FRONT" },
    { key = "loc",      label = "LOC LEFT",  facing = "LEFT" },
    { key = "loc",      label = "LOC RIGHT", facing = "RIGHT" },
    { key = "loc",      label = "LOC REAR",  facing = "REAR" },
    { key = "cluster",  label = "CLUSTER",   input = "size" },
    { key = "crit",     label = "CRIT CHECK" },
}

-- 'Mech Hit Location Table (2D6). A 2 is a possible through-armor crit (TAC).
local MECH_LOCATION = {
    FRONT = { [2]="CT", [3]="RA", [4]="RA", [5]="RL", [6]="RT", [7]="CT",
              [8]="LT", [9]="LL", [10]="LA", [11]="LA", [12]="HD" },
    LEFT  = { [2]="LT", [3]="LL", [4]="LA", [5]="LA", [6]="LL", [7]="LT",
              [8]="CT", [9]="RT", [10]="RA", [11]="RL", [12]="HD" },
    RIGHT = { [2]="RT", [3]="RL", [4]="RA", [5]="RA", [6]="RL", [7]="RT",
              [8]="CT", [9]="LT", [10]="LA", [11]="LL", [12]="HD" },
}
MECH_LOCATION.REAR = MECH_LOCATION.FRONT

-- Cluster Hits Table. Row = 2D6 roll, column = weapon size 2..20.
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
local CLUSTER_MAX = 20

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local state                  -- persisted
local M = {}                 -- layout metrics (runtime)
local ui = { btn = {}, input = {} }
local button_count, input_count = 0, 0
local groups = {}            -- current layout: { {guids={...}, label_slot=n, color=rgb, name=...} }
local unrolled = {}          -- guid -> true for dice spawned but not rolled yet
local last_layout = "pairs"  -- "pairs" or "sorted"

local function _default_state()
    return { version = 2, color = 1, mode = 1, tn = "", size = "", mirror = false }
end

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------
local function _clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function _trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _hex(rgb)
    return string.format("%02x%02x%02x",
        math.floor(_clamp(rgb[1], 0, 1) * 255 + 0.5),
        math.floor(_clamp(rgb[2], 0, 1) * 255 + 0.5),
        math.floor(_clamp(rgb[3], 0, 1) * 255 + 0.5))
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

local function _rgb_of(c)
    if c == nil then return { 1, 1, 1 } end
    return { c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1 }
end

-- Map a die tint to a color group. Palette colors keep palette order; any
-- other tint (dice brought from another mod) gets its own group after them.
local function _color_group(rgb)
    local best, best_d = nil, 0.03
    for i, p in ipairs(PALETTE) do
        local d = (rgb[1] - p.rgb[1]) ^ 2 + (rgb[2] - p.rgb[2]) ^ 2 + (rgb[3] - p.rgb[3]) ^ 2
        if d < best_d then best, best_d = i, d end
    end
    if best then
        return { key = "p" .. best, order = best, name = PALETTE[best].name, rgb = PALETTE[best].rgb }
    end
    local q = { math.floor(rgb[1] * 20 + 0.5) / 20, math.floor(rgb[2] * 20 + 0.5) / 20, math.floor(rgb[3] * 20 + 0.5) / 20 }
    local hex = _hex(q)
    return { key = "x" .. hex, order = 100, name = "#" .. string.upper(hex), rgb = q }
end

--------------------------------------------------------------------------------
-- Rules (pure functions, also used by the tests)
--------------------------------------------------------------------------------
function cluster_hits(size, roll)
    size = math.floor(tonumber(size) or 0)
    roll = _clamp(math.floor(tonumber(roll) or 2), 2, 12)
    if size <= 0 then return 0, false end
    if size == 1 then return 1, false end
    if size <= CLUSTER_MAX then return CLUSTER_ROWS[roll][size - 1], false end
    local total, left = 0, size          -- MRM-30/40: split into chunks of <= 20
    while left > 0 do
        local chunk = math.min(left, CLUSTER_MAX)
        total = total + ((chunk == 1) and 1 or CLUSTER_ROWS[roll][chunk - 1])
        left = left - chunk
    end
    return total, true
end

function mech_location(facing, total)
    return (MECH_LOCATION[facing] or MECH_LOCATION.FRONT)[total]
end

function crit_check(total)
    if total <= 7 then return 0 end
    if total <= 9 then return 1 end
    if total <= 11 then return 2 end
    return 3
end

-- Interpret one group of dice values under the current READ AS mode.
-- Returns label (short, under the pair), chat text and tone.
function read_group(values, mode_index, tn, size)
    local mode = MODES[mode_index] or MODES[1]
    local total = 0
    for _, v in ipairs(values) do total = total + v end
    if #values ~= 2 then
        return tostring(total), tostring(total) .. " (" .. #values .. " die)", "none"
    end
    local dice = values[1] .. "+" .. values[2]
    if mode.key == "tohit" then
        tn = tonumber(tn)
        if not tn then return tostring(total), dice .. " = " .. total, "info" end
        if tn >= 13 then return total .. " NO", dice .. " = " .. total .. " (TN 13+ impossible)", "bad" end
        if total >= tn then return total .. " HIT", dice .. " = " .. total .. " HIT", "good" end
        return total .. " miss", dice .. " = " .. total .. " miss", "bad"
    elseif mode.key == "loc" then
        local code = mech_location(mode.facing, total)
        local rear = mode.facing == "REAR" and (code == "CT" or code == "LT" or code == "RT")
        local loc = code .. (rear and "(R)" or "")
        if total == 2 then return "2 " .. loc .. " TAC", dice .. " = 2 " .. loc .. " +TAC", "bad" end
        if code == "HD" then return "12 HEAD", dice .. " = 12 HEAD", "bad" end
        return total .. " " .. loc, dice .. " = " .. total .. " " .. loc, "info"
    elseif mode.key == "cluster" then
        size = tonumber(size)
        if not size or size < 1 then return tostring(total), dice .. " = " .. total, "info" end
        local hits, approx = cluster_hits(size, total)
        local txt = hits .. "/" .. math.floor(size) .. (approx and "~" or "")
        return total .. ": " .. txt, dice .. " = " .. total .. " -> " .. txt .. " hit", "info"
    elseif mode.key == "crit" then
        local n = crit_check(total)
        if n == 0 then return total .. " none", dice .. " = " .. total .. " no crit", "info" end
        if n == 3 then return "12 CRIT x3", dice .. " = 12: 3 crits / head or limb blown off", "bad" end
        return total .. " CRIT x" .. n, dice .. " = " .. total .. ": " .. n .. " crit" .. (n > 1 and "s" or ""), "bad"
    end
    return tostring(total), dice .. " = " .. total, "none"
end

--------------------------------------------------------------------------------
-- Layout helpers
--------------------------------------------------------------------------------
local function _measure()
    local s = self.getScale()
    M.sx, M.sy, M.sz = s.x, s.y, s.z
    local ok, b = pcall(function() return self.getBoundsNormalized() end)
    if ok and b and b.size and b.size.x > 0 and b.size.z > 0 then
        M.k = math.min(b.size.x / DESIGN_W, b.size.z / DESIGN_D)
        M.top = ((b.center.y - self.getPosition().y) + b.size.y / 2) / M.sy
    else
        M.k = math.min(M.sx / DESIGN_W, M.sz / DESIGN_D)
        M.top = 0.5
    end
end

-- Design coords (vx right, vz away from the player) -> object local.
local function _local(vx, vz, lift)
    local mx = state.mirror and -1 or 1
    return { mx * vx * M.k / M.sx, M.top + (lift or 0.03) / M.sy, -vz * M.k / M.sz }
end

local function _world(vx, vz, lift)
    return self.positionToWorld(_local(vx, vz, lift))
end

-- World position -> design coords (vx, vz, height above the mat surface).
local function _design(pos)
    local l = self.positionToLocal(pos)
    local mx = state.mirror and -1 or 1
    return mx * l.x * M.sx / M.k, -l.z * M.sz / M.k, (l.y - M.top) * M.sy
end

local function _ui_scale()
    return { M.k / M.sx, M.k / M.sy, M.k / M.sz }
end

local function _row_z(r) return ROW_FIRST_Z - (r - 1) * ROW_H end

--------------------------------------------------------------------------------
-- UI helpers
--------------------------------------------------------------------------------
local function _add_button(key, p)
    self.createButton({
        click_function = p.fn or "noop",
        function_owner = self,
        label = p.label or "",
        position = _local(p.vx, p.vz, p.lift),
        rotation = { 0, 0, 0 },
        scale = _ui_scale(),
        width = (p.w or 0) * BUTTON_UNITS,
        height = (p.h or 0) * BUTTON_UNITS,
        font_size = (p.font or 0.45) * BUTTON_UNITS,
        color = p.color or PANEL_COLOR,
        font_color = p.font_color or MAT_TEXT,
        tooltip = p.tooltip or "",
    })
    ui.btn[key] = button_count
    button_count = button_count + 1
end

local function _add_label(key, vx, vz, text, font, color)
    _add_button(key, { vx = vx, vz = vz, label = text, font = font, font_color = color or MAT_TEXT })
end

local function _edit(key, params)
    local idx = ui.btn[key]
    if idx == nil then return end
    params.index = idx
    self.editButton(params)
end

local function _mode() return MODES[state.mode] or MODES[1] end

local function _refresh_controls()
    for i, c in ipairs(PALETTE) do
        local sel = (i == state.color)
        _edit("color_" .. i, {
            label = sel and "ON" or "",
            width = (sel and 1.05 or 0.8) * BUTTON_UNITS,
            height = (sel and 1.05 or 0.8) * BUTTON_UNITS,
        })
    end
    local mode = _mode()
    _edit("read_as", { label = "READ AS\n" .. mode.label })
    local idx = ui.input.number
    if idx ~= nil then
        local value, placeholder = "", "-"
        if mode.input == "tn" then value, placeholder = state.tn, "TN" end
        if mode.input == "size" then value, placeholder = state.size, "SIZE" end
        self.editInput({ index = idx, value = value, label = placeholder })
    end
end

local function _build_ui()
    self.clearButtons()
    self.clearInputs()
    ui = { btn = {}, input = {} }
    button_count, input_count = 0, 0
    _measure()

    _add_label("title", -7.6, 8.45, "BATTLETECH  DICE", 1.0)
    _add_label("subtitle", -7.6, 7.55, "ordered 2D6 - in 2s, by color", 0.42, MAT_TEXT_DIM)
    _add_button("help", { vx = 10.9, vz = 8.3, w = 2.2, h = 0.85, label = "HELP", font = 0.4,
        fn = "btn_help", tooltip = "Print how to use the mat to your chat" })
    _add_button("mirror", { vx = 13.55, vz = 8.3, w = 2.5, h = 0.85, label = "MIRROR", font = 0.4,
        fn = "btn_mirror", tooltip = "Flip the layout left/right if it reads backwards" })

    -- Dice color picker + spawn buttons
    _add_label("color_label", -13.6, 6.3, "DICE\nCOLOR", 0.34, MAT_TEXT_DIM)
    for i, c in ipairs(PALETTE) do
        _add_button("color_" .. i, { vx = -11.9 + (i - 1) * 1.17, vz = 6.3, w = 0.8, h = 0.8, font = 0.3,
            color = c.rgb, font_color = _text_on(c.rgb), fn = "pick_color_" .. i,
            tooltip = c.name .. " dice for the next +D6" })
    end
    for n, amount in ipairs(SPAWN_AMOUNTS) do
        local main = (amount == 2)
        _add_button("spawn_" .. amount, { vx = 0.9 + (n - 1) * 2.05, vz = 6.3, w = 1.85, h = main and 1.05 or 0.85,
            label = "+" .. amount .. "D6", font = main and 0.46 or 0.38,
            color = main and { 0.85, 0.85, 0.82 } or PANEL_COLOR, font_color = main and { 0.05, 0.05, 0.05 } or MAT_TEXT,
            fn = "spawn_" .. amount, tooltip = "Add " .. amount .. " dice in the selected color" .. (main and " (one weapon = one +2D6)" or "") })
    end
    _add_label("count", 12.9, 6.3, "0 dice", 0.36, MAT_TEXT_DIM)

    -- Roll row
    _add_button("roll_pairs", { vx = -9.5, vz = 4.75, w = 9.6, h = 1.35, label = "ROLL IN 2s BY COLOR", font = 0.62,
        color = { 0.66, 0.14, 0.14 }, font_color = { 1, 1, 1 }, fn = "btn_roll_pairs",
        tooltip = "Roll every die on the mat. Each color gets its own row; dice are paired in 2s inside their color." })
    _add_button("roll_sorted", { vx = -2.75, vz = 4.75, w = 3.4, h = 1.35, label = "ROLL\nSORTED", font = 0.4,
        fn = "btn_roll_sorted", tooltip = "Roll every die and sort by result (40K style rows of 6s, 5s, ...)" })
    _add_button("read_as", { vx = 1.45, vz = 4.75, w = 4.3, h = 1.35, label = "", font = 0.4,
        color = { 0.18, 0.30, 0.55 }, font_color = { 1, 1, 1 }, fn = "btn_read_as",
        tooltip = "What the number under each pair means: SUM, TO-HIT vs TN, hit LOCATION, CLUSTER hits, CRIT CHECK. Right-click goes back." })
    self.createInput({
        input_function = "input_number", function_owner = self, label = "-", value = "",
        position = _local(4.6, 4.75, 0.03), rotation = { 0, 0, 0 }, scale = _ui_scale(),
        width = 1.5 * BUTTON_UNITS, height = 1.0 * BUTTON_UNITS, font_size = 0.55 * BUTTON_UNITS,
        alignment = 3, validation = 2, tab = 1, color = { 0.85, 0.85, 0.82 }, font_color = { 0.05, 0.05, 0.05 },
        tooltip = "TO-HIT: target number.  CLUSTER: launcher size (e.g. 15 for LRM-15).",
    })
    ui.input.number = input_count
    input_count = input_count + 1
    _add_button("del_misses", { vx = 7.9, vz = 4.75, w = 3.3, h = 1.35, label = "DELETE\nMISSES", font = 0.38,
        fn = "btn_del_misses", tooltip = "TO-HIT: remove the pairs that missed so you can roll locations for the hits" })
    _add_button("clear", { vx = 12.25, vz = 4.75, w = 4.4, h = 1.35, label = "CLEAR\n(right-click)", font = 0.38,
        color = { 0.30, 0.30, 0.30 }, fn = "btn_clear", tooltip = "Right-click: delete every die on the mat" })

    -- Result rows (pre-created, shown/hidden by editing)
    for r = 1, MAX_ROWS do
        _add_button("row_" .. r, { vx = ROW_LABEL_X, vz = _row_z(r), label = "", font = 0.36, lift = 0.02 })
    end
    for g = 1, MAX_GROUP_LABELS do
        _add_button("group_" .. g, { vx = 0, vz = 0, label = "", font = 0.34, lift = 0.02,
            fn = "group_click_" .. g, tooltip = "Click: re-roll this pair" })
    end

    _refresh_controls()
end

--------------------------------------------------------------------------------
-- Dice
--------------------------------------------------------------------------------
local function _is_d6(o)
    if o == nil or (o.isDestroyed and o.isDestroyed()) then return false end
    local t = o.type or o.tag
    if t ~= "Dice" then return false end
    local ok, rvs = pcall(function() return o.getRotationValues() end)
    return ok and type(rvs) == "table" and #rvs == 6
end

-- Every d6 lying on (or just above) the mat, not held by a player.
local function _dice_on_mat()
    local out = {}
    for _, o in ipairs(getAllObjects()) do
        if o ~= self and _is_d6(o) and (o.held_by_color == nil or o.held_by_color == "") then
            local vx, vz, h = _design(o.getPosition())
            if math.abs(vx) <= DESIGN_W / 2 and math.abs(vz) <= DESIGN_D / 2 and h > -0.5 and h < 8 then
                out[#out + 1] = { obj = o, vx = vx, vz = vz }
            end
        end
    end
    return out
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
end

local function _die_value(die)
    local v = tonumber(die.getValue())
    if v then return math.floor(v) end
    return 1
end

-- Put a die at design (vx, vz) showing `value`, square to the mat.
local function _place(die, vx, vz, value)
    local half = DIE_SIZE * M.k / 2
    local ok, b = pcall(function() return die.getBoundsNormalized() end)
    if ok and b and b.size and b.size.y > 0 then half = b.size.y / 2 end
    die.setPosition(_world(vx, vz, half + 0.02))
    local rot = _face_rotation(die, value)
    if rot then die.setRotation(rot) end
    if die.setVelocity then die.setVelocity({ 0, 0, 0 }) end
    if die.setAngularVelocity then die.setAngularVelocity({ 0, 0, 0 }) end
end

local function _normalize_die_size(die)
    local ok, b = pcall(function() return die.getBoundsNormalized() end)
    if not ok or not b or not b.size then return end
    local size = math.max(b.size.x, b.size.y, b.size.z)
    if size <= 0 then return end
    local f = die.getScale().x * (DIE_SIZE * M.k) / size
    die.setScale({ f, f, f })
end

--------------------------------------------------------------------------------
-- Layout + labels
--------------------------------------------------------------------------------
local function _hide_results()
    for r = 1, MAX_ROWS do _edit("row_" .. r, { label = "", width = 0, height = 0 }) end
    for g = 1, MAX_GROUP_LABELS do _edit("group_" .. g, { label = "", width = 0, height = 0 }) end
end

local function _group_values(g)
    local vals = {}
    for _, guid in ipairs(g.guids) do
        local die = getObjectFromGUID(guid)
        if die == nil then return nil end
        vals[#vals + 1] = g.values and g.values[guid] or _die_value(die)
    end
    return vals
end

local function _group_is_unrolled(g)
    for _, guid in ipairs(g.guids) do
        if unrolled[guid] then return true end
    end
    return false
end

-- Update the label under one pair from its dice.
local function _refresh_group_label(g)
    if not g.label_slot then return nil end
    local key = "group_" .. g.label_slot
    local vals = _group_values(g)
    if vals == nil then
        _edit(key, { label = "gone", color = TONE_COLORS.none, tooltip = "A die of this pair is missing" })
        return nil
    end
    if _group_is_unrolled(g) then
        _edit(key, { label = "?", color = TONE_COLORS.none, tooltip = "Not rolled yet" })
        return nil
    end
    local label, chat, tone = read_group(vals, state.mode, state.tn, state.size)
    _edit(key, { label = label, color = TONE_COLORS[tone] or TONE_COLORS.none,
        tooltip = g.name .. " pair: " .. chat .. "\nClick to re-roll this pair" })
    return chat, tone
end

local function _refresh_labels()
    for _, g in ipairs(groups) do _refresh_group_label(g) end
end

-- Group dice into rows. layout = "pairs" (by color, in 2s) or "sorted" (by value).
local function _build_rows(dice, layout)
    local rows = {}
    if layout == "sorted" then
        local by_value = {}
        for _, d in ipairs(dice) do
            local v = d.value or _die_value(d.obj)
            by_value[v] = by_value[v] or {}
            table.insert(by_value[v], d)
        end
        for v = 6, 1, -1 do
            local list = by_value[v]
            if list then
                table.sort(list, function(a, b)
                    if a.group.order ~= b.group.order then return a.group.order < b.group.order end
                    return a.group.key < b.group.key
                end)
                local row = { label = v .. "s: " .. #list, color = PANEL_COLOR, text = MAT_TEXT, groups = {} }
                for _, d in ipairs(list) do
                    table.insert(row.groups, { dice = { d }, name = d.group.name, rgb = d.group.rgb })
                end
                rows[#rows + 1] = row
            end
        end
        return rows
    end

    -- pairs: one row per color, colors in palette order, dice in reading order
    local by_color, order = {}, {}
    for _, d in ipairs(dice) do
        local key = d.group.key
        if not by_color[key] then
            by_color[key] = { group = d.group, dice = {} }
            order[#order + 1] = key
        end
        table.insert(by_color[key].dice, d)
    end
    table.sort(order, function(a, b)
        local ga, gb = by_color[a].group, by_color[b].group
        if ga.order ~= gb.order then return ga.order < gb.order end
        return a < b
    end)
    for _, key in ipairs(order) do
        local entry = by_color[key]
        table.sort(entry.dice, function(a, b)
            if math.abs(a.vz - b.vz) > 0.6 then return a.vz > b.vz end
            if math.abs(a.vx - b.vx) > 1e-6 then return a.vx < b.vx end
            return a.obj.getGUID() < b.obj.getGUID()
        end)
        local row = { label = string.upper(entry.group.name), color = entry.group.rgb,
            text = _text_on(entry.group.rgb), groups = {} }
        for i = 1, #entry.dice, 2 do
            local g = { dice = { entry.dice[i] }, name = entry.group.name, rgb = entry.group.rgb }
            if entry.dice[i + 1] then table.insert(g.dice, entry.dice[i + 1]) end
            table.insert(row.groups, g)
        end
        rows[#rows + 1] = row
    end
    return rows
end

-- Place every die of `rows` on the mat and set up the labels.
local function _apply_rows(rows, layout)
    _hide_results()
    groups = {}
    local r, slot, overflow = 0, 0, false
    for _, row in ipairs(rows) do
        r = r + 1
        local x = AREA_LEFT
        local first = true
        for _, g in ipairs(row.groups) do
            local n = #g.dice
            local width = n * DIE_SIZE + (n - 1) * DIE_GAP
            if x + width > AREA_RIGHT + 1e-6 then          -- wrap onto a new row
                r = r + 1
                x = AREA_LEFT
            end
            if first or x == AREA_LEFT then
                if r <= MAX_ROWS then
                    _edit("row_" .. r, {
                        label = first and row.label or "",
                        width = 2.1 * BUTTON_UNITS, height = 1.0 * BUTTON_UNITS,
                        color = row.color, font_color = row.text,
                        position = _local(ROW_LABEL_X, _row_z(r), 0.02),
                    })
                end
                first = false
            end
            if r > MAX_ROWS then overflow = true end
            local vz = _row_z(r)
            local guids, values = {}, {}
            for j, d in ipairs(g.dice) do
                local vx = x + (j - 1) * (DIE_SIZE + DIE_GAP) + DIE_SIZE / 2
                local value = d.value or _die_value(d.obj)
                _place(d.obj, vx, vz, value)
                guids[#guids + 1] = d.obj.getGUID()
                values[d.obj.getGUID()] = value
            end
            local entry = { guids = guids, values = values, name = g.name, rgb = g.rgb }
            if layout == "pairs" and r <= MAX_ROWS and slot < MAX_GROUP_LABELS then
                slot = slot + 1
                entry.label_slot = slot
                _edit("group_" .. slot, {
                    position = _local(x + width / 2, vz + GROUP_LABEL_DZ, 0.02),
                    width = math.max(width, 2.1) * BUTTON_UNITS, height = 0.55 * BUTTON_UNITS,
                })
            end
            groups[#groups + 1] = entry
            x = x + width + ((layout == "sorted") and SINGLE_GAP or GROUP_GAP)
        end
    end
    last_layout = layout
    return overflow
end

local function _update_count()
    local n = #_dice_on_mat()
    _edit("count", { label = n .. " di" .. ((n == 1) and "e" or "ce") })
    return n
end

-- Collect, (optionally) roll, and lay out every die on the mat.
local function _arrange(layout, roll)
    local found = _dice_on_mat()
    local function roll_die(d)
        d.value = math.random(6)
        unrolled[d.obj.getGUID()] = nil
    end
    for _, d in ipairs(found) do
        d.group = _color_group(_rgb_of(d.obj.getColorTint()))
        -- SORTED needs the values before it can build its rows
        if roll and layout == "sorted" then roll_die(d) end
    end
    local rows = _build_rows(found, layout)
    if roll and layout == "pairs" then
        -- roll in reading order: color by color, pair by pair
        for _, row in ipairs(rows) do
            for _, g in ipairs(row.groups) do
                for _, d in ipairs(g.dice) do roll_die(d) end
            end
        end
    end
    local overflow = _apply_rows(rows, layout)
    _refresh_labels()
    _update_count()
    return found, rows, overflow
end

local function _chat_summary(rows, player_color, layout)
    local mode = _mode()
    local header = "== " .. _player_name(player_color) .. ": "
    if layout == "sorted" then
        header = header .. "ROLL SORTED =="
        printToAll(header, { 1, 1, 1 })
        local parts = {}
        for _, row in ipairs(rows) do parts[#parts + 1] = row.label end
        printToAll(table.concat(parts, "  |  "), { 0.9, 0.9, 0.9 })
        return
    end
    header = header .. "IN 2s BY COLOR - " .. mode.label
    if mode.input == "tn" and tonumber(state.tn) then header = header .. " (TN " .. state.tn .. ")" end
    if mode.input == "size" and tonumber(state.size) then header = header .. " (size " .. state.size .. ")" end
    printToAll(header .. " ==", { 1, 1, 1 })
    local gi = 0
    local hits, pairs_total = 0, 0
    for _, row in ipairs(rows) do
        local parts = {}
        for _ = 1, #row.groups do
            gi = gi + 1
            local g = groups[gi]
            local vals = g and _group_values(g)
            if vals then
                local label, _, tone = read_group(vals, state.mode, state.tn, state.size)
                parts[#parts + 1] = label
                if #vals == 2 then
                    pairs_total = pairs_total + 1
                    if tone == "good" then hits = hits + 1 end
                end
            end
        end
        printToAll("[" .. _hex(row.color) .. "]" .. row.label .. "[-]: " .. table.concat(parts, "  |  "), { 0.9, 0.9, 0.9 })
    end
    if mode.key == "tohit" and tonumber(state.tn) then
        printToAll("Hits: " .. hits .. " / " .. pairs_total, { 1, 1, 1 })
    end
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
local function _roll(layout, player_color)
    local found, rows, overflow = _arrange(layout, true)
    if #found == 0 then
        printToColor("BattleTech Dice: no dice on the mat. Pick a color and click +2D6 first.", player_color, { 1, 0.6, 0.2 })
        return
    end
    _chat_summary(rows, player_color, layout)
    if overflow then
        printToColor("BattleTech Dice: too many dice for the mat - some rows run past the edge.", player_color, { 1, 0.6, 0.2 })
    end
end

local function _spawn(amount, player_color)
    local current = #_dice_on_mat()
    if current + amount > MAX_DICE then
        printToColor("BattleTech Dice: dice limit (" .. MAX_DICE .. ") reached.", player_color, { 1, 0.6, 0.2 })
        amount = MAX_DICE - current
    end
    if amount <= 0 then return end
    local c = PALETTE[state.color]
    local pending = amount
    for i = 1, amount do
        spawnObject({
            type = "Die_6",
            position = _world(AREA_RIGHT - 1 - (i - 1) * 1.2, _row_z(MAX_ROWS), 2),
            rotation = { 0, self.getRotation().y, 0 },
            scale = { 1, 1, 1 },
            sound = false,
            callback_function = function(die)
                die.setColorTint(c.rgb)
                die.setName("BT " .. c.name .. " die")
                if die.addTag then die.addTag(DICE_TAG) end
                _normalize_die_size(die)
                unrolled[die.getGUID()] = true
                pending = pending - 1
                if pending == 0 then _arrange("pairs", false) end
            end,
        })
    end
end

local function _reroll_group(slot, player_color)
    for _, g in ipairs(groups) do
        if g.label_slot == slot then
            local vals = {}
            for _, guid in ipairs(g.guids) do
                local die = getObjectFromGUID(guid)
                if die == nil then
                    printToColor("BattleTech Dice: that pair is missing a die - roll again.", player_color, { 1, 0.6, 0.2 })
                    return
                end
                local v = math.random(6)
                unrolled[guid] = nil
                g.values[guid] = v
                vals[#vals + 1] = v
                -- keep the die exactly where it is, just show the new face
                local rot = _face_rotation(die, v)
                if rot then die.setRotation(rot) end
            end
            local chat = _refresh_group_label(g)
            printToAll("[" .. _hex(g.rgb) .. "]" .. string.upper(g.name) .. "[-] re-roll by "
                .. _player_name(player_color) .. ": " .. (chat or table.concat(vals, "+")), { 0.9, 0.9, 0.9 })
            return
        end
    end
end

local function _delete_misses(player_color)
    local tn = tonumber(state.tn)
    if _mode().key ~= "tohit" or not tn then
        printToColor("BattleTech Dice: set READ AS to TO-HIT and enter a TN first.", player_color, { 1, 0.6, 0.2 })
        return
    end
    local removed = 0
    for _, g in ipairs(groups) do
        local vals = _group_values(g)
        if vals and #vals == 2 and not _group_is_unrolled(g) and (vals[1] + vals[2] < tn or tn >= 13) then
            for _, guid in ipairs(g.guids) do
                local die = getObjectFromGUID(guid)
                if die then die.destruct() end
            end
            removed = removed + 1
        end
    end
    printToAll(_player_name(player_color) .. " removed " .. removed .. " missed pair" .. (removed == 1 and "" or "s") .. ".", { 1, 0.85, 0.3 })
    -- Destruction completes at the end of the frame; re-pack afterwards.
    Wait.frames(function() _arrange("pairs", false) end, 1)
end

local function _clear(player_color)
    local n = 0
    for _, d in ipairs(_dice_on_mat()) do
        d.obj.destruct()
        n = n + 1
    end
    groups, unrolled = {}, {}
    _hide_results()
    _edit("count", { label = "0 dice" })
    if n > 0 then printToAll(_player_name(player_color) .. " cleared the dice mat (" .. n .. " dice).", { 1, 0.85, 0.3 }) end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
local function _load_state(saved_data)
    state = _default_state()
    if saved_data == nil or saved_data == "" then return end
    local ok, data = pcall(function() return JSON.decode(saved_data) end)
    if not ok or type(data) ~= "table" then return end
    if tonumber(data.color) then state.color = _clamp(math.floor(tonumber(data.color)), 1, #PALETTE) end
    if tonumber(data.mode) then state.mode = _clamp(math.floor(tonumber(data.mode)), 1, #MODES) end
    if data.tn ~= nil then state.tn = _trim(data.tn) end
    if data.size ~= nil then state.size = _trim(data.size) end
    if type(data.mirror) == "boolean" then state.mirror = data.mirror end
end

function onLoad(saved_data)
    math.randomseed(os.time())
    for _ = 1, 5 do math.random() end
    _load_state(saved_data)
    _build_ui()
    -- Dice from a saved game: re-attach the labels once everything is loaded.
    Wait.time(function() _arrange(last_layout, false) end, 1)
end

function onSave()
    return JSON.encode(state)
end

--------------------------------------------------------------------------------
-- UI handlers (global: TTS calls them by name)
--------------------------------------------------------------------------------
function noop() end

function btn_roll_pairs(_, color) _roll("pairs", color) end
function btn_roll_sorted(_, color) _roll("sorted", color) end
function btn_del_misses(_, color) _delete_misses(color) end

function btn_clear(_, color, alt)
    if not alt then
        printToColor("BattleTech Dice: use RIGHT-click to clear the mat.", color, { 1, 0.6, 0.2 })
        return
    end
    _clear(color)
end

function btn_read_as(_, color, alt)
    local step = alt and -1 or 1
    state.mode = ((state.mode - 1 + step) % #MODES) + 1
    _refresh_controls()
    _refresh_labels()
end

function input_number(_, color, value)
    local mode = _mode()
    if mode.input == "tn" then state.tn = _trim(value) end
    if mode.input == "size" then state.size = _trim(value) end
    _refresh_labels()
end

function btn_mirror()
    state.mirror = not state.mirror
    _build_ui()
    _arrange(last_layout, false)
end

local HELP_TEXT = table.concat({
    "[b]BattleTech Dice v" .. VERSION .. "[/b]  -  in 2s, by color",
    "1) Click a DICE COLOR, then +2D6 once per weapon (use a different color per weapon or per weapon type).",
    "2) ROLL IN 2s BY COLOR rolls everything instantly. Each color gets its own row and its dice are paired in 2s - colors are never mixed.",
    "3) The box under each pair shows its result. Click it to re-roll just that pair.",
    "4) READ AS changes what that box means: SUM, TO-HIT (type the TN in the number box), LOC FRONT/LEFT/RIGHT/REAR, CLUSTER (type the launcher size), CRIT CHECK.",
    "   Attack flow: TO-HIT -> DELETE MISSES -> READ AS LOC -> ROLL again: every hit keeps its color and shows where it landed.",
    "5) ROLL SORTED rolls and sorts by face (40K style). Right-click CLEAR to delete all dice on the mat.",
    "Dice you drop on the mat yourself are included and grouped by their color. MIRROR flips the layout if it reads backwards.",
}, "\n")

function btn_help(_, color)
    printToColor(HELP_TEXT, color, { 0.9, 0.9, 0.9 })
end

for i = 1, #PALETTE do
    _G["pick_color_" .. i] = function()
        state.color = i
        _refresh_controls()
    end
end

for _, amount in ipairs(SPAWN_AMOUNTS) do
    _G["spawn_" .. amount] = function(_, color) _spawn(amount, color) end
end

for g = 1, MAX_GROUP_LABELS do
    _G["group_click_" .. g] = function(_, color) _reroll_group(g, color) end
end

--------------------------------------------------------------------------------
-- Public API: other scripts can call these with mat.call(name, params)
--------------------------------------------------------------------------------
-- params: { layout = "pairs"|"sorted", color = "White" }
function api_roll(params)
    params = params or {}
    _roll((params.layout == "sorted") and "sorted" or "pairs", params.color or "White")
    return true
end

-- Current groups: { {color="Red", values={4,5}, label="9 HIT"}, ... }
function api_get_results()
    local out = {}
    for _, g in ipairs(groups) do
        local vals = _group_values(g)
        if vals then
            local label = read_group(vals, state.mode, state.tn, state.size)
            out[#out + 1] = { color = g.name, values = vals, label = label }
        end
    end
    return out
end
