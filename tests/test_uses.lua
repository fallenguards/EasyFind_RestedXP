-- RestedXP's Active Items under the GPS arrow: what its steps say to use
-- (an item, a spell, a macro), a button each, its own panel hidden with
-- its arrow meanwhile (asked for, 2026-11-21).
local Harness = require("Harness")
local Eq, True = Harness.Eq, Harness.True

local T = {}

local function Led()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    return ctx
end

function T.itsActiveItems_goUnderTheGPSArrow_itsPanelHidden()
    local ctx = Led()
    ctx.bags[1251] = 3
    ctx.spells[8690] = true
    ctx.rxp.activeItems[1251] = true
    ctx.rxp.activeSpells[8690] = true
    ctx.rxp.activeMacros["133685:Linen Bandages"] = "/cast Linen Bandage"
    ctx.rxp.UpdateItemFrame()
    Eq(#ctx.uses, 3)
    Eq(ctx.uses[1].kind, "spell", "spells first")
    Eq(ctx.uses[1].name, "Spell 8690")
    Eq(ctx.uses[2].kind, "macro")
    Eq(ctx.uses[2].name, "Linen Bandages")
    Eq(ctx.uses[2].icon, 133685)
    Eq(ctx.uses[2].macro, "/cast Linen Bandage", "its text, for the button to run")
    Eq(ctx.uses[3].kind, "item")
    Eq(ctx.uses[3].id, 1251)
    Eq(ctx.uses[3].name, "Item 1251")
    Eq(ctx.itemPanel.shown, false, "its panel hidden")
    local sets = ctx.useSets
    ctx.rxp.UpdateItemFrame()
    Eq(ctx.useSets, sets, "the same things: nothing sent again")
    Eq(ctx.itemPanel.shown, false, "and kept hidden when it redraws")
    ctx.rxp.activeItems, ctx.rxp.activeSpells, ctx.rxp.activeMacros = {}, {}, {}
    ctx.rxp.UpdateItemFrame()
    Eq(#ctx.uses, 0, "none left: the buttons go")
end

-- As its own panel: an item only while carried, a spell once known; one
-- the guide keeps shown either way.
function T.onlyWhatCanBeUsed_orWhatTheGuideKeepsShown()
    local ctx = Led()
    ctx.rxp.activeItems[1251] = true
    ctx.rxp.activeItems[6948] = "p"
    ctx.rxp.activeSpells[8690] = true
    ctx.rxp.activeMacros["0:No icon"] = "/dance"
    ctx.rxp.activeMacros["junk"] = "/sit"
    ctx.rxp.UpdateItemFrame()
    Eq(#ctx.uses, 2)
    Eq(ctx.uses[1].name, "No icon")
    Eq(ctx.uses[1].icon, 134400, "no icon of its own: the question mark")
    Eq(ctx.uses[2].id, 6948, "kept shown by the guide")
    ctx.bags[1251] = 1
    ctx.rxp.UpdateItemFrame()
    Eq(#ctx.uses, 3, "looted: its button comes")
end

function T.inAFight_theUsesWaitForItsEnd()
    local ctx = Led()
    ctx.combat = true
    ctx.rxp.activeItems[6948] = "p"
    ctx.rxp.UpdateItemFrame()
    Eq(ctx.uses, nil, "nothing in the fight")
    Eq(ctx.itemPanel.shown, true, "its panel as it was")
    ctx.combat = false
    ctx.Fire("PLAYER_REGEN_ENABLED")
    Eq(#ctx.uses, 1)
    Eq(ctx.itemPanel.shown, false)
end

function T.keepingItsArrow_keepsItsPanel_followingOff_noButtons()
    local ctx = Led()
    ctx.ns.Follow.SetHidesArrow(false)
    ctx.rxp.activeItems[6948] = "p"
    ctx.rxp.UpdateItemFrame()
    Eq(#ctx.uses, 1, "the buttons still")
    Eq(ctx.itemPanel.shown, true, "its panel kept")
    ctx.ns.Follow.SetHidesArrow(true)
    Eq(ctx.itemPanel.shown, false, "switched back: hidden at once")
    ctx.ns.Follow.SetOn(false)
    Eq(#ctx.uses, 0, "following off: no buttons")
    Eq(ctx.itemPanel.shown, true, "and its panel its own again")
end

function T.anOlderGPS_orAnUnreadableRestedXP_leavesItsPanelAlone()
    local old = Harness.Load({ gps = false })
    old.Point(1)
    old.Login()
    old.rxp.activeItems[6948] = "p"
    old.rxp.UpdateItemFrame()
    Eq(old.uses, nil)
    Eq(old.itemPanel.shown, true)
    True(old.ns.Reader.Uses()[1] ~= nil, "still read")
end

return T
