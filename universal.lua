-- 1. Load ImGui Module
local ImGuiURL = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/imgui.lua"
local libCode = game:HttpGet(ImGuiURL)

-- Strip HTML if GitHub served a webpage
libCode = string.gsub(libCode, "<[^>]*>", "")

-- Force the library to return the table at the very end, no matter what
libCode = libCode .. "\n\nreturn ImGui"

local libFunc, err = loadstring(libCode)
if libFunc then
    local success, returnedImGui = pcall(libFunc)
    if success and returnedImGui then
        ImGui = returnedImGui 
    else
        error("ImGui module failed to execute: " .. tostring(returnedImGui))
    end
else
    error("Failed to compile ImGui: " .. tostring(err))
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Initialize UI
ImGui.Init({ ToggleKey = Enum.KeyCode.RightShift })
local win = ImGui.Window("Universal Hub", { Position = UDim2.fromOffset(100, 100), Width = 280 })

local tabs = win:Tabs({"Aimbot", "Visuals"})

local config = {
    AimbotEnabled = false,
    Fov = 200,
    Smoothness = 0.9,
    TargetPart = "Head",
    
    EspEnabled = true,
    EspColor = Color3.fromRGB(255, 0, 0)
}

-- AIMBOT TAB
tabs.Aimbot:Checkbox("Enable Aimbot", false, function(v)
    config.AimbotEnabled = v
end)

tabs.Aimbot:SliderInt("FOV Radius", 10, 800, 200, function(v)
    config.Fov = v
end)

tabs.Aimbot:Slider("Smoothness", 0.1, 1.0, 0.9, function(v)
    config.Smoothness = v
end)

tabs.Aimbot:Separator()
tabs.Aimbot:Text("Hold RMB to lock.")

-- VISUALS TAB (ESP)
tabs.Visuals:Checkbox("Enable ESP", true, function(v)
    config.EspEnabled = v
    if not v then
        for char, highlight in pairs(activeHighlights) do
            if highlight then highlight:Destroy() end
        end
        activeHighlights = {}
    end
end)

-- LOGIC
local isAiming = false
local lockedTarget = nil
local activeHighlights = {}

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 and config.AimbotEnabled then
        isAiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isAiming = false
        lockedTarget = nil
    end
end)

local function getTarget()
    local target = nil
    local shortestDistance = math.huge
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char and char:FindFirstChild(config.TargetPart) and char:FindFirstChild("HumanoidRootPart") then
                local part = char[config.TargetPart]
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                
                if onScreen and screenPos.Z > 0 then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if distance < shortestDistance and distance < config.Fov then
                        target = part
                        shortestDistance = distance
                    end
                end
            end
        end
    end
    return target
end

local function addHighlight(character)
    if not character or not character.Parent then return end
    if activeHighlights[character] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = config.EspColor
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 1 
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character
    
    activeHighlights[character] = highlight
end

local function updateESP()
    if not config.EspEnabled then return end

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

RunService.RenderStepped:Connect(function()
    if isAiming and config.AimbotEnabled then
        if not lockedTarget or not lockedTarget.Parent or not lockedTarget:FindFirstChild("Humanoid") or lockedTarget.Parent.Humanoid.Health <= 0 then
            lockedTarget = getTarget()
        end

        if lockedTarget then
            local screenPos = Camera:WorldToViewportPoint(lockedTarget.Position)
            local mousePos = UserInputService:GetMouseLocation()
            
            local moveX = (screenPos.X - mousePos.X) * config.Smoothness
            local moveY = (screenPos.Y - mousePos.Y) * config.Smoothness
            
            if typeof(mousemoverel) == "function" then
                mousemoverel(moveX, moveY)
            elseif typeof(mousemoveabs) == "function" then
                mousemoveabs(mousePos.X + moveX, mousePos.Y + moveY)
            end
        end
    end
end)
