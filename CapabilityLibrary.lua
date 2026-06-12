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
    },
}

function PB.CapabilityLibrary:CanClassProvide(groupKey, classFile)
    local classes = self.groupClasses[groupKey]
    return classes ~= nil and classFile ~= nil and classes[classFile] == true
end
