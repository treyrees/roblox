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
        -- Show default avatar parts if no costume
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 0
            end
        end
        return true
    end

    -- Hide the default avatar (but keep it functional)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Transparency = 1
        end
        if part:IsA("Accessory") or part:IsA("Shirt") or part:IsA("Pants") or part:IsA("BodyColors") then
            part:Destroy()
        end
    end

    -- Also hide face
    local head = character:FindFirstChild("Head")
    if head then
        local face = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
        if face then
            face.Transparency = 1
        end
    end

    -- Prepare the costume model
    costumeModel.Name = "CostumeOverlay"

    -- Unanchor all parts and make them non-collidable
    for _, part in ipairs(costumeModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.Massless = true
        end
    end

    -- Find the costume's root (Torso or HumanoidRootPart)
    local costumeRoot = costumeModel:FindFirstChild("HumanoidRootPart")
        or costumeModel:FindFirstChild("Torso")
        or costumeModel.PrimaryPart

    if not costumeRoot then
        -- Just use the first part
        for _, part in ipairs(costumeModel:GetDescendants()) do
            if part:IsA("BasePart") then
                costumeRoot = part
                break
            end
        end
    end

    if not costumeRoot then
        warn("[CharacterManager] Costume has no parts!")
        return false
    end

    -- Remove the costume's humanoid (we don't need it)
    local costumeHumanoid = costumeModel:FindFirstChildOfClass("Humanoid")
    if costumeHumanoid then
        costumeHumanoid:Destroy()
    end

    -- Set PrimaryPart for positioning
    costumeModel.PrimaryPart = costumeRoot

    -- Position costume at player's location before welding
    costumeModel:PivotTo(rootPart.CFrame)

    -- Parent costume to character
    costumeModel.Parent = character

    -- Weld ALL costume parts to player's HumanoidRootPart
    -- This ensures the entire costume moves as one unit with the player
    for _, part in ipairs(costumeModel:GetDescendants()) do
        if part:IsA("BasePart") then
            -- Remove any existing AccessoryWeld (for Accessory Handles)
            local existingWeld = part:FindFirstChild("AccessoryWeld")
            if existingWeld then
                existingWeld:Destroy()
            end

            local weld = Instance.new("Weld")
            weld.Name = "CostumeWeld_" .. part.Name
            weld.Part0 = rootPart
            weld.Part1 = part
            -- C0 = offset from rootPart to where part currently is
            -- C1 = identity (part stays at its current relative position)
            weld.C0 = rootPart.CFrame:ToObjectSpace(part.CFrame)
            weld.C1 = CFrame.new(0, 0, 0)
            weld.Parent = part
        end
    end

    -- Store reference
    playerCharacterModels[player] = costumeModel

    print("[CharacterManager] Applied costume overlay:", characterId, "to", player.Name)
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
