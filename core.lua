-- TurtlePvP: BG helper for WoW 1.12 / Turtle WoW
-- core.lua: Shared state, utilities, container, class/GUID helpers

---------------------------------------------------------------------
-- BG zone detection
---------------------------------------------------------------------
local BG_ZONES = {
    ["Arathi Basin"] = "ab",
    ["Warsong Gulch"] = "wsg",
    ["Alterac Valley"] = "av",
    ["Sunnyglade Valley"] = "sgv",
    ["Thorn Gorge"] = "tg",
}

function TBGH_GetBGType()
    local zone = GetRealZoneText()
    return BG_ZONES[zone] or nil
end

-- Expose so modules can register new zones
TBGH_BG_ZONES = BG_ZONES

---------------------------------------------------------------------
-- Main addon table
---------------------------------------------------------------------
TBGH = {
    MAX = 2000,
    RPS = { [0]=0, [1]=10/12, [2]=10/9, [3]=10/6, [4]=10/3, [5]=30 },
    prev = {},
    lastProjection = nil,
    wsg = {
        alliCarrier = nil,
        hordeCarrier = nil,
        alliCarrierLastThreshold = nil,
        hordeCarrierLastThreshold = nil,
        efcAnnounceSeenAt = {},
        efcManualSeenAt = nil,
    },
    guidTracker = {
        nameToGuid = {},
        guidToName = {},
    },
    hasNampower = false,
    hasUnitXP = false,
    AB_BASE_NAMES = {
        ["Stables"]    = "ST",
        ["Blacksmith"] = "BS",
        ["Lumber Mill"]= "LM",
        ["Gold Mine"]  = "GM",
        ["Farm"]       = "FM",
    },
    AB_BASES = {},
    AB_BASE_RANGE = 0.1,
    abBaseCounts = nil,
    rezWave = {
        lastWave = nil,
        deadSet = {},
    },
    capTimers = {},
    prevOwners = {},
    CAP_DURATION = 60,
    -- Cross-file shared state
    containerActiveBG = nil,
    totemSkipping = false,
    MAX_TOTEM_SKIPS = 20,
    previewSection = nil,
    -- Module registry
    modules = {},
}

---------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------
TBGH.DEFAULT_CONTAINER_POS = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 1133, y = -37 }
TBGH.DEFAULT_BASE_POS      = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 1077, y = -104 }
TBGH.DEFAULT_WSG_POS       = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 1133, y = -37 }

TBGH.TEX_NEUTRAL         = 0
TBGH.TEX_ALLI_ASSAULT    = 1
TBGH.TEX_ALLI_CONTROLLED = 2
TBGH.TEX_HORDE_ASSAULT   = 3
TBGH.TEX_HORDE_CONTROLLED = 4

TBGH.AB_SHORT_NAMES = { "ST", "BS", "LM", "GM", "FM" }

TBGH.LANDMARK_TO_BASE = {
    ["Stables"]    = 1,
    ["Blacksmith"] = 2,
    ["Lumber Mill"]= 3,
    ["Gold Mine"]  = 4,
    ["Farm"]       = 5,
}

---------------------------------------------------------------------
-- Class colors and icon data (shared by WSG overlay + settings)
---------------------------------------------------------------------
TBGH.CLASS_COLORS = {
    ["WARRIOR"]     = "ffc79c6e",
    ["PALADIN"]     = "fff58cba",
    ["HUNTER"]      = "ffabd473",
    ["ROGUE"]       = "fffff569",
    ["PRIEST"]      = "ffffffff",
    ["SHAMAN"]      = "ff0070de",
    ["MAGE"]        = "ff69ccf0",
    ["WARLOCK"]     = "ff9482c9",
    ["DRUID"]       = "ffff7d0a",
}

TBGH.CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes"

TBGH.CLASS_TCOORDS = {
    ["WARRIOR"]     = {0,    0.25, 0,    0.25},
    ["MAGE"]        = {0.25, 0.5,  0,    0.25},
    ["ROGUE"]       = {0.5,  0.75, 0,    0.25},
    ["DRUID"]       = {0.75, 1,    0,    0.25},
    ["HUNTER"]      = {0,    0.25, 0.25, 0.5},
    ["SHAMAN"]      = {0.25, 0.5,  0.25, 0.5},
    ["PRIEST"]      = {0.5,  0.75, 0.25, 0.5},
    ["WARLOCK"]     = {0.75, 1,    0.25, 0.5},
    ["PALADIN"]     = {0,    0.25, 0.5,  0.75},
}

---------------------------------------------------------------------
-- Event frame
---------------------------------------------------------------------
local frame = CreateFrame("Frame", "TurtlePvPFrame")
frame:RegisterEvent("UPDATE_WORLD_STATES")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE")
frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE")
frame:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL")
frame:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("CHAT_MSG_BATTLEGROUND")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("PLAYER_DEAD")
TBGH.frame = frame

