local addonName, BCF = ...

-- ============================================================================
-- MODULE: PvP
-- ============================================================================

local T = BCF.Tokens
local CLASS_COLOR = {T.Accent[1], T.Accent[2], T.Accent[3]}

-- Class colors for roster display
local CLASS_COLORS = {
    ["Warrior"]     = {0.78, 0.61, 0.43},
    ["Paladin"]     = {0.96, 0.55, 0.73},
    ["Hunter"]      = {0.67, 0.83, 0.45},
    ["Rogue"]       = {1.00, 0.96, 0.41},
    ["Priest"]      = {1.00, 1.00, 1.00},
    ["Shaman"]      = {0.00, 0.44, 0.87},
    ["Mage"]        = {0.41, 0.80, 0.94},
    ["Warlock"]     = {0.58, 0.51, 0.79},
    ["Druid"]       = {1.00, 0.49, 0.04},
}

-- Collapse state for sections
local collapseState = {
    ["Today"] = false,
    ["Yesterday"] = true,
}

-- Arena bracket labels
local BRACKET_LABELS = {"2v2", "3v3", "5v5"}

-- ============================================================================
-- ROW POOL
-- ============================================================================
local GetRow, ReleaseRow = BCF.CreateRowPool(
    function(row)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 30, 0)
        row.icon:Hide()

        row.value = BCF.CleanFont(row:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
        row.value:SetPoint("RIGHT", -8, 0)
        row.value:SetJustifyH("RIGHT")
    end,
    function(row)
        row.expandBtn:Hide()
        row.icon:Hide()
        row.value:SetText("")
    end
)

-- ============================================================================
-- CONFIRMATION DIALOG (shared for Leave/Disband)
-- ============================================================================
local confirmDialog = CreateFrame("Frame", "BCFPvPConfirm", UIParent, "BackdropTemplate")
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
confirmYesText:SetText("Confirm")
confirmYesText:SetTextColor(1, 0.4, 0.4)
confirmYes:SetScript("OnEnter", function(self) self:SetBackdropColor(0.6, 0.2, 0.2, 1) end)
confirmYes:SetScript("OnLeave", function(self) self:SetBackdropColor(0.5, 0.15, 0.15, 1) end)

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
confirmNo:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.2, 0.24, 1) end)
confirmNo:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.18, 1) end)
confirmNo:SetScript("OnClick", function() confirmDialog:Hide() end)

local function ShowConfirm(text, warnText, onConfirm)
    confirmText:SetText(text)
    confirmWarn:SetText(warnText or "This cannot be undone!")
    confirmYes:SetScript("OnClick", function()
        confirmDialog:Hide()
        onConfirm()
    end)
    BCF.ShowRightOfMain(confirmDialog)
    confirmDialog:Show()
end

-- ============================================================================
-- INVITE DIALOG
-- ============================================================================
local inviteDialog = CreateFrame("Frame", "BCFPvPInvite", UIParent, "BackdropTemplate")
inviteDialog:SetSize(280, 100)
inviteDialog:SetFrameStrata("DIALOG")
inviteDialog:SetPoint("CENTER")
inviteDialog:EnableMouse(true)
inviteDialog:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1
})
inviteDialog:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
inviteDialog:SetBackdropBorderColor(T.Accent[1]*0.6, T.Accent[2]*0.6, T.Accent[3]*0.6, 1)
inviteDialog:Hide()

local inviteLabel = BCF.CleanFont(inviteDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
inviteLabel:SetPoint("TOP", 0, -12)
inviteLabel:SetText("Invite player to arena team")
inviteLabel:SetTextColor(1, 1, 1)

local inviteEdit = CreateFrame("EditBox", nil, inviteDialog, "BackdropTemplate")
inviteEdit:SetSize(200, 22)
inviteEdit:SetPoint("TOP", inviteLabel, "BOTTOM", 0, -8)
inviteEdit:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
inviteEdit:SetBackdropColor(0.1, 0.1, 0.12, 1)
inviteEdit:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
inviteEdit:SetFontObject("GameFontHighlight")
BCF.CleanFont(inviteEdit)
inviteEdit:SetAutoFocus(false)
inviteEdit:SetMaxLetters(40)
inviteEdit:SetTextInsets(6, 6, 0, 0)

local inviteOk = CreateFrame("Button", nil, inviteDialog, "BackdropTemplate")
inviteOk:SetSize(80, 24)
inviteOk:SetPoint("BOTTOMLEFT", 30, 10)
inviteOk:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
inviteOk:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 1)
inviteOk:SetBackdropBorderColor(T.Accent[1]*0.6, T.Accent[2]*0.6, T.Accent[3]*0.6, 1)
local inviteOkText = BCF.CleanFont(inviteOk:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
inviteOkText:SetPoint("CENTER", 0, 0)
inviteOkText:SetText("Invite")
inviteOkText:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3])
inviteOk:SetScript("OnEnter", function(self) self:SetBackdropColor(T.Accent[1]*0.4, T.Accent[2]*0.4, T.Accent[3]*0.4, 1) end)
inviteOk:SetScript("OnLeave", function(self) self:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 1) end)

