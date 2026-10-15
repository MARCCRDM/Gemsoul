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
		-- (test only) which body it's on: your character, or nil; in the
		-- world either way
		IsDescendantOf = function(_, ancestor)
			return (owner ~= nil and owner == ancestor) or ancestor == workspace or ancestor == game
		end,
		FindFirstAncestorWhichIsA = function()
			return nil
		end,
		AncestryChanged = {
			Connect = function()
				return { Disconnect = function() end }
			end,
		},
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

-- Trim strips (the server's neon parts, Equipment.inlay): they hide with
-- their own part, are recoloured PartFxRate times a second, and a plate's
-- strips (one SeamSeed) move as one.
local function strip(attributes)
	local self = part(0, 0)
	self.Color = attributes.SeamA
	self.CFrame = { Position = { X = 0, Y = 0, Z = 0 } }
	self.IsDescendantOf = function(_, ancestor)
		return ancestor == workspace or ancestor == game
	end
	self.FindFirstAncestorWhichIsA = function()
		return nil
	end
	self.GetAttribute = function(_, name)
		return attributes[name]
	end
	self.AttributeChanged = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}
	self.AncestryChanged = self.AttributeChanged
	return self
end
local left = strip({ SeamFx = "Shift", SeamA = gold, SeamB = red, SeamSeed = 3 })
local right = strip({ SeamFx = "Shift", SeamA = gold, SeamB = red, SeamSeed = 3 })
local other = strip({ SeamFx = "Shift", SeamA = gold, SeamB = red, SeamSeed = 9 })
added(left)
added(right)
added(other)
assert(SeamVisibility.shows(left), "a strip in view shows")
-- (In this crowd they're checked a slice a frame: give them a round.)
CLOCK = 9
for _ = 1, SeamVisibility.Spread + 1 do
	bound()
end
CLOCK = 10
bound()
local painted = left.Color
assert(left.Color.R == right.Color.R and left.Color.G == right.Color.G, "a plate's strips aren't in step")
assert(left.Color.G ~= other.Color.G, "different plates' strips move in lockstep")
CLOCK = 10 + 0.4 / SeamVisibility.PartFxRate
bound()
assert(left.Color == painted, "a strip was recoloured faster than PartFxRate")
CLOCK = 10 + 1.2 / SeamVisibility.PartFxRate
bound()
assert(left.Color ~= painted, "a strip wasn't recoloured at PartFxRate")
assert(left.Visible == nil, "a strip had its visibility toggled (it hides with its own part)")
left.Transparency = 1
for _ = 1, SeamVisibility.Spread + 1 do
	bound() -- (the clock holds still: whatever's painted now is the same colour)
end
local hiddenColor = left.Color
CLOCK = 13
bound()
assert(left.Color == hiddenColor, "a hidden strip was recoloured")

-- Copies (LiveLooks): the first-person sword and the previews are clones,
-- and a clone can't be counted on to keep its tag. Watched, they're found
-- by attribute; a preview moves while it's on screen however far off the
-- camera is; the Shop's mannequins (drawn nowhere) are never touched.
local Vector = {}
Vector.__sub = function(a, b)
	return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, Vector)
end
Vector.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return nil
end
local function at(x)
	return setmetatable({ X = x, Y = 0, Z = 0 }, Vector)
end
local camera = { Name = "Camera", CFrame = { Position = at(0) } }
workspace.CurrentCamera = camera
-- A GUI chain: a ScreenGui, a frame in it, a ViewportFrame in that.
local function gui(kind, parent)
	return {
		Parent = parent,
		Visible = true,
		Enabled = true,
		IsA = function(_, class)
			return class == kind or (class == "GuiObject" and kind ~= "LayerCollector")
		end,
	}
end
local screen = gui("LayerCollector", nil)
local panel = gui("GuiObject", screen)
local preview = gui("ViewportFrame", panel)
-- A copied strip: where it's drawn ("camera", "view", "world" or "away"),
-- at x studs from the camera; Leave() takes it out of the game.
local function copied(where, x, attributes)
	local self = part(0, 0)
	self.Color = attributes.SeamA
	self.CFrame = { Position = at(x) }
	local listeners, moved = {}, {}
	local inGame = true
	self.IsDescendantOf = function(_, ancestor)
		if ancestor == game then
			return inGame
		elseif ancestor == workspace then
			return inGame and (where == "world" or where == "camera")
		elseif ancestor == camera then
			return inGame and where == "camera"
		end
		return false
	end
	self.FindFirstAncestorWhichIsA = function(_, class)
		return if class == "ViewportFrame" and where == "view" and inGame then preview else nil
	end
	self.GetAttribute = function(_, name)
		return attributes[name]
	end
	local function signal(into)
		return {
			Connect = function(_, fn)
				into[fn] = true
				return {
					Disconnect = function()
						into[fn] = nil
					end,
				}
			end,
		}
	end
	self.AttributeChanged = signal(listeners)
	self.AncestryChanged = signal(moved)
	self.Listening = function()
		return next(listeners) ~= nil
	end
	self.Leave = function()
		inGame = false
		for fn in moved do
			fn()
		end
	end
	return self
end
local function copyOf(strips)
	return {
		GetAttribute = function()
			return nil
		end,
		GetDescendants = function()
			return strips
		end,
		DescendantAdded = {
			Connect = function()
				return { Disconnect = function() end }
			end,
		},
	}
end
-- (The clock only moves on from here.)
CLOCK = 40
local function tick()
	CLOCK += 0.11
	bound()
end
local function moves(seam, label)
	local seen = {}
	for _ = 1, 30 do
		tick()
		seen[string.format("%.3f", seam.Color.G)] = true
	end
	local distinct = 0
	for _ in seen do
		distinct += 1
	end
	return distinct > 4, label
end
local fx = { SeamFx = "Shift", SeamA = gold, SeamB = red, SeamSeed = 2 }
-- First person: an untagged copy in the camera moves.
local held = copied("camera", 1, fx)
LiveLooks.watch(copyOf({ held }))
assert(moves(held, ""), "your first-person copy of an animated skin stood still")
-- A preview, 900 studs from the camera: moves while it's on screen.
local shown = copied("view", 900, fx)
LiveLooks.watch(copyOf({ shown }))
assert(moves(shown, ""), "an Inventory/Shop preview of an animated skin stood still")
screen.Enabled = false
tick()
local closed = shown.Color
for _ = 1, 10 do
	tick()
end
assert(shown.Color == closed, "a preview was animated while its screen was closed")
screen.Enabled = true
panel.Visible = false
for _ = 1, 10 do
	tick()
end
assert(shown.Color == closed, "a preview was animated inside a hidden frame")
panel.Visible = true
assert(moves(shown, ""), "a preview stood still once it was back on screen")
-- A tagged clone in a preview (if Roblox keeps its tag) moves too, however
-- far off the camera is: it's classed with the preview, not the world.
local taggedCopy = copied("view", 900, fx)
added(taggedCopy)
assert(moves(taggedCopy, ""), "a tagged clone in a preview was held still as a far-off world seam")
-- The same skin in the world that far off holds still (FxRange).
local farWorld = copied("world", 900, fx)
added(farWorld)
local farColor = farWorld.Color
for _ = 1, 10 do
	tick()
end
assert(farWorld.Color == farColor, "a far-off world seam was animated")
-- The Shop's mannequins (ReplicatedStorage): drawn nowhere, never touched.
local mannequin = copied("away", 1, fx)
added(mannequin)
local stored = mannequin.Color
assert(moves(mannequin, "") == false and mannequin.Color == stored, "a seam drawn nowhere was animated")
-- A copy leaving the game (the view rebuilt, the preview closed) is
-- forgotten: no longer painted, its listener dropped.
held.Leave()
assert(not held:Listening(), "a copy that left the game kept its listener")
local gone = held.Color
for _ = 1, 10 do
	tick()
end
assert(held.Color == gone, "a copy that left the game was still painted")
-- A copy that isn't animated (no SeamFx) isn't taken on at all.
local plain = copied("camera", 1, { SeamA = gold })
LiveLooks.watch(copyOf({ plain }))
assert(not plain:Listening(), "a still seam in a copy was watched")
workspace.CurrentCamera = nil
print("seam visibility: all checks passed")
