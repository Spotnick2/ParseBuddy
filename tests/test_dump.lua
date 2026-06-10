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
assertContains(lines, "Encounter: active=yes", "active encounter line")
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
}
Encounter.encounteredBosses["Creature-Z"] = Encounter.primaryVisibleBoss
local fallbackLines = Encounter:BuildDumpLines()
assertContains(fallbackLines, "primaryBoss=Fallback Boss visible=no fallback=yes", "fallback boss status")

print("ParseBuddy dump tests passed: " .. testsRun)
