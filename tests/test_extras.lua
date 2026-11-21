-- What the guide's steps lay over the GPS (2026-11-18), each by its own
-- switch: a death skip leads a ghost to the Spirit Healer, a grind step's
-- XP shows under the step, a loop step's circuit is drawn on the maps.
local Harness = require("Harness")
local Eq, True = Harness.Eq, Harness.True

local T = {}

local function Step(ctx, i) return ctx.guide.steps[i] end
local function Add(step, e)
    e.step = step
    step.elements[#step.elements + 1] = e
    return e
end

function T.aDeathSkip_onAStepTheGuideIsOn_isTheGPSs()
    local ctx = Harness.Load()
    ctx.Point(1)
    ctx.Login()
    Eq(ctx.deathSkip, false, "none yet")
    Add(Step(ctx, 1), { tag = "deathskip", text = "Die and respawn at the |cRXP_FRIENDLY_ Spirit Healer|r" })
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    ctx.Settle()
    -- The step's own spot goes with it: the GPS knows no Spirit Healer on
    -- Zephras Isle and led its ghosts to their corpses (2026-11-21).
    Eq(type(ctx.deathSkip), "table", "the guide says to die: set, with where its healer stands")
    Eq(ctx.deathSkip.mapID, Step(ctx, 1).elements[1].zone)
    True(math.abs(ctx.deathSkip.x - Step(ctx, 1).elements[1].x / 100) < 1e-9, "the step's own spot")
    ctx.ns.Follow.SetExtra("deathSkip", false)
    Eq(ctx.deathSkip, false, "its switch off: not")
    ctx.ns.Follow.SetExtra("deathSkip", true)
    Eq(type(ctx.deathSkip), "table")
    ctx.Point(2)
    ctx.Settle()
    Eq(ctx.deathSkip, false, "the step gone: not")
    -- A death skip step with no spot of its own: set all the same.
    Add(Step(ctx, 4), { tag = "deathskip", text = "Die and respawn" })
    ctx.Point(4)
    for k, step in ipairs(ctx.guide.steps) do step.active = k == 4 end
    ctx.Message("RXPGuidesV2_GuideStepsChanged")
    ctx.Settle()
    Eq(ctx.deathSkip, true, "no spot on the step: the GPS looks for the healer itself")
end

-- "Grind to 895+/1400xp" (.xp 3+895): at level 3, the XP toward 895.
function T.aGrindStep_showsTheXPTowardItsGoal()
    local ctx = Harness.Load()
    Add(Step(ctx, 3), { tag = "xp", level = 3, xp = 895, text = "Grind to 895+/1400xp" })
    ctx.level, ctx.xp, ctx.xpMax = 3, 642, 1400
    ctx.Point(3)
    ctx.Login()
    Eq(ctx.status, "XP 642 / 895 (71%)")
    ctx.xp = 700
    ctx.Fire("PLAYER_XP_UPDATE")
    Eq(ctx.status, "XP 700 / 895 (78%)", "as it grows")
    ctx.xp = 900
    ctx.Fire("PLAYER_XP_UPDATE")
    Eq(ctx.status, nil, "reached: gone")
    ctx.level, ctx.xp = 2, 100
    ctx.Fire("PLAYER_LEVEL_UP")
    Eq(ctx.status, "Level 2 of 3", "below its level: the level it is reached at")
    ctx.ns.Follow.SetExtra("grindXP", false)
    Eq(ctx.status, nil, "its switch off")
end

-- The guide's other ways of writing a goal: the level itself, a share of
-- its bar, an amount short of it; a condition (.xp <7) is none.
function T.everyKindOfGoal()
    local ctx = Harness.Load()
    local e = Add(Step(ctx, 3), { tag = "xp", level = 4, xp = 0 })
    ctx.Point(3)
    ctx.Login()
    local G = ctx.ns.Follow.GrindText
    ctx.level, ctx.xp, ctx.xpMax = 3, 500, 2000
    Eq(G(), "XP 500 / 2000 (25%)", "level 4: the whole bar of level 3")
    e.xp = -400
    Eq(G(), "XP 500 / 1600 (31%)", "400 short of level 4")
    e.level, e.xp = 3, 0.5
    Eq(G(), "XP 500 / 1000 (50%)", "half of level 3")
    e.reverseLogic = true
    Eq(G(), nil, "a condition: no goal")
end

function T.aLoopStep_drawsItsCircuit_whileTheGuideLeads()
    local ctx = Harness.Load()
    local step = Step(ctx, 4)
    step.loop = true
    for _, p in ipairs({ { 50, 40 }, { 52, 40 }, { 52, 40 }, { 51, 43 } }) do
        Add(step, { tag = "goto", zone = 1436, x = p[1], y = p[2] })
    end
    ctx.Point(4)
    ctx.Login()
    True(ctx.circuit ~= nil, "drawn")
    Eq(#ctx.circuit, 3, "its spots, the same spot twice once")
    Eq(ctx.circuit[2].x, 0.52, "in map fractions")
    ctx.PlayerRoute("Booty Bay")
    Eq(ctx.circuit, nil, "a route of the player's own: none")
    ctx.ns.Follow.LeadNow()
    True(ctx.circuit ~= nil, "the guide again")
    ctx.ns.Follow.SetExtra("circuits", false)
    Eq(ctx.circuit, nil, "its switch off")
end

function T.theirSwitches_onTheSettingsPage()
    local ctx = Harness.Load()
    local rows = {}
    local kit = {}
    local function Row(label)
        local r = { label = label }
        function r.SetPoint() end
        rows[label] = r
        return r
    end
    function kit.Title() return Row("title") end
    function kit.Checkbox(_, label, get, set)
        local r = Row(label)
        r.get, r.set = get, set
        return r
    end
    function kit.Stepper(_, label) return Row(label) end
    ctx.extension.settings({}, kit)
    for _, label in ipairs({ "Spirit Healer on death skips", "XP on grind steps", "Farm circuits on the map" }) do
        True(rows[label] ~= nil, label)
        True(rows[label].get(), label .. ": on")
    end
    rows["XP on grind steps"].set(false)
    Eq(ctx.env.EasyFindRestedXPDB.grindXP, false, "saved off")
    rows["XP on grind steps"].set(true)
    Eq(ctx.env.EasyFindRestedXPDB.grindXP, nil, "on: nothing saved")
end

return T
