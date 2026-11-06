local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local FOV_RADIUS = 200
local SENSITIVITY = 0.9
local AIM_KEY = Enum.UserInputType.MouseButton2
local TARGET_PART = "Head"

local isAiming = false
local lockedTarget = nil

local function getTarget()
    local target = nil
    local shortestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and char:FindFirstChild(TARGET_PART) and char:FindFirstChild("HumanoidRootPart") then
                local part = char[TARGET_PART]
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                local mousePos = UserInputService:GetMouseLocation()
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                
                if distance < shortestDistance and distance < FOV_RADIUS then
                    target = part
                    shortestDistance = distance
                end
            end
        end
    end
    return target
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == AIM_KEY then isAiming = true end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == AIM_KEY then
        isAiming = false
        lockedTarget = nil
    end
end)

RunService.RenderStepped:Connect(function()
    if isAiming then
        if not lockedTarget or not lockedTarget.Parent or not lockedTarget.Parent:FindFirstChild("Humanoid") or lockedTarget.Parent.Humanoid.Health <= 0 then
            lockedTarget = getTarget()
        end

        if lockedTarget then
            local screenPos = Camera:WorldToViewportPoint(lockedTarget.Position)
            local mousePos = UserInputService:GetMouseLocation()
            
            local moveX = (screenPos.X - mousePos.X) * SENSITIVITY
            local moveY = (screenPos.Y - mousePos.Y) * SENSITIVITY
            
            if typeof(mousemoverel) == "function" then
                mousemoverel(moveX, moveY)
            end
        end
    end
end)

local wallhackEnabled = true
local activeHighlights = {} 

local function addHighlight(character)
    if not character or not character.Parent then return end
    if activeHighlights[character] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 1 
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character
    
    activeHighlights[character] = highlight
end

local function updateESP()
    if not wallhackEnabled then
        for char, highlight in pairs(activeHighlights) do
            if highlight then highlight:Destroy() end
        end
        activeHighlights = {}
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local character = plr.Character
            if character and character.Parent then
                if not activeHighlights[character] then
                    addHighlight(character)
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.5) do
        updateESP()
    end
end)
