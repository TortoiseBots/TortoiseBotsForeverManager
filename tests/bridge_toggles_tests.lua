return function(root)
    dofile(root .. "/Forever.lua")
    dofile(root .. "/BridgeToggles.lua")

    local TB = TortoiseBots
    local F = TB.Forever

    local origCapsKnown = TB.ServerCapabilitiesKnown
    local origOnPartyToggleResult = TB.OnPartyToggleResult
    local origSetStatus = TB.SetStatus
    local origLogMessage = TB.LogMessage

    TB.ServerCapabilitiesKnown = function() return false end

    -- Toggles translate to .tb cmd
    assert(F.Translate("action aoe") == ".tb cmd aoe")
    assert(F.Translate("action aoe on") == ".tb cmd aoe on")
    assert(F.Translate("action aoe off") == ".tb cmd aoe off")
    assert(F.Translate("action aoe status") == ".tb cmd aoe status")
    assert(F.Translate("action aoe bogus") == nil)

    assert(F.Translate("action autocc") == ".tb cmd autocc")
    assert(F.Translate("action auto cc on") == ".tb cmd autocc on")
    assert(F.Translate("action auto cc off") == ".tb cmd autocc off")
    assert(F.Translate("action auto cc status") == ".tb cmd autocc status")

    assert(F.Translate("action sap on") == ".tb cmd sap on")
    assert(F.Translate("action sap off") == ".tb cmd sap off")
    assert(F.Translate("action loot on") == ".tb cmd loot on")
    assert(F.Translate("action loot status") == ".tb cmd loot status")

    -- Corpse run
    assert(F.Translate("action corpse run") == ".tb cmd corpserun")
    assert(F.Translate("action corpserun") == ".tb cmd corpserun")

    -- Toggle reply updates party toggle state and Forever.lua still completes batch
    local capturedKey, capturedScope, capturedVal
    TB.OnPartyToggleResult = function(key, scope, val)
        capturedKey, capturedScope, capturedVal = key, scope, val
    end
    local lastStatus, lastKind
    TB.SetStatus = function(text, kind) lastStatus, lastKind = text, kind end
    TB.LogMessage = function() end

    TB.OnSystemMessage("cmd-begin")
    TB.OnSystemMessage("cmd verb=aoe status=accepted bots=3 result=party%203 state=on")
    TB.OnSystemMessage("cmd-end count=1 records=1 verb=aoe lead=Tester bots=3 ok=3 refused=0")
    assert(capturedKey == "aoe" and capturedScope == "party 3" and capturedVal == "on",
        "cmd toggle reply should update party toggle state")
    assert(lastKind == "ok" and string.find(lastStatus or "", "aoe", 1, true),
        "cmd-end should still emit ok status")

    -- Order status=read reply
    capturedKey, capturedScope, capturedVal = nil, nil, nil
    TB.OnSystemMessage("order-begin")
    TB.OnSystemMessage("order bot=Alpha verb=autocc status=read state=off")
    TB.OnSystemMessage("order-end count=1 records=1 verb=autocc bots=1 read=1 queued=0 refused=0")
    assert(capturedKey == "autocc" and capturedScope == "bot:Alpha" and capturedVal == "off",
        "order status=read reply should update toggle state")

    TB.ServerCapabilitiesKnown = origCapsKnown
    TB.OnPartyToggleResult = origOnPartyToggleResult
    TB.SetStatus = origSetStatus
    TB.LogMessage = origLogMessage

    print("PASS: BridgeToggles checks")
end
