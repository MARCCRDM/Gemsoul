--[[
	MY POD: your pod and its front yard (Shared.PodStyle; Server.PodServer
	builds them; the prompt on your pod's door opens it). Every pick shows on
	your pod straight away and is kept. Each piece shows its rarity; the ones
	you haven't rolled yet (your pod rolls one each time it lands) are locked.

	  Left    COLLECTION (how many pieces you have), HULL and GLOW swatches,
	          then the YARD: which spot (left or right of the stair) and
	          the decor for it. Hovering a piece names it.
	  Right   SHOWCASE: one of your kaiju on the pedestal by the pod, or none

	  PodUI.open()
	  PodUI.start()   once: the door's prompt shows on your own pod only
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PodStyle = require(ReplicatedStorage.Shared.PodStyle)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local PodUI = {}

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new
local W, H = 780, 520
local LEFT_W = 430
local CYAN = Color3.fromRGB(110, 220, 255)
local CARD = Color3.fromRGB(20, 26, 38)
local CARD_ON = Color3.fromRGB(26, 50, 62)
local LOCKED = Color3.fromRGB(16, 20, 30)
local KIND = { Hull = "Hull", Glow = "Glow", Left = "Decor", Right = "Decor" }
local SLOT_NAME = { Left = "LEFT OF THE STAIR", Right = "RIGHT OF THE STAIR" }

local ui: { [string]: any } = {}
local state = { Style = PodStyle.default(), Kaiju = {}, Owned = {}, Busy = false, Slot = "Left" }

local draw -- (forward)

local function line(parent: Instance, value: string, size: number, color: Color3, x, y, w, h, font: Enum.Font?): TextLabel
	local label = IronUi.text(parent, value, size, color, font or IronUi.Bold)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	return label
end

-- An outline round a box (Border: on a TextButton it'd outline its text otherwise).
local function ring(parent: Instance, thickness: number, color: Color3): UIStroke
	return new("UIStroke", { Thickness = thickness, Color = color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function button(parent: Instance, color: Color3, x, y, w, h, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	UiKit.round(b, 7)
	b:SetAttribute("UiSound", "Click")
	b.Activated:Connect(onClick)
	return b
end

-- A small padlock (drawn: no glyph), its middle at (x, y) in `parent`.
local function padlock(parent: Instance, x: number, y: number, color: Color3): Frame
	local lock = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(12, 14),
		ZIndex = 3,
	}, parent)
	local shackle = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(8, 9),
		ZIndex = 3,
	}, lock)
	UiKit.round(shackle, 4)
	ring(shackle, 2, color)
	local body = new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(12, 8),
		ZIndex = 4,
	}, lock)
	UiKit.round(body, 2)
	return lock
end

local function owns(kind: string, id: any): boolean
	return PodStyle.owns(state.Owned, kind, id)
end

-- What a piece is, for its row's heading: "CHROME · EPIC" (· LOCKED).
local function describe(kind: string, id: any): (string, Color3)
	local entry = PodStyle.find(kind, id)
	if not entry then
		return "", P.Dim
	end
	local rarity = PodStyle.rarity(entry.Rarity)
	return entry.Name .. "  ·  " .. rarity.Name .. (if owns(kind, id) then "" else "  ·  LOCKED"), rarity.Color
end

-- Picks one thing (`key` of the style = `value`) and keeps it.
local function pick(key: string, value: any)
	if state.Busy then
		return
	end
	local kind = KIND[key]
	if kind and not owns(kind, value) then
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

-- A row of colour swatches (`kind`: "Hull" or "Glow"), each with its
-- rarity under it; hovering one names it on `label`.
local PRISM = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 90)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)),
})
local function swatches(parent: Instance, kind: string, y: number, label: TextLabel)
	local row = {}
	local size, gap = 44, 10
	for i, entry in (if kind == "Hull" then PodStyle.Hulls else PodStyle.Glows) do
		local x = (i - 1) * (size + gap)
		local b = button(parent, entry.Color, x, y, size, size, function()
			pick(kind, entry.Id)
		end)
		UiKit.round(b, 9)
		if entry.Prism then
			new("UIGradient", { Color = PRISM, Rotation = 45 }, b)
		end
		-- (not yours: dimmed, a padlock on it)
		local shade = new("Frame", {
			BackgroundColor3 = LOCKED,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, b)
		UiKit.round(shade, 9)
		local lock = padlock(b, size / 2, size / 2, Color3.fromRGB(200, 208, 222))
		local selected = ring(b, 0, Color3.new(1, 1, 1))
		local strip = new("Frame", {
			BackgroundColor3 = PodStyle.rarity(entry.Rarity).Color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x + 8, y + size + 4),
			Size = UDim2.fromOffset(size - 16, 3),
		}, parent)
		UiKit.round(strip, 2)
		b.MouseEnter:Connect(function()
			label.Text, label.TextColor3 = describe(kind, entry.Id)
		end)
		b.MouseLeave:Connect(function()
			label.Text, label.TextColor3 = describe(kind, state.Style[kind])
		end)
		row[entry.Id] = { Ring = selected, Shade = shade, Lock = lock }
	end
	return row
