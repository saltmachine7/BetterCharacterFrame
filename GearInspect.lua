local addonName, BCF = ...

-- ============================================================================
-- MODULE: GearInspect
-- ============================================================================

local T = BCF.Tokens

-- --- Equipment Slot Definitions ---
-- slotID mapping: https://wowwiki-archive.fandom.com/wiki/InventorySlotId
BCF.EquipSlots = {
    {id = 1,  name = "Head",      label = "Head"},
    {id = 2,  name = "Neck",      label = "Neck"},
    {id = 3,  name = "Shoulder",  label = "Shoulder"},
    {id = 15, name = "Back",      label = "Back"},
    {id = 5,  name = "Chest",     label = "Chest"},
    {id = 4,  name = "Shirt",     label = "Shirt"},
    {id = 19, name = "Tabard",    label = "Tabard"},
    {id = 9,  name = "Wrist",     label = "Wrist"},
    {id = 10, name = "Hands",     label = "Hands"},
    {id = 6,  name = "Waist",     label = "Waist"},
    {id = 7,  name = "Legs",      label = "Legs"},
    {id = 8,  name = "Feet",      label = "Feet"},
    {id = 11, name = "Finger0",   label = "Ring 1"},
    {id = 12, name = "Finger1",   label = "Ring 2"},
    {id = 13, name = "Trinket0",  label = "Trinket 1"},
    {id = 14, name = "Trinket1",  label = "Trinket 2"},
    {id = 16, name = "MainHand",  label = "Main Hand"},
    {id = 17, name = "SecondaryHand", label = "Off Hand"},
    {id = 18, name = "Ranged",    label = "Ranged"},
}

-- Slots that can have enchants (no rings, trinkets, neck in TBC without special cases)
local ENCHANTABLE_SLOTS = {
    [1] = true,   -- Head (glyph)
    [3] = true,   -- Shoulder (inscription)
    [15] = true,  -- Back
    [5] = true,   -- Chest
    [9] = true,   -- Wrist
    [10] = true,  -- Hands
    [7] = true,   -- Legs (armor kit / spellthread)
    [8] = true,   -- Feet
    [16] = true,  -- Main Hand
    [17] = true,  -- Off Hand (if weapon)
}

-- --- Parse Item Link for Enchant/Gem IDs ---
-- Item link format: |Hitem:itemID:enchantID:gem1:gem2:gem3:gem4:...|h[Name]|h
local function ParseItemLink(link)
    if not link then return nil end

    local _, _, itemID, enchantID, gem1, gem2, gem3, gem4 = link:find(
        "|Hitem:(%d+):(%d*):(%d*):(%d*):(%d*):(%d*)"
    )

    return {
        itemID = tonumber(itemID) or 0,
        enchantID = tonumber(enchantID) or 0,
        gems = {
            tonumber(gem1) or 0,
            tonumber(gem2) or 0,
            tonumber(gem3) or 0,
            tonumber(gem4) or 0,
        },
    }
end

local scanTooltip
local pendingItemInfoRefresh = false

local function ScheduleMissingItemInfoRefresh()
    if pendingItemInfoRefresh then return end
    pendingItemInfoRefresh = true
    C_Timer.After(0.15, function()
        pendingItemInfoRefresh = false
        if BCF.RefreshGear then BCF.RefreshGear() end
        if BCF.MainFrame and BCF.MainFrame:IsShown() and BCF.RefreshCharacter then
            BCF.RefreshCharacter()
        end
    end)
end

-- Locale-independent socket type detection (EN, DE, FR, ES)
local function MatchSocketType(text)
    if text:find("Meta") and (text:find("Socket") or text:find("Sockel") or text:find("Ch[aâ]sse")) then return "Meta" end
    if (text:find("Red") or text:find("Rot")) and (text:find("Socket") or text:find("Sockel") or text:find("Ch[aâ]sse")) then return "Red" end
    if (text:find("Yellow") or text:find("Gelb")) and (text:find("Socket") or text:find("Sockel") or text:find("Ch[aâ]sse")) then return "Yellow" end
    if (text:find("Blue") or text:find("Blau")) and (text:find("Socket") or text:find("Sockel") or text:find("Ch[aâ]sse")) then return "Blue" end
    return nil
end
BCF.MatchSocketType = MatchSocketType

local function GetSocketInfo(slotID)
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "BCFScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    scanTooltip:ClearLines()
    scanTooltip:SetInventoryItem("player", slotID)

    local sockets = {}
    for i = 1, scanTooltip:NumLines() do
        local line = _G["BCFScanTooltipTextLeft" .. i]
        if line then
            local socketType = MatchSocketType(line:GetText() or "")
            if socketType then table.insert(sockets, socketType) end
        end
    end

    return sockets
end

