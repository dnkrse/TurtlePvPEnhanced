-- TurtlePvP: wsg.lua — Warsong Gulch flag carrier overlay + detection

local container = TBGH.container

---------------------------------------------------------------------
-- Hidden tooltip for buff name verification
---------------------------------------------------------------------
local flagScanTooltip = CreateFrame("GameTooltip", "TurtlePvPFlagScanTooltip", nil, "GameTooltipTemplate")

---------------------------------------------------------------------
-- WSG: Stacked flag carrier overlay
---------------------------------------------------------------------
local WSG_ICON_SIZE = 16
local WSG_ROW_HEIGHT = 18
TBGH.WSG_ICON_SIZE = WSG_ICON_SIZE
TBGH.WSG_ROW_HEIGHT = WSG_ROW_HEIGHT

local wsgFrame = CreateFrame("Frame", "TurtlePvPWSGFrame", container)
wsgFrame:SetWidth(200)
wsgFrame:SetHeight(WSG_ROW_HEIGHT * 2 + 4)
wsgFrame:SetPoint("LEFT", container, "LEFT", 4, 0)
wsgFrame:SetFrameStrata("HIGH")
wsgFrame:Hide()
TBGH.wsgFrame = wsgFrame

-- Row 1: Alliance
local wsgAlliFrame = CreateFrame("Button", "TurtlePvPWSGAlli", wsgFrame)
wsgAlliFrame:SetWidth(200)
wsgAlliFrame:SetHeight(WSG_ROW_HEIGHT)
wsgAlliFrame:SetPoint("TOPLEFT", wsgFrame, "TOPLEFT", 0, -2)
wsgAlliFrame:SetFrameStrata("HIGH")
wsgAlliFrame:EnableMouse(true)
wsgAlliFrame:RegisterForDrag("LeftButton")

local wsgAlliIcon = wsgAlliFrame:CreateTexture(nil, "OVERLAY")
wsgAlliIcon:SetWidth(WSG_ICON_SIZE)
wsgAlliIcon:SetHeight(WSG_ICON_SIZE)
wsgAlliIcon:SetPoint("LEFT", wsgAlliFrame, "LEFT", 0, 0)
wsgAlliIcon:SetTexture("Interface\\WorldStateFrame\\AllianceIcon")

local wsgAlliClassIcon = wsgAlliFrame:CreateTexture(nil, "OVERLAY")
wsgAlliClassIcon:SetWidth(WSG_ICON_SIZE)
wsgAlliClassIcon:SetHeight(WSG_ICON_SIZE)
wsgAlliClassIcon:SetPoint("LEFT", wsgAlliIcon, "RIGHT", 2, 0)
wsgAlliClassIcon:SetTexture(TBGH.CLASS_ICONS)
wsgAlliClassIcon:Hide()
TBGH.wsgAlliClassIcon = wsgAlliClassIcon

local wsgAlliText = wsgAlliFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
wsgAlliText:SetPoint("LEFT", wsgAlliClassIcon, "RIGHT", 4, -1)
wsgAlliText:SetTextColor(1, 1, 0, 1)
wsgAlliText:SetText("")
TBGH.wsgAlliText = wsgAlliText

local wsgAlliHP = wsgAlliFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsgAlliHP:SetPoint("LEFT", wsgAlliText, "RIGHT", 4, 0)
wsgAlliHP:SetText("")
TBGH.wsgAlliHP = wsgAlliHP

local wsgAlliDist = wsgAlliFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsgAlliDist:SetPoint("LEFT", wsgAlliHP, "RIGHT", 4, 0)
wsgAlliDist:SetText("")
TBGH.wsgAlliDist = wsgAlliDist

wsgAlliFrame:SetScript("OnClick", function()
    local name = TBGH.wsg.hordeCarrier
    if not name then return end
    TargetByName(name, true)
    if IsControlKeyDown() and UnitFactionGroup("player") ~= "Alliance" then
        local seenAt = TBGH.wsg.efcManualSeenAt
        if TBGH.db.wsgDedup ~= false and seenAt and (GetTime() - seenAt) < 10 then return end
        local pct = TBGH:GetHealthPct(name)
        if pct then
            local cc = TBGH:GetClassColorByName(name)
            local cOpen = cc and ("|c" .. cc) or "|cffffd100"
            SendChatMessage("EFC: " .. cOpen .. name .. "|r - " .. pct .. "% Health", "BATTLEGROUND")
        end
    end
end)
wsgAlliFrame:SetScript("OnDragStart", function()
    if IsShiftKeyDown() or (TurtlePvPSettingsFrame and TurtlePvPSettingsFrame:IsShown()) then
        container:StartMoving()
    end
end)
wsgAlliFrame:SetScript("OnDragStop", function()
    container:StopMovingOrSizing()
    TBGH.SaveContainerPos()
end)

