local PB = ParseBuddy

PB.Summary = {
    active = nil,
    last = nil,
}

local function percentage(seconds, total)
    if total <= 0 then
        return 0
    end
    return (seconds / total) * 100
end

local function summaryState(evaluation)
    if evaluation.state == "active" or evaluation.state == "expiring" then
        return "satisfied"
    end
    if evaluation.state == "partial" then
        return "partial"
    end
    return "missing"
end

function PB.Summary:Begin(encounter)
    self.last = nil
    PB.lastEncounterSummary = nil
    local settings = PB.Defaults:CopySettings(PB.Config:GetSettings())
    local groups = {}
    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        local groupSettings = settings.groups[group.key]
        if groupSettings and groupSettings.enabled then
            groups[group.key] = {
                key = group.key,
                label = group.label,
                required = groupSettings.required ~= false,
                current = "missing",
                lastAt = encounter.startedAt,
                satisfied = 0,
                partial = 0,
                missing = 0,
            }
        end
    end

    self.active = {
        encounterId = encounter.id,
        encounterName = encounter.name,
        startedAt = encounter.startedAt,
        graceEndsAt = encounter.startedAt + ParseBuddyDB.pullGracePeriod,
        scope = PB.Config:GetScope(),
        displayMode = settings.displayMode,
        settings = settings,
        groups = groups,
    }
end

function PB.Summary:Accrue(now)
    local active = self.active
    if not active then
        return
    end

    local _, group
    for _, group in pairs(active.groups) do
        local from = math.max(group.lastAt or active.startedAt, active.graceEndsAt)
        if now > from then
            group[group.current] = group[group.current] + (now - from)
        end
        group.lastAt = now
    end
end

function PB.Summary:Observe(now, bossGUID)
    local active = self.active
    if not active then
        return false
    end

    self:Accrue(now)
    if not bossGUID then
        return false
    end

    local evaluations = PB.State:EvaluateBoss(
        bossGUID,
        now,
        ParseBuddyDB.warningThreshold,
        false,
        active.settings.groups
    )
    local _, evaluation
    for _, evaluation in ipairs(evaluations) do
        local group = active.groups[evaluation.group.key]
        if group then
            group.current = summaryState(evaluation)
        end
    end
    return true
end

function PB.Summary:Finalize(endedAt, success)
    local active = self.active
    if not active then
        return nil
    end

    self:Accrue(endedAt)
    local measuredDuration = math.max(0, endedAt - active.graceEndsAt)
    local summary = {
        encounterId = active.encounterId,
        encounterName = active.encounterName,
        success = success == 1 or success == true,
        startedAt = active.startedAt,
        endedAt = endedAt,
        totalDuration = math.max(0, endedAt - active.startedAt),
        measuredDuration = measuredDuration,
        scope = active.scope,
        displayMode = active.displayMode,
        groups = {},
    }

    local _, libraryGroup
    for _, libraryGroup in ipairs(PB.DebuffLibrary.groups) do
        local group = active.groups[libraryGroup.key]
        if group then
            summary.groups[#summary.groups + 1] = {
                key = group.key,
                label = group.label,
                required = group.required,
                satisfied = group.satisfied,
                partial = group.partial,
                missing = group.missing,
                satisfiedPercent = percentage(group.satisfied, measuredDuration),
                partialPercent = percentage(group.partial, measuredDuration),
                missingPercent = percentage(group.missing, measuredDuration),
            }
        end
    end

    self.active = nil
    self.last = summary
    PB.lastEncounterSummary = summary
    if ParseBuddyDB.summaryAuto then
        self:Print()
    end
    return summary
end

function PB.Summary:Print()
    local summary = self.last
    if not summary then
        PB:Print("No encounter summary is available.")
        return false
    end

    PB:Print(string.format(
        "Summary: %s - %s - total %.1fs, measured %.1fs after grace - scope=%s mode=%s",
        summary.encounterName or "Unknown Encounter",
        summary.success and "success" or "wipe",
        summary.totalDuration,
        summary.measuredDuration,
        summary.scope,
        summary.displayMode
    ))
    local _, group
    for _, group in ipairs(summary.groups) do
        PB:Print(string.format(
            "%s (%s): satisfied %.1fs %.1f%%, partial %.1fs %.1f%%, missing %.1fs %.1f%%",
            group.label,
            group.required and "required" or "optional",
            group.satisfied,
            group.satisfiedPercent,
            group.partial,
            group.partialPercent,
            group.missing,
            group.missingPercent
        ))
    end
    return true
end

function PB.Summary:SetAuto(value)
    value = value and value:lower() or ""
    if value == "on" then
        ParseBuddyDB.summaryAuto = true
    elseif value == "off" then
        ParseBuddyDB.summaryAuto = false
    elseif value ~= "" then
        PB:Print("Summary auto must be 'on' or 'off'.")
        return false
    end
    PB:Print("Automatic encounter summary " .. (ParseBuddyDB.summaryAuto and "enabled." or "disabled."))
    return true
end

function PB.Summary:Clear()
    self.last = nil
    PB.lastEncounterSummary = nil
end
