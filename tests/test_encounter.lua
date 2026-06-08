ParseBuddy = {
    State = {
        resets = 0,
        ResetEncounter = function(self) self.resets = self.resets + 1 end,
        EvaluateBoss = function() return { { state = "missing" } } end,
    },
    UI = {
        calls = {},
        ShowEncounter = function(self, encounter, primaryBoss)
            self.calls[#self.calls + 1] = { "show", encounter, primaryBoss }
        end,
        UpdateEncounter = function(self, encounter, primaryBoss, evaluations)
            self.calls[#self.calls + 1] = { "update", encounter, primaryBoss }
        end,
        HideEncounter = function(self)
            self.calls[#self.calls + 1] = { "hide" }
        end,
    },
}

ParseBuddyDB = { pullGracePeriod = 6, warningThreshold = 5 }
GetTime = function() return 100 end
C_Timer = { After = function(_, callback) ParseBuddy.pendingGrace = callback end }

UnitExists = function() return false end
UnitGUID = function() return nil end
UnitName = function() return nil end

assert(loadfile("Encounter.lua"))()

local Encounter = ParseBuddy.Encounter
local testsRun = 0

local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local units = {
    boss1 = { guid = "Creature-B", name = "Primary Boss" },
    boss2 = { guid = "Creature-A", name = "Secondary Boss" },
}

local provider = {
    Exists = function(unitToken) return units[unitToken] ~= nil end,
    GUID = function(unitToken) return units[unitToken] and units[unitToken].guid end,
    Name = function(unitToken) return units[unitToken] and units[unitToken].name end,
}

Encounter:Start(100, "Test Encounter", 3, 10, provider)
assertEqual(Encounter.active, true, "encounter active")
assertEqual(Encounter.encounter.id, 100, "encounter id")
assertEqual(#Encounter.visibleOrder, 2, "two visible bosses")
assertEqual(Encounter.primaryVisibleBoss.guid, "Creature-B", "boss1 is primary")
assertEqual(Encounter:IsBossGUID("Creature-A"), true, "secondary boss encountered")
assertEqual(Encounter:IsBossVisible("Creature-A"), true, "secondary boss visible")
assertEqual(ParseBuddy.UI.calls[1][1], "show", "encounter UI shown")
assertEqual(ParseBuddy.UI.calls[#ParseBuddy.UI.calls][1], "update", "initial boss scan updates UI")
assertEqual(type(ParseBuddy.pendingGrace), "function", "grace callback scheduled")

units.boss1 = nil
Encounter:RefreshVisibleBosses(provider)
assertEqual(#Encounter.visibleOrder, 1, "one visible boss after phase change")
assertEqual(Encounter.primaryVisibleBoss.guid, "Creature-A", "boss2 becomes primary")
assertEqual(Encounter:IsBossGUID("Creature-B"), true, "hidden boss retained internally")
assertEqual(Encounter:IsBossVisible("Creature-B"), false, "hidden boss removed from visible map")
assertEqual(Encounter.encounteredBosses["Creature-B"].visible, false, "hidden boss visibility flag")
assertEqual(Encounter.encounteredBosses["Creature-B"].lastUnitToken, "boss1", "last unit token retained")

units.boss2 = nil
Encounter:RefreshVisibleBosses(provider)
assertEqual(#Encounter.visibleOrder, 0, "no visible bosses")
assertEqual(Encounter.primaryVisibleBoss, nil, "no primary boss")
assertEqual(Encounter:IsBossGUID("Creature-A"), true, "all hidden bosses retained")

ParseBuddy.pendingGrace()
assertEqual(ParseBuddy.UI.calls[#ParseBuddy.UI.calls][1], "update", "grace callback refreshes display")

Encounter:End(100, "Test Encounter", 3, 10, 1)
assertEqual(Encounter.active, false, "encounter ended")
assertEqual(next(Encounter.encounteredBosses), nil, "encountered bosses reset at end")
assertEqual(ParseBuddy.UI.calls[#ParseBuddy.UI.calls][1], "hide", "encounter UI hidden")

Encounter:RefreshVisibleBosses(provider)
assertEqual(#Encounter.visibleOrder, 0, "inactive refresh ignored")

print("ParseBuddy Encounter tests passed: " .. testsRun)
