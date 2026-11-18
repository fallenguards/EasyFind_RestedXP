-- Reader.lua: RestedXP's guide, steps and arrow read as plain values.
local Harness = require("Harness")
local Eq, True = Harness.Eq, Harness.True

local T = {}

function T.aGuideLine_readsAsPlainWords()
    local R = Harness.Load().ns.Reader
    Eq(R.Clean(">>|Tinterface/worldmap/chatbubble_64grey.blp:20|tTalk to |cRXP_FRIENDLY_Farmer Furlbrow|r"),
        "Talk to Farmer Furlbrow")
    Eq(R.Clean("|cff00ff25Kill|r boars\nthen more"), "Kill boars", "a color code and the second line gone")
    Eq(R.Clean(">>  "), nil, "nothing left: nil")
end

function T.aQuestPlaceholder_takesTheQuestsName()
    local ctx = Harness.Load()
    local step = ctx.guide.steps[1]
    Eq(ctx.ns.Reader.StepText(step, step.elements[2]), "Accept The Forgotten Heirloom")
    Eq(ctx.ns.Reader.StepText(step), "Talk to Farmer Furlbrow", "the step's first line with words")
end

function T.theTarget_isTheArrowsWaypoint_whileItsStepIsOn()
    local ctx = Harness.Load()
    local R = ctx.ns.Reader
    ctx.Point(1)
    Eq(R.Target(), ctx.guide.steps[1].elements[1])
    ctx.guide.steps[1].elements[1].completed = true
    Eq(R.Target(), nil, "reached")
    ctx.guide.steps[1].elements[1].completed = nil
    ctx.guide.steps[1].active = false
    Eq(R.Target(), nil, "its step done: the arrow's leftover")
    ctx.arrow.element = { zone = 1436, x = 50, y = 50 }
    Eq(R.Target(), nil, "the corpse's: no step")
end

function T.aWaypoint_asTheGPSTakesIt()
    local ctx = Harness.Load()
    local R = ctx.ns.Reader
    local d = R.Dest(ctx.guide.steps[1].elements[1])
    Eq(d.name, "Farmer Furlbrow", "named after the creature the step targets")
    Eq(d.npcName, "Farmer Furlbrow", "for the Target button")
    Eq(d.mapID, 1436)
    True(math.abs(d.x - 0.5995) < 1e-9 and math.abs(d.y - 0.1935) < 1e-9, "hundredths to map fractions")
    Eq(d.step, "Talk to Farmer Furlbrow", "the last step's words")
    Eq(d.questMark, "offer")
    Eq(d.questID, nil, "a quest still to take is in no log")
    True(d.quietArrival, "the guide moves straight on")
    local last = R.Dest(ctx.guide.steps[5].elements[1])
    Eq(last.questMark, "turnin")
    Eq(last.questID, 64)
    local plain = R.Dest(ctx.guide.steps[3].elements[1])
    Eq(plain.name, "Travel to Saldean's Farm", "no creature: its words")
    Eq(plain.npcName, nil)
end

function T.ahead_areTheNextStepsSpots_skippingStepsWithNone()
    local ctx = Harness.Load()
    local R = ctx.ns.Reader
    local from = ctx.guide.steps[1].elements[1]
    local two = R.Ahead(from, 2)
    Eq(#two, 2)
    Eq(two[1].step.index, 2)
    Eq(two[2].step.index, 3)
    local three = R.Ahead(from, 3)
    Eq(three[3].step.index, 5, "step 4 has no spot")
    Eq(#R.Ahead(from, 0), 0)
end

function T.itsGuides_asItsMenuOffersThem()
    local ctx = Harness.Load()
    local R = ctx.ns.Reader
    local guides = R.Guides()
    Eq(#guides, 2, "an internal guide is left out")
    Eq(R.GroupName(guides[2]), "RestedXP Alliance 1-20", "its group's marker gone")
end

function T.aVersionReadOtherwise_isNotReady()
    True(Harness.Load().ns.Reader.Ready())
    True(not Harness.Load({ broken = true }).ns.Reader.Ready())
end

return T
