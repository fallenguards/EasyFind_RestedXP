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

-- A guide line as plain words: its icons, its color tags and its leading
-- ">>" gone, the first line only.
function Reader.Clean(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|cRXP_[%u_]-_", ""):gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", ""):match("^[^\n]*"):gsub("^[%s>]+", ""):gsub("%s+$", "")
    return text ~= "" and text or nil
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

-- The creature a step names (".target"), or nil.
function Reader.TargetName(step)
    for _, e in ipairs(Elements(step)) do
        local t = type(e.targets) == "table" and e.targets[1]
        if type(t) == "string" and t ~= "" then return t end
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

-- The waypoint its arrow points at while that step is on, or nil.
function Reader.Target()
    local arrow = Reader.Arrow()
    local e = arrow and arrow.element
    if not Spot(e) or e.completed or e.skip or e.hidden then return nil end
    local step = e.step
    if type(step) ~= "table" or not step.active then return nil end
    return e
end

function Reader.Key(e)
    local step = e.step
    return sformat("%d|%.4f|%.4f|%s", e.zone, e.x, e.y, tostring(step and step.index))
end

-- The guide's next waypoints after e's step, the first spot of each step.
function Reader.Ahead(e, n)
    local out = {}
    local g = Reader.Guide()
    local from = e and type(e.step) == "table" and tonumber(e.step.index)
    if not (g and from and n and n > 0) then return out end
    for i = from + 1, #g.steps do
        local spot = Reader.FirstSpot(g.steps[i])
        if spot then out[#out + 1] = spot end
        if #out >= n then break end
    end
    return out
end

-- A spot as the GPS takes it: the step's creature, its words, its quest mark.
function Reader.Dest(e)
    local step = e.step
    local npc = Reader.TargetName(step)
    local mark, quest
    for id, kind in pairs(Reader.Quests(step)) do
        if kind == "turnin" then
            mark, quest = "turnin", id
        elseif kind == "accept" and not mark then
            mark = "offer"
        end
    end
    local text = Reader.StepText(step, e)
    local index = type(step) == "table" and tonumber(step.index)
    return { name = npc or text or sformat(ns.L["STEP_FMT"], index or 0), npcName = npc,
             mapID = e.zone, x = e.x / 100, y = e.y / 100, step = text,
             questMark = mark, questID = quest, quietArrival = true }
end
