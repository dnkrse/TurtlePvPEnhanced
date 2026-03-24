---------------------------------------------------------------------
-- Alterac Valley module (placeholder)
---------------------------------------------------------------------

TBGH:RegisterModule({
    name = "av",
    tab  = "bg",

    buildSettings = function(parent, prevFrame)
        local f = TBGH.CreateSectionFrame(parent, prevFrame,
            "Alterac Valley",
            "Interface\\Icons\\INV_Jewelry_Necklace_21")

        local lbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -34)
        lbl:SetTextColor(0.5, 0.5, 0.5, 1)
        lbl:SetText("Coming soon!")

        f:SetHeight(54)
        return f
    end,
})