-- Row 2: Horde
local wsgHordeFrame = CreateFrame("Button", "TurtlePvPWSGHorde", wsgFrame)
wsgHordeFrame:SetWidth(200)
wsgHordeFrame:SetHeight(WSG_ROW_HEIGHT)
wsgHordeFrame:SetPoint("TOPLEFT", wsgAlliFrame, "BOTTOMLEFT", 0, -2)
wsgHordeFrame:SetFrameStrata("HIGH")
wsgHordeFrame:EnableMouse(true)
wsgHordeFrame:RegisterForDrag("LeftButton")

local wsgHordeIcon = wsgHordeFrame:CreateTexture(nil, "OVERLAY")
wsgHordeIcon:SetWidth(WSG_ICON_SIZE)
wsgHordeIcon:SetHeight(WSG_ICON_SIZE)
wsgHordeIcon:SetPoint("LEFT", wsgHordeFrame, "LEFT", 0, 0)
wsgHordeIcon:SetTexture("Interface\\WorldStateFrame\\HordeIcon")

local wsgHordeClassIcon = wsgHordeFrame:CreateTexture(nil, "OVERLAY")
wsgHordeClassIcon:SetWidth(WSG_ICON_SIZE)
wsgHordeClassIcon:SetHeight(WSG_ICON_SIZE)
wsgHordeClassIcon:SetPoint("LEFT", wsgHordeIcon, "RIGHT", 2, 0)
wsgHordeClassIcon:SetTexture(TBGH.CLASS_ICONS)
wsgHordeClassIcon:Hide()
TBGH.wsgHordeClassIcon = wsgHordeClassIcon

local wsgHordeText = wsgHordeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
wsgHordeText:SetPoint("LEFT", wsgHordeClassIcon, "RIGHT", 4, -1)
wsgHordeText:SetTextColor(1, 1, 0, 1)
wsgHordeText:SetText("")
TBGH.wsgHordeText = wsgHordeText

local wsgHordeHP = wsgHordeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsgHordeHP:SetPoint("LEFT", wsgHordeText, "RIGHT", 4, 0)
wsgHordeHP:SetText("")
TBGH.wsgHordeHP = wsgHordeHP

local wsgHordeDist = wsgHordeFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsgHordeDist:SetPoint("LEFT", wsgHordeHP, "RIGHT", 4, 0)
wsgHordeDist:SetText("")
TBGH.wsgHordeDist = wsgHordeDist

-- Focused Assault text
local wsgFocusedText = wsgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsgFocusedText:SetPoint("RIGHT", wsgFrame, "RIGHT", -2, 0)
wsgFocusedText:SetJustifyH("RIGHT")
wsgFocusedText:SetTextColor(1, 0.4, 0.4, 1)
wsgFocusedText:SetText("")
TBGH.wsgFocusedText = wsgFocusedText

local FOCUSED_ASSAULT_TEX = "Interface\\Icons\\Ability_Warrior_EndlessRage"

function TBGH:GetFocusedAssaultStacks()
    local carriers = { self.wsg.alliCarrier, self.wsg.hordeCarrier }
    for _, name in ipairs(carriers) do
        if name then
            local unit = self:GetUnitByName(name)
            if unit then
                for d = 1, 32 do
                    local tex, count = UnitDebuff(unit, d)
                    if not tex then break end
                    if tex == FOCUSED_ASSAULT_TEX then
                        return (count and count > 0) and count or 1
                    end
                end
            end
        end
    end
    return 0
end

wsgHordeFrame:SetScript("OnClick", function()
    local name = TBGH.wsg.alliCarrier
    if not name then return end
    TargetByName(name, true)
    if IsControlKeyDown() and UnitFactionGroup("player") ~= "Horde" then
        local seenAt = TBGH.wsg.efcManualSeenAt
        if TBGH.db.wsgDedup ~= false and seenAt and (GetTime() - seenAt) < 10 then return end
        local pct = TBGH:GetHealthPct(name)
        if pct then
            local cc = TBGH:GetClassColorByName(name)
            local cOpen = cc and ("|c" .. cc) or "|cffffd100"
            SendChatMessage("EFC: " .. cOpen .. name .. "|r - " .. pct .. "% Health", "BATTLEGROUND")
        end
    end
end)
wsgHordeFrame:SetScript("OnDragStart", function()
    if IsShiftKeyDown() or (TurtlePvPSettingsFrame and TurtlePvPSettingsFrame:IsShown()) then
        container:StartMoving()
    end
end)
wsgHordeFrame:SetScript("OnDragStop", function()
    container:StopMovingOrSizing()
    TBGH.SaveContainerPos()
end)

