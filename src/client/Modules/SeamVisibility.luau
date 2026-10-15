--[[
	Skin seams and glowing edges (tagged SkinSeam by the server) are thin
	neon parts set into the armour (Equipment.inlay, edgeLines): they hide
	and show with the armour by themselves. Older ones were SelectionBoxes,
	which Roblox draws even round a part that is hidden, so a box shows only
	while its part does (or your own suit's outlines filled the first-person
	view, and a staged or stowed piece left its outline floating in the
	air). Purely local.

	Seams can be alive, too: one with a SeamFx attribute (set from its
	skin's palette, Cosmetics) is recoloured while it shows, between its
	SeamA (the seam colour, set on every seam) and SeamB (the glow); a
	plate's strips share a SeamSeed, so its frame moves as one. (Strips are
	recoloured PartFxRate times a second, boxes every frame: a suit has over
	a hundred strips.)
	  Pulse    breathes, bright to dim and back
	  Shift    swings from one colour to the other
	  Flicker  crackles like a live wire: the glow, with sharp flashes
	  Rainbow  runs through every hue
	  Scan     a bright bar (SeamB) sweeps to and fro over a dimmed lens
	           (SeamA): each band's SeamSeed (0-10) is where it sits
	  Aurora   flows through three colours (SeamA, SeamB, SeamC), a little
	           behind from one band to the next
	(Scan and Aurora are visors' (Cosmetics.VisorLook); a visor's lens is
	tagged and animated here as a seam is.)

	Copies move too: your first-person sword, the Inventory's and the Shop's
	previews and gear art are clones, found by their attributes (LiveLooks)
	since a clone can't be counted on to keep its tag. A preview's seams move
	while it's on screen, wherever the world's camera is.

	  SeamVisibility.shows(box)  pure: whether the box's part is showing
	  SeamVisibility.fxColor(fx, a, b, t, seed, c?)  pure: an animated seam's colour
	  SeamVisibility.start()
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)
local LiveLooks = require(script.Parent.LiveLooks)

local SeamVisibility = {}

function SeamVisibility.shows(seam: Instance): boolean
	local part = if seam:IsA("SelectionBox") then seam.Adornee else seam
	return part ~= nil and part:IsA("BasePart") and part.Transparency < 0.99 and part.LocalTransparencyModifier < 0.99
end

local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

-- From one colour to another round the colour wheel (the short way), not
-- straight across it: blue to gold goes by way of green, not grey.
local function wheel(a: Color3, b: Color3, k: number): Color3
	local ha, sa, va = a:ToHSV()
	local hb, sb, vb = b:ToHSV()
	local turn = (hb - ha + 0.5) % 1 - 0.5
	return Color3.fromHSV((ha + turn * k) % 1, sa + (sb - sa) * k, va + (vb - va) * k)
end

type Fx = { Fx: string, A: Color3, B: Color3, C: Color3?, Seed: number }

-- The colour of an animated seam at time `t` (seconds). `seed` staggers
-- boxes a little, so a suit's seams don't all flash in lockstep (and places
-- a visor's band across its lens: 0 at one side, 10 at the other).
function SeamVisibility.fxColor(fx: string, a: Color3, b: Color3, t: number, seed: number, c: Color3?): Color3
	if fx == "Pulse" then
		local k = 0.5 + 0.5 * math.sin(t * math.pi * 2 / 1.8)
		return a:Lerp(BLACK, 0.5 * (1 - k)):Lerp(WHITE, 0.15 * k)
	elseif fx == "Shift" then
		return a:Lerp(b, 0.5 + 0.5 * math.sin(t * math.pi * 2 / 2.6 + seed * 0.4))
	elseif fx == "Flicker" then
		local n = math.noise(t * 9, seed * 7.3, 0.5)
		if n > 0.32 then
			return b:Lerp(WHITE, 0.5) -- a flash
		end
		return a:Lerp(BLACK, math.clamp(-n, 0, 0.4))
	elseif fx == "Rainbow" then
		local _, s, v = a:ToHSV()
		return Color3.fromHSV((t * 0.18 + seed * 0.03) % 1, math.max(s, 0.65), math.max(v, 0.9))
	elseif fx == "Scan" then
		-- To and fro across the lens in 2.8 s, a soft glow either side of it.
		local phase = (t / 1.4) % 2
		local at = if phase < 1 then phase else 2 - phase
		local hit = math.clamp(1 - math.abs(math.clamp(seed, 0, 10) / 10 - at) * 4.5, 0, 1)
		return a:Lerp(BLACK, 0.45):Lerp(b, hit * hit * (3 - 2 * hit))
	elseif fx == "Aurora" then
		-- a, b, c and round again in 4.5 s, each band a step behind.
		local third = c or a
		local u = (t / 4.5 + seed * 0.03) % 1 * 3
		local k = u % 1
		k = k * k * (3 - 2 * k)
		if u < 1 then
			return wheel(a, b, k)
		elseif u < 2 then
			return wheel(b, third, k)
		end
		return wheel(third, a, k)
	end
	return a
end

-- Cost: a neon suit has up to ~80 outlines, so a full server has well over a
-- thousand. Those round your own body, in the first-person view and in a
-- preview are checked every frame (first person hides and shows your plates
-- from one frame to the next; a preview only while it's on screen).
-- Everyone else's only change when their gear is staged or stowed, so
-- they're checked a slice at a time: every one of them every few frames
-- (Spread). Animated outlines in the world move only near the camera
-- (FxRange); far off, too small to see, they hold still. Seams drawn
-- nowhere (the Shop's mannequins in ReplicatedStorage) aren't checked.
SeamVisibility.Spread = 4
SeamVisibility.SliceMin = 64 -- (fewer outlines than this: all, every frame)
SeamVisibility.FxRange = 120
SeamVisibility.PartFxRate = 20

local Players = game:GetService("Players")
local boxes: { [Instance]: boolean } = {} -- every seam: SelectionBoxes and strips
-- Animated seams, read once (and again only when a restyle changes them).
local effects: { [Instance]: Fx } = {}
local links: { [Instance]: { RBXScriptConnection } } = {}
local own: { [Instance]: boolean } = {} -- on your body, in the camera or in a preview
local views: { [Instance]: Instance } = {} -- a preview's seams: their ViewportFrame
local showing: { [Instance]: boolean } = {}
local near: { [Instance]: boolean } = {}
local others: { Instance } = {} -- everyone else's, checked a slice a frame
local dirty, cursor, count = true, 0, 0

local function paint(seam: Instance, color: Color3)
	if seam:IsA("SelectionBox") then
		seam.Color3 = color
	else
		(seam :: BasePart).Color = color
	end
end
local function read(seam: Instance)
	local fx, a, b = seam:GetAttribute("SeamFx"), seam:GetAttribute("SeamA"), seam:GetAttribute("SeamB")
	local c, seed = seam:GetAttribute("SeamC"), seam:GetAttribute("SeamSeed")
	if typeof(fx) == "string" and typeof(a) == "Color3" then
		count += 1
		effects[seam] = {
			Fx = fx,
			A = a,
			B = if typeof(b) == "Color3" then b else a,
			C = if typeof(c) == "Color3" then c else nil,
			Seed = if type(seed) == "number" then seed else count % 17,
		}
	elseif effects[seam] then
		-- Restyled to a still seam: back to its own colour (SeamA).
		effects[seam] = nil
		if typeof(a) == "Color3" then
			paint(seam, a)
		end
	end
end
local function classify(seam: Instance)
	local me = Players.LocalPlayer
	local character = me and me.Character
	local place = LiveLooks.place(seam)
	views[seam] = if place == "View" then LiveLooks.viewOf(seam) else nil
	local mine = place == "View" or place == "Camera" or (character ~= nil and seam:IsDescendantOf(character))
	own[seam] = if mine then true else nil
	-- (Drawn nowhere: neither yours nor anyone's, so not checked at all.)
	boxes[seam] = if mine or place == "World" then true else false
	dirty = true
end
local function drop(seam: Instance)
	if boxes[seam] == nil then
		return
	end
	boxes[seam], effects[seam], own[seam], views[seam], showing[seam], near[seam] = nil, nil, nil, nil, nil, nil
	dirty = true
	for _, link in links[seam] or {} do
		link:Disconnect()
	end
	links[seam] = nil
end
local function add(instance: Instance)
	if (instance:IsA("SelectionBox") or instance:IsA("BasePart")) and boxes[instance] == nil then
		classify(instance)
		read(instance)
		links[instance] = {
			instance.AttributeChanged:Connect(function()
				read(instance)
			end),
			-- Moved (into a preview, onto a body) or gone: an untagged copy
			-- has no tag to lose, so it's forgotten as it leaves the game.
			LiveLooks.follow(instance, function()
				if boxes[instance] ~= nil then
					classify(instance)
				end
			end, function()
				drop(instance)
			end),
		}
	end
end

function SeamVisibility.start()
	for _, instance in CollectionService:GetTagged(Tags.SkinSeam) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.SkinSeam):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.SkinSeam):Connect(drop)
	-- Copies (first person, previews, gear art): by attribute (LiveLooks).
	LiveLooks.track("SeamFx", add)
	-- A new body: whose outlines are yours changes.
	local me = Players.LocalPlayer
	if me then
		me.CharacterAdded:Connect(function()
			for seam in boxes do
				classify(seam)
			end
		end)
	end
	local live: { [Instance]: boolean } = {} -- each preview: on screen this frame?
	local function check(seam: Instance, eye: Vector3?)
		local shows = SeamVisibility.shows(seam)
		local view = views[seam]
		if view and shows then
			local on = live[view]
			if on == nil then
				on = LiveLooks.onScreen(view)
				live[view] = on
			end
			shows = on
		end
		local box = if seam:IsA("SelectionBox") then seam else nil
		if box and box.Visible ~= shows then
			box.Visible = shows -- (a strip hides with its own part)
		end
		showing[seam] = shows
		if eye and effects[seam] then
			local part = if box then box.Adornee :: BasePart? else seam :: BasePart
			local position = part and part.CFrame.Position
			near[seam] = position == nil or (position - eye).Magnitude < SeamVisibility.FxRange
		end
	end
	local nextPartFx = 0
	-- Just after the camera (and the first-person view, which hides your own
	-- parts at Camera + 3), so a box never shows for a frame round the camera.
	RunService:BindToRenderStep("SkinSeams", Enum.RenderPriority.Camera.Value + 4, function()
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		table.clear(live)
		if dirty then
			dirty = false
			table.clear(others)
			for seam, drawn in boxes do
				if drawn and not own[seam] then
					table.insert(others, seam)
				end
			end
			cursor = 0
		end
		for seam in own do
			check(seam, nil)
			near[seam] = true
		end
		local n = #others
		local slice = if n <= SeamVisibility.SliceMin
			then n
			else math.max(SeamVisibility.SliceMin, math.ceil(n / SeamVisibility.Spread))
		for _ = 1, slice do
			cursor = cursor % n + 1
			check(others[cursor], eye)
		end
		local parts = t >= nextPartFx
		if parts then
			nextPartFx = t + 1 / SeamVisibility.PartFxRate
		end
		for seam, effect in effects do
			if showing[seam] and near[seam] ~= false and boxes[seam] then
				local box = seam:IsA("SelectionBox")
				if box or parts then
					paint(seam, SeamVisibility.fxColor(effect.Fx, effect.A, effect.B, t, effect.Seed, effect.C))
				end
			end
		end
	end)
end

return SeamVisibility
