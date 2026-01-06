--[[
    CharacterSelection.server.lua
    Server script to handle character selection and spawning
    Place in ServerScriptService

    Fixes:
    - Properly clones character models with clothing (Shirt/Pants)
    - Adds Animate script for humanoid run animations
    - Handles character appearance (BodyColors, Accessories)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get character folder
local Characters = ReplicatedStorage:WaitForChild("Characters")

-- Create or get SelectionEvents folder
local SelectionEvents = ReplicatedStorage:FindFirstChild("SelectionEvents")
if not SelectionEvents then
    SelectionEvents = Instance.new("Folder")
    SelectionEvents.Name = "SelectionEvents"
    SelectionEvents.Parent = ReplicatedStorage
end

-- Create remote events for selection
local SelectCharacter = SelectionEvents:FindFirstChild("SelectCharacter")
if not SelectCharacter then
    SelectCharacter = Instance.new("RemoteEvent")
    SelectCharacter.Name = "SelectCharacter"
    SelectCharacter.Parent = SelectionEvents
end

local CharacterSelected = SelectionEvents:FindFirstChild("CharacterSelected")
if not CharacterSelected then
    CharacterSelected = Instance.new("RemoteEvent")
    CharacterSelected.Name = "CharacterSelected"
    CharacterSelected.Parent = SelectionEvents
end

-- Track player character choices
local playerCharacters = {} -- [player] = characterName

-- Default Roblox R15 Animate script animation IDs
local DEFAULT_ANIMATIONS = {
    idle = {
        Animation1 = "rbxassetid://507766666",
        Animation2 = "rbxassetid://507766951",
    },
    walk = "rbxassetid://507777826",
    run = "rbxassetid://507767714",
    jump = "rbxassetid://507765000",
    fall = "rbxassetid://507767968",
    climb = "rbxassetid://507765644",
    swim = "rbxassetid://507784897",
    swimidle = "rbxassetid://507785072",
}

-- Create the Animate LocalScript for a character
local function createAnimateScript(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Check if Animate script already exists and is valid
    local existingAnimate = character:FindFirstChild("Animate")
    if existingAnimate and existingAnimate:IsA("LocalScript") then
        -- Check if it has animation children (valid Animate script)
        if existingAnimate:FindFirstChild("idle") or existingAnimate:FindFirstChild("walk") then
            print("[CharacterSelection] Character already has valid Animate script")
            return
        else
            -- Invalid Animate script, remove it
            existingAnimate:Destroy()
        end
    end

    -- Create new Animate script
    local animate = Instance.new("LocalScript")
    animate.Name = "Animate"

    -- Create animation folders and values
    local function createAnimationValue(name, animId, parent)
        local anim = Instance.new("Animation")
        anim.Name = name
        anim.AnimationId = animId
        anim.Parent = parent
        return anim
    end

    local function createAnimationFolder(name, animations)
        local folder = Instance.new("StringValue")
        folder.Name = name
        folder.Parent = animate

        if type(animations) == "string" then
            createAnimationValue(name .. "Anim", animations, folder)
        elseif type(animations) == "table" then
            for animName, animId in pairs(animations) do
                createAnimationValue(animName, animId, folder)
            end
        end

        return folder
    end

    -- Create all animation folders
    createAnimationFolder("idle", DEFAULT_ANIMATIONS.idle)
    createAnimationFolder("walk", DEFAULT_ANIMATIONS.walk)
    createAnimationFolder("run", DEFAULT_ANIMATIONS.run)
    createAnimationFolder("jump", DEFAULT_ANIMATIONS.jump)
    createAnimationFolder("fall", DEFAULT_ANIMATIONS.fall)
    createAnimationFolder("climb", DEFAULT_ANIMATIONS.climb)
    createAnimationFolder("swim", DEFAULT_ANIMATIONS.swim)
    createAnimationFolder("swimidle", DEFAULT_ANIMATIONS.swimidle)

    -- The actual animation controller script
    animate.Source = [[
-- Animate LocalScript (auto-generated)
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

local animations = {}
local currentTrack = nil
local currentState = "idle"

-- Load all animations
local function loadAnimations()
    for _, folder in pairs(script:GetChildren()) do
        if folder:IsA("StringValue") then
            local animName = folder.Name
            animations[animName] = {}
            for _, anim in pairs(folder:GetChildren()) do
                if anim:IsA("Animation") then
                    local track = animator:LoadAnimation(anim)
                    table.insert(animations[animName], track)
                end
            end
        end
    end
end

local function playAnimation(state, fadeTime)
    fadeTime = fadeTime or 0.1

    if currentState == state and currentTrack and currentTrack.IsPlaying then
        return
    end

    -- Stop current animation
    if currentTrack then
        currentTrack:Stop(fadeTime)
    end

    -- Play new animation
    currentState = state
    local anims = animations[state]
    if anims and #anims > 0 then
        local anim = anims[math.random(1, #anims)]
        anim:Play(fadeTime)
        currentTrack = anim

        -- Loop idle animations
        if state == "idle" then
            anim.Looped = true
        end
    end
end

local function onStateChanged(_, newState)
    if newState == Enum.HumanoidStateType.Running then
        -- Will be handled by Running event for speed detection
    elseif newState == Enum.HumanoidStateType.Jumping then
        playAnimation("jump", 0.1)
    elseif newState == Enum.HumanoidStateType.Freefall then
        playAnimation("fall", 0.2)
    elseif newState == Enum.HumanoidStateType.Climbing then
        playAnimation("climb", 0.1)
    elseif newState == Enum.HumanoidStateType.Swimming then
        playAnimation("swim", 0.2)
    end
end

local function onRunning(speed)
    if humanoid:GetState() == Enum.HumanoidStateType.Running then
        if speed > 0.5 then
            if speed > 10 then
                playAnimation("run", 0.2)
            else
                playAnimation("walk", 0.2)
            end
        else
            playAnimation("idle", 0.3)
        end
    end
end

-- Initialize
loadAnimations()

humanoid.StateChanged:Connect(onStateChanged)
humanoid.Running:Connect(onRunning)

-- Start with idle
playAnimation("idle", 0)
]]

    animate.Parent = character
    print("[CharacterSelection] Created Animate script for character")
end

-- Clone clothing and accessories from template to character
local function applyAppearance(template, character)
    -- Clone Shirt
    local templateShirt = template:FindFirstChildOfClass("Shirt")
    if templateShirt then
        local existingShirt = character:FindFirstChildOfClass("Shirt")
        if existingShirt then existingShirt:Destroy() end

        local newShirt = templateShirt:Clone()
        newShirt.Parent = character
        print("[CharacterSelection] Applied Shirt:", newShirt.ShirtTemplate)
    end

    -- Clone Pants
    local templatePants = template:FindFirstChildOfClass("Pants")
    if templatePants then
        local existingPants = character:FindFirstChildOfClass("Pants")
        if existingPants then existingPants:Destroy() end

        local newPants = templatePants:Clone()
        newPants.Parent = character
        print("[CharacterSelection] Applied Pants:", newPants.PantsTemplate)
    end

    -- Clone ShirtGraphic (T-Shirt)
    local templateTShirt = template:FindFirstChildOfClass("ShirtGraphic")
    if templateTShirt then
        local existingTShirt = character:FindFirstChildOfClass("ShirtGraphic")
        if existingTShirt then existingTShirt:Destroy() end

        local newTShirt = templateTShirt:Clone()
        newTShirt.Parent = character
    end

    -- Clone BodyColors
    local templateColors = template:FindFirstChild("Body Colors") or template:FindFirstChildOfClass("BodyColors")
    if templateColors then
        local existingColors = character:FindFirstChild("Body Colors") or character:FindFirstChildOfClass("BodyColors")
        if existingColors then existingColors:Destroy() end

        local newColors = templateColors:Clone()
        newColors.Parent = character
    end

    -- Clone Accessories
    for _, item in pairs(template:GetChildren()) do
        if item:IsA("Accessory") then
            -- Remove existing accessory of same name
            local existing = character:FindFirstChild(item.Name)
            if existing and existing:IsA("Accessory") then
                existing:Destroy()
            end

            local newAccessory = item:Clone()
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:AddAccessory(newAccessory)
            else
                newAccessory.Parent = character
            end
        end
    end

    -- Copy face
    local templateHead = template:FindFirstChild("Head")
    local characterHead = character:FindFirstChild("Head")
    if templateHead and characterHead then
        local templateFace = templateHead:FindFirstChild("face") or templateHead:FindFirstChildOfClass("Decal")
        if templateFace then
            local existingFace = characterHead:FindFirstChild("face") or characterHead:FindFirstChildOfClass("Decal")
            if existingFace then existingFace:Destroy() end

            local newFace = templateFace:Clone()
            newFace.Parent = characterHead
        end
    end
end

-- Spawn player as selected character
local function spawnAsCharacter(player, characterName)
    local template = Characters:FindFirstChild(characterName)
    if not template then
        warn("[CharacterSelection] Character not found:", characterName)
        return false
    end

    print("[CharacterSelection] Spawning", player.Name, "as", characterName)

    -- Store the selection
    playerCharacters[player] = characterName

    -- Get the player's current character
    local character = player.Character
    if not character then
        -- Wait for character to spawn
        character = player.CharacterAdded:Wait()
    end

    -- Apply appearance from template
    applyAppearance(template, character)

    -- Ensure Animate script exists
    createAnimateScript(character)

    -- Notify client
    CharacterSelected:FireClient(player, characterName)

    return true
end

-- Handle character selection request
SelectCharacter.OnServerEvent:Connect(function(player, characterName)
    if typeof(characterName) ~= "string" then return end

    -- Validate character exists
    if not Characters:FindFirstChild(characterName) then
        warn("[CharacterSelection] Invalid character:", characterName)
        return
    end

    spawnAsCharacter(player, characterName)
end)

-- Re-apply character appearance when player respawns
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        -- Wait for character to fully load
        task.wait(0.1)

        local savedCharacter = playerCharacters[player]
        if savedCharacter then
            local template = Characters:FindFirstChild(savedCharacter)
            if template then
                applyAppearance(template, character)
                createAnimateScript(character)
                print("[CharacterSelection] Re-applied", savedCharacter, "appearance on respawn")
            end
        else
            -- Even without selection, ensure Animate script exists
            createAnimateScript(character)
        end
    end)
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
    playerCharacters[player] = nil
end)

-- For existing players (in case script loads after players join)
for _, player in pairs(Players:GetPlayers()) do
    if player.Character then
        createAnimateScript(player.Character)
    end

    player.CharacterAdded:Connect(function(character)
        task.wait(0.1)

        local savedCharacter = playerCharacters[player]
        if savedCharacter then
            local template = Characters:FindFirstChild(savedCharacter)
            if template then
                applyAppearance(template, character)
                createAnimateScript(character)
            end
        else
            createAnimateScript(character)
        end
    end)
end

print("[CharacterSelection] Character selection system initialized")
print("[CharacterSelection] Available characters:", table.concat(
    (function()
        local names = {}
        for _, child in pairs(Characters:GetChildren()) do
            table.insert(names, child.Name)
        end
        return names
    end)(),
    ", "
))
