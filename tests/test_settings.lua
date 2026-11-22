-- The extension's settings page: its switches, the GPS arrow's box among
-- them (hidden from the box's own menu, it was looked for on this page,
-- 2026-11-18), and every switch's label short enough for its row (one cut
-- to "Hide RestedXP's arrow and ta...").
local Harness = require("Harness")
local Eq, True = Harness.Eq, Harness.True

local T = {}
local LOCALES = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
-- The keys a switch's label reads, and the room its row has: about 28
-- Latin letters (a cut showed at 28), a CJK or Hangul character two.
local SWITCHES = { "FOLLOW", "HIDE_ARROW", "OWN_ARROW", "BOX", "USE_ICONS", "TARGET_PAIRS", "DEATH_SKIP", "GRIND_XP",
                   "CIRCUITS" }
local ROOM = 28

-- The page built with a stand-in kit: its rows in order.
local function Page(ctx)
    local rows = {}
    local function Row(kind, label)
        local r = { kind = kind, label = label }
        function r.SetPoint() end
        rows[#rows + 1] = r
        return r
    end
    local kit = {}
    function kit.Title() return Row("title") end
    function kit.Checkbox(_, label, get, set, tooltip)
        local r = Row("check", label)
        r.get, r.set, r.tooltip = get, set, tooltip
        return r
    end
    function kit.Stepper(_, label) return Row("stepper", label) end
    ctx.extension.settings({}, kit)
    return rows
end

local function Find(rows, label)
    for _, r in ipairs(rows) do
        if r.label == label then return r end
    end
end

function T.theGPSArrowsBox_isSwitchedOnThisPage()
    local ctx = Harness.Load()
    local box = Find(Page(ctx), "Box under the arrow")
    True(box ~= nil, "the box's switch")
    True(box.tooltip ~= nil, "saying what the box is")
    True(box.get(), "shown")
    box.set(false)
    Eq(ctx.box, false, "hidden through the GPS")
    Eq(box.get(), false, "and read back")
    box.set(true)
    Eq(box.get(), true)
end

-- Its arrow on a route of the player's own: a switch under the hide one,
-- off until set (asked for, 2026-11-20).
function T.itsArrowOnTheirOwnRoutes_isSwitchedOnThisPage()
    local ctx = Harness.Load()
    local rows = Page(ctx)
    local own = Find(rows, "Show it on your own routes")
    True(own ~= nil, "the switch")
    True(own.tooltip ~= nil, "saying both arrows show")
    Eq(own.get(), false, "off until set")
    for i, r in ipairs(rows) do
        if r == own then Eq(rows[i - 1].label, "Hide RestedXP's arrow", "under the switch it changes") end
    end
    own.set(true)
    Eq(own.get(), true)
    Eq(ctx.env.EasyFindRestedXPDB.ownArrow, true, "kept")
    own.set(false)
    Eq(ctx.env.EasyFindRestedXPDB.ownArrow, nil, "off leaves nothing saved")
end

-- The GPS's buttons under its arrow, as asked: "allow these things to be
-- configured in the rxp extension settings" (2026-11-21).
function T.theButtonsUnderTheArrow_areSwitchedOnThisPage()
    local ctx = Harness.Load()
    local rows = Page(ctx)
    for _, x in ipairs({ { label = "Items to use as icons", action = "useIcons" },
                         { label = "Two targets to a row", action = "targetPairs" } }) do
        local row = Find(rows, x.label)
        True(row ~= nil, x.label)
        True(row.tooltip ~= nil, "saying what off does")
        True(row.get(), "on as the GPS has it")
        row.set(false)
        Eq(ctx.look[x.action], false, "set through the GPS")
        Eq(row.get(), false, "and read back")
        row.set(true)
        Eq(row.get(), true)
    end
    for i, r in ipairs(rows) do
        if r.label == "Items to use as icons" then Eq(rows[i - 1].label, "Box under the arrow", "under the box's switch") end
    end
end

function T.aGPSFromBeforeThem_showsNeither()
    local rows = Page(Harness.Load({ look = false }))
    Eq(Find(rows, "Items to use as icons"), nil)
    Eq(Find(rows, "Two targets to a row"), nil)
    True(Find(rows, "Box under the arrow") ~= nil, "the rest of the page stays")
end

function T.withoutTheGPSsBoxAction_noSwitch()
    local ctx = Harness.Load({ gps = false })
    Eq(Find(Page(ctx), "Box under the arrow"), nil)
end

-- The width a label takes, in Latin letters.
local function Width(text)
    local w = 0
    for _, code in utf8.codes(text) do
        w = w + ((code >= 0x1100 and code <= 0x11FF or code >= 0x2E80) and 2 or 1)
    end
    return w
end

function T.everySwitchLabel_fitsItsRow()
    for _, locale in ipairs(LOCALES) do
        local text = Harness.Read("Locales/" .. locale .. ".lua")
        for _, key in ipairs(SWITCHES) do
            local label = text:match('L%["' .. key .. '"%] = "(.-)"\r?\n')
            if label then
                True(Width(label) <= ROOM, locale .. " " .. key .. " is " .. Width(label) .. " wide: " .. label)
            end
        end
    end
end

return T
