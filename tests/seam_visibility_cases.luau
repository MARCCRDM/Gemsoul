local function part(transparency: number, modifier: number)
	return {
		Transparency = transparency,
		LocalTransparencyModifier = modifier,
		IsA = function(_, kind)
			return kind == "BasePart"
		end,
	}
end
local function box(adornee, attributes, owner)
	local listeners = {}
	local self
	self = {
		Adornee = adornee,
		-- (test only) which body it's on: your character, or nil
		IsDescendantOf = function(_, ancestor)
			return owner ~= nil and owner == ancestor
		end,
		Visible = true,
		Color3 = attributes and attributes.SeamA,
		IsA = function(_, kind)
			return kind == "SelectionBox"
		end,
		GetAttribute = function(_, name)
			return (attributes or {})[name]
		end,
		-- (test only) what the server's Equipment.outline does on a restyle
		Restyle = function(_, changes)
			attributes = attributes or {}
			for name, value in changes do
				attributes[name] = if value == false then nil else value
			end
			for listener in listeners do
				listener()
			end
		end,
		AttributeChanged = {
			Connect = function(_, fn)
				listeners[fn] = true
				return {
					Disconnect = function()
						listeners[fn] = nil
					end,
				}
			end,
		},
		Listeners = function()
			local n = 0
			for _ in listeners do
				n += 1
			end
			return n
		end,
	}
	return self
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

-- Animated seams: recoloured each frame between SeamA and SeamB.
local gold, red = Color3.fromRGB(255, 184, 40), Color3.fromRGB(230, 40, 56)
local plate = part(0, 0)
local shifting = box(plate, { SeamFx = "Shift", SeamA = gold, SeamB = red })
added(shifting)
local seen = {}
for frame = 0, 26 do
	CLOCK = frame / 10
	bound()
	seen[string.format("%.2f", shifting.Color3.G)] = true
end
local distinct = 0
for _ in seen do
	distinct += 1
end
assert(distinct > 5, "a Shift seam changes colour from frame to frame")
local still = box(part(0, 0), { SeamA = gold })
added(still)
CLOCK = 1.3
bound()
assert(still.Color3 == gold, "a seam with no SeamFx keeps its colour")
-- A hidden plate's seam isn't animated (nothing to see).
plate.Transparency = 1
local before = shifting.Color3
CLOCK = 2.1
bound()
assert(shifting.Color3 == before and not shifting.Visible, "a hidden seam isn't recoloured")
plate.Transparency = 0
-- Restyled to a still look: back to its own colour, and stays there.
shifting:Restyle({ SeamFx = false, SeamB = false })
assert(shifting.Color3 == gold, "a seam restyled to still goes back to SeamA")
CLOCK = 0.7
bound()
assert(shifting.Color3 == gold, "a still seam isn't animated")
-- Restyled to an animated look: animates again.
shifting:Restyle({ SeamFx = "Rainbow" })
CLOCK = 0.2
bound()
local first = shifting.Color3
CLOCK = 2.2
bound()
local now = shifting.Color3
assert(
	math.abs(first.R - now.R) + math.abs(first.G - now.G) + math.abs(first.B - now.B) > 0.1,
	"a seam restyled to Rainbow animates"
)
-- Untagged: forgotten, listener dropped.
assert(shifting:Listeners() == 1, "one listener per box")
removed(shifting)
assert(shifting:Listeners() == 0, "an untagged box drops its listener")
local frozen = shifting.Color3
CLOCK = 3.3
bound()
assert(shifting.Color3 == frozen, "an untagged box isn't animated")

-- A full server: everyone else's outlines are checked a slice a frame, all
-- of them within a few frames; your own every frame.
local crowd = {}
for i = 1, 400 do
	local plate = part(0, 0)
	local outline = box(plate, { SeamA = gold })
	added(outline)
	crowd[i] = { Plate = plate, Box = outline }
end
bound()
for _, entry in crowd do
	entry.Plate.Transparency = 1 -- everyone stows their gear
end
bound()
local stillShowing = 0
for _, entry in crowd do
	if entry.Box.Visible then
		stillShowing += 1
	end
end
assert(stillShowing > 0, "every outline in a full server was checked in one frame (not sliced)")
for _ = 2, SeamVisibility.Spread do
	bound()
end
for _, entry in crowd do
	assert(not entry.Box.Visible, "an outline wasn't checked within Spread frames")
end
-- Yours: on your body, checked every frame even in a crowd.
local me = services.Players.LocalPlayer
local myPlate = part(0, 0)
me.Character = { Name = "Me" }
local mine = box(myPlate, { SeamA = gold }, me.Character)
added(mine)
bound()
myPlate.LocalTransparencyModifier = 1 -- first person
bound()
assert(not mine.Visible, "your own outline lagged behind first person in a crowd")
myPlate.LocalTransparencyModifier = 0
-- A new body: an outline already tagged becomes yours.
local later2 = box(part(0, 0), { SeamA = gold }, "NextBody")
added(later2)
me.Character = "NextBody"
respawned()
bound()
later2.Adornee.LocalTransparencyModifier = 1
bound()
assert(not later2.Visible, "outlines on your new body weren't treated as yours")
print("seam visibility: all checks passed")