-- Full enchant name → abbreviated stat text (for wishlist + character tab fallback)
BCF.ENCHANT_STATS = {
    -- Head
    ["Glyph of Ferocity"] = "34 AP / 16 Hit",
    ["Glyph of Power"] = "22 SP / 14 Hit",
    ["Glyph of Renewal"] = "35 Heal / 7 MP5",
    ["Glyph of the Defender"] = "16 Def / 17 Dodge",
    ["Glyph of the Outcast"] = "17 Str / 16 Def",
    ["Glyph of the Gladiator"] = "18 Stam / 20 Resil",
    ["Presence of Might"] = "10 Def / 10 Dodge / 15 BV",
    -- Shoulder
    ["Might of the Scourge"] = "26 AP / 14 Crit",
    ["Power of the Scourge"] = "15 SP / 14 Spell Crit",
    ["Fortitude of the Scourge"] = "16 Dodge / 100 Armor",
    ["Greater Inscription of the Blade"] = "20 AP / 15 Crit",
    ["Greater Inscription of Vengeance"] = "30 AP / 10 Crit",
    ["Greater Inscription of Discipline"] = "18 SP / 10 Crit",
    ["Greater Inscription of the Oracle"] = "6 MP5 / 22 Heal",
    ["Greater Inscription of Faith"] = "33 Heal / 7 MP5",
    ["Greater Inscription of the Knight"] = "15 Def / 10 Dodge",
    ["Greater Inscription of Warding"] = "15 Dodge / 10 Def",
    ["Inscription of Faith"] = "22 Heal / 5 MP5",
    ["Heavy Knothide Armor Kit"] = "10 Stam",
    -- Back
    ["Enchant Cloak - Greater Agility"] = "12 Agi",
    ["Enchant Cloak - Subtlety"] = "-2% Threat",
    ["Enchant Cloak - Steelweave"] = "12 Def",
    ["Enchant Cloak - Dodge"] = "12 Dodge",
    ["Enchant Cloak - Major Armor"] = "120 Armor",
    ["Enchant Cloak - Major Resistance"] = "7 All Resist",
    ["Enchant Cloak - Greater Shadow Resistance"] = "15 Shadow Resist",
    ["Enchant Cloak - Spell Penetration"] = "20 Spell Pen",
    -- Chest
    ["Enchant Chest - Exceptional Stats"] = "6 Stats",
    ["Enchant Chest - Exceptional Health"] = "150 HP",
    ["Enchant Chest - Major Spirit"] = "15 Spi",
    ["Enchant Chest - Major Resilience"] = "15 Resil",
    ["Enchant Chest - Restore Mana Prime"] = "6 MP5",
    ["Enchant Chest - Defense"] = "15 Def",
    -- Wrist
    ["Enchant Bracer - Spellpower"] = "15 SP",
    ["Enchant Bracer - Brawn"] = "12 Str",
    ["Enchant Bracer - Fortitude"] = "12 Stam",
    ["Enchant Bracer - Assault"] = "24 AP",
    ["Enchant Bracer - Superior Healing"] = "30 Heal",
    ["Enchant Bracer - Major Defense"] = "12 Def",
    ["Enchant Bracer - Stats"] = "4 Stats",
    ["Enchant Bracer - Restore Mana Prime"] = "6 MP5",
    -- Hands
    ["Enchant Gloves - Major Spellpower"] = "20 SP",
    ["Enchant Gloves - Major Strength"] = "15 Str",
    ["Enchant Gloves - Superior Agility"] = "15 Agi",
    ["Enchant Gloves - Major Healing"] = "35 Heal",
    ["Enchant Gloves - Blasting"] = "10 Crit",
    ["Enchant Gloves - Assault"] = "26 AP",
    ["Enchant Gloves - Spell Strike"] = "15 Hit",
    ["Enchant Gloves - Threat"] = "2% Threat",
    ["Enchant Gloves - Frost Power"] = "20 Frost SP",
    ["Glove Reinforcements"] = "240 Armor",
    -- Legs
    ["Runic Spellthread"] = "35 SP / 20 Stam",
    ["Mystic Spellthread"] = "25 SP / 15 Stam",
    ["Silver Spellthread"] = "15 SP / 10 Stam",
    ["Golden Spellthread"] = "66 Heal / 20 Stam",
    ["Nethercobra Leg Armor"] = "50 AP / 12 Crit",
    ["Nethercleft Leg Armor"] = "40 Stam / 12 Agi",
    ["Cobrahide Leg Armor"] = "40 AP / 10 Crit",
    ["Clefthide Leg Armor"] = "30 Stam / 10 Agi",
    -- Feet
    ["Enchant Boots - Cat's Swiftness"] = "6 Agi / Speed",
    ["Enchant Boots - Boar's Speed"] = "9 Stam / Speed",
    ["Enchant Boots - Dexterity"] = "12 Agi",
    ["Enchant Boots - Surefooted"] = "10 Hit / Speed",
    ["Enchant Boots - Fortitude"] = "12 Stam",
    ["Enchant Boots - Vitality"] = "4 HP5 / 4 MP5",
    ["Enchant Boots - Minor Speed"] = "Speed",
    -- Ring
    ["Enchant Ring - Spellpower"] = "12 SP",
    ["Enchant Ring - Healing Power"] = "20 Heal",
    ["Enchant Ring - Stats"] = "4 Stats",
    -- Shield
    ["Enchant Shield - Major Stamina"] = "18 Stam",
    ["Enchant Shield - Intellect"] = "12 Int",
    ["Enchant Shield - Shield Block"] = "15 Block",
    -- Ranged
    ["Khorium Scope"] = "12 Crit",
    ["Stabilitzed Eternium Scope"] = "28 Crit",
    ["Biznicks 247x128 Accurascope"] = "30 Hit",
}

