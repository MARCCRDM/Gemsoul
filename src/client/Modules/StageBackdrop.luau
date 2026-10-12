--[[
	The Inventory's miner stage: an observation bay over a ringed planet.

	  Viewport    a tall window behind the active miner: deep space, stars, a
	              ringed planet rising with a lit limb, steel mullions
	  Bulkheads   dark pillars either side with teal light strips that breathe
	  Backlight   a soft rim glow (stacked rings) behind the active miner
	  Floor       a dark, glossy deck with a horizon haze, a lit pedestal under
	              each miner (the middle one largest, with a pulsing ring)

	Built once (create), only moved each frame (update).

	  StageBackdrop.create(stage) -> backdrop
	  StageBackdrop.update(backdrop, time)
]]
local StageBackdrop = {}

local GOLD = Color3.fromRGB(255, 196, 82)
local GOLD_HOT = Color3.fromRGB(255, 232, 170)
local TEAL = Color3.fromRGB(64, 214, 230)
local NAVY = Color3.fromRGB(8, 12, 22)
local STEEL = Color3.fromRGB(22, 28, 38)
local SEAM = Color3.fromRGB(110, 150, 170)
local HORIZON = 0.62 -- where the back wall meets the floor (fraction of height)
local MOTES = 18

-- Where the miners stand (fractions of the stage): the two waiting in the
-- top corners and the active one in the middle.
local PEDESTALS = {
	{ X = 0.09, Y = 0.37, W = 0.1, Main = false },
	{ X = 0.5, Y = 0.88, W = 0.26, Main = true },
	{ X = 0.91, Y = 0.37, W = 0.1, Main = false },
}

local seeded
local function seededStatic(i: number, salt: number): number
	local x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453
	return x - math.floor(x)
end

local function make(class: string, props, parent: Instance): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function slab(parent: Instance, props)
	local frame = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 0 }, parent)
	for key, value in props do
		frame[key] = value
	end
	return frame
end

local function fade(parent: Instance, rotation: number, from: number, to: number, mid: number?)
	return make("UIGradient", {
		Rotation = rotation,
		Transparency = if mid
			then NumberSequence.new({
				NumberSequenceKeypoint.new(0, from),
				NumberSequenceKeypoint.new(0.5, mid),
				NumberSequenceKeypoint.new(1, to),
			})
			else NumberSequence.new(from, to),
	}, parent)
end

