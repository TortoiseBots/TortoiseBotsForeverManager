-- TortoiseBotsForever bridge (WIP).
--
-- The addon speaks the TortoiseBots `.bot` protocol. The TortoiseBotsForever
-- server module does not have that command layer yet: today it only has the
-- GM test commands `.tb <sub>`. Until the server answers with TBM:CAPS, the
-- few addon commands that have a `.tb` twin are translated here, and every
-- other feature is shown as "Not currently available".
--
-- Once the server advertises its capabilities (native protocol), this file
-- steps aside and the addon runs exactly as on TortoiseBots.

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
TB.Forever = TB.Forever or {}
local F = TB.Forever

F.WIP_TITLE = "Not currently available"
F.WIP_TEXT  = "TortoiseBotsForever is still being ported (WIP). This comes back when the server supports it."
F.GM_TEXT   = "Uses the server's .tb test commands: needs a GM account for now."

-- `.bot action <intent>` -> `.tb order <scope> <verb>` (town errands ride the
-- same path: the bot must already stand near the right NPC or mailbox).
local ORDER_VERBS = {
    ["attack"]   = "attack my",
    ["pull"]     = "pull my",
    ["end pull"] = "endpull",
    ["follow"]   = "follow",
    ["stay"]     = "stay",
    ["come"]     = "come",
    ["free"]     = "free",
    ["release"]  = "release",
    ["repair"]   = "repair",
    ["sell"]     = "sell",
    ["learn"]    = "train",
}
local ROLE_WORDS = { tank = "tank", heal = "healer", healer = "healer", dps = "dps", none = "none", clear = "none" }

-- Planned `.tb` twins: each row switches on in one line (flip its `on`) once
-- the server confirms the syntax. While `on` is false the intent has no
-- translation and its control stays greyed ("Not currently available").
-- (No ignore row: the panel has no ignore intent yet. Add one with the button.)
F.Future = {
    -- Needs the target's 32-hex guid, which the panel cannot build reliably:
    -- stays on the greyed side until it can name a target.
    pullback = { on = false, match = "^action pullback$", build = function() return ".tb cmd pullback" end },
    -- Commander's order path, live: rest travels as `.tb cmd rest`.
    rest     = { on = true,  match = "^action rest$",     build = function() return ".tb cmd rest" end },
    -- Commander's task path, live: `my` is the commander's current target.
    use      = { on = true,  match = "^action use$",      build = function() return ".tb cmd use my" end },
    -- Crowd-control permissions (`.tb cc ... allow|deny`): the panel's mark
    -- intents are a different feature, so there is nothing to map yet.
    cc       = { on = false, match = "^action cc%s+(.+)$", build = function(tail) return ".tb cc " .. tail end },
}

local READABLE_CODES = {
    ["no-engine"] = "no engine running",
    ["action-not-registered"] = "action not supported",
    ["not-in-group"] = "not in party",
    ["no-commander"] = "no commander",
    ["no-entrance"] = "no instance entrance",
    ["no-such-player"] = "not in world",
    ["not-a-bot"] = "not a logged-in bot",
    ["no-party"] = "not in a party",
    ["no-bots"] = "no bots in party",
    ["ambiguous-party"] = "ambiguous party",
    ["missing-target"] = "missing target",
    ["missing-verb"] = "missing verb",
    ["unknown-verb"] = "unknown verb",
    ["missing-argument"] = "missing argument",
    ["unexpected-argument"] = "unexpected argument",
    ["bad-argument"] = "invalid argument",
    ["missing-role"] = "missing role",
    ["bad-role"] = "invalid role",
    ["not-allowed"] = "not allowed",
    ["engine-not-built"] = "engine not built",
    ["queue-full"] = "order queue full",
    ["nothing-to-assist"] = "nothing to assist",
    ["party-refused"] = "party invite refused",
    ["teleport-refused"] = "teleport refused",
}

local KNOWN_RECORD_KINDS = {
    order = "order",
    role = "role",
    tele = "tele",
    party = "party",
    ["party-join"] = "party",
    enter = "enter",
    master = "master",
    equip = "equip",
    commander = "commander",
    binding = "commander",
    member = "commander",
    gear = "gear",
    cmd = "cmd",
    plan = "plan",
    run = "run",
}

local activeBatches = {}

local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

local function me()
    return UnitName and UnitName("player") or nil
