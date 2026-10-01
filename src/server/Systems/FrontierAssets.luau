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
	for step = 1, 4 do
		add(0, 2.72 + step * 0.09, 0, 0.32 - step * 0.06, 0.1, 0.12, steel, Enum.Material.Metal)
	end
	if rarity >= 2 then
		for i = -1, 1 do
			add(0, i * 0.18, 0, 0.23, 0.045, 0.25, finish)
		end
		for _, side in { -1, 1 } do
			add(side * 0.4, 0.45, 0, 0.13, 0.3, 0.28, dark)
		end
	end
	if rarity >= 3 then
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
		for _, side in { -1, 1 } do
			add(side * 0.48, 0.48, 0, 0.1, 0.4, 0.2, gold, Enum.Material.Metal)
			for i = 1, 3 do
				add(side * 0.1, 0.55 + i * 0.32, -0.09, 0.08, 0.045, 0.025, gold)
			end
		end
	end
end

function Assets.shield(folder, arm, mount, rarity, accent, finish)
	rarity = math.clamp(rarity or 1, 1, 5)
	local function add(x, y, z, sx, sy, sz, color, material)
		return part(folder, arm, mount, CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, material)
	end
	-- Stepped kite silhouette replaces the smooth oval; plates float over a dark frame.
	add(0, 0.18, 0, 1.35, 1.55, 0.22, dark)
	add(0, -0.7, 0, 0.95, 0.3, 0.22, dark)
	add(0, -0.92, 0, 0.55, 0.16, 0.22, dark)
	add(0, 0.16, -0.14, 1.15, 1.38, 0.12, finish)
	add(0, -0.63, -0.14, 0.76, 0.25, 0.12, finish)
	if rarity >= 2 then
		for _, side in { -1, 1 } do
			add(side * 0.59, 0.16, -0.19, 0.065, 1.35, 0.07, steel)
		end
		add(0, 0.83, -0.19, 1.23, 0.065, 0.07, steel)
	end
	if rarity >= 3 then
		for _, side in { -1, 1 } do
			add(side * 0.4, 0.1, -0.24, 0.26, 0.85, 0.1, dark)
			for i = 1, 3 do
				add(side * 0.4, i * 0.2 - 0.3, -0.3, 0.16, 0.055, 0.035, steel)
			end
		end
	end
	if rarity >= 4 then
		for _, side in { -1, 1 } do
			add(side * 0.54, 0.17, -0.25, 0.035, 0.98, 0.035, accent, Enum.Material.Neon)
		end
		add(0, 0.59, -0.23, 0.34, 0.045, 0.04, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for _, side in { -1, 1 } do
			add(side * 0.64, 0.73, -0.15, 0.17, 0.39, 0.15, gold)
			add(side * 0.27, -0.63, -0.25, 0.08, 0.25, 0.08, gold)
		end
		add(0, -0.83, -0.18, 0.32, 0.12, 0.09, gold)
	end
end

return Assets
