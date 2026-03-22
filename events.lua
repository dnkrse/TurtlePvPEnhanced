-- TurtlePvP: events.lua — OnEvent + OnUpdate handlers (module dispatch)

local frame = TBGH.frame
local container = TBGH.container

---------------------------------------------------------------------
-- Event handler
---------------------------------------------------------------------
frame:SetScript("OnEvent", function()
    local db = TBGH.db
    local bgType = TBGH_GetBGType()
    local modules = TBGH.modules
    local nMod = table.getn(modules)

    if event == "UPDATE_WORLD_STATES" then
        for i = 1, nMod do
            local mod = modules[i]
            if mod.onWorldStates and (not mod.bgType or mod.bgType == bgType) then
                mod.onWorldStates()
            end
        end

    elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"
        or event == "CHAT_MSG_BG_SYSTEM_HORDE"
        or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL"
        or event == "CHAT_MSG_RAID_BOSS_EMOTE" then
        for i = 1, nMod do
            local mod = modules[i]
            if mod.onBGMessage and (not mod.bgType or mod.bgType == bgType) then
                mod.onBGMessage(arg1, event)
            end
        end

    elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
        -- Core: totem skip
        if event == "PLAYER_TARGET_CHANGED" and db.totemSkip ~= false and not TBGH.totemSkipping then
            if UnitExists("target") and not UnitIsPlayer("target") then
                local ctype = UnitCreatureType("target")
                local tname = UnitName("target") or ""
                if ctype == "Totem" or string.find(tname, "Totem") then
                    TBGH.totemSkipping = true
                    for i = 1, TBGH.MAX_TOTEM_SKIPS do
                        TargetNearestEnemy()
                        if not UnitExists("target") or UnitIsPlayer("target") then break end
                        local ct2 = UnitCreatureType("target")
                        local tn2 = UnitName("target") or ""
                        if ct2 ~= "Totem" and not string.find(tn2, "Totem") then break end
                    end
                    TBGH.totemSkipping = false
                    return
                end
            end
        end
        -- Core: GUID harvest
        local unit = (event == "PLAYER_TARGET_CHANGED") and "target" or "mouseover"
        TBGH:HarvestGUID(unit)
        if event == "PLAYER_TARGET_CHANGED" then
            TBGH:HarvestGUID("targettarget")
        end
        -- Dispatch to modules
        for i = 1, nMod do
            local mod = modules[i]
            if mod.onTargetChanged and (not mod.bgType or mod.bgType == bgType) then
                mod.onTargetChanged(unit, event)
            end
        end

    elseif event == "CHAT_MSG_BATTLEGROUND" then
        -- Dedup EFC announcements from other addon users
        local db = TBGH.db
        local msg = arg1
        if db.wsgAutoAnnounce ~= false and db.wsgDedup ~= false and msg and string.find(msg, "EFC") then
            if string.find(msg, "EFC LOW") then
                local _, _, pctStr = string.find(msg, "(%d+)%%")
                local pct = pctStr and tonumber(pctStr)
                if pct then
                    local thresh = nil
                    if pct <= 20 then thresh = 20
                    elseif pct <= 40 then thresh = 40
                    end
                    if thresh then
                        TBGH.wsg.efcAnnounceSeenAt[thresh] = GetTime()
                    end
                end
            elseif string.find(msg, "^EFC:") then
                TBGH.wsg.efcManualSeenAt = GetTime()
            end
        end

    elseif event == "PLAYER_DEAD" then
        if db.autoRelease and TBGH_GetBGType() then
            RepopMe()
        end

    elseif event == "UNIT_INVENTORY_CHANGED" then
        if arg1 == "player" then
            TBGH:CheckHelmetAutoHide()
        end

    elseif event == "UNIT_HEALTH_GUID" or event == "UNIT_AURA_GUID" then
        TBGH:ProcessGUID(arg1)
    elseif event == "SPELL_START_OTHER" then
        TBGH:ProcessGUID(arg3)

    elseif event == "VARIABLES_LOADED" then
        TBGH:ReloadDB()
        db = TBGH.db
        TBGH.hasNampower = (GetNampowerVersion ~= nil)
        TBGH.hasUnitXP = (UnitXP ~= nil)
        if TBGH.hasNampower then
            frame:RegisterEvent("UNIT_HEALTH_GUID")
            frame:RegisterEvent("UNIT_AURA_GUID")
            frame:RegisterEvent("SPELL_START_OTHER")
        end
        if TBGH.UpdateMinimapBtnPos then
            TBGH.UpdateMinimapBtnPos(db.minimapAngle or 225)
        end
        for i = 1, nMod do
            local mod = modules[i]
            if mod.onVariablesLoaded then mod.onVariablesLoaded() end
        end
        TBGH:CheckHelmetAutoHide()

    elseif event == "PLAYER_ENTERING_WORLD" then
        TBGH.containerActiveBG = nil
        -- Reset ALL modules (regardless of current zone)
        for i = 1, nMod do
            local mod = modules[i]
            if mod.reset then mod.reset() end
        end
        -- Notify matching modules
        bgType = TBGH_GetBGType()
        for i = 1, nMod do
            local mod = modules[i]
            if mod.onEnterWorld and (not mod.bgType or mod.bgType == bgType) then
                mod.onEnterWorld()
            end
        end
    end
end)

---------------------------------------------------------------------
-- OnUpdate — dispatch to matching modules
---------------------------------------------------------------------
frame:SetScript("OnUpdate", function()
    local bgType = TBGH_GetBGType()
    local modules = TBGH.modules
    local elapsed = arg1
    for i = 1, table.getn(modules) do
        local mod = modules[i]
        if mod.onUpdate and (not mod.bgType or mod.bgType == bgType) then
            mod.onUpdate(elapsed)
        end
    end
end)
