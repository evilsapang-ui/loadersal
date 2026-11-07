-- 1. Load ImGui Module
local ImGuiURL = "https://raw.githubusercontent.com/evilsapang-ui/loadersal/main/imgui.lua?t=" .. tostring(os.time())
local libCode = game:HttpGet(ImGuiURL)

local libFunc, err = loadstring(libCode)
if not libFunc then
    error("Failed to compile ImGui: " .. tostring(err))
end

local success, returnedImGui = pcall(libFunc)
local ImGui
if success and returnedImGui then
    ImGui = returnedImGui
else
    error("ImGui module failed to return a table: " .. tostring(returnedImGui))
end

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- 2. Dynamic Executor Detection
local function getExecutor()
    local ok, name = pcall(function()
        if identifyexecutor then return identifyexecutor() end
        if getexecutorname then return getexecutorname() end
        return "Unknown"
    end)
    if ok and name then
        return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
    end
    return "Unknown"
end
local executorName = getExecutor()

-- 3. Game Hooks
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChessFolder = ReplicatedStorage:WaitForChild("Chess", 10)
if not ChessFolder then
    return warn("[NoiRoc] Could not find Chess folder. Are you in a RoChess game?")
end

local Engine = require(ChessFolder.Engine)
local Bot = require(ChessFolder.Bot)

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
    return warn("[NoiRoc] Could not find the game controller. Make sure you are in an active game.")
end

-- 4. State
local config = {
    AutoplayEnabled = false,
    HintsEnabled = false,
    DepthLimit = 22,
    ThinkTime = 2.5,
    MinDelay = 0.6,
    MaxDelay = 2.4,

    RainbowTopBar = false,
    Notifications = true,
    Animations = true,
    KeepOnScreen = true,
}

local stats = { Depth = 0, Nodes = 0, Time = 0.00, Status = "off" }
local running = true
local loading = false
local connections = {}
local fps = 60

-- Hint arrow helpers. The board is read from the controller every time,
-- because the game can build a new board for each game.
local HINT_COLOR = Color3.fromRGB(46, 196, 182)
local drawn = { board = nil, key = nil, at = 0 }

local function clearHint()
    if drawn.board then
        local b = drawn.board
        pcall(function() b:setArrow("best", nil) end)
    end
    drawn.board, drawn.key = nil, nil
end

local function setHint(move, now)
    local b = controller.board
    if not b then return end
    if drawn.board and drawn.board ~= b then clearHint() end
    -- only redraw when the move changed (or every 0.5s in case the game wiped the arrow)
    if drawn.key == move and drawn.board == b and now - drawn.at < 0.5 then return end
    local from = Engine.algToIndex64(string.sub(move, 1, 2))
    local to = Engine.algToIndex64(string.sub(move, 3, 4))
    local ok = pcall(function() b:setArrow("best", from, to, HINT_COLOR, 0.2) end)
    if ok then drawn.board, drawn.key, drawn.at = b, move, now end
end

-- Debug helper: prints every function name the game exposes on the controller, session and board.
-- Used to find how a live game submits a move (see the Hub tab button).
local function dumpApi()
    local function names(t, label)
        local out, seen = {}, {}
        local function collect(tbl)
            for k, v in pairs(tbl) do
                if type(v) == "function" and not seen[k] then
                    seen[k] = true
                    table.insert(out, tostring(k))
                end
            end
        end
        collect(t)
        local mt = getmetatable(t)
        if mt and type(mt.__index) == "table" then collect(mt.__index) end
        table.sort(out)
        print("[NoiRoc] " .. label .. ": " .. table.concat(out, ", "))
    end
    names(controller, "controller")
    local session = controller.session
    if session then
        print("[NoiRoc] session.kind = " .. tostring(session.kind) .. ", myColor = " .. tostring(session.myColor))
        names(session, "session")
    end
    if controller.board then names(controller.board, "board") end
end

