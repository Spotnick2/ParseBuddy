ParseBuddy = {
    State = {
        resets = 0,
        candidatesByBoss = {},
        ResetEncounter = function(self) self.resets = self.resets + 1 end,
        ForgetBoss = function(self, bossGUID) self.candidatesByBoss[bossGUID] = nil end,
        ResyncBossUnit = function(self, unitToken, bossGUID)
            self.scans = (self.scans or 0) + 1
            self.lastScanUnit = unitToken
            self.lastScanGUID = bossGUID
            return true, 2
        end,
        ExpireBoss = function(self) self.expirations = (self.expirations or 0) + 1 end,
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
C_Timer = { After = function(delay, callback)
    ParseBuddy.pendingGraceDelay = delay
    ParseBuddy.pendingGrace = callback
end,
NewTicker = function(interval, callback)
    ParseBuddy.tickerInterval = interval
    ParseBuddy.tickerCallback = callback
    return {
        Cancel = function() ParseBuddy.tickerCancelled = true end,
    }
end }

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
assertEqual(ParseBuddy.pendingGraceDelay, 6.1, "grace refresh includes scheduling padding")
assertEqual(ParseBuddy.tickerInterval, 0.2, "display ticker interval")
assertEqual(ParseBuddy.State.scans, 2, "visible bosses scanned when unit tokens appear")

local callsBeforeTicker = #ParseBuddy.UI.calls
ParseBuddy.tickerCallback()
assertEqual(#ParseBuddy.UI.calls, callsBeforeTicker + 1, "display ticker refreshes UI")
assertEqual(ParseBuddy.State.scans, 2, "display ticker does not scan auras")

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
assertEqual(Encounter.primaryVisibleBoss, nil, "vanished visible boss is hidden")
assertEqual(Encounter:IsBossGUID("Creature-A"), true, "all hidden bosses retained")
assertEqual(Encounter:LearnBossFromCombatLog("Creature-Add", "Restless Skeleton"), false, "add cannot replace a previously visible boss")
assertEqual(Encounter.primaryVisibleBoss, nil, "blocked add does not become primary")
assertEqual(Encounter:ReclaimPrimaryBoss("Creature-A"), true, "known hidden boss can reclaim primary")
assertEqual(Encounter.primaryVisibleBoss.guid, "Creature-A", "reclaimed boss becomes primary")

ParseBuddy.pendingGrace()
assertEqual(ParseBuddy.UI.calls[#ParseBuddy.UI.calls][1], "update", "grace callback refreshes display")

Encounter:End(100, "Test Encounter", 3, 10, 1)
assertEqual(Encounter.active, false, "encounter ended")
assertEqual(next(Encounter.encounteredBosses), nil, "encountered bosses reset at end")
assertEqual(ParseBuddy.UI.calls[#ParseBuddy.UI.calls][1], "hide", "encounter UI hidden")
assertEqual(ParseBuddy.tickerCancelled, true, "display ticker cancelled at encounter end")

Encounter:RefreshVisibleBosses(provider)
assertEqual(#Encounter.visibleOrder, 0, "inactive refresh ignored")

local emptyProvider = {
    Exists = function() return false end,
    GUID = function() return nil end,
    Name = function() return nil end,
}

Encounter:Start(101, "Magtheridon", 4, 25, emptyProvider)
assertEqual(Encounter.primaryVisibleBoss, nil, "no visible boss at fallback start")
assertEqual(Encounter:LearnBossFromCombatLog("Creature-Z", "Hellfire Channeler"), true, "channeler becomes provisional fallback")
assertEqual(Encounter.primaryVisibleBoss.guid, "Creature-Z", "provisional fallback becomes primary")
assertEqual(Encounter.encounteredBosses["Creature-Z"].discoveredFromCombatLog, true, "fallback flag recorded")
assertEqual(Encounter:LearnBossFromCombatLog("Creature-Y", "Hellfire Channeler"), false, "second channeler is rejected")
assertEqual(Encounter.primaryVisibleBoss.guid, "Creature-Z", "fallback primary remains stable")

ParseBuddy.State.candidatesByBoss = { ["Creature-Z"] = { majorArmor = {} } }
assertEqual(Encounter:LearnBossFromCombatLog("Creature-M", "Magtheridon"), true, "Magtheridon replaces provisional channeler")
assertEqual(Encounter.primaryVisibleBoss.guid, "Creature-M", "encounter-name target becomes primary")
assertEqual(Encounter.primaryVisibleBoss.matchesEncounterName, true, "encounter-name match recorded")
assertEqual(Encounter.encounteredBosses["Creature-Z"], nil, "provisional fallback removed after promotion")
assertEqual(ParseBuddy.State.candidatesByBoss["Creature-Z"], nil, "provisional fallback state removed after promotion")
assertEqual(Encounter:LearnBossFromCombatLog("Creature-Y", "Hellfire Channeler"), false, "channeler cannot replace Magtheridon")

Encounter:RefreshVisibleBosses(emptyProvider)
assertEqual(Encounter.primaryVisibleBoss.guid, "Creature-M", "combat-log fallback survives an empty boss scan")

Encounter:End(101, "Magtheridon", 4, 25, 1)
Encounter:RefreshVisibleBosses(provider)
assertEqual(#Encounter.visibleOrder, 0, "inactive refresh ignored")

print("ParseBuddy Encounter tests passed: " .. testsRun)
