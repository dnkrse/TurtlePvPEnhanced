-- TurtlePvP: settings.lua — Settings window, tabs, checkboxes, previews

local container = TBGH.container

---------------------------------------------------------------------
-- Settings window
---------------------------------------------------------------------
local settingsFrame = CreateFrame("Frame", "TurtlePvPSettingsFrame", UIParent)
settingsFrame:SetWidth(340)
settingsFrame:SetHeight(400)
settingsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
settingsFrame:SetFrameStrata("DIALOG")
settingsFrame:SetMovable(true)
settingsFrame:EnableMouse(true)
settingsFrame:SetClampedToScreen(true)
settingsFrame:RegisterForDrag("LeftButton")
settingsFrame:SetScript("OnDragStart", function() settingsFrame:StartMoving() end)
settingsFrame:SetScript("OnDragStop", function() settingsFrame:StopMovingOrSizing() end)
settingsFrame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
settingsFrame:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
settingsFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
settingsFrame:Hide()

-- Title
local settingsTitle = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
settingsTitle:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 12, -10)
settingsTitle:SetTextColor(1, 0.82, 0, 1)
settingsTitle:SetText("TurtlePvPEnhanced")

local settingsVersion = settingsFrame:CreateFontString(nil, "OVERLAY")
settingsVersion:SetFont("Fonts\\FRIZQT__.TTF", 9)
settingsVersion:SetPoint("LEFT", settingsTitle, "RIGHT", 6, 0)
settingsVersion:SetTextColor(0.45, 0.45, 0.45, 1)
settingsVersion:SetText("v" .. (GetAddOnMetadata("TurtlePvPEnhanced", "Version") or "?"))

-- Title separator
local titleSep = settingsFrame:CreateTexture(nil, "ARTWORK")
titleSep:SetHeight(1)
titleSep:SetPoint("TOPLEFT",  settingsFrame, "TOPLEFT",  8, -26)
titleSep:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -8, -26)
titleSep:SetTexture("Interface\\BUTTONS\\WHITE8X8")
titleSep:SetVertexColor(0.35, 0.35, 0.35, 0.8)

