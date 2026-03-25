-- TurtlePvP: commands.lua — Slash commands, auto-signup system, copy frame

---------------------------------------------------------------------
-- BG test frame (monitors queue status after signup attempts)
---------------------------------------------------------------------
local bgTestFrame = CreateFrame("Frame", "TurtlePvPBGTestFrame")
bgTestFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
bgTestFrame:SetScript("OnEvent", function()
    if not TBGH._bgTestActive then return end
    TBGH._bgTestActive = nil
    for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
        local status = GetBattlefieldStatus(i)
        if status and status ~= "none" then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff00ff00[TurtlePvPEnhanced]|r Queue slot " .. i ..
                " status='" .. status .. "' -> last arg was: " ..
                tostring(TBGH._bgTestLastArg))
        end
    end
end)

---------------------------------------------------------------------
-- BG menu function harvester
---------------------------------------------------------------------
local BG_MENU_NAMES = { [3]="Warsong Gulch", [4]="Arathi Basin", [5]="Alterac Valley", [6]="Sunnyglade Valley" }

local function GetBGMenuFuncs()
    local buildFn  = _G["BuildTWBGQueueMenu"]
    local menuFrame = _G["TWBGQueueMinimapMenuFrame"]
    if not buildFn then return nil end
    local funcs = {}
    local origAdd = UIDropDownMenu_AddButton
    UIDropDownMenu_AddButton = function(info, level)
        funcs[table.getn(funcs) + 1] = info and info.func or nil
    end
    buildFn(menuFrame)
    UIDropDownMenu_AddButton = origAdd
    return funcs
end

