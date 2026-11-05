--[[
	MY POD: your pod and its front yard (Shared.PodStyle; Server.PodServer
	builds them; the prompt on your pod's door opens it). Every pick shows on
	your pod straight away and is kept. Each piece shows its rarity; the ones
	you haven't rolled yet (your pod rolls one each time it lands) are locked.

	  Left    HULL (its colour) and GLOW (the beacon, the trim, your name),
	          then the yard's two spots either side of the stair, LEFT and
	          RIGHT: what stands there
	  Right   SHOWCASE: one of your kaiju on the pedestal by the pod, or none

	  PodUI.open()
	  PodUI.start()   once: the door's prompt shows on your own pod only
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PodStyle = require(ReplicatedStorage.Shared.PodStyle)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local PodUI = {}

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new
local W, H = 760, 500
local LEFT_W = 400
local CYAN = Color3.fromRGB(110, 220, 255)
local INK = Color3.fromRGB(10, 13, 20)
local CARD = Color3.fromRGB(18, 23, 34)

local ui: { [string]: any } = {}
local state = { Style = PodStyle.default(), Kaiju = {}, Owned = {}, Busy = false }
local LOCKED = Color3.fromRGB(34, 40, 54)

local draw -- (forward)

local function line(parent: Instance, value: string, size: number, color: Color3, x, y, w, h): TextLabel
	local label = IronUi.text(parent, value, size, color, IronUi.Bold)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	return label
end

local function chip(parent: Instance, text: string, color: Color3, x, y, w, h, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		Text = text,
		Font = IronUi.Heading,
		TextSize = 11,
		TextColor3 = INK,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	UiKit.round(b, 7)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(onClick)
	return b
end

local KIND = { Hull = "Hull", Glow = "Glow", Left = "Decor", Right = "Decor" }

-- Picks one thing (`key` of the style = `value`) and keeps it.
local function pick(key: string, value: any)
	if state.Busy then
		return
	end
	local kind = KIND[key]
	if kind and not PodStyle.owns(state.Owned, kind, value) then
		local entry = PodStyle.find(kind, value)
		local rarity = PodStyle.rarity(entry and entry.Rarity or "Common")
		UiKit.toast(string.format("%s (%s) is locked: your pod rolls a new piece each time it lands.", entry and entry.Name or "That", rarity.Name), rarity.Color)
		return
	end
	local wanted = table.clone(state.Style)
	wanted[key] = value
	state.Style = wanted
	draw()
	state.Busy = true
	task.spawn(function()
		local result = GemClient.request("PodStyle", wanted)
		state.Busy = false
		if result and result.Ok and result.Style then
			state.Style = result.Style
		elseif result and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, P.Gold)
		end
		draw()
	end)
end

-- A row of colour swatches (`list`: PodStyle.Hulls or .Glows) for `key`,
-- each with its rarity's colour under it.
local function swatches(parent: Instance, list, key: string, y: number)
	local row = {}
	local size = 40
	for i, entry in list do
		local x = (i - 1) * (size + 9)
		local b = chip(parent, "", entry.Color, x, y, size, size, function()
			pick(key, entry.Id)
		end)
		local ring = new("UIStroke", { Thickness = 0, Color = Color3.new(1, 1, 1) }, b)
		local strip = new("Frame", {
			BackgroundColor3 = PodStyle.rarity(entry.Rarity).Color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x + 6, y + size + 3),
			Size = UDim2.fromOffset(size - 12, 3),
		}, parent)
		UiKit.round(strip, 2)
		if entry.Prism then
			new("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 90)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)),
				}),
				Rotation = 45,
			}, b)
		end
		local lock = line(b, "LOCKED", 8, P.Dim, 0, size / 2 - 5, size, 10)
		lock.TextXAlignment = Enum.TextXAlignment.Center
		row[entry.Id] = { Ring = ring, Button = b, Lock = lock, Color = entry.Color }
	end
	return row
end

