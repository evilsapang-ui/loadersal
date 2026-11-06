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

-- 2. Game Hooks
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChessFolder = ReplicatedStorage:WaitForChild("Chess", 10)
if not ChessFolder then
    return warn("[NoiRoChess] Could not find Chess folder. Are you in a RoChess game?")
end

local Engine = require(ChessFolder.Engine)
local Bot = require(ChessFolder.Bot)
local Remotes = ChessFolder:WaitForChild("Remotes")
local MakeMove = Remotes:WaitForChild("MakeMove", 5) or Remotes:WaitForChild("SubmitMove", 5)

local enabled = true
local currentBestMove = nil
local session = nil
local board = nil

-- 3. Find the Session and Board from the PlayerGui
local function findGameObjects()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end

    -- Find the Session (The game stores the session in the App controller)
    -- We traverse the GUI to find the board object.
    for _, obj in ipairs(pg:GetDescendants()) do
        if obj.Name == "Board" and obj:IsA("Frame") then
            board = obj
            break
        end
    end

    -- If we found the board, we can just overwrite its setArrow function
    if board then
        local originalSetArrow = board.setArrow
        board.setArrow = function(self, name, from, to, color, thickness)
            if originalSetArrow then
                originalSetArrow(self, name, from, to, color, thickness)
            end
        end
        return true
    end
    return false
end

-- 4. Configuration State
local config = {
    AutoplayEnabled = false,
    HintsEnabled = false,
    DepthLimit = 22,
    ThinkTime = 2.5,
    MinDelay = 0.6,
    MaxDelay = 2.4
}

local stats = {
    Depth = 0,
    Nodes = 0,
    Time = 0.00,
    Status = "searching for game..."
}

-- 5. Build the UI
ImGui.Init({ ToggleKey = Enum.KeyCode.RightShift })
local win = ImGui.Window("NoiRoChess Hub", { Position = UDim2.fromOffset(100, 100), Width = 320 })
local tabs = win:Tabs({"Play", "Hub", "Settings"})

-- PLAY TAB
tabs.Play:TextColored("[Engine]", Color3.fromRGB(100, 200, 100))
tabs.Play:Checkbox("Autoplay", false, function(v) config.AutoplayEnabled = v end)
tabs.Play:TextDisabled("Use with caution.")

tabs.Play:Spacing(10)
tabs.Play:TextColored("[Hints (Board ESP)]", Color3.fromRGB(100, 200, 100))
tabs.Play:Checkbox("Show Hints", false, function(v)
    config.HintsEnabled = v
    if not v and board then board:setArrow("best", nil) end
end)
tabs.Play:TextDisabled("Shows the best move arrow on the board.")

tabs.Play:SliderInt("Depth limit", 1, 30, 22, function(v) config.DepthLimit = v end)
tabs.Play:Slider("Think time", 0.1, 10, 2.5, function(v) config.ThinkTime = v end)

tabs.Play:Spacing(10)
local statLabel = tabs.Play:Text("Depth 0 | 0k nodes | 0.00s")
local statusLabel = tabs.Play:Text("Status: searching for game...")

-- HUB TAB
tabs.Hub:TextColored("[Info]", Color3.fromRGB(100, 200, 100))
tabs.Hub:Text("Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
tabs.Hub:Button("Unload", function()
    if board then board:setArrow("best", nil) end
    gui:Destroy()
end)

-- SETTINGS TAB
tabs.Settings:TextColored("[Timing]", Color3.fromRGB(100, 200, 100))
tabs.Settings:Slider("Min delay", 0.1, 5, 0.6, function(v) config.MinDelay = v end)
tabs.Settings:Slider("Max delay", 0.1, 10, 2.4, function(v) config.MaxDelay = v end)

-- 6. Main Logic Loop
local RunService = game:GetService("RunService")
local moveDelay = 0
local targetMove = nil
local lastFen = ""

RunService.RenderStepped:Connect(function()
    if not enabled then return end

    -- Try to find the board if we haven't yet
    if not board then
        if findGameObjects() then
            stats.Status = "waiting for game..."
        else
            return
        end
    end

    -- We need to find the session object. Since it's not exposed, 
    -- we'll rely on the game's own Bot module to calculate the move.
    -- (If you can find the exact path to the 'session' object, replace this).
    
    stats.Status = "thinking..."
    
    local fen = Engine.START_FEN -- FILL: If you can grab the real FEN from the board, put it here.
    
    if lastFen ~= fen then
        lastFen = fen
        
        local startTime = os.clock()
        local moveUci, info = Bot.think(fen, {}, {rating = 3000, depth = config.DepthLimit, time = config.ThinkTime})
        
        if moveUci then
            stats.Depth = info and info.depth or config.DepthLimit
            stats.Nodes = info and info.nodes or 0
            stats.Time = os.clock() - startTime
            currentBestMove = moveUci
            
            if config.AutoplayEnabled and MakeMove then
                targetMove = moveUci
                moveDelay = os.clock() + math.random(config.MinDelay * 100, config.MaxDelay * 100) / 100
            end
        end
    end

    -- Draw hints
    if config.HintsEnabled and currentBestMove and board then
        local fromSquare = Engine.algToIndex64((string.sub(currentBestMove, 1, 2)))
        local toSquare = Engine.algToIndex64((string.sub(currentBestMove, 3, 4)))
        board:setArrow("best", fromSquare, toSquare, Color3.fromRGB(46, 196, 182), 0.2)
    end

    -- Handle autoplay
    if config.AutoplayEnabled and targetMove and MakeMove then
        if os.clock() >= moveDelay then
            stats.Status = "playing..."
            -- Fire the remote
            pcall(function()
                MakeMove:FireServer(targetMove)
            end)
            targetMove = nil
        end
    end
end)

-- 7. UI Updater
task.spawn(function()
    while task.wait(0.1) do
        if statLabel then
            statLabel:Set(string.format("Depth %d | %.1fk nodes | %.2fs", stats.Depth, stats.Nodes / 1000, stats.Time))
            statusLabel:Set("Status: " .. stats.Status)
        end
    end
end)
