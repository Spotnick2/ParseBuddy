ParseBuddy = {
    messages = {},
    debugMessages = {},
    Print = function(self, message) self.messages[#self.messages + 1] = message end,
    Debug = function(self, message) self.debugMessages[#self.debugMessages + 1] = message end,
}
ParseBuddyDB = { pullGracePeriod = 6 }

assert(loadfile("Defaults.lua"))()
assert(loadfile("DebuffLibrary.lua"))()

local settings = ParseBuddy.Defaults:CopySettings(ParseBuddy.Defaults.settings)
local capability = {}
local _, libraryGroup
for _, libraryGroup in ipairs(ParseBuddy.DebuffLibrary.groups) do
    settings.groups[libraryGroup.key].enabled = false
    capability[libraryGroup.key] = "available"
end
settings.groups.majorArmor.enabled = true

ParseBuddy.Config = {
    GetSettings = function() return settings end,
    GetScope = function() return "personal" end,
}
ParseBuddy.Roster = {
    GetGroupCapability = function(_, key) return capability[key] or "unknown" end,
    GetLeaderName = function() return "Raidleader" end,
}

assert(loadfile("Broadcast.lua"))()

local now = 0
local callbacks = {}
local sent = {}
local inRaid = true
local inGroup = true
local inCombat = false
local provider = {
    Now = function() return now end,
    After = function(delay, callback) callbacks[#callbacks + 1] = { delay = delay, callback = callback } end,
    IsInRaid = function() return inRaid end,
    IsInGroup = function() return inGroup end,
    Send = function(message, channel, target)
        sent[#sent + 1] = { message = message, channel = channel, target = target }
    end,
    InCombat = function() return inCombat end,
}
ParseBuddy.Broadcast:SetProvider(provider)

local testsRun = 0
local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local groupsByKey = ParseBuddy.DebuffLibrary.groupsByKey
local function evaluation(key, state)
    return { group = groupsByKey[key], state = state }
end

settings.broadcast.enabled = false
ParseBuddy.Broadcast:Begin({ id = 1, name = "Boss", startedAt = 0 })
assertEqual(ParseBuddy.Broadcast.active.enabled, false, "broadcast defaults off")
ParseBuddy.Broadcast:Observe(1, { evaluation("majorArmor", "grace") })
assertEqual(#callbacks, 0, "disabled broadcast schedules nothing")

settings.broadcast.enabled = true
settings.broadcast.channel = "raid"
settings.broadcast.delay = 3
ParseBuddy.Broadcast:Begin({ id = 2, name = "Boss", startedAt = 0 })
ParseBuddy.Broadcast:Observe(2, { evaluation("majorArmor", "grace") })
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, 9, "grace plus delay determines due time")
assertEqual(#sent, 0, "observation never sends directly")
now = 8
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, 0, "alert does not send before due time")
now = 9
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, 1, "due callback sends alert")
assertEqual(sent[1].channel, "RAID", "raid destination routed")
assertEqual(string.find(sent[1].message, "Armor", 1, true) ~= nil, true, "public message identifies group without player names")
ParseBuddy.Broadcast:Observe(10, { evaluation("majorArmor", "missing") })
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, 1, "same missing period is deduplicated")

ParseBuddy.Broadcast:Observe(12, { evaluation("majorArmor", "partial") })
ParseBuddy.Broadcast:Observe(13, { evaluation("majorArmor", "missing") })
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, nil, "partial does not re-arm an announced group")
ParseBuddy.Broadcast:Observe(14, { evaluation("majorArmor", "active") })
ParseBuddy.Broadcast:Observe(15, { evaluation("majorArmor", "missing") })
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, 18, "satisfied then missing re-arms group")
now = 18
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, 1, "per-group cooldown delays rapid re-alert")
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, 39, "group cooldown is conservative")
now = 39
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, 2, "re-armed group sends after cooldown")

ParseBuddy.Broadcast:Begin({ id = 21, name = "Boss", startedAt = 40 })
now = 42
ParseBuddy.Broadcast:Observe(now, { evaluation("majorArmor", "grace") })
ParseBuddy.Broadcast:Observe(43, { evaluation("majorArmor", "partial") })
ParseBuddy.Broadcast:Observe(47, { evaluation("majorArmor", "missing") })
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, 50, "unannounced partial interruption can schedule a later missing period")

settings.groups.majorArmor.required = false
ParseBuddy.Broadcast:Begin({ id = 3, name = "Boss", startedAt = 40 })
ParseBuddy.Broadcast:Observe(47, { evaluation("majorArmor", "missing") })
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, nil, "optional group never schedules")
settings.groups.majorArmor.required = true
settings.groups.majorArmor.enabled = false
ParseBuddy.Broadcast:Begin({ id = 4, name = "Boss", startedAt = 50 })
ParseBuddy.Broadcast:Observe(57, { evaluation("majorArmor", "missing") })
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, nil, "disabled group never schedules")

