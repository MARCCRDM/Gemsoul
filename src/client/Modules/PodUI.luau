--[[
	MY POD: your pod and its front yard (Shared.PodStyle; Server.PodServer
	builds them; the prompt on your pod's door opens it). Every pick shows on
	your pod straight away and is kept. Each piece shows its rarity; the ones
	you don't own are locked (your pod's first landing rolled you one).

	  Left    PREVIEW: your own pod, turning slowly (a copy of it in a
	          ViewportFrame, made again after each pick); under it the piece
	          in focus (the one you last touched, or what you're wearing):
	          its name, rarity, what it is and whether it's yours; then the
	          COLLECTION (how many pieces you have).
	  Right   tabs: HULL, GLOW, YARD and SHOWCASE, each with how many of
	          its pieces you have. HULL tiles draw a little pod in its
	          colours (roof, frame, finish); GLOW tiles a lit lamp; YARD
	          picks a spot (either side of the stair), then what stands
	          there; SHOWCASE one of your kaiju on the pedestal, or none.

	  PodUI.open()
	  PodUI.start()   once: the door's prompt shows on your own pod only
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PodStyle = require(ReplicatedStorage.Shared.PodStyle)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local PodUI = {}

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new
local W, H = 900, 580
local LEFT_W = 316
local TOP = 78
local CYAN = Color3.fromRGB(110, 220, 255)
local CARD = Color3.fromRGB(20, 26, 38)
local CARD_ON = Color3.fromRGB(26, 50, 62)
local LOCKED = Color3.fromRGB(10, 13, 21)
local DARK = Color3.fromRGB(58, 62, 72)
local KIND = { Hull = "Hull", Glow = "Glow", Left = "Decor", Right = "Decor" }
local LISTS = { Hull = PodStyle.Hulls, Glow = PodStyle.Glows, Decor = PodStyle.Decor }
local TABS = { { Id = "Hull", Name = "HULL" }, { Id = "Glow", Name = "GLOW" }, { Id = "Yard", Name = "YARD" }, { Id = "Showcase", Name = "SHOWCASE" } }
local TAB_KIND = { Hull = "Hull", Glow = "Glow", Yard = "Decor" }
local SLOT_NAME = { Left = "LEFT OF THE STAIR", Right = "RIGHT OF THE STAIR" }
local FINISH = { Metal = "metal", CorrodedMetal = "weathered", DiamondPlate = "tread plate", Foil = "foil", CrackedLava = "lava", Ice = "ice" }
local PRISM = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 90)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 110, 255)),
})

local ui: { [string]: any } = {}
local state = { Style = PodStyle.default(), Kaiju = {}, Owned = {}, Busy = false, Slot = "Left", Tab = "Hull", Focus = nil }

local draw -- (forward)
local refreshPreview -- (forward)

local function line(parent: Instance, value: string, size: number, color: Color3, x, y, w, h, font: Enum.Font?): TextLabel
	local label = IronUi.text(parent, value, size, color, font or IronUi.Bold)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	return label
end

-- An outline round a box (Border: on a TextButton it'd outline its text
-- otherwise); one of thickness 0 starts off (switched on by `lit`).
local function ring(parent: Instance, thickness: number, color: Color3): UIStroke
	return new("UIStroke", {
		Thickness = if thickness > 0 then thickness else 2,
		Enabled = thickness > 0,
		Color = color,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function box(parent: Instance, color: Color3, x, y, w, h, radius: number?): Frame
	local f = new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	if radius then
		UiKit.round(f, radius)
	end
	return f
end

local function button(parent: Instance, color: Color3, x, y, w, h, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = color,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	UiKit.round(b, 8)
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
		ZIndex = 4,
	}, parent)
	local shackle = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 0),
		Size = UDim2.fromOffset(8, 8),
		ZIndex = 4,
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

-- How many of a list are yours (not counting "nothing").
local function tally(kind: string): (number, number)
	local have, total = 0, 0
	for _, entry in LISTS[kind] do
		if entry.Id ~= "None" then
			total += 1
			if owns(kind, entry.Id) then
				have += 1
			end
		end
	end
	return have, total
end

-- Picks one thing (`key` of the style = `value`) and keeps it; a locked one
-- is only shown (in focus), not put on.
local function pick(key: string, value: any)
	local kind = KIND[key]
	if kind then
		state.Focus = { Kind = kind, Id = value }
	end
	if state.Busy then
		return
	end
	if kind and not owns(kind, value) then
		draw()
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
		-- (the server repaints the pod: copy it again once that's arrived)
		task.delay(0.35, function()
			refreshPreview()
		end)
	end)
