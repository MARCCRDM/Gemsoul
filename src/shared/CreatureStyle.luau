--[[
	One look for everything that fights in the Rift and the Outpost. The
	kaiju (Shared.KaijuModels) wear their element as angular plates in its
	colour, glows in its light and a darker trim; the dungeons' bosses and
	room fighters (Server BrainrotBosses, BrainrotSkins) were lit in the raw
	element colour instead, and read as another game's. They take these
	palettes too, and the same plates, lit vents and a glowing core
	(BrainrotSkins.blend), so a Fire boss burns in the orange its Fire
	kaiju do.

	  CreatureStyle.Palettes[element]            Plate, Glow, Trim
	  CreatureStyle.palette(element) -> palette  (Fire's for an unknown one)
	  CreatureStyle.near(a, b) -> boolean        the same colour, near enough
	  CreatureStyle.recolour(objects, raw, palette) -> number
	      every part and light among `objects` in the raw colour takes the
	      palette: a glowing part (Neon) and a light its Glow, the rest its
	      Plate. How many changed.
]]
local CreatureStyle = {}

local C = Color3.fromRGB

-- Each element's plates, the glow of its eyes, core and vents, and a darker trim.
CreatureStyle.Palettes = {
	Fire = { Plate = C(236, 138, 44), Glow = C(255, 196, 96), Trim = C(150, 72, 26) },
	Frost = { Plate = C(72, 178, 198), Glow = C(140, 238, 255), Trim = C(36, 104, 132) },
	Shock = { Plate = C(234, 198, 62), Glow = C(150, 222, 255), Trim = C(140, 112, 34) },
	Poison = { Plate = C(112, 196, 84), Glow = C(200, 255, 120), Trim = C(56, 116, 46) },
}

function CreatureStyle.palette(element: string?)
	return CreatureStyle.Palettes[element or ""] or CreatureStyle.Palettes.Fire
end

function CreatureStyle.near(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 2 / 255
end

function CreatureStyle.recolour(objects: { Instance }, raw: Color3, palette): number
	local changed = 0
	for _, object in objects do
		if object:IsA("BasePart") and CreatureStyle.near(object.Color, raw) then
			object.Color = if object.Material == Enum.Material.Neon then palette.Glow else palette.Plate
			changed += 1
		elseif object:IsA("Light") and CreatureStyle.near(object.Color, raw) then
			object.Color = palette.Glow
			changed += 1
		end
	end
	return changed
end

return CreatureStyle
