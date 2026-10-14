local function part(transparency: number, modifier: number)
	return {
		Transparency = transparency,
		LocalTransparencyModifier = modifier,
		IsA = function(_, kind)
			return kind == "BasePart"
		end,
	}
end
local function box(adornee)
	return {
		Adornee = adornee,
		Visible = true,
		IsA = function(_, kind)
			return kind == "SelectionBox"
		end,
	}
end

assert(SeamVisibility.shows(box(part(0, 0))), "a plate in view keeps its seams")
assert(
	not SeamVisibility.shows(box(part(0, 1))),
	"your own plate, hidden round the first-person camera, hides its seams"
)
assert(not SeamVisibility.shows(box(part(1, 0))), "a staged or stowed plate hides its seams")
assert(not SeamVisibility.shows(box(nil)), "a box with no part shows nothing")

-- Live: tagged boxes follow their parts every frame.
local helmet = part(0, 0)
local worn = box(helmet)
tagged[Tags.SkinSeam] = { worn }
SeamVisibility.start()
assert(bound, "binds a render step")
bound()
assert(worn.Visible, "shown while its plate shows")
helmet.LocalTransparencyModifier = 1 -- first person
bound()
assert(not worn.Visible, "hidden in first person")
helmet.LocalTransparencyModifier = 0
bound()
assert(worn.Visible, "back on leaving first person")
local later = box(part(1, 0))
added(later)
bound()
assert(not later.Visible, "a box tagged later is followed too")
print("seam visibility: all checks passed")
