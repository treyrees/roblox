--[[
    CharacterSelection.client.lua
    Client-side character selection UI
    Place in StarterPlayerScripts
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for modules
local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))

-- Wait for selection events
local SelectionEvents = ReplicatedStorage:WaitForChild("SelectionEvents")
local SelectCharacter = SelectionEvents:WaitForChild("SelectCharacter")
local CharacterSelected = SelectionEvents:WaitForChild("CharacterSelected")

-- UI Constants
local GRID_COLUMNS = 3
local CARD_SIZE = UDim2.new(0, 180, 0, 240)
local CARD_PADDING = 15
local SELECTED_SCALE = 1.05

-- State
local selectedCharacterId = nil
local characterCards = {}
local selectionUI = nil
local isSelectionOpen = true

-- ============================================
-- UI CREATION
-- ============================================

local function createStatBar(parent, statName, value, maxValue, yPos)
    local container = Instance.new("Frame")
    container.Name = statName .. "Stat"
    container.Size = UDim2.new(1, -20, 0, 20)
    container.Position = UDim2.new(0, 10, 0, yPos)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(0, 60, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.Text = statName
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(1, -65, 0, 8)
    barBg.Position = UDim2.new(0, 65, 0.5, -4)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    barBg.BorderSizePixel = 0
    barBg.Parent = container

    local barFill = Instance.new("Frame")
    barFill.Name = "Fill"
    barFill.Size = UDim2.new(math.clamp(value / maxValue, 0, 1), 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(80, 180, 120)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg

    local corner1 = Instance.new("UICorner")
    corner1.CornerRadius = UDim.new(0, 4)
    corner1.Parent = barBg

    local corner2 = Instance.new("UICorner")
    corner2.CornerRadius = UDim.new(0, 4)
    corner2.Parent = barFill

    return container
end

local function createCharacterCard(characterId, characterInfo, stats)
    local card = Instance.new("Frame")
    card.Name = characterId .. "Card"
    card.Size = CARD_SIZE
    card.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    card.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Name = "SelectionStroke"
    stroke.Color = characterInfo.portraitColor or Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = card

    -- Portrait area (colored block for now - can be replaced with ViewportFrame)
    local portrait = Instance.new("Frame")
    portrait.Name = "Portrait"
    portrait.Size = UDim2.new(1, -20, 0, 80)
    portrait.Position = UDim2.new(0, 10, 0, 10)
    portrait.BackgroundColor3 = characterInfo.portraitColor or Color3.fromRGB(80, 80, 80)
    portrait.BorderSizePixel = 0
    portrait.Parent = card

    local portraitCorner = Instance.new("UICorner")
    portraitCorner.CornerRadius = UDim.new(0, 8)
    portraitCorner.Parent = portrait

    -- Character name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -20, 0, 22)
    nameLabel.Position = UDim2.new(0, 10, 0, 95)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = characterInfo.displayName
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    -- Ability name
    local abilityLabel = Instance.new("TextLabel")
    abilityLabel.Name = "AbilityLabel"
    abilityLabel.Size = UDim2.new(1, -20, 0, 16)
    abilityLabel.Position = UDim2.new(0, 10, 0, 115)
    abilityLabel.BackgroundTransparency = 1
    abilityLabel.TextColor3 = characterInfo.portraitColor or Color3.fromRGB(150, 150, 150)
    abilityLabel.TextSize = 12
    abilityLabel.Font = Enum.Font.GothamMedium
    abilityLabel.Text = characterInfo.ability
    abilityLabel.TextXAlignment = Enum.TextXAlignment.Left
    abilityLabel.Parent = card

    -- Stat bars
    local statStartY = 140
    local statSpacing = 22

    -- Normalize stats to show relative strengths
    local speedVal = (stats.SPRINT_SPEED or 80) / 100
    local staminaVal = (stats.MAX_STAMINA or 100) / 150
    local turnVal = 1 - ((stats.MIN_TURN_RATE or 60) / 150) -- Lower is better for turning

    createStatBar(card, "Speed", speedVal, 1, statStartY)
    createStatBar(card, "Stamina", staminaVal, 1, statStartY + statSpacing)
    createStatBar(card, "Agility", turnVal, 1, statStartY + statSpacing * 2)

    -- Select button
    local selectBtn = Instance.new("TextButton")
    selectBtn.Name = "SelectButton"
    selectBtn.Size = UDim2.new(1, -20, 0, 32)
    selectBtn.Position = UDim2.new(0, 10, 1, -42)
    selectBtn.BackgroundColor3 = characterInfo.portraitColor or Color3.fromRGB(80, 120, 200)
    selectBtn.BorderSizePixel = 0
    selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectBtn.TextSize = 14
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.Text = "SELECT"
    selectBtn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = selectBtn

    -- Hover effects
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0}):Play()
        end
    end)

    card.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            if selectedCharacterId ~= characterId then
                TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.5}):Play()
            end
        end
    end)

    -- Selection
    selectBtn.MouseButton1Click:Connect(function()
        selectCharacter(characterId)
    end)

    return card