end

-- Tiles -----------------------------------------------------------------------------------------------

-- A hull's tile art: a little pod in its colours (roof, body, frame), the
-- glow you wear on its trim, a sheen across it if it has a finish.
local function hullArt(parent: Instance, entry, glow: Color3): Frame
	local roof = entry.Roof or entry.Color
	local frame = entry.Frame or DARK
	local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 46) }, parent)
	local function piece(color: Color3, w: number, h: number, dx: number, y: number, radius: number?): Frame
		local f = box(art, color, 0, 0, w, h, radius)
		f.AnchorPoint, f.Position = Vector2.new(0.5, 0), UDim2.new(0.5, dx, 0, y)
		return f
	end
	piece(roof, 54, 12, 0, 0, 6)
	local body = piece(entry.Color, 60, 24, 0, 8, 3)
	piece(frame, 4, 24, -31, 8, 1)
	piece(frame, 4, 24, 31, 8, 1)
	piece(Color3.fromRGB(255, 196, 96), 12, 14, 0, 16, 2)
	local trim = piece(glow, 64, 2, 0, 32)
	piece(frame, 64, 4, 0, 34, 1)
	if entry.Material and FINISH[entry.Material] then
		new("UIGradient", {
			Rotation = 35,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.42, 0),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(0.58, 0),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}, body)
	end
	return trim
end

-- A glow's tile art: a lamp lit in it.
local function glowArt(parent: Instance, entry)
	local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 50) }, parent)
	local halo = box(art, entry.Color, 0, 0, 44, 44, 22)
	halo.AnchorPoint, halo.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0, 24)
	halo.BackgroundTransparency = 0.75
	local lamp = box(art, entry.Color, 0, 0, 26, 26, 13)
	lamp.AnchorPoint, lamp.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0, 24)
	ring(lamp, 2, entry.Color:Lerp(Color3.new(1, 1, 1), 0.6))
	if entry.Prism then
		new("UIGradient", { Color = PRISM, Rotation = 45 }, lamp)
		new("UIGradient", { Color = PRISM, Rotation = 45 }, halo)
	end
end

