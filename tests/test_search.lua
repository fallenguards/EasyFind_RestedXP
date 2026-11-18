-- RestedXP.lua: its guides and the loaded guide's steps as rows, and
-- EasyFind's quest and bag rows marked with the step that takes them.
local Harness = require("Harness")
local Eq, True = Harness.Eq, Harness.True

local T = {}

local function Decorator(ctx) return ctx.decorators[1] end

function T.itsGuides_areRows_aClickLoadsOne()
    local ctx = Harness.Load()
    local p = ctx.providers.rxpguides
    True(p.eager, "a short list, searched from the first key")
    local rows = p.rows()
    Eq(#rows, 2)
    Eq(rows[1].name, "13-15 Westfall")
    Eq(rows[1].searchCommandDesc, "RestedXP guide: RestedXP Alliance 1-20")
    Eq(rows[2].name, "11-14 Darkshore")
    p.select(rows[2])
    Eq(ctx.loaded, ctx.rxp.guides[3])
end

function T.theGuidesSteps_areRows_foundByTheirCreaturesAndQuests()
    local ctx = Harness.Load()
    local p = ctx.providers.rxpsteps
    True(p.lowResults, "found by plain search")
    local rows = p.rows()
    Eq(#rows, 5)
    Eq(rows[1].name, "Talk to Farmer Furlbrow")
    Eq(rows[1].searchCommandDesc, "Step 1 of 13-15 Westfall")
    local words = table.concat(rows[1].keywordsLower, "|")
    True(words:find("farmer furlbrow", 1, true) and words:find("the forgotten heirloom", 1, true), words)
    Eq(rows[1].mapID, 1436, "its place answers too")
    Eq(rows[4].name, "Collect Okra")
    Eq(rows[4].mapID, nil)
end

function T.aStep_jumpsTheGuide_andItsSpotTakesTheGPSButton()
    local ctx = Harness.Load()
    local p = ctx.providers.rxpsteps
    local rows = p.rows()
    p.select(rows[3])
    Eq(ctx.setStep, 3)
    local spot = p.place(rows[3])
    Eq(spot.mapID, 1436)
    True(math.abs(spot.x - 0.5604) < 1e-9)
    Eq(p.place(rows[4]), nil, "no spot: no GPS button")
end

function T.theStepsPage_listsWhatIsAhead()
    local ctx = Harness.Load()
    local p = ctx.providers.rxpsteps
    local rows = p.rows()
    ctx.Point(3)
    True(not p.browse(rows[2]), "behind")
    True(p.browse(rows[3]) and p.browse(rows[5]))
    Eq(ctx.extension.scope, "rxpsteps", "the tile opens it")
end

function T.aQuestRow_namesTheStepThatTakesIt()
    local ctx = Harness.Load()
    local d = Decorator(ctx)
    local quest = { name = "The Forgotten Heirloom", questId = 64 }
    ctx.Point(1)
    True(d.applies(quest))
    Eq(d.subtext(quest), "RestedXP: step 1")
    ctx.Point(3)
    Eq(d.subtext(quest), "RestedXP: step 5", "the next mention from the step the guide is on")
    ctx.rxpData.currentStep = 9
    Eq(d.subtext(quest), "RestedXP: step 5", "past them all: its last")
    local menu = d.menu(quest)
    Eq(menu[1].label, "Go to step 5")
    menu[1].onClick()
    Eq(ctx.setStep, 5)
    True(not d.applies({ name = "Hogger", questId = 176 }), "a quest the guide never takes")
end

function T.aBagItem_aLaterStepNeeds_isMarked()
    local ctx = Harness.Load()
    local d = Decorator(ctx)
    local okra = { name = "Okra", itemID = 732, category = "Bag" }
    ctx.Point(1)
    Eq(d.subtext(okra), "RestedXP: step 4 needs 4")
    True(not d.applies({ name = "Okra", itemID = 732, category = "Item" }), "the catalog's row: not one you hold")
    ctx.rxpData.currentStep = 5
    True(not d.applies(okra), "its step is behind: nothing to keep it for")
end

function T.aNewGuide_rebuildsTheStepRows_aNewStepOnlyRepaints()
    local ctx = Harness.Load()
    ctx.Login()
    ctx.providers.rxpsteps.rows()
    ctx.Message("RXPGuidesV2_UpdateActiveSteps")
    Eq(#ctx.refreshed, 0, "same guide: the rows stand")
    True(ctx.repaints >= 1, "the marks are read again")
    ctx.rxp.currentGuide = Harness.Guide()
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    Eq(ctx.refreshed[1], "rxpsteps")
end

function T.withoutRestedXP_nothingIsRegistered()
    local ctx = Harness.Load({ rxp = false })
    Eq(ctx.extension, nil)
    Eq(next(ctx.providers), nil)
    Eq(#ctx.decorators, 0)
end

function T.anOlderEasyFind_saysSo_andRegistersNothing()
    local ctx = Harness.Load({ minor = 12 })
    Eq(ctx.extension, nil)
    True(ctx.printed[1] and ctx.printed[1]:find("newer EasyFind", 1, true), "said in chat")
end

function T.anUnreadableRestedXP_saysSoAtLogin()
    local ctx = Harness.Load({ broken = true })
    ctx.Login()
    True(ctx.printed[1] and ctx.printed[1]:find("cannot be read", 1, true), "said in chat")
end

return T