function StageBackdrop.create(stage: GuiObject)
	local root = make("Frame", {
		Name = "StageBackdrop",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		ClipsDescendants = true,
	}, stage)

	-- The bay: near-black navy, lifting a little toward the floor.
	local wall = slab(root, { Size = UDim2.fromScale(1, HORIZON), BackgroundColor3 = NAVY })
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(4, 6, 12), Color3.fromRGB(16, 24, 36)) }, wall)

	-- The viewport: space, stars and a ringed planet.
	local window = slab(root, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.06),
		Size = UDim2.fromScale(0.56, HORIZON - 0.06),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
	})
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 6, 18)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(22, 16, 48)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 60, 78)),
		}),
	}, window)
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, window)
	for i = 1, 46 do
		local big = i % 9 == 0
		local star = slab(window, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(seededStatic(i, 7), seededStatic(i, 9) * 0.7),
			Size = UDim2.fromOffset(if big then 3 else 2, if big then 3 else 2),
			BackgroundTransparency = 0.2 + seededStatic(i, 11) * 0.6,
		})
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, star)
	end
	-- The planet: a huge disc rising from the bottom of the window, lit on
	-- its upper limb, with a thin ring across it.
	local planet = slab(window, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.62, 0.58),
		Size = UDim2.fromScale(1.3, 1.3),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
	})
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, planet)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 220, 230)),
			ColorSequenceKeypoint.new(0.04, Color3.fromRGB(40, 110, 140)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(14, 30, 48)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 10, 18)),
		}),
	}, planet)
	make("UIStroke", { Color = TEAL, Thickness = 2, Transparency = 0.35 }, planet)
	local ring = slab(window, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.fromScale(1.6, 0.05),
		Rotation = -9,
		BackgroundTransparency = 1,
	})
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	make("UIStroke", { Color = GOLD_HOT, Thickness = 1.5, Transparency = 0.5 }, ring)
	-- Mullions and the frame.
	for _, x in { 1 / 3, 2 / 3 } do
		slab(window, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.new(0, 6, 1, 0),
			BackgroundColor3 = STEEL,
		})
	end
	make("UIStroke", { Color = Color3.fromRGB(40, 52, 66), Thickness = 6 }, window)
	-- A haze where the window meets the deck.
	local haze = slab(window, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = TEAL,
	})
	fade(haze, 90, 1, 0.75)

	-- Bulkheads either side, each with a breathing light strip.
	local strips = {}
	for _, side in { 0, 1 } do
		local pillar = slab(root, {
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.fromScale(if side == 0 then 0.17 else 0.83, 0),
			Size = UDim2.fromScale(0.035, HORIZON),
			BackgroundColor3 = STEEL,
		})
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(8, 10, 16), Color3.fromRGB(40, 50, 64)) }, pillar)
		local strip = slab(pillar, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.new(0, 2, 0.76, 0),
			BackgroundColor3 = TEAL,
		})
		fade(strip, 90, 0.9, 0.9, 0)
		table.insert(strips, strip)
	end

	-- The floor: a dark glossy deck with the window's light lying on it.
	local floor = slab(root, {
		Position = UDim2.fromScale(0, HORIZON),
		Size = UDim2.fromScale(1, 1 - HORIZON),
	})
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(26, 40, 52), Color3.fromRGB(5, 7, 12)),
	}, floor)
	local reflection = slab(floor, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(0.56, 0.7),
		BackgroundColor3 = TEAL,
	})
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.88),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, reflection)
	for i = 1, 4 do
		slab(floor, {
			Position = UDim2.fromScale(0, (i / 4) ^ 1.8),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = SEAM,
			BackgroundTransparency = 0.9,
		})
	end
	local seam = slab(root, {
		Position = UDim2.fromScale(0, HORIZON),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = TEAL,
		BackgroundTransparency = 0.3,
	})
	fade(seam, 0, 1, 1, 0)

	-- The rim glow behind the active miner: soft stacked discs.
	local beams = {}
	for i, scale in { 0.62, 0.46, 0.3 } do
		local glow = slab(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			BackgroundColor3 = if i == 3 then GOLD_HOT else TEAL,
			BackgroundTransparency = 0.9,
		})
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
		beams[i] = glow
	end
	local ticks = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(0, 0) }, root)

	-- Pedestals under each miner: a flat steel disc seen from just above,
	-- a gold rim, and a pool of light around it.
	local pedestals = {}
	for i, spot in PEDESTALS do
		local tall = spot.W * 0.36 -- discs are wide and flat (scale of height)
		local pool = slab(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot.X, spot.Y),
			Size = UDim2.fromScale(spot.W * 1.6, tall * 1.9),
			BackgroundColor3 = GOLD,
			BackgroundTransparency = if spot.Main then 0.82 else 0.9,
		})
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, pool)
		fade(pool, 0, 1, 1, 0)
		local disc = slab(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot.X, spot.Y),
			Size = UDim2.fromScale(spot.W, tall),
			BackgroundColor3 = Color3.fromRGB(26, 32, 42),
			-- A floor pad seen from above, not a solid button.
			BackgroundTransparency = 0.45,
		})
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(96, 106, 122), Color3.fromRGB(12, 15, 20)),
		}, disc)
		local rim = make("UIStroke", {
			Color = GOLD,
			Thickness = if spot.Main then 1.5 else 1,
			Transparency = if spot.Main then 0.15 else 0.45,
		}, disc)
		-- An energy ring pulsing out from under the main pedestal.
		local pulse = nil
		if spot.Main then
			pulse = slab(root, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(spot.X, spot.Y),
				Size = UDim2.fromScale(spot.W, tall),
				BackgroundTransparency = 1,
			})
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, pulse)
			make("UIStroke", { Color = GOLD_HOT, Thickness = 1.5 }, pulse)
		end
		pedestals[i] = { Disc = disc, Rim = rim, Pulse = pulse, Spot = spot, Tall = tall }
	end

	-- Dust drifting up through the light.
	local motes = {}
	for i = 1, MOTES do
		local mote = slab(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(2, 2),
			BackgroundColor3 = TEAL:Lerp(GOLD_HOT, 0.5),
		})
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, mote)
		motes[i] = mote
	end

	-- Vignette: the bay's corners fall into shadow.
	for _, side in { 0, 1 } do
		local shade = slab(root, {
			AnchorPoint = Vector2.new(side, 0),
			Position = UDim2.fromScale(side, 0),
			Size = UDim2.fromScale(0.18, 1),
			BackgroundColor3 = Color3.fromRGB(4, 6, 10),
		})
		fade(shade, if side == 0 then 0 else 180, 0.15, 1)
	end

	return { Root = root, Beams = beams, Ticks = ticks, Pedestals = pedestals, Motes = motes, Strips = strips }
end

seeded = function(i: number, salt: number): number
	local x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453
	return x - math.floor(x)
end

function StageBackdrop.update(backdrop, time: number)
	local t = time
	local breathe = 0.5 + 0.5 * math.sin(t * 1.3)
	-- The crest turns slowly; the spotlight breathes.
	backdrop.Ticks.Rotation = (t * 6) % 360
	for i, glow in backdrop.Beams do
		glow.BackgroundTransparency = 0.93 - 0.03 * breathe - (i - 1) * 0.01
	end
	for i, strip in backdrop.Strips do
		strip.BackgroundTransparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * 1.7 + i * 1.3))
	end
	-- The main pedestal's ring pulses outward and fades.
	for _, pedestal in backdrop.Pedestals do
		local spot = pedestal.Spot
		if pedestal.Pulse then
			local phase = (t / 2.2) % 1
			pedestal.Pulse.Size = UDim2.fromScale(spot.W * (1 + phase * 0.5), pedestal.Tall * (1 + phase * 0.5))
			local stroke = pedestal.Pulse:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 0.2 + 0.8 * phase
			end
			pedestal.Rim.Transparency = 0.25 - 0.2 * breathe
		end
	end
	-- Dust rising through the beam and drifting.
	for i, mote in backdrop.Motes do
		local period = 6 + seeded(i, 1) * 6
		local phase = (t / period + seeded(i, 2)) % 1
		local x = 0.5 + (seeded(i, 3) - 0.5) * 0.34 + math.sin(t * 0.5 + i) * 0.015
		mote.Position = UDim2.fromScale(x, 0.9 - phase * 0.85)
		mote.BackgroundTransparency = 0.25 + 0.75 * math.abs(phase - 0.5) * 2
	end
end

return StageBackdrop
