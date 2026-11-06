-- 1. Load ImGui Module
local ImGuiURL = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/imgui.lua?t=" .. tostring(os.time())
local libCode = game:HttpGet(ImGuiURL)

local libFunc, err = loadstring(libCode)
if not libFunc then
    error("Failed to compile ImGui: " .. tostring(err))
end

local success, returnedImGui = pcall(libFunc)
if success and returnedImGui then
    ImGui = returnedImGui
else
    error("ImGui module failed to return a table: " .. tostring(returnedImGui))
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Initialize UI
ImGui.Init({ ToggleKey = Enum.KeyCode.RightShift })
local win = ImGui.Window("Kontra Aimbot", { Position = UDim2.fromOffset(100, 100), Width = 280 })

local tabs = win:Tabs({"Aimbot", "Visuals", "Settings"})

-- Configuration
local config = {
    AimbotEnabled = false,
    Fov = 200,
    Smoothness = 0.9,
    
    EspEnabled = true,
    EspColor = Color3.fromRGB(255, 0, 0)
}

local activeHighlights = {}

---------------------------------------------------------
-- AIMBOT TAB
---------------------------------------------------------
tabs.Aimbot:Checkbox("Enable Aimbot", false, function(v)
    config.AimbotEnabled = v
end)

tabs.Aimbot:Slider("Smoothness", 0.1, 1.0, 0.9, function(v)
    config.Smoothness = v
end)

tabs.Aimbot:SliderInt("FOV Radius", 10, 800, 200, function(v)
    config.Fov = v
end)

tabs.Aimbot:Separator()
tabs.Aimbot:Text("Hold RMB to lock.")

---------------------------------------------------------
-- VISUALS TAB (ESP)
---------------------------------------------------------
tabs.Visuals:Checkbox("Enable ESP", true, function(v)
    config.EspEnabled = v
    if not v then
        for char, highlight in pairs(activeHighlights) do
            if highlight then highlight:Destroy() end
            activeHighlights[char] = nil
        end
    end
end)

---------------------------------------------------------
-- SETTINGS TAB
---------------------------------------------------------
local themeNames = {"Blue", "Red", "Green", "Maroon", "Purple"}
tabs.Settings:Combo("UI Theme", themeNames, 1, function(val, idx)
    ImGui.SetTheme(val)
end)

---------------------------------------------------------
-- KONTRA AIMBOT LOGIC
---------------------------------------------------------
local isAiming = false
local lockedTarget = nil
local CHARACTERS = workspace:WaitForChild("Characters")

local function getHead(char)
    for _, name in ipairs({"Head", "HumanoidRootPart", "Torso", "UpperTorso"}) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end

local function myCharacter()
    local c = LocalPlayer.Character
    return (c and c.Parent == CHARACTERS) and c or nil
end

local function isMe(char)
    local me = myCharacter()
    if me and char == me then return true end
    
    local meHead = me and getHead(me)
    if not meHead then
        local lc = LocalPlayer.Character
        meHead = lc and getHead(lc)
    end
    if not meHead then return false end
    
    local h = getHead(char)
    if not h then return false end
    return (h.Position - meHead.Position).Magnitude < 1.0
end

local function isAlive(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    return getHead(char) ~= nil
end

local function getTarget()
    local best, bestDist = nil, math.huge
    local mousePos = UserInputService:GetMouseLocation()

    for _, char in ipairs(CHARACTERS:GetChildren()) do
        if char:IsA("Model") and not isMe(char) and isAlive(char) then
            local part = getHead(char)
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen and screenPos.Z > 0 then
                    local d = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if d < bestDist and d < config.Fov then
                        best = part
                        bestDist = d
                    end
                end
            end
        end
    end
    return best
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
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

RunService.RenderStepped:Connect(function()
    if not config.AimbotEnabled or not isAiming then return end

    if not lockedTarget or not lockedTarget.Parent or not isAlive(lockedTarget.Parent) then
        lockedTarget = getTarget()
    end

    if lockedTarget then
        local screenPos = Camera:WorldToViewportPoint(lockedTarget.Position)
        local mousePos = UserInputService:GetMouseLocation()

        local moveX = (screenPos.X - mousePos.X) * config.Smoothness
        local moveY = (screenPos.Y - mousePos.Y) * config.Smoothness

        if typeof(mousemoverel) == "function" then
            mousemoverel(moveX, moveY)
        end
    end
end)

---------------------------------------------------------
-- KONTRA ESP LOGIC
---------------------------------------------------------
local function addHighlight(character)
    if not character or not character.Parent then return end
    if activeHighlights[character] then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = config.EspColor
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 1 
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character
    
    activeHighlights[character] = highlight
end

local function updateESP()
    if not config.EspEnabled then
        if next(activeHighlights) then
            for char, highlight in pairs(activeHighlights) do
                if highlight then highlight:Destroy() end
                activeHighlights[char] = nil
            end
        end
        return
    end

    local characters = workspace:FindFirstChild("Characters")
    if not characters then return end

    for _, char in ipairs(characters:GetChildren()) do
        if char:IsA("Model") and not isMe(char) and isAlive(char) then
            if not activeHighlights[char] then
                addHighlight(char)
            end
        end
    end
end

task.spawn(function()
    while task.wait(0.5) do
        updateESP()
    end
end)
