local PB = ParseBuddy

PB.CapabilityLibrary = {
    groupClasses = {
        spellVulnerability = { WARLOCK = true },
        majorArmor = { WARRIOR = true, ROGUE = true },
        faerieFire = { DRUID = true },
        judgement = { PALADIN = true },
        attackPower = { WARRIOR = true, DRUID = true },
        attackSpeed = { WARRIOR = true },
        recklessness = { WARLOCK = true },
        fireVulnerability = { MAGE = true },
        wintersChill = { MAGE = true },
        shadowVulnerability = { WARLOCK = true },
        shadowWeaving = { PRIEST = true },
        misery = { PRIEST = true },
        shadowEmbrace = { WARLOCK = true },
        mangle = { DRUID = true },
        hemorrhage = { ROGUE = true },
        insectSwarm = { DRUID = true },
        exposeWeakness = { HUNTER = true },
        crusaderJudgement = { PALADIN = true },
    },
}

function PB.CapabilityLibrary:CanClassProvide(groupKey, classFile)
    local classes = self.groupClasses[groupKey]
    return classes ~= nil and classFile ~= nil and classes[classFile] == true
end
