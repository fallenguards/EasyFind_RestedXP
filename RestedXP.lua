-- RestedXP in EasyFind: its guides as rows (a click loads one), the loaded
-- guide's steps as rows and as a page (a click jumps the guide there, the
-- GPS button routes to the step), EasyFind's quest and bag rows marked
-- with the step that takes them, and the tile's switches for following.
local _, ns = ...
local API = EasyFind and EasyFind.API
local Reader, Follow = ns.Reader, ns.Follow
if not (API and API.VERSION == 1 and Reader and Follow) then return end

local L = ns.L
local KEY = "restedxp"
local STEPS_KEY, GUIDES_KEY = "rxpsteps", "rxpguides"
local ICON = "Interface\\AddOns\\EasyFind_RestedXP\\restedxp"
local LOGO = "Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64"
local OFFER_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local TURNIN_ICON = "Interface\\GossipFrame\\ActiveQuestIcon"
local CHAT_COLOR = "|cff66ccff"
local ITEM_ROWS = { Bag = true, Bank = true }

local sformat, slower, ipairs, pairs, next, tostring = string.format, string.lower, ipairs, pairs, next, tostring

local function Say(text)
    print(CHAT_COLOR .. L["EXT_NAME"] .. ":|r " .. text)
end

if (API.MINOR or 0) < 13 then
    Say(L["NEEDS_EASYFIND"])
    return
end

local function Lower(list)
    local out = {}
    for i = 1, #list do out[i] = slower(list[i]) end
    return out
end

-- ==== its guides ===============================================================

local function GuideKey(g) return tostring(g.group) .. "||" .. g.name end

local function FindGuide(key)
    for _, g in ipairs(Reader.Guides()) do
        if GuideKey(g) == key then return g end
    end
end

