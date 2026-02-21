local addonName, BCF = ...

-- ============================================================================
-- MODULE: Wishlist
-- ============================================================================

local T = BCF.Tokens
local SLOT_INDENT = 18 -- sub-headers narrower by icon width each side

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PHASE_ORDER = { PR = 1, T4 = 2, T5 = 3, T6 = 4, ZA = 5, SWP = 6 }
local PHASE_LABELS = {
    PR = "Pre-Raid", T4 = "Phase 1", T5 = "Phase 2",
    T6 = "Phase 3", ZA = "Phase 4", SWP = "Phase 5",
}

local ENCHANT_SLOT_TO_IDS = {
    ["Head"]               = {1},
    ["Shoulder"]           = {3},
    ["Back"]               = {15},
    ["Chest"]              = {5},
    ["Wrist"]              = {9},
    ["Hands"]              = {10},
    ["Legs"]               = {7},
    ["Feet"]               = {8},
    ["Main Hand"]          = {16},
    ["Off Hand"]           = {17},
    ["Ring"]               = {11, 12},
    ["Ranged/Relic"]       = {18},
    ["Main Hand~Off Hand"] = {16, 17},
    ["Shoulder~Legs"]      = {3, 7},
}

-- ============================================================================
-- SLOT DEFINITIONS
-- ============================================================================

BCF.WISHLIST_SLOTS = {
    {id = 1,  label = "Head"},      {id = 2,  label = "Neck"},
    {id = 3,  label = "Shoulder"},   {id = 15, label = "Back"},
    {id = 5,  label = "Chest"},      {id = 9,  label = "Wrist"},
    {id = 10, label = "Hands"},      {id = 6,  label = "Waist"},
    {id = 7,  label = "Legs"},       {id = 8,  label = "Feet"},
    {id = 11, label = "Ring 1"},     {id = 12, label = "Ring 2"},
    {id = 13, label = "Trinket 1"},  {id = 14, label = "Trinket 2"},
    {id = 16, label = "Main Hand"},  {id = 17, label = "Off Hand"},
    {id = 18, label = "Ranged"},
    {id = 100, label = "Gems",     isCategory = true, categoryType = "gem"},
    {id = 101, label = "Enchants", isCategory = true, categoryType = "enchant"},
}

local EQUIPSLOT_TO_ID = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3,
    INVTYPE_CLOAK = 15, INVTYPE_CHEST = 5, INVTYPE_ROBE = 5,
    INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_WAIST = 6,
    INVTYPE_LEGS = 7, INVTYPE_FEET = 8,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13,
    INVTYPE_WEAPON = 16, INVTYPE_2HWEAPON = 16,
    INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17,
    INVTYPE_SHIELD = 17, INVTYPE_HOLDABLE = 17,
    INVTYPE_RANGED = 18, INVTYPE_RANGEDRIGHT = 18,
    INVTYPE_THROWN = 18, INVTYPE_RELIC = 18,
}

-- ============================================================================
-- DATA LAYER
-- ============================================================================

local function GetCharacterWishlists()
    local charKey = BCF.GetCharacterKey()
    BCF.DB.Characters = BCF.DB.Characters or {}
    BCF.DB.Characters[charKey] = BCF.DB.Characters[charKey] or {}
    BCF.DB.Characters[charKey].Wishlists = BCF.DB.Characters[charKey].Wishlists or {}
    return BCF.DB.Characters[charKey].Wishlists
end

local function GetWishlistSettings()
    local charKey = BCF.GetCharacterKey()
    BCF.DB.Characters = BCF.DB.Characters or {}
    BCF.DB.Characters[charKey] = BCF.DB.Characters[charKey] or {}
    BCF.DB.Characters[charKey].WishlistSettings = BCF.DB.Characters[charKey].WishlistSettings or {
        ActiveList = nil,
        HiddenLists = {},
        CollapsedSlots = {},
        CollapsedLists = {},
        ShowOverlays = true,
        ShowTooltips = true,
    }
    return BCF.DB.Characters[charKey].WishlistSettings
end

function BCF.CreateWishlist(name, spec, phase)
    local wishlists = GetCharacterWishlists()
    if wishlists[name] then return false end

    local maxSort = 0
    for _, data in pairs(wishlists) do
        if data.sortIndex and data.sortIndex > maxSort then
            maxSort = data.sortIndex
        end
    end

    wishlists[name] = {
        sortIndex = maxSort + 1,
        createdAt = time(),
        spec = spec,
        phase = phase,
        slots = {},
    }
    return true
end

function BCF.DeleteWishlist(name)
    local wishlists = GetCharacterWishlists()
    wishlists[name] = nil
    local settings = GetWishlistSettings()
    if settings.ActiveList == name then
        settings.ActiveList = nil
    end
end

function BCF.RenameWishlist(oldName, newName)
    if oldName == newName then return false end
    local wishlists = GetCharacterWishlists()
    if not wishlists[oldName] or wishlists[newName] then return false end

    wishlists[newName] = wishlists[oldName]
    wishlists[oldName] = nil

    local settings = GetWishlistSettings()
    if settings.CollapsedLists and settings.CollapsedLists[oldName] then
        settings.CollapsedLists[newName] = true
        settings.CollapsedLists[oldName] = nil
    end
    if settings.ActiveList == oldName then
        settings.ActiveList = newName
    end
    return true
end

function BCF.GetWishlists()
    local wishlists = GetCharacterWishlists()
    local sorted = {}
    for name, data in pairs(wishlists) do
        table.insert(sorted, {name = name, data = data})
    end
    table.sort(sorted, function(a, b)
        return (a.data.sortIndex or 0) < (b.data.sortIndex or 0)
    end)
    return sorted
end

function BCF.ReorderWishlists(fromIndex, toIndex)
    local wishlists = GetCharacterWishlists()
    local sorted = BCF.GetWishlists()

    if not sorted[fromIndex] then return false end
    if fromIndex == toIndex then return false end

    local moving = table.remove(sorted, fromIndex)
    if toIndex > #sorted + 1 then toIndex = #sorted + 1 end
    if toIndex < 1 then toIndex = 1 end
    table.insert(sorted, toIndex, moving)

    for i, entry in ipairs(sorted) do
        entry.data.sortIndex = i
        if wishlists[entry.name] then
            wishlists[entry.name].sortIndex = i
        end
    end
    return true
end

function BCF.SetWishlistIcon(listName, iconPath)
    local wishlists = GetCharacterWishlists()
    if wishlists[listName] then
        wishlists[listName].icon = iconPath
    end
end

function BCF.AddWishlistItem(listName, slotID, itemLink, source)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if not list then return false end

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if not itemID then return false end

    list.slots = list.slots or {}
    list.slots[slotID] = list.slots[slotID] or {}

    for _, entry in ipairs(list.slots[slotID]) do
        if entry.itemID == itemID then return false end
    end

    local isFirst = #list.slots[slotID] == 0
    table.insert(list.slots[slotID], {
        itemID = itemID,
        link = itemLink,
        source = source or "",
        selected = isFirst,
    })
    return true
end

function BCF.AddWishlistEnchant(listName, enchantName, enchantSlot, enchantPhase)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if not list then return false end

    list.slots = list.slots or {}
    list.slots[101] = list.slots[101] or {}

    for _, entry in ipairs(list.slots[101]) do
        if entry.enchantName == enchantName then return false end
    end

    local isFirst = #list.slots[101] == 0
    table.insert(list.slots[101], {
        itemID = 0,
        enchantName = enchantName,
        enchantSlot = enchantSlot,
        enchantPhase = enchantPhase,
        source = "",
        selected = isFirst,
    })
    return true
end

function BCF.RemoveWishlistItem(listName, slotID, itemIndex)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if not list or not list.slots or not list.slots[slotID] then return end

    local wasSelected = list.slots[slotID][itemIndex] and list.slots[slotID][itemIndex].selected
    table.remove(list.slots[slotID], itemIndex)

    if wasSelected and #list.slots[slotID] > 0 then
        list.slots[slotID][1].selected = true
    end
end

-- Paired slots: selecting an item in one slot avoids duplicating in its pair
local PAIRED_SLOTS = { [11] = 12, [12] = 11, [13] = 14, [14] = 13, [16] = 17, [17] = 16 }

function BCF.SelectWishlistItem(listName, slotID, itemIndex)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if not list or not list.slots or not list.slots[slotID] then return end

    -- Gems and enchants: toggle multi-select
    if slotID >= 100 then
        local entry = list.slots[slotID][itemIndex]
        if entry then entry.selected = not entry.selected end
        return
    end

    for i, entry in ipairs(list.slots[slotID]) do
        entry.selected = (i == itemIndex)
    end

    -- For paired slots (ring/trinket), avoid same item in both
    local pairedSlot = PAIRED_SLOTS[slotID]
    if pairedSlot and list.slots[pairedSlot] then
        local selectedID = list.slots[slotID][itemIndex] and list.slots[slotID][itemIndex].itemID
        if selectedID then
            local pairedItems = list.slots[pairedSlot]
            local currentPaired = nil
            for _, e in ipairs(pairedItems) do
                if e.selected then currentPaired = e break end
            end
            if currentPaired and currentPaired.itemID == selectedID then
                -- Paired slot has same item, bump to next different item
                for i, e in ipairs(pairedItems) do
                    if e.itemID ~= selectedID then
                        for j, pe in ipairs(pairedItems) do pe.selected = (j == i) end
                        break
                    end
                end
            end
        end
    end
end

function BCF.GetSelectedItems(listName)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if not list or not list.slots then return {} end

    local selected = {}
    for slotID, items in pairs(list.slots) do
        for _, entry in ipairs(items) do
            if entry.selected then
                selected[slotID] = entry
                break
            end
        end
    end

    -- 2H weapon in main hand clears off-hand
    if selected[16] and selected[16].link then
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(selected[16].link)
        if equipLoc == "INVTYPE_2HWEAPON" then
            selected[17] = nil
        end
    end

    return selected
end

function BCF.EquipSlotToSlotID(equipSlot)
    return EQUIPSLOT_TO_ID[equipSlot]
end

-- ============================================================================
-- MIGRATION
-- ============================================================================

function BCF.MigrateOldWishlist()
    local charKey = BCF.GetCharacterKey()
    if not BCF.DB.Characters or not BCF.DB.Characters[charKey] then return end

    local oldWishlist = BCF.DB.Characters[charKey].Wishlist
    if not oldWishlist or type(oldWishlist) ~= "table" or not next(oldWishlist) then return end

    if BCF.DB.Characters[charKey].Wishlists and next(BCF.DB.Characters[charKey].Wishlists) then
        BCF.DB.Characters[charKey].Wishlist = nil
        return
    end

    local wishlists = GetCharacterWishlists()
    local imported = { sortIndex = 1, createdAt = time(), slots = {} }

    local count = 0
    for slotID, link in pairs(oldWishlist) do
        if type(link) == "string" and link:match("item:(%d+)") then
            local itemID = tonumber(link:match("item:(%d+)"))
            imported.slots[slotID] = {
                {itemID = itemID, link = link, source = "", selected = true}
            }
            count = count + 1
        end
    end

    if count > 0 then
        wishlists["Imported"] = imported
        BCF.Print("|cff00ccff[BCF]|r Migrated " .. count .. " wishlist items to new multi-list format.")
    end

    BCF.DB.Characters[charKey].Wishlist = nil
end

