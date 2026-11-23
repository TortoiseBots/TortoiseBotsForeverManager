-- Forever #133/#134 panel verb routing, gating, sample-line parsing, and FakeServer checks.
return function(ctx)
    local root = (type(ctx) == "table" and ctx.root) or ctx or "."
    local advanceTime = type(ctx) == "table" and ctx.advanceTime or nil

    dofile(root .. "/Forever.lua")
    dofile(root .. "/ForeverHybrid.lua")
    dofile(root .. "/BridgeToggles.lua")

    local TB = TortoiseBots
    local F = TB.Forever

    local savedCapsKnown = TB.ServerCapabilitiesKnown
    local savedSetStatus = TB.SetStatus
    local savedLogMessage = TB.LogMessage
    local savedTogglePending = TB.togglePending
    TB.SetStatus = function() end
    TB.LogMessage = function() end
    TB.togglePending = {}

    local function resetState()
        TB.ClearServerVerbs()
        TB.OnSystemMessage("TBM:CAPS|")
        TB._serverCaps = {}
        if TB.InvalidateAddonTransport then TB.InvalidateAddonTransport() end
    end

    local PANEL_CMDS = {
        { verb = "totem",       cmd = "totem Alpha status" },
        { verb = "blessing",    cmd = "blessing Alpha status" },
        { verb = "choice",      cmd = "choice Alpha status" },
        { verb = "behavior",    cmd = "behavior Alpha loot off" },
        { verb = "service",     cmd = "service Alpha" },
        { verb = "inv",         cmd = "inv Alpha" },
        { verb = "inventory",   cmd = "inventory Alpha" },
        { verb = "item",        cmd = "item Alpha equip 0 1" },
        { verb = "trade",       cmd = "trade Alpha" },
        { verb = "professions", cmd = "professions Alpha" },
        { verb = "lootlog",     cmd = "lootlog" },
    }

    -- 1. Routing & gating when VERBS/CAPS omit these verbs (non-GM, no tb-gm).
    resetState()
    TB.ServerCapabilitiesKnown = function() return true end
    TB.OnSystemMessage("TBM:VERBS_BEGIN|1")
    TB.OnSystemMessage("TBM:VERBS|roster")
    TB.OnSystemMessage("TBM:VERBS_END")
    TB.OnSystemMessage("TBM:CAPS|order")
    TB.RefreshActionControls()

    for _, entry in ipairs(PANEL_CMDS) do
        assert(F.Route(entry.cmd) == "grey", entry.cmd .. " should be grey when unlisted for non-GM")
        assert(F.Native(entry.cmd) == false, entry.cmd .. " should not be native when unlisted")
        assert(F.Available(entry.cmd) == false, entry.cmd .. " should not be available when unlisted")
    end
    assert(TB.actionButtons.totem.enabled == false and TB.actionButtons.totem._foreverMarked == true,
        "totem party drop button stays grey when totem is unlisted")
    assert(TB.toggleButtons.spread.enabled == false and TB.toggleButtons.spread._foreverMarked == true,
        "behavior toggle stays grey when behavior is unlisted")
    assert(TB.lootFrame._wipBanner and TB.lootFrame._wipBanner:IsVisible(),
        "loot WIP banner stays visible when lootlog is unlisted")
    assert(not TB.HasBlessingCapability(), "blessing cap false when unlisted")
    assert(not TB.HasBlessingPlayerCapability(), "blessing-player cap false when unlisted")
    assert(not TB.HasChoiceCapability(), "choice cap false when unlisted")
    assert(not TB.HasProfessionsCapability(), "professions cap false when unlisted")
    assert(not TB.HasLootCapability(), "loot-log cap false when unlisted")
    assert(not TB.HasServerCapability("inventory"), "inventory cap false when unlisted")

    -- 2. Routing & un-greying once VERBS and CAPS advertise all 10 families.
    TB.OnSystemMessage("TBM:VERBS_BEGIN|12")
    TB.OnSystemMessage("TBM:VERBS|roster,totem,blessing,choice,behavior,service,inv,inventory,item,trade,professions,lootlog")
    TB.OnSystemMessage("TBM:VERBS_END")
    TB.OnSystemMessage("TBM:CAPS|totem,blessing,blessing-player,choice,behavior,service,inventory,professions,loot-log")
    TB.RefreshActionControls()

    for _, entry in ipairs(PANEL_CMDS) do
        assert(F.Route(entry.cmd) == "native", entry.cmd .. " should route native when listed")
        assert(F.Native(entry.cmd) == true, entry.cmd .. " should be native when listed")
        assert(F.Available(entry.cmd) == true, entry.cmd .. " should be available when listed")
    end
    assert(TB.actionButtons.totem.enabled == true and not TB.actionButtons.totem._foreverMarked,
        "totem party drop button un-greys when totem is in VERBS")
    assert(TB.toggleButtons.spread.enabled == true and not TB.toggleButtons.spread._foreverMarked,
        "behavior toggle un-greys when behavior is in VERBS")
    for _, k in ipairs({ "aoe", "autocc", "sap", "loot" }) do
        assert(TB.toggleButtons[k].enabled == false and TB.toggleButtons[k]._foreverMarked == true,
            "action switch " .. k .. " stays grey for non-GM when only behavior is in VERBS")
    end

    -- With tb-gm, unlisted action switches fall back to bridge (.tb cmd);
    -- once action:aoe/auto cc/sap/loot are in VERBS, they route native for non-GM too.
    TB.OnSystemMessage("TBM:CAPS|totem,blessing,blessing-player,choice,behavior,service,inventory,professions,loot-log,tb-gm")
    TB.RefreshActionControls()
    for _, k in ipairs({ "aoe", "autocc", "sap", "loot" }) do
        assert(TB.toggleButtons[k].enabled == true and not TB.toggleButtons[k]._foreverMarked,
            "action switch " .. k .. " un-greys via bridge when tb-gm is present")
    end
    assert(F.Route("action aoe on") == "bridge" and F.Route("action auto cc on") == "bridge",
        "action switches route to bridge with tb-gm when not in VERBS")

    TB.OnSystemMessage("TBM:VERBS_BEGIN|16")
    TB.OnSystemMessage("TBM:VERBS|roster,totem,blessing,choice,behavior,service,inv,inventory,item,trade,professions,lootlog,action:aoe,action:auto cc,action:sap,action:loot")
    TB.OnSystemMessage("TBM:VERBS_END")
    TB.OnSystemMessage("TBM:CAPS|totem,blessing,blessing-player,choice,behavior,service,inventory,professions,loot-log")
    TB.RefreshActionControls()
    for _, k in ipairs({ "aoe", "autocc", "sap", "loot" }) do
        assert(TB.toggleButtons[k].enabled == true and not TB.toggleButtons[k]._foreverMarked,
            "action switch " .. k .. " un-greys for non-GM once its action:* token is in VERBS")
    end
    assert(F.Route("action aoe on") == "native" and F.Route("action auto cc on") == "native",
        "action switches route native once action:* tokens are in VERBS")
    assert(not TB.lootFrame._wipBanner:IsVisible(),
        "loot WIP banner hides when lootlog is in VERBS")
    assert(TB.HasBlessingCapability(), "blessing cap true when listed")
    assert(TB.HasBlessingPlayerCapability(), "blessing-player cap true when listed")
    assert(TB.HasChoiceCapability(), "choice cap true when listed")
    assert(TB.HasProfessionsCapability(), "professions cap true when listed")
    assert(TB.HasLootCapability(), "loot-log cap true when listed")
    assert(TB.HasServerCapability("inventory"), "inventory cap true when listed")

    -- 3. Sample line parse for each family.
    local totem = TB.ParseTotemLine("TBM:TOTEM|Alpha|earth=strength of earth totem,fire=none,water=mana spring totem,air=auto,mode=manual,known=strength of earth totem+mana spring totem")
    assert(totem and totem.slots.earth == "strength of earth totem" and totem.mode == "manual",
        "ParseTotemLine parses server TBM:TOTEM line")

    local bless = TB.ParseBlessingLine("TBM:BLESSING|Alpha|warrior=might,paladin=wisdom,hunter=might,rogue=might,priest=wisdom,shaman=wisdom,mage=wisdom,warlock=wisdom,druid=wisdom,known=might+wisdom,players=Player:kings")
    assert(bless and bless.classes.warrior == "might" and bless.players.Player == "kings",
        "ParseBlessingLine parses server TBM:BLESSING line")

    local choice = TB.ParseChoiceLine("TBM:CHOICE|Alpha|aspect=hawk,known=hawk+monkey")
    assert(choice and choice.kind == "aspect" and choice.value == "hawk" and #choice.known == 2,
        "ParseChoiceLine parses server TBM:CHOICE line")

    assert(TB.ParseBotPanelMessage("TBM:BOTSTATE_BEGIN|1"))
    assert(TB.ParseBotPanelMessage("TBM:BOTSTATE|Alpha|move=follow,loot=on,aoe=off"))
    assert(TB.ParseBotPanelMessage("TBM:BOTSTATE_END"))
    assert(TB.GetBotState("Alpha") and TB.GetBotState("Alpha").loot == "on",
        "ParseBotPanelMessage parses TBM:BOTSTATE stream")

    local svc = TB.ParseServiceLine("TBM:SERVICE|Alpha|1|1|0|10059:Stormwind")
    assert(svc and svc.food and svc.water and not svc.healthstone and svc.portals[1].spell == 10059,
        "ParseServiceLine parses server TBM:SERVICE line")

    assert(TB.ParseBotPanelMessage("TBM:INV_BEGIN|Alpha|1234"))
    assert(TB.ParseBotPanelMessage("TBM:INV_EQ|0|12345|100|100"))
    assert(TB.ParseBotPanelMessage("TBM:INV_ITEM|0|1|2589|4|e"))
    assert(TB.ParseBotPanelMessage("TBM:INV_END|Alpha|2|16"))
    local inv = TB.GetInventory("Alpha")
    assert(inv and inv.money == 1234 and inv.equipped[0].id == 12345 and inv.items[1].id == 2589 and inv.free == 2,
        "ParseBotPanelMessage parses TBM:INV_* stream")

    assert(TB.ParseBotPanelMessage("TBM:PROF_BEGIN|Alpha"))
    assert(TB.ParseBotPanelMessage("TBM:PROF|186|265|300"))
    assert(TB.ParseBotPanelMessage("TBM:RECIPE|186|2651|3860|1|25|50|100|ok"))
    assert(TB.ParseBotPanelMessage("TBM:RECIPE_MISSING|186|2652|3861|275|0"))
    assert(TB.ParseBotPanelMessage("TBM:PROF_END|Alpha|1|1"))
    local prof = TB.GetProfessions("Alpha")
    assert(prof and prof.skills[1].skill == 186 and prof.recipes[1].spell == 2651 and prof.missing[1].spell == 2652,
        "ParseBotPanelMessage parses TBM:PROF_* stream")

    local lootRow = TB.ParseLootLine("TBM:LOOT|2026-11-22 20:00:00|Alpha|StoreLootAction|2589|Linen Cloth|corpse|Defias Thug|1")
    assert(lootRow and lootRow.bot == "Alpha" and lootRow.itemId == 2589 and lootRow.quality == 1,
        "ParseLootLine parses server TBM:LOOT line")

    local okEq, kindEq, pktEq = TB.ParseActionMessage("TBM:ACTION_ACK|item equip|bot:Alpha|1|2589")
    assert(okEq and kindEq == "ack" and pktEq.intent == "item equip" and pktEq.executor == "2589",
        "ParseActionMessage parses item equip ACK")
    local okTr, kindTr, pktTr = TB.ParseActionMessage("TBM:ACTION_ACK|trade|bot:Alpha|1|open")
    assert(okTr and kindTr == "ack" and pktTr.intent == "trade" and pktTr.executor == "open",
        "ParseActionMessage parses trade ACK")

    -- 4. FakeServer emits VERBS/CAPS and answers all 10 families cleanly.
    resetState()
    TB.ServerCapabilitiesKnown = savedCapsKnown
    TB.SetFakeServer(true)
    if advanceTime then advanceTime(5) end
    assert(TB.SendBotCommand("roster"), "FakeServer answers roster")
    assert(TB.HasServerVerb("item") and TB.HasServerVerb("trade") and TB.HasServerVerb("inventory"),
        "FakeServer VERBS includes item, trade, inventory")
    assert(TB.HasServerCapability("behavior") and TB.HasServerCapability("inventory")
        and TB.HasServerCapability("blessing-player") and TB.HasServerCapability("loot-log"),
        "FakeServer CAPS includes behavior, inventory, blessing-player, loot-log")

    for _, entry in ipairs(PANEL_CMDS) do
        if advanceTime then advanceTime(5) end
        assert(TB.SendBotCommand(entry.cmd), "FakeServer answers " .. entry.cmd)
    end
    assert(TB.GetBlessings("Alpha") and TB.GetBlessings("Alpha").classes.warrior == "might",
        "FakeServer blessing reply parses into BotBlessing store")
    TB.SetFakeServer(false)

    -- Cleanup
    resetState()
    TB.ServerCapabilitiesKnown = savedCapsKnown
    TB.SetStatus = savedSetStatus
    TB.LogMessage = savedLogMessage
    TB.togglePending = savedTogglePending
    TB.Forever = nil
    TB.RefreshActionControls()
    TB.RefreshVersionLine()
    print("PASS: Forever panel routing, gating, and parse checks")
end