---------------------------------------------------------------------
-- Helmet auto-hide
---------------------------------------------------------------------
TBGH.HELM_AUTO_HIDE_ITEMS = {
    {id = 10588, name = "Goblin Rocket Helmet"},
    {id = 10506, name = "Deepdive Helmet"},
    {id = 10726, name = "Gnomish Mind Control Cap"},
}
local helmById = {}
for i = 1, table.getn(TBGH.HELM_AUTO_HIDE_ITEMS) do
    helmById[TBGH.HELM_AUTO_HIDE_ITEMS[i].id] = true
end
local helmAutoHideActive = false

function TBGH:CheckHelmetAutoHide()
    local db = self.db
    if not db or db.helmAutoHide ~= true then
        if helmAutoHideActive then
            ShowHelm(self._savedShowHelm ~= false)
            helmAutoHideActive = false
        end
        return
    end
    local link = GetInventoryItemLink("player", 1) -- head slot
    local shouldHide = false
    if link then
        local _, _, idStr = string.find(link, "item:(%d+):")
        local itemId = idStr and tonumber(idStr)
        if itemId and helmById[itemId] then
            local items = db.helmAutoHideItems
            if not items or items[itemId] ~= false then
                shouldHide = true
            end
        end
    end
    if shouldHide and not helmAutoHideActive then
        self._savedShowHelm = ShowingHelm()
        ShowHelm(false)
        helmAutoHideActive = true
    elseif not shouldHide and helmAutoHideActive then
        ShowHelm(self._savedShowHelm ~= false)
        helmAutoHideActive = false
    end
end

---------------------------------------------------------------------
-- Database
---------------------------------------------------------------------
if not TurtlePvPDB then TurtlePvPDB = {} end
TBGH.db = TurtlePvPDB

function TBGH:ReloadDB()
    if not TurtlePvPDB then TurtlePvPDB = {} end
    self.db = TurtlePvPDB
    local db = self.db
    -- Migrate old SavedVariable names
    if TurtlePvPPos then db.abPos = TurtlePvPPos; TurtlePvPPos = nil end
    if TurtlePvPBasePos then db.basePos = TurtlePvPBasePos; TurtlePvPBasePos = nil end
    if TurtlePvPWSGPos then db.wsgPos = TurtlePvPWSGPos; TurtlePvPWSGPos = nil end
    -- Discard old-format positions
    if db.abPos and db.abPos.point ~= "TOPLEFT" then db.abPos = nil end
    if db.wsgPos and db.wsgPos.point ~= "TOPLEFT" then db.wsgPos = nil end
    if db.basePos and db.basePos.point ~= "TOPLEFT" then db.basePos = nil end
    -- Default module enable states
    if db.abEnabled == nil then db.abEnabled = true end
    if db.abBaseDisplayEnabled == nil then db.abBaseDisplayEnabled = false end
    if db.wsgEnabled == nil then db.wsgEnabled = true end
    if db.wsgAutoAnnounce == nil then db.wsgAutoAnnounce = true end
    -- if db.autoSignup == nil    then db.autoSignup    = false end
    -- if db.autoSignupBGs == nil then db.autoSignupBGs = {[3]=true} end
    if db.totemSkip == nil then db.totemSkip = true end
end

TBGH:ReloadDB()

---------------------------------------------------------------------
-- Module registry
---------------------------------------------------------------------
function TBGH:RegisterModule(def)
    self.modules[table.getn(self.modules) + 1] = def
end

---------------------------------------------------------------------
-- Shared UI helpers
---------------------------------------------------------------------
TBGH.BTN_WIDTH = 65
TBGH.BTN_MARGIN = 8
TBGH.BTN_GAP = 4

function TBGH.CreateSmallButton(name, parent, text, width)
    local btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    btn:SetWidth(width or 65)
    btn:SetHeight(22)
    btn:SetText(text)
    btn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10)
    return btn
end

---------------------------------------------------------------------
-- Strip WoW color escape codes
---------------------------------------------------------------------
function TBGH.StripColors(s)
    if not s then return s end
    s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    return s
end

---------------------------------------------------------------------
-- Shared movable container for all BG overlays
---------------------------------------------------------------------
local container = CreateFrame("Button", "TurtlePvPContainer", UIParent)
container:SetWidth(300)
container:SetHeight(24)
container:SetFrameStrata("HIGH")
container:SetMovable(true)
container:SetClampedToScreen(true)
container:RegisterForClicks("LeftButtonUp")
container:RegisterForDrag("LeftButton")
TBGH.container = container

function TBGH.ApplyContainerPos(pos)
    pos = pos or TBGH.DEFAULT_CONTAINER_POS
    container:ClearAllPoints()
    container:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

