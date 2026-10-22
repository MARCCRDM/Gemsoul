--[[
	Each boss's realm: the side of the Rift its trip is built in (Server.
	World.RiftWorld builds the caves in its colours and stands its set
	pieces in them; Client.RiftClient lights the air its way). All of them
	are hellish, each in its boss's element, and no two the same.

	  RiftRealms.of(bossId) -> realm   (Default, Drago's crater flats, for
	                                    a boss with none)
	  RiftRealms.Order                 the ten, in the bounty board's order
	  RiftRealms.Default

	A realm:
	  Id, Boss, Name, Element
	  Feature       its set pieces (RiftWorld.Features: Craters, Logs,
	                Floes, Tide, Freezer, Vines, Spires, Blades, Bog, Grove)
	  Stalagmites   rock spikes by the walls too (the fire realms)
	  Rock, Basalt, Obsidian, Under   the rock, the floor, the dark rock,
	                the underside
	  FloorMaterial the floor's material (Basalt; Ice for the frost realms)
	  Glow          what glows in the cracks, the seams and the walls across
	                the passages; Accent the braziers' coals and the fallen's
	                gems; Dark the deep colour (the throne's eyes, the scar's
	                rim); Tongue the third colour of a gate's flames
	  Flame, FlameEdge   the braziers' and gates' fire
	  Scar, Strand, Cloud, CloudUnder   the sky
	  Ash           what falls from it: { From, To, Rate, Speed, Size }
	  Lighting      the air (RiftClient.hellLighting): Clock, Ambient,
	                Outdoor, Brightness, Exposure, HazeColor, HazeDecay,
	                Tint, Saturation
]]
local RiftRealms = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function merge(base, over)
	local out = table.clone(base)
	for key, value in over do
		out[key] = value
	end
	return out
end

-- The elements' bases: every realm of one element starts from its.
local FIRE = {
	Element = "Fire",
	Stalagmites = true,
	Rock = rgb(96, 68, 58),
	Basalt = rgb(70, 54, 50),
	Obsidian = rgb(24, 19, 24),
	Under = rgb(30, 24, 25),
	FloorMaterial = "Basalt",
	Glow = rgb(255, 78, 20),
	Accent = rgb(255, 142, 46),
	Dark = rgb(150, 26, 20),
	Tongue = rgb(255, 200, 96),
	Flame = rgb(255, 142, 46),
	FlameEdge = rgb(150, 26, 20),
	Scar = rgb(255, 220, 236),
	Strand = rgb(255, 120, 150),
	Cloud = rgb(46, 16, 18),
	CloudUnder = rgb(160, 40, 24),
	Ash = { From = rgb(110, 96, 92), To = rgb(255, 142, 46), Rate = 70, Speed = 5.5, Size = 0.35 },
	Lighting = {
		Clock = 17.8,
		Ambient = rgb(96, 42, 40),
		Outdoor = rgb(140, 64, 52),
		Brightness = 1.6,
		Exposure = 0.1,
		HazeColor = rgb(215, 84, 52),
		HazeDecay = rgb(92, 24, 64),
		Tint = rgb(255, 222, 205),
		Saturation = 0.12,
	},
}
local FROST = {
	Element = "Frost",
	Stalagmites = false,
	Rock = rgb(84, 104, 130),
	Basalt = rgb(58, 72, 96),
	Obsidian = rgb(22, 28, 44),
	Under = rgb(20, 26, 40),
	FloorMaterial = "Ice",
	Glow = rgb(150, 222, 255),
	Accent = rgb(120, 190, 255),
	Dark = rgb(36, 70, 150),
	Tongue = rgb(220, 244, 255),
	Flame = rgb(140, 200, 255),
	FlameEdge = rgb(40, 80, 180),
	Scar = rgb(226, 246, 255),
	Strand = rgb(140, 210, 255),
	Cloud = rgb(16, 24, 44),
	CloudUnder = rgb(40, 96, 170),
	Ash = { From = rgb(236, 244, 255), To = rgb(200, 230, 255), Rate = 140, Speed = 2.5, Size = 0.3 },
	Lighting = {
		Clock = 18.4,
		Ambient = rgb(50, 68, 110),
		Outdoor = rgb(70, 100, 152),
		Brightness = 1.5,
		Exposure = 0.05,
		HazeColor = rgb(120, 170, 232),
		HazeDecay = rgb(26, 40, 96),
		Tint = rgb(206, 226, 255),
		Saturation = 0.04,
	},
}
local SHOCK = {
	Element = "Shock",
	Stalagmites = false,
	Rock = rgb(74, 66, 44),
	Basalt = rgb(52, 48, 36),
	Obsidian = rgb(22, 20, 14),
	Under = rgb(22, 20, 12),
	FloorMaterial = "Basalt",
	Glow = rgb(255, 224, 70),
	Accent = rgb(255, 212, 40),
	Dark = rgb(120, 90, 10),
	Tongue = rgb(255, 250, 200),
	Flame = rgb(255, 220, 80),
	FlameEdge = rgb(150, 110, 10),
	Scar = rgb(255, 252, 230),
	Strand = rgb(255, 232, 120),
	Cloud = rgb(30, 28, 16),
	CloudUnder = rgb(130, 108, 20),
	Ash = { From = rgb(255, 236, 140), To = rgb(255, 212, 40), Rate = 50, Speed = 9, Size = 0.22 },
	Lighting = {
		Clock = 18,
		Ambient = rgb(82, 76, 40),
		Outdoor = rgb(124, 112, 52),
		Brightness = 1.6,
		Exposure = 0.08,
		HazeColor = rgb(212, 190, 84),
		HazeDecay = rgb(70, 56, 20),
		Tint = rgb(255, 246, 210),
		Saturation = 0.1,
	},
}
local POISON = {
	Element = "Poison",
	Stalagmites = false,
	Rock = rgb(56, 74, 48),
	Basalt = rgb(38, 52, 36),
	Obsidian = rgb(16, 24, 16),
	Under = rgb(14, 22, 14),
	FloorMaterial = "Slate",
	Glow = rgb(96, 240, 110),
	Accent = rgb(70, 205, 90),
	Dark = rgb(22, 96, 44),
	Tongue = rgb(200, 255, 170),
	Flame = rgb(90, 220, 110),
	FlameEdge = rgb(20, 90, 40),
	Scar = rgb(232, 255, 232),
	Strand = rgb(150, 255, 160),
	Cloud = rgb(14, 28, 16),
	CloudUnder = rgb(40, 124, 52),
	Ash = { From = rgb(160, 240, 140), To = rgb(70, 205, 90), Rate = 60, Speed = 1.8, Size = 0.4 },
	Lighting = {
		Clock = 18.2,
		Ambient = rgb(42, 72, 42),
		Outdoor = rgb(62, 112, 62),
		Brightness = 1.5,
		Exposure = 0.06,
		HazeColor = rgb(96, 176, 96),
		HazeDecay = rgb(20, 64, 30),
		Tint = rgb(218, 255, 218),
		Saturation = 0.08,
	},
}

