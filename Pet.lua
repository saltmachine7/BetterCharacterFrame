local addonName, BCF = ...

-- ============================================================================
-- MODULE: Pet
-- ============================================================================

local T = BCF.Tokens
local CLASS_COLOR = {T.Accent[1], T.Accent[2], T.Accent[3]}

-- Happiness texture coords (from PetPaperDollFrame)
-- Texture: Interface\PetPaperDollFrame\UI-PetHappiness
local HAPPINESS_COORDS = {
    [1] = {0.375, 0.5625, 0, 0.359375},   -- Unhappy
    [2] = {0.1875, 0.375, 0, 0.359375},    -- Content
    [3] = {0, 0.1875, 0, 0.359375},        -- Happy
}

local HAPPINESS_COLORS = {
    [1] = {1.0, 0.3, 0.3},     -- Red
    [2] = {1.0, 0.8, 0.2},     -- Yellow
    [3] = {0.3, 1.0, 0.3},     -- Green
}

local HAPPINESS_LABELS = {
    [1] = "Unhappy",
    [2] = "Content",
    [3] = "Happy",
}

local STAT_IDS   = {1, 2, 3, 4, 5}
local STAT_NAMES = {"Strength", "Agility", "Stamina", "Intellect", "Spirit"}

local RESISTANCE_IDS   = {2, 3, 4, 5, 6}
local RESISTANCE_NAMES = {"Fire", "Nature", "Frost", "Shadow", "Arcane"}

local collapseState = {
    ["Base Stats"]   = false,
    ["Combat"]       = false,
    ["Resistances"]  = true,
}

-- ============================================================================
-- ROW POOL
-- ============================================================================
local GetRow, ReleaseRow = BCF.CreateRowPool(
    function(row)
        row.value = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        row.value:SetPoint("RIGHT", -8, 0)
        row.value:SetJustifyH("RIGHT")
    end,
    function(row)
        row.expandBtn:Hide()
        row.value:SetText("")
    end
)

-- ============================================================================
-- RENDER HELPERS
-- ============================================================================
local function RenderHeader(container, rows, yOffset, rowIndex, text, stateKey)
    local cc = CLASS_COLOR
    local row = GetRow(container)
    rowIndex = rowIndex + 1
    table.insert(rows, row)

    row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
    row:SetPoint("RIGHT", container, "RIGHT", -5, 0)
    row:SetBackdropColor(cc[1]*0.12, cc[2]*0.12, cc[3]*0.12, 0.9)

    row.expandBtn:Show()
    row.expandBtn:SetText(collapseState[stateKey] and "+" or "-")
    row.expandBtn:SetTextColor(cc[1], cc[2], cc[3])
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", T.RowTextIndent, 0)
    row.name:SetText(text)
    row.name:SetTextColor(cc[1], cc[2], cc[3])
    row.name:SetWidth(0)

    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            collapseState[stateKey] = not collapseState[stateKey]
            if BCF.PetScrollContent then BCF.RefreshPet(BCF.PetContainer) end
        end
    end)
    row:SetScript("OnEnter", function(self) self:SetBackdropColor(cc[1]*0.2, cc[2]*0.2, cc[3]*0.2, 1) end)
    row:SetScript("OnLeave", function(self) self:SetBackdropColor(cc[1]*0.12, cc[2]*0.12, cc[3]*0.12, 0.9) end)

    return yOffset - T.HeaderRowHeight, rowIndex
end