-- Close button
local closeBtn = CreateFrame("Button", "TurtlePvPSettingsClose", settingsFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", 2, 2)

---------------------------------------------------------------------
-- Preview helpers — delegate to modules
---------------------------------------------------------------------
local function HideAllPreviews()
    for i = 1, table.getn(TBGH.modules) do
        local mod = TBGH.modules[i]
        if mod.hidePreview then mod.hidePreview() end
    end
    TBGH.previewSection = nil
end
TBGH.HideAllPreviews = HideAllPreviews

local function ShowSectionPreview(section)
    HideAllPreviews()
    TBGH.previewSection = section
    for i = 1, table.getn(TBGH.modules) do
        local mod = TBGH.modules[i]
        if mod.name == section and mod.showPreview then
            mod.showPreview()
            return
        end
    end
end
TBGH.ShowSectionPreview = ShowSectionPreview

---------------------------------------------------------------------
-- Tab system: "Battlegrounds" and "Combat"
---------------------------------------------------------------------
local activeTab = "bg"

-- MakeThinScrollbar: minimal 5px track + gold thumb, mouse-wheel + drag to scroll.
-- vH: explicit visible height — avoids relying on GetHeight() before layout is resolved.
-- Returns an UpdateThumb() function to call after externally resetting scroll position.
local function MakeThinScrollbar(wrapper, sf, child, vH)
    local PAD = 4
    local BAR_W = 5

    local track = wrapper:CreateTexture(nil, "BACKGROUND")
    track:SetWidth(BAR_W)
    track:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    track:SetVertexColor(0.06, 0.06, 0.06, 0.85)
    track:SetPoint("TOPRIGHT",    wrapper, "TOPRIGHT",    -3, -PAD)
    track:SetPoint("BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", -3,  PAD)

    local thumb = CreateFrame("Frame", nil, wrapper)
    thumb:SetWidth(BAR_W)
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetAllPoints(thumb)
    thumbTex:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    thumbTex:SetVertexColor(0.8, 0.67, 0.0, 0.75)
    thumb:Hide()

    local trkH = vH - PAD * 2   -- constant: track pixel height

    local function UpdateThumb()
        local cH = child:GetHeight()
        if cH <= vH then thumb:Hide(); return end
        local thmH   = math.max(16, trkH * vH / cH)
        local rangeT = trkH - thmH
        local rangeS = cH - vH
        local posY   = rangeS > 0 and (sf:GetVerticalScroll() / rangeS * rangeT) or 0
        thumb:SetHeight(thmH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", wrapper, "TOPRIGHT", -3, -(PAD + posY))
        thumb:Show()
    end

    local dragging, dragStartY, dragStartScroll = false, 0, 0
    thumb:EnableMouse(true)
    thumb:SetScript("OnMouseDown", function()
        dragging = true
        local _, sy = GetCursorPosition()
        dragStartY     = sy / UIParent:GetEffectiveScale()
        dragStartScroll = sf:GetVerticalScroll()
    end)
    thumb:SetScript("OnMouseUp", function() dragging = false end)

    sf:SetScript("OnUpdate", function()
        if not dragging then return end
        local _, cy = GetCursorPosition()
        local dy     = dragStartY - cy / UIParent:GetEffectiveScale()
        local cH     = child:GetHeight()
        local thmH   = math.max(16, trkH * vH / cH)
        local rangeT = trkH - thmH
        local rangeS = cH - vH
        if rangeT > 0 then
            local new = math.max(0, math.min(rangeS, dragStartScroll + dy * rangeS / rangeT))
            sf:SetVerticalScroll(new)
            UpdateThumb()
        end
    end)

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function()
        local cH     = child:GetHeight()
        local rangeS = math.max(0, cH - vH)
        local new    = math.max(0, math.min(rangeS, sf:GetVerticalScroll() - arg1 * 30))
        sf:SetVerticalScroll(new)
        UpdateThumb()
    end)

    return UpdateThumb
end

-- View height: settingsFrame(400) - header(30) - bottom(46) = 324
local SCROLL_VIEW_H = settingsFrame:GetHeight() - 76

-- BG tab: wrapper → scroll frame → scroll child (bgTabContent)
local bgWrapper = CreateFrame("Frame", nil, settingsFrame)
bgWrapper:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 6, -30)
bgWrapper:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -12, 46)

local bgScrollFrame = CreateFrame("ScrollFrame", "TurtlePvPBGScrollFrame", bgWrapper)
bgScrollFrame:SetPoint("TOPLEFT", bgWrapper, "TOPLEFT", 0, 0)
bgScrollFrame:SetPoint("BOTTOMRIGHT", bgWrapper, "BOTTOMRIGHT", -12, 0)

local bgTabContent = CreateFrame("Frame", nil, bgScrollFrame)
bgTabContent:SetWidth(310)
bgTabContent:SetHeight(374)  -- 8 + 62+6 + 118+6 + 54+6 + 54+6 + 54 = exact BG content height
bgScrollFrame:SetScrollChild(bgTabContent)

-- Combat tab: wrapper → scroll frame → scroll child (combatTabContent)
local combatWrapper = CreateFrame("Frame", nil, settingsFrame)
combatWrapper:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 6, -30)
combatWrapper:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -12, 46)
combatWrapper:Hide()

local combatScrollFrame = CreateFrame("ScrollFrame", "TurtlePvPCombatScrollFrame", combatWrapper)
combatScrollFrame:SetPoint("TOPLEFT", combatWrapper, "TOPLEFT", 0, 0)
combatScrollFrame:SetPoint("BOTTOMRIGHT", combatWrapper, "BOTTOMRIGHT", -12, 0)

local combatTabContent = CreateFrame("Frame", nil, combatScrollFrame)
combatTabContent:SetWidth(310)
combatTabContent:SetHeight(354)  -- 8 + 80+6 + 114+6 + 80+6 + 54 = combat content height
combatScrollFrame:SetScrollChild(combatTabContent)

local bgUpdateThumb     = MakeThinScrollbar(bgWrapper,     bgScrollFrame,     bgTabContent,     SCROLL_VIEW_H)
local combatUpdateThumb = MakeThinScrollbar(combatWrapper, combatScrollFrame, combatTabContent, SCROLL_VIEW_H)

