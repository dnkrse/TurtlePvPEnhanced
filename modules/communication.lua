-- TurtlePvP: communication.lua — Chat & communication utilities

---------------------------------------------------------------------
-- BG chat redirect
-- When inside an active battleground, re-opens the chat box in
-- /bg instead of whatever channel was used last (e.g. /say).
-- Only redirects world/local channel types; intentional choices
-- (PARTY, RAID, GUILD, OFFICER, WHISPER, CHANNEL) are left alone.
---------------------------------------------------------------------
-- Channels to leave alone — everything else gets redirected to /bg
local KEEP_TYPES = {
    ["BATTLEGROUND"] = true,
    ["WHISPER"]      = true,  -- targets a specific person, keep as-is
    ["RAID_WARNING"] = true,  -- /rw, keep intentional raid warnings
}

local function IsInActiveBG()
    return TBGH_GetBGType() ~= nil
end

local commHookFrame = CreateFrame("Frame")
commHookFrame:RegisterEvent("VARIABLES_LOADED")
commHookFrame:SetScript("OnEvent", function()
    local eb = ChatFrameEditBox
    if not eb then return end
    local origOnShow = eb:GetScript("OnShow")
    eb:SetScript("OnShow", function()
        if origOnShow then origOnShow() end
        if TBGH.db and TBGH.db.bgChatRedirect == false then return end
        if not IsInActiveBG() then return end
        if not KEEP_TYPES[string.upper(ChatFrameEditBox.chatType or "")] then
            ChatFrameEditBox.chatType = "BATTLEGROUND"
            if ChatEdit_UpdateHeader then
                ChatEdit_UpdateHeader(ChatFrameEditBox)
            end
        end
    end)
end)

---------------------------------------------------------------------
-- Settings module registration
---------------------------------------------------------------------
TBGH:RegisterModule({
    name = "communication",
    tab  = "combat",

    buildSettings = function(parent, prevFrame)
        -- Always show *New at build time; syncSettings corrects it once saved vars are loaded
        local f = TBGH.CreateSectionFrame(parent, prevFrame, "Communication  |cff00ff7f*New|r", "Interface\\Icons\\INV_Misc_Note_06")
        TBGH._commSectionFrame = f

        local function DismissNew()
            if not TBGH.db.commSeen then
                TBGH.db.commSeen = true
            end
            f._titleLabel:SetText("|cffffd100Communication|r")
        end

        local bgChatCheck = CreateFrame("CheckButton", "TurtlePvPBGChatCheck", f, "UICheckButtonTemplate")
        bgChatCheck:SetWidth(24)
        bgChatCheck:SetHeight(24)
        bgChatCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -26)
        local bgChatLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        bgChatLabel:SetPoint("LEFT", bgChatCheck, "RIGHT", 2, 0)
        bgChatLabel:SetText("Default to |cffff7d0a/bg|r chat in battlegrounds")

        bgChatCheck:SetScript("OnEnter", function()
            DismissNew()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText("Default to /bg Chat in Battlegrounds", 1, 0.82, 0)
            GameTooltip:AddLine("When you open the chat box inside a BG, it will always switch to Battleground chat, even if you last used /say or /raid.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        bgChatCheck:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        bgChatCheck:SetScript("OnClick", function()
            TBGH.db.bgChatRedirect = this:GetChecked() and true or false
            DismissNew()
        end)

        f:SetHeight(54)

        TBGH._bgChatCheck = bgChatCheck
        TBGH._commDismissNew = DismissNew
        return f
    end,

    syncSettings = function()
        if TBGH._bgChatCheck then
            TBGH._bgChatCheck:SetChecked(TBGH.db.bgChatRedirect ~= false)
        end
        -- Hide *New badge once saved vars are loaded and user has seen it
        if TBGH._commDismissNew and TBGH.db.commSeen then
            TBGH._commDismissNew()
        end
    end,
})
