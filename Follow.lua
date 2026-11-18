-- The GPS following the guide: each waypoint RestedXP's arrow points at,
-- and the guide's next few after it as stops, routed for real (walks,
-- lifts, flights, boats). A route of the player's own comes first: the
-- guide waits until it ends. A route the player ended is not started
-- again for the same waypoint; the next one starts the guide's again.
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

local state = { leading = false, yielded = false, faded = false, pending = false }
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

-- force: lead to the guide's waypoint even when it was sent before.
function Follow.Sync(force)
    if not (Follow.On() and Reader.Ready() and API.HasAction("gps", "navigate")) then return Fade(false) end
    if state.yielded then return Fade(false) end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    local e = Reader.Target()
    if not e then return Fade(state.leading) end
    local key = Reader.Key(e)
    local char = Char()
    if key == char.key and not force then return Fade(state.leading) end
    local list = { Reader.Dest(e) }
    if API.HasAction("gps", "navigateTrip") then
        for _, spot in ipairs(Reader.Ahead(e, Follow.Ahead())) do list[#list + 1] = Reader.Dest(spot) end
    end
    -- Kept before the call: its route can start inside it.
    local before = char.sent
    char.sent = {}
    for i = 1, #list do char.sent[i] = Plain(list[i]) end
    local ok
    if #list > 1 then
        ok = API.CallAction("gps", "navigateTrip", list, { quiet = true })
    else
        ok = API.CallAction("gps", "navigate", list[1], { quiet = true })
    end
    if ok then char.key = key else char.sent = before end
end

-- One sync for a burst of changes, and none in a fight (the GPS's buttons
-- are secure): it waits for the fight's end.
local events = CreateFrame("Frame")
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
    end)
end

function Follow.LeadNow()
    state.yielded = false
    Follow.Sync(true)
end

function Follow.SetOn(on)
    if on then DB().follow = nil else DB().follow = false end
    if on then Follow.LeadNow() else Fade(false) end
end

function Follow.SetHidesArrow(on)
    if on then DB().keepArrow = nil else DB().keepArrow = true end
    Fade(state.leading)
end

function Follow.SetAhead(n)
    DB().ahead = n
    if state.leading then Follow.LeadNow() end
end

API.On("gps", "routeStarted", function(dest)
    local mine = Ours(dest)
    state.leading = mine
    if not mine then state.yielded = true end
    Fade(mine)
end)

-- The player's own route over: the guide leads again.
API.On("gps", "routeCleared", function()
    local theirs = state.yielded
    state.leading, state.yielded = false, false
    Fade(false)
    if theirs then
        Char().key = nil
        Follow.Schedule()
    end
end)

-- The arrow's waypoint changed: RestedXP shows or hides the arrow as it
-- picks one, so its shows say when to look.
local lastElement
local function ArrowMoved(arrow)
    if arrow.element ~= lastElement then
        lastElement = arrow.element
        Follow.Schedule()
    end
end

local function Hook()
    local arrow = Reader.Arrow()
    if not arrow then return end
    hooksecurefunc(arrow, "SetShown", ArrowMoved)
    hooksecurefunc(arrow, "Show", ArrowMoved)
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
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        state.pending = false
        Follow.Sync()
        return
    end
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if not Reader.Ready() then return end
        Hook()
        -- A route kept from before the reload: the guide's, or the player's.
        local dest = API.CallAction("gps", "destination")
        if dest then
            state.leading = Ours(dest)
            state.yielded = not state.leading
        end
        Fade(state.leading)
    elseif not (state.leading or state.yielded) then
        -- Back from the dead: the corpse run ended the guide's route.
        Char().key = nil
    end
    Follow.Schedule()
end)
