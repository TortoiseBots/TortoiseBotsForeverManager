-- tests/positions_tests.lua
-- The Positions tab sends only the module's existing chat grammar and reads
-- the cmd/error system lines back. These checks cover the command builders,
-- the reply parser and the combat rule; the real module is not needed.

return function()
    local TB = TortoiseBots
    local previous = TortoiseBotsDB.positions

    -- Builders: only words the module's parser accepts.
    assert(TB.BuildPlaceCommand("circle", "normal", "here", "all")
        == "place circle normal here all", "a full place line is built in grammar order")
    assert(TB.BuildPlaceCommand("arrow", "wide", "target", "healers")
        == "place arrow wide target healers", "target and a role build")
    assert(TB.BuildPlaceCommand("line", "tight", "cursor", "Mage")
        == "place line tight cursor Mage", "a bot name builds as the who word")
    assert(TB.BuildPlaceCommand("line", "tight", "cursor", "Alpha Gamma")
        == "place line tight cursor Alpha Gamma", "several selected names build as the who list")
    assert(TB.BuildPlaceCommand("bogus", "normal", "here", "all") == nil, "an unknown shape is refused")
    assert(TB.BuildPlaceCommand("circle", "5", "here", "all") == nil,
        "a bare numeric gap is not one of the tab's three choices")
    assert(TB.BuildRallyCommand() == "rally here", "rally here is the exact chat word")
    assert(TB.BuildFallbackCommand() == "fallback", "fallback is the exact chat word")
    assert(TB.BuildResumeCommand() == "resume", "resume is the exact chat word")
    assert(TB.BuildPlaceFollowCommand() == "place follow", "follow releases the placement")

    -- Saved choices: valid values survive, stale ones fall back.
    TortoiseBotsDB.positions = { shape = "arc", gap = "wide", who = "tanks" }
    local shape, gap, who = TB.GetPositionsSettings()
    assert(shape == "arc" and gap == "wide" and who == "tanks", "the saved choices are read back")
    TB.SetPositionsSetting("shape", "not-a-shape")
    assert(select(1, TB.GetPositionsSettings()) == "arc", "an invalid stored shape is ignored")
    TB.SetPositionsSetting("gap", "tight")
    assert(select(2, TB.GetPositionsSettings()) == "tight", "a valid gap is stored")

    -- A sent command reaches chat unchanged; then its replies fill the tab.
    local sent = {}
    local oldSend, oldCombat, oldPartyCount = SendChatMessage, InCombatLockdown, GetNumPartyMembers
    SendChatMessage = function(message, chat) table.insert(sent, { message = message, chat = chat }) end
    InCombatLockdown = function() return false end
    GetNumPartyMembers = function() return 1 end

    assert(TB.SendPositionCommand("place circle normal here all") == true, "the command is sent out of combat")
    assert(sent[#sent].message == "place circle normal here all", "chat receives the exact command")
    assert(sent[#sent].chat == "PARTY", "the chat form goes to the group channel")
    TB.OnSystemMessage("cmd-begin")
    TB.OnSystemMessage("cmd verb=place status=accepted bots=2 shape=circle gap=normal anchor=here")
    TB.OnSystemMessage("cmd bot=Mage verb=place role=ranged slot=1 pos=-14.50,-48.10,-21.85")
    TB.OnSystemMessage("cmd bot=Mpriest verb=place role=healer slot=2 status=refused code=liquid msg=the%20slot%20is%20in%20water")
    TB.OnSystemMessage("cmd-end count=4 records=4 verb=place lead=Mtank bots=2 placed=1 refused=1")
    local feedback = TB.GetPositionFeedback()
    assert(feedback and string.find(feedback.text, "Placed 2 bot", 1, true), "the accepted head is shown")
    assert(string.find(feedback.text, "Mpriest refused (liquid)", 1, true), "the refused row names the bot and code")
    assert(string.find(feedback.text, "Placed 1, refused 1", 1, true), "the cmd-end counts are shown")

    -- Selected means the Roster tab's checked bots, expanded to names here.
    local oldSelected = TB.GetSelectedRosterNames
    TB.GetSelectedRosterNames = function() return { "Alpha", "Gamma" } end
    TB.SetPositionsSetting("shape", "circle")
    TB.SetPositionsSetting("gap", "normal")
    TB.SetPositionsSetting("who", "selected")
    assert(TB.SendPlaceCommand("here") == true, "the selected who option is sent")
    assert(sent[#sent].message == "place circle normal here Alpha Gamma",
        "selected bots become the grammar's who list")
    TB.GetSelectedRosterNames = oldSelected
    TB.SetPositionsSetting("who", "all")

    -- A command-level error decodes the URL-encoded message.
    assert(TB.SendPositionCommand("rally here") == true, "the next command replaces the old reply state")
    TB.OnSystemMessage("error code=not-bound cmd=cmd msg=you%20have%20no%20bound%20bots")
    feedback = TB.GetPositionFeedback()
    assert(string.find(feedback.text, "not-bound", 1, true)
        and string.find(feedback.text, "you have no bound bots", 1, true),
        "the command error and its decoded message are shown")

    -- A cursor placement answers twice: waiting, then the placement on the ping.
    assert(TB.SendPositionCommand("place circle normal cursor all") == true, "the cursor command is sent")
    TB.OnSystemMessage("cmd-begin")
    TB.OnSystemMessage("cmd verb=place status=waiting anchor=cursor shape=circle gap=normal wait=30")
    TB.OnSystemMessage("cmd-end count=1 records=1 verb=place pending=yes")
    feedback = TB.GetPositionFeedback()
    assert(string.find(feedback.text, "click the minimap", 1, true), "the waiting cursor reply asks for the ping")
    TB.OnSystemMessage("cmd-begin")
    TB.OnSystemMessage("cmd verb=place status=accepted bots=2 shape=circle gap=normal anchor=cursor")
    TB.OnSystemMessage("cmd-end count=3 records=3 verb=place bots=2 placed=2 refused=0")
    feedback = TB.GetPositionFeedback()
    assert(string.find(feedback.text, "Placed 2 bot", 1, true), "the second cursor reply is not ignored")

    -- The client blocks add-on chat in combat; never fake a send.
    InCombatLockdown = function() return true end
    local count = #sent
    assert(TB.SendPositionCommand("fallback") == false, "a combat click is not sent")
    assert(#sent == count, "nothing reaches chat in combat")
    feedback = TB.GetPositionFeedback()
    assert(string.find(feedback.text, "Type this in party chat", 1, true)
        and string.find(feedback.text, "fallback", 1, true),
        "the combat path shows the exact line to type")

    InCombatLockdown = oldCombat
    SendChatMessage = oldSend
    GetNumPartyMembers = oldPartyCount
    TortoiseBotsDB.positions = previous

    -- The tab exists and the saved active tab accepts its name.
    assert(TB.positionsFrame and TB.tabPositions, "the Positions tab is built")
    TB.ShowTab("positions")
    assert(TB.positionsFrame:IsVisible(), "ShowTab('positions') opens it")
    assert(TortoiseBotsDB.activeTab == "positions", "the active tab is remembered")
    TB.ShowTab("actions")
end
