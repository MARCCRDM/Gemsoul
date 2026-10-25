-- lune run tests/body_health_cases.luau <repo>
-- Health shown on a creature's body (client Modules/BodyHealth): nothing at
-- full health; its colours sink toward the wound colour as it's hurt (the
-- first blows show), a white flash on each blow that lands, smoke below Low,
-- a heal bringing it back; glowing parts and the root left alone; parts that
-- stream in later tinted too; and its own colours back once it's gone.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Color3, Vector3 = roblox.Color3, roblox.Vector3
local Enum = roblox.Enum

local ROOT = process.args[1] or "."
local checks = 0
local function check(ok: any, message: string)
	checks += 1
	assert(ok, message)
end

-- Doubles: a signal, parts, a humanoid and a model.
local function signal()
	local s = { Handlers = {} }
	function s:Connect(fn)
		table.insert(s.Handlers, fn)
		local c = {}
		function c:Disconnect()
			for i, f in s.Handlers do
				if f == fn then
					table.remove(s.Handlers, i)
				end
			end
		end
		return c
	end
	function s:Fire(...)
		for _, fn in table.clone(s.Handlers) do
			fn(...)
		end
	end
	return s
end
local made = {} -- what the module built (the smoke)
local function instance(class: string, props)
	local o = props or {}
	o.ClassName = class
	o.Children = o.Children or {}
	function o:IsA(name)
		return name == class
			or (name == "BasePart" and (class == "Part" or class == "MeshPart"))
			or (name == "Instance")
	end
	function o:Destroy()
		o.Destroyed = true
		o.Parent = nil
	end
	return o
end
local function part(name: string, color, material, transparency)
	return instance("Part", {
		Name = name,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Transparency = transparency or 0,
		Size = Vector3.new(4, 4, 4),
		Position = Vector3.new(0, 0, 0),
	})
end
local inWorld = true
local function model(parts, humanoid)
	local m = instance("Model", { Name = "Kaiju" })
	m.DescendantAdded = signal()
	m.AncestryChanged = signal()
	m.Parts = parts
	m.Humanoid = humanoid
	m.PrimaryPart = parts[1]
	function m:GetDescendants()
		local out = { humanoid }
		for _, p in m.Parts do
			table.insert(out, p)
		end
		return out
	end
	function m:FindFirstChildOfClass(class)
		return if class == "Humanoid" then humanoid else nil
	end
	function m:FindFirstChild(name)
		for _, p in m.Parts do
			if p.Name == name then
				return p
			end
		end
		return nil
	end
	function m:IsDescendantOf()
		return inWorld
	end
	m.Attributes = {}
	function m:GetAttribute(name)
		return m.Attributes[name]
	end
	return m
end
local function humanoid(health, max)
	local h = instance("Humanoid", { Health = health, MaxHealth = max })
	h.HealthChanged = signal()
	return h
end
local function hit(h, health)
	h.Health = health
	h.HealthChanged:Fire(health)
end

local env = setmetatable({
	Color3 = Color3,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	Enum = Enum,
	ColorSequence = roblox.ColorSequence,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	task = task,
	workspace = {},
	Instance = {
		new = function(class)
			local o = instance(class, {})
			table.insert(made, o)
			return o
		end,
	},
}, { __index = _G })
local BodyHealth = luau.load(fs.readFile(ROOT .. "/src/client/Modules/BodyHealth.luau"), {
	debugName = "BodyHealth",
	environment = env,
})()

-- The curve: nothing at full, Dark at none, deeper as it drops, and the
-- first blows already show (more than a straight line would).
check(BodyHealth.tint(1) == 0 and math.abs(BodyHealth.tint(0) - BodyHealth.Dark) < 1e-9, "The tint's ends")
local last = -1
for i = 10, 0, -1 do
	local t = BodyHealth.tint(i / 10)
	check(t > last, "The tint doesn't deepen as health drops at " .. i / 10)
	last = t
end
check(BodyHealth.tint(0.8) > BodyHealth.Dark * 0.2, "The first blows barely show")
check(BodyHealth.tint(1.4) == 0 and BodyHealth.tint(-1) == BodyHealth.Dark, "The tint isn't clamped")
check(not BodyHealth.smokes(1) and not BodyHealth.smokes(BodyHealth.Low) and BodyHealth.smokes(0.1), "Smoke thresholds")
check(not BodyHealth.smokes(0), "A creature that's down still smokes")

