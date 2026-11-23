return function(ctx)
    local root = type(ctx) == "table" and ctx.root or ctx or "."
    dofile(root .. "/Forever.lua")
    dofile(root .. "/BridgeCC.lua")

    local TB = TortoiseBots
    local F = TB.Forever

    local origCapsKnown = TB.ServerCapabilitiesKnown
    local origUnitGUID = UnitGUID
    local origPartyCount = TB.PartyCount
    local origUnitExists = UnitExists
    local origUnitIsPlayer = UnitIsPlayer
    local origUnitInParty = UnitInParty
    local origUnitName = UnitName

    TB.ServerCapabilitiesKnown = function() return false end
    TB.PartyCount = function() return 0 end
    UnitExists = function(u) return u == "player" end
    UnitIsPlayer = function() return false end
    UnitInParty = function() return false end
    UnitName = function(u) if u == "player" then return "Tester" end return nil end

    -- CC clear works without target
    assert(F.Translate("action cc clear") == ".tb cmd cc clear")
    assert(F.Translate("action cc clear Alpha") == ".tb cmd cc clear Alpha")

    -- CC mark requires target GUID
    UnitGUID = function() return nil end
    assert(F.Translate("action cc moon") == nil)
    assert(F.Translate("action cc moon Alpha") == nil)
    assert(F.Translate("ignore add") == nil)

    -- With creature target GUID
    UnitGUID = function(u)
        if u == "target" then return "Creature-0-70-0-0-299-000000000E" end
        return nil
    end
    local hex = F.TargetGuidHex("target")
    assert(hex and #hex == 32)
    assert(F.Translate("action cc moon") == ".tb cmd cc moon " .. hex)
    assert(F.Translate("action cc moon Alpha") == ".tb cmd cc moon " .. hex .. " Alpha")
    assert(F.Translate("action cc star Alpha polymorph") == ".tb cmd cc star " .. hex .. " Alpha polymorph")
    assert(F.Translate("ignore add") == ".tb ignore party add " .. hex)
    assert(F.Translate("ignore remove") == ".tb ignore party remove " .. hex)

    -- F.Future.cc stays off (.tb cc ... allow|deny is a different feature)
    assert(F.Future.cc.on == false)

    TB.ServerCapabilitiesKnown = origCapsKnown
    UnitGUID = origUnitGUID
    TB.PartyCount = origPartyCount
    UnitExists = origUnitExists
    UnitIsPlayer = origUnitIsPlayer
    UnitInParty = origUnitInParty
    UnitName = origUnitName

    print("PASS: BridgeCC checks")
end