-- 5. Languages
local LANG = {
    Spanish = {
        ["Play"] = "Jugar", ["Hub"] = "Hub", ["Settings"] = "Ajustes",
        ["Engine"] = "Motor", ["Timing"] = "Tiempos",
        ["Use with caution. Using max settings on a rookie account may get your account reported and banned."] =
            "Úsalo con precaución. Usar ajustes máximos en una cuenta nueva puede hacer que te reporten y baneen.",
        ["Hints (Board ESP)"] = "Pistas (ESP del tablero)",
        ["Shows the move on the board."] = "Muestra la jugada en el tablero.",
        ["Depth limit"] = "Límite de profundidad", ["Think time"] = "Tiempo de cálculo",
        ["Min delay"] = "Retardo mín.", ["Max delay"] = "Retardo máx.",
        ["Info"] = "Información", ["Unload"] = "Salir",
        ["Appearance"] = "Apariencia", ["Theme"] = "Tema",
        ["Rainbow top bar"] = "Barra superior arcoíris", ["Language"] = "Idioma",
        ["UI scale"] = "Escala de UI", ["Animations"] = "Animaciones",
        ["Interface"] = "Interfaz", ["Keep on screen"] = "Mantener en pantalla",
        ["The menu can't be dragged off the edge"] = "El menú no se puede arrastrar fuera del borde",
        ["Lock position"] = "Bloquear posición", ["Notifications"] = "Notificaciones",
        ["Info bar"] = "Barra de info", ["Center window"] = "Centrar ventana",
        ["Menu"] = "Menú", ["Menu key"] = "Tecla de menú",
        ["Configurations"] = "Configuraciones", ["Name"] = "Nombre",
        ["config name"] = "nombre de config", ["Saved"] = "Guardadas",
        ["Save"] = "Guardar", ["Load"] = "Cargar", ["Delete"] = "Eliminar", ["Refresh"] = "Actualizar",
        ["About"] = "Acerca de", ["Status"] = "Estado", ["Hub is working."] = "El hub funciona.",
        ["Join our Discord"] = "Únete a nuestro Discord", ["Executor"] = "Ejecutor",
        ["working"] = "funcionando", ["Depth"] = "Profundidad", ["nodes"] = "nodos",
        ["off"] = "apagado", ["no game"] = "sin partida", ["waiting..."] = "esperando...",
        ["thinking..."] = "pensando...", ["playing..."] = "jugando...",
        ["Engine enabled"] = "Motor activado", ["Engine disabled"] = "Motor desactivado",
        ["Hints enabled"] = "Pistas activadas", ["Hints disabled"] = "Pistas desactivadas",
        ["Config saved"] = "Config guardada", ["Config loaded"] = "Config cargada",
        ["Config deleted"] = "Config eliminada", ["Enter a config name"] = "Escribe un nombre de config",
        ["Config not found"] = "Config no encontrada", ["Files not supported"] = "El ejecutor no soporta archivos",
        ["Discord link copied"] = "Enlace de Discord copiado",
    },
    Russian = {
        ["Play"] = "Игра", ["Hub"] = "Хаб", ["Settings"] = "Настройки",
        ["Engine"] = "Движок", ["Timing"] = "Тайминг",
        ["Use with caution. Using max settings on a rookie account may get your account reported and banned."] =
            "Используйте осторожно. Максимальные настройки на новом аккаунте могут привести к жалобам и бану.",
        ["Hints (Board ESP)"] = "Подсказки (ESP доски)",
        ["Shows the move on the board."] = "Показывает ход на доске.",
        ["Depth limit"] = "Лимит глубины", ["Think time"] = "Время на ход",
        ["Min delay"] = "Мин. задержка", ["Max delay"] = "Макс. задержка",
        ["Info"] = "Инфо", ["Unload"] = "Выгрузить",
        ["Appearance"] = "Внешний вид", ["Theme"] = "Тема",
        ["Rainbow top bar"] = "Радужная панель", ["Language"] = "Язык",
        ["UI scale"] = "Масштаб UI", ["Animations"] = "Анимации",
        ["Interface"] = "Интерфейс", ["Keep on screen"] = "Не выходить за экран",
        ["The menu can't be dragged off the edge"] = "Меню нельзя вытащить за край",
        ["Lock position"] = "Закрепить позицию", ["Notifications"] = "Уведомления",
        ["Info bar"] = "Инфо-панель", ["Center window"] = "По центру",
        ["Menu"] = "Меню", ["Menu key"] = "Клавиша меню",
        ["Configurations"] = "Конфиги", ["Name"] = "Имя",
        ["config name"] = "имя конфига", ["Saved"] = "Сохранённые",
        ["Save"] = "Сохранить", ["Load"] = "Загрузить", ["Delete"] = "Удалить", ["Refresh"] = "Обновить",
        ["About"] = "О скрипте", ["Status"] = "Статус", ["Hub is working."] = "Хаб работает.",
        ["Join our Discord"] = "Наш Discord", ["Executor"] = "Эксплойт",
        ["working"] = "работает", ["Depth"] = "Глубина", ["nodes"] = "узлов",
        ["off"] = "выкл", ["no game"] = "нет игры", ["waiting..."] = "ожидание...",
        ["thinking..."] = "думаю...", ["playing..."] = "играю...",
        ["Engine enabled"] = "Движок включён", ["Engine disabled"] = "Движок выключен",
        ["Hints enabled"] = "Подсказки включены", ["Hints disabled"] = "Подсказки выключены",
        ["Config saved"] = "Конфиг сохранён", ["Config loaded"] = "Конфиг загружен",
        ["Config deleted"] = "Конфиг удалён", ["Enter a config name"] = "Введите имя конфига",
        ["Config not found"] = "Конфиг не найден", ["Files not supported"] = "Файлы не поддерживаются",
        ["Discord link copied"] = "Ссылка Discord скопирована",
    },
}
LANG.Spanish[executorName .. " is untested. Continue anyway."] = executorName .. " no está probado. Continúa de todos modos."
LANG.Russian[executorName .. " is untested. Continue anyway."] = executorName .. " не проверен. Всё равно продолжить."

