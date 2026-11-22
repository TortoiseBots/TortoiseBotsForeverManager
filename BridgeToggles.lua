-- Forever bridge: M3 party toggles (aoe, autocc, sap, loot) and corpse run (needs TBF PR #205).

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
TB.Forever = TB.Forever or {}
local F = TB.Forever

local TOGGLE_VERBS = {
    aoe       = "aoe",
    autocc    = "autocc",
    ["auto cc"] = "autocc",
    sap       = "sap",
    loot      = "loot",
}

local TOGGLE_ARGS = {
    on     = "on",
    off    = "off",
    status = "status",
}

local function translate(cmd, verb, rest)
    if verb ~= "action" then return nil end
    local intent = string.lower(F.Trim and F.Trim(rest) or rest or "")

    if intent == "corpse run" or intent == "corpserun" then
        return ".tb cmd corpserun"
    end

    for pattern, canonical in pairs(TOGGLE_VERBS) do
        if intent == pattern then
            return ".tb cmd " .. canonical
        end
        local prefix = pattern .. " "
        if string.sub(intent, 1, #prefix) == prefix then
            local arg = F.Trim and F.Trim(string.sub(intent, #prefix + 1)) or string.sub(intent, #prefix + 1)
            local valid = TOGGLE_ARGS[arg]
            if valid then
                return ".tb cmd " .. canonical .. " " .. valid
            end
            return nil
        end
    end

    return nil
end

local function onSystemMessage(msg)
    local kvVerb = string.match(msg, "^cmd%s+(.+)$")
    if kvVerb and F.ParseKV then
        local kv = F.ParseKV(kvVerb)
        local key = kv.verb and TOGGLE_VERBS[string.lower(kv.verb)]
        if key and (kv.state == "on" or kv.state == "off" or kv.state == "mixed") then
            if TB.OnPartyToggleResult then
                TB.OnPartyToggleResult(key, kv.result or "party", kv.state)
            end
        end
        return false
    end

    local orderRest = string.match(msg, "^order%s+(.+)$")
    if orderRest and F.ParseKV then
        local kv = F.ParseKV(orderRest)
        local key = kv.verb and TOGGLE_VERBS[string.lower(kv.verb)]
        if key and kv.status == "read" and (kv.state == "on" or kv.state == "off") then
            if TB.OnPartyToggleResult then
                TB.OnPartyToggleResult(key, kv.bot and ("bot:" .. kv.bot) or "party", kv.state)
            end
        end
        return false
    end

    return false
end

if not F._bridgeToggles then
    F._bridgeToggles = true
    F.Translators = F.Translators or {}
    F.SystemParsers = F.SystemParsers or {}
    table.insert(F.Translators, translate)
    table.insert(F.SystemParsers, onSystemMessage)
end
