--[[
	The frontier's rifts, drawn by each player's client. FrontierServer puts
	an invisible anchor in workspace.Rifts for each: where the tear hangs,
	facing whoever drew it, with OpenAt, HopAt, CloseAt, EndAt (server
	time), Seed, Height and Critter (what's coming through); a dormant one
	at a vein has Dormant instead of a timeline.

	A tear is a ragged rip in the air, never the same shape twice and never
	symmetrical (Shared.Frontier.tear): its two glowing lips, the other
	side's glowing violet between them and a white-hot heart inside that,
	all of it pulsing (Pulse: the lips swelling and whitening, the heart
	flaring, its light and its glow on the ground breathing with it), hair
	cracks running off its lips, the other side's stars seeping out. Bright,
	never a dark hole. Every critter portal, in the Outpost or in the Rift,
	wears the same violets (Palettes.Rift); only a vein's Rift Gate (a
	dormant one) burns the critters' world's colours (Palettes.Hell). It splits open from a hair crack, crackling (with
	its critter's own cue, so you know what's coming: CritterCues), flashes
	as the critter hops out, lingers, and seals with a snap. A dormant one
	only breathes, half open.

	  RiftTear.start()           watch workspace.Rifts (once)
	  RiftTear.step(serverNow)   animate them (OutpostScene, every frame)
	  RiftTear.layout(shape, open) -> lips   where its lips are, `open` 0..1 (pure)
	  RiftTear.pieces(shape, open, plane, now, crackle?, palette?) -> { piece }   every
	      part of it at that moment: { CFrame, Size, Color, Transparency }
	      (pure, so a test or a render can draw it too)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Frontier = require(ReplicatedStorage.Shared.Frontier)

local RiftTear = {}

RiftTear.Near = 220 -- studs: further off, a tear isn't animated
-- Its pulse: Rate beats a second; the lips Swell that much thicker and
-- whiten by Whiten at the top of it.
RiftTear.Pulse = { Rate = 0.9, Swell = 0.35, Whiten = 0.22 }
RiftTear.DormantRate = 15 -- times a second a dormant one breathes (an open one moves every frame)
local DEEP = Color3.fromRGB(110, 40, 210)
local VIOLET = Color3.fromRGB(180, 100, 255)
local MAGENTA = Color3.fromRGB(255, 70, 210)
local CYAN = Color3.fromRGB(80, 235, 255)
local WHITE = Color3.fromRGB(240, 235, 255)
local LIPS = { MAGENTA, VIOLET, CYAN, MAGENTA, WHITE, VIOLET, MAGENTA }
-- Its colours: the other side's violets; a vein's Rift Gate (its anchor's
-- Hell) burns the colours of the critters' world beyond it (Server.RiftWorld).
RiftTear.Palettes = {
	Rift = { Deep = DEEP, Heart = VIOLET, Lips = LIPS, Spark = WHITE, Stars = { MAGENTA, CYAN } },
	Hell = {
		Deep = Color3.fromRGB(150, 30, 8),
		Heart = Color3.fromRGB(255, 70, 20),
		Lips = {
			Color3.fromRGB(255, 120, 30),
			Color3.fromRGB(255, 56, 18),
			Color3.fromRGB(255, 176, 64),
			Color3.fromRGB(255, 120, 30),
			Color3.fromRGB(255, 226, 160),
			Color3.fromRGB(255, 56, 18),
			Color3.fromRGB(255, 120, 30),
		},
		Spark = Color3.fromRGB(255, 232, 180),
		Stars = { Color3.fromRGB(255, 96, 24), Color3.fromRGB(255, 190, 80) },
	},
}
-- Each critter's cue as its rift crackles (a CombatSound, its pitch): the
-- bonk of Sahur's bat, Tralalero's whoosh, Patapim's frost, the croc's bomb.
RiftTear.CritterCues = {
	Sahur = { "Block", 0.6 },
	Tralalero = { "Swing", 1.5 },
	Patapim = { "Freeze", 1.25 },
	Crocodilo = { "Blast", 0.7 },
}

-- Where its lips are, `open` (0 a hair crack, 1 wide open) of the way from
-- the crack they part along: { Left = { Vector2 }, Right = { Vector2 } }.
function RiftTear.layout(shape, open: number)
	local left, right = {}, {}
	for i, spine in shape.Spine do
		table.insert(left, spine:Lerp(shape.Left[i], open))
		table.insert(right, spine:Lerp(shape.Right[i], open))
	end
	return { Left = left, Right = right }
end

local tears = {} -- [anchor] = { Parts, Shape, ... }
-- Rifts not drawn yet: a tear is only built once you're near it (a few
-- dozen parts, a light and sparks each, for every rift in the Outpost on
-- every screen, was waste).
local waiting: { [BasePart]: boolean } = {}
local holder: Instance?
local started = false

local function sound(name: string, at: Vector3, volume: number?, pitch: number?)
	local ok, CombatSound = pcall(require, script.Parent.CombatSound)
	if ok and CombatSound then
		CombatSound.play(name, at, { Volume = volume or 0.8, Pitch = pitch })
	end
end

local function piece(model: Model, color: Color3, transparency: number?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Parent = model
	return p
end

-- A thin bar from `a` to `b` (points in the tear's plane), `z` in front.
local function bar(plane: CFrame, a: Vector2, b: Vector2, thickness: number, z: number): (CFrame, Vector3)
	local d = b - a
	local length = math.max(d.Magnitude, 0.02)
	local mid = (a + b) / 2
	return plane * CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)),
		Vector3.new(length + thickness * 0.6, thickness, thickness * 0.5)
end

-- A band of the other side between two rows of its lips: along the crack,
-- as wide as the lips are apart (times `share`).
local function band(
	plane: CFrame,
	l1: Vector2,
	r1: Vector2,
	l2: Vector2,
	r2: Vector2,
	share: number,
	z: number
): (CFrame, Vector3)
	local top, bottom = (l1 + r1) / 2, (l2 + r2) / 2
	local d = bottom - top
	local width = ((r1 - l1).Magnitude + (r2 - l2).Magnitude) / 2 * share
	local mid = (top + bottom) / 2
	return plane * CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X) + math.pi / 2),
		Vector3.new(math.max(width, 0.02), d.Magnitude + 0.12, 0.04)
