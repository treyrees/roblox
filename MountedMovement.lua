--[[
    MountedMovement.lua
    Horse-mounted racing movement with burst, body tilt, and double jump

    Controls:
    - WASD: Movement
    - Shift: Sprint (hold)
    - Shift (double-tap): Burst (speed boost, costs stamina)
    - Space: Jump (press again in air for double jump with enhanced turning)
    - Q: Drift (hold while turning)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

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
    BASE_TURN_RATE = 480,      -- Degrees per second at low speed
    MIN_TURN_RATE = 100,       -- Degrees per second at max speed (harder to turn when fast)
    DRIFT_TURN_BONUS = 2.0,    -- Multiplier to turn rate while drifting (for aiming)
    DRIFT_RELEASE_RETAIN = 0.92, -- Speed retained when releasing drift (sharp turn)
    DRIFT_STAMINA_DRAIN = 8,   -- Additional stamina drain per second while drifting
    
    -- Jumping
    JUMP_POWER = 66,           -- Base jump power (increased 20%)
    DOUBLE_JUMP_POWER = 55,    -- Second jump power (slightly less)
    DOUBLE_JUMP_COST = 25,     -- Stamina cost for double jump (25% more than base)
    AIR_TURN_RATE = 15,        -- Degrees per second in air (normal)
    DOUBLE_JUMP_TURN_RATE = 120, -- Degrees per second after double jump (enables repositioning)
    DOUBLE_JUMP_TURN_DURATION = 0.8, -- How long enhanced air turning lasts
    AIR_CONTROL = 0.15,        -- How much you can influence air velocity (0-1)
    
    -- Feel
    MOMENTUM_FACTOR = 0.92,    -- How much velocity carries frame-to-frame (0.9-0.99)

    -- Burst (double-tap sprint)
    BURST_SPEED_MULT = 1.4,    -- Speed multiplier during burst (1.4x sprint)
    BURST_DURATION = 1.5,      -- How long burst lasts (seconds)
    BURST_COST = 25,           -- Stamina cost to trigger burst
    BURST_COOLDOWN = 3.0,      -- Seconds before burst can be used again
    BURST_TAP_WINDOW = 0.3,    -- Seconds to double-tap for burst
    BURST_TURN_PENALTY = 0.4,  -- Turn rate multiplier during burst (commit factor - hard to steer)

    -- Body Tilt
    MAX_TILT_ANGLE = 15,       -- Maximum lean angle in degrees
    TILT_SPEED = 8,            -- How fast tilt responds (higher = snappier)
}

-- ============================================
-- STATE
-- ============================================
local state = {
    -- Input
    moveDirection = Vector3.zero,
    isSprinting = false,
    isDrifting = false,
    jumpRequested = false,

    -- Drift (momentum-preserving turn prep)
    wasDrifting = false,           -- Track previous frame's drift state (for release detection)
    driftVelocityDir = Vector3.zero, -- Locked velocity direction while drifting
    driftSpeed = 0,                -- Speed when drift started
    
    -- Physics
    currentSpeed = 0,
    facingAngle = 0,           -- Radians, world Y rotation
    velocity = Vector3.zero,
    isGrounded = true,
    
    -- Stamina
    stamina = Config.MAX_STAMINA,
    regenTimer = 0,
    penaltyTimer = 0,

    -- Burst
    lastSprintTap = 0,         -- Time of last sprint key press
    isBursting = false,
    burstTimer = 0,            -- Remaining burst duration
    burstCooldown = 0,         -- Cooldown until next burst

    -- Tilt
    currentTilt = 0,           -- Current body roll angle (radians)
    turnRate = 0,              -- Current turn rate for tilt calculation

    -- Double Jump
    canDoubleJump = false,     -- Whether double jump is available
    doubleJumpTurnTimer = 0,   -- Remaining enhanced air turn time
    jumpGraceTimer = 0,        -- Grace period after jumping to prevent false landing detection

    -- References
    character = nil,
    humanoid = nil,
    rootPart = nil,
}

-- ============================================
-- INPUT HANDLING
-- ============================================
local function tryTriggerBurst()
    -- Check if burst can be triggered
    if state.burstCooldown > 0 then return false end
    if state.stamina < Config.BURST_COST then return false end
    if state.penaltyTimer > 0 then return false end
    if not state.isGrounded then return false end

    -- Trigger burst
    state.isBursting = true
    state.burstTimer = Config.BURST_DURATION
    state.burstCooldown = Config.BURST_COOLDOWN
    state.stamina = state.stamina - Config.BURST_COST
    return true
end

local function bindInputs()
    -- Sprint (with double-tap burst detection)
    ContextActionService:BindAction("Sprint", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            local now = tick()
            -- Check for double-tap
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

    -- Drift (explicit Begin/End handling for reliability)
    ContextActionService:BindAction("Drift", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            state.isDrifting = true
        elseif inputState == Enum.UserInputState.End then
            state.isDrifting = false
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.Q)
    
    -- Jump
    ContextActionService:BindAction("Jump", function(_, inputState)
        if inputState == Enum.UserInputState.Begin then
            state.jumpRequested = true
        end
        return Enum.ContextActionResult.Pass
    end, false, Enum.KeyCode.Space)
end

local function unbindInputs()
    ContextActionService:UnbindAction("Sprint")
    ContextActionService:UnbindAction("Drift")
    ContextActionService:UnbindAction("Jump")
    -- Reset input state
    state.isSprinting = false
    state.isDrifting = false
    state.jumpRequested = false
    state.isBursting = false
    state.burstTimer = 0
end

local function getMoveDirection()
    -- Camera-relative movement input
    local forward = camera.CFrame.LookVector
    local right = camera.CFrame.RightVector
    
    -- Flatten to horizontal plane
    forward = Vector3.new(forward.X, 0, forward.Z).Unit
    right = Vector3.new(right.X, 0, right.Z).Unit
    
    local direction = Vector3.zero
    
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        direction = direction + forward
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        direction = direction - forward
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        direction = direction + right
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        direction = direction - right
    end
    
    if direction.Magnitude > 0 then
        direction = direction.Unit
    end
    
    return direction
end

-- ============================================
-- BURST SYSTEM
-- ============================================
local function updateBurst(dt)
    -- Update cooldown
    if state.burstCooldown > 0 then
        state.burstCooldown = state.burstCooldown - dt
    end

    -- Update active burst
    if state.isBursting then
        state.burstTimer = state.burstTimer - dt
        if state.burstTimer <= 0 then
            state.isBursting = false
            state.burstTimer = 0
        end
    end
end

-- ============================================
-- STAMINA SYSTEM
-- ============================================
local function updateStamina(dt)
    local draining = false

    -- Sprint drain
    if state.isSprinting and state.moveDirection.Magnitude > 0 and state.isGrounded then
        state.stamina = state.stamina - (Config.SPRINT_DRAIN * dt)
        draining = true
    end
    
    -- Drift drain (additional, only when grounded to match turn bonus)
    if state.isDrifting and state.isSprinting and state.isGrounded and state.moveDirection.Magnitude > 0 then
        state.stamina = state.stamina - (Config.DRIFT_STAMINA_DRAIN * dt)
        draining = true
    end
    
    -- Check for empty (only trigger penalty once when first hitting 0)
    if state.stamina <= 0 then
        if state.penaltyTimer <= 0 then
            state.penaltyTimer = Config.EMPTY_PENALTY_DURATION
        end
        state.stamina = 0
    end
    
    -- Penalty countdown
    if state.penaltyTimer > 0 then
        state.penaltyTimer = state.penaltyTimer - dt
    end
    
    -- Regeneration (faster as stamina fills - satisfying to top off)
    if draining then
        state.regenTimer = Config.REGEN_DELAY
    else
        state.regenTimer = math.max(0, state.regenTimer - dt)
        if state.regenTimer <= 0 and state.penaltyTimer <= 0 then
            -- Exponential regen: slow when empty, very fast when nearly full
            local staminaRatio = state.stamina / Config.MAX_STAMINA
            -- Use exponential curve (ratio^2) for more aggressive high-stamina regen
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
    if state.moveDirection.Magnitude == 0 then
        return 0
    end

    local target = Config.BASE_SPEED

    -- Sprint speed (only if stamina available)
    if state.isSprinting and state.stamina > 0 and state.penaltyTimer <= 0 then
        target = Config.SPRINT_SPEED
    end

    -- Burst speed (overrides sprint)
    if state.isBursting then
        target = Config.SPRINT_SPEED * Config.BURST_SPEED_MULT
    end

    -- Empty stamina penalty
    if state.penaltyTimer > 0 then
        target = target * Config.EMPTY_STAMINA_PENALTY
    end

    return target
end

local function calculateTurnRate(dt)
    -- Turn rate decreases with speed (degrees per second)
    local speedRatio = state.currentSpeed / Config.SPRINT_SPEED
    local turnRate = Config.BASE_TURN_RATE - (speedRatio * (Config.BASE_TURN_RATE - Config.MIN_TURN_RATE))

    -- Burst penalty (commit factor - you're locked into your direction)
    if state.isBursting then
        turnRate = turnRate * Config.BURST_TURN_PENALTY
    end

    -- Drift bonus (only when not bursting)
    if state.isDrifting and state.isSprinting and state.isGrounded and not state.isBursting then
        turnRate = turnRate * Config.DRIFT_TURN_BONUS
    end

    -- Air turn rate (enhanced after double jump)
    if not state.isGrounded then
        if state.doubleJumpTurnTimer > 0 then
            turnRate = Config.DOUBLE_JUMP_TURN_RATE  -- Enhanced turning after double jump
        else
            turnRate = Config.AIR_TURN_RATE
        end
    end

    -- Convert to radians and multiply by dt for frame-rate independence
    return math.rad(turnRate) * dt
end

local function updateGroundedState()
    if not state.rootPart then return end

    local wasGrounded = state.isGrounded

    -- Raycast downward to check ground
    local rayOrigin = state.rootPart.Position
    local rayDirection = Vector3.new(0, -4, 0)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {state.character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
    state.isGrounded = (result ~= nil)

    -- Reset double jump state on landing (but not during jump grace period)
    -- The grace period prevents false landing detection right after jumping
    if state.isGrounded and not wasGrounded and state.jumpGraceTimer <= 0 then
        state.canDoubleJump = false
        state.doubleJumpTurnTimer = 0
    end
end

local function updateMovement(dt)
    if not state.rootPart or not state.humanoid then return end

    state.moveDirection = getMoveDirection()
    updateGroundedState()

    -- Update jump grace timer (prevents false landing detection after jumping)
    if state.jumpGraceTimer > 0 then
        state.jumpGraceTimer = state.jumpGraceTimer - dt
    end

    -- Update double jump turn timer
    if state.doubleJumpTurnTimer > 0 then
        state.doubleJumpTurnTimer = state.doubleJumpTurnTimer - dt
    end
    
    -- Target speed
    local targetSpeed = calculateTargetSpeed()
    
    -- Accelerate/decelerate toward target
    if targetSpeed > state.currentSpeed then
        state.currentSpeed = state.currentSpeed + (Config.ACCELERATION * dt * (targetSpeed - state.currentSpeed))
    else
        state.currentSpeed = state.currentSpeed - (Config.DECELERATION * dt * (state.currentSpeed - targetSpeed))
    end
    state.currentSpeed = math.max(0, state.currentSpeed)
    
    -- Turning (only when moving)
    local actualTurnRate = 0
    if state.moveDirection.Magnitude > 0 then
        local targetAngle = math.atan2(-state.moveDirection.X, -state.moveDirection.Z)
        local angleDiff = targetAngle - state.facingAngle

        -- Normalize angle difference to [-pi, pi]
        while angleDiff > math.pi do angleDiff = angleDiff - (2 * math.pi) end
        while angleDiff < -math.pi do angleDiff = angleDiff + (2 * math.pi) end

        -- Apply turn rate limit (frame-rate independent)
        local maxTurn = calculateTurnRate(dt)
        angleDiff = math.clamp(angleDiff, -maxTurn, maxTurn)
        state.facingAngle = state.facingAngle + angleDiff

        -- Track turn rate for tilt (radians per second)
        if dt > 0 then
            actualTurnRate = angleDiff / dt
        end
    end
    state.turnRate = actualTurnRate
    
    -- Calculate velocity from facing angle and speed
    local facingDir = Vector3.new(-math.sin(state.facingAngle), 0, -math.cos(state.facingAngle))
    local targetVelocity = facingDir * state.currentSpeed

    -- Drift system: momentum-preserving turn preparation
    local activeDrift = state.isDrifting and state.isSprinting and state.isGrounded and not state.isBursting

    -- Drift start: lock in current velocity direction
    if activeDrift and not state.wasDrifting then
        if state.velocity.Magnitude > 0.1 then
            state.driftVelocityDir = state.velocity.Unit
        else
            state.driftVelocityDir = facingDir
        end
        state.driftSpeed = state.currentSpeed
    end

    -- Drift release: snap to new facing direction with speed retention
    if state.wasDrifting and not activeDrift and state.driftSpeed > 0 then
        local retainedSpeed = state.driftSpeed * Config.DRIFT_RELEASE_RETAIN
        state.velocity = facingDir * retainedSpeed
        state.currentSpeed = retainedSpeed
        state.driftSpeed = 0
    end

    state.wasDrifting = activeDrift

    -- Apply momentum (smoothing) - frame-rate independent using exponential decay
    -- At 60fps baseline, dt*60=1, so we get original behavior
    local smoothing = 1 - math.pow(Config.MOMENTUM_FACTOR, dt * 60)
    if state.isGrounded then
        if activeDrift then
            -- While drifting: keep velocity in locked direction, model turns freely
            state.velocity = state.driftVelocityDir * state.currentSpeed
        else
            state.velocity = state.velocity:Lerp(targetVelocity, smoothing)
        end
    else
        -- In air: limited control (also frame-rate independent)
        local airInfluence = state.moveDirection * Config.AIR_CONTROL * state.currentSpeed * dt * 60
        state.velocity = Vector3.new(
            state.velocity.X + airInfluence.X,
            0, -- Y handled by humanoid
            state.velocity.Z + airInfluence.Z
        )
    end
    
    -- Apply to humanoid - set WalkSpeed dynamically for actual speed changes
    state.humanoid.WalkSpeed = state.currentSpeed
    local moveDir = state.velocity.Unit
    if state.velocity.Magnitude > 0.1 then
        state.humanoid:Move(moveDir, false)
    else
        state.humanoid:Move(Vector3.zero, false)
    end
    
    -- Calculate body tilt based on turn rate and speed
    local speedRatio = math.clamp(state.currentSpeed / Config.SPRINT_SPEED, 0, 1)
    local maxTiltRad = math.rad(Config.MAX_TILT_ANGLE)
    -- Tilt is proportional to turn rate and speed (leaning outward from turn - centrifugal feel)
    local targetTilt = state.turnRate * speedRatio * 0.3
    targetTilt = math.clamp(targetTilt, -maxTiltRad, maxTiltRad)

    -- Smooth tilt transition
    local tiltSmoothing = 1 - math.exp(-Config.TILT_SPEED * dt)
    state.currentTilt = state.currentTilt + (targetTilt - state.currentTilt) * tiltSmoothing

    -- Rotate character to face movement direction with tilt
    if state.currentSpeed > 1 then
        -- Apply yaw (Y) and roll (Z) for leaning outward on turns
        state.rootPart.CFrame = CFrame.new(state.rootPart.Position)
            * CFrame.Angles(0, state.facingAngle, 0)
            * CFrame.Angles(0, 0, state.currentTilt)
    end
end

local function handleJump()
    if not state.jumpRequested then return end
    state.jumpRequested = false

    -- Ground jump
    if state.isGrounded then
        if state.stamina < Config.JUMP_COST and state.penaltyTimer <= 0 then return end

        -- Deduct stamina
        if state.penaltyTimer <= 0 then
            state.stamina = state.stamina - Config.JUMP_COST
        end

        -- Execute first jump
        if state.rootPart then
            state.rootPart.AssemblyLinearVelocity = Vector3.new(
                state.rootPart.AssemblyLinearVelocity.X,
                Config.JUMP_POWER,
                state.rootPart.AssemblyLinearVelocity.Z
            )
            state.isGrounded = false
            state.canDoubleJump = true  -- Enable double jump
            state.jumpGraceTimer = 0.15 -- Grace period to prevent false landing detection
        end
        return
    end

    -- Double jump (in air)
    if state.canDoubleJump then
        if state.stamina < Config.DOUBLE_JUMP_COST and state.penaltyTimer <= 0 then return end

        -- Deduct stamina (25% more than base jump)
        if state.penaltyTimer <= 0 then
            state.stamina = state.stamina - Config.DOUBLE_JUMP_COST
        end

        -- Execute double jump
        if state.rootPart then
            state.rootPart.AssemblyLinearVelocity = Vector3.new(
                state.rootPart.AssemblyLinearVelocity.X,
                Config.DOUBLE_JUMP_POWER,
                state.rootPart.AssemblyLinearVelocity.Z
            )
            state.canDoubleJump = false  -- Used up double jump
            state.doubleJumpTurnTimer = Config.DOUBLE_JUMP_TURN_DURATION  -- Enable enhanced air turning
        end
    end
end

-- ============================================
-- CHARACTER SETUP
-- ============================================
local function setupCharacter(character)
    state.character = character
    state.humanoid = character:WaitForChild("Humanoid")
    state.rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Configure humanoid for custom movement
    state.humanoid.WalkSpeed = Config.BASE_SPEED
    state.humanoid.JumpPower = 0  -- We control jumping manually
    state.humanoid.JumpHeight = 0
    state.humanoid.AutoJump = false  -- Disable auto-jump on mobile/obstacles
    
    -- Initialize facing angle from current orientation
    local _, y, _ = state.rootPart.CFrame:ToEulerAnglesYXZ()
    state.facingAngle = y
    
    -- Reset state
    state.currentSpeed = 0
    state.stamina = Config.MAX_STAMINA
    state.penaltyTimer = 0
    state.regenTimer = 0
    state.velocity = Vector3.zero
end

-- ============================================
-- UI (stamina and speed display)
-- ============================================
local function createUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MountedMovementUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui

    -- Container for both bars
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 200, 0, 50)
    container.Position = UDim2.new(0.5, -100, 1, -70)
    container.BackgroundTransparency = 1
    container.Parent = screenGui

    -- Speed bar (top)
    local speedFrame = Instance.new("Frame")
    speedFrame.Name = "SpeedBar"
    speedFrame.Size = UDim2.new(1, 0, 0, 12)
    speedFrame.Position = UDim2.new(0, 0, 0, 0)
    speedFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    speedFrame.BorderSizePixel = 0
    speedFrame.Parent = container

    local speedFill = Instance.new("Frame")
    speedFill.Name = "Fill"
    speedFill.Size = UDim2.new(0, 0, 1, 0)
    speedFill.BackgroundColor3 = Color3.fromRGB(80, 150, 220)
    speedFill.BorderSizePixel = 0
    speedFill.Parent = speedFrame

    local speedLabel = Instance.new("TextLabel")
    speedLabel.Name = "Label"
    speedLabel.Size = UDim2.new(1, 0, 1, 0)
    speedLabel.BackgroundTransparency = 1
    speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    speedLabel.TextSize = 10
    speedLabel.Font = Enum.Font.GothamBold
    speedLabel.Text = "0"
    speedLabel.Parent = speedFrame

    -- Stamina bar (bottom)
    local staminaFrame = Instance.new("Frame")
    staminaFrame.Name = "StaminaBar"
    staminaFrame.Size = UDim2.new(1, 0, 0, 20)
    staminaFrame.Position = UDim2.new(0, 0, 0, 18)
    staminaFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    staminaFrame.BorderSizePixel = 0
    staminaFrame.Parent = container

    local staminaFill = Instance.new("Frame")
    staminaFill.Name = "Fill"
    staminaFill.Size = UDim2.new(1, 0, 1, 0)
    staminaFill.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    staminaFill.BorderSizePixel = 0
    staminaFill.Parent = staminaFrame

    -- Corners for polish
    for _, frame in ipairs({speedFrame, speedFill, staminaFrame, staminaFill}) do
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = frame
    end

    -- Status indicators (sprint/drift)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, 0, 0, 14)
    statusLabel.Position = UDim2.new(0, 0, 0, 40)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = 11
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = ""
    statusLabel.Parent = container

    return staminaFill, speedFill, speedLabel, statusLabel
end

local staminaFill, speedFill, speedLabel, statusLabel = createUI()

local function updateUI()
    -- Stamina bar
    local staminaRatio = state.stamina / Config.MAX_STAMINA
    staminaFill.Size = UDim2.new(staminaRatio, 0, 1, 0)

    -- Stamina color feedback
    if state.penaltyTimer > 0 then
        staminaFill.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    elseif staminaRatio < 0.3 then
        staminaFill.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
    else
        staminaFill.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    end

    -- Speed bar (scale to max burst speed)
    local maxSpeed = Config.SPRINT_SPEED * Config.BURST_SPEED_MULT
    local speedRatio = state.currentSpeed / maxSpeed
    speedFill.Size = UDim2.new(math.min(1, speedRatio), 0, 1, 0)
    speedLabel.Text = string.format("%.0f", state.currentSpeed)

    -- Speed color (blue -> cyan when sprinting -> orange when bursting)
    if state.isBursting then
        speedFill.BackgroundColor3 = Color3.fromRGB(255, 140, 50)
    elseif state.isSprinting and state.currentSpeed > Config.BASE_SPEED then
        speedFill.BackgroundColor3 = Color3.fromRGB(50, 200, 220)
    else
        speedFill.BackgroundColor3 = Color3.fromRGB(80, 150, 220)
    end

    -- Status text
    local status = {}
    if state.isBursting then
        table.insert(status, "BURST")
    elseif state.isSprinting then
        table.insert(status, "SPRINT")
    end
    if state.isDrifting then table.insert(status, "DRIFT") end
    if not state.isGrounded then
        if state.doubleJumpTurnTimer > 0 then
            table.insert(status, "DJUMP")  -- Enhanced air turning active
        elseif state.canDoubleJump then
            table.insert(status, "AIR+")   -- Double jump available
        else
            table.insert(status, "AIR")
        end
    end
    if state.burstCooldown > 0 and not state.isBursting then
        table.insert(status, string.format("CD:%.1f", state.burstCooldown))
    end
    statusLabel.Text = table.concat(status, " | ")
end

-- ============================================
-- MAIN LOOP
-- ============================================
bindInputs()

if player.Character then
    setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(function()
    unbindInputs()
    state.character = nil
    state.humanoid = nil
    state.rootPart = nil
end)

RunService.RenderStepped:Connect(function(dt)
    if not state.humanoid then return end

    updateBurst(dt)
    updateStamina(dt)
    updateMovement(dt)
    handleJump()
    updateUI()
end)
