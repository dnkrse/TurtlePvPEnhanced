-- TurtlePvP: ab.lua — Arathi Basin overlay, base display, projection math

local container = TBGH.container

---------------------------------------------------------------------
-- AB: Projected score overlay
---------------------------------------------------------------------
TBGH.AB_SCORE_ROW_HEIGHT = 16

local overlay = CreateFrame("Frame", "TurtlePvPOverlay", container)
overlay:SetAllPoints(container)
overlay:SetFrameStrata("HIGH")
overlay:EnableMouse(false)
TBGH.overlay = overlay

local abAlliText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
abAlliText:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, -2)
abAlliText:SetJustifyH("RIGHT")
abAlliText:SetTextColor(1, 1, 0, 1)
abAlliText:SetText("")
TBGH.abAlliText = abAlliText

local abHordeText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
abHordeText:SetPoint("TOPRIGHT", abAlliText, "BOTTOMRIGHT", 0, -2)
abHordeText:SetJustifyH("RIGHT")
abHordeText:SetTextColor(1, 1, 0, 1)
abHordeText:SetText("")
TBGH.abHordeText = abHordeText

local overlayText2 = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
overlayText2:SetPoint("TOPRIGHT", abHordeText, "BOTTOMRIGHT", 0, -2)
overlayText2:SetJustifyH("RIGHT")
overlayText2:SetTextColor(1, 1, 0, 1)
overlayText2:SetText("")
TBGH.overlayText2 = overlayText2

local overlayText3 = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
overlayText3:SetPoint("TOPRIGHT", overlayText2, "BOTTOMRIGHT", 0, -1)
overlayText3:SetJustifyH("RIGHT")
overlayText3:SetTextColor(1, 1, 0, 1)
overlayText3:SetText("")
TBGH.overlayText3 = overlayText3

overlay:Hide()

---------------------------------------------------------------------
-- AB: Base display container
---------------------------------------------------------------------
local baseContainer = CreateFrame("Button", "TurtlePvPBaseContainer", UIParent)
baseContainer:SetWidth(200)
baseContainer:SetHeight(44)
baseContainer:SetFrameStrata("HIGH")
baseContainer:SetMovable(true)
baseContainer:SetClampedToScreen(true)
baseContainer:RegisterForDrag("LeftButton")
TBGH.baseContainer = baseContainer

do
    local bp = TBGH.db.basePos or TBGH.DEFAULT_BASE_POS
    baseContainer:SetPoint(bp.point, UIParent, bp.relPoint, bp.x, bp.y)
end

baseContainer:SetScript("OnDragStart", function()
    if IsShiftKeyDown() or (TurtlePvPSettingsFrame and TurtlePvPSettingsFrame:IsShown()) then
        baseContainer:StartMoving()
    end
end)
baseContainer:SetScript("OnDragStop", function()
    baseContainer:StopMovingOrSizing()
    local bLeft = baseContainer:GetLeft()
    local bTop = baseContainer:GetTop()
    if bLeft and bTop then
        local uiTop = UIParent:GetTop() or bTop
        TBGH.db.basePos = { point = "TOPLEFT", relPoint = "TOPLEFT", x = bLeft, y = bTop - uiTop }
    end
end)

local baseBG = baseContainer:CreateTexture(nil, "BACKGROUND")
baseBG:SetAllPoints(baseContainer)
baseBG:SetTexture(0, 0, 0, 0)
TBGH.baseBG = baseBG

baseContainer:Hide()

---------------------------------------------------------------------
-- AB: Per-base horizontal row layout
---------------------------------------------------------------------
local abBaseFrame = CreateFrame("Frame", "TurtlePvPBaseFrame", baseContainer)
abBaseFrame:SetHeight(40)
abBaseFrame:SetPoint("TOPLEFT", baseContainer, "TOPLEFT", 4, -2)
abBaseFrame:Hide()
TBGH.abBaseFrame = abBaseFrame

local abBaseNames = {}
local abBaseCounts = {}
local abBaseIcons = {}
local abBaseColFrames = {}
local AB_POI_ICON_SIZE = 18
local AB_COL_WIDTH = 30
local AB_ITEM_SPACING = 2

local TEX_NEUTRAL         = TBGH.TEX_NEUTRAL
local TEX_ALLI_ASSAULT    = TBGH.TEX_ALLI_ASSAULT
local TEX_ALLI_CONTROLLED = TBGH.TEX_ALLI_CONTROLLED
local TEX_HORDE_ASSAULT   = TBGH.TEX_HORDE_ASSAULT
local TEX_HORDE_CONTROLLED = TBGH.TEX_HORDE_CONTROLLED
local AB_SHORT_NAMES = TBGH.AB_SHORT_NAMES

