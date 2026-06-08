local PB = ParseBuddy

PB.Encounter = {
    active = false,
    encounter = nil,
    encounteredBosses = {},
    visibleBosses = {},
    visibleOrder = {},
    primaryVisibleBoss = nil,
    generation = 0,
}

local BOSS_UNIT_COUNT = 5

local runtimeUnitProvider = {
    Exists = function(unitToken)
        return UnitExists(unitToken)
    end,
    GUID = function(unitToken)
        return UnitGUID(unitToken)
    end,
    Name = function(unitToken)
        return UnitName(unitToken)
    end,
}

function PB.Encounter:Reset()
    self.active = false
    self.encounter = nil
    self.encounteredBosses = {}
    self.visibleBosses = {}
    self.visibleOrder = {}
    self.primaryVisibleBoss = nil
    PB.State:ResetEncounter()
end

function PB.Encounter:Start(encounterId, encounterName, difficultyId, groupSize, unitProvider)
    self:Reset()
    self.generation = self.generation + 1
    self.active = true
    self.encounter = {
        id = encounterId,
        name = encounterName,
        difficultyId = difficultyId,
        groupSize = groupSize,
        startedAt = GetTime(),
    }

    PB.UI:ShowEncounter(self.encounter, nil)
    self:RefreshVisibleBosses(unitProvider)

    local generation = self.generation
    C_Timer.After(ParseBuddyDB.pullGracePeriod, function()
        if self.active and self.generation == generation then
            self:RefreshDisplay()
        end
    end)
end

function PB.Encounter:End(encounterId, encounterName, difficultyId, groupSize, success)
    local endedEncounter = self.encounter
    self:Reset()
    PB.UI:HideEncounter()
    return endedEncounter, success
end

function PB.Encounter:RefreshVisibleBosses(unitProvider)
    if not self.active then
        return
    end

    unitProvider = unitProvider or runtimeUnitProvider

    local guid
    for guid, boss in pairs(self.encounteredBosses) do
        boss.visible = false
        boss.unitToken = nil
    end

    self.visibleBosses = {}
    self.visibleOrder = {}

    local index
    for index = 1, BOSS_UNIT_COUNT do
        local unitToken = "boss" .. index
        if unitProvider.Exists(unitToken) then
            guid = unitProvider.GUID(unitToken)
            if guid then
                local boss = self.encounteredBosses[guid]
                if not boss then
                    boss = {
                        guid = guid,
                        firstSeenIndex = index,
                    }
                    self.encounteredBosses[guid] = boss
                end

                boss.name = unitProvider.Name(unitToken) or boss.name or "Unknown Boss"
                boss.unitToken = unitToken
                boss.lastUnitToken = unitToken
                boss.visible = true

                self.visibleBosses[guid] = boss
                self.visibleOrder[#self.visibleOrder + 1] = boss
            end
        end
    end

    self.primaryVisibleBoss = self.visibleOrder[1]
    self:RefreshDisplay()
end

function PB.Encounter:IsGraceActive(now)
    if not self.active or not self.encounter then
        return false
    end
    return now - self.encounter.startedAt < ParseBuddyDB.pullGracePeriod
end

function PB.Encounter:RefreshDisplay()
    if not self.active then
        return
    end

    local boss = self.primaryVisibleBoss
    local evaluations
    if boss then
        local now = GetTime()
        evaluations = PB.State:EvaluateBoss(
            boss.guid,
            now,
            ParseBuddyDB.warningThreshold,
            self:IsGraceActive(now)
        )
    end
    PB.UI:UpdateEncounter(self.encounter, boss, evaluations)
end

function PB.Encounter:IsBossGUID(guid)
    return guid ~= nil and self.encounteredBosses[guid] ~= nil
end

function PB.Encounter:IsBossVisible(guid)
    return guid ~= nil and self.visibleBosses[guid] ~= nil
end