---------------------------------------------------------------------
-- WSG: Flag message parsing
---------------------------------------------------------------------
local WSG_PATTERNS = {
    { pattern = "The Alliance [Ff]lag was picked up by (.+)!",     side = "alliance", action = "pickup" },
    { pattern = "The Horde [Ff]lag was picked up by (.+)!",        side = "horde",    action = "pickup" },
    { pattern = "(.+) has picked up the Alliance [Ff]lag!",        side = "alliance", action = "pickup" },
    { pattern = "(.+) has picked up the Horde [Ff]lag!",           side = "horde",    action = "pickup" },
    { pattern = "(.+) picked up the Alliance [Ff]lag!",            side = "alliance", action = "pickup" },
    { pattern = "(.+) picked up the Horde [Ff]lag!",               side = "horde",    action = "pickup" },
    { pattern = "The Alliance [Ff]lag was dropped",                 side = "alliance", action = "drop" },
    { pattern = "The Horde [Ff]lag was dropped",                    side = "horde",    action = "drop" },
    { pattern = "The Alliance [Ff]lag was returned to its base by (.+)!", side = "alliance", action = "return" },
    { pattern = "The Horde [Ff]lag was returned to its base by (.+)!",   side = "horde",    action = "return" },
    { pattern = "The Alliance [Ff]lag was returned",                side = "alliance", action = "return" },
    { pattern = "The Horde [Ff]lag was returned",                   side = "horde",    action = "return" },
    { pattern = "The Alliance [Ff]lag was captured by (.+)!",       side = "alliance", action = "capture" },
    { pattern = "The Horde [Ff]lag was captured by (.+)!",          side = "horde",    action = "capture" },
    { pattern = "(.+) captured the Alliance [Ff]lag!",              side = "alliance", action = "capture" },
    { pattern = "(.+) captured the Horde [Ff]lag!",                 side = "horde",    action = "capture" },
    { pattern = "(.+) has captured the Alliance [Ff]lag!",          side = "alliance", action = "capture" },
    { pattern = "(.+) has captured the Horde [Ff]lag!",             side = "horde",    action = "capture" },
}

local function sideFromEvent(ev)
    if ev == "CHAT_MSG_BG_SYSTEM_ALLIANCE" then return "alliance" end
    if ev == "CHAT_MSG_BG_SYSTEM_HORDE" then return "horde" end
    return nil
end

function TBGH:ParseWSGMessage(text, ev)
    if not text then return end
    for _, p in ipairs(WSG_PATTERNS) do
        local _, _, name = string.find(text, p.pattern)
        if string.find(text, p.pattern) then
            if p.action == "pickup" then
                if p.side == "alliance" then
                    self.wsg.alliCarrier = name or "Unknown"
                    self.wsg.alliCarrierLastThreshold = nil
                else
                    self.wsg.hordeCarrier = name or "Unknown"
                    self.wsg.hordeCarrierLastThreshold = nil
                end
            elseif p.action == "drop" or p.action == "return" or p.action == "capture" then
                if p.side == "alliance" then
                    self.wsg.alliCarrier = nil
                    self.wsg.alliCarrierLastThreshold = nil
                else
                    self.wsg.hordeCarrier = nil
                    self.wsg.hordeCarrierLastThreshold = nil
                end
            end
            self:UpdateWSGOverlay()
            return
        end
    end
    local side = sideFromEvent(ev)
    if not side then return end
    local _, _, name = string.find(text, "picked up by (.+)!")
    if not name then _, _, name = string.find(text, "(.+) picked up") end
    if name then
        if side == "alliance" then
            self.wsg.alliCarrier = name
            self.wsg.alliCarrierLastThreshold = nil
        else
            self.wsg.hordeCarrier = name
            self.wsg.hordeCarrierLastThreshold = nil
        end
        self:UpdateWSGOverlay()
        return
    end
    if string.find(text, "dropped") or string.find(text, "returned") or string.find(text, "captured") then
        if side == "alliance" then
            self.wsg.alliCarrier = nil
            self.wsg.alliCarrierLastThreshold = nil
        else
            self.wsg.hordeCarrier = nil
            self.wsg.hordeCarrierLastThreshold = nil
        end
        self:UpdateWSGOverlay()
    end
end