local currentLang = "English"

local function tr(s)
    local d = LANG[currentLang]
    return (d and d[s]) or s
end

local function translateText(orig)
    local d = LANG[currentLang]
    if not d then return orig end
    if d[orig] then return d[orig] end
    local prefix, rest = orig:match("^(.-): (.+)$")
    if prefix and d[prefix] then return d[prefix] .. ": " .. rest end
    return orig
end

-- 6. Build the UI
local screenGui = ImGui.Init({})
local win = ImGui.Window("RoChess NoiRoc", { Position = UDim2.fromOffset(100, 100), Width = 650 })

local uiScale = Instance.new("UIScale")
uiScale.Scale = 1
uiScale.Parent = win.Root

-- Notifications (toasts)
local toastHolder = Instance.new("Frame")
toastHolder.BackgroundTransparency = 1
toastHolder.AnchorPoint = Vector2.new(1, 1)
toastHolder.Position = UDim2.new(1, -12, 1, -12)
toastHolder.Size = UDim2.fromOffset(260, 0)
toastHolder.AutomaticSize = Enum.AutomaticSize.Y
toastHolder.Parent = screenGui
do
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 4)
    l.VerticalAlignment = Enum.VerticalAlignment.Bottom
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = toastHolder
end

local function notify(text)
    if not config.Notifications or loading or not running then return end
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 0, 24)
    t.BackgroundColor3 = ImGui.Theme.TitleBgActive[1]
    t.BorderSizePixel = 0
    t.Font = Enum.Font.Code
    t.TextSize = 14
    t.TextColor3 = ImGui.Theme.Text
    t.Text = text
    t.Parent = toastHolder
    local stroke = Instance.new("UIStroke")
    stroke.Color = ImGui.Theme.Border
    stroke.Transparency = 0.5
    stroke.Parent = t
    task.delay(3, function()
        if not t.Parent then return end
        if config.Animations then
            local info = TweenInfo.new(0.3)
            TweenService:Create(t, info, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
            TweenService:Create(stroke, info, { Transparency = 1 }):Play()
            task.wait(0.3)
        end
        t:Destroy()
    end)
end

local W = {} -- widgets that are saved in configs
local function reg(name, kind, h, items)
    W[name] = { kind = kind, h = h, items = items }
    return h
end

local badge = win:TextColored("working", Color3.fromRGB(150, 255, 150))

local tabs = win:SidebarTabs({"Play", "Hub", "Settings"}, 90)

-- ==========================================
-- PLAY TAB
-- ==========================================
local cols = tabs.Play:Columns(2)
local left, right = cols[1], cols[2]

left:Section("Engine")
reg("Engine", "bool", left:Checkbox("Engine", false, function(v)
    config.AutoplayEnabled = v
    notify(tr(v and "Engine enabled" or "Engine disabled"))
end))
left:SubText("Use with caution. Using max settings on a rookie account may get your account reported and banned.")

reg("Hints", "bool", left:Checkbox("Hints (Board ESP)", false, function(v)
    config.HintsEnabled = v
    if not v then clearHint() end
    notify(tr(v and "Hints enabled" or "Hints disabled"))
end))
left:SubText("Shows the move on the board.")

reg("DepthLimit", "num", left:SliderInt("Depth limit", 1, 30, 22, function(v) config.DepthLimit = v end))
reg("ThinkTime", "num", left:Slider("Think time", 0.1, 10, 2.5, function(v) config.ThinkTime = v end))

local statLabel = left:TextDisabled("Depth 0 | 0.0k nodes | 0.00s")
local statusLabel = left:TextDisabled("Status: off")

right:Section("Timing")
reg("MinDelay", "num", right:Slider("Min delay", 0.1, 5, 0.6, function(v) config.MinDelay = v end))
reg("MaxDelay", "num", right:Slider("Max delay", 0.1, 10, 2.4, function(v) config.MaxDelay = v end))

-- ==========================================
-- HUB TAB
-- ==========================================
local hubCols = tabs.Hub:Columns(2)
local hubLeft = hubCols[1]

hubLeft:Section("Info")
hubLeft:Text("Executor: " .. executorName)
local hubKeyText = hubLeft:Text("Menu key: RightShift")
hubLeft:Text("Discord: https://discord.gg/UBeRG8Qp2f")
hubLeft:Text(executorName .. " is untested. Continue anyway.")
hubLeft:Button("Print game API (debug)", dumpApi)

local function unload()
    running = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    clearHint()
    if screenGui then screenGui:Destroy() end
end
hubLeft:Button("Unload", unload)

-- ==========================================
-- SETTINGS TAB
-- ==========================================
local setCols = tabs.Settings:Columns(2)
local setLeft, setRight = setCols[1], setCols[2]

local infoBar -- created at the bottom, referenced by the settings below
local applyLanguage

setLeft:Section("Appearance")

local themeNames = {"Blue", "Red", "Green", "Maroon", "Purple", "Pink", "Mint", "Navy"}
reg("Theme", "drop", setLeft:Dropdown("Theme", themeNames, 1, function(val)
    ImGui.SetTheme(val)
end), themeNames)

reg("RainbowTopBar", "bool", setLeft:Checkbox("Rainbow top bar", false, function(v)
    config.RainbowTopBar = v
    if not v then
        win.TitleBar.BackgroundColor3 = ImGui.Theme.TitleBgActive[1]
    end
end))

local langNames = {"English", "Spanish", "Russian"}
reg("Language", "drop", setLeft:Dropdown("Language", langNames, 1, function(val)
    currentLang = val
    applyLanguage()
end), langNames)

reg("UIScale", "num", setLeft:Slider("UI scale", 0.5, 1.5, 1, function(v)
    if config.Animations then
        TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { Scale = v }):Play()
    else
        uiScale.Scale = v
    end
end))

