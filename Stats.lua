local addonName, BCF = ...

-- ============================================================================
-- MODULE: Stats
-- ============================================================================

local T = BCF.Tokens

-- --- TipTac GearScore Quality Colors (Exact TacoTip v0.4.3 gradient formula) ---
-- For TBC Anniversary: BRACKET_SIZE = 400
local GS_BRACKET_SIZE = 400
local GS_MAX_SCORE = GS_BRACKET_SIZE * 6 - 1 -- 2399

-- GS_Quality table with gradient formulas per bracket (from TipTac/LibFroznFunctions)
-- Note: TipTac swaps Blue/Green channels intentionally
local GS_Quality = {
    [GS_BRACKET_SIZE*6] = { -- 2400: Legendary (orange)
        Red   = { A = 0.94, B = GS_BRACKET_SIZE*5, C = 0.00006, D = 1 },
        Blue  = { A = 0.47, B = GS_BRACKET_SIZE*5, C = 0.00047, D = -1 },
        Green = { A = 0, B = 0, C = 0, D = 0 },
    },
    [GS_BRACKET_SIZE*5] = { -- 2000: Epic (purple)
        Red   = { A = 0.69, B = GS_BRACKET_SIZE*4, C = 0.00025, D = 1 },
        Blue  = { A = 0.28, B = GS_BRACKET_SIZE*4, C = 0.00019, D = 1 },
        Green = { A = 0.97, B = GS_BRACKET_SIZE*4, C = 0.00096, D = -1 },
    },
    [GS_BRACKET_SIZE*4] = { -- 1600: Superior (blue)
        Red   = { A = 0.0, B = GS_BRACKET_SIZE*3, C = 0.00069, D = 1 },
        Blue  = { A = 0.5, B = GS_BRACKET_SIZE*3, C = 0.00022, D = -1 },
        Green = { A = 1, B = GS_BRACKET_SIZE*3, C = 0.00003, D = -1 },
    },
    [GS_BRACKET_SIZE*3] = { -- 1200: Uncommon (green)
        Red   = { A = 0.12, B = GS_BRACKET_SIZE*2, C = 0.00012, D = -1 },
        Blue  = { A = 1, B = GS_BRACKET_SIZE*2, C = 0.00050, D = -1 },
        Green = { A = 0, B = GS_BRACKET_SIZE*2, C = 0.001, D = 1 },
    },
    [GS_BRACKET_SIZE*2] = { -- 800: Common (white)
        Red   = { A = 1, B = GS_BRACKET_SIZE, C = 0.00088, D = -1 },
        Blue  = { A = 1, B = 0, C = 0, D = 0 },
        Green = { A = 1, B = GS_BRACKET_SIZE, C = 0.001, D = -1 },
    },
    [GS_BRACKET_SIZE] = { -- 400: Trash (grey)
        Red   = { A = 0.55, B = 0, C = 0.00045, D = 1 },
        Blue  = { A = 0.55, B = 0, C = 0.00045, D = 1 },
        Green = { A = 0.55, B = 0, C = 0.00045, D = 1 },
    },
}

-- Returns r, g, b based on GearScore using TipTac gradient formula
-- Exposed as BCF.GetGearScoreQualityColor for use in GUI.lua
local function GetGearScoreQualityColor(gs)
    gs = tonumber(gs) or 0
    if gs > GS_MAX_SCORE then gs = GS_MAX_SCORE end

    -- Find which bracket the score falls into
    for i = 0, 5 do
        local bracketMin = i * GS_BRACKET_SIZE
        local bracketMax = (i + 1) * GS_BRACKET_SIZE
        if gs > bracketMin and gs <= bracketMax then
            local q = GS_Quality[bracketMax]
            if q then
                -- TipTac formula: Color = A + ((Score - B) * C * D)
                local r = q.Red.A + ((gs - q.Red.B) * q.Red.C * q.Red.D)
                local g = q.Blue.A + ((gs - q.Blue.B) * q.Blue.C * q.Blue.D)
                local b = q.Green.A + ((gs - q.Green.B) * q.Green.C * q.Green.D)
                return r, g, b
            end
        end
    end
    -- Fallback for score = 0 or very low
    return 0.55, 0.55, 0.55
end
BCF.GetGearScoreQualityColor = GetGearScoreQualityColor

-- Returns r, g, b based on average item level (simple thresholds, matches item quality colors)
local function GetILevelQualityColor(avgILevel)
    if avgILevel < 70 then
        return unpack(T.QualityPoor)      -- Grey
    elseif avgILevel < 105 then
        return unpack(T.QualityCommon)    -- White
    elseif avgILevel < 115 then
        return unpack(T.QualityUncommon)  -- Green
    elseif avgILevel < 130 then
        return unpack(T.QualityRare)      -- Blue
    else
        return unpack(T.QualityEpic)      -- Purple
    end
end

-- --- Combat Rating Constants (TBC 2.4.3) ---
-- These are the CR_ constants available in TBC
local CR = {
    WEAPON_SKILL        = 1,   -- CR_WEAPON_SKILL
    DEFENSE_SKILL       = 2,   -- CR_DEFENSE_SKILL
    DODGE               = 3,   -- CR_DODGE
    PARRY               = 4,   -- CR_PARRY
    BLOCK               = 5,   -- CR_BLOCK
    HIT_MELEE           = 6,   -- CR_HIT_MELEE
    HIT_RANGED          = 7,   -- CR_HIT_RANGED
    HIT_SPELL           = 8,   -- CR_HIT_SPELL
    CRIT_MELEE          = 9,   -- CR_CRIT_MELEE
    CRIT_RANGED         = 10,  -- CR_CRIT_RANGED
    CRIT_SPELL          = 11,  -- CR_CRIT_SPELL
    HIT_TAKEN_MELEE     = 12,
    HIT_TAKEN_RANGED    = 13,
    HIT_TAKEN_SPELL     = 14,
    CRIT_TAKEN_MELEE    = 15,
    CRIT_TAKEN_RANGED   = 16,
    CRIT_TAKEN_SPELL    = 17,
    HASTE_MELEE         = 18,  -- CR_HASTE_MELEE
    HASTE_RANGED        = 19,  -- CR_HASTE_RANGED
    HASTE_SPELL         = 20,  -- CR_HASTE_SPELL
    WEAPON_SKILL_MAINHAND = 21,
    WEAPON_SKILL_OFFHAND  = 22,
    WEAPON_SKILL_RANGED   = 23,
    EXPERTISE           = 24,  -- CR_EXPERTISE
    ARMOR_PENETRATION   = 25,
}
BCF.CR = CR

-- --- Stat Index Constants ---
local STAT_STR = 1
local STAT_AGI = 2
local STAT_STA = 3
local STAT_INT = 4
local STAT_SPI = 5