end

local function inGroup()
    if TB.PartyCount and TB.PartyCount() > 0 then return true end
    if TB.RaidCount and TB.RaidCount() > 0 then return true end
    return false
end

-- The order scope: a targeted party bot, else the player's party (or `party` when solo).
local function orderScope()
    if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target")
        and not (UnitIsUnit and UnitIsUnit("target", "player"))
        and ((UnitInParty and UnitInParty("target")) or (UnitInRaid and UnitInRaid("target"))) then
        return UnitName("target")
    end
    local player = me()
    if player and inGroup() then
        return "party " .. player
    end
    return "party"
end

-- True once the server speaks the native protocol (TBM:CAPS arrived).
function F.Native()
    return TB.ServerCapabilitiesKnown and TB.ServerCapabilitiesKnown() or false
end

-- `.bot` payload -> `.tb` chat line, or nil when Forever has no twin yet.
function F.Translate(cmd)
    cmd = trim(cmd)
    for _, row in pairs(F.Future or {}) do
        local tail = string.match(cmd, row.match)
        if tail and row.on then return row.build(tail) end
    end
    local verb, rest = string.match(cmd, "^(%S+)%s*(.*)$")
    if not verb then return nil end
    verb = string.lower(verb)

    if verb == "action" then
        local intent = string.lower(rest)
        -- Pull timers are not supported by `.tb order pull`: drop the seconds.
        intent = string.gsub(intent, "^(pull)%s+%d+$", "%1")
        local order = ORDER_VERBS[intent]
        if order then return ".tb order " .. orderScope() .. " " .. order end
        return nil
    end

    if verb == "autogear" then
        local bot = string.match(rest, "^(%S+)%s*$")
        if bot then return ".tb gear " .. bot .. " upgrade" end
        return nil
    end

    local name, extra = string.match(rest, "^(%S+)%s*(.*)$")
    if verb == "role" and name then
        local word = ROLE_WORDS[string.lower(extra or "")]
        if not word then return nil end
        -- No name: the sender's own character (its role is stored for the live side).
        if name == "self" then return ".tb role " .. word end
        return ".tb role " .. name .. " " .. word
    end
    if verb == "command" and name and string.lower(extra or "") == "d equip upgrades" then
        return ".tb gear " .. name .. " upgrade"
    end
    if not name or name == "" then return nil end
    local player = me()
    if verb == "add" and player then return ".tb login " .. name .. " " .. player end
    if verb == "remove" or verb == "logout" then return ".tb logout " .. name end
    if verb == "invite" and player then return ".tb group " .. name .. " " .. player end
    if verb == "uninvite" then return ".tb ungroup " .. name end
    if verb == "summon" and player then return ".tb tele " .. name .. " to " .. player end
    return nil
end

-- Can this `.bot` payload run on the server right now?
function F.Available(cmd)
    if F.Native() then return true end
    return F.Translate(cmd) ~= nil
end

-- Send a translated line. The client blocks SendChatMessage to SAY from
-- addon code, so the line goes as a whisper to yourself: the server runs a
-- dot command from any chat line before it is delivered. Must run from a
-- click (a timer or an event may still be blocked).
function F.Send(cmd)
    local line = F.Translate(cmd)
    local player = me()
    if not line or not player then
        if TB.SetStatus then TB.SetStatus(F.WIP_TITLE .. " (WIP)", "warn") end
        return false
    end
    if TB.trace and TB.TracePrint then TB.TracePrint("> " .. line .. "   [forever]") end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok = send and pcall(send, line, "WHISPER", nil, player)
    if not ok and TB.SetStatus then TB.SetStatus("Could not send: type " .. line .. " in chat.", "warn") end
    return ok and true or false
end

-- Show a control as not available yet: greyed, with the WIP tooltip.
function F.MarkUnavailable(control, title, extraTip)
    if not control then return end
    if not control._foreverMarked then
        control._foreverOrigOnEnter = control.GetScript and control:GetScript("OnEnter") or nil
        control._foreverOrigOnLeave = control.GetScript and control:GetScript("OnLeave") or nil
        control._foreverMarked = true
    end
    if control.Disable then control:Disable() end
    if control.SetMotionScriptsWhileDisabled then control:SetMotionScriptsWhileDisabled(true) end
    local tip = extraTip or control._tbTipText or (control.toggle and control.toggle.tip) or nil
    control:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or F.WIP_TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(F.WIP_TEXT, 0.8, 0.8, 0.8, true)
        if tip and tip ~= "" then
            GameTooltip:AddLine(tip, 0.65, 0.65, 0.65, true)
        end
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

