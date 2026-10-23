--[[
	A wild kaiju's health over its head: its name, its level and a health
	bar, so you can size one up before you start on it, see how a fight is
	going, and see when it's worn down enough to catch. Only wild kaiju get
	one: the rest of the Outpost's creatures (your kaiju, a rift's critters)
	keep their health on their bodies alone (BodyHealth), and a wild kaiju
	keeps its outline too. The bar is in its outline's colours (green, amber,
	red: BodyHealth.outlineColor), and a pale trail shows what the last blow
	took before it drains away. The vein guardian's is gold; one being
	caught (KaijuTameBy) has a gold edge.

	The nearest Budget within Range of the camera show, never one knocked
	out. They sit in PlayerGui (so they're in the player's language: "Lv"
	reads "Nv" in Spanish), each adorning its kaiju's root.

	  WildBars.watch(model)   start drawing it (KaijuHud's scan hands it each
	                          wild kaiju it finds)
	  WildBars.start()        which show, a few times a second, and the
	                          trails draining
	  WildBars.plate(model, phone?) -> BillboardGui   builds one (its Title,
	                          Level, Back, Fill and Trail inside); smaller
	                          on a phone (PhoneSize, everything inside in
	                          proportion)
	  WildBars.draw(plate, share, trail, guardian, catching)   fills it in
	  WildBars.choose(entries, budget, range) -> { [entry]: true }   which
	                          show: entries are { Distance, Share } (pure)
	  WildBars.phone() -> boolean          a phone (touch, no keyboard; or a
	                          short screen): the smaller plates
	  WildBars.Budget, PhoneBudget, Range, Size, PhoneSize, Hold, Drain
]]
local BodyHealth = require(script.Parent.BodyHealth)

local WildBars = {}

WildBars.Budget = 6 -- shown at once, at most
WildBars.Range = 140 -- studs from the camera: further, none
WildBars.Size = Vector2.new(210, 36) -- the plate, in pixels
-- On a phone: smaller, and fewer at once (they were a third of the screen).
WildBars.PhoneSize = Vector2.new(124, 22)
WildBars.PhoneBudget = 4
WildBars.Hold = 0.35 -- seconds the trail holds after a blow
WildBars.Drain = 0.8 -- how much of the bar the trail drains a second
WildBars.Every = 0.25 -- seconds between picks

local INK = Color3.fromRGB(12, 11, 16)
local EDGE = Color3.fromRGB(70, 66, 84)
local GOLD = Color3.fromRGB(255, 204, 92)
local TRAIL = Color3.fromRGB(255, 236, 200)
local NAME = Color3.fromRGB(242, 240, 236)

