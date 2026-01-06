--[[
    HorseSpawner.server.lua
    Server script to set up mountable horses in the world
    Supports both Toolbox horse models and procedural fallback
    Place in ServerScriptService
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create remote events for mount/dismount communication
local MountEvents = Instance.new("Folder")
MountEvents.Name = "MountEvents"
MountEvents.Parent = ReplicatedStorage

local MountHorse = Instance.new("RemoteEvent")
MountHorse.Name = "MountHorse"
MountHorse.Parent = MountEvents

local DismountHorse = Instance.new("RemoteEvent")
DismountHorse.Name = "DismountHorse"
DismountHorse.Parent = MountEvents

-- Track which player is on which horse
local mountedPlayers = {} -- [player] = horse
local horseMounts = {}    -- [horse] = player

-- ============================================
-- HORSE SETUP (for Toolbox models)
-- ============================================

-- Find the primary part to use for movement and mounting
local function findHorsePrimaryPart(horse)
    -- Check if already set
    if horse.PrimaryPart then
        return horse.PrimaryPart
    end

    -- Look for common primary parts in order of preference
    local candidates = {
        "HumanoidRootPart",
        "Torso",
        "Body",
        "Root",
        "MainPart"
    }

    for _, name in ipairs(candidates) do
        local part = horse:FindFirstChild(name, true)
        if part and part:IsA("BasePart") then
            horse.PrimaryPart = part
            return part
        end
    end

    -- Fallback: find any BasePart
    for _, child in ipairs(horse:GetDescendants()) do
        if child:IsA("BasePart") then
            horse.PrimaryPart = child
            return child
        end
    end

    return nil
end

-- Set up a horse model for mounting
local function setupHorse(horse)
    local primaryPart = findHorsePrimaryPart(horse)
    if not primaryPart then
        warn("[HorseSpawner] Could not find primary part for horse:", horse.Name)
        return false
    end

    -- Disable the horse's built-in riding script if it has one
    local ridingScript = horse:FindFirstChild("RidingScript", true)
    if ridingScript and ridingScript:IsA("Script") then
        ridingScript.Disabled = true
        print("[HorseSpawner] Disabled built-in RidingScript")
    end

    -- Also disable any LocalScripts
    for _, script in ipairs(horse:GetDescendants()) do
        if script:IsA("LocalScript") or script:IsA("Script") then
            if script.Name:lower():find("ride") or script.Name:lower():find("mount") or script.Name:lower():find("control") then
                script.Disabled = true
                print("[HorseSpawner] Disabled script:", script.Name)
            end
        end
    end

    -- Disable any existing Seat functionality (we use welding instead)
    local seat = horse:FindFirstChild("Seat", true)
    if seat and seat:IsA("Seat") then
        seat.Disabled = true
    end

    -- Make sure the horse can move (unanchor parts)
    for _, part in ipairs(horse:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            -- Keep collision for the main body only
            if part ~= primaryPart then
                part.CanCollide = false
            end
        end
    end

    -- The primary part should be anchored for our movement system
    primaryPart.Anchored = true
    primaryPart.CanCollide = false

    -- Find or create a part to attach the ProximityPrompt
    local promptParent = primaryPart

    -- Check if there's already a mount prompt
    local existingPrompt = horse:FindFirstChild("MountPrompt", true)
    if existingPrompt then
        existingPrompt:Destroy()
    end

    -- Create ProximityPrompt for mounting
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "MountPrompt"
    prompt.ActionText = "Mount"
    prompt.ObjectText = horse.Name
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = promptParent

    -- Handle mount request
    prompt.Triggered:Connect(function(player)
        -- Check if horse is already mounted
        if horseMounts[horse] then
            return
        end

        -- Check if player is already mounted
        if mountedPlayers[player] then
            return
        end

        -- Mount the player
        mountedPlayers[player] = horse
        horseMounts[horse] = player
        prompt.Enabled = false

        -- Fire to the specific client
        MountHorse:FireClient(player, horse)
        print("[HorseSpawner] Player", player.Name, "mounted", horse.Name)
    end)

    print("[HorseSpawner] Set up horse:", horse.Name, "with primary part:", primaryPart.Name)
    return true
end

-- Find all horses in workspace and set them up
local function findAndSetupHorses()
    local horsesFound = 0

    -- Look for models that might be horses
    local function checkModel(model)
        if not model:IsA("Model") then return end

        -- Check if it's likely a horse by looking for horse-like parts
        local hasHumanoid = model:FindFirstChildOfClass("Humanoid") ~= nil
        local hasTorso = model:FindFirstChild("Torso") ~= nil
        local hasHorseIndicators = model:FindFirstChild("Mane") or
            model:FindFirstChild("Tail") or
            model:FindFirstChild("Saddle") or
            model:FindFirstChild("LeftHind") or
            model:FindFirstChild("RightHind") or
            model:FindFirstChild("LeftFore") or
            model:FindFirstChild("RightFore")

        local nameIndicatesHorse = model.Name:lower():find("horse") ~= nil

        if (hasHumanoid and hasHorseIndicators) or nameIndicatesHorse then
            if setupHorse(model) then
                horsesFound = horsesFound + 1
            end
        end

        -- Check children (for nested models like Horse > Horse)
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("Model") then
                checkModel(child)
            end
        end
    end

    -- Scan workspace
    for _, child in ipairs(workspace:GetChildren()) do
        checkModel(child)
    end

    return horsesFound
end

-- ============================================
-- PROCEDURAL HORSE FALLBACK
-- ============================================

local function createProceduralHorse(position, name)
    local horse = Instance.new("Model")
    horse.Name = name or "Horse"

    -- Body (main part)
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(3, 2.5, 6)
    body.Position = position + Vector3.new(0, 2, 0)
    body.BrickColor = BrickColor.new("Brown")
    body.Material = Enum.Material.SmoothPlastic
    body.Anchored = true
    body.CanCollide = false
    body.Parent = horse

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.5, 1.5, 2)
    head.Position = position + Vector3.new(0, 3.5, 3.5)
    head.BrickColor = BrickColor.new("Brown")
    head.Material = Enum.Material.SmoothPlastic
    head.Anchored = true
    head.CanCollide = false
    head.Parent = horse

    -- Neck
    local neck = Instance.new("Part")
    neck.Name = "Neck"
    neck.Size = Vector3.new(1, 2, 1)
    neck.Position = position + Vector3.new(0, 3, 2.5)
    neck.BrickColor = BrickColor.new("Brown")
    neck.Material = Enum.Material.SmoothPlastic
    neck.Anchored = true
    neck.CanCollide = false
    neck.Parent = horse

    -- Legs
    local legPositions = {
        Vector3.new(-1, 0.75, -2),
        Vector3.new(1, 0.75, -2),
        Vector3.new(-1, 0.75, 2),
        Vector3.new(1, 0.75, 2),
    }

    for i, legOffset in ipairs(legPositions) do
        local leg = Instance.new("Part")
        leg.Name = "Leg" .. i
        leg.Size = Vector3.new(0.6, 1.5, 0.6)
        leg.Position = position + legOffset
        leg.BrickColor = BrickColor.new("Brown")
        leg.Material = Enum.Material.SmoothPlastic
        leg.Anchored = true
        leg.CanCollide = false
        leg.Parent = horse
    end

    -- Tail
    local tail = Instance.new("Part")
    tail.Name = "Tail"
    tail.Size = Vector3.new(0.3, 0.3, 1.5)
    tail.Position = position + Vector3.new(0, 2, -3.5)
    tail.BrickColor = BrickColor.new("Black")
    tail.Material = Enum.Material.SmoothPlastic
    tail.Anchored = true
    tail.CanCollide = false
    tail.Parent = horse

    -- Mane
    local mane = Instance.new("Part")
    mane.Name = "Mane"
    mane.Size = Vector3.new(0.2, 1, 2)
    mane.Position = position + Vector3.new(0, 3.5, 1.5)
    mane.BrickColor = BrickColor.new("Black")
    mane.Material = Enum.Material.SmoothPlastic
    mane.Anchored = true
    mane.CanCollide = false
    mane.Parent = horse

    horse.PrimaryPart = body
    horse.Parent = workspace

    -- Set up mounting for this horse
    setupHorse(horse)

    return horse
end

-- ============================================
-- DISMOUNT HANDLING
-- ============================================

local function findMountPrompt(horse)
    -- Try to find the prompt in various locations
    local prompt = horse:FindFirstChild("MountPrompt", true)
    if prompt then return prompt end

    -- Check primary part
    if horse.PrimaryPart then
        prompt = horse.PrimaryPart:FindFirstChild("MountPrompt")
        if prompt then return prompt end
    end

    return nil
end

DismountHorse.OnServerEvent:Connect(function(player)
    local horse = mountedPlayers[player]
    if not horse then return end

    -- Clear mount state
    mountedPlayers[player] = nil
    horseMounts[horse] = nil

    -- Re-enable prompt
    local prompt = findMountPrompt(horse)
    if prompt then
        prompt.Enabled = true
    end

    print("[HorseSpawner] Player", player.Name, "dismounted")
end)

-- Clean up when player leaves
game.Players.PlayerRemoving:Connect(function(player)
    local horse = mountedPlayers[player]
    if horse then
        mountedPlayers[player] = nil
        horseMounts[horse] = nil

        local prompt = findMountPrompt(horse)
        if prompt then
            prompt.Enabled = true
        end
    end
end)

-- ============================================
-- INITIALIZATION
-- ============================================

-- Wait a moment for workspace to load
task.wait(1)

-- Find and set up existing horses
local horsesFound = findAndSetupHorses()
print("[HorseSpawner] Found and set up", horsesFound, "horse(s) in workspace")

-- If no horses found, create a procedural fallback
if horsesFound == 0 then
    local function findSpawnPosition()
        local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
        if spawn then
            return spawn.Position + Vector3.new(10, 0, 0)
        end

        local spawnsFolder = workspace:FindFirstChild("Spawns")
        if spawnsFolder then
            local firstSpawn = spawnsFolder:FindFirstChildOfClass("SpawnLocation")
            if firstSpawn then
                return firstSpawn.Position + Vector3.new(10, 0, 0)
            end
        end

        return Vector3.new(10, 0, 10)
    end

    local spawnPos = findSpawnPosition()
    local fallbackHorse = createProceduralHorse(spawnPos, "Horse")
    print("[HorseSpawner] Created procedural fallback horse at", fallbackHorse.PrimaryPart.Position)
end
