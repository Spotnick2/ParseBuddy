local PB = ParseBuddy

PB.Broadcast = {
    active = nil,
    timerToken = 0,
}

local GLOBAL_COOLDOWN = 5
local GROUP_COOLDOWN = 30

local runtimeProvider = {
    Now = function() return GetTime() end,
    After = function(delay, callback) C_Timer.After(delay, callback) end,
    IsInRaid = function() return IsInRaid and IsInRaid() or false end,
    IsInGroup = function() return IsInGroup and IsInGroup() or false end,
    Send = function(message, channel, target) SendChatMessage(message, channel, nil, target) end,
    InCombat = function() return InCombatLockdown and InCombatLockdown() or false end,
}

local function boolText(value)
    return value and "yes" or "no"
end

local function formatMessage(group)
    return string.format("[ParseBuddy] Missing boss debuff: %s (%s).", group.label, group.missingText)
end

function PB.Broadcast:SetProvider(provider)
    self.provider = provider
end

function PB.Broadcast:GetProvider()
    return self.provider or runtimeProvider
end

function PB.Broadcast:Begin(encounter)
    self:End()
    local settings = PB.Defaults:CopySettings(PB.Config:GetSettings())
    local broadcast = settings.broadcast or {}
    local groups = {}
    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        local groupSettings = settings.groups[group.key]
        groups[group.key] = {
            key = group.key,
            label = group.label,
            missingText = group.missingText,
            enabled = groupSettings and groupSettings.enabled == true,
            required = groupSettings and groupSettings.required ~= false,
            capability = PB.Roster and PB.Roster:GetGroupCapability(group.key) or "unknown",
            announced = false,
            missingActive = false,
        }
    end

    self.active = {
        encounterId = encounter.id,
        encounterName = encounter.name,
        startedAt = encounter.startedAt,
        graceEndsAt = encounter.startedAt + ParseBuddyDB.pullGracePeriod,
        scope = PB.Config:GetScope(),
        enabled = broadcast.enabled == true,
        channel = broadcast.channel or "raid",
        delay = tonumber(broadcast.delay) or 3,
        groups = groups,
        lastSentAt = nil,
    }
end

function PB.Broadcast:End()
    self.timerToken = self.timerToken + 1
    self.active = nil
end

function PB.Broadcast:Schedule()
    local active = self.active
    if not active or not active.enabled then
        return
    end
    self.timerToken = self.timerToken + 1
    local earliest
    local _, group
    for _, group in pairs(active.groups) do
        if group.dueAt and (not earliest or group.dueAt < earliest) then
            earliest = group.dueAt
        end
    end
    if not earliest then
        return
    end

    local token = self.timerToken
    local provider = self:GetProvider()
    provider.After(math.max(0, earliest - provider.Now()), function()
        if self.active == active and self.timerToken == token then
            self:ProcessDue()
        end
    end)
end

function PB.Broadcast:Observe(now, evaluations)
    local active = self.active
    if not active or not active.enabled then
        return false
    end
    local changed = false
    local _, evaluation
    for _, evaluation in ipairs(evaluations or {}) do
        local group = active.groups[evaluation.group.key]
        if group then
            local state = evaluation.state
            if state == "active" or state == "expiring" then
                if group.announced or group.missingActive or group.dueAt then
                    changed = true
                end
                group.announced = false
                group.missingActive = false
                group.dueAt = nil
            elseif group.enabled and group.required and group.capability == "available"
                and (state == "missing" or state == "grace")
            then
                if not group.missingActive then
                    group.missingActive = true
                    changed = true
                    if not group.announced then
                        local base = state == "grace" and active.graceEndsAt or now
                        group.dueAt = math.max(base, active.graceEndsAt) + active.delay
                    end
                end
            else
                if group.dueAt or group.missingActive then
                    changed = true
                end
                group.dueAt = nil
                group.missingActive = false
            end
        end
    end
    if changed then
        self:Schedule()
    end
    return changed
end

function PB.Broadcast:ResolveDestination()
    local active = self.active
    local provider = self:GetProvider()
    if active.channel == "party" and provider.IsInGroup() then
        return "PARTY", nil
    elseif active.channel == "raid" and provider.IsInRaid() then
        return "RAID", nil
    elseif active.channel == "leader" then
        local leaderName = PB.Roster and PB.Roster:GetLeaderName() or nil
        if leaderName then
            return "WHISPER", leaderName
        end
    end
    return nil, nil
end

function PB.Broadcast:SendGroup(group, now)
    local channel, target = self:ResolveDestination()
    if not channel then
        PB:Debug("Broadcast suppressed: destination " .. tostring(self.active.channel) .. " is unavailable.")
        return false
    end
    self:GetProvider().Send(formatMessage(group), channel, target)
    self.active.lastSentAt = now
    group.lastSentAt = now
    return true
end

function PB.Broadcast:ProcessDue()
    local active = self.active
    if not active or not active.enabled then
        return false
    end
    local provider = self:GetProvider()
    local now = provider.Now()
    local due = {}
    local _, group
    for _, group in pairs(active.groups) do
        if group.dueAt and group.dueAt <= now and not group.announced then
            due[#due + 1] = group
        end
    end
    table.sort(due, function(left, right) return left.key < right.key end)

    local sent = false
    for _, group in ipairs(due) do
        local allowedAt = math.max(
            group.dueAt,
            (active.lastSentAt or -math.huge) + GLOBAL_COOLDOWN,
            (group.lastSentAt or -math.huge) + GROUP_COOLDOWN
        )
        if allowedAt <= now and not sent then
            self:SendGroup(group, now)
            group.announced = true
            group.dueAt = nil
            sent = true
        else
            group.dueAt = allowedAt
        end
    end
    self:Schedule()
    return sent
end

function PB.Broadcast:GetDiagnosticLines()
    local lines = {}
    local active = self.active
    if not active then
        lines[1] = "Broadcast: active=no"
        return lines
    end
    lines[#lines + 1] = string.format(
        "Broadcast: active=yes enabled=%s scope=%s channel=%s delay=%.1f lastSentAt=%s",
        boolText(active.enabled), tostring(active.scope), tostring(active.channel), active.delay,
        active.lastSentAt and string.format("%.1f", active.lastSentAt) or "none"
    )
    local keys = {}
    local key
    for key in pairs(active.groups) do keys[#keys + 1] = key end
    table.sort(keys)
    local _, groupKey
    for _, groupKey in ipairs(keys) do
        local group = active.groups[groupKey]
        if group.dueAt or group.announced or group.missingActive then
            lines[#lines + 1] = string.format(
                "  group=%s capability=%s missing=%s announced=%s dueAt=%s",
                group.key, group.capability, boolText(group.missingActive), boolText(group.announced),
                group.dueAt and string.format("%.1f", group.dueAt) or "none"
            )
        end
    end
    return lines
end

function PB.Broadcast:Test()
    if self:GetProvider().InCombat() then
        PB:Print("Broadcast test is unavailable during combat.")
        return false
    end
    PB:Print("[ParseBuddy TEST] Missing boss debuff: Armor (Sunder / Expose). No group message was sent.")
    return true
end
