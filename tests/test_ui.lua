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

print("ParseBuddy UI tests passed: " .. testsRun)
