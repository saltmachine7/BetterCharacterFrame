local addonName, BCF = ...

-- ============================================================================
-- MODULE: Core
-- ============================================================================

BCF.Version = C_AddOns and C_AddOns.GetAddOnMetadata
    and C_AddOns.GetAddOnMetadata("BetterCharacterFrame", "Version")
    or GetAddOnMetadata and GetAddOnMetadata("BetterCharacterFrame", "Version")
    or "unknown"
BCF.Name = "BetterCharacterFrame"
BCF.TaintedSession = false
BCF.TaintSource = nil

-- C_Container compatibility (TBC Anniversary vs Classic)
BCF.GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots or
function() return 0 end
BCF.GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink or
function() return nil end
BCF.PickupContainerItem = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem or function() end
BCF.SocketContainerItem = (C_Container and C_Container.SocketContainerItem) or SocketContainerItem or function() end

function BCF.Print(msg)
    if BCF.DB and BCF.DB.General and BCF.DB.General.MuteChat then return end
    print(msg)
end

local CURRENCY_HONOR = 1901
local CURRENCY_ARENA = 1900

function BCF.GetCurrencyAmount(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info and info.quantity then return info.quantity end
    end
    if currencyID == CURRENCY_HONOR and GetHonorCurrency then
        return GetHonorCurrency() or 0
    elseif currencyID == CURRENCY_ARENA and GetArenaCurrency then
        return GetArenaCurrency() or 0
    end
    return 0
end

local ITEM_INFO_RETRY_BASE_DELAY = 0.25
local ITEM_INFO_MAX_RETRIES = 6
local itemInfoWaiters = {}
local itemInfoRetryState = {}

local function ExtractItemID(item)
    if type(item) == "number" then
        return item
    end
    if type(item) == "string" then
        local id = item:match("item:(%-?%d+)") or item:match("^(%-?%d+)$")
        return tonumber(id)
    end
    return nil
end

local function DispatchItemInfo(itemID)
    local waiters = itemInfoWaiters[itemID]
    if not waiters then return false end

    local i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12 = GetItemInfo(itemID)
    if not i1 then return false end

    itemInfoWaiters[itemID] = nil
    itemInfoRetryState[itemID] = nil

    for _, cb in ipairs(waiters) do
        if type(cb) == "function" then
            local ok, err = pcall(cb, i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12)
            if not ok then
                BCF.Print("|cffff6600[BCF]|r ItemInfo callback error: " .. tostring(err))
            end
        end
    end
    return true
end

local function ScheduleItemInfoRetry(itemID)
    if not itemID then return end

    local state = itemInfoRetryState[itemID] or { attempts = 0, pending = false }
    if state.pending or state.attempts >= ITEM_INFO_MAX_RETRIES then return end

    state.pending = true
    state.attempts = state.attempts + 1
    itemInfoRetryState[itemID] = state

    C_Timer.After(ITEM_INFO_RETRY_BASE_DELAY * state.attempts, function()
        state.pending = false
        if not itemInfoWaiters[itemID] then return end
        GetItemInfo(itemID) -- prime request again
        if not DispatchItemInfo(itemID) then
            ScheduleItemInfoRetry(itemID)
        end
    end)
end

function BCF.GetItemInfoSafe(item, callback)
    local i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12 = GetItemInfo(item)
    if i1 then
        return i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12
    end

    local itemID = ExtractItemID(item)
    if callback and itemID then
        itemInfoWaiters[itemID] = itemInfoWaiters[itemID] or {}
        table.insert(itemInfoWaiters[itemID], callback)
        GetItemInfo(itemID) -- prime server request
        ScheduleItemInfoRetry(itemID)
    end
    return nil
end

local itemInfoEventFrame = CreateFrame("Frame")
itemInfoEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoEventFrame:SetScript("OnEvent", function(_, _, itemID, success)
    if not itemID or not itemInfoWaiters[itemID] then return end
    if success == false then
        ScheduleItemInfoRetry(itemID)
        return
    end
    if not DispatchItemInfo(itemID) then
        ScheduleItemInfoRetry(itemID)
    end
end)

-- === DEFERRED SHOW SYSTEM ===
-- Create this frame at load time (clean context) so it can safely show BCF later
local showRequestFrame = CreateFrame("Frame")
local pendingShow = false

local function FlushPendingToggle(self)
    if pendingShow then
        pendingShow = false
        if BCF.MainFrame then
            if BCF.MainFrame:IsShown() then
                BCF.MainFrame:Hide()
            else
                BCF.MainFrame:Show()
                -- Skip direct refresh in combat; OnShow + dirty flags handle deferred refresh
                if not InCombatLockdown() then
                    if BCF.activeHeaderTab == 1 and BCF.activeSubTab == 1 then
                        if BCF.RefreshStats then BCF.RefreshStats() end
                    end
                    if BCF.RefreshGear then BCF.RefreshGear() end
                end
            end
        end
    end
    -- One-shot updater: keep OnUpdate detached while idle.
    self:SetScript("OnUpdate", nil)
end

-- Called from ToggleCharacter hook to safely toggle BCF next frame
local function RequestToggle()
    if pendingShow then return end
    pendingShow = true
    showRequestFrame:SetScript("OnUpdate", FlushPendingToggle)
end

-- === TOGGLE BUTTON ===
-- Keep this as a normal button to avoid restricted-frame handles.
local toggleButton = CreateFrame("Button", "BCFToggleButton", UIParent)
toggleButton:SetSize(1, 1)
toggleButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -100, -100)
toggleButton:Show()
toggleButton:SetScript("OnClick", function()
    RequestToggle()
end)

