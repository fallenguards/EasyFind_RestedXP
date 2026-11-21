std = "lua51"
max_line_length = false
-- The dev notes are untracked and never ship.
exclude_files = { "dev" }

-- Standard WoW addon patterns, not real issues.
ignore = {
    "431",  -- shadowing upvalue
    "432",  -- shadowing upvalue argument
}

-- Its saved settings
globals = { "EasyFindRestedXPDB", "EasyFindRestedXPCharDB" }

-- WoW API and RestedXP Guides (read-only)
read_globals = {
    "EasyFind", "RXP", "RXPG_ARROW", "RXPCData", "LibStub",
    "C_AddOns", "C_Map", "C_QuestLog", "C_Timer", "CreateVector2D", "IsAddOnLoaded", "GetLocale", "CreateFrame",
    "InCombatLockdown", "UnitIsDeadOrGhost", "hooksecurefunc",
    "UnitXP", "UnitXPMax", "UnitLevel", "BreakUpLargeNumbers", "issecretvalue",
    "C_Item", "C_Spell", "C_SpellBook", "GetItemCount", "GetSpellInfo", "IsEquippedItem", "IsPlayerSpell", "IsSpellKnown",
    "PlayerHasToy",
}

-- WoW callbacks have fixed signatures; unused args are normal
unused_args = false
self = false

-- The tests run on the lua in PATH (5.4) and stand in for the game's globals.
files["tests"] = { std = "max", ignore = { "111", "112", "113", "121", "122", "143", "211" } }
