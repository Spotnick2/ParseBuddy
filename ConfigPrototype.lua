local PB = ParseBuddy

PB.ConfigPrototype = {}

local AVAILABILITY = {
    spellVulnerability = "Available",
    majorArmor = "Available",
    faerieFire = "Available",
    judgement = "Not Available",
    attackPower = "Available",
    attackSpeed = "Available",
    recklessness = "Unknown",
}

function PB.ConfigPrototype:Reset()
    local groups = {}
    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        groups[group.key] = {
            enabled = true,
            required = group.key ~= "recklessness",
            availability = AVAILABILITY[group.key] or "Unknown",
        }
    end
    self.state = {
        scope = "global",
        displayMode = "PROBLEMS_ONLY",
        showUnavailable = false,
        locked = true,
        scale = 0.8,
        opacity = 0.9,
        groups = groups,
        alerts = {
            enabled = false,
            channel = "raid",
            delay = 3,
        },
        summaryAuto = false,
        diagnosticsExpanded = false,
        debug = false,
        lastAction = nil,
    }
    return self.state
end

function PB.ConfigPrototype:GetState()
    return self.state or self:Reset()
end

function PB.ConfigPrototype:SetScope(scope)
    if scope == "global" or scope == "personal" then
        self:GetState().scope = scope
        return true
    end
    return false
end

function PB.ConfigPrototype:SetDisplayMode(mode)
    if mode == "PROBLEMS_ONLY" or mode == "FULL_LIST" then
        self:GetState().displayMode = mode
        return true
    end
    return false
end

function PB.ConfigPrototype:SetValue(key, value)
    if self:GetState()[key] == nil then
        return false
    end
    self.state[key] = value
    return true
end

function PB.ConfigPrototype:ClampSliderValue(value, minimum, maximum, step)
    value = tonumber(value) or minimum
    value = math.max(minimum, math.min(maximum, value))
    if step and step > 0 then
        value = math.floor((value - minimum) / step + 0.5) * step + minimum
        value = math.max(minimum, math.min(maximum, value))
    end
    return value
end

function PB.ConfigPrototype:SetSliderValue(key, value, minimum, maximum, step)
    if self:GetState()[key] == nil then
        return false
    end
    self.state[key] = self:ClampSliderValue(value, minimum, maximum, step)
    return true
end

function PB.ConfigPrototype:SetGroupValue(groupKey, key, value)
    local group = self:GetState().groups[groupKey]
    if not group or (key ~= "enabled" and key ~= "required") then
        return false
    end
    group[key] = value == true
    return true
end

function PB.ConfigPrototype:SetAlertsEnabled(enabled)
    self:GetState().alerts.enabled = enabled == true
end

function PB.ConfigPrototype:AreAlertControlsEnabled()
    return self:GetState().alerts.enabled == true
end

function PB.ConfigPrototype:SetAlertChannel(channel)
    if channel ~= "party" and channel ~= "raid" and channel ~= "leader" then
        return false
    end
    self:GetState().alerts.channel = channel
    return true
end

function PB.ConfigPrototype:SetAlertDelay(delay)
    self:GetState().alerts.delay = self:ClampSliderValue(delay, 0, 60, 1)
    return true
end

function PB.ConfigPrototype:ToggleDiagnostics()
    local state = self:GetState()
    state.diagnosticsExpanded = not state.diagnosticsExpanded
    return state.diagnosticsExpanded
end

function PB.ConfigPrototype:RecordAction(action)
    self:GetState().lastAction = action
    PB:Print("Configuration prototype: " .. action .. ". No live setting was changed.")
end

PB.ConfigPrototype:Reset()
