local PB = ParseBuddy

PB.State = {
    candidatesByBoss = {},
}

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
            state = "missing",
            recentCandidate = best and best.candidate or nil,
            sourceKnown = false,
        }
    end

    return {
        group = group,
        state = best.kind,
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
    }
    local options = {
        attackPower = { enabled = false },
    }
    return self:EvaluateGroups(candidates, options, { now = now, warningThreshold = 5 })
end

function PB.State:ResetEncounter()
    self.candidatesByBoss = {}
end

function PB.State:GetBossCandidates(bossGUID)
    local bossCandidates = self.candidatesByBoss[bossGUID]
    if not bossCandidates then
        bossCandidates = {}
        self.candidatesByBoss[bossGUID] = bossCandidates
    end
    return bossCandidates
end

function PB.State:HandleAuraEvent(event)
    local groupKey = PB.DebuffLibrary.spellIdToGroupKey[event.spellId]
    if not groupKey then
        return false
    end

    local bossCandidates = self:GetBossCandidates(event.destGUID)
    local groupCandidates = bossCandidates[groupKey]
    if not groupCandidates then
        groupCandidates = {}
        bossCandidates[groupKey] = groupCandidates
    end

    if event.subevent == "SPELL_AURA_REMOVED" then
        groupCandidates[event.spellId] = nil
        return true
    end

    local candidate = groupCandidates[event.spellId] or {}
    candidate.spellId = event.spellId
    candidate.spellName = event.spellName
    candidate.sourceName = event.sourceName
    candidate.sourceGUID = event.sourceGUID
    candidate.destGUID = event.destGUID
    candidate.active = true
    candidate.removedAt = nil
    candidate.lastSeenAt = event.timestamp

    if event.subevent == "SPELL_AURA_APPLIED_DOSE" or event.subevent == "SPELL_AURA_REMOVED_DOSE" then
        candidate.stacks = event.amount or candidate.stacks or 1
    elseif not candidate.stacks then
        candidate.stacks = 1
    end

    groupCandidates[event.spellId] = candidate
    return true
end

local function candidatesAsArray(candidatesBySpell)
    local candidates = {}
    local _, candidate
    for _, candidate in pairs(candidatesBySpell or {}) do
        candidates[#candidates + 1] = candidate
    end
    return candidates
end

function PB.State:EvaluateBoss(bossGUID, now, warningThreshold, graceActive)
    local bossCandidates = self.candidatesByBoss[bossGUID] or {}
    local evaluations = {}
    local index

    for index, group in ipairs(PB.DebuffLibrary.groups) do
        local evaluation = self:EvaluateGroup(
            group,
            candidatesAsArray(bossCandidates[group.key]),
            { now = now, warningThreshold = warningThreshold }
        )
        if graceActive and evaluation.state == "missing" then
            evaluation.state = "grace"
        end
        evaluations[index] = evaluation
    end

    return evaluations
end
