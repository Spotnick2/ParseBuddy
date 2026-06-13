local PB = ParseBuddy

PB.ConfigPanel = {
    panel = nil,
    category = nil,
    apiPath = nil,
}

local CONTENT_WIDTH = 620
local LEFT = 18
local ROW_HEIGHT = 23

local SEGMENT_STYLE = {
    selected = {
        background = { 0.52, 0.34, 0.05, 0.95 },
        border = { 0.95, 0.72, 0.18, 1 },
        text = { 1, 0.92, 0.55, 1 },
    },
    unselected = {
        background = { 0.08, 0.08, 0.10, 0.88 },
        border = { 0.30, 0.30, 0.34, 1 },
        text = { 0.72, 0.72, 0.76, 1 },
    },
    disabled = {
        background = { 0.09, 0.09, 0.11, 0.92 },
        border = { 0.28, 0.28, 0.31, 0.95 },
        text = { 0.62, 0.62, 0.65, 1 },
    },
}

local AVAILABILITY_STYLE = {
    Available = { 0.35, 0.90, 0.42, 1 },
    ["Not Available"] = { 0.58, 0.58, 0.62, 1 },
    Unknown = { 0.95, 0.76, 0.24, 1 },
}

function PB.ConfigPanel:GetSegmentStyle(selected, enabled)
    if enabled == false then return SEGMENT_STYLE.disabled end
    return selected and SEGMENT_STYLE.selected or SEGMENT_STYLE.unselected
end

function PB.ConfigPanel:GetAvailabilityStyle(value)
    return AVAILABILITY_STYLE[value] or AVAILABILITY_STYLE.Unknown
end

local runtimeAPI = {
    RegisterCanvas = function(panel, name)
        return Settings.RegisterCanvasLayoutCategory(panel, name)
    end,
    RegisterAddOn = function(category)
        Settings.RegisterAddOnCategory(category)
    end,
    RegisterLegacy = function(panel)
        InterfaceOptions_AddCategory(panel)
    end,
    OpenSettings = function(category)
        Settings.OpenToCategory(category:GetID())
    end,
    OpenLegacy = function(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end,
}

local function setEnabled(control, enabled)
    if control.SetEnabled then
        control:SetEnabled(enabled)
    elseif enabled and control.Enable then
        control:Enable()
    elseif not enabled and control.Disable then
        control:Disable()
    end
    if control.SetAlpha then
        control:SetAlpha(enabled and 1 or (control.RefreshStyle and 0.9 or 0.76))
    end
    if control.linkedText then
        local _, textObject
        for _, textObject in ipairs(control.linkedText) do
            textObject:SetAlpha(enabled and 1 or 0.76)
        end
    end
    control.parseBuddyEnabled = enabled
    if control.RefreshStyle then control:RefreshStyle() end
end

function PB.ConfigPanel:DetectAPI(api)
    api = api or runtimeAPI
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
        and api.RegisterCanvas and api.RegisterAddOn
    then
        return "settings"
    end
    if InterfaceOptions_AddCategory and api.RegisterLegacy then
        return "legacy"
    end
    return "none"
end

function PB.ConfigPanel:Register(panel, api, forcedPath)
    api = api or runtimeAPI
    local path = forcedPath or self:DetectAPI(api)
    if path == "settings" then
        local category = api.RegisterCanvas(panel, panel.name)
        api.RegisterAddOn(category)
        self.category = category
    elseif path == "legacy" then
        api.RegisterLegacy(panel)
    else
        return false
    end
    self.panel = panel
    self.apiPath = path
    self.api = api
    return true
end

function PB.ConfigPanel:Open()
    if not self.panel then
        return false
    end
    local api = self.api or runtimeAPI
    if self.apiPath == "settings" and self.category and api.OpenSettings then
        api.OpenSettings(self.category)
        return true
    elseif self.apiPath == "legacy" and api.OpenLegacy then
        api.OpenLegacy(self.panel)
        return true
    end
    return false
end

local function addText(parent, text, template, x, y, width)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    font:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    if width then
        font:SetWidth(width)
        font:SetJustifyH("LEFT")
    end
    font:SetText(text)
    return font
end

local function addSection(parent, y, text)
    local label = addText(parent, text, "GameFontNormalLarge", LEFT, y, CONTENT_WIDTH - LEFT * 2)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.35, 0.35, 0.45, 0.55)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", LEFT, y - 22)
    line:SetSize(CONTENT_WIDTH - LEFT * 2, 1)
    return label, y - 34
end

