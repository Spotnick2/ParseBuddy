local PB = ParseBuddy

PB.UI = {}

local FRAME_WIDTH = 440
local HEADER_HEIGHT = 42
-- A healthy row is confirmation and gets one compact line. A row reporting a
-- problem earns a second line for the group and what is missing from it.
local ROW_HEIGHT = 18
local ROW_HEIGHT_DETAIL = 26
local ROW_SPACING = 2
local ACCENT_WIDTH = 3
local FRAME_PADDING = 6
local COLLAPSED_FRAME_HEIGHT = HEADER_HEIGHT + FRAME_PADDING
local MIN_SCALE = 0.6
local MAX_SCALE = 1.4
local MIN_OPACITY = 0.2
local MAX_OPACITY = 1
local LOCKED_TEXTURE = "Interface\\Buttons\\LockButton-Locked-Up"
local UNLOCKED_TEXTURE = "Interface\\Buttons\\LockButton-Unlocked-Up"
local DISPLAY_MODE_PROBLEMS = "PROBLEMS_ONLY"
local DISPLAY_MODE_FULL = "FULL_LIST"
local VISIBILITY_APPLIED = "applied"
local SCREEN_MARGIN = 40

-- Filling fourteen rows edge to edge is what made the frame fight the game for
-- attention. The row itself stays dark and the state shows in a left accent.
local ROW_BACKGROUND = { 0.09, 0.09, 0.11, 0.86 }

local STATE_COLORS = {
    active = { 0.24, 0.78, 0.34, 1 },
    warning = { 0.96, 0.74, 0.16, 1 },
    missing = { 0.90, 0.22, 0.22, 1 },
    disabled = { 0.42, 0.42, 0.46, 1 },
    grace = { 0.55, 0.55, 0.60, 1 },
    notAvailable = { 0.42, 0.42, 0.46, 1 },
}

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function createBackdrop(frame, color)
    if not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(color[1], color[2], color[3], color[4])
    frame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
end

local function getIcon(spellId)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellId)
    end
    if GetSpellTexture then
        return GetSpellTexture(spellId)
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function saveFramePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ParseBuddyDB.frame.point = point or "CENTER"
    ParseBuddyDB.frame.relativePoint = relativePoint or point or "CENTER"
    ParseBuddyDB.frame.x = x or 0
    ParseBuddyDB.frame.y = y or 0
end

local function createRow(parent, index)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local row = CreateFrame("Frame", nil, parent, template)
    row:SetHeight(ROW_HEIGHT)

    row.accent = row:CreateTexture(nil, "OVERLAY")
    row.accent:SetPoint("TOPLEFT", 1, -1)
    row.accent:SetPoint("BOTTOMLEFT", 1, 1)
    row.accent:SetWidth(ACCENT_WIDTH)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetPoint("LEFT", ACCENT_WIDTH + 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Only drawn on a problem row, where naming the group is the whole point.
    row.groupText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.groupText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, 1)
    row.groupText:SetWidth(200)
    row.groupText:SetJustifyH("LEFT")

    row.effectText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.effectText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.effectText:SetWidth(200)
    row.effectText:SetJustifyH("LEFT")

    row.sourceText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.sourceText:SetPoint("RIGHT", row, "RIGHT", -58, 0)
    row.sourceText:SetWidth(104)
    row.sourceText:SetJustifyH("RIGHT")

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.statusText:SetPoint("RIGHT", -6, 0)
    row.statusText:SetWidth(50)
    row.statusText:SetJustifyH("RIGHT")

    createBackdrop(row, ROW_BACKGROUND)

    return row
end

local function rowHeightFor(data)
    return data and data.detailed and ROW_HEIGHT_DETAIL or ROW_HEIGHT
end

-- The display ticker reaches RenderEvaluations five times a second, and it is
-- only allowed to update timers, colours and row visibility. A row whose offset
-- has not moved must not be reanchored, so steady-state refreshes touch no
-- layout at all.
local function positionRow(row, offset)
    if row.parseBuddyOffset == offset then
        return false
    end
    row.parseBuddyOffset = offset
    if not row.ClearAllPoints or not row.SetPoint then
        return false
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", FRAME_PADDING, -HEADER_HEIGHT - offset)
    row:SetPoint("TOPRIGHT", -FRAME_PADDING, -HEADER_HEIGHT - offset)
    return true