end

local function createSelectionUI()
    local characters = CharacterData.getCharacterList()

    -- Main ScreenGui
    selectionUI = Instance.new("ScreenGui")
    selectionUI.Name = "CharacterSelectionUI"
    selectionUI.ResetOnSpawn = false
    selectionUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    selectionUI.Parent = playerGui

    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    overlay.BackgroundTransparency = 0.3
    overlay.BorderSizePixel = 0
    overlay.Parent = selectionUI

    -- Main container
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent = selectionUI

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 60)
    title.Position = UDim2.new(0, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 36
    title.Font = Enum.Font.GothamBold
    title.Text = "SELECT YOUR RIDER"
    title.Parent = container

    -- Subtitle
    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, 0, 0, 24)
    subtitle.Position = UDim2.new(0, 0, 0, 85)
    subtitle.BackgroundTransparency = 1
    subtitle.TextColor3 = Color3.fromRGB(150, 150, 150)
    subtitle.TextSize = 14
    subtitle.Font = Enum.Font.Gotham
    subtitle.Text = "Each rider has unique stats and a special ability"
    subtitle.Parent = container

    -- Grid container
    local gridContainer = Instance.new("Frame")
    gridContainer.Name = "GridContainer"
    gridContainer.Size = UDim2.new(0, (CARD_SIZE.X.Offset + CARD_PADDING) * GRID_COLUMNS - CARD_PADDING, 0, 500)
    gridContainer.Position = UDim2.new(0.5, 0, 0.5, 20)
    gridContainer.AnchorPoint = Vector2.new(0.5, 0.5)
    gridContainer.BackgroundTransparency = 1
    gridContainer.Parent = container

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = CARD_SIZE
    gridLayout.CellPadding = UDim2.new(0, CARD_PADDING, 0, CARD_PADDING)
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.SortOrder = Enum.SortOrder.Name
    gridLayout.Parent = gridContainer

    -- Create character cards
    for i, charInfo in ipairs(characters) do
        local stats = CharacterData.getStats(charInfo.id)
        local card = createCharacterCard(charInfo.id, charInfo, stats)
        card.Name = string.format("%02d_%s", i, charInfo.id) -- Prefix with number for sort order
        card.Parent = gridContainer
        characterCards[charInfo.id] = card
    end

    -- Ability description panel (bottom)
    local abilityPanel = Instance.new("Frame")
    abilityPanel.Name = "AbilityPanel"
    abilityPanel.Size = UDim2.new(0, 500, 0, 60)
    abilityPanel.Position = UDim2.new(0.5, 0, 1, -80)
    abilityPanel.AnchorPoint = Vector2.new(0.5, 0)
    abilityPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    abilityPanel.BackgroundTransparency = 0.2
    abilityPanel.BorderSizePixel = 0
    abilityPanel.Visible = false
    abilityPanel.Parent = container

    local abilityCorner = Instance.new("UICorner")
    abilityCorner.CornerRadius = UDim.new(0, 8)
    abilityCorner.Parent = abilityPanel

    local abilityText = Instance.new("TextLabel")
    abilityText.Name = "AbilityText"
    abilityText.Size = UDim2.new(1, -30, 1, 0)
    abilityText.Position = UDim2.new(0, 15, 0, 0)
    abilityText.BackgroundTransparency = 1
    abilityText.TextColor3 = Color3.fromRGB(220, 220, 220)
    abilityText.TextSize = 14
    abilityText.Font = Enum.Font.Gotham
    abilityText.Text = ""
    abilityText.TextWrapped = true
    abilityText.TextYAlignment = Enum.TextYAlignment.Center
    abilityText.Parent = abilityPanel

    return selectionUI
