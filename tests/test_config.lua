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
assertEqual(ParseBuddyDB.schemaVersion, 4, "account settings schema upgraded")
assertEqual(ParseBuddyCharDB.schemaVersion, 3, "character settings schema initialized")
assertEqual(Config:GetDisplayMode(), "FULL_LIST", "legacy account display mode migrates into global settings")
assertEqual(Config:GetGroupSettings("recklessness").enabled, true, "recklessness enabled by default")
assertEqual(Config:GetGroupSettings("recklessness").required, false, "recklessness optional by default")
assertEqual(Config:GetGroupSettings("majorArmor").required, true, "core groups required by default")
assertEqual(ParseBuddyCharDB.settings, nil, "personal settings are lazy")
assertEqual(Config:GetGroupSettings("attackSpeed").visibility, "applied", "thunder clap ships as applied-only")
assertEqual(Config:GetGroupSettings("attackSpeed").required, false, "applied-only groups do not alert by default")
assertEqual(Config:GetGroupSettings("majorArmor").visibility, "always", "core groups ship as always-shown")

local appliedGroup = Config:GetGroupSettings("attackSpeed")
Config:HandleGroupCommand("attackSpeed always")
assertEqual(appliedGroup.visibility, "always", "always verb promotes an applied-only group")
assertEqual(appliedGroup.enabled, true, "always verb also turns tracking on")
Config:HandleGroupCommand("attackSpeed required")
assertEqual(appliedGroup.required, true, "required verb still sets the alert flag")
Config:HandleGroupCommand("attackSpeed applied")
assertEqual(appliedGroup.visibility, "applied", "applied verb demotes the group")
assertEqual(appliedGroup.required, true, "applied verb preserves the separate alert preference")
Config:HandleGroupCommand("attackSpeed always")
assertEqual(appliedGroup.required, true, "returning to always restores the alert preference")
Config:HandleGroupCommand("attackSpeed applied")
Config:HandleGroupCommand("attackSpeed disable")
assertEqual(appliedGroup.enabled, false, "disable verb stops tracking")
assertEqual(appliedGroup.visibility, "applied", "disable preserves the chosen tier")
Config:HandleGroupCommand("attackSpeed enable")
assertEqual(appliedGroup.enabled, true, "legacy enable verb resumes tracking")
assertEqual(appliedGroup.visibility, "applied", "legacy enable verb does not override a deliberate tier")
Config:HandleGroupCommand("attackSpeed applied")

Config:SetScope("personal")
assertEqual(Config:GetScope(), "personal", "personal scope selected")
assertEqual(ParseBuddyCharDB.settings.displayMode, "FULL_LIST", "first personal selection copies global display mode")
assertEqual(ParseBuddyCharDB.settings.groups.majorArmor.required, true, "first personal selection copies group settings")
assertEqual(ParseBuddyCharDB.settings.showUnavailable, false, "first personal selection copies unavailable-row setting")
assertEqual(ParseBuddyCharDB.settings.broadcast.enabled, false, "first personal selection copies default-off broadcast setting")

Config:SetDisplayMode("PROBLEMS_ONLY")
Config:HandleGroupCommand("majorarmor optional")
Config:HandleGroupCommand("recklessness disable")
Config:HandleUnavailableCommand("show")
Config:HandleBroadcastCommand("on")
Config:HandleBroadcastCommand("channel leader")
Config:HandleBroadcastCommand("delay 7")
assertEqual(ParseBuddyCharDB.settings.displayMode, "PROBLEMS_ONLY", "personal display mode mutates personal settings")
assertEqual(ParseBuddyCharDB.settings.groups.majorArmor.required, false, "personal group requirement persists")
assertEqual(ParseBuddyCharDB.settings.groups.recklessness.enabled, false, "personal group enable state persists")
assertEqual(Config:GetShowUnavailable(), true, "personal unavailable-row setting persists")
assertEqual(ParseBuddyCharDB.settings.broadcast.enabled, true, "personal broadcast enabled setting persists")
assertEqual(ParseBuddyCharDB.settings.broadcast.channel, "leader", "personal broadcast channel persists")
assertEqual(ParseBuddyCharDB.settings.broadcast.delay, 7, "personal broadcast delay persists")

