local addonName, BCF = ...

-- ============================================================================
-- MODULE: GUI
-- ============================================================================

local T = BCF.Tokens

-- ============================================================================
-- STATIC POPUP DIALOGS
-- ============================================================================

-- Delete gear set confirmation uses BCF.ShowConfirmDialog (defined in Wishlist.lua)

-- ============================================================================
-- MAIN FRAME
-- ============================================================================

function BCF.CreateMainFrame()
    if BCF.MainFrame then return end

    -- Forward declare gear slot storage for closures created earlier in this function.
    local gearSlotFrames

    local f = CreateFrame("Frame", "BCFMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(T.MainWidth, T.MainHeight)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(not (BCF.DB and BCF.DB.General and BCF.DB.General.LockFrame))
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:Hide()

    -- Restore saved position
    if BCF.DB and BCF.DB.WindowPos then
        local p = BCF.DB.WindowPos
        if type(p) == "table" and type(p[1]) == "string" and type(p[3]) == "string"
            and type(p[4]) == "number" and type(p[5]) == "number" then
            f:ClearAllPoints()
            f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
        end
    end

    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if BCF.DB then
            local point, _, relPoint, x, y = self:GetPoint()
            BCF.DB.WindowPos = { point, nil, relPoint, x, y }
        end
    end)
    f:RegisterForDrag("LeftButton")

    BCF.ApplyPanelStyle(f)

    -- If frame bootstrap is deferred due to combat lockdown (e.g. /reload in combat),
    -- show a pulsing red border so the user knows full UI init is queued.
    local deferredInitGlow = CreateFrame("Frame", nil, f, "BackdropTemplate")
    deferredInitGlow:SetPoint("TOPLEFT", 0, 0)
    deferredInitGlow:SetPoint("BOTTOMRIGHT", 0, 0)
    deferredInitGlow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    deferredInitGlow:SetBackdropBorderColor(1, 0, 0, 0.8)
    deferredInitGlow:Hide()
    deferredInitGlow:SetScript("OnUpdate", function(self)
        local alpha = 0.35 + 0.65 * math.abs(math.sin(GetTime() * 2.5))
        self:SetBackdropBorderColor(1, 0, 0, alpha)
    end)

    local deferredInitMask = CreateFrame("Frame", nil, f, "BackdropTemplate")
    deferredInitMask:SetPoint("TOPLEFT", 0, 0)
    deferredInitMask:SetPoint("BOTTOMRIGHT", 0, 0)
    deferredInitMask:SetFrameStrata("DIALOG")
    deferredInitMask:SetFrameLevel(300)
    deferredInitMask:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    deferredInitMask:SetBackdropColor(0, 0, 0, 0.96)
    deferredInitMask:EnableMouse(true)
    deferredInitMask:SetScript("OnMouseDown", function() end)
    deferredInitMask:SetScript("OnMouseUp", function() end)
    deferredInitMask:SetScript("OnMouseWheel", function() end)
    deferredInitMask:Hide()

    local deferredInitText = BCF.CleanFont(deferredInitMask:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"))
    deferredInitText:SetPoint("CENTER", 0, 8)
    deferredInitText:SetTextColor(1, 0.2, 0.2, 1)
    deferredInitText:SetText("GUI will load when combat ends")

    local deferredInitSubText = BCF.CleanFont(deferredInitMask:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    deferredInitSubText:SetPoint("TOP", deferredInitText, "BOTTOM", 0, -8)
    deferredInitSubText:SetTextColor(1, 0.35, 0.35, 0.95)
    deferredInitSubText:SetText("BCF is locked during combat reload")

    -- Register for native ESC close behavior.
    if UISpecialFrames then
        local found = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "BCFMainFrame" then
                found = true
                break
            end
        end
        if not found then
            tinsert(UISpecialFrames, "BCFMainFrame")
        end
    end

    -- === ESCAPE HANDLING ===
    -- CharacterFrame IS BCFMainFrame → ESC works via UIPanelWindows (all Blizzard code)

    f:SetScript("OnHide", function(self)
        if BCFIconPicker then BCFIconPicker:Hide() end
        -- Close options unless reload dialog is pending
        if BCF.CloseOptionsSilent then BCF.CloseOptionsSilent() end
    end)

    -- Click-Away to clear focus (fixes sticky rename fields)
    f:SetScript("OnMouseDown", function()
        local focus = GetCurrentKeyBoardFocus()
        if focus and not focus:IsForbidden() then
            focus:ClearFocus()
        end
    end)

    local function GetCursorItemTypeAndColor()
        local cursorType, cursorItemID, cursorItemLink = GetCursorInfo()
        if cursorType ~= "item" then
            return cursorType
        end

        local _, _, quality = GetItemInfo(cursorItemLink or cursorItemID)
        if quality then
            local r, g, b = GetItemQualityColor(quality)
            return cursorType, r, g, b
        end

        -- If item info isn't cached yet, derive color from hyperlink prefix.
        if type(cursorItemLink) == "string" then
            local hex = cursorItemLink:match("|c(%x%x%x%x%x%x%x%x)|Hitem:")
            if hex and #hex == 8 then
                local r = tonumber(hex:sub(3, 4), 16) / 255
                local g = tonumber(hex:sub(5, 6), 16) / 255
                local b = tonumber(hex:sub(7, 8), 16) / 255
                if r and g and b then
                    return cursorType, r, g, b
                end
            end
        end

        -- Fallback while item data is uncached.
        return cursorType, 0.2, 0.5, 1.0
    end

    -- Drag-target monitor: show glow on empty slots while cursor holds an item
    local lastCursorHasItem = false
    f:SetScript("OnUpdate", function()
        local hasItem = CursorHasItem()
        if not hasItem and not lastCursorHasItem then return end
        lastCursorHasItem = hasItem

        if not gearSlotFrames then return end

        local cursorR, cursorG, cursorB = 0.2, 0.5, 1.0
        if hasItem then
            local cursorType
            cursorType, cursorR, cursorG, cursorB = GetCursorItemTypeAndColor()
            if cursorType ~= "item" then
                cursorR, cursorG, cursorB = 0.2, 0.5, 1.0
            end
        end

        for slotID, frame in pairs(gearSlotFrames) do
            if frame.DragBackdrop then
                if hasItem then
                    local canGoInSlot = CursorCanGoInSlot and CursorCanGoInSlot(slotID) or false
                    if canGoInSlot and not GetInventoryItemLink("player", slotID) and MouseIsOver(frame) then
                        frame.DragBackdrop:SetColorTexture(cursorR, cursorG, cursorB, 0.45)
                        frame.DragBackdrop:Show()
                        if frame.HoverGlow then
                            frame.HoverGlow:SetColorTexture(cursorR, cursorG, cursorB, 0.35)
                        end
                    else
                        frame.DragBackdrop:Hide()
                    end
                else
                    frame.DragBackdrop:Hide()
                end
            end
        end
    end)

    -- Title Bar (borderless)
    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetHeight(32)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    titleBar:SetBackdropColor(T.Accent[1] * 0.12, T.Accent[2] * 0.12, T.Accent[3] * 0.12, 0.98)

    local closeBtn = BCF.CreateCloseButton(titleBar, 20, function()
        if BCF.MainFrame then BCF.MainFrame:Hide() end
    end)
    closeBtn:SetPoint("RIGHT", -8, 0)

    -- Config Button (gear icon, subtle)
    local configBtn = CreateFrame("Button", nil, titleBar)
    configBtn:SetSize(16, 16)
    configBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    local configTex = configBtn:CreateTexture(nil, "ARTWORK")
    configTex:SetAllPoints()
    configTex:SetTexture("Interface\\WorldMap\\Gear_64")
    configTex:SetTexCoord(0, 0.5, 0, 0.5)
    configTex:SetVertexColor(0.5, 0.5, 0.5, 1)
    configBtn:SetScript("OnEnter", function() configTex:SetVertexColor(1, 1, 1, 1) end)
    configBtn:SetScript("OnLeave", function() configTex:SetVertexColor(0.5, 0.5, 0.5, 1) end)

    BCF.optionsPanelOpen = false
    -- Pulsing red border for gear icon when options panel is open
    local configGlow = CreateFrame("Frame", nil, configBtn, "BackdropTemplate")
    configGlow:SetPoint("TOPLEFT", -3, 3)
    configGlow:SetPoint("BOTTOMRIGHT", 3, -3)
    configGlow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    configGlow:SetBackdropBorderColor(1, 0, 0, 0.8)
    configGlow:Hide()
    configGlow:SetScript("OnUpdate", function(self)
        local alpha = 0.35 + 0.65 * math.abs(math.sin(GetTime() * 2.5))
        self:SetBackdropBorderColor(1, 0, 0, alpha)
    end)
    -- OnClick wired after sub-tabs are created (see below configBtn OnClick block)

    -- Options overlay panel (full-width, covers tabs + content)
    local optionsPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    optionsPanel:SetPoint("TOPLEFT", 0, -32) -- below title bar
    optionsPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    optionsPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    optionsPanel:SetBackdropColor(0.05, 0.05, 0.08, 1)
    optionsPanel:SetFrameStrata("DIALOG")
    optionsPanel:SetFrameLevel(50)
    optionsPanel:EnableMouse(true)
    optionsPanel:Hide()

    -- Scroll frame inside options panel
    local optScroll = CreateFrame("ScrollFrame", nil, optionsPanel)
    optScroll:SetPoint("TOPLEFT", 0, 0)
    optScroll:SetPoint("BOTTOMRIGHT", -8, 0)
    optScroll:EnableMouseWheel(true)
    optScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        local step = 30
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * step)))
    end)

    local optContent = CreateFrame("Frame", nil, optScroll)
    optContent:SetWidth(840)
    optContent:SetHeight(1) -- updated by BuildOptionsPanel
    optScroll:SetScrollChild(optContent)
    optContent.sections = {}

    BCF.OptionsPanel = optionsPanel
    BCF.OptionsContent = optContent
    BCF.OptionsScroll = optScroll

    -- Text Logo (bottom left corner, expanded view only)
    local logo = f:CreateTexture(nil, "OVERLAY")
    logo:SetTexture("Interface/AddOns/BetterCharacterFrame/logo")
    logo:SetSize(192, 48) -- Same visual size as before, higher-res source for sharper rendering
    logo:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 6)
    logo:SetAlpha(0.6)
    if not BCF.DB.General.IsExpanded then logo:Hide() end
    BCF.LogoTexture = logo

    -- Version Text (bottom right of logo)
    local versionText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("BOTTOMLEFT", logo, "BOTTOMLEFT", 193, -2)
    versionText:SetText("v" .. BCF.Version)
    versionText:SetTextColor(0.5, 0.5, 0.5, 0.35)
    if not BCF.DB.General.IsExpanded then versionText:Hide() end
    BCF.LogoVersion = versionText

    -- ================================================================
    -- DYNAMIC TITLE BAR ELEMENTS
    -- ================================================================

    -- Title text: "Name  Level  Spec  Class" (with embedded color codes)
    -- Simple approach - just left-aligned in titlebar
    local playerNameText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    playerNameText:SetPoint("LEFT", 10, 0)
    playerNameText:SetJustifyH("LEFT")
    playerNameText:SetWordWrap(false)
    BCF.RegisterFont(playerNameText, "header")

    -- Placeholder for clipping frame (not used, but referenced by animation code)
    local titleTextClip = titleBar

    -- Legacy level text (hidden, all info now in center text)
    local levelSpecText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    levelSpecText:SetPoint("RIGHT", configBtn, "LEFT", -12, 0)
    levelSpecText:SetTextColor(unpack(T.TextMuted))

    -- Title dropdown (anchored to right of player name text, expanded view only)
    local titleDropBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    titleDropBtn:SetHeight(T.RowHeight)
    titleDropBtn:SetPoint("LEFT", playerNameText, "RIGHT", 6, 0)
    -- No backdrop - transparent by default

    local titleLabel = titleDropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleLabel:SetPoint("LEFT", 4, 0)
    titleLabel:SetTextColor(unpack(T.TextMuted))

    local titleArrow = titleDropBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleArrow:SetPoint("LEFT", titleLabel, "RIGHT", 4, 0)
    titleArrow:SetText("v")
    titleArrow:SetTextColor(unpack(T.TextMuted))

    -- Title Dropdown Panel
    local titleDropPanel = CreateFrame("Frame", "BCFTitleDropdown", titleDropBtn, "BackdropTemplate")
    titleDropPanel:SetPoint("TOPLEFT", titleDropBtn, "BOTTOMLEFT", 0, -2)
    titleDropPanel:SetWidth(220)
    titleDropPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    titleDropPanel:SetBackdropColor(0.06, 0.06, 0.09, 0.98)
    titleDropPanel:SetFrameStrata("DIALOG")
    titleDropPanel:Hide()

    -- Format title for short display (strip player name placeholder)
    local function FormatTitleShort(titlePattern)
        if not titlePattern then return nil end
        local short = titlePattern:gsub(",?%s*%%s%s*", ""):gsub("%s*%%s,?%s*", "")
        short = strtrim(short)
        return (short ~= "") and short or nil
    end

    -- Count known titles
    local function CountKnownTitles()
        local count = 0
        for i = 1, GetNumTitles() do
            if IsTitleKnown(i) then count = count + 1 end
        end
        return count
    end

    -- Get current title short text
    local function GetCurrentTitleShort()
        local idx = GetCurrentTitle()
        if idx and idx > 0 then
            return FormatTitleShort(GetTitleName(idx))
        end
        return nil
    end

    local function BuildTitleList()
        for _, child in pairs({ titleDropPanel:GetChildren() }) do
            child:Hide()
            child:SetParent(nil)
        end

        local y = -4
        local pName = UnitName("player")

        -- "No Title" option (clear current title)
        local noRow = CreateFrame("Button", nil, titleDropPanel)
        noRow:SetHeight(20)
        noRow:SetPoint("TOPLEFT", 4, y)
        noRow:SetPoint("RIGHT", -4, 0)
        local noBg = noRow:CreateTexture(nil, "BACKGROUND")
        noBg:SetAllPoints()
        noBg:SetColorTexture(0, 0, 0, 0)
        local noText = noRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noText:SetPoint("LEFT", 8, 0)
        noText:SetText("No Title")
        noText:SetTextColor(unpack(T.TextMuted))
        noRow:SetScript("OnClick", function()
            if BCF.SuppressTitleRefresh then BCF.SuppressTitleRefresh(2) end
            SetCurrentTitle(-1)
            titleDropPanel:Hide()
            titleArrow:SetText("v")
            titleLabel:SetText("No Title")
            titleLabel:SetTextColor(unpack(T.TextMuted))
            C_Timer.After(0, function()
                titleDropBtn:SetWidth(titleLabel:GetStringWidth() + titleArrow:GetStringWidth() + 16)
            end)
        end)
        noRow:SetScript("OnEnter",
            function()
                noBg:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.15); noText:SetTextColor(1, 1, 1)
            end)
        noRow:SetScript("OnLeave", function()
            noBg:SetColorTexture(0, 0, 0, 0); noText:SetTextColor(unpack(T.TextMuted))
        end)
        y = y - 20

        for i = 1, GetNumTitles() do
            if IsTitleKnown(i) then
                local tName = GetTitleName(i)
                if tName then
                    local row = CreateFrame("Button", nil, titleDropPanel)
                    row:SetHeight(20)
                    row:SetPoint("TOPLEFT", 4, y)
                    row:SetPoint("RIGHT", -4, 0)
                    local rowBg = row:CreateTexture(nil, "BACKGROUND")
                    rowBg:SetAllPoints()
                    rowBg:SetColorTexture(0, 0, 0, 0)
                    local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    rowText:SetPoint("LEFT", 8, 0)
                    rowText:SetText(tName:format(pName))
                    rowText:SetTextColor(unpack(T.TextSecondary))

                    local titleIdx = i
                    row:SetScript("OnClick", function()
                        if BCF.SuppressTitleRefresh then BCF.SuppressTitleRefresh(2) end
                        SetCurrentTitle(titleIdx)
                        titleDropPanel:Hide()
                        titleArrow:SetText("v")
                        local short = FormatTitleShort(tName)
                        if short then
                            titleLabel:SetText(short)
                            titleLabel:SetTextColor(unpack(T.TextSecondary))
                        else
                            titleLabel:SetText("No Title")
                            titleLabel:SetTextColor(unpack(T.TextMuted))
                        end
                        C_Timer.After(0, function()
                            titleDropBtn:SetWidth(titleLabel:GetStringWidth() + titleArrow:GetStringWidth() + 16)
                        end)
                    end)
                    row:SetScript("OnEnter",
                        function()
                            rowBg:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.15); rowText:SetTextColor(1, 1,
                                1)
                        end)
                    row:SetScript("OnLeave",
                        function()
                            rowBg:SetColorTexture(0, 0, 0, 0); rowText:SetTextColor(unpack(T.TextSecondary))
                        end)
                    y = y - 20
                end
            end
        end
        titleDropPanel:SetHeight(math.abs(y) + 4)
    end

    -- ================================================================
    -- BCF.RefreshTitleBar() - Updates all dynamic title bar elements
    -- ================================================================
    -- Get talent tab name (handles both Classic and Anniversary API)
    local function GetTabSpecName(tabIndex)
        local r1, r2 = GetTalentTabInfo(tabIndex)
        if type(r1) == "string" and r1 ~= "" then return r1 end
        if type(r2) == "string" and r2 ~= "" then return r2 end
        return ""
    end

    -- Count talent points in a tab via individual talents
    local function CountTabPoints(tabIndex)
        local points = 0
        for i = 1, (GetNumTalents(tabIndex) or 0) do
            local _, _, _, _, rank = GetTalentInfo(tabIndex, i)
            points = points + (tonumber(rank) or 0)
        end
        return points
    end

    function BCF.RefreshTitleBar()
        local _, pClass = UnitClass("player")
        local cc = RAID_CLASS_COLORS[pClass] or { r = 1, g = 1, b = 1 }
        local pName = UnitName("player")
        local localClass = UnitClass("player")
        local pLevel = UnitLevel("player")

        -- Determine spec (skip if no talent points spent)
        local specN = ""
        local pTab = 1
        local maxPts = 0
        for i = 1, GetNumTalentTabs() do
            local pts = CountTabPoints(i)
            if pts > maxPts then
                maxPts = pts
                pTab = i
            end
        end
        if maxPts > 0 then
            specN = GetTabSpecName(pTab)
        end

        local hexCC = string.format("%02x%02x%02x", cc.r * 255, cc.g * 255, cc.b * 255)
        local isExpanded = BCF.DB and BCF.DB.General and BCF.DB.General.ShowItemDetails

        -- Guild name: fetch from API
        local guildName = GetGuildInfo("player")
        if (not guildName or guildName == "") and BCF._cachedGuildName then
            guildName = BCF._cachedGuildName
        end

        if guildName and guildName ~= "" then
            BCF._cachedGuildName = guildName
        elseif IsInGuild and IsInGuild() then
            pcall(function()
                if GuildRoster then GuildRoster() end
            end)
            local retryDone = false
            local retries = { 0.25, 0.6, 1.2, 2.5, 5 }
            for _, delay in ipairs(retries) do
                C_Timer.After(delay, function()
                    if retryDone then return end
                    if not BCF.RefreshTitleBar then return end
                    local gn = GetGuildInfo("player")
                    if gn and gn ~= "" then
                        BCF._cachedGuildName = gn
                        retryDone = true
                    end
                    BCF.RefreshTitleBar()
                end)
            end
        end

        local titleCount = CountKnownTitles()
        local currentShort = GetCurrentTitleShort()

        -- Build token map for ordered title bar
        local tokenMap = {
            NAME   = "|cff" .. hexCC .. pName .. "|r",
            LEVEL  = "|cffb3b3b3" .. tostring(pLevel) .. "|r",
            TALENT = specN ~= "" and ("|cffb3b3b3" .. specN .. "|r") or nil,
            CLASS  = "|cffb3b3b3" .. localClass .. "|r",
            GUILD  = (guildName and guildName ~= "") and ("|cff44ff44<" .. guildName .. ">|r") or nil,
            -- TITLE is shown via the dropdown button only, not inline
        }

        -- Assemble ordered text
        local order = BCF.DB.General.TitleOrder
        if type(order) ~= "table" then
            order = { "NAME", "LEVEL", "TALENT", "CLASS", "GUILD" }
        end
        local parts = {}
        for _, key in ipairs(order) do
            if tokenMap[key] then
                table.insert(parts, tokenMap[key])
            end
        end
        playerNameText:SetText(table.concat(parts, "  "))

        -- Title dropdown (expanded view only, always clickable if 1+ titles)
        if isExpanded and titleCount >= 1 then
            titleDropBtn:Show()
            titleDropBtn:EnableMouse(true)
            titleArrow:Show()
            titleArrow:SetText("v")
            if currentShort then
                titleLabel:SetText(currentShort)
                titleLabel:SetTextColor(unpack(T.TextSecondary))
            else
                titleLabel:SetText("No Title")
                titleLabel:SetTextColor(unpack(T.TextMuted))
            end
            C_Timer.After(0, function()
                titleDropBtn:SetWidth(titleLabel:GetStringWidth() + titleArrow:GetStringWidth() + 16)
            end)
        else
            titleDropBtn:Hide()
            titleDropPanel:Hide()
        end

        -- Use white base color; embedded |cff codes handle per-section coloring
        playerNameText:SetTextColor(1, 1, 1)
        -- Hide separate level text (all info is in center text now)
        levelSpecText:SetText("")
        levelSpecText:Hide()
    end

    -- Dropdown click handler (only active when multiple titles)
    titleDropBtn:SetScript("OnClick", function()
        if CountKnownTitles() < 1 then return end
        if titleDropPanel:IsShown() then
            titleDropPanel:Hide()
            titleArrow:SetText("v")
        else
            BuildTitleList()
            titleDropPanel:Show()
            titleArrow:SetText("^")
        end
    end)

    titleDropBtn:SetScript("OnEnter", function(self)
        if CountKnownTitles() < 1 then return end
        titleLabel:SetTextColor(1, 1, 1)
        titleArrow:SetTextColor(1, 1, 1)
    end)
    titleDropBtn:SetScript("OnLeave", function(self)
        if CountKnownTitles() <= 1 then return end
        local currentShort = GetCurrentTitleShort()
        if currentShort then
            titleLabel:SetTextColor(unpack(T.TextSecondary))
        else
            titleLabel:SetTextColor(unpack(T.TextMuted))
        end
        titleArrow:SetTextColor(unpack(T.TextMuted))
    end)

    -- Event frame for dynamic title bar updates
    if BCF.TitleBarEvents then BCF.TitleBarEvents:UnregisterAllEvents() end
    local titleBarEvents = CreateFrame("Frame")
    BCF.TitleBarEvents = titleBarEvents
    titleBarEvents:RegisterEvent("PLAYER_LEVEL_UP")
    titleBarEvents:RegisterEvent("CHARACTER_POINTS_CHANGED")
    titleBarEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    titleBarEvents:RegisterEvent("KNOWN_TITLES_UPDATE")
    titleBarEvents:RegisterEvent("PLAYER_TALENT_UPDATE")
    titleBarEvents:RegisterEvent("PLAYER_GUILD_UPDATE")
    titleBarEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    titleBarEvents:RegisterEvent("GUILD_ROSTER_UPDATE")
    local titleRefreshSuppressed = false
    titleBarEvents:SetScript("OnEvent", function()
        if titleRefreshSuppressed then return end
        BCF.RefreshTitleBar()
    end)
    BCF.SuppressTitleRefresh = function(duration)
        titleRefreshSuppressed = true
        C_Timer.After(duration, function() titleRefreshSuppressed = false end)
    end

    -- Guild data + title bar refresh moved to consolidated OnShow handler below

    -- Initial refresh
    C_Timer.After(0.1, function() BCF.RefreshTitleBar() end)

    -- ========================================================================
    -- HEADER TABS (Row 1): Character | Pet* | Reputation | Skills | PvP | Currency*
    -- ========================================================================
    local headerTabContainer = CreateFrame("Frame", nil, f)
    headerTabContainer:SetHeight(T.TabHeight)
    headerTabContainer:SetPoint("TOPLEFT", 0, -32)
    headerTabContainer:SetPoint("TOPRIGHT", 0, -32)

    local headerTabs = {}
    local activeHeaderTab = 1 -- 1 = Character (default)
    BCF.activeHeaderTab = 1
    local headerTabsCollapsed = false
    local subTabsCollapsed = false

    -- Build header tab list (Pet tab is injected dynamically when pet is active)
    local headerTabNames = { "Character" }
    table.insert(headerTabNames, "Reputation")
    table.insert(headerTabNames, "Skills")
    table.insert(headerTabNames, "PvP")
    table.insert(headerTabNames, "Currency")

    -- ========================================================================
    -- SUB-TABS (Row 2): Stats | Sets | Wishlist (only under Character)
    -- ========================================================================
    local subTabContainer = CreateFrame("Frame", nil, f)
    subTabContainer:SetHeight(T.TabHeight)
    subTabContainer:SetPoint("TOPLEFT", 0, -(32 + T.TabHeight))
    subTabContainer:SetPoint("TOPRIGHT", 0, -(32 + T.TabHeight))

    local subTabs = {}
    local activeSubTab = 1 -- 1 = Stats (default)
    BCF.activeSubTab = 1
    local subTabNames = { "Stats", "Equipment Sets", "Wishlist" }

    local tabFrames = {}
    local tabs = subTabs -- Alias for compatibility with existing code

    -- Content area - position depends on whether sub-tabs are visible
    local contentArea = CreateFrame("Frame", nil, f)
    contentArea:SetPoint("BOTTOMRIGHT", 0, 0)

    local function UpdateContentAreaPosition()
        contentArea:ClearAllPoints()
        contentArea:SetPoint("BOTTOMRIGHT", 0, 0)

        -- Calculate offset based on collapsed states
        local headerHeight = headerTabsCollapsed and 0 or T.TabHeight
        local subHeight = 0
        if activeHeaderTab == 1 and not subTabsCollapsed then
            subHeight = T.TabHeight
        end

        contentArea:SetPoint("TOPLEFT", 0, -(32 + headerHeight + subHeight))
    end

    -- Coming Soon overlay for non-Character headers
    local headerComingSoon = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
    headerComingSoon:SetAllPoints()
    headerComingSoon:SetFrameLevel(contentArea:GetFrameLevel() + 50)
    headerComingSoon:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    headerComingSoon:SetBackdropColor(T.Background[1], T.Background[2], T.Background[3], 0.98)
    headerComingSoon:Hide()

    local headerComingSoonText = BCF.CleanFont(headerComingSoon:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    headerComingSoonText:SetPoint("CENTER", 0, 0)
    headerComingSoonText:SetText("Coming Soon\226\132\162")
    headerComingSoonText:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.35)

    -- ========================================================================
    -- REPUTATION TAB CONTENT (scrollable faction list)
    -- ========================================================================
    local reputationContainer = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
    reputationContainer:SetAllPoints()
    reputationContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    reputationContainer:SetBackdropColor(T.Background[1], T.Background[2], T.Background[3], 1)
    reputationContainer:Hide()

    -- ScrollFrame (full width minus slider)
    local repScrollFrame = CreateFrame("ScrollFrame", nil, reputationContainer)
    repScrollFrame:SetPoint("TOPLEFT", 0, 0)
    repScrollFrame:SetPoint("BOTTOMRIGHT", -8, 0)

    local reputationContent = CreateFrame("Frame", nil, repScrollFrame)
    reputationContent:SetWidth(repScrollFrame:GetWidth())
    reputationContent:SetHeight(1)
    repScrollFrame:SetScrollChild(reputationContent)
    repScrollFrame:SetScript("OnSizeChanged", function(self, w) reputationContent:SetWidth(w - 5) end)
    BCF.ReputationContent = reputationContent
    BCF.ReputationContainer = reputationContainer
    BCF.ReputationScrollFrame = repScrollFrame

    -- Custom slider (overlays on right edge)
    local repSlider = CreateFrame("Slider", nil, reputationContainer, "BackdropTemplate")
    repSlider:SetPoint("TOPRIGHT", 0, 0)
    repSlider:SetPoint("BOTTOMRIGHT", 0, 0)
    repSlider:SetWidth(6)
    repSlider:SetFrameLevel(repScrollFrame:GetFrameLevel() + 5)
    repSlider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    repSlider:SetBackdropColor(0, 0, 0, 0.2)

    local repThumb = repSlider:CreateTexture(nil, "ARTWORK")
    repThumb:SetSize(6, 30)
    repThumb:SetColorTexture(unpack(T.Accent))
    repSlider:SetThumbTexture(repThumb)

    repSlider:SetOrientation("VERTICAL")
    repSlider:SetValueStep(1)
    repSlider:EnableMouse(false)

    -- Draggable thumb button
    local repThumbBtn = CreateFrame("Button", nil, repSlider)
    repThumbBtn:SetFrameLevel(repSlider:GetFrameLevel() + 2)
    repThumbBtn:EnableMouse(true)
    repThumbBtn:RegisterForDrag("LeftButton")
    repThumbBtn:SetAllPoints(repSlider:GetThumbTexture())

    repThumbBtn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.isDragging = true
        self.startY = select(2, GetCursorPosition())
        self.startVal = repSlider:GetValue()
        local min, max = repSlider:GetMinMaxValues()
        self.valRange = max - min
        self.heightRange = repSlider:GetHeight() - self:GetHeight()
        if self.heightRange < 1 then self.heightRange = 1 end
    end)

    repThumbBtn:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.isDragging = false
    end)

    repThumbBtn:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currY = select(2, GetCursorPosition())
            local diff = self.startY - currY
            local delta = (diff / self.heightRange) * self.valRange
            repSlider:SetValue(self.startVal + delta)
        end
    end)

    BCF.WireScrollbar(repScrollFrame, reputationContent, repSlider, repThumb, reputationContainer)

    -- ========================================================================
    -- SKILLS TAB CONTENT (scrollable skills list)
    -- ========================================================================
    local skillsContainer = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
    skillsContainer:SetAllPoints()
    skillsContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    skillsContainer:SetBackdropColor(T.Background[1], T.Background[2], T.Background[3], 1)
    skillsContainer:Hide()

    local skillsScrollFrame = CreateFrame("ScrollFrame", nil, skillsContainer)
    skillsScrollFrame:SetPoint("TOPLEFT", 0, 0)
    skillsScrollFrame:SetPoint("BOTTOMRIGHT", -8, 0)

    local skillsContent = CreateFrame("Frame", nil, skillsScrollFrame)
    skillsContent:SetWidth(skillsScrollFrame:GetWidth())
    skillsContent:SetHeight(1)
    skillsScrollFrame:SetScrollChild(skillsContent)
    skillsScrollFrame:SetScript("OnSizeChanged", function(self, w) skillsContent:SetWidth(w - 5) end)
    BCF.SkillsContent = skillsContent
    BCF.SkillsContainer = skillsContainer

    -- Custom slider for skills
    local skillsSlider = CreateFrame("Slider", nil, skillsContainer, "BackdropTemplate")
    skillsSlider:SetPoint("TOPRIGHT", 0, 0)
    skillsSlider:SetPoint("BOTTOMRIGHT", 0, 0)
    skillsSlider:SetWidth(6)
    skillsSlider:SetFrameLevel(skillsScrollFrame:GetFrameLevel() + 5)
    skillsSlider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    skillsSlider:SetBackdropColor(0, 0, 0, 0.2)

    local skillsThumb = skillsSlider:CreateTexture(nil, "ARTWORK")
    skillsThumb:SetSize(6, 30)
    skillsThumb:SetColorTexture(unpack(T.Accent))
    skillsSlider:SetThumbTexture(skillsThumb)

    skillsSlider:SetOrientation("VERTICAL")
    skillsSlider:SetValueStep(1)
    skillsSlider:EnableMouse(false)

    local skillsThumbBtn = CreateFrame("Button", nil, skillsSlider)
    skillsThumbBtn:SetFrameLevel(skillsSlider:GetFrameLevel() + 2)
    skillsThumbBtn:EnableMouse(true)
    skillsThumbBtn:RegisterForDrag("LeftButton")
    skillsThumbBtn:SetAllPoints(skillsSlider:GetThumbTexture())

    skillsThumbBtn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.isDragging = true
        self.startY = select(2, GetCursorPosition())
        self.startVal = skillsSlider:GetValue()
        local min, max = skillsSlider:GetMinMaxValues()
        self.valRange = max - min
        self.heightRange = skillsSlider:GetHeight() - self:GetHeight()
        if self.heightRange < 1 then self.heightRange = 1 end
    end)

    skillsThumbBtn:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.isDragging = false
    end)

    skillsThumbBtn:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currY = select(2, GetCursorPosition())
            local diff = self.startY - currY
            local delta = (diff / self.heightRange) * self.valRange
            skillsSlider:SetValue(self.startVal + delta)
        end
    end)

    BCF.WireScrollbar(skillsScrollFrame, skillsContent, skillsSlider, skillsThumb, skillsContainer)

    -- ========================================================================
    -- PVP TAB CONTENT (scrollable pvp info)
    -- ========================================================================
    local pvpContainer = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
    pvpContainer:SetAllPoints()
    pvpContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    pvpContainer:SetBackdropColor(T.Background[1], T.Background[2], T.Background[3], 1)
    pvpContainer:Hide()

    local pvpScrollFrame = CreateFrame("ScrollFrame", nil, pvpContainer)
    pvpScrollFrame:SetPoint("TOPLEFT", 0, 0)
    pvpScrollFrame:SetPoint("BOTTOMRIGHT", -8, 0)

    local pvpContent = CreateFrame("Frame", nil, pvpScrollFrame)
    pvpContent:SetWidth(pvpScrollFrame:GetWidth())
    pvpContent:SetHeight(1)
    pvpScrollFrame:SetScrollChild(pvpContent)
    pvpScrollFrame:SetScript("OnSizeChanged", function(self, w) pvpContent:SetWidth(w - 5) end)
    BCF.PvPContent = pvpContent
    BCF.PvPContainer = pvpContainer

    local pvpSlider = CreateFrame("Slider", nil, pvpContainer, "BackdropTemplate")
    pvpSlider:SetPoint("TOPRIGHT", 0, 0)
    pvpSlider:SetPoint("BOTTOMRIGHT", 0, 0)
    pvpSlider:SetWidth(6)
    pvpSlider:SetFrameLevel(pvpScrollFrame:GetFrameLevel() + 5)
    pvpSlider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    pvpSlider:SetBackdropColor(0, 0, 0, 0.2)

    local pvpThumb = pvpSlider:CreateTexture(nil, "ARTWORK")
    pvpThumb:SetSize(6, 30)
    pvpThumb:SetColorTexture(unpack(T.Accent))
    pvpSlider:SetThumbTexture(pvpThumb)

    pvpSlider:SetOrientation("VERTICAL")
    pvpSlider:SetValueStep(1)
    pvpSlider:EnableMouse(false)

    local pvpThumbBtn = CreateFrame("Button", nil, pvpSlider)
    pvpThumbBtn:SetFrameLevel(pvpSlider:GetFrameLevel() + 2)
    pvpThumbBtn:EnableMouse(true)
    pvpThumbBtn:RegisterForDrag("LeftButton")
    pvpThumbBtn:SetAllPoints(pvpSlider:GetThumbTexture())

    pvpThumbBtn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.isDragging = true
        self.startY = select(2, GetCursorPosition())
        self.startVal = pvpSlider:GetValue()
        local min, max = pvpSlider:GetMinMaxValues()
        self.valRange = max - min
        self.heightRange = pvpSlider:GetHeight() - self:GetHeight()
        if self.heightRange < 1 then self.heightRange = 1 end
    end)

    pvpThumbBtn:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.isDragging = false
    end)

    pvpThumbBtn:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currY = select(2, GetCursorPosition())
            local diff = self.startY - currY
            local delta = (diff / self.heightRange) * self.valRange
            pvpSlider:SetValue(self.startVal + delta)
        end
    end)

    BCF.WireScrollbar(pvpScrollFrame, pvpContent, pvpSlider, pvpThumb, pvpContainer)

    -- ========================================================================
    -- CURRENCY TAB CONTENT (scrollable currency list)
    -- ========================================================================
    local currencyContainer = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
    currencyContainer:SetAllPoints()
    currencyContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    currencyContainer:SetBackdropColor(T.Background[1], T.Background[2], T.Background[3], 1)
    currencyContainer:Hide()

    local currencyScrollFrame = CreateFrame("ScrollFrame", nil, currencyContainer)
    currencyScrollFrame:SetPoint("TOPLEFT", 0, 0)
    currencyScrollFrame:SetPoint("BOTTOMRIGHT", -8, 0)

    local currencyContent = CreateFrame("Frame", nil, currencyScrollFrame)
    currencyContent:SetWidth(currencyScrollFrame:GetWidth())
    currencyContent:SetHeight(1)
    currencyScrollFrame:SetScrollChild(currencyContent)
    currencyScrollFrame:SetScript("OnSizeChanged", function(self, w) currencyContent:SetWidth(w - 5) end)
    BCF.CurrencyContent = currencyContent
    BCF.CurrencyContainer = currencyContainer

    local currencySlider = CreateFrame("Slider", nil, currencyContainer, "BackdropTemplate")
    currencySlider:SetPoint("TOPRIGHT", 0, 0)
    currencySlider:SetPoint("BOTTOMRIGHT", 0, 0)
    currencySlider:SetWidth(6)
    currencySlider:SetFrameLevel(currencyScrollFrame:GetFrameLevel() + 5)
    currencySlider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    currencySlider:SetBackdropColor(0, 0, 0, 0.2)

    local currencyThumb = currencySlider:CreateTexture(nil, "ARTWORK")
    currencyThumb:SetSize(6, 30)
    currencyThumb:SetColorTexture(unpack(T.Accent))
    currencySlider:SetThumbTexture(currencyThumb)

    currencySlider:SetOrientation("VERTICAL")
    currencySlider:SetValueStep(1)
    currencySlider:EnableMouse(false)

    local currencyThumbBtn = CreateFrame("Button", nil, currencySlider)
    currencyThumbBtn:SetFrameLevel(currencySlider:GetFrameLevel() + 2)
    currencyThumbBtn:EnableMouse(true)
    currencyThumbBtn:RegisterForDrag("LeftButton")
    currencyThumbBtn:SetAllPoints(currencySlider:GetThumbTexture())

    currencyThumbBtn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.isDragging = true
        self.startY = select(2, GetCursorPosition())
        self.startVal = currencySlider:GetValue()
        local min, max = currencySlider:GetMinMaxValues()
        self.valRange = max - min
        self.heightRange = currencySlider:GetHeight() - self:GetHeight()
        if self.heightRange < 1 then self.heightRange = 1 end
    end)

    currencyThumbBtn:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.isDragging = false
    end)

    currencyThumbBtn:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currY = select(2, GetCursorPosition())
            local diff = self.startY - currY
            local delta = (diff / self.heightRange) * self.valRange
            currencySlider:SetValue(self.startVal + delta)
        end
    end)

    BCF.WireScrollbar(currencyScrollFrame, currencyContent, currencySlider, currencyThumb, currencyContainer)

    -- ========================================================================
    -- PET TAB CONTENT (model left, stats right, info bottom)
    -- Wrapped in do...end to scope locals (Lua 200 local variable limit)
    -- ========================================================================
    do
        local INFO_BAR_H = 50
        local MODEL_W_PCT = 0.35 -- model takes 35% width

        local petContainer = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
        petContainer:SetAllPoints()
        petContainer:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        petContainer:SetBackdropColor(T.Background[1], T.Background[2], T.Background[3], 1)
        petContainer:Hide()
        BCF.PetContainer = petContainer

        -- LEFT: Pet model (35% width, full height minus info bar)
        local petModel = CreateFrame("PlayerModel", nil, petContainer)
        petModel:SetPoint("TOPLEFT", 0, 0)
        petModel:SetPoint("BOTTOMLEFT", 0, INFO_BAR_H)
        petModel:SetWidth(T.MainWidth * MODEL_W_PCT)
        petModel:SetFrameLevel(petContainer:GetFrameLevel() + 1)
        if UnitExists("pet") then petModel:SetUnit("pet") end
        petModel:SetFacing(math.rad(-15))
        petModel:EnableMouse(true)
        petModel:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self.isRotating = true
                self.startX = GetCursorPosition()
                self.startRotation = self:GetFacing() or 0
            end
        end)
        petModel:SetScript("OnMouseUp", function(self) self.isRotating = false end)
        petModel:SetScript("OnUpdate", function(self)
            if self.isRotating and self.startRotation then
                local x = GetCursorPosition()
                local diff = (x - self.startX) * 0.015
                self:SetFacing(self.startRotation + diff)
            end
        end)
        petModel:SetScript("OnShow", function(self)
            if UnitExists("pet") then self:SetUnit("pet") end
        end)
        BCF.PetModel = petModel

        -- RIGHT: Scrollable stats panel (55% width, full height minus info bar)
        local petStatsPanel = CreateFrame("Frame", nil, petContainer, "BackdropTemplate")
        petStatsPanel:SetPoint("TOPLEFT", petModel, "TOPRIGHT", 0, 0)
        petStatsPanel:SetPoint("BOTTOMRIGHT", petContainer, "BOTTOMRIGHT", 0, INFO_BAR_H)
        BCF.ApplyPanelStyle(petStatsPanel, true)

        local petScrollFrame = CreateFrame("ScrollFrame", nil, petStatsPanel)
        petScrollFrame:SetPoint("TOPLEFT", 0, 0)
        petScrollFrame:SetPoint("BOTTOMRIGHT", -8, 0)
        BCF.PetScrollFrame = petScrollFrame

        local petContent = CreateFrame("Frame", nil, petScrollFrame)
        petContent:SetWidth(petScrollFrame:GetWidth())
        petContent:SetHeight(1)
        petScrollFrame:SetScrollChild(petContent)
        petScrollFrame:SetScript("OnSizeChanged", function(self, w) petContent:SetWidth(w - 5) end)
        BCF.PetScrollContent = petContent

        -- Custom slider for stats
        local petSlider = CreateFrame("Slider", nil, petStatsPanel, "BackdropTemplate")
        petSlider:SetPoint("TOPRIGHT", 0, 0)
        petSlider:SetPoint("BOTTOMRIGHT", 0, 0)
        petSlider:SetWidth(6)
        petSlider:SetFrameLevel(petScrollFrame:GetFrameLevel() + 5)
        petSlider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        petSlider:SetBackdropColor(0, 0, 0, 0.2)
        BCF.PetSlider = petSlider

        local petThumb = petSlider:CreateTexture(nil, "ARTWORK")
        petThumb:SetSize(6, 30)
        petThumb:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.8)
        petSlider:SetThumbTexture(petThumb)

        local petThumbBtn = CreateFrame("Button", nil, petSlider)
        petThumbBtn:SetAllPoints(petSlider:GetThumbTexture())
        petThumbBtn:RegisterForDrag("LeftButton")
        petThumbBtn:SetScript("OnDragStart", function(self)
            self.isDragging = true
            self.startY = select(2, GetCursorPosition())
            self.startVal = petSlider:GetValue()
        end)
        petThumbBtn:SetScript("OnDragStop", function(self) self.isDragging = false end)
        petThumbBtn:SetScript("OnUpdate", function(self)
            if self.isDragging then
                local y = select(2, GetCursorPosition())
                local scale = petSlider:GetEffectiveScale()
                local diff = (self.startY - y) / scale
                local minVal, maxVal = petSlider:GetMinMaxValues()
                local newVal = math.max(minVal, math.min(maxVal, self.startVal + diff))
                petSlider:SetValue(newVal)
            end
        end)

        BCF.WireScrollbar(petScrollFrame, petContent, petSlider, petThumb, petStatsPanel)

        -- BOTTOM: Info bar (full width, fixed height at bottom)
        local petInfoBar = CreateFrame("Frame", nil, petContainer, "BackdropTemplate")
        petInfoBar:SetPoint("BOTTOMLEFT", 0, 0)
        petInfoBar:SetPoint("BOTTOMRIGHT", 0, 0)
        petInfoBar:SetHeight(INFO_BAR_H)
        BCF.ApplyPanelStyle(petInfoBar, true)
        BCF.PetInfoBar = petInfoBar

        -- Info bar left: Name + Level/Family
        local petNameText = BCF.CleanFont(petInfoBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"))
        petNameText:SetPoint("TOPLEFT", 10, -6)
        petNameText:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3])
        BCF.PetNameText = petNameText

        local petLevelText = BCF.CleanFont(petInfoBar:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        petLevelText:SetPoint("LEFT", petNameText, "RIGHT", 10, 0)
        petLevelText:SetTextColor(T.TextSecondary[1], T.TextSecondary[2], T.TextSecondary[3])
        BCF.PetLevelText = petLevelText

        -- Info bar left row 2: Loyalty + Training Points
        local loyaltyText = BCF.CleanFont(petInfoBar:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        loyaltyText:SetPoint("TOPLEFT", petNameText, "BOTTOMLEFT", 0, -2)
        loyaltyText:SetTextColor(T.TextSecondary[1], T.TextSecondary[2], T.TextSecondary[3])
        BCF.PetLoyaltyText = loyaltyText

        -- Happiness overlay: bottom-right corner of pet model
        local happyLabel = BCF.CleanFont(petContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        happyLabel:SetPoint("BOTTOMRIGHT", petModel, "BOTTOMRIGHT", -6, 6)
        BCF.PetHappyLabel = happyLabel

        local happyIcon = petContainer:CreateTexture(nil, "OVERLAY")
        happyIcon:SetSize(18, 18)
        happyIcon:SetPoint("RIGHT", happyLabel, "LEFT", -4, 0)
        happyIcon:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
        BCF.PetHappyIcon = happyIcon

        -- XP bar (bottom of info bar, full width)
        local petXPBar = CreateFrame("StatusBar", nil, petInfoBar)
        petXPBar:SetPoint("BOTTOMLEFT", 10, 4)
        petXPBar:SetPoint("BOTTOMRIGHT", -10, 4)
        petXPBar:SetHeight(10)
        petXPBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        petXPBar:SetStatusBarColor(T.Accent[1] * 0.8, T.Accent[2] * 0.8, T.Accent[3] * 0.8, 0.8)
        petXPBar:SetMinMaxValues(0, 1)
        local xpBarBg = petXPBar:CreateTexture(nil, "BACKGROUND")
        xpBarBg:SetAllPoints()
        xpBarBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        xpBarBg:SetVertexColor(0.1, 0.1, 0.12, 1)
        local xpBarText = BCF.CleanFont(petXPBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
        xpBarText:SetPoint("CENTER")
        xpBarText:SetTextColor(1, 1, 1, 0.9)
        BCF.PetXPBar = petXPBar
        BCF.PetXPBarText = xpBarText

        local tpText = BCF.CleanFont(petInfoBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
        tpText:SetPoint("BOTTOMLEFT", petXPBar, "TOPLEFT", 0, 2)
        tpText:SetTextColor(T.TextMuted[1], T.TextMuted[2], T.TextMuted[3])
        BCF.PetTPText = tpText
    end -- do (pet container scope)

    -- ========================================================================
    -- TAB WIDTH UPDATE FUNCTIONS
    -- ========================================================================
    local function UpdateHeaderTabWidths()
        local currentWidth = f:GetWidth()
        local tw = currentWidth / #headerTabNames
        for i, tab in ipairs(headerTabs) do
            tab:SetWidth(tw)
            tab:ClearAllPoints()
            tab:SetPoint("LEFT", headerTabContainer, "LEFT", (i - 1) * tw, 0)
        end
    end

    local function UpdateSubTabWidths()
        local currentWidth = f:GetWidth()
        local tw = currentWidth / #subTabNames
        for i, tab in ipairs(subTabs) do
            tab:SetWidth(tw)
            tab:ClearAllPoints()
            tab:SetPoint("LEFT", subTabContainer, "LEFT", (i - 1) * tw, 0)
        end
    end

    -- Compatibility alias
    local function UpdateTabWidths()
        UpdateHeaderTabWidths()
        UpdateSubTabWidths()
    end

    -- Forward declarations (defined later, needed by SwitchHeaderTab)
    local EXPANDED_WIDTH, COLLAPSED_WIDTH = 840, 520
    local MODEL_X_EXPANDED, MODEL_X_COLLAPSED = 310, 150
    local toggleBtn     -- created after animation section
    gearSlotFrames = {} -- populated by CreateOrUpdateSlot
    -- Animation state (forward-declared, assigned after animFrame creation)
    local isAnimating = false
    local targetWidth, startWidth = 0, 0
    local targetModelX, startModelX = 0, 0
    local startSlotWidth, targetSlotWidth = 0, 0
    local startTime = 0
    local DURATION = 0.3
    local animFrame -- created after toggle button
    local AnimateToState
    local wishlistClickBlocker
    local blockerHoverFrame

    -- ========================================================================
    -- SUB-TAB SWITCHING (Stats/Equipment/Sets/Wishlist under Character)
    -- ========================================================================
    local function SafeShowFrame(frame)
        if not frame then return end
        if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
        frame:Show()
    end

    local function SafeHideFrame(frame)
        if not frame then return end
        if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
        frame:Hide()
    end

    local function ResetSideStatsContent()
        if not (BCF.SideStats and BCF.SideStats.Content) then return end
        if BCF.SideStats.ScrollFrame then
            BCF.SideStats.ScrollFrame:SetVerticalScroll(0)
        end
        if BCF.SideStats.ComingSoon then
            SafeHideFrame(BCF.SideStats.ComingSoon)
        end
        BCF.ClearContainer(BCF.SideStats.Content)
    end

    local contentFadeToken = 0
    local function FadeSideStatsContent()
        if not (BCF.SideStats and BCF.SideStats.Content) then return end
        local container = BCF.SideStats.Content
        contentFadeToken = contentFadeToken + 1
        local myToken = contentFadeToken

        C_Timer.After(0, function()
            if myToken ~= contentFadeToken then return end
            if not container or not container:IsShown() then return end

            local children = { container:GetChildren() }
            for _, child in ipairs(children) do
                if child and child.SetAlpha and child.GetAlpha then
                    local isProtected = child.IsProtected and child:IsProtected()
                    if not isProtected then
                        UIFrameFadeRemoveFrame(child)
                        child:SetAlpha(0)
                        UIFrameFadeIn(child, 0.12, 0, 1)
                    end
                end
            end
        end)
    end

    local bootstrapQueuedForCombatEnd = false
    local bootstrapComplete = false

    local function SetBootstrapQueued(queued)
        bootstrapQueuedForCombatEnd = queued and true or false
        if bootstrapQueuedForCombatEnd then
            deferredInitGlow:Show()
            deferredInitMask:Show()
        else
            deferredInitGlow:Hide()
            deferredInitMask:Hide()
        end
    end

    local function UpdateWishlistClickBlocker()
        if not wishlistClickBlocker then return end
        local shouldBlock = (activeHeaderTab == 1 and activeSubTab == 3)
        if shouldBlock then
            wishlistClickBlocker:Show()
        else
            wishlistClickBlocker:Hide()
        end
    end

    local function SwitchSubTab(index)
        activeSubTab = index
        BCF.activeSubTab = index
        local canRetargetSlots = not InCombatLockdown()

        -- Update sub-tab visual states (safe in combat — no Show/Hide)
        for i, tab in ipairs(subTabs) do
            if i == index then
                tab:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 1)
                tab.label:SetTextColor(unpack(T.Accent))
            else
                tab:SetBackdropColor(0.06, 0.06, 0.09, 1)
                tab.label:SetTextColor(unpack(T.TextSecondary))
            end
        end

        -- Reset picker state on any tab switch
        BCF.WishlistPickerOpen = false

        -- Disable gear slot interaction on wishlist tab
        -- SetID(255) = invalid inventory slot, C-level ItemButton handler picks up nothing
        -- Unregister drag/clicks at Lua level, OnEnter/OnLeave (tooltips) unaffected
        -- Skip in combat: ItemButton frames are protected, re-registration taints
        if canRetargetSlots then
            for slotID, frame in pairs(gearSlotFrames) do
                if index == 3 then
                    frame:SetID(255)
                    frame:RegisterForDrag()
                    frame:RegisterForClicks()
                else
                    frame:SetID(slotID)
                    frame:RegisterForDrag("LeftButton")
                    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                end
                if frame.GemButtons then
                    for i = 1, 4 do
                        if frame.GemButtons[i] then
                            frame.GemButtons[i]:EnableMouse(true)
                        end
                    end
                end
            end
        end

        -- All sub-tabs share character model/gear + SideStats panel
        if index == 1 or index == 2 then
            -- Show character tab (model + gear + side panel)
            SafeShowFrame(tabFrames[1])
            SafeHideFrame(tabFrames[3])

            -- Re-dress model if coming from Wishlist tab (which undresses it)
            if BCF.ModelFrame then
                BCF.LastGearHash = nil -- Force model refresh
            end

            -- Always show SideStats panel, but swap content
            if BCF.SideStats and BCF.SideStats.Content then
                SafeShowFrame(BCF.SideStats)
                ResetSideStatsContent()

                -- Refresh appropriate content
                if index == 1 then
                    if BCF.RefreshStats then BCF.RefreshStats(BCF.SideStats) end
                    BCF.dirtyStats = false
                elseif index == 2 then
                    if BCF.RefreshSets then BCF.RefreshSets(BCF.SideStats) end
                end
                FadeSideStatsContent()
            end

            -- When leaving Wishlist in combat, redraw slot visuals immediately from live gear.
            if InCombatLockdown() and BCF.RefreshCombatSlotVisual and BCF.GearSlotFrames then
                for slotID in pairs(BCF.GearSlotFrames) do
                    BCF.RefreshCombatSlotVisual(slotID)
                end
            end

            if BCF.RefreshCharacter then BCF.RefreshCharacter() end
        elseif index == 3 then
            -- Wishlist tab (list view in SideStats, BiS preview on paper doll)
            SafeShowFrame(tabFrames[1])

            -- Preview active wishlist or show naked paperdoll
            local charKey = BCF.GetCharacterKey()
            local wSettings = BCF.DB.Characters and BCF.DB.Characters[charKey]
                and BCF.DB.Characters[charKey].WishlistSettings
            local activeList = wSettings and wSettings.ActiveList

            if activeList then
                -- Re-sync via active-list entry point so slot/model state always
                -- matches the selected wishlist after switching from other sub-tabs.
                if BCF.SetActiveWishlist then
                    BCF.SetActiveWishlist(activeList)
                elseif BCF.PreviewWishlist then
                    BCF.PreviewWishlist(activeList)
                end
            else
                -- No active list: naked paperdoll
                if BCF.ModelFrame then BCF.ModelFrame:Undress() end
                if BCF.GearSlotFrames then
                    for _, frame in pairs(BCF.GearSlotFrames) do
                        frame.Icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                        frame.Icon:SetVertexColor(0.4, 0.4, 0.4)
                        frame.IconBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
                        frame.ILvlOverlay:SetText("")
                        if frame.ItemName then frame.ItemName:SetText("") end
                        if frame.EnchantText then frame.EnchantText:SetText("") end
                        if frame.InfoFrame then frame.InfoFrame:Hide() end
                        if frame.FlyoutBtn then frame.FlyoutBtn:Hide() end
                        if frame.Cooldown then frame.Cooldown:Clear() end
                        for i = 1, 4 do
                            if frame.GemButtons and frame.GemButtons[i] then
                                frame.GemButtons[i]:Hide()
                            end
                        end
                    end
                end
            end

            if BCF.SideStats and BCF.SideStats.Content then
                SafeShowFrame(BCF.SideStats)
                ResetSideStatsContent()
                if BCF.RefreshWishlist then BCF.RefreshWishlist(BCF.SideStats) end
                FadeSideStatsContent()
            end
        end
        UpdateWishlistClickBlocker()
    end

    -- ========================================================================
    -- HEADER TAB SWITCHING (Character/Pet/Reputation/Skills/PvP/Currency)
    -- ========================================================================
    local charTabWasExpanded = false -- remembers Character/Pet expanded state across tab switches

    local function SwitchHeaderTab(index)
        activeHeaderTab = index
        BCF.activeHeaderTab = index

        -- Update header tab visual states (safe — SetBackdropColor/SetTextColor are not protected)
        for i, tab in ipairs(headerTabs) do
            if i == index then
                tab:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 1)
                tab.label:SetTextColor(unpack(T.Accent))
            else
                tab:SetBackdropColor(0.06, 0.06, 0.09, 1)
                tab.label:SetTextColor(unpack(T.TextSecondary))
            end
        end

        -- Get selected tab name
        local tabName = headerTabNames[index]

        -- Collapsed-only tabs: Rep, Skills, PvP, Currency (no expand allowed)
        local isCollapsedOnly = (tabName == "Reputation" or tabName == "Skills"
            or tabName == "PvP" or tabName == "Currency")

        -- Animate collapse when entering a collapsed-only tab
        if isCollapsedOnly and BCF.DB.General.IsExpanded and not isAnimating then
            charTabWasExpanded = true
            targetWidth = COLLAPSED_WIDTH
            targetModelX = MODEL_X_COLLAPSED
            startSlotWidth = 200
            targetSlotWidth = 40
            startWidth = f:GetWidth()
            startModelX = MODEL_X_EXPANDED
            startTime = GetTime()
            isAnimating = true
            if animFrame then animFrame:Show() end
        end

        -- Animate expand when returning to Character or Pet tab
        if (index == 1 or tabName == "Pet") and charTabWasExpanded and not isAnimating then
            charTabWasExpanded = false
            BCF.DB.General.IsExpanded = true
            BCF.DB.General.ShowItemDetails = true
            if BCF.RefreshCharacter then BCF.RefreshCharacter() end
            if BCF.RefreshTitleBar then BCF.RefreshTitleBar() end
            -- Reset slots to collapsed visual state before animating out
            for slotID, frame in pairs(gearSlotFrames) do
                if slotID ~= 16 and slotID ~= 17 and slotID ~= 18 then
                    frame:SetWidth(40)
                    if frame.InfoFrame then frame.InfoFrame:SetAlpha(0) end
                end
                if frame.FlyoutBtn then frame.FlyoutBtn:SetAlpha(0) end
            end
            f:SetWidth(COLLAPSED_WIDTH)
            BCF.UpdateLayout(MODEL_X_COLLAPSED)
            toggleBtn.Text:SetText("<")
            targetWidth = EXPANDED_WIDTH
            targetModelX = MODEL_X_EXPANDED
            startSlotWidth = 40
            targetSlotWidth = 200
            startWidth = COLLAPSED_WIDTH
            startModelX = MODEL_X_COLLAPSED
            startTime = GetTime()
            isAnimating = true
            if animFrame then animFrame:Show() end
        end

        -- Show/hide toggle button based on tab type
        if isCollapsedOnly then
            toggleBtn:Hide()
        else
            toggleBtn:Show()
        end

        -- Hide all module frames first
        reputationContainer:Hide()
        skillsContainer:Hide()
        pvpContainer:Hide()
        currencyContainer:Hide()
        if BCF.PetContainer then BCF.PetContainer:Hide() end

        -- Show/hide sub-tabs based on whether Character is selected
        if index == 1 then
            -- Character header: show sub-tabs row
            subTabContainer:Show()
            headerComingSoon:Hide()
            UpdateContentAreaPosition()
            -- Activate current sub-tab content
            SwitchSubTab(activeSubTab)
        elseif tabName == "Reputation" then
            -- Reputation header: show faction list
            subTabContainer:Hide()
            headerComingSoon:Hide()
            reputationContainer:Show()
            UpdateContentAreaPosition()
            SafeHideFrame(tabFrames[1])
            SafeHideFrame(tabFrames[3])
            SafeHideFrame(BCF.SideStats)
            if BCF.RefreshReputation then
                BCF.RefreshReputation(BCF.ReputationContent)
            end
        elseif tabName == "Skills" then
            -- Skills header: show skills list
            subTabContainer:Hide()
            headerComingSoon:Hide()
            skillsContainer:Show()
            UpdateContentAreaPosition()
            SafeHideFrame(tabFrames[1])
            SafeHideFrame(tabFrames[3])
            SafeHideFrame(BCF.SideStats)
            if BCF.RefreshSkills then
                BCF.RefreshSkills(BCF.SkillsContent)
            end
        elseif tabName == "PvP" then
            -- PvP header: show PvP stats and arena teams
            subTabContainer:Hide()
            headerComingSoon:Hide()
            pvpContainer:Show()
            UpdateContentAreaPosition()
            SafeHideFrame(tabFrames[1])
            SafeHideFrame(tabFrames[3])
            SafeHideFrame(BCF.SideStats)
            if BCF.RefreshPvP then
                BCF.RefreshPvP(BCF.PvPContent)
            end
            if ArenaTeamRoster then
                pcall(ArenaTeamRoster, 1)
                pcall(ArenaTeamRoster, 2)
                pcall(ArenaTeamRoster, 3)
            end
        elseif tabName == "Currency" then
            -- Currency header: show currency list
            subTabContainer:Hide()
            headerComingSoon:Hide()
            currencyContainer:Show()
            UpdateContentAreaPosition()
            SafeHideFrame(tabFrames[1])
            SafeHideFrame(tabFrames[3])
            SafeHideFrame(BCF.SideStats)
            if BCF.RefreshCurrency then
                BCF.RefreshCurrency(BCF.CurrencyContent)
            end
        elseif tabName == "Pet" then
            -- Pet header: show pet model and stats
            subTabContainer:Hide()
            headerComingSoon:Hide()
            if BCF.PetContainer then BCF.PetContainer:Show() end
            UpdateContentAreaPosition()
            SafeHideFrame(tabFrames[1])
            SafeHideFrame(tabFrames[3])
            SafeHideFrame(BCF.SideStats)
            if BCF.RefreshPet then
                BCF.RefreshPet(BCF.PetContainer)
            end
        else
            -- Other headers: hide sub-tabs, show Coming Soon
            subTabContainer:Hide()
            headerComingSoon:Show()
            UpdateContentAreaPosition()
            SafeHideFrame(tabFrames[1])
            SafeHideFrame(tabFrames[3])
            SafeHideFrame(BCF.SideStats)
        end
        UpdateWishlistClickBlocker()
    end

    -- Post-combat: refresh gear display after equipment changes
    local slotRegenFrame = CreateFrame("Frame")
    slotRegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    slotRegenFrame:SetScript("OnEvent", function()
        if BCF.MainFrame and BCF.MainFrame:IsShown() and BCF.RefreshCharacter then
            BCF.RefreshCharacter()
        end
    end)

    -- ========================================================================
    -- CREATE HEADER TABS (text only, no icons)
    -- ========================================================================
    local headerTabWidth = f:GetWidth() / #headerTabNames
    for i, name in ipairs(headerTabNames) do
        local tab = CreateFrame("Button", nil, headerTabContainer, "BackdropTemplate")
        tab:SetSize(headerTabWidth, T.TabHeight)
        tab:SetPoint("LEFT", (i - 1) * headerTabWidth, 0)
        tab:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })

        tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tab.label:SetPoint("CENTER", 0, 0)
        tab.label:SetText(name)

        tab:SetScript("OnClick", function()
            if BCF.optionsPanelOpen then
                BCF.optionsPanelOpen = false
                configTex:SetVertexColor(0.5, 0.5, 0.5, 1)
                configGlow:Hide()
                optionsPanel:Hide()
            end
            SwitchHeaderTab(i)
        end)
        headerTabs[i] = tab
    end

    -- Expose for dynamic tab injection (test command)
    BCF._headerTabNames = headerTabNames
    BCF._headerTabs = headerTabs
    BCF._headerTabContainer = headerTabContainer

    -- Rebuild header tabs from headerTabNames (add/remove Pet dynamically)
    function BCF.RebuildHeaderTabs()
        -- Remove old tab buttons
        for _, tab in ipairs(headerTabs) do
            tab:Hide()
            tab:SetParent(nil)
        end
        wipe(headerTabs)
        -- Create new ones
        local tw = f:GetWidth() / #headerTabNames
        for i, name in ipairs(headerTabNames) do
            local tab = CreateFrame("Button", nil, headerTabContainer, "BackdropTemplate")
            tab:SetSize(tw, T.TabHeight)
            tab:SetPoint("LEFT", (i - 1) * tw, 0)
            tab:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            tab.label:SetPoint("CENTER", 0, 0)
            tab.label:SetText(name)
            tab:SetScript("OnClick", function()
                if BCF.optionsPanelOpen then
                    BCF.optionsPanelOpen = false
                    configTex:SetVertexColor(0.5, 0.5, 0.5, 1)
                    configGlow:Hide()
                    optionsPanel:Hide()
                end
                SwitchHeaderTab(i)
            end)
            headerTabs[i] = tab
        end
        BCF._headerTabs = headerTabs
        -- Re-select current tab
        SwitchHeaderTab(1)
    end

    -- ========================================================================
    -- CREATE SUB-TABS (text only, no icons)
    -- ========================================================================
    local subTabWidth = f:GetWidth() / #subTabNames
    for i, name in ipairs(subTabNames) do
        local tab = CreateFrame("Button", nil, subTabContainer, "BackdropTemplate")
        tab:SetSize(subTabWidth, T.TabHeight)
        tab:SetPoint("LEFT", (i - 1) * subTabWidth, 0)
        tab:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })

        tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tab.label:SetPoint("CENTER", 0, 0)
        tab.label:SetText(name)

        tab:SetScript("OnClick", function()
            if BCF.optionsPanelOpen then
                BCF.optionsPanelOpen = false
                configTex:SetVertexColor(0.5, 0.5, 0.5, 1)
                configGlow:Hide()
                optionsPanel:Hide()
            end
            SwitchSubTab(i)
        end)
        subTabs[i] = tab
        tabs[i] = tab -- Compatibility alias
    end

    -- De-highlight / re-highlight all tabs
    local function DimAllTabs()
        for _, tab in ipairs(headerTabs) do
            tab:SetBackdropColor(0.06, 0.06, 0.09, 1)
            tab.label:SetTextColor(unpack(T.TextSecondary))
        end
        for _, tab in ipairs(subTabs) do
            tab:SetBackdropColor(0.06, 0.06, 0.09, 1)
            tab.label:SetTextColor(unpack(T.TextSecondary))
        end
    end

    local function RestoreTabHighlights()
        -- Restore active header tab
        for i, tab in ipairs(headerTabs) do
            if i == activeHeaderTab then
                tab:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 1)
                tab.label:SetTextColor(unpack(T.Accent))
            else
                tab:SetBackdropColor(0.06, 0.06, 0.09, 1)
                tab.label:SetTextColor(unpack(T.TextSecondary))
            end
        end
        -- Restore active sub-tab
        for i, tab in ipairs(subTabs) do
            if i == activeSubTab then
                tab:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 1)
                tab.label:SetTextColor(unpack(T.Accent))
            else
                tab:SetBackdropColor(0.06, 0.06, 0.09, 1)
                tab.label:SetTextColor(unpack(T.TextSecondary))
            end
        end
    end

    -- Open/close options panel (full overlay)
    local optionsWasCollapsed = false

    local function CloseOptionsPanel()
        if not BCF.optionsPanelOpen then return end
        BCF.optionsPanelOpen = false
        configTex:SetVertexColor(0.5, 0.5, 0.5, 1)
        configGlow:Hide()
        optionsPanel:Hide()
        RestoreTabHighlights()
        -- Re-collapse if we force-expanded
        if optionsWasCollapsed and not isAnimating then
            optionsWasCollapsed = false
            targetWidth = COLLAPSED_WIDTH
            targetModelX = MODEL_X_COLLAPSED
            startSlotWidth = 200
            targetSlotWidth = 40
            startWidth = f:GetWidth()
            startModelX = MODEL_X_EXPANDED
            startTime = GetTime()
            isAnimating = true
            if animFrame then animFrame:Show() end
        end
    end

    -- Called from OnHide (ESC): reset options unless reload dialog is pending
    BCF.CloseOptionsSilent = function()
        if not BCF.optionsPanelOpen then return end
        -- If reload dialog is showing, keep options state for next open
        if BCF._reloadOverlay and BCF._reloadOverlay:IsShown() then return end
        BCF.optionsPanelOpen = false
        configTex:SetVertexColor(0.5, 0.5, 0.5, 1)
        configGlow:Hide()
        optionsPanel:Hide()
        optionsWasCollapsed = false
        RestoreTabHighlights()
    end

    local function OpenOptionsPanel()
        if BCF.optionsPanelOpen then return end
        -- Expand if collapsed
        optionsWasCollapsed = not BCF.DB.General.IsExpanded
        if optionsWasCollapsed and not isAnimating then
            toggleBtn:GetScript("OnClick")(toggleBtn)
        end
        BCF.optionsPanelOpen = true
        configTex:SetVertexColor(T.Accent[1], T.Accent[2], T.Accent[3], 1)
        configGlow:Hide()
        DimAllTabs()
        -- Clear and rebuild options content
        BCF.ClearContainer(optContent)
        optContent.sections = {}
        BCF.BuildOptionsPanel(optContent)
        optScroll:SetVerticalScroll(0)
        optionsPanel:Show()
    end

    -- Wire config (gear) button OnClick — deferred to here so SwitchSubTab/subTabs are in scope
    local optionsQueuedForCombatEnd = false

    configBtn:SetScript("OnClick", function()
        if isAnimating then return end
        if BCF.optionsPanelOpen then
            CloseOptionsPanel()
        elseif InCombatLockdown() then
            if optionsQueuedForCombatEnd then
                -- Cancel queue
                optionsQueuedForCombatEnd = false
                configGlow:Hide()
            else
                -- Queue open for combat end
                optionsQueuedForCombatEnd = true
                configGlow.elapsed = 0
                configGlow:Show()
            end
        else
            OpenOptionsPanel()
        end
    end)

    -- Close options on combat start (queue reopen) / reopen on combat end
    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if BCF.optionsPanelOpen then
                CloseOptionsPanel()
                -- Queue reopen after combat
                optionsQueuedForCombatEnd = true
                configGlow.elapsed = 0
                configGlow:Show()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if optionsQueuedForCombatEnd then
                optionsQueuedForCombatEnd = false
                configGlow:Hide()
                if BCF.MainFrame and BCF.MainFrame:IsShown() then
                    OpenOptionsPanel()
                end
            end
        end
    end)

    -- ========================================================================
    -- UNIFIED TAB TOGGLE WITH VERTICAL ANIMATION (FRAME EXPANDS UPWARD)
    -- ========================================================================
    -- States: 1=Both, 2=HeaderOnly, 3=None, 4=SubOnly
    -- Cycle: Both -> HeaderOnly -> None -> SubOnly -> Both
    local TAB_STATE_BOTH = 1
    local TAB_STATE_HEADER_ONLY = 2
    local TAB_STATE_NONE = 3
    local TAB_STATE_SUB_ONLY = 4
    local tabState = TAB_STATE_BOTH
    -- Tab state managed directly.

    -- Animation constants
    local TAB_ANIM_DURATION = 0.25
    local TITLE_BAR_HEIGHT = 32
    local TAB_H = T.TabHeight
    local BASE_HEIGHT = T.MainHeight                                      -- Full height with all tabs visible (520)
    local CONTENT_HEIGHT = BASE_HEIGHT - TITLE_BAR_HEIGHT - TAB_H - TAB_H -- Content area height (432)

    -- Get frame height, tab heights, and content top offset for each state
    local function GetTargetState(state)
        local frameHeight, headerHeight, subHeight, contentTop, subTop
        if state == TAB_STATE_BOTH then
            frameHeight = BASE_HEIGHT
            headerHeight = TAB_H
            subHeight = TAB_H
            contentTop = -(TITLE_BAR_HEIGHT + TAB_H + TAB_H) -- -80
            subTop = -(TITLE_BAR_HEIGHT + TAB_H)             -- -56
        elseif state == TAB_STATE_HEADER_ONLY then
            frameHeight = BASE_HEIGHT - TAB_H
            headerHeight = TAB_H
            subHeight = 0
            contentTop = -(TITLE_BAR_HEIGHT + TAB_H) -- -56
            subTop = -(TITLE_BAR_HEIGHT + TAB_H)     -- -56
        elseif state == TAB_STATE_NONE then
            frameHeight = BASE_HEIGHT - TAB_H - TAB_H
            headerHeight = 0
            subHeight = 0
            contentTop = -TITLE_BAR_HEIGHT -- -32
            subTop = -TITLE_BAR_HEIGHT     -- -32
        else                               -- TAB_STATE_SUB_ONLY
            frameHeight = BASE_HEIGHT - TAB_H
            headerHeight = 0
            subHeight = TAB_H
            contentTop = -(TITLE_BAR_HEIGHT + TAB_H) -- -56
            subTop = -TITLE_BAR_HEIGHT               -- -32 (sub moves up)
        end
        return frameHeight, headerHeight, subHeight, contentTop, subTop
    end

    -- Animation frame
    local tabAnimFrame = CreateFrame("Frame")
    tabAnimFrame:Hide()
    local tabAnimStartTime = 0
    local tabAnimStartHeight, tabAnimTargetHeight = BASE_HEIGHT, BASE_HEIGHT
    local tabAnimStartHeaderHeight, tabAnimTargetHeaderHeight = TAB_H, TAB_H
    local tabAnimStartSubHeight, tabAnimTargetSubHeight = TAB_H, TAB_H
    local tabAnimStartContentTop, tabAnimTargetContentTop = -(TITLE_BAR_HEIGHT + TAB_H + TAB_H),
        -(TITLE_BAR_HEIGHT + TAB_H + TAB_H)
    local tabAnimStartSubTop, tabAnimTargetSubTop = -(TITLE_BAR_HEIGHT + TAB_H), -(TITLE_BAR_HEIGHT + TAB_H)
    local tabAnimStartY = 0                                      -- Track frame Y position for smooth animation
    local tabAnimStartTextOffset, tabAnimTargetTextOffset = 0, 0 -- Title text X offset for centering
    local tabAnimating = false

    -- Enable clipping on tab containers for height animation
    headerTabContainer:SetClipsChildren(true)
    subTabContainer:SetClipsChildren(true)

    -- Apply animated state with interpolated values
    local function ApplyAnimatedState(frameHeight, headerHeight, subHeight, contentTop, subTop, textOffset)
        -- Set frame height (Y position handled separately for smoothness)
        f:SetHeight(frameHeight)

        -- Header container height + alpha fade (clipping handles visibility)
        headerTabContainer:SetHeight(math.max(0.1, headerHeight)) -- min 0.1 to avoid SetHeight(0) issues
        headerTabContainer:SetAlpha(headerHeight / TAB_H)         -- fade with height
        if headerHeight > 0.5 then
            headerTabContainer:Show()
        else
            headerTabContainer:Hide()
        end

        -- Sub container position, height + alpha fade (interpolated)
        subTabContainer:ClearAllPoints()
        subTabContainer:SetPoint("TOPLEFT", 0, subTop)
        subTabContainer:SetPoint("TOPRIGHT", 0, subTop)
        subTabContainer:SetHeight(math.max(0.1, subHeight)) -- min 0.1 to avoid SetHeight(0) issues
        subTabContainer:SetAlpha(subHeight / TAB_H)         -- fade with height
        if subHeight > 0.5 and activeHeaderTab == 1 then
            subTabContainer:Show()
        elseif subHeight <= 0.5 then
            subTabContainer:Hide()
        end

        -- Content area position (interpolated)
        contentArea:ClearAllPoints()
        contentArea:SetPoint("TOPLEFT", 0, contentTop)
        contentArea:SetPoint("BOTTOMRIGHT", 0, 0)
    end

    -- Text is always left-aligned at LEFT + 10
    -- Title dropdown appears to the right of text in expanded view only

    -- Apply final state (non-animated) - no text offset here, handled by horizontal animation
    local function ApplyTabState(state)
        local frameHeight, headerHeight, subHeight, contentTop, subTop = GetTargetState(state)
        ApplyAnimatedState(frameHeight, headerHeight, subHeight, contentTop, subTop, nil)
        -- Sync collapsed state flags
        headerTabsCollapsed = (state == TAB_STATE_NONE or state == TAB_STATE_SUB_ONLY)
        subTabsCollapsed = (state == TAB_STATE_HEADER_ONLY or state == TAB_STATE_NONE)
    end

    tabAnimFrame:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local progress = (now - tabAnimStartTime) / TAB_ANIM_DURATION

        if progress >= 1 then
            -- Animation complete - apply final state
            local targetHeight, _, _, targetContentTop, targetSubTop = GetTargetState(tabState)

            -- Final Y position adjustment
            local point, relativeTo, relativePoint, xOfs, _ = f:GetPoint(1)
            if point and relativeTo then
                local targetY = tabAnimStartY + (tabAnimTargetHeight - tabAnimStartHeight) / 2
                f:ClearAllPoints()
                f:SetPoint(point, relativeTo, relativePoint, xOfs, targetY)
            end

            ApplyTabState(tabState)
            self:Hide()
            tabAnimating = false
        else
            -- Cubic ease-out
            progress = 1 - (1 - progress) ^ 3

            local newHeight = tabAnimStartHeight + (tabAnimTargetHeight - tabAnimStartHeight) * progress
            local headerHeight = tabAnimStartHeaderHeight +
                (tabAnimTargetHeaderHeight - tabAnimStartHeaderHeight) * progress
            local subHeight = tabAnimStartSubHeight + (tabAnimTargetSubHeight - tabAnimStartSubHeight) * progress
            local contentTop = tabAnimStartContentTop + (tabAnimTargetContentTop - tabAnimStartContentTop) * progress
            local subTop = tabAnimStartSubTop + (tabAnimTargetSubTop - tabAnimStartSubTop) * progress

            -- Smoothly animate frame Y position to keep bottom stationary
            local yOffset = (newHeight - tabAnimStartHeight) / 2
            local point, relativeTo, relativePoint, xOfs, _ = f:GetPoint(1)
            if point and relativeTo then
                f:ClearAllPoints()
                f:SetPoint(point, relativeTo, relativePoint, xOfs, tabAnimStartY + yOffset)
            end

            ApplyAnimatedState(newHeight, headerHeight, subHeight, contentTop, subTop, nil)
        end
    end)

    AnimateToState = function(newState)
        if tabAnimating then return end
        if newState == tabState then return end

        -- Get current state values
        local startHeight, startHeaderHeight, startSubHeight, startContentTop, startSubTop = GetTargetState(tabState)
        tabAnimStartHeight = f:GetHeight() -- Use actual current height
        tabAnimStartHeaderHeight = startHeaderHeight
        tabAnimStartSubHeight = startSubHeight
        tabAnimStartContentTop = startContentTop
        tabAnimStartSubTop = startSubTop

        -- Capture current frame Y position
        local _, _, _, _, currentY = f:GetPoint(1)
        tabAnimStartY = currentY or 0

        -- Get target state values
        local targetHeight, targetHeaderHeight, targetSubHeight, targetContentTop, targetSubTop = GetTargetState(
            newState)
        tabAnimTargetHeight = targetHeight
        tabAnimTargetHeaderHeight = targetHeaderHeight
        tabAnimTargetSubHeight = targetSubHeight
        tabAnimTargetContentTop = targetContentTop
        tabAnimTargetSubTop = targetSubTop

        tabState = newState
        tabAnimStartTime = GetTime()
        tabAnimating = true
        tabAnimFrame:Show()
    end

    local function CycleTabState()
        local nextState
        if activeHeaderTab == 1 then
            -- Character tab: full 4-state cycle
            if tabState == TAB_STATE_BOTH then
                nextState = TAB_STATE_HEADER_ONLY
            elseif tabState == TAB_STATE_HEADER_ONLY then
                nextState = TAB_STATE_NONE
            elseif tabState == TAB_STATE_NONE then
                nextState = TAB_STATE_SUB_ONLY
            else
                nextState = TAB_STATE_BOTH
            end
        else
            -- Non-Character tabs: only header toggle (no sub-tabs)
            if tabState == TAB_STATE_BOTH or tabState == TAB_STATE_HEADER_ONLY then
                nextState = TAB_STATE_NONE
            else
                nextState = TAB_STATE_HEADER_ONLY
            end
        end
        AnimateToState(nextState)
    end

    -- State indicator text (shows what clicking will HIDE)
    -- Both visible -> vv (click hides bottom), Header only -> v (click hides top)
    -- None visible -> ^ (click shows bottom), Sub only -> ^^ (click shows top)
    local function GetStateIndicator()
        if tabState == TAB_STATE_BOTH then
            return "vv"
        elseif tabState == TAB_STATE_HEADER_ONLY then
            return "v"
        elseif tabState == TAB_STATE_NONE then
            return "^"
        else
            return "^^"
        end
    end

    -- Unified toggle button (in title bar, left of config gear)
    local unifiedToggleBtn = CreateFrame("Button", "BCFUnifiedToggleBtn", titleBar, "BackdropTemplate")
    unifiedToggleBtn:SetSize(20, 16)
    unifiedToggleBtn:SetPoint("RIGHT", configBtn, "LEFT", -6, 0)
    unifiedToggleBtn:SetFrameLevel(titleBar:GetFrameLevel() + 5)
    unifiedToggleBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    unifiedToggleBtn:SetBackdropColor(0.1, 0.1, 0.12, 0.8)

    local unifiedToggleText = unifiedToggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    unifiedToggleText:SetPoint("CENTER", 0, 0)
    unifiedToggleText:SetText("vv")
    unifiedToggleText:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3])

    unifiedToggleBtn:SetScript("OnEnter", function()
        unifiedToggleText:SetTextColor(1, 1, 1)
        unifiedToggleBtn:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 0.9)
        GameTooltip:SetOwner(unifiedToggleBtn, "ANCHOR_LEFT")
        GameTooltip:SetText("Toggle Tabs")
        GameTooltip:AddLine("Click to cycle tab visibility", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    unifiedToggleBtn:SetScript("OnLeave", function()
        unifiedToggleText:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3])
        unifiedToggleBtn:SetBackdropColor(0.1, 0.1, 0.12, 0.8)
        GameTooltip:Hide()
    end)
    unifiedToggleBtn:SetScript("OnClick", function()
        CycleTabState()
        unifiedToggleText:SetText(GetStateIndicator())
    end)

    -- Hook into SwitchHeaderTab to handle state transitions
    local originalSwitchHeaderTab = SwitchHeaderTab
    local savedTabState = nil -- Remember state before leaving Character tab
    SwitchHeaderTab = function(index)
        originalSwitchHeaderTab(index)

        if index ~= 1 then
            -- Leaving Character: save current state, apply without sub-tabs
            if not savedTabState then
                savedTabState = tabState
            end
            local displayState = tabState
            if displayState == TAB_STATE_BOTH then
                displayState = TAB_STATE_HEADER_ONLY
            elseif displayState == TAB_STATE_SUB_ONLY then
                displayState = TAB_STATE_NONE
            end
            local frameHeight = GetTargetState(tabState)                     -- Keep original frame height
            local _, _, _, contentTop, subTop = GetTargetState(displayState) -- Content shifts up
            local headerVisible = (displayState ~= TAB_STATE_NONE)
            ApplyAnimatedState(frameHeight, headerVisible and TAB_H or 0, 0, contentTop, subTop)
            headerTabsCollapsed = not headerVisible
            subTabsCollapsed = true
            subTabContainer:Hide()
        else
            -- Returning to Character: restore saved state
            if savedTabState then
                tabState = savedTabState
                savedTabState = nil
            end
            ApplyTabState(tabState)
        end
        unifiedToggleText:SetText(GetStateIndicator())
    end

    -- ========================================================================
    -- CHAR TAB (Mirrored Layout)
    -- ========================================================================
    local charTab = CreateFrame("Frame", nil, contentArea)
    charTab:SetAllPoints()
    tabFrames[1] = charTab

    -- Keep non-character modules visually above Character tab so combat-safe
    -- switching (without protected Hide calls) does not bleed through.
    local moduleFrameLevel = charTab:GetFrameLevel() + 20
    if reputationContainer then reputationContainer:SetFrameLevel(moduleFrameLevel) end
    if skillsContainer then skillsContainer:SetFrameLevel(moduleFrameLevel) end
    if pvpContainer then pvpContainer:SetFrameLevel(moduleFrameLevel) end
    if currencyContainer then currencyContainer:SetFrameLevel(moduleFrameLevel) end
    if BCF.PetContainer then BCF.PetContainer:SetFrameLevel(moduleFrameLevel) end

    local showDetails = BCF.DB.General.ShowItemDetails
    -- (gearSlotFrames forward-declared above)

    local modelFrame = CreateFrame("DressUpModel", nil, charTab)
    modelFrame:SetPoint("TOP", 0, -30)
    modelFrame:SetPoint("BOTTOM", 0, 50)
    modelFrame:SetWidth(260)                              -- Fit between slots to prevent blocking clicks
    modelFrame:SetFrameLevel(charTab:GetFrameLevel() + 1) -- Low level so slots (level +10) are above
    modelFrame:SetUnit("player")
    modelFrame:SetFacing(math.rad(-15))
    modelFrame:SetScript("OnShow", function(self)
        if BCF.activeSubTab == 3 then return end
        self:SetUnit("player")
    end)
    BCF.ModelFrame = modelFrame -- Store for later access

    -- Mouse Rotation Logic
    modelFrame:EnableMouse(true)
    modelFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isRotating = true
            self.startX = GetCursorPosition()
            self.startRotation = self:GetFacing() or 0
        end
    end)
    modelFrame:SetScript("OnMouseUp", function(self)
        self.isRotating = false
    end)
    modelFrame:SetScript("OnUpdate", function(self)
        if self.isRotating and self.startRotation then
            local x = GetCursorPosition()
            local diff = (x - self.startX) * 0.015 -- Sensitivity
            self:SetFacing(self.startRotation + diff)
        end
    end)

    -- Toggle Button for Details (Animated) — global, visible on all tabs
    -- (EXPANDED_WIDTH, COLLAPSED_WIDTH, MODEL_X_EXPANDED, MODEL_X_COLLAPSED forward-declared above)

    toggleBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    toggleBtn:SetSize(24, 24)
    toggleBtn:SetFrameStrata("HIGH")
    toggleBtn:SetFrameLevel(100)
    toggleBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)
    toggleBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    toggleBtn:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    toggleBtn:EnableMouse(true)

    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }

    toggleBtn.Text = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    toggleBtn.Text:SetPoint("CENTER", 0, 0)
    toggleBtn.Text:SetText(">")
    toggleBtn.Text:SetTextColor(color.r, color.g, color.b)

    toggleBtn:SetScript("OnEnter", function(self)
        self.Text:SetTextColor(1, 1, 1)
        self:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 0.95)
        GameTooltip:Hide()
    end)
    toggleBtn:SetScript("OnLeave", function(self)
        self.Text:SetTextColor(color.r, color.g, color.b)
        self:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
    end)

    local function SetDetailsVisibility(show)
        BCF.DB.General.ShowItemDetails = show
        if BCF.RefreshCharacter then BCF.RefreshCharacter() end
        -- Update Arrow Text
        if show then
            toggleBtn.Text:SetText("<")
        else
            toggleBtn.Text:SetText(">")
        end
    end

    -- Animation State (forward-declared above)

    animFrame = CreateFrame("Frame")
    animFrame:Hide()
    animFrame:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local progress = (now - startTime) / DURATION
        local onCharTab = (activeHeaderTab == 1)

        if progress >= 1 then
            -- Final state
            f:SetWidth(targetWidth)

            if onCharTab then
                -- Final slot widths & info visibility
                for slotID, frame in pairs(gearSlotFrames) do
                    if slotID ~= 16 and slotID ~= 17 and slotID ~= 18 then
                        frame:SetWidth(targetSlotWidth)
                        if frame.InfoFrame then
                            if targetSlotWidth >= 200 then
                                frame.InfoFrame:SetAlpha(1)
                            else
                                frame.InfoFrame:SetAlpha(0)
                                frame.InfoFrame:Hide()
                            end
                        end
                    end
                end

                -- Restore flyout visibility for Sets tab after collapse animation
                for _, frame in pairs(gearSlotFrames) do
                    if frame.FlyoutBtn then
                        if targetSlotWidth >= 200 or BCF.activeSubTab == 2 then
                            frame.FlyoutBtn:SetAlpha(1)
                            frame.FlyoutBtn:Show()
                        else
                            frame.FlyoutBtn:SetAlpha(0)
                            frame.FlyoutBtn:Hide()
                        end
                    end
                end

                if BCF.UpdateLayout then BCF.UpdateLayout(targetModelX) end
            end

            UpdateTabWidths()

            self:Hide()
            isAnimating = false

            -- Finalize collapse state
            if targetWidth == COLLAPSED_WIDTH then
                BCF.DB.General.IsExpanded = false
                BCF.DB.General.ShowItemDetails = false
                toggleBtn.Text:SetText(">")
                if BCF.LogoTexture then BCF.LogoTexture:Hide() end
                if BCF.LogoVersion then BCF.LogoVersion:Hide() end
                titleDropBtn:Hide()
                titleDropBtn:SetAlpha(0)
                titleDropPanel:Hide()
            else
                -- Finalize expand state
                if BCF.LogoTexture then BCF.LogoTexture:Show() end
                if BCF.LogoVersion then BCF.LogoVersion:Show() end
                if onCharTab then
                    titleDropBtn:SetAlpha(1)
                end
            end

            -- Refresh content to ensure clean layout (respect active tab)
            if onCharTab and BCF.SideStats then
                if activeSubTab == 1 and BCF.RefreshStats then
                    BCF.RefreshStats(BCF.SideStats)
                elseif activeSubTab == 2 and BCF.RefreshSets then
                    BCF.RefreshSets(BCF.SideStats)
                elseif activeSubTab == 3 then
                    local charKey = BCF.GetCharacterKey()
                    local wSettings = BCF.DB.Characters and BCF.DB.Characters[charKey]
                        and BCF.DB.Characters[charKey].WishlistSettings
                    local activeList = wSettings and wSettings.ActiveList
                    if activeList and BCF.SetActiveWishlist then
                        BCF.SetActiveWishlist(activeList)
                    elseif activeList and BCF.PreviewWishlist then
                        BCF.PreviewWishlist(activeList)
                    end
                    -- Fade in wishlist text after data is populated
                    if targetWidth > COLLAPSED_WIDTH then
                        for _, frame in pairs(gearSlotFrames) do
                            if frame.InfoFrame then
                                UIFrameFadeIn(frame.InfoFrame, 0.3, 0, 1)
                            end
                        end
                    end
                end
            end
            if onCharTab and BCF.RefreshTitleBar then BCF.RefreshTitleBar() end
        else
            -- Ease Out Cubic
            progress = 1 - (1 - progress) ^ 3

            local newWidth = startWidth + (targetWidth - startWidth) * progress
            f:SetWidth(newWidth)

            if onCharTab then
                local newModelX = startModelX + (targetModelX - startModelX) * progress

                -- Smooth slot width transition (drives stats panel slide)
                local newSlotWidth = startSlotWidth + (targetSlotWidth - startSlotWidth) * progress
                for slotID, frame in pairs(gearSlotFrames) do
                    if slotID ~= 16 and slotID ~= 17 and slotID ~= 18 then
                        frame:SetWidth(newSlotWidth)
                    end
                end

                -- Smooth enchant/info fade
                local infoAlpha
                if targetSlotWidth > startSlotWidth then
                    infoAlpha = math.max(0, (progress - 0.3) / 0.7)
                else
                    infoAlpha = 1 - math.min(1, progress / 0.5)
                end
                local wishlistExpanding = (activeSubTab == 3 and targetSlotWidth > startSlotWidth)
                for slotID, frame in pairs(gearSlotFrames) do
                    if frame.InfoFrame then
                        -- Wishlist expand: keep at 0 (fades in after SetActiveWishlist)
                        frame.InfoFrame:SetAlpha(wishlistExpanding and 0 or infoAlpha)
                    end
                    if frame.FlyoutBtn then
                        frame.FlyoutBtn:SetAlpha(BCF.activeSubTab == 2 and 1 or infoAlpha)
                    end
                end

                -- Smooth title dropdown fade (synced with expansion)
                if titleDropBtn then
                    if targetWidth > startWidth then
                        titleDropBtn:SetAlpha(infoAlpha)
                        if infoAlpha > 0 then titleDropBtn:Show() end
                    else
                        titleDropBtn:SetAlpha(infoAlpha)
                        if infoAlpha <= 0 then titleDropBtn:Hide() end
                    end
                end

                if BCF.UpdateLayout then BCF.UpdateLayout(newModelX) end
            end

            -- Smooth logo fade (works on all tabs)
            local logoFade
            if targetWidth > startWidth then
                logoFade = math.max(0, (progress - 0.3) / 0.7) * 0.6
            else
                logoFade = (1 - math.min(1, progress / 0.5)) * 0.6
            end
            if BCF.LogoTexture then
                BCF.LogoTexture:SetAlpha(logoFade)
                if logoFade > 0 then BCF.LogoTexture:Show() end
            end
            if BCF.LogoVersion then
                BCF.LogoVersion:SetAlpha(logoFade)
                if logoFade > 0 then BCF.LogoVersion:Show() end
            end

            UpdateTabWidths()
        end
    end)

    toggleBtn:SetScript("OnClick", function()
        if isAnimating then return end

        local isExpanded = BCF.DB.General.IsExpanded
        local onCharTab = (activeHeaderTab == 1)

        -- Close options panel when collapsing
        if isExpanded and BCF.optionsPanelOpen then
            BCF.optionsPanelOpen = false
            configTex:SetVertexColor(0.5, 0.5, 0.5, 1)
            configGlow:Hide()
            optionsPanel:Hide()
            RestoreTabHighlights()
        end

        if isExpanded then
            -- COLLAPSE
            targetWidth = COLLAPSED_WIDTH
            if onCharTab then
                targetModelX = MODEL_X_COLLAPSED
                startSlotWidth = 200
                targetSlotWidth = 40
            end
        else
            -- EXPAND
            BCF.DB.General.IsExpanded = true
            toggleBtn.Text:SetText("<")

            if onCharTab then
                BCF.DB.General.ShowItemDetails = true
                BCF.RefreshCharacter()
                BCF.RefreshTitleBar()

                -- Reset visual state to collapsed (data stays populated, alpha invisible)
                for slotID, frame in pairs(gearSlotFrames) do
                    if slotID ~= 16 and slotID ~= 17 and slotID ~= 18 then
                        frame:SetWidth(40)
                        if frame.InfoFrame then
                            frame.InfoFrame:SetAlpha(0)
                        end
                    end
                    if frame.FlyoutBtn then
                        frame.FlyoutBtn:SetAlpha(0)
                    end
                end
                f:SetWidth(COLLAPSED_WIDTH)
                BCF.UpdateLayout(MODEL_X_COLLAPSED)

                targetModelX = MODEL_X_EXPANDED
                startSlotWidth = 40
                targetSlotWidth = 200
            end

            targetWidth = EXPANDED_WIDTH
        end

        startWidth = f:GetWidth()
        if onCharTab then
            startModelX = isExpanded and MODEL_X_EXPANDED or MODEL_X_COLLAPSED
        end
        startTime = GetTime()
        isAnimating = true
        animFrame:Show()
    end)

    -- Initialize State
    if BCF.DB.General.IsExpanded == nil then
        BCF.DB.General.IsExpanded = false
    end
    -- ShowItemDetails must always mirror IsExpanded (fix stale SavedVariables)
    BCF.DB.General.ShowItemDetails = BCF.DB.General.IsExpanded

    -- Set frame width and slot widths BEFORE rendering to avoid layout mismatch
    local initialModelX = BCF.DB.General.IsExpanded and MODEL_X_EXPANDED or MODEL_X_COLLAPSED
    f:SetWidth(BCF.DB.General.IsExpanded and EXPANDED_WIDTH or COLLAPSED_WIDTH)
    local initSlotWidth = BCF.DB.General.IsExpanded and 200 or 40
    for slotID, frame in pairs(gearSlotFrames) do
        if slotID ~= 16 and slotID ~= 17 and slotID ~= 18 then
            frame:SetWidth(initSlotWidth)
        end
    end
    if BCF.UpdateLayout then BCF.UpdateLayout(initialModelX) end

    SetDetailsVisibility(BCF.DB.General.ShowItemDetails)

    -- Consolidated OnShow: refresh + tab width sync.
    -- Do not reposition in combat: secure show path (BCFToggleButton) must not call
    -- protected methods like ClearAllPoints/SetPoint.
    f:SetScript("OnShow", function(self)
        if bootstrapQueuedForCombatEnd and InCombatLockdown() then
            if BCF.ApplyAllFonts then BCF.ApplyAllFonts() end
            BCF.RefreshTitleBar()
            return
        end
        if not InCombatLockdown() then
            -- Keep saved placement outside combat; skip during secure combat open.
            if BCF.DB and BCF.DB.WindowPos then
                local p = BCF.DB.WindowPos
                self:ClearAllPoints()
                self:SetPoint(p[1], UIParent, p[3], p[4], p[5])
            end
            local uiScale = BCF.DB.General.UIScale or 1.0
            self:SetScale(uiScale)
            if BCF.ModelFrame then BCF.ModelFrame:SetModelScale(1.0 / uiScale) end
        end
        if BCF.ApplyAllFonts then BCF.ApplyAllFonts() end
        if BCF.RefreshGear then BCF.RefreshGear() end
        if BCF.RefreshCharacter then BCF.RefreshCharacter() end
        -- Wishlist tab: re-apply paperdoll after frame hierarchy settles.
        -- DressUpModel loses dressed state on hide/show; slot icons may also need refresh.
        if BCF.activeSubTab == 3 and BCF.activeHeaderTab == 1 then
            C_Timer.After(0, function()
                if not BCF.MainFrame or not BCF.MainFrame:IsShown() then return end
                if BCF.activeSubTab ~= 3 then return end
                local charKey = BCF.GetCharacterKey and BCF.GetCharacterKey()
                local wSettings = charKey and BCF.DB.Characters and BCF.DB.Characters[charKey]
                    and BCF.DB.Characters[charKey].WishlistSettings
                local activeList = wSettings and wSettings.ActiveList
                if activeList and BCF.PreviewWishlist then
                    BCF.PreviewWishlist(activeList)
                end
            end)
        end
        if IsInGuild and IsInGuild() then
            pcall(function() if GuildRoster then GuildRoster() end end)
        end
        BCF.RefreshTitleBar()
        C_Timer.After(0.01, function()
            if UpdateTabWidths then UpdateTabWidths() end
        end)
    end)

    -- Define Slot Groups
    local leftSlots = { 1, 2, 3, 15, 5, 4, 19, 9 }
    local rightSlots = { 10, 6, 7, 8, 11, 12, 13, 14 }
    local bottomSlots = { 16, 17, 18 }

    -- HELPER: Create Slot
    local function CreateOrUpdateSlot(slotID, parent, side)
        local frame = gearSlotFrames[slotID]
        if not frame then
            -- Blizzard paperdoll slot template provides secure native click/drag/use behavior.
            frame = CreateFrame("ItemButton", "BCFSlot" .. slotID, parent,
                "PaperDollItemSlotButtonTemplate,BackdropTemplate")
            frame:SetSize(40, 42)                            -- Initial size (collapsed), RefreshCharacter updates width for expanded
            frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            frame:SetBackdropColor(0, 0, 0, 0)               -- Fully transparent backdrop for proper hit detection
            frame:SetHitRectInsets(0, 0, 0, 0)               -- Ensure entire frame area is clickable
            frame:SetFrameLevel(parent:GetFrameLevel() + 10) -- Ensure slots are above other charTab elements
            if PaperDollItemSlotButton_OnLoad then
                pcall(PaperDollItemSlotButton_OnLoad, frame)
            end
            -- Stop Blizzard's auto-updates from fighting our icon management.
            -- Click/drag behavior comes from template scripts, not events.
            -- OnShow neutralized: RefreshCharacter/PreviewWishlistSlots handle icon updates.
            frame:UnregisterAllEvents()
            frame:SetScript("OnEvent", nil)
            frame:SetScript("OnShow", nil)
            frame:RegisterForDrag("LeftButton")
            frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            frame:SetID(slotID)
            frame.slotID = slotID

            -- Remove Blizzard decorative slot art; keep icon-only visuals.
            local normalTex = frame:GetNormalTexture()
            if normalTex then
                normalTex:SetAlpha(0)
                normalTex:Hide()
            end
            local pushedTex = frame:GetPushedTexture()
            if pushedTex then
                pushedTex:SetAlpha(0)
                pushedTex:Hide()
            end
            local disabledTex = frame:GetDisabledTexture()
            if disabledTex then
                disabledTex:SetAlpha(0)
                disabledTex:Hide()
            end
            local highlightTex = frame:GetHighlightTexture()
            if highlightTex then
                highlightTex:SetAlpha(0)
                highlightTex:Hide()
            end
            frame:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
            highlightTex = frame:GetHighlightTexture()
            if highlightTex then
                highlightTex:SetAlpha(0)
                highlightTex:Hide()
            end
            local name = frame:GetName()
            if name then
                local bg = _G[name .. "Background"]
                if bg then
                    bg:SetAlpha(0)
                    bg:Hide()
                end
                local blizzBorder = _G[name .. "IconBorder"]
                if blizzBorder then
                    blizzBorder:SetAlpha(0)
                    blizzBorder:Hide()
                end
            end

            -- Use template icon so Blizzard slot scripts stay intact.
            local icon = frame.icon or _G[frame:GetName() .. "IconTexture"] or frame:CreateTexture(nil, "ARTWORK")
            icon:SetSize(40, 40)
            icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
            frame.Icon = icon

            local border = CreateFrame("Frame", nil, frame)
            border:SetPoint("TOPLEFT", icon, -1, 1)
            border:SetPoint("BOTTOMRIGHT", icon, 1, -1)
            border:EnableMouse(false)                      -- Don't capture clicks - let frame handle them
            border.SetBackdropBorderColor = function() end -- Borderless no-op
            frame.IconBorder = border

            -- iLvl Overlay (On top of icon)
            local ilvlOverlay = BCF.CleanFont(frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal"))
            ilvlOverlay:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
            ilvlOverlay:SetDrawLayer("OVERLAY", 7)
            ilvlOverlay:SetJustifyH("RIGHT")
            ilvlOverlay:Show()
            frame.ILvlOverlay = ilvlOverlay

            -- BiS Star Overlay (top-left of icon, shown when equipped item is a wishlist favorite)
            local bisStar = border:CreateTexture(nil, "OVERLAY")
            bisStar:SetSize(12, 12)
            bisStar:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
            bisStar:SetTexture("Interface\\COMMON\\FavoritesIcon")
            bisStar:Hide()
            frame.BisStar = bisStar

            -- Info Container (Item Name + Enchant + Gems) — height set by dual anchors
            local infoFrame = CreateFrame("Frame", nil, frame)
            infoFrame:EnableMouse(false) -- Don't capture clicks - let frame handle them
            frame.InfoFrame = infoFrame

            -- Item Name (Row 1)
            local itemName = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            frame.ItemName = itemName
            BCF.RegisterFont(itemName, "items")

            -- Enchant Text (Row 2)
            local enchantText = infoFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            frame.EnchantText = enchantText
            BCF.RegisterFont(enchantText, "items")

            -- Gem Container
            local gemContainer = CreateFrame("Frame", nil, infoFrame)
            gemContainer:SetSize(46, 12)    -- enough for 4 small gems
            gemContainer:EnableMouse(false) -- Let clicks pass through to frame
            frame.GemContainer = gemContainer

            frame.GemButtons = {}
            for i = 1, 4 do
                local gemBtn = CreateFrame("Button", nil, gemContainer)
                gemBtn:SetSize(10, 10)
                gemBtn:EnableMouse(false) -- Let clicks pass through to parent slot frame
                local gTex = gemBtn:CreateTexture(nil, "ARTWORK")
                gTex:SetAllPoints()
                gemBtn.Texture = gTex

                gemBtn:SetScript("OnEnter", function(self)
                    if self.gemLink then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetHyperlink(self.gemLink)
                        GameTooltip:Show()
                    elseif self.socketType then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(self.socketType .. " Socket")
                        GameTooltip:Show()
                    end
                end)
                gemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                frame.GemButtons[i] = gemBtn
            end

            -- Hover highlight overlay (quality-colored inner glow) across full slot row.
            local hoverGlow = frame:CreateTexture(nil, "HIGHLIGHT")
            hoverGlow:SetAllPoints(frame)
            hoverGlow:SetColorTexture(1, 1, 1, 0.15)
            frame.HoverGlow = hoverGlow

            -- Cooldown frame for on-use items (trinkets, etc.) on icon area only.
            local cooldown = frame.Cooldown or frame.cooldown or _G[frame:GetName() .. "Cooldown"]
            if not cooldown then
                cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
            end
            cooldown:ClearAllPoints()
            cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
            cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
            cooldown:SetDrawEdge(true)
            cooldown:SetHideCountdownNumbers(false)
            cooldown:EnableMouse(false) -- Don't block clicks on parent slot frame
            -- Disable mouse on all cooldown children (CooldownFrameTemplate may have internal frames)
            for _, child in pairs({ cooldown:GetChildren() }) do
                if child.EnableMouse then child:EnableMouse(false) end
            end
            frame.Cooldown = cooldown

            -- Drag-target backdrop: soft blue inner glow shown on empty slots while cursor holds an item
            local dragBackdrop = frame:CreateTexture(nil, "OVERLAY")
            dragBackdrop:SetPoint("TOPLEFT", icon, 2, -2)
            dragBackdrop:SetPoint("BOTTOMRIGHT", icon, -2, 2)
            dragBackdrop:SetColorTexture(0.2, 0.5, 1.0, 0.4)
            dragBackdrop:SetBlendMode("ADD")
            dragBackdrop:Hide()
            frame.DragBackdrop = dragBackdrop

            -- Custom hover handlers: keep secure click/drag behavior from template,
            -- but avoid Blizzard OnEnter slot-name lookup on custom frame names.
            frame:SetScript("OnEnter", function(self)
                if BCF.IsDraggingScroll then return end

                -- Wishlist mode: show BiS item tooltip
                if BCF.activeSubTab == 3 then
                    local charKey = BCF.GetCharacterKey()
                    local wSettings = BCF.DB.Characters and BCF.DB.Characters[charKey]
                        and BCF.DB.Characters[charKey].WishlistSettings
                    local activeList = wSettings and wSettings.ActiveList
                    if activeList then
                        local selected = BCF.GetSelectedItems(activeList)
                        local entry = selected and selected[slotID]
                        if entry and entry.link then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetHyperlink(entry.link)
                            GameTooltip:Show()
                            local _, _, quality = GetItemInfo(entry.link)
                            if quality then
                                local r, g, b = GetItemQualityColor(quality)
                                hoverGlow:SetColorTexture(r, g, b, 0.35)
                            end
                            return
                        end
                    end
                    hoverGlow:SetColorTexture(1, 1, 1, 0.2)
                    return
                end

                -- Character/sets/stats mode: quality hover + dragged-item quality overlay.
                local cursorType, r, g, b = GetCursorItemTypeAndColor()
                if cursorType == "item" then
                    hoverGlow:SetColorTexture(r, g, b, 0.5)
                    local link = GetInventoryItemLink("player", slotID)
                    if link then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetInventoryItem("player", slotID)
                        GameTooltip:Show()
                    end
                    return
                end

                local link = GetInventoryItemLink("player", slotID)
                if link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetInventoryItem("player", slotID)
                    GameTooltip:Show()
                    local _, _, quality = GetItemInfo(link)
                    if quality then
                        local r, g, b = GetItemQualityColor(quality)
                        hoverGlow:SetColorTexture(r, g, b, 0.35)
                    else
                        hoverGlow:SetColorTexture(1, 1, 1, 0.2)
                    end
                else
                    hoverGlow:SetColorTexture(1, 1, 1, 0.2)
                end
            end)
            frame:SetScript("OnLeave", function()
                GameTooltip:Hide()
                hoverGlow:SetColorTexture(1, 1, 1, 0.15)
            end)
            -- Flyout Button: class-colored vertical line adjacent to icon
            local flyoutBtn = CreateFrame("Button", nil, frame)
            flyoutBtn:SetSize(10, 40)
            flyoutBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            flyoutBtn:SetFrameLevel(frame:GetFrameLevel() + 5)
            -- Vertical line background
            local flyoutLine = flyoutBtn:CreateTexture(nil, "BACKGROUND")
            flyoutLine:SetPoint("TOPLEFT", 3, 0)
            flyoutLine:SetPoint("BOTTOMRIGHT", -3, 0)
            flyoutLine:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.35)
            flyoutBtn.Line = flyoutLine
            -- Arrow indicator
            local flyoutArrow = BCF.CleanFont(flyoutBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
            flyoutArrow:SetPoint("CENTER", 0, 0)
            flyoutArrow:SetText(">")
            flyoutArrow:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.8)
            flyoutBtn.ArrowText = flyoutArrow
            flyoutBtn:SetScript("OnEnter", function(self)
                local qr, qg, qb = self.qualityR or T.Accent[1], self.qualityG or T.Accent[2],
                    self.qualityB or T.Accent[3]
                self.Line:SetColorTexture(qr, qg, qb, 0.7)
                self.ArrowText:SetTextColor(1, 1, 1, 1)
            end)
            flyoutBtn:SetScript("OnLeave", function(self)
                if self.qualityR then
                    -- Has item: restore to quality color
                    self.Line:SetColorTexture(self.qualityR, self.qualityG, self.qualityB, 0.35)
                    self.ArrowText:SetTextColor(self.qualityR, self.qualityG, self.qualityB, 0.8)
                else
                    -- Empty slot: restore to gray
                    self.Line:SetColorTexture(0.3, 0.3, 0.3, 0.2)
                    self.ArrowText:SetTextColor(0.3, 0.3, 0.3, 0.4)
                end
            end)
            flyoutBtn:SetScript("OnClick", function()
                BCF.ToggleFlyout(slotID, frame)
            end)
            frame.FlyoutBtn = flyoutBtn

            gearSlotFrames[slotID] = frame
        end

        local f = frame
        f.slotSide = side -- Store side for flyout direction
        f:ClearAllPoints()

        f.Icon:ClearAllPoints()
        f.InfoFrame:ClearAllPoints()
        if f.ItemName then f.ItemName:ClearAllPoints() end
        f.EnchantText:ClearAllPoints()
        f.GemContainer:ClearAllPoints()

        -- iLvl Overlay is fixed to Icon, no need to move

        -- Flyout line positioning (adjacent to icon edge)
        if f.FlyoutBtn then
            f.FlyoutBtn:ClearAllPoints()
            -- Set default arrow direction based on side
            if f.FlyoutBtn.ArrowText then
                f.FlyoutBtn.ArrowText:SetText(side == "LEFT" and ">" or "<")
            end
        end

        if side == "LEFT" then
            -- [Info fills to left edge] [Icon] [FlyoutLine]
            f.Icon:ClearAllPoints()
            f.Icon:SetPoint("RIGHT", 0, 0)
            -- Double anchor: TOPLEFT to frame, BOTTOMRIGHT to icon BOTTOMLEFT for full vertical height
            f.InfoFrame:ClearAllPoints()
            f.InfoFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 3, 0)
            f.InfoFrame:SetPoint("BOTTOMRIGHT", f.Icon, "BOTTOMLEFT", -3, 0)
            if f.FlyoutBtn then
                f.FlyoutBtn:SetPoint("LEFT", f.Icon, "RIGHT", 0, 0)
            end

            -- Info layout: 1/3 Name (top), 1/3 Enchant (center), 1/3 Gems (bottom)
            if f.ItemName then
                f.ItemName:ClearAllPoints()
                f.ItemName:SetPoint("TOPLEFT", f.InfoFrame, "TOPLEFT", 0, -2)
                f.ItemName:SetPoint("TOPRIGHT", f.InfoFrame, "TOPRIGHT", 0, -2)
                f.ItemName:SetJustifyH("LEFT")
                f.ItemName:SetWordWrap(false)
            end
            -- Enchant: centered vertically
            f.EnchantText:ClearAllPoints()
            f.EnchantText:SetPoint("LEFT", f.InfoFrame, "LEFT", 0, 0)
            f.EnchantText:SetPoint("RIGHT", f.InfoFrame, "RIGHT", 0, 0)
            f.EnchantText:SetJustifyH("LEFT")
            f.EnchantText:SetWordWrap(false)
            f.GemContainer:ClearAllPoints()
            f.GemContainer:SetPoint("BOTTOMLEFT", f.InfoFrame, "BOTTOMLEFT", 0, 2)

            -- Layout gem buttons L to R (matching left-alignment)
            for i = 1, 4 do
                f.GemButtons[i]:ClearAllPoints()
                f.GemButtons[i]:SetPoint("LEFT", (i - 1) * 12, 0)
            end
        elseif side == "RIGHT" then
            f.Icon:ClearAllPoints()
            f.Icon:SetPoint("LEFT", 0, 0)
            -- Double anchor: TOPLEFT from icon TOPRIGHT, BOTTOMRIGHT to frame BOTTOMRIGHT
            f.InfoFrame:ClearAllPoints()
            f.InfoFrame:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", 3, 0)
            f.InfoFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 0)
            if f.FlyoutBtn then
                f.FlyoutBtn:SetPoint("RIGHT", f.Icon, "LEFT", 0, 0)
            end

            -- Info layout: 1/3 Name (top), 1/3 Enchant (center), 1/3 Gems (bottom)
            if f.ItemName then
                f.ItemName:ClearAllPoints()
                f.ItemName:SetPoint("TOPLEFT", f.InfoFrame, "TOPLEFT", 0, -2)
                f.ItemName:SetPoint("TOPRIGHT", f.InfoFrame, "TOPRIGHT", 0, -2)
                f.ItemName:SetJustifyH("LEFT")
                f.ItemName:SetWordWrap(false)
            end
            -- Enchant: centered vertically
            f.EnchantText:ClearAllPoints()
            f.EnchantText:SetPoint("LEFT", f.InfoFrame, "LEFT", 0, 0)
            f.EnchantText:SetPoint("RIGHT", f.InfoFrame, "RIGHT", 0, 0)
            f.EnchantText:SetJustifyH("LEFT")
            f.EnchantText:SetWordWrap(false)
            f.GemContainer:ClearAllPoints()
            f.GemContainer:SetPoint("BOTTOMLEFT", f.InfoFrame, "BOTTOMLEFT", 0, 2)

            -- Layout gem buttons L to R
            for i = 1, 4 do
                f.GemButtons[i]:ClearAllPoints()
                f.GemButtons[i]:SetPoint("LEFT", (i - 1) * 12, 0)
            end
        elseif side == "BOTTOM_MH" then
            -- Mainhand: Icon CENTERED (unchanged), InfoFrame to LEFT
            f.Icon:SetPoint("CENTER", 0, 0)
            f.InfoFrame:SetPoint("TOPRIGHT", f.Icon, "TOPLEFT", -3, 0)
            f.InfoFrame:SetPoint("BOTTOMRIGHT", f.Icon, "BOTTOMLEFT", -3, 0)
            f.InfoFrame:SetWidth(160)
            -- Info layout: 1/3 Name (top), 1/3 Enchant (center), 1/3 Gems (bottom)
            if f.ItemName then
                f.ItemName:SetPoint("TOPRIGHT", f.InfoFrame, "TOPRIGHT", 0, -2)
                f.ItemName:SetPoint("TOPLEFT", f.InfoFrame, "TOPLEFT", 0, -2)
                f.ItemName:SetJustifyH("RIGHT")
                f.ItemName:SetWordWrap(false)
            end
            f.EnchantText:ClearAllPoints()
            f.EnchantText:SetPoint("LEFT", f.InfoFrame, "LEFT", 0, 0)
            f.EnchantText:SetPoint("RIGHT", f.InfoFrame, "RIGHT", 0, 0)
            f.EnchantText:SetJustifyH("RIGHT")
            f.EnchantText:SetWordWrap(false)
            f.GemContainer:SetPoint("BOTTOMRIGHT", f.InfoFrame, "BOTTOMRIGHT", 0, 2)
            for i = 1, 4 do
                f.GemButtons[i]:ClearAllPoints()
                f.GemButtons[i]:SetPoint("RIGHT", -(i - 1) * 12, 0)
            end
            if f.FlyoutBtn then
                f.FlyoutBtn:SetSize(40, 4)
                if f.FlyoutBtn.ArrowText then f.FlyoutBtn.ArrowText:SetText("^") end
                f.FlyoutBtn:SetPoint("BOTTOM", f.Icon, "TOP", 0, 1)
                if f.FlyoutBtn.Line then
                    f.FlyoutBtn.Line:ClearAllPoints()
                    f.FlyoutBtn.Line:SetAllPoints(f.FlyoutBtn)
                end
            end
        elseif side == "BOTTOM_OH" then
            -- Offhand: Icon CENTERED, InfoFrame below starting at left edge of icon
            f.Icon:SetPoint("CENTER", 0, 0)
            f.InfoFrame:SetPoint("TOPLEFT", f.Icon, "BOTTOMLEFT", 0, -2)
            f.InfoFrame:SetSize(160, 42)
            -- Info layout: Name (top), Enchant (center), Gems (bottom)
            if f.ItemName then
                f.ItemName:SetPoint("TOPLEFT", f.InfoFrame, "TOPLEFT", 0, -2)
                f.ItemName:SetPoint("TOPRIGHT", f.InfoFrame, "TOPRIGHT", 0, -2)
                f.ItemName:SetJustifyH("LEFT")
                f.ItemName:SetWordWrap(false)
            end
            f.EnchantText:ClearAllPoints()
            f.EnchantText:SetPoint("LEFT", f.InfoFrame, "LEFT", 0, 0)
            f.EnchantText:SetPoint("RIGHT", f.InfoFrame, "RIGHT", 0, 0)
            f.EnchantText:SetJustifyH("LEFT")
            f.EnchantText:SetWordWrap(false)
            f.GemContainer:SetPoint("BOTTOMLEFT", f.InfoFrame, "BOTTOMLEFT", 0, 2)
            for i = 1, 4 do
                f.GemButtons[i]:ClearAllPoints()
                f.GemButtons[i]:SetPoint("LEFT", (i - 1) * 12, 0)
            end
            if f.FlyoutBtn then
                f.FlyoutBtn:SetSize(40, 4)
                if f.FlyoutBtn.ArrowText then f.FlyoutBtn.ArrowText:SetText("^") end
                f.FlyoutBtn:SetPoint("BOTTOM", f.Icon, "TOP", 0, 1)
                if f.FlyoutBtn.Line then
                    f.FlyoutBtn.Line:ClearAllPoints()
                    f.FlyoutBtn.Line:SetAllPoints(f.FlyoutBtn)
                end
            end
        elseif side == "BOTTOM_RANGED" then
            -- Ranged: Icon CENTERED (unchanged), InfoFrame to RIGHT
            f.Icon:SetPoint("CENTER", 0, 0)
            f.InfoFrame:SetPoint("TOPLEFT", f.Icon, "TOPRIGHT", 3, 0)
            f.InfoFrame:SetPoint("BOTTOMLEFT", f.Icon, "BOTTOMRIGHT", 3, 0)
            f.InfoFrame:SetWidth(160)
            -- Info layout: 1/3 Name (top), 1/3 Enchant (center), 1/3 Gems (bottom)
            if f.ItemName then
                f.ItemName:SetPoint("TOPLEFT", f.InfoFrame, "TOPLEFT", 0, -2)
                f.ItemName:SetPoint("TOPRIGHT", f.InfoFrame, "TOPRIGHT", 0, -2)
                f.ItemName:SetJustifyH("LEFT")
                f.ItemName:SetWordWrap(false)
            end
            f.EnchantText:ClearAllPoints()
            f.EnchantText:SetPoint("LEFT", f.InfoFrame, "LEFT", 0, 0)
            f.EnchantText:SetPoint("RIGHT", f.InfoFrame, "RIGHT", 0, 0)
            f.EnchantText:SetJustifyH("LEFT")
            f.EnchantText:SetWordWrap(false)
            f.GemContainer:SetPoint("BOTTOMLEFT", f.InfoFrame, "BOTTOMLEFT", 0, 2)
            for i = 1, 4 do
                f.GemButtons[i]:ClearAllPoints()
                f.GemButtons[i]:SetPoint("LEFT", (i - 1) * 12, 0)
            end
            if f.FlyoutBtn then
                f.FlyoutBtn:SetSize(40, 4)
                if f.FlyoutBtn.ArrowText then f.FlyoutBtn.ArrowText:SetText("^") end
                f.FlyoutBtn:SetPoint("BOTTOM", f.Icon, "TOP", 0, 1)
                if f.FlyoutBtn.Line then
                    f.FlyoutBtn.Line:ClearAllPoints()
                    f.FlyoutBtn.Line:SetAllPoints(f.FlyoutBtn)
                end
            end
        else -- CENTER/BOTTOM fallback
            f.Icon:SetPoint("CENTER", 0, 0)
            f.InfoFrame:Hide()
            if f.FlyoutBtn then f.FlyoutBtn:Hide() end
        end

        -- Visibility of InfoFrame is now handled by BCF.RefreshCharacter based on BCF.DB.General.ShowItemDetails
        -- The width of the slot frame itself is also handled by BCF.RefreshCharacter

        return frame
    end


    -- --- 4. Refresh Handling ---
    -- Update Layout Logic Helper (Handles dynamic Model X)
    function BCF.UpdateLayout(modelX)
        local startY = -15

        local slotH = 46
        local slotH = 46
        local centerOffset = 100 -- Standard gap

        -- Model
        modelFrame:ClearAllPoints()
        modelFrame:SetPoint("TOP", charTab, "TOPLEFT", modelX, -20)
        modelFrame:SetPoint("BOTTOM", charTab, "BOTTOMLEFT", modelX, 46)

        -- Left Slots
        for i, slotID in ipairs(leftSlots) do
            local frame = gearSlotFrames[slotID]
            if frame then
                frame:ClearAllPoints()
                -- Anchor TOPRIGHT to maintain Left-Edge alignment roughly
                frame:SetPoint("TOPRIGHT", charTab, "TOPLEFT", modelX - centerOffset, startY - (i - 1) * slotH)
            end
        end

        -- Right Slots
        for i, slotID in ipairs(rightSlots) do
            local frame = gearSlotFrames[slotID]
            if frame then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", charTab, "TOPLEFT", modelX + centerOffset, startY - (i - 1) * slotH)
            end
        end

        -- Bottom Slots (fixed 45px spacing - weapons show icon only)
        local centerStart = -((#bottomSlots * 45) / 2) + 22.5
        for i, slotID in ipairs(bottomSlots) do
            local frame = gearSlotFrames[slotID]
            if frame then
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", charTab, "BOTTOMLEFT", modelX + centerStart + (i - 1) * 45, 40)
            end
        end

        -- Toggle Button (now global, positioned on main frame via SetFrameStrata)

        -- Dynamic SideStats Positioning
        -- Direct anchor to slot 10, letting WoW handle the positioning
        if BCF.SideStats and gearSlotFrames[10] and gearSlotFrames[14] then
            BCF.SideStats:ClearAllPoints()

            -- Top: 5px gap from slot 10's right edge, aligned with its top
            BCF.SideStats:SetPoint("TOPLEFT", gearSlotFrames[10], "TOPRIGHT", 5, 0)

            -- Bottom: Same X offset, anchored to slot 14's bottom (extends full column height)
            BCF.SideStats:SetPoint("BOTTOMLEFT", gearSlotFrames[14], "BOTTOMRIGHT", 5, 0)

            -- Width: Fixed at 220px
            BCF.SideStats:SetWidth(220)
        end

        BCF.GearSlotFrames = gearSlotFrames
    end

    -- ================================================================
    -- EQUIPMENT FLYOUT SYSTEM
    -- ================================================================

    -- Slot ID -> equipment location mapping for bag scanning
    local SLOT_INVTYPES = {
        [1]  = { INVTYPE_HEAD = true },
        [2]  = { INVTYPE_NECK = true },
        [3]  = { INVTYPE_SHOULDER = true },
        [15] = { INVTYPE_CLOAK = true },
        [5]  = { INVTYPE_CHEST = true, INVTYPE_ROBE = true },
        [9]  = { INVTYPE_WRIST = true },
        [10] = { INVTYPE_HAND = true },
        [6]  = { INVTYPE_WAIST = true },
        [7]  = { INVTYPE_LEGS = true },
        [8]  = { INVTYPE_FEET = true },
        [11] = { INVTYPE_FINGER = true },
        [12] = { INVTYPE_FINGER = true },
        [13] = { INVTYPE_TRINKET = true },
        [14] = { INVTYPE_TRINKET = true },
        [16] = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true },
        [17] = { INVTYPE_WEAPON = true, INVTYPE_SHIELD = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true },
        [18] = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true },
    }

    -- Shared flyout panel (horizontal)
    local flyoutPanel = CreateFrame("Frame", "BCFEquipFlyout", charTab, "BackdropTemplate")
    flyoutPanel:SetHeight(42)
    flyoutPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    flyoutPanel:SetBackdropColor(0.06, 0.06, 0.09, 0.95)
    flyoutPanel:SetFrameStrata("DIALOG")
    flyoutPanel:Hide()
    flyoutPanel.bagFrames = {}
    flyoutPanel.bagFrameBySlot = {}
    flyoutPanel.activeSlot = nil
    flyoutPanel.expandDir = "RIGHT" -- "LEFT" or "RIGHT"

    -- Close flyout when clicking elsewhere (but not when clicking the active flyout button)
    flyoutPanel:SetScript("OnShow", function()
        flyoutPanel:SetScript("OnUpdate", function(self)
            if not MouseIsOver(self) then
                -- Don't auto-close if the mouse is over the active flyout button
                -- (let the button's OnClick handle the toggle instead)
                local activeFrame = self.activeSlotFrame
                local overBtn = activeFrame and activeFrame.FlyoutBtn and MouseIsOver(activeFrame.FlyoutBtn)
                if not overBtn and IsMouseButtonDown("LeftButton") then
                    self:Hide()
                end
            end
        end)
    end)
    flyoutPanel:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        -- Reset arrow on the active slot's flyout button
        if self.activeSlotFrame and self.activeSlotFrame.FlyoutBtn and self.activeSlotFrame.FlyoutBtn.ArrowText then
            local s = self.activeSlotFrame.slotSide or "RIGHT"
            if s == "BOTTOM_MH" or s == "BOTTOM_OH" or s == "BOTTOM_RANGED" then
                self.activeSlotFrame.FlyoutBtn.ArrowText:SetText("^")
            elseif s == "LEFT" then
                self.activeSlotFrame.FlyoutBtn.ArrowText:SetText(">")
            else
                self.activeSlotFrame.FlyoutBtn.ArrowText:SetText("<")
            end
        end
        self.activeSlot = nil
        self.activeSlotFrame = nil
    end)

    -- Hidden scanning tooltip for equipability checks
    local scanTip = CreateFrame("GameTooltip", "BCFScanTooltip", nil, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")

    -- Check if an item link has red text in its tooltip (= can't use)
    local function IsItemUsableByPlayer(link)
        -- Re-own the tooltip each time to ensure clean state
        scanTip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetHyperlink(link)
        -- Scan ALL tooltip lines (left AND right) for red text (r > 0.9, g < 0.2, b < 0.2)
        -- Red text indicates: Requires [Skill], Classes: [restricted], level requirements, etc.
        for i = 2, scanTip:NumLines() do
            -- Check left-side text
            local leftObj = _G["BCFScanTooltipTextLeft" .. i]
            if leftObj then
                local r, g, b = leftObj:GetTextColor()
                if r and r > 0.9 and g < 0.2 and b < 0.2 then
                    return false -- Red text = can't use
                end
            end
            -- Check right-side text (some requirements appear on the right)
            local rightObj = _G["BCFScanTooltipTextRight" .. i]
            if rightObj and rightObj:GetText() then
                local r, g, b = rightObj:GetTextColor()
                if r and r > 0.9 and g < 0.2 and b < 0.2 then
                    return false -- Red text on right side = can't use
                end
            end
        end
        return true
    end

    local function ScanBagsForSlot(slotID)
        local validTypes = SLOT_INVTYPES[slotID]
        if not validTypes then return {} end

        local items = {}
        for bag = 0, 4 do
            local numSlots = BCF.GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local link = BCF.GetContainerItemLink(bag, slot)
                if link then
                    local _, _, _, _, _, _, _, _, equipLoc, tex, _, itemClassID = GetItemInfo(link)
                    if equipLoc and validTypes[equipLoc] then
                        -- Filter: only show items the player can actually equip
                        if IsItemUsableByPlayer(link) then
                            local _, _, quality = GetItemInfo(link)
                            table.insert(items, {
                                link = link,
                                icon = tex,
                                quality = quality or 1,
                                bag = bag,
                                slot = slot,
                            })
                        end
                    end
                end
            end
        end
        return items
    end

    -- Combat-safe visual refresh for a single slot (no frame show/hide/layout calls).
    local function RefreshSingleSlotVisual(slotID, frame)
        if not frame then return end

        local link = GetInventoryItemLink("player", slotID)
        if link then
            local icon = GetInventoryItemTexture("player", slotID)
            if frame.Icon and icon then
                frame.Icon:SetTexture(icon)
                frame.Icon:SetAlpha(1)
                frame.Icon:SetVertexColor(1, 1, 1)
            end

            local _, _, quality, itemLevel = GetItemInfo(link)
            if (not itemLevel or itemLevel <= 0) and GetDetailedItemLevelInfo then
                local detailed = GetDetailedItemLevelInfo(link)
                if detailed and detailed > 0 then itemLevel = detailed end
            end
            if GetInventoryItemQuality then
                quality = GetInventoryItemQuality("player", slotID) or quality
            end
            if quality then
                local r, g, b = GetItemQualityColor(quality)
                if frame.IconBorder then
                    frame.IconBorder:SetBackdropBorderColor(r, g, b, 1)
                end
                if frame.FlyoutBtn then
                    frame.FlyoutBtn.qualityR = r
                    frame.FlyoutBtn.qualityG = g
                    frame.FlyoutBtn.qualityB = b
                    if frame.FlyoutBtn.Line then
                        frame.FlyoutBtn.Line:SetColorTexture(r, g, b, 0.35)
                    end
                    if frame.FlyoutBtn.ArrowText then
                        frame.FlyoutBtn.ArrowText:SetTextColor(r, g, b, 0.8)
                    end
                end
            end

            if frame.ILvlOverlay then
                local displayILvl = itemLevel
                if (not displayILvl or displayILvl <= 0) and BCF.LastGearScan and BCF.LastGearScan.slots and BCF.LastGearScan.slots[slotID] then
                    displayILvl = BCF.LastGearScan.slots[slotID].itemLevel
                end
                if BCF.DB and BCF.DB.General and BCF.DB.General.ShowILvl ~= false and displayILvl and displayILvl > 0 then
                    frame.ILvlOverlay:SetText(tostring(math.floor(displayILvl + 0.5)))
                    if quality then
                        local r, g, b = GetItemQualityColor(quality)
                        frame.ILvlOverlay:SetTextColor(r, g, b)
                    else
                        frame.ILvlOverlay:SetTextColor(0.8, 0.8, 0.8)
                    end
                    frame.ILvlOverlay:Show()
                else
                    frame.ILvlOverlay:SetText("")
                    frame.ILvlOverlay:Hide()
                end
            end
        else
            if frame.Icon then
                frame.Icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                frame.Icon:SetAlpha(1)
                frame.Icon:SetVertexColor(0.4, 0.4, 0.4)
            end
            if frame.IconBorder then
                frame.IconBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
            end
            if frame.ILvlOverlay then
                frame.ILvlOverlay:SetText("")
                frame.ILvlOverlay:Hide()
            end
        end

        -- Keep icon cooldown timer responsive during combat swaps.
        if frame.Cooldown then
            local start, duration, enable = GetInventoryItemCooldown("player", slotID)
            if enable and enable == 1 and start and duration and start > 0 and duration > 0 then
                frame.Cooldown:SetCooldown(start, duration)
            else
                frame.Cooldown:Clear()
            end
        end
    end

    local ScheduleCombatDetailRefresh

    -- Combat-safe detail redraw: refresh names/enchants/gems without layout/size churn.
    local function RefreshCombatDetailVisuals()
        if not BCF.DB or not BCF.DB.General or not BCF.DB.General.ShowItemDetails then return end
        if not gearSlotFrames then return end

        local scan = BCF.ScanGear and BCF.ScanGear() or BCF.LastGearScan
        if not scan or not scan.slots then return end
        BCF.LastGearScan = scan

        for slotID, frame in pairs(gearSlotFrames) do
            local slotData = scan.slots[slotID]
            local liveLink = GetInventoryItemLink("player", slotID)
            local displayName = (slotData and slotData.itemName) or ""
            local displayQuality = slotData and slotData.quality
            local displayILvl = slotData and slotData.itemLevel
            if GetInventoryItemQuality then
                displayQuality = GetInventoryItemQuality("player", slotID) or displayQuality
            end

            if liveLink then
                local liveName, _, liveQuality, liveILvl = (BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(liveLink, function()
                    ScheduleCombatDetailRefresh()
                end)) or GetItemInfo(liveLink)
                if (not liveILvl or liveILvl <= 0) and GetDetailedItemLevelInfo then
                    local detailed = GetDetailedItemLevelInfo(liveLink)
                    if detailed and detailed > 0 then liveILvl = detailed end
                end
                if (not displayName or displayName == "") and liveName then
                    displayName = liveName
                end
                if liveQuality then
                    displayQuality = liveQuality
                end
                if liveILvl and liveILvl > 0 then
                    displayILvl = liveILvl
                end
            end

            if frame and frame.InfoFrame then
                SafeShowFrame(frame.InfoFrame)
            end

            if frame and frame.ItemName then
                BCF.FitText(frame.ItemName, displayName)
                if displayQuality then
                    local r, g, b = GetItemQualityColor(displayQuality)
                    frame.ItemName:SetTextColor(r, g, b)
                else
                    frame.ItemName:SetTextColor(0.7, 0.7, 0.7)
                end
            end

            if frame and frame.ILvlOverlay then
                if BCF.DB and BCF.DB.General and BCF.DB.General.ShowILvl ~= false and displayILvl and displayILvl > 0 then
                    frame.ILvlOverlay:SetText(tostring(math.floor(displayILvl + 0.5)))
                    if displayQuality then
                        local r, g, b = GetItemQualityColor(displayQuality)
                        frame.ILvlOverlay:SetTextColor(r, g, b)
                    else
                        frame.ILvlOverlay:SetTextColor(0.8, 0.8, 0.8)
                    end
                    frame.ILvlOverlay:Show()
                else
                    frame.ILvlOverlay:SetText("")
                    frame.ILvlOverlay:Hide()
                end
            end

            if frame and frame.EnchantText then
                local ench = (slotData and slotData.enchantText) or ""
                frame.EnchantText:SetText(ench)
                if slotData and slotData.enchantStatus == "missing" then
                    frame.EnchantText:SetTextColor(1, 0.3, 0.3)
                else
                    frame.EnchantText:SetTextColor(0.2, 1, 0.2)
                end
            end

            if frame and frame.GemButtons then
                local showGems = BCF.DB.General.ShowGemSockets ~= false
                for i = 1, 4 do
                    local btn = frame.GemButtons[i]
                    if btn then
                        local socketType = slotData and slotData.socketInfo and slotData.socketInfo[i]
                        if showGems and socketType then
                            SafeShowFrame(btn)
                            local gemID = slotData.gems and slotData.gems[i]
                            if gemID and gemID > 0 then
                                local _, _, _, _, _, _, _, _, _, gemIcon = GetItemInfo(gemID)
                                btn.Texture:SetTexture(gemIcon or "Interface\\Icons\\INV_Misc_Gem_01")
                                local _, gemLink = GetItemInfo(gemID)
                                btn.gemLink = gemLink
                            else
                                local tex = "Interface\\ItemSocketingFrame\\UI-EmptySocket-" .. (socketType or "Prismatic")
                                if socketType == "Meta" then
                                    tex = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta"
                                end
                                btn.Texture:SetTexture(tex)
                                btn.gemLink = nil
                            end
                        else
                            SafeHideFrame(btn)
                        end
                    end
                end
            end

            if frame and frame.Cooldown then
                local start, duration, enable = GetInventoryItemCooldown("player", slotID)
                if enable and enable == 1 and start and duration and start > 0 and duration > 0 then
                    frame.Cooldown:SetCooldown(start, duration)
                else
                    frame.Cooldown:Clear()
                end
            end
        end
    end

    local pendingCombatDetailRefresh = false
    ScheduleCombatDetailRefresh = function()
        if pendingCombatDetailRefresh then return end
        pendingCombatDetailRefresh = true
        C_Timer.After(0.1, function()
            pendingCombatDetailRefresh = false
            if InCombatLockdown() then
                RefreshCombatDetailVisuals()
            end
        end)
    end

    local function RefreshCombatCooldownVisuals(slotID)
        if not gearSlotFrames then return end

        if slotID then
            local frame = gearSlotFrames[slotID]
            if frame and frame.Cooldown then
                local start, duration, enable = GetInventoryItemCooldown("player", slotID)
                if enable and enable == 1 and start and duration and start > 0 and duration > 0 then
                    frame.Cooldown:SetCooldown(start, duration)
                else
                    frame.Cooldown:Clear()
                end
            end
            return
        end

        for id, frame in pairs(gearSlotFrames) do
            if frame and frame.Cooldown then
                local start, duration, enable = GetInventoryItemCooldown("player", id)
                if enable and enable == 1 and start and duration and start > 0 and duration > 0 then
                    frame.Cooldown:SetCooldown(start, duration)
                else
                    frame.Cooldown:Clear()
                end
            end
        end
    end

    -- Expose combat-safe single-slot refresh for Core event handling.
    function BCF.RefreshCombatSlotVisual(slotID)
        if not slotID or not gearSlotFrames then return end
        RefreshSingleSlotVisual(slotID, gearSlotFrames[slotID])
        ScheduleCombatDetailRefresh()
    end

    function BCF.RefreshCombatCooldowns(slotID)
        RefreshCombatCooldownVisuals(slotID)
    end

    -- ========================================================================
    -- TOGGLE FLYOUT (unified entry point for all slots)
    -- ContainerFrameItemButtonTemplate: native Blizzard handler for combat
    -- equipping. Keep template visuals untouched to avoid tainting secure click flow.
    -- ========================================================================
    local function EnsureFlyoutButton(bag, slot)
        flyoutPanel.bagFrameBySlot[bag] = flyoutPanel.bagFrameBySlot[bag] or {}
        local existing = flyoutPanel.bagFrameBySlot[bag][slot]
        if existing then return existing end
        if InCombatLockdown() then return nil end

        local bagFrame = CreateFrame("Frame", nil, flyoutPanel)
        bagFrame:SetSize(40, 40)
        bagFrame:SetID(bag) -- immutable: consumed by ContainerFrameItemButtonTemplate click handler
        flyoutPanel.bagFrameBySlot[bag][slot] = bagFrame
        table.insert(flyoutPanel.bagFrames, bagFrame)

        local btn = CreateFrame("Button", nil, bagFrame, "ContainerFrameItemButtonTemplate")
        btn:SetAllPoints(bagFrame)
        btn:SetID(slot) -- immutable: consumed by ContainerFrameItemButtonTemplate click handler
        -- Strict right-click-only behavior for flyout equip buttons.
        btn:RegisterForClicks("RightButtonDown", "RightButtonUp")
        -- Block template default left-button drag/pickup behavior.
        btn:RegisterForDrag()
        bagFrame.btn = btn

        if not btn.icon then
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetAllPoints()
            btn.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
        end

        return bagFrame
    end

    local function EnsureFlyoutButtonsForCurrentBags()
        for bag = 0, 4 do
            local numSlots = (BCF.GetContainerNumSlots and BCF.GetContainerNumSlots(bag))
                or (GetContainerNumSlots and GetContainerNumSlots(bag))
                or 0
            for slot = 1, numSlots do
                EnsureFlyoutButton(bag, slot)
            end
        end
    end

    EnsureFlyoutButtonsForCurrentBags()

    function BCF.ToggleFlyout(slotID, slotFrame)
        if InCombatLockdown() and BCF.TaintedSession then
            flyoutPanel:Hide()
            BCF.Print("|cff00ccff[BCF]|r Tainted session: combat flyout weapon swap is blocked until reload.")
            return
        end

        local side = slotFrame.slotSide or "RIGHT"
        local isWeaponSlot = (side == "BOTTOM_MH" or side == "BOTTOM_OH" or side == "BOTTOM_RANGED")

        -- Toggle off if already showing this slot
        if flyoutPanel:IsShown() and flyoutPanel.activeSlot == slotID then
            flyoutPanel:Hide()
            return
        end

        -- Hide existing flyout buttons
        for i = 1, #flyoutPanel.bagFrames do
            flyoutPanel.bagFrames[i]:Hide()
        end

        local items = ScanBagsForSlot(slotID)
        if #items == 0 then
            flyoutPanel:Hide()
            return
        end

        flyoutPanel.activeSlot = slotID
        flyoutPanel.activeSlotFrame = slotFrame
        flyoutPanel:ClearAllPoints()

        if isWeaponSlot then
            -- Vertical layout: stack buttons upward from weapon slot
            flyoutPanel:SetWidth(44)
            flyoutPanel:SetHeight(#items * 44 + 4)
            flyoutPanel:SetPoint("BOTTOM", slotFrame.FlyoutBtn or slotFrame.Icon, "TOP", 0, 2)
            if slotFrame.FlyoutBtn and slotFrame.FlyoutBtn.ArrowText then
                slotFrame.FlyoutBtn.ArrowText:SetText("v")
            end
        else
            -- Horizontal layout: expand left or right
            local expandDir = (side == "LEFT") and "RIGHT" or "LEFT"
            flyoutPanel.expandDir = expandDir
            flyoutPanel:SetWidth(math.max(44, #items * 44 + 4))
            flyoutPanel:SetHeight(44)
            if slotFrame.FlyoutBtn and slotFrame.FlyoutBtn.ArrowText then
                slotFrame.FlyoutBtn.ArrowText:SetText(side == "LEFT" and "<" or ">")
            end
            if expandDir == "RIGHT" then
                flyoutPanel:SetPoint("LEFT", slotFrame.FlyoutBtn or slotFrame.Icon, "RIGHT", 2, 0)
            else
                flyoutPanel:SetPoint("RIGHT", slotFrame.FlyoutBtn or slotFrame.Icon, "LEFT", -2, 0)
            end
        end

        for i, item in ipairs(items) do
            local bagFrame = EnsureFlyoutButton(item.bag, item.slot)
            local btn = bagFrame and bagFrame.btn

            -- Position
            if bagFrame and btn then
                bagFrame:ClearAllPoints()
                if isWeaponSlot then
                    bagFrame:SetPoint("BOTTOM", flyoutPanel, "BOTTOM", 0, 2 + (i - 1) * 44)
                elseif flyoutPanel.expandDir == "RIGHT" then
                    bagFrame:SetPoint("LEFT", flyoutPanel, "LEFT", 2 + (i - 1) * 44, 0)
                else
                    bagFrame:SetPoint("RIGHT", flyoutPanel, "RIGHT", -2 - (i - 1) * 44, 0)
                end

                -- Update visuals
                btn.icon:SetTexture(item.icon)

                bagFrame:Show()
                btn:Show()
            end
        end

        flyoutPanel:Show()
    end

    function BCF.HideFlyoutPanel()
        if flyoutPanel and flyoutPanel:IsShown() then
            flyoutPanel:Hide()
        end
    end

    function BCF.RefreshCharacter()
        -- Skip refresh during expand/collapse animation to prevent visual glitches
        if isAnimating then return end

        -- In combat: skip layout/anchor work, but still update slot data.
        local inCombat = InCombatLockdown()

        -- On wishlist tab, skip model/gear refresh entirely (wishlist manages its own state)
        if BCF.activeSubTab == 3 then return end

        -- Refresh 3D model when gear hash changes.
        -- Must run in combat too so leaving Wishlist immediately restores live model.
        if BCF.ModelFrame then
            local hashParts = {}
            for slot = 1, 19 do
                hashParts[slot] = GetInventoryItemLink("player", slot) or ""
            end
            local currentGearHash = table.concat(hashParts)
            if currentGearHash ~= BCF.LastGearHash then
                BCF.LastGearHash = currentGearHash
                BCF.ModelFrame:SetUnit("player")
            end
        end

        -- Combat-safe: avoid layout/anchor/size mutations while locked down.
        -- Still re-apply detail visibility/content so expand/collapse toggles recover in combat.
        if inCombat then
            local showDetails = BCF.DB and BCF.DB.General and BCF.DB.General.ShowItemDetails
            if showDetails then
                if gearSlotFrames then
                    for _, frame in pairs(gearSlotFrames) do
                        if frame and frame.InfoFrame then
                            SafeShowFrame(frame.InfoFrame)
                        end
                    end
                end
                if ScheduleCombatDetailRefresh then
                    ScheduleCombatDetailRefresh()
                end
                if BCF.RefreshCombatCooldowns then
                    BCF.RefreshCombatCooldowns()
                end
            else
                if gearSlotFrames then
                    for _, frame in pairs(gearSlotFrames) do
                        if frame and frame.InfoFrame then
                            SafeHideFrame(frame.InfoFrame)
                        end
                        if frame and frame.GemButtons then
                            for i = 1, 4 do
                                local btn = frame.GemButtons[i]
                                if btn then SafeHideFrame(btn) end
                            end
                        end
                    end
                end
            end
            return
        end

        -- Ensure Layout uses current Model X (based on width state)
        -- We calculate desired Model X and set it.
        local isExpanded = BCF.DB.General.ShowItemDetails
        local targetModelX = isExpanded and MODEL_X_EXPANDED or MODEL_X_COLLAPSED

        -- Update Slots logic (Create/Update)
        -- Left slots use LEFT style (Mirrored: Text Left, Icon Right) to hug the model better
        for i, slotID in ipairs(leftSlots) do
            CreateOrUpdateSlot(slotID, charTab, "LEFT")
        end
        for i, slotID in ipairs(rightSlots) do
            CreateOrUpdateSlot(slotID, charTab, "RIGHT")
        end
        -- Bottom slots: each has unique layout
        CreateOrUpdateSlot(16, charTab, "BOTTOM_MH")
        CreateOrUpdateSlot(17, charTab, "BOTTOM_OH")
        CreateOrUpdateSlot(18, charTab, "BOTTOM_RANGED")

        -- Update Data & Visibility FIRST (so slots have correct widths)
        local showDetails = BCF.DB.General.ShowItemDetails
        local scan = BCF.LastGearScan or BCF.ScanGear()

        -- Build BiS star lookup: selected wishlist item IDs per slot
        local bisItems = {}
        if BCF.DB.General.ShowEquippedBiSStar ~= false then
            local charKey = BCF.GetCharacterKey()
            local wSettings = BCF.DB.Characters and BCF.DB.Characters[charKey]
                and BCF.DB.Characters[charKey].WishlistSettings
            local activeList = wSettings and wSettings.ActiveList
            if activeList then
                local wishlists = BCF.DB.Characters[charKey].Wishlists
                local list = wishlists and wishlists[activeList]
                if list and list.slots then
                    for sID, entries in pairs(list.slots) do
                        if type(sID) == "number" and sID <= 18 then
                            for _, entry in ipairs(entries) do
                                if entry.selected and entry.itemID then
                                    bisItems[sID] = bisItems[sID] or {}
                                    bisItems[sID][entry.itemID] = true
                                end
                            end
                        end
                    end
                end
            end
        end

        for slotID, frame in pairs(gearSlotFrames) do
            -- 1. Visibility & Width (CRITICAL: Set width BEFORE anchoring)
            local isWeaponSlot = (slotID == 16 or slotID == 17 or slotID == 18)
            if showDetails then
                if not isWeaponSlot then
                    frame.InfoFrame:Show()
                    if not inCombat then
                        frame:SetWidth(200) -- Full width covers icon + text area
                    end
                else
                    -- Weapon slots: slot stays 40x42, InfoFrame extends outside
                    frame.InfoFrame:Show()
                    if not inCombat then
                        frame:SetSize(40, 42)
                    end
                end
                if frame.FlyoutBtn then frame.FlyoutBtn:Show() end
            else
                -- COMPACT VIEW: NEVER show info
                frame.InfoFrame:Hide()
                if not inCombat then
                    frame:SetSize(40, 42)
                end
                -- Flyout buttons visible in compact mode for Sets tab only
                if frame.FlyoutBtn then
                    if BCF.activeSubTab == 2 then
                        frame.FlyoutBtn:Show()
                        if frame.FlyoutBtn:GetAlpha() < 0.01 then
                            UIFrameFadeIn(frame.FlyoutBtn, 0.3, 0, 1)
                        end
                    else
                        local btn = frame.FlyoutBtn
                        if btn:GetAlpha() > 0.01 then
                            UIFrameFade(btn, {
                                mode = "OUT",
                                timeToFade = 0.3,
                                startAlpha = btn:GetAlpha(),
                                endAlpha = 0,
                                finishedFunc = function() btn:Hide() end,
                            })
                        else
                            btn:SetAlpha(0)
                            btn:Hide()
                        end
                    end
                end
            end

            -- 2. Data Update
            if scan then
                local slotData = scan.slots[slotID]
                local liveLink = GetInventoryItemLink("player", slotID)
                if slotData and not slotData.isEmpty and liveLink then
                    frame.Icon:SetTexture(slotData.icon)
                    frame.Icon:SetAlpha(1)
                    frame.Icon:Show()
                    -- Grey out locked items (being moved)
                    local isLocked = IsInventoryItemLocked(slotID)
                    if isLocked then
                        frame.Icon:SetVertexColor(0.15, 0.15, 0.15)
                    else
                        frame.Icon:SetVertexColor(1, 1, 1)
                    end
                    local renderQuality = slotData.quality
                    if GetInventoryItemQuality then
                        renderQuality = GetInventoryItemQuality("player", slotID) or renderQuality
                    end
                    local liveILvl = slotData.itemLevel
                    if liveLink then
                        local _, _, liveQuality, infoILvl = (BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(liveLink, function()
                            if ScheduleCombatDetailRefresh then ScheduleCombatDetailRefresh() end
                        end)) or GetItemInfo(liveLink)
                        if (not infoILvl or infoILvl <= 0) and GetDetailedItemLevelInfo then
                            local detailed = GetDetailedItemLevelInfo(liveLink)
                            if detailed and detailed > 0 then infoILvl = detailed end
                        end
                        if liveQuality then
                            renderQuality = liveQuality
                        end
                        if infoILvl and infoILvl > 0 then
                            liveILvl = infoILvl
                        end
                    end
                    local r, g, b = GetItemQualityColor(renderQuality or 1)
                    frame.IconBorder:SetBackdropBorderColor(r, g, b, 1)

                    -- Quality-colored flyout handle
                    if frame.FlyoutBtn then
                        if frame.FlyoutBtn.Line then
                            frame.FlyoutBtn.Line:SetColorTexture(r, g, b, 0.35)
                        end
                        if frame.FlyoutBtn.ArrowText then
                            frame.FlyoutBtn.ArrowText:SetTextColor(r, g, b, 0.8)
                        end
                        -- Store quality color for hover restore
                        frame.FlyoutBtn.qualityR = r
                        frame.FlyoutBtn.qualityG = g
                        frame.FlyoutBtn.qualityB = b
                    end

                    -- BiS Star Overlay
                    if frame.BisStar then
                        local itemID = slotData.itemID
                        local isBis = itemID and bisItems[slotID] and bisItems[slotID][itemID]
                        if isBis then
                            frame.BisStar:Show()
                        else
                            frame.BisStar:Hide()
                        end
                    end

                    -- iLvl Overlay (use item quality color)
                    if BCF.DB.General.ShowILvl ~= false and liveILvl and liveILvl > 0 then
                        frame.ILvlOverlay:SetText(tostring(math.floor(liveILvl + 0.5)))
                        frame.ILvlOverlay:SetTextColor(r, g, b)
                        frame.ILvlOverlay:Show()
                    else
                        frame.ILvlOverlay:SetText("")
                        frame.ILvlOverlay:Hide()
                    end

                    -- Info Update
                    if showDetails then
                        -- Item Name (Row 1) - quality colored, smart abbreviated
                        if frame.ItemName then
                            BCF.FitText(frame.ItemName, slotData.itemName or "")
                            frame.ItemName:SetTextColor(r, g, b)
                        end

                        -- Enchant (Row 2)
                        frame.EnchantText:SetText(slotData.enchantText or "")
                        if slotData.enchantStatus == "missing" then
                            frame.EnchantText:SetTextColor(1, 0.3, 0.3)
                        else
                            frame.EnchantText:SetTextColor(0.2, 1, 0.2)
                        end

                        -- Gems
                        local showGems = BCF.DB.General.ShowGemSockets ~= false
                        for i = 1, 4 do
                            local btn = frame.GemButtons[i]
                            local socketType = slotData.socketInfo and slotData.socketInfo[i]

                            if showGems and socketType then
                                btn:Show()
                                local gemID = slotData.gems[i]
                                btn.socketType = socketType

                                if gemID and gemID > 0 then
                                    local _, _, _, _, _, _, _, _, _, gemIcon = GetItemInfo(gemID)
                                    btn.Texture:SetTexture(gemIcon or "Interface\\Icons\\INV_Misc_Gem_01")
                                    local _, gemLink = GetItemInfo(gemID)
                                    btn.gemLink = gemLink
                                else
                                    local tex = "Interface\\ItemSocketingFrame\\UI-EmptySocket-" ..
                                        (socketType or "Prismatic")
                                    if socketType == "Meta" then
                                        tex =
                                        "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta"
                                    end
                                    btn.Texture:SetTexture(tex)
                                    btn.gemLink = nil
                                end
                            else
                                btn:Hide()
                            end
                        end
                    end

                    -- Update cooldown display for on-use items
                    if frame.Cooldown then
                        frame.Cooldown:ClearAllPoints()
                        frame.Cooldown:SetPoint("TOPLEFT", frame.Icon, "TOPLEFT", 0, 0)
                        frame.Cooldown:SetPoint("BOTTOMRIGHT", frame.Icon, "BOTTOMRIGHT", 0, 0)
                        local start, duration, enable = GetInventoryItemCooldown("player", slotID)
                        if enable and enable == 1 and start > 0 and duration > 0 then
                            frame.Cooldown:SetCooldown(start, duration)
                        else
                            frame.Cooldown:Clear()
                        end
                    end
                else
                    -- Empty Slot — unified grey
                    frame.Icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                    frame.Icon:SetAlpha(1)
                    frame.Icon:Show()
                    frame.Icon:SetVertexColor(0.4, 0.4, 0.4)
                    frame.IconBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
                    frame.ILvlOverlay:SetText("")
                    frame.ILvlOverlay:Hide()
                    if frame.BisStar then frame.BisStar:Hide() end
                    if frame.ItemName then frame.ItemName:SetText("") end
                    if frame.InfoFrame then frame.InfoFrame:Hide() end
                    -- Grey out flyout handle for empty slots
                    if frame.FlyoutBtn then
                        if frame.FlyoutBtn.Line then
                            frame.FlyoutBtn.Line:SetColorTexture(0.3, 0.3, 0.3, 0.2)
                        end
                        if frame.FlyoutBtn.ArrowText then
                            frame.FlyoutBtn.ArrowText:SetTextColor(0.3, 0.3, 0.3, 0.4)
                        end
                        frame.FlyoutBtn.qualityR = nil
                        frame.FlyoutBtn.qualityG = nil
                        frame.FlyoutBtn.qualityB = nil
                    end
                    -- Clear cooldown for empty slots
                    if frame.Cooldown then
                        frame.Cooldown:Clear()
                    end
                end
            end
        end

        -- NOW anchor the stats panel (after slot widths are correct)
        BCF.UpdateLayout(targetModelX)

        -- Show SideStats panel (don't refresh - let SwitchTab handle content)
        if BCF.SideStats then
            SafeShowFrame(BCF.SideStats)
        end
    end

    -- ========================================================================
    -- SIDE STATS & SETS
    -- ========================================================================

    local function ResolveSideStatsContainer(target)
        if BCF.SideStats and target == BCF.SideStats and BCF.SideStats.Content then
            return BCF.SideStats.Content
        end
        return target
    end

    function BCF.ClearContainer(container)
        if not container then return end
        container.sections = container.sections or {}
        for _, section in ipairs(container.sections) do
            section:ClearAllPoints()
            section:Hide()
            section:SetParent(nil)
        end
        container.sections = {}
        -- Hide ALL child frames (catches anything not tracked in sections)
        local children = { container:GetChildren() }
        for _, child in ipairs(children) do
            child:ClearAllPoints()
            child:Hide()
        end
        -- Hide ALL regions (font strings, textures directly on container)
        local regions = { container:GetRegions() }
        for _, region in ipairs(regions) do
            region:Hide()
        end
    end

    -- Side Stats for Character Tab (Container)
    BCF.SideStats = CreateFrame("Frame", nil, charTab, "BackdropTemplate")
    BCF.SideStats:SetWidth(220)
    BCF.SideStats:SetClipsChildren(true)
    -- NO SetHeight - let dual anchors in UpdateLayout calculate height automatically

    -- ScrollFrame (full width - slider overlays when needed)
    local scrollF = CreateFrame("ScrollFrame", nil, BCF.SideStats)
    scrollF:SetPoint("TOPLEFT", 0, 0)
    scrollF:SetPoint("BOTTOMRIGHT", 0, 0)

    local scrollC = CreateFrame("Frame", nil, scrollF)
    scrollC:SetWidth(220)
    scrollC:SetHeight(400) -- Dynamic
    scrollF:SetScrollChild(scrollC)
    BCF.SideStats.Content = scrollC
    BCF.SideStats.ScrollFrame = scrollF

    -- Slick Slider (overlays on right edge when scrolling needed)
    local slider = CreateFrame("Slider", nil, BCF.SideStats, "BackdropTemplate")
    slider:SetPoint("TOPRIGHT", 0, 0)
    slider:SetPoint("BOTTOMRIGHT", 0, 0)
    slider:SetWidth(6)
    slider:SetFrameLevel(scrollF:GetFrameLevel() + 5)
    slider:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    slider:SetBackdropColor(0, 0, 0, 0.2)

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(6, 30)
    thumb:SetColorTexture(unpack(T.Accent))
    slider:SetThumbTexture(thumb)

    slider:SetOrientation("VERTICAL")
    slider:SetValueStep(1)

    -- Mirrored scroll: Slider TOP = List BOTTOM (direct mapping, no inversion)
    -- Mirrored scroll: Slider DOWN = List DOWN (content moves up)
    -- Logic: slider value 0 (top) -> scroll to max (bottom of content)
    -- ================================================================
    -- SCROLLBAR LOGIC (Mirrored: Slider Down = List Down)
    -- ================================================================
    -- Disable mouse on slider track to prevent "Jump to Click"
    slider:EnableMouse(false)

    -- Create draggable thumb button
    local thumbBtn = CreateFrame("Button", nil, slider)
    thumbBtn:SetFrameLevel(slider:GetFrameLevel() + 2)
    thumbBtn:EnableMouse(true)
    thumbBtn:RegisterForDrag("LeftButton")

    -- Sync Thumb Button to Slider's Visual Thumb
    -- We use OnUpdate to ensure it tracks perfectly even during animations/resizes
    -- OR better: Hook script to SetPoint if possible? No.
    -- Simplest: SetAllPoints to the region.
    thumbBtn:SetAllPoints(slider:GetThumbTexture())

    -- Drag Logic
    thumbBtn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self.isDragging = true
        BCF.IsDraggingScroll = true
        self.startY = select(2, GetCursorPosition())
        self.startVal = slider:GetValue()
        local min, max = slider:GetMinMaxValues()
        self.valRange = max - min
        self.heightRange = slider:GetHeight() - self:GetHeight()
        if self.heightRange < 1 then self.heightRange = 1 end
    end)

    thumbBtn:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self.isDragging = false
        BCF.IsDraggingScroll = false
    end)

    thumbBtn:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currY = select(2, GetCursorPosition())
            local diff = self.startY - currY -- Drag Down (negative Y) -> Increase Value
            -- Why inverted? Screen coords Y increases UP. Dragging down decreases Y.
            -- Slider Top = 0. Slider Bottom = Max.
            -- Moving Thumb Down (negative diff) should INCREASE value.

            -- Wait, standard slider: Top is Min? Or Top is Max?
            -- Orientation VERTICAL: Min is Bottom, Max is Top usually.
            -- BUT we want "Top = 0 (Start of List)".
            -- ScrollFrame: 0 is Top. Max is Bottom.
            -- Slider UI: Usually Min at Bottom.
            -- If we mapped directly: Slider 0 at Bottom.
            -- BetterCharacterFrame logic (lines 1731): scrollF:SetVerticalScroll(value).

            -- Let's check orientation.
            -- If slider Min is 0 and Max is YRange.
            -- Vertical Slider: Value increases UP usually.
            -- BUT SetValueStep(1).

            -- Let's assume standard behavior:
            -- Dragging thumb DOWN by X pixels should change value by (X / TrackHeight) * ValueRange.
            -- Drag Down -> Y decreases. diff is positive (startY - currY).
            -- dragging down 10px: startY=100, currY=90 => diff=10.
            -- Thumb moves down 10px.
            -- Should value increase or decrease?
            -- If Top is 0 and Bottom is Max: Moving down INCREASES value.
            -- So `val = startVal + (diff / heightRange * valRange)`.

            local delta = (diff / self.heightRange) * self.valRange
            slider:SetValue(self.startVal + delta)
        end
    end)

    BCF.SideStats:EnableMouse(true)
    BCF.WireScrollbar(scrollF, scrollC, slider, thumb, BCF.SideStats)

    BCF.SideStats.Slider = slider

    -- Blocks click-through into live equipment slots while Wishlist preview is active.
    -- This avoids interacting with protected item buttons in combat without mutating slot click registration.
    wishlistClickBlocker = CreateFrame("Button", nil, charTab, "BackdropTemplate")
    wishlistClickBlocker:SetPoint("TOPLEFT", charTab, "TOPLEFT", 0, 0)
    wishlistClickBlocker:SetPoint("BOTTOMLEFT", charTab, "BOTTOMLEFT", 0, 0)
    wishlistClickBlocker:SetPoint("RIGHT", BCF.SideStats, "LEFT", -5, 0)
    wishlistClickBlocker:SetFrameStrata("HIGH")
    wishlistClickBlocker:SetFrameLevel(50)
    wishlistClickBlocker:EnableMouse(true)
    wishlistClickBlocker:RegisterForClicks("AnyUp", "AnyDown")
    wishlistClickBlocker:SetScript("OnClick", function() end)
    wishlistClickBlocker:SetScript("OnMouseDown", function() end)
    wishlistClickBlocker:SetScript("OnMouseUp", function() end)
    wishlistClickBlocker:SetScript("OnUpdate", function(self)
        if not (self:IsShown() and BCF.GearSlotFrames) then return end

        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        x = x / scale
        y = y / scale

        local hitFrame = nil
        for _, slotFrame in pairs(BCF.GearSlotFrames) do
            if slotFrame and slotFrame:IsShown() then
                local left, right = slotFrame:GetLeft(), slotFrame:GetRight()
                local bottom, top = slotFrame:GetBottom(), slotFrame:GetTop()
                if left and right and bottom and top and x >= left and x <= right and y >= bottom and y <= top then
                    hitFrame = slotFrame
                    break
                end
            end
        end

        if hitFrame ~= blockerHoverFrame then
            if blockerHoverFrame then
                local oldLeave = blockerHoverFrame:GetScript("OnLeave")
                if oldLeave then oldLeave(blockerHoverFrame) end
            else
                GameTooltip:Hide()
            end
            blockerHoverFrame = hitFrame
            if blockerHoverFrame then
                local onEnter = blockerHoverFrame:GetScript("OnEnter")
                if onEnter then onEnter(blockerHoverFrame) end
            end
        end
    end)
    wishlistClickBlocker:SetScript("OnHide", function()
        if blockerHoverFrame then
            local onLeave = blockerHoverFrame:GetScript("OnLeave")
            if onLeave then onLeave(blockerHoverFrame) end
        end
        blockerHoverFrame = nil
        GameTooltip:Hide()
    end)
    wishlistClickBlocker:Hide()
    UpdateWishlistClickBlocker()

    local function BootstrapMainFrameNow()
        if bootstrapComplete then return end
        bootstrapComplete = true
        SetBootstrapQueued(false)

        -- Initialize tabs: Character header selected, Stats sub-tab selected
        SwitchHeaderTab(1)
        SwitchSubTab(1)

        -- Re-apply expanded/collapsed state NOW that all frames exist
        -- (The earlier init block at toggle-button creation runs before gearSlotFrames is populated)
        local initModelX = BCF.DB.General.IsExpanded and MODEL_X_EXPANDED or MODEL_X_COLLAPSED
        local initSlotW  = BCF.DB.General.IsExpanded and 200 or 40
        f:SetWidth(BCF.DB.General.IsExpanded and EXPANDED_WIDTH or COLLAPSED_WIDTH)
        for slotID, frame in pairs(gearSlotFrames) do
            if slotID ~= 16 and slotID ~= 17 and slotID ~= 18 then
                frame:SetWidth(initSlotW)
                if frame.InfoFrame then
                    if BCF.DB.General.IsExpanded then
                        frame.InfoFrame:Show()
                        frame.InfoFrame:SetAlpha(1)
                    else
                        frame.InfoFrame:Hide()
                        frame.InfoFrame:SetAlpha(0)
                    end
                end
                if frame.FlyoutBtn then
                    if BCF.DB.General.IsExpanded or BCF.activeSubTab == 2 then
                        frame.FlyoutBtn:Show()
                        frame.FlyoutBtn:SetAlpha(1)
                    else
                        frame.FlyoutBtn:Hide()
                        frame.FlyoutBtn:SetAlpha(0)
                    end
                end
            end
        end
        BCF.UpdateLayout(initModelX)
        UpdateTabWidths()
        if BCF.DB.General.IsExpanded then
            toggleBtn.Text:SetText("<")
            if titleDropBtn then
                titleDropBtn:SetAlpha(1); titleDropBtn:Show()
            end
        else
            toggleBtn.Text:SetText(">")
            if titleDropBtn then
                titleDropBtn:SetAlpha(0); titleDropBtn:Hide()
            end
        end
        if BCF.RefreshCharacter then
            BCF.RefreshCharacter()
        end
    end

    BCF.MainFrame = f
    if InCombatLockdown() then
        SetBootstrapQueued(true)
        local bootstrapFrame = CreateFrame("Frame")
        bootstrapFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        bootstrapFrame:SetScript("OnEvent", function(self)
            if not bootstrapQueuedForCombatEnd then
                self:UnregisterAllEvents()
                return
            end
            BootstrapMainFrameNow()
            self:UnregisterAllEvents()
        end)
    else
        BootstrapMainFrameNow()
    end


    local function EnsureDropLine(container, height, alpha)
        if not container.dropTargetLine then
            local line = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            line:SetHeight(height or 2)
            line:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            line:SetBackdropColor(T.Accent[1], T.Accent[2], T.Accent[3], alpha or 0.8)
            line:SetFrameStrata("TOOLTIP")
            line:SetFrameLevel(9999)
            line:Hide()
            container.dropTargetLine = line
        end
    end

    local function GetDragGhost()
        if not BCF.DragGhost then
            local g = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            g:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            g:SetBackdropColor(unpack(T.Accent))
            g:SetAlpha(0.6)
            g:SetFrameStrata("TOOLTIP")
            g.label = g:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            g.label:SetPoint("CENTER")
            BCF.DragGhost = g
        end
        return BCF.DragGhost
    end

    -- Returns: gapIndex (where 1 is top, N+1 is bottom), anchorFrame
    local function GetInsertionIndex(container, cursorY)
        if not container.sections or #container.sections == 0 then return 1, nil end

        local closestDist = 99999
        local closestGap = 1
        local closestHeaderFrame = nil
        local headerCount = 0
        local lastHeaderFrame = nil

        for _, section in ipairs(container.sections) do
            -- Skip dragged headers to keep gap indices consistent with visual line positioning
            if section:IsShown() and section.isHeader and not section.isDragging then
                headerCount = headerCount + 1
                lastHeaderFrame = section

                local top = section:GetTop()
                local bottom = section:GetBottom()

                if top and bottom then
                    local center = (top + bottom) / 2
                    local dist = math.abs(cursorY - center)

                    if dist < closestDist then
                        closestDist = dist
                        closestHeaderFrame = section

                        -- If we are in the upper half of this header, gap is at this header's position
                        -- If we are in the lower half, gap is at next header's position
                        if cursorY > center then
                            closestGap = headerCount
                        else
                            closestGap = headerCount + 1
                        end
                    end
                end
            end
        end

        return closestGap, closestHeaderFrame, lastHeaderFrame, headerCount
    end

    local function AddDragLogic(header, container, role, catName)
        header:EnableMouse(true)
        header:RegisterForDrag("LeftButton")
        header.catName = catName

        EnsureDropLine(container, 2, 0.8)

        header:SetScript("OnDragStart", function(self)
            if BCF.IsRefreshingStats then return end
            self.isDragging = true
            self:SetAlpha(0) -- Hide original

            local ghost = GetDragGhost()
            ghost:SetSize(self:GetWidth(), self:GetHeight())
            ghost.label:SetText(catName)
            ghost:Show()
            container.dropTargetLine:Show()
            container.dropTargetLine:SetFrameStrata("TOOLTIP")

            ghost:SetScript("OnUpdate", function(g)
                local x, y = GetCursorPosition()
                -- Match scale of container for correct Y comparison
                local s = container:GetEffectiveScale()
                local cY = y / s

                -- Ghost position still needs UIParent scale if parented to UIParent?
                -- Yes, standard practice for dragging frame:
                local uis = UIParent:GetEffectiveScale()
                g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / uis, y / uis)

                -- But for GetInsertionIndex, pass cY relative to container scale
                local gapIdx, closestFrame, lastFrame, totalHeaders = GetInsertionIndex(container, cY)

                -- Store gapIdx for OnDragStop to use (visual line = source of truth)
                container.lastGapIdx = gapIdx

                if closestFrame then
                    container.dropTargetLine:ClearAllPoints()
                    -- If gapIdx points to a header that is AFTER the closest header, anchor to bottom
                    -- This happens when closestGap = headerCount + 1
                    -- Find the header frame at gapIdx to anchor to its TOP, OR use the closestFrame's BOTTOM

                    local targetHeaderFrame = nil
                    if gapIdx <= totalHeaders then
                        -- Find the header that is currently at target position (skip the one being dragged)
                        local currentHeaderAtPos = 0
                        for _, sec in ipairs(container.sections) do
                            if sec.isHeader and not sec.isDragging then
                                currentHeaderAtPos = currentHeaderAtPos + 1
                                if currentHeaderAtPos == gapIdx then
                                    targetHeaderFrame = sec
                                    break
                                end
                            end
                        end
                    end

                    if targetHeaderFrame then
                        -- Draw line ABOVE the header at targetHeaderFrame
                        container.dropTargetLine:SetPoint("BOTTOMLEFT", targetHeaderFrame, "TOPLEFT", 0, 0)
                        container.dropTargetLine:SetPoint("BOTTOMRIGHT", targetHeaderFrame, "TOPRIGHT", -5, 0)
                        container.dropTargetLine:Show()
                    elseif lastFrame then
                        -- Draw line BELOW the last header
                        container.dropTargetLine:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, 0)
                        container.dropTargetLine:SetPoint("TOPRIGHT", lastFrame, "BOTTOMRIGHT", -5, 0)
                        container.dropTargetLine:Show()
                    else
                        container.dropTargetLine:Hide()
                    end
                else
                    container.dropTargetLine:Hide()
                end
            end)
        end)

        header:SetScript("OnDragStop", function(self)
            self.isDragging = false
            self:SetAlpha(1) -- Restore

            local ghost = BCF.DragGhost
            if ghost then
                ghost:Hide()
                ghost:SetScript("OnUpdate", nil)
            end
            container.dropTargetLine:Hide()

            local gapIdx = container.lastGapIdx

            if gapIdx then
                -- Find current index (original position among all headers, including self)
                local currentIdx = 0
                local headerIdx = 0
                for _, sec in ipairs(container.sections) do
                    if sec.isHeader then
                        headerIdx = headerIdx + 1
                        if sec == self then
                            currentIdx = headerIdx
                            break
                        end
                    end
                end

                -- gapIdx directly represents target position (no adjustment needed)
                local finalIdx = gapIdx

                if currentIdx > 0 and finalIdx ~= currentIdx then
                    BCF.ReorderStats(role, catName, finalIdx)
                    BCF.RefreshStats(container)
                end
            end
        end)
    end



    function BCF.RefreshStats(targetContainer)
        if BCF.IsRefreshingStats then return end
        BCF.IsRefreshingStats = true

        -- Use xpcall to ensure we release the lock even if an error occurs
        local status, err = xpcall(function()
            local paddingRight = 0
            targetContainer = ResolveSideStatsContainer(targetContainer)

            local container = targetContainer or BCF.StatsContent
            if not container then return end

            BCF.ClearContainer(container)

            local role = BCF.DetectRole()
            -- Only update Role Text if on Stats Tab
            if BCF.RoleText and container == BCF.StatsContent then
                local roleLabel = role:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end)
                BCF.RoleText:SetText("Detected Role: |cff" ..
                    string.format("%02x%02x%02x", T.Accent[1] * 255, T.Accent[2] * 255, T.Accent[3] * 255) ..
                    roleLabel .. "|r")
            end

            -- Use Ordered Stats
            local categories = BCF.GetOrderedStats(role)

            local yOffset = 0
            if container == BCF.StatsContent then yOffset = -25 end -- Offset for Role Text

            for i, cat in ipairs(categories) do
                local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
                header:SetHeight(T.HeaderRowHeight)
                header:SetPoint("TOPLEFT", 5, yOffset)
                header:SetPoint("RIGHT", -5 - paddingRight, 0)
                header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                header:SetBackdropColor(T.Accent[1] * 0.12, T.Accent[2] * 0.12, T.Accent[3] * 0.12, 0.9)
                table.insert(container.sections, header)
                header.isHeader = true
                header.catName = cat.name
                AddDragLogic(header, container, role, cat.name)

                -- Collapse Logic
                if not BCF.DB.Stats.Collapsed then BCF.DB.Stats.Collapsed = {} end
                local collapseKey = role .. ":" .. cat.name
                local isCollapsed = BCF.DB.Stats.Collapsed[collapseKey]
                if isCollapsed == nil then
                    isCollapsed = (i > 3)
                end

                -- Toggle Click
                header:SetScript("OnMouseUp", function(self, button)
                    if not self.isDragging and button == "LeftButton" then
                        BCF.DB.Stats.Collapsed[collapseKey] = not BCF.DB.Stats.Collapsed[collapseKey]
                        BCF.RefreshStats(targetContainer)
                    end
                end)

                -- Arrow
                local arrow = header:CreateTexture(nil, "ARTWORK")
                arrow:SetSize(12, 12)
                arrow:SetPoint("RIGHT", -5, 0)
                arrow:SetTexture(isCollapsed and "Interface\\Buttons\\UI-microbutton-Lbutton-Up" or
                    "Interface\\Buttons\\UI-microbutton-Dbutton-Up")
                arrow:SetAlpha(0.7)

                local headerIcon = header:CreateTexture(nil, "ARTWORK")
                headerIcon:SetSize(16, 16)
                headerIcon:SetPoint("LEFT", 6, 0)
                headerIcon:SetTexture(cat.icon)
                headerIcon:SetTexCoord(0.12, 0.88, 0.12, 0.88)

                local headerText = BCF.CleanFont(header:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
                headerText:SetPoint("LEFT", headerIcon, "RIGHT", 6, 0)
                headerText:SetText(cat.name)
                headerText:SetTextColor(unpack(T.Accent))

                yOffset = yOffset - 26

                if not isCollapsed then
                    local ok, stats = false, nil
                    if type(cat.getStats) == "function" then
                        ok, stats = pcall(cat.getStats)
                    end

                    if not ok then
                        -- Surface error: nil function or pcall failure
                        local errRow = CreateFrame("Frame", nil, container)
                        errRow:SetHeight(18)
                        errRow:SetPoint("TOPLEFT", 5, yOffset)
                        errRow:SetPoint("RIGHT", -5 - paddingRight, 0)
                        table.insert(container.sections, errRow)
                        local errText = errRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        errText:SetPoint("LEFT", 8, 0)
                        if type(cat.getStats) ~= "function" then
                            errText:SetText("|cffff4444Error: getStats is nil for " .. (cat.name or "?") .. "|r")
                        else
                            errText:SetText("|cffff4444Error: " .. tostring(stats) .. "|r")
                        end
                        errText:SetTextColor(1, 0.3, 0.3)
                        yOffset = yOffset - 18
                    end
                    if ok and stats then
                        for j, stat in ipairs(stats) do
                            local row = CreateFrame("Frame", nil, container)
                            row:SetHeight(18)
                            row:SetPoint("TOPLEFT", 5, yOffset)
                            row:SetPoint("RIGHT", -5 - paddingRight, 0)
                            row:EnableMouse(true)
                            table.insert(container.sections, row)

                            -- Alternating row background
                            local rowBg = row:CreateTexture(nil, "BACKGROUND")
                            rowBg:SetAllPoints()
                            if j % 2 == 0 then rowBg:SetColorTexture(1, 1, 1, 0.03) else rowBg:SetColorTexture(0, 0, 0, 0) end

                            -- Column 1: Stat Name (left)
                            local label = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
                            label:SetPoint("LEFT", 8, 0)
                            label:SetText(stat.label)
                            label:SetTextColor(unpack(T.TextSecondary))

                            local showRatings = BCF.DB.Stats.ShowRatings ~= false
                            local showPct = BCF.DB.Stats.ShowPercentages ~= false

                            if stat.rating ~= nil and showRatings and showPct then
                                -- 3-column layout: Name | Rating | sep | Value

                                -- Column 3: Value/Percentage (far right, white)
                                local pctText = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY",
                                    "GameFontHighlightSmall"))
                                pctText:SetPoint("RIGHT", -5, 0)
                                pctText:SetText(stat.pct or "")
                                if stat.color then
                                    pctText:SetTextColor(stat.color[1], stat.color[2], stat.color[3], 1)
                                else
                                    pctText:SetTextColor(1, 1, 1, 1)
                                end

                                -- Column 2: Separator (fixed position)
                                local sep = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
                                sep:SetPoint("RIGHT", row, "RIGHT", -55, 0)
                                sep:SetText("|")
                                sep:SetTextColor(0.25, 0.25, 0.3, 1)

                                -- Column 1b: Rating (middle, muted)
                                local ratingText = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY",
                                    "GameFontHighlightSmall"))
                                ratingText:SetPoint("RIGHT", row, "RIGHT", -63, 0)
                                ratingText:SetText(tostring(stat.rating))
                                ratingText:SetTextColor(unpack(T.TextMuted))
                            elseif stat.rating ~= nil and showRatings and not showPct then
                                -- 2-column: Name | Rating only
                                local valText = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY",
                                    "GameFontHighlightSmall"))
                                valText:SetPoint("RIGHT", -5, 0)
                                valText:SetText(tostring(stat.rating))
                                valText:SetTextColor(unpack(T.TextMuted))
                            else
                                -- 2-column layout: Name | Value/Percentage
                                local valText = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY",
                                    "GameFontHighlightSmall"))
                                valText:SetPoint("RIGHT", -5, 0)
                                valText:SetText(stat.pct or "")
                                if stat.color then
                                    valText:SetTextColor(stat.color[1], stat.color[2], stat.color[3], 1)
                                else
                                    valText:SetTextColor(1, 1, 1, 1)
                                end
                            end

                            -- Cursor-bound tooltip on hover
                            if stat.tooltip then
                                row:SetScript("OnEnter", function(self)
                                    if BCF.IsDraggingScroll then return end
                                    rowBg:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.08)
                                    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                                    GameTooltip:ClearLines()
                                    GameTooltip:SetText(stat.tooltip.title or stat.label, T.Accent[1], T.Accent[2],
                                        T.Accent[3])
                                    if stat.tooltip.lines then
                                        for _, line in ipairs(stat.tooltip.lines) do
                                            GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true)
                                        end
                                    end
                                    GameTooltip:Show()
                                end)
                                row:SetScript("OnLeave", function()
                                    if j % 2 == 0 then
                                        rowBg:SetColorTexture(1, 1, 1, 0.03)
                                    else
                                        rowBg:SetColorTexture(0,
                                            0, 0, 0)
                                    end
                                    GameTooltip:Hide()
                                end)
                            else
                                -- Subtle hover even without tooltip
                                row:SetScript("OnEnter", function()
                                    if BCF.IsDraggingScroll then return end
                                    rowBg:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.05)
                                end)
                                row:SetScript("OnLeave", function()
                                    if j % 2 == 0 then
                                        rowBg:SetColorTexture(1, 1, 1, 0.03)
                                    else
                                        rowBg:SetColorTexture(0,
                                            0, 0, 0)
                                    end
                                end)
                            end

                            yOffset = yOffset - 18
                        end
                    end
                end
                yOffset = yOffset - T.SectionGap
            end
            -- Update Container Height with safety clamp
            local contentHeight = math.abs(yOffset) + 20
            if contentHeight < 100 then contentHeight = 100 end
            if contentHeight > 2000 then contentHeight = 2000 end

            container:SetHeight(contentHeight)
        end, geterrorhandler())

        BCF.IsRefreshingStats = false

        if not status then
            print("BCF Error: Stats Refresh Failed", err)
        end
    end

    -- ============================================================================
    -- EQUIPMENT SETS (Tab 2) - Collapsible with Item Lists
    -- ============================================================================

    -- --- Drag Logic for Sets ---
    local function AddSetDragLogic(header, container, setIndex)
        header:EnableMouse(true)
        header:RegisterForDrag("LeftButton")

        EnsureDropLine(container, 4, 0.7)

        header:SetScript("OnDragStart", function(self)
            if BCF.IsRefreshingSets then return end
            self.isDragging = true
            self:SetAlpha(0) -- Hide original to prevent visual clutter

            local ghost = GetDragGhost()
            ghost:SetSize(self:GetWidth(), self:GetHeight())
            ghost.label:SetText(self.setName or "Set")
            ghost:Show()
            container.dropTargetLine:Show()
            container.dropTargetLine:SetFrameStrata("TOOLTIP")

            ghost:SetScript("OnUpdate", function(g)
                local x, y = GetCursorPosition()
                local s = container:GetEffectiveScale()
                local cY = y / s

                local uis = UIParent:GetEffectiveScale()
                g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / uis, y / uis)

                local gapIdx, closestFrame, lastFrame, totalHeaders = GetInsertionIndex(container, cY)

                -- Store gapIdx for OnDragStop to use (visual line = source of truth)
                container.lastGapIdx = gapIdx

                if closestFrame then
                    container.dropTargetLine:ClearAllPoints()
                    local targetHeaderFrame = nil
                    if gapIdx <= totalHeaders then
                        local currentHeaderAtPos = 0
                        for _, sec in ipairs(container.sections) do
                            if sec.isHeader and not sec.isDragging then
                                currentHeaderAtPos = currentHeaderAtPos + 1
                                if currentHeaderAtPos == gapIdx then
                                    targetHeaderFrame = sec
                                    break
                                end
                            end
                        end
                    end

                    if targetHeaderFrame then
                        container.dropTargetLine:SetPoint("BOTTOMLEFT", targetHeaderFrame, "TOPLEFT", 0, 0)
                        container.dropTargetLine:SetPoint("BOTTOMRIGHT", targetHeaderFrame, "TOPRIGHT", -5, 0)
                        container.dropTargetLine:Show()
                    elseif lastFrame then
                        container.dropTargetLine:SetPoint("TOPLEFT", lastFrame, "BOTTOMLEFT", 0, 0)
                        container.dropTargetLine:SetPoint("TOPRIGHT", lastFrame, "BOTTOMRIGHT", -5, 0)
                        container.dropTargetLine:Show()
                    else
                        container.dropTargetLine:Hide()
                    end
                else
                    container.dropTargetLine:Hide()
                end
            end)
        end)

        header:SetScript("OnDragStop", function(self)
            -- Debounce: skip if another reorder just happened (prevents double-fire after RefreshSets)
            local ghost = BCF.DragGhost
            if BCF.LastReorderTime and (GetTime() - BCF.LastReorderTime) < 0.5 then
                self.isDragging = false
                self:SetAlpha(1)
                if ghost then
                    ghost:Hide()
                    ghost:SetScript("OnUpdate", nil)
                end
                container.dropTargetLine:Hide()
                return
            end

            self.isDragging = false
            self:SetAlpha(1)

            if ghost then
                ghost:Hide()
                ghost:SetScript("OnUpdate", nil)
            end
            container.dropTargetLine:Hide()

            -- Use stored gapIdx from OnUpdate (visual line = source of truth)
            local gapIdx = container.lastGapIdx

            if gapIdx then
                -- Recalculate current index at runtime (matching stats drag behavior)
                local currentIdx = 0
                local headerIdx = 0
                for _, sec in ipairs(container.sections) do
                    if sec.isHeader then
                        headerIdx = headerIdx + 1
                        if sec == self then
                            currentIdx = headerIdx
                            break
                        end
                    end
                end

                local finalIdx = gapIdx

                if currentIdx > 0 and finalIdx ~= currentIdx then
                    BCF.LastReorderTime = GetTime()
                    if BCF.ReorderGearSets(currentIdx, finalIdx) then
                        BCF.RefreshSets(container)
                    end
                end
            end
        end)
    end

    function BCF.RefreshSets(targetContainer)
        if BCF.IsRefreshingSets then return end
        BCF.IsRefreshingSets = true

        local status, err = xpcall(function()
            targetContainer = ResolveSideStatsContainer(targetContainer)

            local container = targetContainer
            if not container then
                BCF.Print("|cffff0000[BCF]|r RefreshSets: container is nil")
                return
            end

            BCF.ClearContainer(container)

            -- Init structure (guard against nil DB) - must happen BEFORE GetGearSets
            BCF.DB = BCF.DB or {}
            BCF.DB.Sets = BCF.DB.Sets or {}
            BCF.DB.Sets.Collapsed = BCF.DB.Sets.Collapsed or {}

            local sets = BCF.GetGearSets()
            if not sets then sets = {} end -- Guard against nil return
            local activeSetName = BCF.GetActiveGearSet and BCF.GetActiveGearSet() or nil
            local queuedSetName = BCF.GetQueuedGearSetName and BCF.GetQueuedGearSetName() or nil
            local yOffset = 0
            local paddingRight = 0         -- matches stats list padding

            -- Render Sets
            for i, setData in ipairs(sets) do
                -- Guard against corrupt set data
                if not setData or not setData.name then
                    BCF.Print("|cffff6600[BCF]|r Skipping corrupt set at index " .. i)
                else
                    local collapseKey = setData.name
                    local isCollapsed = BCF.DB.Sets.Collapsed[collapseKey]
                    local isActiveSet = (activeSetName == setData.name)
                    local isQueuedSet = (queuedSetName == setData.name)
                    local isFullyEquipped = BCF.IsGearSetFullyEquipped and BCF.IsGearSetFullyEquipped(setData.name) or false
                    local isEquippedSet = isFullyEquipped and not isQueuedSet

                    -- Header Frame
                    local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
                    header:SetHeight(T.HeaderRowHeight)
                    header:SetPoint("TOPLEFT", 5, yOffset)
                    header:SetPoint("RIGHT", -5 - paddingRight, 0)
                    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                    if isEquippedSet then
                        header:SetBackdropColor(T.Accent[1] * 0.25, T.Accent[2] * 0.25, T.Accent[3] * 0.25, 0.95)
                    else
                        header:SetBackdropColor(T.Accent[1] * 0.12, T.Accent[2] * 0.12, T.Accent[3] * 0.12, 0.9)
                    end
                    table.insert(container.sections, header)
                    header.isHeader = true
                    header.setName = setData.name
                    header.setIndex = i

                    -- Add Drag Logic
                    AddSetDragLogic(header, container, i)

                    -- Active indicator (left accent bar)
                    if isEquippedSet then
                        local activeBar = header:CreateTexture(nil, "OVERLAY")
                        activeBar:SetSize(3, 20)
                        activeBar:SetPoint("LEFT", 1, 0)
                        activeBar:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.9)
                    end

                    if isQueuedSet then
                        local queuedGlow = CreateFrame("Frame", nil, header, "BackdropTemplate")
                        -- Keep border fully inside the row so top edge is not clipped by scroll region.
                        queuedGlow:SetPoint("TOPLEFT", 0, 0)
                        queuedGlow:SetPoint("BOTTOMRIGHT", 0, 0)
                        queuedGlow:SetFrameLevel(header:GetFrameLevel() + 8)
                        queuedGlow:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
                        queuedGlow:SetBackdropBorderColor(1, 0, 0, 0.8)
                        queuedGlow:SetScript("OnUpdate", function(self)
                            local alpha = 0.35 + 0.65 * math.abs(math.sin(GetTime() * 2.5))
                            self:SetBackdropBorderColor(1, 0, 0, alpha)
                        end)
                    end

                    -- Arrow (right side, before buttons)
                    local arrow = header:CreateTexture(nil, "ARTWORK")
                    arrow:SetSize(12, 12)
                    arrow:SetPoint("RIGHT", -60, 0) -- Adjusted for buttons
                    arrow:SetTexture(isCollapsed and "Interface\\Buttons\\UI-microbutton-Lbutton-Up" or
                        "Interface\\Buttons\\UI-microbutton-Dbutton-Up")
                    arrow:SetAlpha(0.7)

                    -- Toggle Collapse (Only clicking empty space)
                    header:SetScript("OnMouseUp", function(self, button)
                        if not self.isDragging and button == "LeftButton" then
                            BCF.DB.Sets.Collapsed[collapseKey] = not BCF.DB.Sets.Collapsed[collapseKey]
                            BCF.RefreshSets(targetContainer)
                        end
                    end)

                    -- Icon Button (left) - larger for visibility
                    local iconBtn = CreateFrame("Button", nil, header)
                    iconBtn:SetSize(18, 18)
                    iconBtn:SetPoint("LEFT", 4, 0)
                    local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
                    iconTex:SetAllPoints()
                    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    -- Use set's icon or fallback to a random inventory icon
                    local iconPath = setData.icon
                    if not iconPath or iconPath == "" or iconPath == 0 then
                        iconPath = "Interface\\Icons\\INV_Chest_Plate01" -- Fallback
                    elseif type(iconPath) == "string" and iconPath:find("QuestionMark") then
                        iconPath = "Interface\\Icons\\INV_Chest_Plate01" -- Fallback
                    end
                    iconTex:SetTexture(iconPath)
                    iconBtn:Show() -- Ensure visibility

                    -- Drag to Action Bar: Create/Pickup Macro
                    iconBtn:RegisterForDrag("LeftButton")
                    iconBtn:SetScript("OnDragStart", function()
                        local macroName = "BCF:" .. setData.name:sub(1, 12)
                        local macroBody = BCF.BuildGearSetMacroBody and BCF.BuildGearSetMacroBody(setData.name)
                            or ("/bcf equipset " .. setData.name)
                        local macroIcon = "INV_Misc_QuestionMark"
                        if type(iconPath) == "string" then
                            macroIcon = iconPath:gsub("Interface\\Icons\\", "")
                        elseif type(iconPath) == "number" then
                            macroIcon = iconPath
                        end

                        -- Find existing macro by name
                        local existingIndex = GetMacroIndexByName(macroName)
                        if existingIndex and existingIndex > 0 then
                            EditMacro(existingIndex, macroName, macroIcon, macroBody)
                            PickupMacro(existingIndex)
                        else
                            -- Try character-specific first, then global
                            local numGlobal, numPerChar = GetNumMacros()
                            local maxPerChar = MAX_CHARACTER_MACROS or 18
                            local maxGlobal = MAX_ACCOUNT_MACROS or 120
                            if numPerChar < maxPerChar then
                                local newIndex = CreateMacro(macroName, macroIcon, macroBody, true)
                                if newIndex then PickupMacro(newIndex) end
                            elseif numGlobal < maxGlobal then
                                local newIndex = CreateMacro(macroName, macroIcon, macroBody, false)
                                if newIndex then PickupMacro(newIndex) end
                            else
                                BCF.Print(
                                    "|cff00ccff[BCF]|r Macro slots full. Delete a macro to add gear set shortcuts.")
                            end
                        end
                    end)
                    iconBtn:SetScript("OnDragStop", function()
                        -- Nothing needed, macro is on cursor
                    end)

                    iconBtn:SetScript("OnClick", function()
                        if BCF.ShowIconPicker then
                            BCF.ShowIconPicker(setData.name, iconTex)
                        end
                    end)
                    iconBtn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine(setData.name, T.Accent[1], T.Accent[2], T.Accent[3])
                        GameTooltip:AddLine("Click to change icon", 0.7, 0.7, 0.7)
                        GameTooltip:AddLine("Drag to action bar", 0.7, 0.7, 0.7)
                        GameTooltip:Show()
                    end)
                    iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

                    -- Name EditBox (Left-Aligned next to icon)
                    local nameEdit = CreateFrame("EditBox", nil, header, "BackdropTemplate")
                    nameEdit:SetPoint("LEFT", iconBtn, "RIGHT", 6, 0)
                    nameEdit:SetWidth(90) -- Reduced width for cleaner appearance
                    nameEdit:SetHeight(18)
                    nameEdit:SetFontObject("GameFontHighlight")
                    nameEdit:SetAutoFocus(false)
                    nameEdit:SetText(setData.name)
                    nameEdit:SetCursorPosition(0) -- Show text from beginning when too long
                    nameEdit:SetJustifyH("LEFT")
                    nameEdit:SetTextColor(unpack(T.Accent))
                    BCF.CleanFont(nameEdit)

                    -- Backdrop only on focus
                    nameEdit:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile =
                        "Interface\\Buttons\\WHITE8X8",
                        edgeSize = 1
                    })
                    nameEdit:SetBackdropColor(0, 0, 0, 0)
                    nameEdit:SetBackdropBorderColor(0, 0, 0, 0)

                    nameEdit:SetScript("OnEditFocusGained", function(self)
                        self:SetBackdropColor(0, 0, 0, 0.5)
                        self:SetBackdropBorderColor(unpack(T.Accent))
                    end)

                    local isRenaming = false
                    local function SaveRename(self)
                        if isRenaming then return end
                        isRenaming = true
                        self:ClearFocus()
                        local newName = self:GetText()
                        if newName and newName ~= "" and newName ~= setData.name then
                            BCF.RenameGearSet(setData.name, newName)
                            -- Revert lock to ensure re-entry
                            BCF.IsRefreshingSets = false
                            if BCF.RefreshSets then BCF.RefreshSets(targetContainer) end
                        else
                            self:SetText(setData.name) -- Revert
                        end
                        self:SetCursorPosition(0)      -- Always reset cursor to beginning
                        self:SetBackdropColor(0, 0, 0, 0)
                        self:SetBackdropBorderColor(0, 0, 0, 0)
                        isRenaming = false
                    end

                    nameEdit:SetScript("OnEnterPressed", SaveRename)
                    nameEdit:SetScript("OnEditFocusLost", SaveRename)

                    -- Equip Button (Rightmost)
                    local equipBtn = CreateFrame("Button", nil, header)
                    equipBtn:SetSize(18, 18)
                    equipBtn:SetPoint("RIGHT", -4, 0)
                    local equipTex = equipBtn:CreateTexture(nil, "ARTWORK")
                    equipTex:SetAllPoints()
                    equipTex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
                    if isEquippedSet then
                        equipTex:SetDesaturated(false)
                        equipTex:SetVertexColor(0.2, 1, 0.2)
                    else
                        equipTex:SetDesaturated(true)
                        equipTex:SetVertexColor(1, 1, 1)
                    end
                    equipBtn:SetScript("OnClick", function()
                        local currentName = setData.name or nameEdit:GetText()
                        if currentName and currentName ~= "" then
                            if BCF.TriggerGearSetMacro then
                                BCF.TriggerGearSetMacro(currentName)
                            else
                                BCF.EquipGearSet(currentName, true)
                            end
                            if BCF.RefreshSets then
                                BCF.RefreshSets(targetContainer)
                            end
                        end
                    end)
                    equipBtn:SetScript("OnEnter", function()
                        if BCF.IsDraggingScroll then return end
                        equipTex:SetDesaturated(false)                -- Color on hover
                        equipTex:SetVertexColor(0.2, 1, 0.2)
                        GameTooltip:SetOwner(equipBtn, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Equip Set", 0.2, 1, 0.2) -- Green
                        GameTooltip:Show()
                    end)
                    equipBtn:SetScript("OnLeave", function()
                        if isEquippedSet then
                            equipTex:SetDesaturated(false)
                            equipTex:SetVertexColor(0.2, 1, 0.2)
                        else
                            equipTex:SetDesaturated(true)
                            equipTex:SetVertexColor(1, 1, 1)
                        end
                        GameTooltip:Hide()
                    end)

                    -- Save Button (Next to Equip)
                    local saveBtn = CreateFrame("Button", nil, header)
                    saveBtn:SetSize(18, 18)
                    saveBtn:SetPoint("RIGHT", equipBtn, "LEFT", -4, 0)
                    local saveTex = saveBtn:CreateTexture(nil, "ARTWORK")
                    saveTex:SetAllPoints()
                    saveTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
                    saveTex:SetDesaturated(true) -- Greyed out by default

                    saveBtn:SetScript("OnClick", function(self)
                        local currentName = nameEdit:GetText()
                        if currentName and currentName ~= "" then
                            BCF.SaveGearSet(currentName, true)
                            BCF.IsRefreshingSets = false
                            BCF.RefreshSets(targetContainer)
                        end
                    end)
                    saveBtn:SetScript("OnEnter", function(self)
                        if BCF.IsDraggingScroll then return end
                        saveTex:SetDesaturated(false)                  -- Color on hover
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Update Set", 1, 0.8, 0.2) -- Yellow
                        GameTooltip:Show()
                    end)
                    saveBtn:SetScript("OnLeave", function()
                        saveTex:SetDesaturated(true) -- Back to grey
                        GameTooltip:Hide()
                    end)

                    -- Delete Button (Next to Save)
                    local delBtn = CreateFrame("Button", nil, header)
                    delBtn:SetSize(18, 18)
                    delBtn:SetPoint("RIGHT", saveBtn, "LEFT", -4, 0)
                    local delTex = delBtn:CreateTexture(nil, "ARTWORK")
                    delTex:SetAllPoints()
                    delTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                    delTex:SetDesaturated(true) -- Greyed out by default

                    delBtn:SetScript("OnClick", function(self)
                        local currentName = nameEdit:GetText()
                        if currentName and currentName ~= "" and BCF.ShowConfirmDialog then
                            BCF.ShowConfirmDialog("Delete |cffffffff" .. currentName .. "|r?", function()
                                BCF.DeleteGearSet(currentName)
                                BCF.IsRefreshingSets = false
                                if BCF.RefreshSets and BCF.SideStats then
                                    BCF.RefreshSets(BCF.SideStats)
                                end
                            end)
                        end
                    end)
                    delBtn:SetScript("OnEnter", function(self)
                        if BCF.IsDraggingScroll then return end
                        delTex:SetDesaturated(false) -- Color on hover
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Delete Set", 1, 0, 0)
                        GameTooltip:Show()
                    end)
                    delBtn:SetScript("OnLeave", function()
                        delTex:SetDesaturated(true) -- Back to grey
                        GameTooltip:Hide()
                    end)

                    yOffset = yOffset - 26

                    if not isCollapsed then
                        -- Render Slots
                        local slots = {
                            { id = 1,  name = "Head" }, { id = 2, name = "Neck" }, { id = 3, name = "Shoulder" },
                            { id = 15, name = "Back" }, { id = 5, name = "Chest" }, { id = 9, name = "Wrist" },
                            { id = 10, name = "Hands" }, { id = 6, name = "Waist" }, { id = 7, name = "Legs" },
                            { id = 8,  name = "Feet" }, { id = 11, name = "Ring1" }, { id = 12, name = "Ring2" },
                            { id = 13, name = "Trink1" }, { id = 14, name = "Trink2" },
                            { id = 16, name = "Main" }, { id = 17, name = "Off" }, { id = 18, name = "Ranged" }
                        }

                        -- CRITICAL GUARD: Ensure setData.slots exists (Previously .items)
                        if setData.slots then
                            for _, slot in ipairs(slots) do
                                local slotData = setData.slots[slot.id]
                                local itemLink = slotData and slotData.link
                                if itemLink then
                                    local row = CreateFrame("Frame", nil, container)
                                    row:SetHeight(18)
                                    row:SetPoint("TOPLEFT", 10, yOffset) -- Indent
                                    row:SetPoint("RIGHT", -10, 0)
                                    table.insert(container.sections, row)

                                    -- Icon
                                    local itemIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
                                    if GetItemInfo then
                                        local _, _, _, _, _, _, _, _, _, tIcon = GetItemInfo(itemLink)
                                        if tIcon then itemIcon = tIcon end
                                    end

                                    local iconBtn = CreateFrame("Button", nil, row)
                                    iconBtn:SetSize(16, 16)
                                    iconBtn:SetPoint("LEFT", 0, 0)
                                    local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
                                    iconTex:SetAllPoints()
                                    iconTex:SetTexture(itemIcon)
                                    iconTex:SetTexCoord(0.1, 0.9, 0.1, 0.9)

                                    -- Icon: tooltip + shift-click to link
                                    iconBtn:SetScript("OnEnter", function(self)
                                        if BCF.IsDraggingScroll then return end
                                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                        GameTooltip:SetHyperlink(itemLink)
                                        GameTooltip:Show()
                                    end)
                                    iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                                    iconBtn:SetScript("OnClick", function(_, button)
                                        if IsShiftKeyDown() then
                                            HandleModifiedItemClick(itemLink)
                                        end
                                    end)

                                    local txt = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY",
                                        "GameFontHighlightSmall"))
                                    txt:SetPoint("LEFT", iconBtn, "RIGHT", 6, 0)
                                    txt:SetPoint("RIGHT", 0, 0)
                                    txt:SetText(itemLink)
                                    txt:SetJustifyH("LEFT")

                                    yOffset = yOffset - 18
                                end
                            end
                        else
                            -- Debug check: why no items?
                            -- print("BCF Warning: Set has no items table", setData.name)
                        end
                    end
                    yOffset = yOffset - T.SectionGap
                end -- end of corrupt data check
            end

            -- Footer: "Create New Set" Button
            local footerBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
            footerBtn:SetHeight(28)
            footerBtn:SetPoint("TOPLEFT", 5, yOffset)
            footerBtn:SetPoint("RIGHT", -5 - paddingRight, 0)
            footerBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
            footerBtn:SetBackdropColor(T.Accent[1] * 0.05, T.Accent[2] * 0.05, T.Accent[3] * 0.05, 0.5)
            table.insert(container.sections, footerBtn)

            -- Plus Icon
            local plusIcon = footerBtn:CreateTexture(nil, "ARTWORK")
            plusIcon:SetSize(16, 16)
            plusIcon:SetPoint("LEFT", 8, 0)
            plusIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
            plusIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
            plusIcon:SetAlpha(0.7)

            -- Label
            local footerText = footerBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            footerText:SetPoint("LEFT", plusIcon, "RIGHT", 8, 0)
            footerText:SetText("Create New Equipment Set")
            footerText:SetTextColor(T.Accent[1] * 0.8, T.Accent[2] * 0.8, T.Accent[3] * 0.8, 1)
            BCF.CleanFont(footerText)

            -- Hover Effect
            footerBtn:SetScript("OnEnter", function(self)
                if BCF.IsDraggingScroll then return end
                self:SetBackdropColor(T.Accent[1] * 0.15, T.Accent[2] * 0.15, T.Accent[3] * 0.15, 0.8)
                footerText:SetTextColor(unpack(T.Accent))
                plusIcon:SetAlpha(1.0)
            end)
            footerBtn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(T.Accent[1] * 0.05, T.Accent[2] * 0.05, T.Accent[3] * 0.05, 0.5)
                footerText:SetTextColor(T.Accent[1] * 0.8, T.Accent[2] * 0.8, T.Accent[3] * 0.8, 1)
                plusIcon:SetAlpha(0.7)
            end)

            -- Click: Create New Equipment Set
            footerBtn:SetScript("OnClick", function()
                -- Find unique name by incrementing counter
                local counter = 1
                local newName = "New Set " .. counter
                local existingNames = {}
                for _, setData in ipairs(sets) do
                    existingNames[setData.name] = true
                end
                while existingNames[newName] do
                    counter = counter + 1
                    newName = "New Set " .. counter
                end
                BCF.SaveGearSet(newName, false)
                BCF.IsRefreshingSets = false
                BCF.RefreshSets(targetContainer)
            end)

            if #sets == 0 then
                yOffset = yOffset - 60
                local empty = BCF.CleanFont(container:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
                empty:SetPoint("TOP", container, "TOP", 0, yOffset)
                empty:SetText("No Equipment Sets Saved")
                empty:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.6)
                table.insert(container.sections, empty)
            else
                yOffset = yOffset - 30
            end

            yOffset = yOffset - 26

            -- Finalize container height with safety clamp
            local contentHeight = math.abs(yOffset) + 20
            if contentHeight < 100 then contentHeight = 100 end
            if contentHeight > 2000 then contentHeight = 2000 end

            container:SetHeight(contentHeight)
        end, function(e)
            local msg = tostring(e) or "unknown error"
            local trace = ""
            if debug and debug.traceback then
                local ok, tb = pcall(debug.traceback, "", 2)
                if ok and tb then trace = "\n" .. tb end
            end
            return msg .. trace
        end)

        BCF.IsRefreshingSets = false

        if not status then
            BCF.Print("|cffff0000[BCF]|r Sets Refresh Error:", tostring(err))
        end
    end

    -- ============================================================================
    -- TYPOGRAPHY PASS: Remove all shadows and outlines from font strings
    -- ============================================================================
    local function CleanAllFonts(frame)
        if not frame then return end
        -- Clean direct children regions (font strings)
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region.GetFont and region.SetShadowOffset then
                BCF.CleanFont(region)
            end
        end
        -- Recurse into child frames
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            CleanAllFonts(child)
        end
    end

    -- Defer to after all frames are initialized
    C_Timer.After(0.2, function()
        if BCF.MainFrame then CleanAllFonts(BCF.MainFrame) end
    end)

    -- Force Layout Update on Load
    if BCF.RefreshCharacter then BCF.RefreshCharacter() end
    -- Force Stats Update on Load (Fix for empty list until tab swap)
    if BCF.RefreshStats then
        -- Ensure we have a container to refresh into
        if BCF.SideStats and BCF.SideStats.Content then
            BCF.RefreshStats(BCF.SideStats.Content)
        end
    end
end
