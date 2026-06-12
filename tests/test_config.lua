ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
    Encounter = {
        active = false,
        refreshes = 0,
        RefreshDisplay = function(self)
            self.refreshes = self.refreshes + 1
        end,
    },
}

ParseBuddyDB = {
    displayMode = "FULL_LIST",
}
ParseBuddyCharDB = nil

assert(loadfile("Defaults.lua"))()
assert(loadfile("DebuffLibrary.lua"))()
assert(loadfile("Config.lua"))()

local Config = ParseBuddy.Config
local testsRun = 0

local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

Config:Initialize()
assertEqual(Config:GetScope(), "global", "new character defaults to global scope")
assertEqual(ParseBuddyDB.schemaVersion, 2, "account settings schema upgraded")
assertEqual(ParseBuddyCharDB.schemaVersion, 1, "character settings schema initialized")
assertEqual(Config:GetDisplayMode(), "FULL_LIST", "legacy account display mode migrates into global settings")
assertEqual(Config:GetGroupSettings("recklessness").enabled, true, "recklessness enabled by default")
assertEqual(Config:GetGroupSettings("recklessness").required, false, "recklessness optional by default")
assertEqual(Config:GetGroupSettings("majorArmor").required, true, "core groups required by default")
assertEqual(ParseBuddyCharDB.settings, nil, "personal settings are lazy")

Config:SetScope("personal")
assertEqual(Config:GetScope(), "personal", "personal scope selected")
assertEqual(ParseBuddyCharDB.settings.displayMode, "FULL_LIST", "first personal selection copies global display mode")
assertEqual(ParseBuddyCharDB.settings.groups.majorArmor.required, true, "first personal selection copies group settings")

Config:SetDisplayMode("PROBLEMS_ONLY")
Config:HandleGroupCommand("majorarmor optional")
Config:HandleGroupCommand("recklessness disable")
assertEqual(ParseBuddyCharDB.settings.displayMode, "PROBLEMS_ONLY", "personal display mode mutates personal settings")
assertEqual(ParseBuddyCharDB.settings.groups.majorArmor.required, false, "personal group requirement persists")
assertEqual(ParseBuddyCharDB.settings.groups.recklessness.enabled, false, "personal group enable state persists")

Config:SetScope("global")
assertEqual(Config:GetDisplayMode(), "FULL_LIST", "global display mode preserved after personal changes")
assertEqual(Config:GetGroupSettings("majorArmor").required, true, "global group requirement preserved")
assertEqual(Config:GetGroupSettings("recklessness").enabled, true, "global group enable state preserved")

Config:HandleGroupCommand("spellvulnerability disable")
assertEqual(ParseBuddyDB.settings.groups.spellVulnerability.enabled, false, "case-insensitive stable key mutates global settings")
Config:SetScope("personal")
assertEqual(Config:GetGroupSettings("spellVulnerability").enabled, true, "existing personal copy is not overwritten by later global changes")

Config:Initialize()
assertEqual(Config:GetScope(), "personal", "scope selection persists across initialization")
assertEqual(Config:GetDisplayMode(), "PROBLEMS_ONLY", "personal display setting persists across initialization")
assertEqual(Config:GetGroupSettings("majorArmor").required, false, "personal group setting persists across initialization")

ParseBuddy.Encounter.active = true
Config:HandleGroupCommand("judgement optional")
assertEqual(ParseBuddy.Encounter.refreshes, 1, "group mutation refreshes active encounter")
Config:SetScope("global")
assertEqual(ParseBuddy.Encounter.refreshes, 2, "scope switch refreshes active encounter")

assertEqual(Config:HandleGroupCommand("notAGroup enable"), false, "unknown group key rejected")
assertEqual(Config:HandleGroupCommand("majorArmor invalid"), false, "invalid group action rejected")
assertEqual(Config:SetScope("invalid"), false, "invalid scope rejected")

local messageCount = #ParseBuddy.messages
Config:PrintGroups()
assertEqual(#ParseBuddy.messages, messageCount + 7, "groups command prints every stable group key")

print("ParseBuddy Config tests passed: " .. testsRun)