Config:SetScope("global")
assertEqual(Config:GetDisplayMode(), "FULL_LIST", "global display mode preserved after personal changes")
assertEqual(Config:GetGroupSettings("majorArmor").required, true, "global group requirement preserved")
assertEqual(Config:GetGroupSettings("recklessness").enabled, true, "global group enable state preserved")
assertEqual(Config:GetShowUnavailable(), false, "global unavailable-row setting preserved")
assertEqual(ParseBuddyDB.settings.broadcast.enabled, false, "global broadcast setting preserved")

Config:HandleGroupCommand("spellvulnerability disable")
assertEqual(ParseBuddyDB.settings.groups.spellVulnerability.enabled, false, "case-insensitive stable key mutates global settings")
Config:SetScope("personal")
assertEqual(Config:GetGroupSettings("spellVulnerability").enabled, true, "existing personal copy is not overwritten by later global changes")

Config:Initialize()
assertEqual(Config:GetScope(), "personal", "scope selection persists across initialization")
assertEqual(Config:GetDisplayMode(), "PROBLEMS_ONLY", "personal display setting persists across initialization")
assertEqual(Config:GetGroupSettings("majorArmor").required, false, "personal group setting persists across initialization")
assertEqual(Config:GetShowUnavailable(), true, "personal unavailable setting persists across initialization")
assertEqual(ParseBuddyCharDB.settings.broadcast.channel, "leader", "personal broadcast settings persist across initialization")

ParseBuddy.Encounter.active = true
Config:HandleGroupCommand("judgement optional")
assertEqual(ParseBuddy.Encounter.refreshes, 1, "group mutation refreshes active encounter")
Config:SetScope("global")
assertEqual(ParseBuddy.Encounter.refreshes, 2, "scope switch refreshes active encounter")

assertEqual(Config:HandleGroupCommand("notAGroup enable"), false, "unknown group key rejected")
assertEqual(Config:HandleGroupCommand("majorArmor invalid"), false, "invalid group action rejected")
assertEqual(Config:SetScope("invalid"), false, "invalid scope rejected")
assertEqual(Config:HandleUnavailableCommand("invalid"), false, "invalid unavailable action rejected")
assertEqual(Config:HandleBroadcastCommand("channel invalid"), false, "invalid broadcast channel rejected")
assertEqual(Config:HandleBroadcastCommand("delay 61"), false, "invalid broadcast delay rejected")

local messageCount = #ParseBuddy.messages
Config:PrintGroups()
assertEqual(#ParseBuddy.messages, messageCount + #ParseBuddy.DebuffLibrary.groups, "groups command prints every stable group key")

-- Upgrading an existing install: `visibility` postdates these settings, so it is
-- derived from the intent already stored in `required` rather than taken from
-- the new shipped defaults.
ParseBuddyDB = {
    schemaVersion = 4,
    settings = {
        groups = {
            attackSpeed = { enabled = true, required = true },
            recklessness = { enabled = true, required = false },
        },
    },
}
ParseBuddyCharDB = {
    schemaVersion = 3,
    activeScope = "global",
    settings = {
        groups = {
            attackSpeed = { enabled = true, required = true },
        },
    },
}
Config:Initialize()
assertEqual(ParseBuddyDB.settings.groups.attackSpeed.visibility, "always",
    "an upgraded required group keeps reporting absence")
assertEqual(ParseBuddyDB.settings.groups.attackSpeed.required, true,
    "upgrading does not clear a deliberate alert flag")
assertEqual(ParseBuddyDB.settings.groups.recklessness.visibility, "always",
    "an upgraded optional group keeps showing its missing row in Full List")
assertEqual(ParseBuddyDB.settings.groups.recklessness.required, false,
    "upgrading does not change an optional group's alert preference")
assertEqual(ParseBuddyCharDB.settings.groups.attackSpeed.visibility, "always",
    "personal settings are derived independently of the account store")
assertEqual(ParseBuddyDB.settings.groups.majorArmor.visibility, "always",
    "groups absent from the upgraded store still take shipped defaults")

-- A fresh install has no group entries to derive from, so it takes the defaults.
ParseBuddyDB = {}
ParseBuddyCharDB = nil
Config:Initialize()
assertEqual(ParseBuddyDB.settings.groups.attackSpeed.visibility, "applied",
    "a fresh install ships thunder clap as applied-only")
assertEqual(ParseBuddyDB.settings.groups.majorArmor.visibility, "always",
    "a fresh install ships core groups as always-shown")

print("ParseBuddy Config tests passed: " .. testsRun)