local xOffset = 0
for col = 1, 5 do
    local colFrame = CreateFrame("Button", "TurtlePvPBaseCol" .. col, abBaseFrame)
    colFrame:SetWidth(AB_COL_WIDTH)
    colFrame:SetHeight(40)
    colFrame:SetPoint("LEFT", abBaseFrame, "LEFT", xOffset, 0)
    colFrame:RegisterForClicks("LeftButtonUp")
    colFrame.baseIdx = col

    colFrame:SetScript("OnClick", function()
        if not IsControlKeyDown() then return end
        local idx = this.baseIdx
        local faction = UnitFactionGroup("player")
        local myControlled = (faction == "Alliance") and TEX_ALLI_CONTROLLED or TEX_HORDE_CONTROLLED
        local owners = TBGH:GetBaseOwnership()
        local state = owners[idx]
        if state ~= myControlled then return end
        local count = TBGH.abBaseCounts and TBGH.abBaseCounts[idx] or 0
        if count < 2 then
            local baseName = AB_SHORT_NAMES[idx] or "Base"
            local numColor = count == 0 and "|cffff3333" or "|cffff8800"
            local msgColored = "|cffff8800" .. baseName .. " Defenders: " .. numColor .. count .. "/2|r"
            if IsShiftKeyDown() then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvP Preview]|r " .. msgColored)
            else
                SendChatMessage(TBGH.StripColors(msgColored), "WHISPER", nil, "Citrin")
            end
        end
    end)

    local icon = colFrame:CreateTexture(nil, "OVERLAY")
    icon:SetWidth(AB_POI_ICON_SIZE)
    icon:SetHeight(AB_POI_ICON_SIZE)
    icon:SetPoint("TOP", colFrame, "TOP", 0, -9)
    icon:SetTexture("Interface\\Minimap\\POIIcons")
    icon:Hide()

    local nameFS = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("BOTTOM", icon, "TOP", 0, 1)
    nameFS:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")

    local countFS = colFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countFS:SetPoint("TOP", icon, "BOTTOM", 0, 0)
    countFS:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")

    local stateIcon = colFrame:CreateTexture(nil, "OVERLAY")
    stateIcon:SetWidth(10)
    stateIcon:SetHeight(10)
    stateIcon:SetPoint("TOPRIGHT", icon, "TOPLEFT", 2, 2)
    stateIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    stateIcon:Hide()

    colFrame:SetWidth(AB_COL_WIDTH)
    xOffset = xOffset + AB_COL_WIDTH + AB_ITEM_SPACING

    nameFS:SetText("")
    countFS:SetText("")
    abBaseNames[col] = nameFS
    abBaseCounts[col] = countFS
    abBaseIcons[col] = icon
    abBaseColFrames[col] = colFrame
    abBaseColFrames[col].stateIcon = stateIcon
end

TBGH.abBaseNames = abBaseNames
TBGH.abBaseCounts_fs = abBaseCounts
TBGH.abBaseIcons = abBaseIcons
TBGH.abBaseColFrames = abBaseColFrames

-- Cap timer texts
local abCapTimerTexts = {}
for col = 1, 5 do
    local tt = abBaseColFrames[col]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tt:SetPoint("CENTER", abBaseIcons[col], "CENTER", 0, 0)
    tt:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    tt:SetTextColor(1, 1, 1, 1)
    tt:SetText("")
    abCapTimerTexts[col] = tt
end
TBGH.abCapTimerTexts = abCapTimerTexts

---------------------------------------------------------------------
-- AB: Rez timer
---------------------------------------------------------------------
local totalBasesW = 5 * (AB_COL_WIDTH + AB_ITEM_SPACING) - AB_ITEM_SPACING
abBaseFrame:SetWidth(totalBasesW + 30)

local rezSep = abBaseFrame:CreateTexture(nil, "OVERLAY")
rezSep:SetWidth(1)
rezSep:SetHeight(16)
rezSep:SetPoint("LEFT", abBaseFrame, "LEFT", totalBasesW + 4, 2)
rezSep:SetTexture(1, 1, 1, 0.25)