-- A body: hide, a glowing eye, the root (hidden), a see-through fin.
local HIDE = Color3.fromRGB(120, 160, 90)
local root = part("HumanoidRootPart", Color3.fromRGB(10, 10, 10), nil, 1)
local hide = part("Torso", HIDE)
local eye = part("Eye", Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
local fin = part("Fin", Color3.fromRGB(90, 90, 200), nil, 0.97)
local h = humanoid(100, 100)
local m = model({ root, hide, eye, fin }, h)
BodyHealth.watch(m)
check(hide.Color == HIDE, "A whole creature's colours changed")
BodyHealth.watch(m) -- (twice: still one entry)
check(#h.HealthChanged.Handlers == 1, "Watching twice hooked its health twice")

-- A blow: a white flash, then sunk toward the wound colour.
local function near(a, b)
	return (a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2 < 1e-6
end
local function flashed(share)
	return HIDE:Lerp(BodyHealth.Wound, BodyHealth.tint(share)):Lerp(BodyHealth.Flash.Color, BodyHealth.Flash.Amount)
end
hit(h, 60)
check(near(hide.Color, flashed(0.6)) and hide.Color.R > HIDE.R, "No white flash on a blow")
task.wait(BodyHealth.Flash.Seconds + 0.05)
local sunk = HIDE:Lerp(BodyHealth.Wound, BodyHealth.tint(0.6))
check((hide.Color.G - sunk.G) ^ 2 < 1e-6 and hide.Color.G < HIDE.G, "A hurt body didn't sink toward the wound")
check(eye.Color == Color3.fromRGB(255, 220, 60), "A glowing eye lost its light")
check(root.Color == Color3.fromRGB(10, 10, 10) and fin.Color == Color3.fromRGB(90, 90, 200), "Hidden parts were tinted")
check(#made == 0, "It smoked before it was low")

-- A part streaming in later is tinted too.
local tail = part("Tail", HIDE)
table.insert(m.Parts, tail)
m.DescendantAdded:Fire(tail)
check((tail.Color.G - sunk.G) ^ 2 < 1e-6, "A part that streamed in wasn't tinted")

-- Low: it smokes; healed, the smoke stops and its colours come back
-- (no flash for a heal).
hit(h, 20)
task.wait(BodyHealth.Flash.Seconds + 0.05)
local emitter
for _, o in made do
	if o.ClassName == "ParticleEmitter" then
		emitter = o
	end
end
check(emitter and emitter.Enabled == true, "A creature low on health doesn't smoke")
check(hide.Color.G < sunk.G, "Lower health didn't sink it further")
hit(h, 100)
check(hide.Color == HIDE and tail.Color == HIDE, "A heal didn't bring its colours back (or flashed)")
check(emitter.Enabled == false, "A healed creature still smokes")

-- Flashes overlapping: the newer one sets when the body settles.
hit(h, 70)
task.wait(BodyHealth.Flash.Seconds * 0.5)
hit(h, 50)
task.wait(BodyHealth.Flash.Seconds * 0.7)
check(near(hide.Color, flashed(0.5)), "An older flash cut a newer one short")
task.wait(BodyHealth.Flash.Seconds)
local half = HIDE:Lerp(BodyHealth.Wound, BodyHealth.tint(0.5))
check((hide.Color.G - half.G) ^ 2 < 1e-6, "The body didn't settle after two blows")

-- Gone: its own colours back, its hooks off, the smoke cleared.
local wisp = emitter.Parent
inWorld = false
m.AncestryChanged:Fire()
check(hide.Color == HIDE and tail.Color == HIDE, "A creature gone kept its wounds")
check(#h.HealthChanged.Handlers == 0, "A creature gone is still watched")
check(wisp and wisp.Destroyed == true, "Its smoke stayed")

-- No humanoid: nothing to show.
local statue = model({ part("Stone", HIDE) }, nil)
statue.FindFirstChildOfClass = function()
	return nil
end
BodyHealth.watch(statue)
check(statue.Parts[1].Color == HIDE, "A body without health was tinted")

-- The outline's colour: green when well, amber worn down, red nearly done.
local O = BodyHealth.Outline
check(
	near(BodyHealth.outlineColor(1), O.Good) and near(BodyHealth.outlineColor(O.WarnAt), O.Warn),
	"Outline green/amber ends"
)
check(near(BodyHealth.outlineColor(O.BadAt), O.Bad) and near(BodyHealth.outlineColor(0), O.Bad), "Outline red end")
check(BodyHealth.outlineColor(0.45).G > BodyHealth.outlineColor(0.35).G, "The outline doesn't redden as health drops")

-- Who gets one: the wild kaiju first (even well, even far), then the
-- nearest hurt ones; never one glowing gold to be caught, nor a well tame one.
local wildFar = { Wild = true, Hurt = false, Distance = 300 }
local wildHeld = { Wild = true, Hurt = true, Distance = 5, Held = true }
local bugNear = { Hurt = true, Distance = 10 }
local bugFar = { Hurt = true, Distance = 120 }
local bugWell = { Hurt = false, Distance = 3 }
local bugAway = { Hurt = true, Distance = O.Range + 5 }
local picked = BodyHealth.choose({ bugFar, bugWell, wildFar, bugNear, wildHeld, bugAway }, 2)
check(
	picked[wildFar] and picked[bugNear] and not picked[bugFar],
	"The outline budget didn't go wild first, then nearest"
)
check(
	not picked[wildHeld] and not picked[bugWell] and not picked[bugAway],
	"Outlined one held in gold, a well one or one out of range"
)
check(
	BodyHealth.choose({ { Wild = true, Distance = O.WildRange + 1 } }, 5)[1] == nil,
	"A wild kaiju out of range was outlined"
)

-- On a body: a wild kaiju, well, outlined green through rocks; hurt, red,
-- flaring on the blow; down, none.
made = {}
local wildHide = part("Torso", HIDE)
local wildRoot = part("HumanoidRootPart", HIDE, nil, 1)
local wh = humanoid(100, 100)
local wm = model({ wildRoot, wildHide }, wh)
wm.Attributes.KaijuWild = true
inWorld = true
BodyHealth.watch(wm)
BodyHealth.step(Vector3.new(0, 0, 20))
for _, o in made do
	check(not (o.ClassName == "Highlight" and o.Adornee == wm and not o.Destroyed), "Wild kaiju must not have the green health outline")
end
-- Gem-carrying critters still need their recovery outline.
wm.Attributes.KaijuWild = nil
wm.Attributes.CarryingGem = true
BodyHealth.step(Vector3.new(0, 0, 20))
local ring
for _, o in made do
	if o.ClassName == "Highlight" then
		ring = o
	end
end
check(ring and ring.Adornee == wm and ring.Parent == wm, "A gem-carrying critter lost its outline")
check(ring.DepthMode == Enum.HighlightDepthMode.AlwaysOnTop, "A wild kaiju's outline doesn't show through rocks")
check(near(ring.OutlineColor, O.Good), "A well wild kaiju's outline isn't green")
hit(wh, 20)
check(
	near(ring.OutlineColor, BodyHealth.outlineColor(0.2)) and ring.FillTransparency == O.Flare,
	"A blow didn't redden and flare the outline"
)
task.wait(BodyHealth.Flash.Seconds * 2 + 0.05)
check(ring.FillTransparency == O.Fill, "The outline's flare didn't settle")
hit(wh, 0)
BodyHealth.step(Vector3.new(0, 0, 20))
check(ring.Destroyed == true, "A creature that's down kept its outline")

-- Mending in the lobby: a green shimmer off the player, on and off.
made = {}
local body = model({ part("HumanoidRootPart", HIDE, nil, 1) }, humanoid(50, 100))
BodyHealth.mend(body, true)
local shimmer
for _, o in made do
	if o.ClassName == "ParticleEmitter" then
		shimmer = o
	end
end
check(shimmer and shimmer.Enabled == true, "A player mending doesn't shimmer")
BodyHealth.mend(body, true)
check(#made == 2, "Mending twice made two shimmers")
BodyHealth.mend(body, false)
check(shimmer.Enabled == false, "The shimmer didn't stop with the mending")

print(
	"PASS: "
		.. checks
		.. " body health checks (the tint curve, flash, smoke, heal, glow and hidden parts, streaming, gone, outlines, mending)"
)
