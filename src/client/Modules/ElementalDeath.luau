--[[
	A fighter killed by an element dies in that element's style. The body is
	copied piece by piece (a local stand-in; the real one is hidden) and
	taken apart:

	  Fire    the armour chars and catches light, then blows apart in a
	          fireball, burning pieces flung out trailing smoke
	  Shock   the body locks up crackling with arcs, flashes white, then
	          bursts in a storm of sparks
	  Poison  it melts: plates turn acid green and slump into a spreading
	          puddle, bubbling, then the remains burst
	  Frost   frozen solid in a shell of ice, spikes growing out, a beat of
	          stillness, then it shatters into flying shards

	The element is the last one that hit it (the server keeps it on the
	model as "LastHitElement"). Purely local and short-lived.

	  ElementalDeath.play(model, element) -> true when it ran
	  ElementalDeath.start()               players' bodies too (on death)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CombatFx = require(script.Parent.CombatFx)
local CombatSound = require(script.Parent.CombatSound)
local CombatVfx = require(script.Parent.CombatVfx)

local ElementalDeath = {}
ElementalDeath.MaxPieces = 140

local played = setmetatable({}, { __mode = "k" }) -- [model] = true, once each

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "ElementalDeaths"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function tween(object: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function neon(size: Vector3, cframe: CFrame, color: Color3, transparency: number, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.Neon
	part.Color, part.Size, part.Transparency = color, size, transparency
	if shape then
		part.Shape = shape
	end
	part.CFrame = cframe
	part.Parent = fxFolder()
	return part
end

-- The stand-in: a local copy of every visible piece, largest first, with the
-- real body hidden. Each piece remembers where it started.
local function copyBody(model: Model)
	local sources = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "HumanoidRootPart" then
			table.insert(sources, d)
		end
	end
	table.sort(sources, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	local holder = Instance.new("Model")
	holder.Name = "Remains"
	holder.Parent = fxFolder()
	local pieces = {}
	for i, source in sources do
		source.LocalTransparencyModifier = 1
		if i <= ElementalDeath.MaxPieces then
			local ok, copy = pcall(function()
				return source:Clone()
			end)
			if ok and copy then
				for _, child in copy:GetChildren() do
					if not child:IsA("DataModelMesh") then
						child:Destroy()
					end
				end
				copy.Anchored = true
				copy.CanCollide, copy.CanQuery, copy.CanTouch = false, false, false
				copy.Massless = true
				copy.LocalTransparencyModifier = 0
				copy.CFrame = source.CFrame
				copy.Parent = holder
				table.insert(pieces, { Part = copy, Home = source.CFrame, Color = source.Color })
			end
		end
	end
	Debris:AddItem(holder, 4)
	return pieces, holder
end

local function centreOf(pieces, model: Model): (Vector3, number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local centre = if root then root.Position else (pieces[1] and pieces[1].Part.Position or Vector3.zero)
	local floor = centre.Y - 3
	for _, piece in pieces do
		floor = math.min(floor, piece.Part.Position.Y - piece.Part.Size.Y / 2)
	end
	return centre, floor
end

-- Every piece flies outward from `centre` (and stops being anchored).
local function blowApart(pieces, centre: Vector3, speed: NumberRange, lift: number)
	for _, piece in pieces do
		local part = piece.Part
		if part.Parent then
			local out = part.Position - centre
			out = Vector3.new(out.X, math.max(out.Y, 0) + 0.3, out.Z)
			if out.Magnitude < 0.05 then
				out = Vector3.new(math.random() - 0.5, 1, math.random() - 0.5)
			end
			part.CanCollide = true
			part.Anchored = false
			part.AssemblyLinearVelocity = out.Unit * (speed.Min + math.random() * (speed.Max - speed.Min))
				+ Vector3.new(0, lift * (0.6 + math.random() * 0.8), 0)
			part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
				* 24
		end
	end
end

local function fadeOut(pieces, after: number, seconds: number)
	task.delay(after, function()
		for _, piece in pieces do
			if piece.Part.Parent then
				tween(piece.Part, seconds, { Transparency = 1 })
			end
		end
	end)
end

local function ring(at: Vector3, color: Color3, radius: number, seconds: number)
	local disc = neon(
		Vector3.new(0.12, 1, 1),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		0.15,
		Enum.PartType.Cylinder
	)
	tween(disc, seconds, { Size = Vector3.new(0.05, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(disc, seconds + 0.1)
end

local function ball(at: Vector3, color: Color3, radius: number, seconds: number)
	local sphere = neon(Vector3.one * 1.5, CFrame.new(at), color, 0.05, Enum.PartType.Ball)
	tween(sphere, seconds, { Size = Vector3.one * radius * 2, Transparency = 1 })
	Debris:AddItem(sphere, seconds + 0.1)
end

-- The elements ------------------------------------------------------------------------------------

local STYLES = {}

function STYLES.Fire(pieces, centre: Vector3, floor: number)
	local orange = GemConfig.ElementColors.Fire:Lerp(Color3.fromRGB(255, 150, 40), 0.5)
	-- Catching light: the armour glows hot, flames climb the body.
	for _, piece in pieces do
		tween(piece.Part, 0.4, { Color = piece.Color:Lerp(orange, 0.65) })
	end
	local flames = neon(Vector3.new(2, 4, 1), CFrame.new(centre), orange, 1)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 9, 18, orange, Color3.fromRGB(255, 60, 20)
	fire.Parent = flames
	Debris:AddItem(flames, 2.5)
	CombatFx.flash(centre, orange, 4, 18, 0.45)
	CombatSound.element("Cast", "Fire", centre)
	task.wait(0.45)
	-- The blast.
	CombatSound.play("Death", centre)
	CombatSound.element("Impact", "Fire", centre, { Volume = 1.2 })
	CombatFx.flash(centre, orange, 10, 40, 0.7)
	CombatFx.burst(centre, orange, "Embers", 2.4)
	CombatFx.burst(centre, Color3.fromRGB(255, 220, 140), "Sparks", 2)
	CombatFx.shake(0.5, 0.35)
	ball(centre, orange, 9, 0.55)
	ball(centre, Color3.fromRGB(255, 240, 200), 5, 0.3)
	ring(Vector3.new(centre.X, floor + 0.1, centre.Z), orange, 16, 0.6)
	CombatVfx.scorch(Vector3.new(centre.X, floor, centre.Z), 6, orange)
	blowApart(pieces, centre, NumberRange.new(28, 48), 26)
	for i, piece in pieces do
		tween(piece.Part, 1.4, { Color = Color3.fromRGB(38, 28, 24) })
		if i % 7 == 1 then
			local burn = Instance.new("Fire")
			burn.Size, burn.Heat, burn.Color = 2.5, 4, orange
			burn.Parent = piece.Part
			local smoke = Instance.new("Smoke")
			smoke.Size, smoke.Opacity, smoke.RiseVelocity = 1.5, 0.15, 3
			smoke.Color = Color3.fromRGB(60, 50, 45)
			smoke.Parent = piece.Part
		end
	end
	fadeOut(pieces, 1.9, 0.8)
end

function STYLES.Shock(pieces, centre: Vector3, floor: number)
	local ion = GemConfig.ElementColors.Shock
	local white = Color3.fromRGB(235, 245, 255)
	-- Locked up, crackling: pieces twitch and flash, arcs leap across the body.
	local started = os.clock()
	local step = 0
	while os.clock() - started < 0.55 do
		step += 1
		for _, piece in pieces do
			local part = piece.Part
			if math.random() < 0.35 then
				part.Material = Enum.Material.Neon
				part.Color = if math.random() < 0.5 then white else ion
			else
				part.Material = Enum.Material.SmoothPlastic
				part.Color = piece.Color:Lerp(ion, 0.35)
			end
			local jitter = 0.18
			part.CFrame = piece.Home
				* CFrame.new(
					(math.random() - 0.5) * jitter,
					(math.random() - 0.5) * jitter,
					(math.random() - 0.5) * jitter
				)
		end
		if step % 2 == 1 and #pieces > 1 then
			local a = pieces[math.random(1, #pieces)].Part.Position
			local b = pieces[math.random(1, #pieces)].Part.Position
			CombatVfx.lightning(a, b + (b - a).Unit * 2, if math.random() < 0.5 then ion else white)
		end
		if step % 3 == 1 then
			CombatSound.play("Zap", centre, { Volume = 0.6 })
		end
		task.wait(0.05)
	end
	-- The burst.
	CombatSound.play("Death", centre)
	CombatSound.element("Impact", "Shock", centre, { Volume = 1.2 })
	CombatFx.flash(centre, white, 12, 40, 0.5)
	CombatFx.burst(centre, ion, "Sparks", 2.8)
	CombatFx.shake(0.45, 0.3)
	ball(centre, white, 7, 0.35)
	ring(Vector3.new(centre.X, floor + 0.1, centre.Z), ion, 18, 0.5)
	for _ = 1, 6 do
		local out = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5)
		if out.Magnitude > 0.05 then
			CombatVfx.lightning(centre, centre + out.Unit * (8 + math.random() * 8), ion)
		end
	end
	blowApart(pieces, centre, NumberRange.new(30, 52), 22)
	for _, piece in pieces do
		piece.Part.Material = Enum.Material.SmoothPlastic
		tween(piece.Part, 1.2, { Color = Color3.fromRGB(34, 36, 44) })
	end
	fadeOut(pieces, 1.7, 0.8)
end

function STYLES.Poison(pieces, centre: Vector3, floor: number)
	local acid = GemConfig.ElementColors.Poison
	-- Melting: plates go acid green and slump into a spreading puddle.
	local puddle = neon(
		Vector3.new(0.1, 1, 1),
		CFrame.new(centre.X, floor + 0.06, centre.Z) * CFrame.Angles(0, 0, math.rad(90)),
		acid,
		0.25,
		Enum.PartType.Cylinder
	)
	tween(puddle, 1.1, { Size = Vector3.new(0.1, 11, 11) })
	Debris:AddItem(puddle, 3.2)
	task.delay(2.2, function()
		if puddle.Parent then
			tween(puddle, 0.9, { Transparency = 1 })
		end
	end)
	CombatSound.element("Cast", "Poison", centre)
	for _, piece in pieces do
		local part = piece.Part
		local height = part.Position.Y - floor
		local drop = height * (0.75 + math.random() * 0.2)
		local spread = Vector3.new(part.Position.X - centre.X, 0, part.Position.Z - centre.Z) * 0.6
		tween(part, 1.0, {
			Color = piece.Color:Lerp(acid, 0.75),
			Size = Vector3.new(part.Size.X * 1.25, part.Size.Y * 0.35, part.Size.Z * 1.25),
			CFrame = part.CFrame + Vector3.new(spread.X, -drop, spread.Z),
		}, Enum.EasingStyle.Sine)
	end
	for _ = 1, 5 do
		CombatFx.burst(centre - Vector3.new(0, 2, 0), acid, "Embers", 0.8)
		task.wait(0.2)
	end
	-- The remains burst.
	local low = Vector3.new(centre.X, floor + 0.8, centre.Z)
	CombatSound.play("Death", low)
	CombatSound.element("Impact", "Poison", low, { Volume = 1.2 })
	CombatFx.flash(low, acid, 8, 30, 0.5)
	CombatFx.burst(low, acid, "Embers", 2.4)
	CombatFx.shake(0.35, 0.3)
	ball(low, acid, 7, 0.45)
	blowApart(pieces, low, NumberRange.new(14, 26), 30)
	fadeOut(pieces, 1.2, 0.8)
end

function STYLES.Frost(pieces, centre: Vector3, floor: number)
	local ice = Color3.fromRGB(196, 236, 255)
	local deep = GemConfig.ElementColors.Frost
	-- Frozen solid: an ice shell, spikes growing out, a beat of stillness.
	for _, piece in pieces do
		local part = piece.Part
		part.Material = Enum.Material.Ice
		tween(part, 0.25, { Color = piece.Color:Lerp(ice, 0.8), Transparency = 0.12 })
	end
	CombatSound.element("Cast", "Frost", centre)
	CombatFx.burst(centre, deep, "Frost", 1.8)
	CombatFx.flash(centre, deep, 4, 20, 0.6)
	local spikes = {}
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2
		local tilt = CFrame.Angles(math.rad(25 + math.random() * 30), angle, 0)
		local base = CFrame.new(centre + Vector3.new(0, (math.random() - 0.4) * 3, 0)) * tilt
		local spike = neon(Vector3.new(0.5, 0.2, 0.5), base, ice, 0.2)
		spike.Material = Enum.Material.Glass
		tween(
			spike,
			0.3,
			{ Size = Vector3.new(0.6, 2.4 + math.random() * 1.6, 0.6), CFrame = base * CFrame.new(0, 1.4, 0) }
		)
		table.insert(spikes, spike)
		Debris:AddItem(spike, 3)
	end
	task.wait(0.7)
	-- Shatter.
	CombatSound.play("Death", centre)
	CombatSound.element("Impact", "Frost", centre, { Volume = 1.3 })
	CombatFx.flash(centre, ice, 10, 36, 0.45)
	CombatFx.burst(centre, ice, "Shards", 2.6)
	CombatFx.shake(0.45, 0.3)
	ring(Vector3.new(centre.X, floor + 0.1, centre.Z), deep, 15, 0.5)
	-- Extra splinters from the biggest pieces.
	for i = 1, math.min(#pieces, 24) do
		local source = pieces[i].Part
		for _ = 1, 2 do
			local shard = neon(
				Vector3.new(0.25, 0.25 + math.random() * 0.6, 0.25),
				source.CFrame
					* CFrame.new((math.random() - 0.5) * source.Size.X, (math.random() - 0.5) * source.Size.Y, 0),
				ice,
				0.15
			)
			shard.Material = Enum.Material.Glass
			table.insert(pieces, { Part = shard, Home = shard.CFrame, Color = ice })
		end
	end
	for _, spike in spikes do
		table.insert(pieces, { Part = spike, Home = spike.CFrame, Color = ice })
	end
	blowApart(pieces, centre, NumberRange.new(24, 44), 18)
	fadeOut(pieces, 1.3, 0.9)
end

-- Plays `element`'s death on `model`; false (and nothing done) for an
-- element without one.
function ElementalDeath.play(model: Model?, element: string?): boolean
	local style = element and STYLES[element]
	if not style or not model or not model.Parent or played[model] then
		return false
	end
	played[model] = true
	local pieces, _ = copyBody(model)
	if #pieces == 0 then
		return false
	end
	local centre, floor = centreOf(pieces, model)
	task.spawn(style, pieces, centre, floor)
	return true
end

-- Players' bodies too (a duel, the Arena, a dungeon): on death, the last
-- element that hit them.
local started = false
function ElementalDeath.start()
	if started then
		return
	end
	started = true
	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				ElementalDeath.play(character, character:GetAttribute("LastHitElement"))
			end)
		end
	end
	local function track(player: Player)
		if player.Character then
			task.spawn(watch, player.Character)
		end
		player.CharacterAdded:Connect(watch)
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
end

return ElementalDeath