end

local function setRowVisible(row, visible)
    if row.parseBuddyVisible == visible then
        return
    end
    row.parseBuddyVisible = visible
    if visible then
        row:Show()
    else
        row:Hide()
    end
end

function PB.UI:ApplyRowData(row, data)
    local color = STATE_COLORS[data.state] or STATE_COLORS.disabled
    if row.displayState ~= data.state then
        if row.accent and row.accent.SetColorTexture then
            row.accent:SetColorTexture(color[1], color[2], color[3], color[4])
        end
        row.displayState = data.state
    end

    local detailed = data.detailed == true
    if row.detailed ~= detailed then
        if row.SetHeight then
            row:SetHeight(detailed and ROW_HEIGHT_DETAIL or ROW_HEIGHT)
        end
        if row.groupText and row.groupText.Show and row.groupText.Hide then
            if detailed then row.groupText:Show() else row.groupText:Hide() end
        end
        if row.effectText and row.effectText.ClearAllPoints and row.icon then
            row.effectText:ClearAllPoints()
            if detailed then
                row.effectText:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -11)
            else
                row.effectText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            end
        end
        row.detailed = detailed
    end
    if row.iconSpellId ~= data.iconSpellId then
        row.icon:SetTexture(getIcon(data.iconSpellId))
        row.iconSpellId = data.iconSpellId
    end
    if row.groupValue ~= data.group then
        row.groupText:SetText(data.group)
        row.groupValue = data.group
    end
    if row.effectValue ~= data.effect then
        row.effectText:SetText(data.effect)
        row.effectValue = data.effect
    end
    if row.sourceValue ~= data.source then
        row.sourceText:SetText(data.source)
        row.sourceValue = data.source
    end
    if row.statusValue ~= data.status then
        row.statusText:SetText(data.status)
        row.statusValue = data.status
    end
end

local function formatDuration(remaining)
    local seconds = math.max(0, math.floor((remaining or 0) + 0.5))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function getDefaultIconSpellId(group)
    return group.spells[1].spellIds[#group.spells[1].spellIds]
end

function PB.UI:EvaluationToRowData(evaluation)
    local group = evaluation.group
    local candidate = evaluation.candidate
    local spell = evaluation.spell
    local state = evaluation.state
    local effect
    local status
    local displayState = state

    -- A row with nothing on the boss has to say which group it is and what would
    -- satisfy it. A row with a live effect does not: the icon and the effect name
    -- already carry that, and repeating the group label is what made the frame
    -- twice as tall as it needed to be.
    local detailed = state == "disabled" or state == "grace"
        or state == "missing" or state == "notAvailable"

    if state == "disabled" then
        effect = group.missingText
        status = "DISABLED"
    elseif state == "grace" then
        effect = group.missingText .. " pending"
        status = "GRACE"
    elseif state == "missing" then
        effect = group.missingText .. " missing"
        status = "MISSING"
    elseif state == "notAvailable" then
        effect = group.missingText .. " unavailable"
        status = "N/A"
    else
        effect = spell.displayName
        if spell.requiredStacks then
            effect = effect .. " " .. tostring(candidate.stacks or 0) .. "/" .. tostring(spell.requiredStacks)
        end
        status = evaluation.remaining and formatDuration(evaluation.remaining) or "ACTIVE"
    end

    if state == "expiring" or state == "partial" or (state == "active" and not evaluation.sourceKnown) then
        displayState = "warning"
    end

    -- The group label always travels with the row. Encounter:BuildEvaluationLines
    -- formats /pb dump, completed snapshots and the retained live view from this
    -- same table, and a diagnostic that cannot say which group an effect
    -- satisfied is worth much less. The live frame hides it via `detailed`
    -- instead of dropping it here.
    return {
        iconSpellId = candidate and candidate.spellId or getDefaultIconSpellId(group),
        group = group.label,
        effect = effect,
        source = candidate and candidate.sourceName or "",
        status = status,
        state = displayState,
        detailed = detailed,
    }
end

function PB.UI:CreateFrame()
    if self.frame then
        return self.frame
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "ParseBuddyFrame", UIParent, template)
    local rowCount = #PB.DebuffLibrary.groups
    frame:SetSize(FRAME_WIDTH, HEADER_HEIGHT + (rowCount * (ROW_HEIGHT + ROW_SPACING)) + FRAME_PADDING)
    frame.rowCount = rowCount
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    createBackdrop(frame, { 0.035, 0.035, 0.04, 0.96 })

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 10, -7)
    frame.title:SetText("ParseBuddy")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -1)
    frame.subtitle:SetText("Test Boss - deterministic preview")

    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", -3, -3)

    frame.lockButton = CreateFrame("Button", nil, frame)
    frame.lockButton:SetSize(20, 20)
    frame.lockButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -2, 0)
    frame.lockButton:SetScript("OnClick", function()
        if ParseBuddyDB.frame.locked then
            PB.UI:Unlock()
        else
            PB.UI:Lock()
        end
    end)
    frame.lockButton:SetScript("OnEnter", function(button)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(ParseBuddyDB.frame.locked and "Unlock ParseBuddy" or "Lock ParseBuddy")
        GameTooltip:Show()
    end)
    frame.lockButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    frame.rows = {}
    local index
    for index = 1, rowCount do
        frame.rows[index] = createRow(frame, index)
    end

    frame:SetScript("OnDragStart", function(currentFrame)
        if not ParseBuddyDB.frame.locked then
            currentFrame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(currentFrame)
        currentFrame:StopMovingOrSizing()
        saveFramePosition(currentFrame)
    end)

    self.frame = frame
    return frame
