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
    if originalSetArrow then originalSetArrow(self, name, from, to, color, thickness) end
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
    Status = "off"
}

-- 4. Build the UI
ImGui.Init({ ToggleKey = Enum.KeyCode.RightShift })
local win = ImGui.Window("RoChess Noic hub", { Position = UDim2.fromOffset(100, 100), Width = 650 })

-- Top status badge
local statusBadge = win:TextColored("working", Color3.fromRGB(150, 255, 150))
statusBadge.Instance.TextSize = 12
statusBadge.Instance.TextXAlignment = Enum.TextXAlignment.Center
statusBadge.Instance.TextWrapped = false
statusBadge.Instance.Size = UDim2.new(0, 60, 0, 16)
statusBadge.Instance.Position = UDim2.new(0, 110, 0, 2)
statusBadge.Instance.BackgroundTransparency = 1
statusBadge.Instance.Parent.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
statusBadge.Instance.Parent.Size = UDim2.new(0, 60, 0, 16)
statusBadge.Instance.Parent.Position = UDim2.new(0, 110, 0, 2)

local tabs = win:SidebarTabs({"Play", "Hub", "Settings"}, 90)

-- ==========================================
-- PLAY TAB
-- ==========================================
local cols = tabs.Play:Columns(2)
local left = cols[1]
local right = cols[2]

-- Left Column
left:Section("Engine")
left:Checkbox("Engine", false, function(v) config.AutoplayEnabled = v end)
left:SubText("Use with caution. Using max settings on a rookie account may get your account reported and banned.")

left:Checkbox("Hints (Board ESP)", false, function(v)
    config.HintsEnabled = v
    if not v and board then board:setArrow("best", nil) end
end)
left:SubText("Shows the move on the board.")

left:SliderInt("Depth limit", 1, 30, 22, function(v) config.DepthLimit = v end)
left:Slider("Think time", 0.1, 10, 2.5, function(v) config.ThinkTime = v end)

local statLabel = left:TextDisabled("Depth 0 | 0k nodes | 0.00s")
local statusLabel = left:TextDisabled("Status: off")

-- Right Column
right:Section("Timing")
right:Slider("Min delay", 0.1, 5, 0.6, function(v) config.MinDelay = v end)
right:Slider("Max delay", 0.1, 10, 2.4, function(v) config.MaxDelay = v end)

-- ==========================================
-- HUB TAB
-- ==========================================
local hubCols = tabs.Hub:Columns(2)
local hubLeft = hubCols[1]

hubLeft:Section("Info")
hubLeft:Text("Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
hubLeft:Text("Menu key: Right Shift")
hubLeft:Text("Discord: https://discord.gg/UBeRG8Qp2f")
hubLeft:Text("Bunni is untested. Continue anyway.")
hubLeft:Button("Unload", function()
    if board then board:setArrow("best", nil) end
    win:Destroy()
end)

-- ==========================================
-- SETTINGS TAB
-- ==========================================
local setCols = tabs.Settings:Columns(2)
local setLeft = setCols[1]
local setRight = setCols[2]

-- Left Column
setLeft:Section("Appearance")
setLeft:Dropdown("Theme", {"default", "Dark", "Light"}, 1, function(val) end)
setLeft:Checkbox("Rainbow top bar", false, function(v) end)
setLeft:Dropdown("Language", {"English", "Spanish", "Russian"}, 1, function(val) end)
setLeft:Slider("UI scale", 0.5, 1.5, 1, function(v) end)
setLeft:Checkbox("Animations", true, function(v) end)

setLeft:Section("Interface")
setLeft:Checkbox("Keep on screen", true, function(v) end)
setLeft:SubText("The menu can't be dragged off the edge", 0)
setLeft:Checkbox("Lock position", false, function(v) end)
setLeft:Checkbox("Notifications", true, function(v) end)
setLeft:Checkbox("Info bar", true, function(v) end)
setLeft:Button("Center window", function() end)

-- Right Column
setRight:Section("Menu")
setRight:Keybind("Menu key", Enum.KeyCode.RightShift, nil, function(k) end)
setRight:Button("Unload", function() win:Destroy() end)

setRight:Section("Configurations")
setRight:InputText("Name", "", function(t) end, "config name")
setRight:Dropdown("Saved", {"None"}, 1, function(val) end)
setRight:ButtonGroup(2, {
    {"Save", function() end},
    {"Load", function() end},
    {"Delete", function() end},
    {"Refresh", function() end}
})

setRight:Section("About")
setRight:Text("Status")
setRight:SubText("Hub is working.", 0)
setRight:Text("Noic Hub")
setRight:Text("Executor: Bunni")
setRight:Button("Join our Discord", function() end)

-- Info bar
win:InfoBar("v1.0.0 | Executor: Bunni", "FPS: 60 | Ping: 30ms")

-- 5. Main Logic Loop
local RunService = game:GetService("RunService")
local moveDelay = 0
local targetMove = nil
local lastFen = ""

RunService.RenderStepped:Connect(function()
    if not enabled then return end
    
    local session = controller.session
    if not session or session.kind == "analysis" then 
        stats.Status = "no game"
        return 
    end

    local engine = session:engineAt(#session.ucis)
    local isMyTurn = (session.myColor == 1 and engine.side == 1) or 
                     (session.myColor == -1 and engine.side == -1)
    
    if not isMyTurn then 
        stats.Status = "waiting..."
        if config.HintsEnabled and board then board:setArrow("best", nil) end
        return 
    end

    stats.Status = "thinking..."

    local currentFen = engine:getFen()
    if lastFen ~= currentFen then
        lastFen = currentFen
        targetMove = nil
        
        local fen = session.startFen or Engine.START_FEN
        local startTime = os.clock()
        local moveUci, info = Bot.think(fen, session.ucis, {rating = 3000, depth = config.DepthLimit, time = config.ThinkTime})
        
        if moveUci then
            stats.Depth = info and info.depth or config.DepthLimit
            stats.Nodes = info and info.nodes or 0
            stats.Time = os.clock() - startTime
            currentBestMove = moveUci
            
            if config.AutoplayEnabled then
                targetMove = moveUci
                moveDelay = os.clock() + math.random(math.floor(config.MinDelay * 100), math.floor(config.MaxDelay * 100)) / 100
            end
        end
    end

    if config.HintsEnabled and currentBestMove and board then
        local fromSquare = Engine.algToIndex64((string.sub(currentBestMove, 1, 2)))
        local toSquare = Engine.algToIndex64((string.sub(currentBestMove, 3, 4)))
        board:setArrow("best", fromSquare, toSquare, Color3.fromRGB(46, 196, 182), 0.2)
    end

    if config.AutoplayEnabled and targetMove then
        if os.clock() >= moveDelay then
            stats.Status = "playing..."
            session:applyUci(targetMove)
            targetMove = nil
        end
    end
end)

-- 6. UI Updater
task.spawn(function()
    while task.wait(0.1) do
        if statLabel then
            statLabel:Set(string.format("Depth %d | %.1fk nodes | %.2fs", stats.Depth, stats.Nodes / 1000, stats.Time))
            statusLabel:Set("Status: " .. stats.Status)
        end
    end
end)
