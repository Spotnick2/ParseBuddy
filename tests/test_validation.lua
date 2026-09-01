ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
}

assert(loadfile("Defaults.lua"))()
assert(loadfile("DebuffLibrary.lua"))()
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

local missingId = 25225
local provider = {
    GetName = function(spellId)
        if spellId == missingId then
            return nil
        end
        return "Spell " .. tostring(spellId)
    end,
}

local result = ParseBuddy:ValidateSpellIds(provider)
assertEqual(result.checked > 0, true, "validation checks tracked IDs")
assertEqual(#result.missingIds, 1, "validation reports missing IDs")
assertEqual(result.missingIds[1], missingId, "missing IDs are deterministic")
assertEqual(string.find(ParseBuddy.messages[1], "tracked IDs available", 1, true) ~= nil, true, "validation prints summary")
assertEqual(string.find(ParseBuddy.messages[2], "group=majorArmor", 1, true) ~= nil, true, "validation identifies missing group")

-- spellIdToGroupKey is flat and last-writer-wins, and EvaluateGroup gates on it,
-- so a duplicate silently hides a spell from whichever group claimed it first.
assertEqual(#ParseBuddy.DebuffLibrary.duplicateSpellIds, 0,
    "no spell ID is claimed by more than one group")

-- State:EvaluateBoss falls back to the library's own defaults when a group has
-- no stored settings, so the two sources must not drift.
local _, libraryGroup
for _, libraryGroup in ipairs(ParseBuddy.DebuffLibrary.groups) do
    local shipped = ParseBuddy.Defaults.settings.groups[libraryGroup.key]
    assertEqual(shipped ~= nil, true,
        "group " .. libraryGroup.key .. " has shipped settings")
    assertEqual(libraryGroup.required, shipped.required,
        "group " .. libraryGroup.key .. " requirement matches shipped settings")
    assertEqual(libraryGroup.visibility, shipped.visibility,
        "group " .. libraryGroup.key .. " visibility matches shipped settings")
end

print("ParseBuddy validation tests passed: " .. testsRun)