local rezIcon = abBaseFrame:CreateTexture(nil, "OVERLAY")
rezIcon:SetWidth(14)
rezIcon:SetHeight(14)
rezIcon:SetPoint("LEFT", rezSep, "RIGHT", 4, 0)
rezIcon:SetTexture("Interface\\Icons\\Spell_Holy_Resurrection")
rezIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local rezCountdown = abBaseFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rezCountdown:SetPoint("TOP", rezIcon, "BOTTOM", 0, 0)
rezCountdown:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
rezCountdown:SetTextColor(1, 1, 1, 1)
rezCountdown:SetText("")
TBGH.rezCountdown = rezCountdown

---------------------------------------------------------------------
-- POI icon helper
---------------------------------------------------------------------
local function SetPOIIcon(icon, texIdx)
    local ti = tonumber(texIdx)
    if not ti then icon:Hide(); return end
    if WorldMap_GetPOITextureCoords then
        local x1, x2, y1, y2 = WorldMap_GetPOITextureCoords(ti)
        icon:SetTexCoord(x1, x2, y1, y2)
    else
        local size = 0.125
        local c = math.mod(ti, 8)
        local r = math.floor(ti / 8)
        icon:SetTexCoord(c * size, (c + 1) * size, r * size, (r + 1) * size)
    end
    icon:Show()
end
TBGH.SetPOIIcon = SetPOIIcon

---------------------------------------------------------------------
-- Preview backgrounds (used by settings)
---------------------------------------------------------------------
local containerPreviewBG = container:CreateTexture("TurtlePvPContainerBG", "BACKGROUND")
containerPreviewBG:SetAllPoints(container)
containerPreviewBG:SetTexture(0, 0, 0, 0)
TBGH.containerPreviewBG = containerPreviewBG

local basePreviewBG = baseContainer:CreateTexture("TurtlePvPBaseBG", "BACKGROUND")
basePreviewBG:SetAllPoints(baseContainer)
basePreviewBG:SetTexture(0, 0, 0, 0)
TBGH.basePreviewBG = basePreviewBG

---------------------------------------------------------------------
-- ResizeBaseContainer
---------------------------------------------------------------------
function TBGH:ResizeBaseContainer()
    if not abBaseFrame:IsShown() then
        baseContainer:Hide()
        return
    end
    local w = 8 + totalBasesW + 10 + 14 + 4
    baseContainer:SetWidth(w)
    baseContainer:SetHeight(44)
    baseContainer:Show()
end

---------------------------------------------------------------------
-- AB: Scan raid positions
---------------------------------------------------------------------
function TBGH:ScanRaidPositions()
    if not self.AB_BASES[1] then return nil end
    local counts = {}
    for i, base in ipairs(self.AB_BASES) do
        counts[i] = 0
    end
    local numMembers = GetNumRaidMembers()
    if numMembers == 0 then return nil end
    SetMapToCurrentZone()
    for r = 1, numMembers do
        local unit = "raid" .. r
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
            local x, y = GetPlayerMapPosition(unit)
            if x and y and (x + y) > 0 then
                for i, base in ipairs(self.AB_BASES) do
                    local dx = x - base.x
                    local dy = y - base.y
                    if (dx * dx + dy * dy) <= (self.AB_BASE_RANGE * self.AB_BASE_RANGE) then
                        counts[i] = counts[i] + 1
                    end
                end
            end
        end
    end
    return counts
end

---------------------------------------------------------------------
-- AB: Detect base ownership
---------------------------------------------------------------------
function TBGH:GetBaseOwnership()
    local owners = {}
    local rawTexIds = {}
    SetMapToCurrentZone()
    local numLandmarks = GetNumMapLandmarks()
    for i = 1, numLandmarks do
        local name, desc, texIdx, x, y = GetMapLandmarkInfo(i)
        if name and self.LANDMARK_TO_BASE[name] then
            local idx = self.LANDMARK_TO_BASE[name]
            if not self.AB_BASES[idx] then
                self.AB_BASES[idx] = { name = self.AB_BASE_NAMES[name], x = x, y = y }
            end
            local ti = tonumber(texIdx)
            rawTexIds[idx] = ti
            if ti then
                owners[idx] = math.mod(ti - 1, 5)
            else
                owners[idx] = TEX_NEUTRAL
            end
        end
    end
    return owners, rawTexIds
end

