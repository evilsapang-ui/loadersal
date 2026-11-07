local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local ImGui = {}
local Container = {}
Container.__index = Container

local function C(r, g, b) return Color3.fromRGB(r, g, b) end

local Theme = {
	Text            = C(255, 255, 255),
	TextDisabled    = C(128, 128, 128),
	WindowBg        = { C(15, 15, 15),    0.06 },
	TitleBg         = { C(10, 10, 10),    0 },
	TitleBgActive   = { C(41, 74, 122),   0 },
	Border          = C(110, 110, 128),
	FrameBg         = { C(41, 74, 122),   0.46 },
	FrameBgHovered  = { C(66, 150, 250),  0.60 },
	FrameBgActive   = { C(66, 150, 250),  0.33 },
	Button          = { C(66, 150, 250),  0.60 },
	ButtonHovered   = { C(66, 150, 250),  0.00 },
	ButtonActive    = { C(15, 135, 250),  0.00 },
	Header          = { C(66, 150, 250),  0.69 },
	HeaderHovered   = { C(66, 150, 250),  0.20 },
	HeaderActive    = { C(66, 150, 250),  0.00 },
	CheckMark       = C(66, 150, 250),
	SliderGrab      = C(61, 133, 224),
	SliderGrabActive= C(66, 150, 250),
	Separator       = C(110, 110, 128),
	PlotFill        = C(230, 179, 0),
}
ImGui.Theme = Theme

local FONT = Enum.Font.Code
local FONT_SIZE = 14
local ITEM_H = 20
local LABEL_W = 100 

local function paint(inst, t)
	inst.BackgroundColor3 = t[1]
	inst.BackgroundTransparency = t[2]
end

local function make(class, props, parent)
	local inst = Instance.new(class)
	
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		inst.Font = FONT
		inst.TextSize = FONT_SIZE
		inst.TextColor3 = Theme.Text
		inst.BackgroundTransparency = 1
	end
	if props then
		for k, v in pairs(props) do inst[k] = v end
	end
	inst.Parent = parent
	return inst
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch
end

local function interactive(listener, target, normal, hover, active)
	local over, down = false, false
	local function refresh()
		paint(target, (down and active) or (over and hover) or normal)
	end
	refresh()
	listener.MouseEnter:Connect(function() over = true refresh() end)
	listener.MouseLeave:Connect(function() over = false down = false refresh() end)
	listener.InputBegan:Connect(function(i) if isPress(i) then down = true refresh() end end)
	listener.InputEnded:Connect(function(i) if isPress(i) then down = false refresh() end end)
	return refresh
end

local function newContainer(parent, props)
	local f = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, parent)
	if props then for k, v in pairs(props) do f[k] = v end end
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	return setmetatable({ Frame = f, _n = 0 }, Container)
end

function Container:_order()
	self._n += 1
	return self._n
end

