-- Test scenarios for the BattleTech Dice Mat. Each TESTS entry runs in a fresh
-- Lua runtime with mock_tts.lua + the mat script loaded (see run_tests.py).

TESTS = {}

local function eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected [" .. tostring(b) .. "] got [" .. tostring(a) .. "]", 2) end
end
local function ok(c, msg) if not c then error(msg or "assertion failed", 2) end end
local function near(a, b, eps, msg)
    if math.abs(a - b) > (eps or 1e-6) then error((msg or "") .. " expected ~" .. b .. " got " .. a, 2) end
end

local function state() return JSON.decode(onSave()) end

local function set_input(fn_prefix, i, value)
    _G[fn_prefix .. i](self, "White", value, false)
end

local function dice_of_slot(i)
    local st = state()
    local out = {}
    for d = 1, 2 do
        local g = st.slots[i].dice[d]
        out[d] = (g ~= "" and getObjectFromGUID(g)) or nil
    end
    return out
end

local function button_by_fn(fn)
    for _, b in ipairs(self._buttons) do if b.click_function == fn then return b end end
end

-- World-space centre of a button (uses the same transform as the mat).
local function button_world(b) return self.positionToWorld(b.position) end

local SLOT_NAMES = { "Red", "Blue", "Green", "Yellow", "Orange", "Purple", "Cyan", "Pink", "White", "Brown", "Lime", "Grey" }

local function find_button(tooltip_exact)
    for _, b in ipairs(self._buttons) do if b.tooltip == tooltip_exact then return b end end
end
local function pad(i) return find_button(SLOT_NAMES[i] .. " pair lands here") end
local function result(i) return find_button("Last result for the " .. SLOT_NAMES[i] .. " pair") end

local function fresh()
    math.randomseed(1234)
    onLoad("")
end

--------------------------------------------------------------------------------
-- Rules tables
--------------------------------------------------------------------------------
TESTS.cluster_table_shape = function()
    for size = 2, 20 do
        local prev = 0
        for roll = 2, 12 do
            local h = cluster_hits(size, roll)
            ok(h >= 1 and h <= size, "cluster " .. size .. "/" .. roll .. " out of range: " .. h)
            ok(h >= prev, "cluster column " .. size .. " not monotonic at roll " .. roll)
            prev = h
        end
        eq(cluster_hits(size, 12), size, "roll 12 must hit fully for size " .. size)
        eq(cluster_hits(size, 11), size, "roll 11 must hit fully for size " .. size)
    end
end

TESTS.cluster_table_known_values = function()
    -- Published spot checks (row 7 across 2/4/5/6/10/15/20).
    local row7 = { [2] = 1, [4] = 3, [5] = 3, [6] = 4, [10] = 6, [15] = 9, [20] = 12 }
    for size, hits in pairs(row7) do eq(cluster_hits(size, 7), hits, "row 7 size " .. size) end
    eq(cluster_hits(20, 9), 16, "LRM-20 on a 9")
    eq(cluster_hits(20, 2), 6, "LRM-20 on a 2")
    eq(cluster_hits(10, 2), 3, "LRM-10 on a 2")
    eq(cluster_hits(10, 9), 8, "LRM-10 on a 9")
    eq(cluster_hits(15, 4), 6, "LRM-15 on a 4")
    eq(cluster_hits(6, 2), 2, "SRM-6 on a 2")
    eq(cluster_hits(2, 7), 1, "SRM-2 on a 7")
    eq(cluster_hits(2, 8), 2, "SRM-2 on an 8")
    eq(cluster_hits(4, 3), 2, "SRM-4 on a 3")
    eq(cluster_hits(5, 1), 1, "rolls below 2 clamp to 2")
    eq(cluster_hits(5, 15), 5, "rolls above 12 clamp to 12")
    eq(cluster_hits(1, 7), 1, "single shot")
    local h, approx = cluster_hits(30, 12)
    eq(h, 30, "MRM-30 on a 12"); ok(approx, "size > 20 flagged approx")
end