-- --- Role Detection via Talent Trees ---
-- Returns: "melee_dps", "ranged_dps", "caster_dps", "healer", "tank"
-- Count talent points in a tab via individual talents
local function CountTabPoints(tabIndex)
    local points = 0
    for i = 1, (GetNumTalents(tabIndex) or 0) do
        local _, _, _, _, rank = GetTalentInfo(tabIndex, i)
        points = points + (tonumber(rank) or 0)
    end
    return points
end

-- Get talent tab name (handles both Classic and Anniversary API)
local function GetTabSpecName(tabIndex)
    local r1, r2 = GetTalentTabInfo(tabIndex)
    if type(r1) == "string" and r1 ~= "" then return r1 end
    if type(r2) == "string" and r2 ~= "" then return r2 end
    return ""
end

function BCF.DetectRole()
    local _, playerClass = UnitClass("player")
    local numTabs = GetNumTalentTabs()
    local tabPoints = {}

    for i = 1, numTabs do
        tabPoints[i] = CountTabPoints(i)
    end

    -- Find primary tree (most points)
    local primaryTab = 1
    for i = 2, numTabs do
        if tabPoints[i] > tabPoints[primaryTab] then
            primaryTab = i
        end
    end

    -- Class-specific role mapping
    -- Tab order: 1, 2, 3
    local roleMap = {
        WARRIOR     = {"melee_dps", "melee_dps", "tank"},      -- Arms, Fury, Protection
        PALADIN     = {"healer", "tank", "melee_dps"},          -- Holy, Protection, Retribution
        HUNTER      = {"ranged_dps", "ranged_dps", "ranged_dps"}, -- BM, MM, Survival
        ROGUE       = {"melee_dps", "melee_dps", "melee_dps"},  -- Assassination, Combat, Subtlety
        PRIEST      = {"healer", "healer", "caster_dps"},       -- Discipline, Holy, Shadow
        SHAMAN      = {"caster_dps", "melee_dps", "healer"},    -- Elemental, Enhancement, Restoration
        MAGE        = {"caster_dps", "caster_dps", "caster_dps"}, -- Arcane, Fire, Frost
        WARLOCK     = {"caster_dps", "caster_dps", "caster_dps"}, -- Affliction, Demonology, Destruction
        DRUID       = {"caster_dps", "melee_dps", "healer"},    -- Balance, Feral, Restoration
    }

    -- Enhancement Shaman override
    if playerClass == "SHAMAN" and primaryTab == 2 then
        return "melee_dps"
    end

    -- Feral Druid: check if bear or cat (look for thick hide / survival of fittest talents)
    if playerClass == "DRUID" and primaryTab == 2 then
        -- Simple heuristic: if they have heavy points in Restoration too, likely tank
        -- Otherwise default to melee_dps (cat)
        return "melee_dps"
    end

    local roles = roleMap[playerClass]
    if roles then
        return roles[primaryTab] or "melee_dps"
    end

    return "melee_dps" -- fallback
end

-- ============================================================================
-- CLASS/SPEC-SPECIFIC STAT CATEGORY ORDERS
-- ============================================================================
BCF.ClassSpecStatOrder = {
    -- Warrior
    WARRIOR = {
        [1] = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"},      -- Arms (DPS)
        [2] = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"},      -- Fury (DPS)
        [3] = {"General", "Base Attributes", "Defense", "Melee", "Ranged", "Spell"},      -- Protection (Tank)
        default = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"}, -- No talents = DPS
    },
    -- Mage
    MAGE = {
        [1] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Arcane
        [2] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Fire
        [3] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Frost
        default = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},
    },
    -- Hunter
    HUNTER = {
        [1] = {"General", "Base Attributes", "Ranged", "Melee", "Defense", "Spell"},      -- Beast Mastery
        [2] = {"General", "Base Attributes", "Ranged", "Melee", "Defense", "Spell"},      -- Marksmanship
        [3] = {"General", "Base Attributes", "Ranged", "Melee", "Defense", "Spell"},      -- Survival
        default = {"General", "Base Attributes", "Ranged", "Melee", "Defense", "Spell"},
    },
    -- Rogue
    ROGUE = {
        [1] = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"},      -- Assassination
        [2] = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"},      -- Combat
        [3] = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"},      -- Subtlety
        default = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"},
    },
    -- Warlock
    WARLOCK = {
        [1] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Affliction
        [2] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Demonology
        [3] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Destruction
        default = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},
    },
    -- Priest
    PRIEST = {
        [1] = {"General", "Base Attributes", "Spell", "Defense", "Ranged", "Melee"},      -- Discipline
        [2] = {"General", "Base Attributes", "Spell", "Defense", "Ranged", "Melee"},      -- Holy
        [3] = {"General", "Base Attributes", "Spell", "Defense", "Ranged", "Melee"},      -- Shadow
        default = {"General", "Base Attributes", "Spell", "Defense", "Ranged", "Melee"},
    },
    -- Paladin
    PALADIN = {
        [1] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Holy
        [2] = {"General", "Base Attributes", "Defense", "Spell", "Melee", "Ranged"},      -- Protection
        [3] = {"General", "Base Attributes", "Melee", "Defense", "Spell", "Ranged"},      -- Retribution
        default = {"General", "Base Attributes", "Melee", "Defense", "Spell", "Ranged"}, -- No talents = Ret
    },
    -- Druid
    DRUID = {
        [1] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Balance
        [2] = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"},      -- Feral (DPS default)
        [3] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Restoration
        feral_tank = {"General", "Base Attributes", "Defense", "Melee", "Ranged", "Spell"}, -- Feral Tank
        default = {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"}, -- No talents = Feral DPS
    },
    -- Shaman
    SHAMAN = {
        [1] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Elemental
        [2] = {"General", "Base Attributes", "Melee", "Defense", "Spell", "Ranged"},      -- Enhancement
        [3] = {"General", "Base Attributes", "Spell", "Defense", "Melee", "Ranged"},      -- Restoration
        default = {"General", "Base Attributes", "Melee", "Defense", "Spell", "Ranged"}, -- No talents = Enh
    },
}

-- Get the default stat order for current class/spec
function BCF.GetClassSpecDefaultOrder()
    local _, playerClass = UnitClass("player")
    local classOrders = BCF.ClassSpecStatOrder[playerClass]
    if not classOrders then
        return {"General", "Base Attributes", "Melee", "Defense", "Ranged", "Spell"}
    end

    local numTabs = GetNumTalentTabs()
    local tabPoints = {}
    local totalPoints = 0

    for i = 1, numTabs do
        tabPoints[i] = CountTabPoints(i)
        totalPoints = totalPoints + tabPoints[i]
    end

    -- No talents spent = use default for class
    if totalPoints == 0 then
        return classOrders.default or classOrders[1]
    end

    -- Find primary tree
    local primaryTab = 1
    for i = 2, numTabs do
        if tabPoints[i] > tabPoints[primaryTab] then
            primaryTab = i
        end
    end

    return classOrders[primaryTab] or classOrders.default or classOrders[1]