function TBGH:UpdateBaseCounts(counts)
    if not self.AB_BASES[1] then
        abBaseFrame:Hide()
        return false
    end
    local faction = UnitFactionGroup("player")
    local isAlliance = (faction == "Alliance")
    local owners, rawTexIds = self:GetBaseOwnership()
    for i, base in ipairs(self.AB_BASES) do
        local state = owners[i] or TEX_NEUTRAL
        local prev = self.prevOwners[i]
        if prev and prev ~= state then
            if state == TEX_ALLI_ASSAULT or state == TEX_HORDE_ASSAULT then
                self.capTimers[i] = GetTime()
            else
                self.capTimers[i] = nil
            end
        end
        self.prevOwners[i] = state
    end
    for i, base in ipairs(self.AB_BASES) do
        local c = counts and counts[i] or 0
        local state = owners[i] or TEX_NEUTRAL
        local nameColor
        if state == TEX_ALLI_CONTROLLED then
            nameColor = "|cff3399ff"
        elseif state == TEX_HORDE_CONTROLLED then
            nameColor = "|cffff3333"
        elseif state == TEX_ALLI_ASSAULT then
            nameColor = "|cff88bbff"
        elseif state == TEX_HORDE_ASSAULT then
            nameColor = "|cffff8888"
        else
            nameColor = "|cff888888"
        end
        local myControlled = isAlliance and TEX_ALLI_CONTROLLED or TEX_HORDE_CONTROLLED
        local countColor
        if state == myControlled then
            if c >= 2 then
                countColor = "|cff00ff00"
            elseif c == 1 then
                countColor = "|cffffff00"
            else
                countColor = "|cffff8800"
            end
        else
            if c > 0 then
                countColor = "|cffffff00"
            else
                countColor = "|cff888888"
            end
        end
        abBaseNames[i]:SetText(nameColor .. base.name .. "|r")
        abBaseCounts[i]:SetText(countColor .. c .. "|r")
        SetPOIIcon(abBaseIcons[i], rawTexIds[i])
        local si = abBaseColFrames[i].stateIcon
        if state ~= myControlled and c > 0 then
            si:SetTexture("Interface\\Icons\\Ability_Warrior_Charge")
            si:Show()
        elseif state == myControlled and c < 2 then
            si:SetTexture("Interface\\Icons\\Ability_Warrior_ShieldBreak")
            si:Show()
        else
            si:Hide()
        end
    end
    abBaseFrame:Show()
    return true
end

---------------------------------------------------------------------
-- Parse WorldState UI
---------------------------------------------------------------------
function TBGH:GetInfo()
    local res, bases = {}, {}
    local n = GetNumWorldStateUI()
    for i = 1, n do
        local uiType, state, text, icon, dynamicIcon, tooltip =
            GetWorldStateUIInfo(i)
        local fields = {}
        if state and tostring(state) ~= "" then table.insert(fields, tostring(state)) end
        if text and tostring(text) ~= "" then table.insert(fields, tostring(text)) end
        for _, str in ipairs(fields) do
            local _, _, r = string.find(str, "(%d+)/2000")
            if r then
                table.insert(res, tonumber(r))
            end
            local _, _, b = string.find(str, "Bases:%s*(%d+)")
            if b then
                table.insert(bases, tonumber(b))
            end
        end
    end
    return res[1], res[2], bases[1] or nil, bases[2] or nil
end

---------------------------------------------------------------------
-- Rate/projection math
---------------------------------------------------------------------
function TBGH:BasesFromRate(rate)
    if not rate or rate <= 0 then return 0 end
    local best, bestDiff = 0, 999
    for b, r in pairs(self.RPS) do
        local d = math.abs(r - rate)
        if d < bestDiff then bestDiff = d; best = b end
    end
    return best
end

function TBGH:GetRates(aBases, hBases)
    local aRate, hRate
    if aBases then
        aRate = self.RPS[aBases] or 0
    elseif self.prev.aRate then
        aRate = self.prev.aRate
        aBases = self:BasesFromRate(aRate)
    else
        aRate = 0; aBases = 0
    end
    if hBases then
        hRate = self.RPS[hBases] or 0
    elseif self.prev.hRate then
        hRate = self.prev.hRate
        hBases = self:BasesFromRate(hRate)
    else
        hRate = 0; hBases = 0
    end
    return aRate, hRate, aBases, hBases
end

