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

	  SeamVisibility.shows(box)  pure: whether the box's part is showing
	  SeamVisibility.fxColor(fx, a, b, t, seed)  pure: an animated seam's colour
	  SeamVisibility.start()
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local SeamVisibility = {}

function SeamVisibility.shows(seam: Instance): boolean
	local part = if seam:IsA("SelectionBox") then seam.Adornee else seam
	return part ~= nil and part:IsA("BasePart") and part.Transparency < 0.99 and part.LocalTransparencyModifier < 0.99
end

local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

type Fx = { Fx: string, A: Color3, B: Color3, Seed: number }

-- The colour of an animated seam at time `t` (seconds). `seed` staggers
-- boxes a little, so a suit's seams don't all flash in lockstep.
function SeamVisibility.fxColor(fx: string, a: Color3, b: Color3, t: number, seed: number): Color3
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
	end
	return a
end

-- Cost: a neon suit has up to ~80 outlines, so a full server has well over a
-- thousand. Those round your own body (and the first-person view) are
-- checked every frame, since first person hides and shows your plates from
-- one frame to the next. Everyone else's only change when their gear is
-- staged or stowed, so they're checked a slice at a time: every one of them
-- every few frames (Spread). Animated outlines move only near the camera
-- (FxRange); far off, too small to see, they hold still.
SeamVisibility.Spread = 4
SeamVisibility.SliceMin = 64 -- (fewer outlines than this: all, every frame)
SeamVisibility.FxRange = 120
SeamVisibility.PartFxRate = 20

function SeamVisibility.start()
	local Players = game:GetService("Players")
	local boxes: { [Instance]: boolean } = {} -- every seam: SelectionBoxes and strips
	-- Animated seams, read once (and again only when a restyle changes them).
	local effects: { [Instance]: Fx } = {}
	local links: { [Instance]: RBXScriptConnection } = {}
	local own: { [Instance]: boolean } = {} -- on your body or in the camera
	local showing: { [Instance]: boolean } = {}
	local near: { [Instance]: boolean } = {}
	local others: { Instance } = {} -- everyone else's, checked a slice a frame
	local dirty, cursor, count = true, 0, 0
	local nextPartFx = 0
	local function paint(seam: Instance, color: Color3)
		if seam:IsA("SelectionBox") then
			seam.Color3 = color
		else
			(seam :: BasePart).Color = color
		end
	end
	local function read(seam: Instance)
		local fx, a, b = seam:GetAttribute("SeamFx"), seam:GetAttribute("SeamA"), seam:GetAttribute("SeamB")
		local seed = seam:GetAttribute("SeamSeed")
		if typeof(fx) == "string" and typeof(a) == "Color3" then
			count += 1
			effects[seam] = {
				Fx = fx,
				A = a,
				B = if typeof(b) == "Color3" then b else a,
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
		local camera = workspace.CurrentCamera
		local mine = (character ~= nil and seam:IsDescendantOf(character))
			or (camera ~= nil and seam:IsDescendantOf(camera))
		own[seam] = if mine then true else nil
		dirty = true
	end
	local function add(instance: Instance)
		if (instance:IsA("SelectionBox") or instance:IsA("BasePart")) and not boxes[instance] then
			boxes[instance] = true
			classify(instance)
			read(instance)
			links[instance] = instance.AttributeChanged:Connect(function()
				read(instance)
			end)
		end
	end
	for _, instance in CollectionService:GetTagged(Tags.SkinSeam) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.SkinSeam):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.SkinSeam):Connect(function(instance)
		boxes[instance], effects[instance], own[instance], showing[instance], near[instance] = nil, nil, nil, nil, nil
		dirty = true
		if links[instance] then
			links[instance]:Disconnect()
			links[instance] = nil
		end
	end)
	-- A new body: whose outlines are yours changes.
	local me = Players.LocalPlayer
	if me then
		me.CharacterAdded:Connect(function()
			for seam in boxes do
				classify(seam)
			end
		end)
	end
	local function check(seam: Instance, eye: Vector3?)
		local shows = SeamVisibility.shows(seam)
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
	-- Just after the camera (and the first-person view, which hides your own
	-- parts at Camera + 3), so a box never shows for a frame round the camera.
	RunService:BindToRenderStep("SkinSeams", Enum.RenderPriority.Camera.Value + 4, function()
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		if dirty then
			dirty = false
			table.clear(others)
			for seam in boxes do
				if not own[seam] then
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
			if showing[seam] and near[seam] ~= false then
				local box = seam:IsA("SelectionBox")
				if box or parts then
					paint(seam, SeamVisibility.fxColor(effect.Fx, effect.A, effect.B, t, effect.Seed))
				end
			end
		end
	end)
end

return SeamVisibility