---------------------------------------------------------------------
-- Auto-signup timer frame (disabled — re-enable when feature is ready)
---------------------------------------------------------------------
--[[
local autoSignupFrame = CreateFrame("Frame", "TurtlePvPAutoSignupFrame")
autoSignupFrame._nextTry    = 0
autoSignupFrame._pendingBGs = nil
autoSignupFrame._state      = "idle"
autoSignupFrame._stateDeadline = 0
TBGH.autoSignupFrame = autoSignupFrame

autoSignupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
autoSignupFrame:SetScript("OnEvent", function()
    autoSignupFrame._nextTry = GetTime() + 5
end)

-- Possible join frame names used by Turtle WoW's BG system
local BF_FRAME_CANDIDATES = {
    "BattlefieldFrame",
    "TWBGQueueJoinFrame",
    "TWBGQueueFrame",
    "TWBGBattlefieldFrame",
}
local function FindVisibleBFFrame()
    for _, name in ipairs(BF_FRAME_CANDIDATES) do
        local f = _G[name]
        if f and f:IsShown() then return f, name end
    end
    return nil, nil
end

local function ScanForBFFrame()
    local found = {}
    for name, obj in pairs(_G) do
        if type(name) == "string" and type(obj) == "table" then
            local ok, shown = pcall(function() return obj.IsShown and obj:IsShown() end)
            if ok and shown then
                local ln = string.lower(name)
                if string.find(ln, "battlefield") or string.find(ln, "twbg") or string.find(ln, "bgqueue") then
                    found[table.getn(found)+1] = name
                end
            end
        end
    end
    return found
end

autoSignupFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    local db = TBGH.db

    -- State: waiting for a BG join frame to become visible, then click Join
    if autoSignupFrame._state == "waiting_frame" then
        local maxS = MAX_BATTLEFIELD_QUEUES or 3

        for i = 1, maxS do
            local status = GetBattlefieldStatus(i)
            local prev   = autoSignupFrame._statusBefore and autoSignupFrame._statusBefore[i]
            if status ~= prev and (status == "queued" or status == "confirm" or status == "active") then
                autoSignupFrame._state        = "idle"
                autoSignupFrame._stateDeadline = 0
                autoSignupFrame._nextCallTime  = now + 0.6
                autoSignupFrame._queuedNames = autoSignupFrame._queuedNames or {}
                autoSignupFrame._queuedNames[table.getn(autoSignupFrame._queuedNames)+1] = autoSignupFrame._currentBGName
                return
            end
        end

        local bf, bfName = FindVisibleBFFrame()
        if bf then
            local joinBtn = _G[bfName .. "JoinButton"] or _G["BattlefieldFrameJoinButton"]
            if joinBtn and joinBtn:IsEnabled() then joinBtn:Click() end
            bf:Hide()
            autoSignupFrame._state        = "idle"
            autoSignupFrame._stateDeadline = 0
            autoSignupFrame._nextCallTime  = now + 0.6
            autoSignupFrame._queuedNames = autoSignupFrame._queuedNames or {}
            autoSignupFrame._queuedNames[table.getn(autoSignupFrame._queuedNames)+1] = autoSignupFrame._currentBGName
            if bfName ~= BF_FRAME_CANDIDATES[1] then
                BF_FRAME_CANDIDATES[1] = bfName
            end
        elseif now > autoSignupFrame._stateDeadline then
            local hits = ScanForBFFrame()
            if table.getn(hits) > 0 then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffff4444[TurtlePvPEnhanced]|r Auto-signup: join frame not found, but these BG frames are visible: " ..
                    table.concat(hits, ", ") .. " -- report this so the addon can be updated")
            else
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffff4444[TurtlePvPEnhanced]|r Auto-signup: no join frame appeared for " ..
                    tostring(autoSignupFrame._currentBGName))
            end
            autoSignupFrame._state        = "idle"
            autoSignupFrame._nextCallTime = now + 0.6
        end
        return
    end

    -- Drain pending BG list
    if autoSignupFrame._pendingBGs and table.getn(autoSignupFrame._pendingBGs) > 0 then
        if now < (autoSignupFrame._nextCallTime or 0) then return end

        local entry = table.remove(autoSignupFrame._pendingBGs, 1)
        if entry then
            autoSignupFrame._currentBGName = entry.name
            autoSignupFrame._statusBefore = {}
            for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
                autoSignupFrame._statusBefore[i] = GetBattlefieldStatus(i)
            end
            local savThis = this
            this = _G["DropDownList1Button" .. tostring(entry.menuIdx)]
                   or _G["TWBGQueueMinimapMenuFrame"]
                   or this
            entry.fn()
            this = savThis

            autoSignupFrame._state         = "waiting_frame"
            autoSignupFrame._stateDeadline = now + 3.0
        end
        return
    end

    -- After all pending done, print summary
    if autoSignupFrame._state == "idle"
       and autoSignupFrame._queuedNames
       and table.getn(autoSignupFrame._queuedNames) > 0
       and now >= (autoSignupFrame._nextCallTime or 0) then
        local names = ""
        for i, n in ipairs(autoSignupFrame._queuedNames) do
            names = names .. (i > 1 and ", " or "") .. n
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Auto-signup: queued for " .. names)
        autoSignupFrame._queuedNames = nil
    end

    if not db.autoSignup then return end
    if now < autoSignupFrame._nextTry then return end
    autoSignupFrame._nextTry = now + 30

    local usedSlots = 0
    local maxSlots  = MAX_BATTLEFIELD_QUEUES or 3
    for i = 1, maxSlots do
        local status = GetBattlefieldStatus(i)
        if status == "active" then return end
        if status and status ~= "none" then
            usedSlots = usedSlots + 1
        end
    end
    if usedSlots >= maxSlots then return end

    local funcs = GetBGMenuFuncs()
    if not funcs then return end

    local pending = {}
    for idx, enabled in pairs(db.autoSignupBGs or {}) do
        if enabled and usedSlots < maxSlots then
            local fn = funcs[idx]
            if fn then
                pending[table.getn(pending) + 1] = { fn = fn, name = BG_MENU_NAMES[idx] or ("BG#"..idx), menuIdx = idx }
                usedSlots = usedSlots + 1
            end
        end
    end

    if table.getn(pending) > 0 then
        autoSignupFrame._pendingBGs   = pending
        autoSignupFrame._nextCallTime = now
        autoSignupFrame._queuedNames  = nil
    end