TESTS.mech_location_table = function()
    local front = { "CT", "RA", "RA", "RL", "RT", "CT", "LT", "LL", "LA", "LA", "HD" }
    local left  = { "LT", "LL", "LA", "LA", "LL", "LT", "CT", "RT", "RA", "RL", "HD" }
    local right = { "RT", "RL", "RA", "RA", "RL", "RT", "CT", "LT", "LA", "LL", "HD" }
    for t = 2, 12 do
        eq(mech_location("FRONT", t), front[t - 1], "front " .. t)
        eq(mech_location("REAR", t), front[t - 1], "rear " .. t)
        eq(mech_location("LEFT", t), left[t - 1], "left " .. t)
        eq(mech_location("RIGHT", t), right[t - 1], "right " .. t)
    end
end

TESTS.crit_tables = function()
    for t = 2, 7 do eq((crit_check(t)), 0, "crit " .. t) end
    eq((crit_check(8)), 1); eq((crit_check(9)), 1)
    eq((crit_check(10)), 2); eq((crit_check(11)), 2)
    eq((crit_check(12)), 3)
    eq(crit_slot(1, 4), 4); eq(crit_slot(3, 6), 6); eq(crit_slot(4, 1), 7); eq(crit_slot(6, 6), 12)
end

--------------------------------------------------------------------------------
-- UI build / layout
--------------------------------------------------------------------------------
TESTS.ui_builds_and_handlers_exist = function()
    fresh()
    eq(#self._buttons, 80, "full button set (32 controls/labels + 4 x 12 slot buttons)")
    eq(#self._inputs, 36, "3 inputs x 12 slots")
    for _, b in ipairs(self._buttons) do
        ok(type(_G[b.click_function]) == "function", "missing click function " .. tostring(b.click_function))
        ok(b.function_owner == self, "function_owner must be self")
        ok(b.font_size <= 1000, "font_size capped at 1000 (" .. b.font_size .. ")")
        ok(b.width == 0 or b.width >= 60, "button width below TTS minimum")
    end
    for _, inp in ipairs(self._inputs) do
        ok(type(_G[inp.input_function]) == "function", "missing input function " .. tostring(inp.input_function))
    end
end

-- Axis-aligned rectangles in world space for everything drawn on the mat.
local function rects()
    local s = self.getScale()
    local out = {}
    local function add(kind, p, w, h)
        local c = self.positionToWorld(p.position)
        out[#out + 1] = { kind = kind, label = p.label or p.tooltip or "", x = c.x, z = c.z,
            hw = w * p.scale[1] * s.x / 2, hh = h * p.scale[3] * s.z / 2 }
    end
    for _, b in ipairs(self._buttons) do
        if b.width > 0 then
            add("button", b, b.width / 500, b.height / 500)
        else
            -- label: approximate the text extent (0.55 em per char, 1 em high per line)
            local lines, longest = 0, 0
            for line in (b.label .. "\n"):gmatch("(.-)\n") do
                lines = lines + 1
                if #line > longest then longest = #line end
            end
            local em = b.font_size / 500
            add("label", b, longest * em * 0.55, lines * em)
        end
    end
    for _, i in ipairs(self._inputs) do add("input", i, i.width / 500, i.height / 500) end
    return out
end

TESTS.layout_fits_on_mat = function()
    fresh()
    local b = self.getBoundsNormalized()
    for _, r in ipairs(rects()) do
        ok(math.abs(r.x) + r.hw <= b.size.x / 2 + 1e-6, "element off the mat in X: " .. r.label)
        ok(math.abs(r.z) + r.hh <= b.size.z / 2 + 1e-6, "element off the mat in Z: " .. r.label)
    end
end

TESTS.layout_no_overlaps = function()
    fresh()
    local rs = rects()
    for a = 1, #rs do
        for c = a + 1, #rs do
            local A, B = rs[a], rs[c]
            -- dice pads intentionally sit under nothing else; everything must be disjoint
            local overlap = math.abs(A.x - B.x) < (A.hw + B.hw) - 1e-3 and math.abs(A.z - B.z) < (A.hh + B.hh) - 1e-3
            ok(not overlap, "overlap: '" .. A.label .. "' and '" .. B.label .. "'")
        end
    end
end

TESTS.slot_order_reads_left_to_right_top_to_bottom = function()
    fresh()
    -- White sits at -Z looking +Z: left = -X, top (far) = +Z.
    local p1, p2, p6, p7 = button_world(pad(1)), button_world(pad(2)), button_world(pad(6)), button_world(pad(7))
    ok(p1.z > p2.z and p2.z > p6.z, "slots 1..6 run top to bottom")
    ok(p1.x < p7.x, "column 1 (slots 1-6) is left of column 2 (7-12)")
    near(p1.z, p7.z, 1e-6, "slot 1 and 7 share a row")
    local title = MOCK.button("BATTLETECH  DICE  MAT")
    ok(button_world(title).z > p1.z, "title is above the slots")
end

--------------------------------------------------------------------------------
-- Roll pipeline
--------------------------------------------------------------------------------
local function check_parked(i, ndice, mirrored)
    local dice = dice_of_slot(i)
    local p = button_world(pad(i))
    local xs = {}
    for d = 1, ndice do
        local die = dice[d]
        ok(die, "slot " .. i .. " die " .. d .. " exists")
        ok(die._locked, "parked die is locked")
        near(die._pos.z, p.z, 1e-6, "die sits in its slot row (slot " .. i .. ")")
        ok(math.abs(die._pos.x - p.x) <= 0.8, "die sits on its pad (slot " .. i .. ")")
        xs[d] = die._pos.x
    end
    if ndice == 2 then
        if mirrored then
            ok(xs[1] > xs[2], "mirrored: die A follows the mirrored layout in slot " .. i)
        else
            ok(xs[1] < xs[2], "die A is left of die B in slot " .. i)
        end
        ok(dice[1]._pos.y > self._pos.y, "die above the mat")
    else
        ok(dice[2] == nil, "1-die mode removes die B")
        near(dice[1]._pos.x, p.x, 1e-6, "single die centred on the pad")
    end
end

TESTS.tohit_rolls_ordered_color_locked_pairs = function()
    fresh()
    MOCK.click("slot_select_5")                     -- 5 pairs
    for i = 1, 5 do set_input("slot_tn_", i, "7") end
    set_input("slot_name_", 1, "Medium Laser")
    MOCK.forced_values = { 6, 6, 1, 1, 3, 4, 2, 5, 5, 6 }  -- totals: 12, 2, 7, 7, 11
    local n0 = #MOCK.chat
    MOCK.click("btn_tohit", "Red")
    ok(MOCK.run(), "roll finished")
    local dice = MOCK.dice()
    eq(#dice, 10, "two dice per pair")
    for i = 1, 5 do
        check_parked(i, 2)
        local d = dice_of_slot(i)
        ok(d[1]._name:find("Pair " .. i .. " %(" .. SLOT_NAMES[i] .. "%)"), "die named for its slot")
        ok(d[1].hasTag("BTDiceMat"), "die tagged")
    end
    local st = state()
    eq(st.slots[1].hit, "hit"); eq(st.slots[2].hit, "miss"); eq(st.slots[3].hit, "hit")
    eq(st.slots[4].hit, "hit"); eq(st.slots[5].hit, "hit")
    ok(st.hit_known, "hit_known after a full to-hit")
    eq(result(1).label, "12 vs 7\nHIT"); eq(result(2).label, "2 vs 7\nMISS")
    local chat = MOCK.chat_since(n0)
    ok(chat[1]:find("Tester%-Red: TO%-HIT %- 5 pairs"), "header: " .. chat[1])
    ok(chat[2]:find("#1 RED") and chat[2]:find("Medium Laser: 6 %+ 6 = 12 vs TN 7 %-> HIT"), chat[2])
    ok(chat[3]:find("#2 BLUE") and chat[3]:find("MISS"), chat[3])
    ok(chat[6]:find("#5 ORANGE"), "chat lines in slot order")
    ok(chat[7]:find("Hits: 4 / 5"), chat[7])
end

TESTS.location_only_rolls_hits_and_keeps_colors = function()
    fresh()
    MOCK.click("slot_select_3")
    for i = 1, 3 do set_input("slot_tn_", i, "8") end
    MOCK.forced_values = { 5, 5, 1, 2, 6, 6 }       -- hit, miss, hit
    MOCK.click("btn_tohit"); MOCK.run()
    local miss_die = dice_of_slot(2)[1]
    local rolls_before = miss_die._rolls
    MOCK.forced_values = { 3, 4, 1, 1 }             -- slot1: 7 -> CT, slot3: 2 -> CT + TAC
    local n0 = #MOCK.chat
    MOCK.click("btn_location"); MOCK.run()
    eq(miss_die._rolls, rolls_before, "missed pair not re-rolled")
    eq(result(1).label, "7: CT\nCenter Torso")
    eq(result(3).label, "2: CT\nTAC CHECK!")
    eq(result(2).label, "3 vs 8\nMISS", "missed slot keeps its to-hit result")
    local chat = MOCK.chat_since(n0)
    ok(chat[1]:find("LOCATION %(MECH, from FRONT%) %- 2 pairs"), chat[1])
    ok(chat[2]:find("#1 RED") and chat[3]:find("#3 GREEN"), "only hit slots reported, in order")
    check_parked(1, 2); check_parked(3, 2)
end

TESTS.location_facing_rear_and_side = function()
    fresh()
    MOCK.click("slot_select_1")
    MOCK.click("btn_facing")        -- LEFT
    MOCK.forced_values = { 4, 4 }   -- 8 from the left -> CT
    MOCK.click("btn_location"); MOCK.run()
    eq(result(1).label, "8: CT\nCenter Torso")
    MOCK.click("btn_facing"); MOCK.click("btn_facing")  -- RIGHT -> REAR
    MOCK.forced_values = { 3, 3 }   -- 6 from the rear -> RT (rear)
    MOCK.click("btn_location"); MOCK.run()
    eq(result(1).label, "6: RT(R)\nRight Torso")
    MOCK.click("btn_facing", "White", true)  -- right-click cycles back to RIGHT
    MOCK.forced_values = { 6, 6 }
    MOCK.click("btn_location"); MOCK.run()
    eq(result(1).label, "12: HD\nHEAD HIT!")
end

TESTS.punch_and_kick_use_one_die = function()
    fresh()
    MOCK.click("slot_select_2")
    MOCK.click("btn_generic"); MOCK.run()
    eq(#MOCK.dice(), 4)
    MOCK.click("btn_loc_table")     -- PUNCH
    MOCK.forced_values = { 6, 3 }
    MOCK.click("btn_location"); MOCK.run()
    eq(#MOCK.dice(), 2, "die B removed in 1D6 mode")
    check_parked(1, 1); check_parked(2, 1)
    eq(result(1).label, "PUNCH 6\nHEAD")
    eq(result(2).label, "PUNCH 3\nCENTER TORSO")
    MOCK.click("btn_loc_table")     -- KICK
    MOCK.forced_values = { 1, 4 }
    MOCK.click("btn_location"); MOCK.run()
    eq(result(1).label, "KICK 1\nRIGHT LEG"); eq(result(2).label, "KICK 4\nLEFT LEG")
    MOCK.click("btn_generic"); MOCK.run()
    eq(#MOCK.dice(), 4, "die B respawned for 2D6 rolls")
    check_parked(1, 2)
end

TESTS.cluster_uses_size_and_modifier = function()
    fresh()
    MOCK.click("slot_select_3")
    set_input("slot_cluster_", 1, "20")
    set_input("slot_cluster_", 3, "6")
    MOCK.forced_values = { 4, 3, 2, 3 }  -- slot1 7 -> 12/20 ; slot3 5 -> 3/6
    MOCK.click("btn_cluster"); MOCK.run()
    eq(result(1).label, "7\n12 / 20 HIT")
    eq(result(3).label, "5\n3 / 6 HIT")
    eq(result(2).label, "", "slot without cluster size not rolled")
    MOCK.click("btn_clmod_inc"); MOCK.click("btn_clmod_inc")   -- Artemis +2
    MOCK.forced_values = { 4, 3, 2, 3 }
    MOCK.click("btn_cluster"); MOCK.run()
    eq(result(1).label, "7+2=9\n16 / 20 HIT")
    for _ = 1, 10 do MOCK.click("btn_clmod_dec") end
    eq(state().cluster_mod, -4, "modifier clamps at -4 (AMS)")
end

TESTS.cluster_without_sizes_warns = function()
    fresh()
    local n0 = #MOCK.chat
    MOCK.click("btn_cluster", "Blue")
    MOCK.run()
    eq(#MOCK.dice(), 0, "nothing rolled")
    ok(MOCK.chat[n0 + 1].to == "Blue" and MOCK.chat[n0 + 1].msg:find("CLUSTER size"), "warning to the clicker")
end

TESTS.crit_and_slot_modes = function()
    fresh()
    MOCK.click("slot_select_2")
    MOCK.forced_values = { 4, 4, 6, 6 }
    MOCK.click("btn_crit"); MOCK.run()
    eq(result(1).label, "8\n1 CRIT"); eq(result(2).label, "12\n3 / BLOWN OFF")
    MOCK.forced_values = { 2, 5, 5, 3 }
    MOCK.click("btn_critslot"); MOCK.run()
    eq(result(1).label, "SLOT 5\n(6-slot loc: 5)"); eq(result(2).label, "SLOT 9\n(6-slot loc: 3)")
end

TESTS.generic_pass_fail = function()
    fresh()
    MOCK.click("slot_select_2")
    set_input("slot_tn_", 1, " 9 ")
    MOCK.forced_values = { 4, 5, 3, 3 }
    MOCK.click("btn_generic"); MOCK.run()
    eq(result(1).label, "9 vs 9\nPASS"); eq(result(2).label, "6\n2D6")
end

TESTS.impossible_tn = function()
    fresh()
    MOCK.click("slot_select_1")
    set_input("slot_tn_", 1, "13")
    MOCK.forced_values = { 6, 6 }
    MOCK.click("btn_tohit"); MOCK.run()
    eq(result(1).label, "12 vs 13\nIMPOSSIBLE"); eq(state().slots[1].hit, "miss")
end

TESTS.reroll_single_pair = function()
    fresh()
    MOCK.click("slot_select_3")
    for i = 1, 3 do set_input("slot_tn_", i, "8") end
    MOCK.forced_values = { 1, 1, 1, 1, 6, 6 }
    MOCK.click("btn_tohit"); MOCK.run()
    local other = dice_of_slot(1)[1]
    local r0 = other._rolls
    MOCK.forced_values = { 5, 5 }
    MOCK.click("slot_reroll_2"); MOCK.run()
    eq(other._rolls, r0, "other pairs untouched")
    eq(result(2).label, "10 vs 8\nHIT", "re-roll keeps the slot's roll type")
    eq(state().slots[2].hit, "hit")
    check_parked(2, 2)
end

TESTS.busy_guard = function()
    fresh()
    MOCK.click("btn_tohit", "Green")
    local n0 = #MOCK.chat
    MOCK.click("btn_tohit", "Green")
    ok(MOCK.chat[n0 + 1].msg:find("still in progress"), "second click rejected while rolling")
    MOCK.run()
    eq(#MOCK.dice(), 8)
end

TESTS.pairs_decrease_removes_dice = function()
    fresh()
    MOCK.click("slot_select_6")
    MOCK.click("btn_generic"); MOCK.run()
    eq(#MOCK.dice(), 12)
    MOCK.click("btn_pairs_dec"); MOCK.click("btn_pairs_dec")
    eq(#MOCK.dice(), 8)
    eq(state().pairs, 4)
    for _ = 1, 20 do MOCK.click("btn_pairs_inc") end
    eq(state().pairs, 12, "clamped to 12")
    MOCK.click("btn_clear")
    eq(#MOCK.dice(), 0, "CLEAR removes all dice")
end

TESTS.save_load_roundtrip = function()
    fresh()
    MOCK.click("slot_select_3")
    set_input("slot_name_", 2, "LRM 15")
    set_input("slot_tn_", 2, "9")
    set_input("slot_cluster_", 2, "15")
    MOCK.click("btn_facing"); MOCK.click("btn_hits_only"); MOCK.click("btn_clmod_inc")
    MOCK.click("btn_tohit"); MOCK.run()
    local saved = onSave()
    local guid = dice_of_slot(2)[1]._guid
    -- Reload the script on the same object (as TTS does on game load).
    onLoad(saved)
    local st = state()
    eq(st.pairs, 3); eq(st.slots[2].name, "LRM 15"); eq(st.slots[2].tn, "9"); eq(st.slots[2].cluster, "15")
    eq(st.facing, 2); eq(st.hits_only, false); eq(st.cluster_mod, 1)
    eq(st.slots[2].dice[1], guid, "dice re-associated by GUID")
    local inp
    for _, x in ipairs(self._inputs) do if x.input_function == "slot_name_2" then inp = x end end
    eq(inp.value, "LRM 15", "inputs restored")
    -- Corrupt / foreign save data must not crash.
    onLoad("not json")
    eq(state().pairs, 4)
end

TESTS.lost_die_and_timeout = function()
    fresh()
    MOCK.click("slot_select_2")
    MOCK.click("btn_generic"); MOCK.run()
    local d = dice_of_slot(1)
    MOCK.never_settle[d[2]._guid] = true    -- this die never comes to rest
    local t0 = MOCK.now
    MOCK.click("btn_generic")
    -- a player deletes a die mid-roll
    Wait.time(function() dice_of_slot(2)[1].destruct() end, 0.3)
    MOCK.run()
    ok(MOCK.now - t0 >= 10, "finished via timeout")
    eq(result(2).label, "DIE LOST\nre-roll")
    ok(result(1).label:find("2D6"), "slot 1 still resolved")
    -- re-roll respawns the lost die
    MOCK.never_settle = {}
    MOCK.click("slot_reroll_2"); MOCK.run()
    check_parked(2, 2)
end

TESTS.mirror_flips_layout_and_dice = function()
    fresh()
    MOCK.click("slot_select_7")
    MOCK.click("btn_generic"); MOCK.run()
    local x1 = dice_of_slot(1)[1]._pos.x
    MOCK.click("btn_mirror")
    ok(state().mirror, "mirror saved")
    local p1, p7 = button_world(pad(1)), button_world(pad(7))
    ok(p1.x > p7.x, "column order flipped")
    check_parked(1, 2, true)
    ok(dice_of_slot(1)[1]._pos.x > 0 and x1 < 0, "dice moved with their slot")
end

TESTS.mat_rotation_and_scale_independent = function()
    -- Rotated, resized mat: dice still land on their pads.
    self._rot = { x = 0, y = 90, z = 0 }
    self._scale = { x = 35, y = 0.3, z = 22 }
    fresh()
    MOCK.click("slot_select_4")
    MOCK.click("btn_generic"); MOCK.run()
    for i = 1, 4 do
        local d = dice_of_slot(i)
        local p = button_world(pad(i))
        local mid = { x = (d[1]._pos.x + d[2]._pos.x) / 2, z = (d[1]._pos.z + d[2]._pos.z) / 2 }
        near(mid.x, p.x, 1e-6, "pair centred on pad x"); near(mid.z, p.z, 1e-6, "pair centred on pad z")
        -- die rotation is aligned with the mat yaw
        local rot = d[1]._rot
        near((rot.y - 90) % 90, 0, 1e-6, "die yaw aligned to mat")
    end
end

TESTS.dice_are_sized_and_face_up = function()
    fresh()
    MOCK.click("slot_select_1")
    MOCK.forced_values = { 6, 1 }
    MOCK.click("btn_generic"); MOCK.run()
    local d = dice_of_slot(1)
    local b = d[1].getBoundsNormalized()
    local k = math.min(25.5 / 30, 16.15 / 19)
    near(b.size.x, k, 1e-6, "die resized to DIE_SIZE * k")
    eq(d[1]._rot.x, 90, "die A turned to show 6 (x=90)")
    eq(d[2]._rot.x, -90, "die B turned to show 1 (x=-90)")
    near(d[1]._pos.y, self._pos.y + 0.25 / 2 + k / 2 + 0.02, 1e-6, "die rests on the mat surface")
end

TESTS.api_roll = function()
    fresh()
    ok(api_roll({ mode = "generic", color = "Blue" }), "api roll accepted")
    MOCK.run()
    eq(#api_get_results(), 4)
    eq(api_get_results()[1].mode, "generic")
    ok(not api_roll({ mode = "bogus" }), "unknown mode rejected")
end

TESTS.on_destroy_cleans_up = function()
    fresh()
    MOCK.click("btn_generic"); MOCK.run()
    eq(#MOCK.dice(), 8)
    onDestroy()
    eq(#MOCK.dice(), 0)
end
