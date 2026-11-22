return function(root)
    local TB = TortoiseBots
    dofile(root .. "/Forever.lua")

    local savedCapsKnown = TB.ServerCapabilitiesKnown
    TB.ServerCapabilitiesKnown = function() return false end

    local tipTitle, tipLines
    local realSetText = GameTooltip.SetText
    local realAddLine = GameTooltip.AddLine
    GameTooltip.SetText = function(_, text) tipTitle = text; tipLines = {} end
    GameTooltip.AddLine = function(_, text) table.insert(tipLines, text) end

    TB.RefreshActionControls()
    TB.RefreshVersionLine()

    local wipBtn = TB.actionButtons.ready
    local followBtn = TB.actionButtons.follow
    assert(wipBtn and wipBtn.enabled == false, "WIP action button should be disabled when Native() is false")
    assert(wipBtn._foreverMarked == true, "WIP action button should be marked unavailable")
    wipBtn.scripts.OnEnter(wipBtn)
    assert(tipTitle == "Not currently available", "WIP button tooltip title must be 'Not currently available'")
    assert(tipLines[1] and string.find(tipLines[1], "still being ported", 1, true),
        "WIP button tooltip must explain TortoiseBotsForever WIP status")

    assert(followBtn and followBtn.enabled == true, "Available action button should stay enabled")
    assert(not followBtn._foreverMarked, "Available action button should not be marked unavailable")

    assert(TB.rosterFrame and TB.rosterFrame._wipBanner and TB.rosterFrame._wipBanner:IsVisible(),
        "Roster tab should show WIP banner when Native() is false")
    assert(TB.versionLine and string.find(TB.versionLine:GetText() or "", "some features are not available yet while the bots are being fully ported", 1, true),
        "Main window header should show WIP bridge notice")

    -- When TBM:CAPS arrives (Native() becomes true), normal gating takes over.
    TB.ServerCapabilitiesKnown = function() return true end
    TB.RefreshActionControls()
    TB.RefreshVersionLine()

    assert(wipBtn.enabled == true, "WIP button should re-enable once Native() is true")
    assert(not wipBtn._foreverMarked, "WIP mark should be cleared once Native() is true")
    wipBtn.scripts.OnEnter(wipBtn)
    assert(tipTitle ~= "Not currently available", "Original tooltip should be restored once Native() is true")
    assert(not TB.rosterFrame._wipBanner:IsVisible(), "Roster WIP banner should hide once Native() is true")
    assert(not string.find(TB.versionLine:GetText() or "", "some features are not available yet while the bots are being fully ported", 1, true),
        "WIP bridge notice should clear once Native() is true")

    GameTooltip.SetText = realSetText
    GameTooltip.AddLine = realAddLine
    TB.ServerCapabilitiesKnown = savedCapsKnown
    TB.Forever = nil
    TB.RefreshActionControls()
    TB.RefreshVersionLine()
    print("PASS: Forever WIP gating checks")
end
