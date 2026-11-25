-- Offline fake server (/tbfm fake) checks.
-- Run from tests/regression.lua like the other suites: the canvas, roster,
-- inventory and order parsers must accept the canned wire lines, and no line
-- may reach chat while fake mode is on.
return function(env)
local advanceTime = env.advanceTime
local sent = env.sent
local addonSent = env.addonSent
local TB = TortoiseBots

TB.SetFakeServer(true)
advanceTime(5)
local before = table.getn(sent)
assert(TB.SendBotCommand("roster"), "the fake server accepts a roster request")
assert(table.getn(sent) == before, "fake mode must not put a .bot line in chat")
assert(TB.serverVersion == "v2.4.1-forever", "the fake server reports its version")
assert(TB._serverCaps and TB._serverCaps.order, "the fake server reports capabilities")
local alpha = TB.GetState("Alpha")
assert(alpha and alpha.serverState == "online" and alpha.classId == 1,
    "the fake roster row is committed (state, class)")
local guild = TB.GetClaimedBots()
assert(guild and guild[1] and guild[1].name == "Goldie" and guild[1].level == 60,
    "the fake claimed-guild row is committed (" .. tostring(guild and #guild) .. " rows, "
        .. tostring(guild and guild[1] and guild[1].name) .. ")")

advanceTime(5)
assert(TB.SendBotCommand("inv Alpha"), "the fake server answers an inventory request")
local inv = TB.GetInventory("Alpha")
assert(inv and inv.money == 12345, "the fake inventory money is committed")
assert(inv.equipped and inv.equipped[0] and inv.equipped[0].id == 12345,
    "the fake equipped row is committed")
assert(inv.items and #inv.items == 2 and inv.items[1].count == 4,
    "the fake bag rows are committed")

advanceTime(5)
assert(TB.SendBotCommand("order list"), "the fake server answers an order list")
local orders = TB.GetOrders()
local first = orders and orders[1]
assert(first and first.bot == "Goldie" and first.type == "craft"
    and first.state == "waiting" and first.want == 10,
    "the fake order row is committed")

advanceTime(5)
assert(TB.SendBotCommand("behavior Alpha"), "the fake server answers a behaviour request")
local st = TB.GetBotState("Alpha")
assert(st and st.move == "follow", "the fake bot state is committed")

assert(TB.HasServerCapability("hire-anywhere"), "the fake server allows hiring anywhere")
assert(TB.tabHire and TB.tabHire:IsVisible(), "the fake hire-anywhere shows the Hire tab")
advanceTime(5)
local hireChat = table.getn(sent)
assert(TB.SendHire() == true, "the fake server accepts a hire")
assert(table.getn(sent) == hireChat, "fake hire must not put a .bot line in chat")
assert(string.find(TB.hireFrame.feeText:GetText(), "Fee paid", 1, true),
    "the fake hire ACK carries a fee")

TB.SetFakeServer(false)
advanceTime(5)
local addonBefore = table.getn(addonSent)
local chatBefore = table.getn(sent)
TB.SendBotCommand("roster")
assert(table.getn(addonSent) == addonBefore + 1 and addonSent[addonBefore + 1].message == "roster",
    "with fake mode off the request leaves over the server's addon channel again")
assert(table.getn(sent) == chatBefore, "no chat fallback while the addon channel is up")
end