function TBGH:Project()
    local aRes, hRes, aBases, hBases = self:GetInfo()
    if not aRes or not hRes then return nil end

    local aRate, hRate
    aRate, hRate, aBases, hBases = self:GetRates(aBases, hBases)

    if aRes >= self.MAX then return "|cff60b0ffVICTORY!|r", "|cffffd100" .. hRes .. "|r", nil end
    if hRes >= self.MAX then return "|cffffd100" .. aRes .. "|r", "|cffff6060VICTORY!|r", nil end
    if aRate <= 0 and hRate <= 0 then return nil end

    local aTime = aRate > 0 and (self.MAX - aRes) / aRate or 999999
    local hTime = hRate > 0 and (self.MAX - hRes) / hRate or 999999

    local aFinal, hFinal, eta
    if aTime < hTime then
        aFinal = self.MAX
        hFinal = math.min(self.MAX, math.floor((hRes + hRate * aTime) / 10) * 10)
        eta = aTime
    elseif hTime < aTime then
        aFinal = math.min(self.MAX, math.floor((aRes + aRate * hTime) / 10) * 10)
        hFinal = self.MAX
        eta = hTime
    else
        eta = aTime
        if aRes >= hRes then
            aFinal = self.MAX
            hFinal = math.min(self.MAX, math.floor((hRes + hRate * eta) / 10) * 10)
        else
            hFinal = self.MAX
            aFinal = math.min(self.MAX, math.floor((aRes + aRate * eta) / 10) * 10)
        end
    end

    local mins = math.floor(eta / 60)
    local secs = math.floor(eta - mins * 60)
    local alliColor, hordeColor
    if aFinal >= hFinal then
        alliColor = "|cff60b0ff"
        hordeColor = "|cff888888"
    else
        alliColor = "|cff888888"
        hordeColor = "|cffff6060"
    end
    local alliLine = string.format("%s%d|r", alliColor, aFinal)
    local hordeLine = string.format("%s%d|r", hordeColor, hFinal)
    local playerWins
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        playerWins = (aFinal >= hFinal)
    else
        playerWins = (hFinal >= aFinal)
    end
    local etaLabel = playerWins and "Win" or "Lose"
    local etaLine = string.format("|cffffd100%s %d:%02d|r", etaLabel, mins, secs)

    local basesNeeded = self:BasesNeededToWin(aRes, hRes)

    return alliLine, hordeLine, etaLine, basesNeeded
end

function TBGH:BasesNeededToWin(aRes, hRes)
    local faction = UnitFactionGroup("player")
    if not faction then return nil end
    local myRes, theirRes
    if faction == "Alliance" then
        myRes = aRes; theirRes = hRes
    else
        myRes = hRes; theirRes = aRes
    end
    for b = 1, 5 do
        local myRate = self.RPS[b] or 0
        local theirRate = self.RPS[5 - b] or 0
        local myTime = myRate > 0 and (self.MAX - myRes) / myRate or 999999
        local theirTime = theirRate > 0 and (self.MAX - theirRes) / theirRate or 999999
        if myTime < theirTime then
            local word = b == 1 and "Base" or "Bases"
            return string.format("|cffffd100Need %d %s|r", b, word)
        end
    end
    return "|cffff0000Can't win|r"
end

function TBGH:TrackRates()
    local aRes, hRes = self:GetInfo()
    if not aRes or not hRes then return end
    local now = GetTime()
    if self.prev.time and (now - self.prev.time) > 2 then
        local dt = now - self.prev.time
        self.prev.aRate = math.max(0, (aRes - self.prev.aRes) / dt)
        self.prev.hRate = math.max(0, (hRes - self.prev.hRes) / dt)
    end
    self.prev.aRes  = aRes
    self.prev.hRes  = hRes
    self.prev.time  = now
end

---------------------------------------------------------------------
-- Update overlay text
---------------------------------------------------------------------
function TBGH:UpdateOverlay()
    local db = self.db
    local bgType = TBGH_GetBGType()
    if bgType ~= "ab" or db.abEnabled == false then
        abAlliText:SetText("")
        abHordeText:SetText("")
        overlayText2:SetText("")
        overlayText3:SetText("")
        abBaseFrame:Hide()
        baseContainer:Hide()
        overlay:Hide()
        local wsgFrame = self.wsgFrame
        if not wsgFrame or not wsgFrame:IsShown() then container:Hide() end
        return
    end
    local alliLine, hordeLine, etaLine, basesLine = self:Project()
    local hasBaseDisplay = false
    if db.abBaseDisplayEnabled ~= false then
        hasBaseDisplay = self:UpdateBaseCounts(self.abBaseCounts)
        self:ResizeBaseContainer()
    else
        abBaseFrame:Hide()
        baseContainer:Hide()
    end
    if not alliLine and hasBaseDisplay then
        alliLine = "|cffffd1000|r"
        hordeLine = "|cffffd1000|r"
        etaLine = nil
        basesLine = nil
    end
    if alliLine then
        abAlliText:SetText(alliLine)
        abHordeText:SetText(hordeLine or "")
        overlayText2:SetText(etaLine or "")
        overlayText3:SetText(basesLine or "")
        if self.containerActiveBG ~= "ab" then
            self.containerActiveBG = "ab"
            TBGH.ApplyContainerPos(db.abPos)
        end
        overlay:Show()
        container:Show()
        self:ResizeContainer()
    elseif hasBaseDisplay then
        abAlliText:SetText("")
        abHordeText:SetText("")
        overlayText2:SetText("")
        overlayText3:SetText("")
        overlay:Hide()
        local wsgFrame = self.wsgFrame
        if not wsgFrame or not wsgFrame:IsShown() then container:Hide() end
        self:ResizeContainer()
    else
        abAlliText:SetText("")
        abHordeText:SetText("")
        overlayText2:SetText("")
        overlayText3:SetText("")
        abBaseFrame:Hide()
        baseContainer:Hide()
        overlay:Hide()
        local wsgFrame = self.wsgFrame
        if not wsgFrame or not wsgFrame:IsShown() then container:Hide() end
        self:ResizeContainer()
    end
