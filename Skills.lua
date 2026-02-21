local addonName, BCF = ...

-- ============================================================================
-- MODULE: Skills
-- ============================================================================

local T = BCF.Tokens

local CLASS_COLOR = {T.Accent[1], T.Accent[2], T.Accent[3]}

-- Locale-independent category detection by encounter order.
-- WoW returns skill headers in the same order for all locales:
-- 1: Class Skills, 2: Professions, 3: Secondary Skills,
-- 4: Weapon Skills, 5: Armor Proficiencies, 6: Languages
local HEADER_BY_INDEX = {
    { sort = 5, maxRank = nil,  collapse = true  }, -- 1: Class Skills
    { sort = 1, maxRank = 375,  collapse = false }, -- 2: Professions
    { sort = 2, maxRank = 375,  collapse = false }, -- 3: Secondary Skills
    { sort = 3, maxRank = 350,  collapse = false }, -- 4: Weapon Skills
    { sort = 4, maxRank = nil,  collapse = true  }, -- 5: Armor Proficiencies
    { sort = 6, maxRank = 300,  collapse = true  }, -- 6: Languages
}

-- Built at scan time: localized header name -> properties
local headerProps = {}

-- Collapse state persisted to BCF.DB.Skills.Collapsed
local function GetCollapseState()
    if not BCF.DB or not BCF.DB.Skills then return {} end
    local cs = BCF.DB.Skills.Collapsed
    for name, props in pairs(headerProps) do
        if cs[name] == nil then
            cs[name] = props.collapse or false
        end
    end
    return cs
end

-- Skill name -> icon texture path
local SKILL_ICONS = {
    -- Primary Professions
    ["Alchemy"]           = "Interface\\Icons\\Trade_Alchemy",
    ["Blacksmithing"]     = "Interface\\Icons\\Trade_BlackSmithing",
    ["Enchanting"]        = "Interface\\Icons\\Trade_Engraving",
    ["Engineering"]       = "Interface\\Icons\\Trade_Engineering",
    ["Herbalism"]         = "Interface\\Icons\\Trade_Herbalism",
    ["Jewelcrafting"]     = "Interface\\Icons\\INV_Misc_Gem_01",
    ["Leatherworking"]    = "Interface\\Icons\\INV_Misc_ArmorKit_17",
    ["Mining"]            = "Interface\\Icons\\Trade_Mining",
    ["Skinning"]          = "Interface\\Icons\\INV_Weapon_ShortBlade_01",
    ["Tailoring"]         = "Interface\\Icons\\Trade_Tailoring",
    -- Secondary Skills
    ["Cooking"]           = "Interface\\Icons\\INV_Misc_Food_15",
    ["First Aid"]         = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    ["Fishing"]           = "Interface\\Icons\\Trade_Fishing",
    -- Weapon Skills
    ["Axes"]              = "Interface\\Icons\\INV_Axe_01",
    ["Bows"]              = "Interface\\Icons\\INV_Weapon_Bow_07",
    ["Crossbows"]         = "Interface\\Icons\\INV_Weapon_Crossbow_01",
    ["Daggers"]           = "Interface\\Icons\\INV_Weapon_ShortBlade_04",
    ["Defense"]           = "Interface\\Icons\\INV_Shield_06",
    ["Fist Weapons"]      = "Interface\\Icons\\INV_Gauntlets_04",
    ["Guns"]              = "Interface\\Icons\\INV_Weapon_Rifle_01",
    ["Maces"]             = "Interface\\Icons\\INV_Hammer_05",
    ["Polearms"]          = "Interface\\Icons\\INV_Spear_07",
    ["Riding"]            = "Interface\\Icons\\Ability_Mount_Ridinghorse",
    ["Staves"]            = "Interface\\Icons\\INV_Staff_08",
    ["Swords"]            = "Interface\\Icons\\INV_Sword_04",
    ["Thrown"]            = "Interface\\Icons\\INV_ThrowingKnife_03",
    ["Two-Handed Axes"]   = "Interface\\Icons\\INV_Axe_09",
    ["Two-Handed Maces"]  = "Interface\\Icons\\INV_Hammer_09",
    ["Two-Handed Swords"] = "Interface\\Icons\\INV_Sword_07",
    ["Unarmed"]           = "Interface\\Icons\\INV_Gauntlets_05",
    ["Wands"]             = "Interface\\Icons\\INV_Wand_01",
    -- Armor Proficiencies
    ["Cloth"]             = "Interface\\Icons\\INV_Chest_Cloth_21",
    ["Leather"]           = "Interface\\Icons\\INV_Chest_Leather_09",
    ["Mail"]              = "Interface\\Icons\\INV_Chest_Chain_05",
    ["Plate Mail"]        = "Interface\\Icons\\INV_Chest_Plate16",
    ["Shield"]            = "Interface\\Icons\\INV_Shield_04",
    -- Languages resolved via spell IDs at runtime (no hardcoded paths)
}

