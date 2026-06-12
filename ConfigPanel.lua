local PB = ParseBuddy

PB.ConfigPanel = {
    panel = nil,
    category = nil,
    apiPath = nil,
}

local CONTENT_WIDTH = 620
local LEFT = 18
local ROW_HEIGHT = 25

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
    end
    if control.SetAlpha then
        control:SetAlpha(enabled and 1 or 0.45)
    end
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

local function addChoice(parent, choices, x, y, selected, onSelect)
    local buttons = {}
    local offset = 0
    local _, choice
    local function refresh()
        local selectedValue = selected()
        for _, button in ipairs(buttons) do
            button:SetButtonState(button.value == selectedValue and "PUSHED" or "NORMAL", true)
        end
    end
    for _, choice in ipairs(choices) do
        local width = choice.width or 90
        local value = choice.value
        local button = addButton(parent, choice.label, x + offset, y, width, function()
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
    addText(parent, label, "GameFontHighlight", x, y - 2)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 70, y)
    slider:SetWidth(width)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    if slider.Low then slider.Low:SetText("") end
    if slider.High then slider.High:SetText("") end
    slider:SetValue(getValue())
    local valueText = addText(parent, format(getValue()), "GameFontNormal", x + width + 82, y - 2)
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value / step + 0.5) * step
        setValue(value)
        valueText:SetText(format(value))
    end)
    return slider
end

function PB.ConfigPanel:Build(panel)
    if panel.built then return end
    panel.built = true
    local model = PB.ConfigPrototype
    local state = model:GetState()

    local title = addText(panel, "ParseBuddy", "GameFontNormalHuge", LEFT, -14)
    local version = addText(panel, "v" .. tostring(PB.version or "prototype"), "GameFontHighlightSmall", 520, -21)
    version:SetTextColor(0.65, 0.65, 0.65)
    local notice = addText(panel, "CONFIGURATION PROTOTYPE - changes are not saved", "GameFontNormal", LEFT, -43)
    notice:SetTextColor(1, 0.65, 0.15)
    addText(panel, "Scope", "GameFontHighlight", LEFT, -69)
    addChoice(panel, {
        { label = "Global", value = "global", width = 82, tooltip = "Prototype account-wide scope. This does not change the live profile." },
        { label = "Personal", value = "personal", width = 82, tooltip = "Prototype character scope. This does not change the live profile." },
    }, 75, -74, function() return state.scope end, function(value) model:SetScope(value) end)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -108)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 8)
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
    addSlider(content, "Scale", LEFT, y, 150, 0.6, 1.4, 0.05, function() return state.scale end, function(value) model:SetValue("scale", value) end, function(value) return string.format("%.2f", value) end)
    addSlider(content, "Opacity", 320, y, 150, 0.2, 1, 0.05, function() return state.opacity end, function(value) model:SetValue("opacity", value) end, function(value) return string.format("%.2f", value) end)
    y = y - 36
    addButton(content, "Test Frame", LEFT, y, 105, function() model:RecordAction("Test Frame") end, "Prototype action only; the live encounter frame is not changed.")
    addButton(content, "Reset Position", 130, y, 120, function() model:RecordAction("Reset Position") end, "Prototype action only; the saved frame position is not changed.")

    y = y - 48
    _, y = addSection(content, y, "Debuff Groups")
    addText(content, "Group", "GameFontNormal", LEFT, y)
    addText(content, "Enabled", "GameFontNormal", 280, y)
    addText(content, "Requirement", "GameFontNormal", 365, y)
    addText(content, "Availability", "GameFontNormal", 525, y)
    y = y - 24
    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        local groupKey = group.key
        local groupState = state.groups[groupKey]
        addText(content, group.label, "GameFontHighlight", LEFT, y - 4, 250)
        addCheckbox(content, "", 284, y, function() return groupState.enabled end, function(value) model:SetGroupValue(groupKey, "enabled", value) end)
        addChoice(content, {
            { label = "Required", value = true, width = 78 },
            { label = "Optional", value = false, width = 74 },
        }, 356, y - 5, function() return groupState.required end, function(value) model:SetGroupValue(groupKey, "required", value) end)
        local availability = addText(content, groupState.availability, "GameFontHighlightSmall", 530, y - 4)
        if groupState.availability == "Not Available" then availability:SetTextColor(0.55, 0.55, 0.55) end
        y = y - ROW_HEIGHT
    end

    y = y - 18
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
    y = y - 34
    addText(content, "Destination", "GameFontHighlight", LEFT, y - 4)
    local channelButtons = addChoice(content, {
        { label = "Party", value = "party", width = 70 },
        { label = "Raid", value = "raid", width = 70 },
        { label = "Leader", value = "leader", width = 76 },
    }, 105, y - 9, function() return state.alerts.channel end, function(value) model:SetAlertChannel(value) end)
    local _, channelButton
    for _, channelButton in ipairs(channelButtons) do alertControls[#alertControls + 1] = channelButton end
    local delaySlider = addSlider(content, "Delay", 350, y, 130, 0, 30, 1, function() return state.alerts.delay end, function(value) model:SetAlertDelay(value) end, function(value) return tostring(value) .. " sec" end)
    alertControls[#alertControls + 1] = delaySlider
    y = y - 36
    local alertTest = addButton(content, "Test Alert", LEFT, y, 105, function() model:RecordAction("Test Alert") end, "Records a prototype action and does not send chat.")
    alertControls[#alertControls + 1] = alertTest
    refreshAlertControls()

    y = y - 48
    _, y = addSection(content, y, "Summary")
    addCheckbox(content, "Print encounter summary automatically", LEFT, y, function() return state.summaryAuto end, function(value) model:SetValue("summaryAuto", value) end)

    y = y - 48
    local diagnosticsButton
    local diagnostics = CreateFrame("Frame", nil, content)
    diagnostics:SetPoint("TOPLEFT", content, "TOPLEFT", LEFT, y - 30)
    diagnostics:SetSize(CONTENT_WIDTH - LEFT * 2, 65)
    local function refreshDiagnostics()
        if state.diagnosticsExpanded then diagnostics:Show() else diagnostics:Hide() end
        diagnosticsButton:SetText((state.diagnosticsExpanded and "v " or "> ") .. "Diagnostics")
        content:SetHeight(-y + (state.diagnosticsExpanded and 120 or 50))
    end
    diagnosticsButton = addButton(content, "> Diagnostics", LEFT, y, 130, function()
        model:ToggleDiagnostics()
        refreshDiagnostics()
    end)
    addButton(diagnostics, "Validate Spell IDs", 0, 0, 125, function() model:RecordAction("Validate Spell IDs") end)
    addButton(diagnostics, "Roster", 133, 0, 80, function() model:RecordAction("Roster") end)
    addButton(diagnostics, "Debug Scan", 221, 0, 95, function() model:RecordAction("Debug Scan") end)
    addButton(diagnostics, "Dump", 324, 0, 75, function() model:RecordAction("Dump") end)
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
