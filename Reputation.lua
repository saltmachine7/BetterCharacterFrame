local addonName, BCF = ...

-- ============================================================================
-- MODULE: Reputation
-- ============================================================================

local T = BCF.Tokens

-- Standing colors
local STANDING_COLORS = {
    [1] = {0.78, 0.23, 0.18},  -- Hated (red)
    [2] = {0.80, 0.35, 0.22},  -- Hostile (dark orange)
    [3] = {0.75, 0.45, 0.25},  -- Unfriendly (orange)
    [4] = {0.90, 0.80, 0.50},  -- Neutral (yellow)
    [5] = {0.25, 0.65, 0.25},  -- Friendly (green)
    [6] = {0.25, 0.75, 0.45},  -- Honored (teal-green)
    [7] = {0.30, 0.55, 0.85},  -- Revered (blue)
    [8] = {0.58, 0.40, 0.82},  -- Exalted (purple)
}

local STANDING_LABELS = {
    [1] = "Hated",
    [2] = "Hostile",
    [3] = "Unfriendly",
    [4] = "Neutral",
    [5] = "Friendly",
    [6] = "Honored",
    [7] = "Revered",
    [8] = "Exalted",
}

-- ============================================================================
-- FAVORITES STORAGE
-- ============================================================================
local function EnsureCharacterStorage()
    local charKey = BCF.GetCharacterKey and BCF.GetCharacterKey()
    if not charKey or not BCF.DB then return nil end
    BCF.DB.Characters = BCF.DB.Characters or {}
    BCF.DB.Characters[charKey] = BCF.DB.Characters[charKey] or {}
    BCF.DB.Characters[charKey].FavoriteFactions = BCF.DB.Characters[charKey].FavoriteFactions or {}
    return charKey
end

local function GetFavorites()
    local charKey = EnsureCharacterStorage()
    if charKey then
        return BCF.DB.Characters[charKey].FavoriteFactions
    end
    return {}
end

local function IsFavorite(factionName)
    local favs = GetFavorites()
    return favs[factionName] == true
end

local function ToggleFavorite(factionName)
    local favs = GetFavorites()
    if favs[factionName] then
        favs[factionName] = nil
    else
        favs[factionName] = true
    end
end

-- Favorites header state persisted to BCF.DB.Reputation.FavoritesExpanded
local function IsFavoritesExpanded()
    return BCF.DB and BCF.DB.Reputation and BCF.DB.Reputation.FavoritesExpanded ~= false
end

