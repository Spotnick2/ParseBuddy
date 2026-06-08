local PB = ParseBuddy

PB.DebuffLibrary = {
    groups = {
        {
            key = "spellVulnerability",
            label = "Spell Vulnerability",
            missingText = "CoE / CoS",
            required = true,
            mode = "any",
            spells = {
                { displayName = "CoE", spellIds = { 1490, 11721, 11722, 27228 } },
                { displayName = "CoS", spellIds = { 17862, 17937, 27229 } },
            },
        },
        {
            key = "majorArmor",
            label = "Armor",
            missingText = "Sunder / Expose",
            required = true,
            mode = "any",
            spells = {
                { displayName = "Sunder", spellIds = { 7386, 7405, 8380, 11596, 11597, 25225 }, requiredStacks = 5 },
                { displayName = "Expose", spellIds = { 8647, 8649, 8650, 11197, 11198, 26866 } },
            },
        },
        {
            key = "faerieFire",
            label = "Faerie Fire",
            missingText = "Faerie Fire",
            required = true,
            mode = "any",
            spells = {
                { displayName = "Faerie Fire", spellIds = { 770, 778, 9749, 9907, 26993 } },
                { displayName = "Faerie Fire", spellIds = { 16857, 17390, 17391, 17392, 27011 } },
            },
        },
        {
            key = "judgement",
            label = "Judgement",
            missingText = "Wisdom / Light",
            required = true,
            mode = "any",
            spells = {
                { displayName = "Wisdom", spellIds = { 20186, 20354, 20355, 27164 } },
                { displayName = "Light", spellIds = { 20185, 20344, 20345, 20346, 27162 } },
            },
        },
        {
            key = "attackPower",
            label = "Attack Power",
            missingText = "Demo Shout / Roar",
            required = true,
            mode = "any",
            spells = {
                { displayName = "Demo Shout", spellIds = { 1160, 6190, 11554, 11555, 11556, 25203 } },
                { displayName = "Demo Roar", spellIds = { 99, 1735, 9490, 9747, 9898, 26998 } },
            },
        },
        {
            key = "attackSpeed",
            label = "Attack Speed",
            missingText = "Thunder Clap",
            required = true,
            mode = "any",
            spells = {
                { displayName = "Thunder Clap", spellIds = { 6343, 8198, 8204, 8205, 11580, 11581, 25264 } },
            },
        },
    },
    groupsByKey = {},
    spellIdToGroupKey = {},
    spellsById = {},
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
                self.spellIdToGroupKey[spellId] = group.key
                self.spellsById[spellId] = spell
            end
        end
    end
end

PB.DebuffLibrary:BuildLookups()
