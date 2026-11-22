return function(root)
    dofile(root .. "/Forever.lua")
    dofile(root .. "/BridgeUpkeep.lua")

    local TB = TortoiseBots
    local F = TB.Forever

    local origCapsKnown = TB.ServerCapabilitiesKnown
    local origSetStatus = TB.SetStatus
    local origLogMessage = TB.LogMessage
    local origSendChatMessage = SendChatMessage
    local origUnitName = UnitName

    TB.ServerCapabilitiesKnown = function() return false end
    UnitName = function(u) if u == "player" then return "Tester" end return nil end

    -- Player commands sent as typed .bot chat
    assert(F.Translate("maintenance Alpha") == ".bot maintenance Alpha")
    assert(F.Translate("maintenance") == nil)
    assert(F.Translate("autogear Alpha") == ".bot autogear Alpha")
    assert(F.Translate("autogear Alpha blue") == ".bot autogear Alpha blue")
    assert(F.Translate("autogear Alpha 60") == ".bot autogear Alpha 60")
    assert(F.Translate("command Alpha d equip upgrades") == ".tb gear Alpha upgrade")
    assert(F.Translate("stats Alpha") == ".bot stats Alpha")
    assert(F.Translate("stats") == nil)

    local sentWhispers = {}
    SendChatMessage = function(msg, chatType, lang, target)
        table.insert(sentWhispers, { msg = msg, chatType = chatType, target = target })
    end
    assert(F.Send("maintenance Alpha") == true)
    assert(#sentWhispers == 1 and sentWhispers[1].msg == ".bot maintenance Alpha"
        and sentWhispers[1].chatType == "WHISPER" and sentWhispers[1].target == "Tester")

    -- Reply parsing
    local lastStatus, lastKind
    TB.SetStatus = function(text, kind) lastStatus, lastKind = text, kind end
    TB.LogMessage = function() end

    TB.OnSystemMessage("TortoiseBots: maintenance Alpha: ok 4 item(s) granted, repaired, saved")
    assert(lastKind == "ok" and string.find(lastStatus or "", "Maintenance Alpha", 1, true))

    TB.OnSystemMessage("TortoiseBots: maintenance: refused disabled: player maintenance is disabled")
    assert(lastKind == "warn" and string.find(lastStatus or "", "maintenance", 1, true))

    TB.OnSystemMessage("Re-geared Alpha within the configured caps.")
    assert(lastKind == "ok" and string.find(lastStatus or "", "Re-geared Alpha", 1, true))

    TB.OnSystemMessage("TortoiseBots: stats Alpha: ok level 60 Warrior, 100% hp, 0% mana, 12g 34s 56c, zone 1519 Stormwind City, alive, follow")
    assert(lastKind == "ok" and F.Stats["alpha"] ~= nil and string.find(F.Stats["alpha"], "level 60 Warrior", 1, true))

    -- Chat hiding for .bot maintenance/autogear/stats
    assert(F.ShouldHideChatMessage("CHAT_MSG_WHISPER_INFORM", ".bot maintenance Alpha", "Tester") == true)
    assert(F.ShouldHideChatMessage("CHAT_MSG_WHISPER", ".bot autogear Alpha", "Tester") == true)
    assert(F.ShouldHideChatMessage("CHAT_MSG_WHISPER", ".bot stats Alpha", "SomeoneElse") == false)

    TB.ServerCapabilitiesKnown = origCapsKnown
    TB.SetStatus = origSetStatus
    TB.LogMessage = origLogMessage
    SendChatMessage = origSendChatMessage
    UnitName = origUnitName

    print("PASS: BridgeUpkeep checks")
end
