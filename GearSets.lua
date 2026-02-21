local addonName, BCF = ...

-- ============================================================================
-- MODULE: GearSets
-- ============================================================================

local function GetCharacterGearSets()
    local _, charData = BCF.EnsureCharacterStorage()
    if not charData then return {} end
    charData.GearSets = charData.GearSets or {}
    return charData.GearSets
end

local function GetGearSetSettings()
    local _, charData = BCF.EnsureCharacterStorage()
    if not charData then return { ActiveSet = nil } end
    charData.GearSetSettings = charData.GearSetSettings or {
        ActiveSet = nil,
    }
    return charData.GearSetSettings
end

function BCF.GetActiveGearSet()
    return GetGearSetSettings().ActiveSet
end

function BCF.SetActiveGearSet(setName)
    local settings = GetGearSetSettings()
    settings.ActiveSet = setName
end

local function GetGearSetMacroName(setName)
    return "BCF:" .. setName:sub(1, 12)
end

local function ExtractItemID(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

function BCF.IsGearSetFullyEquipped(setName)
    if not setName or setName == "" then return false end
    local gearSets = GetCharacterGearSets()
    local setData = gearSets[setName]
    if not setData or not setData.slots then return false end

    local comparedSlots = 0
    for slotID, slotData in pairs(setData.slots) do
        if type(slotID) == "number" and slotID >= 1 and slotID <= 18 and slotData and slotData.link then
            comparedSlots = comparedSlots + 1
            local equippedLink = GetInventoryItemLink("player", slotID)
            if not equippedLink then
                return false
            end
            local expectedID = ExtractItemID(slotData.link)
            local equippedID = ExtractItemID(equippedLink)
            if not expectedID or not equippedID or expectedID ~= equippedID then
                return false
            end
        end
    end

    return comparedSlots > 0
end

local function GetMacroItemToken(slotData)
    if not slotData or not slotData.link then return nil end
    -- Prefer stable saved item name (works best for /equipslot with spaces).
    if slotData.name and slotData.name ~= "" and slotData.name ~= "Unknown" then
        return slotData.name
    end
    local liveName = BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(slotData.link) or GetItemInfo(slotData.link)
    if liveName and liveName ~= "" then
        return liveName
    end
    local itemID = slotData.link:match("item:(%d+)")
    if itemID then
        return "item:" .. itemID
    end
    return nil
end

function BCF.BuildGearSetMacroBody(setName)
    local gearSets = GetCharacterGearSets()
    local setData = gearSets[setName]
    if not setData or not setData.slots then
        return "/bcf equipset " .. setName
    end

    local lines = { "/bcf equipset " .. setName }
    for _, slotID in ipairs({ 16, 17, 18 }) do
        local slotData = setData.slots[slotID]
        local token = GetMacroItemToken(slotData)
        if token and token ~= "" then
            table.insert(lines, "/equipslot " .. slotID .. " " .. token)
        end
    end

    return table.concat(lines, "\n")
end

function BCF.TriggerGearSetMacro(setName)
    if not setName or setName == "" then return false end
    BCF.SetActiveGearSet(setName)

    if InCombatLockdown() then
        -- Running macro text from insecure Lua in combat is not reliable/protected.
        -- Fall back to safe armor-only queue and let explicit action-bar macros handle weapons.
        if BCF.EquipGearSet then
            BCF.EquipGearSet(setName, true)
        end
        if BCF.TaintedSession then
            BCF.Print("|cff00ccff[BCF]|r Tainted session: in-combat weapon swap blocked on set button.")
        end
        C_Timer.After(0.1, function()
            if BCF.RefreshGear then BCF.RefreshGear() end
            if BCF.RefreshCharacter then BCF.RefreshCharacter() end
        end)
        return true
    end

    if BCF.EquipGearSet then
        -- Out of combat: use direct full-set equip (including weapons).
        -- This avoids RunMacroText failures in tainted sessions.
        local ok = BCF.EquipGearSet(setName, false)
        C_Timer.After(0.1, function()
            if BCF.RefreshGear then BCF.RefreshGear() end
            if BCF.RefreshCharacter then BCF.RefreshCharacter() end
        end)
        return ok
    end
    return false
end

function BCF.SyncGearSetMacro(setName, macroIcon)
    if not setName or setName == "" then return end
    local macroName = GetGearSetMacroName(setName)
    local macroBody = BCF.BuildGearSetMacroBody(setName)
    local macroIndex = GetMacroIndexByName(macroName)
    if macroIndex and macroIndex > 0 then
        EditMacro(macroIndex, macroName, macroIcon or nil, macroBody, nil)
    end
end

-- --- Save current equipped gear as a named set ---
-- updateExisting: if true, preserves icon and createdAt; if false/nil, creates new
function BCF.SaveGearSet(name, updateExisting)
    local gearSets = GetCharacterGearSets()
    local existingSet = gearSets[name]

    -- Calculate next sortIndex for new sets (max + 1)
    local nextSortIndex = 1
    if not (updateExisting and existingSet) then
        for _, data in pairs(gearSets) do
            if data.sortIndex and data.sortIndex >= nextSortIndex then
                nextSortIndex = data.sortIndex + 1
            end
        end
    end

    local setData = {
        name = name,
        icon = (updateExisting and existingSet and existingSet.icon) or "Interface\\Icons\\INV_Misc_Note_01",
        createdAt = (updateExisting and existingSet and existingSet.createdAt) or time(),
        sortIndex = (updateExisting and existingSet and existingSet.sortIndex) or nextSortIndex,
        slots = {},
    }

    for _, slotInfo in ipairs(BCF.EquipSlots) do
        local link = GetInventoryItemLink("player", slotInfo.id)
        local texture = GetInventoryItemTexture("player", slotInfo.id)
        if link then
            local itemName = BCF.GetItemInfoSafe and BCF.GetItemInfoSafe(link) or GetItemInfo(link)
            setData.slots[slotInfo.id] = {
                link = link,
                icon = texture,
                name = itemName or "Unknown",
            }
        end
    end

    -- Use name as key (overwrite if same name)
    gearSets[name] = setData
    BCF.SyncGearSetMacro(name, setData.icon)
    BCF.Print("|cff00ccff[BCF]|r Gear set |cff00ff00" .. name .. "|r saved!")

    if BCF.RefreshSets and BCF.SideStats then BCF.RefreshSets(BCF.SideStats) end
end

-- --- Delete a saved gear set ---
function BCF.DeleteGearSet(name)
    local gearSets = GetCharacterGearSets()
    if gearSets[name] then
        gearSets[name] = nil
        if BCF.GetActiveGearSet and BCF.GetActiveGearSet() == name then
            BCF.SetActiveGearSet(nil)
        end
        BCF.Print("|cff00ccff[BCF]|r Gear set |cffff6600" .. name .. "|r deleted.")
        if BCF.RefreshSets and BCF.SideStats then BCF.RefreshSets(BCF.SideStats) end
    end
end

-- --- List all saved gear sets ---
function BCF.GetGearSets()
    local gearSets = GetCharacterGearSets()
    local sets = {}
    for name, data in pairs(gearSets) do
        -- Ensure sortIndex exists
        if not data.sortIndex then data.sortIndex = data.createdAt or 0 end
        table.insert(sets, data)
    end
    -- Sort by sortIndex
    table.sort(sets, function(a, b)
        if a.sortIndex ~= b.sortIndex then
            return (a.sortIndex or 0) < (b.sortIndex or 0)
        end
        return (a.createdAt or 0) < (b.createdAt or 0)
    end)
    return sets
end

-- --- Reorder Gear Sets (Update sortIndex) ---
function BCF.ReorderGearSets(fromIndex, toIndex)
    local gearSets = GetCharacterGearSets()
    local sets = BCF.GetGearSets()

    if not sets[fromIndex] then return false end
    if fromIndex == toIndex then return false end

    local movingSet = table.remove(sets, fromIndex)

    if toIndex > #sets + 1 then toIndex = #sets + 1 end
    if toIndex < 1 then toIndex = 1 end
    table.insert(sets, toIndex, movingSet)

    for i, data in ipairs(sets) do
        data.sortIndex = i
        if gearSets[data.name] then
            gearSets[data.name].sortIndex = i
        end
    end

    return true
end

-- --- Equip a saved gear set ---
local WEAPON_SLOTS = { [16] = true, [17] = true, [18] = true }
local pendingGearQueue = nil -- { name = string, items = { link, ... } }

function BCF.GetQueuedGearSetName()
    return pendingGearQueue and pendingGearQueue.name or nil
end

local function RefreshVisibleSetList()
    if not BCF.RefreshSets then return end
    if not (BCF.MainFrame and BCF.MainFrame:IsShown()) then return end
    if BCF.activeHeaderTab ~= 1 or BCF.activeSubTab ~= 2 then return end
    BCF.RefreshSets(BCF.SideStats)
end

function BCF.EquipGearSet(name, armorOnly)
    local gearSets = GetCharacterGearSets()
    local setData = gearSets[name]

    if not setData then
        BCF.Print("|cff00ccff[BCF]|r Gear set |cffff6600" .. name .. "|r not found.")
        return false
    end

    local inCombat = InCombatLockdown()
    local equipped = 0
    BCF.SetActiveGearSet(name)

    if inCombat then
        local queuedTotal, queuedWeapons, queuedArmor = 0, 0, 0
        pendingGearQueue = { name = name, items = {} }
        for slotID, slotData in pairs(setData.slots) do
            if slotData.link and (not armorOnly or not WEAPON_SLOTS[slotID]) then
                table.insert(pendingGearQueue.items, slotData.link)
                queuedTotal = queuedTotal + 1
                if WEAPON_SLOTS[slotID] then
                    queuedWeapons = queuedWeapons + 1
                else
                    queuedArmor = queuedArmor + 1
                end
            end
        end
        if queuedTotal > 0 then
            if armorOnly then
                BCF.Print("|cff00ccff[BCF]|r Gear set |cff00ff00" ..
                name .. "|r queued (" .. queuedArmor .. " non-weapon items) for after combat.")
            else
                BCF.Print("|cff00ccff[BCF]|r Gear set |cff00ff00" ..
                name .. "|r queued (" .. queuedWeapons .. " weapons, " .. queuedArmor .. " armor) for after combat.")
            end
        else
            pendingGearQueue = nil
        end
        RefreshVisibleSetList()
        return true
    end

    for slotID, slotData in pairs(setData.slots) do
        if slotData.link and (not armorOnly or not WEAPON_SLOTS[slotID]) then
            EquipItemByName(slotData.link)
            equipped = equipped + 1
        end
    end

    if equipped > 0 then
        if armorOnly then
            BCF.Print("|cff00ccff[BCF]|r Equipped " .. equipped .. " non-weapon items from |cff00ff00" .. name .. "|r")
        else
            BCF.Print("|cff00ccff[BCF]|r Equipped " .. equipped .. " items from |cff00ff00" .. name .. "|r")
        end
    end
    RefreshVisibleSetList()
    return true
end

-- Combat queue: auto-equip queued gear when combat ends
local combatQueueFrame = CreateFrame("Frame")
combatQueueFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatQueueFrame:SetScript("OnEvent", function()
    if not pendingGearQueue then return end
    local items = pendingGearQueue.items
    local name = pendingGearQueue.name
    pendingGearQueue = nil
    for _, link in ipairs(items) do
        EquipItemByName(link)
    end
    BCF.Print("|cff00ccff[BCF]|r Equipped queued set |cff00ff00" .. name .. "|r")
    RefreshVisibleSetList()
    C_Timer.After(0.5, function()
        if BCF.RefreshGear then BCF.RefreshGear() end
        if BCF.RefreshCharacter then BCF.RefreshCharacter() end
    end)
end)

-- --- Rename a gear set ---
function BCF.RenameGearSet(oldName, newName)
    local gearSets = GetCharacterGearSets()
    if gearSets[oldName] then
        local oldMacroName = GetGearSetMacroName(oldName)
        local oldMacroIndex = GetMacroIndexByName(oldMacroName)
        local data = gearSets[oldName]
        data.name = newName
        gearSets[newName] = data
        gearSets[oldName] = nil
        if oldMacroIndex and oldMacroIndex > 0 then
            local newMacroName = GetGearSetMacroName(newName)
            local newMacroBody = BCF.BuildGearSetMacroBody(newName)
            EditMacro(oldMacroIndex, newMacroName, data.icon or nil, newMacroBody, nil)
        else
            BCF.SyncGearSetMacro(newName, data.icon)
        end
        if BCF.GetActiveGearSet and BCF.GetActiveGearSet() == oldName then
            BCF.SetActiveGearSet(newName)
        end
        BCF.Print("|cff00ccff[BCF]|r Gear set renamed to |cff00ff00" .. newName .. "|r.")
        if BCF.RefreshSets and BCF.SideStats then BCF.RefreshSets(BCF.SideStats) end
    end
end
