-- Forever bridge: player upkeep & info commands sent as typed `.bot` chat
-- (maintenance, autogear, stats; stats needs TBF PR #203).

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
TB.Forever = TB.Forever or {}
local F = TB.Forever

F.Stats = F.Stats or {}

local function translate(cmd, verb, rest)
    local trimmed = F.Trim and F.Trim(rest) or rest or ""
    if verb == "maintenance" then
        local bot = string.match(trimmed, "^(%S+)$")
        if bot then return ".bot maintenance " .. bot end
        return nil
    elseif verb == "autogear" then
        local bot, cap = string.match(trimmed, "^(%S+)%s*(%S*)$")
        if bot and cap ~= "" then
            return ".bot autogear " .. bot .. " " .. cap
        elseif bot then
            return ".bot autogear " .. bot
        end
        return nil
    elseif verb == "stats" then
        local bot = string.match(trimmed, "^(%S+)$")
        if bot then return ".bot stats " .. bot end
        return nil
    end
    return nil
end

local function onSystemMessage(msg, emitStatus)
    local bot, body = string.match(msg, "^TortoiseBots:%s*maintenance%s+(%S+):%s*(.+)$")
    if bot then
        local isOk = string.sub(body, 1, 2) == "ok"
        emitStatus("Maintenance " .. bot .. ": " .. body, isOk and "ok" or "warn", msg)
        return true
    end

    local statsBot, statsBody = string.match(msg, "^TortoiseBots:%s*stats%s+(%S+):%s*ok%s+(.+)$")
    if statsBot then
        F.Stats[string.lower(statsBot)] = statsBody
        emitStatus(statsBot .. ": " .. statsBody, "ok", msg)
        return true
    end

    local refusedVerb, refusedCode, refusedText = string.match(msg, "^TortoiseBots:%s*([%a]+):%s*refused%s+(%S+):%s*(.+)$")
    if refusedVerb then
        local readable = F.ReadableCode and F.ReadableCode(refusedCode) or refusedCode
        emitStatus(refusedVerb .. ": " .. readable .. " - " .. refusedText, "warn", msg)
        return true
    end

    if string.match(msg, "^Re%-geared%s+%S+") then
        emitStatus(msg, "ok", msg)
        return true
    end

    return false
end

local function shouldHideChat(event, message, sender, isSelfSender)
    if string.find(message, "^%.bot%s+maintenance%s")
        or string.find(message, "^%.bot%s+autogear%s")
        or string.find(message, "^%.bot%s+stats%s") then
        if event == "CHAT_MSG_WHISPER_INFORM" then return true end
        if event == "CHAT_MSG_WHISPER" and isSelfSender(sender) then return true end
    end
    return false
end

if not F._bridgeUpkeep then
    F._bridgeUpkeep = true
    F.Translators = F.Translators or {}
    F.SystemParsers = F.SystemParsers or {}
    F.HideChatChecks = F.HideChatChecks or {}
    table.insert(F.Translators, translate)
    table.insert(F.SystemParsers, onSystemMessage)
    table.insert(F.HideChatChecks, shouldHideChat)
end
