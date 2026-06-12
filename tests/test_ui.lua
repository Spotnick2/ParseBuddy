ParseBuddy = {
    Encounter = { active = true },
    printed = nil,
    Print = function(self, message)
        self.printed = message
    end,
    DebuffLibrary = { groups = {} },
    State = {
        CreateTestEvaluations = function()
            error("test evaluations should not be created during an encounter")
        end,
    },
}

assert(loadfile("UI.lua"))()

local testsRun = 0

local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

ParseBuddy.UI:ShowTestMode()
assertEqual(ParseBuddy.printed, "Test mode is unavailable during an active encounter.", "test mode blocked during encounter")
assertEqual(ParseBuddy.UI.mode, nil, "blocked test mode does not replace encounter mode")

local hides = 0
ParseBuddy.UI.frame = {
    Hide = function()
        hides = hides + 1
    end,
}
ParseBuddy.UI.mode = "test"
ParseBuddy.UI:HideEncounter()
assertEqual(hides, 1, "encounter end hides frame regardless of prior mode")
assertEqual(ParseBuddy.UI.mode, nil, "encounter end clears UI mode")

GetSpellTexture = function(spellId) return "icon-" .. tostring(spellId) end
local calls = { color = 0, icon = 0, group = 0, effect = 0, source = 0, status = 0 }
local function textTarget(key)
    return {
        SetText = function()
            calls[key] = calls[key] + 1
        end,
    }
end
local row = {
    SetBackdropColor = function() calls.color = calls.color + 1 end,
    icon = { SetTexture = function() calls.icon = calls.icon + 1 end },
    groupText = textTarget("group"),
    effectText = textTarget("effect"),
    sourceText = textTarget("source"),
    statusText = textTarget("status"),
}
local data = {
    state = "active",
    iconSpellId = 25225,
    group = "Armor",
    effect = "Sunder 5/5",
    source = "Tank",
    status = "00:24",
}
ParseBuddy.UI:ApplyRowData(row, data)
ParseBuddy.UI:ApplyRowData(row, data)
assertEqual(calls.color, 1, "unchanged row color is not redrawn")
assertEqual(calls.icon, 1, "unchanged row icon is not redrawn")
assertEqual(calls.group, 1, "unchanged group text is not redrawn")
assertEqual(calls.effect, 1, "unchanged effect text is not redrawn")
assertEqual(calls.source, 1, "unchanged source text is not redrawn")
assertEqual(calls.status, 1, "unchanged timer text is not redrawn")
data.status = "00:23"
ParseBuddy.UI:ApplyRowData(row, data)
assertEqual(calls.status, 2, "changed timer text is redrawn")
assertEqual(calls.icon, 1, "timer update does not redraw icon")

local alpha
ParseBuddyDB = { frame = { opacity = 0.65 } }
ParseBuddy.UI.frame = {
    SetAlpha = function(_, value) alpha = value end,
}
ParseBuddy.UI:ApplySavedOpacity()
assertEqual(alpha, 0.65, "saved opacity applies to frame")

ParseBuddy.UI:SetOpacity("0.45")
assertEqual(ParseBuddyDB.frame.opacity, 0.45, "opacity setting persists")
assertEqual(alpha, 0.45, "opacity setting applies immediately")

ParseBuddy.UI:SetOpacity("0.10")
assertEqual(ParseBuddyDB.frame.opacity, 0.45, "invalid opacity does not change setting")

local titleText
local lockTexture
ParseBuddy.UI.frame = {
    SetAlpha = function(_, value) alpha = value end,
    title = { SetText = function(_, value) titleText = value end },
    lockButton = { SetNormalTexture = function(_, value) lockTexture = value end },
}
ParseBuddyDB.frame.locked = true
ParseBuddy.UI:UpdateLockDisplay()
assertEqual(titleText, "ParseBuddy", "lock state is not embedded in title text")
assertEqual(lockTexture, "Interface\\Buttons\\LockButton-Locked-Up", "locked texture is shown")
ParseBuddyDB.frame.locked = false
ParseBuddy.UI:UpdateLockDisplay()
assertEqual(lockTexture, "Interface\\Buttons\\LockButton-Unlocked-Up", "unlocked texture is shown")

ParseBuddyDB.frame.point = "TOPLEFT"
ParseBuddyDB.frame.relativePoint = "TOPLEFT"
ParseBuddyDB.frame.x = 20
ParseBuddyDB.frame.y = -20
ParseBuddyDB.frame.scale = 0.8
ParseBuddy.UI.ApplySavedPosition = function() end
ParseBuddy.UI.ApplySavedScale = function() end
ParseBuddy.UI:ResetPosition()
assertEqual(ParseBuddyDB.frame.opacity, 1, "reset restores opacity")

local function evaluation(state, required, sourceKnown, label)
    return {
        state = state,
        sourceKnown = sourceKnown,
        group = {
            label = label,
            missingText = label,
            required = required,
            spells = { { spellIds = { 1 } } },
        },
        candidate = state ~= "missing" and state ~= "grace" and { spellId = 1, sourceName = sourceKnown and "Source" or nil } or nil,
        spell = state ~= "missing" and state ~= "grace" and { displayName = label } or nil,
    }
