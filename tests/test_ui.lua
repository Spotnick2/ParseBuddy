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

print("ParseBuddy UI tests passed: " .. testsRun)
