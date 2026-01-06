--[[
    HorseSpawner.server.lua
    Server script to create mountable horses in the world
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

-- Create a simple horse model
local function createHorse(position, name)
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

    -- Legs (4 of them)
    local legPositions = {
        Vector3.new(-1, 0.75, -2),   -- Back left
        Vector3.new(1, 0.75, -2),    -- Back right
        Vector3.new(-1, 0.75, 2),    -- Front left
        Vector3.new(1, 0.75, 2),     -- Front right
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

    -- Set primary part for model manipulation
    horse.PrimaryPart = body

    -- ProximityPrompt for mounting
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "MountPrompt"
    prompt.ActionText = "Mount"
    prompt.ObjectText = "Horse"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 8
    prompt.RequiresLineOfSight = false
    prompt.Parent = body

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
    end)

    horse.Parent = workspace
    return horse
end

-- Handle dismount request from client
DismountHorse.OnServerEvent:Connect(function(player)
    local horse = mountedPlayers[player]
    if not horse then return end

    -- Clear mount state
    mountedPlayers[player] = nil
    horseMounts[horse] = nil

    -- Re-enable prompt
    local prompt = horse.Body:FindFirstChild("MountPrompt")
    if prompt then
        prompt.Enabled = true
    end
end)

-- Clean up when player leaves
game.Players.PlayerRemoving:Connect(function(player)
    local horse = mountedPlayers[player]
    if horse then
        mountedPlayers[player] = nil
        horseMounts[horse] = nil

        local prompt = horse.Body:FindFirstChild("MountPrompt")
        if prompt then
            prompt.Enabled = true
        end
    end
end)

-- Find the SpawnLocation to place horse nearby
local function findSpawnPosition()
    -- Look for SpawnLocation in workspace
    local spawn = workspace:FindFirstChildOfClass("SpawnLocation")

    if spawn then
        -- Place horse 10 studs in front of spawn (positive Z)
        return spawn.Position + Vector3.new(10, 0, 0)
    end

    -- Fallback: check if there's a Spawns folder
    local spawnsFolder = workspace:FindFirstChild("Spawns")
    if spawnsFolder then
        local firstSpawn = spawnsFolder:FindFirstChildOfClass("SpawnLocation")
        if firstSpawn then
            return firstSpawn.Position + Vector3.new(10, 0, 0)
        end
    end

    -- Default fallback position
    return Vector3.new(10, 0, 10)
end

local spawnPos = findSpawnPosition()
local testHorse = createHorse(spawnPos, "TestHorse")

print("[HorseSpawner] Test horse created at", testHorse.PrimaryPart.Position)
