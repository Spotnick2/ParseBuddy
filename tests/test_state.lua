ParseBuddy = {}

assert(loadfile("DebuffLibrary.lua"))()
assert(loadfile("State.lua"))()

local Library = ParseBuddy.DebuffLibrary
local State = ParseBuddy.State
local testsRun = 0

local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function evaluate(groupKey, candidates, options)
    return State:EvaluateGroup(Library.groupsByKey[groupKey], candidates, options or { now = 100, warningThreshold = 5 })
end

assertEqual(#Library.groups, 6, "six MVP groups")
assertEqual(Library.spellIdToGroupKey[27228], "spellVulnerability", "CoE lookup")
assertEqual(Library.spellIdToGroupKey[25225], "majorArmor", "Sunder lookup")
assertEqual(Library.spellIdToGroupKey[26866], "majorArmor", "Expose lookup")
assertEqual(Library.spellIdToGroupKey[26993], "faerieFire", "Faerie Fire lookup")
assertEqual(Library.spellIdToGroupKey[27164], "judgement", "Wisdom lookup")
assertEqual(Library.spellIdToGroupKey[25203], "attackPower", "Demo Shout lookup")
assertEqual(Library.spellIdToGroupKey[25264], "attackSpeed", "Thunder Clap lookup")

local result = evaluate("majorArmor", {
    { spellId = 25225, sourceName = "Tank", sourceGUID = "B", active = true, stacks = 3, expiresAt = 120 },
})
assertEqual(result.state, "partial", "Sunder below five stacks")
assertEqual(result.candidate.stacks, 3, "partial stack display")

result = evaluate("majorArmor", {
    { spellId = 25225, sourceName = "Tank", sourceGUID = "B", active = true, stacks = 4, expiresAt = 120 },
    { spellId = 26866, sourceName = "Rogue", sourceGUID = "A", active = true, expiresAt = 110 },
})
assertEqual(result.state, "active", "Expose satisfies Armor")
assertEqual(result.candidate.spellId, 26866, "Expose beats partial Sunder")

result = evaluate("majorArmor", {
    { spellId = 25225, sourceName = "Tank", sourceGUID = "B", active = true, stacks = 5, expiresAt = 103 },
    { spellId = 26866, sourceName = nil, sourceGUID = "A", active = true, expiresAt = 120 },
})
assertEqual(result.state, "active", "healthy unknown beats expiring known")
assertEqual(result.candidate.spellId, 26866, "deterministic health priority")
assertEqual(result.sourceKnown, false, "unknown source retained")

result = evaluate("majorArmor", {
    { spellId = 25225, sourceName = "Tank", sourceGUID = "B", active = true, stacks = 5, expiresAt = 120 },
    { spellId = 26866, sourceName = "Rogue", sourceGUID = "A", active = true, expiresAt = 120 },
})
assertEqual(result.candidate.spellId, 25225, "library priority breaks satisfying tie")

result = evaluate("majorArmor", {
    { spellId = 25225, sourceName = nil, sourceGUID = "A", active = true, stacks = 5, expiresAt = 120 },
    { spellId = 26866, sourceName = "Rogue", sourceGUID = "B", active = true, expiresAt = 120 },
})
assertEqual(result.candidate.spellId, 26866, "known source beats unknown source")

result = evaluate("majorArmor", {
    { spellId = 25225, sourceName = "Tank", sourceGUID = "B", active = true, stacks = 5, expiresAt = 103 },
})
assertEqual(result.state, "expiring", "warning threshold")

result = evaluate("majorArmor", {
    { spellId = 25225, sourceName = "Tank", active = false, stacks = 5, removedAt = 99 },
})
assertEqual(result.state, "missing", "removed candidate is missing")
assertEqual(result.recentCandidate.spellId, 25225, "recent candidate retained")

result = evaluate("judgement", {}, { now = 100, warningThreshold = 5 })
assertEqual(result.state, "missing", "empty group is missing")

result = evaluate("judgement", {
    { spellId = 25225, sourceName = "Tank", active = true, stacks = 5, expiresAt = 120 },
})
assertEqual(result.state, "missing", "candidate from another group is ignored")

result = evaluate("attackPower", {}, { now = 100, warningThreshold = 5, enabled = false })
assertEqual(result.state, "disabled", "disabled group")

result = evaluate("majorArmor", {
    { spellId = 25225, sourceName = "Second", sourceGUID = "B", active = true, stacks = 4, expiresAt = 120 },
    { spellId = 25225, sourceName = "First", sourceGUID = "A", active = true, stacks = 4, expiresAt = 120 },
})
assertEqual(result.candidate.sourceGUID, "A", "source GUID breaks final tie")

State.candidatesByBoss["Boss-To-Forget"] = { majorArmor = {} }
State:ForgetBoss("Boss-To-Forget")
assertEqual(State.candidatesByBoss["Boss-To-Forget"], nil, "forget boss clears candidate state")

State:ResetEncounter()
assertEqual(State:HandleAuraEvent({
    timestamp = 100,
    subevent = "SPELL_AURA_APPLIED",
    sourceGUID = "Player-A",
    sourceName = "Tank",
    destGUID = "Boss-A",
    spellId = 25225,
    spellName = "Sunder Armor",
}), true, "runtime apply accepted")

local live = State:EvaluateBoss("Boss-A", 100, 5, false)
assertEqual(live[2].state, "partial", "initial Sunder is partial")
assertEqual(live[2].candidate.stacks, 1, "initial aura stack defaults to one")

State:HandleAuraEvent({
    timestamp = 101,
    subevent = "SPELL_AURA_APPLIED_DOSE",
    sourceGUID = "Player-A",
    sourceName = "Tank",
    destGUID = "Boss-A",
    spellId = 25225,
    spellName = "Sunder Armor",
    amount = 5,
})
live = State:EvaluateBoss("Boss-A", 101, 5, false)
assertEqual(live[2].state, "active", "five live Sunder stacks satisfy Armor")

State:HandleAuraEvent({
    timestamp = 102,
    subevent = "SPELL_AURA_REMOVED",
    sourceGUID = "Player-A",
    sourceName = "Tank",
    destGUID = "Boss-A",
    spellId = 25225,
    spellName = "Sunder Armor",
})
live = State:EvaluateBoss("Boss-A", 102, 5, false)
assertEqual(live[2].state, "missing", "live removal clears candidate")

live = State:EvaluateBoss("Boss-B", 102, 5, true)
assertEqual(live[1].state, "grace", "missing group is neutral during grace")

print("ParseBuddy State tests passed: " .. testsRun)