end

-- The yard's decor: a card each (its rarity down its left edge, a padlock
-- if it's not yours), for the spot being dressed (state.Slot).
local function decorCards(parent: Instance, y: number, label: TextLabel)
	local cards = {}
	local cols, gap = 3, 8
	local w, h = (LEFT_W - (cols - 1) * gap) // cols, 30
	for i, entry in PodStyle.Decor do
		local col, r = (i - 1) % cols, (i - 1) // cols
		local b = button(parent, CARD, col * (w + gap), y + r * (h + 6), w, h, function()
			pick(state.Slot, entry.Id)
		end)
		local edge = new("Frame", {
			BackgroundColor3 = PodStyle.rarity(entry.Rarity).Color,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 4, 1, 0),
		}, b)
		UiKit.round(edge, 2)
		local name = line(b, entry.Name, 11, P.Text, 12, 0, w - 34, h)
		local lock = padlock(b, w - 14, h / 2, P.Dim)
		local selected = ring(b, 0, CYAN)
		b.MouseEnter:Connect(function()
			label.Text, label.TextColor3 = describe("Decor", entry.Id)
		end)
		b.MouseLeave:Connect(function()
			label.Text, label.TextColor3 = describe("Decor", state.Style[state.Slot])
		end)
		cards[entry.Id] = { Button = b, Name = name, Lock = lock, Ring = selected }
	end
	return cards
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
	local bodyH = H - 94

	-- the collection: how many pieces you have
	line(body, "COLLECTION", 12, P.Dim, 0, 0, 120, 16)
	ui.Count = line(body, "", 12, P.Text, LEFT_W - 160, 0, 160, 16)
	ui.Count.TextXAlignment = Enum.TextXAlignment.Right
	local track = new("Frame", { BackgroundColor3 = CARD, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(LEFT_W, 6) }, body)
	UiKit.round(track, 3)
	ui.Fill = new("Frame", { BackgroundColor3 = CYAN, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, track)
	UiKit.round(ui.Fill, 3)

	line(body, "HULL", 12, P.Dim, 0, 40, 60, 16)
	ui.HullName = line(body, "", 12, P.Text, 60, 40, LEFT_W - 60, 16)
	ui.HullName.TextXAlignment = Enum.TextXAlignment.Right
	ui.Hull = swatches(body, "Hull", 60, ui.HullName)

	line(body, "GLOW", 12, P.Dim, 0, 124, 60, 16)
	ui.GlowName = line(body, "", 12, P.Text, 60, 124, LEFT_W - 60, 16)
	ui.GlowName.TextXAlignment = Enum.TextXAlignment.Right
	ui.Glow = swatches(body, "Glow", 144, ui.GlowName)

	-- the yard: which spot, then what stands there
	line(body, "YARD", 12, P.Dim, 0, 208, 60, 16)
	ui.DecorName = line(body, "", 12, P.Text, 60, 208, LEFT_W - 60, 16)
	ui.DecorName.TextXAlignment = Enum.TextXAlignment.Right
	ui.Slots = {}
	local half = (LEFT_W - 8) // 2
	for i, slot in { "Left", "Right" } do
		local b = button(body, CARD, (i - 1) * (half + 8), 228, half, 40, function()
			state.Slot = slot
			draw()
		end)
		line(b, SLOT_NAME[slot], 10, P.Dim, 12, 5, half - 24, 14)
		local piece = line(b, "", 13, P.Text, 12, 19, half - 24, 16)
		ui.Slots[slot] = { Button = b, Piece = piece, Ring = ring(b, 0, CYAN) }
	end
	ui.Decor = decorCards(body, 278, ui.DecorName)

	-- how the roll works, and the rarities (commonest first)
	local foot = bodyH - 18
	line(body, "Your pod rolls a new piece every time it lands.", 11, P.Dim, 0, foot - 20, LEFT_W, 14, IronUi.Body)
	local x = 0
	for _, r in PodStyle.Rarities do
		local dot = new("Frame", { BackgroundColor3 = r.Color, BorderSizePixel = 0, Position = UDim2.fromOffset(x, foot + 4), Size = UDim2.fromOffset(8, 8) }, body)
		UiKit.round(dot, 4)
		local width = math.ceil(#r.Name * 7.4)
		line(body, r.Name, 10, r.Color, x + 12, foot, width + 4, 16)
		x += 12 + width + 14
	end

	-- the showcase
	local rx, rw = LEFT_W + 28, W - 40 - LEFT_W - 28
	new("Frame", { BackgroundColor3 = P.Edge, BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromOffset(LEFT_W + 13, 0), Size = UDim2.fromOffset(1, bodyH) }, body)
	line(body, "SHOWCASE", 12, P.Dim, rx, 0, rw, 16)
	line(body, "One of your kaiju on the pedestal by your pod.", 11, P.Dim, rx, 18, rw, 16, IronUi.Body)
	ui.List = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(rx, 42),
		Size = UDim2.fromOffset(rw, bodyH - 42),
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
	-- the collection
	local have, total = 0, 0
	for kind, list in { Hull = PodStyle.Hulls, Glow = PodStyle.Glows, Decor = PodStyle.Decor } do
		for _, entry in list do
			if entry.Id ~= "None" then
				total += 1
				if owns(kind, entry.Id) then
					have += 1
				end
			end
		end
	end
	ui.Count.Text = string.format("%d / %d PIECES", have, total)
	ui.Fill.Size = UDim2.fromScale(if total > 0 then have / total else 0, 1)
	-- hull and glow
	for _, kind in { "Hull", "Glow" } do
		for id, swatch in ui[kind] do
			local mine = owns(kind, id)
			swatch.Ring.Thickness = if style[kind] == id then 3 else 0
			swatch.Shade.Visible = not mine
			swatch.Lock.Visible = not mine
		end
	end
	ui.HullName.Text, ui.HullName.TextColor3 = describe("Hull", style.Hull)
	ui.GlowName.Text, ui.GlowName.TextColor3 = describe("Glow", style.Glow)
	-- the yard
	for slot, s in ui.Slots do
		local on = state.Slot == slot
		local entry = PodStyle.find("Decor", style[slot])
		s.Piece.Text = if entry then entry.Name else "NOTHING"
		s.Ring.Thickness = if on then 2 else 0
		s.Button.BackgroundColor3 = if on then CARD_ON else CARD
	end
	local current = style[state.Slot]
	for id, card in ui.Decor do
		local mine = owns("Decor", id)
		local chosen = current == id
		card.Ring.Thickness = if chosen then 2 else 0
		card.Button.BackgroundColor3 = if chosen then CARD_ON elseif mine then CARD else LOCKED
		card.Name.TextColor3 = if mine then P.Text else P.Dim
		card.Name.TextTransparency = if mine then 0 else 0.35
		card.Lock.Visible = not mine
	end
	ui.DecorName.Text, ui.DecorName.TextColor3 = describe("Decor", current)
	-- the showcase
	IronUi.clear(ui.List)
	local function row(text: string, sub: string, tint: Color3, chosen: boolean, onClick: () -> ())
		local b = new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = if chosen then CARD_ON else CARD,
			Size = UDim2.new(1, -6, 0, 46),
		}, ui.List)
		UiKit.round(b, 8)
		if chosen then
			ring(b, 2, CYAN)
		end
		b:SetAttribute("UiSound", "Click")
		local edge = new("Frame", { BackgroundColor3 = tint, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, 0) }, b)
		UiKit.round(edge, 2)
		line(b, text, 13, P.Text, 14, 6, 220, 18)
		line(b, sub, 11, P.Dim, 14, 25, 220, 15, IronUi.Body)
		b.Activated:Connect(onClick)
	end
	row("NONE", "An empty pedestal", P.Edge, style.Showcase == nil, function()
		pick("Showcase", nil)
	end)
	for _, k in state.Kaiju do
		local tint = GemConfig.ElementColors[k.Element] or P.Edge
		row(string.upper(k.Name or k.Species), string.format("%s  ·  %s  ·  LV %d", k.Species, k.Element or "?", k.Level or 1), tint, style.Showcase == k.Id, function()
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
