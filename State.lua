local PB = ParseBuddy

PB.State = {
    candidatesByBoss = {},
}

local MAX_BOSS_DEBUFFS = 60

local runtimeAuraProvider = {
    GetDebuff = function(unitToken, index)
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex(unitToken, index, "HARMFUL")
            if not aura then
                return nil
            end
            return {
                name = aura.name,
                stacks = aura.applications,
                duration = aura.duration,
                expirationTime = aura.expirationTime,
                sourceUnit = aura.sourceUnit,
                spellId = aura.spellId,
            }
        end

        local name, _, stacks, _, duration, expirationTime, sourceUnit, _, _, spellId = UnitAura(unitToken, index, "HARMFUL")
        if not name then
            return nil
        end
        return {
            name = name,
            stacks = stacks,
            duration = duration,
            expirationTime = expirationTime,
            sourceUnit = sourceUnit,
            spellId = spellId,
        }
    end,
    SourceGUID = function(unitToken)
        return unitToken and UnitGUID(unitToken) or nil
    end,
    SourceName = function(unitToken)
        return unitToken and UnitName(unitToken) or nil
    end,
}

local function readUnitDebuffs(unitToken, auraProvider)
    auraProvider = auraProvider or runtimeAuraProvider
    local auras = {}
    local inspectedCount = 0
    local index

    for index = 1, MAX_BOSS_DEBUFFS do
        local aura = auraProvider.GetDebuff(unitToken, index)
        if not aura then
            break
        end

        inspectedCount = inspectedCount + 1
        aura.index = index
        if aura.sourceUnit then
            aura.sourceGUID = auraProvider.SourceGUID and auraProvider.SourceGUID(aura.sourceUnit) or nil
            aura.sourceName = auraProvider.SourceName and auraProvider.SourceName(aura.sourceUnit) or nil
        end
        auras[#auras + 1] = aura
    end

    return auras, inspectedCount
end

local STATE_RANK = {
    activeKnown = 1,
    activeUnknown = 2,
    expiringKnown = 3,
    expiringUnknown = 4,
    partialKnown = 5,
    partialUnknown = 6,
    recent = 7,
}

local function hasKnownSource(candidate)
    return candidate.sourceName ~= nil and candidate.sourceName ~= ""
end

local function getRemaining(candidate, now)
    if not candidate.expiresAt then
        return nil
    end
    return candidate.expiresAt - now
end

local function isActive(candidate, now)
    if candidate.active == false or candidate.removedAt then
        return false
    end
    return not candidate.expiresAt or candidate.expiresAt > now
end

local function isSatisfying(candidate, spell)
    return not spell.requiredStacks or (candidate.stacks or 0) >= spell.requiredStacks
end

local function classifyCandidate(candidate, spell, now, warningThreshold)
    if not isActive(candidate, now) then
        if candidate.lastSeenAt or candidate.removedAt or candidate.expiresAt then
            return STATE_RANK.recent, "recent", getRemaining(candidate, now)
        end
        return nil
    end

    local knownSource = hasKnownSource(candidate)
    local remaining = getRemaining(candidate, now)
    if not isSatisfying(candidate, spell) then
        return knownSource and STATE_RANK.partialKnown or STATE_RANK.partialUnknown, "partial", remaining
    end

    if remaining and remaining <= warningThreshold then
        return knownSource and STATE_RANK.expiringKnown or STATE_RANK.expiringUnknown, "expiring", remaining
    end

    return knownSource and STATE_RANK.activeKnown or STATE_RANK.activeUnknown, "active", remaining
end

local function candidateComesFirst(left, right)
    if left.rank ~= right.rank then
        return left.rank < right.rank
    end

    if left.kind == "partial" and (left.candidate.stacks or 0) ~= (right.candidate.stacks or 0) then
        return (left.candidate.stacks or 0) > (right.candidate.stacks or 0)
    end

    if left.spell.priority ~= right.spell.priority then
        return left.spell.priority < right.spell.priority
    end

    if left.candidate.spellId ~= right.candidate.spellId then
        return left.candidate.spellId < right.candidate.spellId
    end

    return (left.candidate.sourceGUID or "") < (right.candidate.sourceGUID or "")
end

function PB.State:EvaluateGroup(group, candidates, options)
    options = options or {}
    local now = options.now or 0
    local warningThreshold = options.warningThreshold or 5

    if options.enabled == false then
        return {
            group = group,
            state = "disabled",
            required = options.required,
            sourceKnown = false,
        }
    end

    local best
    local index
    for index, candidate in ipairs(candidates or {}) do
        local spell = PB.DebuffLibrary.spellsById[candidate.spellId]
        if spell and PB.DebuffLibrary.spellIdToGroupKey[candidate.spellId] == group.key then
            local rank, kind, remaining = classifyCandidate(candidate, spell, now, warningThreshold)
            if rank then
                local evaluated = {
                    rank = rank,
                    kind = kind,
                    remaining = remaining,
                    candidate = candidate,
                    spell = spell,
                }
                if not best or candidateComesFirst(evaluated, best) then
                    best = evaluated
                end
            end
        end
    end

    if not best or best.kind == "recent" then
        return {
            group = group,
            state = options.capability == "notAvailable" and "notAvailable" or "missing",
            required = options.required,
            capability = options.capability or "unknown",
            recentCandidate = best and best.candidate or nil,
            sourceKnown = false,
        }
    end

    return {
        group = group,
        state = best.kind,
        required = options.required,
        candidate = best.candidate,
        spell = best.spell,
        remaining = best.remaining,
        sourceKnown = hasKnownSource(best.candidate),
    }
end

function PB.State:EvaluateGroups(candidatesByGroup, optionsByGroup, sharedOptions)
    local evaluations = {}
    local index
    for index, group in ipairs(PB.DebuffLibrary.groups) do
        local groupOptions = optionsByGroup and optionsByGroup[group.key] or {}
        local options = {
            now = groupOptions.now or (sharedOptions and sharedOptions.now) or 0,
            warningThreshold = groupOptions.warningThreshold or (sharedOptions and sharedOptions.warningThreshold) or 5,
            enabled = groupOptions.enabled,
            required = groupOptions.required,
            capability = groupOptions.capability,
        }
        evaluations[index] = self:EvaluateGroup(group, candidatesByGroup and candidatesByGroup[group.key] or {}, options)
    end
    return evaluations
end

function PB.State:CreateTestEvaluations()
    local now = 1000
    local candidates = {
        spellVulnerability = {
            { spellId = 27228, sourceName = "Drakuzo", sourceGUID = "Player-Test-1", active = true, expiresAt = now + 292 },
        },
        majorArmor = {
            { spellId = 25225, sourceName = "Tankname", sourceGUID = "Player-Test-2", active = true, stacks = 5, expiresAt = now + 24 },
        },
        faerieFire = {
            { spellId = 26993, sourceName = "Druidname", sourceGUID = "Player-Test-3", active = true, expiresAt = now + 4 },
        },
        judgement = {},
        attackPower = {},
        attackSpeed = {
            { spellId = 25264, sourceName = "Tankname", sourceGUID = "Player-Test-2", active = true, expiresAt = now + 18 },
        },
        recklessness = {
            { spellId = 27226, sourceName = "Warlockname", sourceGUID = "Player-Test-4", active = true, expiresAt = now + 86 },
        },
    }
    local options = {
        attackPower = { enabled = true, required = true, capability = "notAvailable" },
    }
    return self:EvaluateGroups(candidates, options, { now = now, warningThreshold = 5 })
end

function PB.State:ResetEncounter()
    self.candidatesByBoss = {}
end

function PB.State:GetUnitDebuffs(unitToken, auraProvider)
    if not unitToken then
        return {}, 0
    end

    return readUnitDebuffs(unitToken, auraProvider)
end

function PB.State:GetBossCandidates(bossGUID)
    local bossCandidates = self.candidatesByBoss[bossGUID]
    if not bossCandidates then
        bossCandidates = {}
        self.candidatesByBoss[bossGUID] = bossCandidates
    end
    return bossCandidates
end

function PB.State:ForgetBoss(bossGUID)
    self.candidatesByBoss[bossGUID] = nil
end

function PB.State:HandleAuraEvent(event)
    local groupKey = PB.DebuffLibrary.spellIdToGroupKey[event.spellId]
    if not groupKey then
        return false
    end

    local observedAt = event.observedAt or event.timestamp

    if event.subevent == "SPELL_AURA_REMOVED" then
        local bossCandidates = self.candidatesByBoss[event.destGUID]
        local groupCandidates = bossCandidates and bossCandidates[groupKey]
        local candidate = groupCandidates and groupCandidates[event.spellId]
        if not candidate then
            return false
        end

        candidate.active = false
        candidate.removedAt = observedAt
        candidate.lastSeenAt = observedAt
        return true
    end

    local bossCandidates = self:GetBossCandidates(event.destGUID)
    local groupCandidates = bossCandidates[groupKey]
    if not groupCandidates then
        groupCandidates = {}
        bossCandidates[groupKey] = groupCandidates
    end

    local candidate = groupCandidates[event.spellId] or {}
    candidate.spellId = event.spellId
    candidate.spellName = event.spellName
    if event.sourceName ~= nil and event.sourceName ~= "" then
        candidate.sourceName = event.sourceName
    end
    if event.sourceGUID ~= nil and event.sourceGUID ~= "" then
        candidate.sourceGUID = event.sourceGUID
    end
    candidate.destGUID = event.destGUID
    candidate.active = true
    candidate.removedAt = nil
    candidate.lastSeenAt = observedAt
    local spell = PB.DebuffLibrary.spellsById[event.spellId]
    if spell and spell.duration
        and event.subevent ~= "SPELL_AURA_REMOVED_DOSE"
    then
        candidate.expiresAt = observedAt + spell.duration
        candidate.durationSource = "known"
    elseif event.subevent ~= "SPELL_AURA_REMOVED_DOSE" then
        candidate.expiresAt = nil
        candidate.durationSource = nil
    end

    if event.subevent == "SPELL_AURA_APPLIED_DOSE" or event.subevent == "SPELL_AURA_REMOVED_DOSE" then
        candidate.stacks = event.amount or candidate.stacks or 1
    elseif not candidate.stacks then
        candidate.stacks = 1
    end

    groupCandidates[event.spellId] = candidate
    return true
end

function PB.State:ExpireBoss(bossGUID, now)
    local bossCandidates = self.candidatesByBoss[bossGUID]
    if not bossCandidates then
        return false
    end

    local changed = false
    local _, groupCandidates
    for _, groupCandidates in pairs(bossCandidates) do
        local _, candidate
        for _, candidate in pairs(groupCandidates) do
            if candidate.active ~= false and candidate.expiresAt and candidate.expiresAt <= now then
                candidate.active = false
                candidate.removedAt = candidate.expiresAt
                changed = true
            end
        end
    end
    return changed
end

function PB.State:ResyncBossUnit(unitToken, bossGUID, auraProvider, now, preserveRecentSeconds, ignoredSpellId)
    if not unitToken or not bossGUID then
        return false, 0
    end

    auraProvider = auraProvider or runtimeAuraProvider
    now = now or GetTime()
    local seenSpellIds = {}
    local trackedCount = 0
    local index
    local auras, inspectedCount = readUnitDebuffs(unitToken, auraProvider)

    for index = 1, #auras do
        local aura = auras[index]
        local groupKey = aura.spellId ~= ignoredSpellId
            and aura.spellId
            and PB.DebuffLibrary.spellIdToGroupKey[aura.spellId]
        if groupKey then
            trackedCount = trackedCount + 1
            seenSpellIds[aura.spellId] = true

            local bossCandidates = self:GetBossCandidates(bossGUID)
            local groupCandidates = bossCandidates[groupKey]
            if not groupCandidates then
                groupCandidates = {}
                bossCandidates[groupKey] = groupCandidates
            end

            local candidate = groupCandidates[aura.spellId] or {}
            candidate.spellId = aura.spellId
            candidate.spellName = aura.name
            candidate.destGUID = bossGUID
            candidate.stacks = aura.stacks and aura.stacks > 0 and aura.stacks or 1
            candidate.active = true
            candidate.removedAt = nil
            candidate.lastSeenAt = now
            candidate.lastScannedAt = now
            candidate.durationSource = "scan"

            if aura.expirationTime and aura.expirationTime > 0 then
                candidate.expiresAt = aura.expirationTime
            else
                local spell = PB.DebuffLibrary.spellsById[aura.spellId]
                candidate.expiresAt = spell and spell.duration and (now + spell.duration) or nil
                candidate.durationSource = candidate.expiresAt and "known" or nil
            end

            if not hasKnownSource(candidate) and aura.sourceUnit then
                candidate.sourceGUID = auraProvider.SourceGUID and auraProvider.SourceGUID(aura.sourceUnit) or nil
                candidate.sourceName = auraProvider.SourceName and auraProvider.SourceName(aura.sourceUnit) or nil
            end

            groupCandidates[aura.spellId] = candidate
        end
    end

    local bossCandidates = self.candidatesByBoss[bossGUID]
    if bossCandidates then
        local _, groupCandidates
        for _, groupCandidates in pairs(bossCandidates) do
            local spellId, candidate
            for spellId, candidate in pairs(groupCandidates) do
                local recentlySeen = preserveRecentSeconds
                    and candidate.lastSeenAt
                    and now - candidate.lastSeenAt <= preserveRecentSeconds
                if candidate.active ~= false and not seenSpellIds[spellId] and not recentlySeen then
                    candidate.active = false
                    candidate.removedAt = now
                    candidate.lastScannedAt = now
                end
            end
        end
    end

    return true, trackedCount, inspectedCount
end

local function candidatesAsArray(candidatesBySpell)
    local candidates = {}
    local _, candidate
    for _, candidate in pairs(candidatesBySpell or {}) do
        candidates[#candidates + 1] = candidate
    end
    return candidates
end

function PB.State:EvaluateBoss(bossGUID, now, warningThreshold, graceActive, settingsByGroup)
    local bossCandidates = self.candidatesByBoss[bossGUID] or {}
    local evaluations = {}
    local index

    for index, group in ipairs(PB.DebuffLibrary.groups) do
        local groupSettings = settingsByGroup and settingsByGroup[group.key]
            or PB.Config and PB.Config:GetGroupSettings(group.key) or {
            enabled = true,
            required = group.required,
        }
        local evaluation = self:EvaluateGroup(
            group,
            candidatesAsArray(bossCandidates[group.key]),
            {
                now = now,
                warningThreshold = warningThreshold,
                enabled = groupSettings.enabled,
                required = groupSettings.required,
                capability = PB.Roster and PB.Roster:GetGroupCapability(group.key) or "unknown",
            }
        )
        if graceActive and evaluation.state == "missing" then
            evaluation.state = "grace"
        end
        evaluations[index] = evaluation
    end

    return evaluations
end
