ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
}

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

print("ParseBuddy validation tests passed: " .. testsRun)
