--[[
	How each realm's Rift is built (World.RiftWorld lays the caves out and
	asks these for the parts): its walls, its floors, the barrier across a
	passage, the lamps in a cave's corners, the arch over a passage, the
	throne and the sky. A realm (Shared.RiftRealms) names one of each in
	its Style, so no two bosses' trips are built the same way: a fire
	boss's rock and flame, a frost boss's ice, a shock boss's crystal and
	current, a poison boss's roots and bog, and within an element each
	boss its own.

	  RiftStyles.install(kit) -> { Walls, Corners, Floors, Gates, Lamps,
	      Arches, Thrones, Skies }, each { [kind] = builder }:
	    Walls[kind](parent, a, b, inward, rng, ledges)   a wall along the
	        floor's edge from a to b (inward: into the cave); its solid
	        slab is "RockWall", in the realm's Rock
	    Corners[kind](parent, at, rng)   the column in a cave's corner (by
	        the wall's kind)
	    Floors[kind](parent, center, size, rng)   what's on a cave's floor
	    Gates[kind](model, frame, width, room)   the barrier across a
	        passage: a solid "Wall", a "Glow", its "Tongue"s (the strands
	        of the curtain, 8 or more) and 3 fires at least
	    Lamps[kind](parent, at)   a lamp, with fire and light
	    Arches[kind](model, mid, dir, side, width, rng)   over a passage:
	        its "Arch" and "Fang"s hang 12 studs clear of the floor
	    Thrones[kind](model, frame, seat)   the throne (frame: at the seat,
	        facing the way in)
	    Skies[kind](model, center, span, rng)   the sky: 8 "Scar"s or more
	        (what burns across it) and 8 "Cloud"s
	The kit (RiftWorld's): part, glow, light, fire, face, flat, yawOf,
	cylinder, disc, UP, Wall, Thick, Passage, BONE, and P, the realm.
]]
local RiftStyles = {}

