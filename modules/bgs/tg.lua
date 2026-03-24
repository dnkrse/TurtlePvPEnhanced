---------------------------------------------------------------------
-- Thorn Gorge module (placeholder)
---------------------------------------------------------------------

TBGH:RegisterModule({
    name = "tg",
    tab  = "bg",

    buildSettings = function(parent, prevFrame)
        local f = TBGH.CreateSectionFrame(parent, prevFrame,
            "Thorn Gorge",
            "Interface\\Icons\\INV_Jewelry_Talisman_04")

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -34)
        lbl:SetTextColor(0.5, 0.5, 0.5, 1)
        lbl:SetText("Coming soon!")

        f:SetHeight(54)
        return f
    end,
})
