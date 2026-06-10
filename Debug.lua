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