local function urlDecode(s)
    if not s then return "" end
    return (string.gsub(s, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function parseKV(rest)
    local kv = {}
    for k, v in string.gmatch(rest or "", "(%S+)=([^%s]*)") do
        kv[k] = urlDecode(v)
    end
    return kv
end

local function readableCode(code)
    if not code or code == "" then return "refused" end
    return READABLE_CODES[code] or string.gsub(code, "%-", " ")
end

local function formatRefusals(refusals)
    local parts = {}
    for _, r in ipairs(refusals) do
        local reason = readableCode(r.code)
        if r.bot and r.bot ~= "" then
            table.insert(parts, r.bot .. ": " .. reason)
        else
            table.insert(parts, reason)
        end
    end
    return table.concat(parts, ", ")
end

local function emitStatus(text, kind, rawMsg)
    if TB.SetStatus then TB.SetStatus(text, kind) end
    if TB.LogMessage then TB.LogMessage(text, rawMsg or text) end
end

local function isTortoiseWarn(body)
    return string.find(body, "not logged in", 1, true)
        or string.find(body, "not grouped", 1, true)
        or string.find(body, "not ungrouped", 1, true)
        or string.find(body, "is not a logged%-in bot")
        or string.find(body, "no character named", 1, true)
        or string.find(body, "neither a host bot", 1, true)
        or string.find(body, "does not exist", 1, true)
        or string.find(body, "not created", 1, true)
        or string.find(body, "not teleported", 1, true)
        or string.find(body, "not converted", 1, true)
        or string.find(body, "not changed", 1, true)
        or string.find(body, "no result sent", 1, true)
        or string.find(body, "INCOMPLETE", 1, true)
        or string.find(body, "FAILED", 1, true)
end

local function formatEndSummary(kind, kv, refusedCount, refusals)
    if kind == "order" then
        local verb = kv.verb or "order"
        if refusedCount == 0 then
            return string.format("Order %s queued (%s bot(s))", verb, kv.queued or kv.bots or "0")
        end
        return string.format("Order %s: %d refused (%s)", verb, refusedCount, formatRefusals(refusals))
    elseif kind == "role" then
        local role = kv.role or "role"
        if refusedCount == 0 then
            return string.format("Role %s applied (%s bot(s))", role, kv.bots or "0")
        end
        return string.format("Role %s: %d refused (%s)", role, refusedCount, formatRefusals(refusals))
    elseif kind == "tele" then
        if refusedCount == 0 then
            local target = kv.target or ((kv.started or "1") .. " bot(s)")
            return string.format("Teleport started (%s)", target)
        end
        return string.format("Teleport: %d refused (%s)", refusedCount, formatRefusals(refusals))
    elseif kind == "gear" then
        local changed = tonumber(kv.changed) or 0
        if refusedCount ~= 0 then
            return string.format("Gear upgrades: %d refused (%s)", refusedCount, formatRefusals(refusals))
        elseif changed == 0 then
            return "Gear already up to date"
        end
        return string.format("Gear upgrades equipped (%d changed)", changed)
    elseif kind == "cmd" then
        local verb = kv.verb or "order"
        if refusedCount == 0 then
            return string.format("Order %s accepted (%s bot(s))", verb, kv.bots or "0")
        end
        return string.format("Order %s: %d refused (%s)", verb, refusedCount, formatRefusals(refusals))
    end
    if refusedCount == 0 then
        return string.format("%s complete", kind)
    end
    return string.format("%s: %d refused (%s)", kind, refusedCount, formatRefusals(refusals))
end

-- Parse `.tb` system replies while the server does not speak native TBM.
function F.OnSystemMessage(msg)
    if type(msg) ~= "string" or msg == "" then return false end
    if issecretvalue and issecretvalue(msg) then return false end

    if string.find(msg, "You do not have permission", 1, true) then
        emitStatus("Forever bridge: needs a GM account (.tb test commands).", "warn", msg)
        return true
    end

    local tbBody = string.match(msg, "^TortoiseBots:%s*(.+)$")
    if tbBody then
        emitStatus(tbBody, isTortoiseWarn(tbBody) and "warn" or "ok", msg)
        return true
    end

    local errRest = string.match(msg, "^error%s+(.+)$")
    if errRest then
        local kv = parseKV(errRest)
        local prefix = (kv.cmd and kv.cmd ~= "") and (kv.cmd .. ": ") or ""
        local detail = (kv.msg and kv.msg ~= "") and (" - " .. kv.msg) or ""
        emitStatus(prefix .. readableCode(kv.code) .. detail, "warn", msg)
        return true
    end

    local beginKind = string.match(msg, "^([a-z]+)%-begin$") or string.match(msg, "^([a-z]+)%-begin%s+")
    if beginKind then
        activeBatches[beginKind] = { refusals = {} }
        return true
    end

    local endKind, endRest = string.match(msg, "^([a-z]+)%-end%s*(.*)$")
    if endKind then
        local kv = parseKV(endRest)
        local batch = activeBatches[endKind]
        activeBatches[endKind] = nil
        local refusals = batch and batch.refusals or {}
        local refusedCount = tonumber(kv.refused) or #refusals
        local summary = formatEndSummary(endKind, kv, refusedCount, refusals)
        emitStatus(summary, (refusedCount == 0) and "ok" or "warn", msg)
        return true
    end

    local recKind, recRest = string.match(msg, "^([a-z]+%-?[a-z]*)%+?%s+(.+)$")
    local batchKey = recKind and KNOWN_RECORD_KINDS[recKind]
    if batchKey then
        local kv = parseKV(recRest)
        if kv.status == "refused" then
            activeBatches[batchKey] = activeBatches[batchKey] or { refusals = {} }
            table.insert(activeBatches[batchKey].refusals, {
                bot = kv.bot,
                code = kv.code,
                msg = kv.msg,
            })
        end
        return true
    end

    return false
end

local function isSelfSender(sender)
    if not sender or sender == "" then return true end
    local player = me()
    if not player then return false end
    local short = string.match(sender, "^([^%-]+)") or sender
    return short == player
end

-- Hide bridge chatter (outgoing `.tb` self-whispers and structured `*-begin`/`*-end` lines).
-- Keep errors and permission messages visible.
function F.ShouldHideChatMessage(event, message, sender)
    if type(message) ~= "string" then return false end
    if issecretvalue and issecretvalue(message) then return false end

    if string.find(message, "^%.tb$") or string.find(message, "^%.tb%s") then
        if event == "CHAT_MSG_WHISPER_INFORM" then return true end
        if event == "CHAT_MSG_WHISPER" and isSelfSender(sender) then return true end
        return false
    end

    if string.find(message, "^error%s") then return false end

    if event == nil or event == "CHAT_MSG_SYSTEM" then
        if string.match(message, "^[a-z]+%-begin$") or string.match(message, "^[a-z]+%-begin%s+") then
            return true
        end
        if string.match(message, "^[a-z]+%-end$") or string.match(message, "^[a-z]+%-end%s+") then
            return true
        end
        local recKind = string.match(message, "^([a-z]+%-?[a-z]*)%+?%s+%a+=")
        if recKind and KNOWN_RECORD_KINDS[recKind] then
            return true
        end
    end

    return false
end

-- Restore a control that was marked unavailable once the server supports it.
function F.RestoreAvailable(control)
    if not control or not control._foreverMarked then return end
    control._foreverMarked = nil
    if control.Enable then control:Enable() end
    if control._foreverOrigOnEnter then
        control:SetScript("OnEnter", control._foreverOrigOnEnter)
    elseif control._tbTipText and TB.UI and TB.UI.SetTooltip then
        TB.UI.SetTooltip(control, control._tbTipText, control._tbTipTitle)
    else
        control:SetScript("OnEnter", nil)
    end
    if control._foreverOrigOnLeave then
        control:SetScript("OnLeave", control._foreverOrigOnLeave)
    elseif not (control._tbTipText and TB.UI and TB.UI.SetTooltip) then
        control:SetScript("OnLeave", nil)
    end
    control._foreverOrigOnEnter = nil
    control._foreverOrigOnLeave = nil
end

function F.GateControl(control, cmd, title, extraTip)
    if not control then return end
    if F.Available(cmd) then
        F.RestoreAvailable(control)
    else
        F.MarkUnavailable(control, title, extraTip)
    end
end
