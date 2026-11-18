-- RestedXP read in one place: its guides, the guide's steps and the
-- waypoint its arrow points at. None of it is a promised interface (its
-- addon object is left global for debugging), so every read checks what it
-- finds and gives nothing rather than an error.
local _, ns = ...
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not (IsAddOnLoaded and IsAddOnLoaded("RXPGuides")) then return end

local Reader = {}
ns.Reader = Reader

local type, tonumber, ipairs, pairs, tostring = type, tonumber, ipairs, pairs, tostring
local sformat = string.format
local NONE = {}

local function RXP()
    local r = _G.RXP
    return type(r) == "table" and r or nil
end

function Reader.Arrow()
    local a = _G.RXPG_ARROW
    return type(a) == "table" and type(a.SetAlpha) == "function" and a or nil
end

-- Whether this RestedXP reads as this extension expects.
function Reader.Ready()
    local rxp = RXP()
    return rxp ~= nil and type(rxp.guides) == "table" and Reader.Arrow() ~= nil
end

function Reader.Guide()
    local rxp = RXP()
    local g = rxp and rxp.currentGuide
    return type(g) == "table" and type(g.steps) == "table" and g or nil
end

function Reader.GuideName(g)
    return g and (g.displayname or g.name) or nil
end

-- The step the guide is on.
function Reader.CurrentIndex()
    local data = _G.RXPCData
    return type(data) == "table" and tonumber(data.currentStep) or 1
end

function Reader.Step()
    local g = Reader.Guide()
    local step = g and g.steps[Reader.CurrentIndex()]
    return type(step) == "table" and step or nil
end

