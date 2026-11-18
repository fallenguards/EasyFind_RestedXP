-- Every locale says every line, with the same format codes as enUS.
local Harness = require("Harness")
local Eq, True = Harness.Eq, Harness.True

local T = {}
local LOCALES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
-- Lines that read the same in every language.
local SAME = { EXT_NAME = true }

local function Lines(locale)
    local out, order = {}, {}
    for key, text in Harness.Read("Locales/" .. locale .. ".lua"):gmatch('L%["(%w[%w_]*)"%] = "(.-)"\r?\n') do
        out[key] = text
        order[#order + 1] = key
    end
    return out, order
end

local function Codes(text)
    local codes = {}
    for c in text:gmatch("%%[sd%%]") do codes[#codes + 1] = c end
    return table.concat(codes, " ")
end

function T.everyLocale_saysEveryLine_withTheSameCodes()
    local en, order = Lines("enUS")
    True(#order >= 5, "enUS read")
    for _, locale in ipairs(LOCALES) do
        local lines = Lines(locale)
        for _, key in ipairs(order) do
            if not SAME[key] then True(lines[key] ~= nil, locale .. " says " .. key) end
            if lines[key] then Eq(Codes(lines[key]), Codes(en[key]), locale .. " " .. key .. " codes") end
        end
        for key in pairs(lines) do True(en[key] ~= nil, locale .. " " .. key .. " is an enUS key") end
    end
end

function T.eachLocale_loadsOnlyOnItsClient()
    for _, locale in ipairs(LOCALES) do
        local ctx = Harness.Load({ locale = locale })
        True(ctx.ns.L["FOLLOW"] ~= "Follow the guide", locale .. " says it in its own words")
    end
    Eq(Harness.Load({ locale = "enUS" }).ns.L["FOLLOW"], "Follow the guide")
end

return T
