ParseBuddy = {
    DebuffLibrary = {
        spellIdToGroupKey = { [25225] = "majorArmor" },
    },
    Encounter = {
        refreshed = 0,
        learned = {},
        visibleMode = true,
        IsBossGUID = function(self, guid)
            return self.visibleMode and guid == "Boss-GUID" or self.learned[guid] ~= nil
        end,
        HasVisibleBosses = function(self)
            return self.visibleMode
        end,
        LearnBossFromCombatLog = function(self, guid, name)
            if self.visibleMode then
                return false
            end
            self.learned[guid] = name
            return true
        end,
        ShouldRefreshForGUID = function(self, guid)
            return self.visibleMode and guid == "Boss-GUID" or self.learned[guid] ~= nil
        end,
        RefreshDisplay = function(self) self.refreshed = self.refreshed + 1 end,
    },
    State = {
        events = {},
        HandleAuraEvent = function(self, event)
            self.events[#self.events + 1] = event
            return true
        end,
    },
}

CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end

local currentEvent
CombatLogGetCurrentEventInfo = function()
    return unpack(currentEvent)
end

assert(loadfile("Events.lua"))()

local Events = ParseBuddy.Events
local testsRun = 0

local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

currentEvent = { 100, "SWING_DAMAGE", false, "Player", "Player", 0, 0, "Boss-GUID" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 0, "irrelevant subevent exits")

currentEvent = { 100, "SPELL_AURA_APPLIED", false, "Player", "Tank", 0, 0, "Boss-GUID", "Boss", 0, 0, 99999, "Other", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 0, "untracked spell exits")

currentEvent = { 100, "SPELL_AURA_APPLIED", false, "Player", "Tank", 0, 0, "Trash-GUID", "Trash", 0, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 0, "non-boss destination exits")

currentEvent = { 100, "SPELL_AURA_APPLIED_DOSE", false, "Player", "Tank", 0, 0, "Boss-GUID", "Boss", 0, 0, 25225, "Sunder Armor", 1, "DEBUFF", 5 }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 1, "tracked boss aura dispatched")
assertEqual(ParseBuddy.State.events[1].amount, 5, "dose amount dispatched")
assertEqual(ParseBuddy.Encounter.refreshed, 1, "visible boss refreshes display")

ParseBuddy.Encounter.visibleMode = false
currentEvent = { 100, "SPELL_AURA_APPLIED", false, "Player", "Tank", 0, 0, "Fallback-GUID", "Fallback Boss", 0, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 2, "fallback boss aura dispatched")
assertEqual(ParseBuddy.Encounter.learned["Fallback-GUID"], "Fallback Boss", "fallback boss learned from combat log")
assertEqual(ParseBuddy.Encounter.refreshed, 2, "fallback boss refreshes display")

print("ParseBuddy Events tests passed: " .. testsRun)
