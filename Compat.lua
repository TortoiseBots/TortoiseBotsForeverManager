-- TortoiseBotsManagerForever/Compat.lua
-- The modern Classic (WoW Forever 1.60.1) replacements for the 1.12 client API.
-- Everything else in the addon talks to this file, so an API that moves again
-- is one edit here. Written for the modern client: C_ChatInfo, C_Container,
-- C_UnitAuras, GetNumGroupMembers/IsInRaid, UnitPower and SOUNDKIT, with a
-- fallback to the legacy name so the offline harness (which mocks 1.12) and
-- older Classic clients still work.
TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
TB.C = TB.C or {}

local _G = _G
local CC = _G.C_Container
local Chat = _G.C_ChatInfo
local Auras = _G.C_UnitAuras

-- ── addon messages ──────────────────────────────────────────────────────────
-- 1.12 exposed RegisterAddonMessagePrefix/SendAddonMessage as globals; the
-- modern client only has C_ChatInfo (the globals are gone on 11.x clients).
-- Codes 3 and 8 mean "throttled, try again": a raid clicking quickly fills the
-- client's addon-message budget, so a throttled line is retried, not dropped.
local prefixRegistered = false
local THROTTLED = { [3] = true, [8] = true }

function TB.RegisterAddonPrefix(prefix)
    if prefixRegistered then return true end
    local reg = Chat and Chat.RegisterAddonMessagePrefix or _G.RegisterAddonMessagePrefix
    if not reg then return false end
    local ok, res = pcall(reg, prefix)
    prefixRegistered = ok and res ~= false
    return prefixRegistered
end

function TB.CanSendAddon()
    return (Chat and Chat.SendAddonMessage or _G.SendAddonMessage) ~= nil and prefixRegistered
end

local function sendAddonOnce(prefix, text, channel, target)
    local send = Chat and Chat.SendAddonMessage or _G.SendAddonMessage
    if not send then return false, nil end
    local ok, res = pcall(send, prefix, text, channel, target)
    if ok and (res == nil or res == true or res == 0) then return true, nil end
    return false, ok and tonumber(res) or nil
end

-- Returns true when the line was sent, or queued for a retry after a throttle.
-- `tries` counts the retries; after five seconds one line is given up and the
-- caller falls back to chat (SendBotCommand) or reports it.
function TB.SendAddonMessageCompat(prefix, text, channel, target, tries)
    tries = tries or 0
    if not TB.RegisterAddonPrefix(prefix) then return false end
    local sent, code = sendAddonOnce(prefix, text, channel, target)
    if sent then return true end
    if code and THROTTLED[code] and tries < 5 and _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(1.0, function()
            TB.SendAddonMessageCompat(prefix, text, channel, target, tries + 1)
        end)
        return true
    end
    if TB.TracePrint then
        TB.TracePrint("! addon message refused (" .. tostring(code or "no API") .. "): " .. tostring(text))
    end
    return false
end

-- ── group size ──────────────────────────────────────────────────────────────
-- GetNumPartyMembers/GetNumRaidMembers are gone on modern clients.
-- GetNumSubgroupMembers = party members without the player (0 in a raid);
-- GetNumGroupMembers = the whole raid, or the party with the player.
function TB.PartyCount()
    if _G.GetNumSubgroupMembers then return _G.GetNumSubgroupMembers() or 0 end
    if _G.GetNumPartyMembers then return _G.GetNumPartyMembers() or 0 end
    if _G.GetNumGroupMembers and not (_G.IsInRaid and _G.IsInRaid()) then
        return math.max((_G.GetNumGroupMembers() or 0) - 1, 0)
    end
    return 0
end

function TB.RaidCount()
    if _G.IsInRaid then
        if not _G.IsInRaid() then return 0 end
        if _G.GetNumGroupMembers then return _G.GetNumGroupMembers() or 0 end
        if _G.GetNumRaidMembers then return _G.GetNumRaidMembers() or 0 end
        return 0
    end
    if _G.GetNumRaidMembers then return _G.GetNumRaidMembers() or 0 end
    return 0
end

