ParseBuddy = {
    version = "0.1.8.0",
    messages = {},
    Print = function(self, message) self.messages[#self.messages + 1] = message end,
}
ParseBuddyDB = {
    frame = { locked = false, scale = 1, opacity = 1 },
    debug = false,
    summaryAuto = false,
}
ParseBuddyCharDB = {}

assert(loadfile("DebuffLibrary.lua"))()
assert(loadfile("Defaults.lua"))()

local actionCalls = {}
ParseBuddy.UI = {
    Lock = function() ParseBuddyDB.frame.locked = true; actionCalls.lock = (actionCalls.lock or 0) + 1 end,
    Unlock = function() ParseBuddyDB.frame.locked = false; actionCalls.unlock = (actionCalls.unlock or 0) + 1 end,
    SetScale = function(_, value) ParseBuddyDB.frame.scale = tonumber(value); actionCalls.scale = value end,
    SetOpacity = function(_, value) ParseBuddyDB.frame.opacity = tonumber(value); actionCalls.opacity = value end,
    ResetPosition = function() ParseBuddyDB.frame.scale = 1; ParseBuddyDB.frame.opacity = 1; actionCalls.reset = true end,
    ShowTestMode = function() actionCalls.testFrame = true end,
}
ParseBuddy.Roster = {
    GetGroupCapability = function(_, key)
        if key == "judgement" then return "notAvailable" end
        if key == "recklessness" then return "unknown" end
        return "available"
    end,
    Print = function() actionCalls.roster = true end,
}
ParseBuddy.Encounter = {
    active = false,
    RefreshDisplay = function() actionCalls.refresh = (actionCalls.refresh or 0) + 1 end,
    DebugScan = function() actionCalls.debugScan = true end,
}
ParseBuddy.Broadcast = { Test = function() actionCalls.testAlert = true; return true end }
ParseBuddy.ValidateSpellIds = function() actionCalls.validate = true end
ParseBuddy.Dump = function() actionCalls.dump = true end

assert(loadfile("Config.lua"))()
ParseBuddy.Defaults:Apply(ParseBuddyDB)
ParseBuddy.Config:Initialize()
assert(loadfile("ConfigModel.lua"))()
assert(loadfile("ConfigPanel.lua"))()

local testsRun = 0
local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local Model = ParseBuddy.ConfigPanelModel
local state = Model:GetState()
assertEqual(state.scope, "global", "panel starts on active global scope")
assertEqual(state.displayMode, "PROBLEMS_ONLY", "panel reads live global display mode")
assertEqual(state.groups.judgement.availability, "Not Available", "panel reads cached roster capability")
assertEqual(state.groups.recklessness.availability, "Unknown", "panel presents unknown roster capability")

assertEqual(Model:SetDisplayMode("FULL_LIST"), true, "display mode interaction accepted")
assertEqual(ParseBuddyDB.settings.displayMode, "FULL_LIST", "display mode writes global settings")
assertEqual(Model:SetShowUnavailable(true), true, "unavailable interaction accepted")
assertEqual(ParseBuddyDB.settings.showUnavailable, true, "unavailable visibility writes global settings")
assertEqual(Model:SetGroupValue("majorArmor", "required", false), true, "group requirement interaction accepted")
assertEqual(ParseBuddyDB.settings.groups.majorArmor.required, false, "required checkbox unchecked writes optional")

assertEqual(Model:SetScope("personal"), true, "personal scope selected")
assertEqual(ParseBuddyCharDB.activeScope, "personal", "active scope persists per character")
assertEqual(ParseBuddyCharDB.settings.displayMode, "FULL_LIST", "first personal selection copies current global settings")
assertEqual(ParseBuddyCharDB.settings.groups.majorArmor.required, false, "personal first-use copy includes group settings")
Model:SetDisplayMode("PROBLEMS_ONLY")
Model:SetGroupValue("majorArmor", "required", true)
assertEqual(ParseBuddyCharDB.settings.displayMode, "PROBLEMS_ONLY", "personal display setting changes independently")
assertEqual(ParseBuddyDB.settings.displayMode, "FULL_LIST", "global display setting remains preserved")
assertEqual(ParseBuddyCharDB.settings.groups.majorArmor.required, true, "personal group setting changes independently")
assertEqual(ParseBuddyDB.settings.groups.majorArmor.required, false, "global group setting remains preserved")

Model:SetAlertsEnabled(true)
Model:SetAlertChannel("leader")
Model:SetAlertDelay(90)
assertEqual(ParseBuddyCharDB.settings.broadcast.enabled, true, "broadcast enabled writes active personal scope")
assertEqual(ParseBuddyCharDB.settings.broadcast.channel, "leader", "broadcast destination writes active personal scope")
assertEqual(ParseBuddyCharDB.settings.broadcast.delay, 60, "broadcast delay clamps and persists")
assertEqual(Model:AreAlertControlsEnabled(), true, "alert subordinate controls follow live master setting")

Model:SetFrameLocked(true)
Model:SetSliderValue("scale", 1.8, 0.6, 1.4, 0.05)
Model:SetSliderValue("opacity", 0.1, 0.2, 1, 0.05)
assertEqual(ParseBuddyDB.frame.locked, true, "frame lock remains account-wide")
assertEqual(ParseBuddyDB.frame.scale, 1.4, "frame scale clamps and remains account-wide")
assertEqual(ParseBuddyDB.frame.opacity, 0.2, "frame opacity clamps and remains account-wide")

Model:SetSummaryAuto(true)
Model:SetDebug(true)
assertEqual(ParseBuddyDB.summaryAuto, true, "summary auto writes account-wide setting")
assertEqual(ParseBuddyDB.debug, true, "debug output writes account-wide setting")
assertEqual(#ParseBuddy.messages, 0, "panel setting changes do not spam chat output")
assertEqual(Model:ToggleDiagnostics(), true, "diagnostics expand locally")
assertEqual(Model:ToggleDiagnostics(), false, "diagnostics collapse locally")

Model:RunAction("Test Frame")
Model:RunAction("Reset Position")
Model:RunAction("Test Alert")
Model:RunAction("Validate Spell IDs")
Model:RunAction("Roster")
Model:RunAction("Debug Scan")
Model:RunAction("Dump")
assertEqual(actionCalls.testFrame, true, "test frame routes to live UI action")
assertEqual(actionCalls.reset, true, "reset routes to live UI action")
assertEqual(actionCalls.testAlert, true, "test alert routes to guarded broadcast test")
assertEqual(actionCalls.validate, true, "validate routes to spell validation")
assertEqual(actionCalls.roster, true, "roster routes to cached diagnostics")
assertEqual(actionCalls.debugScan, true, "debug scan routes to encounter diagnostics")
assertEqual(actionCalls.dump, true, "dump routes to diagnostics")

local selectedStyle = ParseBuddy.ConfigPanel:GetSegmentStyle(true, true)
local unselectedStyle = ParseBuddy.ConfigPanel:GetSegmentStyle(false, true)
local disabledStyle = ParseBuddy.ConfigPanel:GetSegmentStyle(true, false)
assertEqual(selectedStyle ~= unselectedStyle, true, "selected segment has distinct style metadata")
assertEqual(selectedStyle.border[1] > unselectedStyle.border[1], true, "selected segment border is visually stronger")
assertEqual(disabledStyle.text[1] < selectedStyle.text[1], true, "disabled segment remains distinct")
assertEqual(ParseBuddy.ConfigPanel:GetAvailabilityStyle("Available")[2] > 0.8, true, "available presentation is green")

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
    RegisterAddOn = function(value) if value == category then modernRegistered = modernRegistered + 1 end end,
    OpenSettings = function(value) modernOpened = value:GetID() end,
}
Settings = { RegisterCanvasLayoutCategory = function() end, RegisterAddOnCategory = function() end }
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
    RegisterLegacy = function(value) if value == panel then legacyRegistered = legacyRegistered + 1 end end,
    OpenLegacy = function(value) if value == panel then legacyOpened = legacyOpened + 1 end end,
}
assertEqual(Panel:DetectAPI(legacyAPI), "legacy", "legacy API selected when Settings API unavailable")
assertEqual(Panel:Register(panel, legacyAPI), true, "legacy panel registration succeeds")
assertEqual(legacyRegistered, 1, "legacy category registered")
assertEqual(Panel:Open(), true, "legacy panel opens")
assertEqual(legacyOpened, 1, "legacy panel passed to opener")

InterfaceOptions_AddCategory = nil
assertEqual(Panel:DetectAPI({}), "none", "missing configuration APIs detected")

print("ParseBuddy Config panel tests passed: " .. testsRun)
