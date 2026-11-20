-- Forever bridge tests (loaded only here so native regression tests stay untouched).
return function(ctx)
    local root = ctx.root or "."
    local chatFilters = ctx.chatFilters or {}

    dofile(root .. "/Forever.lua")

    local TB = TortoiseBots
    local F = TB.Forever
    assert(F, "TB.Forever should load")

    -- Save globals we temporarily override
    local origCapsKnown = TB.ServerCapabilitiesKnown
    local origSetStatus = TB.SetStatus
    local origLogMessage = TB.LogMessage
    local origSendChatMessage = SendChatMessage
    local origPartyCount = TB.PartyCount
    local origRaidCount = TB.RaidCount
    local origUnitExists = UnitExists
    local origUnitIsPlayer = UnitIsPlayer
    local origUnitIsUnit = UnitIsUnit
    local origUnitInParty = UnitInParty
    local origUnitInRaid = UnitInRaid
    local origUnitName = UnitName

    local function resetScope()
        TB.ServerCapabilitiesKnown = function() return false end
        TB.PartyCount = function() return 0 end
        TB.RaidCount = function() return 0 end
        UnitExists = function(u) return u == "player" end
        UnitIsPlayer = function() return false end
        UnitIsUnit = function(a, b) return a == b end
        UnitInParty = function() return false end
        UnitInRaid = function() return false end
        UnitName = function(u) if u == "player" then return "Tester" end return nil end
    end

    resetScope()

    -- 1. Translation table cases: available intents (solo -> party)
    local intentCases = {
        { "action attack", ".tb order party attack my" },
        { "action pull", ".tb order party pull my" },
        { "action pull 5", ".tb order party pull my" },
        { "action end pull", ".tb order party endpull" },
        { "action follow", ".tb order party follow" },
        { "action stay", ".tb order party stay" },
        { "action come", ".tb order party come" },
        { "action free", ".tb order party free" },
        { "action release", ".tb order party release" },
    }
    for _, c in ipairs(intentCases) do
        local got = F.Translate(c[1])
        assert(got == c[2], string.format("Translate(%q): expected %q, got %q", c[1], c[2], tostring(got)))
        assert(F.Available(c[1]) == true, "Available(" .. c[1] .. ") should be true")
    end

    -- Non-action translations
    assert(F.Translate("add Alpha") == ".tb login Alpha Tester")
    assert(F.Translate("remove Alpha") == ".tb logout Alpha")
    assert(F.Translate("logout Alpha") == ".tb logout Alpha")
    assert(F.Translate("invite Alpha") == ".tb group Alpha Tester")
    assert(F.Translate("uninvite Alpha") == ".tb ungroup Alpha")
    assert(F.Translate("summon Alpha") == ".tb tele Alpha to Tester")
    assert(F.Translate("role Alpha tank") == ".tb role Alpha tank")
    assert(F.Translate("role Alpha heal") == ".tb role Alpha healer")
    assert(F.Translate("role Alpha healer") == ".tb role Alpha healer")
    assert(F.Translate("role Alpha dps") == ".tb role Alpha dps")
    assert(F.Translate("role Alpha none") == ".tb role Alpha none")
    assert(F.Translate("role self tank") == nil)

    -- Unknown / unsupported -> nil
    for _, unk in ipairs({ "action stop", "action flee", "roster", "alts", "", "unknowncmd Alpha" }) do
        assert(F.Translate(unk) == nil, "Translate(" .. unk .. ") should be nil")
        assert(F.Available(unk) == false, "Available(" .. unk .. ") should be false")
    end

    -- Party scope when player is in a group
    TB.PartyCount = function() return 1 end
    assert(F.Translate("action stay") == ".tb order party Tester stay",
        "party scope should include player name when in a party")

    -- Bot-target scope overrides party scope
    UnitExists = function(u) return u == "player" or u == "target" end
    UnitIsPlayer = function(u) return u == "target" end
    UnitIsUnit = function(a, b) return a == b end
    UnitInParty = function(u) return u == "target" end
    UnitName = function(u)
        if u == "player" then return "Tester" end
        if u == "target" then return "Alpha" end
        return nil
    end
    assert(F.Translate("action attack") == ".tb order Alpha attack my",
        "targeting a party bot should scope orders to that bot")

    -- Targeting self falls back to party scope
    UnitIsUnit = function(a, b) return (a == "target" and b == "player") or a == b end
    assert(F.Translate("action attack") == ".tb order party Tester attack my",
        "targeting self should use party scope")

    resetScope()

    -- 2. Native() true disables translation requirement for Available()
    TB.ServerCapabilitiesKnown = function() return true end
    assert(F.Native() == true, "Native() should be true when ServerCapabilitiesKnown() is true")
    assert(F.Available("roster") == true, "Available should return true when Native() is true")
    assert(F.Available("action stop") == true, "Available should return true for all commands when Native() is true")

    resetScope()

    -- 3. Send uses WHISPER to self
    local sentWhispers = {}
    SendChatMessage = function(msg, chatType, lang, target)
        table.insert(sentWhispers, { msg = msg, chatType = chatType, lang = lang, target = target })
    end
    local lastStatus, lastStatusKind
    TB.SetStatus = function(text, kind)
        lastStatus, lastStatusKind = text, kind
    end
    local logs = {}
    TB.LogMessage = function(clean, raw)
        table.insert(logs, { clean = clean, raw = raw })
    end

    assert(F.Send("action stay") == true, "F.Send should succeed for available command")
    assert(#sentWhispers == 1, "F.Send should call SendChatMessage once")
    assert(sentWhispers[1].msg == ".tb order party stay", "F.Send should send translated command")
    assert(sentWhispers[1].chatType == "WHISPER", "F.Send should use WHISPER")
    assert(sentWhispers[1].target == "Tester", "F.Send should whisper self")

    assert(F.Send("action stop") == false, "F.Send should return false for unavailable command")
    assert(lastStatusKind == "warn", "F.Send unavailable should set warn status")

    -- 4. Reply parsing cases (via TB.OnSystemMessage)
    lastStatus, lastStatusKind = nil, nil
    logs = {}
    TB.OnSystemMessage("TortoiseBots: Alpha is logging in.")
    assert(lastStatus == "Alpha is logging in." and lastStatusKind == "ok",
        "TortoiseBots login reply should set ok status")
    assert(#logs == 1 and logs[1].clean == "Alpha is logging in.", "TortoiseBots reply should log")

    TB.OnSystemMessage("TortoiseBots: Alpha not logged in: already online.")
    assert(lastStatusKind == "warn", "TortoiseBots failure reply should set warn status")

    -- Order success sequence
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("order-begin")
    TB.OnSystemMessage("order bot=Alpha verb=attack seq=1 status=queued")
    TB.OnSystemMessage("order-end count=1 records=1 verb=attack target=party bots=1 queued=1 refused=0")
    assert(lastStatusKind == "ok" and string.find(lastStatus or "", "attack", 1, true),
        "order-end with refused=0 should set ok status")

    -- Order refusal sequence (readable code)
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("order-begin")
    TB.OnSystemMessage("order bot=Alpha verb=attack status=refused code=no-engine msg=the%20bot%20has%20no%20running%20engine")
    TB.OnSystemMessage("order-end count=1 records=1 verb=attack target=party bots=1 queued=0 refused=1")
    assert(lastStatusKind == "warn", "order-end with refused=1 should set warn status")
    assert(string.find(lastStatus or "", "no engine running", 1, true),
        "refused code should be shown readable: " .. tostring(lastStatus))

    -- Role sequence
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("role-begin")
    TB.OnSystemMessage("role bot=Alpha role=tank status=stored")
    TB.OnSystemMessage("role-end count=1 records=1 role=tank target=Alpha bots=1 queued=0")
    assert(lastStatusKind == "ok" and string.find(lastStatus or "", "tank", 1, true),
        "role-end should set ok status")

    -- Tele sequence
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("tele-begin")
    TB.OnSystemMessage("tele bot=Alpha to=Tester status=started")
    TB.OnSystemMessage("tele-end count=1 records=1 target=Alpha bots=1 started=1 refused=0")
    assert(lastStatusKind == "ok" and string.find(lastStatus or "", "Teleport", 1, true),
        "tele-end should set ok status")

    -- One-line error reply
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("error code=no-such-player cmd=order msg=Alpha%20is%20not%20in%20the%20world")
    assert(lastStatusKind == "warn", "error reply should set warn status")
    assert(string.find(lastStatus or "", "not in world", 1, true)
        and string.find(lastStatus or "", "Alpha is not in the world", 1, true),
        "error reply should decode msg and format readable code: " .. tostring(lastStatus))

    -- Missing permission reply
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("You do not have permission to perform that function.")
    assert(lastStatusKind == "warn"
        and string.find(lastStatus or "", "needs a GM account (.tb test commands)", 1, true),
        "missing permission should mention GM account (.tb test commands)")

    -- Native() true bypasses Forever system message parser
    TB.ServerCapabilitiesKnown = function() return true end
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("TortoiseBots: Alpha is logging in.")
    assert(lastStatus == nil, "Forever OnSystemMessage should not run when Native() is true")
    resetScope()

    -- 5. Chat filter cases
    assert(chatFilters.CHAT_MSG_WHISPER_INFORM(nil, "CHAT_MSG_WHISPER_INFORM", ".tb order party stay", "Tester") == true,
        "outgoing .tb whisper echo should be hidden")
    assert(chatFilters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", ".tb order party stay", "Tester") == true,
        "self .tb whisper should be hidden")
    assert(not chatFilters.CHAT_MSG_WHISPER(nil, "CHAT_MSG_WHISPER", ".tb order party stay", "SomeoneElse"),
        "whisper from another player should stay visible")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "order-begin") == true,
        "order-begin should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "order bot=Alpha verb=attack seq=1 status=queued") == true,
        "per-bot order line should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "order-end count=1 records=1 verb=attack target=party bots=1 queued=1 refused=0") == true,
        "order-end should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "role-begin") == true,
        "role-begin should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "tele-begin") == true,
        "tele-begin should be hidden")
    assert(not chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "error code=no-such-player cmd=order msg=Alpha%20is%20not%20in%20the%20world"),
        "error lines must stay visible in chat")
    assert(not chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "You do not have permission to perform that function."),
        "permission errors must stay visible in chat")

    -- Restore globals
    TB.ServerCapabilitiesKnown = origCapsKnown
    TB.SetStatus = origSetStatus
    TB.LogMessage = origLogMessage
    SendChatMessage = origSendChatMessage
    TB.PartyCount = origPartyCount
    TB.RaidCount = origRaidCount
    UnitExists = origUnitExists
    UnitIsPlayer = origUnitIsPlayer
    UnitIsUnit = origUnitIsUnit
    UnitInParty = origUnitInParty
    UnitInRaid = origUnitInRaid
    UnitName = origUnitName

    print("PASS: Forever bridge checks")
end