---------------------------------------------------------------------
-- WSG: Update overlay display
---------------------------------------------------------------------
function TBGH:UpdateWSGOverlay()
    local db = self.db
    local bgType = TBGH_GetBGType()
    if bgType ~= "wsg" or db.wsgEnabled == false then
        wsgFrame:Hide()
        local overlay = self.overlay
        if not overlay or not overlay:IsShown() then container:Hide() end
        return
    end
    local ac = self.wsg.alliCarrier
    local hc = self.wsg.hordeCarrier
    local CLASS_ICONS = self.CLASS_ICONS
    local CLASS_TCOORDS = self.CLASS_TCOORDS
    if hc then
        local cc = self:GetClassColorByName(hc) or "ff3399ff"
        wsgAlliText:SetText("|c" .. cc .. hc .. "|r")
        local engClass = self:GetClassByName(hc)
        if engClass and CLASS_TCOORDS[engClass] then
            local tc = CLASS_TCOORDS[engClass]
            wsgAlliClassIcon:SetTexture(CLASS_ICONS)
            wsgAlliClassIcon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        else
            wsgAlliClassIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            wsgAlliClassIcon:SetTexCoord(0, 1, 0, 1)
        end
        wsgAlliClassIcon:SetAlpha(1)
        wsgAlliClassIcon:Show()
        local pct = self:GetHealthPct(hc)
        if pct then
            local r, g = 1, 1
            if pct > 50 then r = (100 - pct) / 50 else g = pct / 50 end
            wsgAlliHP:SetTextColor(r, g, 0, 1)
            wsgAlliHP:SetText(pct .. "%")
        else
            wsgAlliHP:SetText("")
        end
        local dist = self:GetDistance(hc)
        if dist then
            if dist <= 20 then
                wsgAlliDist:SetTextColor(1, 0, 0, 1)
            elseif dist <= 40 then
                wsgAlliDist:SetTextColor(1, 1, 0, 1)
            else
                wsgAlliDist:SetTextColor(1, 1, 1, 1)
            end
            wsgAlliDist:SetText(dist .. "yd")
        else
            wsgAlliDist:SetText("")
        end
    else
        wsgAlliText:SetText("")
        wsgAlliHP:SetText("")
        wsgAlliDist:SetText("")
        wsgAlliClassIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        wsgAlliClassIcon:SetTexCoord(0, 1, 0, 1)
        wsgAlliClassIcon:SetAlpha(0.3)
        wsgAlliClassIcon:Show()
    end
    if ac then
        local cc = self:GetClassColorByName(ac) or "ffff3333"
        wsgHordeText:SetText("|c" .. cc .. ac .. "|r")
        local engClass = self:GetClassByName(ac)
        if engClass and CLASS_TCOORDS[engClass] then
            local tc = CLASS_TCOORDS[engClass]
            wsgHordeClassIcon:SetTexture(CLASS_ICONS)
            wsgHordeClassIcon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        else
            wsgHordeClassIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            wsgHordeClassIcon:SetTexCoord(0, 1, 0, 1)
        end
        wsgHordeClassIcon:SetAlpha(1)
        wsgHordeClassIcon:Show()
        local pct = self:GetHealthPct(ac)
        if pct then
            local r, g = 1, 1
            if pct > 50 then r = (100 - pct) / 50 else g = pct / 50 end
            wsgHordeHP:SetTextColor(r, g, 0, 1)
            wsgHordeHP:SetText(pct .. "%")
        else
            wsgHordeHP:SetText("")
        end
        local dist = self:GetDistance(ac)
        if dist then
            if dist <= 20 then
                wsgHordeDist:SetTextColor(1, 0, 0, 1)
            elseif dist <= 40 then
                wsgHordeDist:SetTextColor(1, 1, 0, 1)
            else
                wsgHordeDist:SetTextColor(1, 1, 1, 1)
            end
            wsgHordeDist:SetText(dist .. "yd")
        else
            wsgHordeDist:SetText("")
        end
    else
        wsgHordeText:SetText("")
        wsgHordeHP:SetText("")
        wsgHordeDist:SetText("")
        wsgHordeClassIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        wsgHordeClassIcon:SetTexCoord(0, 1, 0, 1)
        wsgHordeClassIcon:SetAlpha(0.3)
        wsgHordeClassIcon:Show()
    end
    if self.containerActiveBG ~= "wsg" then
        self.containerActiveBG = "wsg"
        TBGH.ApplyContainerPos(db.wsgPos or self.DEFAULT_WSG_POS)
    end
    local stacks = self:GetFocusedAssaultStacks()
    if stacks > 0 then
        wsgFocusedText:SetText("|cffff6666" .. (stacks * 10) .. "% Assault|r")
    else
        wsgFocusedText:SetText("")
    end
    wsgFrame:Show()
    container:Show()
    self:ResizeContainer()
    self:CheckEFCHealthThresholds()
end

