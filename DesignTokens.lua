local addonName, BCF = ...

-- ============================================================================
-- MODULE: DesignTokens
-- ============================================================================

local _, playerClass = UnitClass("player")
local classColor = RAID_CLASS_COLORS[playerClass] or { r = 0.4, g = 0.8, b = 1 }

BCF.Tokens = {
    -- Colors
    Background      = {0.05, 0.05, 0.08, 0.95},
    BackgroundLight  = {0.08, 0.08, 0.12, 0.95},
    BackgroundPanel  = {0.06, 0.06, 0.10, 0.90},
    Accent          = {classColor.r, classColor.g, classColor.b, 1},
    AccentDim       = {classColor.r * 0.6, classColor.g * 0.6, classColor.b * 0.6, 1},
    AccentGlow      = {classColor.r, classColor.g, classColor.b, 0.3},
    Border          = {classColor.r * 0.8, classColor.g * 0.8, classColor.b * 0.8, 0.8},
    BorderDim       = {0.2, 0.2, 0.25, 0.8},
    Hover           = {classColor.r, classColor.g, classColor.b, 0.3},
    Text            = {classColor.r, classColor.g, classColor.b, 1},
    TextMain        = {1, 1, 1, 1},
    TextSecondary   = {0.7, 0.7, 0.7, 1},
    TextMuted       = {0.45, 0.45, 0.5, 1},

    -- Destructive / Close Button
    DestructiveBg       = {0.3, 0.1, 0.1, 0.8},
    DestructiveBgHover  = {0.5, 0.15, 0.15, 1},
    DestructiveText     = {0.8, 0.3, 0.3},
    DestructiveTextHover = {1, 0.4, 0.4},

    -- Subtle Accents
    AccentSubtle    = {classColor.r * 0.3, classColor.g * 0.3, classColor.b * 0.3, 1},
    RowStripe       = {0.06, 0.06, 0.09},

    -- Status Colors
    StatusGood      = {0.3, 0.9, 0.3, 1},
    StatusWarning   = {1.0, 0.8, 0.2, 1},
    StatusBad       = {1.0, 0.3, 0.3, 1},

    -- Item Quality Colors
    QualityPoor     = {0.62, 0.62, 0.62},
    QualityCommon   = {1.00, 1.00, 1.00},
    QualityUncommon  = {0.12, 1.00, 0.00},
    QualityRare     = {0.00, 0.44, 0.87},
    QualityEpic     = {0.64, 0.21, 0.93},
    QualityLegendary = {1.00, 0.50, 0.00},

    -- Dimensions
    MainWidth       = 840,
    MainHeight      = 550,
    TabHeight       = 28,
    BottomTabHeight = 24,
    RowHeight       = 22,
    HeaderRowHeight = 24,
    RowTextIndent   = 22,
    IconSize        = 36,
    IconSizeSmall   = 24,
    BorderSize      = 1,
    Padding         = 10,
    SectionGap      = 8,

    -- Animations
    FadeInDuration  = 0.2,
    FadeOutDuration = 0.15,
}

local T = BCF.Tokens

-- ============================================================================
-- TYPOGRAPHY: Strip shadows and outlines from any FontString
-- Call after creating any FontString to ensure clean typography.
-- ============================================================================
function BCF.CleanFont(fontString)
    if not fontString then return fontString end
    fontString:SetShadowOffset(0, 0)
    fontString:SetShadowColor(0, 0, 0, 0)
    -- If the font has OUTLINE in its flags, re-set without it
    local fontFile, fontSize, fontFlags = fontString:GetFont()
    if fontFile and fontFlags and (fontFlags:find("OUTLINE") or fontFlags:find("THICKOUTLINE")) then
        fontString:SetFont(fontFile, fontSize, "")
    end
    return fontString
end

-- ============================================================================
-- TEXT HELPERS
-- ============================================================================

--- Pixel-aware text fitting: abbreviates at word boundaries to fit FontString width.
--- Uses GetStringWidth() vs GetWidth() so it works at any UI scale or layout.
function BCF.FitText(fontString, name)
    if not name or name == "" then fontString:SetText(""); return end
    fontString:SetText(name)
    local maxW = fontString:GetWidth()
    if maxW <= 0 or fontString:GetStringWidth() <= maxW then return end

    for i = #name, 1, -1 do
        if name:byte(i) == 32 then
            fontString:SetText(name:sub(1, i - 1) .. "...")
            if fontString:GetStringWidth() <= maxW then return end
        end
    end
    fontString:SetText("...")
end

-- ============================================================================
-- REUSABLE UI WIDGET FACTORIES
-- ============================================================================

-- --- Apply standard dark panel backdrop ---
function BCF.ApplyPanelStyle(frame, useLighter)
    local bg = useLighter and T.BackgroundLight or T.Background
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    frame:SetBackdropColor(unpack(bg))
end

