-- TortoiseBotsForeverManager port lint.
-- The target is the WoW Forever client (modern Classic API), so this
-- replaces the upstream 1.12 lint: every file in the .toc must compile as Lua 5.1
-- and the addon may not call a removed 1.12 API or read a 1.12 script global
-- directly (Compat.lua owns the modern replacements). Globals and API names are
-- covered by luacheck (.luacheckrc).
--
-- Run with: lua5.1 tests/lint.lua .

local root = arg[1] or "."
local tocPath = root .. "/TortoiseBotsForeverManager.toc"

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local toc = read(tocPath)
assert(toc, "cannot read " .. tocPath)

-- Lua 5.1's parser rejects 5.0 escapes and other modern syntax the client lacks.
local files = {}
for raw in string.gmatch(toc, "[^\r\n]+") do
    local line = string.gsub(raw, "\r", "")
    if not string.find(line, "^##") and string.find(line, "%.lua%s*$") then
        local name = string.gsub(line, "%s+$", "")
        local path = root .. "/" .. name
        files[#files + 1] = name
        local chunk, err = loadfile(path)
        assert(chunk, name .. " does not compile on Lua 5.1: " .. tostring(err))
    end
end
assert(#files > 0, "the .toc lists no Lua files")
assert(read(root .. "/Compat.lua"), "Compat.lua is missing from the addon")

-- Comments and strings are stripped before the API scan: the help text names
-- commands, it does not call them.
local function strip(src)
    src = string.gsub(src, "%-%-%[(=*)%[.-%]%1%]", "")
    src = string.gsub(src, "%-%-[^\n]*", "")
    src = string.gsub(src, "%[(=*)%[.-%]%1%]", "")
    src = string.gsub(src, "\"[^\"\n]*\"", "\"\"")
    src = string.gsub(src, "'[^'\n]*'", "''")
    return src
end

-- Names the 1.12 client had and this one does not (or that must go through
-- Compat.lua so the fallback stays in one place).
local forbidden = {
    { "table.getn", "table.getn is Lua 5.0; use #" },
    { "getglobal", "getglobal is gone; use _G[...]" },
    { "setglobal", "setglobal is gone" },
    { "string.gfind", "string.gfind is gone; use string.gmatch" },
    { ":gfind", "string:gfind is gone; use :gmatch" },
    { "math.mod", "math.mod is gone; use math.fmod" },
    { "SendAddonMessage", "use TB.SendAddonMessageCompat (C_ChatInfo wrapper)" },
    { "RegisterAddonMessagePrefix", "use TB.RegisterAddonPrefix (C_ChatInfo wrapper)" },
    { "UnitMana", "use TB.UnitMana (UnitPower wrapper)" },
    { "UnitBuff", "use TB.BuffIcon (C_UnitAuras wrapper)" },
    { "GetContainerNumSlots", "use TB.BagSlots (C_Container wrapper)" },
    { "GetContainerItemLink", "use TB.BagLink (C_Container wrapper)" },
    { "GetContainerItemInfo", "use TB.BagInfo (C_Container wrapper)" },
    { "PickupContainerItem", "use TB.BagPickup (C_Container wrapper)" },
    { "SplitContainerItem", "use TB.BagSplit (C_Container wrapper)" },
    { "CursorHasItem", "use TB.BagCursorHasItem (C_Container wrapper)" },
    { "GetNumPartyMembers", "use TB.PartyCount (GetNumSubgroupMembers wrapper)" },
    { "GetNumRaidMembers", "use TB.RaidCount (IsInRaid/GetNumGroupMembers wrapper)" },
}

-- True when `needle` is called as a bare name: not a field of a table (TB.UnitMana)
-- and not part of a longer identifier (TB.SendAddonMessageCompat).
local function callsBare(src, needle)
    local pos = 1
    while true do
        local a, b = string.find(src, needle, pos, true)
        if not a then return false end
        local before = a > 1 and string.sub(src, a - 1, a - 1) or ""
        local after = string.sub(src, b + 1, b + 1)
        if before ~= "." and not string.match(before, "%w") and after ~= "_"
            and not string.match(after, "%w") then
            return true
        end
        pos = b + 1
    end
end

local failures = {}
for _, name in ipairs(files) do
    if name ~= "Compat.lua" then
        local src = strip(read(root .. "/" .. name) or "")
        for _, rule in ipairs(forbidden) do
            if callsBare(src, rule[1]) then
                failures[#failures + 1] = name .. ": " .. rule[1] .. " (" .. rule[2] .. ")"
            end
        end
        if string.find(src, "%f[%a]this%f[%A]") then
            failures[#failures + 1] = name .. ": legacy `this` global (handlers take self)"
        end
    end
end

-- The modern APIs must be reached through the shim.
local compat = read(root .. "/Compat.lua") or ""
for _, needle in ipairs({ "C_ChatInfo", "C_Container", "UnitPower", "GetNumSubgroupMembers", "IsInRaid" }) do
    if not string.find(compat, needle, 1, true) then
        failures[#failures + 1] = "Compat.lua does not use " .. needle
    end
end

if #failures > 0 then
    io.stderr:write("FAIL: port lint, " .. #failures .. " problem(s)\n")
    for _, line in ipairs(failures) do io.stderr:write("  " .. line .. "\n") end
    os.exit(1)
end
print("PASS: port lint, " .. #files .. " .toc files compile, no 1.12 API call left")
