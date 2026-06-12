ParseBuddy = {
    UI = {
        mode = "encounter",
        EvaluationToRowData = function(_, evaluation)
            if evaluation.state == "missing" then
                return {
                    group = evaluation.group.label,
                    effect = evaluation.group.missingText .. " missing",
                    source = "",
                    status = "MISSING",
                }
            end
            return {
                group = evaluation.group.label,
                effect = evaluation.spell.displayName,
                source = evaluation.candidate.sourceName,
                status = "04:52",
            }
        end,
        frame = {
            IsShown = function()
                return true
            end,
        },
    },
    Broadcast = {
        GetDiagnosticLines = function()
            return { "Broadcast: active=yes enabled=yes scope=global channel=raid delay=3.0 lastSentAt=none" }
        end,
    },
    State = {
        candidatesByBoss = {
            ["Creature-B"] = {
                spellVulnerability = {
                    [27228] = {
                        spellId = 27228,
                        spellName = "Curse of Elements",
                        sourceName = "Drakuzo",
                        stacks = 1,
                        active = true,
                        expiresAt = 392,
                        lastSeenAt = 100,
                    },
                },
            },
        },
        EvaluateBoss = function()
            return {
                {
                    group = { label = "Spell Vulnerability", missingText = "CoE / CoS" },
                    state = "active",
                    candidate = { sourceName = "Drakuzo", stacks = 1 },
                    spell = { displayName = "CoE" },
                    remaining = 292,
                },
                {
                    group = { label = "Judgement", missingText = "Wisdom / Light" },
                    state = "missing",
                },
            }
        end,
    },
}

ParseBuddyDB = { warningThreshold = 5, pullGracePeriod = 6 }
GetTime = function()
    return 100
end
time = function()
    return 123456
end
local delayedCallback
C_Timer = {
    After = function(_, callback)
        delayedCallback = callback
    end,
}

assert(loadfile("Encounter.lua"))()

local Encounter = ParseBuddy.Encounter
local testsRun = 0

local function assertContains(lines, needle, message)
    testsRun = testsRun + 1
    local index
    for index = 1, #lines do
        if lines[index]:find(needle, 1, true) then
            return
        end
    end
    error(message .. ": missing " .. needle, 2)
end

Encounter.active = true
Encounter.encounter = {
    id = 100,
    name = "Test Encounter",
    difficultyId = 3,
    groupSize = 10,
    startedAt = 100,
    metrics = {
        relevantCLEU = 4,
        displayRefreshes = 12,
        tickerTicks = 8,
        scans = 3,
        scansByReason = { cleu = 2, debugscan = 1 },
        inspectedAuras = 18,
        trackedAurasSeen = 5,
    },
}
Encounter.visibleOrder = {
    { guid = "Creature-B", name = "Primary Boss", unitToken = "boss1", visible = true, lastUnitToken = "boss1", firstSeenIndex = 1 },
    { guid = "Creature-A", name = "Secondary Boss", unitToken = "boss2", visible = true, lastUnitToken = "boss2", firstSeenIndex = 2 },
}
Encounter.visibleBosses = {
    ["Creature-B"] = Encounter.visibleOrder[1],
    ["Creature-A"] = Encounter.visibleOrder[2],
}
Encounter.primaryVisibleBoss = Encounter.visibleOrder[1]
Encounter.encounteredBosses = {
    ["Creature-B"] = Encounter.visibleOrder[1],
    ["Creature-A"] = Encounter.visibleOrder[2],
}

local lines = Encounter:BuildDumpLines()
assertContains(lines, "Dump source: LIVE", "live dump source label")
assertContains(lines, "Encounter: active=yes", "active encounter line")
assertContains(lines, "Metrics: cleu=4 refreshes=12 ticker=8 scans=3", "diagnostic metrics line")
assertContains(lines, "Broadcast: active=yes enabled=yes", "broadcast diagnostics included")
assertContains(lines, "boss1: guid=Creature-B", "visible boss mapping")
assertContains(lines, "Tracked candidates:", "tracked candidates heading")
assertContains(lines, "spellId=27228", "candidate summary")
assertContains(lines, "Visible evaluations:", "visible evaluations heading")
assertContains(lines, "Judgement: Wisdom / Light missing", "missing evaluation line")

