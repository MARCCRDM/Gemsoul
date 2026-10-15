-- Copies of gear move as the gear does (LiveLooks): your first-person sword,
-- the Inventory's and the Shop's previews are clones, and a clone can't be
-- counted on to keep its CollectionService tag. Watched, their Prismatic
-- plates shimmer (PrismaticShimmer) and their stones' lights breathe
-- (GemLights); a preview moves while it's on screen, however far off the
-- camera is; what's drawn nowhere is left alone.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- A GUI chain: a ScreenGui, a frame in it, a preview (ViewportFrame) in that.
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
local camera = { CFrame = { Position = at(0) } }
workspace.CurrentCamera = camera

local function signal()
	local handlers = {}
	return {
		Handlers = handlers,
		Connect = function(_, fn)
			handlers[fn] = true
			return {
				Disconnect = function()
					handlers[fn] = nil
				end,
			}
		end,
		Fire = function()
			for fn in handlers do
				fn()
			end
		end,
	}
end
-- A part or light: where it's drawn ("camera", "view", "world" or "away"),
-- `x` studs from the camera. Leave() takes it out of the game.
local function thing(class, where, x, attributes)
	local self = { Color = Color3.new(0.5, 0.5, 0.5), Brightness = 1, Position = at(x) }
	local inGame = true
	local changed, named, ancestry = signal(), {}, signal()
	self.IsA = function(_, kind)
		return kind == class or (class == "PointLight" and kind == "Light")
	end
	self.GetAttribute = function(_, name)
		return attributes[name]
	end
	self.SetAttribute = function(_, name, value)
		attributes[name] = value
		changed.Fire()
		if named[name] then
			named[name].Fire()
		end
	end
	self.AttributeChanged = changed
	self.GetAttributeChangedSignal = function(_, name)
		named[name] = named[name] or signal()
		return named[name]
	end
	self.AncestryChanged = ancestry
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
	self.FindFirstAncestorWhichIsA = function(_, kind)
		return if kind == "ViewportFrame" and where == "view" and inGame then preview else nil
	end
	self.Leave = function()
		inGame = false
		ancestry.Fire()
	end
	-- (Built outside the game, moved about there, then placed.)
	self.Unplaced = function()
		inGame = false
	end
	self.MoveOutside = function()
		ancestry.Fire()
	end
	self.Place = function()
		inGame = true
		ancestry.Fire()
	end
	self.Listening = function()
		if next(changed.Handlers) or next(ancestry.Handlers) then
			return true
		end
		for _, s in named do
			if next(s.Handlers) then
				return true
			end
		end
		return false
	end
	if class == "PointLight" then
		self.Parent = {
			Position = at(x),
			IsA = function(_, kind)
				return kind == "BasePart"
			end,
		}
	end
	return self
end
local function copyOf(things)
	return {
		GetAttribute = function()
			return nil
		end,
		GetDescendants = function()
			return things
		end,
		DescendantAdded = signal(),
	}
end
local function frame()
	CLOCK += 1 / 30
	for _, fn in frames do
		fn()
	end
end
-- How many different values `key` takes over a second of frames.
local function variety(object, key)
	local seen, n = {}, 0
	for _ = 1, 30 do
		frame()
		local value = object[key]
		local mark = if type(value) == "number"
			then string.format("%.4f", value)
			else string.format("%.4f", value.R + value.G * 3 + value.B * 7)
		if not seen[mark] then
			seen[mark], n = true, n + 1
		end
	end
	return n
end

-- 1. Where things are drawn, and whether a preview is on screen.
check(LiveLooks.place(thing("BasePart", "view", 0, {})) == "View", "a preview's part isn't placed in the View")
check(
	LiveLooks.place(thing("BasePart", "camera", 0, {})) == "Camera",
	"the first-person copy isn't placed in the Camera"
)
check(LiveLooks.place(thing("BasePart", "world", 0, {})) == "World", "a worn part isn't placed in the World")
check(LiveLooks.place(thing("BasePart", "away", 0, {})) == "Away", "a stored part isn't placed Away")
check(LiveLooks.onScreen(preview), "a visible preview isn't on screen")
screen.Enabled = false
check(not LiveLooks.onScreen(preview), "a preview counts as on screen with its ScreenGui off")
screen.Enabled = true
panel.Visible = false
check(not LiveLooks.onScreen(preview), "a preview counts as on screen inside a hidden frame")
panel.Visible = true
check(not LiveLooks.onScreen(gui("ViewportFrame", nil)), "a preview under no ScreenGui counts as on screen")

-- 2. A copy watched before the animators start is still picked up.
local early = thing("BasePart", "camera", 1, { PrismaticBase = Color3.new(1, 0.2, 0.2) })
local copy = copyOf({ early })
LiveLooks.watch(copy)
LiveLooks.watch(copy) -- (twice: still one entry)
PrismaticShimmer.start()
GemLights.start()
check(variety(early, "Color") > 5, "a copy watched before the shimmer started stood still")