-- ============================================================================
-- ROW POOL
-- ============================================================================
local GetRow, ReleaseRow = BCF.CreateRowPool(
    function(row)
        row.starBtn = CreateFrame("Button", nil, row)
        row.starBtn:SetSize(20, 20)
        row.starBtn:SetPoint("LEFT", 4, 0)
        row.starBtn.tex = row.starBtn:CreateTexture(nil, "ARTWORK")
        row.starBtn.tex:SetAllPoints()
        row.starBtn.tex:SetTexture("Interface\\COMMON\\FavoritesIcon")
        row.starBtn:Hide()

        row.atWarIcon = row:CreateTexture(nil, "OVERLAY")
        row.atWarIcon:SetSize(14, 14)
        row.atWarIcon:SetTexture("Interface\\PVPFrame\\Icon-Combat")
        row.atWarIcon:SetPoint("RIGHT", -8, 0)
        row.atWarIcon:Hide()

        row.standing = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        row.standing:SetPoint("RIGHT", row.atWarIcon, "LEFT", -6, 0)
        row.standing:SetJustifyH("RIGHT")
        row.standing:SetWidth(75)

        row.barBg = CreateFrame("StatusBar", nil, row)
        row.barBg:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
        row.barBg:SetPoint("RIGHT", row.standing, "LEFT", -10, 0)
        row.barBg:SetHeight(10)
        row.barBg:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        row.barBg:SetMinMaxValues(0, 1)
        row.barBg.bg = row.barBg:CreateTexture(nil, "BACKGROUND")
        row.barBg.bg:SetAllPoints()
        row.barBg.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.barBg.bg:SetVertexColor(0.1, 0.1, 0.12, 1)

        row.progress = BCF.CleanFont(row.barBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
        row.progress:SetPoint("CENTER", 0, 0)
        row.progress:SetTextColor(1, 1, 1, 0.9)
    end,
    function(row)
        row.starBtn:SetScript("OnClick", nil)
        row.starBtn:Hide()
    end
)

-- ============================================================================
-- RENDER A FACTION ROW (shared between favorites and normal list)
-- ============================================================================
local function RenderFactionRow(row, container, factionIndex, rowIndex, yOffset)
    local name, description, standingID, barMin, barMax, barValue, atWarWith,
          canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)

    if not name or isHeader then return false end

    local isFav = IsFavorite(name)
    local indent = 24  -- Space for star

    local bgAlpha = BCF.ApplyRowStripe(row, rowIndex)
    row.expandBtn:Hide()
    row.factionIndex = factionIndex
    row.isHeader = false

    -- Star button
    row.starBtn:Show()
    row.starBtn:SetPoint("LEFT", 6, 0)
    if isFav then
        row.starBtn.tex:SetVertexColor(T.Accent[1], T.Accent[2], T.Accent[3])
        row.starBtn.tex:SetAlpha(1)
    else
        row.starBtn.tex:SetVertexColor(0.4, 0.4, 0.4)
        row.starBtn.tex:SetAlpha(0.4)
    end
    row.starBtn:SetScript("OnClick", function()
        local wasAdding = not IsFavorite(name)
        local hadFavorites = false
        local favs = GetFavorites()
        for _ in pairs(favs) do hadFavorites = true; break end

        ToggleFavorite(name)

        -- Compensate scroll so view stays fixed
        local sf = BCF.ReputationScrollFrame
        if sf then
            local oldScroll = sf:GetVerticalScroll()
            local delta = 24  -- one row height
            if wasAdding and not hadFavorites then
                delta = 48  -- header + row for first favorite
            elseif not wasAdding then
                -- Removing: check if this was the last favorite
                local remaining = false
                local newFavs = GetFavorites()
                for _ in pairs(newFavs) do remaining = true; break end
                delta = remaining and -24 or -48
            end
            BCF.RefreshReputation(container)
            sf:SetVerticalScroll(math.max(0, oldScroll + delta))
        else
            BCF.RefreshReputation(container)
        end
    end)

    -- Name
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.starBtn, "RIGHT", 4, 0)
    row.name:SetText(name)
    row.name:SetWidth(120)

    -- Standing
    local standingColor = STANDING_COLORS[standingID] or {0.5, 0.5, 0.5}
    local standingLabel = STANDING_LABELS[standingID] or "Unknown"
    row.standing:SetText(standingLabel)
    row.standing:SetTextColor(standingColor[1], standingColor[2], standingColor[3])

    -- Name color matches standing
    row.name:SetTextColor(standingColor[1], standingColor[2], standingColor[3])

    -- Standing always at fixed position for consistent bar width
    row.standing:ClearAllPoints()
    row.standing:SetPoint("RIGHT", -8, 0)

    -- At War indicator (inside standing area, doesn't affect bar width)
    if atWarWith then
        row.atWarIcon:ClearAllPoints()
        row.atWarIcon:SetSize(10, 10)
        row.atWarIcon:SetPoint("LEFT", row.standing, "LEFT", 0, 0)
        row.atWarIcon:Show()
        row.atWarIcon:SetVertexColor(0.9, 0.3, 0.3)
        row.name:SetTextColor(0.9, 0.3, 0.3)
    else
        row.atWarIcon:Hide()
    end

    -- Progress bar
    row.barBg:Show()
    row.progress:Show()

    local barRange = barMax - barMin
    local barProgress = barValue - barMin
    local pct = barRange > 0 and (barProgress / barRange) or 0

    row.barBg:SetStatusBarColor(standingColor[1], standingColor[2], standingColor[3], 0.8)
    row.barBg:SetValue(pct)
    row.progress:SetText(string.format("%d / %d", barProgress, barRange))

    -- Click to open detail popup
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            BCF.ShowFactionDetail(factionIndex)
        end
    end)

    -- Hover
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T.Accent[1]*0.1, T.Accent[2]*0.1, T.Accent[3]*0.1, 0.8)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(name, 1, 1, 1)
        GameTooltip:AddLine(standingLabel, standingColor[1], standingColor[2], standingColor[3])
        GameTooltip:AddLine(string.format("%d / %d", barProgress, barRange), 0.8, 0.8, 0.8)
        if description and description ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(description, 1, 1, 1, true)
        end
        if atWarWith then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("At War", 0.9, 0.3, 0.3)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click for options", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T.RowStripe[1], T.RowStripe[2], T.RowStripe[3], bgAlpha)
        GameTooltip:Hide()
    end)

    return true