function TBGH.SaveContainerPos()
    local left = container:GetLeft()
    local top = container:GetTop()
    if left and top then
        local db = TBGH.db
        local uiTop = UIParent:GetTop() or top
        if TBGH.containerActiveBG == "wsg" then
            db.wsgPos = { point = "TOPLEFT", relPoint = "TOPLEFT", x = left, y = top - uiTop }
        else
            db.abPos = { point = "TOPLEFT", relPoint = "TOPLEFT", x = left, y = top - uiTop }
        end
    end
end

-- Default position on load
container:SetPoint(TBGH.DEFAULT_CONTAINER_POS.point, UIParent, TBGH.DEFAULT_CONTAINER_POS.relPoint,
    TBGH.DEFAULT_CONTAINER_POS.x, TBGH.DEFAULT_CONTAINER_POS.y)

container:SetScript("OnDragStart", function()
    if IsShiftKeyDown() or (TurtlePvPSettingsFrame and TurtlePvPSettingsFrame:IsShown()) then
        container:StartMoving()
    end
end)
container:SetScript("OnDragStop", function()
    container:StopMovingOrSizing()
    TBGH.SaveContainerPos()
end)
container:SetScript("OnClick", function()
    if IsControlKeyDown() then
        local bgType = TBGH_GetBGType()
        if bgType == "ab" then
            TBGH:AnnounceAB()
        elseif bgType == "wsg" then
            TBGH:AnnounceWSG()
        end
    end
end)

container:Hide()

---------------------------------------------------------------------
-- Drag handle
---------------------------------------------------------------------
local dragHandle = CreateFrame("Button", "TurtlePvPDragHandle", container)
dragHandle:SetWidth(16)
dragHandle:SetHeight(16)
dragHandle:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
dragHandle:SetFrameStrata("HIGH")
dragHandle:SetFrameLevel(container:GetFrameLevel() + 10)
dragHandle:SetMovable(false)
dragHandle:RegisterForDrag("LeftButton")
dragHandle:EnableMouse(true)

local dragIcon = dragHandle:CreateTexture(nil, "OVERLAY")
dragIcon:SetAllPoints(dragHandle)
dragIcon:SetTexture("Interface\\WorldStateFrame\\NeutralIcon")
dragIcon:SetAlpha(0.7)

dragHandle:SetScript("OnDragStart", function()
    container:StartMoving()
end)
dragHandle:SetScript("OnDragStop", function()
    container:StopMovingOrSizing()
    TBGH.SaveContainerPos()
end)

---------------------------------------------------------------------
-- Class lookup (shared utility)
---------------------------------------------------------------------
TBGH.classCache = {}

function TBGH:GetClassByName(name)
    if not name then return nil end
    if self.classCache[name] then return self.classCache[name] end
    local numMembers = GetNumRaidMembers()
    for r = 1, numMembers do
        local rName = UnitName("raid" .. r)
        if rName == name then
            local _, engClass = UnitClass("raid" .. r)
            if engClass then self.classCache[name] = engClass end
            return engClass
        end
    end
    local numParty = GetNumPartyMembers()
    for p = 1, numParty do
        if UnitName("party" .. p) == name then
            local _, engClass = UnitClass("party" .. p)
            if engClass then self.classCache[name] = engClass end
            return engClass
        end
    end
    if UnitName("target") == name then
        local _, engClass = UnitClass("target")
        if engClass then self.classCache[name] = engClass end
        return engClass
    end
    if UnitName("mouseover") == name then
        local _, engClass = UnitClass("mouseover")
        if engClass then self.classCache[name] = engClass end
        return engClass
    end
    return nil
end

function TBGH:GetClassColorByName(name)
    local engClass = self:GetClassByName(name)
    if engClass and self.CLASS_COLORS[engClass] then
        return self.CLASS_COLORS[engClass]
    end
    return nil
end

function TBGH:GetUnitByName(name)
    if not name then return nil end
    if UnitName("target") == name then return "target" end
    if UnitName("mouseover") == name then return "mouseover" end
    local numMembers = GetNumRaidMembers()
    for r = 1, numMembers do
        if UnitName("raid" .. r) == name then return "raid" .. r end
        if UnitName("raid" .. r .. "target") == name then return "raid" .. r .. "target" end
    end
    local numParty = GetNumPartyMembers()
    for p = 1, numParty do
        if UnitName("party" .. p) == name then return "party" .. p end
        if UnitName("party" .. p .. "target") == name then return "party" .. p .. "target" end
    end
    if UnitName("targettarget") == name then return "targettarget" end
    return nil
end

---------------------------------------------------------------------
-- Nampower GUID tracker
---------------------------------------------------------------------
function TBGH:ProcessGUID(guid)
    if not guid then return end
    local name = UnitName(guid)
    if name and name ~= "Unknown" and name ~= "" then
        self.guidTracker.nameToGuid[name] = guid
        self.guidTracker.guidToName[guid] = name
    end