end

-- Every part of a tear at `open` in `plane` (its anchor's CFrame, leaning
-- by its tilt): per row its left lip, right lip, the dark and its heart;
-- then its hair cracks. `crackle` (studs) jitters its lips; `now` makes its
-- heart flicker. Always the same count, in the same order.
function RiftTear.pieces(shape, open: number, plane: CFrame, now: number, crackle: number?, palette: any?)
	local colors = palette or RiftTear.Palettes.Rift
	local lips = RiftTear.layout(shape, open)
	local pulse = RiftTear.Pulse
	local beat = 0.5 + 0.5 * math.sin(now * pulse.Rate * math.pi * 2)
	local thick = math.max(0.08, 0.05 * shape.Height) * (0.6 + 0.4 * open) * (1 + pulse.Swell * beat)
	local white = pulse.Whiten * beat
	local hidden = open < 0.02
	local shake = crackle or 0
	local function jitter(v: Vector2): Vector2
		if shake <= 0 then
			return v
		end
		return v + Vector2.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake)
	end
	local list = {}
	local function add(cf: CFrame, size: Vector3, color: Color3, transparency: number)
		table.insert(list, { CFrame = cf, Size = size, Color = color, Transparency = transparency })
	end
	for i = 1, #shape.Spine - 1 do
		local l1, l2 = jitter(lips.Left[i]), jitter(lips.Left[i + 1])
		local r1, r2 = jitter(lips.Right[i]), jitter(lips.Right[i + 1])
		local cf, size = bar(plane, l1, l2, thick, -0.06)
		add(cf, size, colors.Lips[(i - 1) % #colors.Lips + 1]:Lerp(WHITE, white), if hidden then 1 else 0)
		cf, size = bar(plane, r1, r2, thick, -0.06)
		add(cf, size, colors.Lips[(i + 2) % #colors.Lips + 1]:Lerp(WHITE, white), if hidden then 1 else 0)
		cf, size = band(plane, l1, r1, l2, r2, 0.98, 0)
		add(cf, size, colors.Deep:Lerp(colors.Heart, 0.25 * beat), if hidden then 1 else 0.05 + 0.12 * (1 - beat))
		-- (Its heart flares with the pulse, and flickers.)
		cf, size = band(plane, l1, r1, l2, r2, 0.36 + 0.12 * beat, -0.03)
		add(cf, size, colors.Heart:Lerp(WHITE, 0.1 + 0.3 * beat), if hidden then 1 else 0.1 * math.abs(math.sin(now * 9 + i)))
	end
	for _, branch in shape.Branches do
		-- (Running off its lip, growing as it opens; now and then a flicker.)
		local from = if branch.Left then lips.Left[branch.Row] else lips.Right[branch.Row]
		local cf, size = bar(plane, from, from + (branch[2] - branch[1]) * open, 0.05, -0.05)
		add(cf, size, colors.Spark, if open < 0.2 then 1 elseif shake > 0 and math.random() < 0.15 then 0.75 else 0.15)
	end
	return list
end

local function build(anchor: BasePart)
	if tears[anchor] or not holder then
		return
	end
	local seed = anchor:GetAttribute("Seed")
	local height = anchor:GetAttribute("Height")
	if type(seed) ~= "number" or type(height) ~= "number" then
		return
	end
	local shape = Frontier.tear(seed, height)
	local model = Instance.new("Model")
	model.Name = "RiftTear"
	-- (Every critter portal in the same violets, the Rift's too; only a
	-- vein's Rift Gate, dormant, burns the critters' world's colours.)
	local dormant = anchor:GetAttribute("Dormant") == true
	local palette = if dormant and anchor:GetAttribute("Hell") then RiftTear.Palettes.Hell else RiftTear.Palettes.Rift
	local tear = {
		Anchor = anchor,
		Model = model,
		Shape = shape,
		Palette = palette,
		Dormant = dormant,
		Parts = {},
		Flashed = false,
		Snapped = false,
		Sounded = false,
	}
	for _, spec in RiftTear.pieces(shape, 1, CFrame.identity, 0, nil, palette) do
		table.insert(tear.Parts, piece(model, spec.Color, 1))
	end
	-- Its glow on the ground, and its light.
	tear.Floor = piece(model, palette.Heart, 0.7)
	tear.Floor.Shape = Enum.PartType.Cylinder
	local foot = anchor.Position - Vector3.new(0, height / 2 + 0.35, 0)
	tear.Floor.Size = Vector3.new(0.06, height * 0.9, height * 0.9)
	tear.Floor.CFrame = CFrame.new(foot) * CFrame.Angles(0, 0, math.pi / 2)
	local light = Instance.new("PointLight")
	light.Color = palette.Heart
	light.Range = height * 2.2
	light.Brightness = 0
	light.Shadows = false
	light.Parent = tear.Parts[math.max(1, (math.ceil(#shape.Spine / 2) - 1) * 4 + 3)]
	tear.Light = light
	-- The other side's stars, seeping out toward whoever drew it.
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, palette.Stars[1]),
		ColorSequenceKeypoint.new(0.5, palette.Stars[2]),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 214, 120)),
	})
	stars.LightEmission = 1
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	stars.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	stars.Lifetime = NumberRange.new(0.6, 1.3)
	stars.Speed = NumberRange.new(1.5, 4.5)
	stars.SpreadAngle = Vector2.new(60, 60)
	stars.EmissionDirection = Enum.NormalId.Front
	stars.Rate = 0
	stars.Parent = attachment
	tear.Stars, tear.Attachment = stars, attachment
	model.Parent = holder
	tears[anchor] = tear
end

local function drop(anchor: Instance)
	waiting[anchor :: BasePart] = nil
	local tear = tears[anchor]
	if tear then
		tears[anchor] = nil
		tear.Model:Destroy()
		tear.Attachment:Destroy()
	end
end

-- A quick flash at `at` (the critter hopping out, or the tear snapping shut).
local function flash(at: CFrame, size: Vector3, grow: number)
	if not holder then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = WHITE
	p.Shape = Enum.PartType.Ball
	p.Size = size
	p.CFrame = at
	p.Parent = holder
	local TweenService = game:GetService("TweenService")
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = size * grow,
		Transparency = 1,
	}):Play()
	game:GetService("Debris"):AddItem(p, 0.35)
end

local function animate(tear, now: number)
	local anchor = tear.Anchor
	local shape = tear.Shape
	local open
	if tear.Dormant then
		-- (Breathing, half open: a rift that never quite closes.)
		open = 0.38 + 0.08 * math.sin(now * 1.3 + shape.Height) + 0.04 * math.sin(now * 3.1)
	else
		local life = {
			OpenAt = anchor:GetAttribute("OpenAt") or 0,
			HopAt = anchor:GetAttribute("HopAt") or 0,
			CloseAt = anchor:GetAttribute("CloseAt") or 0,
			EndAt = anchor:GetAttribute("EndAt") or 0,
		}
		open = Frontier.openness(life, now)
		local at = anchor.Position
		if not tear.Sounded and now >= life.OpenAt then
			tear.Sounded = true
			sound("NovaWarn", at, 0.6)
			local cue = RiftTear.CritterCues[anchor:GetAttribute("Critter") or ""]
			if cue then
				sound(cue[1], at, 0.9, cue[2])
			end
		end
		if not tear.Flashed and now >= life.HopAt then
			tear.Flashed = true
			flash(anchor.CFrame, Vector3.one * shape.Height * 0.25, 4)
			sound("Zap", at, 0.8)
		end
		if not tear.Snapped and now >= life.EndAt - 0.06 then
			tear.Snapped = true
			flash(anchor.CFrame, Vector3.new(0.25, shape.Height * 0.6, 0.25), 2.5)
		end
	end
	-- Crackling while it splits and seals: its lips jitter.
	local crackle = if open > 0 and open < 0.98 and not tear.Dormant then 0.035 * shape.Height else 0.008 * shape.Height
	local plane = anchor.CFrame * CFrame.Angles(0, 0, shape.Tilt)
	for k, spec in RiftTear.pieces(shape, open, plane, now, crackle, tear.Palette) do
		local part = tear.Parts[k]
		part.Size, part.CFrame, part.Transparency = spec.Size, spec.CFrame, spec.Transparency
	end
	-- Its glow on the ground and its light breathe with its pulse.
	local beat = 0.5 + 0.5 * math.sin(now * RiftTear.Pulse.Rate * math.pi * 2)
	tear.Floor.Transparency = 1 - (0.4 + 0.25 * beat) * open
	local glow = (if tear.Dormant then 1.6 else 3 * open) * (0.7 + 0.6 * beat)
	tear.Light.Brightness = glow
	local rate = if tear.Dormant then 12 else 50 * open
	if tear.Stars.Rate ~= rate then
		tear.Stars.Rate = rate
	end
end

function RiftTear.step(serverNow: number)
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for anchor in waiting do
		if not anchor.Parent then
			waiting[anchor] = nil
		elseif (anchor.Position - eye).Magnitude <= RiftTear.Near then
			build(anchor)
			if tears[anchor] then
				waiting[anchor] = nil
			end
		end
	end
	for anchor, tear in tears do
		if not anchor.Parent then
			drop(anchor)
		else
			local near = (anchor.Position - eye).Magnitude <= RiftTear.Near
			if near ~= tear.Near then
				tear.Near = near
				tear.Model.Parent = if near then holder else nil
				tear.Stars.Enabled = near
			end
			if near and (not tear.Dormant or serverNow >= (tear.NextAt or 0)) then
				tear.NextAt = serverNow + 1 / RiftTear.DormantRate
				animate(tear, serverNow)
			end
		end
	end
end

function RiftTear.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local rifts = workspace:WaitForChild("Rifts", 120)
		if not rifts then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "RiftTears"
		folder.Parent = workspace
		holder = folder
		-- (Built in `step` once near: its attributes may land a moment after it does.)
		local function added(child: Instance)
			if child:IsA("BasePart") then
				waiting[child] = true
			end
		end
		rifts.ChildAdded:Connect(added)
		rifts.ChildRemoved:Connect(drop)
		for _, child in rifts:GetChildren() do
			added(child)
		end
	end)
end

return RiftTear
