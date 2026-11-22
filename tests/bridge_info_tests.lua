return function(root)
    dofile(root .. "/Forever.lua")
    dofile(root .. "/BridgeInfo.lua")

    local TB = TortoiseBots
    local F = TB.Forever

    local origCapsKnown = TB.ServerCapabilitiesKnown
    local origSetStatus = TB.SetStatus
    local origLogMessage = TB.LogMessage
    local origUnitName = UnitName

    TB.ServerCapabilitiesKnown = function() return false end
    UnitName = function(u) if u == "player" then return "Tester" end return nil end

    -- Translations
    assert(F.Translate("who") == ".bot who")
    assert(F.Translate("who all") == ".bot who all")
    assert(F.Translate("roster") == nil, "roster auto-poll must stay nil in bridge mode")

    assert(F.Translate("spec Alpha 1") == ".tb spec Alpha 1")
    assert(F.Translate("spec Alpha protection") == ".tb spec Alpha protection")
    assert(F.Translate("spec Alpha none") == ".tb spec Alpha none")
    assert(F.Translate("spec party protection") == ".tb spec party Tester protection")
    assert(F.Translate("spec Alpha") == nil)

    assert(F.Translate("talents Alpha") == ".tb talents Alpha")
    assert(F.Translate("talents") == nil)

    -- Reply parsing: .bot who
    local lastStatus, lastKind
    local logs = {}
    TB.SetStatus = function(text, kind) lastStatus, lastKind = text, kind end
    TB.LogMessage = function(clean, raw) table.insert(logs, { clean = clean, raw = raw }) end

    TB.OnSystemMessage("TortoiseBots: who: 2 bot(s)")
    assert(lastKind == "ok" and lastStatus == "Online bots: 2")
    assert(#F.WhoList == 0, "who header should reset WhoList")

    TB.OnSystemMessage("TortoiseBots: who: Alpha level 60 Warrior map 0 follow engine")
    TB.OnSystemMessage("TortoiseBots: who: Bravo level 58 Priest map 0 stay engine")
    assert(#F.WhoList == 2)
    assert(F.WhoList[1].name == "Alpha" and F.WhoList[1].level == 60 and F.WhoList[1].class == "Warrior")
    assert(F.WhoList[2].name == "Bravo" and F.WhoList[2].move == "stay")

    -- Reply parsing: .tb talents
    TB.OnSystemMessage("TortoiseBots: Alpha (level 60): spec=protection (tab 2) spent=51 (11/5/35) free=0 applied=51")
    assert(lastKind == "ok" and F.Talents["alpha"] ~= nil)
    assert(F.Talents["alpha"].spec == "protection" and F.Talents["alpha"].spent == 51 and F.Talents["alpha"].free == 0)

    -- Chat hiding for .bot who
    assert(F.ShouldHideChatMessage("CHAT_MSG_WHISPER_INFORM", ".bot who", "Tester") == true)
    assert(F.ShouldHideChatMessage("CHAT_MSG_WHISPER", ".bot who all", "Tester") == true)
    assert(F.ShouldHideChatMessage("CHAT_MSG_WHISPER", ".bot who", "SomeoneElse") == false)

    TB.ServerCapabilitiesKnown = origCapsKnown
    TB.SetStatus = origSetStatus
    TB.LogMessage = origLogMessage
    UnitName = origUnitName

    print("PASS: BridgeInfo checks")
end