end)
--]]

---------------------------------------------------------------------
-- Copy frame (popup EditBox for Ctrl+A / Ctrl+C)
---------------------------------------------------------------------
local _tbgCopyFrame = nil
local function TBG_ShowCopyBox(titleText, bodyText)
    if not _tbgCopyFrame then
        local f = CreateFrame("Frame", "TurtlePvPCopyFrame", UIParent)
        f:SetWidth(540)
        f:SetHeight(110)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
        f._lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f._lbl:SetPoint("TOP", f, "TOP", 0, -14)
        local eb = CreateFrame("EditBox", "TurtlePvPCopyEditBox", f)
        eb:SetPoint("TOPLEFT",     f, "TOPLEFT",     14, -34)
        eb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14,  12)
        eb:SetFontObject(ChatFontNormal)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        f._eb = eb
        _tbgCopyFrame = f
    end
    _tbgCopyFrame._lbl:SetText(titleText)
    _tbgCopyFrame._eb:SetText(bodyText)
    _tbgCopyFrame._eb:HighlightText()
    _tbgCopyFrame:Show()
end

---------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------
SLASH_TBG1 = "/tbg"
SLASH_TBG2 = "/turtlebg"
SlashCmdList["TBG"] = function() TBGH:Estimate() end

SLASH_TBGDEBUG1 = "/tbgdebug"
SlashCmdList["TBGDEBUG"] = function() TBGH:Debug() end

SLASH_TBGWSG1 = "/tbgwsg"
SlashCmdList["TBGWSG"] = function()
    local msg = DEFAULT_CHAT_FRAME
    local ac = TBGH.wsg.alliCarrier
    local hc = TBGH.wsg.hordeCarrier
    msg:AddMessage("|cffffff00========= WSG Flag Status =========|r")
    if hc then
        msg:AddMessage(string.format("|cff3399ffAlliance Flagcarrier:|r |cff3399ff%s|r", hc))
    else
        msg:AddMessage("|cff3399ffAlliance Flagcarrier:|r none")
    end
    if ac then
        msg:AddMessage(string.format("|cffff3333Horde Flagcarrier:|r |cffff3333%s|r", ac))
    else
        msg:AddMessage("|cffff3333Horde Flagcarrier:|r none")
    end
    msg:AddMessage("|cffffff00======================================|r")
end

SLASH_TBGWSGDEBUG1 = "/tbgwsgdebug"
SlashCmdList["TBGWSGDEBUG"] = function()
    TBGH.wsgDebug = not TBGH.wsgDebug
    if TBGH.wsgDebug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r WSG message debug ON — pick up a flag to see messages")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r WSG message debug OFF")
    end
end

SLASH_TBGSIGNUP1 = "/tbgsignup"
SlashCmdList["TBGSIGNUP"] = function(arg)
    arg = arg and string.gsub(arg, "^%s*(.-)%s*$", "%1") or ""

    local joinFn = _G["JoinBattleground"]
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00ff00[TurtlePvPEnhanced]|r JoinBattleground type: " .. type(joinFn))

    if arg == "" then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff00ff00[TurtlePvPEnhanced]|r Usage: /tbgsignup <id>  -- try: 1  2  3")
        local found = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and (
                string.find(string.lower(k), "battleground") or
                string.find(string.lower(k), "joinbg") or
                string.find(string.lower(k), "bgqueue")
            ) then
                found[table.getn(found) + 1] = k .. " (" .. type(v) .. ")"
            end
        end
        if table.getn(found) > 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Matching globals (" .. table.getn(found) .. "):")
            for _, s in ipairs(found) do
                DEFAULT_CHAT_FRAME:AddMessage("  " .. s)
            end
            TBG_ShowCopyBox(
                "BG Globals — Ctrl+A then Ctrl+C to copy",
                table.concat(found, " | "))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvPEnhanced]|r No battleground globals found. Click the BG Finder button first, then retry.")
        end
        return
    end

    if not joinFn then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff4444[TurtlePvPEnhanced]|r JoinBattleground is nil. Click the BG Finder button once first, then try again.")
        return
    end

    local callArg = tonumber(arg) or arg
    TBGH._bgTestActive = true
    TBGH._bgTestLastArg = callArg
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00ff00[TurtlePvPEnhanced]|r Calling JoinBattleground(" .. tostring(callArg) .. ") ...")
    joinFn(callArg)
