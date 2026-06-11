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
local GRACE_REFRESH_PADDING = 0.1

local function appendLine(lines, value)
    lines[#lines + 1] = value
end

local function formatMaybe(value)
    if value == nil or value == "" then
        return "none"
    end
    return tostring(value)
end

local function formatBool(value)
    return value and "yes" or "no"
end

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
    C_Timer.After(ParseBuddyDB.pullGracePeriod + GRACE_REFRESH_PADDING, function()
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

    if self.visibleOrder[1] then
        self.primaryVisibleBoss = self.visibleOrder[1]
    elseif not (self.primaryVisibleBoss and self.primaryVisibleBoss.discoveredFromCombatLog) then
        self.primaryVisibleBoss = nil
    end
    self:RefreshDisplay()
end

function PB.Encounter:HasVisibleBosses()
    return next(self.visibleBosses) ~= nil
end

function PB.Encounter:IsPrimaryBossGUID(guid)
    return guid ~= nil and self.primaryVisibleBoss ~= nil and self.primaryVisibleBoss.guid == guid
end

function PB.Encounter:ShouldRefreshForGUID(guid)
    return self:IsPrimaryBossGUID(guid)
end

function PB.Encounter:ReclaimPrimaryBoss(guid)
    if not self.active or self:HasVisibleBosses() or self.primaryVisibleBoss then
        return false
    end

    local boss = self.encounteredBosses[guid]
    if not boss or not (boss.lastUnitToken or boss.matchesEncounterName) then
        return false
    end

    self.primaryVisibleBoss = boss
    return true
end

function PB.Encounter:HasAuthoritativeHiddenBoss()
    local _, boss
    for _, boss in pairs(self.encounteredBosses) do
        if boss.lastUnitToken or boss.matchesEncounterName then
            return true
        end
    end
    return false
end

function PB.Encounter:LearnBossFromCombatLog(guid, name)
    if not self.active or not guid then
        return false
    end

    if self:HasVisibleBosses() then
        return false
    end

    if not self.primaryVisibleBoss and self:HasAuthoritativeHiddenBoss() then
        return false
    end

    local matchesEncounterName = name ~= nil
        and name ~= ""
        and self.encounter ~= nil
        and name == self.encounter.name

    if self.primaryVisibleBoss then
        if not matchesEncounterName or self.primaryVisibleBoss.matchesEncounterName then
            return false
        end

        local previousGUID = self.primaryVisibleBoss.guid
        self.encounteredBosses[previousGUID] = nil
        PB.State:ForgetBoss(previousGUID)
    end

    local boss = {
        guid = guid,
        name = name or "Unknown Boss",
        firstSeenIndex = 0,
        visible = false,
        unitToken = nil,
        lastUnitToken = nil,
        discoveredFromCombatLog = true,
        matchesEncounterName = matchesEncounterName,
    }
    self.encounteredBosses[guid] = boss
    self.primaryVisibleBoss = boss
    return true
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

function PB.Encounter:BuildDumpLines()
    local lines = {}
    appendLine(lines, "ParseBuddy dump:")

    local uiMode = PB.UI and PB.UI.mode or "none"
    local frameShown = PB.UI and PB.UI.frame and PB.UI.frame:IsShown() or false

    if not self.active then
        appendLine(lines, string.format("Encounter: active=no uiMode=%s frameShown=%s", tostring(uiMode), formatBool(frameShown)))
        return lines
    end

    appendLine(lines, string.format(
        "Encounter: active=yes id=%s name=%s difficulty=%s groupSize=%s startedAt=%.1f",
        formatMaybe(self.encounter and self.encounter.id),
        formatMaybe(self.encounter and self.encounter.name),
        formatMaybe(self.encounter and self.encounter.difficultyId),
        formatMaybe(self.encounter and self.encounter.groupSize),
        tonumber(self.encounter and self.encounter.startedAt) or 0
    ))
    local primaryBoss = self.primaryVisibleBoss
    appendLine(lines, string.format(
        "UI: mode=%s frameShown=%s primaryBoss=%s visible=%s fallback=%s encounterMatch=%s",
        tostring(uiMode),
        formatBool(frameShown),
        formatMaybe(primaryBoss and primaryBoss.name),
        formatBool(primaryBoss and primaryBoss.visible),
        formatBool(primaryBoss and primaryBoss.discoveredFromCombatLog),
        formatBool(primaryBoss and primaryBoss.matchesEncounterName)
    ))

    appendLine(lines, "Visible boss units:")
    local index
    for index = 1, BOSS_UNIT_COUNT do
        local unitToken = "boss" .. index
        local boss = nil
        local visibleBoss = nil
        for _, candidate in ipairs(self.visibleOrder) do
            if candidate.unitToken == unitToken then
                visibleBoss = candidate
                break
            end
        end
        if visibleBoss then
            boss = visibleBoss
            appendLine(lines, string.format("  %s: guid=%s name=%s", unitToken, formatMaybe(boss.guid), formatMaybe(boss.name)))
        else
            appendLine(lines, string.format("  %s: none", unitToken))
        end
    end

    appendLine(lines, "Encountered bosses:")
    if next(self.encounteredBosses) == nil then
        appendLine(lines, "  none")
    else
        local encountered = {}
        local guid, boss
        for guid, boss in pairs(self.encounteredBosses) do
            encountered[#encountered + 1] = boss
        end
        table.sort(encountered, function(left, right)
            return tostring(left.guid) < tostring(right.guid)
        end)
        local _, item
        for _, item in ipairs(encountered) do
            appendLine(lines, string.format(
                "  guid=%s name=%s visible=%s unit=%s lastUnit=%s firstSeenIndex=%s",
                formatMaybe(item.guid),
                formatMaybe(item.name),
                formatBool(item.visible),
                formatMaybe(item.unitToken),
                formatMaybe(item.lastUnitToken),
                formatMaybe(item.firstSeenIndex)
            ))
        end
    end

    appendLine(lines, "Tracked candidates:")
    local candidatesByBoss = PB.State and PB.State.candidatesByBoss or {}
    if next(candidatesByBoss) == nil then
        appendLine(lines, "  none")
    else
        local bosses = {}
        local bossGUID
        for bossGUID in pairs(candidatesByBoss) do
            bosses[#bosses + 1] = bossGUID
        end
        table.sort(bosses)

        local bossIndex
        for bossIndex = 1, #bosses do
            bossGUID = bosses[bossIndex]
            appendLine(lines, string.format("  bossGUID=%s", tostring(bossGUID)))
            local bossCandidates = candidatesByBoss[bossGUID] or {}
            local groupKeys = {}
            local groupKey
            for groupKey in pairs(bossCandidates) do
                groupKeys[#groupKeys + 1] = groupKey
            end
            table.sort(groupKeys)

            local groupIndex
            for groupIndex = 1, #groupKeys do
                groupKey = groupKeys[groupIndex]
                local groupCandidates = bossCandidates[groupKey] or {}
                local candidateList = {}
                local spellId, candidate
                for spellId, candidate in pairs(groupCandidates) do
                    candidateList[#candidateList + 1] = candidate
                end
                table.sort(candidateList, function(left, right)
                    return tonumber(left.spellId) < tonumber(right.spellId)
                end)
                appendLine(lines, string.format("    group=%s count=%d", tostring(groupKey), #candidateList))
                local candidateIndex
                for candidateIndex = 1, #candidateList do
                    candidate = candidateList[candidateIndex]
                    appendLine(lines, string.format(
                        "      spellId=%s spellName=%s source=%s stacks=%s active=%s removedAt=%s expiresAt=%s lastSeenAt=%s",
                        formatMaybe(candidate.spellId),
                        formatMaybe(candidate.spellName),
                        formatMaybe(candidate.sourceName),
                        formatMaybe(candidate.stacks),
                        formatBool(candidate.active ~= false),
                        formatMaybe(candidate.removedAt),
                        formatMaybe(candidate.expiresAt),
                        formatMaybe(candidate.lastSeenAt)
                    ))
                end
            end
        end
    end

    appendLine(lines, "Visible evaluations:")
    if not self.primaryVisibleBoss then
        appendLine(lines, "  none - no boss target is currently selected")
    else
        local now = GetTime()
        local evaluations = PB.State:EvaluateBoss(
            self.primaryVisibleBoss.guid,
            now,
            ParseBuddyDB.warningThreshold,
            self:IsGraceActive(now)
        )
        local evaluation
        for _, evaluation in ipairs(evaluations or {}) do
            local row = PB.UI:EvaluationToRowData(evaluation)
            appendLine(lines, string.format(
                "  %s: %s - %s - %s",
                formatMaybe(row.group),
                formatMaybe(row.effect),
                formatMaybe(row.source),
                formatMaybe(row.status)
            ))
        end
    end

    return lines
end

function PB.Encounter:IsBossGUID(guid)
    return guid ~= nil and self.encounteredBosses[guid] ~= nil
end

function PB.Encounter:IsBossVisible(guid)
    return guid ~= nil and self.visibleBosses[guid] ~= nil
end
