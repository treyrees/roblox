--[[
    CharacterSelection.server.lua
    DEPRECATED - This script is disabled.

    Character selection is now handled by CharacterManager.server.lua which provides:
    - Full costume overlay (not just clothing)
    - GetCharacterData RemoteFunction for MountedMovement
    - Proper welding for mounted gameplay

    This script was causing a race condition where both systems listened to the
    same SelectCharacter event, causing inconsistent behavior (sometimes only
    clothes changed, sometimes the full model changed).

    Original features:
    - Applied clothing (Shirt/Pants) from character templates to player
    - Kept player's original skin/face (dressing up, not replacing)
    - Worked on initial selection and respawn
]]

do return end -- DISABLED: CharacterManager handles all character selection

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

    -- TODO: Add accessory support (hats, etc.)
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