end

-- ============================================================================
-- RENDER A HEADER ROW
-- ============================================================================
local function RenderHeaderRow(row, container, text, isCollapsed, onClickFn)
    row:SetBackdropColor(T.Accent[1]*0.12, T.Accent[2]*0.12, T.Accent[3]*0.12, 0.9)
    row.expandBtn:Show()
    row.expandBtn:SetText(isCollapsed and "+" or "-")
    row.expandBtn:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3])
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", T.RowTextIndent, 0)
    row.name:SetText(text)
    row.name:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3])
    row.name:SetWidth(0)
    row.standing:SetText("")
    row.barBg:Hide()
    row.progress:Hide()
    row.atWarIcon:Hide()
    row.starBtn:Hide()
    row.isHeader = true

    row:EnableMouse(true)
    row:SetScript("OnMouseUp", onClickFn)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T.Accent[1]*0.2, T.Accent[2]*0.2, T.Accent[3]*0.2, 1)
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T.Accent[1]*0.12, T.Accent[2]*0.12, T.Accent[3]*0.12, 0.9)
    end)
end

-- ============================================================================
-- FACTION DETAIL POPUP
-- ============================================================================
local factionDetail = CreateFrame("Frame", "BCFFactionDetail", UIParent, "BackdropTemplate")
factionDetail:SetWidth(280)
factionDetail:SetHeight(200)
factionDetail:SetFrameStrata("HIGH")
factionDetail:SetMovable(false)
factionDetail:EnableMouse(true)
factionDetail:SetClipsChildren(true)
factionDetail:Hide()

local function StyleDetailPopup()
    factionDetail:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    factionDetail:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
end

