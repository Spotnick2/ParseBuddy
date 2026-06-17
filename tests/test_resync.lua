ParseBuddy = {}

assert(loadfile("DebuffLibrary.lua"))()
assert(loadfile("State.lua"))()

local State = ParseBuddy.State
local testsRun = 0

local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local auras = {
    {
        name = "Sunder Armor",
        stacks = 5,
        duration = 30,
        expirationTime = 125,
        sourceUnit = "raid1",
        spellId = 25225,
    },
    {
        name = "Untracked Aura",
        stacks = 1,
        expirationTime = 140,
        spellId = 99999,
    },
}

local provider = {
    GetDebuff = function(_, index) return auras[index] end,
    SourceGUID = function(unit) return unit == "raid1" and "Player-Tank" or nil end,
    SourceName = function(unit) return unit == "raid1" and "Tank" or nil end,
}

local scanned, tracked, inspected = State:ResyncBossUnit("boss1", "Boss-A", provider, 100)
assertEqual(scanned, true, "visible boss scan completes")
assertEqual(tracked, 1, "scan counts tracked auras only")
assertEqual(inspected, 2, "scan reports inspected aura count")
local candidate = State.candidatesByBoss["Boss-A"].majorArmor[25225]
assertEqual(candidate.stacks, 5, "scan confirms stack count")
assertEqual(candidate.expiresAt, 125, "scan uses client expiration")
assertEqual(candidate.durationSource, "scan", "scan expiration source recorded")
assertEqual(candidate.sourceName, "Tank", "late-load scan recovers source when available")

local listedAuras, listedCount = State:GetUnitDebuffs("boss1", provider)
assertEqual(listedCount, 2, "debug aura read inspects all harmful auras")
assertEqual(#listedAuras, 2, "debug aura read returns tracked and untracked auras")
assertEqual(listedAuras[1].sourceName, "Tank", "debug aura read resolves source name")
assertEqual(listedAuras[2].spellId, 99999, "debug aura read preserves untracked spell ID")

candidate.sourceName = "CLEU Tank"
candidate.sourceGUID = "Player-CLEU"
auras[1].sourceUnit = "raid2"
State:ResyncBossUnit("boss1", "Boss-A", provider, 101)
assertEqual(candidate.sourceName, "CLEU Tank", "scan does not overwrite CLEU source attribution")
assertEqual(candidate.sourceGUID, "Player-CLEU", "scan preserves CLEU source GUID")

auras = {}
State:ResyncBossUnit("boss1", "Boss-A", provider, 110)
assertEqual(candidate.active, false, "complete scan marks absent tracked aura inactive")
assertEqual(candidate.removedAt, 110, "scan records inferred removal time")
assertEqual(candidate.lastScannedAt, 110, "scan timestamp retained")

auras = {
    {
        name = "Expose Armor",
        stacks = 1,
        duration = 24,
        expirationTime = 134,
        spellId = 26866,
    },
}
State:ResyncBossUnit("boss1", "Boss-A", provider, 110)
local expose = State.candidatesByBoss["Boss-A"].majorArmor[26866]
assertEqual(expose.expiresAt, 134, "variable-duration aura uses exact client expiration")

State:HandleAuraEvent({
    timestamp = 200,
    subevent = "SPELL_AURA_APPLIED",
    sourceName = "Druid",
    sourceGUID = "Player-Druid",
    destGUID = "Boss-Race",
    spellId = 26993,
    spellName = "Faerie Fire",
})
auras = {}
State:ResyncBossUnit("boss1", "Boss-Race", provider, 200, 0.2)
local recent = State.candidatesByBoss["Boss-Race"].faerieFire[26993]
assertEqual(recent.active, true, "same-frame CLEU candidate survives a lagging aura scan")
State:ResyncBossUnit("boss1", "Boss-Race", provider, 200.3, 0.2)
assertEqual(recent.active, false, "later complete scan can clear absent CLEU candidate")

State:HandleAuraEvent({
    observedAt = 300,
    subevent = "SPELL_AURA_APPLIED",
    sourceName = "Tank",
    destGUID = "Boss-Removal",
    spellId = 25225,
    spellName = "Sunder Armor",
})
State:HandleAuraEvent({
    observedAt = 301,
    subevent = "SPELL_AURA_REMOVED",
    destGUID = "Boss-Removal",
    spellId = 25225,
})
auras = {
    {
        name = "Sunder Armor",
        stacks = 5,
        expirationTime = 330,
        spellId = 25225,
    },
}
State:ResyncBossUnit("boss1", "Boss-Removal", provider, 301, 0.2, 25225)
local removed = State.candidatesByBoss["Boss-Removal"].majorArmor[25225]
assertEqual(removed.active, false, "stale scan cannot reactivate a just-removed aura")
assertEqual(removed.removedAt, 301, "CLEU removal timestamp remains authoritative")

print("ParseBuddy resync tests passed: " .. testsRun)
