--[[
	The Inventory's miner stage: a war-hangar bay behind the three miners.

	  Back wall   heavy bulkhead panels with lit seams, a hazard band low on
	              the wall and a gold slit light along the top
	  Spotlight   a gold beam pouring down on the active miner, with dust
	              drifting up through it
	  Emblem      a slow-turning crest ring behind the active miner
	  Floor       a steel deck in perspective, grid lines running to the
	              horizon, and a lit pedestal under each miner (the middle
	              one, the active miner's, largest and brightest)

	Built once (create), only moved each frame (update).

	  StageBackdrop.create(stage) -> backdrop
	  StageBackdrop.update(backdrop, time)
]]
local StageBackdrop = {}

local GOLD = Color3.fromRGB(255, 196, 82)
local GOLD_HOT = Color3.fromRGB(255, 232, 170)
local STEEL = Color3.fromRGB(34, 42, 54)
local STEEL_LIGHT = Color3.fromRGB(70, 82, 98)
local SEAM = Color3.fromRGB(110, 150, 170)
local HORIZON = 0.58 -- where the back wall meets the floor (fraction of height)
local MOTES = 18

-- Where the miners stand (fractions of the stage): left, middle, right.
local PEDESTALS = {
	{ X = 0.16, Y = 0.6, W = 0.15, Main = false },
	{ X = 0.5, Y = 0.84, W = 0.24, Main = true },
	{ X = 0.84, Y = 0.6, W = 0.15, Main = false },
}

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

	-- Back wall: bulkhead panels, alternately lit, with seams between.
	local wall = slab(root, { Size = UDim2.fromScale(1, HORIZON), BackgroundColor3 = STEEL })
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(14, 18, 26), STEEL) }, wall)
	local panels = 9
	for i = 0, panels - 1 do
		local panel = slab(wall, {
			Position = UDim2.fromScale(i / panels, 0.08),
			Size = UDim2.new(1 / panels, -6, 0.78, 0),
			BackgroundColor3 = if i % 2 == 0 then STEEL_LIGHT else STEEL,
			BackgroundTransparency = 0.55,
		})
		fade(panel, 90, 0.6, 0.1)
		-- A lit seam down the panel's edge and two bolts.
		slab(panel, {
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = SEAM,
			BackgroundTransparency = 0.75,
		})
		for _, y in { 0.08, 0.92 } do
			local bolt = slab(panel, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, y),
				Size = UDim2.fromOffset(4, 4),
				BackgroundColor3 = SEAM,
				BackgroundTransparency = 0.5,
			})
			make("UICorner", { CornerRadius = UDim.new(1, 0) }, bolt)
		end
	end
	-- A gold slit light running along the top of the wall.
	local slit = slab(wall, {
		Position = UDim2.fromScale(0, 0.03),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.35,
	})
	fade(slit, 0, 0.9, 0.9, 0)
	-- A hazard band low on the wall: amber and black chevrons.
	local hazard = slab(wall, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 7),
		BackgroundColor3 = Color3.fromRGB(16, 16, 18),
		ClipsDescendants = true,
	})
	for i = 0, 70 do
		slab(hazard, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, i * 16, 0.5, 0),
			Size = UDim2.fromOffset(7, 26),
			Rotation = 40,
			BackgroundColor3 = Color3.fromRGB(214, 150, 30),
			BackgroundTransparency = 0.45,
		})
	end

	-- The floor: a steel deck, darker toward the camera's feet.
	local floor = slab(root, {
		Position = UDim2.fromScale(0, HORIZON),
		Size = UDim2.fromScale(1, 1 - HORIZON),
		BackgroundColor3 = Color3.fromRGB(20, 26, 34),
	})
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(40, 50, 62), Color3.fromRGB(8, 11, 16)),
	}, floor)
	-- Grid lines running to the horizon (a vanishing point at the centre).
	for i = -9, 9 do
		local spread = i / 9
		local line = slab(floor, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5 + spread * 0.08, 0),
			Size = UDim2.new(0, 1, 2.2, 0),
			Rotation = -spread * 62,
			BackgroundColor3 = SEAM,
			BackgroundTransparency = 0.82,
		})
		fade(line, 90, 0.2, 1)
	end
	-- Cross lines, closer together toward the horizon.
	for i = 1, 6 do
		local y = (i / 6) ^ 1.8
		slab(floor, {
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = SEAM,
			BackgroundTransparency = 0.86 - 0.04 * i,
		})
	end
	-- A bright line where wall meets floor.
	local seam = slab(root, {
		Position = UDim2.fromScale(0, HORIZON),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = SEAM,
		BackgroundTransparency = 0.4,
	})
	fade(seam, 0, 1, 1, 0.1)

	-- The spotlight on the active miner: three stacked beams, widest faintest.
	local beams = {}
	for i, width in { 0.36, 0.24, 0.12 } do
		local beam = slab(root, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(width, 0.92),
			BackgroundColor3 = GOLD,
			BackgroundTransparency = 0.86 + i * 0.01,
		})
		make("UIGradient", {
			Rotation = 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, beam)
		beams[i] = beam
	end

	-- The crest behind the active miner: two rings and tick marks.
	local crest = make("Frame", {
		Name = "Crest",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.42, 0.42),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		ZIndex = 0,
	}, root)
	crest.Size = UDim2.fromScale(0.95, 0.95)
	for i, scale in { 1, 0.82 } do
		local ring = make("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			ZIndex = 0,
		}, crest)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		make("UIStroke", {
			Color = GOLD,
			Thickness = if i == 1 then 2 else 1,
			Transparency = if i == 1 then 0.72 else 0.8,
		}, ring)
	end
	local ticks = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}, crest)
	for i = 0, 23 do
		local angle = math.rad(i * 15)
		local long = i % 6 == 0
		slab(ticks, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.sin(angle) * 0.455, 0.5 - math.cos(angle) * 0.455),
			Size = UDim2.fromOffset(if long then 3 else 2, if long then 12 else 6),
			Rotation = i * 15,
			BackgroundColor3 = GOLD,
			BackgroundTransparency = if long then 0.45 else 0.7,
		})
	end

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
		})
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(96, 106, 122), Color3.fromRGB(12, 15, 20)),
		}, disc)
		local rim = make("UIStroke", {
			Color = GOLD,
			Thickness = if spot.Main then 2 else 1.5,
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
			BackgroundColor3 = GOLD_HOT,
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

	return { Root = root, Beams = beams, Ticks = ticks, Pedestals = pedestals, Motes = motes }
end

local function seeded(i: number, salt: number): number
	local x = math.sin(i * 127.1 + salt * 311.7) * 43758.5453
	return x - math.floor(x)
end

function StageBackdrop.update(backdrop, time: number)
	local t = time
	local breathe = 0.5 + 0.5 * math.sin(t * 1.3)
	-- The crest turns slowly; the spotlight breathes.
	backdrop.Ticks.Rotation = (t * 6) % 360
	for i, beam in backdrop.Beams do
		beam.BackgroundTransparency = 0.88 + i * 0.01 - 0.04 * breathe
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
