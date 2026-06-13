local PB = ParseBuddy

PB.Roster = {
    snapshot = nil,
}

local runtimeProvider = {
    IsInRaid = function()
        return IsInRaid and IsInRaid() or false
    end,
    GroupCount = function()
        return GetNumGroupMembers and GetNumGroupMembers() or 0
    end,
    Exists = function(unitToken)
        return UnitExists and UnitExists(unitToken) or false
    end,
    Class = function(unitToken)
        if not UnitClass then
            return nil, nil
        end
        return UnitClass(unitToken)
    end,
    Name = function(unitToken)
        return UnitName and UnitName(unitToken) or nil
    end,
    IsLeader = function(unitToken)
        return UnitIsGroupLeader and UnitIsGroupLeader(unitToken) or false
    end,
}

local function addMember(snapshot, provider, unitToken)
    if not provider.Exists(unitToken) then
        snapshot.complete = false
        return
    end

    local _, classFile = provider.Class(unitToken)
    local name = provider.Name(unitToken)
    if not classFile then
        snapshot.complete = false
    end
    snapshot.members[#snapshot.members + 1] = {
        unitToken = unitToken,
        name = name,
        classFile = classFile,
    }
    if classFile then
        snapshot.classes[classFile] = true
    end
    if provider.IsLeader and provider.IsLeader(unitToken) then
        snapshot.leaderName = name
    end
end

function PB.Roster:Refresh(reason, provider)
    provider = provider or runtimeProvider
    local snapshot = {
        reason = reason or "manual",
        members = {},
        classes = {},
        capabilities = {},
        complete = true,
    }
    local count = provider.GroupCount() or 0
    local index

    if provider.IsInRaid() then
        snapshot.mode = "raid"
        snapshot.expectedCount = count
        for index = 1, count do
            addMember(snapshot, provider, "raid" .. tostring(index))
        end
    elseif count > 0 then
        snapshot.mode = "party"
        snapshot.expectedCount = count
        addMember(snapshot, provider, "player")
        for index = 1, math.max(0, count - 1) do
            addMember(snapshot, provider, "party" .. tostring(index))
        end
    else
        snapshot.mode = "solo"
        snapshot.expectedCount = 1
        addMember(snapshot, provider, "player")
    end

    if #snapshot.members ~= snapshot.expectedCount then
        snapshot.complete = false
    end

    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        local available = false
        local classFile
        for classFile in pairs(snapshot.classes) do
            if PB.CapabilityLibrary:CanClassProvide(group.key, classFile) then
                available = true
                break
            end
        end
        if available then
            snapshot.capabilities[group.key] = "available"
        elseif snapshot.complete then
            snapshot.capabilities[group.key] = "notAvailable"
        else
            snapshot.capabilities[group.key] = "unknown"
        end
    end

    self.snapshot = snapshot
    if PB.ConfigPanel and PB.ConfigPanel.RefreshControls then
        PB.ConfigPanel:RefreshControls()
    end
    return snapshot
end

function PB.Roster:GetGroupCapability(groupKey)
    if not self.snapshot then
        return "unknown"
    end
    return self.snapshot.capabilities[groupKey] or "unknown"
end

function PB.Roster:GetLeaderName()
    return self.snapshot and self.snapshot.leaderName or nil
end

function PB.Roster:Print()
    local snapshot = self.snapshot
    if not snapshot then
        PB:Print("Roster cache is unavailable.")
        return false
    end

    PB:Print(string.format(
        "Roster: mode=%s members=%d/%d complete=%s reason=%s",
        tostring(snapshot.mode),
        #snapshot.members,
        snapshot.expectedCount or 0,
        snapshot.complete and "yes" or "no",
        tostring(snapshot.reason)
    ))
    local _, member
    for _, member in ipairs(snapshot.members) do
        PB:Print(string.format(
            "  %s name=%s class=%s",
            tostring(member.unitToken),
            tostring(member.name or "unknown"),
            tostring(member.classFile or "unknown")
        ))
    end
    local _, group
    for _, group in ipairs(PB.DebuffLibrary.groups) do
        PB:Print(string.format("  %s=%s", group.key, self:GetGroupCapability(group.key)))
    end
    return true
end