-- --- Create a styled button ---
function BCF.CreateButton(parent, text, onClick, w, h)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w or 100, h or 26)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    btn:SetBackdropColor(0.12, 0.12, 0.16, 1)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("CENTER")
    btn.label:SetText(text)

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.5)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.12, 0.12, 0.16, 1)
    end)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- --- Create a styled checkbox ---
function BCF.CreateCheckbox(parent, labelText, initialValue, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(220, 24)

    local check = CreateFrame("CheckButton", nil, frame, "BackdropTemplate")
    check:SetSize(18, 18)
    check:SetPoint("LEFT", 0, 0)
    check:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    check:SetBackdropColor(0.08, 0.08, 0.12, 0.95)

    local checkmark = check:CreateTexture(nil, "ARTWORK")
    checkmark:SetSize(12, 12)
    checkmark:SetPoint("CENTER")
    checkmark:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    checkmark:Hide()

    check:SetScript("OnEnter", function()
        check:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 0.8)
    end)
    check:SetScript("OnLeave", function()
        if check:GetChecked() then
            check:SetBackdropColor(T.Accent[1]*0.4, T.Accent[2]*0.4, T.Accent[3]*0.4, 0.8)
        else
            check:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
        end
    end)

    check:SetScript("OnClick", function()
        local checked = check:GetChecked()
        if checked then
            checkmark:Show()
            check:SetBackdropColor(T.Accent[1]*0.4, T.Accent[2]*0.4, T.Accent[3]*0.4, 0.8)
        else
            checkmark:Hide()
            check:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
        end
        if onChange then onChange(checked) end
    end)

    check:SetChecked(initialValue)
    if initialValue then
        checkmark:Show()
        check:SetBackdropColor(T.Accent[1]*0.4, T.Accent[2]*0.4, T.Accent[3]*0.4, 0.8)
    end

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 8, 0)
    label:SetText(labelText)
    label:SetTextColor(0.9, 0.9, 0.9, 1)

    function frame:SetValue(val)
        check:SetChecked(val)
        if val then
            checkmark:Show()
            check:SetBackdropColor(T.Accent[1]*0.4, T.Accent[2]*0.4, T.Accent[3]*0.4, 0.8)
        else
            checkmark:Hide()
            check:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
        end
    end

    frame.check = check
    frame.label = label
    return frame
end

-- --- Create a red borderless close button ---
function BCF.CreateCloseButton(parent, size, onClick)
    size = size or 20
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    btn:SetBackdropColor(unpack(T.DestructiveBg))

    local label = BCF.CleanFont(btn:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    label:SetPoint("CENTER", 0, 0)
    label:SetText("x")
    label:SetTextColor(unpack(T.DestructiveText))
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(T.DestructiveBgHover))
        label:SetTextColor(unpack(T.DestructiveTextHover))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(T.DestructiveBg))
        label:SetTextColor(unpack(T.DestructiveText))
    end)
    btn:SetScript("OnClick", onClick)
    return btn
end

function BCF.ApplyRowStripe(row, rowIndex)
    local alpha = rowIndex % 2 == 0 and 0.5 or 0.3
    row:SetBackdropColor(T.RowStripe[1], T.RowStripe[2], T.RowStripe[3], alpha)
    return alpha
end

-- --- Position a dialog to the right of the main frame ---
function BCF.ShowRightOfMain(frame)
    frame:ClearAllPoints()
    if BCF.MainFrame then
        frame:SetPoint("TOPLEFT", BCF.MainFrame, "TOPRIGHT", 4, 0)
    else
        frame:SetPoint("CENTER")
    end
end

-- --- Quality color helper ---
function BCF.GetQualityColor(quality)
    if quality == 0 then return unpack(T.QualityPoor)
    elseif quality == 1 then return unpack(T.QualityCommon)
    elseif quality == 2 then return unpack(T.QualityUncommon)
    elseif quality == 3 then return unpack(T.QualityRare)
    elseif quality == 4 then return unpack(T.QualityEpic)
    elseif quality == 5 then return unpack(T.QualityLegendary)
    else return 1, 1, 1 end
end

function BCF.CreateRowPool(initRow, resetRow)
    local pool = {}
    local function GetRow(parent)
        local row = table.remove(pool)
        if not row then
            row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            row:SetHeight(T.RowHeight)
            row:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
            row.expandBtn = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.expandBtn:SetPoint("LEFT", 6, 0)
            row.expandBtn:SetText("+")
            row.expandBtn:SetTextColor(0.6, 0.6, 0.6)
            row.name = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
            row.name:SetPoint("LEFT", T.RowTextIndent, 0)
            row.name:SetJustifyH("LEFT")
            initRow(row)
        end
        row:SetParent(parent)
        row:Show()
        return row
    end
    local function ReleaseRow(row)
        row:Hide()
        row:ClearAllPoints()
        row:SetScript("OnMouseUp", nil)
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        resetRow(row)
        table.insert(pool, row)
    end
    return GetRow, ReleaseRow
