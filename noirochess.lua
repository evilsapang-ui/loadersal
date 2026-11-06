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

-- Find the game controller (to get the board and session)
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

-- Add the "working" status badge top right
local statusBadge = win:TextColored("  working  ", Color3.fromRGB(150, 255, 150))
statusBadge.Instance.Parent.BackgroundColor3 = Color3.fromRGB(30, 50, 30)
statusBadge.Instance.Parent.Size = UDim2.new(0, 60, 0, 16)
statusBadge.Instance.Parent.Position = UDim2.new(0, 120, 0, 2)

local tabs = win:Tabs({"Play", "Hub", "Settings"})

-- PLAY TAB
local left, right = tabs.Play:Column()

-- Left Column (Engine)
local engineCard = left:GroupCard()
engineCard:SectionHeader("Engine")
engineCard:Checkbox("Engine", false, function(v) config.AutoplayEnabled = v end)
engineCard:TextDisabled("Use with caution. Using max settings on a rookie account may get your account reported and banned.")

engineCard:Spacing(8)
engineCard:Checkbox("Hints (Board ESP)", false, function(v)
    config.HintsEnabled = v
    if not v and board then board:setArrow("best", nil) end
end)
engineCard:TextDisabled("Shows the move on the board.")

engineCard:SliderInt("Depth limit", 1, 30, 22, function(v) config.DepthLimit = v end)
engineCard:Slider("Think time", 0.1, 10, 2.5, function(v) config.ThinkTime = v end)

engineCard:Spacing(8)
local statLabel = engineCard:TextDisabled("Depth 0 | 0k nodes | 0.00s")
local statusLabel = engineCard:TextDisabled("Status: off")

-- Right Column (Timing)
local timingCard = right:GroupCard()
timingCard:SectionHeader("Timing")
timingCard:Slider("Min delay", 0.1, 5, 0.6, function(v) config.MinDelay = v end)
timingCard:Slider("Max delay", 0.1, 10, 2.4, function(v) config.MaxDelay = v end)

-- HUB TAB
local hubLeft, hubRight = tabs.Hub:Column()
local infoCard = hubLeft:GroupCard()
infoCard:SectionHeader("Info")
infoCard:Text("Executor: " .. (identifyexecutor and identifyexecutor() or "Unknown"))
infoCard:Text("Menu key: Right Shift")
infoCard:Text("Discord: https://discord.gg/UBeRG8Qp2f")
infoCard:Text("Bunni is untested. Continue anyway.")

infoCard:Button("Unload", function()
    if board then board:setArrow("best", nil) end
    gui:Destroy()
end)

-- SETTINGS TAB
local setLeft, setRight = tabs.Settings:Column()

-- Left Column
local appearanceCard = setLeft:GroupCard()
appearanceCard:SectionHeader("Appearance")
appearanceCard:Combo("Theme", {"default", "Dark", "Light"}, 1, function(val) end)
appearanceCard:Checkbox("Rainbow top bar", false, function(v) end)
appearanceCard:Combo("Language", {"English", "Spanish", "Russian"}, 1, function(val) end)
appearanceCard:Slider("UI scale", 0.5, 1.5, 1, function(v) end)
appearanceCard:Checkbox("Animations", true, function(v) end)

local interfaceCard = setLeft:GroupCard()
interfaceCard:SectionHeader("Interface")
interfaceCard:Checkbox("Keep on screen", true, function(v) end)
interfaceCard:TextDisabled("The menu can't be dragged off the edge")
interfaceCard:Checkbox("Lock position", false, function(v) end)
interfaceCard:Checkbox("Notifications", true, function(v) end)
interfaceCard:Checkbox("Info bar", true, function(v) end)
interfaceCard:Button("Center window", function() end)

-- Right Column
local menuCard = setRight:GroupCard()
menuCard:SectionHeader("Menu")
menuCard:Keybind("Menu key", Enum.KeyCode.RightShift, nil, function(k) end)
menuCard:Button("Unload", function() gui:Destroy() end)

local configCard = setRight:GroupCard()
configCard:SectionHeader("Configurations")
configCard:TextBox("Name", "", function(t) end, "config name")
configCard:Combo("Saved", {"None", "Legit", "Rage"}, 1, function(val) end)

configCard:ButtonRow({
    { text = "Save", callback = function() end },
    { text = "Load", callback = function() end },
    { text = "Delete", callback = function() end },
    { text = "Refresh", callback = function() end }
})

local aboutCard = setRight:GroupCard()
aboutCard:SectionHeader("About")
aboutCard:Text("Status")
aboutCard:TextDisabled("Hub is working.")
aboutCard:Text("Noic Hub")
aboutCard:Text("Executor: Bunni")
aboutCard:Button("Join our Discord", function() end)

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

    -- Check whose turn it is
    local engine = session:engineAt(#session.ucis)
    local isMyTurn = (session.myColor == 1 and engine.side == 1) or 
                     (session.myColor == -1 and engine.side == -1)
    
    if not isMyTurn then 
        stats.Status = "waiting..."
        if config.HintsEnabled and board then board:setArrow("best", nil) end
        return 
    end

    stats.Status = "thinking..."

    -- Run engine
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

    -- Autoplay
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