end

assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("active", true, true, "Healthy"), "PROBLEMS_ONLY"), false, "healthy active row hidden in problems mode")
assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("active", true, false, "Unknown"), "PROBLEMS_ONLY"), true, "unknown-source active row shown in problems mode")
assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("expiring", false, true, "Expiring"), "PROBLEMS_ONLY"), true, "expiring row shown in problems mode")
assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("partial", false, true, "Partial"), "PROBLEMS_ONLY"), true, "partial row shown in problems mode")
assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("missing", true, false, "Required"), "PROBLEMS_ONLY"), true, "required missing row shown in problems mode")
assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("missing", false, false, "Optional"), "PROBLEMS_ONLY"), false, "optional missing row hidden in problems mode")
assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("grace", true, false, "Grace"), "PROBLEMS_ONLY"), true, "required grace row shown in problems mode")
assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("disabled", true, false, "Disabled"), "FULL_LIST"), false, "disabled row hidden in full mode")
assertEqual(ParseBuddy.UI:IsEvaluationVisible(evaluation("active", true, true, "Healthy"), "FULL_LIST"), true, "healthy row shown in full mode")

local rendered = {}
local rowShows = { 0, 0, 0, 0 }
local rowHides = { 0, 0, 0, 0 }
local height
local rows = {}
local index
for index = 1, 4 do
    rows[index] = {
        Show = function() rowShows[index] = rowShows[index] + 1 end,
        Hide = function() rowHides[index] = rowHides[index] + 1 end,
    }
end
ParseBuddy.UI.frame = {
    rows = rows,
    SetHeight = function(_, value) height = value end,
}
ParseBuddy.UI.ApplyRowData = function(_, targetRow, rowData)
    rendered[#rendered + 1] = { row = targetRow, group = rowData.group }
end
ParseBuddyDB.displayMode = "PROBLEMS_ONLY"
local compactEvaluations = {
    evaluation("active", true, true, "Healthy One"),
    evaluation("missing", true, false, "Missing"),
    evaluation("active", true, true, "Healthy Two"),
    evaluation("expiring", true, true, "Expiring"),
}
assertEqual(ParseBuddy.UI:RenderEvaluations(compactEvaluations, false), 2, "problems mode compacts visible rows")
assertEqual(rendered[1].group, "Missing", "first compact slot receives first problem")
assertEqual(rendered[2].group, "Expiring", "second compact slot receives later problem")
assertEqual(rowShows[1], 1, "first compact row shown")
assertEqual(rowShows[2], 1, "second compact row shown")
assertEqual(rowShows[3], 0, "unused stale row remains hidden")
assertEqual(rowHides[4], 1, "all row slots are hidden before compaction")
assertEqual(height, 116, "frame height matches two compact rows")

local showCountBeforeRepeat = rowShows[1] + rowShows[2] + rowShows[3] + rowShows[4]
local hideCountBeforeRepeat = rowHides[1] + rowHides[2] + rowHides[3] + rowHides[4]
ParseBuddy.UI:RenderEvaluations(compactEvaluations, false)
assertEqual(rowShows[1] + rowShows[2] + rowShows[3] + rowShows[4], showCountBeforeRepeat, "unchanged compact rows are not reshown on ticker refresh")
assertEqual(rowHides[1] + rowHides[2] + rowHides[3] + rowHides[4], hideCountBeforeRepeat, "unchanged hidden rows are not rehidden on ticker refresh")

rendered = {}
ParseBuddyDB.displayMode = "FULL_LIST"
assertEqual(ParseBuddy.UI:RenderEvaluations(compactEvaluations, false), 4, "full mode renders every enabled evaluation")
assertEqual(rendered[3].group, "Healthy Two", "full mode overwrites compact row slots without stale data")

rendered = {}
ParseBuddyDB.displayMode = "PROBLEMS_ONLY"
assertEqual(ParseBuddy.UI:RenderEvaluations(compactEvaluations, true), 4, "test rendering bypasses display filtering")

local refreshes = 0
ParseBuddy.Encounter.active = true
ParseBuddy.Encounter.RefreshDisplay = function() refreshes = refreshes + 1 end
ParseBuddy.UI:SetDisplayMode("full")
assertEqual(ParseBuddyDB.displayMode, "FULL_LIST", "full mode persists")
assertEqual(refreshes, 1, "mode change refreshes active encounter")
ParseBuddy.UI:SetDisplayMode("problems")
assertEqual(ParseBuddyDB.displayMode, "PROBLEMS_ONLY", "problems mode persists")
assertEqual(refreshes, 2, "second mode change refreshes active encounter")
ParseBuddy.UI:SetDisplayMode("invalid")
assertEqual(ParseBuddyDB.displayMode, "PROBLEMS_ONLY", "invalid mode leaves persisted setting unchanged")

print("ParseBuddy UI tests passed: " .. testsRun)