settings.groups.majorArmor.enabled = true
capability.majorArmor = "notAvailable"
ParseBuddy.Broadcast:Begin({ id = 5, name = "Boss", startedAt = 60 })
ParseBuddy.Broadcast:Observe(67, { evaluation("majorArmor", "notAvailable") })
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, nil, "unavailable group never schedules")
capability.majorArmor = "unknown"
ParseBuddy.Broadcast:Begin({ id = 6, name = "Boss", startedAt = 70 })
ParseBuddy.Broadcast:Observe(77, { evaluation("majorArmor", "missing") })
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.dueAt, nil, "unknown capability never schedules")

capability.majorArmor = "available"
settings.broadcast.channel = "party"
settings.broadcast.delay = 4
ParseBuddy.Broadcast:Begin({ id = 7, name = "Boss", startedAt = 80 })
settings.broadcast.channel = "leader"
settings.broadcast.delay = 20
settings.groups.majorArmor.required = false
assertEqual(ParseBuddy.Broadcast.active.channel, "party", "channel frozen at pull")
assertEqual(ParseBuddy.Broadcast.active.delay, 4, "delay frozen at pull")
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.required, true, "required flag frozen at pull")
assertEqual(ParseBuddy.Broadcast.active.groups.majorArmor.capability, "available", "capability frozen at pull")
settings.groups.majorArmor.required = true

now = 90
ParseBuddy.Broadcast:Observe(now, { evaluation("majorArmor", "missing") })
now = 94
ParseBuddy.Broadcast:ProcessDue()
assertEqual(sent[#sent].channel, "PARTY", "party destination routed")

settings.broadcast.channel = "leader"
settings.broadcast.delay = 0
ParseBuddy.Broadcast:Begin({ id = 8, name = "Boss", startedAt = 100 })
now = 106
ParseBuddy.Broadcast:Observe(now, { evaluation("majorArmor", "missing") })
ParseBuddy.Broadcast:ProcessDue()
assertEqual(sent[#sent].channel, "WHISPER", "leader destination uses whisper")
assertEqual(sent[#sent].target, "Raidleader", "leader destination uses cached leader")

settings.broadcast.channel = "raid"
ParseBuddy.Broadcast:Begin({ id = 9, name = "Boss", startedAt = 110 })
inRaid = false
now = 116
ParseBuddy.Broadcast:Observe(now, { evaluation("majorArmor", "missing") })
local beforeUnavailable = #sent
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, beforeUnavailable, "unavailable requested destination is suppressed")
assertEqual(#ParseBuddy.debugMessages > 0, true, "unavailable destination emits local debug warning")
inRaid = true

settings.broadcast.channel = "raid"
settings.broadcast.delay = 3
ParseBuddy.Broadcast:Begin({ id = 10, name = "Boss", startedAt = 120 })
now = 122
ParseBuddy.Broadcast:Observe(now, { evaluation("majorArmor", "grace") })
local staleCallback = callbacks[#callbacks].callback
ParseBuddy.Broadcast:End()
now = 129
staleCallback()
assertEqual(ParseBuddy.Broadcast.active, nil, "encounter cleanup clears active broadcast state")
assertEqual(#sent, beforeUnavailable, "stale deferred callback cannot send after cleanup")

inCombat = true
assertEqual(ParseBuddy.Broadcast:Test(), false, "broadcast test blocked in combat")
inCombat = false
assertEqual(ParseBuddy.Broadcast:Test(), true, "broadcast test allowed out of combat")
assertEqual(string.find(ParseBuddy.messages[#ParseBuddy.messages], "ParseBuddy TEST", 1, true) ~= nil, true, "test output is clearly marked")

settings.broadcast.enabled = true
ParseBuddy.Broadcast:Begin({ id = 11, name = "Boss", startedAt = 130 })
ParseBuddy.Broadcast:Observe(132, { evaluation("majorArmor", "grace") })
local diagnosticLines = ParseBuddy.Broadcast:GetDiagnosticLines()
assertEqual(string.find(diagnosticLines[1], "enabled=yes", 1, true) ~= nil, true, "diagnostics include frozen broadcast state")
assertEqual(string.find(diagnosticLines[2], "group=majorArmor", 1, true) ~= nil, true, "diagnostics include pending group")

settings.groups.attackSpeed.enabled = true
capability.attackSpeed = "available"
settings.broadcast.delay = 0
settings.broadcast.channel = "raid"
ParseBuddy.Broadcast:Begin({ id = 12, name = "Boss", startedAt = 200 })
now = 206
local sentBeforeGlobalCooldown = #sent
ParseBuddy.Broadcast:Observe(now, {
    evaluation("majorArmor", "missing"),
    evaluation("attackSpeed", "missing"),
})
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, sentBeforeGlobalCooldown + 1, "only one simultaneous alert sends immediately")
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, sentBeforeGlobalCooldown + 1, "global cooldown blocks the second simultaneous alert")
now = 211
ParseBuddy.Broadcast:ProcessDue()
assertEqual(#sent, sentBeforeGlobalCooldown + 2, "second alert sends after global cooldown")

print("ParseBuddy Broadcast tests passed: " .. testsRun)