end

function TBGH:HarvestGUID(unit)
    if not GetUnitGUID then return end
    if not UnitExists(unit) then return end
    local guid = GetUnitGUID(unit)
    if guid then self:ProcessGUID(guid) end
end

function TBGH:GetGUID(name)
    if not name then return nil end
    return self.guidTracker.nameToGuid[name]
end

---------------------------------------------------------------------
-- Enhanced HP
---------------------------------------------------------------------
function TBGH:GetHealthPct(name)
    if self.hasNampower and GetUnitField then
        local guid = self:GetGUID(name)
        if guid then
            local hp = GetUnitField(guid, "health")
            local hpMax = GetUnitField(guid, "maxHealth")
            if hp and hpMax and hpMax > 0 then
                return math.floor(hp / hpMax * 100)
            end
        end
    end
    local unit = self:GetUnitByName(name)
    if not unit then return nil end
    local hp = UnitHealth(unit)
    local hpMax = UnitHealthMax(unit)
    if not hp or not hpMax or hpMax == 0 then return nil end
    return math.floor(hp / hpMax * 100)
end

---------------------------------------------------------------------
-- Distance
---------------------------------------------------------------------
function TBGH:GetDistance(name)
    if not UnitXP then return nil end
    if not name then return nil end
    local guid = self:GetGUID(name)
    if guid then
        local ok, dist = pcall(function() return UnitXP("distanceBetween", "player", guid) end)
        if ok and type(dist) == "number" then return math.floor(dist) end
    end
    local unit = self:GetUnitByName(name)
    if unit then
        local ok, dist = pcall(function() return UnitXP("distanceBetween", "player", unit) end)
        if ok and type(dist) == "number" then return math.floor(dist) end
    end
    return nil
end

---------------------------------------------------------------------
-- Auto-size container to fit visible content (called by AB/WSG)
---------------------------------------------------------------------
function TBGH:ResizeContainer()
    local container = self.container
    local w = 20
    local h = 0
    local overlay = self.overlay
    if overlay and overlay:IsShown() then
        local abAlliText = self.abAlliText
        local abHordeText = self.abHordeText
        local overlayText2 = self.overlayText2
        local overlayText3 = self.overlayText3
        local hasAlliText = abAlliText:GetText() and abAlliText:GetText() ~= ""
        if hasAlliText then
            h = (self.AB_SCORE_ROW_HEIGHT * 2) + 6
            local textW = math.max(abAlliText:GetStringWidth() or 0, abHordeText:GetStringWidth() or 0) + 8
            if textW > w then w = textW end
        end
        if overlayText2:GetText() and overlayText2:GetText() ~= "" then
            h = h + 14
            local etaW = (overlayText2:GetStringWidth() or 0) + 8
            if etaW > w then w = etaW end
        end
        if overlayText3:GetText() and overlayText3:GetText() ~= "" then
            h = h + 13
            local winW = (overlayText3:GetStringWidth() or 0) + 8
            if winW > w then w = winW end
        end
    end
    local wsgFrame = self.wsgFrame
    if wsgFrame and wsgFrame:IsShown() then
        local WSG_ICON_SIZE = self.WSG_ICON_SIZE
        local WSG_ROW_HEIGHT = self.WSG_ROW_HEIGHT
        local classW = WSG_ICON_SIZE + 2
        local alliHPW = (self.wsgAlliHP:GetStringWidth() or 0)
        local alliDistW = (self.wsgAlliDist:GetStringWidth() or 0)
        local alliW = WSG_ICON_SIZE + classW + 4 + (self.wsgAlliText:GetStringWidth() or 0)
        if alliHPW > 0 then alliW = alliW + 4 + alliHPW end
        if alliDistW > 0 then alliW = alliW + 4 + alliDistW end
        local hordeHPW = (self.wsgHordeHP:GetStringWidth() or 0)
        local hordeDistW = (self.wsgHordeDist:GetStringWidth() or 0)
        local hordeW = WSG_ICON_SIZE + classW + 4 + (self.wsgHordeText:GetStringWidth() or 0)
        if hordeHPW > 0 then hordeW = hordeW + 4 + hordeHPW end
        if hordeDistW > 0 then hordeW = hordeW + 4 + hordeDistW end
        local wsgW = math.max(alliW, hordeW)
        local focusW = (self.wsgFocusedText:GetStringWidth() or 0)
        if focusW > 0 then
            wsgW = wsgW + focusW + 12
        end
        if wsgW + 10 > w then w = wsgW + 10 end
        h = WSG_ROW_HEIGHT * 2 + 4
    end
    if h < 12 then h = 12 end
    container:SetWidth(w)
    container:SetHeight(h)
end
