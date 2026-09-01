local PB = ParseBuddy

PB.DebuffLibrary = {
    groups = {
        {
            key = "spellVulnerability",
            label = "Spell Vulnerability",
            missingText = "CoE / CoS",
            required = true,
            visibility = "always",
            mode = "any",
            spells = {
                { displayName = "CoE", spellIds = { 1490, 11721, 11722, 27228 }, duration = 300 },
                { displayName = "CoS", spellIds = { 17862, 17937, 27229 }, duration = 300 },
            },
        },
        {
            key = "majorArmor",
            label = "Armor",
            missingText = "Sunder / Expose",
            required = true,
            visibility = "always",
            mode = "any",
            spells = {
                { displayName = "Sunder", spellIds = { 7386, 7405, 8380, 11596, 11597, 25225 }, requiredStacks = 5, duration = 30 },
                -- Expose Armor carries no static duration here by design: its expiry is
                -- taken from the client during an aura scan instead.
                { displayName = "Expose", spellIds = { 8647, 8649, 8650, 11197, 11198, 26866 }, clientDuration = true },
            },
        },
        {
            key = "faerieFire",
            label = "Faerie Fire",
            missingText = "Faerie Fire",
            required = true,
            visibility = "always",
            mode = "any",
            spells = {
                { displayName = "Faerie Fire", spellIds = { 770, 778, 9749, 9907, 26993 }, duration = 40 },
                { displayName = "Faerie Fire", spellIds = { 16857, 17390, 17391, 17392, 27011 }, duration = 40 },
            },
        },
        {
            key = "judgement",
            label = "Judgement",
            missingText = "Wisdom / Light",
            required = true,
            visibility = "always",
            mode = "any",
            spells = {
                { displayName = "Wisdom", spellIds = { 20186, 20354, 20355, 27164 }, duration = 20 },
                { displayName = "Light", spellIds = { 20185, 20344, 20345, 20346, 27162 }, duration = 20 },
            },
        },
        {
            key = "attackPower",
            label = "Attack Power",
            missingText = "Demo Shout / Roar",
            required = true,
            visibility = "always",
            mode = "any",
            spells = {
                { displayName = "Demo Shout", spellIds = { 1160, 6190, 11554, 11555, 11556, 25203 }, duration = 30 },
                { displayName = "Demo Roar", spellIds = { 99, 1735, 9490, 9747, 9898, 26998 }, duration = 30 },
            },
        },
        {
            key = "attackSpeed",
            label = "Attack Speed",
            missingText = "Thunder Clap",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Thunder Clap", spellIds = { 6343, 8198, 8204, 8205, 11580, 11581, 25264 }, duration = 30 },
            },
        },
        {
            key = "recklessness",
            label = "Armor Support",
            missingText = "Curse of Recklessness",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Recklessness", spellIds = { 704, 7658, 7659, 11717, 27226 }, duration = 120 },
            },
        },
        -- The groups below were built from spell IDs, durations and stack counts
        -- observed directly in this project's own combat logs, cross-checked
        -- against LibClassicDurations where that database covers them. Only IDs
        -- with direct evidence are listed: a rank nobody in a level 70 raid casts
        -- is better omitted than guessed, and an unlisted rank simply goes
        -- uncredited rather than being mis-attributed.
        --
        -- All of them are talent-gated rather than class-gated, so they ship as
        -- applied-only. Class presence alone must never claim one is missing.
        {
            key = "fireVulnerability",
            label = "Fire Vulnerability",
            missingText = "Improved Scorch",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Fire Vuln", spellIds = { 22959 }, requiredStacks = 5, duration = 30 },
            },
        },
        {
            key = "wintersChill",
            label = "Winter's Chill",
            missingText = "Winter's Chill",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Winter's Chill", spellIds = { 12579 }, requiredStacks = 5, duration = 15 },
            },
        },
        {
            key = "shadowVulnerability",
            label = "Shadow Vulnerability",
            missingText = "Improved Shadow Bolt",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Shadow Vuln", spellIds = { 17794, 17797, 17798, 17799, 17800 }, requiredStacks = 4, duration = 12 },
            },
        },
        {
            key = "shadowWeaving",
            label = "Shadow Weaving",
            missingText = "Shadow Weaving",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Shadow Weaving", spellIds = { 15258 }, requiredStacks = 5, duration = 15 },
            },
        },
        {
            key = "misery",
            label = "Misery",
            missingText = "Misery",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Misery", spellIds = { 33200 }, duration = 24 },
            },
        },
        {
            key = "shadowEmbrace",
            label = "Shadow Embrace",
            missingText = "Shadow Embrace",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Shadow Embrace", spellIds = { 32390 }, duration = 12 },
            },
        },
        {
            key = "mangle",
            label = "Bleed Damage",
            missingText = "Mangle",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Mangle (Bear)", spellIds = { 33987 }, duration = 12 },
                { displayName = "Mangle (Cat)", spellIds = { 33983 }, duration = 12 },
            },
        },
        {
            key = "hemorrhage",
            label = "Hemorrhage",
            missingText = "Hemorrhage",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Hemorrhage", spellIds = { 16511, 17347, 17348 }, duration = 15 },
            },
        },
        {
            key = "insectSwarm",
            label = "Insect Swarm",
            missingText = "Insect Swarm",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Insect Swarm", spellIds = { 5570, 24974, 24975, 24976, 24977 }, duration = 12 },
            },
        },
        {
            key = "exposeWeakness",
            label = "Expose Weakness",
            missingText = "Expose Weakness",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Expose Weakness", spellIds = { 34501 }, duration = 7 },
            },
        },
        {
            key = "crusaderJudgement",
            label = "Crusader",
            missingText = "Judgement of the Crusader",
            required = false,
            visibility = "applied",
            mode = "any",
            spells = {
                { displayName = "Crusader", spellIds = { 21183, 20188, 20300, 20301, 20302, 20303, 27159 }, duration = 20 },
            },
        },
    },
    groupsByKey = {},
    spellIdToGroupKey = {},
    spellsById = {},
    duplicateSpellIds = {},
}