-- One tile: its art (the yard's has its name instead), the name, its rarity
-- under it and as a strip along the bottom; dimmed with a padlock when it's
-- not yours; ringed when it's on your pod. `key` "Slot": the yard's spot
-- being dressed.
local function tile(parent: Instance, kind: string, key: string, entry, x: number, y: number, w: number, h: number)
	local rarity = PodStyle.rarity(entry.Rarity)
	local b = button(parent, CARD, x, y, w, h, function()
		pick(if key == "Slot" then state.Slot else key, entry.Id)
	end)
	UiKit.round(b, 10)
	local trim = nil
	if kind == "Hull" then
		trim = hullArt(b, entry, PodStyle.glow(state.Style))
	elseif kind == "Glow" then
		glowArt(b, entry)
	end
	local name
	if kind == "Decor" then
		name = line(b, entry.Name, 12, P.Text, 8, 8, w - 26, 30)
		name.TextWrapped = true
		name.TextYAlignment = Enum.TextYAlignment.Top
	else
		name = line(b, entry.Name, 11, P.Text, 6, h - 34, w - 12, 14)
		name.TextXAlignment = Enum.TextXAlignment.Center
	end
	local tier = line(b, rarity.Name, 9, rarity.Color, 8, h - 19, w - 16, 12)
	tier.TextXAlignment = if kind == "Decor" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	local band = box(b, rarity.Color, 0, h - 3, w, 3)
	band.BackgroundTransparency = 0.15
	local shade = new("Frame", {
		BackgroundColor3 = LOCKED,
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, b)
	UiKit.round(shade, 10)
	local lock = padlock(b, w - 13, 14, Color3.fromRGB(200, 208, 222))
	local worn = ring(b, 0, Color3.new(1, 1, 1))
	return { Button = b, Shade = shade, Lock = lock, Ring = worn, Trim = trim }
end

-- A grid of tiles for `kind`, `cols` across, from row `y`.
local function grid(page: Instance, kind: string, key: string, y: number, cols: number, h: number)
	local width = (ui.PageW - (cols - 1) * 10 - 8) // cols
	local tiles = {}
	for i, entry in LISTS[kind] do
		local c, r = (i - 1) % cols, (i - 1) // cols
		tiles[entry.Id] = tile(page, kind, key, entry, c * (width + 10), y + r * (h + 10), width, h)
	end
	return tiles
end

-- The preview -----------------------------------------------------------------------------------------

-- Your pod and its yard (the pads' Pod with your OwnerId, and its Display).
local function findMine(): (Instance?, Instance?)
	local settlement = workspace:FindFirstChild("Settlement", true)
	local pads = settlement and settlement:FindFirstChild("Pads")
	for _, pad in if pads then pads:GetChildren() else {} do
		local pod = pad:FindFirstChild("Pod")
		if pod and pod:GetAttribute("OwnerId") == player.UserId then
			return pod, pad:FindFirstChild("Display")
		end
	end
	return nil, nil
end
-- (a copy keeps only what draws: no sounds, signs or prompts)
local function bare(copy: Instance)
	for _, d in copy:GetDescendants() do
		if d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ProximityPrompt") or d:IsA("BaseScript") then
			d:Destroy()
		end
	end
end
refreshPreview = function()
	if not ui.World then
		return
	end
	ui.World:ClearAllChildren()
	ui.Center = nil
	local pod, yard = findMine()
	ui.NoPod.Visible = pod == nil
	if not pod then
		return
	end
	local ok = pcall(function()
		local copy = (pod :: Model):Clone()
		bare(copy)
		copy.Parent = ui.World
		if yard then
			local yardCopy = yard:Clone()
			bare(yardCopy)
			yardCopy.Parent = ui.World
		end
		local cf, size = copy:GetBoundingBox()
		ui.Center = cf.Position
		ui.Reach = math.max(size.X, size.Z) * 1.35 + size.Y * 0.4
		ui.Up = size.Y * 0.35
	end)
	if not ok then
		ui.World:ClearAllChildren()
		ui.Center = nil
		ui.NoPod.Visible = true
	end
end
local function turn(dt: number)
	if not ui.Center or not ui.Camera then
		return
	end
	ui.Spin = (ui.Spin or 0) + dt * 0.35
	local a = ui.Spin
	local offset = Vector3.new(math.sin(a) * ui.Reach, ui.Up, math.cos(a) * ui.Reach)
	ui.Camera.CFrame = CFrame.lookAt(ui.Center + offset, ui.Center)
end

-- The window -------------------------------------------------------------------------------------------

local function build()
	local w = IronUi.window("PodStyle", 12, W, H, "⌂", CYAN)
	w.Title.Text = "MY POD"
	w.Subtitle.Text = "Your pod and its front yard. Every pick shows straight away."
	local function close()
		w.Gui.Enabled = false
		if ui.Turning then
			ui.Turning:Disconnect()
			ui.Turning = nil
		end
	end
	w.Close.Activated:Connect(close)
	w.Shade.Activated:Connect(close)
	ui.Window = w
	local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(20, TOP), Size = UDim2.new(1, -40, 1, -TOP - 16) }, w.Panel)
	local bodyH = H - TOP - 16

	-- the preview
	local frame = box(body, Color3.fromRGB(8, 11, 19), 0, 0, LEFT_W, 230, 12)
	ring(frame, 1, P.Edge).Transparency = 0.5
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(150, 156, 170),
		LightColor = Color3.fromRGB(255, 248, 236),
		LightDirection = Vector3.new(-0.6, -1, -0.4),
	}, frame)
	ui.World = new("WorldModel", {}, view)
	ui.Camera = new("Camera", { FieldOfView = 40 }, view)
	view.CurrentCamera = ui.Camera
	ui.NoPod = line(frame, "Your pod shows here once it's landed.", 12, P.Dim, 0, 0, LEFT_W, 230, IronUi.Body)
	ui.NoPod.TextXAlignment = Enum.TextXAlignment.Center
	line(frame, "PREVIEW", 10, P.Dim, 12, 10, 100, 12)

	-- the piece in focus
	ui.FocusKind = line(body, "", 10, P.Dim, 0, 244, LEFT_W, 12)
	ui.FocusName = line(body, "", 18, P.Text, 0, 258, LEFT_W, 24)
	ui.FocusDot = box(body, P.Dim, 0, 291, 8, 8, 4)
	ui.FocusRarity = line(body, "", 11, P.Dim, 14, 287, LEFT_W - 14, 16)
	ui.FocusBlurb = line(body, "", 13, P.Dim, 0, 310, LEFT_W, 36, IronUi.Body)
	ui.FocusBlurb.TextWrapped = true
	ui.FocusBlurb.TextYAlignment = Enum.TextYAlignment.Top
	ui.FocusState = line(body, "", 11, CYAN, 0, 352, LEFT_W, 16)

	-- the collection
	local cy = bodyH - 92
	line(body, "COLLECTION", 11, P.Dim, 0, cy, 120, 14)
	ui.Count = line(body, "", 11, P.Text, LEFT_W - 160, cy, 160, 14)
	ui.Count.TextXAlignment = Enum.TextXAlignment.Right
	local track = box(body, CARD, 0, cy + 20, LEFT_W, 6, 3)
	ui.Fill = box(track, CYAN, 0, 0, 0, 6, 3)
	ui.Fill.Size = UDim2.fromScale(0, 1)
	local note = line(body, "Your pod's first landing rolled you a piece. The locked ones show what else is out there.", 11, P.Dim, 0, cy + 34, LEFT_W, 30, IronUi.Body)
	note.TextWrapped = true

	-- the tabs
	local rx = LEFT_W + 24
	local rw = W - 40 - rx
	ui.PageW = rw
	ui.Tabs = {}
	local tabW = (rw - 3 * 8) // 4
	for i, t in TABS do
		local b = button(body, CARD, rx + (i - 1) * (tabW + 8), 0, tabW, 42, function()
			state.Tab = t.Id
			state.Focus = nil
			draw()
		end)
		local name = line(b, t.Name, 12, P.Text, 12, 6, tabW - 24, 16)
		local count = line(b, "", 10, P.Dim, 12, 22, tabW - 24, 14, IronUi.Body)
		local under = box(b, CYAN, 0, 39, tabW, 3)
		ui.Tabs[t.Id] = { Button = b, Name = name, Count = count, Under = under }
	end

	-- the pages
	ui.Pages = {}
	local function page(id: string): ScrollingFrame
		local p = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(rx, 54),
			Size = UDim2.fromOffset(rw, bodyH - 54),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			Visible = false,
		}, body)
		ui.Pages[id] = p
		return p
	end
	ui.Hull = grid(page("Hull"), "Hull", "Hull", 0, 5, 100)
	ui.Glow = grid(page("Glow"), "Glow", "Glow", 0, 5, 100)
	local yard = page("Yard")
	ui.Slots = {}
	local half = (rw - 8 - 8) // 2
	for i, slot in { "Left", "Right" } do
		local b = button(yard, CARD, (i - 1) * (half + 8), 0, half, 46, function()
			state.Slot = slot
			state.Focus = nil
			draw()
		end)
		line(b, SLOT_NAME[slot], 10, P.Dim, 12, 7, half - 24, 14)
		local piece = line(b, "", 13, P.Text, 12, 22, half - 24, 16)
		ui.Slots[slot] = { Button = b, Piece = piece, Ring = ring(b, 0, CYAN) }
	end
	ui.Decor = grid(yard, "Decor", "Slot", 58, 4, 66)
	ui.ShowList = page("Showcase")
	UiKit.list(ui.ShowList, 6)
	return w
