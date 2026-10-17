--[[
	A rift in the Outpost's sky: another dimension seeping in. It hangs in
	the north, 34 degrees up and past the red moon, so the moon and the
	stars pass in front of it. Each player's own client draws it (a
	BillboardGui far out in the black); the server sends nothing.

	  the void    a disc of the other side: a turning nebula, and stars in
	              colours ours doesn't have, inside a churning rim
	  ripples     rings that leave the rim one after another and spread out,
	              fading, like a stone dropped into space
	  vortex      three arms of motes turning slowly round it
	  seepage     sparks that leak out of the rim and drift out and down, and
	              glowing motes (3D) falling slowly toward the quarry
	  cracks      hairline fractures that flicker round the rim
	  surge       every few seconds the rim flares and a bright ring leaves

	  SkyRift.mount(at)    builds it for the Outpost centred on `at` (once)
	  SkyRift.show(on)     shows or hides it (hidden, nothing runs)
	  SkyRift.step(dt)     animates it (30 updates a second at most)
	  SkyRift.draw(parent) -> { update = function(t) }   the picture alone, in
	                       any square frame (the billboard, or a preview)

	The shape and the timing are plain functions, tested without Roblox
	(tests/sky_rift_cases.luau):
	  SkyRift.ripple(t, i)  ring i's size (a share of the rift) and fade at time t
	  SkyRift.surge(t)      how hard the rim flares at time t (0 to 1)
	  SkyRift.mote(t, k)    seeping spark k's place, size and fade at time t
	  SkyRift.crack(t, k)   whether crack k flickers on at time t
]]
local SkyRift = {}

SkyRift.Offset = { 315, 1455, -2135 } -- from the Outpost's middle: north, high, beyond the planets
SkyRift.Size = 1700 -- studs across: as far as a ripple goes
SkyRift.Void = 0.26 -- the opening, as a share of that
SkyRift.Rings, SkyRift.RingPeriod = 6, 6 -- ripples out at once, and the seconds each one takes
SkyRift.Motes, SkyRift.MoteLife = 20, 4.5 -- seeping sparks, and about how long each lasts
SkyRift.SurgeEvery, SkyRift.Cracks = 9, 7

local DEEP = Color3.fromRGB(40, 8, 72)
local VIOLET = Color3.fromRGB(150, 70, 255)
local MAGENTA = Color3.fromRGB(255, 70, 210)
local CYAN = Color3.fromRGB(80, 235, 255)
local WHITE = Color3.fromRGB(240, 235, 255)
local CRACK = Color3.fromRGB(235, 215, 255)
-- The other side's stars: pink, green and gold.
local ALIEN = { Color3.fromRGB(255, 120, 220), Color3.fromRGB(120, 255, 190), Color3.fromRGB(255, 214, 120), WHITE }

local function frac(x: number): number
	return x - math.floor(x)
end

-- Ring i (1 to Rings) at time t: its width as a share of the rift, how
-- transparent its line is (1 is gone), and how far it has sagged below the
-- middle as it spread (as if what comes through were heavy). It fades in
-- leaving the rim and out at the edge, so its restart is never seen.
function SkyRift.ripple(t: number, i: number): (number, number, number)
	local phase = frac(t / SkyRift.RingPeriod + (i - 1) / SkyRift.Rings)
	local grow = 1 - (1 - phase) ^ 2
	local show = math.min(1, phase / 0.08) * (1 - phase) ^ 1.6
	return SkyRift.Void + (0.94 - SkyRift.Void) * grow, 1 - 0.85 * show, 0.03 * grow
end

-- How hard the rim flares at time t: 1 as a surge starts, easing to 0 in a
-- second, then nothing until the next.
function SkyRift.surge(t: number): number
	return math.max(0, 1 - (t % SkyRift.SurgeEvery) / 1.1) ^ 2
end

