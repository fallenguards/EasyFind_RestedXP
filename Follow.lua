-- The GPS following the guide: each waypoint RestedXP's arrow points at,
-- and the guide's next few after it as stops, routed for real (walks,
-- lifts, flights, boats). A route of the player's own holds until it ends
-- or the arrow moves to another waypoint. The guide's route cleared by the
-- player is led again from where they stand; arrived at, it is not.
local _, ns = ...
local Reader = ns.Reader
local API = EasyFind and EasyFind.API
if not (Reader and API) then return end

local Follow = {}
ns.Follow = Follow

local mabs, tonumber, ipairs = math.abs, tonumber, ipairs
local SAME = 0.0005           -- map fractions this close are one spot
local SETTLE = 0.2            -- seconds: a burst of guide changes acts once
local AHEAD_MAX = 5

local function DB()
    EasyFindRestedXPDB = EasyFindRestedXPDB or {}
    return EasyFindRestedXPDB
end
ns.DB = DB

-- This character's trip: what was last sent, and where it ends.
local function Char()
    EasyFindRestedXPCharDB = EasyFindRestedXPCharDB or {}
    return EasyFindRestedXPCharDB
end

function Follow.On() return DB().follow ~= false end
function Follow.HidesArrow() return DB().keepArrow ~= true end
function Follow.Ahead()
    local n = tonumber(DB().ahead) or 2
    return n < 0 and 0 or n > AHEAD_MAX and AHEAD_MAX or n
end
Follow.AHEAD_MAX = AHEAD_MAX

-- force: send the guide's route even when it is the one sent last.
local state = { leading = false, yielded = false, faded = false, pending = false, panelHidden = false, force = false }
Follow._state = state

local function Same(a, b)
    return type(a) == "table" and type(b) == "table" and a.mapID == b.mapID and a.name == b.name
        and mabs((a.x or 0) - (b.x or 0)) < SAME and mabs((a.y or 0) - (b.y or 0)) < SAME
end

-- A route the GPS has is the guide's when it ends at one of the stops sent
-- (one it cannot reach is left out of the trip).
local function Ours(dest)
    for _, s in ipairs(Char().sent or {}) do
        if Same(dest, s) then return true end
    end
    return false
end

-- RestedXP's arrow faded while the GPS leads: its own drawing sets the
-- alpha every frame, so each set is answered with 0.
local hooked, busy
local function KeepFaded(frame, alpha)
    if busy or not state.faded or not alpha or alpha <= 0 then return end
    busy = true
    frame:SetAlpha(0)
    busy = false
end

local function Fade(on)
    on = on and Follow.On() and Follow.HidesArrow() or false
    local arrow = Reader.Arrow()
    if not arrow or on == state.faded then return end
    if on and not hooked then
        hooked = true
        hooksecurefunc(arrow, "SetAlpha", KeepFaded)
    end
    state.faded = on
    busy = true
    arrow:SetAlpha(on and 0 or 1)
    busy = false
end
Follow.Fade = Fade

local function Plain(d)
    return { name = d.name, mapID = d.mapID, x = d.x, y = d.y }
end

local function SameList(a, b)
    if type(b) ~= "table" or #a ~= #b then return false end
    for i = 1, #a do
        if not Same(a[i], b[i]) then return false end
    end
    return true
end