end

-- ============================================
-- SELECTION LOGIC
-- ============================================

function selectCharacter(characterId)
    if selectedCharacterId == characterId then
        -- Already selected, confirm selection
        confirmSelection()
        return
    end

    -- Update visual selection
    for id, card in pairs(characterCards) do
        local stroke = card:FindFirstChild("SelectionStroke")
        local btn = card:FindFirstChild("SelectButton")
        if id == characterId then
            -- Selected card
            if stroke then
                stroke.Thickness = 3
                stroke.Transparency = 0
            end
            if btn then
                btn.Text = "CONFIRM"
            end
            -- Scale up slightly
            TweenService:Create(card, TweenInfo.new(0.2), {
                Size = UDim2.new(CARD_SIZE.X.Scale, CARD_SIZE.X.Offset * SELECTED_SCALE,
                                 CARD_SIZE.Y.Scale, CARD_SIZE.Y.Offset * SELECTED_SCALE)
            }):Play()
        else
            -- Deselected card
            if stroke then
                stroke.Thickness = 2
                stroke.Transparency = 0.5
            end
            if btn then
                btn.Text = "SELECT"
            end
            -- Reset scale
            TweenService:Create(card, TweenInfo.new(0.2), {
                Size = CARD_SIZE
            }):Play()
        end
    end

    -- Update ability panel
    local charData = CharacterData[characterId]
    if charData then
        local abilityPanel = selectionUI.Container:FindFirstChild("AbilityPanel")
        if abilityPanel then
            abilityPanel.Visible = true
            abilityPanel.AbilityText.Text = charData.ability .. ": " .. charData.abilityDescription
        end
    end

    selectedCharacterId = characterId
end

function confirmSelection()
    if not selectedCharacterId then return end

    -- Send selection to server
    SelectCharacter:FireServer(selectedCharacterId)

    -- Close UI with animation
    local overlay = selectionUI:FindFirstChild("Overlay")
    local container = selectionUI:FindFirstChild("Container")

    if container then
        TweenService:Create(container, TweenInfo.new(0.3), {
            Position = UDim2.new(0, 0, -0.1, 0)
        }):Play()
    end

    if overlay then
        local tween = TweenService:Create(overlay, TweenInfo.new(0.3), {
            BackgroundTransparency = 1
        })
        tween:Play()
        tween.Completed:Connect(function()
            selectionUI.Enabled = false
            isSelectionOpen = false
        end)
    else
        selectionUI.Enabled = false
        isSelectionOpen = false
    end

    print("[CharacterSelection] Selected:", selectedCharacterId)
end

-- ============================================
-- INITIALIZATION
-- ============================================

-- Create the selection UI
createSelectionUI()

-- Handle server confirmation
CharacterSelected.OnClientEvent:Connect(function(characterId)
    print("[CharacterSelection] Server confirmed:", characterId)
    -- Could trigger additional effects here
end)

-- Keyboard shortcut to reopen selection (for testing)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        if selectionUI then
            selectionUI.Enabled = not selectionUI.Enabled
            isSelectionOpen = selectionUI.Enabled
        end
    end
end)

print("[CharacterSelection] UI initialized")