local function MakeSettingsTab(frameName, labelText, width)
    local f = CreateFrame("Button", frameName, settingsFrame)
    f:SetWidth(width)
    f:SetHeight(28)
    f:EnableMouse(true)

    local function SetTex(active)
        local tex = active
            and "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab"
            or  "Interface\\PaperDollInfoFrame\\UI-Character-InactiveTab"
        -- v0=0,v1=1: open side faces up so tab connects to the frame above it
        local v0, v1 = 0, 1
        f.L:SetTexture(tex); f.L:SetTexCoord(0,    0.25, v0, v1)
        f.R:SetTexture(tex); f.R:SetTexCoord(0.75, 1,    v0, v1)
        f.M:SetTexture(tex); f.M:SetTexCoord(0.25, 0.75, v0, v1)
    end

    local L = f:CreateTexture(nil, "BACKGROUND")
    L:SetWidth(16); L:SetPoint("LEFT", f, "LEFT", 0, 0)
    L:SetPoint("TOP", f, "TOP", 0, 0); L:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    f.L = L

    local R = f:CreateTexture(nil, "BACKGROUND")
    R:SetWidth(16); R:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    R:SetPoint("TOP", f, "TOP", 0, 0); R:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    f.R = R

    local M = f:CreateTexture(nil, "BACKGROUND")
    M:SetPoint("LEFT", L, "RIGHT", 0, 0); M:SetPoint("RIGHT", R, "LEFT", 0, 0)
    M:SetPoint("TOP", f, "TOP", 0, 0); M:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
    f.M = M

    local lbl = f:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    lbl:SetPoint("CENTER", f, "CENTER", 0, 2)
    lbl:SetText(labelText)
    f.lbl = lbl

    f.SetActive = function(self, active)
        SetTex(active)
        if active then
            self.lbl:SetTextColor(1, 0.82, 0)
        else
            self.lbl:SetTextColor(0.7, 0.7, 0.7)
        end
    end

    SetTex(false)
    return f
end

local function UpdateScrollMetrics()
    bgUpdateThumb()
    combatUpdateThumb()
end

-- tabCombat x = 10 (tabBG offsetX) + 110 (tabBG width) - 2 (overlap) = 118
local TAB_BG_X     = 10
local TAB_COMBAT_X = 118
local TAB_Y_ACTIVE   = 4   -- active tab rises to visually connect to the frame
local TAB_Y_INACTIVE = 4

local function UpdateSettingsTabs()
    if activeTab == "bg" then
        bgWrapper:Show()
        combatWrapper:Hide()
        TurtlePvPTabBG:SetActive(true)
        TurtlePvPTabCombat:SetActive(false)
        TurtlePvPTabBG:ClearAllPoints()
        TurtlePvPTabBG:SetPoint("TOPLEFT", settingsFrame, "BOTTOMLEFT", TAB_BG_X, TAB_Y_ACTIVE)
        TurtlePvPTabCombat:ClearAllPoints()
        TurtlePvPTabCombat:SetPoint("TOPLEFT", settingsFrame, "BOTTOMLEFT", TAB_COMBAT_X, TAB_Y_INACTIVE)
    else
        bgWrapper:Hide()
        combatWrapper:Show()
        TurtlePvPTabBG:SetActive(false)
        TurtlePvPTabCombat:SetActive(true)
        TurtlePvPTabBG:ClearAllPoints()
        TurtlePvPTabBG:SetPoint("TOPLEFT", settingsFrame, "BOTTOMLEFT", TAB_BG_X, TAB_Y_INACTIVE)
        TurtlePvPTabCombat:ClearAllPoints()
        TurtlePvPTabCombat:SetPoint("TOPLEFT", settingsFrame, "BOTTOMLEFT", TAB_COMBAT_X, TAB_Y_ACTIVE)
    end
end

-- Tab buttons (initial positions set by UpdateSettingsTabs on first call)
local tabBG = MakeSettingsTab("TurtlePvPTabBG", "Battlegrounds", 110)
tabBG:SetPoint("TOPLEFT", settingsFrame, "BOTTOMLEFT", TAB_BG_X, TAB_Y_ACTIVE)

