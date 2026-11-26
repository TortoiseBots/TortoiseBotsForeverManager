-- TortoiseBotsManager/BotPositions.lua
-- The Positions tab for issue #15: place the commander's bots in a shape,
-- remember a rally point and call them back to it.
--
-- The module already speaks these words at the pinned dev revision
-- (forever/docs/PLACE-RALLY-NOTES.md and TB-COMMANDS.md section 20).  A normal
-- player reaches them through party/raid chat or a whisper to one of its own
-- bots; `.tb cmd` is the GM form, so it is never sent from here.  The `.bot`
-- form does not exist for these verbs.
--
-- Every click sends one exact line (shown in the tab's feedback line):
--   place <shape> <tight|normal|wide> <here|target|cursor> <who>
--   place follow
--   rally here
--   fallback
--   resume
-- The replies are ordinary system chat lines ("cmd ...", "cmd-end ..." or
-- "error ..."), so the tab reads them instead of inventing an optimistic
-- result.  A cursor placement waits for the player's own minimap ping (30 s);
-- an add-on cannot send CMSG_MINIMAP_PING for the player, so the tab says so.

local TB = TortoiseBots
local C = TB.C or {}
local COL = C.COLOR or {}

local SHAPES = { "close", "circle", "arc", "spread", "line", "column", "spear", "arrow" }
local GAPS = { "tight", "normal", "wide" }
local WHO = { "all", "selected", "tanks", "healers", "melee", "ranged", "dps", "target" }
local VERBS = { place = true, rally = true, fallback = true, resume = true }

local SHAPE_LABEL = {
    close = "Close block", circle = "Circle", arc = "Half ring",
    spread = "Spread grid", line = "Line", column = "Column",
    spear = "Spear (wedge)", arrow = "Arrow (V)",
}
local GAP_LABEL = { tight = "Tight (2.5 yd)", normal = "Normal (4 yd)", wide = "Wide (8 yd)" }
local WHO_LABEL = {
    all = "All bots", tanks = "Tanks", healers = "Healers", melee = "Melee",
    ranged = "Ranged", dps = "DPS",
}
local WHO_TIP = {
    "All bots, the bots checked in the Roster tab (Selected), a role,",
    "or the one bot you have targeted. The existing place grammar takes all of them.",
}

local function color(name) return COL[name] or { 1, 1, 1 } end
local function now() return (GetTime and GetTime()) or 0 end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

local function cycleValue(list, value, dir)
    local index = 1
    for i, v in ipairs(list) do if v == value then index = i break end end
    index = index + (dir or 1)
    if index < 1 then index = #list end
    if index > #list then index = 1 end
    return list[index]
end

-- ── saved choices ────────────────────────────────────────────────────────────
-- Kept beside the add-on's other UI preferences.  Invalid stored words fall
-- back to the module's defaults instead of being sent to the server.
function TB.GetPositionsSettings()
    local db = TortoiseBotsDB or {}
    local prefs = type(db.positions) == "table" and db.positions or {}
    local shape = contains(SHAPES, prefs.shape) and prefs.shape or "circle"
    local gap = contains(GAPS, prefs.gap) and prefs.gap or "normal"
    local who = contains(WHO, prefs.who) and prefs.who or "all"
    return shape, gap, who
end

function TB.SetPositionsSetting(key, value)
    local db = TortoiseBotsDB or {}
    if type(db.positions) ~= "table" then db.positions = {} end
    if key == "shape" and contains(SHAPES, value) then db.positions.shape = value
    elseif key == "gap" and contains(GAPS, value) then db.positions.gap = value
    elseif key == "who" and contains(WHO, value) then db.positions.who = value
    else return false end
    return true
end

local function cycleSetting(key, dir)
    local shape, gap, who = TB.GetPositionsSettings()
    local list = key == "shape" and SHAPES or key == "gap" and GAPS or WHO
    local current = key == "shape" and shape or key == "gap" and gap or who
    TB.SetPositionsSetting(key, cycleValue(list, current, dir))
    if TB.RefreshPositionsTab then TB.RefreshPositionsTab() end
end

local function selectedNames()
    return TB.GetSelectedRosterNames and TB.GetSelectedRosterNames() or {}
end

local function whoWord()
    local _, _, who = TB.GetPositionsSettings()
    if who == "selected" then
        local names = selectedNames()
        if #names == 0 then return nil, "Select bots in the Roster tab first (or pick All bots)." end
        return table.concat(names, " ")
    end
    if who ~= "target" then return who end
    local bot = TB.GetTargetBot and TB.GetTargetBot() or nil
    if not bot then return nil, "Target one of your bots first (or pick All bots)." end
    return bot
end

local function whoLabel()
    local _, _, who = TB.GetPositionsSettings()
    if who == "selected" then
        local count = #selectedNames()
        return count > 0 and ("Selected (" .. count .. ")") or "Selected (none)"
    end
    if who ~= "target" then return WHO_LABEL[who] or who end
    local bot = TB.GetTargetBot and TB.GetTargetBot() or nil
    return bot and ("Target: " .. bot) or "Target (no bot)"
end

-- ── exact command lines ──────────────────────────────────────────────────────
-- Grammar: `.tb cmd place <shape> [gap] [anchor] [face] [who...]`; the chat
-- form is the same words.  The who word is last because every earlier word is
-- an option of the shape.
function TB.BuildPlaceCommand(shape, gap, anchor, who)
    shape, gap, anchor, who = shape or "circle", gap or "normal", anchor or "here", who or "all"
    if not contains(SHAPES, shape) then return nil end
    if not contains(GAPS, gap) then return nil end
    if anchor ~= "here" and anchor ~= "target" and anchor ~= "cursor" then return nil end
    if who == "" or who == nil then who = "all" end
    return "place " .. shape .. " " .. gap .. " " .. anchor .. " " .. who
end

function TB.BuildRallyCommand() return "rally here" end
function TB.BuildFallbackCommand() return "fallback" end
function TB.BuildResumeCommand() return "resume" end
function TB.BuildPlaceFollowCommand() return "place follow" end

-- ── transport ───────────────────────────────────────────────────────────────
-- A normal player's chat is the only ingress for these verbs.  The 1.60
-- client refuses add-on SendChatMessage in combat (the same restriction the
-- add-on's .bot transport already handles), so say the exact line and let the
-- player send it there; never queue it as if it had gone out.
local function chatBlocked()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat and UnitAffectingCombat("player") then return true end
    return false
end

local function channel()
    if TB.RaidCount and TB.RaidCount() > 0 then return "RAID" end
    if TB.PartyCount and TB.PartyCount() > 0 then return "PARTY" end
    return nil
end

local function sendChat(cmd)
    if chatBlocked() then
        if TB.SetStatus then TB.SetStatus("In combat: type this in party chat: " .. cmd, "warn") end
        return false, "in combat"
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return false, "no chat API" end
    local chat = channel()
    local ok
    if chat then
        ok = pcall(send, cmd, chat, nil, nil)
    else
        -- A targeted own bot accepts the same whisper form even when the
        -- player is not in its group; otherwise there is no channel at all.
        local target = TB.GetTargetBot and TB.GetTargetBot() or nil
        if not target then
            if TB.SetStatus then TB.SetStatus("Join your bots in a party first.", "warn") end
            return false, "not grouped"
        end
        ok = pcall(send, cmd, "WHISPER", nil, target)
    end
    if not ok then return false, "send failed" end
    return true
end

-- Reply state for the command the tab just sent.  Only the position verbs are
-- accepted, so other `.tb cmd` traffic cannot overwrite this tab.
local reply

local function fieldDecoder(value)
    if not value then return "" end
    return (string.gsub(value, "%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function fields(line)
    local out = {}
    for key, value in string.gmatch(line or "", "(%S+)=(%S+)") do
        out[key] = fieldDecoder(value)
    end
    return out
end

local function shortMessage(text, cap)
    text = text or ""
    cap = cap or 90
    if string.len(text) <= cap then return text end
    return string.sub(text, 1, cap - 3) .. "..."
end

local feedback

local function setFeedback(text, kind)
    feedback = { text = text, kind = kind }
    if TB.RefreshPositionsTab then TB.RefreshPositionsTab() end
end

function TB.GetPositionFeedback()
    return feedback
end

local function refusalText()
    local out = {}
    for _, row in ipairs(reply and reply.refused or {}) do
        local code = row.code and row.code ~= "" and (" (" .. row.code .. ")") or ""
        local msg = row.msg and row.msg ~= "" and (": " .. shortMessage(row.msg, 60)) or ""
        table.insert(out, "|cffff5050" .. (row.bot or "bot") .. " refused" .. code .. msg .. "|r")
    end
    return table.concat(out, "\n")
end

local function replyText()
    local text
    local head = reply and reply.head
    if reply and reply.error then
        text = "|cffff5050Refused:|r " .. (reply.error.code and reply.error.code ~= "" and reply.error.code or "error")
        if reply.error.msg and reply.error.msg ~= "" then text = text .. " - " .. shortMessage(reply.error.msg, 100) end
    elseif head then
        local verb = head.verb or (reply and reply.verb) or "place"
        if verb == "place" then
            if head.status == "waiting" then
                text = "|cffffb040At cursor:|r click the minimap where the bots should stand within 30 s."
            elseif head.follow == "yes" then
                text = "|cff40ff40Released " .. tostring(head.bots or "?") .. " bot(s).|r"
            elseif head.status == "accepted" then
                text = "|cff40ff40Placed " .. tostring(head.bots or "?") .. " bot(s).|r "
                    .. (head.shape or "?") .. " / " .. (head.gap or "?") .. " / " .. (head.anchor or "?")
            else
                text = "|cffffb040Place:|r " .. tostring(head.status or "waiting")
            end
        elseif verb == "rally" then
            if head.set == "yes" or head.status == "accepted" then
                text = "|cff40ff40Rally point set.|r"
                if head.pos then text = text .. " " .. head.pos end
            elseif head.cleared == "yes" then
                text = "|cff40ff40Rally point cleared.|r"
            else
                text = "|cffffb040Rally:|r " .. tostring(head.status or "shown")
            end
        elseif verb == "fallback" then
            text = "|cff40ff40Falling back:|r " .. tostring(head.bots or "?") .. " bot(s) from "
                .. tostring(head.from or "?")
        elseif verb == "resume" then
            text = "|cff40ff40Resume sent.|r"
        else
            text = "|cffffb040" .. verb .. ": " .. tostring(head.status or "sent") .. "|r"
        end
    elseif feedback then
        text = feedback.text
    else
        text = "Pick a shape and a gap, then place the bots."
    end

    local refused = refusalText()
    if refused ~= "" and not (not head and feedback) then text = text .. "\n" .. refused end
    if reply and reply.ended then
        local endFields = reply.endFields or {}
        if endFields.placed and endFields.refused then
            text = text .. "\n" .. "Placed " .. endFields.placed .. ", refused " .. endFields.refused .. "."
        elseif endFields.released then
            text = text .. "\n" .. "Released " .. endFields.released .. " bot(s)."
        end
    end
    local kind
    if reply and (reply.error or #(reply.refused or {}) > 0) then
        kind = "err"
    elseif reply and reply.head and reply.head.status == "waiting" then
        kind = "pending"
    elseif reply and (reply.head or reply.ended) then
        kind = "ok"
    elseif feedback then
        kind = feedback.kind
    else
        kind = "ok"
    end
    return text, kind
end

-- The system-chat reply lines.  Returns true when the line belongs to this
-- tab's open position command so Comms.lua can stop looking at it.
function TB.ParsePositionMessage(msg)
    if not reply or not reply.open then return false end
    -- A cursor placement answers twice: the waiting reply, then the real one
    -- when the player's minimap ping arrives. Keep the second window open for
    -- the server's own 30 s wait.
    local maxAge = reply.cursorPending and 35 or 20
    if now() - (reply.at or 0) > maxAge then
        reply = nil
        return false
    end
    if string.find(msg or "", "^cmd%-begin") then
        local afterCursor = reply.cursorPending
        if afterCursor then
            -- The second reply to the same cursor request: start its head
            -- afresh, but keep reading until its own cmd-end.
            reply.cursorPending = false
            reply.head = nil
            reply.rows = {}
            reply.refused = {}
            reply.endFields = nil
            reply.ended = false
            reply.error = nil
        end
        reply.started = true
        setFeedback(afterCursor and "Ping received. Placing..." or "Sent. Waiting for the bots...", "pending")
        return true
    end
    if string.find(msg or "", "^cmd%-end") then
        reply.ended = true
        reply.awaiting = false
        reply.endFields = fields(msg)
        if reply.head and reply.head.status == "waiting" then
            reply.cursorPending = true
            reply.at = now()
        else
            reply.open = false
        end
        local text, kind = replyText()
        setFeedback(text, kind)
        return true
    end
    if string.find(msg or "", "^error%s+code=") and string.find(msg or "", "cmd=cmd") then
        reply.error = fields(msg)
        reply.open = false
        reply.awaiting = false
        local text, kind = replyText()
        setFeedback(text, kind)
        return true
    end
    if string.find(msg or "", "^cmd%s") or msg == "cmd" then
        local row = fields(msg)
        local verb = row.verb
        if not verb or not VERBS[verb] then return false end
        reply.verb = verb
        if row.status == "refused" or row.status == "queued" and row.code and row.code ~= "" then
            table.insert(reply.refused, row)
        elseif row.bot then
            table.insert(reply.rows, row)
        else
            reply.head = row
        end
        reply.awaiting = false
        local text, kind = replyText()
        setFeedback(text, kind)
        return true
    end
    return false
end

function TB.SendPositionCommand(cmd)
    cmd = TB.Trim(cmd or "")
    if cmd == "" then return false end
    local ok, why = sendChat(cmd)
    if not ok then
        local text = "|cffffb040Not sent:|r " .. (why or "chat unavailable")
        if why == "in combat" then
            text = text .. "\nType this in party chat: |cffffff00" .. cmd .. "|r"
        elseif why == "not grouped" then
            text = text .. "\nJoin your bots in a party or raid, or target one of your bots."
        end
        reply = nil
        setFeedback(text, "err")
        return false
    end
    reply = { at = now(), open = true, awaiting = true, rows = {}, refused = {} }
    if TB.SetStatus then TB.SetStatus("Position command sent.", "pending") end
    setFeedback("|cffb8b8b8Sent:|r " .. cmd .. "\nWaiting for the bots...", "pending")
    return true
end

function TB.SendPlaceCommand(anchor)
    local shape, gap = TB.GetPositionsSettings()
    local who, whoErr = whoWord()
    if not who then
        reply = nil
        setFeedback("|cffff5050Place:|r " .. (whoErr or "pick who moves."), "err")
        return false
    end
    local cmd = TB.BuildPlaceCommand(shape, gap, anchor, who)
    if not cmd then
        reply = nil
        setFeedback("|cffff5050Place:|r invalid shape, gap or anchor.", "err")
        return false
    end
    return TB.SendPositionCommand(cmd)
end

-- ── UI ──────────────────────────────────────────────────────────────────────
local tab

local function setTooltip(widget, title, lines)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        for _, line in ipairs(lines or {}) do
            GameTooltip:AddLine(line, 0.9, 0.9, 0.9, 1)
        end
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
end

local function smallButton(parent, label, width, x, y, tipTitle, tip, onClick)
    local button = TB.StyleButton(CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"))
    button:SetWidth(width); button:SetHeight(20)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    if tip then setTooltip(button, tipTitle, tip) end
    return button
end

local function valueLabel(parent, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("CENTER")
    TB.SetTextColor(fs, color("text"))
    return fs
end


function TB.RefreshPositionsTab()
    if not tab then return end
    local shape, gap = TB.GetPositionsSettings()
    tab.shapeValue:SetText(SHAPE_LABEL[shape] or shape)
    tab.gapValue:SetText(GAP_LABEL[gap] or gap)
    tab.whoValue:SetText(whoLabel())
    if tab.targetBtn then
        if UnitExists and UnitExists("target") then tab.targetBtn:Enable() else tab.targetBtn:Disable() end
    end
    local text, kind = replyText()
    tab.feedback:SetText(text)
    TB.SetTextColor(tab.feedback, color(kind == "err" and "red" or kind == "ok" and "green" or "muted"))
end

function TB.CreatePositionsTab(parent)
    tab = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    local tw = (C.PANEL_W or 500) - (C.PAD or 10) * 2
    tab:SetWidth(tw); tab:SetHeight(325)

    if TB.UI and TB.UI.CreateHeading then
        TB.UI.CreateHeading(tab, "Positions", "Shape the group, then hold the spot")
    end

    local shapeTitle = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shapeTitle:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -30)
    shapeTitle:SetText("SHAPE")
    TB.SetTextColor(shapeTitle, color("title"))
    tab.shapeValue = valueLabel(tab, 50, -48, 130)
    smallButton(tab, "<", 20, 6, -46, "Shape", { "Click to cycle the shapes the module supports.",
        "Close, circle, arc, spread, line, column, spear, arrow." }, function() cycleSetting("shape", -1) end)
    smallButton(tab, ">", 20, 184, -46, "Shape", { "Click to cycle the shapes the module supports." }, function() cycleSetting("shape", 1) end)

    local gapTitle = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gapTitle:SetPoint("TOPLEFT", tab, "TOPLEFT", 216, -30)
    gapTitle:SetText("GAP")
    TB.SetTextColor(gapTitle, color("title"))
    tab.gapValue = valueLabel(tab, 256, -48, 100)
    smallButton(tab, "<", 20, 216, -46, "Gap", { "Tight 2.5 yd, normal 4 yd, wide 8 yd." }, function() cycleSetting("gap", -1) end)
    smallButton(tab, ">", 20, 356, -46, "Gap", { "Tight 2.5 yd, normal 4 yd, wide 8 yd." }, function() cycleSetting("gap", 1) end)

    local whoTitle = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    whoTitle:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -66)
    whoTitle:SetText("WHO")
    TB.SetTextColor(whoTitle, color("title"))
    tab.whoValue = valueLabel(tab, 46, -84, 300)
    smallButton(tab, "<", 20, 6, -82, "Who", WHO_TIP, function() cycleSetting("who", -1) end)
    smallButton(tab, ">", 20, 356, -82, "Who", WHO_TIP, function() cycleSetting("who", 1) end)

    local placeTitle = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    placeTitle:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -102)
    placeTitle:SetText("PLACE AT")
    TB.SetTextColor(placeTitle, color("title"))

    smallButton(tab, "Here", 74, 6, -118, "Here",
        { "The shape forms along your facing, its nearest slot 2 yd from you.",
          "Sends: place <shape> <gap> here <who>" },
        function() TB.SendPlaceCommand("here") end)
    local target = smallButton(tab, "Target", 74, 86, -118, "Target",
        { "The shape forms around your creature target, never inside it.",
          "Sends: place <shape> <gap> target <who>" },
        function() TB.SendPlaceCommand("target") end)
    tab.targetBtn = target
    local cursor = smallButton(tab, "At cursor", 92, 166, -118, "At cursor",
        { "Sends the cursor anchor, which waits up to 30 s for your minimap ping.",
          "Then click the minimap where the bots should stand.",
          "The add-on cannot send the ping for you." },
        function()
            local ok = TB.SendPlaceCommand("cursor")
            if ok then
                setFeedback("|cffffb040At cursor:|r click the minimap where the bots should stand within 30 s.\n"
                    .. "The add-on cannot send the ping for you.", "pending")
            end
        end)
    setTooltip(cursor)

    tab.cursorHint = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.cursorHint:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -144)
    tab.cursorHint:SetWidth(tw - 12)
    tab.cursorHint:SetJustifyH("LEFT")
    tab.cursorHint:SetText("At cursor: press it, then click the minimap where the bots should stand within 30 s.")
    TB.SetTextColor(tab.cursorHint, color("faint"))

    local rallyTitle = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rallyTitle:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -174)
    rallyTitle:SetText("RALLY & RELEASE")
    TB.SetTextColor(rallyTitle, color("title"))

    smallButton(tab, "Rally here", 86, 6, -190, "Rally here",
        { "Remember where you stand as the fall-back point.",
          "Sends: rally here" },
        function() TB.SendPositionCommand(TB.BuildRallyCommand()) end)
    smallButton(tab, "Fall back", 80, 98, -190, "Fall back",
        { "Every bot drops its target and forms up at the rally point",
          "(or where you stand when no rally point is remembered).",
          "Sends: fallback" },
        function() TB.SendPositionCommand(TB.BuildFallbackCommand()) end)
    smallButton(tab, "Resume", 66, 184, -190, "Resume",
        { "Ends a fall back and puts the bots back on follow.",
          "Sends: resume" },
        function() TB.SendPositionCommand(TB.BuildResumeCommand()) end)
    smallButton(tab, "Follow (release)", 124, 256, -190, "Follow (release)",
        { "Releases every placement hold: the bots follow again.",
          "Sends: place follow" },
        function() TB.SendPositionCommand(TB.BuildPlaceFollowCommand()) end)

    tab.feedback = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tab.feedback:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, -222)
    tab.feedback:SetWidth(tw - 12)
    tab.feedback:SetJustifyH("LEFT")
    tab.feedback:SetHeight(86)
    TB.SetTextColor(tab.feedback, color("muted"))

    tab:RegisterEvent("PLAYER_TARGET_CHANGED")
    if TB.RegisterGroupEvents then
        TB.RegisterGroupEvents(tab)
    else
        pcall(tab.RegisterEvent, tab, "PARTY_MEMBERS_CHANGED")
        pcall(tab.RegisterEvent, tab, "RAID_ROSTER_UPDATE")
    end
    tab:SetScript("OnEvent", function()
        if TB.RefreshPositionsTab then TB.RefreshPositionsTab() end
    end)

    TB.RefreshPositionsTab()
    tab:Hide()
    return tab
end