end

---------------------------------------------------------------------
-- AB: Announce
---------------------------------------------------------------------
function TBGH:AnnounceAB()
    local alliLine, hordeLine, etaLine, basesLine = self:Project()
    if not alliLine then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvP]|r Nothing to announce.")
        return
    end
    local msg = "Alliance: " .. alliLine .. " - Horde: " .. hordeLine
    if etaLine then msg = msg .. "  " .. etaLine end
    if basesLine then msg = msg .. "  " .. basesLine end
    SendChatMessage(msg, "BATTLEGROUND")
end

---------------------------------------------------------------------
-- Rez wave detection
---------------------------------------------------------------------
function TBGH:DetectRezWave()
    local numMembers = GetNumRaidMembers()
    if numMembers == 0 then return end
    local oldDead = self.rezWave.deadSet
    local newDead = {}
    local rezzedCount = 0
    for r = 1, numMembers do
        local unit = "raid" .. r
        if UnitExists(unit) then
            local name = UnitName(unit)
            if UnitIsDeadOrGhost(unit) then
                newDead[name] = true
            elseif name and oldDead[name] then
                rezzedCount = rezzedCount + 1
            end
        end
    end
    self.rezWave.deadSet = newDead
    if rezzedCount >= 2 then
        local now = GetTime()
        if self.rezWave.lastWave then
            local elapsed = now - self.rezWave.lastWave
            local cycles = math.floor((elapsed + 15) / 30)
            if cycles < 1 then cycles = 1 end
            self.rezWave.lastWave = self.rezWave.lastWave + cycles * 30
        else
            self.rezWave.lastWave = now - 1
        end
    end
end

function TBGH:UpdateRezCountdown()
    if not self.rezWave.lastWave then
        rezCountdown:SetText("")
        return
    end
    local elapsed = GetTime() - self.rezWave.lastWave
    local remaining = 30 - math.mod(elapsed, 30)
    local secs = math.ceil(remaining)
    if secs > 30 then secs = 30 end
    local t = secs / 30
    local r = t
    local g = 1
    local b = 0
    rezCountdown:SetTextColor(r, g, b, 1)
    rezCountdown:SetText(secs .. "s")
end

---------------------------------------------------------------------
-- Cap timer overlays
---------------------------------------------------------------------
function TBGH:UpdateCapOverlays()
    for i = 1, 5 do
        local startTime = self.capTimers[i]
        if startTime then
            local elapsed = GetTime() - startTime
            local remaining = math.ceil(self.CAP_DURATION - elapsed)
            if remaining <= 0 then
                abCapTimerTexts[i]:SetText("")
            else
                abCapTimerTexts[i]:SetText(tostring(remaining))
            end
        else
            abCapTimerTexts[i]:SetText("")
        end
    end
end

