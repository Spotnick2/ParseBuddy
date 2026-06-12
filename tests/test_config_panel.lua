ParseBuddy = {
    version = "0.1.7.12",
    messages = {},
    Print = function(self, message) self.messages[#self.messages + 1] = message end,
}
ParseBuddyDB = { marker = "account", nested = { value = 1 } }
ParseBuddyCharDB = { marker = "character", nested = { value = 2 } }

assert(loadfile("DebuffLibrary.lua"))()
assert(loadfile("ConfigPrototype.lua"))()
assert(loadfile("ConfigPanel.lua"))()

local testsRun = 0
local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local Prototype = ParseBuddy.ConfigPrototype
local state = Prototype:GetState()
assertEqual(state.scope, "global", "prototype defaults to global display")
assertEqual(state.displayMode, "PROBLEMS_ONLY", "prototype display mode deterministic")
assertEqual(state.alerts.enabled, false, "prototype alerts default off")
assertEqual(state.diagnosticsExpanded, false, "diagnostics default collapsed")
assertEqual(state.groups.judgement.availability, "Not Available", "fake availability deterministic")

assertEqual(Prototype:SetScope("personal"), true, "prototype scope interaction accepted")
assertEqual(Prototype:SetDisplayMode("FULL_LIST"), true, "prototype display interaction accepted")
Prototype:SetValue("showUnavailable", true)
Prototype:SetGroupValue("majorArmor", "required", false)
Prototype:SetAlertsEnabled(true)
Prototype:SetAlertChannel("leader")
Prototype:SetAlertDelay(8)
assertEqual(state.scope, "personal", "prototype scope updates local state")
assertEqual(state.displayMode, "FULL_LIST", "prototype mode updates local state")
assertEqual(state.showUnavailable, true, "prototype checkbox updates local state")
assertEqual(state.groups.majorArmor.required, false, "prototype group interaction updates local state")
assertEqual(Prototype:AreAlertControlsEnabled(), true, "alert subordinate controls enabled with master")
assertEqual(state.alerts.channel, "leader", "prototype alert channel updates")
assertEqual(state.alerts.delay, 8, "prototype alert delay updates")
Prototype:SetAlertsEnabled(false)
assertEqual(Prototype:AreAlertControlsEnabled(), false, "alert subordinate controls disable with master")
assertEqual(Prototype:ToggleDiagnostics(), true, "diagnostics expand interaction")
assertEqual(Prototype:ToggleDiagnostics(), false, "diagnostics collapse interaction")
Prototype:RecordAction("Test Frame")
assertEqual(state.lastAction, "Test Frame", "prototype action remains local")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "No live setting was changed", 1, true) ~= nil, true, "prototype action clearly reports no live mutation")

assertEqual(ParseBuddyDB.marker, "account", "prototype leaves account saved variables untouched")
assertEqual(ParseBuddyDB.nested.value, 1, "prototype leaves nested account data untouched")
assertEqual(ParseBuddyCharDB.marker, "character", "prototype leaves character saved variables untouched")
assertEqual(ParseBuddyCharDB.nested.value, 2, "prototype leaves nested character data untouched")

local Panel = ParseBuddy.ConfigPanel
local modernRegistered = 0
local modernOpened
local category = { GetID = function() return 44 end }
local modernAPI = {
    RegisterCanvas = function(panel, name)
        assertEqual(panel.name, "ParseBuddy", "modern registration receives panel")
        assertEqual(name, "ParseBuddy", "modern registration receives category name")
        return category
    end,
    RegisterAddOn = function(value)
        if value == category then modernRegistered = modernRegistered + 1 end
    end,
    OpenSettings = function(value) modernOpened = value:GetID() end,
}
Settings = {
    RegisterCanvasLayoutCategory = function() end,
    RegisterAddOnCategory = function() end,
}
InterfaceOptions_AddCategory = function() end
local panel = { name = "ParseBuddy" }
assertEqual(Panel:DetectAPI(modernAPI), "settings", "modern Settings API preferred")
assertEqual(Panel:Register(panel, modernAPI), true, "modern panel registration succeeds")
assertEqual(modernRegistered, 1, "modern addon category registered")
assertEqual(Panel:Open(), true, "modern panel opens")
assertEqual(modernOpened, 44, "modern category ID used when opening")

Settings = nil
local legacyRegistered = 0
local legacyOpened = 0
local legacyAPI = {
    RegisterLegacy = function(value)
        if value == panel then legacyRegistered = legacyRegistered + 1 end
    end,
    OpenLegacy = function(value)
        if value == panel then legacyOpened = legacyOpened + 1 end
    end,
}
assertEqual(Panel:DetectAPI(legacyAPI), "legacy", "legacy API selected when Settings API unavailable")
assertEqual(Panel:Register(panel, legacyAPI), true, "legacy panel registration succeeds")
assertEqual(legacyRegistered, 1, "legacy category registered")
assertEqual(Panel:Open(), true, "legacy panel opens")
assertEqual(legacyOpened, 1, "legacy panel passed to opener")

InterfaceOptions_AddCategory = nil
assertEqual(Panel:DetectAPI({}), "none", "missing configuration APIs detected")

print("ParseBuddy Config panel tests passed: " .. testsRun)