end

-- ============================================================================
-- FONT CONFIGURATION
-- ============================================================================

local FONT_PATHS = {
    DEFAULT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
    FRIZQT  = "Fonts\\FRIZQT__.TTF",
    ARIALN  = "Fonts\\ARIALN.TTF",
    MORPHEUS = "Fonts\\MORPHEUS.ttf",
    SKURRI  = "Fonts\\skurri.ttf",
}

function BCF.GetFontPath(key)
    return FONT_PATHS[key] or FONT_PATHS.DEFAULT
end

-- Registry of FontStrings managed by the font system
-- group: "header", "items", "lists"
BCF.ManagedFonts = {}

function BCF.RegisterFont(fontString, group)
    group = group or "items"
    table.insert(BCF.ManagedFonts, {fs = fontString, group = group})
end

function BCF.ApplyAllFonts()
    if not BCF.DB then return end
    local G = BCF.DB.General
    local path = BCF.GetFontPath(G.FontFamily)
    local sizes = {
        header = G.FontSizeHeader or 14,
        items  = G.FontSizeItems or 11,
        lists  = G.FontSizeLists or 10,
    }
    for i = #BCF.ManagedFonts, 1, -1 do
        local entry = BCF.ManagedFonts[i]
        if entry.fs and entry.fs.GetFont then
            local sz = sizes[entry.group] or sizes.items
            entry.fs:SetFont(path, sz, "")
            BCF.CleanFont(entry.fs)
        else
            table.remove(BCF.ManagedFonts, i)
        end
    end
end

-- ============================================================================
-- CUSTOM SLIDER
-- ============================================================================

function BCF.CreateSlider(parent, labelText, minVal, maxVal, step, initial, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(220, 36)

    local label = BCF.CleanFont(frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(0.9, 0.9, 0.9, 1)

    -- Track background
    local track = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    track:SetSize(130, 6)
    track:SetPoint("BOTTOMLEFT", 0, 4)
    track:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    track:SetBackdropColor(0.08, 0.08, 0.12, 1)

    -- Thumb
    local thumb = CreateFrame("Button", nil, track, "BackdropTemplate")
    thumb:SetSize(12, 14)
    thumb:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    thumb:SetBackdropColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.9)

    -- Value label
    local valText = BCF.CleanFont(frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    valText:SetPoint("LEFT", track, "RIGHT", 8, 0)
    valText:SetTextColor(0.8, 0.8, 0.8, 1)

    local function SnapValue(raw)
        return math.floor(raw / step + 0.5) * step
    end

    local function SetValue(val)
        val = SnapValue(math.max(minVal, math.min(maxVal, val)))
        local pct = (val - minVal) / (maxVal - minVal)
        local trackW = track:GetWidth() - thumb:GetWidth()
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", track, "LEFT", pct * trackW, 0)
        if step >= 1 then
            valText:SetText(tostring(math.floor(val)))
        else
            valText:SetText(string.format("%.2f", val))
        end
        frame.value = val
    end

    SetValue(initial)

    -- Drag behavior
    local dragging = false
    thumb:SetScript("OnMouseDown", function() dragging = true end)
    thumb:SetScript("OnMouseUp", function()
        dragging = false
        if onChange then onChange(frame.value) end
    end)
    thumb:SetScript("OnUpdate", function()
        if not dragging then return end
        local cx = GetCursorPosition()
        local scale = track:GetEffectiveScale()
        local left = track:GetLeft() * scale
        local width = track:GetWidth() * scale - thumb:GetWidth() * scale
        local pct = math.max(0, math.min(1, (cx - left - thumb:GetWidth() * scale * 0.5) / width))
        local val = SnapValue(minVal + pct * (maxVal - minVal))
        SetValue(val)
    end)

    -- Click on track to jump
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function()
        local cx = GetCursorPosition()
        local scale = track:GetEffectiveScale()
        local left = track:GetLeft() * scale
        local width = track:GetWidth() * scale
        local pct = math.max(0, math.min(1, (cx - left) / width))
        local val = SnapValue(minVal + pct * (maxVal - minVal))
        SetValue(val)
        if onChange then onChange(frame.value) end
    end)

    -- Hover effects
    thumb:SetScript("OnEnter", function()
        thumb:SetBackdropColor(T.Accent[1], T.Accent[2], T.Accent[3], 1)
    end)
    thumb:SetScript("OnLeave", function()
        if not dragging then
            thumb:SetBackdropColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.9)
        end
    end)

    frame.SetValue = SetValue
    frame.slider = track
    frame.thumb = thumb
    frame.valueLabel = valText
    return frame
