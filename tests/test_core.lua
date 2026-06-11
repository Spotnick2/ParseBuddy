ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
    validations = 0,
    ValidateSpellIds = function(self)
        self.validations = self.validations + 1
    end,
    snapshots = 0,
    clears = 0,
    PrintSnapshot = function(self) self.snapshots = self.snapshots + 1 end,
    ClearSnapshot = function(self) self.clears = self.clears + 1 end,
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
        SetOpacity = function(self, value) self.opacity = value end,
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

ParseBuddy:HandleSlashCommand("opacity 0.65")
assertEqual(ParseBuddy.UI.opacity, "0.65", "opacity slash command dispatches value")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "opacity", 1, true) ~= nil, true, "help lists opacity")

ParseBuddy:HandleSlashCommand("snapshot")
assertEqual(ParseBuddy.snapshots, 1, "snapshot slash command prints saved snapshot")
ParseBuddy:HandleSlashCommand("clear")
assertEqual(ParseBuddy.clears, 1, "clear slash command clears saved snapshot")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "snapshot", 1, true) ~= nil, true, "help lists snapshot")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "clear", 1, true) ~= nil, true, "help lists clear")

print("ParseBuddy Core tests passed: " .. testsRun)