-- Language spell IDs for icon resolution
local LANGUAGE_SPELL_IDS = {
    ["Common"]      = 668,
    ["Orcish"]      = 669,
    ["Taurahe"]     = 670,
    ["Darnassian"]  = 671,
    ["Dwarvish"]    = 672,
    ["Thalassian"]  = 813,
    ["Gnomish"]     = 7340,
    ["Gutterspeak"] = 17737,
    ["Forsaken"]    = 17737,
    ["Zandali"]     = 7341,
    ["Troll"]       = 7341,
    ["Demonic"]     = 815,
    ["Draconic"]    = 814,
    ["Titan"]       = 816,
    ["Draenei"]     = 29932,
}
for lang, spellID in pairs(LANGUAGE_SPELL_IDS) do
    local _, _, icon = GetSpellInfo(spellID)
    if icon and icon ~= 0 then SKILL_ICONS[lang] = icon end
end

-- Class Specialization Icons (hardcoded per-class fallbacks)
local _, playerClass = UnitClass("player")
local CLASS_SPEC_ICONS = {
    MAGE    = {["Arcane"] = "Interface\\Icons\\Spell_Holy_MagicalSentry",
               ["Fire"]   = "Interface\\Icons\\Spell_Fire_FlameBolt",
               ["Frost"]  = "Interface\\Icons\\Spell_Frost_FrostBolt02"},
    WARRIOR = {["Arms"]       = "Interface\\Icons\\Ability_Rogue_Eviscerate",
               ["Fury"]       = "Interface\\Icons\\Ability_Warrior_InnerRage",
               ["Protection"] = "Interface\\Icons\\Ability_Warrior_DefensiveStance"},
    ROGUE   = {["Assassination"] = "Interface\\Icons\\Ability_Rogue_Eviscerate",
               ["Combat"]        = "Interface\\Icons\\Ability_BackStab",
               ["Subtlety"]      = "Interface\\Icons\\Ability_Stealth"},
    PRIEST  = {["Discipline"] = "Interface\\Icons\\Spell_Holy_WordFortitude",
               ["Holy"]        = "Interface\\Icons\\Spell_Holy_HolyBolt",
               ["Shadow"]      = "Interface\\Icons\\Spell_Shadow_ShadowWordPain"},
    PALADIN = {["Holy"]        = "Interface\\Icons\\Spell_Holy_HolyBolt",
               ["Protection"]  = "Interface\\Icons\\Spell_Holy_DevotionAura",
               ["Retribution"] = "Interface\\Icons\\Spell_Holy_AuraOfLight"},
    HUNTER  = {["Beast Mastery"] = "Interface\\Icons\\Ability_Hunter_BeastTaming",
               ["Marksmanship"]  = "Interface\\Icons\\Ability_Marksmanship",
               ["Survival"]      = "Interface\\Icons\\Ability_Hunter_SwiftStrike"},
    WARLOCK = {["Affliction"]  = "Interface\\Icons\\Spell_Shadow_DeathCoil",
               ["Demonology"]  = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
               ["Destruction"] = "Interface\\Icons\\Spell_Shadow_RainOfFire"},
    SHAMAN  = {["Elemental"]   = "Interface\\Icons\\Spell_Nature_Lightning",
               ["Enhancement"] = "Interface\\Icons\\Spell_Nature_LightningShield",
               ["Restoration"] = "Interface\\Icons\\Spell_Nature_MagicImmunity"},
    DRUID   = {["Balance"]      = "Interface\\Icons\\Spell_Nature_StarFall",
               ["Feral Combat"] = "Interface\\Icons\\Ability_Racial_BearForm",
               ["Restoration"]  = "Interface\\Icons\\Spell_Nature_HealingTouch"},
}
if CLASS_SPEC_ICONS[playerClass] then
    for name, icon in pairs(CLASS_SPEC_ICONS[playerClass]) do
        SKILL_ICONS[name] = SKILL_ICONS[name] or icon
    end
end