-- Which of `entries` ({ Distance, Share }) show: the nearest `budget`
-- within `range`, none knocked out.
function WildBars.choose(entries, budget: number, range: number): { [any]: boolean }
	local want = {}
	for _, entry in entries do
		if entry.Share > 0 and entry.Distance <= range then
			table.insert(want, entry)
		end
	end
	table.sort(want, function(a, b)
		return a.Distance < b.Distance
	end)
	local on = {}
	for i = 1, math.min(budget, #want) do
		on[want[i]] = true
	end
	return on
end

local function make(class: string, props, parent: Instance?)
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end

-- How high over its root its plate sits: just over the top of its body.
local function lift(model: Model, root: BasePart): number
	local ok, box, size = pcall(function()
		return model:GetBoundingBox()
	end)
	if ok and box and size then
		return box.Position.Y + size.Y / 2 - root.Position.Y + 1.4
	end
	return root.Size.Y / 2 + 4
end

-- Its plate: the name over a level chip and the bar.
function WildBars.plate(model: Model, phone: boolean?): BillboardGui
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local size = if phone then WildBars.PhoneSize else WildBars.Size
	local W, H = size.X, size.Y
	-- (Laid out for the desktop plate, scaled to this one.)
	local k = H / WildBars.Size.Y
	local function px(n: number): number
		return math.max(1, math.floor(n * k + 0.5))
	end
	local plate = make("BillboardGui", {
		Name = "WildBar",
		Size = UDim2.fromOffset(W, H),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = WildBars.Range,
		ResetOnSpawn = false,
		Enabled = false,
	})
	if root then
		plate.Adornee = root
		plate.StudsOffsetWorldSpace = Vector3.new(0, lift(model, root :: BasePart), 0)
	end
	local name = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, px(17)),
		Font = Enum.Font.GothamBold,
		TextSize = px(14),
		TextColor3 = NAME,
		TextStrokeColor3 = INK,
		TextStrokeTransparency = 0.25,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextScaled = true,
		Text = model.Name,
	}, plate)
	-- (A long name, the guardian's, shrinks a little before it's cut short.)
	make("UITextSizeConstraint", { MaxTextSize = px(14), MinTextSize = math.min(px(14), if phone then 8 else 10) }, name)
	local level = make("Frame", {
		Name = "Level",
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, px(19)),
		Size = UDim2.fromOffset(px(38), px(15)),
	}, plate)
	make("UICorner", { CornerRadius = UDim.new(0, px(4)) }, level)
	make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = math.max(px(11), 8),
		TextColor3 = GOLD,
		Text = "Lv " .. tostring(model:GetAttribute("KaijuLevel") or 1),
	}, level)
	local back = make("Frame", {
		Name = "Back",
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(px(42), px(21)),
		Size = UDim2.new(1, -px(42), 0, px(11)),
	}, plate)
	make("UICorner", { CornerRadius = UDim.new(0, px(3)) }, back)
	make("UIStroke", { Name = "Edge", Color = EDGE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, back)
	make("Frame", {
		Name = "Trail",
		BackgroundColor3 = TRAIL,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, back)
	make("Frame", {
		Name = "Fill",
		BackgroundColor3 = BodyHealth.outlineColor(1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, back)
	return plate
end

-- Fills `plate` in: `share` of its health (the trail at `trail`, never
-- under it), gold for the guardian, a gold edge while it's being caught.
function WildBars.draw(plate: BillboardGui, share: number, trail: number, guardian: boolean?, catching: boolean?)
	local x = math.clamp(share, 0, 1)
	local back = plate:FindFirstChild("Back") :: Frame
	local fill = back:FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(x, 1)
	fill.BackgroundColor3 = BodyHealth.outlineColor(x)
	local behind = back:FindFirstChild("Trail") :: Frame
	behind.Size = UDim2.fromScale(math.max(x, math.clamp(trail, 0, 1)), 1)
	local edge = back:FindFirstChild("Edge") :: UIStroke
	edge.Color = if guardian or catching then GOLD else EDGE
	edge.Thickness = if catching then 2 else 1
	local name = plate:FindFirstChild("Title") :: TextLabel
	name.TextColor3 = if guardian then GOLD else NAME
end

type Entry = {
	Model: Model,
	Humanoid: Humanoid,
	Plate: BillboardGui,
	Share: number,
	Trail: number,
	HitAt: number,
	Shown: boolean,
}
local entries: { [Model]: Entry } = {}

-- A phone: touch and no keyboard, or a short screen.
local function onPhone(): boolean
	return WildBars.phone()
end
function WildBars.phone(): boolean
	local input = game:GetService("UserInputService")
	local camera = workspace.CurrentCamera
	local view = camera and camera.ViewportSize
	return (input.TouchEnabled and not input.KeyboardEnabled) or (view ~= nil and math.min(view.X, view.Y) < 500)
end

local function shareOf(humanoid: Humanoid): number
	if humanoid.MaxHealth <= 0 then
		return 0
	end
	return math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
end

local function redraw(entry: Entry)
	local model = entry.Model
	WildBars.draw(
		entry.Plate,
		entry.Share,
		entry.Trail,
		model:GetAttribute("KaijuGuardian") == true,
		model:GetAttribute("KaijuTameBy") ~= nil
	)
end

local function drop(model: Model)
	local entry = entries[model]
	if entry then
		entries[model] = nil
		entry.Plate:Destroy()
	end
end

-- Start drawing `model`'s plate (once; a wild kaiju only).
function WildBars.watch(model: Model)
	if entries[model] or model:GetAttribute("KaijuWild") == nil then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local Players = game:GetService("Players")
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local share = shareOf(humanoid)
	local entry: Entry = {
		Model = model,
		Humanoid = humanoid,
		Plate = WildBars.plate(model, onPhone()),
		Share = share,
		Trail = share,
		HitAt = 0,
		Shown = false,
	}
	entries[model] = entry
	redraw(entry)
	entry.Plate.Parent = playerGui
	humanoid.HealthChanged:Connect(function()
		local now = shareOf(humanoid)
		if now < entry.Share then
			entry.HitAt = os.clock()
		else
			entry.Trail = now -- (healed: nothing to drain)
		end
		entry.Share = now
		redraw(entry)
	end)
	for _, name in { "KaijuGuardian", "KaijuTameBy" } do
		model:GetAttributeChangedSignal(name):Connect(function()
			redraw(entry)
		end)
	end
	model:GetAttributeChangedSignal("KaijuLevel"):Connect(function()
		local chip = entry.Plate:FindFirstChild("Level")
		local text = chip and chip:FindFirstChild("Text")
		if text then
			(text :: TextLabel).Text = "Lv " .. tostring(model:GetAttribute("KaijuLevel") or 1)
		end
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			drop(model)
		end
	end)
end

local started = false
function WildBars.start()
	if started then
		return
	end
	started = true
	local RunService = game:GetService("RunService")
	local nextPick = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		-- The trails drain once a blow's had a moment to read.
		for _, entry in entries do
			if entry.Shown and entry.Trail > entry.Share and now - entry.HitAt >= WildBars.Hold then
				entry.Trail = math.max(entry.Share, entry.Trail - WildBars.Drain * dt)
				redraw(entry)
			end
		end
		local camera = workspace.CurrentCamera
		if now < nextPick or not camera then
			return
		end
		nextPick = now + WildBars.Every
		local eye = camera.CFrame.Position
		local list = {}
		for model, entry in entries do
			local root = model.PrimaryPart
			if root and model:IsDescendantOf(workspace) then
				table.insert(list, { Entry = entry, Distance = (root.Position - eye).Magnitude, Share = entry.Share })
			elseif not model:IsDescendantOf(workspace) then
				drop(model)
			end
		end
		local on = WildBars.choose(list, if onPhone() then WildBars.PhoneBudget else WildBars.Budget, WildBars.Range)
		for _, item in list do
			local show = on[item] == true
			if item.Entry.Shown ~= show then
				item.Entry.Shown = show
				item.Entry.Plate.Enabled = show
			end
		end
	end)
end

return WildBars
