--[[
	Health shown on the body, not over it. The Outpost's creatures (your
	kaiju and other players', wild kaiju, a rift's critters) carry no bar or
	name over their heads: in a fight those piled up over the action. Each
	one's body tells how it's doing instead:

	  outlined  a glowing outline round its body in its health's colour:
	            green when it's well, amber as it's worn down, red when it's
	            nearly done (Outline). A wild kaiju is always outlined, and
	            seen through rocks, so you can find one and see at a glance
	            how far it is from being caught; so is a critter running off
	            with a gem (CarryingGem: a gem raid), so you can chase it;
	            anything else once it's hurt. Roblox draws 31 outlines at most, so only Outline.Budget
	            are, the wild kaiju first, then the nearest hurt ones; one
	            glowing gold to be caught (KaijuTaming) keeps its gold
	  hurt      its colours sink a little toward a scorched red-black as its
	            health drops (none at full health, Dark of the way at none);
	            a heal brings them back
	  struck    a white flash on every blow that lands, its outline flaring
	  in danger below Low it smokes, a dark wisp off its back, till it's
	            healed or gone

	Glowing parts (Neon: eyes, element glows) keep their light, so a kaiju
	still reads as its element. Only what's on this screen changes: the
	server's colours are never touched.

	A player mending in the lobby (HealthRegen's LobbyMend on them, after a
	critter's or a wild kaiju's scrape) gives off a soft green shimmer.

	  BodyHealth.watch(model)        start showing it (once: KaijuHud's scan
	                                 hands it each creature it finds)
	  BodyHealth.start()             the outlines and the mending shimmer, a
	                                 few times a second
	  BodyHealth.mend(character, on) its shimmer on or off
	  BodyHealth.step(eye)           pick and colour the outlines (start's tick)
	  BodyHealth.tint(share) -> 0..Dark   how far its colours sink (pure)
	  BodyHealth.smokes(share) -> boolean (pure)
	  BodyHealth.outlineColor(share) -> Color3   (pure)
	  BodyHealth.choose(entries, budget) -> { [entry]: true }   which get an
	                                 outline: entries are { Wild, Hurt,
	                                 Distance, Held } (pure)
	  BodyHealth.Wound, Dark, Low, Flash, Outline
]]
local BodyHealth = {}

BodyHealth.Wound = Color3.fromRGB(62, 18, 16) -- what a body sinks toward
BodyHealth.Dark = 0.3 -- how far, at no health left (the outline says the rest)
BodyHealth.Low = 0.3 -- smoking below this share
BodyHealth.Flash = { Color = Color3.new(1, 1, 1), Amount = 0.7, Seconds = 0.08 }
BodyHealth.Outline = {
	Good = Color3.fromRGB(96, 236, 120), -- well
	Warn = Color3.fromRGB(255, 196, 64), -- worn down (Warn share and under)
	Bad = Color3.fromRGB(255, 64, 52), -- nearly done (Bad share and under)
	WarnAt = 0.6,
	BadAt = 0.3,
	Fill = 0.86, -- its fill's transparency (a wash of the colour)
	Flare = 0.4, -- the fill on a blow, for a moment
	Budget = 10, -- outlined at once, at most (Roblox draws 31 in all)
	Range = 150, -- studs from the camera: further, none
	WildRange = 320, -- a wild kaiju's (seen through rocks)
	Every = 0.25, -- seconds between picks
}

-- How far its colours sink at `share` of its health: the first blows show
-- (a curve, not a line), the last ones most.
function BodyHealth.tint(share: number): number
	return BodyHealth.Dark * (1 - math.clamp(share, 0, 1)) ^ 0.75
end

function BodyHealth.smokes(share: number): boolean
	return share > 0 and share < BodyHealth.Low
end

-- Its outline's colour at `share` of its health: green, through amber
-- (WarnAt) to red (BadAt and under).
function BodyHealth.outlineColor(share: number): Color3
	local o = BodyHealth.Outline
	local x = math.clamp(share, 0, 1)
	if x >= o.WarnAt then
		return o.Warn:Lerp(o.Good, (x - o.WarnAt) / (1 - o.WarnAt))
	elseif x >= o.BadAt then
		return o.Bad:Lerp(o.Warn, (x - o.BadAt) / (o.WarnAt - o.BadAt))
	end
	return o.Bad
end