local function RenderStatRow(container, rows, yOffset, rowIndex, label, val, color)
    local row = GetRow(container)
    rowIndex = rowIndex + 1
    table.insert(rows, row)

    row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
    row:SetPoint("RIGHT", container, "RIGHT", -5, 0)
    local bgAlpha = BCF.ApplyRowStripe(row, rowIndex)
    row.expandBtn:Hide()

    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", 30, 0)
    row.name:SetText(label)
    row.name:SetTextColor(0.8, 0.8, 0.8)
    row.name:SetWidth(0)

    local c = color or {1, 1, 1}
    row.value:SetText(tostring(val or 0))
    row.value:SetTextColor(c[1], c[2], c[3])

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T.Accent[1]*0.1, T.Accent[2]*0.1, T.Accent[3]*0.1, 0.8)
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T.RowStripe[1], T.RowStripe[2], T.RowStripe[3], bgAlpha)
    end)

    return yOffset - T.HeaderRowHeight, rowIndex
end

-- ============================================================================
-- DATA LAYER (reads mock data when test active, real API otherwise)
-- ============================================================================
local function PetExists()
    if BCF._testPetActive and BCF._testPetData then return true end
    -- UnitExists("pet") covers all pet types: Hunter, Warlock, Mage Water Elemental
    -- HasPetUI() may be false briefly during summon, so check both independently
    return UnitExists("pet") or (HasPetUI and HasPetUI())
end

local function PetName()
    if BCF._testPetActive and BCF._testPetData then return BCF._testPetData.name end
    return UnitName("pet") or "Unknown"
end

local function PetLevel()
    if BCF._testPetActive and BCF._testPetData then return BCF._testPetData.level end
    return UnitLevel("pet") or "?"
end

local function PetFamily()
    if BCF._testPetActive and BCF._testPetData then return BCF._testPetData.family end
    return UnitCreatureFamily("pet") or ""
end

local function PetHappiness()
    if BCF._testPetActive and BCF._testPetData then return BCF._testPetData.happiness end
    return GetPetHappiness and GetPetHappiness() or nil
end

local function PetLoyalty()
    if BCF._testPetActive and BCF._testPetData then return BCF._testPetData.loyalty end
    return GetPetLoyalty and GetPetLoyalty() or ""
end

local function PetExperience()
    if BCF._testPetActive and BCF._testPetData then
        return BCF._testPetData.xp, BCF._testPetData.xpMax
    end
    if GetPetExperience then return GetPetExperience() end
    return 0, 1
end

local function PetTrainingPoints()
    if BCF._testPetActive and BCF._testPetData then
        return BCF._testPetData.tpTotal, BCF._testPetData.tpSpent
    end
    if GetPetTrainingPoints then return GetPetTrainingPoints() end
    return 0, 0
end

local function PetStat(statID)
    if BCF._testPetActive and BCF._testPetData then
        local s = BCF._testPetData.stats[statID] or {0,0,0,0}
        return s[1], s[2], s[3], s[4]
    end
    return UnitStat("pet", statID)
end

local function PetAttackPower()
    if BCF._testPetActive and BCF._testPetData then
        local a = BCF._testPetData.ap
        return a[1], a[2], a[3]
    end
    return UnitAttackPower("pet")
end

local function PetDamage()
    if BCF._testPetActive and BCF._testPetData then
        local d = BCF._testPetData.damage
        return d[1], d[2]
    end
    return UnitDamage("pet")
end

local function PetAttackSpeed()
    if BCF._testPetActive and BCF._testPetData then return BCF._testPetData.speed end
    return UnitAttackSpeed("pet")
end

local function PetArmor()
    if BCF._testPetActive and BCF._testPetData then
        local a = BCF._testPetData.armor
        return a[1], a[2]
    end
    return UnitArmor("pet")
end

local function PetResistance(resID)
    if BCF._testPetActive and BCF._testPetData then
        local r = BCF._testPetData.resistances[resID] or {0,0}
        return r[1], r[2]
    end
    return UnitResistance("pet", resID)
end

-- ============================================================================
-- DYNAMIC TAB INJECTION
-- ============================================================================
local function HasPetTab()
    if not BCF._headerTabNames then return false end
    for _, name in ipairs(BCF._headerTabNames) do
        if name == "Pet" then return true end
    end
    return false
end