---------------------------------------------------------------------
-- EFC health threshold auto-announce
---------------------------------------------------------------------
function TBGH:CheckEFCHealthThresholds()
    local db = self.db
    if db.wsgAutoAnnounce == false then return end
    local faction = UnitFactionGroup("player")
    if not faction then return end
    local efcName, efcSide
    if faction == "Alliance" then
        efcName = self.wsg.alliCarrier
        efcSide = "alli"
    else
        efcName = self.wsg.hordeCarrier
        efcSide = "horde"
    end
    if not efcName then
        if efcSide == "alli" then
            self.wsg.alliCarrierLastThreshold = nil
        else
            self.wsg.hordeCarrierLastThreshold = nil
        end
        return
    end
    local pct = self:GetHealthPct(efcName)
    if not pct then return end
    local lastThreshold = efcSide == "alli" and self.wsg.alliCarrierLastThreshold or self.wsg.hordeCarrierLastThreshold
    local newThreshold = nil
    if pct <= 25 and lastThreshold ~= 25 then
        newThreshold = 25
    elseif pct <= 50 and pct > 25 and lastThreshold ~= 50 and lastThreshold ~= 25 then
        newThreshold = 50
    elseif pct <= 75 and pct > 50 and lastThreshold ~= 75 and lastThreshold ~= 50 and lastThreshold ~= 25 then
        newThreshold = 75
    end
    if newThreshold then
        -- Skip if another addon user already announced this threshold recently
        if db.wsgDedup ~= false then
            local seenAt = self.wsg.efcAnnounceSeenAt[newThreshold]
            if seenAt and (GetTime() - seenAt) < 10 then
                if efcSide == "alli" then
                    self.wsg.alliCarrierLastThreshold = newThreshold
                else
                    self.wsg.hordeCarrierLastThreshold = newThreshold
                end
                return
            end
        end
        if efcSide == "alli" then
            self.wsg.alliCarrierLastThreshold = newThreshold
        else
            self.wsg.hordeCarrierLastThreshold = newThreshold
        end
        local cc = self:GetClassColorByName(efcName)
        local cOpen = cc and ("|c" .. cc) or "|cffffd100"
        local prefix = newThreshold == 25 and "EFC LOW:" or ("EFC " .. newThreshold .. "%:")
        local msg = prefix .. " " .. cOpen .. efcName .. "|r"
        SendChatMessage(msg, "BATTLEGROUND")
    end
end

---------------------------------------------------------------------
-- WSG: Announce
---------------------------------------------------------------------
function TBGH:AnnounceWSG()
    local ac = self.wsg.alliCarrier
    local hc = self.wsg.hordeCarrier
    if not ac and not hc then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvP]|r No flag carriers to announce.")
        return
    end
    local parts = {}
    if hc then
        table.insert(parts, "Alliance Flagcarrier: " .. hc)
    end
    if ac then
        table.insert(parts, "Horde Flagcarrier: " .. ac)
    end
    SendChatMessage(table.concat(parts, " - "), "BATTLEGROUND")
end

---------------------------------------------------------------------
-- WSG: Reset
---------------------------------------------------------------------
function TBGH:ResetWSG()
    self.wsg.alliCarrier = nil
    self.wsg.hordeCarrier = nil
    self.wsg.alliCarrierLastThreshold = nil
    self.wsg.hordeCarrierLastThreshold = nil
    self.wsg.efcAnnounceSeenAt = {}
    self.wsg.efcManualSeenAt = nil
    self.classCache = {}
    self.guidTracker.nameToGuid = {}
    self.guidTracker.guidToName = {}
    wsgFocusedText:SetText("")
    self:UpdateWSGOverlay()
end

---------------------------------------------------------------------
-- WSG: Flag buff scanning
---------------------------------------------------------------------
local FLAG_BUFF_CANDIDATES = {
    ["Interface\\Icons\\INV_BannerPVP_02"] = true,
    ["Interface\\Icons\\INV_BannerPVP_01"] = true,
}

local function VerifyFlagBuff(unit, buffIndex)
    flagScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    flagScanTooltip:ClearLines()
    flagScanTooltip:SetUnitBuff(unit, buffIndex)
    local buffName = TurtlePvPFlagScanTooltipTextLeft1 and TurtlePvPFlagScanTooltipTextLeft1:GetText()
    if not buffName then return nil end
    buffName = string.lower(buffName)
    if string.find(buffName, "silverwing flag") then return "alliance" end
    if string.find(buffName, "warsong flag") then return "horde" end
    return nil
end

