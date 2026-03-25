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
            -- Match "EFC <color>75%|r: <name>" — our threshold announcement format
            local _, _, pctStr = string.find(msg, "EFC [^\n]*(%d+)%%")
            local pct = pctStr and tonumber(pctStr)
            if pct then
                local thresh = nil
                if pct <= 25 then thresh = 25
                elseif pct <= 50 then thresh = 50
                elseif pct <= 75 then thresh = 75
                end
                if thresh then
                    TBGH.wsg.efcAnnounceSeenAt[thresh] = GetTime()
                end
            elseif string.find(msg, "^EFC:") then
                TBGH.wsg.efcManualSeenAt = GetTime()
            end
        end

    elseif event == "UNIT_COMBAT" then
        if arg1 == "player" then
            if TBGH.db and TBGH.db.recapDebug then
                TBGH:RecapAddLog(
                    "[RecapDebug] UNIT_COMBAT arg2=" .. tostring(arg2) ..
                    " arg3=" .. tostring(arg3) ..
                    " arg4=" .. tostring(arg4) ..
                    " arg5=" .. tostring(arg5))
            end
            TBGH:RecapOnUnitCombat(arg2, arg3, arg4, arg5)
        end

    elseif event == "CHAT_MSG_COMBAT_SELF_HITS"
        or event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS"
        or event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS" then
        TBGH:RecapEnrichFromChat(arg1, "melee")

    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE"
        or event == "CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"
        or event == "CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE"
        or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"
        or event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"
        or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
        TBGH:RecapEnrichFromChat(arg1, "spell")

    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            TBGH:RecapCheckCC()
        end

    elseif event == "PLAYER_DEAD" then
        TBGH:ScanBattlefieldScores()  -- grab classes from scoreboard before building recap
        TBGH:RecapOnDead()
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

    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        TBGH:ScanBattlefieldScores()

    elseif event == "VARIABLES_LOADED" then
        TBGH:ReloadDB()
        db = TBGH.db
        -- missingIcons is already on TBGH.db via ReloadDB init
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
        TBGH:ScanBattlefieldScores()  -- may already have scores if we zoned in mid-game
        TBGH:RecapReset()
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