-- What the client actually offers, for the features that must disable
-- themselves instead of half-working (mail attach, bag scans). Looked up on
-- every call: the mocked harness defines the legacy globals after the addon loads.
local function bagSlotsApi() return (CC and CC.GetContainerNumSlots) or _G.GetContainerNumSlots end
local function bagLinkApi() return (CC and CC.GetContainerItemLink) or _G.GetContainerItemLink end
local function bagInfoApi() return (CC and CC.GetContainerItemInfo) or _G.GetContainerItemInfo end
function TB.HasBagSlots() return bagSlotsApi() ~= nil end
function TB.HasBagPickup() return ((CC and CC.PickupContainerItem) or _G.PickupContainerItem) ~= nil end
function TB.HasBagSplit() return ((CC and CC.SplitContainerItem) or _G.SplitContainerItem) ~= nil end
function TB.HasBagCursor()
    return _G.CursorHasItem ~= nil or (CC and CC.CursorHasItem) ~= nil
        or (_G.C_Cursor and _G.C_Cursor.HasCursor) ~= nil
end

function TB.BagReady()
    return bagSlotsApi() ~= nil and bagLinkApi() ~= nil and bagInfoApi() ~= nil
end

-- ── bag slots (C_Container) ─────────────────────────────────────────────────
function TB.BagSlots(bag)
    if CC and CC.GetContainerNumSlots then return CC.GetContainerNumSlots(bag) end
    return _G.GetContainerNumSlots and _G.GetContainerNumSlots(bag) or 0
end

function TB.BagLink(bag, slot)
    if CC and CC.GetContainerItemLink then return CC.GetContainerItemLink(bag, slot) end
    return _G.GetContainerItemLink and _G.GetContainerItemLink(bag, slot) or nil
end

-- Same returns as the 1.12 API the callers were written for:
-- iconFileID, stackCount, isLocked, quality, itemID (modern returns a table).
function TB.BagInfo(bag, slot)
    if CC and CC.GetContainerItemInfo then
        local info = CC.GetContainerItemInfo(bag, slot)
        if type(info) == "table" then
            return info.iconFileID, info.stackCount, info.isLocked, info.quality, info.itemID
        end
        return info
    end
    if _G.GetContainerItemInfo then return _G.GetContainerItemInfo(bag, slot) end
end

function TB.BagPickup(bag, slot)
    if CC and CC.PickupContainerItem then return CC.PickupContainerItem(bag, slot) end
    return _G.PickupContainerItem and _G.PickupContainerItem(bag, slot) or nil
end

function TB.BagSplit(bag, slot, count)
    if CC and CC.SplitContainerItem then return CC.SplitContainerItem(bag, slot, count) end
    return _G.SplitContainerItem and _G.SplitContainerItem(bag, slot, count) or nil
end

function TB.BagCursorHasItem()
    if _G.CursorHasItem then return _G.CursorHasItem() end
    if CC and CC.CursorHasItem then return CC.CursorHasItem() end
    if _G.C_Cursor and _G.C_Cursor.HasCursor then return _G.C_Cursor.HasCursor() end
    return false
end

-- ── unit power / auras ──────────────────────────────────────────────────────
function TB.UnitMana(unit)
    if _G.UnitPower then return _G.UnitPower(unit, 0) or 0 end
    return _G.UnitMana and _G.UnitMana(unit) or 0
end

function TB.UnitManaMax(unit)
    if _G.UnitPowerMax then return _G.UnitPowerMax(unit, 0) or 0 end
    return _G.UnitManaMax and _G.UnitManaMax(unit) or 0
end

-- The buff icon path, for icon-name checks: C_UnitAuras returns a table,
-- UnitBuff returns name first and icon second on modern clients (1.12 returned
-- the icon first).
function TB.BuffIcon(unit, index)
    if Auras and Auras.GetAuraDataByIndex then
        local aura = Auras.GetAuraDataByIndex(unit, index, "HELPFUL")
        return aura and aura.icon or nil
    end
    if not _G.UnitBuff then return nil end
    local first, second = _G.UnitBuff(unit, index)
    return second or first
end

-- ── sound / mail ────────────────────────────────────────────────────────────
function TB.PlaySound(name, fallbackId)
    local kit = _G.SOUNDKIT
    if kit and fallbackId and kit[fallbackId] then
        _G.PlaySound(kit[fallbackId])
        return true
    end
    if _G.PlaySound then
        -- 1.12 sound names are gone; a failed call must not break the click.
        local ok = pcall(_G.PlaySound, name)
        return ok
    end
    return false
end

-- The item in a Send Mail attachment slot: name, count. 1.12 took no argument
-- and returned name, texture, count; the modern client takes the slot index
-- (1..ATTACHMENTS_MAX_SEND) and returns name, itemID, texture, count.
function TB.SendMailItem(slot)
    if not _G.GetSendMailItem then return nil, nil end
    local ok, name, second, third, fourth = pcall(_G.GetSendMailItem, slot or 1)
    if not ok or not name or name == "" then return nil, nil end
    local count = type(second) == "number" and fourth or third
    return name, tonumber(count)
end