end

function PB.UI:ApplySavedPosition()
    local frame = self:CreateFrame()
    local position = ParseBuddyDB.frame
    frame:ClearAllPoints()
    frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
end

function PB.UI:ApplySavedScale()
    local frame = self:CreateFrame()
    local scale = tonumber(ParseBuddyDB.frame.scale) or 1
    if scale < MIN_SCALE or scale > MAX_SCALE then
        scale = 1
        ParseBuddyDB.frame.scale = scale
    end
    frame:SetScale(scale)
end

function PB.UI:ApplySavedOpacity()
    local frame = self:CreateFrame()
    local opacity = tonumber(ParseBuddyDB.frame.opacity) or 1
    if opacity < MIN_OPACITY or opacity > MAX_OPACITY then
        opacity = 1
        ParseBuddyDB.frame.opacity = opacity
    end
    frame:SetAlpha(opacity)
end

function PB.UI:UpdateLockDisplay()
    if not self.frame then
        return
    end

    self.frame.title:SetText("ParseBuddy")
    if self.frame.lockButton then
        self.frame.lockButton:SetNormalTexture(ParseBuddyDB.frame.locked and LOCKED_TEXTURE or UNLOCKED_TEXTURE)
    end
end

function PB.UI:SetRowsVisible(visible)
    local index
    for index = 1, #self.frame.rows do
        setRowVisible(self.frame.rows[index], visible)
    end
end

function PB.UI:IsEvaluationVisible(evaluation, displayMode, showUnavailable)
    if not evaluation or evaluation.state == "disabled" then
        return false
    end

    -- An applied-only group overrides both display modes. It exists to confirm a
    -- debuff landed, never to report that one is absent, so it draws a row only
    -- while the effect is actually on the boss.
    if evaluation.visibility == VISIBILITY_APPLIED then
        local state = evaluation.state
        return state == "active" or state == "expiring" or state == "partial"
    end

    if displayMode == DISPLAY_MODE_FULL then
        return true
    end

    if evaluation.state == "notAvailable" then
        return showUnavailable == true
    end

    if evaluation.state == "partial" or evaluation.state == "expiring" then
        return true
    end
    if evaluation.state == "active" and not evaluation.sourceKnown then
        return true
    end
    if evaluation.state == "missing" or evaluation.state == "grace" then
        return evaluation.required ~= false
    end
    return false
end

