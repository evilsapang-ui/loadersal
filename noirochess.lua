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
local Engine = require(ReplicatedStorage.Chess.Engine)
local Bot = require(ReplicatedStorage.Chess.Bot)

local enabled = true
local currentBestMove = nil

local controller = nil
for _, mod in pairs(getloadedmodules()) do
    if mod.Name == "App" or mod.Name == "Main" or mod.Name == "Client" then
        local ok, ret = pcall(require, mod)
        if ok and type(ret) == "table" and ret.board then
            controller = ret
            break
        end
    end
end

if not controller then
    return warn("[NoiRoChess] Could not find the game controller. Make sure you are in an active game.")
end

local board = controller.board
local originalSetArrow = board.setArrow

board.setArrow = function(self, name, from, to, color, thickness)
    if originalSetArrow then
        originalSetArrow(self, name, from, to, color, thickness)
    end
end

-- 3. Configuration State
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
    Status = "no game"
}

-- 4. Build the UI
ImGui.Init({ ToggleKey = Enum.KeyCode.RightShift })
local win = ImGui.Window("NoiRoChess Hub", { Position = UDim2.fromOffset(100, 100), Width = 320 })

local tabs = win:Tabs({"Play", "Hub", "Settings"})

-- PLAY TAB
tabs.Play:TextColored("[Engine]", Color3.fromRGB(100, 200, 100))
tabs.Play:Checkbox("Autoplay", false, function(v)
    config.AutoplayEnabled = v
end)
tabs.Play:TextDisabled("Use with caution. Using max settings on a rookie account may get your account reported and banned.")

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
local statusLabel = tabs.Play:Text("Status: no game")

-- HUB TAB
tabs.Hub:TextColored("[Info]", Color3.fromRGB(100, 200, 100))
tabs.Hub:Text("Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
tabs.Hub:Text("Menu key: Right Shift")
tabs.Hub:Text("Discord: https://discord.gg/UBeRG8Qp2f")
tabs.Hub:Button("Unload", function()
    if board then board:setArrow("best", nil) end
    gui:Destroy()
end)

-- SETTINGS TAB
tabs.Settings:TextColored("[Timing]", Color3.fromRGB(100, 200, 100))
tabs.Settings:Slider("Min delay", 0.1, 5, 0.6, function(v) config.MinDelay = v end)
tabs.Settings:Slider("Max delay", 0.1, 10, 2.4, function(v) config.MaxDelay = v end)

-- 5. Main Logic Loop
local RunService = game:GetService("RunService")
local moveDelay = 0
local targetMove = nil

RunService.RenderStepped:Connect(function()
    if not enabled then return end
    
    local session = controller.session
    if not session or session.kind == "analysis" then 
        stats.Status = "no game"
        return 
    end

    -- Check whose turn it is
    local engine = session:engineAt(#session.ucis)
    local isMyTurn = (session.myColor == 1 and engine.side == 1) or 
                     (session.myColor == -1 and engine.side == -1)
    
    if not isMyTurn then 
        stats.Status = "waiting for opponent"
        return 
    end

    stats.Status = "thinking..."

    -- Run engine
    local fen = session.startFen or Engine.START_FEN
    local startTime = os.clock()
    
    -- If we don't already have a locked move for this turn, calculate one
    if not targetMove then
        local moveUci, info = Bot.think(fen, session.ucis, {rating = 3000, depth = config.DepthLimit, time = config.ThinkTime})
        
        if moveUci then
            stats.Depth = info and info.depth or config.DepthLimit
            stats.Nodes = info and info.nodes or 0
            stats.Time = os.clock() - startTime

            local fromSquare = Engine.algToIndex64((string.sub(moveUci, 1, 2)))
            local toSquare = Engine.algToIndex64((string.sub(moveUci, 3, 4)))

            if config.HintsEnabled then
                board:setArrow("best", fromSquare, toSquare, Color3.fromRGB(46, 196, 182), 0.2)
            else
                board:setArrow("best", nil)
            end

            if config.AutoplayEnabled then
                targetMove = moveUci
                moveDelay = os.clock() + math.random(config.MinDelay * 100, config.MaxDelay * 100) / 100
            end
        end
    end

    -- Handle autoplay delay
    if config.AutoplayEnabled and targetMove then
        if os.clock() >= moveDelay then
            stats.Status = "playing..."
            session:applyUci(targetMove)
            targetMove = nil
            if config.HintsEnabled then board:setArrow("best", nil) end
        end
    end
end)

-- 6. UI Updater (Runs every 0.1s to keep the stats text accurate)
task.spawn(function()
    while task.wait(0.1) do
        if statLabel then
            statLabel:Set(string.format("Depth %d | %.1fk nodes | %.2fs", stats.Depth, stats.Nodes / 1000, stats.Time))
            statusLabel:Set("Status: " .. stats.Status)
        end
    end
end)