-- ============================================================================
-- CONFIRMATION DIALOG (anchored to MainFrame right edge)
-- ============================================================================

local confirmDialog = CreateFrame("Frame", "BCFConfirmDialog", UIParent, "BackdropTemplate")
confirmDialog:SetSize(280, 120)
confirmDialog:SetFrameStrata("DIALOG")
confirmDialog:EnableMouse(true)
confirmDialog:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
})
confirmDialog:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
confirmDialog:Hide()

local confirmText = BCF.CleanFont(confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
confirmText:SetPoint("TOP", 0, -15)
confirmText:SetPoint("LEFT", 15, 0)
confirmText:SetPoint("RIGHT", -15, 0)
confirmText:SetJustifyH("CENTER")
confirmText:SetTextColor(1, 1, 1)

local confirmWarn = BCF.CleanFont(confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
confirmWarn:SetPoint("TOP", confirmText, "BOTTOM", 0, -6)
confirmWarn:SetText("This cannot be undone!")
confirmWarn:SetTextColor(0.9, 0.3, 0.3)

local confirmYes = CreateFrame("Button", nil, confirmDialog, "BackdropTemplate")
confirmYes:SetSize(80, 24)
confirmYes:SetPoint("BOTTOMLEFT", 30, 12)
confirmYes:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
confirmYes:SetBackdropColor(unpack(T.DestructiveBgHover))
confirmYes:SetBackdropBorderColor(T.DestructiveText[1], T.DestructiveText[2], T.DestructiveText[3], 1)
local confirmYesText = BCF.CleanFont(confirmYes:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
confirmYesText:SetPoint("CENTER", 0, 0)
confirmYesText:SetText("Delete")
confirmYesText:SetTextColor(1, 0.4, 0.4)
confirmYes:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.6, 0.2, 0.2, 1)
end)
confirmYes:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.5, 0.15, 0.15, 1)
end)

local confirmNo = CreateFrame("Button", nil, confirmDialog, "BackdropTemplate")
confirmNo:SetSize(80, 24)
confirmNo:SetPoint("BOTTOMRIGHT", -30, 12)
confirmNo:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
confirmNo:SetBackdropColor(0.15, 0.15, 0.18, 1)
confirmNo:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
local confirmNoText = BCF.CleanFont(confirmNo:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
confirmNoText:SetPoint("CENTER", 0, 0)
confirmNoText:SetText("Cancel")
confirmNoText:SetTextColor(0.8, 0.8, 0.8)
confirmNo:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.2, 0.2, 0.24, 1)
end)
confirmNo:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.15, 0.15, 0.18, 1)
end)
confirmNo:SetScript("OnClick", function() confirmDialog:Hide() end)

function BCF.ShowConfirmDialog(title, onConfirm)
    confirmText:SetText(title)
    confirmYes:SetScript("OnClick", function()
        confirmDialog:Hide()
        onConfirm()
    end)
    BCF.ShowRightOfMain(confirmDialog)
    confirmDialog:Show()
end

function BCF.ShowDeleteWishlistConfirm(listName)
    BCF.ShowConfirmDialog("Delete |cffffffff" .. listName .. "|r?", function()
        BCF.DeleteWishlist(listName)

        -- Find next available list or clear paperdoll
        local remaining = BCF.GetWishlists()
        if #remaining > 0 then
            BCF.SetActiveWishlist(remaining[1].name)
        else
            BCF.SetActiveWishlist(nil)
        end

        BCF.IsRefreshingWishlist = false
        if BCF.RefreshWishlist and BCF.SideStats then
            BCF.RefreshWishlist(BCF.SideStats)
        end
    end)
end

-- ============================================================================
-- SLOT CLEAR HELPER
-- ============================================================================

local function ClearSlotFrame(frame)
    frame.Icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    frame.Icon:SetVertexColor(0.4, 0.4, 0.4)
    frame.IconBorder:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
    frame.ILvlOverlay:SetText("")
    frame.ILvlOverlay:Hide()
    if frame.ItemName then frame.ItemName:SetText("") end
    if frame.EnchantText then frame.EnchantText:SetText("") end
    if frame.InfoFrame then frame.InfoFrame:Hide() end
    if frame.FlyoutBtn then frame.FlyoutBtn:Hide() end
    if frame.Cooldown then frame.Cooldown:Clear() end
    for i = 1, 3 do
        if frame.GemButtons and frame.GemButtons[i] then
            frame.GemButtons[i]:Hide()
        end
    end
end

-- ============================================================================
-- DRAG-AND-DROP REORDERING
-- ============================================================================

local function GetWishlistInsertionIndex(container, cursorY)
    if not container.sections or #container.sections == 0 then return 1, nil end

    local closestDist = 99999
    local closestGap = 1
    local closestHeaderFrame = nil
    local headerCount = 0
    local lastHeaderFrame = nil

    for _, section in ipairs(container.sections) do
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

local function AddWishlistDragLogic(header, container)
    header:RegisterForDrag("LeftButton")

    if not container.dropTargetLine then
        local line = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        line:SetHeight(4)
        line:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        line:SetBackdropColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.7)
        line:SetFrameStrata("TOOLTIP")
        line:SetFrameLevel(9999)
        line:Hide()
        container.dropTargetLine = line
    end

    header:SetScript("OnDragStart", function(self)
        if BCF.IsRefreshingWishlist then return end
        self.isDragging = true
        self:SetAlpha(0)

        if not self.ghost then
            local g = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            g:SetSize(self:GetWidth(), self:GetHeight())
            g:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            g:SetBackdropColor(unpack(T.Accent))
            g:SetAlpha(0.6)
            g:SetFrameStrata("TOOLTIP")
            local t = g:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            t:SetPoint("CENTER")
            t:SetText(self.listName or "List")
            self.ghost = g
        end
        self.ghost:Show()
        container.dropTargetLine:Show()
        container.dropTargetLine:SetFrameStrata("TOOLTIP")

        self.ghost:SetScript("OnUpdate", function(g)
            local x, y = GetCursorPosition()
            local s = container:GetEffectiveScale()
            local cY = y / s
            local uis = UIParent:GetEffectiveScale()
            g:ClearAllPoints()
            g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / uis, y / uis)

            local gapIdx, closestFrame, lastFrame, totalHeaders = GetWishlistInsertionIndex(container, cY)
            container.lastGapIdx = gapIdx

            if closestFrame then
                container.dropTargetLine:ClearAllPoints()
                local targetFrame = nil
                if gapIdx <= totalHeaders then
                    local count = 0
                    for _, sec in ipairs(container.sections) do
                        if sec.isHeader and not sec.isDragging then
                            count = count + 1
                            if count == gapIdx then
                                targetFrame = sec
                                break
                            end
                        end
                    end
                end

                if targetFrame then
                    container.dropTargetLine:SetPoint("BOTTOMLEFT", targetFrame, "TOPLEFT", 0, 0)
                    container.dropTargetLine:SetPoint("BOTTOMRIGHT", targetFrame, "TOPRIGHT", -5, 0)
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
        if BCF.LastWishlistReorderTime and (GetTime() - BCF.LastWishlistReorderTime) < 0.5 then
            self.isDragging = false
            self:SetAlpha(1)
            if self.ghost then self.ghost:Hide(); self.ghost:SetScript("OnUpdate", nil) end
            container.dropTargetLine:Hide()
            return
        end

        self.isDragging = false
        self:SetAlpha(1)
        if self.ghost then self.ghost:Hide(); self.ghost:SetScript("OnUpdate", nil) end
        container.dropTargetLine:Hide()

        local gapIdx = container.lastGapIdx
        if gapIdx then
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

            if currentIdx > 0 and gapIdx ~= currentIdx then
                BCF.LastWishlistReorderTime = GetTime()
                if BCF.ReorderWishlists(currentIdx, gapIdx) then
                    BCF.IsRefreshingWishlist = false
                    BCF.RefreshWishlist(container)
                end
            end
        end
    end)
end

-- ============================================================================
-- WISHLIST RENDERER (mirrors RefreshSets exactly)
-- ============================================================================