-- Seeping spark k at time t: where it is (x and y as shares of the rift, 0.5
-- the middle), its size in pixels and how transparent it is. Each leaves the
-- rim and drifts out and down; every time round it takes a new angle.
function SkyRift.mote(t: number, k: number): (number, number, number, number)
	local life = SkyRift.MoteLife + (k * 0.618) % 1.5
	local run = t / life + k * 0.377
	local age = frac(run)
	local angle = k * 2.39996 + math.floor(run) * 0.9
	local r = SkyRift.Void / 2 + age * 0.22
	local x = 0.5 + math.cos(angle) * r
	local y = 0.5 + math.sin(angle) * r + age * age * 0.12
	local show = math.min(1, age / 0.1) * (1 - age) ^ 1.2
	return x, y, 3 + k % 3, 1 - show
end

-- Does crack k flicker on at time t? Now and then, for a seventh of a second.
function SkyRift.crack(t: number, k: number): boolean
	return frac(math.sin((math.floor(t * 7) + k * 17.3) * 12.9898) * 43758.5453) > 0.86
end

-- The picture -----------------------------------------------------------------------------

function SkyRift.draw(parent: Instance)
	local function new(className: string, props: { [string]: any }, under: Instance): any
		local object = Instance.new(className)
		if object:IsA("GuiObject") then
			object.BorderSizePixel = 0
		end
		for key, value in props do
			object[key] = value
		end
		object.Parent = under
		return object
	end
	-- A disc centred in `under`, `scale` of its width across.
	local function disc(under: Instance, scale: number, color: Color3, transparency: number, z: number): Frame
		local frame = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			ZIndex = z,
		}, under)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
		return frame
	end
	-- An outline round `frame` in shifting colours: the line, and its sheen
	-- (turn the sheen to make the colours run round). `broken` breaks the
	-- line into uneven arcs, which swirl as the sheen turns.
	local function outline(
		frame: Frame,
		thickness: number,
		transparency: number,
		colors: { Color3 },
		broken: boolean?
	): (UIStroke, UIGradient)
		local line = new("UIStroke", {
			Thickness = thickness,
			Transparency = transparency,
			Color = Color3.new(1, 1, 1),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, frame)
		local keys = {}
		for i, color in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
		end
		local sheen = new("UIGradient", { Color = ColorSequence.new(keys) }, line)
		if broken then
			sheen.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.16, 0.1),
				NumberSequenceKeypoint.new(0.3, 0.9),
				NumberSequenceKeypoint.new(0.44, 0.15),
				NumberSequenceKeypoint.new(0.6, 0),
				NumberSequenceKeypoint.new(0.76, 0.95),
				NumberSequenceKeypoint.new(0.88, 0.3),
				NumberSequenceKeypoint.new(1, 0),
			})
		end
		return line, sheen
	end
	local SHIMMER = { CYAN, VIOLET, MAGENTA, Color3.fromRGB(255, 214, 120), CYAN }

	local canvas = new("Frame", { Name = "Rift", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	-- A violet haze round it, deepest in the middle (many faint layers, so it
	-- fades smoothly rather than in bands).
	local HAZE = {
		{ 1, DEEP, 0.95 },
		{ 0.86, DEEP, 0.94 },
		{ 0.72, VIOLET, 0.95 },
		{ 0.6, VIOLET, 0.93 },
		{ 0.5, VIOLET, 0.91 },
		{ 0.42, MAGENTA, 0.9 },
		{ 0.36, MAGENTA, 0.87 },
	}
	local haze = {}
	for i, spec in HAZE do
		haze[i] = disc(canvas, spec[1], spec[2], spec[3], 1)
	end
	-- Three arms of motes, turning.
	local vortex = new("Frame", {
		Name = "Vortex",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, canvas)
	for arm = 0, 2 do
		for j = 1, 12 do
			local r = SkyRift.Void / 2 + 0.02 + j * 0.024
			local a = math.rad(arm * 120 + j * 21)
			local dot = disc(vortex, 0.013 - j * 0.0006, VIOLET:Lerp(CYAN, j / 12), 0.25 + j * 0.05, 2)
			dot.Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r)
		end
	end
	-- The ripples, and the bright ring a surge sends out.
	local rings = {}
	for i = 1, SkyRift.Rings do
		local frame = disc(canvas, SkyRift.Void, WHITE, 1, 3)
		local line, sheen = outline(frame, 2 + i % 3, 1, SHIMMER, true)
		rings[i] = { Frame = frame, Line = line, Sheen = sheen }
	end
	local flare = disc(canvas, SkyRift.Void, WHITE, 1, 3)
	local flareLine = outline(flare, 6, 1, { WHITE, CYAN, WHITE })
	-- The glow round the opening.
	local corona = { disc(canvas, 0.37, MAGENTA, 0.8, 4), disc(canvas, 0.31, VIOLET, 0.6, 4) }
	-- The opening: the other side's nebula turning, a swirl of light across
	-- it, and its stars.
	local void = disc(canvas, SkyRift.Void, WHITE, 0, 5)
	void.Name = "Void"
	local nebula = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 0, 52)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(8, 30, 70)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(70, 0, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 60, 80)),
		}),
	}, void)
	local swirl = new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 0.6),
			NumberSequenceKeypoint.new(0.55, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, disc(void, 0.8, CYAN, 0, 6))
	local stars = {}
	for k = 1, 14 do
		local a, r = k * 2.39996, 0.08 + (k * 0.618) % 1 * 0.3
		local star = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r),
			Size = UDim2.fromOffset(2 + k % 2, 2 + k % 2),
			BackgroundColor3 = ALIEN[k % #ALIEN + 1],
			ZIndex = 7,
		}, void)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, star)
		stars[k] = star
	end
	local rim, rimSheen = outline(void, 3, 0.05, { WHITE, CYAN, MAGENTA, WHITE })
	local halo, haloSheen = outline(disc(canvas, SkyRift.Void + 0.025, WHITE, 1, 5), 7, 0.55, { VIOLET, MAGENTA, CYAN })
	-- Cracks running out from the rim, each with a fork.
	local cracks = {}
	for k = 1, SkyRift.Cracks do
		local a = k * 51.4 + (k % 2) * 17
		local length = 0.07 + (k % 3) * 0.025
		local reach = SkyRift.Void / 2 + length / 2
		local crack = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(math.rad(a)) * reach, 0.5 + math.sin(math.rad(a)) * reach),
			Size = UDim2.new(length, 0, 0, 2),
			Rotation = a,
			BackgroundColor3 = CRACK,
			BackgroundTransparency = 1,
			ZIndex = 8,
		}, canvas)
		local fork = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.75, 0.5),
			Size = UDim2.new(0.5, 0, 0, 2),
			Rotation = if k % 2 == 0 then 35 else -35,
			BackgroundColor3 = CRACK,
			BackgroundTransparency = 1,
			ZIndex = 8,
		}, crack)
		cracks[k] = { crack, fork }
	end
	-- The sparks seeping out.
	local motes = {}
	for k = 1, SkyRift.Motes do
		local mote = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = ({ CYAN, VIOLET, MAGENTA, WHITE })[k % 4 + 1],
			BackgroundTransparency = 1,
			ZIndex = 9,
		}, canvas)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, mote)
		motes[k] = mote
	end

	local function update(t: number)
		local surge = SkyRift.surge(t)
		local breathe = math.sin(t * 1.3)
		for i, frame in haze do
			local s = HAZE[i][1] * (1 + 0.025 * math.sin(t * 0.7 + i))
			frame.Size = UDim2.fromScale(s, s)
		end
		vortex.Rotation = (t * 5) % 360
		for i, ring in rings do
			local scale, fade, drop = SkyRift.ripple(t, i)
			ring.Frame.Size = UDim2.fromScale(scale, scale)
			ring.Frame.Position = UDim2.fromScale(0.5, 0.5 + drop)
			ring.Line.Transparency = fade
			ring.Sheen.Rotation = (t * (if i % 2 == 0 then 40 else -55) + i * 60) % 360
		end
		local since = math.min(1, (t % SkyRift.SurgeEvery) / 1.6)
		local out = SkyRift.Void + (0.94 - SkyRift.Void) * (1 - (1 - since) ^ 2)
		flare.Size = UDim2.fromScale(out, out)
		flareLine.Transparency = if since < 1 then 0.1 + 0.9 * since else 1
		flareLine.Thickness = 2 + 6 * (1 - since)
		local glow = 0.37 + 0.01 * breathe + 0.05 * surge
		corona[1].Size = UDim2.fromScale(glow, glow)
		corona[1].BackgroundTransparency = 0.8 - 0.25 * surge
		corona[2].BackgroundTransparency = 0.6 - 0.2 * surge
		local open = SkyRift.Void * (1 + 0.02 * breathe + 0.06 * surge)
		void.Size = UDim2.fromScale(open, open)
		nebula.Rotation = (t * 12) % 360
		swirl.Rotation = (-t * 30) % 360
		for k, star in stars do
			star.BackgroundTransparency = 0.15 + 0.6 * (0.5 + 0.5 * math.sin(t * (1.5 + k % 3) + k))
		end
		rim.Thickness = 3 + 3 * surge
		rimSheen.Rotation = (-t * 90) % 360
		halo.Transparency = 0.55 - 0.35 * surge
		haloSheen.Rotation = (t * 25) % 360
		for k, pair in cracks do
			local lit = surge > 0.3 or SkyRift.crack(t, k)
			pair[1].BackgroundTransparency = if lit then 0.1 else 1
			pair[2].BackgroundTransparency = if lit then 0.3 else 1
		end
		for k, mote in motes do
			local x, y, size, fade = SkyRift.mote(t, k)
			mote.Position = UDim2.fromScale(x, y)
			mote.Size = UDim2.fromOffset(size, size)
			mote.BackgroundTransparency = fade
		end
	end
	update(0)
	return { Canvas = canvas, update = update }