local detailTitle = BCF.CleanFont(factionDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"))
detailTitle:SetPoint("TOP", 0, -10)
detailTitle:SetTextColor(unpack(T.Accent))

local loreFrame = CreateFrame("Frame", nil, factionDetail)
loreFrame:SetPoint("TOPLEFT", 10, -35)
loreFrame:SetPoint("TOPRIGHT", -10, -35)
loreFrame:SetHeight(70)

local loreText = BCF.CleanFont(factionDetail:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
loreText:SetPoint("TOPLEFT", loreFrame, "TOPLEFT", 0, 0)
loreText:SetPoint("TOPRIGHT", loreFrame, "TOPRIGHT", 0, 0)
loreText:SetJustifyH("LEFT")
loreText:SetJustifyV("TOP")
loreText:SetTextColor(0.8, 0.8, 0.8)

local function CreateCheckbox(parent, label, yOffset, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    cb:SetSize(16, 16)
    cb:SetPoint("TOPLEFT", 10, yOffset)
    cb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    cb:SetBackdropColor(0.1, 0.1, 0.12, 1)
    cb:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local check = cb:CreateTexture(nil, "ARTWORK")
    check:SetSize(12, 12)
    check:SetPoint("CENTER", 0, 0)
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:Hide()
    cb.check = check

    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if checked then
            self.check:Show()
            self:SetBackdropBorderColor(T.Accent[1], T.Accent[2], T.Accent[3], 1)
        else
            self.check:Hide()
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
    end)

    local lbl = BCF.CleanFont(parent:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    lbl:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    lbl:SetText(label)
    lbl:SetTextColor(1, 1, 1)
    cb.label = lbl

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    return cb
end

local atWarCheckbox = CreateCheckbox(factionDetail, "At War", -110, "Declare war on this faction. Allows attacking their members.")
local inactiveCheckbox = CreateCheckbox(factionDetail, "Move to Inactive", -132, "Move this faction to the inactive list.")
local watchedCheckbox = CreateCheckbox(factionDetail, "Show as Experience Bar", -154, "Track this faction's reputation on your experience bar.")

local closeBtn = BCF.CreateCloseButton(factionDetail, 20, function() factionDetail:Hide() end)
closeBtn:SetPoint("TOPRIGHT", -5, -5)

factionDetail.factionName = nil

-- Resolve faction index by name (indices shift when headers collapse/expand)
local function FindFactionIndexByName(targetName)
    for i = 1, GetNumFactions() do
        local n = GetFactionInfo(i)
        if n == targetName then return i end
    end
    return nil
end

-- Update checkbox visual to match a boolean state
local function UpdateCheckboxVisual(cb, checked)
    cb:SetChecked(checked)
    cb.check:SetShown(checked)
    cb:SetBackdropBorderColor(checked and T.Accent[1] or 0.3, checked and T.Accent[2] or 0.3, checked and T.Accent[3] or 0.3, 1)
end

function BCF.ShowFactionDetail(factionIndex)
    local name, description, standingID, barMin, barMax, barValue, atWarWith,
          canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)

    if not name or isHeader then return end

    StyleDetailPopup()

    factionDetail.factionName = name
    detailTitle:SetText(name)

    if description and description ~= "" then
        loreText:SetText(description)
    else
        loreText:SetText("No information available.")
    end

    UpdateCheckboxVisual(atWarCheckbox, atWarWith)
    atWarCheckbox:SetEnabled(canToggleAtWar)
    atWarCheckbox.label:SetTextColor(canToggleAtWar and 1 or 0.5, canToggleAtWar and 1 or 0.5, canToggleAtWar and 1 or 0.5)

    atWarCheckbox:SetScript("OnClick", function(self)
        local idx = FindFactionIndexByName(factionDetail.factionName)
        if not idx then return end
        FactionToggleAtWar(idx)
        UpdateCheckboxVisual(self, self:GetChecked())
        if BCF.RefreshReputation and BCF.ReputationContent then
            BCF.RefreshReputation(BCF.ReputationContent)
        end
    end)

    UpdateCheckboxVisual(inactiveCheckbox, IsFactionInactive(factionIndex))

    inactiveCheckbox:SetScript("OnClick", function(self)
        local idx = FindFactionIndexByName(factionDetail.factionName)
        if not idx then return end
        if self:GetChecked() then
            SetFactionInactive(idx)
        else
            SetFactionActive(idx)
        end
        UpdateCheckboxVisual(self, self:GetChecked())
        if BCF.RefreshReputation and BCF.ReputationContent then
            BCF.RefreshReputation(BCF.ReputationContent)
        end
    end)

    UpdateCheckboxVisual(watchedCheckbox, isWatched)

    watchedCheckbox:SetScript("OnClick", function(self)
        local idx = FindFactionIndexByName(factionDetail.factionName)
        if not idx then return end
        if self:GetChecked() then
            SetWatchedFactionIndex(idx)
        else
            SetWatchedFactionIndex(0)
        end
        UpdateCheckboxVisual(self, self:GetChecked())
        if BCF.RefreshReputation and BCF.ReputationContent then
            BCF.RefreshReputation(BCF.ReputationContent)
        end
    end)

    factionDetail:ClearAllPoints()
    if BCF.MainFrame then
        factionDetail:SetPoint("TOP", BCF.MainFrame, "TOP", 0, 0)
        factionDetail:SetPoint("LEFT", BCF.MainFrame, "RIGHT", 2, 0)
        factionDetail:SetHeight(BCF.MainFrame:GetHeight() * 0.4)
    else
        factionDetail:SetPoint("CENTER")
    end

    factionDetail:Show()
end

-- ============================================================================
-- REFRESH REPUTATION LIST
-- ============================================================================
local isRefreshing = false

-- Expand ALL faction headers (handles nested/sub-headers)
-- Returns table of previously-collapsed header names
local function ExpandAllFactionHeaders()
    local wasCollapsed = {}
    local found = true
    while found do
        found = false
        for i = GetNumFactions(), 1, -1 do
            local name, _, _, _, _, _, _, _, isHeader, isCollapsed = GetFactionInfo(i)
            if isHeader and isCollapsed then
                wasCollapsed[name] = true
                ExpandFactionHeader(i)
                found = true
            end
        end
    end
    return wasCollapsed
end

-- Restore previously-collapsed headers
local function RestoreFactionHeaders(wasCollapsed)
    for i = GetNumFactions(), 1, -1 do
        local name, _, _, _, _, _, _, _, isHeader = GetFactionInfo(i)
        if isHeader and wasCollapsed[name] then
            CollapseFactionHeader(i)
        end
    end
end

function BCF.RefreshReputation(container)
    if not container or isRefreshing then return end
    isRefreshing = true

    local scrollFrame = container:GetParent()
    if scrollFrame then
        container:SetWidth(scrollFrame:GetWidth() - 5)
    end

    -- Release existing rows
    container.reputationRows = container.reputationRows or {}
    for _, row in ipairs(container.reputationRows) do
        ReleaseRow(row)
    end
    container.reputationRows = {}

    -- Expand ALL WoW headers so we can access every faction
    -- Collapse state is managed purely by BCF.DB, not WoW's API
    ExpandAllFactionHeaders()

    -- Ensure collapse DB exists
    if BCF.DB and BCF.DB.Reputation then
        BCF.DB.Reputation.Collapsed = BCF.DB.Reputation.Collapsed or {}
    end
    local collapsedDB = (BCF.DB and BCF.DB.Reputation and BCF.DB.Reputation.Collapsed) or {}

    local yOffset = -5
    local rowIndex = 0

    -- Collect favorite faction indices (all headers expanded, full scan)
    local favs = GetFavorites()
    local hasFavorites = false
    for _ in pairs(favs) do hasFavorites = true; break end

    -- == FAVORITES CATEGORY ==
    if hasFavorites then
        local favoriteIndices = {}
        for i = 1, GetNumFactions() do
            local name, _, _, _, _, _, _, _, isHeader = GetFactionInfo(i)
            if name and not isHeader and favs[name] then
                table.insert(favoriteIndices, i)
            end
        end

        if #favoriteIndices > 0 then
            local headerRow = GetRow(container)
            rowIndex = rowIndex + 1
            table.insert(container.reputationRows, headerRow)
            headerRow:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
            headerRow:SetPoint("RIGHT", container, "RIGHT", -5, 0)

            RenderHeaderRow(headerRow, container, "Favorites", not IsFavoritesExpanded(), function(self, button)
                if button == "LeftButton" then
                    BCF.DB.Reputation.FavoritesExpanded = not IsFavoritesExpanded()
                    isRefreshing = false
                    BCF.RefreshReputation(container)
                end
            end)
            yOffset = yOffset - T.HeaderRowHeight

            if IsFavoritesExpanded() then
                for _, fi in ipairs(favoriteIndices) do
                    local row = GetRow(container)
                    rowIndex = rowIndex + 1
                    table.insert(container.reputationRows, row)
                    row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
                    row:SetPoint("RIGHT", container, "RIGHT", -5, 0)

                    if RenderFactionRow(row, container, fi, rowIndex, yOffset) then
                        yOffset = yOffset - T.HeaderRowHeight
                    end
                end
            end
        end
    end

    -- == NORMAL FACTION LIST (BCF-managed collapse) ==
    local topCollapsed = false
    local subCollapsed = false

    for i = 1, GetNumFactions() do
        local name, description, standingID, barMin, barMax, barValue, atWarWith,
              canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(i)

        if name then
            if isHeader and not isChild then
                -- Top-level header: always visible
                topCollapsed = collapsedDB[name] or false
                subCollapsed = false

                local row = GetRow(container)
                rowIndex = rowIndex + 1
                table.insert(container.reputationRows, row)
                row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
                row:SetPoint("RIGHT", container, "RIGHT", -5, 0)

                local headerName = name
                RenderHeaderRow(row, container, name, topCollapsed, function(self, button)
                    if button == "LeftButton" then
                        collapsedDB[headerName] = not collapsedDB[headerName] or nil
                        isRefreshing = false
                        BCF.RefreshReputation(container)
                    end
                end)
                yOffset = yOffset - T.HeaderRowHeight

            elseif isHeader and isChild then
                -- Sub-header: visible only if parent top header is expanded
                if not topCollapsed then
                    subCollapsed = collapsedDB[name] or false

                    local row = GetRow(container)
                    rowIndex = rowIndex + 1
                    table.insert(container.reputationRows, row)
                    row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
                    row:SetPoint("RIGHT", container, "RIGHT", -5, 0)

                    local headerName = name
                    RenderHeaderRow(row, container, name, subCollapsed, function(self, button)
                        if button == "LeftButton" then
                            collapsedDB[headerName] = not collapsedDB[headerName] or nil
                            isRefreshing = false
                            BCF.RefreshReputation(container)
                        end
                    end)
                    yOffset = yOffset - T.HeaderRowHeight
                end

            else
                -- Faction: visible only if no parent header is collapsed
                if not topCollapsed and not subCollapsed then
                    local row = GetRow(container)
                    rowIndex = rowIndex + 1
                    table.insert(container.reputationRows, row)
                    row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
                    row:SetPoint("RIGHT", container, "RIGHT", -5, 0)

                    RenderFactionRow(row, container, i, rowIndex, yOffset)
                    yOffset = yOffset - T.HeaderRowHeight
                end
            end
        end
    end

    container:SetHeight(math.abs(yOffset) + 10)
    isRefreshing = false
end

-- ============================================================================
-- AUTO-FAVORITE SCRYERS/ALDOR
-- ============================================================================
local function AutoFavoriteScryersAldor()
    local charKey = EnsureCharacterStorage()
    if not charKey then return end

    local charData = BCF.DB.Characters[charKey]
    if charData.AutoFavScryersAldorDone then return end

    isRefreshing = true

    local wasCollapsed = ExpandAllFactionHeaders()

    local scryers, aldor
    for i = 1, GetNumFactions() do
        local name, _, standingID, barMin, barMax, barValue, _, _, isHeader = GetFactionInfo(i)
        if not isHeader then
            if name == "The Scryers" then
                scryers = {standing = standingID, value = barValue}
            elseif name == "The Aldor" then
                aldor = {standing = standingID, value = barValue}
            end
        end
    end

    RestoreFactionHeaders(wasCollapsed)

    isRefreshing = false

    charData.FavoriteFactions = charData.FavoriteFactions or {}
    local favs = charData.FavoriteFactions

    if scryers and aldor then
        if scryers.standing == aldor.standing then
            if scryers.standing == 4 then
                -- Both neutral: favorite both
                favs["The Scryers"] = true
                favs["The Aldor"] = true
            elseif scryers.value > aldor.value then
                favs["The Scryers"] = true
                favs["The Aldor"] = nil
            elseif aldor.value > scryers.value then
                favs["The Aldor"] = true
                favs["The Scryers"] = nil
            else
                favs["The Scryers"] = true
                favs["The Aldor"] = true
            end
        elseif scryers.standing > aldor.standing then
            favs["The Scryers"] = true
            favs["The Aldor"] = nil
        else
            favs["The Aldor"] = true
            favs["The Scryers"] = nil
        end
    elseif scryers then
        favs["The Scryers"] = true
    elseif aldor then
        favs["The Aldor"] = true
    end

    charData.AutoFavScryersAldorDone = true
end

-- Default Outland factions to favorite on first load (excludes Scryers/Aldor)
local OUTLAND_DEFAULT_FAVS = {
    "Cenarion Expedition",
    "The Consortium",
    "Thrallmar",
    "Honor Hold",
    "Keepers of Time",
    "Lower City",
    "The Sha'tar",
    "The Violet Eye",
}

local function AutoFavoriteOutlandFactions()
    local charKey = EnsureCharacterStorage()
    if not charKey then return end

    local charData = BCF.DB.Characters[charKey]
    if charData.AutoFavOutlandDone then return end

    isRefreshing = true

    local wasCollapsed = ExpandAllFactionHeaders()

    local targetSet = {}
    for _, n in ipairs(OUTLAND_DEFAULT_FAVS) do
        targetSet[n] = true
    end

    local encountered = {}
    local anyEncountered = false
    for i = 1, GetNumFactions() do
        local name, _, standingID, _, _, _, _, _, isHeader = GetFactionInfo(i)
        if name and not isHeader and targetSet[name] and standingID and standingID > 0 then
            encountered[name] = true
            anyEncountered = true
        end
    end

    if anyEncountered then
        -- Favorites were set: collapse ALL regular headers for clean default view
        for i = GetNumFactions(), 1, -1 do
            local name, _, _, _, _, _, _, _, isHeader = GetFactionInfo(i)
            if isHeader then
                CollapseFactionHeader(i)
            end
        end

        charData.FavoriteFactions = charData.FavoriteFactions or {}
        for name in pairs(encountered) do
            charData.FavoriteFactions[name] = true
        end
    else
        -- Low-level player: no Outland factions, restore original state
        RestoreFactionHeaders(wasCollapsed)
    end

    isRefreshing = false

    charData.AutoFavOutlandDone = true
end

-- Ensure all headers start collapsed in DB when favorites exist (one-time default)
local function EnsureDefaultCollapse()
    local charKey = EnsureCharacterStorage()
    if not charKey then return end
    local charData = BCF.DB.Characters[charKey]
    if charData.DefaultRepCollapseV2 then return end

    charData.FavoriteFactions = charData.FavoriteFactions or {}
    local hasFavs = false
    for _ in pairs(charData.FavoriteFactions) do hasFavs = true; break end
    if not hasFavs then return end

    -- Expand all to discover header names, then mark collapsed in DB
    isRefreshing = true
    ExpandAllFactionHeaders()
    BCF.DB.Reputation.Collapsed = BCF.DB.Reputation.Collapsed or {}
    for i = 1, GetNumFactions() do
        local name, _, _, _, _, _, _, _, isHeader = GetFactionInfo(i)
        if isHeader then
            BCF.DB.Reputation.Collapsed[name] = true
        end
    end
    isRefreshing = false

    charData.DefaultRepCollapseV2 = true
end

-- ============================================================================
-- FACTION DISCOVERY (scan for new factions on reputation events)
-- ============================================================================
local discoveryFrame = CreateFrame("Frame")
discoveryFrame:RegisterEvent("UPDATE_FACTION")
discoveryFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
BCF.repEventFrame = discoveryFrame

local mainFrameCloseHooked = false
local function HookMainFrameClose()
    if mainFrameCloseHooked then return end
    if not BCF.MainFrame then return end
    BCF.MainFrame:HookScript("OnHide", function()
        if factionDetail:IsShown() then
            factionDetail:Hide()
        end
    end)
    mainFrameCloseHooked = true
end

discoveryFrame:SetScript("OnEvent", function(self, event)
    if isRefreshing then return end
    HookMainFrameClose()
    if event == "PLAYER_ENTERING_WORLD" then
        AutoFavoriteScryersAldor()
        AutoFavoriteOutlandFactions()
        EnsureDefaultCollapse()
    end
    if BCF.ReputationContent and BCF.ReputationContainer and BCF.ReputationContainer:IsShown() then
        BCF.RefreshReputation(BCF.ReputationContent)
    end
end)