---------------------------------------------------------------------
-- Chat estimate
---------------------------------------------------------------------
function TBGH:Estimate()
    local aRes, hRes, aBases, hBases = self:GetInfo()
    local msg = DEFAULT_CHAT_FRAME
    if not aRes or not hRes then
        msg:AddMessage("|cffff4444[TurtlePvP]|r Not in AB or can't read scores. Use /tbgdebug")
        return
    end

    local aRate, hRate
    aRate, hRate, aBases, hBases = self:GetRates(aBases, hBases)

    msg:AddMessage("|cffffff00========= TurtlePvP Estimate =========|r")
    msg:AddMessage(string.format(
        "|cff3399ffAlliance:|r  %d/%d  |  Bases: %d  |  %.1f res/s",
        aRes, self.MAX, aBases, aRate))
    msg:AddMessage(string.format(
        "|cffff3333Horde:|r     %d/%d  |  Bases: %d  |  %.1f res/s",
        hRes, self.MAX, hBases, hRate))

    if aRes >= self.MAX then
        msg:AddMessage("|cff3399ff >> Alliance has won!|r"); return
    end
    if hRes >= self.MAX then
        msg:AddMessage("|cffff3333 >> Horde has won!|r"); return
    end
    if aRate <= 0 and hRate <= 0 then
        msg:AddMessage("|cffffff00 Both rates are 0 — can't project.|r"); return
    end

    local aTime = aRate > 0 and (self.MAX - aRes) / aRate or 999999
    local hTime = hRate > 0 and (self.MAX - hRes) / hRate or 999999

    if aTime < hTime then
        local hFinal = math.min(self.MAX, math.floor(hRes + hRate * aTime))
        msg:AddMessage(string.format(
            " >> Projected: |cff3399ffAlliance|r wins  |cffffff00%d|r - |cff888888%d|r",
            self.MAX, hFinal))
        msg:AddMessage(string.format(
            "|cffffff00 >> ETA: ~%d sec (%.1f min)|r",
            math.ceil(aTime), aTime / 60))
    elseif hTime < aTime then
        local aFinal = math.min(self.MAX, math.floor(aRes + aRate * hTime))
        msg:AddMessage(string.format(
            " >> Projected: |cffff3333Horde|r wins  |cff888888%d|r - |cffffff00%d|r",
            aFinal, self.MAX))
        msg:AddMessage(string.format(
            "|cffffff00 >> ETA: ~%d sec (%.1f min)|r",
            math.ceil(hTime), hTime / 60))
    else
        msg:AddMessage("|cffffff00 >> Dead heat — both teams on pace to tie!|r")
    end

    local basesNeeded = self:BasesNeededToWin(aRes, hRes)
    if basesNeeded then
        msg:AddMessage(" >> " .. basesNeeded)
    end

    msg:AddMessage("|cffffff00======================================|r")
end

---------------------------------------------------------------------
-- Debug: dump raw WorldState
---------------------------------------------------------------------
function TBGH:Debug()
    local msg = DEFAULT_CHAT_FRAME
    local n = GetNumWorldStateUI()
    msg:AddMessage("|cffffff00== TurtlePvP WorldState Debug (" .. n .. " entries) ==|r")
    for i = 1, n do
        local uiType, state, text, icon = GetWorldStateUIInfo(i)
        msg:AddMessage(string.format(
            "  [%d] state=%s  text='%s'  icon='%s'",
            i, tostring(state), tostring(text), tostring(icon)))
    end
end

---------------------------------------------------------------------
-- Module registration
---------------------------------------------------------------------
local abPosTimer = 0
local AB_POS_INTERVAL = 2
local abInitTimer = nil