end

-- Initialize character stat order on first load
function BCF.InitCharacterStatOrder()
    local charKey = BCF.GetCharacterKey()
    if not BCF.DB then BCF.DB = {} end
    if not BCF.DB.Characters then BCF.DB.Characters = {} end
    if not BCF.DB.Characters[charKey] then BCF.DB.Characters[charKey] = {} end

    -- Only set default if no order exists for this character
    if not BCF.DB.Characters[charKey].StatOrder then
        BCF.DB.Characters[charKey].StatOrder = BCF.GetClassSpecDefaultOrder()
    end
end

-- --- Stat Definitions ---
-- Each stat has: key, label, getValue function, formatString
-- getValue returns: displayValue, ratingValue (optional)

local function SafeGetCombatRating(id)
    local ok, val = pcall(GetCombatRating, id)
    return ok and val or 0
end

local function SafeGetCombatRatingBonus(id)
    local ok, val = pcall(GetCombatRatingBonus, id)
    return ok and val or 0
end

local function FormatRating(value, rating)
    if rating and rating > 0 then
        return string.format("%.2f%% (%d)", value, rating)
    end
    return string.format("%.2f%%", value)
end

local function FormatInt(value)
    return string.format("%d", value)
end

-- Build stat getters
local function GetBaseStats()
    local stats = {}
    local labels = {"Strength", "Agility", "Stamina", "Intellect", "Spirit"}
    for i = 1, 5 do
        -- UnitStat returns vary by client version:
        --   Classic/Anniversary: stat, effectiveStat, posBuff, negBuff (4 values)
        --   Some TBC builds:     stat, posBuff, negBuff (3 values)
        -- Use select() to safely handle both
        local r1, r2, r3, r4 = UnitStat("player", i)
        local effective, posBuff, negBuff
        if r4 ~= nil then
            -- 4 return values: base, effective, posBuff, negBuff
            effective = tonumber(r2) or 0
            posBuff = tonumber(r3) or 0
            negBuff = tonumber(r4) or 0
        else
            -- 3 return values: effective, posBuff, negBuff
            effective = tonumber(r1) or 0
            posBuff = tonumber(r2) or 0
            negBuff = tonumber(r3) or 0
        end
        local base = effective - posBuff - negBuff
        stats[i] = {
            label = labels[i],
            value = effective,
            base = base,
            bonus = posBuff + negBuff,
        }
    end
    return stats
end

-- ============================================================================
-- Spell school names (indices match GetSpellBonusDamage)
-- ============================================================================
local SCHOOL_NAMES = {[2]="Holy",[3]="Fire",[4]="Nature",[5]="Frost",[6]="Shadow",[7]="Arcane"}
local SCHOOL_ICONS = {
    [2] = "|TInterface\\Icons\\Spell_Holy_HolyBolt:14:14:0:0|t",
    [3] = "|TInterface\\Icons\\Spell_Fire_FireBolt02:14:14:0:0|t",
    [4] = "|TInterface\\Icons\\Spell_Nature_StarFall:14:14:0:0|t",
    [5] = "|TInterface\\Icons\\Spell_Frost_FrostBolt02:14:14:0:0|t",
    [6] = "|TInterface\\Icons\\Spell_Shadow_ShadowBolt:14:14:0:0|t",
    [7] = "|TInterface\\Icons\\Spell_Arcane_Blast:14:14:0:0|t",
}

-- ============================================================================
-- STAT CATEGORIES
-- Each stat row returns a structured table:
--   label     (string)  Left column display name
--   pct       (string)  Percentage or primary value column
--   rating    (number)  Raw rating number (nil = no rating column)
--   rawValue  (number)  Sortable raw number
--   tooltip   (table)   {title, lines={...}} for hover breakdown (optional)
-- ============================================================================

