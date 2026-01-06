--[[
    CharacterData.lua
    Shared module defining all playable characters, their stats, and abilities
    Place in ReplicatedStorage
]]

local CharacterData = {
    -- Gyro Zeppeli - Precision Burst
    -- The ONLY character who can break 100 speed. Rewards stamina discipline.
    Gyro = {
        displayName = "Gyro Zeppeli",
        description = "Master of calculated aggression. The only racer who can break the speed limit.",
        ability = "Precision Burst",
        abilityDescription = "Burst power scales with stamina - above 85% BREAKS the 100 speed cap!",
        modelName = "Gyro",

        portraitColor = Color3.fromRGB(120, 180, 80), -- Green theme

        stats = {
            -- Larger stamina pool (more to manage)
            MAX_STAMINA = 115,
            REGEN_MAX_RATE = 50,        -- Faster top-off

            -- Slightly slower base (trade-off for burst power)
            BASE_SPEED = 38,
            SPRINT_SPEED = 78,

            -- Burst tuning
            BURST_DURATION = 1.8,       -- Longer burst window
            BURST_COST = 20,            -- Cheaper to encourage usage
            BURST_TURN_PENALTY = 0.6,   -- Less harsh turn penalty
        },

        abilityParams = {
            -- Stamina thresholds
            lowThreshold = 0.50,        -- Below 50% = low (no bonus)
            highThreshold = 0.85,       -- Above 85% = high (BREAKS 100!)

            -- Burst multipliers (applied ON TOP of base 1.15x)
            lowStaminaMult = 1.0,       -- 78 * 1.15 * 1.0 = 90 (no bonus)
            midStaminaMult = 1.13,      -- 78 * 1.15 * 1.13 = 101 (just over!)
            highStaminaMult = 1.30,     -- 78 * 1.15 * 1.30 = 117 (BREAKS CAP!)

            -- Turn bonus during burst (counteracts penalty at high stamina)
            burstTurnBonus = 1.8,
        },
    },

    -- Johnny Joestar - Drift Surge
    -- Hits the cap (100) through technical execution. Best cornering.
    Johnny = {
        displayName = "Johnny Joestar",
        description = "Technical precision. Perfect drifts hit the 100 speed cap.",
        ability = "Drift Surge",
        abilityDescription = "Exiting drift grants speed boost - max drift hits exactly 100!",
        modelName = "Johnny",

        portraitColor = Color3.fromRGB(80, 120, 200), -- Blue theme

        stats = {
            -- Standard stamina
            MAX_STAMINA = 100,

            -- Slightly faster sprint (technical racer)
            BASE_SPEED = 40,
            SPRINT_SPEED = 82,
            ACCELERATION = 1.3,         -- Snappier for drift exits

            -- Enhanced drift capabilities
            DRIFT_TURN_BONUS = 2.5,     -- Tightest drifts
            DRIFT_STAMINA_DRAIN = 5,    -- Cheaper drifts (was 8)
            DRIFT_RELEASE_RETAIN = 0.96, -- Almost no speed loss (was 0.92)

            -- Normal burst (doesn't benefit specially)
            BURST_SPEED_MULT = 1.15,    -- 82 * 1.15 = 94
        },

        abilityParams = {
            -- Drift surge scaling
            driftBoostMin = 1.10,       -- Minimum boost (short drift): 82 * 1.10 = 90
            driftBoostMax = 1.22,       -- Maximum boost: 82 * 1.22 = 100 exact!
            driftBoostDuration = 1.6,   -- Long enough to chain or use on straight

            -- Drift timing
            minDriftTime = 0.3,         -- Minimum drift to trigger any surge
            maxDriftTime = 1.2,         -- Drift time for max surge

            -- Surge can be refreshed by new drift
            surgeRefreshable = true,
        },
    },

    -- Diego Brando - Aerial Burst
    -- Doesn't compete on raw speed. Wins through shortcuts and positioning.
    Diego = {
        displayName = "Diego Brando",
        description = "Predatory aerial hunter. Double jump triggers burst and unlocks shortcuts.",
        ability = "Aerial Burst",
        abilityDescription = "Double jump triggers a speed burst and enhanced air control",
        modelName = "Diego",

        portraitColor = Color3.fromRGB(200, 160, 60), -- Gold/yellow theme

        stats = {
            -- Slightly lower stamina (aggressive playstyle)
            MAX_STAMINA = 90,

            -- Good ground speed, but not best
            BASE_SPEED = 42,
            SPRINT_SPEED = 80,

            -- Enhanced jump baseline
            JUMP_POWER = 72,            -- Stronger base jump (was 66)
            DOUBLE_JUMP_POWER = 60,     -- Stronger double jump (was 55)
            JUMP_COST = 18,             -- Cheaper jumps
            DOUBLE_JUMP_COST = 22,      -- Cheaper double jumps

            -- Superior air control
            AIR_CONTROL = 0.25,         -- Was 0.15
            AIR_TURN_RATE = 25,         -- Was 15
            DOUBLE_JUMP_TURN_RATE = 180, -- Near-instant redirects (was 120)
            DOUBLE_JUMP_TURN_DURATION = 1.0, -- Was 0.8

            -- Normal burst (slightly longer cooldown)
            BURST_SPEED_MULT = 1.15,
            BURST_COOLDOWN = 3.5,
        },

        abilityParams = {
            -- Aerial burst (triggers on double jump)
            aerialBurstMult = 1.15,     -- 80 * 1.15 = 92 speed
            aerialBurstDuration = 1.3,  -- Carries through landing

            -- Enhanced double jump power during aerial burst
            doubleJumpBoost = 1.35,     -- 60 * 1.35 = 81 power (big air!)

            -- Forward momentum on double jump
            forwardMomentumBoost = 0.2, -- Adds 20% of current speed as forward impulse
        },
    },

    -- Hot Pants - Phase Shift
    -- Blink forward, maintaining momentum
    HotPants = {
        displayName = "Hot Pants",
        description = "Tactical repositioning expert. Blink through gaps and past opponents.",
        ability = "Phase Shift",
        abilityDescription = "Press F to blink forward, maintaining momentum",
        modelName = "HotPants",
        enabled = false, -- No model yet

        portraitColor = Color3.fromRGB(200, 100, 150), -- Pink theme

        stats = {
            -- Balanced base stats
            BASE_SPEED = 40,
            SPRINT_SPEED = 80,
            MAX_STAMINA = 100,

            -- Slightly better recovery for repositioning playstyle
            REGEN_MIN_RATE = 10,
            REGEN_MAX_RATE = 48,
            REGEN_DELAY = 0.4,

            -- Good air control for blink combos
            AIR_CONTROL = 0.18,
            DOUBLE_JUMP_TURN_RATE = 130,
        },

        abilityParams = {
            blinkDistance = 18,         -- Studs to teleport
            blinkCooldown = 4.0,        -- Seconds between blinks
            blinkStaminaCost = 25,      -- Stamina cost
            blinkMomentumRetain = 1.0,  -- Keep 100% momentum
            blinkKey = Enum.KeyCode.F,  -- Keybind
        },
    },

    -- Sandman - Momentum
    -- Cruising at normal speed slowly builds bonus speed
    Sandman = {
        displayName = "Sandman",
        description = "Endurance runner. Patient pacing builds into unstoppable momentum.",
        ability = "Momentum",
        abilityDescription = "Running at normal speed gradually builds bonus speed",
        modelName = "Sandman",
        enabled = false, -- No model yet

        portraitColor = Color3.fromRGB(180, 140, 100), -- Brown/earth theme

        stats = {
            -- Endurance focused
            MAX_STAMINA = 130,          -- Huge stamina pool
            REGEN_MIN_RATE = 12,        -- Better low-stamina regen
            REGEN_MAX_RATE = 55,        -- Fastest regen
            SPRINT_DRAIN = 12,          -- Lower sprint drain

            -- Speed stats - base is higher, sprint ceiling is similar
            BASE_SPEED = 45,            -- Faster cruising speed
            SPRINT_SPEED = 78,          -- Slightly lower sprint cap

            -- Momentum feel
            MOMENTUM_FACTOR = 0.94,     -- More momentum carryover
            DECELERATION = 2.5,         -- Slower to stop
        },

        abilityParams = {
            momentumBuildRate = 0.08,   -- Speed gained per second while cruising
            momentumMaxBonus = 15,      -- Maximum bonus speed from momentum
            momentumDecayRate = 0.3,    -- Speed lost per second when not cruising
            cruiseSpeedThreshold = 0.6, -- Must be above 60% base speed to build
            sprintResetsBonus = false,  -- Sprinting doesn't reset momentum (keeps it)
        },
    },
}

-- Helper function to get character list for UI
function CharacterData.getCharacterList()
    local list = {}
    for id, data in pairs(CharacterData) do
        -- Only include enabled characters (default to true if not specified)
        if type(data) == "table" and data.displayName and (data.enabled ~= false) then
            table.insert(list, {
                id = id,
                displayName = data.displayName,
                description = data.description,
                ability = data.ability,
                abilityDescription = data.abilityDescription,
                portraitColor = data.portraitColor,
            })
        end
    end
    -- Sort alphabetically by display name for consistent UI order
    table.sort(list, function(a, b)
        return a.displayName < b.displayName
    end)
    return list
end

-- Helper to get stats for a character (merges with defaults)
function CharacterData.getStats(characterId)
    local character = CharacterData[characterId]
    if not character then return nil end
    return character.stats or {}
end

-- Helper to get ability params
function CharacterData.getAbilityParams(characterId)
    local character = CharacterData[characterId]
    if not character then return nil end
    return character.abilityParams or {}
end

return CharacterData
