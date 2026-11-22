return function(root)
    dofile(root .. "/Forever.lua")
    dofile(root .. "/BridgeTactical.lua")

    local TB = TortoiseBots
    local F = TB.Forever

    local origCapsKnown = TB.ServerCapabilitiesKnown
    local origPartyCount = TB.PartyCount
    local origRaidCount = TB.RaidCount
    local origUnitExists = UnitExists
    local origUnitIsPlayer = UnitIsPlayer
    local origUnitIsUnit = UnitIsUnit
    local origUnitInParty = UnitInParty
    local origUnitInRaid = UnitInRaid
    local origUnitName = UnitName
    local origUnitGUID = UnitGUID

    TB.ServerCapabilitiesKnown = function() return false end
    TB.PartyCount = function() return 0 end
    TB.RaidCount = function() return 0 end
    UnitExists = function(u) return u == "player" end
    UnitIsPlayer = function() return false end
    UnitIsUnit = function(a, b) return a == b end
    UnitInParty = function() return false end
    UnitInRaid = function() return false end
    UnitName = function(u) if u == "player" then return "Tester" end return nil end
    UnitGUID = function() return nil end

    -- Simple M1 verbs (solo -> party)
    assert(F.Translate("action stop") == ".tb order party stop")
    assert(F.Translate("action flee") == ".tb order party flee")
    assert(F.Translate("action guard") == ".tb order party guard")
    assert(F.Translate("action rebuff") == ".tb order party rebuff")

    -- Stance words
    for _, w in ipairs({ "near", "tank", "turnback", "turn", "behind" }) do
        assert(F.Translate("action stance " .. w) == ".tb order party stance " .. w)
    end
    assert(F.Translate("action stance bogus") == nil)
    assert(F.Translate("action stance") == nil)

    -- Engage with and without seconds (0-60)
    assert(F.Translate("action engage") == ".tb order party engage")
    assert(F.Translate("action engage 0") == ".tb order party engage 0")
    assert(F.Translate("action engage 5") == ".tb order party engage 5")
    assert(F.Translate("action engage 60") == ".tb order party engage 60")
    assert(F.Translate("action engage 61") == nil)

    -- Interrupt: without target guid -> .tb order party interrupt my
    assert(F.Translate("action interrupt") == ".tb order party interrupt my")
    assert(F.Available("action interrupt") == true)

    -- Interrupt: with creature target guid -> .tb cmd interrupt <hex32>
    UnitGUID = function(u)
        if u == "target" then return "Creature-0-70-0-0-299-000000000E" end
        return nil
    end
    local hex = F.TargetGuidHex("target")
    assert(hex and #hex == 32, "TargetGuidHex should produce 32-hex guid")
    assert(F.Translate("action interrupt") == ".tb cmd interrupt " .. hex)

    -- Party scope when grouped
    UnitGUID = function() return nil end
    TB.PartyCount = function() return 2 end
    assert(F.Translate("action stop") == ".tb order party Tester stop")

    -- Existing RefreshActionControls gating un-greys bridged tactical buttons
    if TB.RefreshActionControls and TB.actionButtons and TB.actionButtons.stop then
        TB.RefreshActionControls()
        assert(TB.actionButtons.stop.enabled == true, "stop button should be enabled when BridgeTactical is loaded")
        assert(not TB.actionButtons.stop._foreverMarked, "stop button should not be marked unavailable")
    end

    -- Restore globals
    TB.ServerCapabilitiesKnown = origCapsKnown
    TB.PartyCount = origPartyCount
    TB.RaidCount = origRaidCount
    UnitExists = origUnitExists
    UnitIsPlayer = origUnitIsPlayer
    UnitIsUnit = origUnitIsUnit
    UnitInParty = origUnitInParty
    UnitInRaid = origUnitInRaid
    UnitName = origUnitName
    UnitGUID = origUnitGUID

    print("PASS: BridgeTactical checks")
end
