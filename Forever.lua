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

TB = TB or {}
TB.Forever = TB.Forever or {}
local F = TB.Forever

F.WIP_TITLE = "Not currently available"
F.WIP_TEXT  = "TortoiseBotsForever is still being ported (WIP). This comes back when the server supports it."
F.GM_TEXT   = "Uses the server's .tb test commands: needs a GM account for now."

-- `.bot action <intent>` -> `.tb order <scope> <verb>`.
local ORDER_VERBS = {
    ["attack"]   = "attack my",
    ["pull"]     = "pull my",
    ["end pull"] = "endpull",
    ["follow"]   = "follow",
    ["stay"]     = "stay",
    ["come"]     = "come",
    ["free"]     = "free",
    ["release"]  = "release",
}

local ROLE_WORDS = { tank = "tank", heal = "healer", healer = "healer", dps = "dps" }

local function trim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end

local function me()
    return UnitName and UnitName("player") or nil
end

-- The order scope: a targeted party bot, else the whole party.
local function orderScope()
    if UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target")
        and not (UnitIsUnit and UnitIsUnit("target", "player"))
        and ((UnitInParty and UnitInParty("target")) or (UnitInRaid and UnitInRaid("target"))) then
        return UnitName("target")
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

    local name, extra = string.match(rest, "^(%S+)%s*(.*)$")
    if verb == "role" and name and name ~= "self" then
        local word = ROLE_WORDS[string.lower(extra or "")]
        if word then return ".tb role " .. name .. " " .. word end
        return nil
    end
    if not name or name == "" then return nil end
    local player = me()
    if verb == "add" and player then return ".tb login " .. name .. " " .. player end
    if verb == "remove" or verb == "logout" then return ".tb logout " .. name end
    if verb == "uninvite" then return ".tb ungroup " .. name end
    if verb == "summon" and player then return ".tb tele " .. name .. " to " .. player end
    return nil
end

-- Can this `.bot` payload run on the server right now?
function F.Available(cmd)
    if F.Native() then return true end
    return F.Translate(cmd) ~= nil
end

-- Send a translated line. Client 70707 blocks SendChatMessage to SAY from
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
function F.MarkUnavailable(control, title)
    if not control then return end
    if control.Disable then control:Disable() end
    if control.SetMotionScriptsWhileDisabled then control:SetMotionScriptsWhileDisabled(true) end
    control:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title or F.WIP_TITLE, 1, 0.82, 0)
        GameTooltip:AddLine(F.WIP_TEXT, 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