local function GuideRows()
    local out = {}
    for _, g in ipairs(Reader.Guides()) do
        local name = Reader.GuideName(g)
        local group = Reader.GroupName(g)
        local words = { L["KW_GUIDE"], L["EXT_NAME"] }
        if group then words[#words + 1] = group end
        out[#out + 1] = { name = name, nameLower = slower(name), keywords = words, keywordsLower = Lower(words),
                          searchCommandDesc = group and sformat(L["GUIDE_SUB"], group) or L["EXT_NAME"],
                          icon = LOGO, rxpGuideKey = GuideKey(g) }
    end
    return out
end

-- ==== the loaded guide's steps =================================================

local function StepIcon(step)
    local kinds = Reader.Quests(step)
    for _, kind in pairs(kinds) do
        if kind == "turnin" then return TURNIN_ICON end
    end
    if next(kinds) then return OFFER_ICON end
    return LOGO
end

local builtFor                      -- the guide the step rows were made from
local function StepRows()
    local out = {}
    local g = Reader.Guide()
    builtFor = g
    if not g then return out end
    local guideName = Reader.GuideName(g) or ""
    for i, step in ipairs(g.steps) do
        local text = Reader.StepText(step)
        if text then
            local words = { L["KW_STEP"] }
            local npc = Reader.TargetName(step)
            if npc then words[#words + 1] = npc end
            for id in pairs(Reader.Quests(step)) do
                local q = Reader.QuestName(id)
                if q then words[#words + 1] = q end
            end
            local spot = Reader.FirstSpot(step)
            out[#out + 1] = { name = text, nameLower = slower(text), keywords = words, keywordsLower = Lower(words),
                              searchCommandDesc = sformat(L["STEP_SUB"], i, guideName), mapID = spot and spot.zone,
                              icon = StepIcon(step), rxpStep = i }
        end
    end
    return out
end

local function StepPlace(row)
    local g = Reader.Guide()
    local spot = g and Reader.FirstSpot(g.steps[row.rxpStep])
    if not spot then return nil end
    return { name = row.name, mapID = spot.zone, x = spot.x / 100, y = spot.y / 100, step = row.name }
end

-- ==== EasyFind's quest and bag rows: the step that takes them ==================

local index = { quests = {}, items = {} }

-- Where each quest and item comes up in the loaded guide, built again when
-- the guide or its steps change.
local function Index()
    local g = Reader.Guide()
    if g == index.guide and (g and #g.steps or 0) == index.n then return index end
    index.guide, index.n, index.quests, index.items = g, g and #g.steps or 0, {}, {}
    for i, step in ipairs(g and g.steps or {}) do
        for id, kind in pairs(Reader.Quests(step)) do
            local list = index.quests[id] or {}
            index.quests[id] = list
            list[#list + 1] = { step = i, kind = kind }
        end
        for id, count in pairs(Reader.Items(step)) do
            local list = index.items[id] or {}
            index.items[id] = list
            list[#list + 1] = { step = i, count = count }
        end
    end
    return index
end

-- The first mention from the step the guide is on; a quest's last one when
-- the guide is past them all.
local function Upcoming(list, keepLast)
    if not list then return nil end
    local now = Reader.CurrentIndex()
    for _, m in ipairs(list) do
        if m.step >= now then return m end
    end
    return keepLast and list[#list] or nil
end

local function QuestMention(row)
    local id = row.questId or row.questID
    return id and Upcoming(Index().quests[id], true)
end

local function ItemMention(row)
    return row.itemID and ITEM_ROWS[row.category] and Upcoming(Index().items[row.itemID]) or nil
end

-- ==== settings, tile and registration ==========================================

local function Settings(page, kit)
    local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
    local follow = kit.Checkbox(page, L["FOLLOW"], Follow.On, Follow.SetOn, L["FOLLOW_TT"])
    follow:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
    local arrow = kit.Checkbox(page, L["HIDE_ARROW"], Follow.HidesArrow, Follow.SetHidesArrow, L["HIDE_ARROW_TT"])
    arrow:SetPoint("TOPLEFT", follow, "BOTTOMLEFT", 0, -4)
    local own = kit.Checkbox(page, L["OWN_ARROW"], Follow.OwnArrow, Follow.SetOwnArrow, L["OWN_ARROW_TT"])
    own:SetPoint("TOPLEFT", arrow, "BOTTOMLEFT", 0, -4)
    local last = own
    -- The GPS's own setting, here too: hidden, it was missed on this page.
    if API.HasAction("gps", "arrowBox") then
        local box = kit.Checkbox(page, L["BOX"], function() return API.CallAction("gps", "arrowBox") ~= false end,
            function(on) API.CallAction("gps", "arrowBox", on) end, L["BOX_TT"])
        box:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
        last = box
    end
    -- The GPS's look for what a guide puts under its arrow, switched here.
    for _, x in ipairs({ { action = "useIcons", label = "USE_ICONS" }, { action = "targetPairs", label = "TARGET_PAIRS" } }) do
        if API.HasAction("gps", x.action) then
            local row = kit.Checkbox(page, L[x.label], function() return API.CallAction("gps", x.action) ~= false end,
                function(on) API.CallAction("gps", x.action, on) end, L[x.label .. "_TT"])
            row:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
            last = row
        end
    end
    -- What the guide's steps lay over the GPS, each where the GPS takes it.
    for _, x in ipairs({ { key = "deathSkip", action = "deathSkip", label = "DEATH_SKIP" },
                         { key = "grindXP", action = "setStatus", label = "GRIND_XP" },
                         { key = "circuits", action = "setCircuit", label = "CIRCUITS" } }) do
        if API.HasAction("gps", x.action) then
            local row = kit.Checkbox(page, L[x.label], function() return Follow.Extra(x.key) end,
                function(on) Follow.SetExtra(x.key, on) end, L[x.label .. "_TT"])
            row:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
            last = row
        end
    end
    local ahead = kit.Stepper(page, L["AHEAD"], 0, Follow.AHEAD_MAX, 1, Follow.Ahead, Follow.SetAhead, L["AHEAD_TT"])
    ahead:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
end

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { L["KW_GUIDE"] },
    scope = STEPS_KEY,
    settings = Settings,
    menu = function()
        return {
            { kind = "check", label = L["FOLLOW"], get = Follow.On, set = Follow.SetOn },
            { kind = "action", label = L["LEAD_NOW"], onClick = Follow.LeadNow },
        }
    end,
})

API.RegisterSearchProvider({
    key = GUIDES_KEY,
    extension = KEY,
    label = L["GUIDES_LABEL"],
    icon = ICON,
    eager = true,
    aliases = { "guides", "rxpguides" },
    words = { L["KW_GUIDE"] },
    hint = { click = L["HINT_GUIDE"] },
    rows = GuideRows,
    select = function(row)
        local g = FindGuide(row.rxpGuideKey)
        if g then Reader.LoadGuide(g) end
    end,
})

API.RegisterSearchProvider({
    key = STEPS_KEY,
    extension = KEY,
    label = L["STEPS_LABEL"],
    icon = ICON,
    lowResults = true,
    aliases = { "rxp", "guide" },
    words = { L["KW_STEP"] },
    hint = { click = L["HINT_STEP"] },
    rows = StepRows,
    browse = function(row) return row.rxpStep >= Reader.CurrentIndex() end,
    place = StepPlace,
    select = function(row) Reader.SetStep(row.rxpStep) end,
})

API.RegisterRowDecorator({
    id = KEY,
    label = L["EXT_NAME"],
    applies = function(row) return QuestMention(row) ~= nil or ItemMention(row) ~= nil end,
    subtext = function(row)
        local q = QuestMention(row)
        if q then return sformat(L["QUEST_STEP"], q.step) end
        local item = ItemMention(row)
        return item and sformat(L["ITEM_STEP"], item.step, item.count) or nil
    end,
    menu = function(row)
        local m = QuestMention(row) or ItemMention(row)
        if not m then return nil end
        return { { kind = "action", label = sformat(L["GO_TO_STEP"], m.step), onClick = function() Reader.SetStep(m.step) end } }
    end,
})

-- The guide loaded or changed: its steps are rows again; the step moved
-- on: the marks on the shown rows are read again.
local function GuideChanged()
    if Reader.Guide() ~= builtFor then API.RefreshSearchProvider(STEPS_KEY) end
    API.RefreshRowDecorations()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not Reader.Ready() then
        Say(L["NO_RXP"])
        return
    end
    local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
    if AceEvent then
        local listener = {}
        AceEvent:Embed(listener)
        listener:RegisterMessage("RXPGuidesV2_UpdateActiveSteps", GuideChanged)
        listener:RegisterMessage("RXPGuidesV2_GuideStepsChanged", GuideChanged)
    end
end)

-- What the tests read.
ns.RestedXP = { GuideRows = GuideRows, StepRows = StepRows, StepPlace = StepPlace, Index = Index,
                QuestMention = QuestMention, ItemMention = ItemMention, FindGuide = FindGuide }