function BCF.RefreshWishlist(targetContainer)
    if BCF.IsRefreshingWishlist then return end
    BCF.IsRefreshingWishlist = true

    local status, err = xpcall(function()
        -- Redirect to Content child for scrolling
        if BCF.SideStats and targetContainer == BCF.SideStats and BCF.SideStats.Content then
            targetContainer = BCF.SideStats.Content
        end

        local container = targetContainer
        if not container then return end

        -- Hide "Coming Soon" if it exists
        if BCF.SideStats and BCF.SideStats.ComingSoon then
            BCF.SideStats.ComingSoon:Hide()
        end

        if BCF.ClearContainer then
            BCF.ClearContainer(container)
        end

        local settings = GetWishlistSettings()
        settings.CollapsedLists = settings.CollapsedLists or {}
        settings.CollapsedSlots = settings.CollapsedSlots or {}

        local lists = BCF.GetWishlists()
        if not lists then lists = {} end
        local yOffset = 0

        -- Check if we're loading a list that doesn't exist yet (BiS import in progress)
        local loadingNewList = false
        if BCF.WishlistLoadingInfo and BCF.WishlistLoadingInfo.listName then
            local found = false
            for _, entry in ipairs(lists) do
                if entry.name == BCF.WishlistLoadingInfo.listName then found = true; break end
            end
            if not found then loadingNewList = true end
        end

        -- Show placeholder header for not-yet-created list during BiS import
        if loadingNewList then
            local info = BCF.WishlistLoadingInfo

            local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
            header:SetHeight(T.HeaderRowHeight)
            header:SetPoint("TOPLEFT", 5, yOffset)
            header:SetPoint("RIGHT", -5, 0)
            header:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            header:SetBackdropColor(0.12, 0.12, 0.15, 0.9)
            table.insert(container.sections, header)

            -- Smooth animated progress fill
            local fill = header:CreateTexture(nil, "BORDER")
            fill:SetPoint("TOPLEFT", 0, 0)
            fill:SetPoint("BOTTOMLEFT", 0, 0)
            fill:SetWidth(1)
            fill:SetColorTexture(T.Accent[1]*0.25, T.Accent[2]*0.25, T.Accent[3]*0.25, 0.95)

            local label = BCF.CleanFont(header:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            label:SetPoint("LEFT", 8, 0)
            label:SetText(info.name)
            label:SetTextColor(0.6, 0.6, 0.6, 0.8)

            local currentPct = 0
            header:SetScript("OnUpdate", function(self, elapsed)
                local w = self:GetWidth()
                if w <= 0 then return end
                local li = BCF.WishlistLoadingInfo
                if not li then
                    self:SetScript("OnUpdate", nil)
                    return
                end
                local targetPct = li.done and 1.0
                    or ((li.total > 0) and (li.resolved / li.total) or 0)
                -- Faster lerp when finishing up
                local speed = li.done and 5.0 or 3.0
                currentPct = currentPct + (targetPct - currentPct) * math.min(1, elapsed * speed)
                fill:SetWidth(math.max(1, w * currentPct))
                local pctText = (li.total > 0 or li.done) and string.format("  %d%%", math.floor(currentPct * 100)) or ""
                label:SetText(li.name .. pctText)
                if li.done and currentPct >= 0.98 then
                    self:SetScript("OnUpdate", nil)
                    if li.onDone then li.onDone() end
                end
            end)

            yOffset = yOffset - 28
        end

        for i, entry in ipairs(lists) do
            local listName = entry.name
            local listData = entry.data
            if not listData then break end

            local collapseKey = listName
            local isCollapsed = settings.CollapsedLists[collapseKey]

            -- ==============================================================
            -- WISHLIST HEADER (same as gear set header)
            -- ==============================================================
            local isActive = settings.ActiveList == listName

            -- Check if this list is currently loading
            local isLoadingThis = BCF.WishlistLoadingInfo
                and BCF.WishlistLoadingInfo.listName == listName

            local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
            header:SetHeight(T.HeaderRowHeight)
            header:SetPoint("TOPLEFT", 5, yOffset)
            header:SetPoint("RIGHT", -5, 0)
            header:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            if isLoadingThis then
                -- Grey base, class-color fill overlays as progress
                header:SetBackdropColor(0.12, 0.12, 0.15, 0.9)
            elseif isActive then
                header:SetBackdropColor(T.Accent[1]*0.25, T.Accent[2]*0.25, T.Accent[3]*0.25, 0.95)
            else
                header:SetBackdropColor(T.Accent[1]*0.12, T.Accent[2]*0.12, T.Accent[3]*0.12, 0.9)
            end
            table.insert(container.sections, header)
            header.isHeader = true
            header.listName = listName

            -- Smooth animated progress fill overlay on the actual header
            if isLoadingThis then
                local fill = header:CreateTexture(nil, "BORDER")
                fill:SetPoint("TOPLEFT", 0, 0)
                fill:SetPoint("BOTTOMLEFT", 0, 0)
                fill:SetWidth(1)
                fill:SetColorTexture(T.Accent[1]*0.25, T.Accent[2]*0.25, T.Accent[3]*0.25, 0.95)

                local currentPct = 0
                header:SetScript("OnUpdate", function(self, elapsed)
                    local w = self:GetWidth()
                    if w <= 0 then return end
                    local li = BCF.WishlistLoadingInfo
                    if not li then
                        self:SetScript("OnUpdate", nil)
                        return
                    end
                    local targetPct
                    if li.done then
                        targetPct = 1.0
                    elseif li.estimated then
                        -- Time-based estimation for dressing phase
                        local t = GetTime() - li.startTime
                        targetPct = (1 - 1 / (1 + t * 0.06)) * 0.92
                    else
                        -- Real resolved/total for import phase
                        targetPct = (li.total > 0) and (li.resolved / li.total) or 0
                    end
                    local speed = li.done and 5.0 or 3.0
                    currentPct = currentPct + (targetPct - currentPct) * math.min(1, elapsed * speed)
                    fill:SetWidth(math.max(1, w * currentPct))
                    if li.done and currentPct >= 0.98 then
                        self:SetScript("OnUpdate", nil)
                        if li.onDone then li.onDone() end
                    end
                end)
            end

            -- Add Drag Logic
            AddWishlistDragLogic(header, container)

            -- Active indicator (left accent bar)
            if isActive and not isLoadingThis then
                local activeBar = header:CreateTexture(nil, "OVERLAY")
                activeBar:SetSize(3, 20)
                activeBar:SetPoint("LEFT", 1, 0)
                activeBar:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.9)
            end

            -- Activate Button (checkmark, rightmost)
            local activateBtn = CreateFrame("Button", nil, header)
            activateBtn:SetSize(18, 18)
            activateBtn:SetPoint("RIGHT", -4, 0)
            local activateTex = activateBtn:CreateTexture(nil, "ARTWORK")
            activateTex:SetAllPoints()
            activateTex:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            if isActive then
                activateTex:SetDesaturated(false)
                activateTex:SetVertexColor(0.2, 1, 0.2)
            else
                activateTex:SetDesaturated(true)
            end

            -- Delete Button (next to checkmark)
            local delBtn = CreateFrame("Button", nil, header)
            delBtn:SetSize(18, 18)
            delBtn:SetPoint("RIGHT", activateBtn, "LEFT", -2, 0)
            local delTex = delBtn:CreateTexture(nil, "ARTWORK")
            delTex:SetAllPoints()
            delTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            delTex:SetDesaturated(true)

            local capturedListNameForDel = listName
            delBtn:SetScript("OnClick", function()
                BCF.ShowDeleteWishlistConfirm(capturedListNameForDel)
            end)
            delBtn:SetScript("OnEnter", function()
                delTex:SetDesaturated(false)
                GameTooltip:SetOwner(delBtn, "ANCHOR_RIGHT")
                GameTooltip:SetText("Delete Wishlist", 1, 0, 0)
                GameTooltip:Show()
            end)
            delBtn:SetScript("OnLeave", function()
                delTex:SetDesaturated(true)
                GameTooltip:Hide()
            end)

            -- Arrow (next to delete)
            local arrow = header:CreateTexture(nil, "ARTWORK")
            arrow:SetSize(12, 12)
            arrow:SetPoint("RIGHT", delBtn, "LEFT", -2, 0)
            arrow:SetTexture(isCollapsed and "Interface\\Buttons\\UI-microbutton-Lbutton-Up" or "Interface\\Buttons\\UI-microbutton-Dbutton-Up")
            arrow:SetAlpha(0.7)

            -- Icon Button (left) - same as gear set headers
            local iconBtn = CreateFrame("Button", nil, header)
            iconBtn:SetSize(18, 18)
            iconBtn:SetPoint("LEFT", 4, 0)
            local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints()
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local iconPath = listData.icon
            if not iconPath or iconPath == "" or iconPath == 0 then
                iconPath = "Interface\\Icons\\INV_Misc_Note_01"
            end
            iconTex:SetTexture(iconPath)

            local capturedListName = listName
            iconBtn:SetScript("OnClick", function()
                if BCF.ShowIconPicker then
                    BCF.ShowIconPicker(capturedListName, iconTex, function(texturePath)
                        local wishlists = GetCharacterWishlists()
                        if wishlists[capturedListName] then
                            wishlists[capturedListName].icon = texturePath
                        end
                    end)
                end
            end)
            iconBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Click to change icon", 1, 1, 1)
                GameTooltip:Show()
            end)
            iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- Header click: toggle collapse
            header:EnableMouse(true)
            header:SetScript("OnMouseUp", function(self, button)
                if not self.isDragging and (button == "LeftButton" or button == "RightButton") then
                    settings.CollapsedLists[collapseKey] = not settings.CollapsedLists[collapseKey]
                    BCF.IsRefreshingWishlist = false
                    BCF.RefreshWishlist(targetContainer)
                end
            end)

            -- Activate button click: set as active list (skip if already loading this list)
            activateBtn:SetScript("OnClick", function()
                if BCF.WishlistLoadingInfo and BCF.WishlistLoadingInfo.listName == capturedListName then return end
                BCF.SetActiveWishlist(capturedListName)
            end)
            activateBtn:SetScript("OnEnter", function()
                activateTex:SetDesaturated(false)
                activateTex:SetVertexColor(0.2, 1, 0.2)
                GameTooltip:SetOwner(activateBtn, "ANCHOR_RIGHT")
                GameTooltip:SetText("Preview on Paperdoll", 0.2, 1, 0.2)
                GameTooltip:Show()
            end)
            activateBtn:SetScript("OnLeave", function()
                if not isActive then
                    activateTex:SetDesaturated(true)
                    activateTex:SetVertexColor(1, 1, 1)
                end
                GameTooltip:Hide()
            end)

            -- Name EditBox (anchored right of icon)
            local nameEdit = CreateFrame("EditBox", nil, header, "BackdropTemplate")
            nameEdit:SetPoint("LEFT", iconBtn, "RIGHT", 4, 0)
            nameEdit:SetWidth(100)
            nameEdit:SetHeight(18)
            nameEdit:SetFontObject("GameFontHighlight")
            nameEdit:SetAutoFocus(false)
            nameEdit:SetText(listName)
            nameEdit:SetCursorPosition(0)
            nameEdit:SetJustifyH("LEFT")
            nameEdit:SetTextColor(unpack(T.Accent))
            BCF.CleanFont(nameEdit)

            nameEdit:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
            nameEdit:SetBackdropColor(0,0,0,0)
            nameEdit:SetBackdropBorderColor(0,0,0,0)

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
                if newName and newName ~= "" and newName ~= listName then
                    BCF.RenameWishlist(listName, newName)
                    BCF.IsRefreshingWishlist = false
                    if BCF.RefreshWishlist then BCF.RefreshWishlist(targetContainer) end
                else
                    self:SetText(listName)
                end
                self:SetCursorPosition(0)
                self:SetBackdropColor(0,0,0,0)
                self:SetBackdropBorderColor(0,0,0,0)
                isRenaming = false
            end

            nameEdit:SetScript("OnEnterPressed", SaveRename)
            nameEdit:SetScript("OnEditFocusLost", SaveRename)

            yOffset = yOffset - 26

            -- ==============================================================
            -- SLOT SUB-HEADERS + ITEM ROWS (only if expanded)
            -- ==============================================================
            if not isCollapsed then
                listData.slots = listData.slots or {}
                local separatorAdded = false
                for _, slotDef in ipairs(BCF.WISHLIST_SLOTS) do
                    local slotID = slotDef.id
                    local slotItems = listData.slots[slotID] or {}
                    local slotCollapseKey = listName .. ":" .. slotID
                    local slotCollapsed = settings.CollapsedSlots[slotCollapseKey]

                    -- Separator before first category (Gems/Enchants)
                    if slotDef.isCategory and not separatorAdded then
                        local sep = container:CreateTexture(nil, "ARTWORK")
                        sep:SetHeight(1)
                        sep:SetPoint("TOPLEFT", 5 + SLOT_INDENT, yOffset + 2)
                        sep:SetPoint("RIGHT", -5 - SLOT_INDENT, 0)
                        sep:SetColorTexture(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 0.5)
                        table.insert(container.sections, sep)
                        yOffset = yOffset - 6
                        separatorAdded = true
                    end

                    -- Slot sub-header (grey, narrower)
                    local slotHeader = CreateFrame("Frame", nil, container, "BackdropTemplate")
                    slotHeader:SetHeight(20)
                    slotHeader:SetPoint("TOPLEFT", 5 + SLOT_INDENT, yOffset)
                    slotHeader:SetPoint("RIGHT", -5 - SLOT_INDENT, 0)
                    slotHeader:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
                    slotHeader:SetBackdropColor(0.12, 0.12, 0.15, 0.7)
                    table.insert(container.sections, slotHeader)

                    -- Arrow (only if slot has items)
                    if #slotItems > 0 then
                        local slotArrow = slotHeader:CreateTexture(nil, "ARTWORK")
                        slotArrow:SetSize(10, 10)
                        slotArrow:SetPoint("RIGHT", -6, 0)
                        slotArrow:SetTexture(slotCollapsed and "Interface\\Buttons\\UI-microbutton-Lbutton-Up" or "Interface\\Buttons\\UI-microbutton-Dbutton-Up")
                        slotArrow:SetAlpha(0.5)
                    end

                    -- Slot name (colored for categories)
                    local slotText = BCF.CleanFont(slotHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
                    slotText:SetPoint("LEFT", 8, 0)
                    slotText:SetText(slotDef.label)
                    if slotDef.categoryType == "gem" then
                        slotText:SetTextColor(0.7, 0.5, 0.9)
                    elseif slotDef.categoryType == "enchant" then
                        slotText:SetTextColor(0.3, 0.8, 0.3)
                    else
                        slotText:SetTextColor(0.6, 0.6, 0.65)
                    end

                    -- Item count (only if has items)
                    if #slotItems > 0 then
                        local countText = BCF.CleanFont(slotHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
                        countText:SetPoint("RIGHT", -22, 0)
                        countText:SetText(#slotItems)
                        countText:SetTextColor(0.45, 0.45, 0.5)
                    end

                    -- Toggle slot collapse
                    slotHeader:EnableMouse(true)
                    slotHeader:SetScript("OnMouseUp", function(_, button)
                        if button == "LeftButton" then
                            settings.CollapsedSlots[slotCollapseKey] = not settings.CollapsedSlots[slotCollapseKey]
                            BCF.IsRefreshingWishlist = false
                            BCF.RefreshWishlist(targetContainer)
                        end
                    end)

                    -- Drag-to-add on slot header (gear slots only)
                    if not slotDef.isCategory then
                        slotHeader:SetScript("OnReceiveDrag", function()
                            local infoType, info1 = GetCursorInfo()
                            if infoType == "item" then
                                local link = select(2, GetItemInfo(info1))
                                if link then
                                    BCF.AddWishlistItem(listName, slotID, link, "")
                                end
                            end
                            ClearCursor()
                            BCF.IsRefreshingWishlist = false
                            BCF.RefreshWishlist(targetContainer)
                        end)
                    end

                    yOffset = yOffset - T.RowHeight

                    -- Item rows (only if not collapsed and has items)
                    if not slotCollapsed and #slotItems > 0 then
                        for itemIdx, itemEntry in ipairs(slotItems) do
                            local row = CreateFrame("Frame", nil, container, "BackdropTemplate")
                            row:SetHeight(18)
                            row:SetPoint("TOPLEFT", 10 + SLOT_INDENT, yOffset)
                            row:SetPoint("RIGHT", -10, 0)
                            row:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
                            table.insert(container.sections, row)

                            local qr, qg, qb = 1, 1, 1
                            local tex
                            local isEnchant = slotDef.categoryType == "enchant"

                            if isEnchant then
                                -- Enchant entries: green color, generic icon
                                qr, qg, qb = 0.2, 1, 0.2
                                tex = "Interface\\Icons\\Trade_Engraving"
                            else
                                -- Gear/gem entries: quality color from item link
                                local _, _, quality, _, _, _, _, _, _, itemTex = GetItemInfo(itemEntry.link)
                                tex = itemTex
                                if quality then
                                    qr, qg, qb = GetItemQualityColor(quality)
                                end
                            end

                            -- Quality-color backdrop for selected items
                            if itemEntry.selected then
                                row:SetBackdropColor(qr, qg, qb, 0.18)
                            else
                                row:SetBackdropColor(0, 0, 0, 0)
                            end

                            -- Icon
                            local iconBtn = CreateFrame("Button", nil, row)
                            iconBtn:SetSize(16, 16)
                            iconBtn:SetPoint("LEFT", 0, 0)
                            local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
                            iconTex:SetAllPoints()
                            iconTex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
                            iconTex:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")

                            if isEnchant then
                                -- Enchant tooltip: name + slot + phase
                                local enchName = itemEntry.enchantName or "Unknown"
                                local enchSlot = (itemEntry.enchantSlot or ""):gsub("~", "/")
                                local enchPhase = PHASE_LABELS[itemEntry.enchantPhase] or itemEntry.enchantPhase or ""
                                iconBtn:SetScript("OnEnter", function(self)
                                    row:SetBackdropColor(qr, qg, qb, 0.28)
                                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                    GameTooltip:AddLine(enchName, 0.2, 1, 0.2)
                                    GameTooltip:AddLine("Slot: " .. enchSlot, 0.7, 0.7, 0.7)
                                    if enchPhase ~= "" then
                                        GameTooltip:AddLine("Phase: " .. enchPhase, 0.5, 0.5, 0.5)
                                    end
                                    GameTooltip:Show()
                                end)
                            else
                                -- Gear/gem tooltip: item hyperlink
                                iconBtn:SetScript("OnEnter", function(self)
                                    row:SetBackdropColor(qr, qg, qb, 0.28)
                                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                    GameTooltip:SetHyperlink(itemEntry.link)
                                    GameTooltip:Show()
                                end)
                            end
                            iconBtn:SetScript("OnLeave", function()
                                local ra = itemEntry.selected and 0.18 or 0
                                row:SetBackdropColor(qr, qg, qb, ra)
                                GameTooltip:Hide()
                            end)

                            -- Text: enchant name or item link
                            local txt = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
                            txt:SetPoint("LEFT", iconBtn, "RIGHT", 6, 0)
                            txt:SetPoint("RIGHT", -32, 0)
                            if isEnchant then
                                txt:SetText(itemEntry.enchantName or "Unknown")
                                txt:SetTextColor(0.2, 1, 0.2)
                            else
                                txt:SetText(itemEntry.link)
                            end
                            txt:SetJustifyH("LEFT")

                            -- Delete button (left of star)
                            local delBtn = CreateFrame("Button", nil, row)
                            delBtn:SetSize(10, 10)
                            delBtn:SetPoint("RIGHT", -16, 0)
                            local delTex = delBtn:CreateTexture(nil, "ARTWORK")
                            delTex:SetAllPoints()
                            delTex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                            delTex:SetDesaturated(true)
                            delTex:SetVertexColor(0.4, 0.4, 0.4)
                            delBtn:SetScript("OnEnter", function()
                                delTex:SetDesaturated(false)
                                delTex:SetVertexColor(1, 0.3, 0.3)
                                row:SetBackdropColor(qr, qg, qb, 0.28)
                            end)
                            delBtn:SetScript("OnLeave", function()
                                delTex:SetDesaturated(true)
                                delTex:SetVertexColor(0.4, 0.4, 0.4)
                                local ra = itemEntry.selected and 0.18 or 0
                                row:SetBackdropColor(qr, qg, qb, ra)
                            end)

                            -- Star button (selected indicator)
                            local starBtn = CreateFrame("Button", nil, row)
                            starBtn:SetSize(14, 14)
                            starBtn:SetPoint("RIGHT", 0, 0)
                            local starTex = starBtn:CreateTexture(nil, "ARTWORK")
                            starTex:SetAllPoints()
                            starTex:SetTexture("Interface\\COMMON\\FavoritesIcon")

                            if itemEntry.selected then
                                starTex:SetDesaturated(false)
                                starTex:SetVertexColor(1, 0.82, 0)
                            else
                                starTex:SetDesaturated(true)
                                starTex:SetVertexColor(0.35, 0.35, 0.35)
                            end

                            -- Capture upvalues for callbacks
                            local capturedIdx = itemIdx
                            local capturedSlotID = slotID
                            local capturedListName = listName
                            local isSelected = itemEntry.selected
                            local restoreAlpha = isSelected and 0.18 or 0

                            local function SelectAndRefresh()
                                BCF.SelectWishlistItem(capturedListName, capturedSlotID, capturedIdx)
                                -- Update paperdoll to reflect new selection
                                local activeSettings = GetWishlistSettings()
                                if activeSettings.ActiveList == capturedListName then
                                    BCF.PreviewWishlist(capturedListName)
                                end
                                BCF.IsRefreshingWishlist = false
                                BCF.RefreshWishlist(targetContainer)
                            end

                            -- Hover: quality-color backdrop (no tooltip on row)
                            row:EnableMouse(true)
                            row:SetScript("OnEnter", function(self)
                                self:SetBackdropColor(qr, qg, qb, 0.28)
                            end)
                            row:SetScript("OnLeave", function(self)
                                self:SetBackdropColor(qr, qg, qb, restoreAlpha)
                            end)

                            -- Left-click: select. Shift+Left: link in chat. Right-click: remove.
                            row:SetScript("OnMouseUp", function(_, button)
                                if button == "LeftButton" then
                                    if IsShiftKeyDown() and itemEntry.link then
                                        HandleModifiedItemClick(itemEntry.link)
                                        return
                                    end
                                    SelectAndRefresh()
                                end
                            end)

                            -- Propagate clicks from icon/star to row
                            iconBtn:SetScript("OnClick", SelectAndRefresh)
                            starBtn:SetScript("OnClick", SelectAndRefresh)

                            -- Wire delete button (uses captured upvalues)
                            delBtn:SetScript("OnClick", function()
                                BCF.RemoveWishlistItem(capturedListName, capturedSlotID, capturedIdx)
                                local activeSettings = GetWishlistSettings()
                                if activeSettings.ActiveList == capturedListName then
                                    BCF.PreviewWishlist(capturedListName)
                                end
                                BCF.IsRefreshingWishlist = false
                                BCF.RefreshWishlist(targetContainer)
                            end)

                            yOffset = yOffset - 18
                        end
                    end
                end
            end

            yOffset = yOffset - T.SectionGap
        end

        -- ==============================================================
        -- FOOTER: "New List" button with inline BiS picker
        -- ==============================================================
        local footerBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
        footerBtn:SetHeight(28)
        footerBtn:SetPoint("TOPLEFT", 5, yOffset)
        footerBtn:SetPoint("RIGHT", -5, 0)
        footerBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        footerBtn:SetBackdropColor(T.Accent[1]*0.05, T.Accent[2]*0.05, T.Accent[3]*0.05, 0.5)
        table.insert(container.sections, footerBtn)

        local plusIcon = footerBtn:CreateTexture(nil, "ARTWORK")
        plusIcon:SetSize(16, 16)
        plusIcon:SetPoint("LEFT", 8, 0)
        plusIcon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
        plusIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        plusIcon:SetAlpha(0.7)

        local footerText = footerBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        footerText:SetPoint("LEFT", plusIcon, "RIGHT", 8, 0)
        footerText:SetText(BCF.WishlistPickerOpen and "Cancel" or "New List")
        footerText:SetTextColor(T.Accent[1]*0.8, T.Accent[2]*0.8, T.Accent[3]*0.8, 1)
        BCF.CleanFont(footerText)

        footerBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T.Accent[1]*0.15, T.Accent[2]*0.15, T.Accent[3]*0.15, 0.8)
            footerText:SetTextColor(unpack(T.Accent))
            plusIcon:SetAlpha(1.0)
        end)
        footerBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T.Accent[1]*0.05, T.Accent[2]*0.05, T.Accent[3]*0.05, 0.5)
            footerText:SetTextColor(T.Accent[1]*0.8, T.Accent[2]*0.8, T.Accent[3]*0.8, 1)
            plusIcon:SetAlpha(0.7)
        end)

        footerBtn:SetScript("OnClick", function()
            BCF.WishlistPickerOpen = not BCF.WishlistPickerOpen
            BCF.IsRefreshingWishlist = false
            BCF.RefreshWishlist(targetContainer)
        end)

        yOffset = yOffset - 30

        -- Inline BiS picker
        if BCF.WishlistPickerOpen then
            -- "Empty Wishlist" option
            local emptyBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
            emptyBtn:SetHeight(T.RowHeight)
            emptyBtn:SetPoint("TOPLEFT", 5 + SLOT_INDENT, yOffset)
            emptyBtn:SetPoint("RIGHT", -5 - SLOT_INDENT, 0)
            emptyBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            emptyBtn:SetBackdropColor(0.06, 0.06, 0.10, 0.6)
            table.insert(container.sections, emptyBtn)

            local emptyText = BCF.CleanFont(emptyBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
            emptyText:SetPoint("CENTER", 0, 0)
            emptyText:SetText("Empty Wishlist")
            emptyText:SetTextColor(T.TextSecondary[1], T.TextSecondary[2], T.TextSecondary[3])

            emptyBtn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(T.Accent[1]*0.12, T.Accent[2]*0.12, T.Accent[3]*0.12, 0.8)
                emptyText:SetTextColor(unpack(T.Accent))
            end)
            emptyBtn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.06, 0.06, 0.10, 0.6)
                emptyText:SetTextColor(T.TextSecondary[1], T.TextSecondary[2], T.TextSecondary[3])
            end)
            emptyBtn:SetScript("OnClick", function()
                local counter = 1
                local newName = "New Wishlist " .. counter
                local existingNames = {}
                for _, e in ipairs(lists) do existingNames[e.name] = true end
                while existingNames[newName] do
                    counter = counter + 1
                    newName = "New Wishlist " .. counter
                end
                BCF.CreateWishlist(newName)
                BCF.WishlistPickerOpen = false
                BCF.IsRefreshingWishlist = false
                BCF.RefreshWishlist(targetContainer)
            end)
            yOffset = yOffset - T.HeaderRowHeight

            -- BiS imports grouped by spec
            local imports = BCF.GetAvailableBiSImports()
            if #imports > 0 then
                local specGroups = {}
                local specOrder = {}
                for _, entry in ipairs(imports) do
                    if not specGroups[entry.spec] then
                        specGroups[entry.spec] = {}
                        table.insert(specOrder, entry.spec)
                    end
                    table.insert(specGroups[entry.spec], entry)
                end

                for _, specName in ipairs(specOrder) do
                    -- Spec sub-header
                    local specHeader = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    specHeader:SetPoint("TOPLEFT", 5 + SLOT_INDENT, yOffset - 2)
                    specHeader:SetText(specName)
                    specHeader:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3])
                    BCF.CleanFont(specHeader)
                    table.insert(container.sections, specHeader)
                    yOffset = yOffset - 16

                    -- Phase buttons
                    local phases = specGroups[specName]
                    table.sort(phases, function(a, b)
                        return (PHASE_ORDER[a.phase] or 0) < (PHASE_ORDER[b.phase] or 0)
                    end)

                    for _, phaseEntry in ipairs(phases) do
                        local phaseBtn = CreateFrame("Button", nil, container, "BackdropTemplate")
                        phaseBtn:SetHeight(20)
                        phaseBtn:SetPoint("TOPLEFT", 5 + SLOT_INDENT * 2, yOffset)
                        phaseBtn:SetPoint("RIGHT", -5 - SLOT_INDENT, 0)
                        phaseBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
                        phaseBtn:SetBackdropColor(0.06, 0.06, 0.10, 0.4)
                        table.insert(container.sections, phaseBtn)

                        local phaseLabel = PHASE_LABELS[phaseEntry.phase] or phaseEntry.phase
                        local pText = BCF.CleanFont(phaseBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
                        pText:SetPoint("LEFT", 6, 0)
                        pText:SetText(phaseLabel .. "  |cff888888(" .. phaseEntry.count .. " items)|r")
                        pText:SetTextColor(0.6, 0.8, 1.0)

                        phaseBtn:SetScript("OnEnter", function(self)
                            self:SetBackdropColor(T.Accent[1]*0.15, T.Accent[2]*0.15, T.Accent[3]*0.15, 0.8)
                            pText:SetTextColor(1, 1, 1)
                        end)
                        phaseBtn:SetScript("OnLeave", function(self)
                            self:SetBackdropColor(0.06, 0.06, 0.10, 0.4)
                            pText:SetTextColor(0.6, 0.8, 1.0)
                        end)

                        local capPhase, capSpec = phaseEntry.phase, phaseEntry.spec
                        local capPhaseLabel = PHASE_LABELS[phaseEntry.phase] or phaseEntry.phase
                        phaseBtn:SetScript("OnClick", function()
                            BCF.WishlistPickerOpen = false
                            BCF.WishlistLoading = true
                            -- Set loading info for progress bar
                            BCF.WishlistLoadingInfo = {
                                name = capSpec .. " " .. capPhaseLabel,
                                listName = capSpec .. " " .. capPhaseLabel,
                                resolved = 0,
                                total = 0,
                            }
                            -- Close picker and show loading bar immediately
                            BCF.IsRefreshingWishlist = false
                            BCF.RefreshWishlist(targetContainer)
                            -- Undress model, show paperdoll loading bar
                            if BCF.ModelFrame then BCF.ModelFrame:Undress() end
                            if BCF.ShowPaperdollLoadingBar then
                                BCF.ShowPaperdollLoadingBar()
                            end
                            -- Preload all items, then import, show slots immediately, load model
                            BCF.PreloadBiSAndImport(capPhase, capSpec, function(newListName)
                                if newListName then
                                    local s = GetWishlistSettings()
                                    s.CollapsedLists = s.CollapsedLists or {}
                                    s.CollapsedLists[newListName] = false
                                    -- Show slot info immediately (items are cached from import)
                                    BCF.PreviewWishlistSlots(newListName)
                                    BCF.SetActiveWishlist(newListName)
                                else
                                    BCF.WishlistLoading = false
                                    BCF.IsRefreshingWishlist = false
                                    if BCF.RefreshWishlist and BCF.SideStats then
                                        BCF.RefreshWishlist(BCF.SideStats)
                                    end
                                end
                            end)
                        end)

                        yOffset = yOffset - T.RowHeight
                    end

                    yOffset = yOffset - 4
                end
            end
        end

        yOffset = yOffset - 30

        if #lists == 0 and not BCF.WishlistPickerOpen then
            local empty = BCF.CleanFont(container:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
            empty:SetPoint("TOP", container, "TOP", 0, yOffset)
            empty:SetText("No Wishlists Saved")
            empty:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.6)
            table.insert(container.sections, empty)
        end

        local contentHeight = math.abs(yOffset) + 20
        if contentHeight < 100 then contentHeight = 100 end
        if contentHeight > 2000 then contentHeight = 2000 end
        container:SetHeight(contentHeight)

    end, function(e)
        BCF.Print("|cffff0000[BCF]|r Wishlist error: " .. tostring(e))
    end)

    BCF.IsRefreshingWishlist = false
