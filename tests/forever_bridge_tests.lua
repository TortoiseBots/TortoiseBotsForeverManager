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
    local origUnitGUID = UnitGUID

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
        { "action repair", ".tb order party repair" },
        { "action sell", ".tb order party sell" },
        { "action learn", ".tb order party train" },
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
    assert(F.Translate("role self tank") == ".tb role tank")
    assert(F.Translate("role self healer") == ".tb role healer")
    assert(F.Translate("role self bogus") == nil)
    assert(F.Translate("command Alpha d equip upgrades") == ".tb gear Alpha upgrade")
    assert(F.Translate("command Alpha d something else") == nil)
    assert(F.Translate("command Alpha accept") == ".tb quest Alpha accept *", "quest accept should translate")
    assert(F.Available("command Alpha accept") == true, "quest accept should be available")
    assert(F.Translate("command Alpha share") == nil, "quest share needs an id the panel has not")

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

    -- 6. Gear upgrades and planned twins
    assert(F.Translate("autogear Alpha") == ".tb gear Alpha upgrade",
        "autogear should translate to .tb gear upgrade")
    assert(F.Available("autogear Alpha") == true, "autogear should be available")
    assert(F.Translate("autogear") == nil, "bare autogear should stay nil")
    assert(F.Send("autogear Alpha") == true, "F.Send should send gear upgrades")

    -- Live twins: rest and use travel as `.tb cmd` now.
    assert(F.Future.rest.on == true, "rest row should be switched on")
    assert(F.Translate("action rest") == ".tb cmd rest", "action rest should translate")
    assert(F.Available("action rest") == true, "action rest should be available")
    assert(F.Future.use.on == true, "use row should be switched on")
    assert(F.Translate("action use") == ".tb cmd use my", "action use should target the commander's target")
    assert(F.Available("action use") == true, "action use should be available")

    -- Still waiting: CC permissions have no panel intent.
    assert(F.Future.cc and F.Future.cc.on == false, "cc row should ship switched off")
    assert(F.Translate("action cc moon Alpha") == nil, "cc mark should stay nil")
    F.Future.cc.on = true
    assert(F.Translate("action cc moon Alpha") == ".tb cc moon Alpha", "cc should translate once on")
    F.Future.cc.on = false
    assert(F.Translate("action cc moon Alpha") == nil, "cc row must be off again after the check")

    -- 7. Target guid conversion (UnitGUID -> 32 hex chars)
    local WOLF = "2001180000004AC0000000000000000E"
    local CHEST = "2C011800000C0E40000000000000ABCD"
    local PLAYER_GUID = "0801180000000000000000000000002A"
    UnitGUID = function(u)
        if u == "target" then return "Creature-0-70-0-0-299-000000000E" end
        return nil
    end
    assert(F.TargetGuidHex() == WOLF, "young wolf example must convert")
    UnitGUID = function() return "GameObject-0-70-0-0-12345-000000ABCD" end
    assert(F.TargetGuidHex() == CHEST, "game object must convert")
    UnitGUID = function() return "Player-70-0000002A" end
    assert(F.TargetGuidHex() == PLAYER_GUID, "player guid must convert")
    for _, bad in ipairs({
        "Critter-0-70-0-0-299-000000000E",
        "Creature-0-70-0-0-299-XYZ",
        "Creature-0-70-0-0-99999999-000000000E",
        "Creature-0-70-0-0-299-1FFFFFFFFFF",
        "Creature-0-70-0-0-299",
        "Player-70",
        "",
    }) do
        UnitGUID = function() return bad end
        assert(F.TargetGuidHex() == nil, "bad guid " .. bad .. " must not convert")
    end
    UnitGUID = nil
    assert(F.TargetGuidHex() == nil, "no UnitGUID API must not convert")

    -- Target-taking verbs ride `.tb cmd` with a guid, else the old path.
    UnitGUID = function() return "Creature-0-70-0-0-299-000000000E" end
    assert(F.Translate("action attack") == ".tb cmd attack " .. WOLF, "attack should use cmd with a guid")
    assert(F.Translate("action pull") == ".tb cmd pull " .. WOLF, "pull should use cmd with a guid")
    assert(F.Translate("action pull 5") == ".tb cmd pull " .. WOLF, "pull timer is dropped on the cmd path too")
    assert(F.Translate("action pullback") == ".tb cmd pullback " .. WOLF, "pullback should use cmd with a guid")
    assert(F.Translate("action focus skull") == ".tb cmd focus " .. WOLF, "focus should use cmd with a guid")
    UnitGUID = function() return nil end
    assert(F.Translate("action attack") == ".tb order party attack my", "attack keeps the order path without a guid")
    assert(F.Translate("action pull") == ".tb order party pull my", "pull keeps the order path without a guid")
    assert(F.Translate("action pullback") == nil, "pullback stays greyed without a guid")
    assert(F.Translate("action focus skull") == nil, "focus stays greyed without a guid")
    UnitGUID = nil

    -- Ignore add/remove on the target
    UnitGUID = function() return "Creature-0-70-0-0-299-000000000E" end
    local sentBefore = #sentWhispers
    assert(F.IgnoreTarget(true) == true, "ignore add should send")
    assert(sentWhispers[#sentWhispers].msg == ".tb ignore party add " .. WOLF,
        "ignore add should name the solo party and the guid")
    TB.PartyCount = function() return 1 end
    assert(F.IgnoreTarget(false) == true, "ignore remove should send")
    assert(sentWhispers[#sentWhispers].msg == ".tb ignore party Tester remove " .. WOLF,
        "ignore remove should name the bound party and the guid")
    assert(#sentWhispers == sentBefore + 2, "ignore should send exactly two lines")
    TB.PartyCount = function() return 0 end
    UnitGUID = function() return nil end
    assert(F.IgnoreTarget(true) == false, "ignore with no target should fail")
    assert(lastStatusKind == "warn", "ignore with no target should warn")
    UnitGUID = nil

    -- Ignore replies
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("ignore-begin #i1")
    TB.OnSystemMessage("ignore commander=Mcmd verb=add status=ok guid=" .. WOLF .. " name=Ashenvale%20Bear expires=1800 #i1")
    TB.OnSystemMessage("ignore-end count=1 records=1 verb=add target=party:Mtank commander=Mcmd ok=1 refused=0 #i1")
    assert(lastStatusKind == "ok" and string.find(lastStatus or "", "Ignore add accepted (1 ok)", 1, true),
        "ignore-end should set ok status: " .. tostring(lastStatus))
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("error code=duplicate cmd=ignore msg=the%20list%20already%20names%20that%20mob #i3")
    assert(lastStatusKind == "warn" and string.find(lastStatus or "", "duplicate", 1, true),
        "ignore error should set warn status")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "ignore-begin #i1") == true,
        "ignore-begin should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "ignore-end count=1 records=1 verb=add target=party:Mtank commander=Mcmd ok=1 refused=0 #i1") == true,
        "ignore-end should be hidden")
    assert(not chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "error code=duplicate cmd=ignore msg=the%20list%20already%20names%20that%20mob #i3"),
        "ignore error lines must stay visible in chat")

    -- Gear reply sequence (upgrades found)
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("gear-begin #g1")
    TB.OnSystemMessage("gear bot=Mtank slot=15 old=2504 new=15210 #g1")
    TB.OnSystemMessage("gear bot=Mpriest changed=0 #g1")
    TB.OnSystemMessage("gear-end count=2 records=2 target=party:Mtank bots=2 changed=1 #g1")
    assert(lastStatusKind == "ok" and string.find(lastStatus or "", "1 changed", 1, true),
        "gear-end with changed=1 should set ok status: " .. tostring(lastStatus))

    -- Gear reply sequence (nothing to equip)
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("gear-begin #g2")
    TB.OnSystemMessage("gear bot=Mpriest changed=0 #g2")
    TB.OnSystemMessage("gear-end count=1 records=1 target=Mpriest bots=1 changed=0 #g2")
    assert(lastStatusKind == "ok" and lastStatus == "Gear already up to date",
        "gear-end with changed=0 should say up to date")

    -- Gear refusal (in combat)
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("error code=in-combat cmd=gear msg=Mtank%20is%20in%20combat #g3")
    assert(lastStatusKind == "warn" and string.find(lastStatus or "", "in combat", 1, true),
        "gear error should set warn status with readable code: " .. tostring(lastStatus))

    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "gear-begin #g1") == true,
        "gear-begin should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "gear bot=Mtank slot=15 old=2504 new=15210 #g1") == true,
        "per-bot gear line should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "gear-end count=2 records=2 target=party:Mtank bots=2 changed=1 #g1") == true,
        "gear-end should be hidden")
    assert(not chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "error code=in-combat cmd=gear msg=Mtank%20is%20in%20combat #g3"),
        "gear error lines must stay visible in chat")

    -- Commander order reply (accepted rest)
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("cmd-begin #c1")
    TB.OnSystemMessage("cmd verb=rest status=accepted bots=2 result=party%202 #c1")
    TB.OnSystemMessage("cmd-end count=1 records=1 verb=rest lead=Mtank bots=2 #c1")
    assert(lastStatusKind == "ok" and string.find(lastStatus or "", "rest accepted (2 bot", 1, true),
        "cmd-end with accepted rest should set ok status: " .. tostring(lastStatus))

    -- Commander order refusal (not bound)
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("error code=not-bound cmd=cmd msg=you%20have%20no%20bound%20bots #c2")
    assert(lastStatusKind == "warn" and string.find(lastStatus or "", "not bound", 1, true),
        "cmd error should set warn status with readable code: " .. tostring(lastStatus))

    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "cmd-begin #c1") == true,
        "cmd-begin should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "cmd verb=rest status=accepted bots=2 result=party%202 #c1") == true,
        "cmd record should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "cmd-end count=1 records=1 verb=rest lead=Mtank bots=2 #c1") == true,
        "cmd-end should be hidden")
    assert(not chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "error code=not-bound cmd=cmd msg=you%20have%20no%20bound%20bots #c2"),
        "cmd error lines must stay visible in chat")

    -- Quest replies (accept ok, filtered refusal, status list)
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("quest-begin #q1")
    TB.OnSystemMessage("quest bot=Mtank verb=accept status=accepted #q1")
    TB.OnSystemMessage("quest-end count=1 records=1 bot=Mtank verb=accept #q1")
    assert(lastStatusKind == "ok" and string.find(lastStatus or "", "Quest accept complete", 1, true),
        "quest-end should set ok status: " .. tostring(lastStatus))
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("quest-begin #q2")
    TB.OnSystemMessage("quest bot=Mtank verb=accept id=123 status=refused code=filtered #q2")
    TB.OnSystemMessage("quest-end count=1 records=1 bot=Mtank verb=accept #q2")
    assert(lastStatusKind == "warn" and string.find(lastStatus or "", "filtered", 1, true),
        "filtered quest should set warn status: " .. tostring(lastStatus))
    lastStatus, lastStatusKind = nil, nil
    TB.OnSystemMessage("quest-begin #q3")
    TB.OnSystemMessage("quest bot=Mtank id=1 title=First%20Quest status=incomplete objectives=1%2F5 #q3")
    TB.OnSystemMessage("quest bot=Mtank id=2 title=Second%20Quest status=complete objectives=5%2F5 #q3")
    TB.OnSystemMessage("quest-end count=2 records=2 bot=Mtank verb=status quests=2 #q3")
    assert(lastStatusKind == "ok" and lastStatus == "Quest log (2 quest(s))",
        "quest status should summarize the log: " .. tostring(lastStatus))
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "quest-begin #q1") == true,
        "quest-begin should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "quest bot=Mtank verb=accept status=accepted #q1") == true,
        "quest record should be hidden")
    assert(chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "quest-end count=1 records=1 bot=Mtank verb=accept #q1") == true,
        "quest-end should be hidden")
    assert(not chatFilters.CHAT_MSG_SYSTEM(nil, "CHAT_MSG_SYSTEM", "error code=bad-id cmd=quest msg=invalid%20quest%20id #q4"),
        "quest error lines must stay visible in chat")

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
    UnitGUID = origUnitGUID

    print("PASS: Forever bridge checks")
end
