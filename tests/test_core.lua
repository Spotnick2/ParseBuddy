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
        PrintTargets = function(self) self.targets = (self.targets or 0) + 1 end,
    },
    UI = {
        ShowTestMode = function() end,
        Lock = function() end,
        Unlock = function() end,
        ResetPosition = function() end,
        SetScale = function() end,
        SetOpacity = function(self, value) self.opacity = value end,
        SetDisplayMode = function(self, value) self.displayMode = value end,
    },
    Config = {
        SetScope = function(self, value) self.scope = value end,
        HandleGroupCommand = function(self, value) self.groupCommand = value end,
        PrintGroups = function(self) self.groupsPrinted = (self.groupsPrinted or 0) + 1 end,
        HandleUnavailableCommand = function(self, value) self.unavailable = value end,
    },
    Roster = {
        Print = function(self) self.prints = (self.prints or 0) + 1 end,
    },
    Summary = {
        Print = function(self) self.prints = (self.prints or 0) + 1 end,
        SetAuto = function(self, value) self.auto = value end,
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

ParseBuddy:HandleSlashCommand("mode problems")
assertEqual(ParseBuddy.UI.displayMode, "problems", "problems mode slash command dispatches value")
ParseBuddy:HandleSlashCommand("mode full")
assertEqual(ParseBuddy.UI.displayMode, "full", "full mode slash command dispatches value")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "mode", 1, true) ~= nil, true, "help lists display mode")

ParseBuddy:HandleSlashCommand("profile personal")
assertEqual(ParseBuddy.Config.scope, "personal", "profile slash command dispatches scope")
ParseBuddy:HandleSlashCommand("group majorArmor optional")
assertEqual(ParseBuddy.Config.groupCommand, "majorarmor optional", "group slash command dispatches normalized argument")
ParseBuddy:HandleSlashCommand("groups")
assertEqual(ParseBuddy.Config.groupsPrinted, 1, "groups slash command lists settings")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "profile", 1, true) ~= nil, true, "help lists profile scope")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "group", 1, true) ~= nil, true, "help lists group commands")

ParseBuddy:HandleSlashCommand("unavailable show")
assertEqual(ParseBuddy.Config.unavailable, "show", "unavailable slash command dispatches scoped setting")
ParseBuddy:HandleSlashCommand("roster")
assertEqual(ParseBuddy.Roster.prints, 1, "roster slash command prints cached diagnostics")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "unavailable", 1, true) ~= nil, true, "help lists unavailable setting")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "roster", 1, true) ~= nil, true, "help lists roster diagnostics")

ParseBuddy:HandleSlashCommand("summary")
assertEqual(ParseBuddy.Summary.prints, 1, "summary slash command prints latest summary")
ParseBuddy:HandleSlashCommand("summary auto on")
assertEqual(ParseBuddy.Summary.auto, "on", "summary auto slash command dispatches value")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "summary", 1, true) ~= nil, true, "help lists summary commands")

ParseBuddy:HandleSlashCommand("targets")
assertEqual(ParseBuddy.Encounter.targets, 1, "targets slash command prints encounter target diagnostics")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "targets", 1, true) ~= nil, true, "help lists target diagnostics")

ParseBuddy:HandleSlashCommand("snapshot")
assertEqual(ParseBuddy.snapshots, 1, "snapshot slash command prints saved snapshot")
ParseBuddy:HandleSlashCommand("clear")
assertEqual(ParseBuddy.clears, 1, "clear slash command clears saved snapshot")
ParseBuddy:HandleSlashCommand("help")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "snapshot", 1, true) ~= nil, true, "help lists snapshot")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "clear", 1, true) ~= nil, true, "help lists clear")

print("ParseBuddy Core tests passed: " .. testsRun)