-- The guides it offers this character, as its own guide menu lists them.
function Reader.Guides()
    local rxp = RXP()
    local out = {}
    if not (rxp and type(rxp.guides) == "table") then return out end
    local active = type(rxp.IsGuideActive) == "function" and rxp.IsGuideActive or nil
    for _, g in ipairs(rxp.guides) do
        if type(g) == "table" and type(g.name) == "string" and not g.internal and (not active or active(g)) then
            out[#out + 1] = g
        end
    end
    return out
end

function Reader.GroupName(g)
    local group = g and (g.groupdisplayname or g.group)
    return type(group) == "string" and (group:gsub("^%*", "")) or nil
end

function Reader.LoadGuide(g)
    local rxp = RXP()
    if not (rxp and type(rxp.LoadGuide) == "function") then return false end
    rxp:LoadGuide(g)
    return true
end

function Reader.SetStep(index)
    local rxp = RXP()
    if not (rxp and type(rxp.SetStep) == "function" and Reader.Guide()) then return false end
    rxp.SetStep(index)
    return true
end

local function Elements(step)
    return type(step) == "table" and type(step.elements) == "table" and step.elements or NONE
end
Reader.Elements = Elements

-- A spot element: a map and x, y in hundredths, as its guides write them.
local function Spot(e)
    return type(e) == "table" and type(e.zone) == "number" and type(e.x) == "number" and type(e.y) == "number"
end
Reader.Spot = Spot

function Reader.FirstSpot(step)
    for _, e in ipairs(Elements(step)) do
        if Spot(e) then return e end
    end
end

local function QuestName(id)
    local name = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    if type(name) ~= "string" or name == "" then
        local rxp = RXP()
        name = rxp and type(rxp.GetQuestName) == "function" and rxp.GetQuestName(id) or nil
    end
    return type(name) == "string" and name ~= "" and name or nil
end
Reader.QuestName = QuestName

-- A guide line as plain words: its icons, its color tags, its creature
-- ids ("Al'Aketh Brutes::251145") and its leading ">>" gone, the first
-- line only; a line with no word ("+1", a loop's count) is none.
function Reader.Clean(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("(%w)(|c)", "%1 %2")   -- "Talk to|cRXP_FRIENDLY_Johaan|r"
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|cRXP_[%u_]-_", ""):gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", ""):gsub("::%d+", ""):match("^[^\n]*"):gsub("%s%s+", " "):gsub("^[%s>]+", ""):gsub("%s+$", "")
    return text:find("%a") and text or nil
end

local function Text(e)
    local t = Reader.Clean(type(e) == "table" and e.text)
    if t and t:find("*quest*", 1, true) then
        local name = tonumber(e.questId) and QuestName(tonumber(e.questId))
        t = t:gsub("%*quest%*", ((name or ""):gsub("%%", "%%%%")))
    end
    return t
end

-- What a step says, its first line with words; first: an element to try first.
function Reader.StepText(step, first)
    local t = first and Text(first)
    if t then return t end
    for _, e in ipairs(Elements(step)) do
        t = Text(e)
        if t then return t end
    end
end

-- A creature id's name: the client's, else as a step's text spells it.
local function CreatureName(id, step)
    local api = EasyFind and EasyFind.API
    local name = api and api.CreatureName and api.CreatureName(id)
    if type(name) == "string" and name ~= "" then return name end
    for _, e in ipairs(Elements(step)) do
        name = type(e.text) == "string" and e.text:match("|cRXP_FRIENDLY_([^|]-)::" .. id .. "|r")
        if name then return name end
    end
end

-- The creature a step names: its ".target", else the one it sells to
-- (".vendor"), else the first its text names ("Talk to Veena Vericloud"
-- carried neither target nor button, 2026-11-18); nil when none.
function Reader.TargetName(step)
    local vendor
    for _, e in ipairs(Elements(step)) do
        local t = type(e.targets) == "table" and e.targets[1]
        if type(t) == "string" and t ~= "" then return t end
        if e.tag == "vendor" and tonumber(e.id) then vendor = vendor or tonumber(e.id) end
    end
    local name = vendor and CreatureName(vendor, step)
    if name then return name end
    for _, e in ipairs(Elements(step)) do
        local id = type(e.text) == "string" and e.text:match("|cRXP_FRIENDLY_[^|]-::(%d+)|r")
        if id then return CreatureName(tonumber(id), step) end
    end
end

-- The quests a step takes or hands in: { [questID] = "accept" | "turnin" | "complete" }.
function Reader.Quests(step, out)
    out = out or {}
    for _, e in ipairs(Elements(step)) do
        local id = tonumber(e.questId)
        if id and (e.tag == "accept" or e.tag == "turnin" or e.tag == "complete") and not out[id] then out[id] = e.tag end
    end
    return out
end

-- The items a step still asks for: { [itemID] = count }.
function Reader.Items(step, out)
    out = out or {}
    for _, e in ipairs(Elements(step)) do
        if e.tag == "collect" and tonumber(e.id) then
            out[tonumber(e.id)] = tonumber(e.qty) or 1
        elseif e.tag == "itemcount" and type(e.ids) == "table" then
            for _, id in ipairs(e.ids) do
                if tonumber(id) then out[tonumber(id)] = tonumber(e.total) or 1 end
            end
        end
    end
    return out
end

-- Whether RestedXP would put e on its arrow, by its own rule: a spot made
-- for the arrow, or an active step's not hidden under a done line.
local function ArrowTakes(e)
    if e.hidden then return false end
    if (tonumber(e.generated) or 0) % 2 == 1 then return true end
    local step, parent = e.step, e.parent
    if not (e.arrow and type(step) == "table" and step.active) then return false end
    if type(parent) == "table" and (parent.completed or parent.skip) then return false end
    return not (e.text and e.completed)
end

local KEPT_YARDS = 60   -- a spot kept from the step before leads while the player is this near

-- Yards from the player to spot e, nil where the client cannot say.
local function YardsTo(e)
    if not (C_Map and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, e.zone, "player")
    if not (ok and pos) then return nil end
    local _, a = C_Map.GetWorldPosFromMapPos(e.zone, pos)
    local _, b = C_Map.GetWorldPosFromMapPos(e.zone, CreateVector2D(e.x / 100, e.y / 100))
    if not (a and b) then return nil end
    local ax, ay = a:GetXY()
    local bx, by = b:GetXY()
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- The waypoint its arrow points at, or nil. Shown, the arrow's own: a done
-- spot stays on it while its step lasts. Switched off in its settings, the
-- one it would show. Hidden on a step with no spot of its own, the spot it
-- keeps from the step before while the player stands by it (a book in the
-- shelf there).
function Reader.Target()
    local arrow = Reader.Arrow()
    local e = arrow and arrow.element
    if not Spot(e) then return nil end
    if arrow:IsShown() then return e end
    local rxp = RXP()
    local profile = rxp and type(rxp.settings) == "table" and rxp.settings.profile
    if not (type(profile) == "table" and profile.showEnabled) or rxp.hideArrow then return nil end
    if profile.disableArrow and ArrowTakes(e) then return e end
    local now = Reader.Step()
    local from = type(e.step) == "table" and tonumber(e.step.index)
    if not (now and from and from < (tonumber(now.index) or 0) and not Reader.FirstSpot(now)) then return nil end
    local yards = YardsTo(e)
    return yards and yards <= KEPT_YARDS and e or nil
end

-- The step a waypoint speaks for: its own, unless that step is gone by
-- and down, then the one the guide is on (its arrow can keep such a spot).
local function WordsStep(e)
    local own = type(e) == "table" and type(e.step) == "table" and e.step or nil
    local now = Reader.Step()
    if not own then return now end
    if own.active or not now or (tonumber(own.index) or 0) >= (tonumber(now.index) or 0) then return own end
    return now
end
Reader.WordsStep = WordsStep

-- The creatures its steps name now, as its Active Targets panel lists
-- them: { name, kind = "talk" | "kill" } each, talk ones first; the
-- waypoint's step's creature leads (its panel leaves out a step's with no
-- .target).
function Reader.Targets(e)
    local rxp = RXP()
    local t = rxp and type(rxp.targeting) == "table" and rxp.targeting
    if not (t and type(t.GetCurrentTargets) == "function") then return {} end
    local talk, mobs, scan = t.GetCurrentTargets()
    local out, seen = {}, {}
    local own = Reader.TargetName(WordsStep(e))
    if own then
        seen[own] = true
        out[1] = { name = own, kind = "talk" }
    end
    local function Add(list, kind)
        for _, name in ipairs(type(list) == "table" and list or NONE) do
            if type(name) == "string" and name ~= "" and not seen[name] then
                seen[name] = true
                out[#out + 1] = { name = name, kind = kind }
            end
        end
    end
    Add(talk, "talk")
    Add(mobs, "kill")
    Add(scan, "kill")
    return out
end

-- Its Active Targets panel, and its own redraw of it (outside a fight).
function Reader.TargetPanel()
    local rxp = RXP()
    local t = rxp and type(rxp.targeting) == "table" and rxp.targeting
    local f = t and t.activeTargetFrame
    return type(f) == "table" and type(f.Hide) == "function" and f or nil
end

function Reader.RedrawTargetPanel()
    local rxp = RXP()
    local t = rxp and type(rxp.targeting) == "table" and rxp.targeting
    if t and type(t.UpdateTargetFrame) == "function" then t:UpdateTargetFrame() end
end

-- Called after it rebuilds its target lists.
function Reader.OnTargetsChanged(fn)
    local rxp = RXP()
    local t = rxp and type(rxp.targeting) == "table" and rxp.targeting
    if t and type(t.UpdateMacro) == "function" then hooksecurefunc(t, "UpdateMacro", fn) end
end

-- Called after its step menu's "Go to step" (the menu holds SetStep
-- itself, so a hook on SetStep misses it); false where it reads otherwise.
function Reader.OnGoToStep(fn)
    local rxp = RXP()
    local frame = rxp and type(rxp.RXPFrame) == "table" and rxp.RXPFrame
    local item = frame and type(frame.bottomMenu) == "table" and frame.bottomMenu[1]
    if not (type(item) == "table" and item.func ~= nil and item.func == rxp.SetStep) then return false end
    local go = item.func
    item.func = function(...)
        go(...)
        fn()
    end
    return true
end

function Reader.Key(e)
    local step = e.step
    return sformat("%d|%.4f|%.4f|%s", e.zone, e.x, e.y, tostring(step and step.index))
end

local function SameSpot(a, b)
    return a.zone == b.zone and math.abs(a.x - b.x) < 0.05 and math.abs(a.y - b.y) < 0.05
end

-- The guide's next waypoints after e's step, the first spot of each step
-- the guide shows: a step it hides (a loop run beside another) is none,
-- nor a spot where the last one is.
function Reader.Ahead(e, n)
    local out = {}
    local g = Reader.Guide()
    local from = e and type(e.step) == "table" and tonumber(e.step.index)
    if not (g and from and n and n > 0) then return out end
    local last = e
    for i = from + 1, #g.steps do
        local step = g.steps[i]
        local spot = not step.hidewindow and Reader.FirstSpot(step)
        if spot and not SameSpot(spot, last) then
            out[#out + 1] = spot
            last = spot
        end
        if #out >= n then break end
    end
    return out
end

-- A spot as the GPS takes it: the step's creature, its words, its quest
-- mark, from the step it speaks for.
function Reader.Dest(e)
    local step = WordsStep(e)
    local npc = Reader.TargetName(step)
    local mark, quest
    for id, kind in pairs(Reader.Quests(step)) do
        if kind == "turnin" then
            mark, quest = "turnin", id
        elseif kind == "accept" and not mark then
            mark = "offer"
        end
    end
    local text = Reader.StepText(step, step == e.step and e or nil)
    local index = type(step) == "table" and tonumber(step.index)
    -- hold: the GPS stays on it till the guide moves on (GPS 1.9.0).
    return { name = npc or text or sformat(ns.L["STEP_FMT"], index or 0), npcName = npc,
             mapID = e.zone, x = e.x / 100, y = e.y / 100, step = text,
             questMark = mark, questID = quest, quietArrival = true, hold = true }
end
