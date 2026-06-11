ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
    Encounter = { active = false },
}
ParseBuddyDB = {}

assert(loadfile("Debug.lua"))()

ParseBuddy.Print = function(self, message)
    self.messages[#self.messages + 1] = message
end

local testsRun = 0
local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

ParseBuddy:Dump()
assertEqual(ParseBuddy.messages[1], "ParseBuddy dump unavailable: no active encounter or saved snapshot.", "dump explains missing snapshot")

local snapshot = { lines = { "ParseBuddy dump:", "Snapshot: Test Boss" } }
ParseBuddy.lastEncounterSnapshot = snapshot
ParseBuddyDB.lastEncounterSnapshot = snapshot
ParseBuddy:Dump()
assertEqual(ParseBuddy.messages[2], "ParseBuddy dump:", "out-of-combat dump prints snapshot")
assertEqual(ParseBuddy.messages[3], "Snapshot: Test Boss", "snapshot lines preserved")

assertEqual(ParseBuddy:PrintSnapshot(), true, "explicit snapshot command succeeds")
ParseBuddy:ClearSnapshot()
assertEqual(ParseBuddy.lastEncounterSnapshot, nil, "clear removes in-memory snapshot")
assertEqual(ParseBuddyDB.lastEncounterSnapshot, nil, "clear removes persisted snapshot")
assertEqual(ParseBuddy:PrintSnapshot(), false, "snapshot command reports cleared state")

print("ParseBuddy snapshot tests passed: " .. testsRun)
