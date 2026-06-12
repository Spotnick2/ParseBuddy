local PB = ParseBuddy

PB.Defaults = {
    values = {
        schemaVersion = 1,
        debug = false,
        summaryAuto = false,
        frame = {
            locked = false,
            scale = 1,
            opacity = 1,
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        },
        selectedProfile = "Default",
        displayMode = "PROBLEMS_ONLY",
        warningThreshold = 5,
        pullGracePeriod = 6,
        showUnknownSource = true,
    },
}

PB.Defaults.settings = {
    displayMode = "PROBLEMS_ONLY",
    groups = {
        spellVulnerability = { enabled = true, required = true },
        majorArmor = { enabled = true, required = true },
        faerieFire = { enabled = true, required = true },
        judgement = { enabled = true, required = true },
        attackPower = { enabled = true, required = true },
        attackSpeed = { enabled = true, required = true },
        recklessness = { enabled = true, required = false },
    },
}

local function applyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function PB.Defaults:Apply(database)
    applyDefaults(database, self.values)
end

function PB.Defaults:ApplySettings(settings)
    applyDefaults(settings, self.settings)
end

function PB.Defaults:CopySettings(settings)
    local copy = {}
    local function copyTable(target, source)
        local key, value
        for key, value in pairs(source) do
            if type(value) == "table" then
                target[key] = {}
                copyTable(target[key], value)
            else
                target[key] = value
            end
        end
    end
    copyTable(copy, settings)
    return copy
end
