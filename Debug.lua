local PB = ParseBuddy

local PREFIX = "|cff7fc8ffParseBuddy:|r "

function PB:Print(message)
    print(PREFIX .. tostring(message))
end

function PB:Debug(message)
    if ParseBuddyDB and ParseBuddyDB.debug then
        self:Print("Debug: " .. tostring(message))
    end
end

function PB:Dump()
    local lines
    if self.Encounter and self.Encounter.BuildDumpLines then
        lines = self.Encounter:BuildDumpLines()
    else
        lines = { "ParseBuddy dump unavailable: encounter module not ready." }
    end

    local index
    for index = 1, #lines do
        self:Print(lines[index])
    end
end

function PB:ValidateSpellIds(spellProvider)
    local result = self.DebuffLibrary:ValidateSpellIds(spellProvider)
    self:Print(string.format(
        "Spell validation: %d/%d tracked IDs available; %d missing.",
        result.valid,
        result.checked,
        #result.missingIds
    ))

    local index
    for index = 1, #result.missingIds do
        local spellId = result.missingIds[index]
        self:Print(string.format(
            "Missing spell ID %d (group=%s).",
            spellId,
            tostring(self.DebuffLibrary.spellIdToGroupKey[spellId])
        ))
    end
    return result
end
