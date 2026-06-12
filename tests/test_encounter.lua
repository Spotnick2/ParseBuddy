ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
    Summary = {
        begins = 0,
        observations = 0,
        finalizes = 0,
        Begin = function(self) self.begins = self.begins + 1 end,
        Observe = function(self) self.observations = self.observations + 1 end,
        Finalize = function(self, _, success)
            self.finalizes = self.finalizes + 1
            return { success = success == 1 }
        end,
        RecordPrimarySwitch = function(self, _, boss, reason)
            self.switches = (self.switches or 0) + 1
            self.lastSwitchGUID = boss and boss.guid or nil
            self.lastSwitchReason = reason
        end,
    },
    Broadcast = {
        begins = 0,
        observations = 0,
        ends = 0,
        Begin = function(self) self.begins = self.begins + 1 end,
        Observe = function(self) self.observations = self.observations + 1 end,
        End = function(self) self.ends = self.ends + 1 end,
        GetDiagnosticLines = function() return { "Broadcast: active=yes enabled=no" } end,
    },
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
        ExpireBoss = function(self)
            self.expirations = (self.expirations or 0) + 1
            local result = self.expireResult
            self.expireResult = false
            return result
        end,
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
        EvaluationToRowData = function(_, evaluation)
            return {
                group = "Test Group",
                effect = evaluation.state,
                source = "",
                status = evaluation.state,
            }
        end,
    },
}

ParseBuddyDB = { pullGracePeriod = 6, warningThreshold = 5 }
GetTime = function() return 100 end
time = function() return 123456 end
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

assert(loadfile("EncounterTargets.lua"))()
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
assertEqual(ParseBuddy.Summary.begins, 1, "encounter starts summary accumulator")
assertEqual(ParseBuddy.Broadcast.begins, 1, "encounter freezes broadcast settings")