-- Ordered longest-first for deterministic gsub matching
local STAT_ABBREV = {
    {"Minor Speed Increase", "Speed"},
    {"Slightly Increased Attack Speed", "Speed"},
    {"Spell Damage and Healing", "SP"},
    {"Spell Critical Strike Rating", "Spell Crit"},
    {"Spell Hit Rating", "Hit"},
    {"Spell Haste Rating", "Spell Haste"},
    {"Spell Penetration", "Spell Pen"},
    {"Spell Damage", "SP"},
    {"Spell Power", "SP"},
    {"Healing Power", "Heal"},
    {"Healing", "Heal"},
    {"Critical Strike Rating", "Crit"},
    {"Armor Penetration Rating", "ArPen"},
    {"Armor Penetration", "ArPen"},
    {"Expertise Rating", "Expertise"},
    {"Haste Rating", "Haste"},
    {"Hit Rating", "Hit"},
    {"Defense Rating", "Def"},
    {"Resilience Rating", "Resil"},
    {"Dodge Rating", "Dodge"},
    {"Parry Rating", "Parry"},
    {"Block Rating", "Block"},
    {"Block Value", "BV"},
    {"Attack Power", "AP"},
    {"Strength", "Str"},
    {"Agility", "Agi"},
    {"Stamina", "Stam"},
    {"Intellect", "Int"},
    {"Spirit", "Spi"},
    {"Defense", "Def"},
    {"Resilience", "Resil"},
    {"All Stats", "Stats"},
    {"all stats", "Stats"},
    {"mana per 5 sec%.", "MP5"},
    {"mana per 5 sec", "MP5"},
}

local WEAPON_NAME_SLOTS = { [16] = true, [17] = true, [18] = true }

local function IsShieldSlot(slotID)
    if slotID ~= 17 then return false end
    local link = GetInventoryItemLink("player", slotID)
    if not link then return false end
    local _, _, _, _, _, _, _, _, equipLoc = (BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(link)) or GetItemInfo(link)
    return equipLoc == "INVTYPE_SHIELD"
end

local function GetEnchantText(slotID)
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "BCFScanTooltip", nil, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    scanTooltip:ClearLines()
    scanTooltip:SetInventoryItem("player", slotID)

    local lines = scanTooltip:NumLines()
    if lines < 1 then return nil end

    for i = 4, lines do
        local line = _G["BCFScanTooltipTextLeft" .. i]
        if line then
            local text = line:GetText() or ""
            local r, g, b = line:GetTextColor()
            if text ~= "" and r < 0.2 and g > 0.9 and b < 0.2 then
                if not text:find("^Equip:") and not text:find("^Use:") and not text:find("Socket") and not text:find("Set:") then
                    text = text:gsub("Enchant [%w]+ %- ", "")

                    -- Weapons (except shield): raw tooltip text
                    if WEAPON_NAME_SLOTS[slotID] and not IsShieldSlot(slotID) then
                        return text
                    end

                    -- Non-weapons: abbreviate stats, format with " / "
                    text = text:gsub("Restore ", "")
                    for _, pair in ipairs(STAT_ABBREV) do
                        text = text:gsub(pair[1], pair[2])
                    end
                    text = text:gsub(" and ", " / ")
                    text = text:gsub("%+", "")
                    text = text:gsub("to Stats", "Stats")
                    text = text:gsub("^%s+", ""):gsub("%s+$", "")
                    return text
                end
            end
        end
    end
    return nil
end