-- (A size from an index, where there's no rng to hand.)
local function rng_or(i: number, lo: number, hi: number): number
	return lo + ((i * 7) % 5) / 4 * (hi - lo)
end

function RiftStyles.install(K)
	local part, glow, light, fire, face, flat = K.part, K.glow, K.light, K.fire, K.face, K.flat
	local cylinder, disc, UP = K.cylinder, K.disc, K.UP
	local function P()
		return K.P
	end
	local function rgb(r, g, b)
		return Color3.fromRGB(r, g, b)
	end
	local Walls, Corners, Floors, Gates, Lamps, Arches, Thrones, Skies = {}, {}, {}, {}, {}, {}, {}, {}

	-- Walls ---------------------------------------------------------------------------------------------------

	-- The solid slab every wall has: Wall tall, nobody climbs or sees out.
	local function slab(parent, a: Vector3, b: Vector3, inward: Vector3, material)
		local along = (b - a).Unit
		local tall, thick = K.Wall, K.Thick
		local mid = (a + b) / 2 - inward * thick / 2
		local frame = face(mid, along)
		local wall = part(
			parent,
			frame * CFrame.new(0, tall / 2, 0),
			Vector3.new(thick, tall, (b - a).Magnitude + thick),
			P().Rock,
			material or Enum.Material.Slate,
			nil,
			true
		)
		wall.Name = "RockWall"
		return wall, frame, along
	end

	-- Things leaning on a wall's foot: `count` of `make(at, s)` along it.
	local function along(a: Vector3, b: Vector3, inward: Vector3, rng, every: number, make)
		for _ = 1, math.max(1, math.floor((b - a).Magnitude / every)) do
			make(a:Lerp(b, rng:NextNumber(0.08, 0.92)), rng:NextNumber(5, 11))
		end
	end

	-- Drago: rock. Boulders heaped at its foot, jagged obsidian crowns,
	-- the odd ledge, a seam of lava down it.
	Walls.Rock = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward)
		local tall, thick = K.Wall, K.Thick
		along(a, b, inward, rng, 15, function(at, s)
			part(
				parent,
				CFrame.new(at + inward * rng:NextNumber(-1.5, 0.5) + UP * s * 0.35)
					* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5)),
				Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.7, 1.1)),
				if rng:NextNumber() < 0.5 then P().Basalt else P().Rock,
				Enum.Material.Slate,
				nil,
				true
			)
		end)
		for _ = 1, math.max(1, math.floor(length / 19)) do
			local at = a:Lerp(b, rng:NextNumber(0.05, 0.95)) - inward * thick * 0.4
			local high = rng:NextNumber(6, 16)
			part(
				parent,
				face(at + UP * (tall + high / 2 - 1), -inward)
					* CFrame.Angles(rng:NextNumber(-0.25, -0.05), 0, rng:NextNumber(-0.15, 0.15)),
				Vector3.new(rng:NextNumber(5, 9), high, rng:NextNumber(5, 8)),
				P().Obsidian,
				Enum.Material.Slate,
				"Wedge"
			)
		end
		if ledges and length > 30 and rng:NextNumber() < 0.7 then
			local span = length * rng:NextNumber(0.35, 0.6)
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (tall - 2.5)
			part(parent, face(at + inward * 5, dir), Vector3.new(12, 4, span), P().Basalt, Enum.Material.Slate).Name = "Ledge"
		end
		if rng:NextNumber() < 0.5 then
			local top = a:Lerp(b, rng:NextNumber(0.2, 0.8)) + inward * 0.05
			local drop = rng:NextNumber(5, 9)
			local seam = glow(part(parent, face(top + UP * drop / 2, dir) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, 0), Vector3.new(0.4, drop, 1.2), P().Glow))
			seam.Name = "Seam"
			seam.Transparency = 0.3
		end
	end
	Corners.Rock = function(parent, at: Vector3, rng)
		part(
			parent,
			CFrame.new(at + UP * (K.Wall / 2 + 3)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			Vector3.new(K.Thick + 3, K.Wall + 6, K.Thick + 3),
			P().Obsidian,
			Enum.Material.Slate,
			nil,
			true
		)
	end

	-- Sahur: charred. Burnt logs stacked and leaning against black rock,
	-- ember cracks glowing in them, stumps along the top still smouldering.
	Walls.Charred = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward)
		local bark = rgb(30, 22, 20)
		for _ = 1, math.max(1, math.floor(length / 17)) do
			local at = a:Lerp(b, rng:NextNumber(0.08, 0.92))
			local long = rng:NextNumber(10, 18)
			local log = part(
				parent,
				face(at + inward * 2.2 + UP * long * 0.45, dir) * CFrame.Angles(0, 0, 0.25 + rng:NextNumber(0, 0.2)),
				Vector3.new(2.6, long, 2.6),
				bark,
				Enum.Material.Wood,
				nil,
				true
			)
			log.Name = "CharredLog"
			local ember = glow(part(parent, log.CFrame * CFrame.new(-1.3, rng:NextNumber(-3, 3), 0), Vector3.new(0.2, rng:NextNumber(3, 6), 0.5), P().Glow))
			ember.Transparency = 0.3
		end
		for _ = 1, math.max(1, math.floor(length / 24)) do
			local at = a:Lerp(b, rng:NextNumber(0.05, 0.95)) - inward * K.Thick * 0.5
			local stump = part(parent, CFrame.new(at + UP * (K.Wall + 2.5)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(4.5, 5, 4.5), bark, Enum.Material.Wood)
			stump.Name = "Stump"
			local coal = glow(disc(parent, at + UP * (K.Wall + 5.1), 1.8, 0.3, P().Accent))
			fire(coal, 4, 8)
		end
		if ledges and length > 30 and rng:NextNumber() < 0.6 then
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (K.Wall - 3)
			part(parent, face(at + inward * 4, dir), Vector3.new(10, 3, length * 0.4), bark, Enum.Material.Wood).Name = "Ledge"
		end
	end
	Corners.Charred = function(parent, at: Vector3, rng)
		local trunk = cylinder(parent, at + UP * (K.Wall / 2 + 3), K.Thick / 2 + 2, K.Wall + 6, rgb(30, 22, 20), Enum.Material.Wood, true)
		trunk.Name = "Column"
		for i = 1, 3 do
			local ember = glow(part(parent, CFrame.new(at + UP * (6 + i * 8)) * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, 0, -(K.Thick / 2 + 2)), Vector3.new(0.6, 4, 0.3), P().Glow))
			ember.Transparency = 0.3
		end
	end

	-- Paperotti: ice. Translucent slabs of ice tiled over blue rock, snow
	-- banked along the top, icicles hanging off it.
	Walls.Ice = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward, Enum.Material.Ice)
		local ice = rgb(170, 214, 245)
		for _ = 1, math.max(1, math.floor(length / 14)) do
			local at = a:Lerp(b, rng:NextNumber(0.06, 0.94))
			local w, h = rng:NextNumber(7, 12), rng:NextNumber(8, 20)
			local tile = part(parent, face(at + inward * 0.9 + UP * h / 2, dir) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, 0), Vector3.new(w, h, 1.6), ice, Enum.Material.Glass, nil, true)
			tile.Transparency = 0.3
			tile.Name = "IceTile"
		end
		for _ = 1, math.max(1, math.floor(length / 20)) do
			local at = a:Lerp(b, rng:NextNumber(0.05, 0.95)) - inward * K.Thick * 0.3
			part(parent, CFrame.new(at + UP * (K.Wall + 1.5)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(rng:NextNumber(6, 10), 3, rng:NextNumber(5, 8)), rgb(240, 246, 255), Enum.Material.Snow).Name = "Snow"
		end
		for _ = 1, math.max(1, math.floor(length / 17)) do
			local at = a:Lerp(b, rng:NextNumber(0.1, 0.9)) + inward * 1.2
			local long = rng:NextNumber(4, 10)
			local icicle = part(parent, CFrame.new(at + UP * (K.Wall - 1 - long / 2)) * CFrame.Angles(math.pi, rng:NextNumber(0, 6), 0), Vector3.new(1.2, long, 1.2), ice, Enum.Material.Glass, "Wedge")
			icicle.Transparency = 0.25
			icicle.Name = "Icicle"
		end
		if ledges and length > 30 and rng:NextNumber() < 0.6 then
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (K.Wall - 2.5)
			local shelf = part(parent, face(at + inward * 4.5, dir), Vector3.new(10, 3, length * 0.4), ice, Enum.Material.Glass)
			shelf.Transparency = 0.3
			shelf.Name = "Ledge"
		end
	end
	Corners.Ice = function(parent, at: Vector3, rng)
		local pillar = part(parent, CFrame.new(at + UP * (K.Wall / 2 + 3)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Vector3.new(K.Thick + 3, K.Wall + 6, K.Thick + 3), rgb(170, 214, 245), Enum.Material.Glass, nil, true)
		pillar.Transparency = 0.25
		pillar.Name = "Column"
		part(parent, CFrame.new(at + UP * (K.Wall + 7.5)), Vector3.new(K.Thick + 5, 3, K.Thick + 5), rgb(240, 246, 255), Enum.Material.Snow)
	end

	-- Tralalero: reef. Dark sea rock with frozen coral fans up it, a wave
	-- frozen as it broke over the top, its foam still glowing.
	Walls.Reef = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward)
		local coral = { rgb(90, 160, 170), rgb(170, 110, 140), rgb(230, 230, 220) }
		for _ = 1, math.max(1, math.floor(length / 13)) do
			local at = a:Lerp(b, rng:NextNumber(0.06, 0.94)) + inward * 0.8 + UP * rng:NextNumber(2, K.Wall - 8)
			local w = rng:NextNumber(3, 6)
			part(parent, face(at, dir) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.4, 0.4)), Vector3.new(w, w * 1.3, 0.8), coral[rng:NextInteger(1, 3)], Enum.Material.Slate, "Wedge").Name = "Coral"
		end
		-- The wave over the top.
		for i = 1, math.max(1, math.floor(length / 26)) do
			local at = a:Lerp(b, (i - 0.5) / math.max(1, math.floor(length / 26))) + inward * 2.5
			local crest = part(parent, face(at + UP * (K.Wall + 4), inward) * CFrame.Angles(-0.55, 0, 0), Vector3.new(16, 9, 8), rgb(140, 220, 235), Enum.Material.Glass, "Wedge")
			crest.Transparency = 0.3
			crest.Name = "Crest"
			local foam = glow(part(parent, face(at + inward * 3 + UP * (K.Wall + 8.2), dir), Vector3.new(0.6, 1, 15), P().Glow))
			foam.Transparency = 0.4
		end
		if ledges and length > 30 and rng:NextNumber() < 0.6 then
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (K.Wall - 2.5)
			part(parent, face(at + inward * 4, dir), Vector3.new(10, 3, length * 0.4), P().Basalt, Enum.Material.Slate).Name = "Ledge"
		end
	end
	Corners.Reef = function(parent, at: Vector3, rng)
		part(parent, CFrame.new(at + UP * (K.Wall / 2 + 3)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Vector3.new(K.Thick + 3, K.Wall + 6, K.Thick + 3), P().Obsidian, Enum.Material.Slate, nil, true).Name = "Column"
		part(parent, CFrame.new(at + UP * (K.Wall + 9)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(3, 8, 6), rgb(22, 36, 46), Enum.Material.Slate, "Wedge").Name = "Fin"
	end

	-- Frigo: freezer. Steel panels riveted in a grid, frost grown in the
	-- seams, racks along them with frozen things, a cold tube now and then.
	Walls.Freezer = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward, Enum.Material.Metal)
		local steel = rgb(150, 164, 184)
		local n = math.max(1, math.floor(length / 19))
		for i = 1, n do
			local at = a:Lerp(b, (i - 0.5) / n) + inward * 0.4
			part(parent, face(at + UP * K.Wall / 2, dir), Vector3.new(0.8, K.Wall - 2, 1.2), rgb(60, 70, 90), Enum.Material.Metal).Name = "Seam"
			local frost = glow(part(parent, face(at + UP * rng:NextNumber(4, K.Wall - 6), dir), Vector3.new(rng:NextNumber(4, 9), 1.1, 0.5), rgb(230, 244, 255)))
			frost.Transparency = 0.45
			frost.Name = "Frost"
		end
		for i = 1, 1 do
			local y = 8 + i * 9
			part(parent, face((a + b) / 2 + inward * 1.6 + UP * y, dir), Vector3.new(3.2, 0.4, length * 0.8), steel, Enum.Material.Metal).Name = "Rack"
			for _ = 1, math.max(1, math.floor(length / 26)) do
				local at = a:Lerp(b, rng:NextNumber(0.15, 0.85)) + inward * 1.6 + UP * (y + 1.6)
				local box = part(parent, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(2.4, 2.8, 2.4), rgb(190, 225, 250), Enum.Material.Glass)
				box.Transparency = 0.35
				part(parent, box.CFrame, Vector3.new(1.2, 1.4, 1.2), rgb(40, 36, 50), Enum.Material.SmoothPlastic)
			end
		end
		if ledges and length > 30 then
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (K.Wall - 2.5)
			part(parent, face(at + inward * 4, dir), Vector3.new(10, 3, length * 0.4), steel, Enum.Material.Metal).Name = "Ledge"
		end
	end
	Corners.Freezer = function(parent, at: Vector3, rng)
		part(parent, CFrame.new(at + UP * (K.Wall / 2 + 3)), Vector3.new(K.Thick + 3, K.Wall + 6, K.Thick + 3), rgb(110, 124, 146), Enum.Material.Metal, nil, true).Name = "Column"
		local tube = glow(part(parent, CFrame.new(at + UP * (K.Wall / 2 + 3)) * CFrame.new(0, 0, -(K.Thick / 2 + 1.8)), Vector3.new(0.5, K.Wall - 4, 0.5), rgb(220, 240, 255)))
		tube.Transparency = 0.2
		light(tube, P().Glow, 30, 1.2)
	end

	-- Chimpanzini: jungle. Great mossy trunks stood side by side, their
	-- canopy closing over the top, vines crackling down them.
	Walls.Jungle = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward, Enum.Material.Grass)
		local bark = rgb(52, 60, 34)
		local n = math.max(1, math.floor(length / 10))
		for i = 1, n do
			local at = a:Lerp(b, (i - 0.5) / n) + inward * 1.8
			local r = rng:NextNumber(2.8, 4.2)
			local tall = K.Wall + rng:NextNumber(-4, 6)
			cylinder(parent, at + UP * tall / 2, r, tall, bark, Enum.Material.Wood, true).Name = "Trunk"
			if i % 2 == 0 then
				local ring = glow(disc(parent, at + UP * rng:NextNumber(6, tall - 6), r + 0.3, 0.3, P().Glow))
				ring.Transparency = 0.35
			end
		end
		for _ = 1, math.max(1, math.floor(length / 22)) do
			local at = a:Lerp(b, rng:NextNumber(0.05, 0.95)) - inward * 1
			part(parent, CFrame.new(at + UP * (K.Wall + 4)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.1), Vector3.new(rng:NextNumber(10, 16), 4, rng:NextNumber(8, 14)), rgb(40, 70, 36), Enum.Material.Grass).Name = "Canopy"
		end
		for _ = 1, math.max(1, math.floor(length / 26)) do
			local at = a:Lerp(b, rng:NextNumber(0.1, 0.9)) + inward * 4
			local long = rng:NextNumber(8, 16)
			cylinder(parent, at + UP * (K.Wall + 2 - long / 2), 0.35, long, rgb(54, 72, 30), Enum.Material.Grass, false).Name = "Vine"
			glow(part(parent, CFrame.new(at + UP * (K.Wall + 2 - rng:NextNumber(2, long))), Vector3.new(0.6, 0.6, 0.6), P().Glow, nil, "Ball"))
		end
		if ledges and length > 30 and rng:NextNumber() < 0.6 then
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (K.Wall - 2.5)
			part(parent, face(at + inward * 5, dir), Vector3.new(12, 3, length * 0.4), rgb(40, 70, 36), Enum.Material.Grass).Name = "Ledge"
		end
	end
	Corners.Jungle = function(parent, at: Vector3, rng)
		cylinder(parent, at + UP * (K.Wall / 2 + 3), K.Thick / 2 + 2.5, K.Wall + 6, rgb(52, 60, 34), Enum.Material.Wood, true).Name = "Column"
		part(parent, CFrame.new(at + UP * (K.Wall + 7)), Vector3.new(16, 4, 16), rgb(40, 70, 36), Enum.Material.Grass).Name = "Canopy"
	end

	-- Gattini: crystal. Violet prisms grown out of the rock at every angle,
	-- static arcing between their tips, spikes of it along the top.
	Walls.Crystal = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward)
		local crystal = rgb(110, 96, 150)
		local tips = {}
		for _ = 1, math.max(1, math.floor(length / 12)) do
			local at = a:Lerp(b, rng:NextNumber(0.06, 0.94)) + inward * 1.2 + UP * rng:NextNumber(1, K.Wall - 10)
			local tall = rng:NextNumber(5, 11)
			local frame = face(at, dir) * CFrame.Angles(rng:NextNumber(-0.9, -0.3), 0, rng:NextNumber(-0.4, 0.4))
			local prism = part(parent, frame * CFrame.new(0, tall / 2, 0), Vector3.new(rng:NextNumber(1.6, 2.6), tall, rng:NextNumber(1.6, 2.6)), crystal, Enum.Material.Glass, "Wedge")
			prism.Transparency = 0.15
			prism.Name = "Prism"
			table.insert(tips, (frame * CFrame.new(0, tall, 0)).Position)
		end
		for i = 2, #tips, 3 do
			local p, q = tips[i - 1], tips[i]
			local arc = glow(part(parent, face((p + q) / 2, flat(q - p)) * CFrame.Angles(math.atan2(q.Y - p.Y, math.max(0.1, flat(q - p).Magnitude)), 0, 0), Vector3.new(0.2, 0.2, (q - p).Magnitude), P().Glow))
			arc.Transparency = 0.3
			arc.Name = "Arc"
		end
		for _ = 1, math.max(1, math.floor(length / 20)) do
			local at = a:Lerp(b, rng:NextNumber(0.05, 0.95)) - inward * K.Thick * 0.4
			local high = rng:NextNumber(6, 14)
			local spike = part(parent, face(at + UP * (K.Wall + high / 2 - 1), -inward) * CFrame.Angles(rng:NextNumber(-0.3, 0.1), 0, 0), Vector3.new(2.5, high, 2.5), crystal, Enum.Material.Glass, "Wedge")
			spike.Transparency = 0.15
			glow(part(parent, spike.CFrame * CFrame.new(0, high / 2 + 0.6, 0), Vector3.new(0.8, 1.4, 0.8), P().Glow, nil, "Wedge"))
		end
		if ledges and length > 30 and rng:NextNumber() < 0.6 then
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (K.Wall - 2.5)
			part(parent, face(at + inward * 4, dir), Vector3.new(10, 3, length * 0.4), P().Basalt, Enum.Material.Slate).Name = "Ledge"
		end
	end
	Corners.Crystal = function(parent, at: Vector3, rng)
		local pillar = part(parent, CFrame.new(at + UP * (K.Wall / 2 + 3)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Vector3.new(K.Thick + 3, K.Wall + 6, K.Thick + 3), rgb(110, 96, 150), Enum.Material.Glass, nil, true)
		pillar.Transparency = 0.15
		pillar.Name = "Column"
		local tip = glow(part(parent, CFrame.new(at + UP * (K.Wall + 9)), Vector3.new(3, 6, 3), P().Glow, nil, "Wedge"))
		light(tip, P().Glow, 30, 1)
	end

	-- Cappuccino: shoji. Dark timber frames with paper panels between,
	-- katanas stuck through them, a tiled roof along the top.
	Walls.Shoji = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward, Enum.Material.Wood)
		local timber, paper = rgb(40, 28, 22), rgb(226, 212, 180)
		local n = math.max(1, math.floor(length / 13))
		for i = 0, n do
			local at = a:Lerp(b, i / n) + inward * 0.9
			part(parent, face(at + UP * K.Wall / 2, dir), Vector3.new(1.2, K.Wall, 1.2), timber, Enum.Material.Wood).Name = "Post"
			if i < n then
				local mid = a:Lerp(b, (i + 0.5) / n) + inward * 0.5
				local panel = part(parent, face(mid + UP * (K.Wall / 2 - 2), dir), Vector3.new(length / n - 1.4, K.Wall - 8, 0.3), paper, Enum.Material.SmoothPlastic)
				panel.Name = "Paper"
				if i % 3 == 1 then
					local blade = part(parent, face(mid + inward * 1.2 + UP * rng:NextNumber(8, K.Wall - 10), dir) * CFrame.Angles(0, 0, rng:NextNumber(0.6, 1.1)), Vector3.new(0.3, 9, 1.6), rgb(200, 205, 215), Enum.Material.Metal)
					blade.Name = "Blade"
					glow(part(parent, blade.CFrame * CFrame.new(0, 0, -0.75), Vector3.new(0.12, 8.6, 0.25), P().Glow)).Transparency = 0.2
				end
			end
		end
		part(parent, face((a + b) / 2 + inward * 0.9 + UP * (K.Wall / 2 - 2), dir), Vector3.new(1.4, 0.8, length * 0.98), timber, Enum.Material.Wood).Name = "Rail"
		part(parent, face((a + b) / 2 - inward * K.Thick * 0.3 + UP * (K.Wall + 2), inward) * CFrame.Angles(-0.5, 0, 0), Vector3.new(length + 2, 1.2, 10), rgb(28, 24, 30), Enum.Material.Slate).Name = "Roof"
		if ledges and length > 30 then
			part(parent, face((a + b) / 2 + inward * 4 + UP * (K.Wall - 2.5), dir), Vector3.new(10, 1.6, length * 0.5), timber, Enum.Material.Wood).Name = "Ledge"
		end
	end
	Corners.Shoji = function(parent, at: Vector3, rng)
		part(parent, CFrame.new(at + UP * (K.Wall / 2 + 3)), Vector3.new(K.Thick + 3, K.Wall + 6, K.Thick + 3), rgb(40, 28, 22), Enum.Material.Wood, nil, true).Name = "Column"
		part(parent, CFrame.new(at + UP * (K.Wall + 7)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Vector3.new(K.Thick + 8, 2, K.Thick + 8), rgb(28, 24, 30), Enum.Material.Slate).Name = "Roof"
	end

	-- Ranocchio: mangrove. A wall of mud held by tangled roots, moss and
	-- slime glowing in the gaps, vines hanging in.
	Walls.Mangrove = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward, Enum.Material.Mud)
		local root = rgb(60, 48, 34)
		for _ = 1, math.max(1, math.floor(length / 10)) do
			local at = a:Lerp(b, rng:NextNumber(0.05, 0.95)) + inward * 1.4 + UP * rng:NextNumber(2, K.Wall - 6)
			local long = rng:NextNumber(8, 18)
			cylinder(parent, at, rng:NextNumber(0.6, 1.3), long, root, Enum.Material.Wood, false, CFrame.Angles(0, 0, rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, 0)).Name = "Root"
		end
		for _ = 1, math.max(1, math.floor(length / 20)) do
			local at = a:Lerp(b, rng:NextNumber(0.1, 0.9)) + inward * 0.6 + UP * rng:NextNumber(2, K.Wall - 4)
			local slime = glow(part(parent, face(at, dir), Vector3.new(rng:NextNumber(2, 5), rng:NextNumber(1, 3), 0.3), P().Glow))
			slime.Transparency = 0.5
			slime.Name = "Slime"
		end
		for _ = 1, math.max(1, math.floor(length / 22)) do
			local at = a:Lerp(b, rng:NextNumber(0.05, 0.95)) - inward * K.Thick * 0.3
			part(parent, CFrame.new(at + UP * (K.Wall + 3)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Vector3.new(rng:NextNumber(5, 9), 6, rng:NextNumber(5, 9)), root, Enum.Material.Wood).Name = "Knot"
		end
		if ledges and length > 30 and rng:NextNumber() < 0.6 then
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (K.Wall - 2.5)
			part(parent, face(at + inward * 4, dir), Vector3.new(10, 3, length * 0.4), rgb(40, 60, 34), Enum.Material.Grass).Name = "Ledge"
		end
	end
	Corners.Mangrove = function(parent, at: Vector3, rng)
		part(parent, CFrame.new(at + UP * (K.Wall / 2 + 3)), Vector3.new(K.Thick + 3, K.Wall + 6, K.Thick + 3), rgb(50, 40, 30), Enum.Material.Mud, nil, true).Name = "Column"
		for i = 1, 3 do
			cylinder(parent, at + UP * (K.Wall / 2 + 3), 0.9, K.Wall + 4, rgb(60, 48, 34), Enum.Material.Wood, false, CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, 0, -(K.Thick / 2 + 2)) * CFrame.Angles(0, 0, 0.12))
		end
	end

	-- Patapim: deadwood. A palisade of dead trunks, fungus shelved up them,
	-- roots hanging in over the floor from the boughs on top.
	Walls.Deadwood = function(parent, a: Vector3, b: Vector3, inward: Vector3, rng, ledges: boolean)
		local length = (b - a).Magnitude
		local _, _, dir = slab(parent, a, b, inward, Enum.Material.Wood)
		local bark = rgb(54, 44, 32)
		local n = math.max(1, math.floor(length / 9.5))
		for i = 1, n do
			local at = a:Lerp(b, (i - 0.5) / n) + inward * 1.6
			local tall = K.Wall + rng:NextNumber(-3, 8)
			cylinder(parent, at + UP * tall / 2, rng:NextNumber(2.4, 3.6), tall, bark, Enum.Material.Wood, true).Name = "Trunk"
			if i % 3 == 0 then
				local shelf = disc(parent, at + inward * 2 + UP * rng:NextNumber(4, tall - 8), rng:NextNumber(1.8, 2.8), 0.7, rgb(150, 120, 70), Enum.Material.SmoothPlastic)
				shelf.CFrame = shelf.CFrame * CFrame.Angles(0, 0, 0)
				shelf.Name = "Fungus"
				glow(disc(parent, shelf.CFrame.Position - UP * 0.45, 1.5, 0.12, P().Glow)).Transparency = 0.4
			end
		end
		for _ = 1, math.max(1, math.floor(length / 20)) do
			local at = a:Lerp(b, rng:NextNumber(0.1, 0.9)) + inward * 3
			local long = rng:NextNumber(6, 14)
			cylinder(parent, at + UP * (K.Wall + 1 - long / 2), 0.3, long, bark, Enum.Material.Wood, false, CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, 0)).Name = "Root"
		end
		if ledges and length > 30 and rng:NextNumber() < 0.6 then
			local at = a:Lerp(b, rng:NextNumber(0.3, 0.7)) + UP * (K.Wall - 2.5)
			part(parent, face(at + inward * 4, dir), Vector3.new(10, 3, length * 0.4), bark, Enum.Material.Wood).Name = "Ledge"
		end
	end
	Corners.Deadwood = function(parent, at: Vector3, rng)
		cylinder(parent, at + UP * (K.Wall / 2 + 3), K.Thick / 2 + 2.5, K.Wall + 6, rgb(54, 44, 32), Enum.Material.Wood, true).Name = "Column"
		local hollow = glow(part(parent, CFrame.new(at + UP * 8) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) * CFrame.new(0, 0, -(K.Thick / 2 + 2.4)), Vector3.new(3, 5, 0.3), P().Glow))
		hollow.Transparency = 0.5
	end

	-- Floors --------------------------------------------------------------------------------------------------
	-- (The solid floor is RiftWorld's; these dress it.)

	local function scatter(parent, center: Vector3, size: number, rng, count: number, make)
		local half = size / 2
		for _ = 1, count do
			make(center + Vector3.new(rng:NextNumber(-half + 4, half - 4), 0, rng:NextNumber(-half + 4, half - 4)))
		end
	end

	Floors.Basalt = function(parent, center: Vector3, size: number, rng)
		scatter(parent, center, size, rng, math.floor(size / 9), function(at)
			local crack = glow(part(parent, CFrame.new(at + UP * 0.03) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Vector3.new(rng:NextNumber(0.3, 0.7), 0.06, rng:NextNumber(5, 14)), P().Glow))
			crack.Name = "Crack"
			crack.Transparency = 0.2
		end)
	end
	Floors.Scorched = function(parent, center: Vector3, size: number, rng)
		scatter(parent, center, size, rng, math.floor(size / 12), function(at)
			disc(parent, at + UP * 0.03, rng:NextNumber(3, 6), 0.06, rgb(18, 14, 14), Enum.Material.Slate).Name = "Cinders"
			local ember = glow(part(parent, CFrame.new(at + UP * 0.05) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(0.4, 0.08, rng:NextNumber(3, 7)), P().Glow))
			ember.Name = "Crack"
			ember.Transparency = 0.3
		end)
	end
	Floors.Lake = function(parent, center: Vector3, size: number, rng)
		scatter(parent, center, size, rng, math.floor(size / 11), function(at)
			local deep = disc(parent, at + UP * 0.03, rng:NextNumber(4, 8), 0.06, rgb(20, 34, 70), Enum.Material.Glass)
			deep.Transparency = 0.3
			deep.Name = "Deep"
		end)
		scatter(parent, center, size, rng, math.floor(size / 8), function(at)
			local crack = glow(part(parent, CFrame.new(at + UP * 0.05) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(0.25, 0.08, rng:NextNumber(6, 16)), rgb(236, 246, 255)))
			crack.Name = "Crack"
			crack.Transparency = 0.5
		end)
	end
	Floors.Tideflat = function(parent, center: Vector3, size: number, rng)
		local yaw = rng:NextNumber(0, 3)
		for i = 1, math.floor(size / 10) do
			local line = glow(part(parent, CFrame.new(center + UP * 0.04) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, (i - size / 20) * 9), Vector3.new(size * 0.8, 0.08, 0.35), P().Glow))
			line.Name = "TideLine"
			line.Transparency = 0.55
		end
		scatter(parent, center, size, rng, math.floor(size / 14), function(at)
			local ripple = disc(parent, at + UP * 0.03, rng:NextNumber(3, 5), 0.06, rgb(120, 200, 215), Enum.Material.Glass)
			ripple.Transparency = 0.5
			ripple.Name = "Ripple"
		end)
	end
	Floors.Grate = function(parent, center: Vector3, size: number, rng)
		local n = math.floor(size / 12)
		for i = 0, n do
			local off = (i / n - 0.5) * (size - 2)
			part(parent, CFrame.new(center + UP * 0.04 + Vector3.new(off, 0, 0)), Vector3.new(0.5, 0.08, size - 2), rgb(60, 70, 90), Enum.Material.Metal).Name = "Seam"
			part(parent, CFrame.new(center + UP * 0.04 + Vector3.new(0, 0, off)), Vector3.new(size - 2, 0.08, 0.5), rgb(60, 70, 90), Enum.Material.Metal).Name = "Seam"
		end
		scatter(parent, center, size, rng, math.floor(size / 14), function(at)
			local frost = disc(parent, at + UP * 0.06, rng:NextNumber(2, 4.5), 0.08, rgb(236, 246, 255), Enum.Material.Snow)
			frost.Name = "Frost"
		end)
	end
	Floors.Soil = function(parent, center: Vector3, size: number, rng)
		scatter(parent, center, size, rng, math.floor(size / 9), function(at)
			disc(parent, at + UP * 0.03, rng:NextNumber(2.5, 5), 0.08, rgb(48, 86, 40), Enum.Material.Grass).Name = "Moss"
		end)
		scatter(parent, center, size, rng, math.floor(size / 16), function(at)
			local spark = glow(part(parent, CFrame.new(at + UP * 0.05) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(0.3, 0.08, rng:NextNumber(3, 6)), P().Glow))
			spark.Name = "Crack"
			spark.Transparency = 0.3
		end)
	end
	Floors.Shard = function(parent, center: Vector3, size: number, rng)
		scatter(parent, center, size, rng, math.floor(size / 9), function(at)
			local fissure = glow(part(parent, CFrame.new(at + UP * 0.04) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(0.3, 0.08, rng:NextNumber(4, 12)), P().Glow))
			fissure.Name = "Crack"
			fissure.Transparency = 0.25
			local bit = part(parent, CFrame.new(at + Vector3.new(rng:NextNumber(-3, 3), 0.9, rng:NextNumber(-3, 3))) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), 0), Vector3.new(0.9, 1.8, 0.9), rgb(110, 96, 150), Enum.Material.Glass, "Wedge")
			bit.Transparency = 0.15
		end)
	end
	Floors.Boards = function(parent, center: Vector3, size: number, rng)
		local n = math.floor(size / 6)
		for i = 0, n do
			local off = (i / n - 0.5) * (size - 2)
			part(parent, CFrame.new(center + UP * 0.03 + Vector3.new(off, 0, 0)), Vector3.new(0.25, 0.06, size - 2), rgb(26, 18, 14), Enum.Material.Wood).Name = "Seam"
		end
		scatter(parent, center, size, rng, math.floor(size / 16), function(at)
			disc(parent, at + UP * 0.05, rng:NextNumber(2, 4), 0.06, rgb(30, 20, 14), Enum.Material.SmoothPlastic).Name = "Stain"
		end)
	end
	Floors.Mud = function(parent, center: Vector3, size: number, rng)
		scatter(parent, center, size, rng, math.floor(size / 10), function(at)
			local puddle = glow(disc(parent, at + UP * 0.04, rng:NextNumber(2, 4), 0.08, P().Glow))
			puddle.Transparency = 0.6
			puddle.Name = "Puddle"
		end)
	end
	Floors.Litter = function(parent, center: Vector3, size: number, rng)
		scatter(parent, center, size, rng, math.floor(size / 8), function(at)
			disc(parent, at + UP * 0.03, rng:NextNumber(2, 4.5), 0.08, if rng:NextNumber() < 0.5 then rgb(60, 90, 40) else rgb(70, 54, 30), Enum.Material.Grass).Name = "Moss"
		end)
		scatter(parent, center, size, rng, math.floor(size / 14), function(at)
			local spore = glow(part(parent, CFrame.new(at + UP * 0.05) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Vector3.new(0.3, 0.08, rng:NextNumber(2, 5)), P().Glow))
			spore.Name = "Crack"
			spore.Transparency = 0.4
		end)
	end

	-- Lamps ---------------------------------------------------------------------------------------------------
	-- (Each has a fire and a light; its main part is "Brazier".)

	local function lampLight(at, coals, size)
		fire(coals, size or 6, 10)
		light(coals, P().Accent, 36, 2.2)
	end
	Lamps.Brazier = function(parent, at: Vector3)
		part(parent, CFrame.new(at + UP * 1.8), Vector3.new(1.4, 3.6, 1.4), P().Obsidian, Enum.Material.Slate, nil, true)
		local bowl = part(parent, CFrame.new(at + UP * 3.9) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1.2, 4, 4), P().Obsidian, Enum.Material.Slate, "Cylinder", true)
		bowl.Name = "Brazier"
		lampLight(at, glow(part(parent, CFrame.new(at + UP * 4.55), Vector3.new(3, 0.3, 3), P().Accent)))
	end
	Lamps.SkullTorch = function(parent, at: Vector3)
		local stake = cylinder(parent, at + UP * 3, 0.5, 6, rgb(30, 22, 20), Enum.Material.Wood, true)
		stake.Name = "Brazier"
		local skull = part(parent, CFrame.new(at + UP * 7), Vector3.new(2.4, 2.4, 2.4), K.BONE, Enum.Material.SmoothPlastic, "Ball")
		lampLight(at, glow(part(parent, CFrame.new(at + UP * 8.3), Vector3.new(1.4, 0.3, 1.4), P().Accent)), 5)
		glow(part(parent, skull.CFrame * CFrame.new(-0.5, 0.2, -1.1), Vector3.new(0.4, 0.4, 0.4), P().Glow, nil, "Ball"))
		glow(part(parent, skull.CFrame * CFrame.new(0.5, 0.2, -1.1), Vector3.new(0.4, 0.4, 0.4), P().Glow, nil, "Ball"))
	end
	Lamps.IceLantern = function(parent, at: Vector3)
		local stand = part(parent, CFrame.new(at + UP * 1.5), Vector3.new(2, 3, 2), rgb(170, 214, 245), Enum.Material.Glass, nil, true)
		stand.Transparency = 0.25
		stand.Name = "Brazier"
		local crystal = glow(part(parent, CFrame.new(at + UP * 5.2) * CFrame.Angles(0, 0.6, 0), Vector3.new(1.6, 4.4, 1.6), P().Glow, nil, "Wedge"))
		crystal.Transparency = 0.15
		lampLight(at, crystal, 3)
	end
	Lamps.Anemone = function(parent, at: Vector3)
		local stalk = cylinder(parent, at + UP * 2, 0.8, 4, rgb(22, 36, 46), Enum.Material.Slate, true)
		stalk.Name = "Brazier"
		local core = glow(part(parent, CFrame.new(at + UP * 4.6), Vector3.new(2.2, 2.2, 2.2), P().Glow, nil, "Ball"))
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			glow(part(parent, CFrame.new(at + UP * 5.4 + Vector3.new(math.cos(a) * 1.4, 0, math.sin(a) * 1.4)), Vector3.new(0.7, 0.7, 0.7), P().Accent, nil, "Ball"))
		end
		lampLight(at, core, 3)
	end
	Lamps.ColdTube = function(parent, at: Vector3)
		local post = part(parent, CFrame.new(at + UP * 3), Vector3.new(1.2, 6, 1.2), rgb(110, 124, 146), Enum.Material.Metal, nil, true)
		post.Name = "Brazier"
		local tube = glow(part(parent, CFrame.new(at + UP * 7), Vector3.new(0.6, 3.6, 0.6), rgb(220, 240, 255)))
		part(parent, CFrame.new(at + UP * 9.2), Vector3.new(2.4, 0.6, 2.4), rgb(110, 124, 146), Enum.Material.Metal)
		lampLight(at, tube, 3)
	end
	Lamps.TeslaPole = function(parent, at: Vector3)
		local pole = part(parent, CFrame.new(at + UP * 3.5), Vector3.new(1, 7, 1), rgb(52, 60, 34), Enum.Material.Wood, nil, true)
		pole.Name = "Brazier"
		for i = 1, 2 do
			glow(disc(parent, at + UP * (2 + i * 2), 1.2, 0.25, P().Glow)).Transparency = 0.3
		end
		local ball = glow(part(parent, CFrame.new(at + UP * 8), Vector3.new(2, 2, 2), P().Glow, nil, "Ball"))
		lampLight(at, ball, 4)
	end
	Lamps.CrystalCluster = function(parent, at: Vector3)
		local base = part(parent, CFrame.new(at + UP * 1), Vector3.new(3, 2, 3), P().Obsidian, Enum.Material.Slate, nil, true)
		base.Name = "Brazier"
		local core
		for i = 1, 3 do
			local a = i * 2.1
			local c = glow(part(parent, CFrame.new(at + UP * 3.8 + Vector3.new(math.cos(a) * 0.8, 0, math.sin(a) * 0.8)) * CFrame.Angles(0.25, a, 0), Vector3.new(1.1, 4 + i * 0.6, 1.1), P().Glow, nil, "Wedge"))
			c.Transparency = 0.15
			core = core or c
		end
		lampLight(at, core, 3)
	end
	Lamps.PaperLantern = function(parent, at: Vector3)
		local post = part(parent, CFrame.new(at + UP * 4), Vector3.new(0.8, 8, 0.8), rgb(40, 28, 22), Enum.Material.Wood, nil, true)
		post.Name = "Brazier"
		part(parent, CFrame.new(at + UP * 8.2) * CFrame.new(0, 0, -1.6), Vector3.new(0.5, 0.5, 3.6), rgb(40, 28, 22), Enum.Material.Wood)
		local lantern = glow(cylinder(parent, at + UP * 6.4 + Vector3.new(0, 0, -3.2), 1.3, 3, rgb(255, 214, 140), nil, false))
		lantern.Transparency = 0.1
		lampLight(at, lantern, 3)
	end
	Lamps.GasLamp = function(parent, at: Vector3)
		local stem = cylinder(parent, at + UP * 3, 0.35, 6, rgb(40, 70, 36), Enum.Material.Grass, true)
		stem.Name = "Brazier"
		local bubble = glow(part(parent, CFrame.new(at + UP * 7), Vector3.new(2.6, 2.6, 2.6), P().Glow, nil, "Ball"))
		bubble.Transparency = 0.25
		lampLight(at, bubble, 3)
	end
	Lamps.Toadstool = function(parent, at: Vector3)
		local stem = cylinder(parent, at + UP * 2.5, 1, 5, rgb(200, 190, 150), Enum.Material.SmoothPlastic, true)
		stem.Name = "Brazier"
		disc(parent, at + UP * 5.6, 3.4, 1.4, rgb(120, 100, 60), Enum.Material.SmoothPlastic).Name = "Cap"
		local gills = glow(disc(parent, at + UP * 4.85, 3, 0.2, P().Glow))
		gills.Transparency = 0.3
		lampLight(at, gills, 3)
	end

	-- Gates ---------------------------------------------------------------------------------------------------
	-- The barrier across a passage: its solid "Wall" (translucent, the
	-- realm's Glow), a "Glow" behind it, 8 or more "Tongue"s (the curtain's
	-- strands) and 3 fires; RiftWorld.openGate hides the Wall, the Glow
	-- and the Tongues and puts the fires and lights out.

	local function barrier(model, frame: CFrame, width: number, color: Color3?, clear: number?)
		local wall = part(model, frame * CFrame.new(0, 9, 0), Vector3.new(width, 18, 1.2), color or P().Glow, Enum.Material.Neon, nil, true)
		wall.Name = "Wall"
		wall.Transparency = clear or 0.78
		wall.CastShadow = false
		local inner = part(model, frame * CFrame.new(0, 8, -0.9), Vector3.new(width - 2, 16, 0.4), P().Accent, Enum.Material.Neon)
		inner.Name = "Glow"
		inner.Transparency = 0.85
		for i = -1, 1 do
			local base = part(model, frame * CFrame.new(i * 6.5, 0.5, 0), Vector3.new(1, 1, 1), P().Glow, Enum.Material.Neon)
			base.Name = "Flame"
			base.Transparency = 1
			fire(base, 9, 16)
		end
		light(wall, P().Accent, 34, 2.4)
		return wall
	end
	local function posts(model, frame: CFrame, width: number, color: Color3, material, cap: boolean?)
		for _, s in { -1, 1 } do
			part(model, frame * CFrame.new(s * (width / 2 + 1.5), 10, 0), Vector3.new(3, 20, 3), color, material, nil, true)
			if cap ~= false then
				part(model, frame * CFrame.new(s * (width / 2 + 1.5), 22, 0) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0), Vector3.new(3, 4, 3), color, material, "CornerWedge")
			end
		end
	end
	-- `count` strands across the width, `make(x, i)`.
	local function strands(width: number, count: number, make)
		for i = 0, count - 1 do
			make(-width / 2 + 0.8 + i * (width - 1.6) / (count - 1), i)
		end
	end

	-- Drago: a wall of fire, tongues of flame licking up it.
	Gates.Fire = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width)
		local tongues = { P().Glow, P().Accent, P().Tongue }
		strands(width, math.floor(width / 1.3), function(x, i)
			local tall = 7 + 8 * math.abs(math.sin(i * 1.7 + room)) + (if i % 3 == 0 then 2 else 0)
			local lick = part(model, frame * CFrame.new(x, tall / 2, -0.2 + (i % 2) * 0.4) * CFrame.Angles(0, 0, math.sin(i * 2.3) * 0.12), Vector3.new(0.7 + (i % 3) * 0.25, tall, 0.35), tongues[i % 3 + 1], Enum.Material.Neon)
			lick.Name = "Tongue"
			lick.Transparency = 0.2 + (i % 3) * 0.12
		end)
		posts(model, frame, width, P().Obsidian, Enum.Material.Slate)
	end
	-- Sahur: burning logs stacked across the way, their ends glowing.
	Gates.Logpile = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, P().Dark, 0.7)
		for i = 0, 7 do
			local y = 1.4 + i * 2.2
			local log = part(model, frame * CFrame.new((i % 2) * 1.2 - 0.6, y, 0) * CFrame.Angles(0, 0, 0), Vector3.new(width + 2, 2.2, 2.2), rgb(30, 22, 20), Enum.Material.Wood)
			log.Name = "Tongue"
			local ember = part(model, frame * CFrame.new(0, y, -1.2), Vector3.new(width * 0.9, 0.5, 0.2), if i % 2 == 0 then P().Glow else P().Accent, Enum.Material.Neon)
			ember.Name = "Tongue"
			ember.Transparency = 0.25
		end
		posts(model, frame, width, rgb(30, 22, 20), Enum.Material.Wood)
	end
	-- Paperotti: icicles down across the way, the air frozen between them.
	Gates.Icicles = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, rgb(170, 214, 245), 0.6)
		strands(width, math.floor(width / 1.6), function(x, i)
			local long = 8 + 9 * math.abs(math.sin(i * 1.9 + room))
			local icicle = part(model, frame * CFrame.new(x, 18 - long / 2, (i % 2) * 0.5 - 0.25) * CFrame.Angles(math.pi, 0, 0), Vector3.new(1.1, long, 1.1), rgb(200, 232, 250), Enum.Material.Glass, "Wedge")
			icicle.Name = "Tongue"
			icicle.Transparency = 0.2
		end)
		part(model, frame * CFrame.new(0, 18.5, 0), Vector3.new(width + 4, 2.5, 3), rgb(240, 246, 255), Enum.Material.Snow)
		posts(model, frame, width, rgb(170, 214, 245), Enum.Material.Glass)
	end
	-- Tralalero: a wave frozen as it curled over the way, foam along its lip.
	Gates.Wave = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, rgb(120, 220, 235), 0.65)
		local n = math.floor(width / 2.4)
		strands(width, n, function(x, i)
			local tall = 10 + 6 * math.abs(math.sin(i * 1.3 + room))
			local curl = part(model, frame * CFrame.new(x, tall / 2, 0.3) * CFrame.Angles(-0.4, 0, 0), Vector3.new(2.3, tall, 4), rgb(140, 220, 235), Enum.Material.Glass, "Wedge")
			curl.Name = "Tongue"
			curl.Transparency = 0.3
			local foam = part(model, frame * CFrame.new(x, tall + 0.4, -1.4), Vector3.new(2, 0.8, 1.2), P().Glow, Enum.Material.Neon)
			foam.Name = "Tongue"
			foam.Transparency = 0.35
		end)
		posts(model, frame, width, P().Obsidian, Enum.Material.Slate)
	end
	-- Frigo: a freezer door, its slats down, frost in the gaps, a cold light on.
	Gates.Shutter = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, rgb(200, 230, 250), 0.7)
		for i = 0, 8 do
			local slat = part(model, frame * CFrame.new(0, 1.2 + i * 2, 0), Vector3.new(width, 1.6, 0.8), rgb(150, 164, 184), Enum.Material.Metal)
			slat.Name = "Tongue"
			local frost = part(model, frame * CFrame.new((i % 3 - 1) * width / 4, 2.1 + i * 2, -0.6), Vector3.new(width / 3, 0.35, 0.2), rgb(236, 246, 255), Enum.Material.Neon)
			frost.Name = "Tongue"
			frost.Transparency = 0.4
		end
		part(model, frame * CFrame.new(0, 19.5, 0), Vector3.new(width + 4, 3, 3), rgb(110, 124, 146), Enum.Material.Metal)
		posts(model, frame, width, rgb(110, 124, 146), Enum.Material.Metal, false)
	end
	-- Chimpanzini: a lattice of vines across the way, live current in them.
	Gates.Lattice = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, P().Glow, 0.85)
		local vine = rgb(54, 72, 30)
		strands(width, math.floor(width / 3), function(x, i)
			for _, lean in { 0.5, -0.5 } do
				local v = part(model, frame * CFrame.new(x, 9, (i % 2) * 0.6 - 0.3) * CFrame.Angles(0, 0, lean), Vector3.new(0.7, 20, 0.7), vine, Enum.Material.Grass)
				v.Name = "Tongue"
			end
			local bead = part(model, frame * CFrame.new(x, 4 + 10 * math.abs(math.sin(i * 1.7 + room)), -0.5), Vector3.new(0.8, 0.8, 0.8), P().Glow, Enum.Material.Neon, "Ball")
			bead.Name = "Tongue"
		end)
		posts(model, frame, width, rgb(52, 60, 34), Enum.Material.Wood)
	end
	-- Gattini: a field of static arcing between two crystal pylons.
	Gates.ArcField = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, P().Glow, 0.88)
		for i = 0, 8 do
			local y = 2 + i * 1.9
			local arc = part(model, frame * CFrame.new((i % 2) * 0.8 - 0.4, y, (i % 3) * 0.3 - 0.3) * CFrame.Angles(0, 0, math.sin(i * 2.3 + room) * 0.08), Vector3.new(width + 1, 0.25, 0.25), if i % 2 == 0 then P().Glow else P().Tongue, Enum.Material.Neon)
			arc.Name = "Tongue"
			arc.Transparency = 0.15 + (i % 3) * 0.15
		end
		for _, s in { -1, 1 } do
			local pylon = part(model, frame * CFrame.new(s * (width / 2 + 1.5), 10, 0), Vector3.new(3, 20, 3), rgb(110, 96, 150), Enum.Material.Glass, nil, true)
			pylon.Transparency = 0.15
			glow(part(model, frame * CFrame.new(s * (width / 2 + 1.5), 22.5, 0), Vector3.new(2, 5, 2), P().Glow, nil, "Wedge"))
		end
	end
	-- Cappuccino: a curtain of blades hung edge-on across the way.
	Gates.BladeCurtain = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, P().Glow, 0.86)
		strands(width, math.floor(width / 1.7), function(x, i)
			local long = 7 + 8 * math.abs(math.sin(i * 1.5 + room))
			local blade = part(model, frame * CFrame.new(x, 18 - long / 2, (i % 2) * 0.5 - 0.25) * CFrame.Angles(0, 0, math.sin(i * 1.1) * 0.06), Vector3.new(0.3, long, 1.6), rgb(200, 205, 215), Enum.Material.Metal)
			blade.Name = "Tongue"
			local edge = part(model, frame * CFrame.new(x, 18 - long / 2, (i % 2) * 0.5 - 0.25 - 0.85), Vector3.new(0.12, long - 0.4, 0.2), P().Glow, Enum.Material.Neon)
			edge.Name = "Tongue"
			edge.Transparency = 0.2
		end)
		part(model, frame * CFrame.new(0, 19, 0), Vector3.new(width + 4, 1.4, 1.4), rgb(40, 28, 22), Enum.Material.Wood)
		posts(model, frame, width, rgb(40, 28, 22), Enum.Material.Wood)
	end
	-- Ranocchio: a curtain of marsh gas, bubbles rising through it.
	Gates.Gas = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, P().Glow, 0.72)
		strands(width, math.floor(width / 2), function(x, i)
			for k = 0, 1 do
				local bubble = part(model, frame * CFrame.new(x, 3 + 11 * ((i * 0.37 + k * 0.5 + room * 0.1) % 1), (i % 2) * 0.6 - 0.3), Vector3.new(1 + (i % 3) * 0.4, 1 + (i % 3) * 0.4, 1 + (i % 3) * 0.4), P().Glow, Enum.Material.Neon, "Ball")
				bubble.Name = "Tongue"
				bubble.Transparency = 0.35
			end
		end)
		for _, s in { -1, 1 } do
			part(model, frame * CFrame.new(s * (width / 2 + 1.5), 10, 0), Vector3.new(3, 20, 3), rgb(50, 40, 30), Enum.Material.Mud, nil, true)
			for i = 1, 3 do
				cylinder(model, (frame * CFrame.new(s * (width / 2 + 1.5), 10, 0)).Position, 0.8, 20, rgb(60, 48, 34), Enum.Material.Wood, false, CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, 0, -2) * CFrame.Angles(0, 0, 0.1))
			end
		end
	end
	-- Patapim: thorned roots woven across the way.
	Gates.Thorns = function(model, frame: CFrame, width: number, room: number)
		barrier(model, frame, width, P().Dark, 0.8)
		local root = rgb(60, 48, 34)
		strands(width, math.floor(width / 3), function(x, i)
			for _, lean in { 0.35, -0.35 } do
				local r = part(model, frame * CFrame.new(x, 9, (i % 2) * 0.6 - 0.3) * CFrame.Angles(0, 0, lean), Vector3.new(1, 19, 1), root, Enum.Material.Wood)
				r.Name = "Tongue"
			end
			local thorn = part(model, frame * CFrame.new(x, 4 + 10 * math.abs(math.sin(i * 1.7 + room)), -0.9) * CFrame.Angles(math.pi / 2, 0, 0), Vector3.new(0.6, 1.8, 0.6), rgb(90, 80, 60), Enum.Material.SmoothPlastic, "Wedge")
			thorn.Name = "Tongue"
		end)
		posts(model, frame, width, root, Enum.Material.Wood)
	end

	-- Arches --------------------------------------------------------------------------------------------------
	-- Over a passage (mid: its middle; dir: along it; side: across). The
	-- "Arch" and the "Fang"s hang 12 studs clear of the floor at least.

	local function lintel(model, mid: Vector3, side: Vector3, width: number, color: Color3, material, size: Vector3?)
		local tall = K.Wall
		return part(model, face(mid + UP * (tall - 3), side), size or Vector3.new(14, 7, width + K.Thick * 2 + 6), color, material)
	end
	local function hang(model, mid: Vector3, side: Vector3, dir: Vector3, width: number, rng, count: number, make)
		for i = 1, count do
			local across = (i - (count + 1) / 2) * width / count + rng:NextNumber(-1, 1)
			make(mid + side * across + dir * rng:NextNumber(-4, 4), i)
		end
	end
	Arches.Rock = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		lintel(model, mid, side, width, P().Basalt, Enum.Material.Slate).Name = "Arch"
		hang(model, mid, side, dir, width, rng, 5, function(at)
			local long = rng:NextNumber(4, 9)
			part(model, CFrame.new(at + UP * (K.Wall - 6.5 - long / 2)) * CFrame.Angles(math.pi, rng:NextNumber(0, 6), 0), Vector3.new(2.2, long, 2.2), P().Obsidian, Enum.Material.Slate, "Wedge").Name = "Fang"
		end)
	end
	Arches.Burnt = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		local beam = lintel(model, mid, side, width, rgb(30, 22, 20), Enum.Material.Wood, Vector3.new(6, 6, width + K.Thick * 2 + 6))
		beam.Name = "Arch"
		hang(model, mid, side, dir, width, rng, 4, function(at)
			local long = rng:NextNumber(3, 7)
			local ember = glow(part(model, CFrame.new(at + UP * (K.Wall - 6 - long / 2)), Vector3.new(0.5, long, 0.5), P().Glow))
			ember.Name = "Fang"
			ember.Transparency = 0.3
		end)
		fire(beam, 8, 10)
	end
	Arches.IceArch = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		local arch = lintel(model, mid, side, width, rgb(170, 214, 245), Enum.Material.Glass)
		arch.Name = "Arch"
		arch.Transparency = 0.3
		hang(model, mid, side, dir, width, rng, 6, function(at)
			local long = rng:NextNumber(3, 8)
			local icicle = part(model, CFrame.new(at + UP * (K.Wall - 6.5 - long / 2)) * CFrame.Angles(math.pi, 0, 0), Vector3.new(1.2, long, 1.2), rgb(200, 232, 250), Enum.Material.Glass, "Wedge")
			icicle.Name = "Fang"
			icicle.Transparency = 0.2
		end)
	end
	Arches.WaveArch = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		local curl = part(model, face(mid + UP * (K.Wall - 1), dir) * CFrame.Angles(-0.6, 0, 0), Vector3.new(width + K.Thick * 2 + 6, 10, 12), rgb(140, 220, 235), Enum.Material.Glass, "Wedge")
		curl.Name = "Arch"
		curl.Transparency = 0.3
		local foam = glow(part(model, face(mid + dir * 5 + UP * (K.Wall + 4.5), side), Vector3.new(1.2, 1, width + K.Thick * 2 + 4), P().Glow))
		foam.Transparency = 0.4
		hang(model, mid, side, dir, width, rng, 4, function(at)
			local drip = glow(part(model, CFrame.new(at + UP * (K.Wall - 5)), Vector3.new(0.6, 2.5, 0.6), P().Glow, nil, "Ball"))
			drip.Name = "Fang"
			drip.Transparency = 0.3
		end)
	end
	Arches.Lintel = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		lintel(model, mid, side, width, rgb(110, 124, 146), Enum.Material.Metal, Vector3.new(10, 5, width + K.Thick * 2 + 6)).Name = "Arch"
		local tube = glow(part(model, face(mid + UP * (K.Wall - 6), side), Vector3.new(0.5, 0.5, width - 2), rgb(220, 240, 255)))
		tube.Name = "Fang"
		light(tube, P().Glow, 30, 1.2)
		hang(model, mid, side, dir, width, rng, 4, function(at)
			local long = rng:NextNumber(2, 5)
			local frost = part(model, CFrame.new(at + UP * (K.Wall - 6 - long / 2)) * CFrame.Angles(math.pi, 0, 0), Vector3.new(0.9, long, 0.9), rgb(236, 246, 255), Enum.Material.Glass, "Wedge")
			frost.Name = "Fang"
			frost.Transparency = 0.3
		end)
	end
	Arches.Canopy = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		lintel(model, mid, side, width, rgb(40, 70, 36), Enum.Material.Grass, Vector3.new(16, 5, width + K.Thick * 2 + 6)).Name = "Arch"
		part(model, face(mid + UP * (K.Wall - 6), side) * CFrame.Angles(0, 0, 0.08), Vector3.new(2, 2, width + K.Thick * 2 + 2), rgb(52, 60, 34), Enum.Material.Wood).Name = "Arch"
		hang(model, mid, side, dir, width, rng, 5, function(at)
			local long = rng:NextNumber(3, 8)
			cylinder(model, at + UP * (K.Wall - 7 - long / 2), 0.3, long, rgb(54, 72, 30), Enum.Material.Grass, false).Name = "Fang"
			glow(part(model, CFrame.new(at + UP * (K.Wall - 7 - long)), Vector3.new(0.6, 0.6, 0.6), P().Glow, nil, "Ball")).Name = "Fang"
		end)
	end
	Arches.CrystalArch = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		local arch = lintel(model, mid, side, width, rgb(110, 96, 150), Enum.Material.Glass, Vector3.new(10, 6, width + K.Thick * 2 + 6))
		arch.Name = "Arch"
		arch.Transparency = 0.15
		hang(model, mid, side, dir, width, rng, 5, function(at, i)
			local long = rng:NextNumber(3, 7)
			local spike = part(model, CFrame.new(at + UP * (K.Wall - 6 - long / 2)) * CFrame.Angles(math.pi, i, 0), Vector3.new(1.4, long, 1.4), rgb(110, 96, 150), Enum.Material.Glass, "Wedge")
			spike.Name = "Fang"
			spike.Transparency = 0.15
			glow(part(model, CFrame.new(at + UP * (K.Wall - 6 - long - 0.4)), Vector3.new(0.6, 0.9, 0.6), P().Glow, nil, "Wedge")).Name = "Fang"
		end)
	end
	Arches.Torii = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		local timber = rgb(150, 40, 34)
		local top = lintel(model, mid, side, width, timber, Enum.Material.Wood, Vector3.new(3, 2.2, width + K.Thick * 2 + 10))
		top.Name = "Arch"
		top.CFrame = top.CFrame * CFrame.new(0, 2, 0)
		part(model, face(mid + UP * (K.Wall - 7.5), side), Vector3.new(2, 1.6, width + K.Thick * 2 + 2), timber, Enum.Material.Wood).Name = "Arch"
		for _, s in { -1, 1 } do
			part(model, CFrame.new(mid + side * s * (width / 2 + 1) + UP * (K.Wall / 2 - 1)), Vector3.new(2, K.Wall - 2, 2), timber, Enum.Material.Wood)
		end
		hang(model, mid, side, dir, width, rng, 4, function(at)
			local lantern = glow(cylinder(model, at + UP * (K.Wall - 9), 0.8, 2.2, rgb(255, 214, 140), nil, false))
			lantern.Name = "Fang"
			lantern.Transparency = 0.1
		end)
	end
	Arches.RootArch = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		lintel(model, mid, side, width, rgb(50, 40, 30), Enum.Material.Mud, Vector3.new(12, 6, width + K.Thick * 2 + 6)).Name = "Arch"
		for i = 1, 3 do
			cylinder(model, mid + UP * (K.Wall - 3 + (i - 2) * 1.5) + dir * (i - 2) * 3, 0.9, width + K.Thick * 2 + 4, rgb(60, 48, 34), Enum.Material.Wood, false, CFrame.Angles(0, math.atan2(side.X, side.Z) + math.pi / 2, 0) * CFrame.Angles(0, 0, 0)).Name = "Arch"
		end
		hang(model, mid, side, dir, width, rng, 4, function(at)
			local long = rng:NextNumber(2, 6)
			cylinder(model, at + UP * (K.Wall - 6.5 - long / 2), 0.25, long, rgb(60, 48, 34), Enum.Material.Wood, false).Name = "Fang"
		end)
	end
	Arches.Bough = function(model, mid: Vector3, dir: Vector3, side: Vector3, width: number, rng)
		cylinder(model, mid + UP * (K.Wall - 3), 2.4, width + K.Thick * 2 + 6, rgb(54, 44, 32), Enum.Material.Wood, false, CFrame.Angles(0, math.atan2(side.X, side.Z) + math.pi / 2, 0)).Name = "Arch"
		hang(model, mid, side, dir, width, rng, 5, function(at, i)
			local long = rng:NextNumber(3, 8)
			cylinder(model, at + UP * (K.Wall - 5.5 - long / 2), 0.3, long, rgb(54, 44, 32), Enum.Material.Wood, false).Name = "Fang"
			if i % 2 == 0 then
				local shelf = disc(model, at + UP * (K.Wall - 5.5 - long), 1.2, 0.4, rgb(150, 120, 70), Enum.Material.SmoothPlastic)
				shelf.Name = "Fang"
				glow(disc(model, at + UP * (K.Wall - 5.8 - long), 1, 0.1, P().Glow)).Name = "Fang"
			end
		end)
	end

	-- Thrones -------------------------------------------------------------------------------------------------
	-- At the far end of the throne cave: `frame` at the seat, its front
	-- toward the way in.

	local function dais(model, frame: CFrame, color: Color3, material)
		part(model, frame * CFrame.new(0, 2, 0), Vector3.new(20, 4, 10), color, material, nil, true)
		part(model, frame * CFrame.new(0, 5, 2), Vector3.new(14, 2.5, 6), color, material, nil, true)
	end
	local function eyes(model, at: CFrame, color: Color3, spread: number)
		for _, s in { -1, 1 } do
			glow(part(model, at * CFrame.new(s * spread, 0, 0), Vector3.new(1.4, 1.4, 1.4), color, nil, "Ball"))
		end
	end
	local function torches(model, frame: CFrame, color: Color3, material, spread: number)
		for _, s in { -1, 1 } do
			local pillar = part(model, frame * CFrame.new(s * spread, 6, 0), Vector3.new(3, 12, 3), color, material, nil, true)
			local top = part(model, frame * CFrame.new(s * spread, 12.3, 0), Vector3.new(3.4, 0.6, 3.4), P().Accent, Enum.Material.Neon)
			fire(top, 10, 20)
			light(pillar, P().Accent, 44, 2.5)
		end
	end

	-- Drago: a dais in a crater, the dragon's skull over it, and the one
	-- bomb that never went off stood nose-down behind, taller than the wall.
	Thrones.Crater = function(model, frame: CFrame, seat: Vector3)
		dais(model, frame, P().Obsidian, Enum.Material.Slate)
		part(model, frame * CFrame.new(0, 14, 4.5), Vector3.new(12, 18, 2.5), P().Obsidian, Enum.Material.Slate, nil, true)
		local skull = part(model, frame * CFrame.new(0, 25, 4.5), Vector3.new(7, 7, 7), K.BONE, Enum.Material.SmoothPlastic, "Ball")
		skull.Name = "Skull"
		part(model, frame * CFrame.new(0, 22, 1.5), Vector3.new(5, 3, 5), K.BONE, Enum.Material.SmoothPlastic, "Wedge")
		eyes(model, frame * CFrame.new(0, 25.4, 1.5), P().Dark, 1.5)
		local iron = rgb(62, 58, 64)
		local bomb = cylinder(model, frame * CFrame.new(0, 15, 6).Position, 4.5, 26, iron, Enum.Material.Metal, true, CFrame.Angles(-0.18, 0, 0))
		bomb.Name = "Bomb"
		part(model, bomb.CFrame * CFrame.new(-13, 0, 0), Vector3.new(7, 7, 7), iron, Enum.Material.Metal, "Ball")
		for f = 1, 4 do
			part(model, bomb.CFrame * CFrame.new(11, 0, 0) * CFrame.Angles(f * math.pi / 2, 0, 0) * CFrame.new(0, 5.5, 0), Vector3.new(6, 6, 0.5), P().Dark, Enum.Material.Metal)
		end
		glow(part(model, bomb.CFrame * CFrame.new(-6, 0, 0), Vector3.new(2, 10, 10), P().Glow, nil, "Cylinder")).Transparency = 0.4
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			part(model, frame * CFrame.new(math.cos(a) * 14, 1.2, 3 + math.sin(a) * 9), Vector3.new(3, 2.4, 3), P().Rock, Enum.Material.Slate)
		end
		torches(model, frame, P().Obsidian, Enum.Material.Slate, 13)
	end
	-- Sahur: a great stump for a seat, three log heads on stakes over it,
	-- the nailed bat leaning against it, fire in the hollow behind.
	Thrones.Stump = function(model, frame: CFrame, seat: Vector3)
		local bark = rgb(30, 22, 20)
		local stump = cylinder(model, frame * CFrame.new(0, 3, 0).Position, 8, 6, bark, Enum.Material.Wood, true)
		stump.Name = "Stump"
		glow(disc(model, frame * CFrame.new(0, 6.1, 0).Position, 7, 0.3, P().Dark)).Transparency = 0.5
		for i = 1, 3 do
			local s = (i - 2) * 6
			cylinder(model, frame * CFrame.new(s, 12, 4).Position, 0.6, 12, bark, Enum.Material.Wood, true)
			local head = cylinder(model, frame * CFrame.new(s, 21, 4).Position, 2.2, 5, rgb(70, 50, 36), Enum.Material.Wood, false)
			head.Name = "LogHead"
			eyes(model, frame * CFrame.new(s, 21.5, 1.6), P().Glow, 0.8)
			part(model, frame * CFrame.new(s, 19.5, 1.9), Vector3.new(2.4, 0.6, 0.4), P().Obsidian, Enum.Material.SmoothPlastic)
		end
		local bat = cylinder(model, frame * CFrame.new(9, 5, -2).Position, 1.1, 11, rgb(70, 50, 36), Enum.Material.Wood, false, CFrame.Angles(0.25, 0, -0.35))
		bat.Name = "Bat"
		for n = 1, 4 do
			part(model, bat.CFrame * CFrame.new(2 + n * 1.2, 0, 0) * CFrame.Angles(n * 1.3, 0, 0) * CFrame.new(0, 1.4, 0), Vector3.new(0.3, 1.4, 0.3), rgb(120, 120, 130), Enum.Material.Metal)
		end
		local hollow = glow(part(model, frame * CFrame.new(0, 10, 8), Vector3.new(10, 14, 3), P().Glow))
		hollow.Transparency = 0.35
		fire(hollow, 14, 20)
		light(hollow, P().Accent, 50, 2.5)
		torches(model, frame, bark, Enum.Material.Wood, 14)
	end
	-- Paperotti: a nest of ice shards with two great eggs in it, frozen,
	-- faintly lit, and a fountain frozen mid-spray behind.
	Thrones.Nest = function(model, frame: CFrame, seat: Vector3)
		local ice = rgb(170, 214, 245)
		dais(model, frame, ice, Enum.Material.Ice)
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			local shard = part(model, frame * CFrame.new(math.cos(a) * 9, 7, 2 + math.sin(a) * 5) * CFrame.Angles(0, -a, 0) * CFrame.Angles(-0.5, 0, 0), Vector3.new(2.2, rng_or(i, 6, 10), 2.2), ice, Enum.Material.Glass, "Wedge")
			shard.Transparency = 0.25
			shard.Name = "Shard"
		end
		for _, s in { -1, 1 } do
			local egg = glow(part(model, frame * CFrame.new(s * 3.2, 8.6, 2), Vector3.new(4.4, 5.6, 4.4), rgb(230, 244, 255), nil, "Ball"))
			egg.Transparency = 0.2
			egg.Name = "Egg"
			light(egg, P().Glow, 24, 1.2)
		end
		local spray = part(model, frame * CFrame.new(0, 16, 9) * CFrame.Angles(0, 0, 0), Vector3.new(14, 20, 3), ice, Enum.Material.Glass, "Wedge")
		spray.Transparency = 0.3
		spray.Name = "Fountain"
		torches(model, frame, ice, Enum.Material.Glass, 14)
	end
	-- Tralalero: a wave frozen as it broke over the seat, two fins cutting
	-- up either side, and a sneaker the size of a boat washed up behind.
	Thrones.Breaker = function(model, frame: CFrame, seat: Vector3)
		dais(model, frame, P().Obsidian, Enum.Material.Slate)
		local wave = part(model, frame * CFrame.new(0, 14, 7) * CFrame.Angles(-0.7, 0, 0), Vector3.new(26, 16, 14), rgb(140, 220, 235), Enum.Material.Glass, "Wedge")
		wave.Transparency = 0.3
		wave.Name = "Wave"
		local foam = glow(part(model, frame * CFrame.new(0, 22.5, -1), Vector3.new(24, 1.2, 2), P().Glow))
		foam.Transparency = 0.35
		light(foam, P().Glow, 40, 1.5)
		for _, s in { -1, 1 } do
			part(model, frame * CFrame.new(s * 11, 5, 1) * CFrame.Angles(0, 0, 0), Vector3.new(3, 10, 7), rgb(22, 36, 46), Enum.Material.Slate, "Wedge", true).Name = "Fin"
		end
		local shoe = part(model, frame * CFrame.new(-16, 3.5, 10) * CFrame.Angles(0, 0.5, 0.15), Vector3.new(14, 6, 6), rgb(230, 230, 225), Enum.Material.SmoothPlastic, nil, true)
		shoe.Name = "Sneaker"
		part(model, shoe.CFrame * CFrame.new(0, -2, 0), Vector3.new(14.5, 2, 6.5), rgb(40, 40, 46), Enum.Material.SmoothPlastic)
		part(model, shoe.CFrame * CFrame.new(-4, 2, 0), Vector3.new(6, 3, 4), rgb(230, 230, 225), Enum.Material.SmoothPlastic, "Wedge")
		glow(part(model, shoe.CFrame * CFrame.new(2, 1, -3.1), Vector3.new(5, 1.2, 0.2), P().Dark)).Transparency = 0.4
	end
	-- Frigo: a fridge the height of the wall, its door hanging open on cold
	-- light and shelves of things gone bad, the seat on its bottom shelf.
	Thrones.Fridge = function(model, frame: CFrame, seat: Vector3)
		local steel, dark = rgb(190, 200, 214), rgb(60, 70, 90)
		part(model, frame * CFrame.new(0, 2, 0), Vector3.new(22, 4, 12), steel, Enum.Material.Metal, nil, true)
		part(model, frame * CFrame.new(0, 17, 6.5), Vector3.new(20, 30, 6), steel, Enum.Material.Metal, nil, true).Name = "Fridge"
		for _, s in { -1, 1 } do
			part(model, frame * CFrame.new(s * 9.6, 17, 2), Vector3.new(0.8, 30, 4), steel, Enum.Material.Metal, nil, true)
		end
		part(model, frame * CFrame.new(0, 32.4, 3.5), Vector3.new(20, 0.8, 12), steel, Enum.Material.Metal)
		local inside = glow(part(model, frame * CFrame.new(0, 17, 3.4), Vector3.new(18, 29, 0.4), rgb(220, 240, 255)))
		inside.Transparency = 0.3
		light(inside, P().Glow, 60, 2.5)
		for i = 1, 3 do
			part(model, frame * CFrame.new(0, 5 + i * 7, 2), Vector3.new(18, 0.5, 4), dark, Enum.Material.Metal).Name = "Shelf"
			for k = -1, 1 do
				local jar = part(model, frame * CFrame.new(k * 5.5, 7 + i * 7, 2), Vector3.new(2.6, 3.4, 2.6), rgb(190, 225, 250), Enum.Material.Glass)
				jar.Transparency = 0.35
				glow(part(model, jar.CFrame, Vector3.new(1.4, 1.6, 1.4), if (i + k) % 2 == 0 then P().Dark else rgb(60, 160, 90), nil, "Ball")).Transparency = 0.2
			end
		end
		local door = part(model, frame * CFrame.new(-16, 17, -2) * CFrame.Angles(0, 1.1, 0), Vector3.new(0.9, 30, 20), steel, Enum.Material.Metal, nil, true)
		door.Name = "Door"
		part(model, door.CFrame * CFrame.new(-0.9, 0, 7), Vector3.new(1, 10, 1.2), dark, Enum.Material.Metal)
		for i = 1, 6 do
			local frost = glow(part(model, frame * CFrame.new((i - 3.5) * 5, 1 + (i % 3) * 10, -4 + (i % 2) * 2), Vector3.new(3, 0.3, 1.5), rgb(236, 246, 255)))
			frost.Transparency = 0.5
		end
		torches(model, frame, dark, Enum.Material.Metal, 15)
	end
	-- Chimpanzini: a banana split open for a seat under a palm wired with
	-- current, its leaves crackling.
	Thrones.Banana = function(model, frame: CFrame, seat: Vector3)
		local peel = rgb(240, 200, 60)
		dais(model, frame, rgb(44, 52, 32), Enum.Material.Grass)
		part(model, frame * CFrame.new(0, 6.5, 1), Vector3.new(16, 3, 8), rgb(250, 236, 180), Enum.Material.SmoothPlastic, nil, true).Name = "Banana"
		for i = 1, 4 do
			local a = (i - 2.5) * 0.9
			local p = part(model, frame * CFrame.new(math.sin(a) * 7, 9, 3 + math.cos(a) * 3) * CFrame.Angles(0, -a, 0) * CFrame.Angles(-0.9, 0, 0), Vector3.new(5, 14, 1.2), peel, Enum.Material.SmoothPlastic, "Wedge")
			p.Name = "Peel"
		end
		local trunk = cylinder(model, frame * CFrame.new(0, 14, 11).Position, 2.2, 28, rgb(52, 60, 34), Enum.Material.Wood, true)
		trunk.Name = "Trunk"
		for i = 1, 3 do
			glow(disc(model, frame * CFrame.new(0, 6 + i * 7, 11).Position, 2.6, 0.3, P().Glow)).Transparency = 0.3
		end
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			part(model, frame * CFrame.new(math.cos(a) * 7, 29, 11 + math.sin(a) * 7) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0.5, 0, 0), Vector3.new(4, 1, 14), rgb(40, 90, 36), Enum.Material.Grass).Name = "Leaf"
		end
		local crackle = glow(part(model, frame * CFrame.new(0, 29.5, 11), Vector3.new(3, 3, 3), P().Glow, nil, "Ball"))
		light(crackle, P().Glow, 50, 2)
		torches(model, frame, rgb(52, 60, 34), Enum.Material.Wood, 14)
	end
	-- Gattini: a cat tower of crystal platforms, static arcing up it, two
	-- pairs of eyes lit at the top.
	Thrones.CatTower = function(model, frame: CFrame, seat: Vector3)
		local crystal = rgb(110, 96, 150)
		dais(model, frame, P().Obsidian, Enum.Material.Slate)
		local post = part(model, frame * CFrame.new(0, 16, 6), Vector3.new(4, 30, 4), crystal, Enum.Material.Glass, nil, true)
		post.Transparency = 0.15
		post.Name = "Tower"
		for i = 1, 4 do
			local plat = part(model, frame * CFrame.new((i % 2) * 6 - 3, 4 + i * 6, 6), Vector3.new(12, 1.2, 8), crystal, Enum.Material.Glass, nil, true)
			plat.Transparency = 0.15
			local arc = glow(part(model, frame * CFrame.new((i % 2) * 6 - 3, 1 + i * 6, 2) * CFrame.Angles(0, 0, 0.4), Vector3.new(0.2, 6, 0.2), P().Glow))
			arc.Transparency = 0.3
		end
		local top = part(model, frame * CFrame.new(0, 30, 6), Vector3.new(10, 3, 10), crystal, Enum.Material.Glass)
		top.Transparency = 0.15
		for _, s in { -1, 1 } do
			local head = part(model, frame * CFrame.new(s * 3, 33, 6), Vector3.new(4, 3.5, 4), rgb(40, 32, 56), Enum.Material.SmoothPlastic)
			part(model, head.CFrame * CFrame.new(-1.2, 2.3, 0), Vector3.new(1.2, 1.6, 1), rgb(40, 32, 56), Enum.Material.SmoothPlastic, "Wedge")
			part(model, head.CFrame * CFrame.new(1.2, 2.3, 0), Vector3.new(1.2, 1.6, 1), rgb(40, 32, 56), Enum.Material.SmoothPlastic, "Wedge")
			eyes(model, head.CFrame * CFrame.new(0, 0.3, -2), P().Glow, 1)
		end
		light(top, P().Glow, 50, 2)
		torches(model, frame, crystal, Enum.Material.Glass, 14)
	end
	-- Cappuccino: a cracked cup the size of a hut, steam rising from it,
	-- a katana through the saucer; the seat is on the saucer's rim.
	Thrones.Cup = function(model, frame: CFrame, seat: Vector3)
		local china = rgb(236, 230, 220)
		local saucer = disc(model, frame * CFrame.new(0, 1, 4).Position, 16, 2, china, Enum.Material.SmoothPlastic)
		saucer.CanCollide = true
		saucer.Name = "Saucer"
		local cup = cylinder(model, frame * CFrame.new(0, 12, 6).Position, 10, 20, china, Enum.Material.SmoothPlastic, true)
		cup.Name = "Cup"
		local coffee = glow(disc(model, frame * CFrame.new(0, 22.2, 6).Position, 9.2, 0.4, rgb(70, 40, 24)))
		coffee.Transparency = 0.1
		local crack = glow(part(model, frame * CFrame.new(-4, 12, -4) * CFrame.Angles(0, 0.4, 0.25), Vector3.new(0.4, 14, 0.5), P().Glow))
		crack.Transparency = 0.2
		light(crack, P().Glow, 40, 1.8)
		cylinder(model, frame * CFrame.new(11, 12, 6).Position, 1.6, 10, china, Enum.Material.SmoothPlastic, false, CFrame.Angles(0, 0, 0))
		local steam = Instance.new("ParticleEmitter")
		steam.Rate = 8
		steam.Lifetime = NumberRange.new(2, 3)
		steam.Speed = NumberRange.new(3, 5)
		steam.Size = NumberSequence.new(3)
		steam.Transparency = NumberSequence.new(0.6)
		steam.Color = ColorSequence.new(rgb(240, 236, 230))
		steam.Parent = coffee
		local blade = part(model, frame * CFrame.new(10, 8, -4) * CFrame.Angles(0, 0.4, 0.5), Vector3.new(0.4, 16, 2.4), rgb(200, 205, 215), Enum.Material.Metal, nil, true)
		blade.Name = "Katana"
		glow(part(model, blade.CFrame * CFrame.new(0, 0, -1.25), Vector3.new(0.14, 15.6, 0.3), P().Glow)).Transparency = 0.2
		torches(model, frame, rgb(40, 28, 22), Enum.Material.Wood, 18)
	end
	-- Ranocchio: half an avocado for a seat, its pit glowing, on a lily pad
	-- in a pool of its own, reeds all round.
	Thrones.Avocado = function(model, frame: CFrame, seat: Vector3)
		local pool = glow(disc(model, frame * CFrame.new(0, 0.2, 3).Position, 17, 0.3, P().Glow))
		pool.Transparency = 0.5
		light(pool, P().Glow, 50, 1.5)
		disc(model, frame * CFrame.new(0, 0.1, 3).Position, 18.5, 0.25, rgb(26, 40, 28), Enum.Material.Mud)
		local pad = disc(model, frame * CFrame.new(0, 0.6, 2).Position, 12, 0.6, rgb(60, 120, 50), Enum.Material.Grass)
		pad.CanCollide = true
		pad.Name = "LilyPad"
		local skin = part(model, frame * CFrame.new(0, 5, 3), Vector3.new(16, 10, 12), rgb(50, 80, 40), Enum.Material.SmoothPlastic, "Ball", true)
		skin.Name = "Avocado"
		part(model, frame * CFrame.new(0, 9.2, 3), Vector3.new(14, 1.6, 10.4), rgb(180, 210, 110), Enum.Material.SmoothPlastic, "Ball")
		local pit = glow(part(model, frame * CFrame.new(0, 10.5, 4), Vector3.new(5, 5, 5), rgb(120, 80, 40), nil, "Ball"))
		pit.Name = "Pit"
		pit.Material = Enum.Material.SmoothPlastic
		glow(part(model, frame * CFrame.new(0, 10.5, 4), Vector3.new(5.6, 1, 5.6), P().Glow, nil, "Ball")).Transparency = 0.4
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			cylinder(model, frame * CFrame.new(math.cos(a) * 18, 3.5, 3 + math.sin(a) * 18).Position, 0.35, 7, rgb(40, 70, 36), Enum.Material.Grass, false)
		end
		torches(model, frame, rgb(50, 40, 30), Enum.Material.Mud, 20)
	end
	-- Patapim: a hollow dead tree, the seat in its mouth of a hollow lit
	-- green, roots spread round it, toadstools up it.
	Thrones.HollowTree = function(model, frame: CFrame, seat: Vector3)
		local bark = rgb(54, 44, 32)
		dais(model, frame, rgb(44, 42, 30), Enum.Material.Mud)
		local trunk = cylinder(model, frame * CFrame.new(0, 18, 8).Position, 9, 36, bark, Enum.Material.Wood, true)
		trunk.Name = "Trunk"
		local hollow = glow(part(model, frame * CFrame.new(0, 9, -0.5), Vector3.new(9, 12, 1.2), P().Glow))
		hollow.Transparency = 0.35
		hollow.Name = "Hollow"
		light(hollow, P().Glow, 50, 2)
		for i = 1, 3 do
			local a = i * 2.1
			cylinder(model, frame * CFrame.new(math.cos(a) * 9, 34, 8 + math.sin(a) * 9).Position, 1.2, 12, bark, Enum.Material.Wood, false, CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, -0.9))
		end
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			cylinder(model, frame * CFrame.new(math.cos(a) * 12, 1.5, 8 + math.sin(a) * 12).Position, 1, 10, bark, Enum.Material.Wood, false, CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, 1.35))
		end
		for i = 1, 3 do
			local at = frame * CFrame.new(-9.5, 6 + i * 6, 8 + (i - 2) * 3)
			disc(model, at.Position, 2.2, 0.8, rgb(150, 120, 70), Enum.Material.SmoothPlastic).Name = "Fungus"
			glow(disc(model, at.Position - UP * 0.5, 1.8, 0.12, P().Glow)).Transparency = 0.4
		end
		torches(model, frame, bark, Enum.Material.Wood, 15)
	end

	-- Skies ---------------------------------------------------------------------------------------------------
	-- Over it all: 8 "Scar"s or more (what burns across it), 14 "Cloud"s
	-- banked round the edge and lit from below, and the "Ash" falling.

	local function clouds(model, center: Vector3, span: number, rng)
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
			local r = span * rng:NextNumber(0.7, 0.95)
			local at = center + Vector3.new(math.cos(a) * r, rng:NextNumber(150, 210), math.sin(a) * r)
			local cloud = part(model, CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(rng:NextNumber(16, 26), rng:NextNumber(120, 210), rng:NextNumber(120, 210)), P().Cloud, Enum.Material.SmoothPlastic, "Cylinder")
			cloud.Name = "Cloud"
			cloud.Transparency = 0.2
			local under = glow(part(model, CFrame.new(at - UP * 9) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1, cloud.Size.Y * 0.8, cloud.Size.Z * 0.8), P().CloudUnder, nil, "Cylinder"))
			under.Transparency = 0.6
		end
	end
	local function ash(model, center: Vector3, span: number)
		local from = part(model, CFrame.new(center + UP * 70), Vector3.new(span, 1, span), P().Under)
		from.Name = "Ash"
		from.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Rate = P().Ash.Rate
		e.Lifetime = NumberRange.new(8, 12)
		e.Speed = NumberRange.new(P().Ash.Speed * 0.75, P().Ash.Speed * 1.25)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Size = NumberSequence.new(P().Ash.Size)
		e.Color = ColorSequence.new(P().Ash.From, P().Ash.To)
		e.LightEmission = 0.4
		e.Parent = from
	end
	-- A scar torn across it (the fire realms): white-hot down the middle,
	-- bleeding at its edges, strands torn off it.
	Skies.Scar = function(model, center: Vector3, span: number, rng)
		local high = center + UP * 260
		local heading = rng:NextNumber(0, math.pi)
		local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local length = span * 1.5
		local points = {}
		for i = 0, 10 do
			local t = i / 10
			local wobble = if i == 0 or i == 10 then 0 else rng:NextNumber(-1, 1) * 28
			table.insert(points, high + dir * (t - 0.5) * length + side * wobble + UP * rng:NextNumber(-12, 12))
		end
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local mid = (a + b) / 2
			local t = math.abs((i - 0.5) / (#points - 1) - 0.5) * 2
			local width = 4 + 12 * (1 - t)
			local frame = face(mid, flat(b - a))
			local rim = glow(part(model, frame, Vector3.new(width * 1.9, 3, (b - a).Magnitude + 3), P().Dark))
			rim.Name = "ScarRim"
			rim.Transparency = 0.35
			glow(part(model, frame, Vector3.new(width, 4, (b - a).Magnitude + 2), P().Scar)).Name = "Scar"
			if i % 3 == 0 then
				local strand = mid + side * (if i % 2 == 0 then 1 else -1) * rng:NextNumber(30, 60)
				glow(part(model, face((mid + strand) / 2, flat(strand - mid)), Vector3.new(2, 2, (strand - mid).Magnitude), P().Strand)).Name = "Strand"
			end
		end
		clouds(model, center, span, rng)
		ash(model, center, span)
	end
	-- An aurora (the frost realms): bands of light rippling across the sky.
	Skies.Aurora = function(model, center: Vector3, span: number, rng)
		local heading = rng:NextNumber(0, math.pi)
		local dir = Vector3.new(math.cos(heading), 0, math.sin(heading))
		local side = Vector3.new(-dir.Z, 0, dir.X)
		for band = 1, 3 do
			local off = (band - 2) * 70
			local colors = { P().Scar, P().Strand, P().Glow }
			for i = 0, 7 do
				local t = (i + 0.5) / 8 - 0.5
				local at = center + UP * (240 + math.sin(i * 1.1 + band) * 18) + dir * t * span * 1.4 + side * (off + math.sin(i * 0.8) * 14)
				local ribbon = glow(part(model, face(at, dir) * CFrame.Angles(0, 0, 0.35 + math.sin(i + band) * 0.2), Vector3.new(6, 26 + (i % 3) * 10, span * 1.4 / 8 + 3), colors[band]))
				ribbon.Name = "Scar"
				ribbon.Transparency = 0.45
			end
		end
		clouds(model, center, span, rng)
		ash(model, center, span)
	end
	-- A storm (the shock realms): bolts of lightning frozen jagged across
	-- the sky, a flash behind each.
	Skies.Storm = function(model, center: Vector3, span: number, rng)
		for bolt = 1, 4 do
			local a = bolt / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
			local at = center + Vector3.new(math.cos(a) * span * 0.35, 300, math.sin(a) * span * 0.35)
			local flash = glow(part(model, CFrame.new(at + UP * 10) * CFrame.Angles(0, 0, math.pi / 2), Vector3.new(1, 70, 70), P().Dark, nil, "Cylinder"))
			flash.Transparency = 0.6
			for seg = 1, 4 do
				local to = at + Vector3.new(rng:NextNumber(-18, 18), -22 * seg, rng:NextNumber(-18, 18))
				local mid = (at + to) / 2
				local d = to - at
				local look = d.Unit
				local right = look:Cross(if math.abs(look.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis).Unit
				local zig = glow(part(model, CFrame.fromMatrix(mid, right, right:Cross(look), -look) * CFrame.Angles(0, 0, rng:NextNumber(0, 3)), Vector3.new(2.5 - seg * 0.3, 2.5 - seg * 0.3, d.Magnitude + 2), P().Scar))
				zig.Name = "Scar"
				at = to
			end
		end
		clouds(model, center, span, rng)
		ash(model, center, span)
	end
	-- A spore moon (the poison realms): a huge sick moon low over the
	-- caves, rays of light through the spore haze under it.
	Skies.SporeMoon = function(model, center: Vector3, span: number, rng)
		local heading = rng:NextNumber(0, math.pi * 2)
		local at = center + Vector3.new(math.cos(heading) * span * 0.45, 230, math.sin(heading) * span * 0.45)
		local moon = glow(part(model, CFrame.new(at), Vector3.new(90, 90, 90), P().Scar, nil, "Ball"))
		moon.Name = "Moon"
		for i = 1, 5 do
			local crater = part(model, CFrame.new(at + Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(-30, 30), rng:NextNumber(-30, 30)).Unit * 44), Vector3.new(rng:NextNumber(8, 16), rng:NextNumber(8, 16), 6), P().Dark, Enum.Material.SmoothPlastic, "Ball")
			crater.Name = "Scar"
		end
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local ray = glow(part(model, CFrame.new(at + Vector3.new(math.cos(a) * 70, -40, math.sin(a) * 70)) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, 0.6), Vector3.new(60, 3, 6), P().Strand))
			ray.Name = "Scar"
			ray.Transparency = 0.5
		end
		clouds(model, center, span, rng)
		ash(model, center, span)
	end

	return { Walls = Walls, Corners = Corners, Floors = Floors, Gates = Gates, Lamps = Lamps, Arches = Arches, Thrones = Thrones, Skies = Skies }
end

return RiftStyles
