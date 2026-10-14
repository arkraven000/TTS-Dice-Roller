-- Test scenarios for the BattleTech Dice Mat v2. Each TESTS entry runs in a
-- fresh Lua runtime with mock_tts.lua + the mat script loaded (run_tests.py).

TESTS = {}

local function eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected [" .. tostring(b) .. "] got [" .. tostring(a) .. "]", 2) end
end
local function ok(c, msg) if not c then error(msg or "assertion failed", 2) end end
local function near(a, b, eps, msg)
    if math.abs(a - b) > (eps or 1e-6) then error((msg or "") .. " expected ~" .. b .. " got " .. a, 2) end
end

local function state() return JSON.decode(onSave()) end

local PALETTE_NAMES = { "Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Cyan", "Pink", "White", "Brown" }
local PALETTE_RGB = { { 0.90, 0.16, 0.16 }, { 0.25, 0.50, 1.00 }, { 0.15, 0.72, 0.28 }, { 1.00, 0.88, 0.10 },
    { 1.00, 0.52, 0.05 }, { 0.66, 0.40, 0.95 }, { 0.15, 0.85, 0.90 }, { 1.00, 0.50, 0.78 },
    { 0.96, 0.96, 0.96 }, { 0.72, 0.47, 0.25 } }

local function color_index(name)
    for i, n in ipairs(PALETTE_NAMES) do if n == name then return i end end
end

local function fresh()
    onLoad("")
    MOCK.run()
end

local function spawn(color, amount)
    MOCK.click("pick_color_" .. color_index(color))
    MOCK.click("spawn_" .. (amount or 2))
    MOCK.run()
end

local function button_by_fn(fn)
    for _, b in ipairs(self._buttons) do if b.click_function == fn then return b end end
end

local function group_label(slot) return button_by_fn("group_click_" .. slot) end

-- Row labels are created right after the CLEAR button, in order.
local function row_label(r)
    for i, b in ipairs(self._buttons) do
        if b.click_function == "btn_clear" then return self._buttons[i + r] end
    end
end

local function tint_name(die)
    local t = die._tint
    for i, c in ipairs(PALETTE_RGB) do
        if t and math.abs(t.x - c[1]) < 1e-6 and math.abs(t.y - c[2]) < 1e-6 and math.abs(t.z - c[3]) < 1e-6 then
            return PALETTE_NAMES[i]
        end
    end
    return "other"
end