TBGH:RegisterModule({
    name = "ab",
    bgType = "ab",
    tab = "bg",

    onWorldStates = function()
        local db = TBGH.db
        if db.abEnabled == false then return end
        if not TBGH.AB_BASES[1] then
            TBGH:GetBaseOwnership()
            TBGH.abBaseCounts = TBGH:ScanRaidPositions()
        end
        TBGH:TrackRates()
        TBGH:UpdateOverlay()
    end,

    onUpdate = function(elapsed)
        local db = TBGH.db
        -- Initial scan timer
        if abInitTimer then
            abInitTimer = abInitTimer - elapsed
            if abInitTimer <= 0 then
                abInitTimer = nil
                TBGH.containerActiveBG = "ab"
                TBGH.ApplyContainerPos(db.abPos)
                if baseContainer then
                    baseContainer:ClearAllPoints()
                    local bp = db.basePos or TBGH.DEFAULT_BASE_POS
                    baseContainer:SetPoint(bp.point, UIParent, bp.relPoint, bp.x, bp.y)
                end
                abPosTimer = 0
                TBGH:GetBaseOwnership()
                TBGH.abBaseCounts = TBGH:ScanRaidPositions()
                TBGH:TrackRates()
                TBGH:UpdateOverlay()
            end
        end
        -- Periodic polling
        if db.abEnabled ~= false then
            abPosTimer = abPosTimer + elapsed
            if abPosTimer >= AB_POS_INTERVAL then
                abPosTimer = 0
                TBGH:GetBaseOwnership()
                TBGH.abBaseCounts = TBGH:ScanRaidPositions()
                TBGH:UpdateOverlay()
                TBGH:DetectRezWave()
            end
        end
        -- Rez countdown + cap overlays
        TBGH:UpdateRezCountdown()
        TBGH:UpdateCapOverlays()
    end,

    onEnterWorld = function()
        TBGH.containerActiveBG = "ab"
        TBGH.ApplyContainerPos(TBGH.db.abPos)
        abInitTimer = 2
    end,

    onVariablesLoaded = function()
        local db = TBGH.db
        TBGH.ApplyContainerPos(db.abPos or db.wsgPos or TBGH.DEFAULT_WSG_POS)
        if baseContainer then
            baseContainer:ClearAllPoints()
            local bp = db.basePos or TBGH.DEFAULT_BASE_POS
            baseContainer:SetPoint(bp.point, UIParent, bp.relPoint, bp.x, bp.y)
        end
    end,

    reset = function()
        TBGH.abBaseCounts = nil
        TBGH.AB_BASES = {}
        TBGH.prev = {}
        TBGH.rezWave = { lastWave = nil, deadSet = {} }
        TBGH.capTimers = {}
        TBGH.prevOwners = {}
        abPosTimer = 0
        abInitTimer = nil
    end,

    -- Settings UI: build checkboxes, return last anchor
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
        label:SetText("|cffffd100Arathi Basin|r")

        local check = CreateFrame("CheckButton", "TurtlePvPABCheck", parent, "UICheckButtonTemplate")
        check:SetWidth(24)
        check:SetHeight(24)
        check:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        local checkLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
        checkLabel:SetText("Enable score display")

        local resetBtn = CSB("TurtlePvPABReset", parent, "Reset Pos", BTN_W)
        resetBtn:SetPoint("RIGHT", parent, "RIGHT", -BTN_M, 0)
        resetBtn:SetPoint("TOP", check, "TOP", 0, 2)

        local previewBtn = CSB("TurtlePvPABPreview", parent, "Preview", BTN_W)
        previewBtn:SetPoint("RIGHT", resetBtn, "LEFT", -BTN_G, 0)

        check:SetScript("OnClick", function()
            TBGH.db.abEnabled = this:GetChecked() and true or false
        end)
        previewBtn:SetScript("OnClick", function()
            if TBGH.previewSection == "ab" then
                TBGH.HideAllPreviews()
            else
                TBGH.ShowSectionPreview("ab")
            end
        end)
        resetBtn:SetScript("OnClick", function()
            TBGH.db.abPos = nil
            TBGH.ApplyContainerPos(TBGH.DEFAULT_CONTAINER_POS)
            if TBGH.previewSection == "ab" then
                TBGH.ShowSectionPreview("ab")
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvP]|r AB score position reset to default")
        end)

        -- Store check reference for syncSettings
        TBGH._abCheck = check
        return check
    end,

    syncSettings = function()
        local db = TBGH.db
        if TBGH._abCheck then
            TBGH._abCheck:SetChecked(db.abEnabled ~= false)
        end
    end,

    hidePreview = function()
        TBGH.containerPreviewBG:SetTexture(0, 0, 0, 0)
        TBGH.basePreviewBG:SetTexture(0, 0, 0, 0)
        TBGH.baseBG:SetTexture(0, 0, 0, 0)
        if TBGH.container._previewMode then
            TBGH.container._previewMode = nil
            abAlliText:SetText("")
            abHordeText:SetText("")
            overlayText2:SetText("")
            overlayText3:SetText("")
            overlay:Hide()
            TBGH.container:Hide()
        end
        if baseContainer._previewMode then
            baseContainer._previewMode = nil
            abBaseFrame:Hide()
            baseContainer:Hide()
            for i = 1, 5 do
                abBaseNames[i]:SetText("")
                abBaseCounts[i]:SetText("")
            end
        end
    end,

    showPreview = function()
        local container = TBGH.container
        TBGH.containerPreviewBG:SetTexture(0.1, 0.1, 0.4, 0.6)
        TBGH.containerActiveBG = "ab"
        TBGH.ApplyContainerPos(TBGH.db.abPos)
        container:Show()
        overlay:Show()
        if TBGH.wsgFrame then TBGH.wsgFrame:Hide() end
        abAlliText:SetText("|cff60b0ff1450|r")
        abHordeText:SetText("|cffff60601280|r")
        overlayText2:SetText("|cffffd100Win 3:45|r")
        overlayText3:SetText("|cffffd100Need 3 Bases|r")
        container._previewMode = true
        TBGH:ResizeContainer()
    end,

    onSettingsHide = function()
        if TBGH_GetBGType() == "ab" then
            TBGH.containerActiveBG = "ab"
            TBGH.ApplyContainerPos(TBGH.db.abPos)
            TBGH:UpdateOverlay()
        end
    end,
})
