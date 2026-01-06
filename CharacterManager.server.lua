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

-- R6 body part names (what our costume models use)
local R6_PARTS = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}

-- Map R6 costume parts to R15 player parts (if player is R15)
local R6_TO_R15_MAP = {
    ["Torso"] = "UpperTorso",
    ["Left Arm"] = "LeftUpperArm",
    ["Right Arm"] = "RightUpperArm",
    ["Left Leg"] = "LeftUpperLeg",
    ["Right Leg"] = "RightUpperLeg",
}

-- Check if character is R15 (has UpperTorso) or R6 (has Torso)
local function isR15(character)
    return character:FindFirstChild("UpperTorso") ~= nil
end

local function applyCharacterModel(player, characterId)
    local character = player.Character
    if not character then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return false end

    -- Remove any existing costume overlay
    local existingCostume = character:FindFirstChild("CostumeOverlay")
    if existingCostume then
        existingCostume:Destroy()
    end

    -- Get the character model template
    local costumeModel = getCharacterModel(characterId)
    if not costumeModel then
        print("[CharacterManager] No model found, keeping default avatar for", characterId)
        return true
    end

    -- Remove player's existing accessories and clothing (we'll apply costume's)
    for _, item in ipairs(character:GetDescendants()) do
        if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("BodyColors") then
            item:Destroy()
        end
    end

    -- Apply clothing from costume to player (renders on player's visible body)
    local costumeShirt = costumeModel:FindFirstChildOfClass("Shirt")
    if costumeShirt then
        costumeShirt:Clone().Parent = character
    end

    local costumePants = costumeModel:FindFirstChildOfClass("Pants")
    if costumePants then
        costumePants:Clone().Parent = character
    end

    -- Apply body colors from costume if present
    local costumeBodyColors = costumeModel:FindFirstChildOfClass("BodyColors")
    if costumeBodyColors then
        costumeBodyColors:Clone().Parent = character
    end

    -- Now handle accessories from costume (hats, hair, etc.)
    -- These get welded to the player as overlays
    local accessoryContainer = Instance.new("Folder")
    accessoryContainer.Name = "CostumeOverlay"
    accessoryContainer.Parent = character

    -- Clone and apply accessories from costume model
    for _, item in ipairs(costumeModel:GetChildren()) do
        if item:IsA("Accessory") then
            local accessory = item:Clone()
            -- Let Roblox's accessory system handle attachment
            accessory.Parent = character
        end
    end

    -- Store reference
    playerCharacterModels[player] = accessoryContainer

    print("[CharacterManager] Applied costume:", characterId, "to", player.Name)
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