BCF.StatCategories = {
    -- ==================================================================
    -- GENERAL (MoP-Style Overview)
    -- ==================================================================
    {
        name = "General",
        icon = "Interface\\Icons\\INV_Misc_Book_11",
        roles = {"melee_dps", "ranged_dps", "caster_dps", "healer", "tank"},
        getStats = function()
            local results = {}

            -- Health
            local hp = UnitHealthMax("player")
            table.insert(results, {
                label = "Health",
                pct = FormatInt(hp),
                rating = nil,
                rawValue = hp,
            })

            -- Mana (conditional - show if player has mana)
            local powerOk, powerType = pcall(UnitPowerType, "player")
            if not powerOk then powerType = 0 end
            powerType = tonumber(powerType) or 0

            -- Try multiple APIs to get max mana (TBC Anniversary compatibility)
            local manaMax = 0
            -- Primary: UnitPowerMax (modern API, power type 0 = mana)
            if UnitPowerMax then
                local ok, val = pcall(UnitPowerMax, "player", 0)
                if ok and val then manaMax = tonumber(val) or 0 end
            end
            -- Fallback: UnitManaMax (classic API)
            if manaMax == 0 and UnitManaMax then
                local ok, val = pcall(UnitManaMax, "player")
                if ok and val then manaMax = tonumber(val) or 0 end
            end

            -- Show mana if: (1) power type is mana OR (2) mana max > 0 (e.g., Mages in forms)
            if powerType == 0 or manaMax > 0 then
                table.insert(results, {
                    label = "Mana",
                    pct = FormatInt(manaMax),
                    rating = nil,
                    rawValue = manaMax,
                })
            end

            -- Gear Score (TacoTip v0.4.3 Formula - exact match)
            -- Calculate first so Item Level can use its color
            -- Formula: floor(((iLevel - A) / B) * SlotMOD * Scale * QualityScale)
            local GS_Scale = 1.8618

            -- TacoTip GS_Formula tables (exact values from TipTac/LibFroznFunctions)
            -- Formula "A" = high level items (iLevel > 120)
            -- Formula "B" = low level items (iLevel <= 120)
            local GS_Formula = {
                A = { -- iLevel > 120
                    [4] = { A = 91.45, B = 0.65 },    -- Epic
                    [3] = { A = 81.375, B = 0.8125 }, -- Rare
                    [2] = { A = 73.0, B = 1.0 },      -- Uncommon
                },
                B = { -- iLevel <= 120
                    [4] = { A = 26.0, B = 1.2 },   -- Epic
                    [3] = { A = 0.75, B = 1.8 },   -- Rare
                    [2] = { A = 8.0, B = 2.0 },    -- Uncommon
                    [1] = { A = 0.0, B = 2.25 },   -- Common
                }
            }

            -- TacoTip GS_ItemTypes SlotMOD (keyed by INVTYPE string)
            local GS_SlotMod = {
                ["INVTYPE_HEAD"] = 1.0,
                ["INVTYPE_NECK"] = 0.5625,
                ["INVTYPE_SHOULDER"] = 0.75,
                ["INVTYPE_CHEST"] = 1.0,
                ["INVTYPE_ROBE"] = 1.0,
                ["INVTYPE_WAIST"] = 0.75,
                ["INVTYPE_LEGS"] = 1.0,
                ["INVTYPE_FEET"] = 0.75,
                ["INVTYPE_WRIST"] = 0.5625,
                ["INVTYPE_HAND"] = 0.75,
                ["INVTYPE_FINGER"] = 0.5625,
                ["INVTYPE_TRINKET"] = 0.5625,
                ["INVTYPE_CLOAK"] = 0.5625,
                ["INVTYPE_WEAPON"] = 1.0,
                ["INVTYPE_WEAPONMAINHAND"] = 1.0,
                ["INVTYPE_WEAPONOFFHAND"] = 1.0,
                ["INVTYPE_HOLDABLE"] = 1.0,
                ["INVTYPE_SHIELD"] = 1.0,
                ["INVTYPE_2HWEAPON"] = 2.0,
                ["INVTYPE_RANGED"] = 0.3164,
                ["INVTYPE_RANGEDRIGHT"] = 0.3164,
                ["INVTYPE_THROWN"] = 0.3164,
                ["INVTYPE_RELIC"] = 0.3164,
                ["INVTYPE_BODY"] = 0,
            }

            local gearScore = 0
            local _, playerClass = UnitClass("player")
            -- Always prefer a fresh equipped-gear snapshot for stats rows.
            local liveScan = (BCF.ScanGear and BCF.ScanGear()) or BCF.LastGearScan or nil
            local liveSlots = liveScan and liveScan.slots or nil

            -- Check for TitanGrip (2H in offhand)
            local titanGrip = 1
            local offHandLink = GetInventoryItemLink("player", 17)
            if offHandLink then
                local _, _, _, _, _, _, _, _, offEquipLoc = (BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(offHandLink))
                    or GetItemInfo(offHandLink)
                if offEquipLoc == "INVTYPE_2HWEAPON" then
                    titanGrip = 0.5
                end
            end

            for _, slot in ipairs(BCF.EquipSlots) do
                if slot.id ~= 4 and slot.id ~= 19 then -- Skip Shirt and Tabard
                    local link = GetInventoryItemLink("player", slot.id)
                    if link then
                        local _, _, quality, iLevel, _, _, _, _, equipLoc = (BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(link))
                            or GetItemInfo(link)
                        if (not iLevel or iLevel <= 0) and GetDetailedItemLevelInfo then
                            local detailedILvl = GetDetailedItemLevelInfo(link)
                            if detailedILvl and detailedILvl > 0 then iLevel = detailedILvl end
                        end
                        if (not iLevel or iLevel <= 0) and liveSlots and liveSlots[slot.id] then
                            iLevel = liveSlots[slot.id].itemLevel
                        end
                        if not quality and GetInventoryItemQuality then
                            quality = GetInventoryItemQuality("player", slot.id)
                        end
                        if iLevel and iLevel > 0 and quality and equipLoc and GS_SlotMod[equipLoc] then
                            -- Quality adjustments (TacoTip exact behavior)
                            local qualityScale = 1
                            local effectiveQuality = quality
                            local effectiveILevel = iLevel

                            if quality == 5 then -- Legendary
                                qualityScale = 1.3
                                effectiveQuality = 4
                            elseif quality == 0 or quality == 1 then -- Poor/Common
                                qualityScale = 0.005
                                effectiveQuality = 2
                            elseif quality == 7 then -- Heirloom
                                effectiveQuality = 3
                                effectiveILevel = 187.05
                            end

                            -- Select formula based on item level
                            local formulaTable = (effectiveILevel > 120) and GS_Formula.A or GS_Formula.B
                            local formula = formulaTable[effectiveQuality]

                            if formula then
                                local effectiveSlotMod = GS_SlotMod[equipLoc] or 1.0

                                -- Hunter-specific adjustments (TacoTip v0.4.3 exact)
                                -- Hunters: ranged is primary weapon, melee is stat-stick
                                if playerClass == "HUNTER" then
                                    if slot.id == 16 then -- Main hand → stat-stick
                                        effectiveSlotMod = 0.3164
                                    elseif slot.id == 17 then -- Off hand → stat-stick
                                        effectiveSlotMod = 0.3164
                                    elseif slot.id == 18 then -- Ranged → primary weapon
                                        effectiveSlotMod = 5.3224
                                    end
                                end

                                -- TitanGrip penalty for MH/OH
                                if slot.id == 16 or slot.id == 17 then
                                    effectiveSlotMod = effectiveSlotMod * titanGrip
                                end

                                local itemScore = math.floor(((effectiveILevel - formula.A) / formula.B) * effectiveSlotMod * GS_Scale * qualityScale)
                                if itemScore < 0 then itemScore = 0 end
                                gearScore = gearScore + itemScore
                            end
                        end
                    end
                end
            end
            local gsR, gsG, gsB = GetGearScoreQualityColor(gearScore)
            -- Store globally for iLvl overlay coloring
            BCF.CurrentGearScore = gearScore
            BCF.GearScoreColor = {gsR, gsG, gsB}
            table.insert(results, {
                label = "Gear Score",
                pct = FormatInt(math.floor(gearScore)),
                rating = nil,
                rawValue = gearScore,
                color = {gsR, gsG, gsB},
            })

            -- Item Level (equipped only, exclude Shirt/Tabard) - uses GearScore color
            local iLevelTotal = 0
            local iLevelCount = 0
            for _, slot in ipairs(BCF.EquipSlots) do
                if slot.id ~= 4 and slot.id ~= 19 then -- Skip Shirt and Tabard
                    local link = GetInventoryItemLink("player", slot.id)
                    if link then
                        local _, _, _, iLevel = (BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(link)) or GetItemInfo(link)
                        if (not iLevel or iLevel <= 0) and GetDetailedItemLevelInfo then
                            local detailedILvl = GetDetailedItemLevelInfo(link)
                            if detailedILvl and detailedILvl > 0 then iLevel = detailedILvl end
                        end
                        if (not iLevel or iLevel <= 0) and liveSlots and liveSlots[slot.id] then
                            iLevel = liveSlots[slot.id].itemLevel
                        end
                        if iLevel and iLevel > 0 then
                            iLevelTotal = iLevelTotal + iLevel
                            iLevelCount = iLevelCount + 1
                        end
                    end
                end
            end
            local avgILevel = iLevelCount > 0 and (iLevelTotal / iLevelCount) or ((liveScan and liveScan.avgItemLevel) or 0)
            table.insert(results, {
                label = "Item Level",
                pct = string.format("%.1f", avgILevel),
                rating = nil,
                rawValue = avgILevel,
                color = {gsR, gsG, gsB},  -- Use GearScore color
            })

            return results
        end,
    },

    -- ==================================================================
    -- BASE ATTRIBUTES
    -- ==================================================================
    {
        name = "Base Attributes",
        icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
        roles = {"melee_dps", "ranged_dps", "caster_dps", "healer", "tank"},
        getStats = function()
            local baseStats = GetBaseStats()
            local results = {}

            -- Stat benefit descriptions per stat index
            local _, playerClass = UnitClass("player")
            local benefitTips = {
                -- Strength
                function(s)
                    local lines = {string.format("Base: %d  |  Bonus: %+d", s.base, s.bonus)}
                    table.insert(lines, "Increases melee attack power")
                    if playerClass == "WARRIOR" or playerClass == "PALADIN" then
                        table.insert(lines, "Increases block value")
                    end
                    return lines
                end,
                -- Agility
                function(s)
                    local lines = {string.format("Base: %d  |  Bonus: %+d", s.base, s.bonus)}
                    table.insert(lines, "Increases Ranged Attack Power")
                    table.insert(lines, string.format("Increases Armor by %d", s.value * 2))
                    local totalCrit = GetCritChance() or 0
                    local ratingCrit = SafeGetCombatRatingBonus(CR.CRIT_MELEE)
                    local critFromAgi = math.max(0, totalCrit - ratingCrit)
                    table.insert(lines, string.format("Increases chance to critically hit by %.2f%%", critFromAgi))
                    if playerClass == "ROGUE" or playerClass == "DRUID" then
                        table.insert(lines, "Increases Dodge chance")
                    end
                    return lines
                end,
                -- Stamina
                function(s)
                    local lines = {string.format("Base: %d  |  Bonus: %+d", s.base, s.bonus)}
                    table.insert(lines, string.format("Grants %d health", s.value * 10))
                    return lines
                end,
                -- Intellect
                function(s)
                    local lines = {string.format("Base: %d  |  Bonus: %+d", s.base, s.bonus)}
                    table.insert(lines, string.format("Increases Mana by %d", s.value * 15))
                    local spellCrit = GetSpellCritChance and (GetSpellCritChance(2) or 0) or 0
                    local spellCritRating = SafeGetCombatRatingBonus(CR.CRIT_SPELL)
                    local critFromInt = math.max(0, spellCrit - spellCritRating)
                    table.insert(lines, string.format("Increases chance to critically hit by %.2f%%", critFromInt))
                    return lines
                end,
                -- Spirit
                function(s)
                    local lines = {string.format("Base: %d  |  Bonus: %+d", s.base, s.bonus)}
                    local baseMR, _ = GetManaRegen()
                    local mp5Spirit = math.floor((baseMR or 0) * 5)
                    table.insert(lines, string.format("Increases Mana Regeneration by %d per 5 sec while not casting", mp5Spirit))
                    table.insert(lines, "Increases Health Regeneration while not in combat")
                    return lines
                end,
            }

            for i, s in ipairs(baseStats) do
                local tipLines = benefitTips[i] and benefitTips[i](s) or {}
                -- 3-column grid: Stat | Bonus (middle, grey) | Effective (right, white)
                local bonusVal = s.bonus ~= 0 and string.format("%+d", s.bonus) or ""
                table.insert(results, {
                    label = s.label,
                    pct = FormatInt(s.value),
                    rating = bonusVal,  -- Bonus in middle column (uses rating slot)
                    rawValue = s.value,
                    tooltip = {title = s.label, lines = tipLines},
                })
            end

            -- Health
            local hp = UnitHealthMax("player")
            table.insert(results, {
                label = "Health",
                pct = FormatInt(hp),
                rating = nil,
                rawValue = hp,
            })

            -- Mana / Rage / Energy (safely handle all Anniversary edge cases)
            local powerOk, powerType = pcall(UnitPowerType, "player")
            if not powerOk then powerType = 0 end
            powerType = tonumber(powerType) or 0

            local powerOk2, powerMax = pcall(UnitManaMax, "player")
            if not powerOk2 then powerMax = 0 end
            powerMax = tonumber(powerMax) or 0

            -- Determine label based on power type
            local powerLabel = "Power"
            if powerType == 0 or (powerMax > 0 and powerType ~= 1 and powerType ~= 3) then
                powerLabel = "Mana"
            elseif powerType == 1 then
                powerLabel = "Rage"
            elseif powerType == 3 then
                powerLabel = "Energy"
            end

            if powerMax > 0 then
                table.insert(results, {
                    label = powerLabel,
                    pct = FormatInt(powerMax),
                    rating = nil,
                    rawValue = powerMax,
                })
            end
            return results
        end,
    },

    -- ==================================================================
    -- MELEE
    -- ==================================================================
    {
        name = "Melee",
        icon = "Interface\\Icons\\Ability_MeleeDamage",
        roles = {"melee_dps", "tank"},
        getStats = function()
            local base, posBuff, negBuff = UnitAttackPower("player")
            local ap = (base or 0) + (posBuff or 0) + (negBuff or 0)
            local speed, offhandSpeed = UnitAttackSpeed("player")
            speed = speed or 0
            offhandSpeed = offhandSpeed or 0

            local hitRating = SafeGetCombatRating(CR.HIT_MELEE)
            local hitPct = SafeGetCombatRatingBonus(CR.HIT_MELEE)
            local critPct = GetCritChance() or 0
            local critRating = SafeGetCombatRating(CR.CRIT_MELEE)
            local hasteRating = SafeGetCombatRating(CR.HASTE_MELEE)
            local hastePct = SafeGetCombatRatingBonus(CR.HASTE_MELEE)
            local expRating = SafeGetCombatRating(CR.EXPERTISE)
            local expPct = SafeGetCombatRatingBonus(CR.EXPERTISE)
            local armorPenRating = SafeGetCombatRating(CR.ARMOR_PENETRATION)
            local armorPenVal = SafeGetCombatRatingBonus(CR.ARMOR_PENETRATION)

            local dmgMin, dmgMax = UnitDamage("player")
            dmgMin = math.floor(dmgMin or 0)
            dmgMax = math.floor(dmgMax or 0)
            local dps = speed > 0 and ((dmgMin + dmgMax) / 2 / speed) or 0

            return {
                {label = "Damage",          pct = string.format("%d - %d", dmgMin, dmgMax), rating = nil, rawValue = dmgMin,
                    tooltip = {title = "Melee Damage", lines = {
                        string.format("Main Hand: %d - %d", dmgMin, dmgMax),
                        string.format("Attack Speed: %.2f sec", speed),
                        string.format("Damage per Second: %.1f", dps),
                    }}},
                {label = "Attack Power",    pct = FormatInt(ap),                        rating = nil,        rawValue = ap,
                    tooltip = {title = "Attack Power", lines = {
                        string.format("Base: %d  |  Bonus: %+d", base or 0, (posBuff or 0) + (negBuff or 0)),
                        string.format("Increases damage by %.1f DPS", ap / 14),
                        "2 Attack Power = 1 DPS",
                    }}},
                {label = "Hit",             pct = string.format("%.2f%%", hitPct),      rating = hitRating,  rawValue = hitPct,
                    tooltip = {title = "Melee Hit", lines = {
                        string.format("Rating: %d", hitRating),
                        " ",
                        "Chance to Miss (Special Attacks):",
                        string.format("  vs Level +0: %.2f%%", math.max(0, 5.0 - hitPct)),
                        string.format("  vs Level +1: %.2f%%", math.max(0, 5.5 - hitPct)),
                        string.format("  vs Level +2: %.2f%%", math.max(0, 6.0 - hitPct)),
                        string.format("  vs Level +3 (Boss): %.2f%%", math.max(0, 9.0 - hitPct)),
                        " ",
                        "Chance to Miss (White / Dual Wield):",
                        string.format("  vs Level +0: %.2f%%", math.max(0, 24.0 - hitPct)),
                        string.format("  vs Level +1: %.2f%%", math.max(0, 24.5 - hitPct)),
                        string.format("  vs Level +2: %.2f%%", math.max(0, 25.0 - hitPct)),
                        string.format("  vs Level +3 (Boss): %.2f%%", math.max(0, 28.0 - hitPct)),
                    }}},
                {label = "Crit",            pct = string.format("%.2f%%", critPct),     rating = critRating, rawValue = critPct,
                    tooltip = {title = "Melee Critical Strike", lines = {
                        string.format("Rating: %d", critRating),
                        string.format("Chance to critically strike: %.2f%%", critPct),
                        "Critical strikes deal 200%% damage",
                    }}},
                {label = "Haste",           pct = string.format("%.2f%%", hastePct),    rating = hasteRating,rawValue = hastePct,
                    tooltip = {title = "Melee Haste", lines = {
                        string.format("Rating: %d", hasteRating),
                        string.format("Increases attack speed by %.2f%%", hastePct),
                        string.format("Effective MH Speed: %.2f sec", speed > 0 and speed / (1 + hastePct/100) or 0),
                    }}},
                {label = "Expertise",       pct = string.format("%.2f%%", expPct),      rating = expRating,  rawValue = expPct,
                    tooltip = {title = "Expertise", lines = {
                        string.format("Rating: %d", expRating),
                        "Reduces chance for attacks to be Dodged or Parried",
                        " ",
                        "Chance to be Dodged:",
                        string.format("  vs Level +0: %.2f%%", math.max(0, 5.0 - expPct)),
                        string.format("  vs Level +1: %.2f%%", math.max(0, 5.5 - expPct)),
                        string.format("  vs Level +2: %.2f%%", math.max(0, 6.0 - expPct)),
                        string.format("  vs Level +3 (Boss): %.2f%%", math.max(0, 6.5 - expPct)),
                        " ",
                        "Chance to be Parried:",
                        string.format("  vs Level +0: %.2f%%", math.max(0, 5.0 - expPct)),
                        string.format("  vs Level +1: %.2f%%", math.max(0, 5.5 - expPct)),
                        string.format("  vs Level +2: %.2f%%", math.max(0, 6.0 - expPct)),
                        string.format("  vs Level +3 (Boss): %.2f%%", math.max(0, 14.0 - expPct)),
                    }}},
                {label = "Armor Pen",       pct = FormatInt(armorPenVal),               rating = armorPenRating, rawValue = armorPenVal,
                    tooltip = {title = "Armor Penetration", lines = {
                        string.format("Rating: %d", armorPenRating),
                        string.format("Reduces enemy Armor by %d", armorPenVal),
                        "Increases physical damage against armored targets",
                    }}},
                {label = "MH Speed",        pct = string.format("%.2f sec", speed),     rating = nil,        rawValue = speed},
                {label = "OH Speed",        pct = string.format("%.2f sec", offhandSpeed), rating = nil,     rawValue = offhandSpeed},
            }
        end,
    },

    -- ==================================================================
    -- RANGED
    -- ==================================================================
    {
        name = "Ranged",
        icon = "Interface\\Icons\\Ability_Marksmanship",
        roles = {"ranged_dps"},
        getStats = function()
            local base, posBuff, negBuff = UnitRangedAttackPower("player")
            local rap = (base or 0) + (posBuff or 0) + (negBuff or 0)

            local hitRating = SafeGetCombatRating(CR.HIT_RANGED)
            local hitPct = SafeGetCombatRatingBonus(CR.HIT_RANGED)
            local critPct = GetRangedCritChance() or 0
            local critRating = SafeGetCombatRating(CR.CRIT_RANGED)
            local hasteRating = SafeGetCombatRating(CR.HASTE_RANGED)
            local hastePct = SafeGetCombatRatingBonus(CR.HASTE_RANGED)
            local armorPenRating = SafeGetCombatRating(CR.ARMOR_PENETRATION)
            local armorPenVal = SafeGetCombatRatingBonus(CR.ARMOR_PENETRATION)

            local rDmgMin, rDmgMax, rSpeed = 0, 0, 0
            if GetInventoryItemLink("player", 18) and UnitRangedDamage then
                local s, lo, hi = UnitRangedDamage("player")
                rDmgMin = math.floor(lo or 0)
                rDmgMax = math.floor(hi or 0)
                rSpeed  = tonumber(s) or 0
            end
            local rDps = rSpeed > 0 and ((rDmgMin + rDmgMax) / 2 / rSpeed) or 0

            return {
                {label = "Damage",          pct = string.format("%d - %d", rDmgMin, rDmgMax), rating = nil, rawValue = rDmgMin,
                    tooltip = {title = "Ranged Damage", lines = {
                        string.format("Damage: %d - %d", rDmgMin, rDmgMax),
                        string.format("Attack Speed: %.2f sec", rSpeed),
                        string.format("Damage per Second: %.1f", rDps),
                    }}},
                {label = "Attack Power",    pct = FormatInt(rap),                       rating = nil,        rawValue = rap,
                    tooltip = {title = "Ranged Attack Power", lines = {
                        string.format("Base: %d  |  Bonus: %+d", base or 0, (posBuff or 0) + (negBuff or 0)),
                        string.format("Increases ranged damage by %.1f DPS", rap / 14),
                        "2 Ranged Attack Power = 1 DPS",
                    }}},
                {label = "Hit",             pct = string.format("%.2f%%", hitPct),      rating = hitRating,  rawValue = hitPct,
                    tooltip = {title = "Ranged Hit", lines = {
                        string.format("Rating: %d", hitRating),
                        " ",
                        "Chance to Miss:",
                        string.format("  vs Level +0: %.2f%%", math.max(0, 5.0 - hitPct)),
                        string.format("  vs Level +1: %.2f%%", math.max(0, 5.5 - hitPct)),
                        string.format("  vs Level +2: %.2f%%", math.max(0, 6.0 - hitPct)),
                        string.format("  vs Level +3 (Boss): %.2f%%", math.max(0, 9.0 - hitPct)),
                    }}},
                {label = "Crit",            pct = string.format("%.2f%%", critPct),     rating = critRating, rawValue = critPct,
                    tooltip = {title = "Ranged Critical Strike", lines = {
                        string.format("Rating: %d", critRating),
                        string.format("Chance to critically strike: %.2f%%", critPct),
                        "Critical strikes deal 200%% damage",
                    }}},
                {label = "Haste",           pct = string.format("%.2f%%", hastePct),    rating = hasteRating,rawValue = hastePct,
                    tooltip = {title = "Ranged Haste", lines = {
                        string.format("Rating: %d", hasteRating),
                        string.format("Increases ranged attack speed by %.2f%%", hastePct),
                        string.format("Effective Weapon Speed: %.2f sec", rSpeed > 0 and rSpeed / (1 + hastePct/100) or 0),
                    }}},
                {label = "Armor Pen",       pct = FormatInt(armorPenVal),               rating = armorPenRating, rawValue = armorPenVal,
                    tooltip = {title = "Armor Penetration", lines = {
                        string.format("Rating: %d", armorPenRating),
                        string.format("Reduces enemy Armor by %d", armorPenVal),
                        "Increases physical damage against armored targets",
                    }}},
                {label = "Weapon Speed",    pct = string.format("%.2f sec", rSpeed),    rating = nil,        rawValue = rSpeed},
            }
        end,
    },

    -- ==================================================================
    -- SPELL
    -- ==================================================================
    {
        name = "Spell",
        icon = "Interface\\Icons\\Spell_Nature_StarFall",
        roles = {"caster_dps", "healer"},
        getStats = function()
            -- Spell power per school
            local schoolDmg = {}
            local maxSpellDmg = 0
            for i = 2, 7 do
                local dmg = GetSpellBonusDamage(i) or 0
                schoolDmg[i] = dmg
                if dmg > maxSpellDmg then maxSpellDmg = dmg end
            end
            local healing = GetSpellBonusHealing() or 0

            -- Build school breakdown tooltip with icons
            local schoolLines = {}
            for i = 2, 7 do
                local icon = SCHOOL_ICONS[i] or ""
                table.insert(schoolLines, string.format("%s %s:  %d", icon, SCHOOL_NAMES[i], schoolDmg[i]))
            end

            local hitRating = SafeGetCombatRating(CR.HIT_SPELL)
            local hitPct = SafeGetCombatRatingBonus(CR.HIT_SPELL)
            local critPct = GetSpellCritChance(2) or 0
            local critRating = SafeGetCombatRating(CR.CRIT_SPELL)
            local hasteRating = SafeGetCombatRating(CR.HASTE_SPELL)
            local hastePct = SafeGetCombatRatingBonus(CR.HASTE_SPELL)
            local penetration = GetSpellPenetration and GetSpellPenetration() or 0

            -- MP5
            local baseMR, castingMR = GetManaRegen()
            local mp5 = math.floor((baseMR or 0) * 5)
            local mp5Casting = math.floor((castingMR or 0) * 5)

            -- Spell crit per school
            local spellCritLines = {}
            for i = 2, 7 do
                local schoolCrit = GetSpellCritChance and (GetSpellCritChance(i) or critPct) or critPct
                local icon = SCHOOL_ICONS[i] or ""
                table.insert(spellCritLines, string.format("%s %s:  %.2f%%", icon, SCHOOL_NAMES[i], schoolCrit))
            end

            local results = {
                {label = "Spell Damage",    pct = FormatInt(maxSpellDmg),               rating = nil,        rawValue = maxSpellDmg,
                    tooltip = {title = "Spell Damage by School", lines = schoolLines}},
                {label = "Healing Power",   pct = FormatInt(healing),                   rating = nil,        rawValue = healing,
                    tooltip = {title = "Healing Power", lines = {
                        string.format("Bonus healing on all spells: +%d", healing),
                        "Increases the effectiveness of healing spells",
                    }}},
                {label = "Spell Hit",       pct = string.format("%.2f%%", hitPct),      rating = hitRating,  rawValue = hitPct,
                    tooltip = {title = "Spell Hit", lines = {
                        string.format("Rating: %d", hitRating),
                        " ",
                        "Chance to Miss:",
                        string.format("  vs Level +0: %.2f%%", math.max(0, 4.0 - hitPct)),
                        string.format("  vs Level +1: %.2f%%", math.max(0, 5.0 - hitPct)),
                        string.format("  vs Level +2: %.2f%%", math.max(0, 6.0 - hitPct)),
                        string.format("  vs Level +3 (Boss): %.2f%%", math.max(0, 16.0 - hitPct)),
                    }}},
                {label = "Spell Crit",      pct = string.format("%.2f%%", critPct),     rating = critRating, rawValue = critPct,
                    tooltip = {title = "Spell Critical Strike by School", lines = spellCritLines}},
                {label = "Spell Haste",     pct = string.format("%.2f%%", hastePct),    rating = hasteRating,rawValue = hastePct,
                    tooltip = {title = "Spell Haste", lines = {
                        string.format("Rating: %d", hasteRating),
                        string.format("Reduces cast time by %.2f%%", hastePct),
                    }}},
            }
            table.insert(results, {label = "Spell Pen",  pct = FormatInt(penetration), rating = penetration, rawValue = penetration,
                tooltip = {title = "Spell Penetration", lines = {
                    string.format("Reduces enemy spell resistance by %d", penetration),
                    "Useful against targets with innate resistance (e.g. Undead, Demons)",
                }}})
            table.insert(results, {label = "MP5 (Not Casting)", pct = FormatInt(mp5), rating = nil, rawValue = mp5,
                tooltip = {title = "Mana per 5 sec (Not Casting)", lines = {
                    string.format("Regenerates %d mana per 5 sec while not casting", mp5),
                    "Derived from Spirit — active outside the 5-second rule",
                }}})
            table.insert(results, {label = "MP5 (Casting)",     pct = FormatInt(mp5Casting),  rating = nil, rawValue = mp5Casting,
                tooltip = {title = "Mana per 5 sec (Casting)", lines = {
                    string.format("Regenerates %d mana per 5 sec while casting", mp5Casting),
                    "From gear with \"mp5\" stat — active at all times",
                }}})
            return results
        end,
    },

    -- ==================================================================
    -- DEFENSE
    -- ==================================================================
    {
        name = "Defense",
        icon = "Interface\\Icons\\Ability_Defend",
        roles = {"tank", "melee_dps", "ranged_dps", "caster_dps", "healer"},
        getStats = function()
            local armorBase, armorEff, armor, bonusArmor = UnitArmor("player")
            local armorVal = armorEff or armor or 0
            local defRating = SafeGetCombatRating(CR.DEFENSE_SKILL)
            local defBonus = SafeGetCombatRatingBonus(CR.DEFENSE_SKILL)

            local dodgePct = GetDodgeChance() or 0
            local dodgeRating = SafeGetCombatRating(CR.DODGE)
            local parryPct = GetParryChance() or 0
            local parryRating = SafeGetCombatRating(CR.PARRY)
            local blockPct = GetBlockChance() or 0
            local blockRating = SafeGetCombatRating(CR.BLOCK)

            -- Block Value
            local blockValue = 0
            if GetShieldBlock then
                local ok, val = pcall(GetShieldBlock)
                blockValue = ok and val or 0
            end

            local resilRating = SafeGetCombatRating(15)
            local resilPct = SafeGetCombatRatingBonus(15)

            -- Armor tooltip: damage reduction vs multiple enemy levels
            local playerLevel = UnitLevel("player")

            local function CalcArmorDR(armor, attackerLevel)
                if armor <= 0 then return 0 end
                local dr = armor / (armor + (400 + 85 * attackerLevel + 4.5 * attackerLevel * (attackerLevel - 59)))
                return math.min(0.75, dr) * 100
            end

            local dr70 = CalcArmorDR(armorVal, playerLevel)
            local dr71 = CalcArmorDR(armorVal, 71)
            local dr72 = CalcArmorDR(armorVal, 72)
            local dr73 = CalcArmorDR(armorVal, 73)

            -- Defense: each 1 Defense = 0.04% dodge/parry/block/miss/crit reduction
            local defTotal = 350 + defBonus  -- base 350 + rating bonus
            local defDodge  = defBonus * 0.04
            local defCritReduc = defBonus * 0.04

            local results = {
                {label = "Armor",           pct = FormatInt(armorVal),                      rating = nil,        rawValue = armorVal,
                    tooltip = {title = "Armor", lines = {
                        "Physical Damage Reduction:",
                        string.format("  vs Level %d: %.1f%%", playerLevel, dr70),
                        string.format("  vs Level 71: %.1f%%", dr71),
                        string.format("  vs Level 72: %.1f%%", dr72),
                        string.format("  vs Level 73 (Boss): %.1f%%", dr73),
                    }}},
                {label = "Defense",         pct = string.format("%d", defTotal),            rating = defRating,  rawValue = defRating,
                    tooltip = {title = "Defense", lines = {
                        string.format("Defense Rating: %d  (+%.0f Defense)", defRating, defBonus),
                        string.format("Increases chance to Dodge, Block and Parry by %.2f%%", defDodge),
                        string.format("Decreases chance to be hit and critically hit by %.2f%%", defCritReduc),
                        " ",
                        "Uncrittable vs Level 73 Boss requires 490 Defense",
                    }}},
                {label = "Dodge",           pct = string.format("%.2f%%", dodgePct),        rating = dodgeRating,rawValue = dodgePct,
                    tooltip = {title = "Dodge", lines = {
                        string.format("Rating: %d", dodgeRating),
                        string.format("Chance to fully avoid a melee attack: %.2f%%", dodgePct),
                    }}},
                {label = "Parry",           pct = string.format("%.2f%%", parryPct),        rating = parryRating,rawValue = parryPct,
                    tooltip = {title = "Parry", lines = {
                        string.format("Rating: %d", parryRating),
                        string.format("Chance to parry a melee attack: %.2f%%", parryPct),
                        "Parrying resets your swing timer",
                    }}},
                {label = "Block",           pct = string.format("%.2f%%", blockPct),        rating = blockRating,rawValue = blockPct,
                    tooltip = {title = "Block", lines = {
                        string.format("Rating: %d", blockRating),
                        string.format("Chance to block a melee attack: %.2f%%", blockPct),
                        string.format("Block Value: %d damage absorbed per block", blockValue),
                    }}},
                {label = "Block Value",     pct = FormatInt(blockValue),                    rating = nil,        rawValue = blockValue,
                    tooltip = {title = "Block Value", lines = {
                        string.format("Absorbs %d damage when a block occurs", blockValue),
                        "Increased by Strength and shield item level",
                    }}},
            }
            -- Always show Resilience (show 0 if none, relevant for PvP awareness)
            table.insert(results, {
                label = "Resilience",
                pct = string.format("%.2f%%", resilPct),
                rating = resilRating,
                rawValue = resilPct,
                tooltip = {title = "Resilience", lines = {
                    string.format("Rating: %d", resilRating),
                    string.format("Reduces chance to be critically hit by %.2f%%", resilPct),
                    string.format("Reduces periodic damage taken by %.2f%%", resilPct),
                    string.format("Reduces damage of critical strikes against you by %.2f%%", resilPct * 2),
                    "Reduces the effect of mana drain effects",
                }}
            })
            return results
        end,
    },
}

