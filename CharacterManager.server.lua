--[[
    CharacterManager.server.lua
    Server-side character selection and spawning
    Place in ServerScriptService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for/create CharacterData module
local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))

-- Create remote events for character selection
local SelectionEvents = Instance.new("Folder")
SelectionEvents.Name = "SelectionEvents"
SelectionEvents.Parent = ReplicatedStorage

local SelectCharacter = Instance.new("RemoteEvent")
SelectCharacter.Name = "SelectCharacter"
SelectCharacter.Parent = SelectionEvents

local CharacterSelected = Instance.new("RemoteEvent")
CharacterSelected.Name = "CharacterSelected"
CharacterSelected.Parent = SelectionEvents

-- RemoteFunction to get player's current character data (for MountedMovement)
local GetCharacterData = Instance.new("RemoteFunction")
GetCharacterData.Name = "GetCharacterData"
GetCharacterData.Parent = SelectionEvents

-- Track player selections
local playerSelections = {} -- [player] = characterId
local playerCharacterModels = {} -- [player] = characterModel instance

-- ============================================
-- CHARACTER MODEL HANDLING
-- ============================================

local function getCharacterModel(characterId)
    -- Look for character models in ReplicatedStorage/Characters
    local charactersFolder = ReplicatedStorage:FindFirstChild("Characters")
    if not charactersFolder then
        warn("[CharacterManager] Characters folder not found in ReplicatedStorage")
        return nil
    end

    local charData = CharacterData[characterId]
    if not charData then
        warn("[CharacterManager] Character data not found for:", characterId)
        return nil
    end

    local modelName = charData.modelName or characterId
    local model = charactersFolder:FindFirstChild(modelName)

    if not model then
        warn("[CharacterManager] Character model not found:", modelName)
        return nil
    end

    return model:Clone()
end

local function applyCharacterModel(player, characterId)
    local character = player.Character
    if not character then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    -- Get the character model template
    local newModel = getCharacterModel(characterId)
    if not newModel then
        -- If no model found, just keep default avatar but apply stats
        print("[CharacterManager] No model found, keeping default avatar for", characterId)
        return true
    end

    -- Get HumanoidRootPart position to maintain location
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local currentCFrame = rootPart and rootPart.CFrame or CFrame.new(0, 5, 0)

    -- For R6 characters, we need to:
    -- 1. Replace body parts with the new model's parts
    -- 2. Keep the HumanoidRootPart and Humanoid functional

    local newHumanoid = newModel:FindFirstChildOfClass("Humanoid")

    -- Method: Replace the character entirely
    -- Store important references
    local oldCharacterName = character.Name

    -- Prepare new model
    newModel.Name = oldCharacterName

    -- CRITICAL: Unanchor all parts in the model (inventory models are often anchored)
    for _, part in ipairs(newModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
        end
    end

    -- Ensure the new model has required components
    local newRootPart = newModel:FindFirstChild("HumanoidRootPart")
    if not newRootPart then
        -- Create HumanoidRootPart if missing (some R6 models don't have it)
        local torso = newModel:FindFirstChild("Torso")
        if torso then
            newRootPart = Instance.new("Part")
            newRootPart.Name = "HumanoidRootPart"
            newRootPart.Size = Vector3.new(2, 2, 1)
            newRootPart.Transparency = 1
            newRootPart.CanCollide = false
            newRootPart.Anchored = false
            newRootPart.CFrame = torso.CFrame
            newRootPart.Parent = newModel

            -- Weld to torso
            local weld = Instance.new("Motor6D")
            weld.Name = "RootJoint"
            weld.Part0 = newRootPart
            weld.Part1 = torso
            weld.Parent = newRootPart
        end
    end

    if newRootPart then
        newRootPart.CFrame = currentCFrame
        newRootPart.Anchored = false
    end

    -- Ensure humanoid exists
    if not newHumanoid then
        newHumanoid = Instance.new("Humanoid")
        newHumanoid.Parent = newModel
    end

    -- Set up the new character
    newModel.PrimaryPart = newRootPart

    -- Parent new model and set as character
    newModel.Parent = workspace

    -- Important: Destroy old character AFTER setting up new one
    local oldCharacter = character
    player.Character = newModel

    -- Clean up old character
    if oldCharacter then
        oldCharacter:Destroy()
    end

    -- Store reference to the model
    playerCharacterModels[player] = newModel

    print("[CharacterManager] Applied character model:", characterId, "to", player.Name)
    return true
end

-- ============================================
-- CHARACTER SELECTION
-- ============================================

local function handleCharacterSelection(player, characterId)
    -- Validate character exists
    if not CharacterData[characterId] then
        warn("[CharacterManager] Invalid character ID:", characterId)
        return
    end

    -- Store selection
    playerSelections[player] = characterId

    -- Apply the character model
    local success = applyCharacterModel(player, characterId)

    if success then
        -- Notify client of successful selection
        CharacterSelected:FireClient(player, characterId)
        print("[CharacterManager] Player", player.Name, "selected", characterId)
    end
end

-- ============================================
-- DATA ACCESS
-- ============================================

-- Allow clients to request their character data (stats + ability params)
GetCharacterData.OnServerInvoke = function(player)
    local characterId = playerSelections[player]
    if not characterId then
        return nil
    end

    local charData = CharacterData[characterId]
    if not charData then
        return nil
    end

    return {
        id = characterId,
        stats = charData.stats or {},
        abilityParams = charData.abilityParams or {},
        ability = charData.ability,
    }
end

-- ============================================
-- EVENT CONNECTIONS
-- ============================================

SelectCharacter.OnServerEvent:Connect(handleCharacterSelection)

-- Re-apply character model on respawn
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        -- Wait a moment for character to fully load
        task.wait(0.1)

        local selectedChar = playerSelections[player]
        if selectedChar then
            -- Re-apply selected character on respawn
            applyCharacterModel(player, selectedChar)
        end
    end)
end)

-- Clean up on player leave
Players.PlayerRemoving:Connect(function(player)
    playerSelections[player] = nil
    playerCharacterModels[player] = nil
end)

print("[CharacterManager] Server initialized")
