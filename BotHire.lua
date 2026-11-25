-- TortoiseBotsForeverManager/BotHire.lua
-- Hire tab: hire a companion from anywhere, for servers that allow it.
--
-- Hiring is normally a <Mercenary Hire> recruiter inside an inn. The server
-- only allows the fast path `.bot hire` when AiPlayerbot.HireAnywhere is on,
-- and then advertises the `hire-anywhere` capability in TBM:CAPS. No
-- capability means no tab at all (not a grey tab): the recruiter is the
-- normal way to hire.
--
-- Wire (the server's `.bot hire` grammar, tokens in any order):
--   hire <class> <race> <male|female> <spec|role> [t0..t7] [level=<1-60>]
-- Class, race, gender and spec are the recruiter's own choices:
--   * class: the faction's hireable classes;
--   * race: the faction's races that can be that class;
--   * spec: the recruiter menu's per-class build list, which also picks the
--     role (see runtime/HireSpecPolicy.h on the server);
--   * tier 0 is the levelled kit; tiers 1..7 are gear kits, unlocked per
--     character at level 60. The server refuses a locked tier with
--     `TBM:ACTION_ERR|hire|tier-locked|<highest available>`;
--   * level defaults to the player's own level and the server clamps it to
--     the hirer's level plus AiPlayerbot.HireMaxLevelAboveHirer.
-- Replies ride the generic action ACK/ERR (Comms.lua):
--   TBM:ACTION_ACK|hire|bot:<Name>|1|tier <n>, fee <copper> copper
--   TBM:ACTION_ERR|hire|<code>|<message>
-- The fee is only known after the server charges it; the tab shows what the
-- server reported. A hire is not a roster row (the server filters it).

local TB = TortoiseBots
local C = TB.C or {}
local COL = C.COLOR or {}

local function color(name) return COL[name] or { 1, 1, 1 } end
local function trim(text) return TB.Trim(text or "") end

local CAP = "hire-anywhere"

-- ── the recruiter's choices ─────────────────────────────────────────────────
-- Class ids are the core ids (SharedDefines.h); 6 (Death Knight) and 10
-- (custom) are not hireable.
local CLASS_ORDER = { 1, 2, 3, 4, 5, 7, 8, 9, 11 }
local CLASS_NAMES = {
    [1] = "Warrior", [2] = "Paladin", [3] = "Hunter", [4] = "Rogue", [5] = "Priest",
    [6] = "Death Knight", [7] = "Shaman", [8] = "Mage", [9] = "Warlock", [11] = "Druid",
}
local CLASS_WORDS = {
    [1] = "warrior", [2] = "paladin", [3] = "hunter", [4] = "rogue", [5] = "priest",
    [7] = "shaman", [8] = "mage", [9] = "warlock", [11] = "druid",
}

-- The classic race/class matrix, filtered again by the player's faction. A
-- server with extra races simply refuses the combination it does not have;
-- these are the choices the recruiter can offer on a stock ForeverCore.
local RACES = {
    { id = 1,  word = "human",    name = "Human",     faction = "Alliance",
      classes = { 1, 2, 3, 4, 5, 8, 9 } },
    { id = 2,  word = "orc",      name = "Orc",       faction = "Horde",
      classes = { 1, 3, 4, 5, 7, 9 } },
    { id = 3,  word = "dwarf",    name = "Dwarf",     faction = "Alliance",
      classes = { 1, 2, 3, 4, 5 } },
    { id = 4,  word = "nightelf", name = "Night Elf", faction = "Alliance",
      classes = { 1, 3, 4, 5, 11 } },
    { id = 5,  word = "undead",   name = "Undead",    faction = "Horde",
      classes = { 1, 3, 4, 5, 8, 9 } },
    { id = 6,  word = "tauren",   name = "Tauren",    faction = "Horde",
      classes = { 1, 3, 7, 11 } },
    { id = 7,  word = "gnome",    name = "Gnome",     faction = "Alliance",
      classes = { 1, 4, 5, 8, 9 } },
    { id = 8,  word = "troll",    name = "Troll",     faction = "Horde",
      classes = { 1, 3, 4, 5, 7, 8 } },
}

local RACE_BY_ID, RACE_BY_WORD, CLASS_BY_TOKEN = {}, {}, {}
for _, race in ipairs(RACES) do
    RACE_BY_ID[race.id] = race
    RACE_BY_WORD[race.word] = race
    local set = {}
    for _, id in ipairs(race.classes) do set[id] = true end
    race.classSet = set
end
for id, word in pairs(CLASS_WORDS) do CLASS_BY_TOKEN[word] = id end
for id, name in pairs(CLASS_NAMES) do CLASS_BY_TOKEN[string.lower(name)] = id end

-- The recruiter's spec rows (runtime/HireSpecPolicy.h), in menu order, with
-- the `.bot hire` words that select the same build. `minLevel` is the
-- shaman tank's Earthshaker Slam requirement (level 10).
local SPECS = {
    [1] = {
        { label = "Protection (Tank)", words = "protection" },
        { label = "Arms (DPS)", words = "arms" },
        { label = "Fury (DPS)", words = "fury" },
    },
    [2] = {
        { label = "Protection (Tank)", words = "protection" },
        { label = "Holy (Healer)", words = "holy" },
        { label = "Retribution (DPS)", words = "retribution" },
    },
    [3] = {
        { label = "Beast Mastery (DPS)", words = "beastmastery" },
        { label = "Marksmanship (DPS)", words = "marksmanship" },
        { label = "Survival (DPS)", words = "survival" },
    },
    [4] = {
        { label = "Assassination (DPS)", words = "assassination" },
        { label = "Combat (DPS)", words = "combat" },
        { label = "Subtlety (DPS)", words = "subtlety" },
    },
    [5] = {
        { label = "Holy (Healer)", words = "holy" },
        { label = "Discipline (Healer)", words = "discipline" },
        { label = "Shadow (DPS)", words = "shadow" },
    },
    [7] = {
        { label = "Restoration (Healer)", words = "restoration" },
        { label = "Elemental (DPS)", words = "elemental" },
        { label = "Enhancement (DPS)", words = "enhancement" },
        { label = "Enhancement (Tank) (experimental)", words = "enhancement tank", minLevel = 10 },
    },
    [8] = {
        { label = "Frost (DPS)", words = "frost" },
        { label = "Fire (DPS)", words = "fire" },
        { label = "Arcane (DPS)", words = "arcane" },
    },
    [9] = {
        { label = "Affliction (DPS)", words = "affliction" },
        { label = "Demonology (DPS)", words = "demonology" },
        { label = "Destruction (DPS)", words = "destruction" },
    },
    [11] = {
        { label = "Feral Bear (Tank)", words = "feral tank" },
        { label = "Restoration (Healer)", words = "restoration" },
        { label = "Balance (DPS)", words = "balance" },
        { label = "Feral Cat (DPS)", words = "feral dps" },
    },
}

-- HireTierName in runtime/HireTierRequestPolicy.h.
local TIERS = {
    { value = 0, name = "Standard" },
    { value = 1, name = "Pre-raid" },
    { value = 2, name = "Zul'Gurub" },
    { value = 3, name = "Molten Core" },
    { value = 4, name = "Blackwing Lair" },
    { value = 5, name = "Ahn'Qiraj" },
    { value = 6, name = "Naxxramas" },
    { value = 7, name = "Karazhan" },
}

local state = { classId = nil, raceId = nil, gender = 0, spec = 1, tier = 0, level = nil }
local frame
local lastFeeText

local function faction()
    if UnitFactionGroup then
        local value = UnitFactionGroup("player")
        if value and string.lower(value) == "horde" then return "Horde" end
    end
    return "Alliance"
end

local function playerLevel()
    local level = UnitLevel and UnitLevel("player") or 60
    level = tonumber(level) or 60
    if level < 1 then return 1 end
    if level > 60 then return 60 end
    return level
end

local function playerClassId()
    if not UnitClass then return nil end
    local _, token = UnitClass("player")
    local id = token and (CLASS_BY_TOKEN[string.lower(token)] or CLASS_BY_TOKEN[token])
    return id
end

local function playerRaceId()
    if not UnitRace then return nil end
    local _, token = UnitRace("player")
    if not token then return nil end
    local byToken = {
        HUMAN = 1, ORC = 2, DWARF = 3, NIGHTELF = 4, SCOURGE = 5, UNDEAD = 5,
        TAUREN = 6, GNOME = 7, TROLL = 8,
    }
    return byToken[string.upper(token)]
end

local function playerGender()
    if not UnitSex then return 0 end
    local sex = UnitSex("player")
    return sex == 3 and 1 or 0
end

function TB.HasHireCapability()
    return TB.HasServerCapability and TB.HasServerCapability(CAP) or false
end

-- ── selection helpers ───────────────────────────────────────────────────────
function TB.HireFaction()
    return faction()
end

function TB.HireClasses()
    local wanted = faction()
    local out = {}
    for _, classId in ipairs(CLASS_ORDER) do
        for _, race in ipairs(RACES) do
            if race.faction == wanted and race.classSet[classId] then
                table.insert(out, classId)
                break
            end
        end
    end
    return out
end

function TB.HireRaces(classId)
    classId = tonumber(classId) or (state.classId or playerClassId())
    local out = {}
    if not classId then return out end
    for _, race in ipairs(RACES) do
        if race.faction == faction() and race.classSet[classId] then
            table.insert(out, race)
        end
    end
    return out
end

function TB.HireSpecs(classId)
    classId = tonumber(classId) or state.classId
    local out = {}
    for _, spec in ipairs(SPECS[classId] or {}) do
        if not spec.minLevel or playerLevel() >= spec.minLevel then
            table.insert(out, spec)
        end
    end
    return out
end

-- Gear tiers matter only at level 60. The server has a `hire-tier` switch;
-- unknown (features not requested yet) counts as on, so the tab never hides
-- a choice the server would accept. The unlocked maximum is character state
-- the server never sends: the tab starts at Standard and the server refuses
-- a locked tier with its own message.
local function tiersUsable(level)
    level = level or state.level or playerLevel()
    if level ~= 60 then return false end
    local features = TB.GetServerFeatures and TB.GetServerFeatures() or {}
    for _, feature in ipairs(features) do
        if feature.key == "hire-tier" then return feature.value == "on" end
    end
    return true
end

function TB.HireTiers()
    local out = {}
    for _, tier in ipairs(TIERS) do
        if tier.value == 0 or tiersUsable() then
            table.insert(out, tier)
        end
    end
    return out
end

function TB.HireTierName(value)
    for _, tier in ipairs(TIERS) do
        if tier.value == value then return tier.name end
    end
    return "Standard"
end

local function clampLevel(value)
    value = math.floor(tonumber(value) or playerLevel())
    if value < 1 then return 1 end
    if value > 60 then return 60 end
    return value
end

local function firstClass()
    local own = playerClassId()
    for _, id in ipairs(TB.HireClasses()) do
        if id == own then return id end
    end
    return TB.HireClasses()[1] or 1
end

local function firstRace(classId)
    local own = playerRaceId()
    local races = TB.HireRaces(classId)
    for _, race in ipairs(races) do
        if race.id == own then return race.id end
    end
    return races[1] and races[1].id or 1
end

local function normalize()
    if not state.classId then
        state.classId = firstClass()
    end
    local classes = TB.HireClasses()
    local classOk = false
    for _, id in ipairs(classes) do
        if id == state.classId then classOk = true end
    end
    if not classOk then state.classId = firstClass() end

    local raceOk = false
    for _, race in ipairs(TB.HireRaces(state.classId)) do
        if race.id == state.raceId then raceOk = true end
    end
    if not raceOk then state.raceId = firstRace(state.classId) end

    if state.gender ~= 0 and state.gender ~= 1 then state.gender = 0 end
    local specs = TB.HireSpecs(state.classId)
    if not specs[state.spec] then state.spec = 1 end
    if not tiersUsable() then state.tier = 0 end
    local tierOk = false
    for _, tier in ipairs(TB.HireTiers()) do
        if tier.value == state.tier then tierOk = true end
    end
    if not tierOk then state.tier = 0 end
    if state.level ~= nil then state.level = clampLevel(state.level) end
    return state
end

function TB.GetHireChoice(kind)
    normalize()
    if kind == "class" then return state.classId end
    if kind == "race" then return state.raceId end
    if kind == "gender" then return state.gender end
    if kind == "spec" then return state.spec end
    if kind == "tier" then return state.tier end
    if kind == "level" then return state.level or playerLevel() end
    return nil
end

function TB.SetHireChoice(kind, value)
    kind = string.lower(trim(kind))
    if kind == "class" then
        local id = tonumber(value) or CLASS_BY_TOKEN[string.lower(trim(value))]
        if not id then return false end
        local ok = false
        for _, available in ipairs(TB.HireClasses()) do
            if available == id then ok = true end
        end
        if not ok then return false end
        state.classId = id
        state.spec = 1
        state.raceId = nil
    elseif kind == "race" then
        local race = tonumber(value) and RACE_BY_ID[tonumber(value)] or RACE_BY_WORD[string.lower(trim(value))]
        if not race then return false end
        local ok = false
        for _, available in ipairs(TB.HireRaces(state.classId)) do
            if available.id == race.id then ok = true end
        end
        if not ok then return false end
        state.raceId = race.id
    elseif kind == "gender" then
        local word = string.lower(trim(value))
        if word == "female" or value == 1 then
            state.gender = 1
        elseif word == "male" or value == 0 then
            state.gender = 0
        else
            return false
        end
    elseif kind == "spec" then
        local index = tonumber(value)
        if not index then return false end
        if not TB.HireSpecs(state.classId)[index] then return false end
        state.spec = index
    elseif kind == "tier" then
        local tier = tonumber(value)
        if not tier then return false end
        local ok = false
        for _, available in ipairs(TB.HireTiers()) do
            if available.value == tier then ok = true end
        end
        if not ok then return false end
        state.tier = tier
    elseif kind == "level" then
        local level = tonumber(value)
        if not level then return false end
        state.level = clampLevel(level)
    else
        return false
    end
    normalize()
    if TB.RefreshHireTab then TB.RefreshHireTab() end
    return true
end

-- The exact `.bot` payload (without the `.bot ` prefix).
function TB.GetHireCommand()
    normalize()
    local classWord = CLASS_WORDS[state.classId]
    local race = RACE_BY_ID[state.raceId]
    local spec = TB.HireSpecs(state.classId)[state.spec]
    if not classWord or not race or not spec then return nil end
    local gender = state.gender == 1 and "female" or "male"
    local level = state.level or playerLevel()
    local tier = tiersUsable(level) and state.tier or 0
    return string.format("hire %s %s %s %s t%d level=%d",
        classWord, race.word, gender, spec.words, tier, level)
end

function TB.SendHire()
    if not TB.HasHireCapability() then return false end
    local cmd = TB.GetHireCommand()
    if not cmd then return false end
    lastFeeText = "Fee: quoted when the server hires."
    if frame and frame.feeText then frame.feeText:SetText(lastFeeText) end
    return TB.SendBotCommand(cmd)
end

-- The ACK detail is "tier <n>, fee <copper> copper"; a server that gives no
-- fee simply leaves the line as it was. ERR keeps the refusal in the status
-- line and says nothing was charged here.
function TB.OnHireReply(packet, ok)
    if not packet or packet.intent ~= "hire" then return false end
    if ok then
        local detail = packet.executor or ""
        local fee = tonumber(string.match(detail, "fee%s+(%d+)%s+copper"))
        local tier = tonumber(string.match(detail, "tier%s+(%d+)"))
        if fee then
            lastFeeText = "Fee paid: " .. (TB.FormatMoney and TB.FormatMoney(fee) or (fee .. "c"))
            if tier then lastFeeText = lastFeeText .. " (tier " .. tier .. ")" end
        else
            lastFeeText = "Hired; the server reported no fee."
        end
    else
        lastFeeText = "Fee: not charged."
    end
    if frame and frame.feeText then frame.feeText:SetText(lastFeeText) end
    return true
end

-- ── menus ───────────────────────────────────────────────────────────────────
-- Builders stay testable without the DropDownList frames, like the other
-- menu builders in the addon.
function TB.BuildHireMenu(kind, addButton)
    kind = string.lower(trim(kind))
    local count = 0
    local function add(info)
        count = count + 1
        addButton(info)
    end
    if kind == "class" then
        local current = TB.GetHireChoice("class")
        for _, id in ipairs(TB.HireClasses()) do
            local choice = id
            add({ text = CLASS_NAMES[id] or ("Class " .. id),
                checked = current == id and 1 or nil,
                func = function() TB.SetHireChoice("class", choice) end })
        end
    elseif kind == "race" then
        local current = TB.GetHireChoice("race")
        for _, race in ipairs(TB.HireRaces(TB.GetHireChoice("class"))) do
            local choice = race
            add({ text = race.name,
                checked = current == race.id and 1 or nil,
                func = function() TB.SetHireChoice("race", choice.id) end })
        end
    elseif kind == "gender" then
        local current = TB.GetHireChoice("gender")
        add({ text = "Male", checked = current == 0 and 1 or nil,
            func = function() TB.SetHireChoice("gender", 0) end })
        add({ text = "Female", checked = current == 1 and 1 or nil,
            func = function() TB.SetHireChoice("gender", 1) end })
    elseif kind == "spec" then
        local current = TB.GetHireChoice("spec")
        for index, spec in ipairs(TB.HireSpecs(TB.GetHireChoice("class"))) do
            local choice = index
            add({ text = spec.label,
                checked = current == index and 1 or nil,
                func = function() TB.SetHireChoice("spec", choice) end })
        end
    elseif kind == "tier" then
        local current = TB.GetHireChoice("tier")
        for _, tier in ipairs(TB.HireTiers()) do
            local choice = tier.value
            add({ text = tier.name,
                checked = current == tier.value and 1 or nil,
                func = function() TB.SetHireChoice("tier", choice) end })
        end
    else
        return 0
    end
    return count
end

local hireMenu
function TB.OpenHireMenu(kind)
    kind = string.lower(trim(kind))
    if not kind or kind == "" then return false end
    if not UIDropDownMenu_Initialize or not ToggleDropDownMenu then return false end
    if not hireMenu then
        hireMenu = CreateFrame("Frame", "TortoiseBotsManagerHireMenu", UIParent, "UIDropDownMenuTemplate")
    end
    UIDropDownMenu_Initialize(hireMenu, function()
        TB.BuildHireMenu(kind, UIDropDownMenu_AddButton)
    end, "MENU")
    ToggleDropDownMenu(1, nil, hireMenu, "cursor")
    return true
end

-- ── the tab ─────────────────────────────────────────────────────────────────
local function setTooltip(button, title, text)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(text, 0.9, 0.9, 0.9, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function fieldButton(card, kind, title, tip, width, x, y)
    local button = TB.UI.CreateButton(card, "", width, 26, {
        x = x, y = y,
        onClick = function() TB.OpenHireMenu(kind) end,
    })
    setTooltip(button, title, tip)
    return button
end

function TB.CreateHireTab(parent)
    local page = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    page:SetWidth(480)
    page:SetHeight(325)
    frame = page

    TB.UI.CreateHeading(page, "Hire a companion", "from anywhere on this server")

    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -20)
    hint:SetWidth(464)
    hint:SetJustifyH("LEFT")
    hint:SetText("Normally companions are hired at <Mercenary Hire> NPCs in inns; this server allows hiring anywhere.")
    TB.SetTextColor(hint, color("muted"))
    page.hint = hint

    local card = TB.UI.CreateCard(page, "COMPANION", 480, 124, { y = -40, line = true })

    page.classBtn = fieldButton(card, "class", "Class",
        "The companion's class. Only your faction's hireable classes are listed.", 150, 8, -26)
    page.raceBtn = fieldButton(card, "race", "Race",
        "Your faction's races that can be that class.", 150, 165, -26)
    page.genderBtn = fieldButton(card, "gender", "Gender",
        "The companion's gender.", 150, 322, -26)
    page.specBtn = fieldButton(card, "spec", "Spec",
        "The same premade builds the recruiter offers for this class; the build also sets the role.", 300, 8, -58)
    page.tierBtn = fieldButton(card, "tier", "Gear tier",
        "Standard is the levelled kit. Higher gear tiers need level 60 and the unlock on this character; the server refuses a locked tier.", 150, 322, -58)

    page.levelStep = TB.UI.CreateStepper(card, {
        point = "TOPLEFT", relTo = card, x = 8, y = -90, width = 112, labelWidth = 60,
        get = function() return state.level or playerLevel() end,
        set = function(value) TB.SetHireChoice("level", value) end,
        format = function(value) return "Level " .. value end,
        tip = "The companion's level. It starts at your own level; the server clamps it to your level plus its allowance.",
        tipTitle = "Level",
    })

    local fee = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fee:SetPoint("TOPLEFT", card, "TOPLEFT", 128, -96)
    fee:SetWidth(190)
    fee:SetJustifyH("LEFT")
    fee:SetText("Fee: quoted when the server hires.")
    TB.SetTextColor(fee, color("muted"))
    page.feeText = fee

    page.hireBtn = TB.UI.CreateButton(card, "Hire", 142, 26, {
        x = 330, y = -90,
        tip = "Hire this companion. The server charges its fee and answers in the status line.",
        tipTitle = "Hire",
        onClick = function() TB.SendHire() end,
    })

    local summary = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    summary:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -172)
    summary:SetWidth(464)
    summary:SetJustifyH("LEFT")
    TB.SetTextColor(summary, color("text"))
    page.summary = summary

    local note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -192)
    note:SetWidth(464)
    note:SetJustifyH("LEFT")
    note:SetText("The server picks the name and sets the fee; it refuses a locked tier, a full party or an empty purse in the status line.")
    TB.SetTextColor(note, color("faint"))
    page.note = note

    page:Hide()
    if TB.RefreshHireTab then TB.RefreshHireTab() end
    return page
