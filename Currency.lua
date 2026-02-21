local addonName, BCF = ...

-- ============================================================================
-- MODULE: Currency
-- ============================================================================

local T = BCF.Tokens
local CLASS_COLOR = {T.Accent[1], T.Accent[2], T.Accent[3]}

-- Known TBC currencies grouped by category
-- { name, itemID (nil for API-based), icon, currencyID (C_CurrencyInfo) }
local CURRENCY_GROUPS = {
    {
        header = "Points",
        items = {
            { name = "Honor Points",  currencyID = 1901,  factionIcon = true },
            { name = "Arena Points",  currencyID = 1900,  icon = 4006481 },
        },
    },
    {
        header = "Dungeon Tokens",
        items = {
            { name = "Badge of Justice",  itemID = 29434 },
        },
    },
    {
        header = "Battleground Marks",
        items = {
            { name = "Alterac Valley Mark of Honor",    itemID = 20560 },
            { name = "Arathi Basin Mark of Honor",      itemID = 20559 },
            { name = "Warsong Gulch Mark of Honor",     itemID = 20558 },
            { name = "Eye of the Storm Mark of Honor",  itemID = 29024 },
        },
    },
    {
        header = "World PvP",
        items = {
            { name = "Halaa Battle Token",    itemID = 26045 },
            { name = "Halaa Research Token",  itemID = 26044 },
            { name = "Spirit Shard",          itemID = 28558 },
        },
    },
    {
        header = "Raid & Misc",
        items = {
            { name = "Apexis Shard",    itemID = 32569 },
            { name = "Apexis Crystal",  itemID = 32572 },
            { name = "Nether Vortex",   itemID = 30183 },
        },
    },
}

-- Collapse state per header
local collapseState = {}
local isRefreshing = false

-- ============================================================================
-- ROW POOL
-- ============================================================================
local GetRow, ReleaseRow = BCF.CreateRowPool(
    function(row)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", T.RowTextIndent, 0)

        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)

        row.value = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        row.value:SetPoint("RIGHT", -8, 0)
        row.value:SetJustifyH("RIGHT")
    end,
    function(row)
        row.expandBtn:Hide()
        row.icon:SetTexture(nil)
        row.icon:Hide()
        row.value:SetText("")
    end
)

local function GetCurrencyCount(item)
    if item.currencyID then
        -- TBC Anniversary: C_CurrencyInfo is the primary API
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local info = C_CurrencyInfo.GetCurrencyInfo(item.currencyID)
            if info and info.quantity then return info.quantity end
        end
        -- Fallback: legacy TBC Classic functions
        if item.currencyID == 1901 and GetHonorCurrency then
            return GetHonorCurrency() or 0
        elseif item.currencyID == 1900 and GetArenaCurrency then
            return GetArenaCurrency() or 0
        end
        return 0
    elseif item.itemID then
        return GetItemCount(item.itemID, true) or 0
    end
    return 0
end

local function GetCurrencyIcon(item)
    if item.factionIcon then
        local faction = UnitFactionGroup("player")
        return (faction == "Horde") and 132485 or 132486
    end
    if item.icon then return item.icon end
    if item.itemID then
        local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(item.itemID)
        return tex
    end
    return nil
end

-- ============================================================================
-- REFRESH
-- ============================================================================
local activeRows = {}

