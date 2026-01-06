--[[
    CharacterData.lua
    Shared module defining all playable characters, their stats, and abilities
    Place in ReplicatedStorage
]]

local CharacterData = {
    -- Gyro Zeppeli - Precision Burst
    -- Burst is stronger near max stamina + sharp turning during burst
    Gyro = {
        displayName = "Gyro Zeppeli",
        description = "Master of calculated aggression. Burst power scales with stamina management.",
        ability = "Precision Burst",
        abilityDescription = "Burst is more powerful at high stamina and allows sharp turning",
        modelName = "Gyro", -- Name of model in ReplicatedStorage/Characters

        -- Portrait/UI
        portraitColor = Color3.fromRGB(120, 180, 80), -- Green theme

        -- Base stats (these override Config defaults)
        stats = {
            -- Stamina-focused for ability synergy
            MAX_STAMINA = 120,          -- Higher stamina pool
            REGEN_MAX_RATE = 50,        -- Faster top-off

            -- Burst specialization
            BURST_SPEED_MULT = 1.3,     -- Base burst is slightly weaker...
            BURST_DURATION = 1.8,       -- ...but lasts longer
            BURST_COST = 20,            -- Cheaper burst
            BURST_TURN_PENALTY = 0.7,   -- Less turn penalty (ability enhances this further)

            -- Balanced elsewhere
            BASE_SPEED = 38,
            SPRINT_SPEED = 78,
        },

        -- Ability-specific modifiers (handled in ability system)
        abilityParams = {
            maxStaminaBurstMult = 1.6,  -- Burst multiplier at 100% stamina
            lowStaminaBurstMult = 1.2,  -- Burst multiplier at low stamina
            staminaThreshold = 0.8,     -- Above 80% = "high stamina"
            burstTurnBonus = 1.5,       -- Turn rate multiplier during burst
        },
    },

    -- Johnny Joestar - Launch Jump
    -- Jumping during burst is supercharged
    Johnny = {
        displayName = "Johnny Joestar",
        description = "Explosive aerial potential. Combine burst with jumps for massive air.",
        ability = "Launch Jump",
        abilityDescription = "Jumping during burst launches you with supercharged power",
        modelName = "Johnny",

        portraitColor = Color3.fromRGB(80, 120, 200), -- Blue theme

        stats = {
            -- Jump-focused
            JUMP_POWER = 75,            -- Stronger base jump
            DOUBLE_JUMP_POWER = 65,     -- Stronger double jump
            JUMP_COST = 18,             -- Cheaper jumps
            DOUBLE_JUMP_COST = 22,
            AIR_CONTROL = 0.2,          -- Better air control
            DOUBLE_JUMP_TURN_RATE = 140, -- Better air turning

            -- Burst synergy
            BURST_DURATION = 1.3,       -- Shorter burst window
            BURST_COOLDOWN = 2.5,       -- Faster cooldown for more burst-jump combos

            -- Slightly lower ground stats
            BASE_SPEED = 38,
            SPRINT_SPEED = 76,
            MAX_STAMINA = 95,
        },

        abilityParams = {
            burstJumpMult = 1.8,        -- Jump power multiplier during burst
            burstDoubleJumpMult = 2.0,  -- Double jump is even more boosted
            launchSpeedBoost = 1.2,     -- Horizontal speed boost on burst-jump
        },
    },

    -- Diego Brando - Drift Surge
    -- Exiting drift gives a speed boost
    Diego = {
        displayName = "Diego Brando",
        description = "Predatory corner speed. Drifts build into devastating straightaway bursts.",
        ability = "Drift Surge",
        abilityDescription = "Exiting drift grants a speed boost based on drift duration",
        modelName = "Diego",

        portraitColor = Color3.fromRGB(200, 160, 60), -- Gold/yellow theme

        stats = {
            -- Drift specialization
            DRIFT_TURN_BONUS = 2.5,     -- Tighter drift turning
            DRIFT_STAMINA_DRAIN = 5,    -- Lower drift stamina cost
            DRIFT_RELEASE_RETAIN = 0.98, -- Keep more speed on drift exit

            -- Aggressive stats
            SPRINT_SPEED = 85,          -- Faster sprint
            BASE_SPEED = 42,            -- Faster base
            ACCELERATION = 1.4,         -- Quicker acceleration

            -- Trade-off: lower stamina
            MAX_STAMINA = 90,
            SPRINT_DRAIN = 18,          -- Drains faster
        },

        abilityParams = {
            driftBoostBase = 1.15,      -- Minimum boost on drift exit
            driftBoostMax = 1.4,        -- Maximum boost after long drift
            driftBoostDuration = 1.2,   -- How long the boost lasts
            driftTimeForMaxBoost = 1.5, -- Seconds of drifting for max boost
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
        if type(data) == "table" and data.displayName then
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
