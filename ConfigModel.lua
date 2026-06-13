local PB = ParseBuddy

PB.ConfigPanelModel = {
    state = nil,
}

local AVAILABILITY_TEXT = {
    available = "Available",
    notAvailable = "Not Available",
    unknown = "Unknown",
}

local function refreshEncounter()
    if PB.Encounter and PB.Encounter.active then
        PB.Encounter:RefreshDisplay()
    end
end

function PB.ConfigPanelModel:ClampSliderValue(value, minimum, maximum, step)
    value = tonumber(value) or minimum
    value = math.max(minimum, math.min(maximum, value))
    if step and step > 0 then
        value = math.floor((value - minimum) / step + 0.5) * step + minimum
        value = math.max(minimum, math.min(maximum, value))
    end
    return value
end

function PB.ConfigPanelModel:Refresh()
    local state = self.state or { diagnosticsExpanded = false }
    local settings = PB.Config:GetSettings()
    state.scope = PB.Config:GetScope()
    state.displayMode = settings.displayMode
    state.showUnavailable = settings.showUnavailable == true
    state.locked = ParseBuddyDB.frame.locked == true
    state.scale = ParseBuddyDB.frame.scale
    state.opacity = ParseBuddyDB.frame.opacity
    state.summaryAuto = ParseBuddyDB.summaryAuto == true
    state.debug = ParseBuddyDB.debug == true
    state.alerts = state.alerts or {}
    state.alerts.enabled = settings.broadcast.enabled == true
    state.alerts.channel = settings.broadcast.channel
    state.alerts.delay = settings.broadcast.delay
    state.groups = state.groups or {}

    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        local groupSettings = PB.Config:GetGroupSettings(group.key)
        local groupState = state.groups[group.key] or {}
        groupState.enabled = groupSettings.enabled == true
        groupState.required = groupSettings.required == true
        local capability = PB.Roster and PB.Roster:GetGroupCapability(group.key) or "unknown"
        groupState.availability = AVAILABILITY_TEXT[capability] or "Unknown"
        state.groups[group.key] = groupState
    end

    self.state = state
    return state
end

function PB.ConfigPanelModel:GetState()
    return self.state or self:Refresh()
end

function PB.ConfigPanelModel:NotifyChanged()
    self:Refresh()
    if PB.ConfigPanel and PB.ConfigPanel.RefreshControls then
        PB.ConfigPanel:RefreshControls()
    end
end

function PB.ConfigPanelModel:SetScope(scope)
    if not PB.Config:SetScope(scope, true) then return false end
    self:NotifyChanged()
    return true
end

function PB.ConfigPanelModel:SetDisplayMode(mode)
    if mode ~= "PROBLEMS_ONLY" and mode ~= "FULL_LIST" then return false end
    PB.Config:SetDisplayMode(mode)
    refreshEncounter()
    self:NotifyChanged()
    return true
end

function PB.ConfigPanelModel:SetShowUnavailable(value)
    PB.Config:SetShowUnavailable(value == true)
    refreshEncounter()
    self:NotifyChanged()
    return true
end

function PB.ConfigPanelModel:SetFrameLocked(value)
    if value then PB.UI:Lock(true) else PB.UI:Unlock(true) end
    self:NotifyChanged()
    return true
end

function PB.ConfigPanelModel:SetSliderValue(key, value, minimum, maximum, step)
    value = self:ClampSliderValue(value, minimum, maximum, step)
    if key == "scale" then
        PB.UI:SetScale(value, true)
    elseif key == "opacity" then
        PB.UI:SetOpacity(value, true)
    else
        return false
    end
    self:NotifyChanged()
    return true
end

function PB.ConfigPanelModel:ResetPosition()
    PB.UI:ResetPosition(true)
    self:NotifyChanged()
end

function PB.ConfigPanelModel:SetGroupValue(groupKey, key, value)
    if key ~= "enabled" and key ~= "required" then return false end
    local settings = PB.Config:GetGroupSettings(groupKey)
    if not settings then return false end
    settings[key] = value == true
    refreshEncounter()
    self:NotifyChanged()
    return true
end

function PB.ConfigPanelModel:SetAlertsEnabled(value)
    PB.Config:GetBroadcastSettings().enabled = value == true
    self:NotifyChanged()
end

function PB.ConfigPanelModel:AreAlertControlsEnabled()
    return self:GetState().alerts.enabled == true
end

function PB.ConfigPanelModel:SetAlertChannel(channel)
    if channel ~= "party" and channel ~= "raid" and channel ~= "leader" then return false end
    PB.Config:GetBroadcastSettings().channel = channel
    self:NotifyChanged()
    return true
end

function PB.ConfigPanelModel:SetAlertDelay(delay)
    PB.Config:GetBroadcastSettings().delay = self:ClampSliderValue(delay, 0, 60, 1)
    self:NotifyChanged()
    return true
end

function PB.ConfigPanelModel:SetSummaryAuto(value)
    ParseBuddyDB.summaryAuto = value == true
    self:NotifyChanged()
end

function PB.ConfigPanelModel:SetDebug(value)
    ParseBuddyDB.debug = value == true
    self:NotifyChanged()
end

function PB.ConfigPanelModel:ToggleDiagnostics()
    local state = self:GetState()
    state.diagnosticsExpanded = not state.diagnosticsExpanded
    return state.diagnosticsExpanded
end

function PB.ConfigPanelModel:RunAction(action)
    if action == "Test Frame" then
        PB.UI:ShowTestMode()
    elseif action == "Reset Position" then
        self:ResetPosition()
    elseif action == "Test Alert" then
        PB.Broadcast:Test()
    elseif action == "Validate Spell IDs" then
        PB:ValidateSpellIds()
    elseif action == "Roster" then
        PB.Roster:Print()
    elseif action == "Debug Scan" then
        PB.Encounter:DebugScan()
    elseif action == "Dump" then
        PB:Dump()
    else
        return false
    end
    return true
end