local inviteCancel = CreateFrame("Button", nil, inviteDialog, "BackdropTemplate")
inviteCancel:SetSize(80, 24)
inviteCancel:SetPoint("BOTTOMRIGHT", -30, 10)
inviteCancel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
inviteCancel:SetBackdropColor(0.15, 0.15, 0.18, 1)
inviteCancel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
local inviteCancelText = BCF.CleanFont(inviteCancel:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
inviteCancelText:SetPoint("CENTER", 0, 0)
inviteCancelText:SetText("Cancel")
inviteCancelText:SetTextColor(0.8, 0.8, 0.8)
inviteCancel:SetScript("OnEnter", function(self) self:SetBackdropColor(0.2, 0.2, 0.24, 1) end)
inviteCancel:SetScript("OnLeave", function(self) self:SetBackdropColor(0.15, 0.15, 0.18, 1) end)
inviteCancel:SetScript("OnClick", function() inviteDialog:Hide() end)

inviteEdit:SetScript("OnEscapePressed", function() inviteDialog:Hide() end)
inviteEdit:SetScript("OnEnterPressed", function(self)
    local name = self:GetText()
    if name and name ~= "" and inviteDialog.teamIndex then
        ArenaTeamInviteByName(inviteDialog.teamIndex, name)
        inviteDialog:Hide()
    end
end)

local function ShowInviteDialog(teamIndex)
    inviteDialog.teamIndex = teamIndex
    inviteEdit:SetText("")
    inviteOk:SetScript("OnClick", function()
        local name = inviteEdit:GetText()
        if name and name ~= "" then
            ArenaTeamInviteByName(teamIndex, name)
            inviteDialog:Hide()
        end
    end)
    BCF.ShowRightOfMain(inviteDialog)
    inviteDialog:Show()
    inviteEdit:SetFocus()
end

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
            if BCF.PvPContent then BCF.RefreshPvP(BCF.PvPContent) end
        end
    end)
    row:SetScript("OnEnter", function(self) self:SetBackdropColor(cc[1]*0.2, cc[2]*0.2, cc[3]*0.2, 1) end)
    row:SetScript("OnLeave", function(self) self:SetBackdropColor(cc[1]*0.12, cc[2]*0.12, cc[3]*0.12, 0.9) end)

    return yOffset - T.HeaderRowHeight, rowIndex
end

