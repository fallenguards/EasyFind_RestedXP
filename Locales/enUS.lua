local _, ns = ...

-- Every string the player sees. Other locales override keys in files of
-- their own; a missing key falls back to this one.
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

L["EXT_NAME"] = "RestedXP"
L["EXT_DESC"] = "The GPS follows your guide step by step; its guides and steps come up in search."
L["NEEDS_EASYFIND"] = "needs a newer EasyFind: update EasyFind to use it."
L["NO_RXP"] = "this version of RestedXP Guides cannot be read: following and its search are off."
L["SETTINGS_HINT"] = "Your RestedXP guide, led by EasyFind's GPS."
L["FOLLOW"] = "Follow the guide"
L["FOLLOW_TT"] = "The GPS leads to each of the guide's waypoints in turn. A route you start yourself holds until the guide moves on."
L["HIDE_ARROW"] = "Hide RestedXP's arrow"
L["HIDE_ARROW_TT"] = "Its arrow and its Active Targets panel, while the GPS leads."
L["BOX"] = "Box under the arrow"
L["BOX_TT"] = "Under the GPS arrow: the step, how far and how long. Arrow text in the GPS settings picks what it says."
L["AHEAD"] = "Waypoints ahead"
L["AHEAD_TT"] = "How many of the guide's next waypoints the route goes on through."
L["LEAD_NOW"] = "Lead to the guide's step"
L["GUIDES_LABEL"] = "RestedXP guides"
L["STEPS_LABEL"] = "Guide steps"
L["GUIDE_SUB"] = "RestedXP guide: %s"
L["STEP_SUB"] = "Step %d of %s"
L["STEP_FMT"] = "Step %d"
L["QUEST_STEP"] = "RestedXP: step %d"
L["ITEM_STEP"] = "RestedXP: step %d needs %d"
L["GO_TO_STEP"] = "Go to step %d"
L["HINT_STEP"] = "Go to step"
L["HINT_GUIDE"] = "Load guide"
L["KW_GUIDE"] = "guide"
L["KW_STEP"] = "step"