end

-- Remove old hook frame if present
if TBGH._hookFrame then
    TBGH._hookFrame:UnregisterAllEvents()
    TBGH._hookFrame = nil
end
TBGH._sendHooked = nil

---------------------------------------------------------------------
-- /tbgmenu — capture BG menu items
---------------------------------------------------------------------
TBGH._menuFuncs = TBGH._menuFuncs or {}

SLASH_TBGMENU1 = "/tbgmenu"
SlashCmdList["TBGMENU"] = function()
    local buildFn = _G["BuildTWBGQueueMenu"]
    local menuFrame = _G["TWBGQueueMinimapMenuFrame"]
    if not buildFn then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvPEnhanced]|r BuildTWBGQueueMenu not found.")
        return
    end

    TBGH._menuFuncs = {}
    local captured = {}
    local origAdd = UIDropDownMenu_AddButton
    UIDropDownMenu_AddButton = function(info, level)
        local text  = (info and info.text)  or "(nil)"
        local func  = (info and info.func)  or nil
        local value = (info and info.value) or "(nil)"
        local idx   = table.getn(captured) + 1
        captured[idx] = "text='" .. tostring(text) ..
                        "'  value='" .. tostring(value) ..
                        "'  func=" .. type(func)
        TBGH._menuFuncs[idx] = { text = text, func = func }
        if origAdd then origAdd(info, level) end
    end

    buildFn(menuFrame)
    UIDropDownMenu_AddButton = origAdd

    local n = table.getn(captured)
    if n == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvPEnhanced]|r BuildTWBGQueueMenu added 0 items.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Captured " .. n .. " menu items. Use /tbgqueue <n> to call one:")
        for i, s in ipairs(captured) do
            DEFAULT_CHAT_FRAME:AddMessage("  [" .. i .. "] " .. s)
        end
    end
end

