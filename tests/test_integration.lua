ParseBuddy = {}
ParseBuddyDB = { pullGracePeriod = 6, warningThreshold = 5 }

local now = 100
GetTime = function() return now end
C_Timer = { After = function() end }
UnitExists = function() return false end
UnitGUID = function() return nil end
UnitName = function() return nil end

COMBATLOG_OBJECT_TYPE_NPC = 0x800
COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40
bit = {
    band = function(value, mask)
        return value % (mask * 2) >= mask and mask or 0
    end,
}
local HOSTILE_NPC_FLAGS = 0x848

ParseBuddy.UI = {
    updates = {},
    ShowEncounter = function() end,
    HideEncounter = function() end,
    UpdateEncounter = function(self, encounter, boss, evaluations)
        self.updates[#self.updates + 1] = {
            encounter = encounter,
            boss = boss,
            evaluations = evaluations,
        }
    end,
}

assert(loadfile("DebuffLibrary.lua"))()
assert(loadfile("State.lua"))()
assert(loadfile("Encounter.lua"))()

local currentEvent
CombatLogGetCurrentEventInfo = function()
    return unpack(currentEvent)
end

assert(loadfile("Events.lua"))()

local testsRun = 0
local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local emptyProvider = {
    Exists = function() return false end,
    GUID = function() return nil end,
    Name = function() return nil end,
}

local function dispatchAura(subevent, destGUID, destName, spellId, spellName, amount)
    currentEvent = {
        now,
        subevent,
        false,
        "Player-Warlock",
        "Warlock",
        0,
        0,
        destGUID,
        destName,
        HOSTILE_NPC_FLAGS,
        0,
        spellId,
        spellName,
        1,
        "DEBUFF",
        amount,
    }
    ParseBuddy.Events:HandleCombatLogEvent()
end

ParseBuddy.Encounter:Start(17257, "Magtheridon", 4, 25, emptyProvider)
dispatchAura("SPELL_AURA_APPLIED", "Creature-Channeler", "Hellfire Channeler", 27228, "Curse of the Elements")
assertEqual(ParseBuddy.Encounter.primaryVisibleBoss.guid, "Creature-Channeler", "channeler seeds provisional fallback")

now = 101
dispatchAura("SPELL_AURA_APPLIED", "Creature-Magtheridon", "Magtheridon", 27228, "Curse of the Elements")
assertEqual(ParseBuddy.Encounter.primaryVisibleBoss.guid, "Creature-Magtheridon", "encounter-name boss replaces provisional fallback")
assertEqual(ParseBuddy.State.candidatesByBoss["Creature-Channeler"], nil, "provisional state is forgotten on promotion")
local magEvaluation = ParseBuddy.State:EvaluateBoss("Creature-Magtheridon", now, 5, false)
assertEqual(magEvaluation[1].state, "active", "promotion event is stored before display evaluation")
assertEqual(magEvaluation[1].candidate.sourceName, "Warlock", "promotion keeps source attribution")

ParseBuddy.Encounter:End(17257, "Magtheridon", 4, 25, 1)

local units = {
    boss1 = { guid = "Creature-Real", name = "Phase Boss" },
}
local provider = {
    Exists = function(unit) return units[unit] ~= nil end,
    GUID = function(unit) return units[unit] and units[unit].guid end,
    Name = function(unit) return units[unit] and units[unit].name end,
}

ParseBuddy.Encounter:Start(200, "Phase Boss", 4, 25, provider)
units.boss1 = nil
ParseBuddy.Encounter:RefreshVisibleBosses(provider)
dispatchAura("SPELL_AURA_APPLIED", "Creature-Add", "Restless Skeleton", 25225, "Sunder Armor")
assertEqual(ParseBuddy.Encounter.primaryVisibleBoss, nil, "unknown add cannot hijack hidden known boss")
assertEqual(ParseBuddy.State.candidatesByBoss["Creature-Add"], nil, "blocked add event is not tracked")

now = 102
dispatchAura("SPELL_AURA_APPLIED", "Creature-Real", "Phase Boss", 25225, "Sunder Armor")
assertEqual(ParseBuddy.Encounter.primaryVisibleBoss.guid, "Creature-Real", "known hidden boss reclaims display from CLEU activity")
assertEqual(ParseBuddy.State.candidatesByBoss["Creature-Real"].majorArmor[25225].stacks, 1, "reclaiming aura event is stored")

print("ParseBuddy integration tests passed: " .. testsRun)
