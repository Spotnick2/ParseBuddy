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
local DISPLAY_REFRESH_INTERVAL = 0.2
local EXACT_SCAN_UNIT_TOKENS = { "target", "focus" }
local REMOVAL_BATCH_DELAY = 0.3

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
    if self.displayTicker then
        self.displayTicker:Cancel()
        self.displayTicker = nil
    end
    self.active = false
    self.encounter = nil
    self.encounteredBosses = {}
    self.visibleBosses = {}
    self.visibleOrder = {}
    self.primaryVisibleBoss = nil
    self.primarySelectionReason = nil
    if PB.Broadcast then
        PB.Broadcast:End()
    end
    PB.State:ResetEncounter()
end

function PB.Encounter:SetPrimaryBoss(boss, reason, observedAt)
    local previousGUID = self.primaryVisibleBoss and self.primaryVisibleBoss.guid or nil
    local nextGUID = boss and boss.guid or nil
    self.primaryVisibleBoss = boss
    self.primarySelectionReason = reason
    if previousGUID ~= nextGUID and PB.Summary then
        PB.Summary:RecordPrimarySwitch(observedAt or GetTime(), boss, reason)
    end
    return previousGUID ~= nextGUID
end

function PB.Encounter:StartDisplayTicker()
    if self.displayTicker or not C_Timer.NewTicker then
        return
    end

    self.displayTicker = C_Timer.NewTicker(DISPLAY_REFRESH_INTERVAL, function()
        if self.active then
            local metrics = self.encounter and self.encounter.metrics
            if metrics then
                metrics.tickerTicks = metrics.tickerTicks + 1
            end
            self:RefreshDisplay()
        end
    end)
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
        metrics = {
            relevantCLEU = 0,
            displayRefreshes = 0,
            tickerTicks = 0,
            scans = 0,
            scansByReason = {},
            inspectedAuras = 0,
            trackedAurasSeen = 0,
        },
    }
    if PB.Summary then
        PB.Summary:Begin(self.encounter)
    end
    if PB.Broadcast then
        PB.Broadcast:Begin(self.encounter)
    end

    PB.UI:ShowEncounter(self.encounter, nil)
    self:RefreshVisibleBosses(unitProvider)
    self:StartDisplayTicker()

    local generation = self.generation
    C_Timer.After(ParseBuddyDB.pullGracePeriod + GRACE_REFRESH_PADDING, function()
        if self.active and self.generation == generation then
            self:RefreshDisplay(true)
        end
    end)
end

function PB.Encounter:End(encounterId, encounterName, difficultyId, groupSize, success)
    local endedEncounter = self.encounter
    local endedAt = GetTime()
    local summary = PB.Summary and PB.Summary:Finalize(endedAt, success) or nil
    local snapshot = self:CaptureSnapshot(success)
    self:Reset()
    PB.UI:HideEncounter()
    return endedEncounter, success, snapshot, summary
end

function PB.Encounter:CaptureSnapshot(success)
    if not self.active or not self.encounter then
        return nil
    end

    local endedAt = GetTime()
    local wallClock = time and time() or 0
    local finalRawCandidateLines = self:BuildCandidateLines("Final raw candidate state:")
    local lines = self:BuildDumpLines({
        source = "COMPLETED SNAPSHOT",
        reportActive = false,
        candidateHeading = "Final raw candidate state:",
        evaluationHeading = "Final evaluations:",
    })
    table.insert(lines, 3, string.format(
        "Snapshot: name=%s success=%s duration=%.1f capturedAt=%s",
        formatMaybe(self.encounter.name),
        formatBool(success == 1 or success == true),
        math.max(0, endedAt - (self.encounter.startedAt or endedAt)),
        formatMaybe(wallClock)
    ))

    local snapshot = {
        schemaVersion = 2,
        encounterId = self.encounter.id,
        encounterName = self.encounter.name,
        difficultyId = self.encounter.difficultyId,
        groupSize = self.encounter.groupSize,
        startedAt = self.encounter.startedAt,
        endedAt = endedAt,
        capturedAt = wallClock,
        success = success == 1 or success == true,
        finalRawCandidateLines = finalRawCandidateLines,
        lastMeaningfulLive = self.encounter.lastMeaningfulLive,
        lines = lines,
    }
    appendLine(lines, "Last meaningful live evaluations:")
    local live = snapshot.lastMeaningfulLive
    if live and live.lines then
        appendLine(lines, string.format(
            "  capturedAt=%.1f bossGUID=%s bossName=%s",
            tonumber(live.capturedAt) or 0,
            formatMaybe(live.bossGUID),
            formatMaybe(live.bossName)
        ))
        local index
        for index = 1, #live.lines do
            appendLine(lines, live.lines[index])
        end
    else
        appendLine(lines, "  none - no satisfying live evaluation was observed")
    end
    PB.lastEncounterSnapshot = snapshot
    ParseBuddyDB.lastEncounterSnapshot = snapshot
    return snapshot