---------------------------------------------------------------------
-- /tbgqueue <n> — call nth menu item's func
---------------------------------------------------------------------
SLASH_TBGQUEUE1 = "/tbgqueue"
SlashCmdList["TBGQUEUE"] = function(arg)
    arg = arg and string.gsub(arg, "^%s*(.-)%s*$", "%1") or ""
    local idx = tonumber(arg)
    if not idx then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvPEnhanced]|r Usage: /tbgqueue <n>  (run /tbgmenu first to see numbers)")
        return
    end
    local entry = TBGH._menuFuncs and TBGH._menuFuncs[idx]
    if not entry or not entry.func then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvPEnhanced]|r No function at index " .. idx .. ". Run /tbgmenu first.")
        return
    end

    local before = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "table" then
            local ok, shown = pcall(function() return v.IsShown and v:IsShown() end)
            if ok and shown then before[k] = true end
        end
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Calling menu func [" .. idx .. "] = " .. tostring(entry.text))
    TBGH._bgTestActive  = true
    TBGH._bgTestLastArg = entry.text
    entry.func()

    local newShown = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "table" and not before[k] then
            local ok, shown = pcall(function() return v.IsShown and v:IsShown() end)
            if ok and shown then
                newShown[table.getn(newShown) + 1] = k
            end
        end
    end
    if table.getn(newShown) > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Newly shown frames:")
        local parts = {}
        for i, s in ipairs(newShown) do
            DEFAULT_CHAT_FRAME:AddMessage("  " .. s)
            parts[i] = s
        end
        TBG_ShowCopyBox("Newly shown frames — Ctrl+A Ctrl+C", table.concat(parts, " | "))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvPEnhanced]|r No new frames appeared. Scanning TWBG/queue globals:")
        local found = {}
        for k, v in pairs(_G) do
            if type(k) == "string" and (
                string.find(string.lower(k), "twbg") or
                string.find(string.lower(k), "bgqueue") or
                string.find(string.lower(k), "signup") or
                string.find(string.lower(k), "joinbg") or
                string.find(string.lower(k), "battlefieldframe") or
                string.find(string.lower(k), "pvpready")
            ) then
                found[table.getn(found) + 1] = k .. " (" .. type(v) .. ")"
            end
        end
        if table.getn(found) > 0 then
            local parts = {}
            for i, s in ipairs(found) do
                DEFAULT_CHAT_FRAME:AddMessage("  " .. s)
                parts[i] = s
            end
            TBG_ShowCopyBox("TWBG/queue globals — Ctrl+A Ctrl+C", table.concat(parts, " | "))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[TurtlePvPEnhanced]|r No matching globals found either.")
        end
    end
end

---------------------------------------------------------------------
-- /tbgmap — dump map landmarks
---------------------------------------------------------------------
SLASH_TBGMAP1 = "/tbgmap"
SlashCmdList["TBGMAP"] = function()
    local msg = DEFAULT_CHAT_FRAME
    local stateNames = { [0]="Neutral", [1]="Alli Assault", [2]="Alli Controlled", [3]="Horde Assault", [4]="Horde Controlled" }
    SetMapToCurrentZone()
    local n = GetNumMapLandmarks()
    msg:AddMessage("|cffffff00== TurtlePvP Map Landmarks (" .. n .. " entries) ==|r")
    for i = 1, n do
        local name, desc, texIdx, x, y = GetMapLandmarkInfo(i)
        local matched = (name and TBGH.LANDMARK_TO_BASE[name]) and "YES" or "NO"
        local ti = tonumber(texIdx)
        local decoded = ti and (stateNames[math.mod(ti - 1, 5)] or "?") or "?"
        msg:AddMessage(string.format(
            "  [%d] name='%s'  texIdx=%s -> %s  desc='%s'  x=%.3f  y=%.3f",
            i, tostring(name), tostring(texIdx), decoded, tostring(desc), x or 0, y or 0))
    end
end

---------------------------------------------------------------------
-- /tbgsettings — toggle settings panel
---------------------------------------------------------------------
SLASH_TBGSETTINGS1 = "/tbgsettings"
SlashCmdList["TBGSETTINGS"] = function()
    if TurtlePvPSettingsFrame:IsShown() then
        TurtlePvPSettingsFrame:Hide()
    else
        TurtlePvPSettingsFrame:Show()
    end
end

