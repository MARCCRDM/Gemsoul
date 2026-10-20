--[[
	A rift in the Outpost's sky: a rip in space, with another dimension
	showing through. It hangs in the north, 34 degrees up, beyond the
	stars: nothing else is in the sky. Each player's own client draws it (a
	BillboardGui far out in the black); the server sends nothing.

	  the tear    a long, jagged rip leaning like "/", pointed at both ends
	              and ragged along both sides, with the other side inside:
	              a nebula flowing down it (soft, brightest down the
	              middle), a white-hot filament, and stars in colours ours
	              doesn't have
	  edges       white-hot torn edges in a soft glow, frayed, one side a
	              shade warmer and the other a shade cooler, flickering
	  haze        the rift's violet glow spilling into the black, in soft
	              bands that fade out to both sides
	  rays        long faint shafts of its light breaking out sideways
	  cracks      fractures running on into space from its ends and sides,
	              faint, and flashing now and then
	  shards      dark slivers of the sky breaking off its edges, lit only
	              along their rims, spinning away and fading
	  seepage     sparks that leak from its edges and drift out and down, and
	              glowing motes (3D) falling slowly toward the quarry
	  surge       every few seconds it flares: the edges blaze, the glow
	              swells and every crack lights

	  SkyRift.mount(at)    builds it for the Outpost centred on `at` (once)
	  SkyRift.show(on)     shows or hides it (hidden, nothing runs)
	  SkyRift.step(dt)     animates it (30 updates a second at most)
	  SkyRift.draw(parent) -> { update = function(t) }   the picture alone, in
	                       any square frame (the billboard, or a preview)

	The shape and the timing are plain functions, tested without Roblox
	(tests/sky_rift_cases.luau):
	  SkyRift.tear()        the tear: { Spine, Left, Right }, points top to
	                        bottom as shares of the picture ({ x, y }, x right,
	                        y down, the middle at 0.5)
	  SkyRift.surge(t)      how hard it flares at time t (0 to 1)
	  SkyRift.mote(t, k)    seeping spark k's place, size and fade at time t
	  SkyRift.shard(t, k)   breaking shard k's place, turn, size and fade
	  SkyRift.crack(t, k)   whether crack k flashes at time t
]]
local SkyRift = {}

SkyRift.Offset = { 315, 1455, -2135 } -- from the Outpost's middle: north, high, beyond the stars
SkyRift.Size = 1700 -- studs across: the picture, glow and all
SkyRift.Length, SkyRift.Width = 0.64, 0.15 -- the tear's length, and its widest, as shares of that
SkyRift.Tilt = 28 -- degrees it leans from upright, its top to the right
SkyRift.Points = 19 -- down each edge, tips included
SkyRift.Motes, SkyRift.MoteLife = 20, 4.5 -- seeping sparks, and about how long each lasts
SkyRift.Shards, SkyRift.ShardLife = 12, 7 -- breaking shards, and about how long each lasts
SkyRift.SurgeEvery, SkyRift.Cracks = 9, 8
SkyRift.Rays = 7 -- shafts of light breaking out of it
SkyRift.HazeSteps = 11 -- slices along each band of its glow (more: smoother ends)

-- One light, the rift's violet, from deep in the black to white-hot at the
-- tear; its two torn sides a shade warmer and a shade cooler.
local DEEP = Color3.fromRGB(34, 10, 70) -- the glow at its farthest
local INSIDE = Color3.fromRGB(8, 4, 22) -- the other side's dark
local VIOLET = Color3.fromRGB(122, 64, 230)
local GLOW_EDGE = Color3.fromRGB(196, 168, 255) -- the glow nearest the tear, and the rays
local EDGE_WARM = Color3.fromRGB(236, 150, 255)
local EDGE_COOL = Color3.fromRGB(150, 182, 255)
local WHITE = Color3.fromRGB(244, 240, 255)
local CRACK = Color3.fromRGB(226, 210, 255)
local SHARD = Color3.fromRGB(10, 8, 20) -- a sliver of the black, breaking off
-- The other side's stars: pink, green and gold.
local ALIEN = { Color3.fromRGB(255, 120, 220), Color3.fromRGB(120, 255, 190), Color3.fromRGB(255, 214, 120), WHITE }
-- The nebula inside, along the tear, top to bottom.
local NEBULA = { Color3.fromRGB(96, 44, 186), Color3.fromRGB(44, 120, 176), Color3.fromRGB(156, 54, 168) }

local function frac(x: number): number
	return x - math.floor(x)
end

