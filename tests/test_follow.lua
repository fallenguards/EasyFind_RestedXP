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

function T.aRouteOfThePlayersOwn_comesFirst_thenTheGuideAgain()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    ctx.PlayerRoute("Booty Bay")
    Eq(ctx.arrow.alpha, 1, "their route: its arrow back")
    ctx.Point(2)
    ctx.Settle()
    Eq(#ctx.navigated, 1, "the guide waits")
    ctx.ClearRoute()
    ctx.Settle()
    Eq(#ctx.navigated, 2, "their route over: the guide's again")
    Eq(Last(ctx).dest[1].name, "Verna Furlbrow")
end

function T.aGuideRouteThePlayerEnded_isNotStartedAgain()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
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
    Eq(#after.navigated, 0, "the same waypoint: the kept route stands")
    Eq(after.arrow.alpha, 0, "and it leads")
    local theirs = Harness.Load()
    theirs.gps.dest = { name = "Booty Bay", mapID = 1434, x = 0.4, y = 0.7 }
    theirs.Point(1)
    theirs.Login()
    Eq(#theirs.navigated, 0, "a route of their own kept: the guide waits")
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

return T
