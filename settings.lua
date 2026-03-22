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
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
settingsFrame:Hide()

-- Title
local settingsTitle = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
settingsTitle:SetPoint("TOP", settingsFrame, "TOP", 0, -16)
settingsTitle:SetText("TurtlePvP")

-- Close button
local closeBtn = CreateFrame("Button", "TurtlePvPSettingsClose", settingsFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", settingsFrame, "TOPRIGHT", -4, -4)

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

local bgTabContent = CreateFrame("Frame", nil, settingsFrame)
bgTabContent:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 12, -40)
bgTabContent:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -12, 46)

local combatTabContent = CreateFrame("Frame", nil, settingsFrame)
combatTabContent:SetPoint("TOPLEFT", settingsFrame, "TOPLEFT", 12, -40)
combatTabContent:SetPoint("BOTTOMRIGHT", settingsFrame, "BOTTOMRIGHT", -12, 46)
combatTabContent:Hide()

local function StyleTab(tab, selected)
    if selected then
        tab:SetTextColor(1, 0.82, 0)
        tab:SetBackdropColor(0.2, 0.2, 0.2, 1)
        tab:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        tab:SetHeight(28)
    else
        tab:SetTextColor(0.6, 0.6, 0.6)
        tab:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        tab:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        tab:SetHeight(24)
    end
end

local function UpdateSettingsTabs()
    if activeTab == "bg" then
        bgTabContent:Show()
        combatTabContent:Hide()
        StyleTab(TurtlePvPTabBG, true)
        StyleTab(TurtlePvPTabCombat, false)
    else
        bgTabContent:Hide()
        combatTabContent:Show()
        StyleTab(TurtlePvPTabBG, false)
        StyleTab(TurtlePvPTabCombat, true)
    end
end

-- Tab buttons
local tabBG = CreateFrame("Button", "TurtlePvPTabBG", settingsFrame)
tabBG:SetWidth(100)
tabBG:SetHeight(28)
tabBG:SetPoint("TOPLEFT", settingsFrame, "BOTTOMLEFT", 12, 2)
tabBG:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = {left = 2, right = 2, top = 2, bottom = 2}})
local tabBGText = tabBG:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tabBGText:SetPoint("CENTER", tabBG, "CENTER", 0, 0)
tabBGText:SetText("Battlegrounds")
tabBG.SetTextColor = function(self, r, g, b) tabBGText:SetTextColor(r, g, b) end

local tabCombat = CreateFrame("Button", "TurtlePvPTabCombat", settingsFrame)
tabCombat:SetWidth(80)
tabCombat:SetHeight(24)
tabCombat:SetPoint("LEFT", tabBG, "RIGHT", -2, 0)
tabCombat:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = {left = 2, right = 2, top = 2, bottom = 2}})
local tabCombatText = tabCombat:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tabCombatText:SetPoint("CENTER", tabCombat, "CENTER", 0, 0)
tabCombatText:SetText("Utilities")
tabCombat.SetTextColor = function(self, r, g, b) tabCombatText:SetTextColor(r, g, b) end

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

StyleTab(tabBG, true)
StyleTab(tabCombat, false)

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
                DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvP]|r You can queue for at most 3 battlegrounds.")
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
local combatSectionLabel = combatTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
combatSectionLabel:SetPoint("TOPLEFT", combatTabContent, "TOPLEFT", 8, -8)
combatSectionLabel:SetText("|cffffd100Combat|r")

local totemSkipCheck = CreateFrame("CheckButton", "TurtlePvPTotemSkipCheck", combatTabContent, "UICheckButtonTemplate")
totemSkipCheck:SetWidth(24)
totemSkipCheck:SetHeight(24)
totemSkipCheck:SetPoint("TOPLEFT", combatSectionLabel, "BOTTOMLEFT", 0, -4)
local totemSkipLabel = combatTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
totemSkipLabel:SetPoint("LEFT", totemSkipCheck, "RIGHT", 2, 0)
totemSkipLabel:SetText("Skip totems when Tab-targeting")

totemSkipCheck:SetScript("OnClick", function()
    TBGH.db.totemSkip = this:GetChecked() and true or false
end)

local autoReleaseCheck = CreateFrame("CheckButton", "TurtlePvPAutoReleaseCheck", combatTabContent, "UICheckButtonTemplate")
autoReleaseCheck:SetWidth(24)
autoReleaseCheck:SetHeight(24)
autoReleaseCheck:SetPoint("TOPLEFT", totemSkipCheck, "BOTTOMLEFT", 0, 2)
local autoReleaseLabel = combatTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
autoReleaseLabel:SetPoint("LEFT", autoReleaseCheck, "RIGHT", 2, 0)
autoReleaseLabel:SetText("Auto-release spirit on death (BGs only)")

autoReleaseCheck:SetScript("OnClick", function()
    TBGH.db.autoRelease = this:GetChecked() and true or false
end)

---------------------------------------------------------------------
-- COMBAT TAB — Gadgets section
---------------------------------------------------------------------
local gadgetsSectionLabel = combatTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gadgetsSectionLabel:SetPoint("TOPLEFT", autoReleaseCheck, "BOTTOMLEFT", 0, -10)
gadgetsSectionLabel:SetText("|cffffd100Gadgets|r")

local helmCheck = CreateFrame("CheckButton", "TurtlePvPHelmCheck", combatTabContent, "UICheckButtonTemplate")
helmCheck:SetWidth(24)
helmCheck:SetHeight(24)
helmCheck:SetPoint("TOPLEFT", gadgetsSectionLabel, "BOTTOMLEFT", 0, -4)
local helmCheckLabel = combatTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
helmCheckLabel:SetPoint("LEFT", helmCheck, "RIGHT", 2, 0)
helmCheckLabel:SetText("Auto-hide helmet on equip")

local helmItemChecks = {}
local helmItemLabels = {}
for i = 1, table.getn(TBGH.HELM_AUTO_HIDE_ITEMS) do
    local entry = TBGH.HELM_AUTO_HIDE_ITEMS[i]
    local cb = CreateFrame("CheckButton", "TurtlePvPHelmItemCheck"..entry.id, combatTabContent, "UICheckButtonTemplate")
    cb:SetWidth(20)
    cb:SetHeight(20)
    local lbl = combatTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    lbl:SetText(entry.name)
    cb._helmId = entry.id
    cb:SetScript("OnClick", function()
        local db = TBGH.db
        if not db.helmAutoHideItems then db.helmAutoHideItems = {} end
        db.helmAutoHideItems[this._helmId] = this:GetChecked() and true or false
        TBGH:CheckHelmetAutoHide()
    end)
    helmItemChecks[i] = cb
    helmItemLabels[i] = lbl
end
helmItemChecks[1]:SetPoint("TOPLEFT", helmCheck, "BOTTOMLEFT", 16, -2)
for j = 2, table.getn(helmItemChecks) do
    helmItemChecks[j]:SetPoint("TOPLEFT", helmItemChecks[j-1], "BOTTOMLEFT", 0, 2)
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
local settingsInfo = bgTabContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
settingsInfo:SetPoint("TOPLEFT", bgLastAnchor, "BOTTOMLEFT", -16, -14)
settingsInfo:SetTextColor(0.7, 0.7, 0.7, 1)
settingsInfo:SetText("Click Preview, then drag to reposition.\nEach module has its own saved position.")

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
