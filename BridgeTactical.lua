-- Forever bridge: M1/M2 tactical orders (stop, flee, guard, stance, engage, rebuff, interrupt).

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
TB.Forever = TB.Forever or {}
local F = TB.Forever

local SIMPLE_TACTICAL = {
    stop   = "stop",
    flee   = "flee",
    guard  = "guard",
    rebuff = "rebuff",
}

local STANCE_WORDS = {
    near     = "near",
    tank     = "tank",
    turnback = "turnback",
    turn     = "turn",
    behind   = "behind",
}

local function translate(cmd, verb, rest, orderScope)
    if verb ~= "action" then return nil end
    local intent = string.lower(F.Trim and F.Trim(rest) or rest or "")

    local simple = SIMPLE_TACTICAL[intent]
    if simple then
        return ".tb order " .. orderScope() .. " " .. simple
    end

    if intent == "interrupt" then
        local guid = F.TargetGuidHex and F.TargetGuidHex()
        if guid then return ".tb cmd interrupt " .. guid end
        return ".tb order " .. orderScope() .. " interrupt my"
    end

    local stanceWord = string.match(intent, "^stance%s+(%S+)$")
    if stanceWord and STANCE_WORDS[stanceWord] then
        return ".tb order " .. orderScope() .. " stance " .. STANCE_WORDS[stanceWord]
    end

    if intent == "engage" then
        return ".tb order " .. orderScope() .. " engage"
    end
    local secStr = string.match(intent, "^engage%s+(%d+)$")
    if secStr then
        local sec = tonumber(secStr)
        if sec and sec >= 0 and sec <= 60 then
            return ".tb order " .. orderScope() .. " engage " .. secStr
        end
        return nil
    end

    return nil
end

if not F._bridgeTactical then
    F._bridgeTactical = true
    F.Translators = F.Translators or {}
    table.insert(F.Translators, translate)
end
