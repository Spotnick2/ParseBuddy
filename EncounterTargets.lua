local PB = ParseBuddy

PB.EncounterTargets = {
    encounters = {
        -- Verified from local WoWCombatLog-061126_194827.txt, encounter 655 on 2026-06-11.
        [655] = {
            name = "Opera Hall",
            npcIds = {
                [17533] = "Romulo",
                [17534] = "Julianne",
            },
        },
    },
}

function PB.EncounterTargets:Get(encounterId)
    return encounterId and self.encounters[encounterId] or nil
end

function PB.EncounterTargets:GetNPCId(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local unitType, npcId = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if unitType ~= "Creature" and unitType ~= "Vehicle" then
        return nil
    end
    return tonumber(npcId)
end

function PB.EncounterTargets:IsRegistered(encounterId, guid)
    local encounter = self:Get(encounterId)
    local npcId = self:GetNPCId(guid)
    return encounter ~= nil and npcId ~= nil and encounter.npcIds[npcId] ~= nil, npcId
end
