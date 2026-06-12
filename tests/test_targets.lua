ParseBuddy = {}

assert(loadfile("EncounterTargets.lua"))()

local Targets = ParseBuddy.EncounterTargets
local testsRun = 0

local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

assertEqual(Targets:GetNPCId("Creature-0-6066-532-101283-17534-00002B6322"), 17534, "Creature GUID NPC ID parsed")
assertEqual(Targets:GetNPCId("Vehicle-0-1-2-3-17533-ABCDEF"), 17533, "Vehicle GUID NPC ID parsed")
assertEqual(Targets:GetNPCId("Player-6064-02BB596E"), nil, "player GUID rejected")
assertEqual(Targets:GetNPCId("Creature-invalid"), nil, "malformed GUID rejected")

local registered, npcId = Targets:IsRegistered(655, "Creature-0-6066-532-101283-17534-00002B6322")
assertEqual(registered, true, "Julianne registered for Opera Hall")
assertEqual(npcId, 17534, "Julianne NPC ID returned")
registered, npcId = Targets:IsRegistered(655, "Creature-0-6066-532-101283-17533-00002B634D")
assertEqual(registered, true, "Romulo registered for Opera Hall")
assertEqual(npcId, 17533, "Romulo NPC ID returned")
registered = Targets:IsRegistered(655, "Creature-0-6066-532-101283-17229-ADD")
assertEqual(registered, false, "Opera Hall add rejected")
assertEqual(Targets:Get(999), nil, "unconfigured encounter has no registry")

print("ParseBuddy target registry tests passed: " .. testsRun)