function PB.DebuffLibrary:BuildLookups()
    local groupIndex
    for groupIndex, group in ipairs(self.groups) do
        self.groupsByKey[group.key] = group

        local spellIndex
        for spellIndex, spell in ipairs(group.spells) do
            spell.priority = spellIndex

            local idIndex
            for idIndex, spellId in ipairs(spell.spellIds) do
                -- These maps are flat and last-writer-wins, and EvaluateGroup
                -- gates on spellIdToGroupKey matching the group it is scoring.
                -- A duplicate would silently hide the spell from whichever group
                -- registered it first, so record the collision for the tests.
                if self.spellIdToGroupKey[spellId] ~= nil then
                    self.duplicateSpellIds[#self.duplicateSpellIds + 1] = spellId
                end
                self.spellIdToGroupKey[spellId] = group.key
                self.spellsById[spellId] = spell
            end
        end
    end
end

PB.DebuffLibrary:BuildLookups()

local runtimeSpellProvider = {
    GetName = function(spellId)
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellId)
            if type(info) == "table" then
                return info.name
            end
            return info
        end
        if GetSpellInfo then
            return GetSpellInfo(spellId)
        end
        return nil
    end,
}

function PB.DebuffLibrary:ValidateSpellIds(spellProvider)
    spellProvider = spellProvider or runtimeSpellProvider
    local result = {
        checked = 0,
        valid = 0,
        missingIds = {},
    }

    local spellId
    for spellId in pairs(self.spellIdToGroupKey) do
        result.checked = result.checked + 1
        if spellProvider.GetName(spellId) then
            result.valid = result.valid + 1
        else
            result.missingIds[#result.missingIds + 1] = spellId
        end
    end
    table.sort(result.missingIds)
    return result
end