-- Which of `entries` ({ Wild, Hurt, Distance, Held }) get an outline:
-- the wild kaiju first, then the nearest hurt ones, `budget` in all. One
-- held in gold (KaijuTaming's glow) or well and tame gets none.
function BodyHealth.choose(entries, budget: number): { [any]: boolean }
	local o = BodyHealth.Outline
	local want = {}
	for _, entry in entries do
		local range = if entry.Wild then o.WildRange else o.Range
		if not entry.Held and (entry.Wild or entry.Hurt) and entry.Distance <= range then
			table.insert(want, entry)
		end
	end
	table.sort(want, function(a, b)
		if (a.Wild == true) ~= (b.Wild == true) then
			return a.Wild == true
		end
		return a.Distance < b.Distance
	end)
	local on = {}
	for i = 1, math.min(budget, #want) do
		on[want[i]] = true
	end
	return on
end

type Entry = {
	Model: Model,
	Humanoid: Humanoid,
	Base: { [BasePart]: Color3 },
	Share: number,
	Flash: number, -- (which flash is the latest, so an old one doesn't end a new one)
	Smoke: ParticleEmitter?,
	Outline: Highlight?, -- while it's outlined
	Flare: number, -- (which flare is the latest)
	Connections: { RBXScriptConnection },
}
local entries: { [Model]: Entry } = {}
-- (Glows keep their light: eyes, element glows, see-through shells.)
local function glows(part: BasePart): boolean
	local material = part.Material
	return material == Enum.Material.Neon or material == Enum.Material.ForceField or material == Enum.Material.Glass
end

local function shareOf(humanoid: Humanoid): number
	return if humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) else 1
end

local function paint(entry: Entry, flash: number?)
	local amount = BodyHealth.tint(entry.Share)
	for part, base in entry.Base do
		local color = if amount > 0 then base:Lerp(BodyHealth.Wound, amount) else base
		if flash then
			color = color:Lerp(BodyHealth.Flash.Color, flash)
		end
		if part.Color ~= color then
			part.Color = color
		end
	end
end

local function learn(entry: Entry, part: Instance)
	if not part:IsA("BasePart") or entry.Base[part] or part.Name == "HumanoidRootPart" then
		return
	end
	if part.Transparency >= 0.95 or glows(part) then
		return
	end
	entry.Base[part] = part.Color
	local amount = BodyHealth.tint(entry.Share)
	if amount > 0 then
		part.Color = part.Color:Lerp(BodyHealth.Wound, amount)
	end
end

-- A dark wisp off its back, sized to it.
local function smoke(entry: Entry): ParticleEmitter?
	local root = entry.Model.PrimaryPart or entry.Model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local size = math.clamp(root.Size.Magnitude * 0.35, 0.8, 6)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BodyHealthSmoke"
	attachment.Position = Vector3.new(0, root.Size.Y * 0.5, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(70, 36, 32), Color3.fromRGB(28, 24, 26))
	emitter.LightEmission = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.6) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.9, 1.4)
	emitter.Rate = 7
	emitter.Speed = NumberRange.new(size * 0.8, size * 1.4)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Acceleration = Vector3.new(0, size * 0.6, 0)
	emitter.Enabled = false
	emitter.Parent = attachment
	return emitter
end

-- Its outline, in its health's colour (flaring a moment on a blow).
local function outline(entry: Entry, struck: boolean?)
	local highlight = entry.Outline
	if not highlight then
		return
	end
	local color = BodyHealth.outlineColor(entry.Share)
	highlight.OutlineColor, highlight.FillColor = color, color
	if struck then
		entry.Flare += 1
		local this = entry.Flare
		highlight.FillTransparency = BodyHealth.Outline.Flare
		task.delay(BodyHealth.Flash.Seconds * 2, function()
			if entry.Outline == highlight and entry.Flare == this then
				highlight.FillTransparency = BodyHealth.Outline.Fill
			end
		end)
	end
end

local function changed(entry: Entry)
	local share = shareOf(entry.Humanoid)
	local struck = share < entry.Share - 1e-3
	entry.Share = share
	outline(entry, struck)
	if struck then
		entry.Flash += 1
		local this = entry.Flash
		paint(entry, BodyHealth.Flash.Amount)
		task.delay(BodyHealth.Flash.Seconds, function()
			if entries[entry.Model] == entry and entry.Flash == this then
				paint(entry)
			end
		end)
	else
		paint(entry)
	end
	local want = BodyHealth.smokes(share)
	if want and not entry.Smoke then
		entry.Smoke = smoke(entry)
	end
	if entry.Smoke and entry.Smoke.Enabled ~= want then
		entry.Smoke.Enabled = want
	end
end

local function forget(model: Model)
	local entry = entries[model]
	if not entry then
		return
	end
	entries[model] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	-- (Its own colours back, should it come back.)
	for part, base in entry.Base do
		part.Color = base
	end
	if entry.Smoke and entry.Smoke.Parent then
		entry.Smoke.Parent:Destroy()
	end
	if entry.Outline then
		entry.Outline:Destroy()
		entry.Outline = nil
	end
