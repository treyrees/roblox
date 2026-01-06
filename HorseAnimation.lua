--[[
    HorseAnimation.lua
    Procedural horse animation system - animates legs, head, tail based on movement
    Works with rigged horse models using Motor6D joints

    Usage:
        local HorseAnimation = require(path.to.HorseAnimation)
        local animator = HorseAnimation.new(horseModel)

        -- In update loop:
        animator:update(dt, speed, isGrounded)
]]

local HorseAnimation = {}
HorseAnimation.__index = HorseAnimation

-- Animation configuration
local Config = {
    -- Leg animation
    LEG_SWING_ANGLE = math.rad(35),      -- Max leg swing forward/back
    LEG_LIFT_ANGLE = math.rad(20),       -- Max leg lift during stride
    CANNON_FOLD_ANGLE = math.rad(40),    -- Lower leg fold during lift

    -- Gait timing (cycles per second at full gallop)
    WALK_FREQUENCY = 2,                   -- Slow walk cycle
    GALLOP_FREQUENCY = 4,                 -- Fast gallop cycle

    -- Head bob
    HEAD_BOB_AMOUNT = math.rad(8),        -- Vertical head movement
    HEAD_BOB_FREQUENCY = 2,               -- Synced with front legs

    -- Tail sway
    TAIL_SWAY_ANGLE = math.rad(15),       -- Side to side sway
    TAIL_SWAY_FREQUENCY = 1.5,            -- Gentle swaying
    TAIL_BOUNCE_ANGLE = math.rad(10),     -- Up/down bounce when running

    -- Mane flow
    MANE_FLOW_ANGLE = math.rad(12),       -- Mane movement

    -- Speed thresholds
    IDLE_THRESHOLD = 1,                   -- Below this = idle
    WALK_THRESHOLD = 25,                  -- Below this = walk
    TROT_THRESHOLD = 50,                  -- Below this = trot
    -- Above TROT_THRESHOLD = gallop

    -- Smoothing
    ANIMATION_SMOOTHING = 10,             -- How fast animations blend
}

function HorseAnimation.new(horseModel)
    local self = setmetatable({}, HorseAnimation)

    self.horse = horseModel
    self.joints = {}
    self.originalC0 = {}
    self.animationTime = 0
    self.currentIntensity = 0

    -- Find and store all Motor6D joints
    self:findJoints()

    return self
end

