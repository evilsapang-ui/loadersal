local ImGuiURL = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/imgui.lua?t=" .. tostring(os.time())
local libCode = game:HttpGet(ImGuiURL)

-- Force the return statement in case the file on GitHub is missing it
libCode = libCode .. "\n\nreturn ImGui"

local libFunc, err = loadstring(libCode)
if not libFunc then
    error("Failed to compile ImGui: " .. tostring(err))
end

-- Execute and capture
local success, returnedImGui = pcall(libFunc)
if success and returnedImGui then
    ImGui = returnedImGui
else
    error("ImGui module failed to return a table: " .. tostring(returnedImGui))
end

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- Initialize UI
ImGui.Init({ ToggleKey = Enum.KeyCode.RightShift })
local win = ImGui.Window("Kontra Aimbot", { Position = UDim2.fromOffset(100, 100), Width = 280 })

-- (The rest of your Kontra UI logic goes here)
local tabs = win:Tabs({"Aimbot", "Settings"})

local config = {
    Enabled = false,
    Fov = 150,
    Smoothness = 0.15,
    TargetPart = "Head"
}

tabs.Aimbot:TextColored("Aimbot Settings", Color3.fromRGB(66, 150, 250))
tabs.Aimbot:Separator()

tabs.Aimbot:Checkbox("Enable Aimbot", false, function(v)
    config.Enabled = v
end)

tabs.Aimbot:Slider("Smoothness", 0.01, 1.0, 0.15, function(v)
    config.Smoothness = v
end)

tabs.Aimbot:SliderInt("FOV Radius", 10, 600, 150, function(v)
    config.Fov = v
end)

tabs.Aimbot:Separator()
tabs.Aimbot:Text("Hold RMB to lock.")

-- SETTINGS TAB (THEMES)
local themeNames = {"Blue", "Red", "Green", "Maroon", "Purple"}
tabs.Settings:Combo("UI Theme", themeNames, 1, function(val, idx)
    ImGui.SetTheme(val)
end)

-- (Rest of your Kontra Aiming logic stays exactly the same)
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(66, 150, 250)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Visible = false

local isAiming = false
local currentTarget = nil

local function getHead(char)
    for _, name in ipairs({"Head", "HumanoidRootPart", "Torso", "UpperTorso"}) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end

local function isAlive(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then return false end
    return getHead(char) ~= nil
end

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 and config.Enabled then
        isAiming = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isAiming = false
        currentTarget = nil
    end
end)

RunService.RenderStepped:Connect(function()
    local mousePos = UIS:GetMouseLocation()
    
    if config.Enabled then
        fovCircle.Position = mousePos
        fovCircle.Radius = config.Fov
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end

    if not config.Enabled or not isAiming then return end

    if not currentTarget or not currentTarget.Parent or not isAlive(currentTarget.Parent) then
        local bestTarget = nil
        local shortestDist = config.Fov
        local Characters = workspace:FindFirstChild("Characters")
        
        if Characters then
            for _, model in ipairs(Characters:GetChildren()) do
                if model:IsA("Model") and model.PrimaryPart then
                    local distToCam = (model.PrimaryPart.Position - Camera.CFrame.Position).Magnitude
                    if distToCam > 2 then
                        local part = getHead(model)
                        if part then
                            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen and screenPos.Z > 0 then
                                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                                if dist < shortestDist then
                                    bestTarget = part
                                    shortestDist = dist
                                end
                            end
                        end
                    end
                end
            end
        end
        currentTarget = bestTarget
    end

    if currentTarget then
        local screenPos, onScreen = Camera:WorldToViewportPoint(currentTarget.Position)
        if onScreen then
            local deltaX = screenPos.X - mousePos.X
            local deltaY = screenPos.Y - mousePos.Y
            
            local moveX = deltaX * config.Smoothness
            local moveY = deltaY * config.Smoothness
            
            if typeof(mousemoverel) == "function" then
                mousemoverel(moveX, moveY)
            elseif typeof(mousemoveabs) == "function" then
                mousemoveabs(mousePos.X + moveX, mousePos.Y + moveY)
            end
        end
    end
end)