-- The row pool grows with the debuff library, and nothing about SetClampedToScreen
-- shrinks a frame that is taller than the screen. Work out how many rows can
-- actually be drawn at the frame's current scale so a long list degrades into an
-- overflow row instead of running off the display.
-- Rows now vary in height, so the screen limit is a pixel budget rather than a
-- row count. Nothing about SetClampedToScreen shrinks a frame taller than the
-- display, so work out what actually fits at the frame's current scale.
function PB.UI:GetRowHeightBudget(frame)
    local capacity = #frame.rows * (ROW_HEIGHT_DETAIL + ROW_SPACING)
    if not UIParent or not UIParent.GetHeight then
        return capacity
    end
    local ok, screenHeight = pcall(function() return UIParent:GetHeight() end)
    if not ok or type(screenHeight) ~= "number" or screenHeight <= 0 then
        return capacity
    end
    local scale = 1
    if frame.GetScale then
        local scaled
        ok, scaled = pcall(function() return frame:GetScale() end)
        if ok and type(scaled) == "number" and scaled > 0 then
            scale = scaled
        end
    end
    local usable = (screenHeight / scale) - HEADER_HEIGHT - FRAME_PADDING - SCREEN_MARGIN
    if usable < ROW_HEIGHT + ROW_SPACING then
        usable = ROW_HEIGHT + ROW_SPACING
    end
    if usable > capacity then
        usable = capacity
    end
    return usable
end