reg("Animations", "bool", setLeft:Checkbox("Animations", true, function(v) config.Animations = v end))

setLeft:Section("Interface")
reg("KeepOnScreen", "bool", setLeft:Checkbox("Keep on screen", true, function(v) config.KeepOnScreen = v end))
setLeft:SubText("The menu can't be dragged off the edge", 0)
reg("LockPosition", "bool", setLeft:Checkbox("Lock position", false, function(v) win.Locked = v end))
reg("Notifications", "bool", setLeft:Checkbox("Notifications", true, function(v) config.Notifications = v end))
reg("InfoBar", "bool", setLeft:Checkbox("Info bar", true, function(v)
    if infoBar then infoBar.Instance.Visible = v end
end))

local function moveWindowTo(x, y)
    local root = win.Root
    local abs = root.AbsolutePosition
    local pos = root.Position
    local target = UDim2.new(pos.X.Scale, pos.X.Offset + (x - abs.X), pos.Y.Scale, pos.Y.Offset + (y - abs.Y))
    if config.Animations then
        TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = target }):Play()
    else
        root.Position = target
    end
end

setLeft:Button("Center window", function()
    local vp = screenGui.AbsoluteSize
    local size = win.Root.AbsoluteSize
    moveWindowTo((vp.X - size.X) / 2, (vp.Y - size.Y) / 2)
end)

