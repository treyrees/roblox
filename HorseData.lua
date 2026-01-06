--[[
    HorseData.lua
    Shared module defining all horses (cosmetic only)
    Place in ReplicatedStorage
]]

local HorseData = {
    -- Default horse - everyone starts with this
    DefaultHorse = {
        displayName = "Valkyrie",
        description = "A reliable steed for any rider.",
        isDefault = true,
        unlocked = true, -- Always unlocked

        -- Appearance
        bodyColor = BrickColor.new("Brown"),
        maneColor = BrickColor.new("Black"),
        tailColor = BrickColor.new("Black"),

        -- Optional model override (nil = use procedural horse)
        modelName = nil,
    },

    -- Unlockable horses (cosmetic only - no stat changes)
    Shadowmare = {
        displayName = "Shadowmare",
        description = "Dark as midnight, swift as shadow.",
        isDefault = false,
        unlocked = false,

        bodyColor = BrickColor.new("Really black"),
        maneColor = BrickColor.new("Dark indigo"),
        tailColor = BrickColor.new("Dark indigo"),

        modelName = nil,
    },

    Snowstorm = {
        displayName = "Snowstorm",
        description = "Born from the frozen north.",
        isDefault = false,
        unlocked = false,

        bodyColor = BrickColor.new("Institutional white"),
        maneColor = BrickColor.new("Light blue"),
        tailColor = BrickColor.new("Light blue"),

        modelName = nil,
    },

    Crimson = {
        displayName = "Crimson",
        description = "A fiery spirit with an iron will.",
        isDefault = false,
        unlocked = false,

        bodyColor = BrickColor.new("Bright red"),
        maneColor = BrickColor.new("Maroon"),
        tailColor = BrickColor.new("Maroon"),

        modelName = nil,
    },

    Golden = {
        displayName = "Golden Sun",
        description = "Blessed by fortune itself.",
        isDefault = false,
        unlocked = false,

        bodyColor = BrickColor.new("Bright yellow"),
        maneColor = BrickColor.new("Neon orange"),
        tailColor = BrickColor.new("Neon orange"),

        modelName = nil,
    },

    Phantom = {
        displayName = "Phantom",
        description = "Some say it's not entirely of this world.",
        isDefault = false,
        unlocked = false,

        bodyColor = BrickColor.new("Fossil"),
        maneColor = BrickColor.new("Cyan"),
        tailColor = BrickColor.new("Cyan"),

        -- Special: slightly transparent
        transparency = 0.2,

        modelName = nil,
    },
}

-- Helper function to get horse list for UI
function HorseData.getHorseList()
    local list = {}
    for id, data in pairs(HorseData) do
        if type(data) == "table" and data.displayName then
            table.insert(list, {
                id = id,
                displayName = data.displayName,
                description = data.description,
                isDefault = data.isDefault or false,
                bodyColor = data.bodyColor,
            })
        end
    end
    -- Sort: default first, then alphabetically
    table.sort(list, function(a, b)
        if a.isDefault ~= b.isDefault then
            return a.isDefault
        end
        return a.displayName < b.displayName
    end)
    return list
end

-- Get default horse ID
function HorseData.getDefaultHorseId()
    for id, data in pairs(HorseData) do
        if type(data) == "table" and data.isDefault then
            return id
        end
    end
    return "DefaultHorse"
end

-- Get horse appearance data
function HorseData.getAppearance(horseId)
    local horse = HorseData[horseId]
    if not horse then
        horse = HorseData.DefaultHorse
    end
    return {
        bodyColor = horse.bodyColor or BrickColor.new("Brown"),
        maneColor = horse.maneColor or BrickColor.new("Black"),
        tailColor = horse.tailColor or BrickColor.new("Black"),
        transparency = horse.transparency or 0,
        modelName = horse.modelName,
    }
end

return HorseData