function PB.UI:RenderEvaluations(evaluations, showAll)
    local frame = self:CreateFrame()
    local displayMode = PB.Config and PB.Config:GetDisplayMode() or ParseBuddyDB.displayMode
    local showUnavailable = PB.Config and PB.Config:GetShowUnavailable() or false
    local index

    local rows = {}
    for index = 1, #(evaluations or {}) do
        local evaluation = evaluations[index]
        if showAll or self:IsEvaluationVisible(evaluation, displayMode, showUnavailable) then
            rows[#rows + 1] = self:EvaluationToRowData(evaluation)
        end
    end

    local budget = self:GetRowHeightBudget(frame)
    local overflowHeight = ROW_HEIGHT + ROW_SPACING
    local used = 0
    local drawn = 0
    for index = 1, #rows do
        local height = rowHeightFor(rows[index]) + ROW_SPACING
        -- Keep room for the overflow row whenever more rows would follow.
        local reserve = index < #rows and overflowHeight or 0
        if drawn >= #frame.rows or used + height + reserve > budget then
            break
        end
        used = used + height
        drawn = drawn + 1
    end

    local hidden = #rows - drawn
    if hidden > 0 and drawn >= #frame.rows then
        -- Spend the last row slot on the count rather than dropping rows silently.
        drawn = drawn - 1
        hidden = #rows - drawn
    end

    local visibleCount = 0
    local offset = 0
    for index = 1, drawn do
        visibleCount = visibleCount + 1
        local row = frame.rows[visibleCount]
        self:ApplyRowData(row, rows[index])
        positionRow(row, offset)
        offset = offset + rowHeightFor(rows[index]) + ROW_SPACING
        setRowVisible(row, true)
    end

    if hidden > 0 then
        visibleCount = visibleCount + 1
        local row = frame.rows[visibleCount]
        self:ApplyRowData(row, {
            iconSpellId = nil,
            group = "",
            effect = string.format("%d more row%s do not fit on screen", hidden, hidden == 1 and "" or "s"),
            source = "",
            status = "",
            state = "disabled",
            detailed = false,
        })
        positionRow(row, offset)
        offset = offset + ROW_HEIGHT + ROW_SPACING
        setRowVisible(row, true)
    end

    for index = visibleCount + 1, #frame.rows do
        setRowVisible(frame.rows[index], false)
    end

    frame:SetHeight(HEADER_HEIGHT + offset + FRAME_PADDING)
    return visibleCount
end

function PB.UI:SetDisplayMode(value)
    local mode = value and value:lower() or ""
    if mode == "problems" then
        PB.Config:SetDisplayMode(DISPLAY_MODE_PROBLEMS)
        PB:Print("Display mode set to Problems Only.")
    elseif mode == "full" then
        PB.Config:SetDisplayMode(DISPLAY_MODE_FULL)
        PB:Print("Display mode set to Full List.")
    elseif mode == "" then
        PB:Print("Display mode: " .. (PB.Config:GetDisplayMode() == DISPLAY_MODE_FULL and "Full List" or "Problems Only") .. " (" .. PB.Config:GetScope() .. ").")
        return
    else
        PB:Print("Mode must be 'problems' or 'full'.")
        return
    end

    if PB.Encounter and PB.Encounter.active then
        PB.Encounter:RefreshDisplay()
    end
end

function PB.UI:Initialize()
    local displayMode = PB.Config:GetDisplayMode()
    if displayMode ~= DISPLAY_MODE_PROBLEMS and displayMode ~= DISPLAY_MODE_FULL then
        PB.Config:SetDisplayMode(DISPLAY_MODE_PROBLEMS)
    end
    self:CreateFrame()
    self:ApplySavedPosition()
    self:ApplySavedScale()
    self:ApplySavedOpacity()
    self:UpdateLockDisplay()
    self.frame:Hide()
end

function PB.UI:SetScale(value, silent)
    if value == nil or value == "" then
        PB:Print(string.format("Frame scale: %.2f", ParseBuddyDB.frame.scale))
        return
    end

    local scale = tonumber(value)
    if not scale or scale < MIN_SCALE or scale > MAX_SCALE then
        PB:Print(string.format("Scale must be between %.1f and %.1f.", MIN_SCALE, MAX_SCALE))
        return
    end

    ParseBuddyDB.frame.scale = scale
    self:ApplySavedScale()
    if not silent then PB:Print(string.format("Frame scale set to %.2f.", scale)) end
end

function PB.UI:SetOpacity(value, silent)
    if value == nil or value == "" then
        PB:Print(string.format("Frame opacity: %.2f", ParseBuddyDB.frame.opacity))
        return
    end

    local opacity = tonumber(value)
    if not opacity or opacity < MIN_OPACITY or opacity > MAX_OPACITY then
        PB:Print(string.format("Opacity must be between %.1f and %.1f.", MIN_OPACITY, MAX_OPACITY))
        return
    end

    ParseBuddyDB.frame.opacity = opacity
    self:ApplySavedOpacity()
    if not silent then PB:Print(string.format("Frame opacity set to %.2f.", opacity)) end
end

function PB.UI:ShowTestMode()
    if PB.Encounter and PB.Encounter.active then
        PB:Print("Test mode is unavailable during an active encounter.")
        return
    end

    local frame = self:CreateFrame()
    local evaluations = PB.State:CreateTestEvaluations()
    self.mode = "test"
    frame.subtitle:SetText("Test Boss - deterministic preview")
    self:RenderEvaluations(evaluations, true)
    self:UpdateLockDisplay()
    frame:Show()
end

function PB.UI:ShowEncounter(encounter, primaryBoss)
    local frame = self:CreateFrame()
    self.mode = "encounter"
    self:UpdateEncounter(encounter, primaryBoss)
    self:UpdateLockDisplay()
    frame:Show()
end

function PB.UI:UpdateEncounter(encounter, primaryBoss, evaluations)
    if self.mode ~= "encounter" or not self.frame then
        return
    end

    if primaryBoss then
        self.frame.subtitle:SetText(primaryBoss.name)
    elseif encounter then
        self.frame.subtitle:SetText((encounter.name or "Encounter") .. " - waiting for visible boss")
    else
        self.frame.subtitle:SetText("Waiting for visible boss")
    end

    if not primaryBoss or not evaluations then
        self:SetRowsVisible(false)
        self.frame:SetHeight(COLLAPSED_FRAME_HEIGHT)
        return
    end

    self:RenderEvaluations(evaluations, false)
end

function PB.UI:HideEncounter()
    if self.frame then
        self.frame:Hide()
        self.mode = nil
    end
end

function PB.UI:Lock(silent)
    ParseBuddyDB.frame.locked = true
    self:UpdateLockDisplay()
    if not silent then PB:Print("Frame locked.") end
end

function PB.UI:Unlock(silent)
    ParseBuddyDB.frame.locked = false
    self:UpdateLockDisplay()
    if not silent then PB:Print("Frame unlocked. Drag the title area to move it.") end
end

function PB.UI:ResetPosition(silent)
    ParseBuddyDB.frame.point = "CENTER"
    ParseBuddyDB.frame.relativePoint = "CENTER"
    ParseBuddyDB.frame.x = 0
    ParseBuddyDB.frame.y = 0
    ParseBuddyDB.frame.scale = 1
    ParseBuddyDB.frame.opacity = 1
    self:ApplySavedPosition()
    self:ApplySavedScale()
    self:ApplySavedOpacity()
    if not silent then PB:Print("Frame position, scale, and opacity reset.") end
end