end

function PB.Encounter:BuildEvaluationLines(evaluations)
    local lines = {}
    local _, evaluation
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
    return lines
end

function PB.Encounter:RecordMeaningfulLiveState(now, evaluations)
    if not self.active or not self.encounter or not self.primaryVisibleBoss then
        return false
    end

    now = now or GetTime()
    evaluations = evaluations or PB.State:EvaluateBoss(
        self.primaryVisibleBoss.guid,
        now,
        ParseBuddyDB.warningThreshold,
        self:IsGraceActive(now)
    )

    local meaningful = false
    local _, evaluation
    for _, evaluation in ipairs(evaluations or {}) do
        if evaluation.state == "active" or evaluation.state == "expiring" or evaluation.state == "partial" then
            meaningful = true
            break
        end
    end
    if not meaningful then
        return false
    end

    self.encounter.lastMeaningfulLive = {
        capturedAt = now,
        bossGUID = self.primaryVisibleBoss.guid,
        bossName = self.primaryVisibleBoss.name,
        lines = self:BuildEvaluationLines(evaluations),
    }
    return true
end

function PB.Encounter:PrepareForAuraRemoval(now)
    if not self.active or not self.encounter then
        return
    end

    local previousRemovalAt = self.encounter.removalBatchLastAt
    local sameBatch = previousRemovalAt ~= nil and now - previousRemovalAt <= REMOVAL_BATCH_DELAY
    self.encounter.removalBatchLastAt = now
    self.encounter.removalBatchToken = (self.encounter.removalBatchToken or 0) + 1
    local token = self.encounter.removalBatchToken
    local generation = self.generation
    if not sameBatch then
        self:RecordMeaningfulLiveState(now)
    end

    C_Timer.After(REMOVAL_BATCH_DELAY, function()
        if self.active
            and self.generation == generation
            and self.encounter
            and self.encounter.removalBatchToken == token
        then
            self.encounter.removalBatchLastAt = nil
            self:RecordMeaningfulLiveState()
        end
    end)
end

function PB.Encounter:CancelPendingRemovalCapture()
    if self.encounter then
        self.encounter.removalBatchToken = (self.encounter.removalBatchToken or 0) + 1
        self.encounter.removalBatchLastAt = nil
    end
end