-- Dice grouped into rows as the White seat sees them (top to bottom, left to right).
local function rows_of_dice()
    local list = MOCK.dice()
    table.sort(list, function(a, b)
        if math.abs(a._pos.z - b._pos.z) > 0.3 then return a._pos.z > b._pos.z end
        return a._pos.x < b._pos.x
    end)
    local rows = {}
    for _, d in ipairs(list) do
        local last = rows[#rows]
        if last and math.abs(last[1]._pos.z - d._pos.z) < 0.3 then
            table.insert(last, d)
        else
            rows[#rows + 1] = { d }
        end
    end
    return rows
end

--------------------------------------------------------------------------------
-- Rules
--------------------------------------------------------------------------------
TESTS.cluster_table_shape = function()
    for size = 2, 20 do
        local prev = 0
        for roll = 2, 12 do
            local h = cluster_hits(size, roll)
            ok(h >= 1 and h <= size, "cluster " .. size .. "/" .. roll .. " out of range")
            ok(h >= prev, "cluster column " .. size .. " not monotonic at " .. roll)
            prev = h
        end
        eq(cluster_hits(size, 11), size); eq(cluster_hits(size, 12), size)
    end
end

TESTS.cluster_table_known_values = function()
    local row7 = { [2] = 1, [4] = 3, [5] = 3, [6] = 4, [10] = 6, [15] = 9, [20] = 12 }
    for size, hits in pairs(row7) do eq(cluster_hits(size, 7), hits, "row 7 size " .. size) end
    eq(cluster_hits(20, 9), 16); eq(cluster_hits(20, 2), 6); eq(cluster_hits(10, 2), 3)
    eq(cluster_hits(10, 9), 8); eq(cluster_hits(15, 4), 6); eq(cluster_hits(6, 2), 2)
    eq(cluster_hits(2, 7), 1); eq(cluster_hits(2, 8), 2); eq(cluster_hits(4, 3), 2)
    eq(cluster_hits(1, 7), 1)
    -- MRM columns printed in Total Warfare are exact; other sizes > 20 are split
    eq(cluster_hits(30, 2), 10); eq(cluster_hits(30, 4), 12); eq(cluster_hits(30, 9), 24)
    eq(cluster_hits(40, 7), 24); eq(cluster_hits(40, 12), 40)
    local h, approx = cluster_hits(30, 12)
    eq(h, 30); ok(not approx, "column 30 is exact")
    h, approx = cluster_hits(25, 12)
    eq(h, 25); ok(approx, "size 25 is an approximation")
end

TESTS.mech_location_table = function()
    local front = { "CT", "RA", "RA", "RL", "RT", "CT", "LT", "LL", "LA", "LA", "HD" }
    local left  = { "LT", "LL", "LA", "LA", "LL", "LT", "CT", "RT", "RA", "RL", "HD" }
    local right = { "RT", "RL", "RA", "RA", "RL", "RT", "CT", "LT", "LA", "LL", "HD" }
    for t = 2, 12 do
        eq(mech_location("FRONT", t), front[t - 1]); eq(mech_location("REAR", t), front[t - 1])
        eq(mech_location("LEFT", t), left[t - 1]); eq(mech_location("RIGHT", t), right[t - 1])
    end
end

TESTS.crit_check_table = function()
    for t = 2, 7 do eq(crit_check(t), 0) end
    eq(crit_check(8), 1); eq(crit_check(9), 1); eq(crit_check(10), 2); eq(crit_check(11), 2); eq(crit_check(12), 3)
end

TESTS.read_group_modes = function()
    -- modes: 1 SUM, 2 TO-HIT, 3 LOC FRONT, 4 LOC LEFT, 5 LOC RIGHT, 6 LOC REAR, 7 CLUSTER, 8 CRIT
    eq((read_group({ 4, 5 }, 1)), "9")
    eq((read_group({ 4, 5 }, 2, "8")), "9 HIT")
    eq((read_group({ 3, 4 }, 2, "8")), "7 miss")
    eq((read_group({ 6, 6 }, 2, "13")), "12 NO")
    eq((read_group({ 3, 4 }, 2, "")), "7")
    eq((read_group({ 1, 1 }, 3)), "2 CT TAC")
    eq((read_group({ 4, 4 }, 4)), "8 CT")
    eq((read_group({ 3, 3 }, 6)), "6 RT(R)")
    eq((read_group({ 6, 6 }, 5)), "12 HEAD")
    eq((read_group({ 4, 5 }, 7, nil, "20")), "9: 16/20")
    eq((read_group({ 4, 4 }, 8)), "8 CRIT x1")
    eq((read_group({ 2, 2 }, 8)), "4 none")
    eq((read_group({ 5 }, 2, "8")), "5", "a lone die just shows its value")
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------
TESTS.ui_builds_and_handlers_exist = function()
    fresh()
    for _, b in ipairs(self._buttons) do
        ok(type(_G[b.click_function]) == "function", "missing click function " .. tostring(b.click_function))
        ok(b.function_owner == self, "function_owner must be self")
        ok(b.font_size <= 1000, "font_size capped at 1000")
        ok(b.width == 0 or b.width >= 60, "button width below the TTS minimum")
    end
    eq(#self._inputs, 1, "one number box (TN / cluster size)")
    ok(type(_G[self._inputs[1].input_function]) == "function")
    ok(MOCK.button("ROLL IN 2s BY COLOR"), "main roll button")
    ok(MOCK.button("+2D6"), "+2D6 button")
end

local function rects()
    local s = self.getScale()
    local out = {}
    local function add(p, w, h)
        local c = self.positionToWorld(p.position)
        out[#out + 1] = { label = p.label or p.tooltip or "", x = c.x, z = c.z,
            hw = w * p.scale[1] * s.x / 2, hh = h * p.scale[3] * s.z / 2 }
    end
    for _, b in ipairs(self._buttons) do
        if b.width > 0 then
            add(b, b.width / 500, b.height / 500)
        elseif b.label ~= "" then
            local lines, longest = 0, 0
            for line in (b.label .. "\n"):gmatch("(.-)\n") do
                lines = lines + 1
                if #line > longest then longest = #line end
            end
            local em = b.font_size / 500
            add(b, longest * em * 0.55, lines * em)
        end
    end
    for _, i in ipairs(self._inputs) do add(i, i.width / 500, i.height / 500) end
    return out
end

local function check_layout()
    local b = self.getBoundsNormalized()
    local rs = rects()
    for _, r in ipairs(rs) do
        ok(math.abs(r.x - self._pos.x) + r.hw <= b.size.x / 2 + 1e-6, "off the mat in X: " .. r.label)
        ok(math.abs(r.z - self._pos.z) + r.hh <= b.size.z / 2 + 1e-6, "off the mat in Z: " .. r.label)
    end
    for a = 1, #rs do
        for c = a + 1, #rs do
            local A, B = rs[a], rs[c]
            local overlap = math.abs(A.x - B.x) < (A.hw + B.hw) - 1e-3 and math.abs(A.z - B.z) < (A.hh + B.hh) - 1e-3
            ok(not overlap, "overlap: '" .. A.label .. "' and '" .. B.label .. "'")
        end
    end
    -- dice stay on the mat and never cover a control or a label
    for _, d in ipairs(MOCK.dice()) do
        local half = d.getBoundsNormalized().size.x / 2
        ok(math.abs(d._pos.x - self._pos.x) + half <= b.size.x / 2 + 1e-6, "die off the mat")
        ok(math.abs(d._pos.z - self._pos.z) + half <= b.size.z / 2 + 1e-6, "die off the mat")
        for _, r in ipairs(rs) do
            local hit = math.abs(d._pos.x - r.x) < (half + r.hw) - 1e-3 and math.abs(d._pos.z - r.z) < (half + r.hh) - 1e-3
            ok(not hit, "die covers '" .. r.label .. "'")
        end
    end
end

TESTS.layout_controls_fit_without_overlap = function()
    fresh()
    check_layout()
end

TESTS.layout_full_mat_fits_without_overlap = function()
    fresh()
    -- 7 colors x 9 pairs fills every row
    for _, c in ipairs({ "Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Cyan" }) do
        spawn(c, 10); spawn(c, 4)
    end
    eq(#MOCK.dice(), 96, "dice limit respected")
    MOCK.forced_values = {}
    MOCK.click("btn_roll_pairs"); MOCK.run()
    check_layout()
end

--------------------------------------------------------------------------------
-- The core requirement: in 2s, by color
--------------------------------------------------------------------------------
TESTS.spawn_lines_dice_up_by_color_unrolled = function()
    fresh()
    spawn("Blue"); spawn("Red"); spawn("Red"); spawn("Blue", 1)
    local rows = rows_of_dice()
    eq(#rows, 2, "one row per color")
    eq(#rows[1], 4); eq(#rows[2], 3)
    for _, d in ipairs(rows[1]) do eq(tint_name(d), "Red", "Red row first (palette order)") end
    for _, d in ipairs(rows[2]) do eq(tint_name(d), "Blue") end
    eq(group_label(1).label, "?", "not rolled yet")
    ok(MOCK.button("7 dice"), "dice counter")
end

TESTS.roll_in_2s_by_color_never_mixes_colors = function()
    fresh()
    -- spawned interleaved: this is exactly what scrambled the pairs before
    spawn("Green"); spawn("Red"); spawn("Green"); spawn("Blue"); spawn("Red")
    MOCK.forced_values = { 4, 5, 6, 6, 1, 2, 3, 3, 2, 5 }
    local n0 = #MOCK.chat
    MOCK.click("btn_roll_pairs", "Red")
    MOCK.run()
    local rows = rows_of_dice()
    eq(#rows, 3)
    local expect = { "Red", "Blue", "Green" }
    for r, row in ipairs(rows) do
        for _, d in ipairs(row) do eq(tint_name(d), expect[r], "row " .. r .. " color") end
        local size = row[1].getBoundsNormalized().size.x
        if #row >= 2 then ok(row[2]._pos.x - row[1]._pos.x < size * 1.2, "pair dice side by side") end
        if #row >= 3 then ok(row[3]._pos.x - row[2]._pos.x > size * 1.5, "gap between pairs") end
    end
    -- every die physically shows the rolled face
    local faces = {}
    for _, row in ipairs(rows) do for _, d in ipairs(row) do faces[#faces + 1] = d.getValue() end end
    eq(table.concat(faces, ","), "4,5,6,6,1,2,3,3,2,5", "faces in layout order")
    eq(group_label(1).label, "9"); eq(group_label(2).label, "12")
    eq(group_label(3).label, "3"); eq(group_label(4).label, "6"); eq(group_label(5).label, "7")
    local chat = MOCK.chat_since(n0)
    ok(chat[1]:find("Tester%-Red: IN 2s BY COLOR %- SUM"), chat[1])
    ok(chat[2]:find("RED%[%-%]: 9  |  12"), chat[2])
    ok(chat[3]:find("BLUE%[%-%]: 3"), chat[3])
    ok(chat[4]:find("GREEN%[%-%]: 6  |  7"), chat[4])
end

TESTS.positions_are_stable_between_rolls = function()
    fresh()
    spawn("Red", 4); spawn("Blue", 2)
    MOCK.click("btn_roll_pairs"); MOCK.run()
    local before = {}
    for _, d in ipairs(MOCK.dice()) do before[d._guid] = { x = d._pos.x, z = d._pos.z } end
    MOCK.click("btn_roll_pairs"); MOCK.run()
    for _, d in ipairs(MOCK.dice()) do
        near(d._pos.x, before[d._guid].x, 1e-6, "die stays in its spot")
        near(d._pos.z, before[d._guid].z, 1e-6)
    end
end

TESTS.odd_die_and_foreign_dice = function()
    fresh()
    spawn("Red", 1)
    -- a teal die from another mod dropped on the mat, one off the mat, one in a hand
    local teal = MOCK.drop_die(self.positionToWorld({ 0, 0.6, 0 }), { 0.13, 0.69, 0.66 }, 3)
    local away = MOCK.drop_die({ x = 100, y = 1, z = 100 }, { 1, 1, 1 }, 3)
    local held_pos = self.positionToWorld({ 0.1, 0.6, 0.1 })
    local held = MOCK.drop_die(held_pos, { 1, 1, 1 }, 3)
    held.held_by_color = "Blue"
    MOCK.forced_values = { 5, 2 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(away._pos.x, 100, "dice off the mat are left alone")
    near(held._pos.x, held_pos.x, 1e-6, "held dice are left alone")
    away.destruct(); held.destruct()   -- leave only the mat's dice for the row check
    local rows = rows_of_dice()
    eq(#rows, 2, "red row + teal row")
    eq(tint_name(rows[1][1]), "Red"); eq(rows[2][1], teal, "unknown tints get their own row after the palette")
    eq(group_label(1).label, "5"); eq(group_label(2).label, "2")
    ok(row_label(2).label:find("^#"), "unknown color row labelled with its hex: " .. row_label(2).label)
end

TESTS.sorted_mode_rows_by_value = function()
    fresh()
    spawn("Red", 4); spawn("Blue", 2)
    MOCK.forced_values = { 6, 1, 6, 3, 6, 1 }
    local n0 = #MOCK.chat
    MOCK.click("btn_roll_sorted"); MOCK.run()
    local rows = rows_of_dice()
    eq(#rows, 3, "rows for 6s, 3s, 1s")
    eq(#rows[1], 3); eq(rows[1][1].getValue(), 6); eq(rows[3][1].getValue(), 1)
    eq(row_label(1).label, "6s: 3")
    eq(group_label(1).width, 0, "no pair labels in sorted mode")
    ok(MOCK.chat_since(n0)[2]:find("6s: 3  |  3s: 1  |  1s: 2"))
end

--------------------------------------------------------------------------------
-- BattleTech flow
--------------------------------------------------------------------------------
TESTS.tohit_delete_misses_then_location = function()
    fresh()
    spawn("Red"); spawn("Red"); spawn("Blue"); spawn("Green")
    MOCK.click("btn_read_as")                         -- TO-HIT
    eq(self._inputs[1].label, "TN", "number box becomes TN")
    input_number(self, "White", "8", false)
    MOCK.forced_values = { 4, 4, 1, 2, 6, 5, 3, 3 }    -- Red 8 HIT, Red 3 miss, Blue 11 HIT, Green 6 miss
    local n0 = #MOCK.chat
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(group_label(1).label, "8 HIT"); eq(group_label(2).label, "3 miss")
    eq(group_label(3).label, "11 HIT"); eq(group_label(4).label, "6 miss")
    local chat = MOCK.chat_since(n0)
    ok(chat[1]:find("TO%-HIT %(TN 8%)"), chat[1])
    ok(chat[#chat]:find("Hits: 2 / 4"), chat[#chat])

    MOCK.click("btn_del_misses"); MOCK.run()
    eq(#MOCK.dice(), 4, "missed pairs removed")
    local rows = rows_of_dice()
    eq(#rows, 2, "Green row gone"); eq(tint_name(rows[1][1]), "Red"); eq(tint_name(rows[2][1]), "Blue")

    MOCK.click("btn_read_as")                         -- LOC FRONT
    eq(self._inputs[1].label, "-", "number box unused for locations")
    MOCK.forced_values = { 3, 4, 6, 6 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(group_label(1).label, "7 CT"); eq(group_label(2).label, "12 HEAD")
    eq(group_label(2).color[1], 0.55, "head hit is highlighted")
end

TESTS.read_as_relabels_without_rolling = function()
    fresh()
    spawn("Red")
    MOCK.forced_values = { 1, 1 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(group_label(1).label, "2")
    MOCK.click("btn_read_as"); MOCK.click("btn_read_as")   -- LOC FRONT
    eq(group_label(1).label, "2 CT TAC")
    MOCK.click("btn_read_as", "White", true)              -- right-click back to TO-HIT
    eq(state().mode, 2)
    for _ = 1, 6 do MOCK.click("btn_read_as") end          -- on to CRIT CHECK
    eq(state().mode, 8); eq(group_label(1).label, "2 none")
    MOCK.click("btn_read_as")
    eq(state().mode, 1, "wraps around to SUM")
end

TESTS.cluster_size_box = function()
    fresh()
    spawn("Purple")
    for _ = 1, 6 do MOCK.click("btn_read_as") end          -- CLUSTER
    eq(self._inputs[1].label, "SIZE")
    input_number(self, "White", "15", false)
    MOCK.forced_values = { 4, 5 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(group_label(1).label, "9: 12/15")
    for _ = 1, 5 do MOCK.click("btn_read_as", "White", true) end   -- back to TO-HIT
    eq(state().mode, 2)
    eq(self._inputs[1].value, "", "TN and size are kept separately")
    eq(state().size, "15")
end

TESTS.click_pair_rerolls_only_that_pair = function()
    fresh()
    spawn("Red", 4)
    MOCK.forced_values = { 1, 1, 2, 2 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    local rows = rows_of_dice()
    local x1, x3 = rows[1][1]._pos.x, rows[1][3]._pos.x
    MOCK.forced_values = { 6, 5 }
    local n0 = #MOCK.chat
    MOCK.click("group_click_2"); MOCK.run()
    eq(group_label(1).label, "2", "first pair untouched")
    eq(group_label(2).label, "11", "second pair re-rolled")
    eq(rows[1][3].getValue(), 6); eq(rows[1][4].getValue(), 5)
    near(rows[1][3]._pos.x, x3, 1e-6, "re-rolled dice stay in place")
    near(rows[1][1]._pos.x, x1, 1e-6)
    ok(MOCK.chat_since(n0)[1]:find("RED%[%-%] re%-roll by Tester%-White: 6%+5 = 11"), MOCK.chat_since(n0)[1])
end

TESTS.clear_needs_right_click = function()
    fresh()
    spawn("Red", 6)
    local n0 = #MOCK.chat
    MOCK.click("btn_clear", "Blue", false)
    eq(#MOCK.dice(), 6, "left-click does not clear")
    ok(MOCK.chat[n0 + 1].msg:find("RIGHT%-click"))
    MOCK.click("btn_clear", "Blue", true)
    MOCK.run()
    eq(#MOCK.dice(), 0)
    eq(group_label(1).width, 0, "labels hidden")
end

TESTS.roll_with_empty_mat_warns = function()
    fresh()
    local n0 = #MOCK.chat
    MOCK.click("btn_roll_pairs", "Green")
    eq(MOCK.chat[n0 + 1].to, "Green")
    ok(MOCK.chat[n0 + 1].msg:find("no dice on the mat"))
end

TESTS.delete_misses_needs_tohit_and_tn = function()
    fresh()
    spawn("Red")
    MOCK.click("btn_roll_pairs"); MOCK.run()
    local n0 = #MOCK.chat
    MOCK.click("btn_del_misses", "Red")
    ok(MOCK.chat[n0 + 1].msg:find("TO%-HIT"))
    eq(#MOCK.dice(), 2)
end

--------------------------------------------------------------------------------
-- Persistence / robustness
--------------------------------------------------------------------------------
TESTS.save_load_roundtrip = function()
    fresh()
    MOCK.click("btn_read_as")
    input_number(self, "White", " 7 ", false)
    spawn("Red"); spawn("Blue")
    MOCK.click("pick_color_4")
    MOCK.forced_values = { 3, 4, 2, 2 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    onLoad(onSave())
    MOCK.run()
    local st = state()
    eq(st.color, 4); eq(st.mode, 2); eq(st.tn, "7")
    eq(self._inputs[1].value, "7", "TN box restored")
    eq(group_label(1).label, "7 HIT", "labels re-attached to the dice after load")
    eq(group_label(2).label, "4 miss")
    onLoad("garbage")
    MOCK.run()
    eq(state().mode, 1, "bad save data falls back to defaults")
end

TESTS.mirror_flips_layout_and_dice = function()
    fresh()
    spawn("Red")
    MOCK.click("btn_roll_pairs"); MOCK.run()
    local before = rows_of_dice()[1][1]._pos.x
    local bx = self.positionToWorld(MOCK.button("ROLL IN 2s BY COLOR").position).x
    MOCK.click("btn_mirror")
    ok(state().mirror)
    near(self.positionToWorld(MOCK.button("ROLL IN 2s BY COLOR").position).x, -bx, 1e-6, "controls mirrored")
    ok(before < 0 and rows_of_dice()[1][2]._pos.x > 0, "dice moved with the layout")
    check_layout()
end

TESTS.rotated_and_scaled_mat = function()
    self._rot = { x = 0, y = 90, z = 0 }
    self._scale = { x = 35, y = 0.3, z = 22 }
    fresh()
    spawn("Red", 4); spawn("Blue", 2)
    MOCK.click("btn_roll_pairs"); MOCK.run()
    for _, d in ipairs(MOCK.dice()) do
        local l = self.positionToLocal(d._pos)
        ok(math.abs(l.x) <= 0.5 and math.abs(l.z) <= 0.5, "die on the rotated mat")
        near((d._rot.y - 90) % 90, 0, 1e-6, "die squared to the mat")
    end
    local k = math.min(35 / 30, 22 / 19)
    near(MOCK.dice()[1].getBoundsNormalized().size.x, k, 1e-6, "dice scale with the mat")
end

TESTS.dice_limit = function()
    fresh()
    local n0 = #MOCK.chat
    for _ = 1, 10 do spawn("Red", 10) end
    eq(#MOCK.dice(), 96)
    ok(MOCK.chat[#MOCK.chat].msg:find("dice limit"))
end

TESTS.api = function()
    fresh()
    spawn("Red")
    MOCK.forced_values = { 2, 3 }
    ok(api_roll({ color = "Blue" })); MOCK.run()
    local res = api_get_results()
    eq(#res, 1); eq(res[1].color, "Red"); eq(res[1].label, "5")
end

--------------------------------------------------------------------------------
-- Regressions from the code review
--------------------------------------------------------------------------------
TESTS.review_ten_colors_all_fit_on_mat = function()
    fresh()
    for _, c in ipairs(PALETTE_NAMES) do spawn(c, 2) end
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(#rows_of_dice(), 10, "one row per color, all 10 colors")
    ok(MOCK.button("20 dice"), "every die still counted")
    check_layout()
    local chat = table.concat(MOCK.chat_since(0), "\n")
    ok(chat:find("BROWN"), "last color still rolled")
    -- a single colour with a long wrap also fits
    MOCK.click("btn_clear", "White", true); MOCK.run()
    spawn("Red", 10); spawn("Red", 10); spawn("Red", 10); spawn("Red", 10); spawn("Red", 10)
    spawn("Red", 10); spawn("Red", 10); spawn("Red", 10); spawn("Red", 10); spawn("Blue", 6)
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(#MOCK.dice(), 96)
    check_layout()
end

TESTS.review_labels_follow_dice_changed_by_hand = function()
    fresh()
    spawn("Red")
    MOCK.click("btn_read_as")
    input_number(self, "White", "8", false)
    MOCK.forced_values = { 1, 2 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(group_label(1).label, "3 miss")
    -- a player hovers the dice and types 6 on each
    for _, d in ipairs(MOCK.dice()) do d.setRotation({ 90, 0, 0 }) end
    MOCK.run(3)
    eq(group_label(1).label, "12 HIT", "label updated from the dice as they lie")
    eq(api_get_results()[1].values[1], 6)
    MOCK.click("btn_del_misses"); MOCK.run()
    eq(#MOCK.dice(), 2, "a pair that now hits is not deleted")
end

TESTS.review_delete_misses_spares_held_and_moved_dice = function()
    fresh()
    spawn("Red"); spawn("Blue")
    MOCK.click("btn_read_as")
    input_number(self, "White", "8", false)
    MOCK.forced_values = { 1, 1, 1, 1 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    local rows = rows_of_dice()
    rows[1][1].held_by_color = "Red"                     -- picked up
    rows[2][1].setPosition({ x = 100, y = 1, z = 100 })  -- moved off the mat
    -- clicking the result of a pair that left the mat is refused, not re-rolled
    local n0 = #MOCK.chat
    local before = rows[2][1]._rot.x
    MOCK.click("group_click_2", "Blue")
    ok(MOCK.chat[n0 + 1].msg:find("no longer on the mat"), MOCK.chat[n0 + 1].msg)
    eq(rows[2][1]._rot.x, before, "moved die not turned")
    MOCK.click("btn_del_misses"); MOCK.run()
    ok(not rows[1][1].isDestroyed(), "held die survives")
    ok(not rows[2][1].isDestroyed(), "moved die survives")
end

TESTS.review_roll_while_spawning_excludes_new_dice = function()
    fresh()
    spawn("Red")
    MOCK.click("pick_color_2")
    MOCK.click("spawn_2")                 -- callbacks not run yet
    MOCK.forced_values = { 3, 4 }
    local n0 = #MOCK.chat
    MOCK.click("btn_roll_pairs")          -- before the blue dice finish spawning
    MOCK.run()
    local chat = table.concat(MOCK.chat_since(n0), "\n")
    ok(not chat:find("WHITE"), "spawning dice are not rolled as white: " .. chat)
    eq(group_label(1).label, "7")
    eq(group_label(2).label, "?", "the blue pair arrives unrolled")
    for _, d in ipairs(rows_of_dice()[2]) do eq(tint_name(d), "Blue") end
end

TESTS.review_quick_spawns_do_not_overlap = function()
    fresh()
    MOCK.click("pick_color_1")
    MOCK.click("spawn_2"); MOCK.click("spawn_2"); MOCK.click("spawn_10")
    local seen = {}
    for _, d in ipairs(MOCK.dice()) do
        local key = string.format("%.2f,%.2f,%.2f", d._pos.x, d._pos.y, d._pos.z)
        ok(not seen[key], "two dice spawned at " .. key)
        seen[key] = true
    end
    MOCK.run()
    eq(#MOCK.dice(), 14)
end

TESTS.review_similar_foreign_tints_share_a_row = function()
    fresh()
    MOCK.drop_die(self.positionToWorld({ -0.1, 0.6, 0 }), { 0.627, 0.1249, 0.941 }, 3)
    MOCK.drop_die(self.positionToWorld({ 0.1, 0.6, 0 }), { 0.627, 0.1251, 0.941 }, 3)
    MOCK.click("btn_roll_pairs"); MOCK.run()
    eq(#rows_of_dice(), 1, "near-identical tints form one pair")
    ok(group_label(1).label:match("^%d+$"), "paired: " .. group_label(1).label)
end

TESTS.review_sorted_layout_guards = function()
    fresh()
    spawn("Red", 4)
    MOCK.click("btn_read_as")
    input_number(self, "White", "8", false)
    MOCK.click("btn_roll_sorted"); MOCK.run()
    local n0 = #MOCK.chat
    MOCK.click("btn_del_misses")
    ok(MOCK.chat[n0 + 1].msg:find("works on pairs"), "refused after SORTED")
    eq(#MOCK.dice(), 4)
    onLoad(onSave()); MOCK.run()
    eq(state().layout, "sorted", "layout survives a reload")
    eq(group_label(1).width, 0, "still sorted, not re-paired")
end

TESTS.review_typing_does_not_relabel_every_keystroke = function()
    fresh()
    spawn("Red")
    MOCK.forced_values = { 4, 4 }
    MOCK.click("btn_roll_pairs"); MOCK.run()
    MOCK.click("btn_read_as")
    input_number(self, "White", "1", true)     -- still typing "10"
    eq(group_label(1).label, "8", "no relabel while editing")
    input_number(self, "White", "10", false)
    eq(group_label(1).label, "8 miss")
end

TESTS.review_mat_locks_itself_after_first_spawn = function()
    self._locked = false
    onLoad("")
    MOCK.run(5)
    ok(self._locked, "locked once it settled")
    ok(state().placed)
    self._locked = false                       -- player unlocks to move it
    onLoad(onSave()); MOCK.run(5)
    ok(not self._locked, "only locks itself once")
end

TESTS.review_warnings_reach_empty_seats = function()
    fresh()
    Player = setmetatable({}, { __index = function() return { seated = false } end })
    local n0 = #MOCK.chat
    api_roll({})
    eq(MOCK.chat[n0 + 1].to, "all", "API warning goes to everyone when White is empty")
end