-- Right column
setRight:Section("Menu")

local menuKeyH
local function refreshMenuText()
    local k = menuKeyH and menuKeyH:Get()
    hubKeyText:Set(tr("Menu key") .. ": " .. (k and k.Name or "None"))
end

menuKeyH = reg("MenuKey", "key", setRight:Keybind("Menu key", Enum.KeyCode.RightShift,
    function() screenGui.Enabled = not screenGui.Enabled end,
    function(k)
        if k == nil then menuKeyH:Set(Enum.KeyCode.RightShift, true) end -- never leave the menu without a key
        refreshMenuText()
    end))
setRight:Button("Unload", unload)

-- Configurations
setRight:Section("Configurations")
local nameBox = setRight:InputText("Name", "", nil, "config name")
local savedDrop
savedDrop = setRight:Dropdown("Saved", {"None"}, 1, function(val)
    if val and val ~= "None" then nameBox:Set(val) end
end)

local FOLDER = "NoiRoc/configs"
local hasFS = type(writefile) == "function" and type(readfile) == "function"
    and type(isfolder) == "function" and type(makefolder) == "function" and type(listfiles) == "function"

local function ensureFolder()
    pcall(function()
        if not isfolder("NoiRoc") then makefolder("NoiRoc") end
        if not isfolder(FOLDER) then makefolder(FOLDER) end
    end)
end

local function listConfigs()
    local names = {}
    if not hasFS then return names end
    ensureFolder()
    pcall(function()
        for _, path in ipairs(listfiles(FOLDER)) do
            local n = path:match("([^/\\]+)%.json$")
            if n then table.insert(names, n) end
        end
    end)
    table.sort(names)
    return names
end

local function refreshConfigs()
    local names = listConfigs()
    if #names == 0 then names = {"None"} end
    savedDrop:SetItems(names, true)
end

local function currentConfigName()
    local n = nameBox:Get() or ""
    n = n:gsub("[^%w_%- ]", "")
    n = n:gsub("^%s+", "")
    n = n:gsub("%s+$", "")
    if n == "" then
        local sel = savedDrop:Get()
        if sel and sel ~= "None" then n = sel end
    end
    return n
end

local function collectConfig()
    local data = {}
    for name, e in pairs(W) do
        if e.kind == "drop" then
            data[name] = (e.h:Get())
        elseif e.kind == "key" then
            local k = e.h:Get()
            if k then data[name] = k.Name end
        else
            data[name] = e.h:Get()
        end
    end
    return data
end

local function applyConfig(data)
    loading = true
    for name, e in pairs(W) do
        local v = data[name]
        if v ~= nil then
            if e.kind == "drop" then
                for i, item in ipairs(e.items) do
                    if item == v then e.h:Set(i) break end
                end
            elseif e.kind == "key" then
                local ok, kc = pcall(function() return Enum.KeyCode[v] end)
                if ok and kc then e.h:Set(kc) end
            else
                e.h:Set(v)
            end
        end
    end
    loading = false
end

setRight:ButtonGroup(2, {
    {"Save", function()
        if not hasFS then return notify(tr("Files not supported")) end
        local n = currentConfigName()
        if n == "" then return notify(tr("Enter a config name")) end
        ensureFolder()
        local ok = pcall(function()
            writefile(FOLDER .. "/" .. n .. ".json", HttpService:JSONEncode(collectConfig()))
        end)
        if ok then
            refreshConfigs()
            notify(tr("Config saved") .. ": " .. n)
        end
    end},
    {"Load", function()
        if not hasFS then return notify(tr("Files not supported")) end
        local n = currentConfigName()
        if n == "" then return notify(tr("Enter a config name")) end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(FOLDER .. "/" .. n .. ".json"))
        end)
        if ok and type(data) == "table" then
            applyConfig(data)
            notify(tr("Config loaded") .. ": " .. n)
        else
            notify(tr("Config not found"))
        end
    end},
    {"Delete", function()
        if not hasFS or type(delfile) ~= "function" then return notify(tr("Files not supported")) end
        local n = currentConfigName()
        if n == "" then return notify(tr("Enter a config name")) end
        local ok = pcall(function() delfile(FOLDER .. "/" .. n .. ".json") end)
        refreshConfigs()
        notify(ok and (tr("Config deleted") .. ": " .. n) or tr("Config not found"))
    end},
    {"Refresh", function() refreshConfigs() end},
})
refreshConfigs()