local function addTooltip(control, text)
    if not text then return end
    control:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function addButton(parent, text, x, y, width, onClick, tooltip)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width, 23)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    addTooltip(button, tooltip)
    return button
end

local SEGMENT_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function applySegmentStyle(button, selected)
    local style = PB.ConfigPanel:GetSegmentStyle(selected, button.parseBuddyEnabled ~= false)
    button.parseBuddySelected = selected
    if button.SetBackdropColor then
        button:SetBackdropColor(style.background[1], style.background[2], style.background[3], style.background[4])
        button:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], style.border[4])
    end
    button.label:SetTextColor(style.text[1], style.text[2], style.text[3], style.text[4])
end

local function addSegment(parent, text, x, y, width, onClick, tooltip)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local button = CreateFrame("Button", nil, parent, template)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width, 22)
    if button.SetBackdrop then button:SetBackdrop(SEGMENT_BACKDROP) end
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    button.parseBuddyEnabled = true
    button:SetScript("OnClick", function()
        if button.parseBuddyEnabled ~= false then onClick() end
    end)
    button:SetScript("OnMouseDown", function()
        if button.parseBuddyEnabled ~= false and button.SetBackdropColor then
            button:SetBackdropColor(0.62, 0.42, 0.08, 1)
        end
    end)
    button:SetScript("OnMouseUp", function() button:RefreshStyle() end)
    button.RefreshStyle = function(self) applySegmentStyle(self, self.parseBuddySelected) end
    addTooltip(button, tooltip)
    return button
end

local function addDisclosure(parent, x, y, width, expanded, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width, 22)
    button.arrow = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.arrow:SetPoint("LEFT", 2, 0)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("LEFT", button.arrow, "RIGHT", 7, 0)
    button.label:SetText("Diagnostics")
    local line = button:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", button.label, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", button, "RIGHT", 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(0.30, 0.30, 0.34, 0.65)
    button.Refresh = function(self)
        self.arrow:SetText(expanded() and "v" or ">")
        self.label:SetTextColor(0.78, 0.78, 0.82, 1)
    end
    button:SetScript("OnClick", function()
        onClick()
        button:Refresh()
    end)
    button:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 0.82, 0, 1) end)
    button:SetScript("OnLeave", function(self) self:Refresh() end)
    button:Refresh()
    return button
end

local function addChoice(parent, choices, x, y, selected, onSelect)
    local buttons = {}
    local offset = 0
    local _, choice
    local function refresh()
        local selectedValue = selected()
        for _, button in ipairs(buttons) do
            applySegmentStyle(button, button.value == selectedValue)
        end
    end
    for _, choice in ipairs(choices) do
        local width = choice.width or 90
        local value = choice.value
        local button = addSegment(parent, choice.label, x + offset, y, width, function()
            onSelect(value)
            refresh()
        end, choice.tooltip)
        button.value = value
        buttons[#buttons + 1] = button
        offset = offset + width + 4
    end
    refresh()
    return buttons, refresh
end

local function addCheckbox(parent, text, x, y, checked, onClick)
    local checkbox = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkbox.Text:SetText(text)
    checkbox:SetChecked(checked())
    checkbox:SetScript("OnClick", function(self)
        onClick(self:GetChecked() == true or self:GetChecked() == 1)
    end)
    return checkbox
end

local function addSlider(parent, label, x, y, width, minimum, maximum, step, getValue, setValue, format)
    local labelText = addText(parent, label, "GameFontHighlight", x, y - 2)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 70, y)
    slider:SetSize(width, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(6)
    track:SetColorTexture(0.12, 0.12, 0.14, 1)
    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
    fill:SetHeight(6)
    fill:SetColorTexture(0.78, 0.57, 0.12, 1)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 18)
    thumb:SetColorTexture(0.95, 0.78, 0.28, 1)
    slider:SetThumbTexture(thumb)
    local valueText = addText(parent, format(getValue()), "GameFontNormal", x + width + 82, y - 2)
    slider:SetScript("OnValueChanged", function(_, value)
        value = PB.ConfigPrototype:ClampSliderValue(value, minimum, maximum, step)
        setValue(value)
        valueText:SetText(format(value))
        local ratio = maximum > minimum and (value - minimum) / (maximum - minimum) or 0
        fill:SetWidth(math.max(1, width * ratio))
    end)
    slider:SetValue(getValue())
    slider.fill = fill
    slider.valueText = valueText
    slider.linkedText = { labelText, valueText }
    return slider
end

