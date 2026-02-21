local addonName, BCF = ...
local T = BCF.Tokens

-- ============================================================================
-- RELOAD PROMPT
-- ============================================================================

local reloadOverlay, reloadDialog

local function ShowReloadPrompt()
    if reloadOverlay and reloadOverlay:IsShown() then return end
    if not BCF.OptionsPanel then return end

    local _, class = UnitClass("player")
    local cc = RAID_CLASS_COLORS[class] or {r = 1, g = 1, b = 1}

    if not reloadOverlay then
        reloadOverlay = CreateFrame("Frame", nil, BCF.OptionsPanel, "BackdropTemplate")
        reloadOverlay:SetAllPoints()
        reloadOverlay:SetFrameLevel(BCF.OptionsPanel:GetFrameLevel() + 100)
        reloadOverlay:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        reloadOverlay:SetBackdropColor(0, 0, 0, 0.7)
        reloadOverlay:EnableMouse(true)

        reloadDialog = CreateFrame("Frame", nil, reloadOverlay, "BackdropTemplate")
        reloadDialog:SetSize(300, 80)
        reloadDialog:SetPoint("CENTER", 0, 20)
        reloadDialog:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        reloadDialog:SetBackdropColor(0.1, 0.1, 0.13, 1)
        reloadDialog:SetBackdropBorderColor(1, 0, 0, 0.8)
        reloadDialog.elapsed = 0
        reloadDialog:SetScript("OnUpdate", function(self, dt)
            self.elapsed = self.elapsed + dt
            local alpha = 0.35 + 0.65 * math.abs(math.sin(self.elapsed * 2.5))
            self:SetBackdropBorderColor(1, 0, 0, alpha)
        end)

        local msg = reloadDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msg:SetPoint("TOP", 0, -12)
        msg:SetText("Changing this requires a /reload.\nDo you want to reload now?")
        msg:SetTextColor(0.9, 0.9, 0.9)
        msg:SetJustifyH("CENTER")

        local yesBtn = CreateFrame("Button", nil, reloadDialog, "BackdropTemplate")
        yesBtn:SetSize(110, 26)
        yesBtn:SetPoint("BOTTOMLEFT", 25, 10)
        yesBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        yesBtn:SetBackdropColor(cc.r, cc.g, cc.b, 0.3)
        local yesText = yesBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        yesText:SetPoint("CENTER")
        yesText:SetText("Reload Now")
        yesText:SetTextColor(1, 1, 1)
        yesBtn:SetScript("OnClick", function() ReloadUI() end)
        yesBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(cc.r, cc.g, cc.b, 0.5) end)
        yesBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(cc.r, cc.g, cc.b, 0.3) end)

        local noBtn = CreateFrame("Button", nil, reloadDialog, "BackdropTemplate")
        noBtn:SetSize(110, 26)
        noBtn:SetPoint("BOTTOMRIGHT", -25, 10)
        noBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        noBtn:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
        local noText = noBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noText:SetPoint("CENTER")
        noText:SetText("Later")
        noText:SetTextColor(0.7, 0.7, 0.7)
        noBtn:SetScript("OnClick", function() reloadOverlay:Hide() end)
        noBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.3, 0.3, 0.3, 0.5) end)
        noBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.2, 0.2, 0.2, 0.5) end)
    end

    BCF._reloadOverlay = reloadOverlay
    reloadOverlay:Show()
end

-- ============================================================================
-- OPTIONS PANEL
-- ============================================================================