function BCF.ConnectSecureToggle()
    if BCF.MainFrame and not BCF.SecureToggleConnected then
        -- Sounds via regular hook.
        BCF.MainFrame:HookScript("OnShow", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
            if BCF.dirtyStats and BCF.RefreshStats then
                BCF.RefreshStats()
                if BCF.activeHeaderTab == 1 and BCF.activeSubTab == 1
                    and BCF.SideStats and BCF.SideStats:IsShown() then
                    BCF.RefreshStats(BCF.SideStats)
                end
                BCF.dirtyStats = false
            end
            if BCF.dirtyGear then
                if BCF.RefreshGear then BCF.RefreshGear() end
                if BCF.RefreshCharacter then BCF.RefreshCharacter() end
                BCF.dirtyGear = false
            end
        end)
        BCF.MainFrame:HookScript("OnHide", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
        end)

        BCF.SecureToggleConnected = true
    end
end

function BCF.SetupKeybindOverride()
    if InCombatLockdown() then return end

    local boundKeys = {}
    for _, action in ipairs({ "TOGGLECHARACTER", "TOGGLECHARACTER0" }) do
        local k1, k2 = GetBindingKey(action)
        if k1 and not boundKeys[k1] then boundKeys[k1] = true end
        if k2 and not boundKeys[k2] then boundKeys[k2] = true end
    end

    local hijacked = {}
    for key in pairs(boundKeys) do
        SetOverrideBindingClick(toggleButton, true, key, "BCFToggleButton")
        table.insert(hijacked, key)
    end

    BCF.HijackedKeys = hijacked

    if #hijacked == 0 and not BCF.KeybindOverrideSet then
        BCF.Print("|cff00ccff[BCF]|r Warning: No TOGGLECHARACTER binding found")
    end

    BCF.KeybindOverrideSet = true
end

-- === BLOCK BLIZZARD CHARACTER FRAME ===
-- Prevent Blizzard's CharacterFrame from ever showing
local originalToggleCharacter = ToggleCharacter
local toggleCharacterWrapped = false

