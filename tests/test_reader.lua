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

-- Undead 6-12 Tirisfal (Forever, 2026-11-18): "Talk toJohaan", and a name
-- whose color tag holds a space.
function T.aNameRightAfterAWord_orWithASpaceInItsTag_readsSpaced()
    local R = Harness.Load().ns.Reader
    Eq(R.Clean(">>|Tinterface/worldmap/chatbubble_64grey.blp:20|tTalk to|cRXP_FRIENDLY_Johaan|r"), "Talk to Johaan")
    Eq(R.Clean(".deathskip >> Die and respawn at the |cRXP_FRIENDLY_ Spirit Healer|r"),
        ".deathskip >> Die and respawn at the Spirit Healer")
    Eq(R.Clean(">>Die and respawn at the |cRXP_FRIENDLY_ Spirit Healer|r"), "Die and respawn at the Spirit Healer")
end

-- Zephras Isle's Skyborne guide (Forever, 2026-11-18): a stop came out
-- named "1" (a loop's "+1" line) and another "Kill Al'Aketh Brutes::251145".
function T.creatureIds_andWordlessLines_areNoText()
    local R = Harness.Load().ns.Reader
    Eq(R.Clean(">>Kill |cRXP_ENEMY_Al'Aketh Brutes::251145|r and |cRXP_ENEMY_Al'Aketh Neophytes::251448|r."),
        "Kill Al'Aketh Brutes and Al'Aketh Neophytes.")
    Eq(R.Clean("+1"), nil, "a loop's count is no line")
end

-- A step the guide hides (its loop beside the shown one) gives no stop,
-- nor a spot where the stop before stands; each stop holds the GPS.
function T.ahead_skipsHiddenSteps_andTheSameSpot_stopsHold()
    local ctx = Harness.Load()
    local R = ctx.ns.Reader
    local steps = ctx.guide.steps
    steps[2].hidewindow = true
    steps[3].elements[1].x, steps[3].elements[1].y = 59.95, 19.36
    ctx.Point(1)
    local ahead = R.Ahead(R.Target(), 2)
    Eq(#ahead, 1, "step 2 hidden, step 3 where step 1 stands, step 4 has no spot")
    Eq(ahead[1].step.index, 5)
    Eq(R.Dest(steps[1].elements[1]).hold, true, "the GPS stays on it till the guide moves on")
end

-- Veena Vericloud's step (Skyborne, Forever, 2026-11-18) has no .target:
-- its .vendor and its text name her; RestedXP's own panel left her out.
function T.aStepWithNoTarget_namesItsVendor_andLeadsTheTargets()
    local ctx = Harness.Load()
    local R = ctx.ns.Reader
    local step = ctx.guide.steps[3]
    step.elements = {
        { tag = "goto", zone = 1436, x = 44.72, y = 45.47, step = step,
          text = ">>Talk to |cRXP_FRIENDLY_Veena Vericloud::254358|r." },
        { tag = "vendor", id = 254358, text = "Vendor trash", step = step },
    }
    Eq(R.TargetName(step), "Veena Vericloud", "from its vendor line, named as its text spells it")
    step.elements[2] = nil
    Eq(R.TargetName(step), "Veena Vericloud", "from its text alone")
    ctx.Point(3)
    ctx.rxpTargets.talk, ctx.rxpTargets.mobs = { "Constable Aonda" }, { "Galestrider" }
    local list = R.Targets(R.Target())
    Eq(list[1].name, "Veena Vericloud", "the step's own creature first")
    Eq(list[1].kind, "talk")
    Eq(list[2].name, "Constable Aonda")
    Eq(#list, 3)
    Eq(R.Dest(step.elements[1]).npcName, "Veena Vericloud", "the route's Target button is hers")
end

function T.aQuestPlaceholder_takesTheQuestsName()
    local ctx = Harness.Load()
    local step = ctx.guide.steps[1]
    Eq(ctx.ns.Reader.StepText(step, step.elements[2]), "Accept The Forgotten Heirloom")
    Eq(ctx.ns.Reader.StepText(step), "Talk to Farmer Furlbrow", "the step's first line with words")
end

-- Whatever its shown arrow points at: a done spot stays on it while its
-- step lasts, and the GPS refused step 56 of 21-22 Wailing Caverns while
-- RestedXP's own arrow pointed there (Forever, 2026-11-18).
function T.theTarget_isTheShownArrowsWaypoint()
    local ctx = Harness.Load()
    local R = ctx.ns.Reader
    ctx.Point(1)
    local e = ctx.guide.steps[1].elements[1]
    Eq(R.Target(), e)
    e.completed = true
    Eq(R.Target(), e, "done, still on the arrow")
    ctx.arrow:Hide()
    Eq(R.Target(), nil, "hidden: the arrow's leftover")
    ctx.arrow:SetShown(true)
    ctx.arrow.element = { title = "Corpse", wx = 1, wy = 2, instance = 0 }
    Eq(R.Target(), nil, "the corpse's: no map spot")
end

-- Its arrow switched off in its settings: the waypoint it would show.
function T.itsArrowSwitchedOff_theWaypointItWouldShow()
    local ctx = Harness.Load()
    local R = ctx.ns.Reader
    ctx.rxp.settings = { profile = { disableArrow = true, showEnabled = true } }
    ctx.Point(1)
    ctx.arrow:SetShown(false)
    local e = ctx.guide.steps[1].elements[1]
    e.arrow = true
    Eq(R.Target(), e)
    e.text, e.completed = "Talk to Farmer Furlbrow", true
    Eq(R.Target(), nil, "its line done")
    e.text, e.completed = nil, nil
    ctx.guide.steps[1].active = false
    Eq(R.Target(), nil, "its step over")
    ctx.guide.steps[1].active = true
    ctx.rxp.hideArrow = true
    Eq(R.Target(), nil, "no waypoints left")
    ctx.rxp.hideArrow = nil
    ctx.rxp.settings.profile.showEnabled = false
    Eq(R.Target(), nil, "RestedXP's guide shown off")
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