end

function BodyHealth.watch(model: Model)
	if entries[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local entry: Entry = {
		Model = model,
		Humanoid = humanoid,
		Base = {},
		Share = shareOf(humanoid),
		Flash = 0,
		Smoke = nil,
		Outline = nil,
		Flare = 0,
		Connections = {},
	}
	entries[model] = entry
	for _, part in model:GetDescendants() do
		learn(entry, part)
	end
	table.insert(entry.Connections, model.DescendantAdded:Connect(function(part)
		learn(entry, part) -- (streaming brings the rest of a body in)
	end))
	table.insert(entry.Connections, humanoid.HealthChanged:Connect(function()
		changed(entry)
	end))
	table.insert(entry.Connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			forget(model)
		end
	end))
	changed(entry)
end

-- Outlines --------------------------------------------------------------------------------------------

local function rootPosition(model: Model): Vector3?
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function addOutline(entry: Entry, wild: boolean)
	local highlight = Instance.new("Highlight")
	highlight.Name = "BodyHealthOutline"
	highlight.Adornee = entry.Model
	highlight.FillTransparency = BodyHealth.Outline.Fill
	highlight.OutlineTransparency = 0
	-- (A wild kaiju's shows through rocks: you can find one.)
	highlight.DepthMode = if wild then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
	highlight.Parent = entry.Model
	entry.Outline = highlight
	outline(entry)
end

-- Which creatures are outlined, from where the camera is (`eye`): the
-- wild kaiju, then the nearest hurt ones, Outline.Budget in all.
function BodyHealth.step(eye: Vector3)
	local list = {}
	for model, entry in entries do
		local at = rootPosition(model)
		if at and entry.Share > 0 then
			table.insert(list, {
				Entry = entry,
				-- (A wild kaiju, or a snatcher with a gem: seen through rocks.)
				Wild = model:GetAttribute("KaijuWild") ~= nil or model:GetAttribute("CarryingGem") ~= nil,
				Hurt = entry.Share < 0.995,
				Distance = (at - eye).Magnitude,
				-- (Glowing gold to be caught: its gold says it all.)
				Held = model:FindFirstChild("TameReady") ~= nil,
			})
		end
	end
	local on = BodyHealth.choose(list, BodyHealth.Outline.Budget)
	for _, item in list do
		local entry = item.Entry
		if on[item] and not entry.Outline then
			addOutline(entry, item.Wild)
		elseif on[item] and entry.Outline then
			local depth = if item.Wild then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
			if entry.Outline.DepthMode ~= depth then
				entry.Outline.DepthMode = depth -- (it picked up a gem, or let go)
			end
		elseif not on[item] and entry.Outline then
			entry.Outline:Destroy()
			entry.Outline = nil
		end
	end
	-- (Gone from the list, down or without a body: no outline either.)
	for model, entry in entries do
		if entry.Outline and (entry.Share <= 0 or not rootPosition(model)) then
			entry.Outline:Destroy()
			entry.Outline = nil
		end
	end
end

-- Mending ---------------------------------------------------------------------------------------------

BodyHealth.Mend = Color3.fromRGB(120, 245, 160)
local mends: { [Model]: ParticleEmitter } = {}

-- A soft green shimmer rising off a player mending in the lobby.
function BodyHealth.mend(character: Model, on: boolean)
	local emitter = mends[character]
	if on and not emitter then
		local root = character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			return
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "BodyHealthMend"
		attachment.Position = Vector3.new(0, -1, 0)
		attachment.Parent = root
		emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(BodyHealth.Mend, Color3.fromRGB(200, 255, 215))
		emitter.LightEmission = 0.7
		emitter.LightInfluence = 0
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.28),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.8, 1.3)
		emitter.Rate = 9
		emitter.Speed = NumberRange.new(2, 3.5)
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Parent = attachment
		mends[character] = emitter
	end
	if emitter then
		emitter.Enabled = on
		if not on and not character:IsDescendantOf(workspace) then
			mends[character] = nil
			if emitter.Parent then
				emitter.Parent:Destroy()
			end
		end
	end
end

local started = false
function BodyHealth.start()
	if started then
		return
	end
	started = true
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local nextStep = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local camera = workspace.CurrentCamera
		if now < nextStep or not camera then
			return
		end
		nextStep = now + BodyHealth.Outline.Every
		BodyHealth.step(camera.CFrame.Position)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				BodyHealth.mend(character, player:GetAttribute("LobbyMend") == true)
			end
		end
		for character in mends do
			if not character:IsDescendantOf(workspace) then
				BodyHealth.mend(character, false)
			end
		end
	end)
end

return BodyHealth
