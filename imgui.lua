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
	
	if class ~= "UIStroke" and class ~= "UIPadding" and class ~= "UIListLayout" then
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
		if isPress(i) then
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
	function body:SetVisible(v) frame.Visible = v end
	function body:Destroy() frame:Destroy() end
	return body
end

return imgui