-- The GPS made to say what the guide says now: its route sent whenever it
-- differs from the one sent last (force: even when it does not), and gone
-- while the guide has no waypoint.
function Follow.Sync(force)
    if not (Follow.On() and Reader.Ready() and API.HasAction("gps", "navigate")) then return Fade(false) end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    force = force or state.force
    local char = Char()
    local e = Reader.Target()
    if not e then
        if state.leading then
            state.leading, char.sent = false, nil
            API.CallAction("gps", "clear")
        end
        return Fade(false)
    end
    local key = Reader.Key(e)
    -- A route of the player's own holds while the arrow stays on the
    -- waypoint it was on (false: none); unknown (kept from before), the
    -- one it is on now.
    if state.yielded then
        if char.heldAt == nil then char.heldAt = key end
        if key == char.heldAt then return Fade(false) end
        state.yielded, char.heldAt = false, nil
    end
    local list = { Reader.Dest(e) }
    if API.HasAction("gps", "navigateTrip") then
        for _, spot in ipairs(Reader.Ahead(e, Follow.Ahead())) do list[#list + 1] = Reader.Dest(spot) end
    end
    local plain = {}
    for i = 1, #list do plain[i] = Plain(list[i]) end
    if not force and SameList(plain, char.sent) then return Fade(state.leading) end
    -- Kept before the call: its route can start inside it.
    local before = char.sent
    char.sent = plain
    local ok
    if #list > 1 then
        ok = API.CallAction("gps", "navigateTrip", list, { quiet = true })
    else
        ok = API.CallAction("gps", "navigate", list[1], { quiet = true })
    end
    if ok then state.force = false else char.sent = before end
end

local events = CreateFrame("Frame")

-- The guide's creatures under the GPS arrow while it follows, a Target
-- button each; RestedXP's own Active Targets panel hidden with its arrow
-- meanwhile (it shows the panel only outside a fight).
local sentTargets, panelHooked = "", false
local function KeepPanelHidden(panel, shown)
    if shown ~= false and state.panelHidden and not InCombatLockdown() then panel:Hide() end
end

function Follow.SyncTargets()
    if InCombatLockdown() then return events:RegisterEvent("PLAYER_REGEN_ENABLED") end
    local can = API.HasAction("gps", "setTargets")
    local list = can and Follow.On() and Reader.Ready() and Reader.Targets(Reader.Target()) or {}
    local parts = {}
    for i, t in ipairs(list) do parts[i] = t.kind .. ":" .. t.name end
    local key = table.concat(parts, "\n")
    if can and key ~= sentTargets then
        sentTargets = key
        API.CallAction("gps", "setTargets", list)
    end
    local panel = Reader.TargetPanel()
    local hide = #list > 0 and Follow.HidesArrow()
    if not panel or hide == state.panelHidden then return end
    state.panelHidden = hide
    if hide then
        if not panelHooked then
            panelHooked = true
            hooksecurefunc(panel, "Show", KeepPanelHidden)
            hooksecurefunc(panel, "SetShown", KeepPanelHidden)
        end
        panel:Hide()
    else
        Reader.RedrawTargetPanel()
    end
end

-- The extras a guide's steps lay over the GPS, each on unless its switch
-- is off: a death skip's Spirit Healer, a grind's XP under the step, a
-- loop step's circuit on the maps (the last two while the guide leads).
function Follow.Extra(key) return DB()[key] ~= false end

function Follow.SetExtra(key, on)
    if on then DB()[key] = nil else DB()[key] = false end
    Follow.SyncExtras()
end

-- The grind's XP for the box under the arrow: toward the goal at its
-- level, else the level it is reached at; nil once there or unknown.
function Follow.GrindText()
    local level, xp = Reader.GrindGoal()
    if not level then return nil end
    local cur, max, now = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if issecretvalue and (issecretvalue(cur) or issecretvalue(max)) then return nil end
    if not (cur and max and now and max > 0) then return nil end
    -- The level the goal sits on: the one before it for 0 and below.
    local at = xp <= 0 and level - 1 or level
    if now < at then return ns.L["GRIND_LEVEL_FMT"]:format(now, level) end
    if now > at then return nil end
    local goal = xp == 0 and max or xp < 0 and max + xp or xp >= 1 and xp or math.floor(max * xp)
    if cur >= goal or goal <= 0 then return nil end
    local Big = BreakUpLargeNumbers or tostring
    return ns.L["GRIND_XP_FMT"]:format(Big(cur), Big(goal), math.floor(cur / goal * 100))
end

local sent = { circuit = "" }
local function CircuitKey(list)
    local parts = {}
    for i, s in ipairs(list) do parts[i] = string.format("%d:%.4f:%.4f", s.mapID, s.x, s.y) end
    return table.concat(parts, "|")
end

function Follow.SyncExtras()
    local on = Follow.On() and Reader.Ready()
    if API.HasAction("gps", "deathSkip") then
        local skip = on and Follow.Extra("deathSkip") and Reader.DeathSkip() or false
        if skip ~= sent.deathSkip then
            sent.deathSkip = skip
            API.CallAction("gps", "deathSkip", skip)
        end
    end
    local leading = on and state.leading
    if API.HasAction("gps", "setStatus") then
        local text = leading and Follow.Extra("grindXP") and Follow.GrindText() or nil
        if text ~= sent.status then
            sent.status = text
            API.CallAction("gps", "setStatus", text)
        end
    end
    if API.HasAction("gps", "setCircuit") then
        local list = leading and Follow.Extra("circuits") and Reader.Circuit(Reader.Target()) or nil
        local key = list and CircuitKey(list) or ""
        if key ~= sent.circuit then
            sent.circuit = key
            API.CallAction("gps", "setCircuit", list)
        end
    end
end

-- One sync for a burst of changes, and none in a fight (the GPS's buttons
-- are secure): it waits for the fight's end.
function Follow.Schedule()
    if state.pending then return end
    state.pending = true
    C_Timer.After(SETTLE, function()
        if InCombatLockdown() then
            events:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        state.pending = false
        Follow.Sync()
        Follow.SyncTargets()
        Follow.SyncExtras()
    end)
end

function Follow.LeadNow()
    state.yielded, Char().heldAt = false, nil
    Follow.Sync(true)
end

-- Its step menu's Go to step, the step it is on too: the guide leads again
-- once its arrow has moved.
function Follow.Picked()
    state.yielded, Char().heldAt = false, nil
    state.force = true
    Follow.Schedule()
end

function Follow.SetOn(on)
    if on then DB().follow = nil else DB().follow = false end
    if on then Follow.LeadNow() else Fade(false) end
    Follow.SyncTargets()
    Follow.SyncExtras()
end

function Follow.SetHidesArrow(on)
    if on then DB().keepArrow = nil else DB().keepArrow = true end
    Fade(state.leading)
    Follow.SyncTargets()
end

function Follow.SetAhead(n)
    DB().ahead = n
    if state.leading then Follow.LeadNow() end
end

-- The player's own route: it holds until the guide's arrow moves on.
API.On("gps", "routeStarted", function(dest)
    local mine = Ours(dest)
    state.leading, state.arrived = mine, false
    if not mine then
        state.yielded = true
        local e = Reader.Target()
        Char().heldAt = e and Reader.Key(e) or false
    end
    Fade(mine)
    Follow.SyncExtras()
end)

API.On("gps", "arrived", function() state.arrived = true end)

-- A route over: the player's own, the guide leads again; the guide's
-- cleared by the player, a reset, led again from here (the Follow switch
-- turns it off; a clear left it off, and the player thought it broken,
-- 2026-11-18); the guide's arrived at, not again for that waypoint.
API.On("gps", "routeCleared", function()
    local theirs, arrived = state.yielded, state.arrived
    state.leading, state.yielded, state.arrived = false, false, false
    Fade(false)
    Follow.SyncExtras()
    if theirs or not arrived then
        Char().heldAt = nil
        state.force = true
        Follow.Schedule()
    end
end)

-- RestedXP shows or hides the arrow as it picks a waypoint, and sets the
-- waypoint after the show: each show or hide is a look once it settles (a
-- sync of the route already sent does nothing).
local function Hook()
    local arrow = Reader.Arrow()
    if not arrow then return end
    hooksecurefunc(arrow, "SetShown", Follow.Schedule)
    hooksecurefunc(arrow, "Show", Follow.Schedule)
    hooksecurefunc(arrow, "Hide", Follow.Schedule)
    Reader.OnTargetsChanged(Follow.Schedule)
    Reader.OnGoToStep(Follow.Picked)
    local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
    if AceEvent then
        local listener = {}
        AceEvent:Embed(listener)
        listener:RegisterMessage("RXPGuidesV2_UpdateActiveSteps", Follow.Schedule)
        listener:RegisterMessage("RXPGuidesV2_GuideStepsChanged", Follow.Schedule)
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_UNGHOST")
events:RegisterEvent("PLAYER_ALIVE")
-- A grind's XP under the step, as it grows.
events:RegisterEvent("PLAYER_XP_UPDATE")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then return Follow.SyncExtras() end
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        state.pending = false
        Follow.Sync()
        Follow.SyncTargets()
        Follow.SyncExtras()
        return
    end
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not Reader.Ready() then return end
        Hook()
        -- A route kept from before the reload: the player's holds; the
        -- guide's is sent again, planned as this version plans it (one
        -- kept from an older one walked on past the guide's stop).
        Char().key = nil   -- a save from before the route was compared whole
        local dest = API.CallAction("gps", "destination")
        if dest then
            state.leading = Ours(dest)
            state.yielded = not state.leading
            if state.leading then state.force = true end
        end
        Fade(state.leading)
    elseif not (state.leading or state.yielded) then
        -- Back from the dead: the corpse run ended the guide's route.
        state.force = true
    end
    Follow.Schedule()
end)
