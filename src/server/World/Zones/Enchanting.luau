-- Zone 4: Enchanting Building.
-- An octagonal stone chamber under a stepped roof. Neon arcane runes pulse on
-- the floor and walls, and floating containment fields hold gems around a
-- central altar where gems are fused onto gear.
local Tags = require(game:GetService("ReplicatedStorage").Shared.Tags)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local RADIUS = 22
local HEIGHT = 22
local CENTER = Vector3.new(0, 0, RADIUS + 2)

local Enchanting = {}

-- Area the zone occupies in its local space, kept clear of trees and flowers.
Enchanting.Footprint = { MinX = -28, MaxX = 28, MinZ = -4, MaxZ = 52 }

-- Octagon corner k; the side between corners 0 and 1 faces the plaza.
local function corner(k: number): Vector3
	local angle = math.rad(-22.5 + 45 * k)
	return CENTER + Vector3.new(RADIUS * math.sin(angle), 0, -RADIUS * math.cos(angle))
end

local function rune(folder: Folder, origin: CFrame, frame: CFrame, scale: number, phase: number, color: Color3)
	local strokes = {
		{ Size = Vector3.new(0.35, 5, 0.2), At = CFrame.identity },
		{ Size = Vector3.new(3, 0.35, 0.2), At = CFrame.new(0, 1.2, 0) },
		{ Size = Vector3.new(0.35, 3, 0.2), At = CFrame.new(0.8, -0.8, 0) * CFrame.Angles(0, 0, math.rad(35)) },
		{ Size = Vector3.new(0.35, 1.6, 0.2), At = CFrame.new(-0.9, -1.4, 0) * CFrame.Angles(0, 0, math.rad(-40)) },
	}
	for _, stroke in strokes do
		local part = Builder.neon(
			folder,
			origin,
			stroke.Size * Vector3.new(scale, scale, 1),
			frame * CFrame.new(stroke.At.Position * scale) * stroke.At.Rotation,
			color,
			nil,
			Tags.ArcaneRune
		)
		part:SetAttribute("Phase", phase)
	end
end