local tabCombat = MakeSettingsTab("TurtlePvPTabCombat", "Utilities", 90)
tabCombat:SetPoint("TOPLEFT", settingsFrame, "BOTTOMLEFT", TAB_COMBAT_X, TAB_Y_INACTIVE)

tabBG:SetScript("OnClick", function()
    activeTab = "bg"
    UpdateSettingsTabs()
    HideAllPreviews()
end)
tabCombat:SetScript("OnClick", function()
    activeTab = "combat"
    UpdateSettingsTabs()
    HideAllPreviews()
end)

---------------------------------------------------------------------
-- BATTLEGROUNDS TAB — Build module settings dynamically
---------------------------------------------------------------------
local bgLastAnchor = bgTabContent
for i = 1, table.getn(TBGH.modules) do
    local mod = TBGH.modules[i]
    if mod.tab == "bg" and mod.buildSettings then
        bgLastAnchor = mod.buildSettings(bgTabContent, bgLastAnchor)
    end
end

--[[ BG Auto-Signup section — disabled until feature is ready
local autoSectionLabel = bgTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
autoSectionLabel:SetPoint("TOPLEFT", bgLastAnchor, "BOTTOMLEFT", -16, -14)
autoSectionLabel:SetText("|cffffd100BG Auto-Signup|r")

local autoEnableCheck = CreateFrame("CheckButton", "TurtlePvPAutoEnableCheck", bgTabContent, "UICheckButtonTemplate")
autoEnableCheck:SetWidth(24)
autoEnableCheck:SetHeight(24)
autoEnableCheck:SetPoint("TOPLEFT", autoSectionLabel, "BOTTOMLEFT", 0, -4)
local autoEnableLabel = bgTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
autoEnableLabel:SetPoint("LEFT", autoEnableCheck, "RIGHT", 2, 0)
autoEnableLabel:SetText("Auto-queue on login / every 30 sec (up to 3)")

local autoBGChecks = {}
local autoBGDefs = { {3,"Warsong Gulch"}, {4,"Arathi Basin"}, {5,"Alterac Valley"}, {6,"Sunnyglade Valley"} }
for i, def in ipairs(autoBGDefs) do
    local idx, label = def[1], def[2]
    local cb = CreateFrame("CheckButton", "TurtlePvPAutoBGCheck"..idx, bgTabContent, "UICheckButtonTemplate")
    cb:SetWidth(20)
    cb:SetHeight(20)
    local lbl = bgTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    lbl:SetText(label)
    cb._bgIdx = idx
    cb:SetScript("OnClick", function()
        local db = TBGH.db
        if not db.autoSignupBGs then db.autoSignupBGs = {} end
        local checked = this:GetChecked() and true or false
        if checked then
            local count = 0
            for _, v in pairs(db.autoSignupBGs) do if v then count = count + 1 end end
            if count >= 3 then
                this:SetChecked(false)
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvPEnhanced]|r You can queue for at most 3 battlegrounds.")
                return
            end
        end
        db.autoSignupBGs[idx] = checked or nil
    end)
    autoBGChecks[i] = cb
end
autoBGChecks[1]:SetPoint("TOPLEFT", autoEnableCheck, "BOTTOMLEFT", 16, -2)
for j = 2, table.getn(autoBGChecks) do
    autoBGChecks[j]:SetPoint("TOPLEFT", autoBGChecks[j-1], "BOTTOMLEFT", 0, 2)
end

autoEnableCheck:SetScript("OnClick", function()
    TBGH.db.autoSignup = this:GetChecked() and true or false
    if TBGH.autoSignupFrame then
        TBGH.autoSignupFrame._nextTry   = TBGH.db.autoSignup and (GetTime() + 3) or 0
        TBGH.autoSignupFrame._announced = false
    end
end)
--]]

---------------------------------------------------------------------
-- COMBAT TAB — Combat section
---------------------------------------------------------------------
local combatFrame = TBGH.CreateSectionFrame(combatTabContent, combatTabContent, "Combat", "Interface\\Icons\\ability_meleedamage")