end

function TB.RefreshHireTab()
    if not frame then return end
    normalize()
    local classId = state.classId
    local race = RACE_BY_ID[state.raceId]
    local spec = TB.HireSpecs(classId)[state.spec]
    local level = state.level or playerLevel()
    local tier = tiersUsable(level) and state.tier or 0

    frame.classBtn:SetText("Class: " .. (CLASS_NAMES[classId] or "?"))
    frame.raceBtn:SetText("Race: " .. (race and race.name or "?"))
    frame.genderBtn:SetText("Gender: " .. (state.gender == 1 and "Female" or "Male"))
    frame.specBtn:SetText("Spec: " .. (spec and spec.label or "?"))
    frame.tierBtn:SetText("Tier: " .. TB.HireTierName(tier))
    if frame.levelStep and frame.levelStep.repaint then frame.levelStep.repaint() end
    frame.summary:SetText(string.format("Will hire: level %d %s %s - %s - %s kit.",
        level, race and race.name or "?", CLASS_NAMES[classId] or "?",
        spec and spec.label or "?", TB.HireTierName(tier)))
    if lastFeeText then frame.feeText:SetText(lastFeeText) end
    -- The tab only exists while the server advertises hire-anywhere, and that
    -- capability comes from the same hire piece that registers the verb.
    if TB.HasHireCapability() then frame.hireBtn:Enable() else frame.hireBtn:Disable() end
end

function TB.NoteHireCaps()
    if TB.UpdateRaidTab then TB.UpdateRaidTab() end
    if TB.RefreshHireTab then TB.RefreshHireTab() end
    if TB.RefreshForeverGating then TB.RefreshForeverGating() end
end
