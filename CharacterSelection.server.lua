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

-- Note: We don't create custom Animate scripts because LocalScript.Source
-- doesn't execute at runtime. The default Roblox Animate script from
-- StarterCharacterScripts handles animations automatically.

-- Clone clothing and accessories from template to character
local function applyAppearance(template, character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("[CharacterSelection] No humanoid found in character")
        return
    end

    -- Wait for character to fully load
    if not character:FindFirstChild("HumanoidRootPart") then
        character:WaitForChild("HumanoidRootPart")
    end

    -- Remove ALL existing accessories first
    for _, item in pairs(character:GetChildren()) do
        if item:IsA("Accessory") then
            item:Destroy()
        end
    end

    -- Try to get HumanoidDescription from template (modern approach)
    local templateHumanoid = template:FindFirstChildOfClass("Humanoid")
    local templateDesc = templateHumanoid and templateHumanoid:FindFirstChildOfClass("HumanoidDescription")

    if templateDesc then
        -- Use HumanoidDescription for clothing (keeps player's body/face)
        local playerDesc = humanoid:GetAppliedDescription() or Instance.new("HumanoidDescription")

        -- Only copy clothing-related properties, keep player's body
        playerDesc.Shirt = templateDesc.Shirt
        playerDesc.Pants = templateDesc.Pants
        playerDesc.GraphicTShirt = templateDesc.GraphicTShirt

        -- Apply the modified description
        humanoid:ApplyDescription(playerDesc)
        print("[CharacterSelection] Applied clothing via HumanoidDescription")
    else
        -- Fallback: Look for Shirt/Pants instances directly
        local templateShirt = template:FindFirstChildOfClass("Shirt")
        if templateShirt then
            local existingShirt = character:FindFirstChildOfClass("Shirt")
            if existingShirt then existingShirt:Destroy() end

            local newShirt = templateShirt:Clone()
            newShirt.Parent = character
            print("[CharacterSelection] Applied Shirt:", newShirt.ShirtTemplate)
        else
            print("[CharacterSelection] No Shirt found in template")
        end

        local templatePants = template:FindFirstChildOfClass("Pants")
        if templatePants then
            local existingPants = character:FindFirstChildOfClass("Pants")
            if existingPants then existingPants:Destroy() end

            local newPants = templatePants:Clone()
            newPants.Parent = character
            print("[CharacterSelection] Applied Pants:", newPants.PantsTemplate)
        else
            print("[CharacterSelection] No Pants found in template")
        end

        local templateTShirt = template:FindFirstChildOfClass("ShirtGraphic")
        if templateTShirt then
            local existingTShirt = character:FindFirstChildOfClass("ShirtGraphic")
            if existingTShirt then existingTShirt:Destroy() end

            local newTShirt = templateTShirt:Clone()
            newTShirt.Parent = character
        end
    end

    -- Clone Accessories (works reliably via AddAccessory API)
    local accessoryCount = 0
    for _, item in pairs(template:GetChildren()) do
        if item:IsA("Accessory") then
            local newAccessory = item:Clone()
            humanoid:AddAccessory(newAccessory)
            accessoryCount = accessoryCount + 1
            print("[CharacterSelection] Applied Accessory:", item.Name)
        end
    end
    print("[CharacterSelection] Applied", accessoryCount, "accessories")
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
                print("[CharacterSelection] Re-applied", savedCharacter, "appearance on respawn")
            end
        end
    end)
end)

-- Clean up when player leaves
Players.PlayerRemoving:Connect(function(player)
    playerCharacters[player] = nil
end)

-- For existing players (in case script loads after players join)
for _, player in pairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function(character)
        task.wait(0.1)

        local savedCharacter = playerCharacters[player]
        if savedCharacter then
            local template = Characters:FindFirstChild(savedCharacter)
            if template then
                applyAppearance(template, character)
            end
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
