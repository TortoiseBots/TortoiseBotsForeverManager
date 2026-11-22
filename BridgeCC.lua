-- Forever bridge: M4 whole-party CC pick/clear (needs TBF PR #208) and `.tb ignore`.

TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
TB.Forever = TB.Forever or {}
local F = TB.Forever

local CC_MARKS = {
    star     = true,
    circle   = true,
    diamond  = true,
    triangle = true,
    moon     = true,
    square   = true,
    cross    = true,
    skull    = true,
}

local function translate(cmd, verb, rest, orderScope)
    local trimmed = F.Trim and F.Trim(rest) or rest or ""
    if verb == "ignore" then
        local op = string.lower(trimmed)
        if op ~= "add" and op ~= "remove" then return nil end
        local guid = F.TargetGuidHex and F.TargetGuidHex()
        if not guid then return nil end
        return ".tb ignore " .. orderScope() .. " " .. op .. " " .. guid
    end

    if verb ~= "action" then return nil end
    local ccTail = string.match(string.lower(trimmed), "^cc%s+(.+)$")
    if not ccTail then return nil end

    if ccTail == "clear" then
        return ".tb cmd cc clear"
    end
    local clearBot = string.match(trimmed, "^[Cc][Cc]%s+[Cc][Ll][Ee][Aa][Rr]%s+(%S+)$")
    if clearBot then
        return ".tb cmd cc clear " .. clearBot
    end

    local mark, extra = string.match(trimmed, "^[Cc][Cc]%s+(%S+)%s*(.*)$")
    if mark and CC_MARKS[string.lower(mark)] then
        local guid = F.TargetGuidHex and F.TargetGuidHex()
        if not guid then return nil end
        local base = ".tb cmd cc " .. string.lower(mark) .. " " .. guid
        if extra and extra ~= "" then
            return base .. " " .. extra
        end
        return base
    end

    return nil
end

if not F._bridgeCC then
    F._bridgeCC = true
    F.Translators = F.Translators or {}
    table.insert(F.Translators, translate)
end