-- --- Scan a single equipment slot ---
local function ScanSlot(slotInfo)
    local slotID = slotInfo.id
    local link = GetInventoryItemLink("player", slotID)
    local texture = GetInventoryItemTexture("player", slotID)

    local result = {
        slotID = slotID,
        slotName = slotInfo.name,
        slotLabel = slotInfo.label,
        link = link,
        icon = texture,
        isEmpty = (link == nil),
        itemName = "",
        itemLevel = 0,
        quality = 0,
        enchantStatus = "none",   -- "ok", "missing", "none" (not enchantable)
        enchantText = nil,        -- The actual text to display
        gemStatus = "none",       -- "ok", "missing", "partial", "none" (no sockets)
        gems = {},                -- List of gem IDs (filled)
        socketInfo = {},          -- List of socket types { "Red", "Blue" }
        socketCount = 0,
        durability = nil,         -- {current, max} or nil
        durabilityPercent = 100,
    }

    if not link then return result end

    -- Item info
    local itemNameStr, _, itemQuality, itemLevel = (BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(link, function()
        ScheduleMissingItemInfoRefresh()
    end)) or GetItemInfo(link)
    if (not itemLevel or itemLevel <= 0) and GetDetailedItemLevelInfo then
        local detailedILvl = GetDetailedItemLevelInfo(link)
        if detailedILvl and detailedILvl > 0 then
            itemLevel = detailedILvl
        end
    end
    if (not itemQuality) and GetInventoryItemQuality then
        itemQuality = GetInventoryItemQuality("player", slotID)
    end
    result.itemLevel = itemLevel or 0
    result.quality = itemQuality or 1
    result.itemName = itemNameStr or ""

    -- Parse link for enchant and gems
    local parsed = ParseItemLink(link)
    if parsed then
        result.itemID = parsed.itemID

        -- Enchant check
        if ENCHANTABLE_SLOTS[slotID] then
            if parsed.enchantID > 0 then
                result.enchantStatus = "ok"
                result.enchantText = GetEnchantText(slotID) or "Enchanted"
            else
                result.enchantStatus = "missing"
                result.enchantText = "|cffff4444No Enchant|r"
            end
        end

        -- Gem check
        -- GetSocketInfo only detects EMPTY sockets (tooltip text "Red Socket" etc.)
        -- Filled sockets show gem name instead, so also check parsed gem IDs
        local socketInfo = GetSocketInfo(slotID)

        -- Determine total socket count from both sources
        local socketCount = #socketInfo
        for i = 1, 4 do
            if parsed.gems[i] > 0 then
                socketCount = math.max(socketCount, i)
            end
        end

        -- Populate gems array from item link
        for i = 1, socketCount do
            result.gems[i] = parsed.gems[i] or 0
        end

        -- Extend socketInfo for filled positions the tooltip missed
        for i = 1, socketCount do
            if not socketInfo[i] and result.gems[i] > 0 then
                socketInfo[i] = "Prismatic"
            elseif not socketInfo[i] then
                socketInfo[i] = "Prismatic"
            end
        end

        result.socketInfo = socketInfo
        result.socketCount = socketCount

        if socketCount > 0 then
            local filledGems = 0
            for i = 1, socketCount do
                if result.gems[i] > 0 then
                    filledGems = filledGems + 1
                end
            end

            if filledGems >= socketCount then
                result.gemStatus = "ok"
            elseif filledGems > 0 then
                result.gemStatus = "partial"
            else
                result.gemStatus = "missing"
            end
        end
    end

    -- Durability
    local current, maxDur = GetInventoryItemDurability(slotID)
    if current and maxDur and maxDur > 0 then
        result.durability = {current, maxDur}
        result.durabilityPercent = math.floor((current / maxDur) * 100)
    end

    return result
end

-- --- Full gear scan ---
function BCF.ScanGear()
    local gear = {}
    local totalILvl = 0
    local itemCount = 0
    local issues = {
        missingEnchants = {},
        missingGems = {},
        lowDurability = {},
        emptySlots = {},
    }

    for _, slotInfo in ipairs(BCF.EquipSlots) do
        local slotData = ScanSlot(slotInfo)
        gear[slotInfo.id] = slotData

        if slotData.isEmpty then
            table.insert(issues.emptySlots, slotInfo.label)
        else
            totalILvl = totalILvl + slotData.itemLevel
            itemCount = itemCount + 1

            if slotData.enchantStatus == "missing" then
                table.insert(issues.missingEnchants, slotInfo.label)
            end
            if slotData.gemStatus == "missing" or slotData.gemStatus == "partial" then
                table.insert(issues.missingGems, slotInfo.label)
            end
            if slotData.durabilityPercent < 25 then
                table.insert(issues.lowDurability, slotInfo.label)
            end
        end
    end

    local avgILvl = itemCount > 0 and math.floor(totalILvl / itemCount) or 0

    return {
        slots = gear,
        avgItemLevel = avgILvl,
        itemCount = itemCount,
        issues = issues,
    }
end

-- Cache for the last scan to avoid rescanning on every frame
BCF.LastGearScan = nil

function BCF.RefreshGear()
    BCF.LastGearScan = BCF.ScanGear()
    if BCF.UpdateGearTab then
        BCF.UpdateGearTab()
    end
end
