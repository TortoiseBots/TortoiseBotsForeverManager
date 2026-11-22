-- TortoiseBotsForever hybrid transport (native TBM:VERBS + .tb bridge fallback).
--
-- The server advertises the verbs it answers natively via `TBM:VERBS|tok,...`
-- right before `TBM:CAPS`. Each command routes independently:
--   1. Native (.bot / TBM addon channel) when its verb/intent is in VERBS,
--      or when CAPS arrived without VERBS (old/other server fallback).
--   2. Bridge (.tb whisper, GM-only) when F.Translate has a twin and the last
--      .tb reply was not a permission refusal.
--   3. Grey (WIP tooltip) otherwise.

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
TB.Forever = TB.Forever or {}
local F = TB.Forever

local bridgePermRefused = false

local function trim(s)
    return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

-- Extract the top verb and (for `action ...`) the intent tokens for VERBS lookup.
function F.CommandTokens(cmd)
    cmd = trim(cmd)
    if cmd == "" then return nil end
    local verb, rest = string.match(cmd, "^(%S+)%s*(.*)$")
    if not verb then return nil end
    verb = string.lower(verb)
    if verb ~= "action" then
        return verb
    end
    rest = string.lower(trim(rest))
    if rest == "" then return "action" end
    local sub = string.match(rest, "^(%S+)")
    local noNum = string.gsub(rest, "%s+%d+$", "")
    return verb, "action:" .. rest, (noNum ~= rest) and ("action:" .. noNum) or nil,
        sub and ("action:" .. sub) or nil
end

function F.IsVerbNative(cmd)
    if not (TB.ServerVerbsKnown and TB.ServerVerbsKnown()) then return false end
    if not TB.HasServerVerb then return false end
    local verb, exactAction, noNumAction, subAction = F.CommandTokens(cmd)
    if not verb then return false end
    if verb ~= "action" then
        return TB.HasServerVerb(verb)
    end
    if exactAction and TB.HasServerVerb(exactAction) then return true end
    if noNumAction and TB.HasServerVerb(noNumAction) then return true end
    if subAction and TB.HasServerVerb(subAction) then return true end
    return TB.HasServerVerb("action")
end

-- True when the command (or, with no argument, the whole server) is native.
-- Old/other servers that send TBM:CAPS without TBM:VERBS stay all-native.
function F.Native(cmd)
    local capsKnown = TB.ServerCapabilitiesKnown and TB.ServerCapabilitiesKnown() or false
    local verbsKnown = TB.ServerVerbsKnown and TB.ServerVerbsKnown() or false
    if capsKnown and not verbsKnown then
        return true
    end
    if cmd and cmd ~= "" then
        return F.IsVerbNative(cmd)
    end
    return false
end

function F.IsBridgePermRefused()
    return bridgePermRefused
end

function F.SetBridgePermRefused(refused)
    local nextVal = refused and true or false
    if bridgePermRefused == nextVal then return end
    bridgePermRefused = nextVal
    if TB.RefreshForeverGating then TB.RefreshForeverGating() end
    if TB.RefreshMiniBar then TB.RefreshMiniBar() end
end

local origOnSystemMessage = F.OnSystemMessage
function F.OnSystemMessage(msg)
    local handled = origOnSystemMessage and origOnSystemMessage(msg) or false
    if type(msg) == "string" and msg ~= "" then
        local lower = string.lower(msg)
        if string.find(lower, "do not have permission", 1, true)
            or string.find(lower, "don't have permission", 1, true) then
            F.SetBridgePermRefused(true)
        elseif handled then
            F.SetBridgePermRefused(false)
        end
    end
    return handled
end

function F.Available(cmd)
    if F.Native(cmd) then return true end
    if bridgePermRefused then return false end
    return F.Translate(cmd) ~= nil
end

function F.Route(cmd)
    if F.Native(cmd) then return "native" end
    if not bridgePermRefused and F.Translate(cmd) ~= nil then return "bridge" end
    return "grey"
end
