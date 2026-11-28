-- TortoiseBotsForeverManager/FakeServer.lua
-- Offline testing for the port (there is no TortoiseBots Forever server yet).
--
--   /tbfm trace      trace: print every addon message sent (>) and received (<)
--   /tbfm fake       toggle the fake server: commands are answered locally with
--                    the wire lines of a canned roster, guild bot, party bot,
--                    inventory, professions and orders, so every tab can be
--                    clicked without a server (nothing leaves the client)
--   /tbfm status     what is on now
--
-- Replies go through TB.OnAddonMessage (prefix TBM, channel PARTY), i.e. the
-- same parser the real server's replies use; the fake server only replaces the
-- transport.
TortoiseBots = TortoiseBots or {}
local TB = TortoiseBots
local C = TB.C or {}

TB.fake = TB.fake or { enabled = false }

local PREFIX = (C and C.ADDON_PREFIX) or "TBM"
local BOTS = { "Alpha", "Bravo" }
local GUIDS = { Alpha = "101", Bravo = "102" }
local CLASS_IDS = { Alpha = "1", Bravo = "5" }   -- warrior, priest
local FAKE_VERBS = "roster,list,alts,behavior,inv,inventory,item,trade,professions,service,totem,choice,blessing,order,lootlog,loot,action,add,remove,logout,invite,uninvite,summon,role,autogear,maintenance,command,run,strategy,formation,downtime,features,help,hire,armory"
local FAKE_CAPS = "order,order-steps,guild-order-steps,professions,blessing,blessing-player,choice,service,totem,behavior,inventory,loot-log,guild-bots,altsummary,run,hiring,hire-anywhere,armory"

local function emit(line)
    if TB.trace and TB.TracePrint then TB.TracePrint("< " .. line .. "   [fake]") end
    if TB.OnAddonMessage then
        TB.OnAddonMessage(PREFIX, line, "PARTY", "FakeServer")
    elseif TB.OnSystemMessage then
        TB.OnSystemMessage(line)
    end
end

