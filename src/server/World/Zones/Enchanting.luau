-- Enchanting tower at the end of the east road: an octagonal stone tower
-- with pulsing arcane runes on its walls and a stepped purple roof. Floating
-- containment fields flank the door where Vey the Arcanist waits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.Builder)

local C = Builder.Colors

local RADIUS = 13
local HEIGHT = 22
local CENTER = Vector3.new(0, 0, RADIUS + 1)

local Enchanting = {}

-- Octagon corner k; the side between corners 0 and 1 faces the street.
local function corner(k: number): Vector3
	local angle = math.rad(-22.5 + 45 * k)
	return CENTER + Vector3.new(RADIUS * math.sin(angle), 0, -RADIUS * math.cos(angle))
end

local function rune(folder: Folder, frame: CFrame, glyph: CFrame, phase: number, color: Color3)
	local strokes = {
		{ Size = Vector3.new(0.35, 4, 0.2), At = CFrame.identity },
		{ Size = Vector3.new(2.4, 0.35, 0.2), At = CFrame.new(0, 1, 0) },
		{ Size = Vector3.new(0.35, 2.4, 0.2), At = CFrame.new(0.6, -0.7, 0) * CFrame.Angles(0, 0, math.rad(35)) },
		{ Size = Vector3.new(0.35, 1.3, 0.2), At = CFrame.new(-0.7, -1.1, 0) * CFrame.Angles(0, 0, math.rad(-40)) },
	}
	for _, stroke in strokes do
		local part = Builder.neon(folder, frame, stroke.Size, glyph * stroke.At, color, nil, Tags.ArcaneRune)
		part:SetAttribute("Phase", phase)
	end
end

local function containmentField(folder: Folder, frame: CFrame, gemColor: Color3, color: Color3)
	Builder.disc(folder, frame, {
		Name = "FieldEmitter",
		Radius = 1.3,
		Height = 3,
		At = CFrame.new(0, 1.5, 0),
		Color = C.Iron,
		Material = Enum.Material.Metal,
	})
	Builder.neonBand(folder, frame, Vector3.new(0, 2.7, 0), 1.3, color)
	Builder.part(folder, frame, {
		Name = "ContainmentField",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3.4, 3.4, 3.4),
		At = CFrame.new(0, 5.6, 0),
		Color = color,
		Material = Enum.Material.ForceField,
		CanCollide = false,
		CastShadow = false,
		Tag = Tags.ContainmentField,
	})
	Builder.neon(
		folder,
		frame,
		Vector3.new(1, 1, 1),
		CFrame.new(0, 5.6, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		gemColor,
		nil,
		Tags.ContainmentField
	)
end

function Enchanting.build(folder: Folder, frame: CFrame, color: Color3)
	local props = { Thickness = 2, Color = C.Stone, Battlements = true, Trim = color }
	for k = 0, 7 do
		local a, b = corner(k), corner(k + 1)
		if k == 0 then
			Builder.wallWithDoor(folder, frame, a.X, a.Z, b.X, b.Z, HEIGHT, 5, 9, props)
		else
			Builder.wall(folder, frame, a.X, a.Z, b.X, b.Z, HEIGHT, props)
			-- Runes on the outside of the walls you can see from the street.
			if k == 1 or k == 7 or k == 2 or k == 6 then
				local mid = (a + b) / 2
				local outward = (mid - CENTER).Unit
				local glyph = Builder.facing(mid + outward * 1.15 + Vector3.new(0, 11, 0), outward.X, outward.Z)
				rune(folder, frame, glyph, k, color)
			end
		end
		Builder.pillar(folder, frame, a.X, a.Z, HEIGHT + 2, color, { Width = 2.5, Color = C.WornStone })
	end

	-- Stepped roof and a spinning crystal on the spire.
	for i, radius in { RADIUS + 1, 10, 6.5, 3 } do
		local y = HEIGHT + i * 1.5 - 0.75
		Builder.disc(folder, frame, {
			Name = "Roof",
			Radius = radius,
			Height = 1.5,
			At = CFrame.new(CENTER + Vector3.new(0, y, 0)),
			Color = Color3.fromRGB(80, 50, 120),
			Material = Enum.Material.Slate,
		})
		Builder.neonBand(folder, frame, CENTER + Vector3.new(0, y, 0), radius, color)
	end
	Builder.part(folder, frame, {
		Name = "Spire",
		Size = Vector3.new(1.2, 6, 1.2),
		At = CFrame.new(CENTER + Vector3.new(0, HEIGHT + 9, 0)),
		Color = C.Chrome,
		Material = Enum.Material.Metal,
	})
	Builder.neon(
		folder,
		frame,
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(CENTER + Vector3.new(0, HEIGHT + 13.5, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		color,
		nil,
		Tags.Spin
	)

	local doorZ = corner(0).Z
	Builder.part(folder, frame, {
		Name = "Door",
		Size = Vector3.new(5, 9, 0.6),
		At = CFrame.new(0, 4.5, doorZ),
		Color = C.DarkWood,
		Material = Enum.Material.WoodPlanks,
	})
	Builder.sign(folder, frame, CFrame.new(0, 12, doorZ - 1.3), Vector3.new(11, 2.2, 0.5), "ARCANUM", color)
	containmentField(folder, frame * CFrame.new(-6.5, 0.5, doorZ - 4), C.Cyan, color)
	containmentField(folder, frame * CFrame.new(6.5, 0.5, doorZ - 4), C.Magenta, color)
	Builder.vendor(folder, frame * CFrame.new(0, 0.5, doorZ - 6), "Enchanting", Vendors.Enchanting)
end

return Enchanting
