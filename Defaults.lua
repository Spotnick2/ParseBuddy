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
        warningCapSeconds = 10,
        pullGracePeriod = 6,
        showUnknownSource = true,
    },
}

PB.Defaults.settings = {
    displayMode = "PROBLEMS_ONLY",
    showUnavailable = false,
    broadcast = {
        enabled = false,
        channel = "raid",
        delay = 3,
    },
    groups = {
        spellVulnerability = { enabled = true, visibility = "always", required = true },
        majorArmor = { enabled = true, visibility = "always", required = true },
        faerieFire = { enabled = true, visibility = "always", required = true },
        judgement = { enabled = true, visibility = "always", required = true },
        attackPower = { enabled = true, visibility = "always", required = true },
        attackSpeed = { enabled = true, visibility = "applied", required = false },
        recklessness = { enabled = true, visibility = "applied", required = false },
        fireVulnerability = { enabled = true, visibility = "applied", required = false },
        wintersChill = { enabled = true, visibility = "applied", required = false },
        shadowVulnerability = { enabled = true, visibility = "applied", required = false },
        shadowWeaving = { enabled = true, visibility = "applied", required = false },
        misery = { enabled = true, visibility = "applied", required = false },
        shadowEmbrace = { enabled = true, visibility = "applied", required = false },
        mangle = { enabled = true, visibility = "applied", required = false },
        hemorrhage = { enabled = true, visibility = "applied", required = false },
        insectSwarm = { enabled = true, visibility = "applied", required = false },
        exposeWeakness = { enabled = true, visibility = "applied", required = false },
        crusaderJudgement = { enabled = true, visibility = "applied", required = false },
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
