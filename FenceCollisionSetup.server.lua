--[[
    FenceCollisionSetup.server.lua
    Finds fence parts in the workspace and adds invisible collision walls
    to prevent players from walking/jumping over them.

    How to use:
    1. Name your fence models/parts with "Fence" in the name (e.g., "Fence", "WoodFence", "FencePost")
    2. This script will automatically add invisible walls on top of them

    Or manually tag parts with CollectionService tag "Fence"
]]

local CollectionService = game:GetService("CollectionService")

-- Configuration
local WALL_HEIGHT = 15        -- How tall the invisible wall should be (studs above fence)
local WALL_TRANSPARENCY = 1   -- 1 = fully invisible, set to 0.5 to debug/see walls
local FENCE_NAME_PATTERN = "fence" -- Case-insensitive pattern to match fence names

-- Track which parts we've already processed
local processedParts = {}

-- Create an invisible wall above a fence part
local function addCollisionWall(part)
    if processedParts[part] then return end
    processedParts[part] = true

    -- Get the size and position of the fence part
    local size = part.Size
    local cf = part.CFrame

    -- Create invisible wall part
    local wall = Instance.new("Part")
    wall.Name = "FenceCollisionWall"
    wall.Anchored = true
    wall.CanCollide = true
    wall.Transparency = WALL_TRANSPARENCY
    wall.Material = Enum.Material.ForceField  -- Lightweight material
    wall.Color = Color3.fromRGB(255, 0, 0)    -- Red for debugging (invisible anyway)

    -- Size: same width/depth as fence, but tall
    wall.Size = Vector3.new(size.X, WALL_HEIGHT, size.Z)

    -- Position: above the fence part
    wall.CFrame = cf * CFrame.new(0, (size.Y / 2) + (WALL_HEIGHT / 2), 0)

    -- Parent to the same parent as the fence (keeps hierarchy clean)
    wall.Parent = part.Parent

    -- If the fence part is destroyed, remove the wall too
    part.AncestryChanged:Connect(function(_, parent)
        if not parent and wall and wall.Parent then
            wall:Destroy()
        end
    end)

    print("[FenceCollision] Added wall above:", part:GetFullName())
end

-- Check if a part is a fence (by name or tag)
local function isFencePart(part)
    -- Check CollectionService tag
    if CollectionService:HasTag(part, "Fence") then
        return true
    end

    -- Check name (case-insensitive)
    local name = part.Name:lower()
    if name:find(FENCE_NAME_PATTERN) then
        return true
    end

    -- Check parent model name
    local model = part:FindFirstAncestorOfClass("Model")
    if model and model.Name:lower():find(FENCE_NAME_PATTERN) then
        return true
    end

    return false
end

-- Process all existing fence parts
local function processExistingFences()
    local count = 0

    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("BasePart") and isFencePart(descendant) then
            addCollisionWall(descendant)
            count = count + 1
        end
    end

    print("[FenceCollision] Processed", count, "fence parts")
end

-- Listen for new fence parts added to workspace
local function setupNewPartListener()
    workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") and isFencePart(descendant) then
            -- Small delay to ensure part is fully loaded
            task.defer(function()
                addCollisionWall(descendant)
            end)
        end
    end)
end

-- Also ensure original fence parts have CanCollide = true
local function ensureFenceCollision()
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("BasePart") and isFencePart(descendant) then
            if not descendant.CanCollide then
                descendant.CanCollide = true
                print("[FenceCollision] Enabled CanCollide on:", descendant:GetFullName())
            end
        end
    end
end

-- Initialize
print("[FenceCollision] Starting fence collision setup...")
ensureFenceCollision()
processExistingFences()
setupNewPartListener()
print("[FenceCollision] Setup complete!")