-- Counted VERBS stream like the real server: BEGIN total, whole-token chunks
-- within one addon message each (255 bytes), END. Splits greedily, never
-- mid-token; an empty list still sends BEGIN|0, one empty line, END.
local function emitVerbsStream(csv)
    local tokens = {}
    for item in string.gmatch(csv or "", "[^,]+") do
        tokens[#tokens + 1] = item
    end
    emit("TBM:VERBS_BEGIN|" .. #tokens)
    local current = "TBM:VERBS|"
    for _, token in ipairs(tokens) do
        local sep = ","
        if current == "TBM:VERBS|" then sep = "" end
        if current ~= "TBM:VERBS|" and #current + #sep + #token > 255 then
            emit(current)
            current = "TBM:VERBS|"
            sep = ""
        end
        current = current .. sep .. token
    end
    emit(current)
    emit("TBM:VERBS_END")
end

local function sendChatLine(line)
    if TB.OnSystemMessage then TB.OnSystemMessage(line) end
end

local function rosterStream()
    emit("TBM:TRANSPORT|party")
    emit("TBM:PROTO|1|0")
    emit("TBM:VERSION|v2.4.1-forever")
    emitVerbsStream(FAKE_VERBS)
    emit("TBM:CAPS|" .. FAKE_CAPS)
    emit("TBM:ROSTER_BEGIN|" .. #BOTS)
    for _, name in ipairs(BOTS) do
        emit("TBM:ROSTER|" .. GUIDS[name] .. "|" .. name .. "|" .. CLASS_IDS[name]
            .. "|online|1|Elwynn Forest|-|" .. (name == "Alpha" and "Warrior" or "Priest"))
    end
    emit("TBM:ALTBOTS|")
    emit("TBM:ROSTER_END")
    emit("TBM:CLAIMED_BEGIN|1")
    emit("TBM:CLAIMED|201|Goldie|3|60|online|1|Ironforge|0|164:300|1|Hunter")
    emit("TBM:CLAIMED_END")
end

local function botStateStream(bot)
    emit("TBM:BOTSTATE_BEGIN|1")
    emit("TBM:BOTSTATE|" .. bot .. "|move=follow,loot=on,aoe=off,auto-cc=on,threat=on,mana=on,cooldowns=off,potion=on")
    emit("TBM:BOTSTATE_END")
end

local function inventoryStream(bot)
    emit("TBM:INV_BEGIN|" .. bot .. "|12345")
    emit("TBM:INV_EQ|0|12345|100|100")
    emit("TBM:INV_EQ|1|12346|80|100")
    emit("TBM:INV_ITEM|0|1|2589|4|0")
    emit("TBM:INV_ITEM|0|2|2592|2|0")
    emit("TBM:INV_END|" .. bot .. "|2|16")
end

local function professionsStream(bot)
    emit("TBM:PROF_BEGIN|" .. bot)
    emit("TBM:PROF|186|265|300")
    emit("TBM:RECIPE|186|2651|3860|1|25|50|100|ok")
    emit("TBM:PROF_END|" .. bot .. "|1|0")
end

-- Armory snapshot: a tank with missing enchants and one empty slot, and a
-- healer that is ready. Alpha's strip arrives in two parts, like the real
-- server splits one that would not fit a single 255-byte addon message.
local ARMORY_ROWS = {
    Alpha = {
        classId = 1, level = 60, role = "tank", spec = "Protection", ilvl = 65,
        melee = 8.0, ranged = 0.0, spell = 0.0, defense = 300, resists = "10+11+12+13+14",
        hitCap = 9.0, defCap = 440,
        stats = "ap=1200,crit=10.0,armor=6000,sta=500,sp=0,heal=0,scrit=0.0,mp5=0,int=40",
        parts = {
            "0:12345:0:1:3,1:12346:0:0:2,2:12347:0:1:3,3:0:0:0:0,4:0:0:2:0,5:12348:0:1:2,6:12349:0:0:2,7:12350:0:0:2,8:12351:0:1:2",
            "9:12352:0:1:2,10:12353:0:0:2,11:12354:0:0:2,12:0:0:2:0,13:0:0:2:0,14:12355:0:0:2,15:12356:0:0:2,16:0:0:0:0,17:12357:0:0:2",
        },
    },
    Bravo = {
        classId = 5, level = 60, role = "healer", spec = "Holy", ilvl = 70,
        melee = 0.0, ranged = 0.0, spell = 18.0, defense = 280, resists = "20+20+20+20+20",
        hitCap = 16.0, defCap = 0,
        stats = "ap=300,crit=5.0,armor=2000,sta=300,sp=200,heal=420,scrit=9.5,mp5=25,int=300",
        parts = { "0:12345:0:0:3,1:12346:0:0:2,15:12358:0:0:2,16:12359:0:0:2" },
    },
}

local function armoryStream(only)
    local names = {}
    for _, name in ipairs(BOTS) do
        if not only or only == name then names[#names + 1] = name end
    end
    emit("TBM:ARMORY_BEGIN|" .. #names)
    for _, name in ipairs(names) do
        local row = ARMORY_ROWS[name]
        local group = (name == BOTS[1]) and "1" or "0"
        emit("TBM:ARMORY|" .. name .. "|" .. row.classId .. "|" .. row.level .. "|1|" .. group
            .. "|" .. row.role .. "|" .. row.spec .. "|" .. row.ilvl
            .. "|" .. string.format("%.1f", row.melee) .. "|" .. string.format("%.1f", row.ranged)
            .. "|" .. string.format("%.1f", row.spell) .. "|" .. row.defense .. "|" .. row.resists
            .. "|" .. string.format("%.1f", row.hitCap) .. "|" .. row.defCap .. "|" .. row.stats)
    end
    for _, name in ipairs(names) do
        local parts = ARMORY_ROWS[name].parts
        for index, entries in ipairs(parts) do
            emit("TBM:ARMORY_EQ|" .. name .. "|" .. index .. "/" .. #parts .. "|" .. entries)
        end
    end
    emit("TBM:ARMORY_END|" .. #names)
end

local function orderStream()
    emit("TBM:ORDER_ACCESS|0|Member|1|0|1|0")
    emit("TBM:ORDER_BEGIN|1")
    emit("TBM:ORDER|Goldie|craft|2318|Light Leather|0|10|waiting|needitems|Elwynn Forest|easy|2|0|-|-|0|2319:4;2320:2|-")
    emit("TBM:ORDER_END")
end

-- One reply per command. Returns true when the fake server answered; it always
-- does, so nothing is sent to the (absent) server.
function TB.FakeServerSend(cmd)
    local verb, rest = string.match(cmd or "", "^(%S+)%s*(.*)$")
    verb = string.lower(verb or "")
    rest = rest or ""

    if verb == "help" then
        sendChatLine("Bot commands: fake server (offline)")
        return true
    end
    if verb == "roster" or verb == "list" then
        rosterStream()
        return true
    end
    if verb == "alts" then
        emit("TBM:ALTSUM|Beta|Beta: level 41 -> 44, +12g, 8 quests done, now in Stranglethorn Vale.")
        emit("TBM:ALTSUM_END|1")
        return true
    end
    if verb == "behavior" then
        local scope, arg = string.match(rest, "^(%S+)%s*(.*)$")
        if scope == "party" then
            local state = string.match(arg or "", "(%S+)%s*$") or "on"
            emit("TBM:ACTION_ACK|behavior|party|" .. #BOTS .. "|" .. (state ~= "" and state or "on"))
            return true
        end
        local bot = (scope and scope ~= "") and scope or BOTS[1]
        botStateStream(bot)
        emit("TBM:ACTION_ACK|behavior|bot:" .. bot .. "|1|-")
        return true
    end
    if verb == "inv" or verb == "inventory" then
        local bot = rest ~= "" and rest or BOTS[1]
        inventoryStream(bot)
        return true
    end
    if verb == "item" then
        local bot, op, a, b = string.match(rest, "^(%S+)%s+(%S+)%s*(%S*)%s*(%S*)")
        bot = (bot and bot ~= "") and bot or BOTS[1]
        op = string.lower(op or "equip")
        if op == "trade" then
            emit("TBM:ACTION_ACK|item trade|bot:" .. bot .. "|1|open")
        else
            emit("TBM:ACTION_ACK|item " .. op .. "|bot:" .. bot .. "|1|2589")
            inventoryStream(bot)
        end
        return true
    end
    if verb == "trade" then
        local bot = (string.match(rest, "^(%S+)") or BOTS[1])
        emit("TBM:ACTION_ACK|trade|bot:" .. bot .. "|1|open")
        return true
    end
    if verb == "professions" then
        local bot = rest ~= "" and rest or BOTS[1]
        professionsStream(bot)
        return true
    end
    if verb == "armory" then
        local bot = TB.NormalizeName(rest) or TB.NormalizeName(string.match(rest or "", "^(%S+)"))
        if bot and not ARMORY_ROWS[bot] then bot = nil end
        armoryStream(bot)
        return true
    end
    if verb == "service" then
        local bot = rest ~= "" and rest or BOTS[1]
        emit("TBM:SERVICE|" .. bot .. "|1|1|0|-")
        return true
    end
    if verb == "totem" then
        local bot = (string.match(rest, "^%S+") or BOTS[1])
        if string.find(rest, "status", 1, true) then
            emit("TBM:TOTEM|" .. bot .. "|earth=stoneskin totem,fire=searing totem,water=mana spring totem,"
                .. "air=windfury totem,mode=auto,known=stoneskin totem+searing totem")
            return true
        end
        emit("TBM:ACTION_ACK|totem set|party|1|-")
        return true
    end
    if verb == "choice" then
        local bot, kind = string.match(rest, "^(%S+)%s*(%S*)")
        emit("TBM:CHOICE|" .. (bot or BOTS[1]) .. "|" .. (kind ~= "" and kind or "aura")
            .. "=auto,known=none+auto")
        return true
    end
    if verb == "blessing" then
        local bot = (string.match(rest, "^(%S+)") or BOTS[1])
        if string.lower(bot) == "party" or string.lower(bot) == "raid" then bot = BOTS[1] end
        emit("TBM:BLESSING|" .. bot
            .. "|warrior=might,paladin=wisdom,hunter=might,rogue=might,priest=wisdom,"
            .. "shaman=wisdom,mage=wisdom,warlock=wisdom,druid=wisdom,known=might+wisdom+kings")
        return true
    end
    if verb == "order" then
        local sub = string.match(rest, "^(%S+)")
        sub = string.lower(sub or "")
        if sub == "list" or sub == "search" then
            orderStream()
            return true
        end
        local bot = string.match(rest, "^%S+%s+(%S+)")
        emit("TBM:ACTION_ACK|order|bot:" .. (bot or "Goldie") .. "|1|"
            .. (sub == "access" and "access" or sub == "rank" and "rank" or sub == "reassign" and "reassign" or "farm"))
        return true
    end
    if verb == "lootlog" or verb == "loot" then
        emit("TBM:LOOT_BEGIN|1|")
        emit("TBM:LOOT|2026-11-22 20:00:00|" .. BOTS[1] .. "|StoreLootAction|2589|Linen Cloth|corpse|Defias Thug|1")
        emit("TBM:LOOT_END|")
        return true
    end
    if verb == "hire" then
        local tier = tonumber(string.match(rest, "t(%d)")) or 0
        local level = tonumber(string.match(rest, "level=(%d+)")) or 60
        emit("TBM:ACTION_ACK|hire|bot:Recruit|1|tier " .. tier .. ", fee 20000 copper, level " .. level)
        return true
    end
    -- Actions, movement, lifecycle, run and everything else: confirm the intent
    -- so the click flashes green and the status line settles.
    local intent = string.match(cmd or "", "^%S+%s*(.*)$")
    if intent == "" then intent = verb end
    emit("TBM:ACTION_ACK|" .. verb .. "|party|" .. #BOTS .. "|-")
    return true
end

function TB.SetFakeServer(on)
    TB.fake.enabled = on and true or false
    if TB.fake.enabled then
        if TB.SetAddonTransport then TB.SetAddonTransport("party") end
        TB.Print("Fake server on: commands are answered locally (no server traffic). /tbfm fake to turn it off.")
    else
        TB.Print("Fake server off.")
    end
    if TB.Refresh then TB.Refresh() end
    if TB.RefreshVersionLine then TB.RefreshVersionLine() end
end

function TB.FakeCommand(msg)
    msg = string.lower(string.gsub(TB.Trim and TB.Trim(msg or "") or (msg or ""), "%s+", " "))
    if msg == "fake" or msg == "echo" then
        TB.SetFakeServer(not TB.fake.enabled)
    elseif msg == "status" or msg == "" then
        TB.Print("trace " .. (TB.trace and "on" or "off") .. " · fake server "
            .. (TB.fake.enabled and "on" or "off") .. " · transport "
            .. ((TB.AddonCommandChannel and TB.AddonCommandChannel()) and "party" or "chat"))
        TB.Print("/tbfm trace - message trace, /tbfm fake - offline fake server, /tbfm status")
    else
        TB.Print("Usage: /tbfm [trace|fake|status]")
    end
end