local function BlockBlizzardCharacterFrame()
    -- Hook ToggleCharacter to do nothing when BCF is replacing it
    if BCF.DB and BCF.DB.General.ReplaceFrame then
        -- If CharacterFrame exists, hide it and prevent future shows
        if CharacterFrame then
            if not InCombatLockdown() then
                CharacterFrame:Hide()
            end
            if not BCF.CharacterFrameHideHooked then
                CharacterFrame:HookScript("OnShow", function(self)
                    if BCF.DB and BCF.DB.General and BCF.DB.General.ReplaceFrame and not InCombatLockdown() then
                        self:Hide()
                    end
                end)
                BCF.CharacterFrameHideHooked = true
            end
        end

        -- Neuter ToggleCharacter function
        if not toggleCharacterWrapped then
            ToggleCharacter = function(tab)
                -- If BCF is replacing, toggle BCF instead
                if BCF.DB and BCF.DB.General.ReplaceFrame then
                    RequestToggle()
                    return
                end
                -- Fallback to original if ReplaceFrame disabled
                originalToggleCharacter(tab)
            end
            toggleCharacterWrapped = true
        end
    end
end

-- === MICRO BUTTON INTERCEPT ===
-- Overlay CharacterMicroButton to click our secure toggle button
-- This bypasses ToggleCharacter entirely and works in combat
local function SetupMicroButtonIntercept()
    if BCF.MicroButtonHooked then return end

    local microBtn = CharacterMicroButton
    if not microBtn then return end

    -- Only setup if ReplaceFrame is enabled
    if not BCF.DB or not BCF.DB.General.ReplaceFrame then return end

    -- Create invisible overlay that routes clicks to BCF toggle
    -- Parent to microBtn so Dominos detects hover on the bar
    local overlay = CreateFrame("Button", "BCFMicroOverlay", microBtn)
    overlay:SetAllPoints(microBtn)
    overlay:SetFrameLevel(microBtn:GetFrameLevel() + 10)
    overlay:SetScript("OnClick", function()
        RequestToggle()
    end)

    -- Forward hover to the original micro button so highlight + tooltip work natively.
    -- LockHighlight forces the yellow border since the overlay steals mouseover from
    -- the C++-driven widget. The original OnEnter handles tooltip (Dominos compat).
    overlay:SetScript("OnEnter", function(self)
        microBtn:LockHighlight()
        if microBtn:GetScript("OnEnter") then
            microBtn:GetScript("OnEnter")(microBtn)
        end
        -- Append BCF extras to the native tooltip
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("BetterCharacterFrame", 0, 0.8, 1)
        GameTooltip:AddLine("Enhanced stats, gear sets, wishlists & more", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    overlay:SetScript("OnLeave", function(self)
        microBtn:UnlockHighlight()
        if microBtn:GetScript("OnLeave") then
            microBtn:GetScript("OnLeave")(microBtn)
        end
        GameTooltip:Hide()
    end)

    BCF.MicroButtonOverlay = overlay
    BCF.MicroButtonHooked = true
end

-- --- Saved Variables Defaults ---
local DEFAULTS = {
    General = {
        ShowOnLogin = false,
        LockFrame = false,
        ReplaceFrame = true,
        ShowItemDetails = false,
        IsExpanded = false,
        FontFamily = "DEFAULT",
        FontSizeHeader = 14,
        FontSizeItems = 8,
        FontSizeLists = 10,
        UIScale = 1.0,
        ShowILvl = true,
        MuteChat = false,
        ShowGemSockets = true,
        ShowEquippedBiSStar = true,
        EnchantDisplayMode = "ABBREV",
        TitleOrder = { "NAME", "LEVEL", "TALENT", "CLASS", "GUILD" },
    },
    Stats = {
        ShowRatings = true,
        ShowPercentages = true,
        AutoDetectRole = true,
        Collapsed = {}, -- {[role:category] = bool}
    },
    Sets = {
        Collapsed = {}, -- {[setName] = bool}
    },
    Skills = {
        Collapsed = {}, -- {[categoryName] = bool}
    },
    Reputation = {
        FavoritesExpanded = true,
        Collapsed = {}, -- {[headerName] = bool}
    },
    Characters = {},    -- {[charKey] = {GearSets = {}, Wishlist = {}}}
    WindowPos = nil,    -- {point, relativeTo, relativePoint, x, y}
}

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

local function MergeDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            saved[k] = DeepCopy(v)
        elseif type(v) == "table" and type(saved[k]) == "table" then
            MergeDefaults(saved[k], v)
        end
    end
end

function BCF.GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

function BCF.EnsureCharacterStorage()
    local charKey = BCF.GetCharacterKey()
    if not charKey or not BCF.DB then return nil end
    BCF.DB.Characters = BCF.DB.Characters or {}
    BCF.DB.Characters[charKey] = BCF.DB.Characters[charKey] or {}
    return charKey, BCF.DB.Characters[charKey]
end

local function MigrateGearSets()
    if not BCF.DB then return end

    -- If old GearSets format exists, migrate it
    if BCF.DB.GearSets and type(BCF.DB.GearSets) == "table" and next(BCF.DB.GearSets) then
        local charKey = BCF.GetCharacterKey()
        BCF.DB.Characters = BCF.DB.Characters or {}
        BCF.DB.Characters[charKey] = BCF.DB.Characters[charKey] or {}

        -- Only migrate if this character doesn't have sets yet
        if not BCF.DB.Characters[charKey].GearSets or not next(BCF.DB.Characters[charKey].GearSets) then
            BCF.DB.Characters[charKey].GearSets = DeepCopy(BCF.DB.GearSets)
            BCF.Print("|cff00ccff[BCF]|r Migrated " .. #BCF.GetGearSets() .. " gear sets to character-specific storage.")
        end

        -- Clear old storage
        BCF.DB.GearSets = nil
    end

    -- If old Wishlist format exists, migrate it
    if BCF.DB.Wishlist and type(BCF.DB.Wishlist) == "table" and next(BCF.DB.Wishlist) then
        local charKey = BCF.GetCharacterKey()
        BCF.DB.Characters = BCF.DB.Characters or {}
        BCF.DB.Characters[charKey] = BCF.DB.Characters[charKey] or {}

        if not BCF.DB.Characters[charKey].Wishlist or not next(BCF.DB.Characters[charKey].Wishlist) then
            BCF.DB.Characters[charKey].Wishlist = DeepCopy(BCF.DB.Wishlist)
        end

        BCF.DB.Wishlist = nil
    end
end

-- --- Throttled Stat Refresh ---
-- Prevents lag from rapid event spam (UNIT_AURA fires many times per second)
local THROTTLE_INTERVAL = 0.3 -- seconds (allows COMBAT_RATING_UPDATE to arrive after equip)
local COMBAT_PANEL_REFRESH_INTERVAL = 0.2
local pendingStatRefresh = false
local pendingGearRefresh = false
local pendingCombatPanelRefresh = false
local taintNoticeShown = false
BCF.dirtyStats = false
BCF.dirtyGear = false

local function ThrottledRefreshStats()
    if pendingStatRefresh then return end
    pendingStatRefresh = true
    C_Timer.After(THROTTLE_INTERVAL, function()
        pendingStatRefresh = false
        if BCF.MainFrame and BCF.MainFrame:IsShown() and BCF.RefreshStats then
            if BCF.activeHeaderTab == 1 and BCF.activeSubTab == 1 then
                BCF.RefreshStats()
                if BCF.SideStats and BCF.SideStats:IsShown() then
                    BCF.RefreshStats(BCF.SideStats)
                end
                BCF.dirtyStats = false
            else
                BCF.dirtyStats = true
            end
        else
            BCF.dirtyStats = true
        end
    end)
end

local function ThrottledRefreshGear()
    if pendingGearRefresh then return end
    pendingGearRefresh = true
    C_Timer.After(THROTTLE_INTERVAL, function()
        pendingGearRefresh = false
        if InCombatLockdown() then
            BCF.dirtyGear = true
            return
        end
        if BCF.MainFrame and BCF.MainFrame:IsShown() then
            if BCF.RefreshGear then BCF.RefreshGear() end
            if BCF.RefreshCharacter then BCF.RefreshCharacter() end
            BCF.dirtyGear = false
        else
            BCF.dirtyGear = true
        end
    end)
end

local function RefreshVisiblePanelsInCombat()
    if not InCombatLockdown() then return end
    if pendingCombatPanelRefresh then return end
    pendingCombatPanelRefresh = true
    C_Timer.After(COMBAT_PANEL_REFRESH_INTERVAL, function()
        pendingCombatPanelRefresh = false
        if not InCombatLockdown() then return end
        if not (BCF.MainFrame and BCF.MainFrame:IsShown()) then return end

        if BCF.activeHeaderTab == 1 and BCF.activeSubTab == 1 and BCF.RefreshStats then
            BCF.RefreshStats()
            if BCF.SideStats and BCF.SideStats:IsShown() then
                BCF.RefreshStats(BCF.SideStats)
            end
        end

        if BCF.ReputationContainer and BCF.ReputationContainer:IsShown() and BCF.RefreshReputation and BCF.ReputationContent then
            BCF.RefreshReputation(BCF.ReputationContent)
        end
        if BCF.SkillsContainer and BCF.SkillsContainer:IsShown() and BCF.RefreshSkills and BCF.SkillsContent then
            BCF.RefreshSkills(BCF.SkillsContent)
        end
        if BCF.PvPContainer and BCF.PvPContainer:IsShown() and BCF.RefreshPvP and BCF.PvPContent then
            BCF.RefreshPvP(BCF.PvPContent)
        end
        if BCF.CurrencyContainer and BCF.CurrencyContainer:IsShown() and BCF.RefreshCurrency and BCF.CurrencyContent then
            BCF.RefreshCurrency(BCF.CurrencyContent)
        end
    end)
end

-- --- Event Frame ---
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UNIT_STATS")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
eventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
-- Additional events for dynamic stat updates
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("COMBAT_RATING_UPDATE")
eventFrame:RegisterEvent("UNIT_RESISTANCES")
eventFrame:RegisterEvent("UNIT_MAXHEALTH")
eventFrame:RegisterEvent("UNIT_ATTACK_POWER")
eventFrame:RegisterEvent("UNIT_RANGED_ATTACK_POWER")
eventFrame:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
eventFrame:RegisterEvent("UNIT_DEFENSE")
eventFrame:RegisterEvent("SPELL_POWER_CHANGED")
eventFrame:RegisterEvent("ADDON_ACTION_BLOCKED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            -- Bootstrap saved variables
            BetterCharacterFrameDB = BetterCharacterFrameDB or {}
            MergeDefaults(BetterCharacterFrameDB, DEFAULTS)
            BCF.DB = BetterCharacterFrameDB

            -- Migrate old data to character-specific storage
            MigrateGearSets()

            -- Restore window position
            if BCF.DB.WindowPos and BCF.MainFrame then
                local p = BCF.DB.WindowPos
                if type(p[1]) == "string" and type(p[3]) == "string"
                    and type(p[4]) == "number" and type(p[5]) == "number" then
                    BCF.MainFrame:ClearAllPoints()
                    BCF.MainFrame:SetPoint(p[1], UIParent, p[3], p[4], p[5])
                else
                    BCF.DB.WindowPos = nil
                end
            end

            self:UnregisterEvent("ADDON_LOADED")
            BCF.Print("|cff00ccff[BCF]|r BetterCharacterFrame v" ..
            BCF.Version .. " loaded. Type |cff00ff00/bcf|r to open.")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Delayed init after all addons loaded
        C_Timer.After(0.5, function()
            -- Initialize character-specific storage
            local charKey = BCF.GetCharacterKey()
            BCF.DB.Characters = BCF.DB.Characters or {}
            BCF.DB.Characters[charKey] = BCF.DB.Characters[charKey] or {}
            BCF.DB.Characters[charKey].GearSets = BCF.DB.Characters[charKey].GearSets or {}
            BCF.DB.Characters[charKey].GearSetSettings = BCF.DB.Characters[charKey].GearSetSettings or {
                ActiveSet = nil,
            }
            BCF.DB.Characters[charKey].Wishlists = BCF.DB.Characters[charKey].Wishlists or {}
            BCF.DB.Characters[charKey].WishlistSettings = BCF.DB.Characters[charKey].WishlistSettings or {
                ActiveList = nil,
                HiddenLists = {},
                CollapsedSlots = {},
                ShowOverlays = true,
                ShowTooltips = true,
            }
            BCF.DB.Characters[charKey].FavoriteFactions = BCF.DB.Characters[charKey].FavoriteFactions or {}

            -- Migrate old flat Wishlist to multi-list format
            if BCF.MigrateOldWishlist then BCF.MigrateOldWishlist() end

            -- Migrate TitleOrder from old string format to array
            local to = BCF.DB.General.TitleOrder
            if type(to) == "string" then
                local presets = {
                    NAME_LEVEL_TALENT_CLASS_GUILD_TITLE = { "NAME", "LEVEL", "TALENT", "CLASS", "GUILD", "TITLE" },
                    NAME_TITLE_LEVEL_TALENT_CLASS_GUILD = { "NAME", "TITLE", "LEVEL", "TALENT", "CLASS", "GUILD" },
                    NAME_LEVEL_TALENT_CLASS_TITLE_GUILD = { "NAME", "LEVEL", "TALENT", "CLASS", "TITLE", "GUILD" },
                }
                BCF.DB.General.TitleOrder = presets[to] or { "NAME", "LEVEL", "TALENT", "CLASS", "GUILD", "TITLE" }
            end

            -- Initialize stat order based on class/spec (first time only)
            if BCF.InitCharacterStatOrder then
                BCF.InitCharacterStatOrder()
            end

            -- Pre-create frame so it's ready for combat use
            if not BCF.MainFrame and BCF.CreateMainFrame then
                BCF.CreateMainFrame()
            end

            -- Connect secure toggle after frame exists
            if BCF.ConnectSecureToggle then
                BCF.ConnectSecureToggle()
            end

            if BCF.RefreshStats then BCF.RefreshStats() end
            if BCF.RefreshGear then BCF.RefreshGear() end
            if BCF.DB.General.ShowOnLogin and BCF.MainFrame then
                BCF.MainFrame:Show()
            end
        end)
    elseif event == "UNIT_STATS" or event == "UNIT_AURA" or event == "UNIT_RESISTANCES"
        or event == "UNIT_MAXHEALTH" or event == "UNIT_ATTACK_POWER"
        or event == "UNIT_RANGED_ATTACK_POWER" or event == "UNIT_DEFENSE" then
        local unit = ...
        if unit == "player" then
            ThrottledRefreshStats()
            RefreshVisiblePanelsInCombat()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        if BCF.HideFlyoutPanel then
            BCF.HideFlyoutPanel()
        end
        if InCombatLockdown() then
            if BCF.RefreshCombatSlotVisual then
                BCF.RefreshCombatSlotVisual(slotID)
            end
            BCF.dirtyGear = true
            RefreshVisiblePanelsInCombat()
        else
            ThrottledRefreshGear()
        end
        ThrottledRefreshStats()
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "UPDATE_INVENTORY_DURABILITY"
        or event == "BAG_UPDATE_COOLDOWN" then
        if InCombatLockdown() and BCF.RefreshCombatCooldowns and event == "BAG_UPDATE_COOLDOWN" then
            BCF.RefreshCombatCooldowns()
        end
        ThrottledRefreshGear()
        ThrottledRefreshStats()
        RefreshVisiblePanelsInCombat()
    elseif event == "CHARACTER_POINTS_CHANGED" or event == "PLAYER_LEVEL_UP"
        or event == "COMBAT_RATING_UPDATE" or event == "PLAYER_DAMAGE_DONE_MODS"
        or event == "SPELL_POWER_CHANGED" then
        ThrottledRefreshStats()
        RefreshVisiblePanelsInCombat()
    elseif event == "ADDON_ACTION_BLOCKED" then
        local blockedAddon = ...
        if blockedAddon and blockedAddon ~= "" and blockedAddon ~= addonName then
            BCF.TaintedSession = true
            BCF.TaintSource = blockedAddon
            if not taintNoticeShown then
                taintNoticeShown = true
                BCF.Print("|cff00ccff[BCF]|r Tainted session detected (" ..
                blockedAddon .. "). Combat flyout weapon swaps are temporarily disabled.")
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            if BCF.MainFrame and BCF.MainFrame:IsShown() then
                if BCF.activeHeaderTab == 1 and BCF.activeSubTab == 1 then
                    if BCF.RefreshStats then BCF.RefreshStats() end
                end
                if BCF.RefreshGear then BCF.RefreshGear() end
            end
        end)

        -- Setup micro button intercept (bypasses ToggleCharacter, works in combat)
        SetupMicroButtonIntercept()

        -- Block Blizzard CharacterFrame from showing
        BlockBlizzardCharacterFrame()

        -- Setup keybind override (must be after bindings are loaded)
        C_Timer.After(0.2, function()
            if BCF.DB and BCF.DB.General.ReplaceFrame then
                BCF.SetupKeybindOverride()
            end
        end)
    end
end)

function BCF.Toggle()
    if InCombatLockdown() then
        local keyHint = BCF.HijackedKeys and #BCF.HijackedKeys > 0 and BCF.HijackedKeys[1] or "keybind"
        BCF.Print("|cff00ccff[BCF]|r Use " ..
        keyHint .. " or micro button in combat - slash commands can't toggle frames.")
        return
    end

    -- Out of combat: normal operation
    if not BCF.MainFrame then
        if BCF.CreateMainFrame then
            BCF.CreateMainFrame()
        end
        -- Connect secure toggle for future combat use
        if BCF.ConnectSecureToggle then
            BCF.ConnectSecureToggle()
        end
    end
    if BCF.MainFrame then
        if BCF.MainFrame:IsShown() then
            BCF.MainFrame:Hide()
        else
            BCF.MainFrame:Show()
            if BCF.activeHeaderTab == 1 and BCF.activeSubTab == 1 then
                if BCF.RefreshStats then BCF.RefreshStats() end
            end
            if BCF.RefreshGear then BCF.RefreshGear() end
        end
    end
end

-- --- Combat Queue for Delayed Frame Creation ---
local combatQueueFrame = CreateFrame("Frame")
combatQueueFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatQueueFrame:SetScript("OnEvent", function()
    if BCF.PendingCreate then
        BCF.PendingCreate = false
        BCF.Toggle()
    end
end)

-- --- Slash Commands ---
SLASH_BCF1 = "/bcf"
SLASH_BCF2 = "/bettercharacterframe"
SlashCmdList["BCF"] = function(msg)
    local msgTrimmed = strtrim and strtrim(msg or "") or ((msg or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    local msgLower = msgTrimmed:lower()
    if msgLower == "options" or msgLower == "config" then
        BCF.Toggle()
    elseif msgLower == "version" or msgLower == "ver" then
        BCF.Print("|cff00ccff[BCF]|r Version " .. BCF.Version)
    elseif msgLower == "reset" then
        -- Clear this character's data and reset to defaults
        local charKey = BCF.GetCharacterKey()
        if BCF.DB and BCF.DB.Characters then
            BCF.DB.Characters[charKey] = nil
        end
        if BCF.DB and BCF.DB.Reputation then
            BCF.DB.Reputation.Collapsed = {}
        end
        if BCF.DB and BCF.DB.General then
            BCF.DB.General.IsExpanded = false
            BCF.DB.General.ShowItemDetails = false
        end
        if BCF.DB then
            BCF.DB.WindowPos = nil
        end
        BCF.Print("|cff00ccff[BCF]|r Character data cleared for |cff00ff00" .. charKey .. "|r")
        BCF.Print("|cff00ccff[BCF]|r Type |cff00ff00/reload|r to complete the reset.")
    elseif msgLower:match("^equipset%s+") then
        -- /bcf equipset SetName: equip/queue all non-weapon slots only
        local setName = msg:match("^[eE][qQ][uU][iI][pP][sS][eE][tT]%s+(.+)$")
        if setName and BCF.EquipGearSet then
            BCF.EquipGearSet(setName, true)
        else
            BCF.Print("|cff00ccff[BCF]|r Usage: /bcf equipset SetName")
        end
    elseif msgLower:match("^equip%s+") then
        -- /bcf equip SetName: equip/queue all non-weapon slots only
        local setName = msg:match("^[eE][qQ][uU][iI][pP]%s+(.+)$")
        if setName and BCF.EquipGearSet then
            BCF.EquipGearSet(setName, true)
        else
            BCF.Print("|cff00ccff[BCF]|r Usage: /bcf equip SetName")
        end
    elseif msgLower == "debug" then
        BCF.DEBUG = not BCF.DEBUG
        BCF.Print("|cff00ccff[BCF]|r Debug mode " .. (BCF.DEBUG and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
    elseif BCF.DEBUG and msgLower == "test pet" then
        if BCF._testPetActive then
            BCF._testPetData = nil
            BCF._testPetActive = false
            if BCF.RemovePetTab then BCF.RemovePetTab() end
            BCF.Print("|cff00ccff[BCF]|r Test pet |cffff4444cleared|r.")
        else
            BCF._testPetData = {
                name = "Deranged Hellboar",
                level = 70,
                family = "Boar",
                happiness = 3,
                loyalty = "Best Friend",
                xp = 3400,
                xpMax = 5000,
                tpTotal = 20,
                tpSpent = 12,
                stats = {
                    [1] = { 62, 62, 0, 0 },
                    [2] = { 78, 78, 0, 0 },
                    [3] = { 388, 388, 0, 0 },
                    [4] = { 0, 0, 0, 0 },
                    [5] = { 53, 53, 0, 0 },
                },
                ap = { 336, 0, 0 },
                damage = { 68, 94 },
                speed = 2.0,
                armor = { 4850, 4850 },
                resistances = {
                    [2] = { 0, 45 },
                    [3] = { 0, 30 },
                    [4] = { 0, 40 },
                    [5] = { 0, 25 },
                    [6] = { 0, 20 },
                },
            }
            BCF._testPetActive = true
            if BCF.InjectPetTab then BCF.InjectPetTab() end
            BCF.Print("|cff00ccff[BCF]|r Test pet |cff00ff00active|r.")
        end
        if BCF.PetContainer and BCF.PetContainer:IsShown() and BCF.RefreshPet then
            BCF.RefreshPet(BCF.PetContainer)
        end
    elseif BCF.DEBUG and msgLower == "tp" then
        if BCF.PetTPText then
            if BCF.PetTPText:IsShown() then
                BCF.PetTPText:Hide()
            else
                BCF.PetTPText:SetText("TP: 8 / 20")
                BCF.PetTPText:Show()
            end
        end
    elseif BCF.DEBUG and msgLower == "debuggems" then
        local scan = BCF.ScanGear and BCF.ScanGear()
        if not scan then
            BCF.Print("|cff00ccff[BCF]|r No scan data.")
            return
        end
        BCF.Print("|cff00ccff[BCF]|r ShowGemSockets=" ..
        tostring(BCF.DB and BCF.DB.General and BCF.DB.General.ShowGemSockets))
        for slotID, data in pairs(scan.slots or {}) do
            if not data.isEmpty and data.socketCount and data.socketCount > 0 then
                local parts = {}
                for i = 1, data.socketCount do
                    local st = data.socketInfo and data.socketInfo[i] or "?"
                    local gid = data.gems and data.gems[i] or 0
                    table.insert(parts, st .. ":" .. tostring(gid))
                end
                print("  Slot " .. slotID .. ": " .. table.concat(parts, ", "))
            end
        end
    elseif BCF.DEBUG and msgLower == "validate" then
        if BCF.ValidateBiSData then
            BCF.ValidateBiSData()
        end
    else
        BCF.Toggle()
    end
end

-- Global toggle for macro/keybind support
function BetterCharacterFrame_Toggle()
    BCF.Toggle()
end