setRight:Section("About")
setRight:Text("Status")
setRight:SubText("Hub is working.", 0)
setRight:Text("NoiRoc")
setRight:Text("Executor: " .. executorName)
setRight:Button("Join our Discord", function()
    if type(setclipboard) == "function" then
        setclipboard("https://discord.gg/UBeRG8Qp2f")
        notify(tr("Discord link copied"))
    end
end)

-- Info bar
infoBar = win:InfoBar("v1.0.0 | Executor: " .. executorName, "FPS: 60 | Ping: 0ms")

-- Anything the script rewrites by itself must be skipped by the language walker
for _, inst in ipairs({ statLabel.Instance, statusLabel.Instance, hubKeyText.Instance }) do
    inst:SetAttribute("NoTranslate", true)
end
for _, c in ipairs(infoBar.Instance:GetChildren()) do
    if c:IsA("TextLabel") then c:SetAttribute("NoTranslate", true) end
end

-- Language: retranslate every label in the UI
function applyLanguage()
    local font = (currentLang == "Russian") and Enum.Font.SourceSans or Enum.Font.Code
    for _, d in ipairs(screenGui:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            d.Font = font
            if d:IsA("TextBox") then
                local oph = d:GetAttribute("origPH") or d.PlaceholderText
                d:SetAttribute("origPH", oph)
                d.PlaceholderText = translateText(oph)
            elseif not d:GetAttribute("NoTranslate") then
                local orig = d:GetAttribute("orig")
                if orig == nil or d.Text ~= d:GetAttribute("applied") then
                    orig = d.Text
                    d:SetAttribute("orig", orig)
                end
                local new = translateText(orig)
                d.Text = new
                d:SetAttribute("applied", new)
            end
        end
    end
    refreshMenuText()
end

refreshMenuText()
notify("NoiRoc " .. "loaded")

-- 7. Main Logic Loop
local hue = 0

local function keepOnScreen()
    if not config.KeepOnScreen or not screenGui.Enabled then return end
    local root = win.Root
    local vp = screenGui.AbsoluteSize
    local abs, size = root.AbsolutePosition, root.AbsoluteSize
    local x = math.clamp(abs.X, 0, math.max(vp.X - size.X, 0))
    local y = math.clamp(abs.Y, 0, math.max(vp.Y - size.Y, 0))
    if math.abs(x - abs.X) > 0.5 or math.abs(y - abs.Y) > 0.5 then
        local p = root.Position
        root.Position = UDim2.new(p.X.Scale, p.X.Offset + (x - abs.X), p.Y.Scale, p.Y.Offset + (y - abs.Y))
    end
end

-- One state table drives both hints and autoplay:
--   best     = best move for the current position (nil until calculated)
--   moveAt   = when autoplay is allowed to play it
--   playedFen/playedAt = stops the same move being sent every frame (retries after 2s if it didn't go through)
local S = {
    session = nil, fen = nil, best = nil, thinking = false,
    failedFen = nil, moveAt = nil, playedFen = nil, playedAt = 0,
}

local function resetState()
    S.session, S.fen, S.best = nil, nil, nil
    S.failedFen, S.moveAt, S.playedFen = nil, nil, nil
end

-- Runs the game's own search directly (Bot.Search) instead of Bot.think.
-- The search yields every few ms (task.wait inside Search:checkTime), so it never freezes the game.
-- Going direct also skips the opening-book dice roll and the Bot.onSearch hook that Bot.think fires.
local function runSearch(session, fen)
    local eng = Bot.buildEngine(session.startFen or Engine.START_FEN, table.clone(session.ucis))
    if eng:status() ~= "ongoing" then return nil end -- finished game: nothing to search
    local search = Bot.Search.new(eng)
    -- the search checks this between slices, so an old search stops as soon as it's pointless
    search.cancelled = function()
        return not running or S.session ~= session or S.fen ~= fen
    end
    local t0 = os.clock()
    local best, score, depth = search:run(config.DepthLimit, config.ThinkTime)
    if not best or best == 0 then return nil end
    return eng:moveToUci(best), {
        score = score, depth = depth, nodes = search.nodes, time = os.clock() - t0,
    }
end

local function startThink(session, fen)
    S.thinking = true
    task.spawn(function()
        local ok, move, info = pcall(runSearch, session, fen)
        S.thinking = false

        if not running or S.session ~= session or S.fen ~= fen then return end -- position changed while thinking
        if ok and move then
            stats.Depth = info.depth or 0
            stats.Nodes = info.nodes or 0
            stats.Time = info.time or 0
            S.best = move
        else
            if not ok then warn("[NoiRoc] search error: " .. tostring(move)) end
            S.failedFen = fen -- don't retry the same position every frame
        end
    end)
end

local function stepChess()
    local session = controller.session
    if not session or session.kind == "analysis" then
        stats.Status = "no game"
        clearHint()
        resetState()
        return
    end
    if S.session ~= session then -- new game
        clearHint()
        resetState()
        S.session = session
    end

    local engine = session:engineAt(#session.ucis)
    local isMyTurn = session.myColor ~= nil and session.myColor == engine.side
    if not isMyTurn then
        stats.Status = "waiting..."
        clearHint()
        S.fen, S.best, S.moveAt = nil, nil, nil
        return
    end

    local fen = engine:getFen()
    if S.fen ~= fen then -- new position on my turn
        S.fen, S.best, S.failedFen, S.moveAt = fen, nil, nil, nil
        clearHint()
    end

    local now = os.clock()
    local wantMove = config.HintsEnabled or config.AutoplayEnabled
    if not wantMove then
        stats.Status = "off"
        clearHint()
        return
    end

    -- calculate once per position, as soon as hints or autoplay is on
    if S.best == nil and not S.thinking and S.failedFen ~= fen then
        startThink(session, fen)
    end
    if S.thinking then stats.Status = "thinking..." end

    -- hints
    if config.HintsEnabled and S.best then
        setHint(S.best, now)
    else
        clearHint()
    end

    -- autoplay
    if config.AutoplayEnabled and S.best then
        stats.Status = "playing..."
        if S.playedFen == fen and now - S.playedAt < 2 then return end
        if not S.moveAt then
            local lo = math.floor(math.min(config.MinDelay, config.MaxDelay) * 100)
            local hi = math.floor(math.max(config.MinDelay, config.MaxDelay) * 100)
            S.moveAt = now + math.random(lo, hi) / 100
        end
        if now >= S.moveAt then
            local ok, res = pcall(session.applyUci, session, S.best)
            if (not ok or not res) and not S.applyWarned then
                S.applyWarned = true
                warn("[NoiRoc] applyUci returned " .. tostring(res) .. " for " .. tostring(S.best))
            end
            S.playedFen, S.playedAt, S.moveAt = fen, now, nil
        end
    else
        S.moveAt = nil
    end
end

local warned = false
table.insert(connections, RunService.RenderStepped:Connect(function(dt)
    if not running then return end

    fps = fps + ((1 / math.max(dt, 1e-4)) - fps) * 0.05

    -- UI features
    keepOnScreen()
    if config.RainbowTopBar then
        hue = (hue + dt * 0.3) % 1
        win.TitleBar.BackgroundColor3 = Color3.fromHSV(hue, 0.8, 0.9)
    end

    -- Chess logic (a failure here must never kill the UI loop)
    local ok, e = pcall(stepChess)
    if not ok and not warned then
        warned = true
        warn("[NoiRoc] chess loop error: " .. tostring(e))
    end
end))

-- 8. UI Updater
task.spawn(function()
    while running do
        task.wait(0.1)
        if not running then break end
        statLabel:Set(string.format("%s %d | %.1fk %s | %.2fs",
            tr("Depth"), stats.Depth, stats.Nodes / 1000, tr("nodes"), stats.Time))
        statusLabel:Set(tr("Status") .. ": " .. tr(stats.Status))

        local ping = 0
        pcall(function()
            ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        infoBar:Set(
            "v1.0.0 | " .. tr("Executor") .. ": " .. executorName,
            string.format("FPS: %d | %s: %dms", math.floor(fps + 0.5), tr("Ping"), ping)
        )
    end
end)