local callsBeforeTicker = #ParseBuddy.UI.calls
local broadcastObservationsBeforeTicker = ParseBuddy.Broadcast.observations
ParseBuddy.tickerCallback()
assertEqual(#ParseBuddy.UI.calls, callsBeforeTicker + 1, "display ticker refreshes UI")
assertEqual(ParseBuddy.State.scans, 2, "display ticker does not scan auras")
assertEqual(ParseBuddy.Broadcast.observations, broadcastObservationsBeforeTicker, "ordinary display ticker does not process broadcast transitions")
local observationsBeforeExpiry = ParseBuddy.Summary.observations
ParseBuddy.State.expireResult = true
ParseBuddy.tickerCallback()
assertEqual(ParseBuddy.Summary.observations, observationsBeforeExpiry + 1, "ticker records summary only when expiration changes state")
assertEqual(ParseBuddy.Broadcast.observations, broadcastObservationsBeforeTicker + 1, "expiration boundary updates pending broadcast state without sending")

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

local _, _, snapshot, summary = Encounter:End(100, "Test Encounter", 3, 10, 1)
assertEqual(Encounter.active, false, "encounter ended")
assertEqual(next(Encounter.encounteredBosses), nil, "encountered bosses reset at end")
assertEqual(ParseBuddy.UI.calls[#ParseBuddy.UI.calls][1], "hide", "encounter UI hidden")
assertEqual(ParseBuddy.tickerCancelled, true, "display ticker cancelled at encounter end")
assertEqual(snapshot.encounterName, "Test Encounter", "encounter end captures snapshot")
assertEqual(snapshot.success, true, "snapshot records encounter success")
assertEqual(snapshot.capturedAt, 123456, "snapshot records wall-clock capture time")
assertEqual(snapshot.schemaVersion, 2, "snapshot schema includes live and raw diagnostics")
assertEqual(ParseBuddy.lastEncounterSnapshot, snapshot, "snapshot retained in memory")
assertEqual(ParseBuddyDB.lastEncounterSnapshot, snapshot, "snapshot retained in saved variables")
assertEqual(summary.success, true, "encounter end returns finalized summary")
assertEqual(ParseBuddy.Summary.finalizes, 1, "encounter end finalizes summary")
assertEqual(ParseBuddy.Broadcast.ends > 0, true, "encounter cleanup clears broadcast state")

Encounter:RefreshVisibleBosses(provider)
assertEqual(#Encounter.visibleOrder, 0, "inactive refresh ignored")

local emptyProvider = {
    Exists = function() return false end,
    GUID = function() return nil end,
    Name = function() return nil end,
}

Encounter:Start(101, "Magtheridon", 4, 25, emptyProvider)
assertEqual(ParseBuddy.lastEncounterSnapshot, snapshot, "new encounter retains previous completed snapshot")
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

Encounter:Start(655, "Opera Hall", 3, 10, emptyProvider)
local julianneGUID = "Creature-0-6066-532-101283-17534-00002B6322"
local romuloGUID = "Creature-0-6066-532-101283-17533-00002B634D"
local addGUID = "Creature-0-6066-532-101283-17229-0000ADD"
assertEqual(Encounter:LearnBossFromCombatLog(julianneGUID, "Julianne"), true, "Opera registry accepts Julianne")
assertEqual(Encounter.primaryVisibleBoss.guid, julianneGUID, "first registered target becomes primary")
assertEqual(Encounter.primarySelectionReason, "recent-registered", "registered activity selection reason")
ParseBuddy.State.candidatesByBoss[julianneGUID] = { spellVulnerability = { [27228] = { spellId = 27228 } } }
assertEqual(Encounter:LearnBossFromCombatLog(romuloGUID, "Romulo"), true, "Opera registry accepts Romulo")
assertEqual(Encounter.primaryVisibleBoss.guid, romuloGUID, "recent registered target becomes primary")
assertEqual(ParseBuddy.State.candidatesByBoss[julianneGUID] ~= nil, true, "switching registered targets retains prior candidate state")
ParseBuddy.State.candidatesByBoss[romuloGUID] = { majorArmor = { [25225] = { spellId = 25225 } } }
assertEqual(Encounter:LearnBossFromCombatLog(addGUID, "Fiendish Imp"), false, "Opera registry rejects arbitrary add")
assertEqual(Encounter.encounteredBosses[addGUID], nil, "rejected add is not retained")
assertEqual(Encounter:ReclaimPrimaryBoss(julianneGUID), true, "relevant registered activity switches hidden primary")
assertEqual(Encounter.primaryVisibleBoss.guid, julianneGUID, "registered reclaim selects active target")
assertEqual(ParseBuddy.State.candidatesByBoss[romuloGUID] ~= nil, true, "registered reclaim retains other boss state")

units.boss1 = { guid = julianneGUID, name = "Julianne" }
units.boss2 = { guid = romuloGUID, name = "Romulo" }
Encounter:RefreshVisibleBosses(provider)
assertEqual(Encounter.primaryVisibleBoss.guid, julianneGUID, "visible boss1 has primary precedence")
assertEqual(Encounter.primarySelectionReason, "visible-boss1", "visible boss1 reason recorded")
assertEqual(Encounter:ReclaimPrimaryBoss(romuloGUID), false, "registered activity cannot override visible boss1")
assertEqual(Encounter.primaryVisibleBoss.guid, julianneGUID, "visible boss1 remains primary")

units.boss1 = nil
Encounter:RefreshVisibleBosses(provider)
assertEqual(Encounter.primaryVisibleBoss.guid, romuloGUID, "first visible registered boss selected without boss1")
assertEqual(Encounter.primarySelectionReason, "visible-registered", "visible registered reason recorded")

units.boss2 = { guid = "Creature-0-6066-532-101283-99999-UNREGISTERED", name = "Visible Add" }
Encounter:RefreshVisibleBosses(provider)
assertEqual(Encounter:ReclaimPrimaryBoss(julianneGUID), true, "visible unregistered non-boss1 does not block registered activity")
assertEqual(Encounter.primaryVisibleBoss.guid, julianneGUID, "recent registered target outranks visible unregistered non-boss1")

local messagesBeforeTargets = #ParseBuddy.messages
assertEqual(Encounter:PrintTargets(), true, "target diagnostics available during encounter")
assertEqual(#ParseBuddy.messages > messagesBeforeTargets, true, "target diagnostics print registry and accepted GUIDs")
local combinedTargets = table.concat(ParseBuddy.messages, "\n")
assertEqual(combinedTargets:find("npcId=17533", 1, true) ~= nil, true, "target diagnostics list Romulo NPC ID")
assertEqual(combinedTargets:find("npcId=17534", 1, true) ~= nil, true, "target diagnostics list Julianne NPC ID")
assertEqual(combinedTargets:find("reason=recent%-registered") ~= nil, true, "target diagnostics list primary reason")

Encounter:End(655, "Opera Hall", 3, 10, 1)
assertEqual(Encounter:PrintTargets(), false, "target diagnostics explain inactive encounter")

print("ParseBuddy Encounter tests passed: " .. testsRun)