function TBGH.ScanUnitForFlags(unit, foundAlliCarrier, foundHordeCarrier)
    if not UnitExists(unit) then return foundAlliCarrier, foundHordeCarrier end
    local name = UnitName(unit)
    TBGH:HarvestGUID(unit)
    local isHostile = UnitIsEnemy("player", unit)
    for b = 1, 32 do
        local tex = UnitBuff(unit, b)
        if not tex then break end
        if FLAG_BUFF_CANDIDATES[tex] then
            local side
            if isHostile then
                if tex == "Interface\\Icons\\INV_BannerPVP_02" then
                    side = "alliance"
                elseif tex == "Interface\\Icons\\INV_BannerPVP_01" then
                    side = "horde"
                end
            else
                side = VerifyFlagBuff(unit, b)
            end
            if side == "alliance" then
                foundAlliCarrier = name
            elseif side == "horde" then
                foundHordeCarrier = name
            end
        end
    end
    return foundAlliCarrier, foundHordeCarrier
end

function TBGH:ScanRaidForFlagCarriers()
    if TBGH_GetBGType() ~= "wsg" then return end
    local numMembers = GetNumRaidMembers()
    if numMembers == 0 then return end
    local foundAlliCarrier = nil
    local foundHordeCarrier = nil
    for r = 1, numMembers do
        foundAlliCarrier, foundHordeCarrier = TBGH.ScanUnitForFlags("raid" .. r, foundAlliCarrier, foundHordeCarrier)
        foundAlliCarrier, foundHordeCarrier = TBGH.ScanUnitForFlags("raid" .. r .. "target", foundAlliCarrier, foundHordeCarrier)
    end
    foundAlliCarrier, foundHordeCarrier = TBGH.ScanUnitForFlags("player", foundAlliCarrier, foundHordeCarrier)
    local changed = false
    if foundAlliCarrier and self.wsg.alliCarrier ~= foundAlliCarrier then
        self.wsg.alliCarrier = foundAlliCarrier
        self.wsg.alliCarrierLastThreshold = nil
        changed = true
    end
    if foundHordeCarrier and self.wsg.hordeCarrier ~= foundHordeCarrier then
        self.wsg.hordeCarrier = foundHordeCarrier
        self.wsg.hordeCarrierLastThreshold = nil
        changed = true
    end
    if changed then
        self:UpdateWSGOverlay()
    end
end

function TBGH:DetectMidGameFlags()
    if TBGH_GetBGType() ~= "wsg" then return end
    self:ScanRaidForFlagCarriers()
    local hordeIcon = AlwaysUpFrame1DynamicIconButtonIcon
    local alliIcon = AlwaysUpFrame2DynamicIconButtonIcon
    if hordeIcon and hordeIcon:IsVisible() and not self.wsg.hordeCarrier then
        self.wsg.hordeCarrier = "Unknown"
        self.wsg.hordeCarrierLastThreshold = nil
    end
    if alliIcon and alliIcon:IsVisible() and not self.wsg.alliCarrier then
        self.wsg.alliCarrier = "Unknown"
        self.wsg.alliCarrierLastThreshold = nil
    end
    self:UpdateWSGOverlay()
end
---------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------
local wsgPosTimer = 0
local WSG_POS_INTERVAL = 0.1
local midGameCheckTimer = nil
local midGameCheckRetries = nil