end

-- ============================================================================
-- BIS IMPORT
-- ============================================================================

function BCF.GetAvailableBiSImports()
    if not BCF.BIS_DATA then return {} end
    local _, _, classID = UnitClass("player")
    local classData = BCF.BIS_DATA[classID]
    if not classData then return {} end

    local result = {}
    for phase, specs in pairs(classData) do
        for spec, slots in pairs(specs) do
            local count = 0
            for _, items in pairs(slots) do
                count = count + #items
            end
            table.insert(result, {phase = phase, spec = spec, count = count})
        end
    end
    table.sort(result, function(a, b)
        if a.phase ~= b.phase then return a.phase < b.phase end
        return a.spec < b.spec
    end)
    return result
end

function BCF.ImportBiSWishlist(phase, spec)
    if not BCF.BIS_DATA then return end
    local _, _, classID = UnitClass("player")
    local classData = BCF.BIS_DATA[classID]
    if not classData or not classData[phase] or not classData[phase][spec] then return end

    local slotData = classData[phase][spec]
    local phaseLabel = PHASE_LABELS[phase] or phase
    local listName = spec .. " " .. phaseLabel

    local wishlists = BCF.GetWishlists()
    local existingNames = {}
    for _, entry in ipairs(wishlists) do
        existingNames[entry.name] = true
    end
    if existingNames[listName] then
        local counter = 2
        while existingNames[listName .. " " .. counter] do
            counter = counter + 1
        end
        listName = listName .. " " .. counter
    end

    BCF.CreateWishlist(listName, spec, phase)

    -- Deduplicate items per slot
    for slotID, items in pairs(slotData) do
        local seen, clean = {}, {}
        for _, itemId in ipairs(items) do
            if not seen[itemId] then
                seen[itemId] = true
                table.insert(clean, itemId)
            end
        end
        slotData[slotID] = #clean > 0 and clean or nil
    end

    -- Slots that should be duplicated: Ring (11->12), Trinket (13->14)
    local DUAL_SLOTS = { [11] = 12, [13] = 14 }

    local addedCount = 0
    local failedItems = {} -- {itemId, slotID}

    for slotID, items in pairs(slotData) do
        local targetSlots = { slotID }
        if DUAL_SLOTS[slotID] then
            table.insert(targetSlots, DUAL_SLOTS[slotID])
        end

        for _, targetSlot in ipairs(targetSlots) do
            for _, itemId in ipairs(items) do
                local link = select(2, GetItemInfo(itemId))
                if link then
                    BCF.AddWishlistItem(listName, targetSlot, link, "")
                    addedCount = addedCount + 1
                else
                    table.insert(failedItems, {itemId = itemId, slotID = targetSlot})
                end
            end
        end
    end

    -- Default paired slots to item #2 (Ring 2, Trinket 2)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if list and list.slots then
        for _, pairedSlot in pairs(DUAL_SLOTS) do
            local items = list.slots[pairedSlot]
            if items and #items >= 2 then
                for i, entry in ipairs(items) do
                    entry.selected = (i == 2)
                end
            end
        end
    end

    -- Import gems (slot 100) filtered by phase
    local targetPhaseOrder = PHASE_ORDER[phase] or 1
    local gemData = BCF.GEM_DATA and BCF.GEM_DATA[classID] and BCF.GEM_DATA[classID][spec]
    if gemData then
        local seenGems = {}
        for _, gem in ipairs(gemData) do
            local gOrder = PHASE_ORDER[gem.phase] or 1
            if (gem.meta or gOrder <= targetPhaseOrder) and not seenGems[gem.id] then
                seenGems[gem.id] = true
                local link = select(2, GetItemInfo(gem.id))
                if link then
                    BCF.AddWishlistItem(listName, 100, link, gem.color or "")
                    addedCount = addedCount + 1
                else
                    table.insert(failedItems, {itemId = gem.id, slotID = 100})
                end
            end
        end
    end

    -- Import enchants (slot 101) filtered by phase
    local enchantData = BCF.ENCHANT_DATA and BCF.ENCHANT_DATA[classID] and BCF.ENCHANT_DATA[classID][spec]
    if enchantData then
        for _, enc in ipairs(enchantData) do
            local eOrder = PHASE_ORDER[enc.phase] or 1
            if eOrder <= targetPhaseOrder then
                BCF.AddWishlistEnchant(listName, enc.name, enc.slot, enc.phase)
                addedCount = addedCount + 1
            end
        end
    end

    -- Auto-favorite: all gems, best enchant per target slot
    local wl = GetCharacterWishlists()[listName]
    if wl and wl.slots then
        -- Gems: select all
        if wl.slots[100] then
            for _, gem in ipairs(wl.slots[100]) do
                gem.selected = true
            end
        end
        -- Enchants: first per enchantSlot wins (highest ranked)
        if wl.slots[101] then
            local seenSlots = {}
            for _, enc in ipairs(wl.slots[101]) do
                local key = enc.enchantSlot or ""
                if not seenSlots[key] then
                    seenSlots[key] = true
                    enc.selected = true
                else
                    enc.selected = false
                end
            end
        end
    end

    BCF.Print("|cff00ccff[BCF]|r Imported " .. addedCount .. " items into '" .. listName .. "'")
    if #failedItems > 0 then
        BCF.Print("|cff00ccff[BCF]|r " .. #failedItems .. " items pending (loading from server...)")
    end

    -- Notify about known missing slots
    local gapKey = phase .. ":" .. spec
    local gapSlots = BCF.BIS_GAPS and BCF.BIS_GAPS[classID] and BCF.BIS_GAPS[classID][gapKey]
    if gapSlots and #gapSlots > 0 then
        local SLOT_LABELS = {}
        for _, def in ipairs(BCF.WISHLIST_SLOTS) do
            SLOT_LABELS[def.id] = def.label
        end
        local names = {}
        for _, sid in ipairs(gapSlots) do
            table.insert(names, SLOT_LABELS[sid] or ("Slot " .. sid))
        end
        BCF.Print("|cff00ccff[BCF]|r |cffffcc00Note:|r No BiS data for: " .. table.concat(names, ", "))
    end

    return listName, failedItems
end

-- ============================================================================
-- ENCHANT / GEM LOOKUP
-- ============================================================================

function BCF.GetBestEnchantForSlot(classID, spec, phase, slotID)
    local specEnchants = BCF.ENCHANT_DATA and BCF.ENCHANT_DATA[classID]
        and BCF.ENCHANT_DATA[classID][spec]
    if not specEnchants then return nil end

    local targetOrder = PHASE_ORDER[phase] or 1
    local best = nil
    local bestOrder = 0

    for _, entry in ipairs(specEnchants) do
        local slotStr = entry.slot
        local ids = ENCHANT_SLOT_TO_IDS[slotStr]
        if ids then
            for _, sid in ipairs(ids) do
                if sid == slotID then
                    local eOrder = PHASE_ORDER[entry.phase] or 1
                    if eOrder <= targetOrder and eOrder > bestOrder then
                        best = entry
                        bestOrder = eOrder
                    end
                end
            end
        end
    end

    return best
end

local SOCKET_ACCEPTS = {
    Red    = { Red = true, Orange = true, Purple = true },
    Yellow = { Yellow = true, Orange = true, Green = true },
    Blue   = { Blue = true, Purple = true, Green = true },
}

function BCF.GetBestGemsForSockets(classID, spec, phase, socketTypes)
    local specGems = BCF.GEM_DATA and BCF.GEM_DATA[classID]
        and BCF.GEM_DATA[classID][spec]
    if not specGems or not socketTypes or #socketTypes == 0 then return {} end

    local targetOrder = PHASE_ORDER[phase] or 1

    local eligible = {}
    local bestMeta = nil
    for _, gem in ipairs(specGems) do
        local gOrder = PHASE_ORDER[gem.phase] or 1
        if gem.meta then
            if not bestMeta then bestMeta = gem end
        elseif gOrder <= targetOrder then
            table.insert(eligible, { gem = gem, order = gOrder })
        end
    end

    local bestRegular = nil
    local bestRegularOrder = 0
    for _, e in ipairs(eligible) do
        if e.order > bestRegularOrder then
            bestRegular = e.gem
            bestRegularOrder = e.order
        end
    end

    local bestByColor = {}
    for _, e in ipairs(eligible) do
        if not e.gem.meta and e.gem.color then
            local prev = bestByColor[e.gem.color]
            if not prev or e.order > prev.order then
                bestByColor[e.gem.color] = e
            end
        end
    end

    local result = {}
    for i, socketType in ipairs(socketTypes) do
        if socketType == "Meta" then
            result[i] = bestMeta
        else
            local accepts = SOCKET_ACCEPTS[socketType]
            local matched = nil
            if accepts then
                local matchedOrder = 0
                for color, entry in pairs(bestByColor) do
                    if accepts[color] and entry.order > matchedOrder then
                        matched = entry.gem
                        matchedOrder = entry.order
                    end
                end
            end
            result[i] = matched or bestRegular
        end
    end
    return result
end

-- ============================================================================
-- SOCKET SCANNING (item link based, not inventory)
-- ============================================================================

function BCF.GetSocketInfoFromLink(itemLink)
    if not itemLink then return {} end

    local scanTT = BCFWishlistScanTT
    if not scanTT then
        scanTT = CreateFrame("GameTooltip", "BCFWishlistScanTT", nil, "GameTooltipTemplate")
        scanTT:SetOwner(UIParent, "ANCHOR_NONE")
        BCFWishlistScanTT = scanTT
    end

    scanTT:ClearLines()
    scanTT:SetHyperlink(itemLink)

    local sockets = {}
    for i = 1, scanTT:NumLines() do
        local line = _G["BCFWishlistScanTTTextLeft" .. i]
        if line then
            local text = line:GetText() or ""
            local socketType = BCF.MatchSocketType and BCF.MatchSocketType(text)
            if socketType then table.insert(sockets, socketType) end
        end
    end
    return sockets
end

-- ============================================================================
-- ITEM PRELOADING
-- ============================================================================

local function CollectAllIDs(pendingIDs, classID, spec, phase)
    -- BiS gear items
    local classData = BCF.BIS_DATA and BCF.BIS_DATA[classID]
    if classData and classData[phase] and classData[phase][spec] then
        for _, items in pairs(classData[phase][spec]) do
            for _, itemId in ipairs(items) do
                if not GetItemInfo(itemId) then
                    pendingIDs[itemId] = true
                end
            end
        end
    end
    -- Gem items
    local gems = BCF.GEM_DATA and BCF.GEM_DATA[classID] and BCF.GEM_DATA[classID][spec]
    if gems then
        for _, g in ipairs(gems) do
            if not GetItemInfo(g.id) then pendingIDs[g.id] = true end
        end
    end
end

local function ResolveWithRetry(pendingIDs, callback, maxRetries, onProgress)
    local POLL_INTERVAL = 0.15
    local MAX_TIME = 30

    local totalCount = 0
    for _ in pairs(pendingIDs) do totalCount = totalCount + 1 end

    if totalCount == 0 then
        if onProgress then onProgress(0, 0) end
        callback()
        return
    end

    -- Kick off all server requests and resolve already-cached items
    local resolvedCount = 0
    for id in pairs(pendingIDs) do
        if GetItemInfo(id) then
            pendingIDs[id] = nil
            resolvedCount = resolvedCount + 1
        else
            GetItemInfo(id)
        end
    end
    if onProgress then onProgress(resolvedCount, totalCount) end

    if resolvedCount >= totalCount then
        callback()
        return
    end

    -- Fast fixed-interval poll — GetItemInfo is a local cache check, cheap to call often
    local elapsed = 0
    local function Poll()
        elapsed = elapsed + POLL_INTERVAL
        for id in pairs(pendingIDs) do
            if GetItemInfo(id) then
                pendingIDs[id] = nil
                resolvedCount = resolvedCount + 1
            end
        end
        if onProgress then onProgress(resolvedCount, totalCount) end

        if resolvedCount >= totalCount then
            callback()
        elseif elapsed < MAX_TIME then
            -- Re-request any still-pending items every ~2s
            if math.floor(elapsed / 2) > math.floor((elapsed - POLL_INTERVAL) / 2) then
                for id in pairs(pendingIDs) do
                    GetItemInfo(id)
                end
            end
            C_Timer.After(POLL_INTERVAL, Poll)
        else
            callback() -- proceed with what we have
        end
    end
    C_Timer.After(POLL_INTERVAL, Poll)
end

function BCF.PreloadBiSAndImport(phase, spec, callback)
    local _, _, classID = UnitClass("player")
    local pendingIDs = {}
    CollectAllIDs(pendingIDs, classID, spec, phase)

    local loadingInfo = BCF.WishlistLoadingInfo

    -- Set total immediately so progress bar starts right away
    local pendingCount = 0
    for _ in pairs(pendingIDs) do pendingCount = pendingCount + 1 end
    if loadingInfo then
        loadingInfo.total = pendingCount
    end

    local function UpdateProgress(resolved, total)
        if loadingInfo then
            loadingInfo.resolved = resolved
            loadingInfo.total = total
        end
    end

    local function FinishLoading(listName)
        if not loadingInfo then
            if callback then callback(listName) end
            return
        end
        loadingInfo.done = true
        loadingInfo.onDone = function()
            BCF.WishlistLoadingInfo = nil
            if callback then callback(listName) end
        end
    end

    ResolveWithRetry(pendingIDs, function()
        local listName, failedItems = BCF.ImportBiSWishlist(phase, spec)

        if failedItems and #failedItems > 0 then
            local retryIDs = {}
            for _, entry in ipairs(failedItems) do
                retryIDs[entry.itemId] = true
            end
            ResolveWithRetry(retryIDs, function()
                local DUAL_SLOTS = { [11] = 12, [13] = 14 }
                local retryCount = 0
                for _, entry in ipairs(failedItems) do
                    local link = select(2, GetItemInfo(entry.itemId))
                    if link then
                        BCF.AddWishlistItem(listName, entry.slotID, link, "")
                        retryCount = retryCount + 1
                    end
                end
                if retryCount > 0 then
                    local l = GetCharacterWishlists()[listName]
                    if l and l.slots then
                        for _, ps in pairs(DUAL_SLOTS) do
                            local sitems = l.slots[ps]
                            if sitems and #sitems >= 2 then
                                local hasSelection = false
                                for _, e in ipairs(sitems) do
                                    if e.selected then hasSelection = true; break end
                                end
                                if not hasSelection then sitems[2].selected = true end
                            end
                        end
                    end
                    BCF.Print("|cff00ccff[BCF]|r Added " .. retryCount .. " more items (cache loaded).")
                end
                FinishLoading(listName)
            end, 10, UpdateProgress)
        else
            FinishLoading(listName)
        end
    end, 10, UpdateProgress)
end

function BCF.PreloadWishlistItems(listName, callback, onProgress)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if not list then callback() return end

    local _, _, classID = UnitClass("player")
    local pendingIDs = {}

    -- Items already in list
    for _, items in pairs(list.slots) do
        for _, entry in ipairs(items) do
            if not GetItemInfo(entry.itemID) then
                pendingIDs[entry.itemID] = true
            end
        end
    end

    -- Also preload from raw BiS data if spec/phase known
    if list.spec and list.phase then
        CollectAllIDs(pendingIDs, classID, list.spec, list.phase)
    end

    ResolveWithRetry(pendingIDs, callback, 10, onProgress)
end

-- ============================================================================
-- PAPERDOLL LOADING BAR
-- ============================================================================

function BCF.ShowPaperdollLoadingBar()
    -- Anchor to the off-hand slot (center bottom)
    local anchor = BCF.GearSlotFrames and BCF.GearSlotFrames[17]
    if not anchor then return end

    if not BCF.PaperdollLoadingBar then
        local bar = CreateFrame("Frame", nil, anchor:GetParent(), "BackdropTemplate")
        bar:SetHeight(6)
        bar:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        bar:SetBackdropColor(0.08, 0.08, 0.10, 0.8)
        BCF.PaperdollLoadingBar = bar

        bar.fill = bar:CreateTexture(nil, "ARTWORK")
        bar.fill:SetPoint("TOPLEFT", 0, 0)
        bar.fill:SetPoint("BOTTOMLEFT", 0, 0)
        bar.fill:SetWidth(1)

        bar.currentPct = 0
    end

    local bar = BCF.PaperdollLoadingBar
    -- Span all 3 weapon slots: left edge of MH to right edge of Ranged
    local mh = BCF.GearSlotFrames[16]
    local ranged = BCF.GearSlotFrames[18]
    if mh and ranged then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", mh, "TOPLEFT", 0, 4)
        bar:SetPoint("BOTTOMRIGHT", ranged, "TOPRIGHT", 0, 4)
    end

    -- Time-based estimated progress: fills smoothly, snaps to 100% when done
    BCF.PaperdollLoadingDone = false
    bar.fill:SetColorTexture(T.Accent[1], T.Accent[2], T.Accent[3], 0.6)
    bar.currentPct = 0
    bar.fill:SetWidth(1)
    bar:Show()

    local startTime = GetTime()
    bar:SetScript("OnUpdate", function(self, elapsed)
        -- Estimated progress: 1 - 1/(1 + t*0.06) — tuned for ~30s loads
        local t = GetTime() - startTime
        local estimatedPct = 1 - 1 / (1 + t * 0.06)
        local targetPct = BCF.PaperdollLoadingDone and 1.0 or (estimatedPct * 0.92)
        local speed = BCF.PaperdollLoadingDone and 5.0 or 3.0
        self.currentPct = self.currentPct + (targetPct - self.currentPct) * math.min(1, elapsed * speed)
        local w = self:GetWidth()
        if w > 0 then
            self.fill:SetWidth(math.max(1, w * self.currentPct))
        end
        if BCF.PaperdollLoadingDone and self.currentPct >= 0.98 then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            BCF.PaperdollLoadingDone = false
        end
    end)
end

function BCF.HidePaperdollLoadingBar()
    BCF.PaperdollLoadingDone = false
    if BCF.PaperdollLoadingBar then
        BCF.PaperdollLoadingBar:SetScript("OnUpdate", nil)
        BCF.PaperdollLoadingBar:Hide()
    end
end

-- ============================================================================
-- PAPER DOLL PREVIEW
-- ============================================================================

function BCF.PreviewWishlistSlots(listName)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if not list or not BCF.GearSlotFrames then return end

    local selected = BCF.GetSelectedItems(listName)
    local _, _, classID = UnitClass("player")
    local showDetails = BCF.DB and BCF.DB.General and BCF.DB.General.ShowItemDetails

    -- Build lookup of SELECTED enchant names in wishlist slot 101
    local wishlistEnchants = {}
    if list.slots and list.slots[101] then
        for _, e in ipairs(list.slots[101]) do
            if e.selected and e.enchantName then wishlistEnchants[e.enchantName] = true end
        end
    end

    local gemIsMetaByID = {}
    do
        local specGems = BCF.GEM_DATA and BCF.GEM_DATA[classID] and list.spec and BCF.GEM_DATA[classID][list.spec]
        if specGems then
            for _, gem in ipairs(specGems) do
                if gem and gem.id then
                    gemIsMetaByID[tonumber(gem.id)] = gem.meta and true or false
                end
            end
        end
    end

    -- Build lookup of SELECTED gem item IDs in wishlist slot 100
    local wishlistGemIDs = {}
    local wishlistGemFallbackID = nil
    local wishlistAnySelectedGemID = nil
    if list.slots and list.slots[100] then
        for _, e in ipairs(list.slots[100]) do
            if e.selected and e.itemID then
                local id = tonumber(e.itemID)
                wishlistGemIDs[id] = true
                if not wishlistAnySelectedGemID then
                    wishlistAnySelectedGemID = id
                end
                if not wishlistGemFallbackID and not gemIsMetaByID[id] then
                    wishlistGemFallbackID = id
                end
            end
        end
    end
    -- Don't use meta gems as fallback for non-meta sockets

    for slotID, frame in pairs(BCF.GearSlotFrames) do
        local entry = selected[slotID]
        if entry and entry.link then
            local itemName, itemLink, quality, ilvl, _, _, _, _, _, texture = GetItemInfo(entry.link)
            if not texture then
                -- Item not cached yet; request it and skip this slot (keep previous state)
                GetItemInfo(entry.link)
            else
                frame.Icon:SetTexture(texture)
                frame.Icon:SetVertexColor(1, 1, 1)

                local r, g, b = GetItemQualityColor(quality or 1)
                frame.IconBorder:SetBackdropBorderColor(r, g, b, 1)

                if ilvl and ilvl > 0 then
                    frame.ILvlOverlay:SetText(tostring(math.floor(ilvl + 0.5)))
                    frame.ILvlOverlay:SetTextColor(r, g, b)
                    frame.ILvlOverlay:Show()
                else
                    frame.ILvlOverlay:SetText("")
                    frame.ILvlOverlay:Hide()
                end

                if showDetails and frame.InfoFrame then
                    frame.InfoFrame:Show()

                    if frame.ItemName then
                        BCF.FitText(frame.ItemName, itemName or "")
                        frame.ItemName:SetTextColor(r, g, b)
                    end

                    -- Enchant (only show if enchant still exists in wishlist slot 101)
                    if frame.EnchantText then
                        local shownEnchant = false
                        if list.spec and list.phase then
                            local enchant = BCF.GetBestEnchantForSlot(classID, list.spec, list.phase, slotID)
                            if enchant and enchant.name then
                                local cleanName = enchant.name:gsub("^Enchant [%w]+ %- ", "")
                                if wishlistEnchants[cleanName] or wishlistEnchants[enchant.name] then
                                    local displayMode = BCF.DB and BCF.DB.General and BCF.DB.General.EnchantDisplayMode
                                    local stats = BCF.ENCHANT_STATS and BCF.ENCHANT_STATS[enchant.name]
                                    local displayText = (displayMode == "FULL") and cleanName or (stats or cleanName)
                                    BCF.FitText(frame.EnchantText, displayText)
                                    frame.EnchantText:SetTextColor(0.2, 1, 0.2)
                                    shownEnchant = true
                                end
                            end
                        end
                        if not shownEnchant then frame.EnchantText:SetText("") end
                    end

                    -- Gems (show only gems still selected in wishlist slot 100)
                    if frame.GemButtons then
                        if next(wishlistGemIDs) then
                            local socketInfo = BCF.GetSocketInfoFromLink(entry.link)
                            if socketInfo and #socketInfo > 0 and list.spec and list.phase then
                                local gems = BCF.GetBestGemsForSockets(classID, list.spec, list.phase, socketInfo)
                                for i = 1, 3 do
                                    local btn = frame.GemButtons[i]
                                    if btn then
                                        if socketInfo[i] then
                                            btn:Show()
                                            local socketType = socketInfo[i]
                                            local recommendedGemID = gems[i] and tonumber(gems[i].id)
                                            local shownGemID = nil
                                            if recommendedGemID and wishlistGemIDs[recommendedGemID] then
                                                shownGemID = recommendedGemID
                                            elseif socketType ~= "Meta" then
                                                shownGemID = wishlistGemFallbackID
                                            end

                                            btn.socketType = socketType
                                            if shownGemID then
                                                local _, gemLink, _, _, _, _, _, _, _, gemIcon = GetItemInfo(shownGemID)
                                                btn.Texture:SetTexture(gemIcon or "Interface\\Icons\\INV_Misc_Gem_01")
                                                btn.gemLink = gemLink
                                            else
                                                btn.Texture:SetTexture("Interface\\ItemSocketingFrame\\UI-EmptySocket-" .. socketInfo[i])
                                                btn.gemLink = nil
                                            end
                                        else
                                            btn:Hide()
                                        end
                                    end
                                end
                            else
                                for i = 1, 3 do
                                    if frame.GemButtons[i] then frame.GemButtons[i]:Hide() end
                                end
                            end
                        else
                            for i = 1, 3 do
                                if frame.GemButtons[i] then frame.GemButtons[i]:Hide() end
                            end
                        end
                    end
                elseif frame.InfoFrame then
                    frame.InfoFrame:Hide()
                end
            end

            if frame.FlyoutBtn then frame.FlyoutBtn:Hide() end
            if frame.Cooldown then frame.Cooldown:Clear() end
        else
            ClearSlotFrame(frame)
        end
    end
end

function BCF.PreviewWishlistModel(listName)
    local wishlists = GetCharacterWishlists()
    local list = wishlists[listName]
    if not list or not BCF.ModelFrame then return end

    local selected = BCF.GetSelectedItems(listName)
    BCF.ModelFrame:Undress()
    for slotID, entry in pairs(selected) do
        if entry.link and slotID ~= 18 and slotID < 100 then
            BCF.ModelFrame:TryOn(entry.link)
        end
    end
end

function BCF.PreviewWishlist(listName)
    BCF.PreviewWishlistSlots(listName)
    BCF.PreviewWishlistModel(listName)
end

-- ============================================================================
-- ACTIVE WISHLIST
-- ============================================================================

function BCF.SetActiveWishlist(listName)
    local settings = GetWishlistSettings()
    settings.ActiveList = listName

    if not listName then
        BCF.WishlistLoading = false
        BCF.WishlistLoadingInfo = nil
        if BCF.HidePaperdollLoadingBar then BCF.HidePaperdollLoadingBar() end
        if BCF.ModelFrame then BCF.ModelFrame:Undress() end
        if BCF.GearSlotFrames then
            for _, frame in pairs(BCF.GearSlotFrames) do
                ClearSlotFrame(frame)
            end
        end
        return
    end

    -- Combat fast path: never gate paperdoll switching on preload/loading UI.
    -- Show immediate best-effort preview, then refine in background as item data arrives.
    if InCombatLockdown() then
        BCF.WishlistLoading = false
        BCF.WishlistLoadingInfo = nil
        BCF.PaperdollLoadingDone = false
        if BCF.HidePaperdollLoadingBar then BCF.HidePaperdollLoadingBar() end

        if BCF.activeSubTab ~= 3 then return end

        BCF.PreviewWishlist(listName)
        BCF.IsRefreshingWishlist = false
        if BCF.RefreshWishlist and BCF.SideStats then
            BCF.RefreshWishlist(BCF.SideStats)
        end

        BCF.PreloadWishlistItems(listName, function()
            local current = GetWishlistSettings()
            if not current or current.ActiveList ~= listName then return end
            if BCF.activeSubTab ~= 3 then return end
            BCF.PreviewWishlist(listName)
            BCF.IsRefreshingWishlist = false
            if BCF.RefreshWishlist and BCF.SideStats then
                BCF.RefreshWishlist(BCF.SideStats)
            end
        end)
        return
    end

    -- Fast path: skip loading bar if selected items already cached
    do
        local selected = BCF.GetSelectedItems(listName)
        local hasItems = false
        local allCached = true
        for slotID, entry in pairs(selected) do
            if slotID < 100 and slotID ~= 18 then
                hasItems = true
                if not entry.link or not GetItemInfo(entry.itemID) then
                    allCached = false
                    break
                end
            end
        end
        if hasItems and allCached then
            BCF.WishlistLoading = false
            BCF.WishlistLoadingInfo = nil
            BCF.PaperdollLoadingDone = false
            if BCF.HidePaperdollLoadingBar then BCF.HidePaperdollLoadingBar() end
            if BCF.ModelFrame then BCF.ModelFrame:Undress() end
            if BCF.activeSubTab ~= 3 then return end  -- user navigated away
            BCF.PreviewWishlistSlots(listName)
            BCF.PreviewWishlistModel(listName)
            BCF.IsRefreshingWishlist = false
            if BCF.RefreshWishlist and BCF.SideStats then
                BCF.RefreshWishlist(BCF.SideStats)
            end
            return
        end
    end

    -- Undress model while items load, show slot info immediately
    BCF.WishlistLoading = true
    if BCF.ModelFrame then BCF.ModelFrame:Undress() end
    BCF.PreviewWishlistSlots(listName)

    -- Show paperdoll loading bar (time-based, tracks model dressing)
    if BCF.ShowPaperdollLoadingBar then
        BCF.ShowPaperdollLoadingBar()
    end

    -- Set loading info for progress bar on the actual header (time-based estimation)
    BCF.WishlistLoadingInfo = {
        name = listName,
        listName = listName,
        estimated = true,
        startTime = GetTime(),
        resolved = 0,
        total = 0,
    }
    BCF.IsRefreshingWishlist = false
    BCF.RefreshWishlist(BCF.SideStats)

    local function OnSwitchProgress(resolved, total)
        if BCF.WishlistLoadingInfo then
            BCF.WishlistLoadingInfo.resolved = resolved
            BCF.WishlistLoadingInfo.total = total
        end
    end

    BCF.PreloadWishlistItems(listName, function()
        -- Mark paperdoll bar done (it lerps to 100% then auto-hides)
        BCF.PaperdollLoadingDone = true
        if BCF.WishlistLoadingInfo then
            BCF.WishlistLoadingInfo.done = true
            BCF.WishlistLoadingInfo.onDone = function()
                BCF.WishlistLoading = false
                BCF.WishlistLoadingInfo = nil
                if BCF.activeSubTab ~= 3 then return end  -- user navigated away
                BCF.PreviewWishlistModel(listName)
                BCF.PreviewWishlistSlots(listName)
                BCF.IsRefreshingWishlist = false
                if BCF.RefreshWishlist and BCF.SideStats then
                    BCF.RefreshWishlist(BCF.SideStats)
                end
            end
        else
            BCF.WishlistLoading = false
            if BCF.activeSubTab ~= 3 then return end  -- user navigated away
            BCF.PreviewWishlist(listName)
            BCF.IsRefreshingWishlist = false
            if BCF.RefreshWishlist and BCF.SideStats then
                BCF.RefreshWishlist(BCF.SideStats)
            end
        end
    end, OnSwitchProgress)
end

-- ============================================================================
-- DATA VALIDATION
-- ============================================================================

function BCF.ValidateBiSData()
    if not BCF.BIS_DATA then
        BCF.Print("|cff00ccff[BCF]|r No BIS_DATA loaded.")
        return
    end

    local CLASS_NAMES = {
        [1] = "Warrior", [2] = "Paladin", [3] = "Hunter", [4] = "Rogue",
        [5] = "Priest", [6] = "Death Knight", [7] = "Shaman", [8] = "Mage",
        [9] = "Warlock", [11] = "Druid",
    }

    local SLOT_LABELS = {}
    for _, def in ipairs(BCF.WISHLIST_SLOTS) do
        SLOT_LABELS[def.id] = def.label
    end

    -- equipLoc values that indicate non-equippable items
    local NON_EQUIPPABLE = { [""] = true, ["INVTYPE_NON_EQUIP"] = true }

    local issues = {}

    for classID, phases in pairs(BCF.BIS_DATA) do
        local className = CLASS_NAMES[classID] or ("Class " .. classID)
        for phase, specs in pairs(phases) do
            for spec, slots in pairs(specs) do
                for slotID, items in pairs(slots) do
                    local slotLabel = SLOT_LABELS[slotID] or ("Slot " .. slotID)
                    local prefix = className .. " > " .. spec .. " > " .. phase .. " > " .. slotLabel

                    -- Check for intra-slot duplicates
                    local seen = {}
                    for _, itemId in ipairs(items) do
                        if seen[itemId] then
                            table.insert(issues, prefix .. ": DUPLICATE itemID " .. itemId)
                        end
                        seen[itemId] = true
                    end

                    -- Check for misplaced or non-equippable items via equipLoc
                    for _, itemId in ipairs(items) do
                        local name, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemId)
                        if not name then
                            table.insert(issues, prefix .. ": UNCACHED itemID " .. itemId)
                        elseif NON_EQUIPPABLE[equipLoc] then
                            table.insert(issues, prefix .. ": NON-EQUIPPABLE -> " .. name .. " (" .. itemId .. ")")
                        elseif slotID == 17 and equipLoc == "INVTYPE_2HWEAPON" then
                            table.insert(issues, prefix .. ": 2H WEAPON in Off Hand -> " .. name .. " (" .. itemId .. ")")
                        elseif slotID == 16 and (equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_SHIELD") then
                            table.insert(issues, prefix .. ": OFFHAND item in Main Hand -> " .. name .. " (" .. itemId .. ")")
                        end
                    end
                end
            end
        end
    end

    -- Report known BiS gaps from generator
    if BCF.BIS_GAPS then
        for classID, entries in pairs(BCF.BIS_GAPS) do
            local className = CLASS_NAMES[classID] or ("Class " .. classID)
            for key, missingSlots in pairs(entries) do
                local phase, spec = key:match("^([^:]+):(.+)$")
                if phase and spec then
                    local slotNames = {}
                    for _, sid in ipairs(missingSlots) do
                        table.insert(slotNames, SLOT_LABELS[sid] or ("Slot " .. sid))
                    end
                    table.insert(issues,
                        className .. " > " .. spec .. " > " .. phase ..
                        ": MISSING SLOTS -> " .. table.concat(slotNames, ", ")
                    )
                end
            end
        end
    end

    if #issues == 0 then
        BCF.Print("|cff00ccff[BCF]|r Validation passed — no issues found.")
    else
        BCF.Print("|cff00ccff[BCF]|r Found " .. #issues .. " issue(s):")
        for _, msg in ipairs(issues) do
            print("  |cffff6666" .. msg .. "|r")
        end
    end
end

-- ============================================================================
-- ALT-CLICK TO ADD ITEMS TO WISHLIST
-- ============================================================================

-- Track if user is actively typing in chat (HasFocus, not IsShown — editbox can be "shown" while invisible)
local chatEditBoxHadFocus = false
local editBoxTracker = CreateFrame("Frame")
editBoxTracker:SetScript("OnUpdate", function()
    local eb = ChatFrameEditBox or (ChatFrame1 and ChatFrame1.editBox)
    chatEditBoxHadFocus = eb and eb:HasFocus() or false
end)

-- Gem detection: GetItemInfo returns itemType as localized string at position 6
local GEM_ITEM_TYPE = "Gem"

-- Enchant spell name patterns → enchantSlot mapping
local ENCHANT_SLOT_PATTERNS = {
    {"Weapon",   "weapon"},
    {"Boots",    "feet"},   {"Cloak",    "back"},
    {"Bracer",   "wrist"},  {"Bracers",  "wrist"},
    {"Gloves",   "hands"},  {"Chest",    "chest"},
    {"Shield",   "offhand"}, {"2H Weapon", "weapon"},
}

local function GetEnchantSlotFromName(name)
    for _, pair in ipairs(ENCHANT_SLOT_PATTERNS) do
        if name:find(pair[1]) then return pair[2] end
    end
    return ""
end

local function DismissEditBox()
    local eb = ChatFrameEditBox or (ChatFrame1 and ChatFrame1.editBox)
    if eb and eb:HasFocus() then eb:ClearFocus() end
end

local function WishlistAdded(msg)
    if BCF.RefreshWishlist and BCF.SideStats then
        BCF.RefreshWishlist(BCF.SideStats)
    end
    DismissEditBox()
    BCF.Print("|cff00ccff[BCF]|r " .. msg)
end

local function TryAddToWishlist(link)
    if not link then return false end

    local settings = GetWishlistSettings()
    local listName = settings.ActiveList
    if not listName then return false end

    -- Handle enchant/spell links (|Henchant:ID|h[name]|h or |Hspell:ID|h[name]|h)
    local enchantName = link:match("|Henchant:%d+|h%[(.-)%]|h") or link:match("|Hspell:%d+|h%[(.-)%]|h")
    if enchantName then
        if enchantName:find("Enchant ") then
            local cleanName = enchantName:gsub("^Enchant [%w]+ %- ", "")
            local enchantSlot = GetEnchantSlotFromName(enchantName)
            if BCF.AddWishlistEnchant(listName, cleanName, enchantSlot, "") then
                WishlistAdded("Added enchant: " .. cleanName)
            end
        end
        return true
    end

    -- Normalize bare item strings from addons like AtlasLoot ("item:12345:0:0:...")
    if not link:match("|Hitem:") then
        local bareID = link:match("^item:(%d+)") or link:match("item:(%d+)")
        if not bareID then return false end
        local _, itemLink = GetItemInfo(tonumber(bareID))
        if itemLink then
            link = itemLink
        else
            return false
        end
    end

    local itemName, _, _, _, _, itemClass, _, _, equipLoc = GetItemInfo(link)
    if not itemName then return false end

    -- Gems
    if itemClass == GEM_ITEM_TYPE then
        if BCF.AddWishlistItem(listName, 100, link, "") then
            WishlistAdded("Added gem: " .. link)
        end
        return true
    end

    -- Recipes: enchant formulas
    if itemClass == "Recipe" then
        local enchantPart = itemName:match("Enchant (.+)")
        if enchantPart then
            local cleanName = itemName:gsub("^[^:]+:%s*", ""):gsub("^Enchant [%w]+ %- ", "")
            local enchantSlot = GetEnchantSlotFromName(itemName)
            if BCF.AddWishlistEnchant(listName, cleanName, enchantSlot, "") then
                WishlistAdded("Added enchant: " .. cleanName)
            end
        end
        return true
    end

    -- Equipment: must have a valid equipLoc
    if not equipLoc or equipLoc == "" then return false end

    local slotID = EQUIPSLOT_TO_ID[equipLoc]
    if not slotID then return false end

    -- For rings/trinkets: if slot 1 has items, try slot 2
    local pairedSlot = PAIRED_SLOTS[slotID]
    if pairedSlot then
        local wishlists = GetCharacterWishlists()
        local list = wishlists[listName]
        if list and list.slots and list.slots[slotID] and #list.slots[slotID] > 0 then
            slotID = pairedSlot
        end
    end

    if BCF.AddWishlistItem(listName, slotID, link, "") then
        WishlistAdded("Added " .. link .. " to wishlist")
    end
    return true
end

local origHandleModifiedItemClick = HandleModifiedItemClick
function HandleModifiedItemClick(link, ...)
    if IsAltKeyDown() and not chatEditBoxHadFocus and TryAddToWishlist(link) then
        return true
    end
    return origHandleModifiedItemClick(link, ...)
end

local origChatEdit_InsertLink = ChatEdit_InsertLink
function ChatEdit_InsertLink(link, ...)
    if IsAltKeyDown() and not chatEditBoxHadFocus and TryAddToWishlist(link) then
        return
    end
    return origChatEdit_InsertLink(link, ...)
end

-- Hook ChatFrameUtil.InsertLink (used by AtlasLoot V2/V3)
if ChatFrameUtil and ChatFrameUtil.InsertLink then
    local origChatFrameUtilInsertLink = ChatFrameUtil.InsertLink
    ChatFrameUtil.InsertLink = function(link, ...)
        if IsAltKeyDown() and not chatEditBoxHadFocus and TryAddToWishlist(link) then
            return true
        end
        return origChatFrameUtilInsertLink(link, ...)
    end
end

local origSetItemRef = SetItemRef
function SetItemRef(link, text, button, chatFrame)
    if IsAltKeyDown() and not chatEditBoxHadFocus and text then
        if TryAddToWishlist(text) then return end
    end
    return origSetItemRef(link, text, button, chatFrame)
end
