ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
    validations = 0,
    ValidateSpellIds = function(self)
        self.validations = self.validations + 1
    end,
    Encounter = {
        scans = 0,
        DebugScan = function(self)
            self.scans = self.scans + 1
        end,
    },
    UI = {
        ShowTestMode = function() end,
        Lock = function() end,
        Unlock = function() end,
        ResetPosition = function() end,
        SetScale = function() end,
    },
}

CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
        UnregisterEvent = function() end,
    }
end
SlashCmdList = {}

assert(loadfile("Core.lua"))()

local testsRun = 0
local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

ParseBuddy:HandleSlashCommand("debugscan")
assertEqual(ParseBuddy.Encounter.scans, 1, "debugscan slash command dispatches encounter scan")

ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "debugscan", 1, true) ~= nil, true, "help lists debugscan")

ParseBuddy:HandleSlashCommand("validate")
assertEqual(ParseBuddy.validations, 1, "validate slash command dispatches spell validation")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "validate", 1, true) ~= nil, true, "help lists validate")

print("ParseBuddy Core tests passed: " .. testsRun)
