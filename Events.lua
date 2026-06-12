local PB = ParseBuddy

PB.Events = {}

local TRACKED_AURA_EVENTS = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
    SPELL_AURA_REMOVED = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED_DOSE = true,
}

local BOSS_DISCOVERY_EVENTS = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED_DOSE = true,
}

local function isTrackableNPC(flags)
    return flags ~= nil
        and bit ~= nil
        and bit.band ~= nil
        and COMBATLOG_OBJECT_TYPE_NPC ~= nil
        and bit.band(flags, COMBATLOG_OBJECT_TYPE_NPC) ~= 0
        and (
            COMBATLOG_OBJECT_REACTION_FRIENDLY == nil
            or bit.band(flags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == 0
        )
end

function PB.Events:HandleCombatLogEvent()
    local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, destFlags, _, spellId, spellName, _, _, amount = CombatLogGetCurrentEventInfo()
    if not TRACKED_AURA_EVENTS[subevent] then
        return
    end
    if not PB.DebuffLibrary.spellIdToGroupKey[spellId] then
        return
    end
    if PB.Encounter:IsBossGUID(destGUID) then
        if BOSS_DISCOVERY_EVENTS[subevent] then
            PB.Encounter:ReclaimPrimaryBoss(destGUID)
        end
    else
        if not BOSS_DISCOVERY_EVENTS[subevent]
            or not isTrackableNPC(destFlags)
            or not PB.Encounter:LearnBossFromCombatLog(destGUID, destName)
        then
            return
        end
    end

    local observedAt = GetTime and GetTime() or timestamp
    if subevent == "SPELL_AURA_REMOVED" then
        PB.Encounter:PrepareForAuraRemoval(observedAt)
    else
        PB.Encounter:CancelPendingRemovalCapture()
    end

    local changed = PB.State:HandleAuraEvent({
        timestamp = timestamp,
        observedAt = observedAt,
        subevent = subevent,
        sourceGUID = sourceGUID,
        sourceName = sourceName,
        destGUID = destGUID,
        destName = destName,
        spellId = spellId,
        spellName = spellName,
        amount = amount,
    })
    PB.Encounter:RecordRelevantCLEU()
    local ignoredSpellId = subevent == "SPELL_AURA_REMOVED" and spellId or nil
    local scanned = PB.Encounter:ResyncBossGUID(destGUID, "cleu", nil, ignoredSpellId)
    if (changed or scanned) and PB.Encounter:ShouldRefreshForGUID(destGUID) then
        if subevent ~= "SPELL_AURA_REMOVED" then
            PB.Encounter:RecordMeaningfulLiveState(observedAt)
        end
        PB.Encounter:RefreshDisplay(true)
    end
end

function PB.Events:Initialize()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ENCOUNTER_START" then
            PB.Encounter:Start(...)
        elseif event == "ENCOUNTER_END" then
            PB.Encounter:End(...)
        elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
            PB.Encounter:RefreshVisibleBosses()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            PB.Events:HandleCombatLogEvent()
        end
    end)

    self.frame = frame
end
