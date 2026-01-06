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

    -- For now, skip model replacement - just use default avatar with stats
    -- TODO: Implement proper R6 model replacement once models have correct joint structure
    print("[CharacterManager] Using default avatar for", characterId, "(model swap disabled)")
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