function BCF.InjectPetTab()
    if HasPetTab() then return end
    if not BCF._headerTabNames then return end
    -- Insert Pet as second tab (after Character)
    table.insert(BCF._headerTabNames, 2, "Pet")
    if BCF.RebuildHeaderTabs then BCF.RebuildHeaderTabs() end
end

function BCF.RemovePetTab()
    if not HasPetTab() then return end
    if BCF._testPetActive then return end -- don't remove during test
    for i, name in ipairs(BCF._headerTabNames) do
        if name == "Pet" then
            table.remove(BCF._headerTabNames, i)
            break
        end
    end
    if BCF.RebuildHeaderTabs then BCF.RebuildHeaderTabs() end
end

-- ============================================================================
-- REFRESH PET
-- ============================================================================
function BCF.RefreshPet(container)
    if not container then return end

    -- If pet disappeared while tab is open, just hide everything
    if not PetExists() then
        if BCF.PetModel then BCF.PetModel:Hide() end
        if BCF.PetInfoBar then BCF.PetInfoBar:Hide() end
        if BCF.PetScrollFrame then BCF.PetScrollFrame:Hide() end
        if BCF.PetSlider then BCF.PetSlider:Hide() end
        return
    end

    if BCF.PetModel then
        BCF.PetModel:Show()
        -- Only set unit if real pet exists (test mode has no real model)
        if not BCF._testPetActive and UnitExists("pet") then
            BCF.PetModel:SetUnit("pet")
        end
    end
    if BCF.PetInfoBar then BCF.PetInfoBar:Show() end
    if BCF.PetScrollFrame then BCF.PetScrollFrame:Show() end

    -- === INFO BAR ===
    if BCF.PetNameText then
        BCF.PetNameText:SetText(PetName())
    end
    if BCF.PetLevelText then
        BCF.PetLevelText:SetText("Level " .. PetLevel() .. "  " .. PetFamily())
    end

    -- Happiness
    local happiness = PetHappiness()
    if BCF.PetHappyIcon and happiness and HAPPINESS_COORDS[happiness] then
        local coords = HAPPINESS_COORDS[happiness]
        BCF.PetHappyIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        BCF.PetHappyIcon:Show()
        local hc = HAPPINESS_COLORS[happiness]
        if BCF.PetHappyLabel then
            BCF.PetHappyLabel:SetText(HAPPINESS_LABELS[happiness] or "")
            BCF.PetHappyLabel:SetTextColor(hc[1], hc[2], hc[3])
        end
    elseif BCF.PetHappyIcon then
        BCF.PetHappyIcon:Hide()
        if BCF.PetHappyLabel then BCF.PetHappyLabel:SetText("") end
    end

    -- Loyalty
    if BCF.PetLoyaltyText then
        BCF.PetLoyaltyText:SetText(PetLoyalty())
    end

    -- XP bar
    if BCF.PetXPBar then
        local currXP, maxXP = PetExperience()
        maxXP = (maxXP and maxXP > 0) and maxXP or 1
        BCF.PetXPBar:SetMinMaxValues(0, maxXP)
        BCF.PetXPBar:SetValue(currXP or 0)
        if BCF.PetXPBarText then
            BCF.PetXPBarText:SetText(string.format("%d / %d XP", currXP or 0, maxXP))
        end
    end

    -- Training points (hunter pets only)
    if BCF.PetTPText then
        local _, class = UnitClass("player")
        if class == "HUNTER" and PetTrainingPoints then
            local totalTP, spent = PetTrainingPoints()
            local available = (totalTP or 0) - (spent or 0)
            BCF.PetTPText:SetText(string.format("TP: %d / %d", available, totalTP or 0))
            BCF.PetTPText:Show()
        else
            BCF.PetTPText:SetText("")
            BCF.PetTPText:Hide()
        end
    end

    -- === SCROLLABLE STATS ===
    local scrollContent = BCF.PetScrollContent
    if not scrollContent then return end

    local scrollFrame = scrollContent:GetParent()
    if scrollFrame then
        scrollContent:SetWidth(scrollFrame:GetWidth() - 5)
    end

    scrollContent.petRows = scrollContent.petRows or {}
    for _, row in ipairs(scrollContent.petRows) do
        ReleaseRow(row)
    end
    scrollContent.petRows = {}

    local yOffset = -5
    local rowIndex = 0
    local rows = scrollContent.petRows

    -- Base Stats
    yOffset, rowIndex = RenderHeader(scrollContent, rows, yOffset, rowIndex, "Base Stats", "Base Stats")
    if not collapseState["Base Stats"] then
        for i, statID in ipairs(STAT_IDS) do
            local base, stat, posBuff, negBuff = PetStat(statID)
            local val = stat or base or 0
            local color = nil
            if posBuff and posBuff > 0 then
                color = {0.3, 1, 0.3}
            elseif negBuff and negBuff < 0 then
                color = {1, 0.3, 0.3}
            end
            yOffset, rowIndex = RenderStatRow(scrollContent, rows, yOffset, rowIndex, STAT_NAMES[i], tostring(val), color)
        end
    end

    -- Combat
    yOffset, rowIndex = RenderHeader(scrollContent, rows, yOffset, rowIndex, "Combat", "Combat")
    if not collapseState["Combat"] then
        local apBase, apPosBuff, apNegBuff = PetAttackPower()
        local ap = (apBase or 0) + (apPosBuff or 0) + (apNegBuff or 0)
        yOffset, rowIndex = RenderStatRow(scrollContent, rows, yOffset, rowIndex,
            "Attack Power", tostring(ap), {CLASS_COLOR[1], CLASS_COLOR[2], CLASS_COLOR[3]})

        local minDmg, maxDmg = PetDamage()
        yOffset, rowIndex = RenderStatRow(scrollContent, rows, yOffset, rowIndex,
            "Damage", string.format("%.0f - %.0f", minDmg or 0, maxDmg or 0))

        local speed = PetAttackSpeed()
        yOffset, rowIndex = RenderStatRow(scrollContent, rows, yOffset, rowIndex,
            "Attack Speed", string.format("%.1f", speed or 0))

        local baseArmor, effectiveArmor = PetArmor()
        yOffset, rowIndex = RenderStatRow(scrollContent, rows, yOffset, rowIndex,
            "Armor", tostring(effectiveArmor or baseArmor or 0))
    end

    -- Resistances
    yOffset, rowIndex = RenderHeader(scrollContent, rows, yOffset, rowIndex, "Resistances", "Resistances")
    if not collapseState["Resistances"] then
        for i, resID in ipairs(RESISTANCE_IDS) do
            local base, total = PetResistance(resID)
            yOffset, rowIndex = RenderStatRow(scrollContent, rows, yOffset, rowIndex,
                RESISTANCE_NAMES[i], tostring(total or base or 0))
        end
    end

    scrollContent:SetHeight(math.abs(yOffset) + 10)
end

-- ============================================================================
-- PET EVENTS (dynamic tab injection + stat refresh)
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_PET")
eventFrame:RegisterEvent("PET_UI_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:RegisterEvent("PET_BAR_UPDATE")
eventFrame:RegisterEvent("UNIT_HAPPINESS")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    -- Filter unit-specific events
    if unit and unit ~= "pet" and unit ~= "player"
       and event ~= "PET_UI_UPDATE" and event ~= "PET_BAR_UPDATE"
       and event ~= "PLAYER_ENTERING_WORLD" then
        return
    end

    -- Dynamic tab: inject when pet exists, remove when gone
    local petActive = PetExists()
    if petActive then
        BCF.InjectPetTab()
    else
        BCF.RemovePetTab()
    end

    -- Refresh stats if pet tab is currently visible
    if BCF.PetContainer and BCF.PetContainer:IsShown() then
        BCF.RefreshPet(BCF.PetContainer)
    end
end)