end

-- ============================================================================
-- CUSTOM DROPDOWN (taint-free, no UIDropDownMenuTemplate)
-- ============================================================================

function BCF.CreateDropdown(parent, labelText, options, initial, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(220, 36)

    local label = BCF.CleanFont(frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(0.9, 0.9, 0.9, 1)

    -- Button that shows current selection
    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetSize(130, 20)
    btn:SetPoint("BOTTOMLEFT", 0, 0)
    btn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    btn:SetBackdropColor(0.08, 0.08, 0.12, 1)

    local selText = BCF.CleanFont(btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    selText:SetPoint("LEFT", 6, 0)
    selText:SetJustifyH("LEFT")
    selText:SetTextColor(0.9, 0.9, 0.9, 1)

    local arrow = BCF.CleanFont(btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.6, 0.6, 0.6, 1)

    -- Dropdown list (parented to UIParent to escape ScrollFrame clipping)
    local list = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    list:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
    list:SetBackdropColor(0.06, 0.06, 0.10, 0.98)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetFrameLevel(200)
    list:SetSize(130, #options * 20 + 2)
    list:Hide()

    local listButtons = {}
    for i, opt in ipairs(options) do
        local item = CreateFrame("Button", nil, list, "BackdropTemplate")
        item:SetSize(128, 20)
        item:SetPoint("TOPLEFT", 1, -1 - (i - 1) * 20)
        item:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        item:SetBackdropColor(0, 0, 0, 0)

        local itemText = BCF.CleanFont(item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(opt.text)
        itemText:SetTextColor(0.8, 0.8, 0.8, 1)

        item:SetScript("OnEnter", function()
            item:SetBackdropColor(T.Accent[1], T.Accent[2], T.Accent[3], 0.4)
            itemText:SetTextColor(1, 1, 1, 1)
        end)
        item:SetScript("OnLeave", function()
            item:SetBackdropColor(0, 0, 0, 0)
            itemText:SetTextColor(0.8, 0.8, 0.8, 1)
        end)
        item:SetScript("OnClick", function()
            frame.selected = opt.value
            selText:SetText(opt.text)
            list:Hide()
            if onChange then onChange(opt.value, i) end
        end)
        listButtons[i] = item
    end

    -- Set initial value
    frame.selected = initial
    for _, opt in ipairs(options) do
        if opt.value == initial then
            selText:SetText(opt.text)
            break
        end
    end

    btn:SetScript("OnClick", function()
        if list:IsShown() then
            list:Hide()
        else
            list:ClearAllPoints()
            list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
            list:Show()
        end
    end)

    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(0.12, 0.12, 0.16, 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropColor(0.08, 0.08, 0.12, 1)
    end)

    -- Close list when clicking elsewhere
    list:SetScript("OnShow", function()
        list:SetScript("OnUpdate", function()
            if not MouseIsOver(list) and not MouseIsOver(btn) and IsMouseButtonDown("LeftButton") then
                list:Hide()
            end
        end)
    end)
    list:SetScript("OnHide", function()
        list:SetScript("OnUpdate", nil)
    end)

    frame.btn = btn
    frame.selText = selText
    frame.list = list
    frame.listButtons = listButtons
    frame.options = options
    return frame
end

function BCF.WireScrollbar(scrollFrame, scrollContent, slider, thumb, extraWheelTarget)
    local isUpdating = false

    local function OnScrollWheel(_, delta)
        if not slider:IsShown() then return end
        local cur = slider:GetValue()
        local step = 20
        slider:SetValue(delta > 0 and (cur - step) or (cur + step))
    end

    scrollFrame:SetScript("OnMouseWheel", OnScrollWheel)
    if extraWheelTarget then
        extraWheelTarget:EnableMouseWheel(true)
        extraWheelTarget:SetScript("OnMouseWheel", OnScrollWheel)
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if not isUpdating then
            isUpdating = true
            scrollFrame:SetVerticalScroll(value)
            isUpdating = false
        end
    end)

    scrollFrame:SetScript("OnScrollRangeChanged", function(self, _, yrange)
        if not yrange then yrange = 0 end
        if yrange <= 0.1 then
            slider:Hide()
            scrollFrame:SetVerticalScroll(0)
        else
            slider:Show()
            slider:SetMinMaxValues(0, yrange)
            local contentH = scrollContent:GetHeight()
            if contentH ~= thumb._lastContentH then
                thumb._lastContentH = contentH
                local ratio = scrollFrame:GetHeight() / contentH
                thumb:SetHeight(math.max(20, ratio * scrollFrame:GetHeight()))
            end
            if not isUpdating then
                isUpdating = true
                slider:SetValue(self:GetVerticalScroll())
                isUpdating = false
            end
        end
    end)
end