-- --- Get Ordered Stats (Character-Specific) ---
function BCF.GetOrderedStats(role)
    local charKey = BCF.GetCharacterKey()

    -- Check for character-specific order first
    local charOrder = BCF.DB and BCF.DB.Characters and BCF.DB.Characters[charKey] and BCF.DB.Characters[charKey].StatOrder
    local order = charOrder or BCF.GetClassSpecDefaultOrder()

    local orderedCats = {}
    local seen = {}

    -- Add categories in saved order
    for _, catName in ipairs(order) do
        if not seen[catName] then
            for _, cat in ipairs(BCF.StatCategories) do
                if cat.name == catName then
                    table.insert(orderedCats, cat)
                    seen[catName] = true
                    break
                end
            end
        end
    end

    -- Add any missing categories (fallback for new categories)
    for _, cat in ipairs(BCF.StatCategories) do
        if not seen[cat.name] then
            table.insert(orderedCats, cat)
        end
    end

    return orderedCats
end

function BCF.ReorderStats(role, fromName, targetIndexOrName, insertAfter)
    local charKey = BCF.GetCharacterKey()
    if not BCF.DB then BCF.DB = {} end
    if not BCF.DB.Characters then BCF.DB.Characters = {} end
    if not BCF.DB.Characters[charKey] then BCF.DB.Characters[charKey] = {} end

    -- Get current names list
    local currentCats = BCF.GetOrderedStats(role)
    local names = {}
    for _, c in ipairs(currentCats) do table.insert(names, c.name) end

    local fromIdx
    for i, n in ipairs(names) do if n == fromName then fromIdx = i end end

    if fromIdx then
        local moving = table.remove(names, fromIdx)

        local targetIdx
        if type(targetIndexOrName) == "number" then
            targetIdx = targetIndexOrName
        else
            -- Find target index in reduced list by name
            for i, n in ipairs(names) do if n == targetIndexOrName then targetIdx = i end end
            if targetIdx and insertAfter then targetIdx = targetIdx + 1 end
        end

        if targetIdx then
            if targetIdx < 1 then targetIdx = 1 end
            if targetIdx > #names + 1 then targetIdx = #names + 1 end

            table.insert(names, targetIdx, moving)
            -- Save to character-specific location
            BCF.DB.Characters[charKey].StatOrder = names
            return true
        end
    end
    return false
end


-- --- Get all stats (for "show all" mode) ---
function BCF.GetAllStats()
    return BCF.StatCategories
end
