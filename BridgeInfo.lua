-- Forever bridge: `.bot who` roster reader, `.tb spec`, and `.tb talents`.

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
TB.Forever = TB.Forever or {}
local F = TB.Forever

F.WhoList = F.WhoList or {}
F.Talents = F.Talents or {}

local function translate(cmd, verb, rest)
    local trimmed = F.Trim and F.Trim(rest) or rest or ""
    if verb == "who" then
        if trimmed == "" then return ".bot who" end
        if string.lower(trimmed) == "all" then return ".bot who all" end
        return nil
    elseif verb == "spec" then
        local target, arg = string.match(trimmed, "^(%S+)%s+(%S+)$")
        if target and arg then
            if string.lower(target) == "party" then
                local player = F.Me and F.Me()
                if player then return ".tb spec party " .. player .. " " .. arg end
                return ".tb spec party " .. arg
            end
            return ".tb spec " .. target .. " " .. arg
        end
        return nil
    elseif verb == "talents" then
        local bot = string.match(trimmed, "^(%S+)$")
        if bot then return ".tb talents " .. bot end
        return nil
    end
    return nil
end

local function onSystemMessage(msg, emitStatus)
    local countStr = string.match(msg, "^TortoiseBots:%s*who:%s*(%d+)%s+bot%(s%)$")
    if countStr then
        F.WhoList = {}
        emitStatus("Online bots: " .. countStr, "ok", msg)
        return true
    end

    local name, level, class, mapId, move, brain = string.match(
        msg, "^TortoiseBots:%s*who:%s*(%S+)%s+level%s+(%d+)%s+(%S+)%s+map%s+(%d+)%s+(%S+)%s+(%S+)$"
    )
    if name then
        table.insert(F.WhoList, {
            name = name,
            level = tonumber(level),
            class = class,
            map = tonumber(mapId),
            move = move,
            brain = brain,
        })
        if TB.LogMessage then TB.LogMessage(name .. " (Lv " .. level .. " " .. class .. ", " .. move .. ")", msg) end
        return true
    end

    local tBot, tLevel, tSpec, tTab, tSpent, tTree, tFree, tApplied = string.match(
        msg, "^TortoiseBots:%s*(%S+)%s+%(level%s+(%d+)%):%s*spec=(%S+)%s+%(tab%s+(%S+)%)%s+spent=(%d+)%s+%(([^%)]+)%)%s+free=(%d+)%s+applied=(%d+)$"
    )
    if tBot then
        F.Talents[string.lower(tBot)] = {
            name = tBot,
            level = tonumber(tLevel),
            spec = tSpec,
            tab = tTab,
            spent = tonumber(tSpent),
            tree = tTree,
            free = tonumber(tFree),
            applied = tonumber(tApplied),
        }
        emitStatus(tBot .. " (" .. tSpec .. "): " .. tSpent .. " spent (" .. tTree .. "), " .. tFree .. " free", "ok", msg)
        return true
    end

    return false
end

local function shouldHideChat(event, message, sender, isSelfSender)
    if message == ".bot who" or message == ".bot who all" then
        if event == "CHAT_MSG_WHISPER_INFORM" then return true end
        if event == "CHAT_MSG_WHISPER" and isSelfSender(sender) then return true end
    end
    return false
end

if not F._bridgeInfo then
    F._bridgeInfo = true
    F.Translators = F.Translators or {}
    F.SystemParsers = F.SystemParsers or {}
    F.HideChatChecks = F.HideChatChecks or {}
    table.insert(F.Translators, translate)
    table.insert(F.SystemParsers, onSystemMessage)
    table.insert(F.HideChatChecks, shouldHideChat)
end
