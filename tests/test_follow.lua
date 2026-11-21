-- Follow.lua: the GPS following the guide, giving way to the player's own
-- routes, and RestedXP's arrow faded while the GPS leads.
local Harness = require("Harness")
local Eq, True = Harness.Eq, Harness.True

local T = {}

local function Last(ctx) return ctx.navigated[#ctx.navigated] end

function T.atLogin_theGPSLeadsToTheWaypoint_andTheNextTwo()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    Eq(#ctx.navigated, 1)
    local sent = Last(ctx)
    Eq(sent.action, "navigateTrip")
    Eq(#sent.dest, 3, "the waypoint and the next two")
    Eq(sent.dest[1].name, "Farmer Furlbrow")
    Eq(sent.dest[3].name, "Travel to Saldean's Farm")
    True(sent.opts.quiet, "the GPS window is not opened")
    Eq(ctx.arrow.alpha, 0, "its arrow faded while the GPS leads")
    ctx.arrow:SetAlpha(1)
    Eq(ctx.arrow.alpha, 0, "its own drawing does not bring it back")
end

-- The Hearthstone only where the guide says to hearth (2026-11-19: the
-- GPS hearthed on "Travel back to Brill", whose cooldown the guide plans
-- around): every route leaves it out until a step the guide is on says
-- .hs, and that change alone sends the same spots again.
function T.theHearthstone_onlyWhereTheGuideSaysToHearth()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    True(Last(ctx).opts.avoid and Last(ctx).opts.avoid.hearth, "left out")
    local sent = #ctx.navigated
    local step = ctx.guide.steps[1]
    local hs = { tag = "hs", text = "Hearth to Brill", step = step }
    step.elements[#step.elements + 1] = hs
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    ctx.Settle()
    Eq(#ctx.navigated, sent + 1, "the same spots sent again")
    Eq(Last(ctx).opts.avoid.hearth, nil, "the guide says to hearth: the GPS may")
    hs.completed = true
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    ctx.Settle()
    True(Last(ctx).opts.avoid and Last(ctx).opts.avoid.hearth, "hearthed: left out again")
end

-- Flight paths the same way (2026-11-19): between its flights the guide
-- walks, for what it has done on the way, so a flight path only while a
-- step it is on says .fly, until it lands.
function T.flightPaths_onlyWhereTheGuideSaysToFly()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    True(Last(ctx).opts.avoid and Last(ctx).opts.avoid.taxi, "left out")
    local sent = #ctx.navigated
    local step = ctx.guide.steps[1]
    local fly = { tag = "fly", text = "Fly to The Crossroads", step = step }
    step.elements[#step.elements + 1] = fly
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    ctx.Settle()
    Eq(#ctx.navigated, sent + 1, "the same spots sent again")
    local avoid = Last(ctx).opts.avoid
    Eq(avoid.taxi, nil, "the guide says to fly: the GPS may")
    True(avoid.hearth, "the Hearthstone still left out")
    local hs = { tag = "hs", text = "Hearth to Brill", step = step }
    step.elements[#step.elements + 1] = hs
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    ctx.Settle()
    Eq(Last(ctx).opts.avoid, nil, "both said: nothing left out")
    fly.completed, hs.completed = true, true
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    ctx.Settle()
    True(Last(ctx).opts.avoid.taxi and Last(ctx).opts.avoid.hearth, "landed: both left out again")
end

function T.eachNewWaypoint_isLedTo_once()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.Point(1)
    ctx.Settle()
    Eq(#ctx.navigated, 1, "the same waypoint: no new route")
    ctx.Point(2)
    ctx.Settle()
    Eq(#ctx.navigated, 2)
    Eq(Last(ctx).dest[1].name, "Verna Furlbrow")
end

-- Their own route holds while the arrow stays on its waypoint; the next
-- waypoint takes the GPS back (2026-11-18).
function T.aRouteOfThePlayersOwn_holdsUntilTheArrowMovesOn()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.PlayerRoute("Booty Bay")
    Eq(ctx.arrow.alpha, 0, "their route: the GPS arrow alone")
    ctx.Point(1)
    ctx.Settle()
    Eq(#ctx.navigated, 1, "the same waypoint: their route holds")
    ctx.Point(2)
    ctx.Settle()
    Eq(#ctx.navigated, 2, "the next waypoint: the guide's again")
    Eq(Last(ctx).dest[1].name, "Verna Furlbrow")
    Eq(ctx.arrow.alpha, 0, "and it leads")
end

function T.aRouteOfThePlayersOwnEnded_theGuidesAgain()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.PlayerRoute("Booty Bay")
    ctx.ClearRoute()
    ctx.Settle()
    Eq(#ctx.navigated, 2, "their route over: the same waypoint led again")
    Eq(Last(ctx).dest[1].name, "Farmer Furlbrow")
end

-- Both arrows showed on a route of the player's own, each its own way
-- (Forever, 2026-11-20): one arrow while the GPS has any route, RestedXP's
-- back once it has none.
function T.aRouteOfThePlayersOwn_showsOneArrow()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.PlayerRoute("Booty Bay")
    ctx.Point(1)
    ctx.Settle()
    Eq(ctx.arrow.alpha, 0, "held on the same waypoint: still the GPS arrow alone")
    ctx.arrow:SetAlpha(1)
    Eq(ctx.arrow.alpha, 0, "its own drawing does not bring it back")
    ctx.holdStart = true
    ctx.ClearRoute()
    Eq(ctx.arrow.alpha, 1, "no route: its arrow its own")
    local kept = Harness.Load()
    kept.gps.dest = { name = "Booty Bay", mapID = 1434, x = 0.4, y = 0.7 }
    kept.Point(1)
    kept.Login()
    Eq(kept.arrow.alpha, 0, "their route kept over a reload: the same")
    local off = Harness.Load()
    off.ns.Follow.SetOn(false)
    off.Point(1)
    off.Login()
    off.PlayerRoute("Booty Bay")
    Eq(off.arrow.alpha, 1, "following off: its arrow is never touched")
end

-- Started while the arrow showed nothing: its first waypoint takes over.
function T.aRouteOfThePlayersOwn_withNoWaypointShown()
    local ctx = Harness.Load()
    ctx.Login()
    ctx.PlayerRoute("Booty Bay")
    ctx.Point(1)
    ctx.Settle()
    Eq(#ctx.navigated, 1)
end

-- Cleared to reset it, the guide's route stayed off and the player saw a
-- broken follow (Forever, 2026-11-18): a clear leads again from here; the
-- Follow switch is what turns the guide off.
function T.aGuideRouteThePlayerCleared_isLedAgain()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.ClearRoute()
    ctx.Settle()
    Eq(#ctx.navigated, 2, "the same waypoint led again")
    Eq(Last(ctx).dest[1].name, "Farmer Furlbrow")
end

-- Arrived at, the route the GPS clears itself stays ended for that waypoint.
function T.aGuideRouteArrivedAt_isNotStartedAgain()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.FireGPS("arrived", ctx.gps.dest)
    ctx.ClearRoute()
    ctx.Point(1)
    ctx.Settle()
    Eq(#ctx.navigated, 1, "the same waypoint stays ended")
    ctx.Point(2)
    ctx.Settle()
    Eq(#ctx.navigated, 2, "the next one leads again")
end

function T.leadNow_leadsAgain()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.ClearRoute()
    ctx.ns.Follow.LeadNow()
    Eq(#ctx.navigated, 2)
end

-- Its log on Forever (2026-11-18): the player's own route held, its arrow
-- on a done spot of the step before, Lead now sent nothing.
function T.leadNow_overTheirRoute_toADoneSpotOnTheArrow()
    local ctx = Harness.Load()
    ctx.gps.dest = { name = "The Glowing Shard", mapID = 1413, x = 0.482, y = 0.328 }
    ctx.Point(1)
    ctx.guide.steps[1].elements[1].completed = true
    ctx.Login()
    Eq(#ctx.navigated, 0, "their route kept: it holds on this waypoint")
    ctx.ns.Follow.LeadNow()
    Eq(#ctx.navigated, 1)
    Eq(Last(ctx).dest[1].name, "Farmer Furlbrow")
end

-- Its arrow kept a spot of the step before while the guide went on to one
-- with none (the book's shelf by Carolai Anise, Forever, 2026-11-18): the
-- GPS goes there with the guide's step's words, sent anew as they change.
function T.aSpotOfAStepGoneBy_speaksForTheStepTheGuideIsOn()
    local ctx = Harness.Load()
    ctx.Point(3)
    ctx.Login()
    Eq(Last(ctx).dest[1].name, "Travel to Saldean's Farm")
    for k, step in ipairs(ctx.guide.steps) do step.active = k == 4 end
    ctx.rxpData.currentStep = 4
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    ctx.Settle()
    Eq(#ctx.navigated, 2, "the same spot, new words: sent again")
    local d = Last(ctx).dest[1]
    Eq(d.name, "Collect Okra", "the step the guide is on")
    True(math.abs(d.x - 0.5604) < 1e-9, "at the spot its arrow kept")
    Eq(Last(ctx).dest[2].name, "Gryan Stoutmantle", "the stops after keep their own")
end

-- Step 40, "Loot the Book in the shelf", has no spot and its arrow hides,
-- keeping step 39's by the shelf (its log, Forever, 2026-11-18): the
-- player standing there is led there with step 40's words; away from it,
-- nothing (a hearth step must not lead back to the last quest).
function T.aStepWithNoSpot_keepsTheSpotBefore_whileThePlayerStandsByIt()
    local ctx = Harness.Load()
    ctx.rxp.settings = { profile = { showEnabled = true } }
    ctx.player = { map = 1436, x = 0.5600, y = 0.3120 }
    ctx.Point(3)
    ctx.Login()
    ctx.Point(4)
    ctx.Settle()
    Eq(ctx.cleared, nil, "not taken away")
    Eq(#ctx.navigated, 2)
    Eq(Last(ctx).dest[1].name, "Collect Okra", "the words of the step it is on")
    True(math.abs(Last(ctx).dest[1].x - 0.5604) < 1e-9, "at the spot kept")
    local away = Harness.Load()
    away.rxp.settings = { profile = { showEnabled = true } }
    away.player = { map = 1436, x = 0.30, y = 0.80 }
    away.Point(3)
    away.Login()
    away.Point(4)
    away.Settle()
    Eq(away.cleared, 1, "far from it: the route goes")
end

-- Go to step on the step it is on put nothing right (2026-11-18): a pick
-- in its step menu leads again, over a route of the player's own too.
function T.goToStep_theStepItIsOn_leadsAgain()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.GoToStep(1)
    ctx.Settle()
    Eq(#ctx.navigated, 2, "the same step: led again")
    Eq(ctx.setStep, 1, "its own step change ran first")
    ctx.PlayerRoute("Booty Bay")
    ctx.GoToStep(1)
    ctx.Settle()
    Eq(#ctx.navigated, 3, "over their route")
    Eq(Last(ctx).dest[1].name, "Farmer Furlbrow")
    ctx.GoToStep(2)
    ctx.Settle()
    Eq(Last(ctx).dest[1].name, "Verna Furlbrow", "another step: led there")
end

-- A step with no waypoint and none kept: the guide's route goes, so the
-- GPS never points at a step the guide has left.
function T.aStepWithNoWaypoint_takesTheGuidesRouteAway()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.Point(4)
    ctx.Settle()
    Eq(ctx.cleared, 1, "the route cleared")
    Eq(#ctx.navigated, 1, "and nothing sent")
    Eq(ctx.arrow.alpha, 1, "its arrow its own")
    ctx.Point(5)
    ctx.Settle()
    Eq(#ctx.navigated, 2, "the next waypoint leads")
    Eq(Last(ctx).action, "navigate", "the guide's last: one stop")
    Eq(Last(ctx).dest.name, "Gryan Stoutmantle")
    local theirs = Harness.Load()
    theirs.Point(1)
    theirs.Login()
    theirs.PlayerRoute("Booty Bay")
    theirs.Point(4)
    theirs.Settle()
    Eq(theirs.cleared, nil, "a route of the player's own is never cleared")
end

function T.switchedOff_nothingIsLed_andItsArrowStays()
    local ctx = Harness.Load()
    ctx.ns.Follow.SetOn(false)
    ctx.Point(1)
    ctx.Login()
    Eq(#ctx.navigated, 0)
    Eq(ctx.arrow.alpha, 1)
end

function T.keepingItsArrow_leavesItShown()
    local ctx = Harness.Load()
    ctx.ns.Follow.SetHidesArrow(false)
    ctx.Point(1)
    ctx.Login()
    Eq(#ctx.navigated, 1)
    Eq(ctx.arrow.alpha, 1)
end

function T.noWaypointsAhead_orAnOlderGPS_oneDestination()
    local ctx = Harness.Load()
    ctx.ns.Follow.SetAhead(0)
    ctx.Point(1)
    ctx.Login()
    Eq(Last(ctx).action, "navigate")
    Eq(Last(ctx).dest.name, "Farmer Furlbrow")
    local old = Harness.Load({ trip = false })
    old.Point(1)
    old.Login()
    Eq(Last(old).action, "navigate")
end

function T.inAFight_itWaitsForTheEnd()
    local ctx = Harness.Load()
    ctx.combat = true
    ctx.Point(1)
    ctx.Login()
    Eq(#ctx.navigated, 0)
    ctx.combat = false
    ctx.Fire("PLAYER_REGEN_ENABLED")
    Eq(#ctx.navigated, 1)
end

function T.dead_theGPSsCorpseRunIsLeftAlone()
    local ctx = Harness.Load()
    ctx.dead = true
    ctx.Point(1)
    ctx.Login()
    Eq(#ctx.navigated, 0)
    ctx.dead = false
    ctx.Fire("PLAYER_ALIVE")
    ctx.Settle()
    Eq(#ctx.navigated, 1, "alive: the guide again")
end

function T.aRouteKeptOverAReload_isKnownAsTheGuides()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    local char = ctx.env.EasyFindRestedXPCharDB
    local after = Harness.Load()
    after.env.EasyFindRestedXPCharDB = char
    after.gps.dest = ctx.gps.dest
    after.Point(1)
    after.Login()
    -- Sent again as this version plans it: one kept from an older version
    -- walked on past the guide's stop for the rest of the session.
    Eq(#after.navigated, 1, "the guide's kept route sent again")
    Eq(Last(after).dest[1].name, "Farmer Furlbrow")
    Eq(after.arrow.alpha, 0, "and it leads")
    local theirs = Harness.Load()
    theirs.gps.dest = { name = "Booty Bay", mapID = 1434, x = 0.4, y = 0.7 }
    theirs.Point(1)
    theirs.Login()
    Eq(#theirs.navigated, 0, "a route of their own kept: it holds on the same waypoint")
    theirs.Point(2)
    theirs.Settle()
    Eq(#theirs.navigated, 1, "the next waypoint takes over")
end

-- The waypoint their route held at is kept over a reload.
function T.aRouteOfThePlayersOwn_holdsOverAReload()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.PlayerRoute("Booty Bay")
    local after = Harness.Load()
    after.env.EasyFindRestedXPCharDB = ctx.env.EasyFindRestedXPCharDB
    after.gps.dest = ctx.gps.dest
    after.Login()
    after.Point(1)
    after.Settle()
    Eq(#after.navigated, 0, "the arrow back on the same waypoint: theirs holds")
    after.Point(2)
    after.Settle()
    Eq(#after.navigated, 1)
end

function T.withoutTheGPS_orAnUnreadableRestedXP_nothingIsLed()
    local ctx = Harness.Load({ gps = false })
    ctx.Point(1)
    ctx.Login()
    Eq(#ctx.navigated, 0)
    local broken = Harness.Load({ broken = true })
    broken.Point(1)
    broken.Login()
    Eq(#broken.navigated, 0)
end

-- Its Active Targets under the GPS arrow, its own panel hidden with its
-- arrow meanwhile (2026-11-18). On step 3, which names no creature of its
-- own (test_reader covers a step's own leading the list).
function T.itsTargets_goUnderTheGPSArrow_itsPanelHidden()
    local ctx = Harness.Load()
    ctx.Point(3)
    ctx.Login()
    ctx.SetTargets({ "Bareth Dawnstone" }, { "Scarlet Warrior" })
    ctx.Settle()
    Eq(#ctx.targets, 2)
    Eq(ctx.targets[1].name, "Bareth Dawnstone")
    Eq(ctx.targets[1].kind, "talk")
    Eq(ctx.targets[2].kind, "kill")
    Eq(ctx.panel.shown, false, "its panel hidden")
    ctx.rxp.targeting:UpdateTargetFrame()
    Eq(ctx.panel.shown, false, "and kept so when it redraws")
    local sets = ctx.targetSets
    ctx.SetTargets({ "Bareth Dawnstone" }, { "Scarlet Warrior" })
    ctx.Settle()
    Eq(ctx.targetSets, sets, "the same creatures: nothing sent again")
    ctx.SetTargets({}, {})
    ctx.Settle()
    Eq(#ctx.targets, 0, "none left: the buttons go")
    Eq(ctx.panel.shown, true, "and its panel is its own again")
end

function T.keepingItsArrow_keepsItsPanel_followingOff_noButtons()
    local ctx = Harness.Load()
    ctx.Point(3)
    ctx.Login()
    ctx.ns.Follow.SetHidesArrow(false)
    ctx.SetTargets({}, { "Scarlet Warrior" })
    ctx.Settle()
    Eq(#ctx.targets, 1, "the buttons still")
    Eq(ctx.panel.shown, true, "its panel kept")
    ctx.ns.Follow.SetOn(false)
    Eq(#ctx.targets, 0, "following off: no buttons")
end

function T.inAFight_theTargetsWaitForItsEnd()
    local ctx = Harness.Load()
    ctx.Point(3)
    ctx.Login()
    ctx.combat = true
    ctx.SetTargets({}, { "Scarlet Warrior" })
    ctx.Settle()
    Eq(ctx.targets, nil, "nothing in the fight")
    ctx.combat = false
    ctx.Fire("PLAYER_REGEN_ENABLED")
    Eq(#ctx.targets, 1)
    Eq(ctx.panel.shown, false)
end

return T
