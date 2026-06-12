ParseBuddy = {
    DebuffLibrary = {
        spellIdToGroupKey = { [25225] = "majorArmor" },
    },
    Encounter = {
        refreshed = 0,
        learned = {},
        reclaimed = {},
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
        ReclaimPrimaryBoss = function(self, guid)
            self.reclaimed[guid] = (self.reclaimed[guid] or 0) + 1
            return true
        end,
        ResyncBossGUID = function(self, guid, reason, _, ignoredSpellId)
            self.scanned = (self.scanned or 0) + 1
            self.lastScanGUID = guid
            self.lastScanReason = reason
            self.lastIgnoredSpellId = ignoredSpellId
            return self.visibleMode or self.learned[guid] ~= nil
        end,
        RecordRelevantCLEU = function(self)
            self.relevant = (self.relevant or 0) + 1
        end,
        RecordMeaningfulLiveState = function(self)
            self.meaningfulCaptures = (self.meaningfulCaptures or 0) + 1
        end,
        PrepareForAuraRemoval = function(self)
            self.removalPreparations = (self.removalPreparations or 0) + 1
        end,
        CancelPendingRemovalCapture = function(self)
            self.removalCancellations = (self.removalCancellations or 0) + 1
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

COMBATLOG_OBJECT_TYPE_NPC = 0x800
COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40
COMBATLOG_OBJECT_REACTION_FRIENDLY = 0x10
bit = {
    band = function(value, mask)
        return value % (mask * 2) >= mask and mask or 0
    end,
}

local HOSTILE_NPC_FLAGS = 0x848
local NEUTRAL_NPC_FLAGS = 0x828
local FRIENDLY_NPC_FLAGS = 0x818
local HOSTILE_PLAYER_FLAGS = 0x448

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
assertEqual(ParseBuddy.Encounter.lastScanReason, "cleu", "relevant CLEU event triggers opportunistic scan")
assertEqual(ParseBuddy.Encounter.relevant, 1, "tracked boss event increments diagnostics")
assertEqual(ParseBuddy.Encounter.meaningfulCaptures, 1, "tracked state change records live diagnostics")

ParseBuddy.Encounter.visibleMode = false
currentEvent = { 100, "SPELL_AURA_REMOVED", false, "Player", "Tank", 0, 0, "Removed-GUID", "Removed Target", HOSTILE_NPC_FLAGS, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 1, "removal event cannot discover fallback boss")

currentEvent = { 100, "SPELL_AURA_APPLIED", false, "Player", "Tank", 0, 0, "Player-GUID", "Mind Controlled Player", HOSTILE_PLAYER_FLAGS, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 1, "hostile player cannot become fallback boss")

currentEvent = { 100, "SPELL_AURA_APPLIED", false, "Player", "Tank", 0, 0, "Friendly-GUID", "Friendly NPC", FRIENDLY_NPC_FLAGS, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 1, "friendly NPC cannot become fallback boss")

currentEvent = { 100, "SPELL_AURA_APPLIED", false, "Player", "Tank", 0, 0, "Midnight-GUID", "Midnight", NEUTRAL_NPC_FLAGS, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 2, "neutral encounter NPC can become fallback boss")
assertEqual(ParseBuddy.Encounter.learned["Midnight-GUID"], "Midnight", "neutral fallback boss learned from combat log")

ParseBuddy.Encounter.learned["Midnight-GUID"] = nil

currentEvent = { 100, "SPELL_AURA_APPLIED", false, "Player", "Tank", 0, 0, "Fallback-GUID", "Fallback Boss", HOSTILE_NPC_FLAGS, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(#ParseBuddy.State.events, 3, "fallback boss aura dispatched")
assertEqual(ParseBuddy.Encounter.learned["Fallback-GUID"], "Fallback Boss", "fallback boss learned from combat log")
assertEqual(ParseBuddy.Encounter.refreshed, 3, "fallback boss refreshes display")

currentEvent = { 101, "SPELL_AURA_REFRESH", false, "Player", "Tank", 0, 0, "Fallback-GUID", "Fallback Boss", HOSTILE_NPC_FLAGS, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(ParseBuddy.Encounter.reclaimed["Fallback-GUID"], 1, "known hidden boss receives reclaim attempt")

currentEvent = { 102, "SPELL_AURA_REMOVED", false, "Player", "Tank", 0, 0, "Fallback-GUID", "Fallback Boss", HOSTILE_NPC_FLAGS, 0, 25225, "Sunder Armor", 1, "DEBUFF" }
Events:HandleCombatLogEvent()
assertEqual(ParseBuddy.Encounter.lastIgnoredSpellId, 25225, "full removal excludes stale same-frame aura from resync")
assertEqual(ParseBuddy.Encounter.removalPreparations, 1, "full removal preserves pre-removal diagnostics")

print("ParseBuddy Events tests passed: " .. testsRun)