function HorseAnimation:findJoints()
    -- Search for Motor6Ds in the horse model
    for _, descendant in ipairs(self.horse:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            local name = descendant.Name
            self.joints[name] = descendant
            self.originalC0[name] = descendant.C0
        end
    end

    -- Also look for specific parts we want to animate directly
    self.parts = {
        head = self.horse:FindFirstChild("Head"),
        tail = self.horse:FindFirstChild("Tail"),
        mane = self.horse:FindFirstChild("Mane"),
        torso = self.horse:FindFirstChild("Torso"),

        -- Front legs
        leftFore = self.horse:FindFirstChild("LeftFore"),
        rightFore = self.horse:FindFirstChild("RightFore"),
        lfCannon = self.horse:FindFirstChild("LFCannon"),
        rfCannon = self.horse:FindFirstChild("RFCannon"),

        -- Back legs
        leftHind = self.horse:FindFirstChild("LeftHind"),
        rightHind = self.horse:FindFirstChild("RightHind"),
        lhCannon = self.horse:FindFirstChild("LHCannon"),
        rhCannon = self.horse:FindFirstChild("RHCannon"),
    }

    -- Debug: print found joints
    local jointCount = 0
    for name, _ in pairs(self.joints) do
        jointCount = jointCount + 1
    end
    print("[HorseAnimation] Found", jointCount, "Motor6D joints")
end

function HorseAnimation:getJoint(name)
    return self.joints[name]
end

function HorseAnimation:animateJoint(jointName, rotationOffset)
    local joint = self.joints[jointName]
    if not joint then return end

    local original = self.originalC0[jointName]
    if not original then return end

    joint.C0 = original * rotationOffset
end

function HorseAnimation:calculateGaitParameters(speed)
    local intensity = 0
    local frequency = Config.WALK_FREQUENCY
    local gait = "idle"

    if speed < Config.IDLE_THRESHOLD then
        intensity = 0
        gait = "idle"
    elseif speed < Config.WALK_THRESHOLD then
        -- Walk: gentle movement
        intensity = (speed - Config.IDLE_THRESHOLD) / (Config.WALK_THRESHOLD - Config.IDLE_THRESHOLD)
        intensity = intensity * 0.4  -- Reduced intensity for walk
        frequency = Config.WALK_FREQUENCY
        gait = "walk"
    elseif speed < Config.TROT_THRESHOLD then
        -- Trot: medium movement
        intensity = 0.4 + ((speed - Config.WALK_THRESHOLD) / (Config.TROT_THRESHOLD - Config.WALK_THRESHOLD)) * 0.3
        frequency = Config.WALK_FREQUENCY + 1
        gait = "trot"
    else
        -- Gallop: full movement
        intensity = 0.7 + math.min(0.3, (speed - Config.TROT_THRESHOLD) / 50 * 0.3)
        frequency = Config.GALLOP_FREQUENCY
        gait = "gallop"
    end

    return intensity, frequency, gait
end

function HorseAnimation:update(dt, speed, isGrounded)
    -- Calculate gait parameters
    local targetIntensity, frequency, gait = self:calculateGaitParameters(speed)

    -- Smooth intensity changes
    local smoothing = 1 - math.exp(-Config.ANIMATION_SMOOTHING * dt)
    self.currentIntensity = self.currentIntensity + (targetIntensity - self.currentIntensity) * smoothing

    -- Advance animation time based on frequency
    self.animationTime = self.animationTime + dt * frequency * math.pi * 2

    local intensity = self.currentIntensity
    local t = self.animationTime

    -- Skip animation if barely moving
    if intensity < 0.01 then
        self:resetToIdle()
        return
    end

    -- Animate legs with gallop pattern
    -- Front legs: Left leads slightly
    -- Back legs: Opposite phase to front, Right leads slightly
    self:animateLeg("LeftFore", "LFCannon", t, intensity, 0)
    self:animateLeg("RightFore", "RFCannon", t, intensity, math.pi * 0.5)
    self:animateLeg("LeftHind", "LHCannon", t, intensity, math.pi)
    self:animateLeg("RightHind", "RHCannon", t, intensity, math.pi * 1.5)

    -- Head bob - synced with front leg movement
    self:animateHead(t, intensity, speed)

    -- Tail animation
    self:animateTail(t, intensity, speed)

    -- Mane flow
    self:animateMane(t, intensity, speed)

    -- Body bounce (subtle)
    self:animateBody(t, intensity)
end

function HorseAnimation:animateLeg(upperJointName, lowerJointName, time, intensity, phaseOffset)
    local phase = time + phaseOffset

    -- Upper leg: swings forward and back
    local swingAngle = math.sin(phase) * Config.LEG_SWING_ANGLE * intensity

    -- Leg lift: lifts during forward swing
    local liftPhase = math.sin(phase)
    local liftAngle = 0
    if liftPhase > 0 then
        liftAngle = liftPhase * Config.LEG_LIFT_ANGLE * intensity
    end

    -- Apply to upper leg joint
    local upperRotation = CFrame.Angles(swingAngle, 0, liftAngle * 0.3)
    self:animateJoint(upperJointName, upperRotation)

    -- Lower leg (cannon): folds during lift
    local foldAngle = 0
    if liftPhase > 0 then
        foldAngle = liftPhase * Config.CANNON_FOLD_ANGLE * intensity
    end

    local lowerRotation = CFrame.Angles(foldAngle, 0, 0)
    self:animateJoint(lowerJointName, lowerRotation)
end

function HorseAnimation:animateHead(time, intensity, speed)
    -- Head bobs up and down with gait
    local bobPhase = time * Config.HEAD_BOB_FREQUENCY / 2
    local bobAngle = math.sin(bobPhase) * Config.HEAD_BOB_AMOUNT * intensity

    -- Head lifts slightly when running fast
    local liftBonus = 0
    if speed > Config.TROT_THRESHOLD then
        liftBonus = math.rad(-5) -- Slight upward tilt
    end

    local headRotation = CFrame.Angles(bobAngle + liftBonus, 0, 0)

    -- Try common joint names for head
    self:animateJoint("Head", headRotation)
    self:animateJoint("Neck", headRotation * CFrame.Angles(bobAngle * 0.5, 0, 0))
end

function HorseAnimation:animateTail(time, intensity, speed)
    -- Tail sways side to side
    local swayPhase = time * Config.TAIL_SWAY_FREQUENCY
    local swayAngle = math.sin(swayPhase) * Config.TAIL_SWAY_ANGLE * math.max(0.3, intensity)

    -- Tail bounces up/down when running
    local bounceAngle = 0
    if intensity > 0.5 then
        bounceAngle = math.sin(time * 2) * Config.TAIL_BOUNCE_ANGLE * intensity
    end

    local tailRotation = CFrame.Angles(bounceAngle, swayAngle, 0)
    self:animateJoint("Tail", tailRotation)
end

function HorseAnimation:animateMane(time, intensity, speed)
    -- Mane flows back when running
    local flowPhase = time * 1.5
    local flowAngle = math.sin(flowPhase) * Config.MANE_FLOW_ANGLE * intensity

    -- Extra backward flow at high speed
    local speedFlow = 0
    if speed > Config.WALK_THRESHOLD then
        speedFlow = math.rad(10) * (intensity - 0.3)
    end

    local maneRotation = CFrame.Angles(flowAngle + speedFlow, 0, 0)
    self:animateJoint("Mane", maneRotation)
end

function HorseAnimation:animateBody(time, intensity)
    -- Subtle body bounce
    local bouncePhase = time * 2
    local bounceAngle = math.sin(bouncePhase) * math.rad(2) * intensity

    -- Slight forward lean when running
    local leanAngle = math.rad(3) * intensity

    local bodyRotation = CFrame.Angles(bounceAngle + leanAngle, 0, 0)
    self:animateJoint("Torso", bodyRotation)
    self:animateJoint("Root", bodyRotation)
end

function HorseAnimation:resetToIdle()
    -- Smoothly return all joints to original positions
    for name, joint in pairs(self.joints) do
        local original = self.originalC0[name]
        if original and joint then
            local current = joint.C0
            joint.C0 = current:Lerp(original, 0.1)
        end
    end
end

function HorseAnimation:destroy()
    -- Reset all joints to original
    for name, joint in pairs(self.joints) do
        local original = self.originalC0[name]
        if original and joint then
            joint.C0 = original
        end
    end

    self.joints = {}
    self.originalC0 = {}
end

return HorseAnimation
