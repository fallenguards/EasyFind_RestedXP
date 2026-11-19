-- The extension loaded offline: its toc's files run in a stand-in game
-- against a recording EasyFind.API (with the GPS's actions and events)
-- and a stand-in RestedXP: its addon object, its guides with steps as its
-- parser leaves them, its arrow frame and its step messages.
--   local Harness = require("Harness")
--   local ctx = Harness.Load({ rxp = false })
local Harness = {}

local source = debug.getinfo(1, "S").source:sub(2)
local ROOT = source:gsub("[/\\]?tests[/\\]Harness%.lua$", "")
if ROOT == "" then ROOT = "." end
Harness.ROOT = ROOT
Harness.TOC = "EasyFind_RestedXP.toc"

function Harness.Read(path)
    local f = assert(io.open(ROOT .. "/" .. path, "rb"))
    local text = f:read("a")
    f:close()
    return text
end

function Harness.Eq(got, want, label)
    if got ~= want then
        error(string.format("%s: got %s, wanted %s", label or "value", tostring(got), tostring(want)), 2)
    end
end

function Harness.True(ok, label)
    if not ok then error((label or "check") .. " failed", 2) end
end

function Harness.Toc()
    local text = Harness.Read(Harness.TOC)
    local fields, files = {}, {}
    for line in text:gsub("\r", ""):gmatch("[^\n]+") do
        local key, value = line:match("^## ([%w%-]+):%s*(.-)%s*$")
        if key then
            fields[key] = value
        elseif not line:match("^#") and line:match("%.lua") then
            files[#files + 1] = line:match("^(%S+)"):gsub("\\", "/")
        end
    end
    return fields, files
end

-- A Westfall guide as RestedXP's parser leaves it: steps numbered, each
-- element tagged and holding its step, spots in hundredths of the map.
local WESTFALL = 1436
function Harness.Guide()
    local steps = {
        { elements = {
            { tag = "goto", zone = WESTFALL, x = 59.95, y = 19.35,
              text = ">>|Tinterface/worldmap/chatbubble_64grey.blp:20|tTalk to |cRXP_FRIENDLY_Farmer Furlbrow|r" },
            { tag = "accept", questId = 64, text = "Accept *quest*" },
            { tag = "target", targets = { "Farmer Furlbrow" }, textOnly = true },
        } },
        { elements = {
            { tag = "goto", zone = WESTFALL, x = 59.92, y = 19.42, text = "Talk to |cRXP_FRIENDLY_Verna Furlbrow|r" },
            { tag = "accept", questId = 36, text = "Accept Westfall Stew" },
            { tag = "target", targets = { "Verna Furlbrow" }, textOnly = true },
        } },
        { elements = {
            { tag = "goto", zone = WESTFALL, x = 56.04, y = 31.23, radius = 65, text = ">> Travel to Saldean's Farm" },
        } },
        { elements = {
            { tag = "collect", id = 732, qty = 4, questId = 9, text = "Collect Okra" },
        } },
        { elements = {
            { tag = "goto", zone = WESTFALL, x = 56.32, y = 47.52, text = "Talk to Gryan Stoutmantle" },
            { tag = "turnin", questId = 64, text = "Turn in *quest*" },
            { tag = "target", targets = { "Gryan Stoutmantle" }, textOnly = true },
        } },
    }
    for i, step in ipairs(steps) do
        step.index = i
        for _, e in ipairs(step.elements) do e.step = step end
    end
    return { name = "13-15 Westfall", group = "RestedXP Alliance 1-20", steps = steps }
end

-- opts.rxp = false: RestedXP not loaded; opts.broken = true: a version whose
-- addon object reads otherwise; opts.gps = false: no GPS; opts.trip = false:
-- a GPS without navigateTrip; opts.minor: EasyFind's API MINOR.
function Harness.Load(opts)
    opts = opts or {}
    local ctx = { printed = {}, frames = {}, timers = {}, navigated = {}, providers = {}, decorators = {},
                  listeners = {}, messages = {}, refreshed = {}, repaints = 0, gps = {} }
    local api = {
        VERSION = 1, MINOR = opts.minor or 13,
        RegisterExtension = function(def) ctx.extension = def end,
        RegisterSearchProvider = function(def) ctx.providers[def.key] = def end,
        RegisterRowDecorator = function(def) ctx.decorators[#ctx.decorators + 1] = def end,
        RefreshSearchProvider = function(key) ctx.refreshed[#ctx.refreshed + 1] = key end,
        RefreshRowDecorations = function() ctx.repaints = ctx.repaints + 1 end,
        HasAction = function(id, name)
            if id ~= "gps" or opts.gps == false then return false end
            return name ~= "navigateTrip" or opts.trip ~= false
        end,
        CallAction = function(_, name, a, b)
            if name == "navigate" or name == "navigateTrip" then
                ctx.navigated[#ctx.navigated + 1] = { action = name, dest = a, opts = b }
                -- The GPS plans, then says its route started: the trip's end.
                local last = name == "navigateTrip" and a[#a] or a
                ctx.gps.dest = { name = last.name, mapID = last.mapID, x = last.x, y = last.y }
                if not ctx.holdStart then ctx.FireGPS("routeStarted", ctx.gps.dest) end
                return true
            end
            if name == "destination" then return ctx.gps.dest end
            -- The box under the GPS arrow: no argument reads it, a boolean sets it.
            if name == "arrowBox" then
                if a == nil then return ctx.box ~= false end
                ctx.box = a
            end
            if name == "clear" then
                ctx.cleared = (ctx.cleared or 0) + 1
                ctx.gps.dest = nil
                ctx.FireGPS("routeCleared")
            end
            if name == "setTargets" then
                ctx.targetSets = ctx.targetSets + 1
                ctx.targets = a
            end
        end,
        On = function(id, event, fn)
            ctx.listeners[id .. ":" .. event] = ctx.listeners[id .. ":" .. event] or {}
            table.insert(ctx.listeners[id .. ":" .. event], fn)
        end,
    }
    function ctx.FireGPS(event, ...)
        for _, fn in ipairs(ctx.listeners["gps:" .. event] or {}) do fn(...) end
    end
    -- The player's own route, or the guide's ending.
    function ctx.PlayerRoute(name)
        ctx.gps.dest = { name = name, mapID = 1429, x = 0.4, y = 0.6 }
        ctx.FireGPS("routeStarted", ctx.gps.dest)
    end
    function ctx.ClearRoute()
        ctx.gps.dest = nil
        ctx.FireGPS("routeCleared")
    end

    -- RestedXP: its guide, the step it is on, its arrow frame.
    local guide = Harness.Guide()
    ctx.guide = guide
    local rxpData = { currentStep = 1 }
    ctx.rxpData = rxpData
    local arrow = { alpha = 1, shown = true }
    function arrow:SetAlpha(a) self.alpha = a end
    function arrow:SetShown(on) self.shown = on end
    function arrow:Show() self.shown = true end
    function arrow:Hide() self.shown = false end
    function arrow:IsShown() return self.shown end
    ctx.arrow = arrow
    local rxp = {
        guides = { guide, { name = "Hidden", group = "x", internal = true }, { name = "11-14 Darkshore", group = "*RestedXP Alliance 1-20" } },
        currentGuide = guide,
        IsGuideActive = function(g) return g.name ~= "Inactive" end,
        GetQuestName = function(id) return ({ [64] = "The Forgotten Heirloom", [36] = "Westfall Stew" })[id] end,
    }
    function rxp:LoadGuide(g) ctx.loaded = g end
    -- The guide moved to step n (from its menu: the button, then n).
    function rxp.SetStep(n, n2)
        if type(n) == "table" then n = n2 end
        ctx.setStep = n
        ctx.Point(n)
    end
    -- Its step menu: "Go to step" first, holding SetStep itself.
    rxp.RXPFrame = { bottomMenu = { { func = rxp.SetStep, arg1 = 1 }, { text = "Select another guide" } } }
    function ctx.GoToStep(i)
        local item = rxp.RXPFrame.bottomMenu[1]
        item.func({}, i)
    end
    if opts.broken then rxp.guides = nil end
    -- Its targeting: the lists its Active Targets panel shows, the panel,
    -- and the call after each rebuild of the lists.
    ctx.targetSets = 0
    ctx.rxpTargets = { talk = {}, mobs = {}, scan = {} }
    local panel = { shown = true }
    function panel:Show() self.shown = true end
    function panel:Hide() self.shown = false end
    function panel:SetShown(on) self.shown = on end
    ctx.panel = panel
    rxp.targeting = {
        activeTargetFrame = panel,
        GetCurrentTargets = function() return ctx.rxpTargets.talk, ctx.rxpTargets.mobs, ctx.rxpTargets.scan, {} end,
    }
    function rxp.targeting:UpdateMacro() end
    function rxp.targeting:UpdateTargetFrame() panel:Show() end
    -- Its lists rebuilt, as a step comes up.
    function ctx.SetTargets(talk, mobs)
        ctx.rxpTargets.talk, ctx.rxpTargets.mobs = talk or {}, mobs or {}
        rxp.targeting:UpdateMacro()
    end
    ctx.rxp = rxp
    -- Point the arrow at step i's spot, as RestedXP does as steps come up:
    -- shown first, its waypoint set after; none, hidden on the last one.
    function ctx.Point(i)
        for k, step in ipairs(guide.steps) do step.active = k == i end
        rxpData.currentStep = i
        local e
        for _, el in ipairs(guide.steps[i].elements) do
            if el.zone then e = el break end
        end
        if e then
            arrow:SetShown(true)
            arrow.element = e
        else
            arrow:Hide()
        end
    end

    local function Frame()
        local f = { events = {}, scripts = {} }
        function f:RegisterEvent(e) self.events[e] = true end
        function f:UnregisterEvent(e) self.events[e] = nil end
        function f:SetScript(k, fn) self.scripts[k] = fn end
        ctx.frames[#ctx.frames + 1] = f
        return f
    end
    local aceEvent = {
        Embed = function(_, target)
            function target:RegisterMessage(message, fn)
                ctx.messages[message] = ctx.messages[message] or {}
                table.insert(ctx.messages[message], fn)
            end
        end,
    }
    function ctx.Message(message, ...)
        for _, fn in ipairs(ctx.messages[message] or {}) do fn(message, ...) end
    end
    ctx.combat = false
    ctx.dead = false
    -- The player on a map (ctx.player = { map, x, y } in fractions); a map
    -- is 1000 yards a side.
    local function Vec(x, y) return { x = x, y = y, GetXY = function(v) return v.x, v.y end } end
    local env = setmetatable({
        CreateVector2D = Vec,
        C_Map = {
            GetPlayerMapPosition = function(map)
                local p = ctx.player
                if p and p.map == map then return Vec(p.x, p.y) end
            end,
            GetWorldPosFromMapPos = function(_, v) return 0, Vec(v.x * 1000, v.y * 1000) end,
        },
        EasyFind = { API = api },
        C_AddOns = { IsAddOnLoaded = function(name) return name == "RXPGuides" and opts.rxp ~= false end },
        C_Timer = { After = function(_, fn) ctx.timers[#ctx.timers + 1] = fn end },
        C_QuestLog = { GetTitleForQuestID = function() return nil end },
        CreateFrame = function() return Frame() end,
        GetLocale = function() return opts.locale or "enUS" end,
        InCombatLockdown = function() return ctx.combat end,
        UnitIsDeadOrGhost = function() return ctx.dead end,
        -- A post-hook on the table's own method, as the game's does.
        hooksecurefunc = function(t, key, hook)
            local orig = t[key]
            t[key] = function(...)
                local r = { orig(...) }
                hook(...)
                return table.unpack(r)
            end
        end,
        LibStub = function(name, silent)
            if name == "AceEvent-3.0" then return aceEvent end
            if not silent then error("no " .. name) end
        end,
        RXP = rxp,
        RXPG_ARROW = arrow,
        RXPCData = rxpData,
        print = function(...) ctx.printed[#ctx.printed + 1] = table.concat({ ... }, " ") end,
    }, { __index = _G })
    env._G = env
    ctx.env = env
    local _, files = Harness.Toc()
    local ns = {}
    for _, file in ipairs(files) do
        local chunk = assert(load(Harness.Read(file), "=" .. file, "t", env))
        chunk("EasyFind_RestedXP", ns)
    end
    ctx.ns = ns
    function ctx.Fire(event, ...)
        for _, f in ipairs(ctx.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end
    -- The timers due now, and any they set.
    function ctx.Settle()
        local n = 0
        while #ctx.timers > 0 and n < 20 do
            local due = ctx.timers
            ctx.timers = {}
            for _, fn in ipairs(due) do fn() end
            n = n + 1
        end
    end
    function ctx.Login()
        ctx.Fire("PLAYER_LOGIN")
        ctx.Settle()
    end
    return ctx
end

return Harness
