ParseBuddy = ParseBuddy or {}

local addonName = ...
local PB = ParseBuddy

PB.addonName = addonName or "ParseBuddy"

local function trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function showHelp()
    PB:Print("Commands: /pb help, test, mode [problems|full], profile [global|personal], groups, group <key> [enable|disable|required|optional], summary [auto on|off], dump, snapshot, clear, debugscan, validate, lock, unlock, reset, scale [0.6-1.4], opacity [0.2-1.0], debug")
end

function PB:HandleSlashCommand(message)
    local input = trim(message):lower()
    local command, argument = input:match("^(%S+)%s*(.-)$")
    command = command or ""

    if command == "" or command == "help" then
        showHelp()
    elseif command == "test" then
        PB.UI:ShowTestMode()
    elseif command == "mode" then
        PB.UI:SetDisplayMode(argument)
    elseif command == "profile" then
        PB.Config:SetScope(argument)
    elseif command == "group" then
        PB.Config:HandleGroupCommand(argument)
    elseif command == "groups" then
        PB.Config:PrintGroups()
    elseif command == "summary" then
        local summaryCommand, summaryValue = argument:match("^(%S*)%s*(.-)$")
        if summaryCommand == "auto" then
            PB.Summary:SetAuto(summaryValue)
        elseif summaryCommand == "" then
            PB.Summary:Print()
        else
            PB:Print("Summary command must be '/pb summary' or '/pb summary auto on|off'.")
        end
    elseif command == "lock" then
        PB.UI:Lock()
    elseif command == "unlock" then
        PB.UI:Unlock()
    elseif command == "reset" then
        PB.UI:ResetPosition()
    elseif command == "scale" then
        PB.UI:SetScale(argument)
    elseif command == "opacity" then
        PB.UI:SetOpacity(argument)
    elseif command == "dump" then
        PB:Dump()
    elseif command == "snapshot" then
        PB:PrintSnapshot()
    elseif command == "clear" then
        PB:ClearSnapshot()
    elseif command == "debugscan" then
        PB.Encounter:DebugScan()
    elseif command == "validate" then
        PB:ValidateSpellIds()
    elseif command == "debug" then
        ParseBuddyDB.debug = not ParseBuddyDB.debug
        PB:Print("Debug output " .. (ParseBuddyDB.debug and "enabled." or "disabled."))
    else
        PB:Print("Unknown command: " .. command)
        showHelp()
    end
end

local function registerSlashCommands()
    SLASH_PARSEBUDDY1 = "/pb"
    SLASH_PARSEBUDDY2 = "/parsebuddy"
    SlashCmdList.PARSEBUDDY = function(message)
        PB:HandleSlashCommand(message)
    end
end

function PB:Initialize()
    ParseBuddyDB = ParseBuddyDB or {}
    PB.Defaults:Apply(ParseBuddyDB)
    PB.Config:Initialize()

    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    PB.version = getMetadata and getMetadata(PB.addonName, "Version") or "unknown"
    PB.lastEncounterSnapshot = ParseBuddyDB.lastEncounterSnapshot

    registerSlashCommands()
    PB.UI:Initialize()
    PB.Events:Initialize()
    PB:Debug("Initialized version " .. PB.version)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if event ~= "ADDON_LOADED" or loadedAddonName ~= PB.addonName then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    PB:Initialize()
end)
