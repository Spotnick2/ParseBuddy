local PB = ParseBuddy

PB.Config = {}

local VALID_SCOPES = {
    global = true,
    personal = true,
}

local function boolText(value)
    return value and "enabled" or "disabled"
end

local function requiredText(value)
    return value and "required" or "optional"
end

function PB.Config:Initialize()
    ParseBuddyDB.schemaVersion = 4
    ParseBuddyDB.settings = ParseBuddyDB.settings or {}
    if ParseBuddyDB.settings.displayMode == nil and ParseBuddyDB.displayMode ~= nil then
        ParseBuddyDB.settings.displayMode = ParseBuddyDB.displayMode
    end
    PB.Defaults:ApplySettings(ParseBuddyDB.settings)

    ParseBuddyCharDB = ParseBuddyCharDB or {}
    ParseBuddyCharDB.schemaVersion = 3
    if not VALID_SCOPES[ParseBuddyCharDB.activeScope] then
        ParseBuddyCharDB.activeScope = "global"
    end
    if ParseBuddyCharDB.settings then
        PB.Defaults:ApplySettings(ParseBuddyCharDB.settings)
    end
end

function PB.Config:GetScope()
    return ParseBuddyCharDB and ParseBuddyCharDB.activeScope or "global"
end

function PB.Config:GetSettings()
    if self:GetScope() == "personal" and ParseBuddyCharDB.settings then
        return ParseBuddyCharDB.settings
    end
    return ParseBuddyDB.settings
end

function PB.Config:SetScope(scope, silent)
    scope = scope and scope:lower() or ""
    if scope == "" then
        PB:Print("Profile scope: " .. self:GetScope() .. ".")
        return true
    end
    if not VALID_SCOPES[scope] then
        PB:Print("Profile must be 'global' or 'personal'.")
        return false
    end

    if scope == "personal" and not ParseBuddyCharDB.settings then
        ParseBuddyCharDB.settings = PB.Defaults:CopySettings(ParseBuddyDB.settings)
    end
    ParseBuddyCharDB.activeScope = scope
    if not silent then PB:Print("Profile scope set to " .. scope .. ".") end
    if PB.Encounter and PB.Encounter.active then
        PB.Encounter:RefreshDisplay()
    end
    return true
end

function PB.Config:GetDisplayMode()
    return self:GetSettings().displayMode
end

function PB.Config:SetDisplayMode(displayMode)
    self:GetSettings().displayMode = displayMode
end

function PB.Config:GetShowUnavailable()
    return self:GetSettings().showUnavailable == true
end

function PB.Config:SetShowUnavailable(show)
    self:GetSettings().showUnavailable = show == true
end

function PB.Config:HandleUnavailableCommand(value)
    value = value and value:lower() or ""
    if value == "show" then
        self:SetShowUnavailable(true)
    elseif value == "hide" then
        self:SetShowUnavailable(false)
    elseif value ~= "" then
        PB:Print("Unavailable must be 'show' or 'hide'.")
        return false
    end

    PB:Print("Unavailable rows in Problems Only: " .. (self:GetShowUnavailable() and "shown" or "hidden") .. " (" .. self:GetScope() .. ").")
    if value ~= "" and PB.Encounter and PB.Encounter.active then
        PB.Encounter:RefreshDisplay()
    end
    return true
end

function PB.Config:GetBroadcastSettings()
    return self:GetSettings().broadcast
end

function PB.Config:HandleBroadcastCommand(argument)
    local command, value = (argument or ""):match("^(%S*)%s*(.-)$")
    command = command and command:lower() or ""
    value = value and value:lower() or ""
    local settings = self:GetBroadcastSettings()

    if command == "on" then
        settings.enabled = true
    elseif command == "off" then
        settings.enabled = false
    elseif command == "channel" then
        if value ~= "party" and value ~= "raid" and value ~= "leader" then
            PB:Print("Broadcast channel must be party, raid, or leader.")
            return false
        end
        settings.channel = value
    elseif command == "delay" then
        local delay = tonumber(value)
        if not delay or delay < 0 or delay > 60 then
            PB:Print("Broadcast delay must be between 0 and 60 seconds.")
            return false
        end
        settings.delay = delay
    elseif command == "test" then
        return PB.Broadcast:Test()
    elseif command ~= "" then
        PB:Print("Broadcast command must be on, off, channel party|raid|leader, delay 0-60, or test.")
        return false
    end

    PB:Print(string.format(
        "Broadcast: %s, channel=%s, delay=%.1fs, scope=%s. Changes apply next encounter.",
        settings.enabled and "on" or "off", settings.channel, settings.delay, self:GetScope()
    ))
    return true
end

function PB.Config:ResolveGroupKey(value)
    local normalized = value and value:lower() or ""
    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        if group.key:lower() == normalized then
            return group.key
        end
    end
    return nil
end

function PB.Config:GetGroupSettings(groupKey)
    local settings = self:GetSettings()
    local groupSettings = settings.groups[groupKey]
    if not groupSettings then
        groupSettings = { enabled = true, required = true }
        settings.groups[groupKey] = groupSettings
    end
    return groupSettings
end

function PB.Config:PrintGroup(groupKey)
    local group = PB.DebuffLibrary.groupsByKey[groupKey]
    local settings = self:GetGroupSettings(groupKey)
    PB:Print(string.format(
        "Group %s (%s): %s, %s, scope=%s.",
        groupKey,
        group.label,
        boolText(settings.enabled),
        requiredText(settings.required),
        self:GetScope()
    ))
end

function PB.Config:HandleGroupCommand(argument)
    local keyInput, action = (argument or ""):match("^(%S+)%s*(.-)$")
    local groupKey = self:ResolveGroupKey(keyInput)
    if not groupKey then
        PB:Print("Unknown group key. Use /pb groups to list valid keys.")
        return false
    end

    action = action and action:lower() or ""
    local settings = self:GetGroupSettings(groupKey)
    if action == "enable" then
        settings.enabled = true
    elseif action == "disable" then
        settings.enabled = false
    elseif action == "required" then
        settings.required = true
    elseif action == "optional" then
        settings.required = false
    elseif action ~= "" then
        PB:Print("Group action must be enable, disable, required, or optional.")
        return false
    end

    self:PrintGroup(groupKey)
    if action ~= "" and PB.Encounter and PB.Encounter.active then
        PB.Encounter:RefreshDisplay()
    end
    return true
end

function PB.Config:PrintGroups()
    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        self:PrintGroup(group.key)
    end
end