-- The same jitter every time for the same i (0 to 1).
local function hash(i: number, salt: number): number
	return frac(math.sin(i * 12.9898 + salt * 78.233) * 43758.5453)
end

-- Its axes: down along the tear, and across it (to the right, going down).
local function axes(): ({ number }, { number })
	local a = math.rad(SkyRift.Tilt)
	return { -math.sin(a), math.cos(a) }, { math.cos(a), math.sin(a) }
end

local shape = nil

-- The tear: points down its middle (bending a little, and zigzagging) and
-- along its torn edges. It's widest in the middle and pointed at both ends,
-- and each side is torn to its own ragged width.
function SkyRift.tear(): { Spine: { { number } }, Left: { { number } }, Right: { { number } } }
	if shape then
		return shape
	end
	local down, across = axes()
	local n = SkyRift.Points
	local spine, left, right = {}, {}, {}
	for i = 1, n do
		local s = (i - 1) / (n - 1)
		local along = (s - 0.5) * SkyRift.Length
		local bend = 0.03 * math.sin(s * math.pi * 2.2 + 0.5) + (if i % 2 == 0 then 1 else -1) * 0.006 * hash(i, 1)
		local x = 0.5 + down[1] * along + across[1] * bend
		local y = 0.5 + down[2] * along + across[2] * bend
		local half = SkyRift.Width / 2 * math.sin(math.pi * s) ^ 0.7
		local l, r = half * (0.45 + 0.55 * hash(i, 2)), half * (0.45 + 0.55 * hash(i, 3))
		spine[i] = { x, y }
		left[i] = { x - across[1] * l, y - across[2] * l }
		right[i] = { x + across[1] * r, y + across[2] * r }
	end
	shape = { Spine = spine, Left = left, Right = right }
	return shape
end

-- How hard it flares at time t: 1 as a surge starts, easing to 0 in a
-- second, then nothing until the next.
function SkyRift.surge(t: number): number
	return math.max(0, 1 - (t % SkyRift.SurgeEvery) / 1.1) ^ 2
end

-- Where something leaving an edge starts: an edge point away from the tips
-- (a new one each time round), and which way is out.
local function fromEdge(k: number, turn: number): ({ number }, number)
	local tear = SkyRift.tear()
	local n = #tear.Spine
	local i = 3 + (k * 5 + turn * 3) % (n - 4)
	if (k + turn) % 2 == 0 then
		return tear.Left[i], -1
	end
	return tear.Right[i], 1
end

-- Seeping spark k at time t: where it is (shares of the picture), its size
-- in pixels and how transparent it is. Each leaves an edge and drifts out
-- and down, fading in and out.
function SkyRift.mote(t: number, k: number): (number, number, number, number)
	local life = SkyRift.MoteLife + (k * 0.618) % 1.5
	local run = t / life + k * 0.377
	local age = frac(run)
	local at, side = fromEdge(k, math.floor(run))
	local _, across = axes()
	local out = 0.005 + age * 0.08
	local x = at[1] + across[1] * side * out
	local y = at[2] + across[2] * side * out + age * age * 0.1
	local show = math.min(1, age / 0.1) * (1 - age) ^ 1.2
	return x, y, 3 + k % 3, 1 - show
end

-- Breaking shard k at time t: where it is, its turn in degrees, its size (a
-- share of the picture) and how transparent it is. Each comes away from an
-- edge, spinning, drifts slowly off and fades.
function SkyRift.shard(t: number, k: number): (number, number, number, number, number)
	local life = SkyRift.ShardLife + (k * 0.618) % 2
	local run = t / life + k * 0.29
	local age = frac(run)
	local at, side = fromEdge(k + 7, math.floor(run))
	local _, across = axes()
	local out = 0.008 + age * 0.07
	local x = at[1] + across[1] * side * out
	local y = at[2] + across[2] * side * out + age * age * 0.025
	local turn = (k * 47 + age * (if k % 2 == 0 then 150 else -120)) % 360
	local size = (0.014 + (k % 3) * 0.004) * (1 - 0.45 * age)
	local show = math.min(1, age / 0.08) * (1 - age) ^ 1.3
	return x, y, turn, size, 1 - show
end

