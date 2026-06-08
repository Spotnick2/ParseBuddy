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