-- 3. Prismatic plates.
local base = { PrismaticBase = Color3.new(0.2, 0.4, 1) }
local nearWorld = thing("BasePart", "world", 10, table.clone(base))
local farWorld = thing("BasePart", "world", 400, table.clone(base))
local stored = thing("BasePart", "away", 1, table.clone(base))
tagged[Tags.Prismatic] = {}
addedTo[Tags.Prismatic](nearWorld)
addedTo[Tags.Prismatic](farWorld)
addedTo[Tags.Prismatic](stored)
check(variety(nearWorld, "Color") > 5, "a worn Prismatic plate near the camera stood still")
check(variety(farWorld, "Color") == 1, "a far-off Prismatic plate shimmered")
check(variety(stored, "Color") == 1, "a Prismatic plate drawn nowhere shimmered")
local held = thing("BasePart", "camera", 1, table.clone(base))
LiveLooks.watch(copyOf({ held }))
check(variety(held, "Color") > 5, "your first-person copy of a Prismatic piece stood still")
local shown = thing("BasePart", "view", 900, table.clone(base))
LiveLooks.watch(copyOf({ shown }))
check(variety(shown, "Color") > 5, "a preview of a Prismatic piece stood still")
screen.Enabled = false
frame()
check(variety(shown, "Color") == 1, "a preview shimmered with its screen closed")
screen.Enabled = true
held.Leave()
check(not held:Listening(), "a copy that left the game kept its listeners")
check(variety(held, "Color") == 1, "a copy that left the game still shimmered")
nearWorld:SetAttribute("PrismaticBase", nil) -- (a skin painted over it)
frame()
check(variety(nearWorld, "Color") == 1, "a plate that lost its PrismaticBase still shimmered")
local plain = thing("BasePart", "camera", 1, {})
LiveLooks.watch(copyOf({ plain }))
check(not plain:Listening(), "a plain part in a copy was taken on")
-- The lottery's reward art: watched while it's still being put together
-- outside the game (moved into its preview there), then placed on screen.
local reward = thing("BasePart", "view", 900, table.clone(base))
reward.Unplaced()
LiveLooks.watch(copyOf({ reward }))
check(variety(reward, "Color") == 1, "a copy not yet in the game shimmered")
reward.MoveOutside()
check(reward:Listening(), "a copy moved about before it was placed was forgotten")
reward.Place()
check(variety(reward, "Color") > 5, "a copy watched before it was placed stood still once placed")
reward.Leave()
check(not reward:Listening(), "a placed copy that left the game was kept")

-- 4. Stones' lights.
check(GemLights.brightness(1, 0.5, 0.4, 0) == 1, "a light doesn't start bright")
check(math.abs(GemLights.brightness(1, 0.5, 0.4, 0.5) - 0.4) < 1e-9, "a light isn't dimmest a period in")
check(math.abs(GemLights.brightness(1, 0.5, 0.4, 1) - 1) < 1e-9, "a light isn't bright again two periods in")
check(GemLights.brightness(0.8, 0, 0.4, 3) == 0.8, "a light with no period moved")
local previous = 2
for i = 0, 10 do
	local b = GemLights.brightness(1, 1, 0.3, i / 10)
	check(b <= previous + 1e-9, "a light doesn't dim steadily to its low point")
	previous = b
end
local pulse = { PulseBase = 0.8, PulsePeriod = 0.5, PulseDim = 0.4 }
local worn = thing("PointLight", "world", 10, table.clone(pulse))
local farLight = thing("PointLight", "world", 400, table.clone(pulse))
addedTo[Tags.GemGlow](worn)
addedTo[Tags.GemGlow](farLight)
check(variety(worn, "Brightness") > 5, "a worn stone's light didn't breathe")
check(variety(farLight, "Brightness") == 1, "a far-off stone's light moved")
-- First person halves the copy's light (FirstPersonCombat): it breathes
-- round that, not back up to the worn one's.
local heldLight = thing("PointLight", "camera", 1, { PulseBase = 0.4, PulsePeriod = 0.5, PulseDim = 0.4 })
LiveLooks.watch(copyOf({ heldLight }))
local brightest = 0
for _ = 1, 30 do
	frame()
	brightest = math.max(brightest, heldLight.Brightness)
end
check(
	brightest > 0.3 and brightest <= 0.4 + 1e-9,
	"your first-person stone's light didn't breathe at its own brightness"
)
local previewLight = thing("PointLight", "view", 1, table.clone(pulse))
LiveLooks.watch(copyOf({ previewLight }))
check(variety(previewLight, "Brightness") == 1, "a preview's light was moved (previews draw none)")
removedFrom[Tags.GemGlow](worn)
check(not worn:Listening(), "an untagged light kept its listeners")
check(variety(worn, "Brightness") == 1, "an untagged light still moved")

print(string.format("PASS: %d live look checks (copies and previews move as the gear does)", checks))