end

-- In the sky ------------------------------------------------------------------------------

local rift = nil

function SkyRift.mount(at: CFrame)
	if rift then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SkyRift"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.CastShadow, anchor.Transparency, anchor.Size = false, 1, Vector3.one
	anchor.CFrame = at * CFrame.new(SkyRift.Offset[1], SkyRift.Offset[2], SkyRift.Offset[3])
	local gui = Instance.new("BillboardGui")
	gui.Name = "Rift"
	gui.Size = UDim2.fromScale(SkyRift.Size, SkyRift.Size) -- (a billboard's scale is studs)
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local drawn = SkyRift.draw(gui)
	-- Glowing motes falling out of it toward the quarry, slowly.
	local seep = Instance.new("ParticleEmitter")
	seep.Rate = 5
	seep.Lifetime = NumberRange.new(10, 16)
	seep.Speed = NumberRange.new(40, 90)
	seep.SpreadAngle = Vector2.new(70, 70)
	seep.EmissionDirection = Enum.NormalId.Bottom
	seep.Acceleration = Vector3.new(0, -6, 0)
	seep.Drag = 0.15
	seep.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 24),
		NumberSequenceKeypoint.new(0.4, 55),
		NumberSequenceKeypoint.new(1, 18),
	})
	seep.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	seep.Color = ColorSequence.new(VIOLET, CYAN)
	seep.LightEmission, seep.LightInfluence = 1, 0
	seep.Rotation, seep.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-30, 30)
	seep.Enabled = false
	seep.Parent = anchor
	anchor.Parent = workspace
	rift = { Gui = gui, Seep = seep, Drawn = drawn, T = 0, Since = 0, Shown = false }
end

function SkyRift.show(on: boolean)
	if rift and rift.Shown ~= on then
		rift.Shown = on
		rift.Gui.Enabled, rift.Seep.Enabled = on, on
	end
end

function SkyRift.step(dt: number)
	if not (rift and rift.Shown) then
		return
	end
	rift.T += dt
	rift.Since += dt
	if rift.Since >= 1 / 30 then
		rift.Since = 0
		rift.Drawn.update(rift.T)
	end
end

return SkyRift
