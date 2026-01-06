--[[
    FenceCollisionSetup.server.lua
    Finds fence models in the workspace and adds invisible collision walls
    to prevent players from walking/jumping over them.

    How to use:
    1. Name your fence models "Fence" (or anything containing "Fence")
    2. This script will automatically add invisible walls on top of them
]]

-- Configuration
local WALL_HEIGHT = 15        -- How tall the invisible wall should be (studs)
local WALL_TRANSPARENCY = 1   -- 1 = fully invisible, set to 0.5 to debug/see walls
local FENCE_NAME_PATTERN = "fence" -- Case-insensitive pattern to match fence names

-- Track which fences we've already processed
local processedFences = {}

-- Get the bounding box of a model or part
local function getBoundingBox(object)
    if object:IsA("Model") then
        -- Use GetBoundingBox for models
        local cf, size = object:GetBoundingBox()
        return cf, size
    elseif object:IsA("BasePart") then
        return object.CFrame, object.Size
    end
    return nil, nil
end

-- Create an invisible wall above a fence
local function addCollisionWall(fence)
    if processedFences[fence] then return end
    processedFences[fence] = true

    local cf, size = getBoundingBox(fence)
    if not cf or not size then
        warn("[FenceCollision] Could not get bounds for:", fence:GetFullName())
        return
    end

    -- Create invisible wall part
    local wall = Instance.new("Part")
    wall.Name = "FenceCollisionWall"
    wall.Anchored = true
    wall.CanCollide = true
    wall.Transparency = WALL_TRANSPARENCY
    wall.Material = Enum.Material.ForceField
    wall.Color = Color3.fromRGB(255, 0, 0)  -- Red for debugging (invisible anyway)

    -- Size: cover the full fence footprint, extend upward
    wall.Size = Vector3.new(size.X, WALL_HEIGHT, size.Z)

    -- Position: above the fence (only use Y rotation from fence)
    local _, yRot, _ = cf:ToEulerAnglesYXZ()
    local topOfFence = cf.Position + Vector3.new(0, size.Y / 2, 0)
    wall.CFrame = CFrame.new(topOfFence + Vector3.new(0, WALL_HEIGHT / 2, 0)) * CFrame.Angles(0, yRot, 0)

    -- Parent to workspace (not fence, so it doesn't affect fence bounds)
    wall.Parent = workspace

    -- If the fence is destroyed, remove the wall too
    fence.AncestryChanged:Connect(function(_, parent)
        if not parent and wall and wall.Parent then
            wall:Destroy()
            processedFences[fence] = nil
        end
    end)

    print("[FenceCollision] Added wall above:", fence:GetFullName(), "Size:", size)
end

-- Check if something is a fence (by name)
local function isFence(object)
    local name = object.Name:lower()
    return name:find(FENCE_NAME_PATTERN) ~= nil
end

-- Enable collision on all parts in a fence
local function ensureFenceCollision(fence)
    if fence:IsA("BasePart") then
        fence.CanCollide = true
    elseif fence:IsA("Model") then
        for _, part in ipairs(fence:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end

-- Process all existing fences
local function processExistingFences()
    local count = 0

    -- Look for direct children of workspace named "Fence"
    for _, child in ipairs(workspace:GetChildren()) do
        if isFence(child) then
            ensureFenceCollision(child)
            addCollisionWall(child)
            count = count + 1
        end
    end

    -- Also check all descendants for nested fences
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if (descendant:IsA("Model") or descendant:IsA("BasePart")) and isFence(descendant) then
            if not processedFences[descendant] then
                ensureFenceCollision(descendant)
                addCollisionWall(descendant)
                count = count + 1
            end
        end
    end

    print("[FenceCollision] Processed", count, "fences")
end

-- Listen for new fences added to workspace
local function setupNewFenceListener()
    workspace.DescendantAdded:Connect(function(descendant)
        if (descendant:IsA("Model") or descendant:IsA("BasePart")) and isFence(descendant) then
            task.defer(function()
                ensureFenceCollision(descendant)
                addCollisionWall(descendant)
            end)
        end
    end)
end

-- Initialize
print("[FenceCollision] Starting fence collision setup...")
processExistingFences()
setupNewFenceListener()
print("[FenceCollision] Setup complete!")