local function RenderStatRow(container, rows, yOffset, rowIndex, label, val, color, iconID)
    local row = GetRow(container)
    rowIndex = rowIndex + 1
    table.insert(rows, row)

    row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
    row:SetPoint("RIGHT", container, "RIGHT", -5, 0)
    local bgAlpha = BCF.ApplyRowStripe(row, rowIndex)
    row.expandBtn:Hide()

    if iconID then
        row.icon:SetTexture(iconID)
        row.icon:Show()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    else
        row.icon:Hide()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 30, 0)
    end
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
-- REFRESH PVP
-- ============================================================================
function BCF.RefreshPvP(container)
    if not container then return end

    local scrollFrame = container:GetParent()
    if scrollFrame then
        container:SetWidth(scrollFrame:GetWidth() - 5)
    end

    -- Release existing rows
    container.pvpRows = container.pvpRows or {}
    for _, row in ipairs(container.pvpRows) do
        ReleaseRow(row)
    end
    container.pvpRows = {}

    local yOffset = -5
    local rowIndex = 0
    local cc = CLASS_COLOR
    local rows = container.pvpRows

    -- ==================================================================
    -- HONOR & CURRENCY
    -- ==================================================================
    local honorPoints = BCF.GetCurrencyAmount(1901)
    local arenaPoints = BCF.GetCurrencyAmount(1900)
    local hk, dk, highestRank = 0, 0, 0
    if GetPVPLifetimeStats then
        hk, dk, highestRank = GetPVPLifetimeStats()
    end

    local rankName = ""
    if GetPVPRankInfo and highestRank and highestRank > 0 then
        rankName = GetPVPRankInfo(highestRank) or ""
    end

    local faction = UnitFactionGroup("player")
    local honorIcon = (faction == "Horde") and 132485 or 132486

    yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
        "Honor Points", honorPoints, {T.Accent[1], T.Accent[2], T.Accent[3]}, honorIcon)
    yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
        "Arena Points", arenaPoints, {T.Accent[1], T.Accent[2], T.Accent[3]}, 4006481)
    yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
        "Lifetime Honorable Kills", hk or 0)
    if rankName and rankName ~= "" then
        yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
            "Highest Rank", rankName, {0.9, 0.8, 0.5})
    end

    -- Spacer
    yOffset = yOffset - 6

    -- ==================================================================
    -- TODAY
    -- ==================================================================
    local todayHK, todayHP = 0, 0
    if GetPVPSessionStats then
        todayHK, todayHP = GetPVPSessionStats()
    end

    yOffset, rowIndex = RenderHeader(container, rows, yOffset, rowIndex, "Today", "Today")
    if not collapseState["Today"] then
        yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
            "Honorable Kills", todayHK or 0)
        yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
            "Estimated Honor", todayHP or 0)
    end

    -- ==================================================================
    -- YESTERDAY
    -- ==================================================================
    local yesterHK, yesterDK, yesterContrib = 0, 0, 0
    if GetPVPYesterdayStats then
        yesterHK, yesterDK, yesterContrib = GetPVPYesterdayStats()
    end

    yOffset, rowIndex = RenderHeader(container, rows, yOffset, rowIndex, "Yesterday", "Yesterday")
    if not collapseState["Yesterday"] then
        yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
            "Honorable Kills", yesterHK or 0)
        yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
            "Honor", yesterContrib or 0)
    end

    -- Spacer
    yOffset = yOffset - 6

    -- ==================================================================
    -- ARENA TEAMS
    -- ==================================================================
    for teamIndex = 1, 3 do
        local bracketLabel = BRACKET_LABELS[teamIndex]
        local teamName, teamSize, teamRating, weekPlayed, weekWins,
              seasonPlayed, seasonWins, playerPlayed, seasonPlayerPlayed,
              teamRank, playerRating

        if GetArenaTeam then
            teamName, teamSize, teamRating, weekPlayed, weekWins,
                seasonPlayed, seasonWins, playerPlayed, seasonPlayerPlayed,
                teamRank, playerRating = GetArenaTeam(teamIndex)
        end

        local stateKey = "Arena" .. teamIndex

        if teamName and teamName ~= "" then
            -- Team exists: render header with name and rating
            if collapseState[stateKey] == nil then
                collapseState[stateKey] = false
            end

            -- Header
            local headerRow = GetRow(container)
            rowIndex = rowIndex + 1
            table.insert(rows, headerRow)
            headerRow:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
            headerRow:SetPoint("RIGHT", container, "RIGHT", -5, 0)
            headerRow:SetBackdropColor(cc[1]*0.12, cc[2]*0.12, cc[3]*0.12, 0.9)

            headerRow.expandBtn:Show()
            headerRow.expandBtn:SetText(collapseState[stateKey] and "+" or "-")
            headerRow.expandBtn:SetTextColor(cc[1], cc[2], cc[3])
            headerRow.name:ClearAllPoints()
            headerRow.name:SetPoint("LEFT", T.RowTextIndent, 0)
            headerRow.name:SetText(string.format("%s (%s)", teamName, bracketLabel))
            headerRow.name:SetTextColor(cc[1], cc[2], cc[3])
            headerRow.name:SetWidth(0)
            headerRow.value:SetText(tostring(teamRating or 0))
            headerRow.value:SetTextColor(1, 0.82, 0)

            headerRow:EnableMouse(true)
            local sk = stateKey
            headerRow:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    collapseState[sk] = not collapseState[sk]
                    if BCF.PvPContent then BCF.RefreshPvP(BCF.PvPContent) end
                end
            end)
            headerRow:SetScript("OnEnter", function(self) self:SetBackdropColor(cc[1]*0.2, cc[2]*0.2, cc[3]*0.2, 1) end)
            headerRow:SetScript("OnLeave", function(self) self:SetBackdropColor(cc[1]*0.12, cc[2]*0.12, cc[3]*0.12, 0.9) end)

            yOffset = yOffset - T.HeaderRowHeight

            if not collapseState[stateKey] then
                -- Team stats
                yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
                    "Team Rating", teamRating or 0, {1, 0.82, 0})
                yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
                    "Week", string.format("%d - %d", weekWins or 0, (weekPlayed or 0) - (weekWins or 0)))
                yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
                    "Season", string.format("%d - %d", seasonWins or 0, (seasonPlayed or 0) - (seasonWins or 0)))
                yOffset, rowIndex = RenderStatRow(container, rows, yOffset, rowIndex,
                    "Your Rating", playerRating or 0, {0.6, 0.8, 1})

                -- Roster
                local numMembers = GetNumArenaTeamMembers and GetNumArenaTeamMembers(teamIndex, true) or 0
                local isCaptain = false

                for m = 1, numMembers do
                    local mName, mRank, mLevel, mClass, mOnline,
                          mPlayed, mWin, mSeasonPlayed, mSeasonWin, mPersonalRating

                    if GetArenaTeamRosterInfo then
                        mName, mRank, mLevel, mClass, mOnline,
                            mPlayed, mWin, mSeasonPlayed, mSeasonWin, mPersonalRating = GetArenaTeamRosterInfo(teamIndex, m)
                    end

                    if mName then
                        local isMe = (mName == UnitName("player"))
                        if isMe and mRank == 0 then isCaptain = true end

                        local row = GetRow(container)
                        rowIndex = rowIndex + 1
                        table.insert(rows, row)

                        row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
                        row:SetPoint("RIGHT", container, "RIGHT", -5, 0)

                        local alpha = (mOnline and mOnline == 1) and 0.5 or 0.25
                        row:SetBackdropColor(0.06, 0.06, 0.09, alpha)
                        row.expandBtn:Hide()

                        -- Name with class color
                        local classColor = CLASS_COLORS[mClass] or {0.7, 0.7, 0.7}
                        local displayName = mName
                        if mRank == 0 then
                            displayName = displayName .. " (Captain)"
                        end

                        row.name:ClearAllPoints()
                        row.name:SetPoint("LEFT", 40, 0)
                        row.name:SetText(displayName)
                        row.name:SetWidth(0)

                        if mOnline and mOnline == 1 then
                            row.name:SetTextColor(classColor[1], classColor[2], classColor[3])
                        else
                            row.name:SetTextColor(classColor[1]*0.5, classColor[2]*0.5, classColor[3]*0.5)
                        end

                        -- Personal rating + week record
                        local ratingStr = string.format("%d  %d-%d", mPersonalRating or 0, mWin or 0, (mPlayed or 0) - (mWin or 0))
                        row.value:SetText(ratingStr)
                        if mOnline and mOnline == 1 then
                            row.value:SetTextColor(0.8, 0.8, 0.8)
                        else
                            row.value:SetTextColor(0.4, 0.4, 0.4)
                        end

                        -- Tooltip
                        row:EnableMouse(true)
                        local rowAlpha = alpha
                        row:SetScript("OnEnter", function(self)
                            self:SetBackdropColor(T.Accent[1]*0.1, T.Accent[2]*0.1, T.Accent[3]*0.1, 0.8)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText(mName, classColor[1], classColor[2], classColor[3])
                            GameTooltip:AddLine(string.format("Level %d %s", mLevel or 0, mClass or ""), 0.8, 0.8, 0.8)
                            GameTooltip:AddLine(string.format("Rating: %d", mPersonalRating or 0), 1, 0.82, 0)
                            GameTooltip:AddLine(string.format("Week: %d-%d", mWin or 0, (mPlayed or 0) - (mWin or 0)), 0.7, 0.7, 0.7)
                            GameTooltip:AddLine(string.format("Season: %d-%d", mSeasonWin or 0, (mSeasonPlayed or 0) - (mSeasonWin or 0)), 0.7, 0.7, 0.7)
                            if mOnline and mOnline == 1 then
                                GameTooltip:AddLine("Online", 0.3, 1, 0.3)
                            else
                                GameTooltip:AddLine("Offline", 0.5, 0.5, 0.5)
                            end
                            GameTooltip:Show()
                        end)
                        row:SetScript("OnLeave", function(self)
                            self:SetBackdropColor(0.06, 0.06, 0.09, rowAlpha)
                            GameTooltip:Hide()
                        end)

                        yOffset = yOffset - T.HeaderRowHeight
                    end
                end

                -- Action buttons row
                local actRow = GetRow(container)
                rowIndex = rowIndex + 1
                table.insert(rows, actRow)
                actRow:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
                actRow:SetPoint("RIGHT", container, "RIGHT", -5, 0)
                actRow:SetBackdropColor(0, 0, 0, 0)
                actRow.expandBtn:Hide()
                actRow.name:SetText("")
                actRow.value:SetText("")

                -- Create action buttons as child frames of actRow
                local ti = teamIndex

                -- Invite button
                local invBtn = CreateFrame("Button", nil, actRow, "BackdropTemplate")
                invBtn:SetSize(60, 18)
                invBtn:SetPoint("LEFT", 30, 0)
                invBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
                invBtn:SetBackdropColor(T.Accent[1]*0.2, T.Accent[2]*0.2, T.Accent[3]*0.2, 1)
                invBtn:SetBackdropBorderColor(T.Accent[1]*0.4, T.Accent[2]*0.4, T.Accent[3]*0.4, 1)
                local invBtnText = BCF.CleanFont(invBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
                invBtnText:SetPoint("CENTER", 0, 0)
                invBtnText:SetText("Invite")
                invBtnText:SetTextColor(T.Accent[1], T.Accent[2], T.Accent[3])
                invBtn:SetScript("OnClick", function() ShowInviteDialog(ti) end)
                invBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(T.AccentSubtle[1], T.AccentSubtle[2], T.AccentSubtle[3], 1) end)
                invBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(T.Accent[1]*0.2, T.Accent[2]*0.2, T.Accent[3]*0.2, 1) end)

                -- Leave button
                local leaveBtn = CreateFrame("Button", nil, actRow, "BackdropTemplate")
                leaveBtn:SetSize(60, 18)
                leaveBtn:SetPoint("LEFT", invBtn, "RIGHT", 6, 0)
                leaveBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
                leaveBtn:SetBackdropColor(0.3, 0.1, 0.1, 0.6)
                leaveBtn:SetBackdropBorderColor(0.5, 0.2, 0.2, 0.8)
                local leaveBtnText = BCF.CleanFont(leaveBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
                leaveBtnText:SetPoint("CENTER", 0, 0)
                leaveBtnText:SetText("Leave")
                leaveBtnText:SetTextColor(unpack(T.DestructiveText))
                leaveBtn:SetScript("OnClick", function()
                    ShowConfirm(
                        string.format("Leave |cffffffff%s|r?", teamName),
                        "You will lose your arena team spot.",
                        function() ArenaTeamLeave(ti) end
                    )
                end)
                leaveBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.4, 0.15, 0.15, 1) end)
                leaveBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.3, 0.1, 0.1, 0.6) end)

                -- Disband button (captain only)
                if isCaptain then
                    local disbandBtn = CreateFrame("Button", nil, actRow, "BackdropTemplate")
                    disbandBtn:SetSize(60, 18)
                    disbandBtn:SetPoint("LEFT", leaveBtn, "RIGHT", 6, 0)
                    disbandBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
                    disbandBtn:SetBackdropColor(0.4, 0.08, 0.08, 0.8)
                    disbandBtn:SetBackdropBorderColor(0.6, 0.15, 0.15, 1)
                    local disbandBtnText = BCF.CleanFont(disbandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"))
                    disbandBtnText:SetPoint("CENTER", 0, 0)
                    disbandBtnText:SetText("Disband")
                    disbandBtnText:SetTextColor(1, 0.3, 0.3)
                    disbandBtn:SetScript("OnClick", function()
                        ShowConfirm(
                            string.format("Disband |cffffffff%s|r?", teamName),
                            "This will permanently delete the team!",
                            function() ArenaTeamDisband(ti) end
                        )
                    end)
                    disbandBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(0.5, 0.1, 0.1, 1) end)
                    disbandBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(0.4, 0.08, 0.08, 0.8) end)
                end

                yOffset = yOffset - T.HeaderRowHeight
            end
        else
            -- No team in this bracket
            local row = GetRow(container)
            rowIndex = rowIndex + 1
            table.insert(rows, row)
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 5, yOffset)
            row:SetPoint("RIGHT", container, "RIGHT", -5, 0)
            row:SetBackdropColor(0.06, 0.06, 0.09, 0.3)
            row.expandBtn:Hide()
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", T.RowTextIndent, 0)
            row.name:SetText(string.format("No %s Team", bracketLabel))
            row.name:SetTextColor(0.4, 0.4, 0.4)
            row.name:SetWidth(0)
            row.value:SetText("")

            yOffset = yOffset - T.HeaderRowHeight
        end
    end

    container:SetHeight(math.abs(yOffset) + 10)
end

-- ============================================================================
-- PVP EVENTS
-- ============================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ARENA_TEAM_UPDATE")
eventFrame:RegisterEvent("ARENA_TEAM_ROSTER_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
eventFrame:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
BCF.pvpEventFrame = eventFrame

eventFrame:SetScript("OnEvent", function()
    if BCF.PvPContent and BCF.PvPContainer and BCF.PvPContainer:IsShown() then
        BCF.RefreshPvP(BCF.PvPContent)
    end
end)
