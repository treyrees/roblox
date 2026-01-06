--[[
    MountedMovement.lua
    Horse-mounted racing movement with burst, body tilt, and double jump
    Player sits on horse, horse moves with custom controls

    Controls (Tank Style - While Mounted):
    - W/S: Move forward/backward
    - A/D: Turn left/right
    - Shift: Sprint (hold, forward only)
    - Shift (double-tap): Burst (speed boost, costs stamina)
    - Space: Jump (press again in air for double jump with enhanced turning)
    - Q: Drift (hold to lock momentum, turn to aim, release for sharp turn)
    - F: Character ability (Hot Pants only - Phase Shift)
    - X: Dismount
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Load horse animation module
local HorseAnimation = require(script.Parent:WaitForChild("HorseAnimation"))

-- Wait for mount events from server
local MountEvents = ReplicatedStorage:WaitForChild("MountEvents")
local MountHorse = MountEvents:WaitForChild("MountHorse")
local DismountHorse = MountEvents:WaitForChild("DismountHorse")

-- Wait for character selection system (optional - may not exist)
local SelectionEvents = ReplicatedStorage:WaitForChild("SelectionEvents", 5)
local GetCharacterData = SelectionEvents and SelectionEvents:WaitForChild("GetCharacterData", 5)

-- ============================================
-- TUNING VALUES (tweak these)
-- ============================================
local Config = {
    -- Speed
    BASE_SPEED = 40,           -- Walking speed
    SPRINT_SPEED = 80,         -- Full gallop (2x base speed)
    ACCELERATION = 1.2,        -- How fast you reach target speed (lower = more horse-like buildup)
    DECELERATION = 3.0,        -- How fast you slow down when not pressing forward
    EMPTY_STAMINA_PENALTY = 0.7, -- Speed multiplier when stamina bottoms out

    -- Stamina
    MAX_STAMINA = 100,
    SPRINT_DRAIN = 15,         -- Per second while sprinting
    JUMP_COST = 20,            -- Flat cost per jump
    REGEN_MIN_RATE = 8,        -- Regen per second when stamina is low
    REGEN_MAX_RATE = 45,       -- Regen per second when stamina is high (very fast top-off)
    REGEN_DELAY = 0.5,         -- Seconds before regen starts
    EMPTY_PENALTY_DURATION = 2, -- Seconds of penalty when emptied

    -- Turning (degrees per second for frame-rate independence)
    BASE_TURN_RATE = 150,      -- Degrees per second at low speed
    MIN_TURN_RATE = 60,        -- Degrees per second at max speed (harder to turn when fast)
    DRIFT_TURN_BONUS = 2.0,    -- Multiplier to turn rate while drifting (for aiming)
    DRIFT_RELEASE_RETAIN = 0.92, -- Speed retained when releasing drift (sharp turn)
    DRIFT_STAMINA_DRAIN = 8,   -- Additional stamina drain per second while drifting

    -- Jumping
    JUMP_POWER = 66,           -- Base jump power
    DOUBLE_JUMP_POWER = 55,    -- Second jump power (slightly less)
    DOUBLE_JUMP_COST = 25,     -- Stamina cost for double jump
    AIR_TURN_RATE = 15,        -- Degrees per second in air (normal)
    DOUBLE_JUMP_TURN_RATE = 120, -- Degrees per second after double jump
    DOUBLE_JUMP_TURN_DURATION = 0.8, -- How long enhanced air turning lasts
    AIR_CONTROL = 0.15,        -- How much you can influence air velocity (0-1)

    -- Feel
    MOMENTUM_FACTOR = 0.92,    -- How much velocity carries frame-to-frame (0.9-0.99)

    -- Wall Collision
    WALL_CHECK_DISTANCE = 3,   -- How far ahead to check for walls
    WALL_CHECK_HEIGHTS = {0, 3, 6, 9, 12}, -- Heights to raycast at (covers full fence height)

    -- Burst (double-tap sprint)
    BURST_SPEED_MULT = 1.4,    -- Speed multiplier during burst (1.4x sprint)
    BURST_DURATION = 1.5,      -- How long burst lasts (seconds)
    BURST_COST = 25,           -- Stamina cost to trigger burst
    BURST_COOLDOWN = 3.0,      -- Seconds before burst can be used again
    BURST_TAP_WINDOW = 0.3,    -- Seconds to double-tap for burst
    BURST_TURN_PENALTY = 0.4,  -- Turn rate multiplier during burst

    -- Body Tilt
    MAX_TILT_ANGLE = 15,       -- Maximum lean angle in degrees
    TILT_SPEED = 8,            -- How fast tilt responds (higher = snappier)

    -- Camera Follow
    CAMERA_DISTANCE = 14,      -- Distance behind horse
    CAMERA_HEIGHT = 8,         -- Height above horse
    CAMERA_SMOOTH = 8,         -- How fast camera follows (higher = snappier)

    -- Rider positioning
    RIDER_HEIGHT_OFFSET = 4,   -- How high above horse body the rider sits
}

-- Store default config for reset
local DefaultConfig = {}
for k, v in pairs(Config) do
    DefaultConfig[k] = v
end

-- ============================================
-- CHARACTER DATA (loaded from server)
-- ============================================
local characterData = {
    id = nil,
    stats = {},
    abilityParams = {},
    ability = nil,
}

-- ============================================
-- ABILITY STATE
-- ============================================
local abilityState = {
    -- Gyro: Precision Burst
    precisionBurstActive = false,

    -- Diego: Drift Surge
    driftStartTime = 0,
    driftSurgeActive = false,
    driftSurgeTimer = 0,
    driftSurgeSpeedMult = 1,

    -- Hot Pants: Phase Shift
    blinkCooldown = 0,
    blinkRequested = false,

    -- Sandman: Momentum
    momentumBonus = 0,
    cruiseTimer = 0,
}

-- ============================================
-- STATE
-- ============================================
local state = {
    -- Mount state
    isMounted = false,
    currentHorse = nil,
    riderWeld = nil,           -- Weld attaching player to horse
    horseAnimator = nil,       -- Procedural animation controller

    -- Input
    moveInput = 0,
    turnInput = 0,
    isSprinting = false,
    isDrifting = false,
    jumpRequested = false,

    -- Drift
    wasDrifting = false,
    driftVelocityDir = Vector3.zero,
    driftSpeed = 0,

    -- Physics
    currentSpeed = 0,
    facingAngle = 0,
    velocity = Vector3.zero,
    isGrounded = true,
    verticalVelocity = 0,      -- For jump physics

    -- Stamina
    stamina = Config.MAX_STAMINA,
    regenTimer = 0,
    penaltyTimer = 0,

    -- Burst
    lastSprintTap = 0,
    isBursting = false,
    burstTimer = 0,
    burstCooldown = 0,

    -- Tilt
    currentTilt = 0,
    turnRate = 0,

    -- Double Jump
    canDoubleJump = false,
    doubleJumpTurnTimer = 0,
    jumpGraceTimer = 0,

    -- Camera
    cameraAngle = 0,

    -- References
    character = nil,
    humanoid = nil,
    rootPart = nil,
}

-- UI references
local screenGui = nil
local staminaFill = nil
local speedFill = nil
local speedLabel = nil
local statusLabel = nil

-- ============================================
-- INPUT HANDLING
-- ============================================
local function tryTriggerBurst()
    if state.burstCooldown > 0 then return false end
    if state.stamina < Config.BURST_COST then return false end
    if state.penaltyTimer > 0 then return false end
    if not state.isGrounded then return false end

    state.isBursting = true
    state.burstTimer = Config.BURST_DURATION
    state.burstCooldown = Config.BURST_COOLDOWN
    state.stamina = state.stamina - Config.BURST_COST
    return true
end

local function bindMountedInputs()
    ContextActionService:BindAction("MountedSprint", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            local now = tick()
            if (now - state.lastSprintTap) <= Config.BURST_TAP_WINDOW then
                tryTriggerBurst()
            end
            state.lastSprintTap = now
            state.isSprinting = true
        elseif inputState == Enum.UserInputState.End then
            state.isSprinting = false
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.LeftShift)

    ContextActionService:BindAction("MountedDrift", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            state.isDrifting = true
        elseif inputState == Enum.UserInputState.End then
            state.isDrifting = false
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.Q)

    ContextActionService:BindAction("MountedJump", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            state.jumpRequested = true
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.Space)

    ContextActionService:BindAction("Dismount", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            dismount()
        end
        return Enum.ContextActionResult.Sink
    end, false, Enum.KeyCode.X)

    -- Ability key (Hot Pants: Phase Shift)
    ContextActionService:BindAction("AbilityKey", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            if characterData.id == "HotPants" then
                abilityState.blinkRequested = true
            end
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.F)
end

local function unbindMountedInputs()
    ContextActionService:UnbindAction("MountedSprint")
    ContextActionService:UnbindAction("MountedDrift")
    ContextActionService:UnbindAction("MountedJump")
    ContextActionService:UnbindAction("Dismount")
    ContextActionService:UnbindAction("AbilityKey")
    state.isSprinting = false
    state.isDrifting = false
    state.jumpRequested = false
    state.isBursting = false
    state.burstTimer = 0
end

local function getInput()
    local move = 0
    local turn = 0

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        move = move + 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        move = move - 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        turn = turn - 1
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        turn = turn + 1
    end

    return move, turn
end

-- ============================================
-- CHARACTER DATA LOADING
-- ============================================
local function loadCharacterData()
    if not GetCharacterData then
        print("[MountedMovement] GetCharacterData not available - using defaults")
        return
    end

    local data = GetCharacterData:InvokeServer()
    if data then
        characterData.id = data.id
        characterData.stats = data.stats or {}
        characterData.abilityParams = data.abilityParams or {}
        characterData.ability = data.ability
        print("[MountedMovement] Loaded character:", data.id, "Ability:", data.ability)
    else
        print("[MountedMovement] No character data - using defaults")
    end
end

local function applyCharacterStats()
    -- Reset to defaults first
    for k, v in pairs(DefaultConfig) do
        Config[k] = v
    end

    -- Apply character-specific stats
    for stat, value in pairs(characterData.stats) do
        if Config[stat] ~= nil then
            Config[stat] = value
        end
    end

    -- Reset stamina to new max
    state.stamina = Config.MAX_STAMINA
end

local function resetAbilityState()
    abilityState.precisionBurstActive = false
    abilityState.driftStartTime = 0
    abilityState.driftSurgeActive = false
    abilityState.driftSurgeTimer = 0
    abilityState.driftSurgeSpeedMult = 1
    abilityState.blinkCooldown = 0
    abilityState.blinkRequested = false
    abilityState.momentumBonus = 0
    abilityState.cruiseTimer = 0
end

-- ============================================
-- BURST SYSTEM
-- ============================================
local function updateBurst(dt)
    if state.burstCooldown > 0 then
        state.burstCooldown = state.burstCooldown - dt
    end

    if state.isBursting then
        state.burstTimer = state.burstTimer - dt
        if state.burstTimer <= 0 then
            state.isBursting = false
            state.burstTimer = 0
        end
    end
end

-- ============================================
-- CHARACTER ABILITIES
-- ============================================

-- Gyro: Precision Burst - stronger at high stamina + better turning
local function getGyroBurstMultiplier()
    if characterData.id ~= "Gyro" then return 1 end

    local params = characterData.abilityParams
    local staminaRatio = state.stamina / Config.MAX_STAMINA

    if staminaRatio >= (params.staminaThreshold or 0.8) then
        return params.maxStaminaBurstMult or 1.6
    else
        -- Lerp between low and max based on stamina
        local t = staminaRatio / (params.staminaThreshold or 0.8)
        local lowMult = params.lowStaminaBurstMult or 1.2
        local highMult = params.maxStaminaBurstMult or 1.6
        return lowMult + (highMult - lowMult) * t
    end
end

local function getGyroBurstTurnBonus()
    if characterData.id ~= "Gyro" or not state.isBursting then return 1 end
    return characterData.abilityParams.burstTurnBonus or 1.5
end

-- Diego: Launch Jump - supercharged jumps during burst
local function getDiegoJumpMultiplier()
    if characterData.id ~= "Diego" or not state.isBursting then return 1 end
    return characterData.abilityParams.burstJumpMult or 1.8
end

local function getDiegoDoubleJumpMultiplier()
    if characterData.id ~= "Diego" or not state.isBursting then return 1 end
    return characterData.abilityParams.burstDoubleJumpMult or 2.0
end

-- Johnny: Drift Surge - speed boost on drift exit
local function updateJohnnyAbility(dt)
    if characterData.id ~= "Johnny" then return end

    local params = characterData.abilityParams

    -- Track drift duration
    local activeDrift = state.isDrifting and state.isSprinting and state.isGrounded and not state.isBursting

    if activeDrift and not state.wasDrifting then
        -- Started drifting
        abilityState.driftStartTime = tick()
    elseif state.wasDrifting and not activeDrift and abilityState.driftStartTime > 0 then
        -- Ended drift - calculate boost
        local driftDuration = tick() - abilityState.driftStartTime
        local maxDriftTime = params.driftTimeForMaxBoost or 1.5
        local t = math.clamp(driftDuration / maxDriftTime, 0, 1)

        local baseBoost = params.driftBoostBase or 1.15
        local maxBoost = params.driftBoostMax or 1.4
        abilityState.driftSurgeSpeedMult = baseBoost + (maxBoost - baseBoost) * t
        abilityState.driftSurgeActive = true
        abilityState.driftSurgeTimer = params.driftBoostDuration or 1.2
        abilityState.driftStartTime = 0
    end

    -- Update surge timer
    if abilityState.driftSurgeActive then
        abilityState.driftSurgeTimer = abilityState.driftSurgeTimer - dt
        if abilityState.driftSurgeTimer <= 0 then
            abilityState.driftSurgeActive = false
            abilityState.driftSurgeSpeedMult = 1
        end
    end
end

local function getJohnnyDriftSurgeMultiplier()
    if characterData.id ~= "Johnny" or not abilityState.driftSurgeActive then return 1 end
    return abilityState.driftSurgeSpeedMult
end

-- Hot Pants: Phase Shift - blink forward
local function tryBlink()
    if characterData.id ~= "HotPants" then return false end
    if abilityState.blinkCooldown > 0 then return false end

    local params = characterData.abilityParams
    local cost = params.blinkStaminaCost or 25

    if state.stamina < cost then return false end

    local horse = state.currentHorse
    if not horse or not horse.PrimaryPart then return false end

    -- Consume stamina
    state.stamina = state.stamina - cost

    -- Calculate blink destination
    local distance = params.blinkDistance or 18
    local facingDir = Vector3.new(math.sin(state.facingAngle), 0, math.cos(state.facingAngle))
    local currentPos = horse.PrimaryPart.Position
    local targetPos = currentPos + facingDir * distance

    -- Raycast to check for obstacles
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {horse, state.character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(currentPos, facingDir * distance, rayParams)
    if result then
        -- Hit something, blink to just before it
        targetPos = result.Position - facingDir * 2
    end

    -- Check ground at target position
    local groundRay = workspace:Raycast(targetPos + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), rayParams)
    if groundRay then
        targetPos = Vector3.new(targetPos.X, groundRay.Position.Y + 2, targetPos.Z)
    end

    -- Teleport horse
    local newCFrame = CFrame.new(targetPos) * CFrame.Angles(0, state.facingAngle, 0)
    horse:PivotTo(newCFrame)

    -- Maintain momentum (or boost it)
    local momentumRetain = params.blinkMomentumRetain or 1.0
    state.velocity = state.velocity * momentumRetain

    -- Set cooldown
    abilityState.blinkCooldown = params.blinkCooldown or 4.0

    print("[MountedMovement] Phase Shift activated!")
    return true
end

local function updateBlinkCooldown(dt)
    if characterData.id ~= "HotPants" then return end

    if abilityState.blinkCooldown > 0 then
        abilityState.blinkCooldown = abilityState.blinkCooldown - dt
    end

    if abilityState.blinkRequested then
        abilityState.blinkRequested = false
        tryBlink()
    end
end

-- Sandman: Momentum - build speed while cruising
local function updateSandmanAbility(dt)
    if characterData.id ~= "Sandman" then return end

    local params = characterData.abilityParams
    local threshold = params.cruiseSpeedThreshold or 0.6
    local minCruiseSpeed = Config.BASE_SPEED * threshold

    -- Check if cruising (moving forward, not sprinting, above threshold)
    local isCruising = state.moveInput > 0
        and not state.isSprinting
        and state.currentSpeed >= minCruiseSpeed
        and state.isGrounded

    if isCruising then
        -- Build momentum
        local buildRate = params.momentumBuildRate or 0.08
        local maxBonus = params.momentumMaxBonus or 15
        abilityState.momentumBonus = math.min(maxBonus, abilityState.momentumBonus + buildRate * dt * 60)
    else
        -- Decay momentum (unless sprinting and sprintResetsBonus is false)
        local shouldDecay = true
        if state.isSprinting and not (params.sprintResetsBonus == true) then
            shouldDecay = false -- Keep momentum while sprinting
        end

        if shouldDecay then
            local decayRate = params.momentumDecayRate or 0.3
            abilityState.momentumBonus = math.max(0, abilityState.momentumBonus - decayRate * dt * 60)
        end
    end
end

local function getSandmanMomentumBonus()
    if characterData.id ~= "Sandman" then return 0 end
    return abilityState.momentumBonus
end

-- ============================================
-- STAMINA SYSTEM
-- ============================================
local function updateStamina(dt)
    local draining = false

    if state.isSprinting and state.moveInput > 0 and state.isGrounded then
        state.stamina = state.stamina - (Config.SPRINT_DRAIN * dt)
        draining = true
    end

    if state.isDrifting and state.isSprinting and state.isGrounded and state.moveInput > 0 then
        state.stamina = state.stamina - (Config.DRIFT_STAMINA_DRAIN * dt)
        draining = true
    end

    if state.stamina <= 0 then
        if state.penaltyTimer <= 0 then
            state.penaltyTimer = Config.EMPTY_PENALTY_DURATION
        end
        state.stamina = 0
    end

    if state.penaltyTimer > 0 then
        state.penaltyTimer = state.penaltyTimer - dt
    end

    if draining then
        state.regenTimer = Config.REGEN_DELAY
    else
        state.regenTimer = math.max(0, state.regenTimer - dt)
        if state.regenTimer <= 0 and state.penaltyTimer <= 0 then
            local staminaRatio = state.stamina / Config.MAX_STAMINA
            local curve = staminaRatio * staminaRatio
            local regenRate = Config.REGEN_MIN_RATE + (curve * (Config.REGEN_MAX_RATE - Config.REGEN_MIN_RATE))
            state.stamina = math.min(Config.MAX_STAMINA, state.stamina + (regenRate * dt))
        end
    end
end

-- ============================================
-- MOVEMENT PHYSICS
-- ============================================
local function calculateTargetSpeed()
    if state.moveInput == 0 then
        return 0
    end

    local target = Config.BASE_SPEED

    -- Sandman: Add momentum bonus to base speed
    target = target + getSandmanMomentumBonus()

    if state.isSprinting and state.stamina > 0 and state.penaltyTimer <= 0 and state.moveInput > 0 then
        target = Config.SPRINT_SPEED + getSandmanMomentumBonus()
    end

    if state.isBursting then
        local burstMult = Config.BURST_SPEED_MULT * getGyroBurstMultiplier()
        target = Config.SPRINT_SPEED * burstMult
    end

    -- Johnny: Apply drift surge multiplier
    target = target * getJohnnyDriftSurgeMultiplier()

    if state.penaltyTimer > 0 then
        target = target * Config.EMPTY_STAMINA_PENALTY
    end

    if state.moveInput < 0 then
        target = target * 0.5
    end

    return target
end

local function calculateTurnRate(dt)
    local speedRatio = state.currentSpeed / Config.SPRINT_SPEED
    local turnRate = Config.BASE_TURN_RATE - (speedRatio * (Config.BASE_TURN_RATE - Config.MIN_TURN_RATE))

    if state.isBursting then
        turnRate = turnRate * Config.BURST_TURN_PENALTY
        -- Gyro: Better turning during burst
        turnRate = turnRate * getGyroBurstTurnBonus()
    end

    if state.isDrifting and state.isSprinting and state.isGrounded and not state.isBursting then
        turnRate = turnRate * Config.DRIFT_TURN_BONUS
    end

    if not state.isGrounded then
        if state.doubleJumpTurnTimer > 0 then
            turnRate = Config.DOUBLE_JUMP_TURN_RATE
        else
            turnRate = Config.AIR_TURN_RATE
        end
    end

    return math.rad(turnRate) * dt
end

local function updateGroundedState()
    local horse = state.currentHorse
    if not horse or not horse.PrimaryPart then return end

    -- Skip ground detection during jump grace period (prevents false landing right after jump)
    if state.jumpGraceTimer > 0 then
        return
    end

    local wasGrounded = state.isGrounded

    local rayOrigin = horse.PrimaryPart.Position
    local rayDirection = Vector3.new(0, -4, 0)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {horse, state.character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
    state.isGrounded = (result ~= nil)

    -- Reset double jump on landing
    if state.isGrounded and not wasGrounded then
        state.canDoubleJump = false
        state.doubleJumpTurnTimer = 0
        state.verticalVelocity = 0
    end
end

-- Check for wall collision in the movement direction
-- Returns true if movement is blocked, false if clear
local function checkWallCollision(horse, movementDir, distance)
    if not horse or not horse.PrimaryPart then return false end
    if movementDir.Magnitude < 0.01 then return false end

    local basePos = horse.PrimaryPart.Position
    local normalizedDir = movementDir.Unit
    local checkDistance = math.max(distance, Config.WALL_CHECK_DISTANCE)

    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {horse, state.character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    -- Check at multiple heights to prevent jumping over fences
    for _, heightOffset in ipairs(Config.WALL_CHECK_HEIGHTS) do
        local rayOrigin = basePos + Vector3.new(0, heightOffset, 0)
        local rayDir = Vector3.new(normalizedDir.X, 0, normalizedDir.Z) * checkDistance

        local result = workspace:Raycast(rayOrigin, rayDir, rayParams)
        if result then
            -- Wall detected at this height
            return true, result.Position, result.Normal
        end
    end

    return false
end

local function updateMovement(dt)
    local horse = state.currentHorse
    if not horse or not horse.PrimaryPart then return end

    state.moveInput, state.turnInput = getInput()
    updateGroundedState()

    if state.jumpGraceTimer > 0 then
        state.jumpGraceTimer = state.jumpGraceTimer - dt
    end

    if state.doubleJumpTurnTimer > 0 then
        state.doubleJumpTurnTimer = state.doubleJumpTurnTimer - dt
    end

    -- Target speed
    local targetSpeed = calculateTargetSpeed()

    -- Accelerate/decelerate
    if targetSpeed > state.currentSpeed then
        state.currentSpeed = state.currentSpeed + (Config.ACCELERATION * dt * (targetSpeed - state.currentSpeed))
    else
        state.currentSpeed = state.currentSpeed - (Config.DECELERATION * dt * (state.currentSpeed - targetSpeed))
    end
    state.currentSpeed = math.max(0, state.currentSpeed)

    -- Turning
    local actualTurnRate = 0
    if state.turnInput ~= 0 then
        local maxTurn = calculateTurnRate(dt)
        local turnAmount = state.turnInput * maxTurn
        state.facingAngle = state.facingAngle + turnAmount
        if dt > 0 then
            actualTurnRate = turnAmount / dt
        end
    end
    state.turnRate = actualTurnRate

    -- Calculate velocity
    local facingDir = Vector3.new(math.sin(state.facingAngle), 0, math.cos(state.facingAngle))
    local targetVelocity = facingDir * state.currentSpeed

    -- Drift system
    local activeDrift = state.isDrifting and state.isSprinting and state.isGrounded and not state.isBursting

    if activeDrift and not state.wasDrifting then
        if state.velocity.Magnitude > 0.1 then
            state.driftVelocityDir = state.velocity.Unit
        else
            state.driftVelocityDir = facingDir
        end
        state.driftSpeed = state.currentSpeed
    end

    if state.wasDrifting and not activeDrift and state.driftSpeed > 0 then
        local retainedSpeed = state.driftSpeed * Config.DRIFT_RELEASE_RETAIN
        state.velocity = facingDir * retainedSpeed
        state.currentSpeed = retainedSpeed
        state.driftSpeed = 0
    end

    state.wasDrifting = activeDrift

    -- Apply momentum
    local smoothing = 1 - math.pow(Config.MOMENTUM_FACTOR, dt * 60)
    if state.isGrounded then
        if activeDrift then
            state.velocity = state.driftVelocityDir * state.currentSpeed
        else
            state.velocity = state.velocity:Lerp(targetVelocity, smoothing)
        end
    else
        -- In air: preserve horizontal momentum, turning changes facing direction only
        state.velocity = Vector3.new(state.velocity.X, 0, state.velocity.Z)
    end

    -- Apply gravity when in air
    if not state.isGrounded then
        state.verticalVelocity = state.verticalVelocity - (196.2 * dt) -- Roblox gravity
    end

    -- Calculate body tilt
    local speedRatio = math.clamp(state.currentSpeed / Config.SPRINT_SPEED, 0, 1)
    local maxTiltRad = math.rad(Config.MAX_TILT_ANGLE)
    local targetTilt = state.turnRate * speedRatio * 0.3
    targetTilt = math.clamp(targetTilt, -maxTiltRad, maxTiltRad)

    local tiltSmoothing = 1 - math.exp(-Config.TILT_SPEED * dt)
    state.currentTilt = state.currentTilt + (targetTilt - state.currentTilt) * tiltSmoothing

    -- Move the horse
    local currentPos = horse.PrimaryPart.Position
    local movement = state.velocity * dt
    local verticalMovement = state.verticalVelocity * dt

    -- Wall collision check - prevent moving into fences/walls
    -- This checks at multiple heights so players can't jump over fences
    local horizontalMovement = Vector3.new(movement.X, 0, movement.Z)
    if horizontalMovement.Magnitude > 0.001 then
        local isBlocked = checkWallCollision(horse, horizontalMovement, horizontalMovement.Magnitude + 1)
        if isBlocked then
            -- Stop horizontal movement and velocity when hitting a wall
            movement = Vector3.new(0, 0, 0)
            state.velocity = Vector3.zero
            state.currentSpeed = 0
        end
    end

    -- Ground check for landing (skip during grace period to prevent false landings)
    if state.verticalVelocity < 0 and state.jumpGraceTimer <= 0 then
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {horse, state.character}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        local result = workspace:Raycast(currentPos, Vector3.new(0, verticalMovement - 0.5, 0), rayParams)
        if result then
            verticalMovement = result.Position.Y - currentPos.Y + 2 -- Keep horse above ground
            state.verticalVelocity = 0
            state.isGrounded = true
            state.canDoubleJump = false
            state.doubleJumpTurnTimer = 0
        end
    end

    local newPos = currentPos + Vector3.new(movement.X, verticalMovement, movement.Z)

    -- Apply new CFrame to horse with tilt (negate tilt so right turn = lean right)
    local newCFrame = CFrame.new(newPos)
        * CFrame.Angles(0, state.facingAngle, 0)
        * CFrame.Angles(0, 0, -state.currentTilt)

    horse:PivotTo(newCFrame)
end

local function handleJump()
    if not state.jumpRequested then return end
    state.jumpRequested = false

    if state.isGrounded then
        if state.stamina < Config.JUMP_COST and state.penaltyTimer <= 0 then return end

        if state.penaltyTimer <= 0 then
            state.stamina = state.stamina - Config.JUMP_COST
        end

        -- Diego: Supercharged jump during burst
        local jumpPower = Config.JUMP_POWER * getDiegoJumpMultiplier()
        state.verticalVelocity = jumpPower

        -- Diego: Also boost horizontal speed during burst jump
        if characterData.id == "Diego" and state.isBursting then
            local params = characterData.abilityParams
            local speedBoost = params.launchSpeedBoost or 1.2
            state.currentSpeed = state.currentSpeed * speedBoost
        end

        state.isGrounded = false
        state.canDoubleJump = true
        state.jumpGraceTimer = 0.15
        return
    end

    if state.canDoubleJump then
        if state.stamina < Config.DOUBLE_JUMP_COST and state.penaltyTimer <= 0 then return end

        if state.penaltyTimer <= 0 then
            state.stamina = state.stamina - Config.DOUBLE_JUMP_COST
        end

        -- Diego: Even more supercharged double jump during burst
        local doubleJumpPower = Config.DOUBLE_JUMP_POWER * getDiegoDoubleJumpMultiplier()
        state.verticalVelocity = doubleJumpPower
        state.canDoubleJump = false
        state.doubleJumpTurnTimer = Config.DOUBLE_JUMP_TURN_DURATION
    end
end

-- ============================================
-- UI
-- ============================================
local function createUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MountedMovementUI"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    screenGui.Parent = player.PlayerGui

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 200, 0, 50)
    container.Position = UDim2.new(0.5, -100, 1, -70)
    container.BackgroundTransparency = 1
    container.Parent = screenGui

    local speedFrame = Instance.new("Frame")
    speedFrame.Name = "SpeedBar"
    speedFrame.Size = UDim2.new(1, 0, 0, 12)
    speedFrame.Position = UDim2.new(0, 0, 0, 0)
    speedFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    speedFrame.BorderSizePixel = 0
    speedFrame.Parent = container

    speedFill = Instance.new("Frame")
    speedFill.Name = "Fill"
    speedFill.Size = UDim2.new(0, 0, 1, 0)
    speedFill.BackgroundColor3 = Color3.fromRGB(80, 150, 220)
    speedFill.BorderSizePixel = 0
    speedFill.Parent = speedFrame

    speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "Label"
    speedLabel.Size = UDim2.new(1, 0, 1, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    speedLabel.TextSize = 10
    speedLabel.Font = Enum.Font.GothamBold
    speedLabel.Text = "0"
    speedLabel.Parent = speedFrame

    local staminaFrame = Instance.new("Frame")
    staminaFrame.Name = "StaminaBar"
    staminaFrame.Size = UDim2.new(1, 0, 0, 20)
    staminaFrame.Position = UDim2.new(0, 0, 0, 18)
    staminaFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    staminaFrame.BorderSizePixel = 0
    staminaFrame.Parent = container

    staminaFill = Instance.new("Frame")
    staminaFill.Name = "Fill"
    staminaFill.Size = UDim2.new(1, 0, 1, 0)
    staminaFill.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    staminaFill.BorderSizePixel = 0
    staminaFill.Parent = staminaFrame

    for _, frame in ipairs({speedFrame, speedFill, staminaFrame, staminaFill}) do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = frame
    end

    statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, 0, 0, 14)
    statusLabel.Position = UDim2.new(0, 0, 0, 40)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = ""
    statusLabel.Parent = container

    local dismountHint = Instance.new("TextLabel")
    dismountHint.Name = "DismountHint"
    dismountHint.Size = UDim2.new(1, 0, 0, 14)
    dismountHint.Position = UDim2.new(0, 0, 0, -18)
    dismountHint.BackgroundTransparency = 1
    dismountHint.TextColor3 = Color3.fromRGB(150, 150, 150)
    dismountHint.TextSize = 10
    dismountHint.Font = Enum.Font.Gotham
    dismountHint.Text = "[X] Dismount"
    dismountHint.Parent = container
end

local function updateUI()
    if not staminaFill then return end

    local staminaRatio = state.stamina / Config.MAX_STAMINA
    staminaFill.Size = UDim2.new(staminaRatio, 0, 1, 0)

    if state.penaltyTimer > 0 then
        staminaFill.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    elseif staminaRatio < 0.3 then
        staminaFill.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
    else
        staminaFill.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    end

    local maxSpeed = Config.SPRINT_SPEED * Config.BURST_SPEED_MULT
    local speedRatio = state.currentSpeed / maxSpeed
    speedFill.Size = UDim2.new(math.min(1, speedRatio), 0, 1, 0)
    speedLabel.Text = string.format("%.0f", state.currentSpeed)

    if state.isBursting then
        speedFill.BackgroundColor3 = Color3.fromRGB(255, 140, 50)
    elseif state.isSprinting and state.currentSpeed > Config.BASE_SPEED then
        speedFill.BackgroundColor3 = Color3.fromRGB(50, 200, 220)
    else
        speedFill.BackgroundColor3 = Color3.fromRGB(80, 150, 220)
    end

    local status = {}
    if state.isBursting then
        table.insert(status, "BURST")
    elseif state.isSprinting then
        table.insert(status, "SPRINT")
    end
    if state.isDrifting then table.insert(status, "DRIFT") end
    if not state.isGrounded then
        if state.doubleJumpTurnTimer > 0 then
            table.insert(status, "DJUMP")
        elseif state.canDoubleJump then
            table.insert(status, "AIR+")
        else
            table.insert(status, "AIR")
        end
    end
    if state.burstCooldown > 0 and not state.isBursting then
        table.insert(status, string.format("CD:%.1f", state.burstCooldown))
    end

    -- Character-specific ability status
    if characterData.id == "Johnny" and abilityState.driftSurgeActive then
        table.insert(status, string.format("SURGE:%.1f", abilityState.driftSurgeTimer))
    end
    if characterData.id == "HotPants" then
        if abilityState.blinkCooldown > 0 then
            table.insert(status, string.format("[F]:%.1f", abilityState.blinkCooldown))
        else
            table.insert(status, "[F]RDY")
        end
    end
    if characterData.id == "Sandman" and abilityState.momentumBonus > 0 then
        table.insert(status, string.format("MTM:+%.0f", abilityState.momentumBonus))
    end

    statusLabel.Text = table.concat(status, " | ")
end

-- ============================================
-- CAMERA FOLLOW
-- ============================================
local function updateCamera(dt)
    local horse = state.currentHorse
    if not horse or not horse.PrimaryPart then return end

    local angleDiff = state.facingAngle - state.cameraAngle

    while angleDiff > math.pi do angleDiff = angleDiff - (2 * math.pi) end
    while angleDiff < -math.pi do angleDiff = angleDiff + (2 * math.pi) end

    local smoothing = 1 - math.exp(-Config.CAMERA_SMOOTH * dt)
    state.cameraAngle = state.cameraAngle + angleDiff * smoothing

    local horsePos = horse.PrimaryPart.Position
    -- Camera positioned behind the horse (opposite to movement direction)
    local behindOffset = Vector3.new(
        -math.sin(state.cameraAngle) * Config.CAMERA_DISTANCE,
        Config.CAMERA_HEIGHT,
        -math.cos(state.cameraAngle) * Config.CAMERA_DISTANCE
    )

    local cameraPos = horsePos + behindOffset
    local lookAt = horsePos + Vector3.new(0, 3, 0)

    camera.CFrame = CFrame.lookAt(cameraPos, lookAt)
end

-- ============================================
-- MOUNT / DISMOUNT
-- ============================================
local function mount(horse)
    print("[MountedMovement] Mount called with horse:", horse and horse.Name or "nil")

    if state.isMounted then
        print("[MountedMovement] Already mounted, ignoring")
        return
    end
    if not state.humanoid or not state.rootPart then
        print("[MountedMovement] No humanoid or rootPart - waiting for character")
        return
    end
    if not horse then
        print("[MountedMovement] No horse provided")
        return
    end

    -- Find PrimaryPart if not set
    if not horse.PrimaryPart then
        print("[MountedMovement] Horse has no PrimaryPart, searching...")
        local candidates = {"HumanoidRootPart", "Torso", "Body"}
        for _, name in ipairs(candidates) do
            local part = horse:FindFirstChild(name, true)
            if part and part:IsA("BasePart") then
                horse.PrimaryPart = part
                print("[MountedMovement] Set PrimaryPart to:", name)
                break
            end
        end
    end

    if not horse.PrimaryPart then
        print("[MountedMovement] ERROR: Could not find PrimaryPart for horse")
        return
    end

    print("[MountedMovement] Using PrimaryPart:", horse.PrimaryPart.Name)

    -- Load character data from server and apply stats
    loadCharacterData()
    applyCharacterStats()
    resetAbilityState()

    state.isMounted = true
    state.currentHorse = horse

    -- Disable player's normal movement
    state.humanoid.PlatformStand = true

    -- Position player on the horse
    local horseBody = horse.PrimaryPart
    local seatPosition = horseBody.Position + Vector3.new(0, Config.RIDER_HEIGHT_OFFSET, 0)

    -- Create weld to attach player to horse
    -- Rotate rider 180° so they face forward (Roblox characters face -Z, horse faces +Z)
    state.riderWeld = Instance.new("Weld")
    state.riderWeld.Part0 = horseBody
    state.riderWeld.Part1 = state.rootPart
    state.riderWeld.C0 = CFrame.new(0, Config.RIDER_HEIGHT_OFFSET, 0) * CFrame.Angles(0, math.pi, 0)
    state.riderWeld.C1 = CFrame.new()
    state.riderWeld.Parent = horseBody

    -- Initialize facing angle from horse orientation
    local _, y, _ = horseBody.CFrame:ToEulerAnglesYXZ()
    state.facingAngle = y
    state.cameraAngle = y

    -- Reset mounted state
    state.currentSpeed = 0
    state.stamina = Config.MAX_STAMINA
    state.penaltyTimer = 0
    state.regenTimer = 0
    state.velocity = Vector3.zero
    state.currentTilt = 0
    state.isBursting = false
    state.burstTimer = 0
    state.burstCooldown = 0
    state.verticalVelocity = 0
    state.isGrounded = true

    -- Bind mounted controls
    bindMountedInputs()

    -- Set camera to Scriptable for manual control
    camera.CameraType = Enum.CameraType.Scriptable

    -- Initialize procedural horse animation
    local animSuccess, animResult = pcall(function()
        return HorseAnimation.new(horse)
    end)
    if animSuccess then
        state.horseAnimator = animResult
        print("[MountedMovement] Horse animation initialized")
    else
        warn("[MountedMovement] Failed to initialize horse animation:", animResult)
        state.horseAnimator = nil
    end

    -- Show UI
    if screenGui then
        screenGui.Enabled = true
        print("[MountedMovement] UI enabled")
    else
        warn("[MountedMovement] No screenGui found!")
    end

    print("[MountedMovement] Mounted horse as", characterData.id or "default")
end

function dismount()
    if not state.isMounted then return end

    state.isMounted = false

    -- Cleanup horse animation
    if state.horseAnimator then
        state.horseAnimator:destroy()
        state.horseAnimator = nil
    end

    -- Remove weld
    if state.riderWeld then
        state.riderWeld:Destroy()
        state.riderWeld = nil
    end

    -- Restore player's normal movement
    if state.humanoid then
        state.humanoid.PlatformStand = false
    end

    -- Position player beside the horse
    local horse = state.currentHorse
    if horse and horse.PrimaryPart and state.rootPart then
        local horsePos = horse.PrimaryPart.Position
        local dismountOffset = Vector3.new(4, 0, 0) -- Dismount to the side
        local dismountCFrame = CFrame.new(horsePos + dismountOffset)
        state.rootPart.CFrame = dismountCFrame
    end

    -- Unbind mounted controls
    unbindMountedInputs()

    -- Restore default camera
    camera.CameraType = Enum.CameraType.Custom

    -- Hide UI
    if screenGui then
        screenGui.Enabled = false
    end

    -- Notify server
    DismountHorse:FireServer()

    state.currentHorse = nil

    print("[MountedMovement] Dismounted")
end

-- ============================================
-- CHARACTER SETUP
-- ============================================
local function setupCharacter(character)
    state.character = character
    state.humanoid = character:WaitForChild("Humanoid")
    state.rootPart = character:WaitForChild("HumanoidRootPart")
end

local function cleanupCharacter()
    if state.isMounted then
        -- Cleanup horse animation
        if state.horseAnimator then
            state.horseAnimator:destroy()
            state.horseAnimator = nil
        end
        if state.riderWeld then
            state.riderWeld:Destroy()
            state.riderWeld = nil
        end
        unbindMountedInputs()
        camera.CameraType = Enum.CameraType.Custom
        if screenGui then
            screenGui.Enabled = false
        end
        state.isMounted = false
        state.currentHorse = nil
    end

    state.character = nil
    state.humanoid = nil
    state.rootPart = nil
end

-- ============================================
-- MAIN LOOP
-- ============================================

createUI()

if player.Character then
    setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(cleanupCharacter)

MountHorse.OnClientEvent:Connect(function(horse)
    print("[MountedMovement] Received MountHorse event, horse:", horse and horse:GetFullName() or "nil")
    mount(horse)
end)

RunService.RenderStepped:Connect(function(dt)
    if not state.isMounted then return end

    -- Core systems
    updateBurst(dt)
    updateStamina(dt)

    -- Character abilities (before movement so they can affect speed)
    updateJohnnyAbility(dt)
    updateBlinkCooldown(dt)
    updateSandmanAbility(dt)

    -- Movement and physics
    updateMovement(dt)
    handleJump()

    -- Horse procedural animation (legs, head, tail based on speed)
    if state.horseAnimator then
        state.horseAnimator:update(dt, state.currentSpeed, state.isGrounded)
    end

    -- Camera and UI
    updateCamera(dt)
    updateUI()
end)