-- Bar color by global completion % (item quality style: white -> green -> blue -> purple)
local function GetBarColor(pct)
    if pct < 0.25 then
        local t = pct / 0.25
        return 1 - 0.85*t, 1 - 0.8*t, 1 - 0.85*t
    elseif pct < 0.5 then
        local t = (pct - 0.25) / 0.25
        return 0.15 + 0.05*t, 0.2 + 0.4*t, 0.15 + 0.85*t
    elseif pct < 0.75 then
        local t = (pct - 0.5) / 0.25
        return 0.2 + 0.43*t, 0.6 - 0.26*t, 1 - 0.17*t
    else
        local t = (pct - 0.75) / 0.25
        return 0.63 + 0.0*t, 0.34 + 0.0*t, 0.83 + 0.0*t
    end
end

-- Rank label text (mirrors reputation standing labels)
local function GetSkillRankLabel(maxRank, sortOrder)
    if maxRank <= 0 then return nil end
    if sortOrder == 1 or sortOrder == 2 then
        if maxRank >= 375 then return "Master"
        elseif maxRank >= 300 then return "Artisan"
        elseif maxRank >= 225 then return "Expert"
        elseif maxRank >= 150 then return "Journeyman"
        else return "Apprentice" end
    end
    if sortOrder == 3 then
        return tostring(maxRank)
    end
    return nil
end

-- ============================================================================
-- ROW POOL
-- ============================================================================
local GetRow, ReleaseRow = BCF.CreateRowPool(
    function(row)
        row.iconTex = row:CreateTexture(nil, "ARTWORK")
        row.iconTex:SetSize(16, 16)
        row.iconTex:SetPoint("LEFT", 6, 0)
        row.iconTex:Hide()

        row.unlearnBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
        row.unlearnBtn:SetSize(14, 14)
        row.unlearnBtn:SetPoint("RIGHT", -8, 0)
        row.unlearnBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        row.unlearnBtn:SetBackdropColor(0.3, 0.1, 0.1, 0.6)
        local unlearnX = BCF.CleanFont(row.unlearnBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
        unlearnX:SetPoint("CENTER", 0, 1)
        unlearnX:SetText("x")
        unlearnX:SetTextColor(unpack(T.DestructiveText))
        row.unlearnBtn.label = unlearnX
        row.unlearnBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(T.DestructiveBgHover))
            self.label:SetTextColor(unpack(T.DestructiveTextHover))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Unlearn this skill", 1, 1, 1)
            GameTooltip:Show()
        end)
        row.unlearnBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T.DestructiveBg[1], T.DestructiveBg[2], T.DestructiveBg[3], 0.6)
            self.label:SetTextColor(unpack(T.DestructiveText))
            GameTooltip:Hide()
        end)
        row.unlearnBtn:Hide()

        row.barBg = CreateFrame("StatusBar", nil, row)
        row.barBg:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
        row.barBg:SetPoint("RIGHT", row, "RIGHT", -8, 0)
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

        row.rankLabel = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        row.rankLabel:SetPoint("RIGHT", -8, 0)
        row.rankLabel:SetJustifyH("RIGHT")
        row.rankLabel:SetWidth(75)
    end,
    function(row)
        row.unlearnBtn:SetScript("OnClick", nil)
        row.unlearnBtn:Hide()
        row.iconTex:Hide()
        row.rankLabel:SetText("")
        row.rankLabel:Hide()
    end
)

-- ============================================================================
-- CONFIRMATION DIALOG
-- ============================================================================
local confirmDialog = CreateFrame("Frame", "BCFSkillConfirm", UIParent, "BackdropTemplate")
confirmDialog:SetSize(280, 120)
confirmDialog:SetFrameStrata("DIALOG")
confirmDialog:SetPoint("CENTER")
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
confirmYesText:SetText("Unlearn")
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

-- ============================================================================
-- REFRESH HELPERS
-- ============================================================================
local isRefreshing = false

local function ShowUnlearnConfirm(skillName)
    confirmText:SetText("Unlearn |cffffffff" .. skillName .. "|r?")
    confirmYes:SetScript("OnClick", function()
        -- Expand all headers to find current index by name
        isRefreshing = true
        for i = GetNumSkillLines(), 1, -1 do
            local name, header, expanded = GetSkillLineInfo(i)
            if header and not expanded then
                ExpandSkillHeader(i)
            end
        end
        for i = 1, GetNumSkillLines() do
            local name, header = GetSkillLineInfo(i)
            if name == skillName and not header then
                AbandonSkill(i)
                break
            end
        end
        isRefreshing = false
        confirmDialog:Hide()
        if BCF.SkillsContent then
            BCF.RefreshSkills(BCF.SkillsContent)
        end
    end)
    BCF.ShowRightOfMain(confirmDialog)
    confirmDialog:Show()
end