local function chamber(folder: Folder, origin: CFrame, color: Color3)
	Builder.disc(folder, origin, {
		Name = "ChamberFloor",
		Radius = RADIUS + 1,
		At = CFrame.new(CENTER + Vector3.new(0, -0.4, 0)),
		Color = C.DarkStone,
		Material = Enum.Material.Slate,
	})
	Builder.part(folder, origin, {
		Name = "Landing",
		Size = Vector3.new(14, 1, 4),
		At = CFrame.new(0, -0.4, 2),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})

	local props = { Thickness = 2, Color = C.Stone, Battlements = true, Trim = color }
	for k = 0, 7 do
		local a, b = corner(k), corner(k + 1)
		if k == 0 then
			Builder.wallWithDoor(folder, origin, a.X, a.Z, b.X, b.Z, HEIGHT, 8, 11, props)
		else
			Builder.wall(folder, origin, a.X, a.Z, b.X, b.Z, HEIGHT, props)

			-- A glowing rune on the inside face of each wall.
			local mid = (a + b) / 2
			local inward = (CENTER - mid).Unit
			local position = mid + inward * 1.15 + Vector3.new(0, 10, 0)
			local glyph = CFrame.lookAt(position, CENTER + Vector3.new(0, 10, 0))
			rune(folder, origin, glyph, 1.2, k, color)
			Builder.light(
				Builder.neon(folder, origin, Vector3.new(0.4, 0.4, 0.2), glyph * CFrame.new(0, 3.8, 0), color),
				color,
				16,
				1.5
			)
		end
		Builder.pillar(folder, origin, a.X, a.Z, HEIGHT + 3, color, { Width = 3, Color = C.WornStone })
	end

	-- Stepped roof topped by a spinning soul crystal.
	for i, radius in { RADIUS + 1, 17, 11, 5 } do
		local y = HEIGHT + i - 1
		Builder.disc(folder, origin, {
			Name = "Roof",
			Radius = radius,
			At = CFrame.new(CENTER + Vector3.new(0, y + 0.5, 0)),
			Color = C.DarkStone,
			Material = Enum.Material.Slate,
		})
		Builder.neonBand(folder, origin, CENTER + Vector3.new(0, y + 0.5, 0), radius, color)
	end
	Builder.part(folder, origin, {
		Name = "Spire",
		Size = Vector3.new(1.5, 8, 1.5),
		At = CFrame.new(CENTER + Vector3.new(0, HEIGHT + 7, 0)),
		Color = C.Chrome,
		Material = Enum.Material.Metal,
	})
	Builder.neon(
		folder,
		origin,
		Vector3.new(3, 3, 3),
		CFrame.new(CENTER + Vector3.new(0, HEIGHT + 13, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		color,
		nil,
		Tags.Spin
	)

	Builder.sign(folder, origin, CFrame.new(0, 14, 2.35), Vector3.new(14, 2.6, 0.6), "ARCANUM // ENCHANT", color)
end

local function altar(folder: Folder, origin: CFrame, color: Color3)
	Builder.disc(folder, origin, {
		Name = "AltarBase",
		Radius = 3.5,
		Height = 3,
		At = CFrame.new(CENTER + Vector3.new(0, 1.5, 0)),
		Color = C.WornStone,
		Material = Enum.Material.Cobblestone,
	})
	local top = Builder.disc(folder, origin, {
		Name = "EnchantAltar",
		Radius = 4,
		Height = 0.6,
		At = CFrame.new(CENTER + Vector3.new(0, 3.3, 0)),
		Color = C.Chrome,
		Material = Enum.Material.Metal,
		Tag = Tags.EnchantAltar,
	})
	Builder.prompt(top, "Fuse Gem", "Enchanting Altar")
	Builder.neonBand(folder, origin, CENTER + Vector3.new(0, 3.3, 0), 4, color)
	Builder.neon(
		folder,
		origin,
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(CENTER + Vector3.new(0, 6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		C.Cyan,
		30,
		Tags.Spin
	)

	-- Floor runes circling the altar.
	Builder.neonRing(folder, origin, CENTER + Vector3.new(0, 0.15, 0), 7, 28, color, 0.3)
	Builder.neonRing(folder, origin, CENTER + Vector3.new(0, 0.15, 0), 13, 24, color, 0.3)
	for i = 0, 9 do
		local angle = i / 10 * 2 * math.pi
		local flat = CFrame.new(CENTER + Vector3.new(0, 0.15, 0))
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0, -10)
			* CFrame.Angles(math.rad(-90), 0, 0)
		rune(folder, origin, flat, 0.6, i, color)
	end
end

local function containmentFields(folder: Folder, origin: CFrame, color: Color3)
	local gemColors = { C.Cyan, C.Magenta, C.Amber }
	for i, angleDeg in { 60, 180, 300 } do
		local angle = math.rad(angleDeg)
		local position = CENTER + Vector3.new(8 * math.sin(angle), 0, -8 * math.cos(angle))

		Builder.disc(folder, origin, {
			Name = "FieldEmitter",
			Radius = 1.5,
			Height = 3,
			At = CFrame.new(position + Vector3.new(0, 1.5, 0)),
			Color = C.Iron,
			Material = Enum.Material.Metal,
		})
		Builder.neonBand(folder, origin, position + Vector3.new(0, 2.7, 0), 1.5, color)

		local fieldCF = CFrame.new(position + Vector3.new(0, 7, 0))
		Builder.part(folder, origin, {
			Name = "ContainmentField",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(4, 4, 4),
			At = fieldCF,
			Color = color,
			Material = Enum.Material.ForceField,
			CanCollide = false,
			CastShadow = false,
			Tag = Tags.ContainmentField,
		})
		Builder.neon(
			folder,
			origin,
			Vector3.new(1.2, 1.2, 1.2),
			fieldCF * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			gemColors[i],
			12,
			Tags.ContainmentField
		)
	end
end

function Enchanting.build(folder: Folder, origin: CFrame, color: Color3)
	chamber(folder, origin, color)
	altar(folder, origin, color)
	containmentFields(folder, origin, color)
end

return Enchanting