function BCF.RefreshCurrency(content)
    if isRefreshing then return end
    if not content then return end

    local scrollFrame = content:GetParent()
    if scrollFrame then
        content:SetWidth(scrollFrame:GetWidth() - 5)
    end

    isRefreshing = true

    for _, row in ipairs(activeRows) do
        ReleaseRow(row)
    end
    wipe(activeRows)

    local yOffset = 0
    local totalItems = 0

    for _, group in ipairs(CURRENCY_GROUPS) do
        local headerName = group.header
        if collapseState[headerName] == nil then
            collapseState[headerName] = false
        end
        local isCollapsed = collapseState[headerName]

        -- Collect items with counts
        local visibleItems = {}
        for _, item in ipairs(group.items) do
            local count = GetCurrencyCount(item)
            local icon = GetCurrencyIcon(item)
            table.insert(visibleItems, {
                name = item.name,
                count = count,
                icon = icon,
                itemID = item.itemID,
            })
        end

        -- Header row
        local headerRow = GetRow(content)
        table.insert(activeRows, headerRow)
        totalItems = totalItems + 1

        headerRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        headerRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset)
        headerRow:SetBackdropColor(CLASS_COLOR[1]*0.15, CLASS_COLOR[2]*0.15, CLASS_COLOR[3]*0.15, 0.9)

        headerRow.expandBtn:Show()
        headerRow.expandBtn:SetText(isCollapsed and "+" or "-")
        headerRow.expandBtn:SetTextColor(CLASS_COLOR[1], CLASS_COLOR[2], CLASS_COLOR[3])

        headerRow.icon:Hide()
        headerRow.name:ClearAllPoints()
        headerRow.name:SetPoint("LEFT", T.RowTextIndent, 0)
        headerRow.name:SetText(headerName)
        headerRow.name:SetTextColor(CLASS_COLOR[1], CLASS_COLOR[2], CLASS_COLOR[3])
        headerRow.name:SetWidth(0)

        headerRow.value:SetText("")

        local hdr = headerName
        headerRow:SetScript("OnMouseUp", function()
            collapseState[hdr] = not collapseState[hdr]
            BCF.RefreshCurrency(content)
        end)
        headerRow:SetScript("OnEnter", function(self)
            self:SetBackdropColor(CLASS_COLOR[1]*0.25, CLASS_COLOR[2]*0.25, CLASS_COLOR[3]*0.25, 0.9)
        end)
        headerRow:SetScript("OnLeave", function(self)
            self:SetBackdropColor(CLASS_COLOR[1]*0.15, CLASS_COLOR[2]*0.15, CLASS_COLOR[3]*0.15, 0.9)
        end)

        yOffset = yOffset + T.RowHeight

        -- Item rows
        if not isCollapsed then
            for idx, item in ipairs(visibleItems) do
                local row = GetRow(content)
                table.insert(activeRows, row)
                totalItems = totalItems + 1

                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
                row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset)

                local alpha = (idx % 2 == 0) and 0.06 or 0.03
                local dimmed = (item.count == 0)
                row:SetBackdropColor(1, 1, 1, alpha)

                row.expandBtn:Hide()

                -- Icon
                if item.icon then
                    row.icon:Show()
                    row.icon:SetTexture(item.icon)
                    row.icon:SetDesaturated(dimmed)
                    row.name:ClearAllPoints()
                    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                else
                    row.icon:Hide()
                    row.name:ClearAllPoints()
                    row.name:SetPoint("LEFT", T.RowTextIndent, 0)
                end

                row.name:SetText(item.name)
                row.name:SetWidth(0)
                row.name:SetTextColor(dimmed and 0.4 or 0.9, dimmed and 0.4 or 0.9, dimmed and 0.4 or 0.9)

                row.value:SetText(tostring(item.count))
                row.value:SetTextColor(dimmed and 0.4 or 1, dimmed and 0.4 or 1, dimmed and 0.4 or 1)

                -- Tooltip
                local itemID = item.itemID
                row:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(1, 1, 1, 0.1)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if itemID then
                        GameTooltip:SetItemByID(itemID)
                    else
                        GameTooltip:SetText(item.name, 1, 1, 1)
                        GameTooltip:AddLine("Count: " .. item.count, 0.8, 0.8, 0.8)
                    end
                    GameTooltip:Show()
                end)
                local rowAlpha = alpha
                row:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(1, 1, 1, rowAlpha)
                    GameTooltip:Hide()
                end)

                yOffset = yOffset + T.RowHeight
            end
        end
    end

    content:SetHeight(yOffset)
    isRefreshing = false
end

-- ============================================================================
-- EVENT HANDLER
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
eventFrame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
eventFrame:SetScript("OnEvent", function()
    if BCF.CurrencyContent then
        BCF.RefreshCurrency(BCF.CurrencyContent)
    end
end)