Encounter.primaryVisibleBoss = nil
Encounter.visibleOrder = {}
local hiddenLines = Encounter:BuildDumpLines()
assertContains(hiddenLines, "no boss target is currently selected", "hidden boss reason")

Encounter.primaryVisibleBoss = {
    guid = "Creature-Z",
    name = "Fallback Boss",
    visible = false,
    discoveredFromCombatLog = true,
    matchesEncounterName = true,
}
Encounter.encounteredBosses["Creature-Z"] = Encounter.primaryVisibleBoss
local fallbackLines = Encounter:BuildDumpLines()
assertContains(fallbackLines, "primaryBoss=Fallback Boss visible=no fallback=yes encounterMatch=yes", "fallback boss status")

local completedLines = Encounter:BuildDumpLines({ source = "COMPLETED SNAPSHOT", reportActive = false })
assertContains(completedLines, "Dump source: COMPLETED SNAPSHOT", "completed dump source label")
assertContains(completedLines, "Encounter: active=no", "completed snapshot reports inactive encounter")

Encounter:RecordMeaningfulLiveState(100)
assertContains(Encounter.encounter.lastMeaningfulLive.lines, "Spell Vulnerability: CoE", "meaningful live evaluation retained")
ParseBuddy.State.EvaluateBoss = function()
    return {
        { group = { label = "Spell Vulnerability", missingText = "CoE / CoS" }, state = "missing" },
    }
end
assert(Encounter:RecordMeaningfulLiveState(101) == false, "all-missing cleanup is not meaningful")
assertContains(Encounter.encounter.lastMeaningfulLive.lines, "Spell Vulnerability: CoE", "terminal cleanup preserves prior live evaluation")

ParseBuddy.State.EvaluateBoss = function()
    return {
        {
            group = { label = "Faerie Fire", missingText = "Faerie Fire" },
            state = "active",
            candidate = { sourceName = "Druid" },
            spell = { displayName = "Faerie Fire" },
        },
    }
end
Encounter:PrepareForAuraRemoval(102)
delayedCallback()
assertContains(Encounter.encounter.lastMeaningfulLive.lines, "Faerie Fire: Faerie Fire", "ordinary removal batch settles to current live state")

Encounter:PrepareForAuraRemoval(103)
ParseBuddy.State.EvaluateBoss = function()
    return {
        {
            group = { label = "Judgement", missingText = "Wisdom / Light" },
            state = "active",
            candidate = { sourceName = "Paladin" },
            spell = { displayName = "Wisdom" },
        },
    }
end
Encounter:PrepareForAuraRemoval(103.1)
assertContains(Encounter.encounter.lastMeaningfulLive.lines, "Faerie Fire: Faerie Fire", "same cleanup batch does not replace first-removal baseline")
ParseBuddy.State.EvaluateBoss = function()
    return {
        { group = { label = "Judgement", missingText = "Wisdom / Light" }, state = "missing" },
    }
end
local snapshot = Encounter:CaptureSnapshot(0)
assertContains(snapshot.lines, "Dump source: COMPLETED SNAPSHOT", "snapshot labels completed source")
assertContains(snapshot.lines, "Encounter: active=no", "snapshot reports completed encounter inactive")
assertContains(snapshot.lines, "Final raw candidate state:", "snapshot keeps final raw candidates")
assertContains(snapshot.lines, "Final evaluations:", "snapshot keeps final evaluations")
assertContains(snapshot.lines, "Last meaningful live evaluations:", "snapshot includes retained live section")
assertContains(snapshot.lines, "Faerie Fire: Faerie Fire", "terminal cleanup snapshot uses pre-removal live state")
assert(snapshot.success == false, "wipe snapshot records failure")
assert(ParseBuddyDB.lastEncounterSnapshot == snapshot, "completed diagnostic snapshot persists")

print("ParseBuddy dump tests passed: " .. testsRun)