-- ============================================================================
-- REFRESH SKILLS LIST
-- ============================================================================
function BCF.RefreshSkills(container)
    if not container then return end

    local scrollFrame = container:GetParent()
    if scrollFrame then
        container:SetWidth(scrollFrame:GetWidth() - 5)
    end

    -- Release existing rows
    container.skillRows = container.skillRows or {}
    for _, row in ipairs(container.skillRows) do
        ReleaseRow(row)
    end
    container.skillRows = {}

    isRefreshing = true

    -- Expand all WoW headers to get full skill data
    local wasCollapsed = {}
    for i = GetNumSkillLines(), 1, -1 do
        local name, isHeader, isExpanded = GetSkillLineInfo(i)
        if isHeader and not isExpanded then
            wasCollapsed[name] = true
            ExpandSkillHeader(i)
        end
    end

    -- Collect skills grouped by header
    local categories = {}
    local categoryList = {}
    local currentHeader = nil
    local headerCount = 0
    headerProps = {}

    for i = 1, GetNumSkillLines() do
        local skillName, isHeader, _, skillRank, numTempPoints,
              skillModifier, skillMaxRank, isAbandonable = GetSkillLineInfo(i)

        if skillName then
            if isHeader then
                currentHeader = skillName
                if not categories[currentHeader] then
                    categories[currentHeader] = {}
                    table.insert(categoryList, currentHeader)
                    headerCount = headerCount + 1
                    headerProps[currentHeader] = HEADER_BY_INDEX[headerCount] or { sort = 99, maxRank = nil, collapse = false }
                end
            elseif currentHeader then
                table.insert(categories[currentHeader], {
                    name = skillName,
                    rank = skillRank,
                    modifier = skillModifier,
                    maxRank = skillMaxRank,
                    abandonable = isAbandonable,
                })
            end
        end
    end

    -- Restore WoW collapse state
    for i = GetNumSkillLines(), 1, -1 do
        local name, isHeader = GetSkillLineInfo(i)
        if isHeader and wasCollapsed[name] then
            CollapseSkillHeader(i)
        end
    end

    isRefreshing = false

    -- Sort categories by priority (locale-independent)
    table.sort(categoryList, function(a, b)
        local sa = headerProps[a] and headerProps[a].sort or 99
        local sb = headerProps[b] and headerProps[b].sort or 99
        return sa < sb
    end)

    -- Build class spec icon map from talent tabs
    local classSpecIcons = {}
    for i = 1, GetNumTalentTabs() do
        local tabName, iconTexture = GetTalentTabInfo(i)
        if tabName and iconTexture then
            classSpecIcons[tabName] = iconTexture
        end
    end

    -- Render
    local yOffset = -5
    local rowIndex = 0
    local cc = CLASS_COLOR
    local cs = GetCollapseState()

    for _, headerName in ipairs(categoryList) do
        local skills = categories[headerName]
        local props = headerProps[headerName]
        local isCollapsed = cs[headerName]
        local globalMax = props and props.maxRank

        -- Header row
        local row = GetRow(container)
        rowIndex = rowIndex + 1
        table.insert(container.skillRows, row)

        row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
        row:SetPoint("RIGHT", container, "RIGHT", -5, 0)

        row:SetBackdropColor(cc[1]*0.12, cc[2]*0.12, cc[3]*0.12, 0.9)
        row.expandBtn:Show()
        row.expandBtn:SetText(isCollapsed and "+" or "-")
        row.expandBtn:SetTextColor(cc[1], cc[2], cc[3])
        row.iconTex:Hide()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", T.RowTextIndent, 0)
        row.name:SetText(headerName)
        row.name:SetTextColor(cc[1], cc[2], cc[3])
        row.name:SetWidth(0)
        row.barBg:Hide()
        row.progress:Hide()
        row.rankLabel:SetText("")
        row.rankLabel:Hide()
        row.unlearnBtn:Hide()

        row:EnableMouse(true)
        local hName = headerName
        row:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" then
                cs[hName] = not cs[hName]
                BCF.RefreshSkills(container)
            end
        end)
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(cc[1]*0.2, cc[2]*0.2, cc[3]*0.2, 1)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(cc[1]*0.12, cc[2]*0.12, cc[3]*0.12, 0.9)
        end)

        yOffset = yOffset - T.HeaderRowHeight

        -- Skill rows (if expanded)
        if not isCollapsed then
            for _, skill in ipairs(skills) do
                local colorMax = (globalMax and globalMax > 0) and globalMax or (skill.maxRank > 0 and skill.maxRank or 1)
                local colorPct = skill.rank / colorMax
                local fillPct = skill.maxRank > 0 and (skill.rank / skill.maxRank) or 1
                local qr, qg, qb = GetBarColor(colorPct)

                local srow = GetRow(container)
                rowIndex = rowIndex + 1
                table.insert(container.skillRows, srow)

                srow:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
                srow:SetPoint("RIGHT", container, "RIGHT", -5, 0)
                local bgAlpha = BCF.ApplyRowStripe(srow, rowIndex)
                srow.expandBtn:Hide()

                -- Icon (includes class spec talent tree icons)
                local icon = SKILL_ICONS[skill.name] or classSpecIcons[skill.name] or select(3, GetSpellInfo(skill.name))
                if icon then
                    srow.iconTex:SetTexture(icon)
                    srow.iconTex:Show()
                else
                    srow.iconTex:Hide()
                end

                -- Name (hardcoded LEFT+28 to match rep star+name layout exactly)
                srow.name:ClearAllPoints()
                srow.name:SetPoint("LEFT", 28, 0)
                srow.name:SetText(skill.name)
                srow.name:SetTextColor(qr, qg, qb)
                srow.name:SetWidth(120)

                -- Rank label always at fixed position (consistent bar width)
                local rankText = GetSkillRankLabel(skill.maxRank, props and props.sort)
                srow.rankLabel:ClearAllPoints()
                srow.rankLabel:SetPoint("RIGHT", srow, "RIGHT", -8, 0)

                -- Unlearn button (inside rank label area, left edge)
                if skill.abandonable then
                    srow.unlearnBtn:ClearAllPoints()
                    srow.unlearnBtn:SetPoint("LEFT", srow.rankLabel, "LEFT", 0, 0)
                    srow.unlearnBtn:Show()
                    local sn = skill.name
                    srow.unlearnBtn:SetScript("OnClick", function()
                        ShowUnlearnConfirm(sn)
                    end)
                else
                    srow.unlearnBtn:Hide()
                end
                if rankText then
                    srow.rankLabel:SetText(rankText)
                    srow.rankLabel:SetTextColor(qr, qg, qb)
                else
                    srow.rankLabel:SetText("")
                end
                srow.rankLabel:Show()

                -- Bar (between name and rank label, matching rep layout)
                srow.barBg:ClearAllPoints()
                srow.barBg:SetPoint("LEFT", srow.name, "RIGHT", 10, 0)
                srow.barBg:SetPoint("RIGHT", srow.rankLabel, "LEFT", -10, 0)
                srow.barBg:SetHeight(10)

                -- Progress bar
                if skill.maxRank > 0 then
                    srow.barBg:Show()
                    srow.barBg:SetStatusBarColor(qr, qg, qb, 0.8)
                    srow.barBg:SetValue(fillPct)
                    srow.progress:Show()
                    if skill.modifier and skill.modifier > 0 then
                        srow.progress:SetText(string.format("%d (+%d) / %d", skill.rank, skill.modifier, skill.maxRank))
                    else
                        srow.progress:SetText(string.format("%d / %d", skill.rank, skill.maxRank))
                    end
                else
                    srow.barBg:Hide()
                    srow.progress:Hide()
                end

                -- Hover
                srow:EnableMouse(true)
                local skillName = skill.name
                local rankStr
                if skill.maxRank > 0 then
                    if skill.modifier and skill.modifier > 0 then
                        rankStr = string.format("%d (+%d) / %d", skill.rank, skill.modifier, skill.maxRank)
                    else
                        rankStr = string.format("%d / %d", skill.rank, skill.maxRank)
                    end
                else
                    rankStr = tostring(skill.rank)
                end
                local isAbandonable = skill.abandonable

                srow:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(qr*0.1, qg*0.1, qb*0.1, 0.8)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(skillName, 1, 1, 1)
                    if skill.maxRank > 0 then
                        GameTooltip:AddLine(rankStr, qr, qg, qb)
                    end
                    if isAbandonable then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine("Can be unlearned", 0.8, 0.5, 0.5)
                    end
                    GameTooltip:Show()
                end)
                srow:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(T.RowStripe[1], T.RowStripe[2], T.RowStripe[3], bgAlpha)
                    GameTooltip:Hide()
                end)

                yOffset = yOffset - T.HeaderRowHeight
            end
        end
    end

    container:SetHeight(math.abs(yOffset) + 10)
end

-- ============================================================================
-- SKILL UPDATE EVENT
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
BCF.skillsEventFrame = eventFrame

eventFrame:SetScript("OnEvent", function()
    if isRefreshing then return end
    if BCF.SkillsContent and BCF.SkillsContainer and BCF.SkillsContainer:IsShown() then
        BCF.RefreshSkills(BCF.SkillsContent)
    end
end)