end

-- What the focus panel says about one piece.
local function focusOn(kind: string, id: any)
	local entry = PodStyle.find(kind, id)
	if not entry then
		return
	end
	local rarity = PodStyle.rarity(entry.Rarity)
	ui.FocusKind.Text = string.upper(kind)
	ui.FocusName.Text = entry.Name
	ui.FocusDot.BackgroundColor3 = rarity.Color
	ui.FocusRarity.Text, ui.FocusRarity.TextColor3 = rarity.Name, rarity.Color
	local finish = entry.Material and FINISH[entry.Material]
	ui.FocusBlurb.Text = (entry.Blurb or "") .. (if finish then " Finish: " .. finish .. "." else "")
	local worn = (kind == "Hull" and state.Style.Hull == id)
		or (kind == "Glow" and state.Style.Glow == id)
		or (kind == "Decor" and (state.Style.Left == id or state.Style.Right == id))
	if not owns(kind, id) then
		ui.FocusState.Text, ui.FocusState.TextColor3 = "LOCKED", P.Dim
	elseif worn then
		ui.FocusState.Text, ui.FocusState.TextColor3 = "ON YOUR POD", CYAN
	else
		ui.FocusState.Text, ui.FocusState.TextColor3 = "YOURS: TAP TO PUT IT ON", P.Good
	end