function PB.ConfigPanel:Build(panel)
    if panel.built then return end
    panel.built = true
    local model = PB.ConfigPrototype
    local state = model:GetState()

    local surface = panel:CreateTexture(nil, "BACKGROUND")
    surface:SetAllPoints(panel)
    surface:SetColorTexture(0.025, 0.025, 0.035, 0.94)

    local headerDivider = panel:CreateTexture(nil, "ARTWORK")
    headerDivider:SetPoint("TOPLEFT", panel, "TOPLEFT", LEFT, -94)
    headerDivider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -38, -94)
    headerDivider:SetHeight(1)
    headerDivider:SetColorTexture(0.45, 0.38, 0.20, 0.8)

    local title = addText(panel, "ParseBuddy", "GameFontNormalHuge", LEFT, -10)
    local version = addText(panel, "v" .. tostring(PB.version or "prototype"), "GameFontHighlightSmall", 520, -17)
    version:SetTextColor(0.65, 0.65, 0.65)
    local notice = addText(panel, "CONFIGURATION PROTOTYPE - changes are not saved", "GameFontNormal", LEFT, -36)
    notice:SetTextColor(1, 0.65, 0.15)
    addText(panel, "Scope", "GameFontHighlight", LEFT, -61)
    addChoice(panel, {
        { label = "Global", value = "global", width = 82, tooltip = "Prototype account-wide scope. This does not change the live profile." },
        { label = "Personal", value = "personal", width = 82, tooltip = "Prototype character scope. This does not change the live profile." },
    }, 75, -66, function() return state.scope end, function(value) model:SetScope(value) end)

    local scroll = CreateFrame("ScrollFrame", "ParseBuddyConfigScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -96)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
    local scrollBar = _G.ParseBuddyConfigScrollFrameScrollBar
    if scrollBar then
        local scrollTrack = panel:CreateTexture(nil, "ARTWORK")
        scrollTrack:SetPoint("TOP", scrollBar, "TOP", 0, -17)
        scrollTrack:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 17)
        scrollTrack:SetWidth(8)
        scrollTrack:SetColorTexture(0.08, 0.08, 0.10, 0.95)
        local thumb = scrollBar:GetThumbTexture()
        if thumb then
            thumb:SetColorTexture(0.78, 0.57, 0.12, 1)
            thumb:SetSize(10, 30)
        end
    end
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(CONTENT_WIDTH)
    scroll:SetScrollChild(content)
    panel.content = content

    local y = -8
    _, y = addSection(content, y, "Display")
    addText(content, "Mode", "GameFontHighlight", LEFT, y - 4)
    addChoice(content, {
        { label = "Problems Only", value = "PROBLEMS_ONLY", width = 116 },
        { label = "Full List", value = "FULL_LIST", width = 92 },
    }, 80, y - 9, function() return state.displayMode end, function(value) model:SetDisplayMode(value) end)
    y = y - 36
    addCheckbox(content, "Show unavailable", LEFT, y, function() return state.showUnavailable end, function(value) model:SetValue("showUnavailable", value) end)
    addCheckbox(content, "Lock frame", 230, y, function() return state.locked end, function(value) model:SetValue("locked", value) end)
    y = y - 34
    addSlider(content, "Scale", LEFT, y, 150, 0.6, 1.4, 0.05, function() return state.scale end, function(value) model:SetSliderValue("scale", value, 0.6, 1.4, 0.05) end, function(value) return string.format("%.2f", value) end)
    addSlider(content, "Opacity", 320, y, 150, 0.2, 1, 0.05, function() return state.opacity end, function(value) model:SetSliderValue("opacity", value, 0.2, 1, 0.05) end, function(value) return string.format("%.2f", value) end)
    y = y - 36
    addButton(content, "Test Frame", LEFT, y, 105, function() model:RecordAction("Test Frame") end, "Prototype action only; the live encounter frame is not changed.")
    addButton(content, "Reset Position", 130, y, 120, function() model:RecordAction("Reset Position") end, "Prototype action only; the saved frame position is not changed.")

    y = y - 48
    _, y = addSection(content, y, "Debuff Groups")
    addText(content, "Group", "GameFontNormal", LEFT, y)
    addText(content, "Enabled", "GameFontNormal", 300, y)
    addText(content, "Required", "GameFontNormal", 390, y)
    addText(content, "Availability", "GameFontNormal", 500, y)
    y = y - 24
    local _, group
    local groupIndex = 0
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        groupIndex = groupIndex + 1
        local groupKey = group.key
        local groupState = state.groups[groupKey]
        local rowBackground = content:CreateTexture(nil, "BACKGROUND")
        rowBackground:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT - 4, y + 3)
        rowBackground:SetSize(CONTENT_WIDTH - (LEFT * 2) + 8, ROW_HEIGHT)
        if groupIndex % 2 == 0 then
            rowBackground:SetColorTexture(0.12, 0.12, 0.14, 0.42)
        else
            rowBackground:SetColorTexture(0.06, 0.06, 0.08, 0.28)
        end
        addText(content, group.label, "GameFontHighlight", LEFT, y - 3, 270)
        addCheckbox(content, "", 304, y + 2, function() return groupState.enabled end, function(value) model:SetGroupValue(groupKey, "enabled", value) end)
        addCheckbox(content, "", 402, y + 2, function() return groupState.required end, function(value) model:SetGroupValue(groupKey, "required", value) end)
        local availability = addText(content, groupState.availability, "GameFontHighlightSmall", 500, y - 3)
        local availabilityColor = PB.ConfigPanel:GetAvailabilityStyle(groupState.availability)
        availability:SetTextColor(availabilityColor[1], availabilityColor[2], availabilityColor[3], availabilityColor[4])
        y = y - ROW_HEIGHT
    end

    y = y - 12
    _, y = addSection(content, y, "Alerts")
    local alertControls = {}
    local function refreshAlertControls()
        local enabled = model:AreAlertControlsEnabled()
        local _, control
        for _, control in ipairs(alertControls) do setEnabled(control, enabled) end
    end
    addCheckbox(content, "Enable broadcasts", LEFT, y, function() return state.alerts.enabled end, function(value)
        model:SetAlertsEnabled(value)
        refreshAlertControls()
    end)
    y = y - 30
    addText(content, "Destination", "GameFontHighlight", LEFT, y - 4)
    local channelButtons = addChoice(content, {
        { label = "Party", value = "party", width = 70 },
        { label = "Raid", value = "raid", width = 70 },
        { label = "Leader", value = "leader", width = 76 },
    }, 105, y - 7, function() return state.alerts.channel end, function(value) model:SetAlertChannel(value) end)
    local _, channelButton
    for _, channelButton in ipairs(channelButtons) do alertControls[#alertControls + 1] = channelButton end
    local delaySlider = addSlider(content, "Delay", 350, y, 130, 0, 60, 1, function() return state.alerts.delay end, function(value) model:SetAlertDelay(value) end, function(value) return tostring(value) .. " sec" end)
    alertControls[#alertControls + 1] = delaySlider
    y = y - 28
    local alertTest = addButton(content, "Test Alert", LEFT, y, 90, function() model:RecordAction("Test Alert") end, "Records a prototype action and does not send chat.")
    alertControls[#alertControls + 1] = alertTest
    refreshAlertControls()

    y = y - 38
    _, y = addSection(content, y, "Summary")
    addCheckbox(content, "Print encounter summary automatically", LEFT, y, function() return state.summaryAuto end, function(value) model:SetValue("summaryAuto", value) end)

    y = y - 42
    local diagnostics = CreateFrame("Frame", nil, content)
    diagnostics:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT, y - 30)
    diagnostics:SetSize(CONTENT_WIDTH - LEFT * 2, 65)
    local function refreshDiagnostics()
        if state.diagnosticsExpanded then diagnostics:Show() else diagnostics:Hide() end
        content:SetHeight(-y + (state.diagnosticsExpanded and 120 or 50))
    end
    local diagnosticsButton = addDisclosure(content, LEFT, y, CONTENT_WIDTH - LEFT * 2, function()
        return state.diagnosticsExpanded
    end, function()
        model:ToggleDiagnostics()
        refreshDiagnostics()
    end)
    addSegment(diagnostics, "Validate Spell IDs", 0, 0, 125, function() model:RecordAction("Validate Spell IDs") end)
    addSegment(diagnostics, "Roster", 133, 0, 80, function() model:RecordAction("Roster") end)
    addSegment(diagnostics, "Debug Scan", 221, 0, 95, function() model:RecordAction("Debug Scan") end)
    addSegment(diagnostics, "Dump", 324, 0, 75, function() model:RecordAction("Dump") end)
    addCheckbox(diagnostics, "Debug output", 0, -31, function() return state.debug end, function(value) model:SetValue("debug", value) end)
    panel.alertControls = alertControls
    panel.diagnostics = diagnostics
    refreshDiagnostics()
end

function PB.ConfigPanel:Initialize(api)
    if self.panel then return true end
    local panel = CreateFrame("Frame", "ParseBuddyOptionsPanel", UIParent)
    panel.name = "ParseBuddy"
    panel:SetScript("OnShow", function(frame) PB.ConfigPanel:Build(frame) end)
    return self:Register(panel, api)
end