TBGH:RegisterModule({
    name = "wsg",
    bgType = "wsg",
    tab = "bg",

    onBGMessage = function(msg, evt)
        if TBGH.wsgDebug then
            DEFAULT_CHAT_FRAME:AddMessage(string.format(
                "|cffffff00[WSG DBG]|r event=%s  msg='%s'",
                tostring(evt), tostring(msg)))
        end
        TBGH:ParseWSGMessage(msg, evt)
    end,

    onTargetChanged = function(unit, evt)
        local db = TBGH.db
        local foundA, foundH = TBGH.ScanUnitForFlags(unit, nil, nil)
        if evt == "PLAYER_TARGET_CHANGED" then
            foundA, foundH = TBGH.ScanUnitForFlags("targettarget", foundA, foundH)
        end
        if foundA and TBGH.wsg.alliCarrier ~= foundA then
            TBGH.wsg.alliCarrier = foundA
            TBGH.wsg.alliCarrierLastThreshold = nil
        end
        if foundH and TBGH.wsg.hordeCarrier ~= foundH then
            TBGH.wsg.hordeCarrier = foundH
            TBGH.wsg.hordeCarrierLastThreshold = nil
        end
        local uName = UnitName(unit)
        if uName and (uName == TBGH.wsg.alliCarrier or uName == TBGH.wsg.hordeCarrier) then
            local _, engClass = UnitClass(unit)
            if engClass and not TBGH.classCache[uName] then
                TBGH.classCache[uName] = engClass
            end
        end
        if db.wsgEnabled ~= false then
            TBGH:UpdateWSGOverlay()
        end
    end,

    onUpdate = function(elapsed)
        local db = TBGH.db
        -- Mid-game flag detection timer
        if midGameCheckTimer then
            midGameCheckTimer = midGameCheckTimer - elapsed
            if midGameCheckTimer <= 0 then
                if not midGameCheckRetries then
                    TBGH.containerActiveBG = "wsg"
                    TBGH.ApplyContainerPos(db.wsgPos or TBGH.DEFAULT_WSG_POS)
                    wsgPosTimer = 0
                end
                TBGH:DetectMidGameFlags()
                midGameCheckRetries = (midGameCheckRetries or 0) + 1
                local needsRetry = midGameCheckRetries <= 3
                    and (TBGH.wsg.alliCarrier == "Unknown" or TBGH.wsg.hordeCarrier == "Unknown"
                         or (not TBGH.wsg.alliCarrier and not TBGH.wsg.hordeCarrier))
                if needsRetry then
                    midGameCheckTimer = 2
                else
                    midGameCheckTimer = nil
                    midGameCheckRetries = nil
                end
            end
        end
        -- Periodic flag carrier scanning
        wsgPosTimer = wsgPosTimer + elapsed
        if wsgPosTimer >= WSG_POS_INTERVAL then
            wsgPosTimer = 0
            TBGH:ScanRaidForFlagCarriers()
            if db.wsgEnabled ~= false then
                TBGH:UpdateWSGOverlay()
            end
            if db.wsgAutoAnnounce ~= false then
                TBGH:CheckEFCHealthThresholds()
            end
        end
        -- Rez countdown (shared with AB)
        TBGH:UpdateRezCountdown()
    end,

    onEnterWorld = function()
        TBGH.containerActiveBG = "wsg"
        TBGH.ApplyContainerPos(TBGH.db.wsgPos or TBGH.DEFAULT_WSG_POS)
        midGameCheckTimer = 2
        midGameCheckRetries = nil
    end,

    reset = function()
        TBGH:ResetWSG()
        wsgPosTimer = 0
        midGameCheckTimer = nil
        midGameCheckRetries = nil
    end,

    -- Settings UI
    buildSettings = function(parent, prevAnchor)
        local db = TBGH.db
        local CSB = TBGH.CreateSmallButton
        local BTN_W = TBGH.BTN_WIDTH
        local BTN_M = TBGH.BTN_MARGIN
        local BTN_G = TBGH.BTN_GAP

        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if prevAnchor == parent then
            label:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -4)
        else
            label:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -12)
        end
        label:SetText("|cffffd100Warsong Gulch|r")

        -- Auto-announce (top-level, independent of overlay)
        local autoCheck = CreateFrame("CheckButton", "TurtlePvPWSGAutoCheck", parent, "UICheckButtonTemplate")
        autoCheck:SetWidth(24)
        autoCheck:SetHeight(24)
        autoCheck:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        local autoCheckLabel = parent:CreateFontString("TurtlePvPWSGAutoCheckLabel", "OVERLAY", "GameFontNormalSmall")
        autoCheckLabel:SetPoint("LEFT", autoCheck, "RIGHT", 2, 0)
        autoCheckLabel:SetText("Auto-announce EFC low HP (75%/50%/25%)")

        -- Dedup sub-checkbox (indented under auto-announce)
        local dedupCheck = CreateFrame("CheckButton", "TurtlePvPWSGDedupCheck", parent, "UICheckButtonTemplate")
        dedupCheck:SetWidth(24)
        dedupCheck:SetHeight(24)
        dedupCheck:SetPoint("TOPLEFT", autoCheck, "BOTTOMLEFT", 16, -2)
        local dedupCheckLabel = parent:CreateFontString("TurtlePvPWSGDedupCheckLabel", "OVERLAY", "GameFontNormalSmall")
        dedupCheckLabel:SetPoint("LEFT", dedupCheck, "RIGHT", 2, 0)
        dedupCheckLabel:SetText("Skip if already announced by another user")

        local function UpdateDedupEnabled()
            if TBGH.db.wsgAutoAnnounce ~= false then
                dedupCheck:Enable()
                dedupCheckLabel:SetTextColor(1, 1, 1, 1)
            else
                dedupCheck:Disable()
                dedupCheckLabel:SetTextColor(0.5, 0.5, 0.5, 1)
            end
        end

        -- Overlay checkbox (independent of announce)
        local check = CreateFrame("CheckButton", "TurtlePvPWSGCheck", parent, "UICheckButtonTemplate")
        check:SetWidth(24)
        check:SetHeight(24)
        check:SetPoint("TOPLEFT", dedupCheck, "BOTTOMLEFT", -16, -2)
        local checkLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
        checkLabel:SetText("Enable flag carrier display")

        local resetBtn = CSB("TurtlePvPWSGReset", parent, "Reset Pos", BTN_W)
        resetBtn:SetPoint("RIGHT", parent, "RIGHT", -BTN_M, 0)
        resetBtn:SetPoint("TOP", check, "TOP", 0, 2)

        local previewBtn = CSB("TurtlePvPWSGPreview", parent, "Preview", BTN_W)
        previewBtn:SetPoint("RIGHT", resetBtn, "LEFT", -BTN_G, 0)

        check:SetScript("OnClick", function()
            TBGH.db.wsgEnabled = this:GetChecked() and true or false
        end)
        previewBtn:SetScript("OnClick", function()
            if TBGH.previewSection == "wsg" then
                TBGH.HideAllPreviews()
            else
                TBGH.ShowSectionPreview("wsg")
            end
        end)
        resetBtn:SetScript("OnClick", function()
            TBGH.db.wsgPos = nil
            TBGH.ApplyContainerPos(TBGH.DEFAULT_WSG_POS)
            if TBGH.previewSection == "wsg" then
                TBGH.ShowSectionPreview("wsg")
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvP]|r WSG position reset to default")
        end)
        autoCheck:SetScript("OnClick", function()
            TBGH.db.wsgAutoAnnounce = this:GetChecked() and true or false
            UpdateDedupEnabled()
        end)
        dedupCheck:SetScript("OnClick", function()
            TBGH.db.wsgDedup = this:GetChecked() and true or false
        end)

        -- Store references for syncSettings
        TBGH._wsgCheck = check
        TBGH._wsgAutoCheck = autoCheck
        TBGH._wsgAutoCheckLabel = autoCheckLabel
        TBGH._wsgDedupCheck = dedupCheck
        TBGH._wsgDedupCheckLabel = dedupCheckLabel
        return check
    end,

    syncSettings = function()
        local db = TBGH.db
        if TBGH._wsgCheck then
            TBGH._wsgCheck:SetChecked(db.wsgEnabled ~= false)
        end
        if TBGH._wsgAutoCheck then
            TBGH._wsgAutoCheck:SetChecked(db.wsgAutoAnnounce ~= false)
        end
        if TBGH._wsgDedupCheck then
            TBGH._wsgDedupCheck:SetChecked(db.wsgDedup ~= false)
        end
        if db.wsgAutoAnnounce ~= false then
            if TBGH._wsgDedupCheck then TBGH._wsgDedupCheck:Enable() end
            if TBGH._wsgDedupCheckLabel then TBGH._wsgDedupCheckLabel:SetTextColor(1, 1, 1, 1) end
        else
            if TBGH._wsgDedupCheck then TBGH._wsgDedupCheck:Disable() end
            if TBGH._wsgDedupCheckLabel then TBGH._wsgDedupCheckLabel:SetTextColor(0.5, 0.5, 0.5, 1) end
        end
    end,

    hidePreview = function()
        if wsgFrame._previewMode then
            wsgFrame._previewMode = nil
            wsgAlliText:SetText("")
            wsgAlliHP:SetText("")
            wsgAlliDist:SetText("")
            wsgHordeText:SetText("")
            wsgHordeHP:SetText("")
            wsgHordeDist:SetText("")
            wsgFrame:Hide()
            if not TBGH.overlay:IsShown() then TBGH.container:Hide() end
        end
    end,

    showPreview = function()
        local container = TBGH.container
        TBGH.containerPreviewBG:SetTexture(0.1, 0.4, 0.1, 0.6)
        TBGH.containerActiveBG = "wsg"
        TBGH.ApplyContainerPos(TBGH.db.wsgPos or TBGH.DEFAULT_WSG_POS)
        container:Show()
        TBGH.overlay:Hide()
        wsgFrame:Show()
        wsgAlliText:SetText("|cff3399ffPlayerName|r")
        wsgHordeText:SetText("|cffff3333PlayerName|r")
        wsgAlliClassIcon:SetTexture(TBGH.CLASS_ICONS)
        wsgAlliClassIcon:SetTexCoord(0, 0.25, 0, 0.25)
        wsgAlliClassIcon:SetAlpha(1)
        wsgAlliClassIcon:Show()
        wsgHordeClassIcon:SetTexture(TBGH.CLASS_ICONS)
        wsgHordeClassIcon:SetTexCoord(0.5, 0.75, 0, 0.25)
        wsgHordeClassIcon:SetAlpha(1)
        wsgHordeClassIcon:Show()
        wsgFrame._previewMode = true
        container._previewMode = true
        TBGH:ResizeContainer()
    end,

    onSettingsHide = function()
        if TBGH_GetBGType() == "wsg" then
            TBGH.containerActiveBG = "wsg"
            TBGH.ApplyContainerPos(TBGH.db.wsgPos or TBGH.DEFAULT_WSG_POS)
            TBGH:UpdateWSGOverlay()
        end
    end,
})