-- Armory readiness checks (server side: TBF #404).
-- Run from tests/regression.lua, same shape as tests/altsum_tests.lua: the
-- caller passes its locals (sent, time helpers) in env.

return function(env)
local advanceTime = env.advanceTime

local TB = TortoiseBots

local ROW_ALPHA = "TBM:ARMORY|Alpha|1|60|1|1|tank|Protection|65|8.0|0.0|0.0|300|10+11+12+13+14|9.0|440|"
    .. "ap=1200,crit=10.0,armor=6000,sta=500,sp=0,heal=0,scrit=0.0,mp5=0,int=40"
local ROW_BRAVO = "TBM:ARMORY|Bravo|5|60|1|0|healer|Holy|70|0.0|0.0|18.0|280|20+20+20+20+20|16.0|0|"
    .. "ap=300,crit=5.0,armor=2000,sta=300,sp=200,heal=420,scrit=9.5,mp5=25,int=300"

-- (1) The tab and its data are gated on the server's `armory` capability.
TB.OnSystemMessage("TBM:CAPS|inventory")
assert(not TB.HasArmoryCapability(), "armory must be off without the capability")
if TB.UpdateRaidTab then TB.UpdateRaidTab() end
assert(not TB.tabArmory:IsVisible(), "the Armory tab must stay hidden without the capability")

TB.OnSystemMessage("TBM:CAPS|inventory,armory")
assert(TB.HasArmoryCapability(), "armory must light from TBM:CAPS")
if TB.UpdateRaidTab then TB.UpdateRaidTab() end
assert(TB.tabArmory:IsVisible(), "the Armory tab must appear with the capability")

-- (2) A strip whose second part is missing is not trusted: the Gear tab
-- says it was not reported instead of inventing missing enchants.
TB.OnSystemMessage("TBM:ARMORY_BEGIN|1")
TB.OnSystemMessage(ROW_ALPHA)
assert(TB.GetArmoryRow("Alpha") == nil, "a row must not commit before ARMORY_END")
TB.OnSystemMessage("TBM:ARMORY_EQ|Alpha|1/2|0:12345:0:1:3,1:12346:0:0:2")
TB.OnSystemMessage("TBM:ARMORY_END|1")
local partial = TB.GetArmoryRow("Alpha")
assert(partial and partial.eqKnown == false, "a half strip must not count as known")
assert(TB.armoryFrame and not TB.armoryFrame.rows[1].squares[0]:IsVisible(),
    "a half strip must not draw its slots")

-- (3) The full snapshot: rows and equipment parts merge; BEGIN/END counts
-- must agree with what arrived.
TB.OnSystemMessage("TBM:ARMORY_BEGIN|2")
TB.OnSystemMessage(ROW_ALPHA)
TB.OnSystemMessage(ROW_BRAVO)
TB.OnSystemMessage("TBM:ARMORY_EQ|Alpha|1/2|0:12345:0:1:3,1:12346:0:0:2")
TB.OnSystemMessage("TBM:ARMORY_EQ|Alpha|2/2|4:0:0:2:0,15:12356:0:0:2,16:0:0:0:0")
TB.OnSystemMessage("TBM:ARMORY_EQ|Bravo|1/1|0:12345:0:0:3,1:12346:0:0:2")
TB.OnSystemMessage("TBM:ARMORY_END|2")
local alpha = TB.GetArmoryRow("Alpha")
local bravo = TB.GetArmoryRow("Bravo")
assert(alpha and bravo, "both rows must commit")
assert(alpha.eqKnown == true and bravo.eqKnown == true, "complete strips must count as known")
assert(#TB.GetArmoryRows() == 2, "the full answer must replace the list")
assert(alpha.missing == nil and TB.ArmoryProblemCount(alpha) == 2,
    "Alpha misses the head enchant and the empty chest")
assert(TB.ArmoryProblemCount(bravo) == 0, "Bravo is fully enchanted")
assert(TB.ArmoryMissingSummary(bravo) == "Nothing missing", "a clean bot says so")
assert(TB.ArmoryMissingSummary(alpha) == "Missing: Head enchant, Chest empty",
    "the short form names the first two problems")
assert(TB.ArmorySlotShown(alpha, 16) == false, "a two-hander's off hand is not drawn")
assert(TB.ArmorySlotShown(alpha, 4) == true, "an empty slot that should hold something is drawn")

-- Roles and goals: Alpha's 8.0 hit is under its 9.0 goal and its 300 defense
-- under the 440 crit cover; Bravo has no hit goal as a healer.
assert(TB.ArmoryHit(alpha) == 8.0 and TB.ArmoryHitPass(alpha) == false, "Alpha is under the hit cap")
assert(TB.ArmoryDefensePass(alpha) == false, "Alpha is under the tank defense goal")
assert(TB.ArmoryHit(bravo) == 0 and TB.ArmoryHitPass(bravo) == nil, "healers have no hit goal")

local summary = TB.ArmorySummary(TB.GetArmoryRows())
assert(summary.tanks == 1 and summary.healers == 1 and summary.dps == 0, "role tiles count the rows")
assert(summary.underHit == 1 and summary.underDefense == 1 and summary.missing == 1,
    "the chips count the real problems")

-- (4) Filters: This raid keeps the grouped bot, search matches names, and
-- Problems only drops the ready healer.
local raid = TB.FilterArmoryRows(TB.GetArmoryRows(), { raidOnly = true })
assert(#raid == 1 and raid[1].name == "Alpha", "This raid keeps only grouped bots")
local bravoOnly = TB.FilterArmoryRows(TB.GetArmoryRows(), { search = "bra" })
assert(#bravoOnly == 1 and bravoOnly[1].name == "Bravo", "search is a case-insensitive name match")
local problems = TB.FilterArmoryRows(TB.GetArmoryRows(), { problemsOnly = true })
assert(#problems == 1 and problems[1].name == "Alpha", "Problems only drops the ready bot")

-- (5) A one-bot answer updates that row and leaves the rest of the list.
local alphaAgain = {}
for key, value in pairs(alpha) do alphaAgain[key] = value end
alphaAgain.hitCap = 8.0
TB.SetArmory({ alphaAgain }, false)
assert(#TB.GetArmoryRows() == 2, "a one-bot answer must merge, not replace")
assert(TB.GetArmoryRow("Alpha").hitCap == 8.0, "the answered row must be replaced")

-- (6) The Armory view paints the row, hit/defense columns and the dots.
TB.RefreshArmoryView()
local frame = TB.armoryFrame
assert(frame and frame.rows[1].armoryData, "the first Armory row must show a bot")
assert(frame.rows[1].hit:GetText() == "8.0/8", "the row shows hit against the cap")
assert(frame.rows[1].def:GetText() == "300", "the tank row shows defense")
assert(frame.rows[1].squares[0].dot:IsVisible(), "a missing enchant shows a red dot")
assert(not frame.rows[1].squares[1].dot:IsVisible(), "a finished slot has no dot")

-- (7) The Gear tab: miss dots, the Missing line, and the Stats/Model sheet.
TB.SetInventory("Alpha", {
    equipped = { [0] = { id = 12345, durability = 100, maxDurability = 100 } },
    items = {}, free = 16, total = 20,
})
TB.OpenBotPanel("Alpha", "gear")
local panel = TB.botPanel
assert(panel and panel.missingText, "the Gear tab owns a Missing line")
assert(panel.missingText:IsVisible(), "the Missing line shows with the capability")
assert(string.find(panel.missingText:GetText(), "^Missing:"), "the Missing line names the problems")
assert(panel.gearButtons[0].missDot:IsVisible(), "an unenchanted slot gets a dot")
assert(panel.statsButton:IsVisible(), "the Stats button shows with the capability")

panel.statsButton.scripts.OnClick(panel.statsButton)
assert(panel.statsSheet:IsVisible(), "Stats shows the sheet")
assert(not panel.model:IsVisible(), "Stats hides the model")
assert(panel.statsButton:GetText() == "Model", "the button now offers the model back")
assert(panel.statsSheet.lines[1].label:GetText() == "GOALS · TANK", "the sheet leads with the goals")
assert(panel.statsSheet.lines[4].label:GetText() == "MELEE", "a tank reads the melee block")
panel.statsButton.scripts.OnClick(panel.statsButton)
assert(panel.model ~= nil and panel.statsButton:GetText() == "Stats", "Model shows the model back")
TB.CloseBotPanel()

-- (8) Without the capability the Gear tab keeps no dots and no sheet, even
-- with a stale row still in memory.
TB.OnSystemMessage("TBM:CAPS|inventory")
assert(TB.GetArmoryRow("Alpha") == nil, "dropping the capability drops the snapshot")
TB.OpenBotPanel("Alpha", "gear")
panel = TB.botPanel
assert(not panel.statsButton:IsVisible(), "no Stats button without the capability")
assert(not panel.gearButtons[0].missDot:IsVisible(), "no dots without the capability")
TB.CloseBotPanel()

-- (9) The fake server answers the same protocol: a two-part strip, both rows.
TB.OnSystemMessage("TBM:CAPS|inventory,armory")
assert(TB.FakeServerSend and TB.FakeServerSend("armory"), "the fake server answers armory")
assert(TB.GetArmoryRow("Alpha") and TB.GetArmoryRow("Bravo"), "fake rows parse")
assert(TB.GetArmoryRow("Alpha").eqKnown == true, "the fake two-part strip commits")
assert(TB.ArmoryProblemCount(TB.GetArmoryRow("Alpha")) > 0, "the fake tank has gear issues")

advanceTime(1)
print("PASS: armory readiness checks")
end