---------------------------------------------------------------------
-- Master command: /tpvp <subcommand>
---------------------------------------------------------------------
SLASH_TPVP1 = "/tpvp"
SlashCmdList["TPVP"] = function(msg)
    local db = TBGH.db
    local sub = string.lower(msg or "")
    sub = string.gsub(sub, "^%s+", "")
    sub = string.gsub(sub, "%s+$", "")

    if sub == "totems" then
        db.totemSkip = not (db.totemSkip ~= false)
        if db.totemSkip then
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Totem Tab-skip |cff00ff00ON|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Totem Tab-skip |cffff4444OFF|r")
        end

    elseif sub == "totemtest" then
        local m = DEFAULT_CHAT_FRAME
        m:AddMessage("|cffffff00===== TurtlePvP Totem Debug =====")
        m:AddMessage("  db.totemSkip = " .. tostring(db.totemSkip))
        m:AddMessage("  totemSkipping = " .. tostring(TBGH.totemSkipping))
        m:AddMessage("  MAX_TOTEM_SKIPS = " .. tostring(TBGH.MAX_TOTEM_SKIPS))
        if UnitExists("target") then
            local tname = UnitName("target") or "nil"
            local ctype = UnitCreatureType("target") or "nil"
            local isPlayer = UnitIsPlayer("target") and "true" or "false"
            local nameMatch = string.find(tname, "Totem") and "YES" or "no"
            m:AddMessage("  Target name: " .. tname)
            m:AddMessage("  CreatureType: " .. ctype)
            m:AddMessage("  IsPlayer: " .. isPlayer)
            m:AddMessage("  Name contains 'Totem': " .. nameMatch)
            if ctype == "Totem" or string.find(tname, "Totem") then
                m:AddMessage("|cff00ff00  -> Would be SKIPPED|r")
            else
                m:AddMessage("|cffff4444  -> Would NOT be skipped|r")
            end
        else
            m:AddMessage("  No target")
        end
        m:AddMessage("|cffffff00================================|r")

    elseif sub == "settings" then
        if TurtlePvPSettingsFrame:IsShown() then
            TurtlePvPSettingsFrame:Hide()
        else
            TurtlePvPSettingsFrame:Show()
        end

    elseif sub == "recap" then
        if TBGH.lastRecap then
            TBGH:ShowRecapFrame()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r No death recap recorded yet.")
        end

    elseif sub == "recapdebug" then
        TBGH.db.recapDebug = not TBGH.db.recapDebug
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Recap UNIT_COMBAT debug: " ..
            (TBGH.db.recapDebug and "|cff00ff00ON|r (take damage to see args)" or "|cffff4444OFF|r"))

    elseif sub == "missingicons" then
        TBGH:ShowMissingIconsFrame()

    elseif sub == "clearicons" then
        for k in pairs(TBGH.db.missingIcons or {}) do TBGH.db.missingIcons[k] = nil end
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Missing icons list cleared.")

    elseif sub == "exportlog" then
        TBGH:ShowRecapExportFrame()

    elseif sub == "recapmock" then
        -- Build a fake death snapshot to preview the recap UI without dying
        local t = GetTime()
        -- Brutahk (Paladin): Physical + Holy — warm family
        local e1a = { time=t-9.5, amount=580, overkill=0,  school="Physical", hitType="crit",  attacker="Brutahk",  class="PALADIN", spell="Seal of Command", enriched=true, isCC=false }
        local e1b = { time=t-8.8, amount=320, overkill=0,  school="Holy",     hitType="crit",  attacker="Brutahk",  class="PALADIN", spell="Holy Shock",      enriched=true, isCC=false }
        local e1c = { time=t-8.1, amount=210, overkill=0,  school="Physical", hitType="hit",   attacker="Brutahk",  class="PALADIN", spell="Crusader Strike",  enriched=true, isCC=false }
        -- Frostina (Mage): Fire + Frost + Arcane
        local e2a = { time=t-7.5, amount=445, overkill=0,  school="Fire",     hitType="crit",  attacker="Frostina", class="MAGE",    spell="Fireball",        enriched=true, isCC=false }
        local e2b = { time=t-6.8, amount=390, overkill=0,  school="Frost",    hitType="crit",  attacker="Frostina", class="MAGE",    spell="Frostbolt",       enriched=true, isCC=false }
        local e2c = { time=t-6.0, amount=178, overkill=0,  school="Arcane",   hitType="hit",   attacker="Frostina", class="MAGE",    spell="Arcane Missiles", enriched=true, isCC=false }
        -- Sneakius (Warlock): Shadow + Nature
        local e3a = { time=t-5.2, amount=512, overkill=0,  school="Shadow",   hitType="crit",  attacker="Sneakius", class="WARLOCK", spell="Shadow Bolt",     enriched=true, isCC=false }
        local e3b = { time=t-4.5, amount=198, overkill=0,  school="Nature",   hitType="hit",   attacker="Sneakius", class="WARLOCK", spell="Corruption",      enriched=true, isCC=false }
        local e3c = { time=t-3.8, amount=264, overkill=0,  school="Shadow",   hitType="hit",   attacker="Sneakius", class="WARLOCK", spell="Drain Life",      enriched=true, isCC=false }
        -- Grimtusk (Hunter): Physical (melee + ranged)
        local e4a = { time=t-3.2, amount=310, overkill=0,  school="Physical", hitType="crit",  attacker="Grimtusk", class="HUNTER",  spell="Aimed Shot",      enriched=true, isCC=false }
        local e4b = { time=t-2.7, amount=160, overkill=0,  school="Physical", hitType="hit",   attacker="Grimtusk", class="HUNTER",  spell="Auto Shot",       enriched=true, isCC=false }
        -- Vexara (Priest): Holy + Shadow
        local e5a = { time=t-2.2, amount=280, overkill=0,  school="Shadow",   hitType="crit",  attacker="Vexara",   class="PRIEST",  spell="Mind Blast",      enriched=true, isCC=false }
        local e5b = { time=t-1.7, amount=145, overkill=0,  school="Holy",     hitType="hit",   attacker="Vexara",   class="PRIEST",  spell="Smite",           enriched=true, isCC=false }
        -- Stormrage (Druid): Nature + Arcane (overkill)
        local e6a = { time=t-1.3, amount=220, overkill=0,  school="Nature",   hitType="hit",   attacker="Stormrage",class="DRUID",   spell="Wrath",           enriched=true, isCC=false }
        local e6b = { time=t-0.8, amount=305, overkill=180,school="Arcane",   hitType="crit",  attacker="Stormrage",class="DRUID",   spell="Starfire",        enriched=true, isCC=false }
        -- Zapthorn (Shaman): Fire (Searing Totem) + Nature — totem icon preview
        local e7a = { time=t-4.2, amount=88,  overkill=0,  school="Fire",     hitType="hit",   attacker="Zapthorn",  class="SHAMAN",  spell="Searing Bolt",    enriched=true, isCC=false }
        local e7b = { time=t-3.9, amount=74,  overkill=0,  school="Fire",     hitType="hit",   attacker="Zapthorn",  class="SHAMAN",  spell="Searing Bolt",    enriched=true, isCC=false }
        local e7c = { time=t-3.6, amount=102, overkill=0,  school="Nature",   hitType="crit",  attacker="Zapthorn",  class="SHAMAN",  spell="Lightning Bolt",  enriched=true, isCC=false }

        local eCC = { time=t-3.5, isCC=true, ccName="Cheap Shot", ccEnd=t-3.5+3.2, attacker="Sneakius" }

        local grpB  = { total = e1a.amount+e1b.amount+e1c.amount, hits = {e1a,e1b,e1c} }
        local grpF  = { total = e2a.amount+e2b.amount+e2c.amount, hits = {e2a,e2b,e2c} }
        local grpS  = { total = e3a.amount+e3b.amount+e3c.amount, hits = {e3a,e3b,e3c} }
        local grpG  = { total = e4a.amount+e4b.amount,            hits = {e4a,e4b}     }
        local grpV  = { total = e5a.amount+e5b.amount,            hits = {e5a,e5b}     }
        local grpD  = { total = e6a.amount+e6b.amount,            hits = {e6a,e6b}     }
        local grpZ  = { total = e7a.amount+e7b.amount+e7c.amount, hits = {e7a,e7b,e7c} }

        -- Seed mock BG scores so the stat line is visible in the preview
        TBGH.bgScoreCache = TBGH.bgScoreCache or {}
        TBGH.bgScoreCache["Brutahk"]   = { kbs=4, deaths=1, hks=18, rank=9,  faction=1 }
        TBGH.bgScoreCache["Frostina"]  = { kbs=2, deaths=3, hks=11, rank=6,  faction=0 }
        TBGH.bgScoreCache["Sneakius"]  = { kbs=7, deaths=0, hks=25, rank=11, faction=1 }
        TBGH.bgScoreCache["Grimtusk"]  = { kbs=1, deaths=2, hks=8,  rank=3,  faction=1 }
        TBGH.bgScoreCache["Vexara"]    = { kbs=0, deaths=4, hks=5,  rank=1,  faction=0 }
        TBGH.bgScoreCache["Stormrage"] = { kbs=3, deaths=1, hks=14, rank=7,  faction=0 }
        TBGH.bgScoreCache["Zapthorn"]  = { kbs=1, deaths=2, hks=7,  rank=4,  faction=1 }

        TBGH.lastRecap = {
            snapshot       = {e1a,e1b,e1c,e2a,e2b,e2c,eCC,e3a,e3b,e3c,e4a,e4b,e5a,e5b,e6a,e6b,e7a,e7b,e7c},
            attackerOrder  = {"Brutahk","Frostina","Sneakius","Grimtusk","Vexara","Stormrage","Zapthorn"},
            attackerGroups = { ["Brutahk"]=grpB, ["Frostina"]=grpF, ["Sneakius"]=grpS,
                               ["Grimtusk"]=grpG, ["Vexara"]=grpV, ["Stormrage"]=grpD,
                               ["Zapthorn"]=grpZ },
            attackerClass  = { ["Brutahk"]="PALADIN", ["Frostina"]="MAGE", ["Sneakius"]="WARLOCK",
                               ["Grimtusk"]="HUNTER", ["Vexara"]="PRIEST", ["Stormrage"]="DRUID",
                               ["Zapthorn"]="SHAMAN" },
            totalDamage    = grpB.total+grpF.total+grpS.total+grpG.total+grpV.total+grpD.total+grpZ.total,
            overkill       = 180,
            killingEntry   = e6b,
            maxHP          = UnitHealthMax("player") or 3500,
            stunTotal      = 3.2,
            incTotal       = 0,
            rootTotal      = 0,
        }
        TBGH:ShowRecapFrame()

    elseif sub == "mockup" then
        -- Alias for recapmock
        TBGH:ShowMockupRecap()

    else
        local m = DEFAULT_CHAT_FRAME
        m:AddMessage("|cff00ff00[TurtlePvPEnhanced]|r Commands:")
        m:AddMessage("  |cffffff00/tpvp settings|r     — open settings panel")
        m:AddMessage("  |cffffff00/tpvp totems|r       — toggle totem Tab-skip on/off")
        m:AddMessage("  |cffffff00/tpvp totemtest|r    — debug: show totem detection for current target")
        m:AddMessage("  |cffffff00/tpvp recap|r        — re-open last death recap")
        m:AddMessage("  |cffffff00/tpvp recapmock|r    — preview recap UI with fake data (alias: mockup)")
        m:AddMessage("  |cffffff00/tpvp mockup|r       — preview recap UI with fake data")
        m:AddMessage("  |cffffff00/tpvp recapdebug|r   — toggle UNIT_COMBAT arg logging")
        m:AddMessage("  |cffffff00/tpvp exportlog|r    — open copyable debug log window")
    end
end

---------------------------------------------------------------------
-- Loaded message
---------------------------------------------------------------------
DEFAULT_CHAT_FRAME:AddMessage(
    "|cff00ff00[TurtlePvPEnhanced]|r Loaded — /tpvp (help), /tbg (AB), /tbgwsg (WSG flags), /tbgsettings, /tbgdebug")
