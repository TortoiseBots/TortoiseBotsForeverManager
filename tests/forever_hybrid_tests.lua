-- Forever hybrid transport tests (TBM:VERBS + per-command routing + tb-gm gating).
return function(ctx)
    local root = (type(ctx) == "table" and ctx.root) or ctx or "."
    local sent = type(ctx) == "table" and ctx.sent or nil
    local addonSent = type(ctx) == "table" and ctx.addonSent or nil
    local advanceTime = type(ctx) == "table" and ctx.advanceTime or nil

    dofile(root .. "/Forever.lua")
    dofile(root .. "/ForeverHybrid.lua")

    local TB = TortoiseBots
    local F = TB.Forever
    assert(F and F.Route and F.IsVerbNative and F.BridgeAllowed, "ForeverHybrid.lua should load")

    local savedParty = TB.PartyCount
    local savedCanSendAddon = TB.CanSendAddon
    local savedSetStatus = TB.SetStatus
    local savedLogMessage = TB.LogMessage

    TB.SetStatus = function() end
    TB.LogMessage = function() end
    TB.CanSendAddon = function() return true end

    local function resetState()
        TB.ClearServerVerbs()
        TB.OnSystemMessage("TBM:CAPS|")
        TB._serverCaps = {}
        if TB.InvalidateAddonTransport then TB.InvalidateAddonTransport() end
    end

    -- 1. Pre-handshake: VERBS unknown, CAPS unknown -> bridge for translated, grey for untranslated,
    --    and silent PARTY probe for bootstrapping "roster".
    resetState()
    local savedCapsKnown = TB.ServerCapabilitiesKnown
    TB.ServerCapabilitiesKnown = function() return false end

    assert(F.Native() == false, "pre-handshake Native() is false")
    assert(F.BridgeAllowed() == true, "pre-handshake BridgeAllowed() is true (legacy GM bootstrap)")
    assert(F.Route("roster") == "grey", "roster is grey before VERBS arrives")
    assert(F.Route("action follow") == "bridge", "action follow routes to bridge before VERBS")
    assert(F.Route("action stop") == "grey", "action stop is grey before VERBS")

    if sent and addonSent and advanceTime then
        TB.PartyCount = function() return 1 end
        local addonBefore = #addonSent
        local chatBefore = #sent
        local ok = TB.SendBotCommand("roster")
        assert(ok == false, "pre-handshake roster returns false (probe only)")
        assert(#addonSent == addonBefore + 1 and addonSent[#addonSent].message == "roster"
            and addonSent[#addonSent].channel == "PARTY",
            "bootstrapping roster probe must still go out over PARTY")
        assert(#sent == chatBefore, "bootstrapping roster probe must not go to chat")
    end

    -- 2. TBM:VERBS parsing + per-command routing for GM (CAPS includes tb-gm).
    TB.OnSystemMessage("TBM:TRANSPORT|party")
    TB.OnSystemMessage("TBM:VERBS|roster, add, action:follow|action:pull")
    TB.ServerCapabilitiesKnown = function() return true end
    TB.OnSystemMessage("TBM:CAPS|order,tb-gm")

    assert(TB.ServerVerbsKnown() == true, "TBM:VERBS sets ServerVerbsKnown")
    assert(TB.HasServerVerb("roster"), "VERBS parses comma-separated token")
    assert(TB.HasServerVerb("add"), "VERBS trims whitespace")
    assert(TB.HasServerVerb("action:follow"), "VERBS parses action:intent token")
    assert(TB.HasServerVerb("action:pull"), "VERBS parses pipe-separated token")
    assert(not TB.HasServerVerb("action:stay"), "unlisted token is not in VERBS")

    assert(F.Native() == false, "hybrid server: whole-server Native() stays false")
    assert(F.BridgeAllowed() == true, "GM with tb-gm cap has BridgeAllowed() == true")
    assert(F.Native("roster") == true, "listed verb is native")
    assert(F.Native("add Alpha") == true, "listed verb with args is native")
    assert(F.Native("action follow") == true, "listed action:intent is native")
    assert(F.Native("action pull 5") == true, "action pull with seconds matches action:pull")
    assert(F.Native("action stay") == false, "unlisted action:stay is not native")
    assert(F.Native("action stop") == false, "unlisted action:stop is not native")

    assert(F.Route("roster") == "native", "roster routes native")
    assert(F.Route("action follow") == "native", "action follow routes native")
    assert(F.Route("action stay") == "bridge", "action stay routes bridge for GM (tb-gm)")
    assert(F.Route("action stop") == "grey", "action stop routes grey")

    if sent and addonSent and advanceTime then
        advanceTime(5)
        local addonBefore = #addonSent
        local chatBefore = #sent
        assert(TB.SendBotCommand("action follow"), "native action follow sends")
        assert(#addonSent == addonBefore + 1 and addonSent[#addonSent].message == "action follow",
            "native command goes over addon channel")
        assert(#sent == chatBefore, "native command does not whisper .tb")

        advanceTime(5)
        addonBefore = #addonSent
        chatBefore = #sent
        assert(TB.SendBotCommand("action stay"), "bridged action stay sends for GM")
        assert(#sent == chatBefore + 1 and string.find(sent[#sent], "^%.tb order "),
            "bridged command goes as .tb whisper")
        assert(#addonSent == addonBefore, "bridged command does not go over addon channel")
    end

    -- 3. Gating repaint when VERBS changes.
    TB.RefreshActionControls()
    local stopBtn = TB.actionButtons.stop
    local followBtn = TB.actionButtons.follow
    local stayBtn = TB.actionButtons.stay
    assert(followBtn.enabled == true and not followBtn._foreverMarked, "native follow button is lit")
    assert(stayBtn.enabled == true and not stayBtn._foreverMarked, "bridged stay button is lit for GM")
    assert(stopBtn.enabled == false and stopBtn._foreverMarked == true, "unlisted stop button is grey")
    assert(TB.rosterFrame and TB.rosterFrame._wipBanner and not TB.rosterFrame._wipBanner:IsVisible(),
        "Roster WIP banner hides once roster is in VERBS")

    TB.OnSystemMessage("TBM:VERBS|roster,action:follow,action:stop")
    assert(stopBtn.enabled == true and not stopBtn._foreverMarked,
        "adding action:stop to VERBS repaints and enables stop button")

    TB.OnSystemMessage("TBM:VERBS|roster,action:follow")
    assert(stopBtn.enabled == false and stopBtn._foreverMarked == true,
        "removing action:stop from VERBS repaints and greys stop button again")

    -- 4. Non-GM player: VERBS + CAPS without tb-gm -> native controls lit, bridge-only controls grey.
    TB.OnSystemMessage("TBM:VERBS|roster,action:follow")
    TB.OnSystemMessage("TBM:CAPS|order")
    assert(F.BridgeAllowed() == false, "non-GM without tb-gm has BridgeAllowed() == false")
    assert(F.Route("action follow") == "native", "native command stays native for non-GM")
    assert(F.Route("action stay") == "grey", "bridge-only command becomes grey for non-GM")
    assert(followBtn.enabled == true and not followBtn._foreverMarked, "native follow stays lit for non-GM")
    assert(stayBtn.enabled == false and stayBtn._foreverMarked == true, "bridge-only stay goes grey for non-GM")

    if sent and addonSent and advanceTime then
        advanceTime(5)
        local chatBefore = #sent
        assert(TB.SendBotCommand("action stay") == false, "non-GM does not send bridge whisper")
        assert(#sent == chatBefore, "non-GM bridge command does not whisper .tb")
    end

    -- Re-granting tb-gm in CAPS restores bridge controls.
    TB.OnSystemMessage("TBM:CAPS|order,tb-gm")
    assert(F.BridgeAllowed() == true, "tb-gm in CAPS restores BridgeAllowed()")
    assert(F.Route("action stay") == "bridge", "bridge-only command restores with tb-gm")
    assert(stayBtn.enabled == true and not stayBtn._foreverMarked, "stay button re-enables with tb-gm")

    -- 5. Empty TBM:VERBS| does NOT fall back to old-server all-native.
    TB.OnSystemMessage("TBM:VERBS|")
    assert(TB.ServerVerbsKnown() == true, "empty TBM:VERBS| still marks verbs known")
    assert(F.Native() == false, "empty TBM:VERBS| is not all-native")
    assert(F.Route("roster") == "grey", "empty TBM:VERBS| keeps roster grey")

    -- 6. Old-server fallback: TBM:CAPS present without TBM:VERBS -> all native.
    resetState()
    TB.ServerCapabilitiesKnown = function() return true end
    TB.OnSystemMessage("TBM:CAPS|order")
    assert(TB.ServerVerbsKnown() == false, "no VERBS line leaves ServerVerbsKnown false")
    assert(F.Native() == true, "old-server fallback: Native() is true")
    assert(F.Native("action stop") == true, "old-server fallback: every command is native")
    assert(F.Route("action stop") == "native", "old-server fallback: Route is native")

    -- 7. FakeServer handshake emits TBM:VERBS before TBM:CAPS.
    resetState()
    TB.ServerCapabilitiesKnown = savedCapsKnown
    TB.SetFakeServer(true)
    if advanceTime then advanceTime(5) end
    assert(TB.SendBotCommand("roster"), "FakeServer answers roster")
    assert(TB.ServerVerbsKnown() == true and TB.HasServerVerb("roster"),
        "FakeServer handshake populates TBM:VERBS")
    TB.SetFakeServer(false)

    -- Cleanup
    resetState()
    TB.ServerCapabilitiesKnown = savedCapsKnown
    TB.PartyCount = savedParty
    TB.CanSendAddon = savedCanSendAddon
    TB.SetStatus = savedSetStatus
    TB.LogMessage = savedLogMessage
    TB.Forever = nil
    TB.RefreshActionControls()
    TB.RefreshVersionLine()
    print("PASS: Forever hybrid transport checks")
end