-- A grid of decor chips for the yard spot `key` ("Left" or "Right"), each
-- edged in its rarity's colour.
local function decorChips(parent: Instance, key: string, y: number)
	local row = {}
	local cols, w, h = 4, 94, 24
	for i, entry in PodStyle.Decor do
		local col, r = (i - 1) % cols, (i - 1) // cols
		local b = chip(parent, entry.Name, P.Edge, col * (w + 6), y + r * (h + 4), w, h, function()
			pick(key, entry.Id)
		end)
		b.TextScaled = true
		new("UITextSizeConstraint", { MaxTextSize = 11 }, b)
		new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, b)
		new("UIStroke", { Thickness = 1, Color = PodStyle.rarity(entry.Rarity).Color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		row[entry.Id] = b
	end
	return row
end

local function build()
	local w = IronUi.window("PodStyle", 12, W, H, "⌂", CYAN)
	w.Title.Text = "MY POD"
	w.Subtitle.Text = "Your pod and its front yard. Every pick shows straight away."
	w.Close.Activated:Connect(function()
		w.Gui.Enabled = false
	end)
	w.Shade.Activated:Connect(function()
		w.Gui.Enabled = false
	end)
	ui.Window = w
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 78), Size = UDim2.new(1, -40, 1, -94) }, w.Panel)
	line(body, "HULL", 12, P.Dim, 0, 0, LEFT_W, 16)
	ui.Hull = swatches(body, PodStyle.Hulls, "Hull", 20)
	ui.HullName = line(body, "", 12, P.Text, 0, 68, LEFT_W, 16)
	line(body, "GLOW", 12, P.Dim, 0, 92, LEFT_W, 16)
	ui.Glow = swatches(body, PodStyle.Glows, "Glow", 112)
	ui.GlowName = line(body, "", 12, P.Text, 0, 160, LEFT_W, 16)
	line(body, "YARD · LEFT OF THE STAIR", 12, P.Dim, 0, 186, LEFT_W, 16)
	ui.Left = decorChips(body, "Left", 204)
	line(body, "YARD · RIGHT OF THE STAIR", 12, P.Dim, 0, 294, LEFT_W, 16)
	ui.Right = decorChips(body, "Right", 312)
	local rx, rw = LEFT_W + 24, W - 40 - LEFT_W - 24
	line(body, "SHOWCASE", 12, P.Dim, rx, 0, rw, 16)
	line(body, "One of your kaiju on the pedestal by your pod.", 11, P.Dim, rx, 18, rw, 16)
	ui.List = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(rx, 42),
		Size = UDim2.fromOffset(rw, H - 94 - 50),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, body)
	UiKit.list(ui.List, 6)
	return w
end

draw = function()
	if not ui.Window then
		return
	end
	local style = state.Style
	for _, kind in { "Hull", "Glow" } do
		for id, swatch in ui[kind] do
			local owned = PodStyle.owns(state.Owned, kind, id)
			swatch.Ring.Thickness = if style[kind] == id then 3 else 0
			swatch.Button.BackgroundColor3 = if owned then swatch.Color else swatch.Color:Lerp(LOCKED, 0.75)
			swatch.Lock.Visible = not owned
		end
		local entry = PodStyle.find(kind, style[kind])
		local label = if kind == "Hull" then ui.HullName else ui.GlowName
		if entry then
			local rarity = PodStyle.rarity(entry.Rarity)
			label.Text = entry.Name .. "  ·  " .. rarity.Name
			label.TextColor3 = if kind == "Glow" then entry.Color else rarity.Color
		end
	end
	for _, slot in { "Left", "Right" } do
		for id, b in ui[slot] do
			local owned = PodStyle.owns(state.Owned, "Decor", id)
			b.BackgroundColor3 = if style[slot] == id then CYAN elseif owned then P.Edge else LOCKED
			b.TextColor3 = if style[slot] == id then INK elseif owned then P.Text else P.Dim
		end
	end
	IronUi.clear(ui.List)
	local function row(text: string, sub: string, chosen: boolean, onClick: () -> ())
		local b = new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = if chosen then Color3.fromRGB(28, 52, 64) else CARD,
			Size = UDim2.new(1, -6, 0, 44),
		}, ui.List)
		UiKit.round(b, 8)
		if chosen then
			new("UIStroke", { Thickness = 2, Color = CYAN }, b)
		end
		b:SetAttribute("UiSound", "Click")
		line(b, text, 13, P.Text, 12, 5, 260, 18)
		line(b, sub, 11, P.Dim, 12, 23, 260, 16)
		b.Activated:Connect(onClick)
	end
	row("NONE", "An empty pedestal", style.Showcase == nil, function()
		pick("Showcase", nil)
	end)
	for _, k in state.Kaiju do
		row(string.upper(k.Name or k.Species), string.format("%s · %s · LV %d", k.Species, k.Element or "?", k.Level or 1), style.Showcase == k.Id, function()
			pick("Showcase", k.Id)
		end)
	end
end

function PodUI.open()
	local w = ui.Window or build()
	w.Gui.Enabled = true
	draw()
	task.spawn(function()
		local result = GemClient.request("PodStyleState")
		if result and result.Ok then
			state.Style = result.Style or state.Style
			state.Kaiju = result.Kaiju or {}
			state.Owned = if type(result.Owned) == "table" then result.Owned else {}
		end
		draw()
	end)
end

-- The door's prompt on your own pod only (everyone's pod has one).
function PodUI.start()
	local function check(prompt: Instance)
		if prompt:IsA("ProximityPrompt") and prompt.Name == "PodPrompt" then
			prompt.Enabled = prompt:GetAttribute("OwnerId") == player.UserId
		end
	end
	for _, d in workspace:GetDescendants() do
		check(d)
	end
	workspace.DescendantAdded:Connect(check)
end

return PodUI
