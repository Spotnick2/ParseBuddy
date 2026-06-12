ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
}

ParseBuddyDB = {
    pullGracePeriod = 6,
    warningThreshold = 5,
    summaryAuto = false,
}

assert(loadfile("Defaults.lua"))()
assert(loadfile("DebuffLibrary.lua"))()

local sourceSettings = ParseBuddy.Defaults:CopySettings(ParseBuddy.Defaults.settings)
sourceSettings.displayMode = "FULL_LIST"
sourceSettings.groups.attackPower.enabled = false
sourceSettings.groups.recklessness.required = false

ParseBuddy.Config = {
    GetSettings = function() return sourceSettings end,
    GetScope = function() return "personal" end,
}

local states = {}
ParseBuddy.State = {
    EvaluateBoss = function(_, _, _, _, _, settingsByGroup)
        local evaluations = {}
        local _, group
        for _, group in ipairs(ParseBuddy.DebuffLibrary.groups) do
            local settings = settingsByGroup[group.key]
            evaluations[#evaluations + 1] = {
                group = group,
                state = settings.enabled and (states[group.key] or "missing") or "disabled",
                required = settings.required,
            }
        end
        return evaluations
    end,
}

assert(loadfile("Summary.lua"))()

local Summary = ParseBuddy.Summary
local testsRun = 0

local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertNear(actual, expected, message)
    testsRun = testsRun + 1
    if math.abs(actual - expected) > 0.001 then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function findGroup(summary, key)
    local _, group
    for _, group in ipairs(summary.groups) do
        if group.key == key then
            return group
        end
    end
end

Summary:Begin({ id = 1, name = "Test Boss", startedAt = 0 })
assertEqual(Summary.last, nil, "new encounter clears previous summary")
assertEqual(Summary.active.scope, "personal", "settings scope frozen at pull")
assertEqual(Summary.active.displayMode, "FULL_LIST", "display mode frozen at pull")
assertEqual(Summary.active.groups.attackPower, nil, "disabled group excluded from accumulator")
assertEqual(Summary.active.groups.recklessness.required, false, "optional group retained")
Summary:RecordPrimarySwitch(1, { guid = "Boss-A", name = "First Boss" }, "recent-registered")
Summary:RecordPrimarySwitch(12, { guid = "Boss-B", name = "Second Boss" }, "recent-registered")

states.majorArmor = "active"
Summary:Observe(2, "Boss")
sourceSettings.groups.majorArmor.enabled = false
sourceSettings.displayMode = "PROBLEMS_ONLY"
Summary:Observe(8, "Boss")
assertEqual(Summary.active.settings.groups.majorArmor.enabled, true, "mid-fight settings do not alter frozen enabled flag")
assertEqual(Summary.active.displayMode, "FULL_LIST", "mid-fight mode does not alter frozen metadata")

states.majorArmor = "active"
Summary:Observe(8, "Boss")
states.majorArmor = "partial"
Summary:Observe(10, "Boss")
states.majorArmor = "active"
Summary:Observe(14, "Boss")
states.majorArmor = "missing"
Summary:Observe(18, "Boss")

local summary = Summary:Finalize(20, 1)
local armor = findGroup(summary, "majorArmor")
assertEqual(summary.success, true, "success summary recorded")
assertNear(summary.totalDuration, 20, "total duration includes pull grace")
assertNear(summary.measuredDuration, 14, "measured duration excludes pull grace")
assertNear(armor.satisfied, 8, "active and equivalent same-time handoff remain satisfied without gap")
assertNear(armor.partial, 4, "partial duration tracked separately")
assertNear(armor.missing, 2, "missing duration tracked")
assertNear(armor.satisfiedPercent, 57.142857, "satisfied percentage calculated")
assertEqual(findGroup(summary, "attackPower"), nil, "disabled group omitted from final summary")
assertEqual(findGroup(summary, "recklessness").required, false, "optional flag preserved in final summary")
assertEqual(#summary.primarySwitches, 2, "primary switches retained as summary metadata")
assertEqual(summary.primarySwitches[2].guid, "Boss-B", "latest primary switch GUID retained")
assertEqual(ParseBuddyDB.lastEncounterSummary, nil, "completed summary is not persisted in account saved variables")
assertEqual(ParseBuddyCharDB, nil, "completed summary does not create character saved variables")

Summary:Begin({ id = 2, name = "Wipe Boss", startedAt = 30 })
assertEqual(Summary.last, nil, "new encounter replaces prior summary immediately")
assertEqual(ParseBuddy.lastEncounterSummary, nil, "new encounter clears addon summary reference")
states.majorArmor = "active"
Summary:Observe(36, "Boss")
ParseBuddyDB.summaryAuto = true
local messageCount = #ParseBuddy.messages
summary = Summary:Finalize(40, 0)
assertEqual(summary.success, false, "wipe summary recorded")
assertEqual(#ParseBuddy.messages > messageCount, true, "automatic summary prints when enabled")

assertEqual(Summary:SetAuto("off"), true, "automatic output can be disabled")
assertEqual(ParseBuddyDB.summaryAuto, false, "automatic output setting persists account-wide")
assertEqual(Summary:SetAuto("invalid"), false, "invalid automatic output value rejected")
assertEqual(Summary:Print(), true, "manual summary prints latest encounter")

Summary:Clear()
assertEqual(Summary.last, nil, "clear removes latest summary")
assertEqual(ParseBuddy.lastEncounterSummary, nil, "clear removes addon summary reference")
assertEqual(Summary.active, nil, "completed summary clear leaves no completed accumulator")
assertEqual(Summary:Print(), false, "manual summary reports missing after clear")

Summary:Begin({ id = 3, name = "Active Boss", startedAt = 50 })
local activeAccumulator = Summary.active
Summary:Clear()
assertEqual(Summary.active, activeAccumulator, "clear does not destroy an active encounter accumulator")

print("ParseBuddy Summary tests passed: " .. testsRun)