RiftRealms.Realms = {
	-- Fire
	Drago = merge(FIRE, {
		Id = "Drago",
		Boss = "Drago",
		Name = "The Crater Flats",
		Feature = "Craters",
	}),
	SahurTrio = merge(FIRE, {
		Id = "SahurTrio",
		Boss = "SahurTrio",
		Name = "The Burning Grove",
		Feature = "Logs",
		Rock = rgb(88, 58, 46),
		Basalt = rgb(58, 42, 38),
		Glow = rgb(255, 96, 24),
		Cloud = rgb(40, 12, 12),
		Lighting = merge(FIRE.Lighting, {
			Ambient = rgb(92, 36, 30),
			Outdoor = rgb(150, 58, 40),
			HazeColor = rgb(205, 66, 36),
			HazeDecay = rgb(80, 18, 40),
		}),
	}),
	-- Frost
	Paperotti = merge(FROST, {
		Id = "Paperotti",
		Boss = "Paperotti",
		Name = "The Frozen Pond",
		Feature = "Floes",
	}),
	TralaleroTwin = merge(FROST, {
		Id = "TralaleroTwin",
		Boss = "TralaleroTwin",
		Name = "The Frozen Tide",
		Feature = "Tide",
		Rock = rgb(66, 98, 112),
		Basalt = rgb(46, 70, 84),
		Obsidian = rgb(18, 30, 40),
		Glow = rgb(120, 236, 236),
		Accent = rgb(90, 210, 220),
		Dark = rgb(20, 90, 110),
		Scar = rgb(220, 255, 255),
		Strand = rgb(120, 230, 240),
		CloudUnder = rgb(30, 110, 130),
		Lighting = merge(FROST.Lighting, {
			Ambient = rgb(44, 76, 90),
			Outdoor = rgb(60, 110, 128),
			HazeColor = rgb(100, 180, 200),
			HazeDecay = rgb(16, 50, 70),
			Tint = rgb(206, 240, 246),
		}),
	}),
	Frigo = merge(FROST, {
		Id = "Frigo",
		Boss = "Frigo",
		Name = "The Freezer",
		Feature = "Freezer",
		Rock = rgb(120, 138, 162),
		Basalt = rgb(86, 100, 124),
		Obsidian = rgb(40, 48, 66),
		Glow = rgb(210, 244, 255),
		Accent = rgb(170, 220, 255),
		Scar = rgb(240, 250, 255),
		Cloud = rgb(26, 32, 50),
		Ash = merge(FROST.Ash, { Rate = 220, Speed = 3.5, Size = 0.25 }),
		Lighting = merge(FROST.Lighting, {
			Ambient = rgb(72, 88, 124),
			Outdoor = rgb(96, 120, 170),
			Brightness = 1.7,
			HazeColor = rgb(160, 196, 240),
			HazeDecay = rgb(40, 56, 110),
			Tint = rgb(222, 236, 255),
		}),
	}),
	-- Shock
	Chimpanzini = merge(SHOCK, {
		Id = "Chimpanzini",
		Boss = "Chimpanzini",
		Name = "The Charged Jungle",
		Feature = "Vines",
		Rock = rgb(62, 72, 40),
		Basalt = rgb(44, 52, 32),
		Obsidian = rgb(20, 24, 12),
		Lighting = merge(SHOCK.Lighting, {
			Ambient = rgb(72, 80, 36),
			Outdoor = rgb(110, 120, 48),
			HazeColor = rgb(196, 200, 80),
			HazeDecay = rgb(50, 60, 18),
		}),
	}),
	Gattini = merge(SHOCK, {
		Id = "Gattini",
		Boss = "Gattini",
		Name = "The Static Spires",
		Feature = "Spires",
		Glow = rgb(255, 242, 150),
		Accent = rgb(250, 226, 96),
		Tongue = rgb(255, 255, 230),
		Rock = rgb(66, 56, 84),
		Basalt = rgb(44, 38, 60),
		Obsidian = rgb(24, 20, 36),
		Under = rgb(20, 16, 30),
		Cloud = rgb(28, 22, 42),
		CloudUnder = rgb(120, 100, 40),
		Lighting = merge(SHOCK.Lighting, {
			Ambient = rgb(74, 62, 90),
			Outdoor = rgb(112, 96, 128),
			HazeColor = rgb(200, 180, 140),
			HazeDecay = rgb(52, 36, 80),
			Tint = rgb(250, 240, 255),
		}),
	}),
	Cappuccino = merge(SHOCK, {
		Id = "Cappuccino",
		Boss = "Cappuccino",
		Name = "The Blade Roost",
		Feature = "Blades",
		Rock = rgb(60, 44, 36),
		Basalt = rgb(40, 30, 26),
		Obsidian = rgb(18, 14, 12),
		Under = rgb(16, 12, 10),
		Glow = rgb(255, 204, 70),
		Accent = rgb(240, 190, 70),
		Cloud = rgb(24, 18, 14),
		CloudUnder = rgb(120, 86, 24),
		Ash = merge(SHOCK.Ash, { Rate = 30 }),
		Lighting = merge(SHOCK.Lighting, {
			Ambient = rgb(70, 54, 36),
			Outdoor = rgb(104, 80, 48),
			Brightness = 1.4,
			HazeColor = rgb(180, 140, 70),
			HazeDecay = rgb(46, 30, 14),
			Tint = rgb(255, 238, 206),
		}),
	}),
	-- Poison
	Ranocchio = merge(POISON, {
		Id = "Ranocchio",
		Boss = "Ranocchio",
		Name = "The Bog",
		Feature = "Bog",
	}),
	PatapimTrio = merge(POISON, {
		Id = "PatapimTrio",
		Boss = "PatapimTrio",
		Name = "The Rotting Grove",
		Feature = "Grove",
		Rock = rgb(64, 60, 40),
		Basalt = rgb(44, 42, 30),
		Obsidian = rgb(20, 18, 12),
		Glow = rgb(150, 236, 90),
		Accent = rgb(120, 210, 80),
		Cloud = rgb(18, 24, 12),
		Ash = merge(POISON.Ash, { Rate = 90, Speed = 1.4 }),
		Lighting = merge(POISON.Lighting, {
			Ambient = rgb(52, 70, 36),
			Outdoor = rgb(74, 104, 50),
			HazeColor = rgb(120, 170, 80),
			HazeDecay = rgb(30, 60, 20),
			Tint = rgb(228, 250, 210),
		}),
	}),
}

RiftRealms.Order = {
	"Drago",
	"SahurTrio",
	"Paperotti",
	"TralaleroTwin",
	"Frigo",
	"Chimpanzini",
	"Gattini",
	"Cappuccino",
	"Ranocchio",
	"PatapimTrio",
}

RiftRealms.Default = RiftRealms.Realms.Drago

function RiftRealms.of(bossId: any)
	return RiftRealms.Realms[bossId or ""] or RiftRealms.Default
end

return RiftRealms
