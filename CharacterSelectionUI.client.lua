--[[
    CharacterSelectionUI.client.lua
    Client script for character selection interface
    Place in StarterPlayerScripts

    Press C to open character selection menu
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Wait for selection events
local SelectionEvents = ReplicatedStorage:WaitForChild("SelectionEvents")
local SelectCharacter = SelectionEvents:WaitForChild("SelectCharacter")
local CharacterSelected = SelectionEvents:WaitForChild("CharacterSelected")

-- Get characters folder to list available characters
local Characters = ReplicatedStorage:WaitForChild("Characters")

-- UI State
local isOpen = false
local screenGui = nil
local mainFrame = nil

-- Character button colors
local COLORS = {
    normal = Color3.fromRGB(50, 50, 60),
    hover = Color3.fromRGB(70, 70, 85),
    selected = Color3.fromRGB(80, 140, 200),
}

-- Create the selection UI
local function createUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CharacterSelectionUI"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = false
    screenGui.Parent = player.PlayerGui

    -- Background overlay
    local overlay = Instance.new("Frame")
    overlay.Name = "Overlay"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui

    -- Main frame
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 350)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Select Character"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame

    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        toggleUI(false)
    end)

    -- Character list container
    local listContainer = Instance.new("ScrollingFrame")
    listContainer.Name = "CharacterList"
    listContainer.Size = UDim2.new(1, -40, 1, -70)
    listContainer.Position = UDim2.new(0, 20, 0, 55)
    listContainer.BackgroundTransparency = 1
    listContainer.ScrollBarThickness = 6
    listContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    listContainer.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = listContainer

    -- Create buttons for each character
    for _, characterModel in pairs(Characters:GetChildren()) do
        if characterModel:IsA("Model") then
            local btn = Instance.new("TextButton")
            btn.Name = characterModel.Name
            btn.Size = UDim2.new(1, -10, 0, 60)
            btn.BackgroundColor3 = COLORS.normal
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.Parent = listContainer

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 8)
            btnCorner.Parent = btn

            -- Character name label
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "CharacterName"
            nameLabel.Size = UDim2.new(1, -20, 1, 0)
            nameLabel.Position = UDim2.new(0, 10, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = characterModel.Name
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 20
            nameLabel.Font = Enum.Font.GothamSemibold
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = btn

            -- Hover effects
            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = COLORS.hover
                }):Play()
            end)

            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.15), {
                    BackgroundColor3 = COLORS.normal
                }):Play()
            end)

            -- Selection
            btn.MouseButton1Click:Connect(function()
                -- Visual feedback
                btn.BackgroundColor3 = COLORS.selected
                task.wait(0.2)

                -- Send selection to server
                SelectCharacter:FireServer(characterModel.Name)

                -- Close menu
                toggleUI(false)
            end)
        end
    end

    -- Update canvas size
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)
    listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)

    -- Hint label
    local hint = Instance.new("TextLabel")
    hint.Name = "Hint"
    hint.Size = UDim2.new(0, 200, 0, 30)
    hint.Position = UDim2.new(0.5, -100, 1, -50)
    hint.BackgroundTransparency = 1
    hint.Text = "[C] Character Select"
    hint.TextColor3 = Color3.fromRGB(180, 180, 180)
    hint.TextSize = 14
    hint.Font = Enum.Font.Gotham
    hint.Parent = player.PlayerGui:FindFirstChild("MountedMovementUI") or screenGui

    return screenGui
end

-- Toggle UI visibility
function toggleUI(open)
    if open == nil then
        open = not isOpen
    end

    isOpen = open
    screenGui.Enabled = isOpen
end

-- Handle keyboard input
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.C then
        toggleUI()
    elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
        toggleUI(false)
    end
end)

-- Handle character selected notification
CharacterSelected.OnClientEvent:Connect(function(characterName)
    print("[CharacterSelection] Now playing as:", characterName)
end)

-- Initialize
createUI()

print("[CharacterSelectionUI] Press C to select a character")
