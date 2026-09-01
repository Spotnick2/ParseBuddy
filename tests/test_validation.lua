ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
}

assert(loadfile("Defaults.lua"))()
assert(loadfile("DebuffLibrary.lua"))()
assert(loadfile("CapabilityLibrary.lua"))()
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

    -- A group with no capability entry resolves to notAvailable for every class,
    -- which hides it and blocks its alerts without raising anything.
    local classes = ParseBuddy.CapabilityLibrary.groupClasses[libraryGroup.key]
    assertEqual(type(classes), "table",
        "group " .. libraryGroup.key .. " declares which classes can provide it")
    local providerCount = 0
    local _class
    for _class in pairs(classes) do
        providerCount = providerCount + 1
    end
    assertEqual(providerCount > 0, true,
        "group " .. libraryGroup.key .. " names at least one provider class")

    -- Every spell needs a duration unless it explicitly defers to the client's
    -- reported expiry. Without either, HandleAuraEvent cannot set a fallback
    -- expiry and a missed removal leaves the row up indefinitely.
    local _, spell
    for _, spell in ipairs(libraryGroup.spells) do
        local bounded = spell.clientDuration == true
            or (type(spell.duration) == "number" and spell.duration > 0)
        assertEqual(bounded, true,
            "spell " .. tostring(spell.displayName) .. " has a bounded expiry")
    end
end

print("ParseBuddy validation tests passed: " .. testsRun)
