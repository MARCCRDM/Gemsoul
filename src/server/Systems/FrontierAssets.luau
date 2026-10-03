-- Shared geometry builders for runtime equipment and offline asset previews.
local Assets = {}
local dark = Color3.fromRGB(30, 38, 52)
local steel = Color3.fromRGB(166, 190, 205)
local gold = Color3.fromRGB(218, 164, 70)

local function part(folder, anchor, mount, at, size, color, material)
	local p = Instance.new("Part")
	p.Name = "Gear"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CFrame = anchor.CFrame * mount * at
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Massless = true
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 0.5
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = anchor, p, p
	p.Parent = folder
	return p
end

-- Preserve the compact pistol silhouette and the original barrel/socket mount.
-- The same builder is used by equipped weapons and item previews.
function Assets.sidearm(folder, hand, mount, rarity, accent, finish)
	rarity = math.clamp(rarity or 1, 1, 5)
	local function add(x, y, z, sx, sy, sz, color, material)
		return part(folder, hand, mount, CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, material)
	end
	add(0, 0, -0.06, 0.2, 0.3, 0.48, dark)
	add(0, 0.28, 0.23, 0.28, 0.76, 0.27, Color3.fromRGB(118, 132, 146))
	local muzzle = part(
		folder,
		hand,
		mount,
		CFrame.new(0, 0.73, 0.23) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.18, 0.23, 0.23),
		dark,
		Enum.Material.Metal
	)
	muzzle.Shape = Enum.PartType.Cylinder
	add(0, 0.3, 0.39, 0.09, 0.15, 0.045, accent)
	-- Inset muzzle, barrel spine, rear sight and grip heel.
	local bore = part(
		folder,
		hand,
		mount,
		CFrame.new(0, 0.827, 0.23) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.025, 0.12, 0.12),
		Color3.fromRGB(8, 12, 18),
		Enum.Material.Metal
	)
	bore.Shape = Enum.PartType.Cylinder
	add(0, 0.32, 0.08, 0.12, 0.53, 0.045, dark)
	add(0, 0.58, 0.065, 0.1, 0.07, 0.07, steel)
	add(0, -0.14, -0.06, 0.23, 0.055, 0.42, dark)
	if rarity >= 2 then
		for _, side in { -1, 1 } do
			add(side * 0.151, 0.26, 0.23, 0.025, 0.42, 0.16, finish)
			for i = 1, 2 do
				add(side * 0.11, -0.1 + i * 0.09, -0.08, 0.025, 0.025, 0.28, steel)
			end
		end
	end
	if rarity >= 3 then
		for _, side in { -1, 1 } do
			for i = 1, 3 do
				add(side * 0.168, 0.34 + i * 0.07, 0.23, 0.025, 0.028, 0.13, dark)
			end
			add(side * 0.168, 0.12, 0.23, 0.03, 0.055, 0.055, steel, Enum.Material.Metal)
		end
	end
	if rarity >= 4 then
		for _, side in { -1, 1 } do
			add(side * 0.17, 0.26, 0.23, 0.025, 0.14, 0.035, accent, Enum.Material.Neon)
		end
		add(0, 0.59, 0.075, 0.045, 0.025, 0.04, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for _, side in { -1, 1 } do
			add(side * 0.153, 0.28, 0.13, 0.03, 0.4, 0.025, gold, Enum.Material.Metal)
			add(side * 0.153, 0.28, 0.33, 0.03, 0.4, 0.025, gold, Enum.Material.Metal)
		end
		add(0, -0.18, -0.06, 0.17, 0.025, 0.28, gold, Enum.Material.Metal)
	end
end

function Assets.sword(folder, hand, mount, rarity, accent, finish)
	rarity = math.clamp(rarity or 1, 1, 5)
	local function add(x, y, z, sx, sy, sz, color, material)
		return part(folder, hand, mount, CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, material)
	end
	-- Wrapped grip, balanced guard, broad fuller, and stepped cutting tip.
	add(0, 0, 0, 0.2, 0.65, 0.22, dark)
	add(0, -0.38, 0, 0.29, 0.15, 0.28, finish)
	add(0, 0.38, 0, 0.82, 0.14, 0.26, finish)
	add(0, 1.6, 0, 0.32, 2.3, 0.12, steel, Enum.Material.Metal)
	add(0, 1.56, -0.07, 0.1, 2.12, 0.035, dark)
	-- Metal edge bevels and a ferrule separate blade, guard and grip.
	for _, side in { -1, 1 } do
		add(side * 0.147, 1.6, 0, 0.026, 2.25, 0.14, steel, Enum.Material.Metal)
	end
	add(0, 0.49, 0, 0.36, 0.11, 0.16, dark)
	for step = 1, 4 do
		add(0, 2.72 + step * 0.09, 0, 0.32 - step * 0.06, 0.1, 0.12, steel, Enum.Material.Metal)
	end
	if rarity >= 2 then
		for _, face in { -1, 1 } do
			add(0, 0.38, face * 0.145, 0.12, 0.065, 0.025, steel, Enum.Material.Metal)
		end
		for i = -1, 1 do
			add(0, i * 0.18, 0, 0.23, 0.045, 0.25, finish)
		end
		for _, side in { -1, 1 } do
			add(side * 0.4, 0.45, 0, 0.13, 0.3, 0.28, dark)
		end
	end
	if rarity >= 3 then
		for _, face in { -1, 1 } do
			add(0, 0.67, face * 0.092, 0.19, 0.15, 0.025, finish)
		end
		for _, side in { -1, 1 } do
			add(side * 0.19, 0.83, 0, 0.09, 0.65, 0.15, finish)
			add(side * 0.28, 0.49, -0.16, 0.12, 0.1, 0.05, steel)
		end
	end
	if rarity >= 4 then
		for _, side in { -1, 1 } do
			add(0, 1.6, side * 0.085, 0.045, 1.8, 0.025, accent, Enum.Material.Neon)
		end
		add(0, -0.4, -0.16, 0.12, 0.07, 0.04, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for _, face in { -1, 1 } do
			add(0, -0.38, face * 0.16, 0.13, 0.07, 0.025, gold, Enum.Material.Metal)
		end
		for _, side in { -1, 1 } do
			add(side * 0.48, 0.48, 0, 0.1, 0.4, 0.2, gold, Enum.Material.Metal)
			for i = 1, 3 do
				add(side * 0.1, 0.55 + i * 0.32, -0.09, 0.08, 0.045, 0.025, gold)
			end
		end
	end
end

function Assets.shield(folder, arm, mount, rarity, accent, finish, family)
	rarity = math.clamp(rarity or 1, 1, 5)
	local function add(x, y, z, sx, sy, sz, color, material)
		return part(folder, arm, mount, CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, material)
	end
	-- Corner locking tabs and lower rank inlays leave the central gem unobstructed.
	for _, side in { -1, 1 } do
		add(side * 0.48, -0.53, -0.235, 0.12, 0.16, 0.055, dark)
		add(side * 0.48, -0.53, -0.27, 0.055, 0.07, 0.025, steel, Enum.Material.Metal)
		if rarity >= 3 then
			for rank = 1, rarity - 2 do
				add(
					side * (0.13 + rank * 0.085),
					-0.72,
					-0.225,
					0.035,
					0.09,
					0.025,
					if rarity == 5 then gold else steel,
					Enum.Material.Metal
				)
			end
		end
	end

	if rarity >= 2 then
		for _, side in { -1, 1 } do
			local fitting = add(side * 0.27, 0.54, -0.235, 0.17, 0.11, 0.035, dark)
			if family == "Skirmisher" then
				fitting.CFrame *= CFrame.Angles(0, 0, math.rad(side * 25))
			end
			add(side * 0.27, 0.54, -0.26, 0.09, 0.035, 0.02, if rarity == 5 then gold else steel, Enum.Material.Metal)
		end
	end

	-- Stepped kite silhouette replaces the smooth oval; plates float over a dark frame.
	if family == "Prospector" then
		for _, side in { -1, 1 } do
			add(side * 0.69, 0.15, 0.02, 0.12, 0.62, 0.18, steel)
		end
	elseif family == "Skirmisher" then
		for _, side in { -1, 1 } do
			add(side * 0.67, 0.42, -0.08, 0.04, 0.88, 0.05, accent)
		end
	elseif family == "Juggernaut" then
		add(0, 0.86, 0, 1.46, 0.16, 0.36, steel)
		for _, side in { -1, 1 } do
			add(side * 0.69, -0.1, 0.02, 0.15, 1.16, 0.3, finish)
		end
	end
	add(0, 0.18, 0, 1.35, 1.55, 0.22, dark)
	add(0, -0.7, 0, 0.95, 0.3, 0.22, dark)
	add(0, -0.92, 0, 0.55, 0.16, 0.22, dark)
	add(0, 0.16, -0.14, 1.15, 1.38, 0.12, finish)
	add(0, -0.63, -0.14, 0.76, 0.25, 0.12, finish)
	-- Recessed central socket housing; leave the gemstone's face clear.
	add(0, 0.1, -0.215, 0.46, 0.48, 0.035, dark)
	add(0, -0.43, -0.215, 0.65, 0.035, 0.035, steel)
	for _, side in { -1, 1 } do
		add(side * 0.46, 0.7, -0.22, 0.055, 0.055, 0.035, steel, Enum.Material.Metal)
	end
	if rarity >= 2 then
		for _, side in { -1, 1 } do
			add(side * 0.47, -0.38, -0.22, 0.055, 0.055, 0.035, steel, Enum.Material.Metal)
		end
		for _, side in { -1, 1 } do
			add(side * 0.59, 0.16, -0.19, 0.065, 1.35, 0.07, steel)
		end
		add(0, 0.83, -0.19, 1.23, 0.065, 0.07, steel)
	end
	if rarity >= 3 then
		add(0, 0.69, -0.225, 0.67, 0.075, 0.055, dark)
		add(0, -0.63, -0.235, 0.38, 0.08, 0.055, steel)
		for _, side in { -1, 1 } do
			add(side * 0.4, 0.1, -0.24, 0.26, 0.85, 0.1, dark)
			for i = 1, 3 do
				add(side * 0.4, i * 0.2 - 0.3, -0.3, 0.16, 0.055, 0.035, steel)
			end
		end
	end
	if rarity >= 4 then
		add(0, -0.47, -0.25, 0.29, 0.035, 0.025, accent, Enum.Material.Neon)
		for _, side in { -1, 1 } do
			add(side * 0.54, 0.17, -0.25, 0.035, 0.98, 0.035, accent, Enum.Material.Neon)
		end
		add(0, 0.59, -0.23, 0.34, 0.045, 0.04, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for _, side in { -1, 1 } do
			add(side * 0.15, 0.39, -0.245, 0.045, 0.23, 0.035, gold, Enum.Material.Metal)
		end
		for _, side in { -1, 1 } do
			add(side * 0.64, 0.73, -0.15, 0.17, 0.39, 0.15, gold)
			add(side * 0.27, -0.63, -0.25, 0.08, 0.25, 0.08, gold)
		end
		add(0, -0.83, -0.18, 0.32, 0.12, 0.09, gold)
	end
end

--[[
	The Forge's weapons (Shared.WeaponForge), in the sword's frame: the grip
	at the hand, the weapon running out along +Y, its face towards -Z. Every
	rarity adds to the last:
	  Uncommon   finish-coloured trims and wraps
	  Rare       extra plates, spikes and a heavier silhouette
	  Epic       glowing accent edges (the gem's colour)
	  Legendary  gold filigree and a lit energy core
	Assets.forge(kind, folder, hand, mount, rarity, accent, finish) builds
	one hand's weapon ("TwinBlades" is built once per hand).
]]
-- `tilt`: degrees about Z, turning a piece in the weapon's face (for curves,
-- flares and slanted tips).
local function adder(folder, hand, mount)
	return function(x, y, z, sx, sy, sz, color, material, tilt)
		local at = CFrame.new(x, y, z)
		if tilt then
			at *= CFrame.Angles(0, 0, math.rad(tilt))
		end
		return part(folder, hand, mount, at, Vector3.new(sx, sy, sz), color, material)
	end
end

-- A lit core: a neon cell with a glow, for the Legendary tier.
local function core(add, x, y, z, size, accent)
	local cell = add(x, y, z, size, size, size, accent, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = accent, 7, 1.4
	light.Parent = cell
	return cell
end

local FORGE = {}

-- A broad chopping blade with a notched spine.
function FORGE.Cleaver(add, rarity, accent, finish)
	add(0, 0, 0, 0.2, 0.7, 0.22, dark)
	add(0, -0.42, 0, 0.28, 0.16, 0.28, finish)
	add(0, 0.42, 0, 0.92, 0.16, 0.3, finish)
	add(0.04, 1.5, 0, 0.62, 2.05, 0.12, steel, Enum.Material.Metal)
	add(-0.28, 1.45, 0, 0.1, 1.8, 0.16, dark) -- the spine
	add(0.36, 1.5, 0, 0.05, 2.0, 0.08, steel, Enum.Material.Metal) -- the edge
	add(0.1, 2.6, 0, 0.66, 0.34, 0.12, steel, Enum.Material.Metal, -28) -- a slanted chisel tip
	add(0.33, 2.62, 0, 0.05, 0.5, 0.08, steel, Enum.Material.Metal, -28)
	for i = 1, 3 do
		add(-0.3, 0.75 + i * 0.4, 0, 0.12, 0.1, 0.18, steel) -- spine notches
	end
	if rarity >= 2 then
		for i = -1, 1 do
			add(0, i * 0.2, 0, 0.23, 0.05, 0.25, finish)
		end
		add(0.04, 1.4, -0.07, 0.36, 1.5, 0.03, finish)
	end
	if rarity >= 3 then
		for _, side in { -1, 1 } do
			add(side * 0.52, 0.5, 0, 0.14, 0.32, 0.22, dark)
		end
		add(-0.42, 2.3, 0, 0.16, 0.5, 0.1, steel, Enum.Material.Metal) -- a back hook
	end
	if rarity >= 4 then
		add(0.39, 1.5, 0, 0.03, 1.9, 0.1, accent, Enum.Material.Neon)
		add(0.04, 1.4, -0.09, 0.06, 1.4, 0.02, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for _, side in { -1, 1 } do
			add(side * 0.48, 0.42, 0, 0.1, 0.24, 0.32, gold, Enum.Material.Metal)
		end
		add(0, -0.56, 0, 0.18, 0.12, 0.18, gold, Enum.Material.Metal)
		core(add, 0.04, 0.9, -0.1, 0.16, accent)
	end
end

-- A short, hooked blade (one per hand).
function FORGE.TwinBlades(add, rarity, accent, finish)
	add(0, 0, 0, 0.18, 0.55, 0.2, dark)
	add(0, -0.34, 0, 0.22, 0.12, 0.22, finish)
	add(0, 0.33, 0, 0.5, 0.12, 0.24, finish)
	-- A blade that sweeps forward as it rises, to a hooked point.
	add(0, 0.72, 0, 0.26, 0.62, 0.1, steel, Enum.Material.Metal)
	add(0.06, 1.25, 0, 0.26, 0.6, 0.1, steel, Enum.Material.Metal, -10)
	add(0.18, 1.74, 0, 0.24, 0.56, 0.1, steel, Enum.Material.Metal, -22)
	add(0.33, 2.08, 0, 0.14, 0.34, 0.09, steel, Enum.Material.Metal, -38)
	add(0.14, 0.72, 0, 0.04, 0.6, 0.07, steel, Enum.Material.Metal)
	add(0.2, 1.24, 0, 0.04, 0.58, 0.07, steel, Enum.Material.Metal, -10)
	add(0.31, 1.71, 0, 0.04, 0.54, 0.07, steel, Enum.Material.Metal, -22)
	add(-0.2, 0.62, 0, 0.16, 0.3, 0.08, steel) -- the back hook
	if rarity >= 2 then
		add(0, 0.1, 0, 0.21, 0.05, 0.23, finish)
		add(0, -0.12, 0, 0.21, 0.05, 0.23, finish)
	end
	if rarity >= 3 then
		add(-0.12, 1.3, 0, 0.12, 0.42, 0.08, steel, Enum.Material.Metal, -14) -- a second hook
		add(0.26, 0.05, 0, 0.06, 0.62, 0.1, finish) -- a knuckle guard
		add(0, 0.33, -0.14, 0.3, 0.08, 0.05, dark)
	end
	if rarity >= 4 then
		add(0.165, 0.72, 0, 0.025, 0.56, 0.08, accent, Enum.Material.Neon)
		add(0.225, 1.24, 0, 0.025, 0.54, 0.08, accent, Enum.Material.Neon, -10)
		add(0.335, 1.7, 0, 0.025, 0.5, 0.08, accent, Enum.Material.Neon, -22)
	end
	if rarity >= 5 then
		add(0, 0.33, 0, 0.6, 0.08, 0.27, gold, Enum.Material.Metal)
		core(add, 0, 0.62, -0.08, 0.1, accent)
	end
end

-- A long shaft with a broad spearhead and wings.
function FORGE.Lance(add, rarity, accent, finish)
	add(0, 0.9, 0, 0.16, 4.2, 0.16, dark)
	add(0, -1.25, 0, 0.22, 0.2, 0.22, finish)
	add(0, 3.05, 0, 0.7, 0.12, 0.16, finish) -- the wings
	-- A leaf-shaped head: broad at the base, tapering to the point.
	add(0, 3.35, 0, 0.42, 0.5, 0.12, steel, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		add(side * 0.1, 3.82, 0, 0.2, 0.62, 0.11, steel, Enum.Material.Metal, side * 14)
	end
	add(0, 4.18, 0, 0.1, 0.28, 0.08, steel, Enum.Material.Metal)
	for _, y in { 0.35, 2.4 } do
		add(0, y, 0, 0.21, 0.12, 0.21, steel, Enum.Material.Metal)
	end
	if rarity >= 2 then
		for i = 0, 3 do
			add(0, -0.25 + i * 0.16, 0, 0.19, 0.06, 0.19, finish)
		end
	end
	if rarity >= 3 then
		for _, side in { -1, 1 } do
			add(side * 0.42, 3.2, 0, 0.12, 0.42, 0.1, steel, Enum.Material.Metal, -side * 30)
		end
		add(0, 2.85, -0.12, 0.28, 0.3, 0.05, finish) -- a pennant plate
	end
	if rarity >= 4 then
		add(0, 3.5, -0.075, 0.05, 0.7, 0.03, accent, Enum.Material.Neon)
		add(0, 1.6, -0.09, 0.04, 1.4, 0.02, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for i = 0, 3 do
			add(0, 1.2 + i * 0.3, 0, 0.24, 0.05, 0.24, gold, Enum.Material.Metal)
		end
		core(add, 0, 3.05, -0.1, 0.14, accent)
	end
end

-- A long haft with a double-bitted head.
function FORGE.Greataxe(add, rarity, accent, finish)
	add(0, 0.8, 0, 0.18, 3.4, 0.18, dark)
	add(0, -0.95, 0, 0.24, 0.16, 0.24, finish)
	add(0, 2.25, 0, 0.32, 0.6, 0.26, finish) -- the eye
	-- Two crescent bits flaring up and down from narrow necks.
	for _, side in { -1, 1 } do
		add(side * 0.36, 2.25, 0, 0.42, 0.5, 0.1, steel, Enum.Material.Metal)
		add(side * 0.74, 2.25, 0, 0.36, 1.05, 0.1, steel, Enum.Material.Metal)
		add(side * 0.8, 2.78, 0, 0.3, 0.5, 0.1, steel, Enum.Material.Metal, -side * 28)
		add(side * 0.8, 1.72, 0, 0.3, 0.5, 0.1, steel, Enum.Material.Metal, side * 28)
		add(side * 0.94, 2.25, 0, 0.06, 1.1, 0.08, steel, Enum.Material.Metal) -- the edge
		add(side * 0.98, 2.84, 0, 0.06, 0.5, 0.07, steel, Enum.Material.Metal, -side * 28)
		add(side * 0.98, 1.66, 0, 0.06, 0.5, 0.07, steel, Enum.Material.Metal, side * 28)
		add(side * 0.25, 2.25, 0, 0.18, 0.6, 0.13, dark)
	end
	add(0, 2.7, 0, 0.12, 0.35, 0.12, steel, Enum.Material.Metal) -- the top spike
	if rarity >= 2 then
		for i = 0, 2 do
			add(0, 0.05 + i * 0.18, 0, 0.21, 0.06, 0.21, finish)
		end
	end
	if rarity >= 3 then
		add(0, 1.85, 0, 0.12, 0.3, 0.12, steel, Enum.Material.Metal) -- a beard spike
		for _, side in { -1, 1 } do
			add(side * 0.55, 2.25, -0.07, 0.12, 0.7, 0.03, dark) -- rivet strips
		end
	end
	if rarity >= 4 then
		for _, side in { -1, 1 } do
			add(side * 0.99, 2.25, 0, 0.025, 1.05, 0.09, accent, Enum.Material.Neon)
			add(side * 1.03, 2.86, 0, 0.025, 0.46, 0.08, accent, Enum.Material.Neon, -side * 28)
			add(side * 1.03, 1.64, 0, 0.025, 0.46, 0.08, accent, Enum.Material.Neon, side * 28)
		end
	end
	if rarity >= 5 then
		for _, side in { -1, 1 } do
			add(side * 0.55, 2.25, -0.06, 0.5, 0.08, 0.02, gold, Enum.Material.Metal)
		end
		core(add, 0, 2.25, -0.15, 0.16, accent)
	end
end

-- A heavy haft with a piston-capped head.
function FORGE.Warhammer(add, rarity, accent, finish)
	add(0, 0.75, 0, 0.2, 3.0, 0.2, dark)
	add(0, -0.82, 0, 0.26, 0.18, 0.26, finish)
	add(0, 2.35, 0, 1.25, 0.7, 0.7, steel, Enum.Material.Metal) -- the head
	for _, side in { -1, 1 } do
		add(side * 0.68, 2.35, 0, 0.14, 0.82, 0.82, finish) -- the faces
	end
	add(0, 2.35, 0, 0.5, 0.74, 0.74, dark) -- a band round the middle
	if rarity >= 2 then
		for i = 0, 2 do
			add(0, 0.0 + i * 0.18, 0, 0.23, 0.06, 0.23, finish)
		end
	end
	if rarity >= 3 then
		add(0, 2.85, 0, 0.18, 0.36, 0.18, steel, Enum.Material.Metal) -- a top spike
		for _, side in { -1, 1 } do
			add(side * 0.4, 2.35, -0.38, 0.12, 0.5, 0.06, dark) -- pistons
		end
	end
	if rarity >= 4 then
		for _, side in { -1, 1 } do
			add(side * 0.76, 2.35, 0, 0.03, 0.6, 0.6, accent, Enum.Material.Neon)
		end
	end
	if rarity >= 5 then
		for _, side in { -1, 1 } do
			add(side * 0.25, 2.35, 0, 0.06, 0.78, 0.78, gold, Enum.Material.Metal)
		end
		core(add, 0, 2.35, -0.38, 0.2, accent)
	end
end

-- Where its gem socket sits, in the same frame.
Assets.ForgeSockets = {
	Cleaver = Vector3.new(0, 0.42, -0.18),
	TwinBlades = Vector3.new(0, 0.33, -0.15),
	Lance = Vector3.new(0, 3.05, 0.12),
	Greataxe = Vector3.new(0, 2.25, 0.16),
	Warhammer = Vector3.new(0, 2.35, 0.38),
}

function Assets.forge(kind: string, folder, hand, mount, rarity, accent, finish)
	local build = FORGE[kind]
	if not build then
		return false
	end
	build(adder(folder, hand, mount), math.clamp(rarity or 1, 1, 5), accent, finish)
	return true
end

return Assets