function BCF.BuildOptionsPanel(container)
    if not container or not BCF.DB then return end
    local T = BCF.Tokens
    local G = BCF.DB.General
    local S = BCF.DB.Stats
    container.sections = container.sections or {}

    local COL_LEFT_X = 20
    local COL_RIGHT_X = 420

    local yLeft, yRight = 0, 0

    local function AddHeader(text, xBase, yOff)
        yOff = yOff - 8
        local hdr = BCF.CleanFont(container:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        hdr:SetPoint("TOPLEFT", xBase, yOff)
        hdr:SetText(text)
        hdr:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3], 1)
        table.insert(container.sections, hdr)
        return yOff - 18
    end

    local function AddCheckbox(label, value, onChange, xBase, yOff)
        local cb = BCF.CreateCheckbox(container, label, value, onChange)
        cb:SetPoint("TOPLEFT", xBase, yOff)
        table.insert(container.sections, cb)
        return yOff - 26
    end

    local function AddSlider(label, minV, maxV, step, value, onChange, xBase, yOff)
        local sl = BCF.CreateSlider(container, label, minV, maxV, step, value, onChange)
        sl:SetPoint("TOPLEFT", xBase, yOff)
        table.insert(container.sections, sl)
        return yOff - 40
    end

    local function AddDropdown(label, options, value, onChange, xBase, yOff)
        local dd = BCF.CreateDropdown(container, label, options, value, onChange)
        dd:SetPoint("TOPLEFT", xBase, yOff)
        table.insert(container.sections, dd)
        return yOff - 40, dd
    end

    -- ===================== LEFT COLUMN =====================

    -- ---- GENERAL ----
    yLeft = AddHeader("GENERAL", COL_LEFT_X, yLeft)

    yLeft = AddCheckbox("Replace Default Frame", G.ReplaceFrame, function(v)
        G.ReplaceFrame = v
        ShowReloadPrompt()
    end, COL_LEFT_X, yLeft)

    yLeft = AddCheckbox("Show on Login", G.ShowOnLogin, function(v)
        G.ShowOnLogin = v
        ShowReloadPrompt()
    end, COL_LEFT_X, yLeft)

    yLeft = AddCheckbox("Lock Frame Position", G.LockFrame, function(v)
        G.LockFrame = v
        if BCF.MainFrame then
            BCF.MainFrame:SetMovable(not v)
            BCF.MainFrame:EnableMouse(true)
        end
    end, COL_LEFT_X, yLeft)

    yLeft = AddCheckbox("Mute Chat Messages", G.MuteChat, function(v)
        G.MuteChat = v
    end, COL_LEFT_X, yLeft)

    -- ---- DISPLAY ----
    yLeft = AddHeader("DISPLAY", COL_LEFT_X, yLeft)

    yLeft = AddSlider("GUI Scale", 0.80, 1.20, 0.05, G.UIScale or 1.0, function(v)
        G.UIScale = v
        if BCF.MainFrame then
            BCF.MainFrame:SetScale(v)
            if BCF.ModelFrame then BCF.ModelFrame:SetModelScale(1.0 / v) end
        end
    end, COL_LEFT_X, yLeft)

    yLeft = AddCheckbox("Show Item Level on Slots", G.ShowILvl, function(v)
        G.ShowILvl = v
        if BCF.RefreshCharacter then BCF.RefreshCharacter() end
    end, COL_LEFT_X, yLeft)

    yLeft = AddCheckbox("Show Gem Sockets", G.ShowGemSockets, function(v)
        G.ShowGemSockets = v
        if BCF.RefreshCharacter then BCF.RefreshCharacter() end
    end, COL_LEFT_X, yLeft)

    yLeft = AddCheckbox("Show Equipped BiS Star", G.ShowEquippedBiSStar, function(v)
        G.ShowEquippedBiSStar = v
        if BCF.RefreshCharacter then BCF.RefreshCharacter() end
    end, COL_LEFT_X, yLeft)

    yLeft = AddDropdown("Enchant Display", {
        {value = "ABBREV", text = "Stat Abbreviations"},
        {value = "FULL",   text = "Full Enchant Names"},
    }, G.EnchantDisplayMode or "ABBREV", function(v)
        G.EnchantDisplayMode = v
        if BCF.RefreshCharacter then BCF.RefreshCharacter() end
        ShowReloadPrompt()
    end, COL_LEFT_X, yLeft)

    -- ---- STATS ----
    yLeft = AddHeader("STATS", COL_LEFT_X, yLeft)

    local ratingsCheckbox, pctCheckbox

    yLeft = AddCheckbox("Show Ratings", S.ShowRatings, function(v)
        if not v and not S.ShowPercentages then
            S.ShowRatings = true
            ratingsCheckbox:SetValue(true)
            return
        end
        S.ShowRatings = v
        if BCF.RefreshStats and BCF.SideStats then BCF.RefreshStats(BCF.SideStats) end
    end, COL_LEFT_X, yLeft)
    ratingsCheckbox = container.sections[#container.sections]

    yLeft = AddCheckbox("Show Percentages", S.ShowPercentages, function(v)
        if not v and not S.ShowRatings then
            S.ShowPercentages = true
            pctCheckbox:SetValue(true)
            return
        end
        S.ShowPercentages = v
        if BCF.RefreshStats and BCF.SideStats then BCF.RefreshStats(BCF.SideStats) end
    end, COL_LEFT_X, yLeft)
    pctCheckbox = container.sections[#container.sections]

    yLeft = AddCheckbox("Auto-Detect Role", S.AutoDetectRole, function(v)
        S.AutoDetectRole = v
        ShowReloadPrompt()
    end, COL_LEFT_X, yLeft)

    -- ===================== RIGHT COLUMN =====================

    -- ---- TYPOGRAPHY ----
    yRight = AddHeader("TYPOGRAPHY", COL_RIGHT_X, yRight)

    yRight = AddDropdown("Font", {
        {value = "DEFAULT",  text = "Default (FRIZQT)"},
        {value = "FRIZQT",   text = "FRIZQT"},
        {value = "ARIALN",   text = "ARIALN"},
        {value = "MORPHEUS", text = "Morpheus"},
        {value = "SKURRI",   text = "Skurri"},
    }, G.FontFamily or "DEFAULT", function(v)
        G.FontFamily = v
        if BCF.ApplyAllFonts then BCF.ApplyAllFonts() end
    end, COL_RIGHT_X, yRight)

    yRight = AddSlider("Header Text Size", 8, 20, 1, G.FontSizeHeader or 14, function(v)
        G.FontSizeHeader = v
        if BCF.ApplyAllFonts then BCF.ApplyAllFonts() end
    end, COL_RIGHT_X, yRight)

    yRight = AddSlider("Item Text Size", 8, 20, 1, G.FontSizeItems or 11, function(v)
        G.FontSizeItems = v
        if BCF.ApplyAllFonts then BCF.ApplyAllFonts() end
    end, COL_RIGHT_X, yRight)

    yRight = AddSlider("List Text Size", 8, 20, 1, G.FontSizeLists or 10, function(v)
        G.FontSizeLists = v
        if BCF.ApplyAllFonts then BCF.ApplyAllFonts() end
    end, COL_RIGHT_X, yRight)

    -- ---- TITLE BAR ORDER ----
    yRight = AddHeader("TITLE BAR ORDER", COL_RIGHT_X, yRight)

    local titleOrder = G.TitleOrder
    if type(titleOrder) ~= "table" then
        titleOrder = {"NAME", "LEVEL", "TALENT", "CLASS", "GUILD", "TITLE"}
        G.TitleOrder = titleOrder
    end

    local titleLabels = {
        NAME = "Name", LEVEL = "Level", TALENT = "Talent",
        CLASS = "Class", GUILD = "Guild", TITLE = "Title",
    }

    local titleDropdowns = {}
    for pos = 1, 6 do
        local opts = {}
        for _, key in ipairs({"NAME", "LEVEL", "TALENT", "CLASS", "GUILD", "TITLE"}) do
            table.insert(opts, {value = key, text = titleLabels[key]})
        end

        local dd
        yRight, dd = AddDropdown("Position " .. pos, opts, titleOrder[pos], function(newVal, _)
            local oldVal = titleOrder[pos]
            for otherPos = 1, 6 do
                if otherPos ~= pos and titleOrder[otherPos] == newVal then
                    titleOrder[otherPos] = oldVal
                    if titleDropdowns[otherPos] then
                        titleDropdowns[otherPos].selText:SetText(titleLabels[oldVal])
                        titleDropdowns[otherPos].selected = oldVal
                    end
                    break
                end
            end
            titleOrder[pos] = newVal
            if BCF.RefreshTitleBar then BCF.RefreshTitleBar() end
        end, COL_RIGHT_X, yRight)
        titleDropdowns[pos] = dd
    end

    local totalHeight = math.max(math.abs(yLeft), math.abs(yRight)) + 20
    container:SetHeight(totalHeight)
end