local totemSkipCheck = CreateFrame("CheckButton", "TurtlePvPTotemSkipCheck", combatFrame, "UICheckButtonTemplate")
totemSkipCheck:SetWidth(24)
totemSkipCheck:SetHeight(24)
totemSkipCheck:SetPoint("TOPLEFT", combatFrame, "TOPLEFT", 18, -26)
local totemSkipLabel = combatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
totemSkipLabel:SetPoint("LEFT", totemSkipCheck, "RIGHT", 2, 0)
totemSkipLabel:SetText("Skip totems when Tab-targeting")

TBGH.AddTooltip(totemSkipCheck, "Skip Totems When Tab-Targeting",
    "Prevents Tab from selecting enemy Shaman totems, so you cycle through players instead.")

totemSkipCheck:SetScript("OnClick", function()
    TBGH.db.totemSkip = this:GetChecked() and true or false
end)

local autoReleaseCheck = CreateFrame("CheckButton", "TurtlePvPAutoReleaseCheck", combatFrame, "UICheckButtonTemplate")
autoReleaseCheck:SetWidth(24)
autoReleaseCheck:SetHeight(24)
autoReleaseCheck:SetPoint("TOPLEFT", totemSkipCheck, "BOTTOMLEFT", 0, 2)
local autoReleaseLabel = combatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
autoReleaseLabel:SetPoint("LEFT", autoReleaseCheck, "RIGHT", 2, 0)
autoReleaseLabel:SetText("Auto-release spirit on death (BGs only)")

TBGH.AddTooltip(autoReleaseCheck, "Auto-Release Spirit in Battlegrounds",
    "Automatically clicks Release Spirit when you die inside a BG, so you respawn faster without pressing a key.")

autoReleaseCheck:SetScript("OnClick", function()
    TBGH.db.autoRelease = this:GetChecked() and true or false
end)

combatFrame:SetHeight(80)

---------------------------------------------------------------------
-- COMBAT TAB — Gadgets section
---------------------------------------------------------------------
local gadgetFrame = TBGH.CreateSectionFrame(combatTabContent, combatFrame, "Gadgets", "Interface\\Icons\\trade_engineering")

local helmCheck = CreateFrame("CheckButton", "TurtlePvPHelmCheck", gadgetFrame, "UICheckButtonTemplate")
helmCheck:SetWidth(24)
helmCheck:SetHeight(24)
helmCheck:SetPoint("TOPLEFT", gadgetFrame, "TOPLEFT", 18, -26)
local helmCheckLabel = gadgetFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
helmCheckLabel:SetPoint("LEFT", helmCheck, "RIGHT", 2, 0)
helmCheckLabel:SetText("Auto-hide helmet on equip")

TBGH.AddTooltip(helmCheck, "Auto-Hide Helmet on Equip",
    "Hides your helmet visually when certain items (like Engineering goggles) are equipped. Tick the items below you want this applied to.")

local helmItemChecks = {}
local helmItemLabels = {}
for i = 1, table.getn(TBGH.HELM_AUTO_HIDE_ITEMS) do
    local entry = TBGH.HELM_AUTO_HIDE_ITEMS[i]
    local cb = CreateFrame("CheckButton", "TurtlePvPHelmItemCheck"..entry.id, gadgetFrame, "UICheckButtonTemplate")
    cb:SetWidth(20)
    cb:SetHeight(20)
    local lbl = gadgetFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    lbl:SetText(entry.name)
    cb._helmId = entry.id
    TBGH.AddTooltip(cb, entry.name, "Hide your helmet automatically whenever this item is equipped.")
    cb:SetScript("OnClick", function()
        local db = TBGH.db
        if not db.helmAutoHideItems then db.helmAutoHideItems = {} end
        db.helmAutoHideItems[this._helmId] = this:GetChecked() and true or false
        TBGH:CheckHelmetAutoHide()
    end)
    helmItemChecks[i] = cb
    helmItemLabels[i] = lbl
end
helmItemChecks[1]:SetPoint("TOPLEFT", helmCheck, "BOTTOMLEFT", 16, 0)
for j = 2, table.getn(helmItemChecks) do
    helmItemChecks[j]:SetPoint("TOPLEFT", helmItemChecks[j-1], "BOTTOMLEFT", 0, 2)