end

draw = function()
	if not ui.Window then
		return
	end
	local style = state.Style
	-- the collection
	local have, total = 0, 0
	for _, kind in { "Hull", "Glow", "Decor" } do
		local h, t = tally(kind)
		have += h
		total += t
	end
	ui.Count.Text = string.format("%d / %d PIECES", have, total)
	ui.Fill.Size = UDim2.fromScale(if total > 0 then have / total else 0, 1)
	-- the tabs
	for _, t in TABS do
		local tab = ui.Tabs[t.Id]
		local on = state.Tab == t.Id
		tab.Button.BackgroundColor3 = if on then CARD_ON else CARD
		tab.Under.Visible = on
		tab.Name.TextColor3 = if on then P.Text else P.Dim
		if t.Id == "Showcase" then
			tab.Count.Text = string.format("%d KAIJU", #state.Kaiju)
		else
			local h, n = tally(TAB_KIND[t.Id])
			tab.Count.Text = string.format("%d / %d", h, n)
		end
		ui.Pages[t.Id].Visible = on
	end
	-- the tiles
	local glow = PodStyle.glow(style)
	for _, kind in { "Hull", "Glow" } do
		for id, t in ui[kind] do
			local mine = owns(kind, id)
			t.Ring.Enabled = style[kind] == id
			t.Shade.Visible = not mine
			t.Lock.Visible = not mine
			if t.Trim then
				t.Trim.BackgroundColor3 = glow
			end
		end
	end
	for slot, s in ui.Slots do
		local on = state.Slot == slot
		local entry = PodStyle.find("Decor", style[slot])
		s.Piece.Text = if entry then entry.Name else "NOTHING"
		s.Ring.Enabled = on
		s.Button.BackgroundColor3 = if on then CARD_ON else CARD
	end
	local current = style[state.Slot]
	for id, t in ui.Decor do
		local mine = owns("Decor", id)
		t.Ring.Enabled = current == id
		t.Shade.Visible = not mine
		t.Lock.Visible = not mine
	end
	-- the focus: the piece last touched on this tab, or what's on your pod
	local want = TAB_KIND[state.Tab]
	local focus = state.Focus
	if want and (not focus or focus.Kind ~= want) then
		focus = { Kind = want, Id = if want == "Decor" then style[state.Slot] else style[want] }
	end
	if want and focus then
		focusOn(focus.Kind, focus.Id)
	else
		ui.FocusKind.Text = "SHOWCASE"
		local chosen = nil
		for _, k in state.Kaiju do
			if k.Id == style.Showcase then
				chosen = k
			end
		end
		ui.FocusName.Text = if chosen then string.upper(chosen.Name or chosen.Species) else "EMPTY PEDESTAL"
		ui.FocusDot.BackgroundColor3 = if chosen then (GemConfig.ElementColors[chosen.Element] or P.Edge) else P.Edge
		ui.FocusRarity.Text = if chosen then string.format("%s  ·  LV %d", chosen.Species, chosen.Level or 1) else ""
		ui.FocusRarity.TextColor3 = P.Dim
		ui.FocusBlurb.Text = "One of your kaiju on the pedestal by your pod, for everyone walking past to see."
		ui.FocusState.Text = ""
	end
	-- the showcase
	IronUi.clear(ui.ShowList)
	local function row(text: string, sub: string, tint: Color3, chosen: boolean, onClick: () -> ())
		local b = new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = if chosen then CARD_ON else CARD,
			Size = UDim2.new(1, -6, 0, 50),
		}, ui.ShowList)
		UiKit.round(b, 8)
		if chosen then
			ring(b, 2, CYAN)
		end
		b:SetAttribute("UiSound", "Click")
		local edge = box(b, tint, 0, 0, 4, 50, 2)
		edge.Size = UDim2.new(0, 4, 1, 0)
		line(b, text, 13, P.Text, 16, 8, 300, 18)
		line(b, sub, 11, P.Dim, 16, 27, 300, 15, IronUi.Body)
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
	state.Focus = nil
	draw()
	refreshPreview()
	if not ui.Turning then
		ui.Turning = RunService.RenderStepped:Connect(turn)
	end
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