function PB.Encounter:RefreshVisibleBosses(unitProvider)
    if not self.active then
        return
    end

    unitProvider = unitProvider or runtimeUnitProvider

    local previousUnitByGUID = {}
    local guid
    for guid, boss in pairs(self.encounteredBosses) do
        previousUnitByGUID[guid] = boss.unitToken
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
                local registered, npcId = PB.EncounterTargets:IsRegistered(self.encounter and self.encounter.id, guid)
                boss.npcId = npcId or boss.npcId
                boss.registeredTarget = registered or boss.registeredTarget
                boss.unitToken = unitToken
                boss.lastUnitToken = unitToken
                boss.visible = true

                self.visibleBosses[guid] = boss
                self.visibleOrder[#self.visibleOrder + 1] = boss

                if previousUnitByGUID[guid] ~= unitToken then
                    self:ResyncBossGUID(guid, "boss-unit-appeared")
                end
            end
        end
    end

    local configuredTargets = PB.EncounterTargets:Get(self.encounter and self.encounter.id)
    local selected
    local reason
    if self.visibleOrder[1] and self.visibleOrder[1].unitToken == "boss1" then
        selected = self.visibleOrder[1]
        reason = "visible-boss1"
    elseif configuredTargets then
        local _, boss
        for _, boss in ipairs(self.visibleOrder) do
            local registered = PB.EncounterTargets:IsRegistered(self.encounter.id, boss.guid)
            if registered then
                selected = boss
                reason = "visible-registered"
                break
            end
        end
    elseif self.visibleOrder[1] then
        selected = self.visibleOrder[1]
        reason = "first-visible"
    end
    if not selected and self.primaryVisibleBoss and self.primaryVisibleBoss.registeredTarget then
        selected = self.primaryVisibleBoss
        reason = self.primarySelectionReason or "previous-authoritative"
    elseif not selected and self.primaryVisibleBoss and self.primaryVisibleBoss.discoveredFromCombatLog then
        selected = self.primaryVisibleBoss
        reason = self.primarySelectionReason or "generic-fallback"
    end
    self:SetPrimaryBoss(selected, reason)
    self:RecordMeaningfulLiveState()
    self:RefreshDisplay(true)
end

function PB.Encounter:ResyncBossGUID(guid, reason, auraProvider, ignoredSpellId)
    local boss = self.encounteredBosses[guid]
    if not boss then
        return false, 0
    end

    local unitToken = boss.visible and boss.unitToken or nil
    if not unitToken then
        local _, fallbackToken
        for _, fallbackToken in ipairs(EXACT_SCAN_UNIT_TOKENS) do
            local exists = not UnitExists or UnitExists(fallbackToken)
            if exists and UnitGUID and UnitGUID(fallbackToken) == guid then
                unitToken = fallbackToken
                break
            end
        end
    end
    if not unitToken then
        return false, 0
    end

    local now = GetTime()
    local preserveRecentSeconds = reason == "cleu" and DISPLAY_REFRESH_INTERVAL or nil
    local scanned, trackedCount, inspectedCount = PB.State:ResyncBossUnit(
        unitToken,
        guid,
        auraProvider,
        now,
        preserveRecentSeconds,
        ignoredSpellId
    )
    if scanned then
        boss.lastScanAt = now
        boss.lastScanReason = reason
        boss.lastScanUnitToken = unitToken
        boss.lastScanTrackedCount = trackedCount
        local metrics = self.encounter and self.encounter.metrics
        if metrics then
            metrics.scans = metrics.scans + 1
            metrics.scansByReason[reason] = (metrics.scansByReason[reason] or 0) + 1
            metrics.inspectedAuras = metrics.inspectedAuras + (inspectedCount or 0)
            metrics.trackedAurasSeen = metrics.trackedAurasSeen + trackedCount
        end
    end
    return scanned, trackedCount, inspectedCount
end

function PB.Encounter:GetAuraDebugUnits(boss)
    local units = {}
    local seenTokens = {}
    if not boss or not boss.guid then
        return units
    end

    local function addUnit(unitToken, reason)
        if unitToken and not seenTokens[unitToken] then
            seenTokens[unitToken] = true
            units[#units + 1] = {
                unitToken = unitToken,
                reason = reason,
            }
        end
    end

    if boss.visible and boss.unitToken then
        addUnit(boss.unitToken, "visible-boss-unit")
    end

    local _, fallbackToken
    for _, fallbackToken in ipairs(EXACT_SCAN_UNIT_TOKENS) do
        local exists = not UnitExists or UnitExists(fallbackToken)
        if exists and UnitGUID and UnitGUID(fallbackToken) == boss.guid then
            addUnit(fallbackToken, "exact-guid-match")
        end
    end

    return units
end

function PB.Encounter:RecordRelevantCLEU()
    if self.encounter and self.encounter.metrics then
        self.encounter.metrics.relevantCLEU = self.encounter.metrics.relevantCLEU + 1
    end
end

function PB.Encounter:DebugAuras(auraProvider)
    if not self.active or not self.primaryVisibleBoss then
        PB:Print("No active boss target is selected for aura diagnostics.")
        return 0, 0
    end

    local boss = self.primaryVisibleBoss
    local units = self:GetAuraDebugUnits(boss)
    if #units == 0 then
        PB:Print(string.format(
            "No exact mapped unit for %s. Target or focus the active boss, then run /pb debugauras again.",
            formatMaybe(boss.name)
        ))
        return 0, 0
    end

    local now = GetTime()
    local scannedUnits = 0
    local totalAuras = 0
    local unitIndex
    for unitIndex = 1, #units do
        local unit = units[unitIndex]
        local auras, inspectedCount = PB.State:GetUnitDebuffs(unit.unitToken, auraProvider)
        scannedUnits = scannedUnits + 1
        totalAuras = totalAuras + #auras
        PB:Print(string.format(
            "Boss auras on %s: boss=%s guid=%s reason=%s harmful=%d inspected=%d",
            unit.unitToken,
            formatMaybe(boss.name),
            formatMaybe(boss.guid),
            unit.reason,
            #auras,
            inspectedCount or #auras
        ))

        local auraIndex, aura
        for auraIndex, aura in ipairs(auras) do
            local remaining = "none"
            if aura.expirationTime and aura.expirationTime > 0 then
                remaining = string.format("%.1fs", math.max(0, aura.expirationTime - now))
            end
            local tracked = aura.spellId and PB.DebuffLibrary.spellIdToGroupKey[aura.spellId] or nil
            PB:Print(string.format(
                "  %02d spellId=%s name=%s stacks=%s remaining=%s source=%s tracked=%s",
                aura.index or auraIndex,
                formatMaybe(aura.spellId),
                formatMaybe(aura.name),
                formatMaybe(aura.stacks and aura.stacks > 0 and aura.stacks or nil),
                remaining,
                formatMaybe(aura.sourceName or aura.sourceUnit),
                formatMaybe(tracked)
            ))
        end
    end

    return scannedUnits, totalAuras
end

function PB.Encounter:DebugScan(auraProvider)
    if not self.active then
        PB:Print("No active encounter to scan.")
        return 0, 0
    end

    local scannedBosses = 0
    local trackedAuras = 0
    local scannedGUIDs = {}
    local _, boss
    for _, boss in ipairs(self.visibleOrder) do
        local scanned, trackedCount = self:ResyncBossGUID(boss.guid, "debugscan", auraProvider)
        if scanned then
            scannedGUIDs[boss.guid] = true
            scannedBosses = scannedBosses + 1
            trackedAuras = trackedAuras + trackedCount
        end
    end
    local guid
    for guid, boss in pairs(self.encounteredBosses) do
        if not scannedGUIDs[guid] then
            local scanned, trackedCount = self:ResyncBossGUID(guid, "debugscan", auraProvider)
            if scanned then
                scannedGUIDs[guid] = true
                scannedBosses = scannedBosses + 1
                trackedAuras = trackedAuras + trackedCount
            end
        end
    end
    self:RefreshDisplay(true)
    PB:Print(string.format("Scanned %d mapped boss unit(s); found %d tracked aura(s).", scannedBosses, trackedAuras))
    return scannedBosses, trackedAuras
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

function PB.Encounter:HasHigherPriorityVisibleTarget()
    if self.visibleOrder[1] and self.visibleOrder[1].unitToken == "boss1" then
        return true
    end
    local _, boss
    for _, boss in ipairs(self.visibleOrder) do
        if boss.registeredTarget then
            return true
        end
    end
    return false
end

function PB.Encounter:ReclaimPrimaryBoss(guid)
    local boss = self.encounteredBosses[guid]
    if boss and boss.registeredTarget then
        if self:HasHigherPriorityVisibleTarget() then
            return false
        end
        boss.lastRelevantAt = GetTime()
        return self:SetPrimaryBoss(boss, "recent-registered", boss.lastRelevantAt)
    end

    if not self.active or self:HasVisibleBosses() or self.primaryVisibleBoss then
        return false
    end

    boss = self.encounteredBosses[guid]
    if not boss or not (boss.lastUnitToken or boss.matchesEncounterName) then
        return false
    end

    self:SetPrimaryBoss(boss, "reclaimed-authoritative")
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

    local configuredTargets = PB.EncounterTargets:Get(self.encounter and self.encounter.id)
    if configuredTargets then
        local registered, npcId = PB.EncounterTargets:IsRegistered(self.encounter.id, guid)
        if not registered then
            return false
        end
        local boss = self.encounteredBosses[guid]
        if not boss then
            boss = {
                guid = guid,
                npcId = npcId,
                name = name or configuredTargets.npcIds[npcId] or "Unknown Boss",
                firstSeenIndex = 0,
                visible = false,
                unitToken = nil,
                lastUnitToken = nil,
                discoveredFromCombatLog = true,
                registeredTarget = true,
            }
            self.encounteredBosses[guid] = boss
        end
        boss.lastRelevantAt = GetTime()
        if not self:HasHigherPriorityVisibleTarget() then
            self:SetPrimaryBoss(boss, "recent-registered", boss.lastRelevantAt)
        end
        return true
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
    self:SetPrimaryBoss(boss, matchesEncounterName and "encounter-name" or "generic-fallback")
    return true
end

function PB.Encounter:PrintTargets()
    if not self.active or not self.encounter then
        PB:Print("No active encounter targets are available.")
        return false
    end

    local configured = PB.EncounterTargets:Get(self.encounter.id)
    PB:Print(string.format(
        "Targets: encounter=%s id=%s registry=%s primary=%s reason=%s",
        tostring(self.encounter.name),
        tostring(self.encounter.id),
        configured and "configured" or "generic",
        self.primaryVisibleBoss and self.primaryVisibleBoss.name or "none",
        self.primarySelectionReason or "none"
    ))
    if configured then
        local npcIds = {}
        local npcId
        for npcId in pairs(configured.npcIds) do
            npcIds[#npcIds + 1] = npcId
        end
        table.sort(npcIds)
        local _, id
        for _, id in ipairs(npcIds) do
            PB:Print(string.format("Configured target: npcId=%d name=%s", id, configured.npcIds[id]))
        end
    end

    local bosses = {}
    local _, boss
    for _, boss in pairs(self.encounteredBosses) do
        bosses[#bosses + 1] = boss
    end
    table.sort(bosses, function(left, right) return tostring(left.guid) < tostring(right.guid) end)
    for _, boss in ipairs(bosses) do
        PB:Print(string.format(
            "Accepted target: guid=%s npcId=%s name=%s visible=%s registered=%s",
            tostring(boss.guid),
            tostring(boss.npcId or PB.EncounterTargets:GetNPCId(boss.guid) or "none"),
            tostring(boss.name),
            boss.visible and "yes" or "no",
            boss.registeredTarget and "yes" or "no"
        ))
    end
    return true
end

function PB.Encounter:IsGraceActive(now)
    if not self.active or not self.encounter then
        return false
    end
    return now - self.encounter.startedAt < ParseBuddyDB.pullGracePeriod
end

function PB.Encounter:RefreshDisplay(recordSummary)
    if not self.active then
        return
    end

    local metrics = self.encounter and self.encounter.metrics
    if metrics then
        metrics.displayRefreshes = metrics.displayRefreshes + 1
    end

    local boss = self.primaryVisibleBoss
    local evaluations
    if boss then
        local now = GetTime()
        local expired = PB.State:ExpireBoss(boss.guid, now)
        evaluations = PB.State:EvaluateBoss(
            boss.guid,
            now,
            ParseBuddyDB.warningThreshold,
            self:IsGraceActive(now)
        )
        if expired then
            self:RecordMeaningfulLiveState(now, evaluations)
        end
        if PB.Summary and (recordSummary or expired) then
            PB.Summary:Observe(now, boss.guid)
        end
        if PB.Broadcast and (recordSummary or expired) then
            PB.Broadcast:Observe(now, evaluations)
        end
    elseif PB.Summary and recordSummary then
        PB.Summary:Observe(GetTime(), nil)
    end
    PB.UI:UpdateEncounter(self.encounter, boss, evaluations)
end

function PB.Encounter:BuildCandidateLines(heading)
    local lines = {}
    appendLine(lines, heading or "Tracked candidates:")
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
                        "      spellId=%s spellName=%s source=%s stacks=%s active=%s removedAt=%s expiresAt=%s durationSource=%s lastSeenAt=%s lastScannedAt=%s",
                        formatMaybe(candidate.spellId),
                        formatMaybe(candidate.spellName),
                        formatMaybe(candidate.sourceName),
                        formatMaybe(candidate.stacks),
                        formatBool(candidate.active ~= false),
                        formatMaybe(candidate.removedAt),
                        formatMaybe(candidate.expiresAt),
                        formatMaybe(candidate.durationSource),
                        formatMaybe(candidate.lastSeenAt),
                        formatMaybe(candidate.lastScannedAt)
                    ))
                end
            end
        end
    end

    return lines
end

function PB.Encounter:BuildDumpLines(options)
    options = options or {}
    local lines = {}
    appendLine(lines, "ParseBuddy dump:")
    appendLine(lines, "Dump source: " .. (options.source or "LIVE"))

    local uiMode = PB.UI and PB.UI.mode or "none"
    local frameShown = PB.UI and PB.UI.frame and PB.UI.frame:IsShown() or false
    local reportActive = options.reportActive
    if reportActive == nil then
        reportActive = self.active
    end

    if not self.encounter then
        appendLine(lines, string.format("Encounter: active=no uiMode=%s frameShown=%s", tostring(uiMode), formatBool(frameShown)))
        return lines
    end

    appendLine(lines, string.format(
        "Encounter: active=%s id=%s name=%s difficulty=%s groupSize=%s startedAt=%.1f",
        formatBool(reportActive),
        formatMaybe(self.encounter.id),
        formatMaybe(self.encounter.name),
        formatMaybe(self.encounter.difficultyId),
        formatMaybe(self.encounter.groupSize),
        tonumber(self.encounter.startedAt) or 0
    ))
    local metrics = self.encounter.metrics or {}
    local scansByReason = metrics.scansByReason or {}
    appendLine(lines, string.format(
        "Metrics: cleu=%d refreshes=%d ticker=%d scans=%d [appear=%d cleu=%d debug=%d] inspected=%d trackedSeen=%d",
        metrics.relevantCLEU or 0, metrics.displayRefreshes or 0, metrics.tickerTicks or 0, metrics.scans or 0,
        scansByReason["boss-unit-appeared"] or 0, scansByReason.cleu or 0, scansByReason.debugscan or 0,
        metrics.inspectedAuras or 0, metrics.trackedAurasSeen or 0
    ))
    local primaryBoss = self.primaryVisibleBoss
    appendLine(lines, string.format(
        "UI: mode=%s frameShown=%s primaryBoss=%s visible=%s fallback=%s encounterMatch=%s primaryReason=%s",
        tostring(uiMode), formatBool(frameShown), formatMaybe(primaryBoss and primaryBoss.name),
        formatBool(primaryBoss and primaryBoss.visible), formatBool(primaryBoss and primaryBoss.discoveredFromCombatLog),
        formatBool(primaryBoss and primaryBoss.matchesEncounterName),
        formatMaybe(self.primarySelectionReason)
    ))
    if PB.Broadcast then
        local broadcastLines = PB.Broadcast:GetDiagnosticLines()
        local broadcastIndex
        for broadcastIndex = 1, #broadcastLines do
            appendLine(lines, broadcastLines[broadcastIndex])
        end
    end

    appendLine(lines, "Visible boss units:")
    local index
    for index = 1, BOSS_UNIT_COUNT do
        local unitToken = "boss" .. index
        local visibleBoss
        local _, candidate
        for _, candidate in ipairs(self.visibleOrder) do
            if candidate.unitToken == unitToken then
                visibleBoss = candidate
                break
            end
        end
        if visibleBoss then
            appendLine(lines, string.format("  %s: guid=%s name=%s", unitToken, formatMaybe(visibleBoss.guid), formatMaybe(visibleBoss.name)))
        else
            appendLine(lines, string.format("  %s: none", unitToken))
        end
    end

    appendLine(lines, "Encountered bosses:")
    if next(self.encounteredBosses) == nil then
        appendLine(lines, "  none")
    else
        local encountered = {}
        local _, boss
        for _, boss in pairs(self.encounteredBosses) do
            encountered[#encountered + 1] = boss
        end
        table.sort(encountered, function(left, right) return tostring(left.guid) < tostring(right.guid) end)
        local _, item
        for _, item in ipairs(encountered) do
            appendLine(lines, string.format(
                "  guid=%s name=%s visible=%s unit=%s lastUnit=%s firstSeenIndex=%s lastScanAt=%s scanReason=%s scanTracked=%s",
                formatMaybe(item.guid), formatMaybe(item.name), formatBool(item.visible), formatMaybe(item.unitToken),
                formatMaybe(item.lastUnitToken), formatMaybe(item.firstSeenIndex), formatMaybe(item.lastScanAt),
                formatMaybe(item.lastScanReason), formatMaybe(item.lastScanTrackedCount)
            ))
        end
    end

    local candidateLines = self:BuildCandidateLines(options.candidateHeading)
    for index = 1, #candidateLines do
        appendLine(lines, candidateLines[index])
    end

    appendLine(lines, options.evaluationHeading or "Visible evaluations:")
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
        local evaluationLines = self:BuildEvaluationLines(evaluations)
        for index = 1, #evaluationLines do
            appendLine(lines, evaluationLines[index])
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
