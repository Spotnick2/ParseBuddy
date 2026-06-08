local PB = ParseBuddy

PB.Events = {}

local TRACKED_AURA_EVENTS = {
    SPELL_AURA_APPLIED = true,
    SPELL_AURA_REFRESH = true,
    SPELL_AURA_REMOVED = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED_DOSE = true,
}

function PB.Events:HandleCombatLogEvent()
    local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, _, _, _, spellId, spellName, _, _, amount = CombatLogGetCurrentEventInfo()
    if not TRACKED_AURA_EVENTS[subevent] then
        return
    end
    if not PB.DebuffLibrary.spellIdToGroupKey[spellId] then
        return
    end
    if not PB.Encounter:IsBossGUID(destGUID) then
        return
    end

    local changed = PB.State:HandleAuraEvent({
        timestamp = timestamp,
        subevent = subevent,
        sourceGUID = sourceGUID,
        sourceName = sourceName,
        destGUID = destGUID,
        spellId = spellId,
        spellName = spellName,
        amount = amount,
    })
    if changed and PB.Encounter:IsBossVisible(destGUID) then
        PB.Encounter:RefreshDisplay()
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