local function row(self, height)
	return make("Frame", {
		Size = UDim2.new(1, 0, 0, height or ITEM_H),
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
end

local function sideLabel(parent, text)
	return make("TextLabel", {
		Text = text,
		Size = UDim2.new(0, LABEL_W - 6, 1, 0),
		Position = UDim2.new(1, -(LABEL_W - 6), 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

function Container:Text(text)
	local l = make("TextLabel", {
		Text = text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = self:_order(),
	}, self.Frame)
	return { Set = function(_, t) l.Text = t end, Get = function() return l.Text end, Instance = l }
end

function Container:TextColored(text, color)
	local h = self:Text(text)
	h.Instance.TextColor3 = color
	return h
end

function Container:TextDisabled(text)
	return self:TextColored(text, Theme.TextDisabled)
end

function Container:Spacing(px)
	make("Frame", {
		Size = UDim2.new(1, 0, 0, px or 4),
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
end

function Container:Separator()
	make("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Separator,
		BackgroundTransparency = 0.5,
		LayoutOrder = self:_order(),
	}, self.Frame)
end

function Container:Button(text, callback)
	local b = make("TextButton", {
		Text = text,
		Size = UDim2.new(1, 0, 0, ITEM_H),
		AutoButtonColor = false,
		LayoutOrder = self:_order(),
	}, self.Frame)
	interactive(b, b, Theme.Button, Theme.ButtonHovered, Theme.ButtonActive)
	b.MouseButton1Click:Connect(function() if callback then callback() end end)
	return { SetText = function(_, t) b.Text = t end, Instance = b }
end

function Container:Checkbox(label, default, callback)
	local value = default and true or false
	local r = make("TextButton", {
		Text = "",
		Size = UDim2.new(1, 0, 0, ITEM_H),
		AutoButtonColor = false,
		LayoutOrder = self:_order(),
	}, self.Frame)
	local box = make("Frame", { Size = UDim2.fromOffset(ITEM_H, ITEM_H) }, r)
	local mark = make("Frame", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.CheckMark,
		Visible = value,
	}, box)
	interactive(r, box, Theme.FrameBg, Theme.FrameBgHovered, Theme.FrameBgActive)
	make("TextLabel", {
		Text = label,
		Size = UDim2.new(1, -(ITEM_H + 6), 1, 0),
		Position = UDim2.fromOffset(ITEM_H + 6, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)

	local h = {}
	function h:Set(v, silent)
		value = v and true or false
		mark.Visible = value
		if callback and not silent then callback(value) end
	end
	function h:Get() return value end
	r.MouseButton1Click:Connect(function() h:Set(not value) end)
	return h
end

local function sliderImpl(self, label, min, max, default, callback, isInt)
	local value = default or min
	local r = row(self)
	local bar = make("Frame", { Size = UDim2.new(1, -LABEL_W, 1, 0) }, r)
	interactive(bar, bar, Theme.FrameBg, Theme.FrameBgHovered, Theme.FrameBgActive)
	local grab = make("Frame", {
		Size = UDim2.new(0, 10, 1, -4),
		BackgroundColor3 = Theme.SliderGrab,
	}, bar)
	local valLabel = make("TextLabel", { Size = UDim2.fromScale(1, 1), ZIndex = 2 }, bar)
	sideLabel(r, label)

	local h = {}
	local function render()
		local a = (max == min) and 0 or (value - min) / (max - min)
		grab.Position = UDim2.new(a, -a * 10, 0, 2)
		valLabel.Text = isInt and tostring(value) or string.format("%.2f", value)
	end
	function h:Set(v, silent)
		v = math.clamp(v, min, max)
		if isInt then v = math.floor(v + 0.5) else v = math.floor(v * 100 + 0.5) / 100 end
		local changed = v ~= value
		value = v
		render()
		if changed and callback and not silent then callback(value) end
	end
	function h:Get() return value end
	render()

	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
		h:Set(min + (max - min) * a)
	end
	bar.InputBegan:Connect(function(i)
		if isPress(i) then
			dragging = true
			grab.BackgroundColor3 = Theme.SliderGrabActive
			fromX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch) then
			fromX(i.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and isPress(i) then
			dragging = false
			grab.BackgroundColor3 = Theme.SliderGrab
		end
	end)
	return h
end

function Container:Slider(label, min, max, default, callback)
	return sliderImpl(self, label, min, max, default, callback, false)
end
function Container:SliderInt(label, min, max, default, callback)
	return sliderImpl(self, label, min, max, default, callback, true)
end

function Container:InputText(label, default, callback, placeholder)
	local r = row(self)
	local frame = make("Frame", { Size = UDim2.new(1, -LABEL_W, 1, 0) }, r)
	paint(frame, Theme.FrameBg)
	local box = make("TextBox", {
		Text = default or "",
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = Theme.TextDisabled,
		Size = UDim2.new(1, -8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
	}, frame)
	box.Focused:Connect(function() paint(frame, Theme.FrameBgActive) end)
	box.FocusLost:Connect(function(enter)
		paint(frame, Theme.FrameBg)
		if callback then callback(box.Text, enter) end
	end)
	sideLabel(r, label)
	return {
		Set = function(_, t) box.Text = t end,
		Get = function() return box.Text end,
		Instance = box,
	}
end

function Container:Combo(label, items, defaultIndex, callback)
	local index = defaultIndex or 1
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, holder)

	local r = make("Frame", {
		Size = UDim2.new(1, 0, 0, ITEM_H),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, holder)
	local main = make("TextButton", {
		Text = "",
		Size = UDim2.new(1, -LABEL_W, 1, 0),
		AutoButtonColor = false,
	}, r)
	interactive(main, main, Theme.FrameBg, Theme.FrameBgHovered, Theme.FrameBgActive)
	local cur = make("TextLabel", {
		Size = UDim2.new(1, -ITEM_H - 4, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, main)
	local arrowBox = make("Frame", {
		Size = UDim2.fromOffset(ITEM_H, ITEM_H),
		Position = UDim2.new(1, -ITEM_H, 0, 0),
	}, main)
	paint(arrowBox, Theme.Button)
	make("TextLabel", { Text = "v", Size = UDim2.fromScale(1, 1) }, arrowBox)
	sideLabel(r, label)

	local list = make("Frame", {
		Size = UDim2.new(1, -LABEL_W, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 2,
	}, holder)
	paint(list, { C(20, 20, 20), 0 })
	make("UIStroke", { Color = Theme.Border, Transparency = 0.5 }, list)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local h = {}
	local buttons = {}
	local function refresh()
		cur.Text = tostring(items[index] or "")
		for i, b in ipairs(buttons) do
			b.BackgroundTransparency = (i == index) and Theme.Header[2] or 1
			b.BackgroundColor3 = Theme.Header[1]
		end
	end
	for i, item in ipairs(items) do
		local b = make("TextButton", {
			Text = "  " .. tostring(item),
			Size = UDim2.new(1, 0, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			LayoutOrder = i,
		}, list)
		b.MouseEnter:Connect(function() paint(b, Theme.HeaderHovered) end)
		b.MouseLeave:Connect(function() refresh() end)
		b.MouseButton1Click:Connect(function()
			h:Set(i)
			list.Visible = false
		end)
		buttons[i] = b
	end
	function h:Set(i, silent)
		index = math.clamp(i, 1, #items)
		refresh()
		if callback and not silent then callback(items[index], index) end
	end
	function h:Get() return items[index], index end
	main.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
	refresh()
	return h
end

function Container:ProgressBar(alpha, overlay)
	alpha = alpha or 0
	local r = row(self)
	paint(r, Theme.FrameBg)
	r.BackgroundTransparency = Theme.FrameBg[2]
	local fill = make("Frame", {
		Size = UDim2.new(alpha, 0, 1, 0),
		BackgroundColor3 = Theme.PlotFill,
	}, r)
	local t = make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Text = overlay or string.format("%d%%", alpha * 100),
		ZIndex = 2,
	}, r)
	return {
		Set = function(_, a, text)
			a = math.clamp(a, 0, 1)
			fill.Size = UDim2.new(a, 0, 1, 0)
			t.Text = text or string.format("%d%%", a * 100)
		end,
	}
end

function Container:CollapsingHeader(label, open)
	local isOpen = open and true or false
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, holder)

	local hdr = make("TextButton", {
		Text = "",
		Size = UDim2.new(1, 0, 0, ITEM_H),
		AutoButtonColor = false,
		LayoutOrder = 1,
	}, holder)
	interactive(hdr, hdr, Theme.Header, Theme.HeaderHovered, Theme.HeaderActive)
	local arrow = make("TextLabel", {
		Size = UDim2.fromOffset(ITEM_H, ITEM_H),
		Text = isOpen and "v" or ">",
	}, hdr)
	make("TextLabel", {
		Text = label,
		Size = UDim2.new(1, -ITEM_H, 1, 0),
		Position = UDim2.fromOffset(ITEM_H, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, hdr)

	local body = newContainer(holder, { LayoutOrder = 2, Visible = isOpen })
	make("UIPadding", { PaddingLeft = UDim.new(0, 8) }, body.Frame)
	hdr.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		body.Frame.Visible = isOpen
		arrow.Text = isOpen and "v" or ">"
	end)
	return body
end

function Container:Tabs(names)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, holder)

	local bar = make("Frame", {
		Size = UDim2.new(1, 0, 0, ITEM_H),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, holder)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, bar)

	local pages, btns, result = {}, {}, {}
	local function select(name)
		for n, p in pairs(pages) do
			p.Frame.Visible = (n == name)
			paint(btns[n], n == name and Theme.HeaderActive or Theme.Header)
			btns[n].BackgroundTransparency = (n == name) and 0.2 or 0.69
		end
	end
	for i, name in ipairs(names) do
		local b = make("TextButton", {
			Text = name,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			AutoButtonColor = false,
			LayoutOrder = i,
		}, bar)
		make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
		b.BackgroundTransparency = 0
		btns[name] = b
		pages[name] = newContainer(holder, { LayoutOrder = 2, Visible = false })
		result[name] = pages[name]
		b.MouseButton1Click:Connect(function() select(name) end)
	end
	select(names[1])
	result.Select = function(_, n) select(n) end
	return result
end

------------------------------------------------------------------ KEYBIND
local KEY_SHORT = {
	RightShift = "RSHIFT", LeftShift = "LSHIFT",
	RightControl = "RCTRL", LeftControl = "LCTRL",
	RightAlt = "RALT", LeftAlt = "LALT",
	Return = "ENTER", Backspace = "BKSP", Escape = "ESC",
	Insert = "INS", Delete = "DEL", PageUp = "PGUP", PageDown = "PGDN",
	CapsLock = "CAPS", Space = "SPACE",
}

local function keyName(key)
	if not key then return "NONE" end
	return KEY_SHORT[key.Name] or string.upper(key.Name)
end

-- callback(key)        -> fires when the bound key is pressed
-- onChanged(key)       -> fires when the user rebinds (key is nil when cleared)
function Container:Keybind(label, default, callback, onChanged)
	local key = default
	local listening = false

	local r = row(self)
	local btn = make("TextButton", {
		Text = "",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
	}, r)

	make("TextLabel", {
		Text = label,
		Size = UDim2.new(1, -90, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, btn)

	local val = make("TextLabel", {
		Size = UDim2.new(0, 90, 1, 0),
		Position = UDim2.new(1, -90, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	}, btn)

	local hovered = false
	local function render()
		if listening then
			val.Text = "[...]"
			val.TextColor3 = Theme.CheckMark
		else
			val.Text = "[" .. keyName(key) .. "]"
			val.TextColor3 = hovered and Theme.Text or Theme.TextDisabled
		end
	end
	render()

	btn.MouseEnter:Connect(function() hovered = true render() end)
	btn.MouseLeave:Connect(function() hovered = false render() end)
	btn.MouseButton1Click:Connect(function()
		listening = true
		render()
	end)

	local h = {}
	function h:Set(k, silent)
		key = k
		listening = false
		render()
		if onChanged and not silent then onChanged(key) end
	end
	function h:Get() return key end
	function h:IsDown() return key ~= nil and UIS:IsKeyDown(key) end

	local conn = UIS.InputBegan:Connect(function(i, processed)
		if i.UserInputType ~= Enum.UserInputType.Keyboard then return end

		if listening then
			-- Escape / Backspace clear the bind
			if i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace then
				h:Set(nil)
			else
				h:Set(i.KeyCode)
			end
			return
		end

		if not processed and key and i.KeyCode == key and callback then
			callback(key)
		end
	end)
	r.Destroying:Connect(function() conn:Disconnect() end)

	return h
end

------------------------------------------------------------------ TEXTBOX (label on top)
-- opts: { Live = true } fires callback on every keystroke instead of on focus lost
function Container:TextBox(label, default, callback, placeholder, opts)
	opts = opts or {}

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, holder)

	if label and label ~= "" then
		make("TextLabel", {
			Text = label,
			Size = UDim2.new(1, 0, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}, holder)
	end

	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, ITEM_H),
		LayoutOrder = 2,
	}, holder)
	paint(frame, Theme.FrameBg)

	local box = make("TextBox", {
		Text = default or "",
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = Theme.TextDisabled,
		Size = UDim2.new(1, -8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ClipsDescendants = true,
	}, frame)

	local focused = false
	box.MouseEnter:Connect(function() if not focused then paint(frame, Theme.FrameBgHovered) end end)
	box.MouseLeave:Connect(function() if not focused then paint(frame, Theme.FrameBg) end end)
	box.Focused:Connect(function() focused = true paint(frame, Theme.FrameBgActive) end)
	box.FocusLost:Connect(function(enter)
		focused = false
		paint(frame, Theme.FrameBg)
		if not opts.Live and callback then callback(box.Text, enter) end
	end)
	if opts.Live then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if callback then callback(box.Text) end
		end)
	end

	return {
		Set = function(_, t) box.Text = t end,
		Get = function() return box.Text end,
		Instance = box,
	}
end

------------------------------------------------------------------ SECTION HEADER  ( | Engine )
function Container:Section(title)
	local r = row(self, 18)
	make("Frame", {
		Size = UDim2.new(0, 2, 1, -4),
		Position = UDim2.fromOffset(0, 2),
		BackgroundColor3 = Theme.CheckMark,
	}, r)
	make("TextLabel", {
		Text = title,
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)
	return r
end

------------------------------------------------------------------ SUB TEXT (gray, wrapped, indented under checkbox)
function Container:SubText(text, indent)
	local l = make("TextLabel", {
		Text = text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextSize = FONT_SIZE - 2,
		TextColor3 = Theme.TextDisabled,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIPadding", { PaddingLeft = UDim.new(0, indent == nil and (ITEM_H + 6) or indent) }, l)
	return { Set = function(_, t) l.Text = t end, Get = function() return l.Text end, Instance = l }
end

------------------------------------------------------------------ COLUMNS
-- local cols = parent:Columns(2); cols[1]:Text("left"); cols[2]:Text("right")
function Container:Columns(count, gap)
	count = count or 2
	gap = gap or 8
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, holder)

	local cols = {}
	for i = 1, count do
		local c = newContainer(holder, {
			Size = UDim2.new(1 / count, -gap * (count - 1) / count, 0, 0),
			LayoutOrder = i,
		})
		cols[i] = c
	end
	return cols
end

------------------------------------------------------------------ BUTTON GROUP (grid, e.g. 2x2)
-- parent:ButtonGroup(2, { {"Save", fn}, {"Load", fn}, {"Delete", fn}, {"Refresh", fn} })
function Container:ButtonGroup(cols, buttons, gap)
	cols = cols or 2
	gap = gap or 4
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIGridLayout", {
		CellSize = UDim2.new(1 / cols, -gap * (cols - 1) / cols, 0, ITEM_H),
		CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)

	local handles = {}
	for i, def in ipairs(buttons) do
		local b = make("TextButton", {
			Text = def[1],
			AutoButtonColor = false,
			LayoutOrder = i,
		}, holder)
		interactive(b, b, Theme.Button, Theme.ButtonHovered, Theme.ButtonActive)
		b.MouseButton1Click:Connect(function() if def[2] then def[2]() end end)
		handles[def[1]] = { SetText = function(_, t) b.Text = t end, Instance = b }
	end
	return handles
end

------------------------------------------------------------------ CONFIG DROPDOWN (label on top, items can be refreshed)
function Container:Dropdown(label, items, defaultIndex, callback)
	items = items or {}
	local index = (#items > 0) and (defaultIndex or 1) or 0

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, holder)

	if label and label ~= "" then
		make("TextLabel", {
			Text = label,
			Size = UDim2.new(1, 0, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}, holder)
	end

	local main = make("TextButton", {
		Text = "",
		Size = UDim2.new(1, 0, 0, ITEM_H),
		AutoButtonColor = false,
		LayoutOrder = 2,
	}, holder)
	interactive(main, main, Theme.FrameBg, Theme.FrameBgHovered, Theme.FrameBgActive)
	local cur = make("TextLabel", {
		Size = UDim2.new(1, -ITEM_H - 8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, main)
	local arrowBox = make("Frame", {
		Size = UDim2.fromOffset(ITEM_H, ITEM_H),
		Position = UDim2.new(1, -ITEM_H, 0, 0),
	}, main)
	paint(arrowBox, Theme.Button)
	make("TextLabel", { Text = "v", Size = UDim2.fromScale(1, 1) }, arrowBox)

	local list = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 3,
	}, holder)
	paint(list, { C(20, 20, 20), 0 })
	make("UIStroke", { Color = Theme.Border, Transparency = 0.5 }, list)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local h = {}
	local buttons = {}

	local function refresh()
		cur.Text = tostring(items[index] or "")
		for i, b in ipairs(buttons) do
			b.BackgroundColor3 = Theme.Header[1]
			b.BackgroundTransparency = (i == index) and Theme.Header[2] or 1
		end
	end

	local function rebuild()
		for _, b in ipairs(buttons) do b:Destroy() end
		buttons = {}
		for i, item in ipairs(items) do
			local b = make("TextButton", {
				Text = "  " .. tostring(item),
				Size = UDim2.new(1, 0, 0, 18),
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				LayoutOrder = i,
			}, list)
			b.MouseEnter:Connect(function() paint(b, Theme.HeaderHovered) end)
			b.MouseLeave:Connect(refresh)
			b.MouseButton1Click:Connect(function()
				h:Set(i)
				list.Visible = false
			end)
			buttons[i] = b
		end
		refresh()
	end

	function h:Set(i, silent)
		if #items == 0 then index = 0 refresh() return end
		index = math.clamp(i, 1, #items)
		refresh()
		if callback and not silent then callback(items[index], index) end
	end
	function h:Get() return items[index], index end
	function h:SetItems(newItems, keepSelection)
		local old = items[index]
		items = newItems or {}
		index = (#items > 0) and 1 or 0
		if keepSelection and old then
			for i, v in ipairs(items) do if v == old then index = i break end end
		end
		rebuild()
	end

	main.MouseButton1Click:Connect(function() list.Visible = not list.Visible end)
	rebuild()
	return h
end

------------------------------------------------------------------ SIDEBAR TABS
-- local t = parent:SidebarTabs({"Play","Settings"}, 90)
-- t.Play:Text("..."); t.Settings:Text("..."); t:Select("Settings")
function Container:SidebarTabs(names, sidebarWidth)
	sidebarWidth = sidebarWidth or 90
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = self:_order(),
	}, self.Frame)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, holder)

	local side = make("Frame", {
		Size = UDim2.new(0, sidebarWidth, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
	}, holder)
	paint(side, { C(10, 10, 10), 0.3 })
	make("UIStroke", { Color = Theme.Border, Transparency = 0.7 }, side)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, side)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
	}, side)

	local content = make("Frame", {
		Size = UDim2.new(1, -(sidebarWidth + 6), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, holder)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, content)

	local pages, btns, result = {}, {}, {}
	local function select(name)
		for n, p in pairs(pages) do
			local on = (n == name)
			p.Frame.Visible = on
			btns[n].BackgroundColor3 = on and Theme.Header[1] or Theme.Button[1]
			btns[n].BackgroundTransparency = on and 0.2 or 1
			btns[n].TextColor3 = on and Theme.Text or Theme.TextDisabled
		end
	end
	for i, name in ipairs(names) do
		local b = make("TextButton", {
			Text = name,
			Size = UDim2.new(1, 0, 0, 24),
			AutoButtonColor = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
		}, side)
		make("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
		btns[name] = b
		b.MouseEnter:Connect(function()
			if not pages[name].Frame.Visible then
				b.BackgroundColor3 = Theme.HeaderHovered[1]
				b.BackgroundTransparency = 0.6
			end
		end)
		b.MouseLeave:Connect(function()
			if not pages[name].Frame.Visible then b.BackgroundTransparency = 1 end
		end)
		pages[name] = newContainer(content, { Visible = false })
		result[name] = pages[name]
		b.MouseButton1Click:Connect(function() select(name) end)
	end
	select(names[1])
	result.Select = function(_, n) select(n) end
	return result
end

------------------------------------------------------------------ BOTTOM INFO BAR
-- local bar = win:InfoBar("v1.0", "FPS: 60")   -- call last so it sits at the bottom
-- bar:Set("left", "right")
function Container:InfoBar(left, right)
	local r = row(self, 18)
	paint(r, { C(10, 10, 10), 0 })
	make("UIStroke", { Color = Theme.Border, Transparency = 0.7 }, r)
	local l = make("TextLabel", {
		Text = left or "",
		TextSize = FONT_SIZE - 2,
		TextColor3 = Theme.TextDisabled,
		Size = UDim2.new(0.5, -6, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, r)
	local rt = make("TextLabel", {
		Text = right or "",
		TextSize = FONT_SIZE - 2,
		TextColor3 = Theme.TextDisabled,
		Size = UDim2.new(0.5, -6, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, r)
	return {
		Set = function(_, a, b)
			if a ~= nil then l.Text = a end
			if b ~= nil then rt.Text = b end
		end,
		Instance = r,
	}
end

local gui
local zCounter = 1

function ImGui.Init(opts)
	opts = opts or {}
	if gui then gui:Destroy() end
	gui = Instance.new("ScreenGui")
	gui.Name = "ImGuiLib"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999

	local parent = opts.Parent
	if not parent then
		local ok, hui = pcall(function() return gethui and gethui() end)
		parent = (ok and hui) or Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	gui.Parent = parent

	if opts.ToggleKey then
		UIS.InputBegan:Connect(function(i, processed)
			if not processed and i.KeyCode == opts.ToggleKey then
				gui.Enabled = not gui.Enabled
			end
		end)
	end
	return gui
end

function ImGui.Window(title, opts)
	opts = opts or {}
	if not gui then ImGui.Init() end

	local frame = make("Frame", {
		Size = UDim2.new(0, opts.Width or 300, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = opts.Position or UDim2.fromOffset(40, 40),
		Active = true,
	}, gui)
	paint(frame, Theme.WindowBg)
	make("UIStroke", { Color = Theme.Border, Transparency = 0.5 }, frame)

	local titleBar = make("Frame", { Size = UDim2.new(1, 0, 0, ITEM_H) }, frame)
	paint(titleBar, Theme.TitleBgActive)

	local collapsed = opts.Collapsed and true or false
	local arrow = make("TextButton", {
		Text = collapsed and ">" or "v",
		Size = UDim2.fromOffset(ITEM_H, ITEM_H),
	}, titleBar)
	make("TextLabel", {
		Text = title,
		Size = UDim2.new(1, -ITEM_H * 2, 1, 0),
		Position = UDim2.fromOffset(ITEM_H, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, titleBar)

	local body = newContainer(frame, { Position = UDim2.fromOffset(0, ITEM_H), Visible = not collapsed })
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
	}, body.Frame)

	arrow.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		body.Frame.Visible = not collapsed
		arrow.Text = collapsed and ">" or "v"
	end)

	if opts.Closable ~= false then
		local x = make("TextButton", {
			Text = "x",
			Size = UDim2.fromOffset(ITEM_H, ITEM_H),
			Position = UDim2.new(1, -ITEM_H, 0, 0),
		}, titleBar)
		x.MouseEnter:Connect(function() paint(x, Theme.HeaderHovered) end)
		x.MouseLeave:Connect(function() x.BackgroundTransparency = 1 end)
		x.MouseButton1Click:Connect(function() frame.Visible = false end)
	end

	local function focus()
		zCounter += 1
		frame.ZIndex = zCounter
	end
	focus()
	frame.InputBegan:Connect(function(i) if isPress(i) then focus() end end)

	local dragging, dragStart, startPos
	titleBar.InputBegan:Connect(function(i)
		if isPress(i) and not body.Locked then
			dragging = true
			dragStart = i.Position
			startPos = frame.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
			or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i) if isPress(i) then dragging = false end end)

	body.Root = frame
	body.TitleBar = titleBar
	body.Locked = false
	function body:SetVisible(v) frame.Visible = v end
	function body:Destroy() frame:Destroy() end
	return body
end

------------------------------------------------------------------ THEME SWITCHING
local function ckey(c)
	return string.format("%d,%d,%d",
		math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

ImGui.Themes = {
	Blue   = { Accent = C(66,150,250), Dark = C(41,74,122),  Active = C(15,135,250), Grab = C(61,133,224), Window = C(15,15,15), Border = C(110,110,128), Plot = C(230,179,0) },
	Red    = { Accent = C(250,66,66),  Dark = C(122,41,41),  Active = C(250,15,15),  Grab = C(224,61,61),  Window = C(17,12,12), Border = C(128,110,110), Plot = C(255,200,0) },
	Green  = { Accent = C(66,250,110), Dark = C(41,122,62),  Active = C(15,250,70),  Grab = C(61,224,98),  Window = C(12,17,13), Border = C(110,128,114), Plot = C(255,230,0) },
	Maroon = { Accent = C(176,48,64),  Dark = C(88,20,32),   Active = C(210,40,60),  Grab = C(150,36,52),  Window = C(18,10,12), Border = C(120,90,96),   Plot = C(230,150,60) },
	Purple = { Accent = C(160,90,250), Dark = C(80,45,122),  Active = C(140,40,250), Grab = C(140,75,224), Window = C(14,12,18), Border = C(114,110,128), Plot = C(255,200,0) },
	Pink   = { Accent = C(250,100,170), Dark = C(122,41,84), Active = C(250,40,140), Grab = C(224,85,155), Window = C(18,11,15), Border = C(128,105,115), Plot = C(255,210,90) },
	Mint   = { Accent = C(80,230,180),  Dark = C(30,110,90), Active = C(20,230,160), Grab = C(70,205,160), Window = C(11,17,15), Border = C(105,128,120), Plot = C(255,225,100) },
	Navy   = { Accent = C(60,100,200),  Dark = C(20,35,90),  Active = C(40,80,230),  Grab = C(50,90,190),  Window = C(10,13,24), Border = C(90,100,130),  Plot = C(230,190,60) },
}

local currentPalette = ImGui.Themes.Blue

function ImGui.SetTheme(t)
	if type(t) == "string" then t = ImGui.Themes[t] end
	if type(t) ~= "table" then return end

	-- fill any missing keys from Blue so custom themes can be partial
	local new = {}
	for k, v in pairs(ImGui.Themes.Blue) do new[k] = t[k] or v end

	-- old color -> new color
	local map = {}
	for k in pairs(ImGui.Themes.Blue) do
		map[ckey(currentPalette[k])] = new[k]
	end

	-- recolor everything that already exists
	if gui then
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("GuiObject") then
				local n = map[ckey(d.BackgroundColor3)]
				if n then d.BackgroundColor3 = n end
			elseif d:IsA("UIStroke") then
				local n = map[ckey(d.Color)]
				if n then d.Color = n end
			end
		end
	end

	-- update the theme tables so new widgets and hover effects use the new colors
	for _, k in ipairs({ "FrameBg", "FrameBgHovered", "FrameBgActive", "TitleBgActive",
		"Button", "ButtonHovered", "Header", "HeaderHovered", "HeaderActive" }) do
		Theme[k][1] = (k == "FrameBg" or k == "TitleBgActive") and new.Dark or new.Accent
	end
	Theme.ButtonActive[1] = new.Active
	Theme.WindowBg[1] = new.Window
	Theme.CheckMark = new.Accent
	Theme.SliderGrab = new.Grab
	Theme.SliderGrabActive = new.Accent
	Theme.Border = new.Border
	Theme.Separator = new.Border
	Theme.PlotFill = new.Plot

	currentPalette = new
end

return ImGui
