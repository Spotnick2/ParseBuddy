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
    if self.Encounter and self.Encounter.active and self.Encounter.BuildDumpLines then
        lines = self.Encounter:BuildDumpLines()
    elseif self.lastEncounterSnapshot and self.lastEncounterSnapshot.lines then
        lines = self.lastEncounterSnapshot.lines
    else
        lines = { "ParseBuddy dump unavailable: no active encounter or saved snapshot." }
    end

    local index
    for index = 1, #lines do
        self:Print(lines[index])
    end
end

function PB:PrintSnapshot()
    local snapshot = self.lastEncounterSnapshot
    if not snapshot or not snapshot.lines then
        self:Print("No encounter snapshot is available.")
        return false
    end

    local index
    for index = 1, #snapshot.lines do
        self:Print(snapshot.lines[index])
    end
    return true
end

function PB:ClearSnapshot()
    self.lastEncounterSnapshot = nil
    if ParseBuddyDB then
        ParseBuddyDB.lastEncounterSnapshot = nil
    end
    self:Print("Encounter snapshot cleared.")
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
