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
local FAKE_CAPS = "order,order-steps,guild-order-steps,professions,blessing,choice,service,totem,loot,guild-bots,altsummary,run"

local function emit(line)
    if TB.trace and TB.TracePrint then TB.TracePrint("< " .. line .. "   [fake]") end
    if TB.OnAddonMessage then
        TB.OnAddonMessage(PREFIX, line, "PARTY", "FakeServer")
    elseif TB.OnSystemMessage then
        TB.OnSystemMessage(line)
    end
end

local function sendChatLine(line)
    if TB.OnSystemMessage then TB.OnSystemMessage(line) end
end

local function rosterStream()
    emit("TBM:TRANSPORT|party")
    emit("TBM:PROTO|1|0")
    emit("TBM:VERSION|v2.4.1-forever")
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
        local scope, arg = string.match(rest, "^(%S+)%s*(%S*)$")
        if scope == "party" then
            emit("TBM:ACTION_ACK|behavior|party|" .. #BOTS .. "|" .. (arg ~= "" and arg or "on"))
            return true
        end
        local bot = scope ~= "" and scope or BOTS[1]
        botStateStream(bot)
        emit("TBM:ACTION_ACK|behavior|bot:" .. bot .. "|1|-")
        return true
    end
    if verb == "inv" then
        local bot = rest ~= "" and rest or BOTS[1]
        inventoryStream(bot)
        return true
    end
    if verb == "professions" then
        local bot = rest ~= "" and rest or BOTS[1]
        professionsStream(bot)
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
        emit("TBM:BLESSING|" .. BOTS[1] .. "|warrior=auto,paladin=auto,druid=auto,known=might+wisdom")
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
        return true   -- an empty loot page is a valid answer
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
