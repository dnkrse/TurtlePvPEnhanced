-- TurtlePvP: minimap.lua — Minimap button

local minimapBtn = CreateFrame("Button", "TurtlePvPMinimapBtn", Minimap)
minimapBtn:SetWidth(31)
minimapBtn:SetHeight(31)
minimapBtn:SetFrameStrata("MEDIUM")
minimapBtn:SetFrameLevel(8)
minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapBtn:SetMovable(true)
minimapBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapBtn:RegisterForDrag("LeftButton")

local minimapBtnIcon = minimapBtn:CreateTexture(nil, "BACKGROUND")
minimapBtnIcon:SetWidth(20)
minimapBtnIcon:SetHeight(20)
minimapBtnIcon:SetPoint("CENTER", minimapBtn, "CENTER", 0, 0)
minimapBtnIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local function UpdateMinimapBtnIcon()
    local faction = UnitFactionGroup("player")
    if faction == "Horde" then
        minimapBtnIcon:SetTexture("Interface\\Icons\\INV_BannerPVP_01")
    else
        minimapBtnIcon:SetTexture("Interface\\Icons\\INV_BannerPVP_02")
    end
end
UpdateMinimapBtnIcon()

minimapBtn:RegisterEvent("PLAYER_ENTERING_WORLD")
minimapBtn:SetScript("OnEvent", UpdateMinimapBtnIcon)

local minimapBtnBorder = minimapBtn:CreateTexture(nil, "OVERLAY")
minimapBtnBorder:SetWidth(53)
minimapBtnBorder:SetHeight(53)
minimapBtnBorder:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 0, 0)
minimapBtnBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- Position function (stored on TBGH for cross-file access)
TBGH.UpdateMinimapBtnPos = function(angle)
    local rads = math.rad(angle or 225)
    local x = 80 * math.cos(rads)
    local y = 80 * math.sin(rads)
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local minimapDragging = false
minimapBtn:SetScript("OnDragStart", function()
    minimapDragging = true
end)
minimapBtn:SetScript("OnDragStop", function()
    minimapDragging = false
end)
minimapBtn:SetScript("OnUpdate", function()
    if not minimapDragging then return end
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(math.atan2(cy - my, cx - mx))
    TBGH.db.minimapAngle = angle
    TBGH.UpdateMinimapBtnPos(angle)
end)
minimapBtn:SetScript("OnClick", function()
    if arg1 == "LeftButton" then
        if TurtlePvPSettingsFrame:IsShown() then
            TurtlePvPSettingsFrame:Hide()
        else
            TurtlePvPSettingsFrame:Show()
        end
    end
end)
minimapBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("TurtlePvP", 1, 1, 1)
    GameTooltip:AddLine("Left-click: Open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: Move button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Apply saved position
TBGH.UpdateMinimapBtnPos(TBGH.db.minimapAngle or 225)
