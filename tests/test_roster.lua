ParseBuddy = {
    messages = {},
    Print = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
}

assert(loadfile("DebuffLibrary.lua"))()
assert(loadfile("CapabilityLibrary.lua"))()
assert(loadfile("Roster.lua"))()

local testsRun = 0
local function assertEqual(actual, expected, message)
    testsRun = testsRun + 1
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function provider(mode, members, count)
    return {
        IsInRaid = function() return mode == "raid" end,
        GroupCount = function() return count or 0 end,
        Exists = function(unit) return members[unit] ~= nil end,
        Class = function(unit)
            local member = members[unit]
            return member and member.classFile, member and member.classFile
        end,
        Name = function(unit)
            local member = members[unit]
            return member and member.name or nil
        end,
        IsLeader = function(unit)
            local member = members[unit]
            return member and member.leader == true or false
        end,
    }
end

local snapshot = ParseBuddy.Roster:Refresh("solo", provider("solo", {
    player = { name = "Solo", classFile = "WARLOCK" },
}, 0))
assertEqual(snapshot.mode, "solo", "solo roster mode")
assertEqual(snapshot.complete, true, "solo roster complete")
assertEqual(ParseBuddy.Roster:GetGroupCapability("spellVulnerability"), "available", "warlock provides spell vulnerability")
assertEqual(ParseBuddy.Roster:GetGroupCapability("recklessness"), "available", "warlock provides recklessness")
assertEqual(ParseBuddy.Roster:GetGroupCapability("majorArmor"), "notAvailable", "warlock cannot provide armor reduction")

snapshot = ParseBuddy.Roster:Refresh("party", provider("party", {
    player = { name = "Priest", classFile = "PRIEST" },
    party1 = { name = "Warrior", classFile = "WARRIOR" },
    party2 = { name = "Druid", classFile = "DRUID" },
}, 3))
assertEqual(snapshot.mode, "party", "party roster mode")
assertEqual(#snapshot.members, 3, "party includes player and party tokens")
assertEqual(ParseBuddy.Roster:GetGroupCapability("majorArmor"), "available", "warrior provides armor reduction")
assertEqual(ParseBuddy.Roster:GetGroupCapability("attackPower"), "available", "warrior or druid provides attack power reduction")
assertEqual(ParseBuddy.Roster:GetGroupCapability("faerieFire"), "available", "druid provides faerie fire")
assertEqual(ParseBuddy.Roster:GetGroupCapability("judgement"), "notAvailable", "party without paladin cannot provide judgement")

snapshot = ParseBuddy.Roster:Refresh("raid", provider("raid", {
    raid1 = { name = "Rogue", classFile = "ROGUE" },
    raid2 = { name = "Paladin", classFile = "PALADIN", leader = true },
}, 2))
assertEqual(snapshot.mode, "raid", "raid roster mode")
assertEqual(ParseBuddy.Roster:GetGroupCapability("majorArmor"), "available", "rogue provides armor reduction")
assertEqual(ParseBuddy.Roster:GetGroupCapability("judgement"), "available", "paladin provides judgement")
assertEqual(ParseBuddy.Roster:GetGroupCapability("attackSpeed"), "notAvailable", "raid without warrior cannot provide attack speed slow")
assertEqual(ParseBuddy.Roster:GetLeaderName(), "Paladin", "raid leader cached for private broadcast routing")

snapshot = ParseBuddy.Roster:Refresh("incomplete", provider("party", {
    player = { name = "Priest", classFile = "PRIEST" },
}, 2))
assertEqual(snapshot.complete, false, "missing party token marks roster incomplete")
assertEqual(ParseBuddy.Roster:GetGroupCapability("judgement"), "unknown", "incomplete roster without provider is unknown")

snapshot = ParseBuddy.Roster:Refresh("incompleteWithProvider", provider("party", {
    player = { name = "Paladin", classFile = "PALADIN" },
}, 2))
assertEqual(ParseBuddy.Roster:GetGroupCapability("judgement"), "available", "known provider wins over incomplete roster")

assertEqual(ParseBuddy.CapabilityLibrary:CanClassProvide("attackSpeed", "WARRIOR"), true, "class mapping accepts baseline provider")
assertEqual(ParseBuddy.CapabilityLibrary:CanClassProvide("attackSpeed", "DRUID"), false, "class mapping does not infer non-baseline provider")

ParseBuddy.messages = {}
ParseBuddy.Roster:Print()
assertEqual(string.find(ParseBuddy.messages[1], "complete=no", 1, true) ~= nil, true, "roster diagnostics include completeness")
assertEqual(string.find(ParseBuddy.messages[2], "name=Paladin", 1, true) ~= nil, true, "explicit roster diagnostics include member names")
assertEqual(#ParseBuddy.messages, 1 + #snapshot.members + #ParseBuddy.DebuffLibrary.groups, "roster diagnostics include every group capability")

print("ParseBuddy Roster tests passed: " .. testsRun)
