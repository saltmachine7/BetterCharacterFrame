local addonName, BCF = ...
local T = BCF.Tokens

-- ========================================================================
-- ICON PICKER (Attached Side Panel, Virtualized Grid)
-- ========================================================================
do
    local iconPicker = CreateFrame("Frame", "BCFIconPicker", UIParent, "BackdropTemplate")
    iconPicker:SetWidth(315)
    iconPicker:SetFrameStrata("HIGH")
    BCF.ApplyPanelStyle(iconPicker)
    iconPicker:SetMovable(false)
    iconPicker:EnableMouse(true)
    iconPicker:SetClipsChildren(true)
    iconPicker:Hide()

    -- Search Bar
    local searchBox = CreateFrame("EditBox", nil, iconPicker, "BackdropTemplate")
    searchBox:SetPoint("TOPLEFT", 8, -8)
    searchBox:SetPoint("BOTTOMRIGHT", iconPicker, "TOPRIGHT", -8, -32)
    searchBox:SetFontObject("GameFontHighlight")
    searchBox:SetTextInsets(6, 6, 0, 0)
    searchBox:SetJustifyH("LEFT")
    searchBox:SetAutoFocus(false)

    searchBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1
    })
    searchBox:SetBackdropColor(0, 0, 0, 0.2)
    searchBox:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.5)

    searchBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropColor(0, 0, 0, 0.5)
        self:SetBackdropBorderColor(unpack(T.Accent))
        if self:GetText() == "Search Icons" then
             self:SetText("")
             self:SetTextColor(1, 1, 1)
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropColor(0, 0, 0, 0.2)
        self:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.5)
        if self:GetText() == "" then
             self:SetText("Search Icons")
             self:SetTextColor(0.5, 0.5, 0.5)
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    searchBox:SetText("Search Icons")
    searchBox:SetTextColor(0.5, 0.5, 0.5)

    local allIcons = {}
    local filteredIcons = {}

    local function LoadIcons()
        if #allIcons > 0 then return end

        local added = {}
        local function Add(tex)
            if tex and not added[tex] then
                table.insert(allIcons, tex)
                added[tex] = true
            end
        end

        if GetMacroIcons then
            local icons = GetMacroIcons()
            if type(icons) == "table" then
                for i = 1, #icons do Add(icons[i]) end
            elseif type(icons) == "number" then
                local num = GetNumMacroIcons()
                for i = 1, num do Add(GetMacroIconInfo(i)) end
            end
        end

        if GetMacroItemIcons then
            local icons = GetMacroItemIcons()
            if type(icons) == "table" then
                for i = 1, #icons do Add(icons[i]) end
            elseif type(icons) == "number" then
                local num = GetNumMacroItemIcons()
                for i = 1, num do Add(GetMacroItemIconInfo(i)) end
            end
        end

        if #allIcons == 0 then
            local P = "Interface\\Icons\\"
            local fallback = {
                P.."INV_Misc_QuestionMark", P.."INV_Sword_04",
                P.."INV_Axe_09", P.."INV_Chest_Plate01", P.."INV_Helmet_08",
            }
            for _, v in ipairs(fallback) do table.insert(allIcons, v) end
        end

        filteredIcons = allIcons
    end

    local spellNameIcons = {}
    local spellCacheBuilt = false

    local function BuildSpellIconCache()
        if spellCacheBuilt then return end
        spellCacheBuilt = true
        for id = 1, 50000 do
            local name, _, icon = GetSpellInfo(id)
            if name and icon and not spellNameIcons[icon] then
                spellNameIcons[icon] = name:lower()
            end
        end
    end

    local equippedIcons = {}

    local function RefreshEquippedIcons()
        wipe(equippedIcons)
        local seen = {}
        for slot = 1, 19 do
            local tex = GetInventoryItemTexture("player", slot)
            if tex and not seen[tex] then
                table.insert(equippedIcons, tex)
                seen[tex] = true
            end
        end
    end

    local function BuildIconList(searchText)
        filteredIcons = {}
        local added = {}
        if not searchText then
            for _, icon in ipairs(equippedIcons) do
                table.insert(filteredIcons, icon)
                added[icon] = true
            end
            for _, icon in ipairs(allIcons) do
                if not added[icon] then
                    table.insert(filteredIcons, icon)
                end
            end
        else
            for _, icon in ipairs(equippedIcons) do
                local iconStr = tostring(icon)
                local cleanName = iconStr:lower():match("([^\\]+)$") or iconStr:lower()
                local spellName = spellNameIcons[icon] or ""
                if cleanName:find(searchText, 1, true) or spellName:find(searchText, 1, true) then
                    table.insert(filteredIcons, icon)
                    added[icon] = true
                end
            end
            for _, icon in ipairs(allIcons) do
                if not added[icon] then
                    local iconStr = tostring(icon)
                    local cleanName = iconStr:lower():match("([^\\]+)$") or iconStr:lower()
                    local spellName = spellNameIcons[icon] or ""
                    if cleanName:find(searchText, 1, true) or spellName:find(searchText, 1, true) then
                        table.insert(filteredIcons, icon)
                    end
                end
            end
        end
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, iconPicker)
    scrollFrame:SetPoint("TOPLEFT", 6, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -6, 6)

    local slider = CreateFrame("Slider", nil, iconPicker, "BackdropTemplate")
    slider:SetPoint("TOPRIGHT", -4, -40)
    slider:SetPoint("BOTTOMRIGHT", -4, 6)
    slider:SetWidth(6)
    slider:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    slider:SetBackdropColor(0, 0, 0, 0.2)
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(6, 30)
    thumb:SetColorTexture(unpack(T.Accent))
    slider:SetThumbTexture(thumb)
    slider:SetOrientation("VERTICAL")
    slider:SetValueStep(1)

    local ICON_SIZE = 38
    local GAP = 3
    local COLUMNS = 7
    local ROWS = 11
    local buttons = {}

    for i = 1, ROWS * COLUMNS do
        local btn = CreateFrame("Button", nil, iconPicker, "BackdropTemplate")
        btn:SetSize(ICON_SIZE, ICON_SIZE)
        btn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        btn:SetBackdropColor(0.1, 0.1, 0.15, 0.8)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        btn.icon = tex

        btn:SetScript("OnEnter", function(self)
            if BCF.IsDraggingScroll then return end
            self:SetBackdropColor(T.Accent[1]*0.5, T.Accent[2]*0.5, T.Accent[3]*0.5, 1)
            if self.texturePath then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local spellName = spellNameIcons[self.texturePath]
                if spellName then
                    local displayName = spellName:gsub("^%l", string.upper)
                    GameTooltip:SetText(displayName, 1, 1, 1)
                    local fileLabel = tostring(self.texturePath):match("([^\\]+)$") or ""
                    if fileLabel ~= "" then
                        GameTooltip:AddLine(fileLabel, 0.5, 0.5, 0.5)
                    end
                else
                    local label = type(self.texturePath) == "string" and (self.texturePath:match("([^\\]+)$") or "Icon") or tostring(self.texturePath)
                    GameTooltip:SetText(label, 1, 1, 1)
                end
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.1, 0.1, 0.15, 0.8)
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function(self)
            if self.texturePath then
                if iconPicker.onSelect then
                    iconPicker.onSelect(self.texturePath)
                elseif iconPicker.targetSet then
                    local sets = BCF.GetGearSets()
                    for _, s in ipairs(sets) do
                        if s.name == iconPicker.targetSet then
                            s.icon = self.texturePath
                            break
                        end
                    end
                    local macroName = "BCF:" .. iconPicker.targetSet:sub(1, 12)
                    local mIdx = GetMacroIndexByName(macroName)
                    if mIdx and mIdx > 0 then
                        local newIcon = self.texturePath
                        if type(newIcon) == "string" then
                            newIcon = newIcon:gsub("Interface\\Icons\\", "")
                        end
                        EditMacro(mIdx, macroName, newIcon, "/bcf equip " .. iconPicker.targetSet)
                    end
                end

                if iconPicker.sourceIcon then
                     iconPicker.sourceIcon:SetTexture(self.texturePath)
                     if self.texturePath == "Interface\\Icons\\INV_Misc_Plus_01" then
                         iconPicker.sourceIcon:SetVertexColor(0.4, 1, 0.4)
                     else
                         iconPicker.sourceIcon:SetVertexColor(1, 1, 1)
                     end
                end

                iconPicker:Hide()
            end
        end)

        table.insert(buttons, btn)
    end

    local function UpdateLayout()
        local r, c = 0, 0
        for i, btn in ipairs(buttons) do
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", iconPicker, "TOPLEFT", 4 + (c * (ICON_SIZE + GAP)), -40 - (r * (ICON_SIZE + GAP)))
            c = c + 1
            if c >= COLUMNS then
                c = 0
                r = r + 1
            end
        end
    end
    UpdateLayout()

    local function RefreshGrid(offset)
        local totalIcons = #filteredIcons
        for i, btn in ipairs(buttons) do
            local index = offset + i
            if index <= totalIcons then
                local iconPath = filteredIcons[index]
                btn.texturePath = iconPath
                btn.icon:SetTexture(iconPath)
                btn:Show()
            else
                btn:Hide()
            end
        end

        local maxRange = math.max(0, totalIcons - #buttons)
        slider:SetMinMaxValues(0, maxRange)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        local offset = math.floor(value / COLUMNS) * COLUMNS
        RefreshGrid(offset)
    end)

    iconPicker:EnableMouseWheel(true)
    iconPicker:SetScript("OnMouseWheel", function(self, delta)
        local cur = slider:GetValue()
        local step = COLUMNS * 3
        if delta > 0 then
            slider:SetValue(cur - step)
        else
            slider:SetValue(cur + step)
        end
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text == "" or text == "Search Icons" or text:lower() == "search icons" then
            BuildIconList()
        else
            BuildSpellIconCache()
            BuildIconList(text:lower())
        end
        slider:SetValue(0)
        RefreshGrid(0)
    end)

    function BCF.ShowIconPicker(setName, iconTexture, onSelect)
        if iconPicker:IsShown() and iconPicker.targetSet == setName then
            iconPicker:Hide()
            return
        end

        LoadIcons()
        RefreshEquippedIcons()

        local isFirstOpen = not iconPicker._hasOpened
        iconPicker._hasOpened = true
        iconPicker.targetSet = setName
        iconPicker.sourceIcon = iconTexture
        iconPicker.onSelect = onSelect

        iconPicker:ClearAllPoints()
        local anchor = BCF.SideStats or BCF.MainFrame

        if anchor and anchor:IsShown() then
             local h = BCF.MainFrame:GetHeight()
             iconPicker:SetHeight(h)
             iconPicker:SetPoint("TOP", BCF.MainFrame, "TOP", 0, 0)
             iconPicker:SetPoint("LEFT", anchor, "RIGHT", 2, 0)
        else
             iconPicker:SetPoint("CENTER")
             iconPicker:SetHeight(BCF.MainFrame:GetHeight() or 520)
        end

        if isFirstOpen then
            searchBox:SetText("Search Icons")
            searchBox:SetTextColor(0.5, 0.5, 0.5)
            searchBox:ClearFocus()
            slider:SetValue(0)
        end

        local searchText = searchBox:GetText()
        if searchText == "" or searchText == "Search Icons" then
            BuildIconList()
        else
            BuildSpellIconCache()
            BuildIconList(searchText:lower())
        end
        RefreshGrid(isFirstOpen and 0 or (math.floor(slider:GetValue() / COLUMNS) * COLUMNS))
        iconPicker:Show()
    end
end