end

gadgetFrame:SetHeight(60 + table.getn(helmItemChecks) * 18)

---------------------------------------------------------------------
-- COMBAT TAB — Build module settings dynamically
---------------------------------------------------------------------
local combatLastAnchor = gadgetFrame
for i = 1, table.getn(TBGH.modules) do
    local mod = TBGH.modules[i]
    if mod.tab == "combat" and mod.buildSettings then
        combatLastAnchor = mod.buildSettings(combatTabContent, combatLastAnchor)
    end
end

local function SyncHelmSubChecks(enabled)
    for i = 1, table.getn(helmItemChecks) do
        if enabled then
            helmItemChecks[i]:Enable()
            helmItemLabels[i]:SetTextColor(1, 1, 1)
        else
            helmItemChecks[i]:Disable()
            helmItemLabels[i]:SetTextColor(0.5, 0.5, 0.5)
        end
    end
end

helmCheck:SetScript("OnClick", function()
    local checked = this:GetChecked() and true or false
    TBGH.db.helmAutoHide = checked
    SyncHelmSubChecks(checked)
    TBGH:CheckHelmetAutoHide()
end)

---------------------------------------------------------------------
-- BATTLEGROUNDS TAB — Info text
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Credit line
---------------------------------------------------------------------
local creditLine = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
creditLine:SetTextColor(0.6, 0.6, 0.6, 1)
creditLine:SetText("For all my PvP friends")

local creditAlliIcon = settingsFrame:CreateTexture(nil, "OVERLAY")
creditAlliIcon:SetWidth(14)
creditAlliIcon:SetHeight(14)
creditAlliIcon:SetTexture("Interface\\WorldStateFrame\\AllianceIcon")

local creditPriestIcon = settingsFrame:CreateTexture(nil, "OVERLAY")
creditPriestIcon:SetWidth(14)
creditPriestIcon:SetHeight(14)
creditPriestIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
creditPriestIcon:SetTexCoord(0.5, 0.75, 0.25, 0.5)

local creditText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
creditText:SetTextColor(1, 1, 1, 1)
creditText:SetText("Citrin (Tel'Abim)")

creditLine:SetPoint("BOTTOM", settingsFrame, "BOTTOM", -70, 16)
creditAlliIcon:SetPoint("LEFT", creditLine, "RIGHT", 3, 0)
creditPriestIcon:SetPoint("LEFT", creditAlliIcon, "RIGHT", 2, 0)
creditText:SetPoint("LEFT", creditPriestIcon, "RIGHT", 3, 0)

---------------------------------------------------------------------
-- OnShow / OnHide
---------------------------------------------------------------------
settingsFrame:SetScript("OnShow", function()
    local db = TBGH.db
    -- Sync module checkboxes
    for i = 1, table.getn(TBGH.modules) do
        local mod = TBGH.modules[i]
        if mod.syncSettings then mod.syncSettings() end
    end
    -- Combat module
    totemSkipCheck:SetChecked(db.totemSkip ~= false)
    autoReleaseCheck:SetChecked(db.autoRelease == true)
    -- Helm auto-hide
    local helmEnabled = db.helmAutoHide == true
    helmCheck:SetChecked(helmEnabled)
    for i = 1, table.getn(helmItemChecks) do
        local itemId = helmItemChecks[i]._helmId
        local itemOn = not db.helmAutoHideItems or db.helmAutoHideItems[itemId] ~= false
        helmItemChecks[i]:SetChecked(itemOn)
    end
    SyncHelmSubChecks(helmEnabled)
    -- Reset scroll positions to top and refresh thumb positions
    bgScrollFrame:SetVerticalScroll(0)
    combatScrollFrame:SetVerticalScroll(0)
    UpdateScrollMetrics()
    UpdateSettingsTabs()
    TBGH.previewSection = nil
end)

settingsFrame:SetScript("OnHide", function()
    HideAllPreviews()
    -- Notify modules to restore real state
    for i = 1, table.getn(TBGH.modules) do
        local mod = TBGH.modules[i]
        if mod.onSettingsHide then mod.onSettingsHide() end
    end
end)

-- Initialize tab visuals
UpdateSettingsTabs()
