local PB = ParseBuddy

PB.Defaults = {
    values = {
        schemaVersion = 1,
        debug = false,
        frame = {
            locked = false,
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