-- Does crack k flash at time t? Now and then, for a seventh of a second.
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
	-- A bar from a to b (shares of the picture, which is square), `thick`
	-- pixels thick, or `wide` of the picture if given.
	local function bar(under: Instance, a: { number }, b: { number }, thick: number, z: number, wide: number?): Frame
		local dx, dy = b[1] - a[1], b[2] - a[2]
		return new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale((a[1] + b[1]) / 2, (a[2] + b[2]) / 2),
			Size = UDim2.new(math.sqrt(dx * dx + dy * dy), 2, wide or 0, if wide then 0 else thick),
			Rotation = math.deg(math.atan2(dy, dx)),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			ZIndex = z,
		}, under)
	end
	local function round(frame: Frame)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	end
	-- A soft falloff across a frame: clear at both sides, `core` at the
	-- middle (its transparency there). `turn` 0 fades across its width, 90
	-- across its height (a bar's thickness).
	local function soft(frame: Frame, core: number, turn: number, colors: ColorSequence?)
		new("UIGradient", {
			Rotation = turn,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, core),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = colors or ColorSequence.new(WHITE),
		}, frame)
	end
	local function mix(a: { number }, b: { number }, f: number): { number }
		return { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f }
	end
	local function apart(a: { number }, b: { number }): number
		return math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
	end

	local tear = SkyRift.tear()
	local spine, left, right = tear.Spine, tear.Left, tear.Right
	local n = #spine
	local down, across = axes()
	-- (What fills it runs down the middle between its edges, and is as wide
	-- as the gap there.)
	local mids, gaps = {}, {}
	for i = 1, n do
		mids[i], gaps[i] = mix(left[i], right[i], 0.5), apart(left[i], right[i])
	end

	local canvas = new("Frame", { Name = "Rift", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local swell = new("UIScale", { Scale = 1 }, canvas)
	-- The glow it casts into the black: three long soft bands along it (the
	-- widest the faintest and the deepest in colour; each its width, length,
	-- strength and colour across), each fading out to both sides and, in
	-- steps along it, to both ends: no hard edges.
	local HAZE = {
		{ 0.46, 0.98, 0.45, ColorSequence.new(DEEP, VIOLET:Lerp(DEEP, 0.35)) },
		{ 0.26, 0.86, 0.6, ColorSequence.new(VIOLET:Lerp(DEEP, 0.25), VIOLET) },
		{ 0.12, 0.74, 0.7, ColorSequence.new(VIOLET, GLOW_EDGE) },
	}
	local haze = {}
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Rotation = SkyRift.Tilt,
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, canvas)
	for i, spec in HAZE do
		for k = 1, SkyRift.HazeSteps do
			local s = (k - 0.5) / SkyRift.HazeSteps
			local frame = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5 + (s - 0.5) * spec[2]),
				Size = UDim2.fromScale(
					spec[1] * (0.55 + 0.45 * math.sin(math.pi * s) ^ 0.5),
					spec[2] / SkyRift.HazeSteps + 0.002
				),
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 1,
				ZIndex = 1,
			}, holder)
			soft(frame, 0.05, 0, spec[4])
			table.insert(haze, { Frame = frame, Layer = i, Fade = math.sin(math.pi * s) ^ 1.4 })
		end
	end
	-- Light breaking out of it: long faint rays fanning from its middle,
	-- each fading away from the tear.
	local rays = {}
	for k = 1, SkyRift.Rays do
		local i = 4 + (k * 7) % (n - 7)
		local sign = if k % 2 == 0 then -1 else 1
		local from = if sign < 0 then left[i] else right[i]
		local way = math.atan2(across[2] * sign, across[1] * sign) + (hash(k, 15) - 0.5) * 1.6
		local reach = 0.07 + 0.16 * hash(k, 16)
		local to = { from[1] + math.cos(way) * reach, from[2] + math.sin(way) * reach }
		local ray = bar(canvas, from, to, 0, 2, 0.005 + 0.008 * hash(k, 17))
		ray.BackgroundColor3 = GLOW_EDGE
		ray.BackgroundTransparency = 0.8
		-- (bright at the tear, gone at its tip)
		new("UIGradient", {
			Rotation = 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, ray)
		rays[k] = { Frame = ray, Seed = k * 1.37 }
	end
	-- Cracks running on into space: from both ends, along it, and from its
	-- sides, out; each a zigzag of three, thin and faint until they flash.
	local cracks = {}
	for k = 1, SkyRift.Cracks do
		local at, way
		if k <= 2 then
			local sign = if k == 1 then -1 else 1
			at = if k == 1 then spine[1] else spine[n]
			way = math.atan2(down[2] * sign, down[1] * sign)
		else
			local i = 3 + (k * 4) % (n - 5)
			local sign = if k % 2 == 0 then -1 else 1
			at = if sign < 0 then left[i] else right[i]
			way = math.atan2(across[2] * sign, across[1] * sign)
		end
		local lines = {}
		local from = at
		for j = 1, 3 do
			local turn = way + (hash(k * 3 + j, 5) - 0.5) * 1.3
			local reach = 0.022 + 0.022 * hash(k * 3 + j, 6)
			local to = { from[1] + math.cos(turn) * reach, from[2] + math.sin(turn) * reach }
			local line = bar(canvas, from, to, 1, 3)
			line.BackgroundColor3 = CRACK
			table.insert(lines, line)
			from = to
		end
		cracks[k] = lines
	end
	-- The tear itself: the dark of the other side, in slices that follow its
	-- ragged width (two to each stretch between points).
	for i = 1, n - 1 do
		for half = 0, 1 do
			local f0, f1 = half / 2, (half + 1) / 2
			local a, b = mix(mids[i], mids[i + 1], f0), mix(mids[i], mids[i + 1], f1)
			local w0 = gaps[i] * (1 - f0) + gaps[i + 1] * f0
			local w1 = gaps[i] * (1 - f1) + gaps[i + 1] * f1
			local slice = bar(canvas, a, b, 0, 4, math.max(w0, w1))
			slice.BackgroundColor3 = INSIDE
			slice.BackgroundTransparency = 0
		end
	end
	-- Its depths: a nebula of the other side's light flowing down it, soft
	-- across its width (deep at the torn edges, brightest down the middle),
	-- and a filament of white-hot light down the very middle.
	local flow, filament = {}, {}
	for i = 1, n - 1 do
		local s = (i - 0.5) / (n - 1)
		local glow = bar(canvas, mids[i], mids[i + 1], 0, 5, math.min(gaps[i], gaps[i + 1]) * 0.9)
		glow.BackgroundColor3 = WHITE
		local tint = if s < 0.5 then NEBULA[1]:Lerp(NEBULA[2], s * 2) else NEBULA[2]:Lerp(NEBULA[3], s * 2 - 1)
		soft(
			glow,
			0.05,
			90,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, INSIDE:Lerp(tint, 0.4)),
				ColorSequenceKeypoint.new(0.5, tint),
				ColorSequenceKeypoint.new(1, INSIDE:Lerp(tint, 0.4)),
			})
		)
		flow[i] = glow
		local line = bar(canvas, mids[i], mids[i + 1], 3, 6)
		line.BackgroundColor3 = WHITE:Lerp(GLOW_EDGE, s * 0.6)
		soft(line, 0, 90)
		filament[i] = line
	end
	-- The other side's stars, inside it.
	local stars = {}
	for k = 1, 16 do
		local i = 3 + (k * 5) % (n - 4)
		local u = (hash(k, 4) - 0.5) * gaps[i] * 0.7
		local star = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(mids[i][1] + across[1] * u, mids[i][2] + across[2] * u),
			Size = UDim2.fromOffset(2 + k % 2, 2 + k % 2),
			BackgroundColor3 = ALIEN[k % #ALIEN + 1],
			ZIndex = 7,
		}, canvas)
		round(star)
		stars[k] = star
	end
	-- The torn edges: a soft glow (warmer down one side, cooler down the
	-- other, both the rift's violet) round a white-hot line.
	local edges = {}
	for side, points in { left, right } do
		local tint = if side == 1 then EDGE_WARM else EDGE_COOL
		for i = 1, n - 1 do
			local glow = bar(canvas, points[i], points[i + 1], 14, 8)
			glow.BackgroundColor3 = tint
			soft(glow, 0, 90)
			local core = bar(canvas, points[i], points[i + 1], 2, 9)
			core.BackgroundColor3 = WHITE
			core.BackgroundTransparency = 0.05
			table.insert(edges, { Glow = glow, Core = core, Seed = i * 1.7 + side * 3.1 })
			-- (Frayed: a torn thread sticking out of the edge.)
			local sign = if side == 1 then -1 else 1
			local at = mix(points[i], points[i + 1], hash(i * 2 + 1, side + 9))
			local turn = math.atan2(across[2] * sign, across[1] * sign) + (hash(i * 2 + 1, side + 11) - 0.5) * 1.6
			local reach = 0.006 + 0.012 * hash(i * 2 + 1, side + 13)
			local thread = bar(canvas, at, { at[1] + math.cos(turn) * reach, at[2] + math.sin(turn) * reach }, 1, 9)
			thread.BackgroundColor3 = WHITE:Lerp(tint, 0.5)
			thread.BackgroundTransparency = 0.35
		end
	end
	-- Pieces of the sky breaking away: dark slivers of the black, lit only
	-- along their edges, each its own long shape.
	local shards = {}
	for k = 1, SkyRift.Shards do
		local shard = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			BackgroundColor3 = SHARD,
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, canvas)
		local rim = new("UIStroke", {
			Thickness = 1,
			Color = if k % 2 == 0 then EDGE_WARM else EDGE_COOL,
			Transparency = 1,
		}, shard)
		shards[k] = { Frame = shard, Rim = rim, Long = 1.4 + hash(k, 21) * 1.4 }
	end
	-- The sparks seeping out.
	local motes = {}
	for k = 1, SkyRift.Motes do
		local mote = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = ({ EDGE_COOL, VIOLET, EDGE_WARM, WHITE })[k % 4 + 1],
			BackgroundTransparency = 1,
			ZIndex = 11,
		}, canvas)
		round(mote)
		motes[k] = mote
	end

	local lastSurge, lastGlow = -1, -1
	local function update(t: number)
		local surge = SkyRift.surge(t)
		local breathe = math.sin(t * 1.3)
		swell.Scale = 1 + 0.008 * breathe + 0.03 * surge
		-- (The haze breathes; its depth and the edges' width change only in a
		-- surge.)
		local glow = 0.04 * math.sin(t * 0.7)
		if math.abs(surge - lastSurge) > 0.01 or math.abs(glow - lastGlow) > 0.01 then
			lastSurge, lastGlow = surge, glow
			for _, band in haze do
				local depth = HAZE[band.Layer][3]
				band.Frame.BackgroundTransparency = 1 - math.min(1, depth * band.Fade * (1 + 0.45 * surge) + glow)
			end
			for _, edge in edges do
				edge.Glow.Size = UDim2.new(edge.Glow.Size.X.Scale, 2, 0, 14 + 10 * surge)
			end
		end
		for _, ray in rays do
			ray.Frame.BackgroundTransparency =
				math.clamp(0.72 + 0.22 * (0.5 + 0.5 * math.sin(t * 0.45 + ray.Seed * 2.3)) - 0.3 * surge, 0, 1)
		end
		for k, lines in cracks do
			local lit = surge > 0.3 or SkyRift.crack(t, k)
			for j, line in lines do
				line.BackgroundTransparency = if lit then 0.1 + 0.15 * j else 0.8 + 0.05 * j
			end
		end
		for i, glow in flow do
			glow.BackgroundTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * 1.2 - i * 0.3)) - 0.15 * surge
		end
		for i, line in filament do
			line.BackgroundTransparency = 0.2 + 0.3 * (0.5 + 0.5 * math.sin(t * 2.3 - i * 0.8)) - 0.2 * surge
		end
		for k, star in stars do
			star.BackgroundTransparency = 0.15 + 0.6 * (0.5 + 0.5 * math.sin(t * (1.5 + k % 3) + k))
		end
		for _, edge in edges do
			local flicker = 0.5 + 0.5 * math.sin(t * 6.3 + edge.Seed * 2.1) * math.sin(t * 2.9 + edge.Seed)
			edge.Glow.BackgroundTransparency = math.max(0, 0.15 + 0.3 * flicker - 0.15 * surge)
		end
		for k, shard in shards do
			local x, y, turn, size, fade = SkyRift.shard(t, k)
			shard.Frame.Position = UDim2.fromScale(x, y)
			shard.Frame.Size = UDim2.fromScale(size * shard.Long, size / shard.Long)
			shard.Frame.Rotation = turn
			shard.Frame.BackgroundTransparency = fade
			shard.Rim.Transparency = 0.3 + 0.7 * fade
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
	anchor.CastShadow, anchor.Transparency = false, 1
	-- (Facing the quarry and leaning as the tear does, so the motes fall out
	-- all along it.)
	local middle = at * CFrame.new(SkyRift.Offset[1], SkyRift.Offset[2], SkyRift.Offset[3])
	anchor.CFrame = CFrame.lookAt(middle.Position, at.Position) * CFrame.Angles(0, 0, math.rad(SkyRift.Tilt))
	anchor.Size = Vector3.new(SkyRift.Size * SkyRift.Width * 0.5, SkyRift.Size * SkyRift.Length * 0.8, 1)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Rift"
	gui.Size = UDim2.fromScale(SkyRift.Size, SkyRift.Size) -- (a billboard's scale is studs)
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local drawn = SkyRift.draw(gui)
	-- Glowing motes spilling out of it toward the quarry, slowly.
	local seep = Instance.new("ParticleEmitter")
	seep.Rate = 5
	seep.Lifetime = NumberRange.new(10, 16)
	seep.Speed = NumberRange.new(40, 90)
	seep.SpreadAngle = Vector2.new(50, 50)
	seep.EmissionDirection = Enum.NormalId.Front
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
	seep.Color = ColorSequence.new(VIOLET, EDGE_COOL)
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
