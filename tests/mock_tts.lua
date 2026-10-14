-- Minimal Tabletop Simulator API mock for offline testing (Lua 5.2 ~ MoonSharp).
-- Simulates: objects with buttons/inputs, Die_6 physics (roll -> settle),
-- async spawnObject, Wait.time/frames/condition on a virtual clock, chat.

MOCK = {
    now = 0,
    tasks = {},
    objects = {},
    guid_seq = 0,
    chat = {},
    settle_time = 1.2,      -- seconds a rolled die takes to come to rest
    never_settle = {},      -- guid -> true: die keeps moving forever
    forced_values = nil,    -- optional queue of die values for the next rolls
}

local function V(t)
    if t == nil then return { x = 0, y = 0, z = 0 } end
    return { x = t.x or t[1] or 0, y = t.y or t[2] or 0, z = t.z or t[3] or 0 }
end
MOCK.V = V

local function schedule(at, fn)
    table.insert(MOCK.tasks, { at = at, fn = fn, seq = #MOCK.tasks })
end

-- Run the virtual clock until no tasks remain (or max_time passes).
function MOCK.run(max_time)
    max_time = max_time or 120
    local limit = MOCK.now + max_time
    while #MOCK.tasks > 0 do
        table.sort(MOCK.tasks, function(a, b)
            if a.at == b.at then return a.seq < b.seq end
            return a.at < b.at
        end)
        local t = table.remove(MOCK.tasks, 1)
        if t.at > limit then
            table.insert(MOCK.tasks, t)
            return false
        end
        if t.at > MOCK.now then MOCK.now = t.at end
        t.fn()
    end
    return true
end

-- Rotation of a vector around Y (Unity convention, degrees).
local function rot_y(v, deg)
    local r = math.rad(deg)
    local c, s = math.cos(r), math.sin(r)
    return { x = v.x * c + v.z * s, y = v.y, z = -v.x * s + v.z * c }
end
MOCK.rot_y = rot_y

local function new_object(kind, params)
    MOCK.guid_seq = MOCK.guid_seq + 1
    local o = {
        _guid = string.format("m%05d", MOCK.guid_seq),
        _kind = kind,
        _pos = V(params.position),
        _rot = V(params.rotation),
        _scale = V(params.scale or { 1, 1, 1 }),
        _base = V(params.base or { 1, 1, 1 }),
        _buttons = {},
        _inputs = {},
        _tags = {},
        _locked = false,
        _destroyed = false,
        _value = 1,
        _name = "",
        _tint = nil,
        resting = true,
        held_by_color = nil,
    }
    function o.getGUID() return o._guid end
    function o.getPosition() return V(o._pos) end
    function o.setPosition(p) o._pos = V(p); return true end
    function o.setPositionSmooth(p) o._pos = V(p); o._smooth = true; return true end
    function o.getRotation() return V(o._rot) end
    function o.setRotation(r) o._rot = V(r); return true end
    function o.setRotationSmooth(r) o._rot = V(r); return true end
    function o.getScale() return V(o._scale) end
    function o.setScale(s) o._scale = V(s); return true end
    function o.getBoundsNormalized()
        return {
            center = V(o._pos),
            size = { x = o._base.x * o._scale.x, y = o._base.y * o._scale.y, z = o._base.z * o._scale.z },
            offset = V(),
        }
    end
    -- TTS local X is mirrored relative to Unity (object yaw 180 = facing White).
    function o.positionToWorld(l)
        l = V(l)
        local u = { x = -l.x * o._scale.x, y = l.y * o._scale.y, z = l.z * o._scale.z }
        local w = rot_y(u, o._rot.y)
        return { x = w.x + o._pos.x, y = w.y + o._pos.y, z = w.z + o._pos.z }
    end
    function o.positionToLocal(w)
        w = V(w)
        local d = { x = w.x - o._pos.x, y = w.y - o._pos.y, z = w.z - o._pos.z }
        local u = rot_y(d, -o._rot.y)
        return { x = -u.x / o._scale.x, y = u.y / o._scale.y, z = u.z / o._scale.z }
    end
    function o.setLock(b) o._locked = b; return true end
    function o.getLock() return o._locked end
    function o.setColorTint(c) o._tint = V(c); o._tint_raw = c; return true end
    function o.setName(n) o._name = n; return true end
    function o.getName() return o._name end
    function o.setDescription(d) o._desc = d; return true end
    function o.addTag(t) o._tags[t] = true; return true end
    function o.hasTag(t) return o._tags[t] == true end
    function o.isDestroyed() return o._destroyed end
    function o.destruct()
        o._destroyed = true
        MOCK.objects[o._guid] = nil
        return true
    end
    function o.getValue() return o._value end
    function o.getRotationValues()
        return {
            { value = 1, rotation = { x = -90, y = 0, z = 0 } },
            { value = 2, rotation = { x = 0, y = 0, z = 0 } },
            { value = 3, rotation = { x = 0, y = 0, z = -90 } },
            { value = 4, rotation = { x = 0, y = 0, z = 90 } },
            { value = 5, rotation = { x = 0, y = 0, z = -180 } },
            { value = 6, rotation = { x = 90, y = 0, z = 0 } },
        }
    end
    function o.roll()
        if MOCK.forced_values and #MOCK.forced_values > 0 then
            o._value = table.remove(MOCK.forced_values, 1)
        else
            o._value = math.random(1, 6)
        end
        o.resting = false
        o._rolls = (o._rolls or 0) + 1
        if not MOCK.never_settle[o._guid] then
            schedule(MOCK.now + MOCK.settle_time, function() o.resting = true end)
        end
        return true
    end
    -- Buttons / inputs
    function o.createButton(p) table.insert(o._buttons, p); return true end
    function o.createInput(p) table.insert(o._inputs, p); return true end
    function o.clearButtons() o._buttons = {}; return true end
    function o.clearInputs() o._inputs = {}; return true end
    function o.getButtons()
        local out = {}
        for i, b in ipairs(o._buttons) do b.index = i - 1; out[i] = b end
        return out
    end
    function o.getInputs()
        local out = {}
        for i, b in ipairs(o._inputs) do b.index = i - 1; out[i] = b end
        return out
    end
    function o.editButton(p)
        local b = o._buttons[p.index + 1]
        assert(b, "editButton: bad index " .. tostring(p.index))
        for k, v in pairs(p) do if k ~= "index" then b[k] = v end end
        return true
    end
    function o.editInput(p)
        local b = o._inputs[p.index + 1]
        assert(b, "editInput: bad index " .. tostring(p.index))
        for k, v in pairs(p) do if k ~= "index" then b[k] = v end end
        return true
    end
    MOCK.objects[o._guid] = o
    return o
end
MOCK.new_object = new_object

function getObjectFromGUID(g) return MOCK.objects[g] end

function spawnObject(p)
    assert(p.type, "spawnObject needs a type")
    local o = new_object(p.type, { position = p.position, rotation = p.rotation, scale = p.scale,
        base = (p.type == "Die_6") and { 0.9, 0.9, 0.9 } or { 1, 1, 1 } })
    o.resting = false
    schedule(MOCK.now + 0.2, function()
        o.resting = true
        if p.callback_function then p.callback_function(o) end
    end)
    return o
end

Wait = {}
function Wait.time(fn, secs) schedule(MOCK.now + (secs or 0), fn); return 1 end
function Wait.frames(fn, n) schedule(MOCK.now + (n or 1) / 60, fn); return 1 end
function Wait.condition(fn, cond, timeout, timeout_fn)
    local deadline = MOCK.now + (timeout or math.huge)
    local function poll()
        if cond() then
            fn()
        elseif MOCK.now >= deadline then
            if timeout_fn then timeout_fn() end
        else
            schedule(MOCK.now + 0.1, poll)
        end
    end
    schedule(MOCK.now, poll)
    return 1
end

function printToAll(msg, color) table.insert(MOCK.chat, { to = "all", msg = msg }) end
function printToColor(msg, pc, color) table.insert(MOCK.chat, { to = pc, msg = msg }) end
function broadcastToAll(msg, color) table.insert(MOCK.chat, { to = "all", msg = msg, broadcast = true }) end
function print(...) end

Player = setmetatable({}, { __index = function(_, color) return { steam_name = "Tester-" .. tostring(color), color = color } end })

-- The mat itself: a BlockSquare-like object, facing the White seat.
self = new_object("BlockSquare", { position = { 0, 1, 0 }, rotation = { 0, 180, 0 }, scale = { 25.5, 0.25, 16.15 } })

-- Helpers for tests ----------------------------------------------------------
function MOCK.button(key_or_label)
    for _, b in ipairs(self._buttons) do
        if b.label == key_or_label then return b end
    end
end

function MOCK.click(fn_name, color, alt)
    local f = _G[fn_name]
    assert(type(f) == "function", "no click function " .. tostring(fn_name))
    f(self, color or "White", alt or false)
end

function MOCK.dice()
    local out = {}
    for _, o in pairs(MOCK.objects) do
        if o._kind == "Die_6" then out[#out + 1] = o end
    end
    return out
end

function MOCK.chat_since(n)
    local out = {}
    for i = n + 1, #MOCK.chat do out[#out + 1] = MOCK.chat[i].msg end
    return out
end
