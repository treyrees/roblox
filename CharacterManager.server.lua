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
        -- Show default avatar parts if no costume
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = 0
            end
        end
        return true
    end

    -- Hide the default avatar body parts (but keep it functional for animations)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Transparency = 1
        end
        -- Only destroy accessories and body colors, keep Shirt/Pants for fallback
        if part:IsA("Accessory") or part:IsA("BodyColors") then
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

    -- Copy clothing from costume to player (if costume has clothing)
    local costumeShirt = costumeModel:FindFirstChildOfClass("Shirt")
    if costumeShirt then
        local existingShirt = character:FindFirstChildOfClass("Shirt")
        if existingShirt then existingShirt:Destroy() end
        costumeShirt:Clone().Parent = character
    end

    local costumePants = costumeModel:FindFirstChildOfClass("Pants")
    if costumePants then
        local existingPants = character:FindFirstChildOfClass("Pants")
        if existingPants then existingPants:Destroy() end
        costumePants:Clone().Parent = character
    end

    -- Prepare the costume model
    costumeModel.Name = "CostumeOverlay"

    -- Remove the costume's humanoid (we don't need it)
    local costumeHumanoid = costumeModel:FindFirstChildOfClass("Humanoid")
    if costumeHumanoid then
        costumeHumanoid:Destroy()
    end

    -- Remove ALL Motor6D joints from costume to prevent animation conflicts
    for _, descendant in ipairs(costumeModel:GetDescendants()) do
        if descendant:IsA("Motor6D") then
            descendant:Destroy()
        end
    end

    -- Unanchor all parts and make them non-collidable
    for _, part in ipairs(costumeModel:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
            part.Massless = true
        end
    end

    -- Parent costume to character
    costumeModel.Parent = character

    -- Check if player is R15 (costume models are R6)
    local playerIsR15 = isR15(character)

    -- Weld costume parts to corresponding player body parts
    local weldedParts = {}

    for _, costumepartName in ipairs(R6_PARTS) do
        local costumePart = costumeModel:FindFirstChild(costumepartName)
        if not costumePart then continue end

        -- Find the corresponding player part
        local playerPartName = costumepartName
        if playerIsR15 and R6_TO_R15_MAP[costumepartName] then
            playerPartName = R6_TO_R15_MAP[costumepartName]
        end

        local playerPart = character:FindFirstChild(playerPartName)
        if not playerPart then
            -- Fallback to rootPart if no matching part found
            playerPart = rootPart
        end

        -- Remove any existing welds on this costume part
        for _, child in ipairs(costumePart:GetChildren()) do
            if child:IsA("Weld") or child:IsA("Motor6D") then
                child:Destroy()
            end
        end

        local weld = Instance.new("Weld")
        weld.Name = "CostumeWeld"
        weld.Part0 = playerPart
        weld.Part1 = costumePart
        -- No rotation - R6 models are already correctly oriented
        weld.C0 = CFrame.new()
        weld.C1 = CFrame.new()
        weld.Parent = costumePart

        weldedParts[costumepartName] = true
    end

    -- For any remaining costume parts (accessories, etc.), weld to rootPart
    for _, part in ipairs(costumeModel:GetDescendants()) do
        if part:IsA("BasePart") and not weldedParts[part.Name] then
            -- Remove any existing welds
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("Weld") or child:IsA("Motor6D") or child.Name == "AccessoryWeld" then
                    child:Destroy()
                end
            end

            -- Only weld if not already welded
            if not part:FindFirstChild("CostumeWeld") then
                local weld = Instance.new("Weld")
                weld.Name = "CostumeWeld_" .. part.Name
                weld.Part0 = rootPart
                weld.Part1 = part
                -- Preserve relative position to rootPart, no rotation
                weld.C0 = rootPart.CFrame:ToObjectSpace(part.CFrame)
                weld.C1 = CFrame.new()
                weld.Parent = part
            end
        end
    end

    -- Store reference
    playerCharacterModels[player] = costumeModel

    print("[CharacterManager] Applied costume overlay:", characterId, "to", player.Name, "(R15:", playerIsR15, ")")
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
