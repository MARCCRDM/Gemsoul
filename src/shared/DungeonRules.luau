-- Deterministic dungeon layout and encounter rules. No Roblox services.
local ElementMatchup = require(script.Parent.ElementMatchup)

local Dungeon = {}
Dungeon.Min = 3
Dungeon.Max = 4
Dungeon.RoomCount = 5
Dungeon.TimeLimit = 900
Dungeon.RoomSize = 64
Dungeon.Spacing = 90
Dungeon.Roster = {
	{
		Id = "Sahur",
		Name = "Tung Tung Tung Sahur",
		Element = "Fire",
		Weakness = "Frost",
		Shape = "Wood",
		Moves = { "HydraulicSlam", "BreachHammer", "TremorSlam" },
	},
	{
		Id = "Tralalero",
		Name = "Tralalero Tralala",
		Element = "Frost",
		Weakness = "Shock",
		Shape = "Shark",
		Moves = { "ServoFlurry", "StimDodge", "KineticRam" },
	},
	{
		Id = "Patapim",
		Name = "Brr Brr Patapim",
		Element = "Poison",
		Weakness = "Fire",
		Shape = "Tree",
		Moves = { "TremorSlam", "SeismicBreaker", "HydraulicSlam" },
	},
	{
		Id = "Crocodilo",
		Name = "Bombardiro Crocodilo",
		Element = "Shock",
		Weakness = "Poison",
		Shape = "Crocodile",
		Moves = { "ArmorPiercer", "KineticRam", "ServoFlurry" },
	},
}
local directions = { { 0, 1 }, { 1, 0 }, { -1, 0 }, { 0, -1 } }
function Dungeon.generate(rng)
	local rooms = { { X = 0, Z = 0 } }
	local used = { ["0:0"] = true }
	for i = 2, Dungeon.RoomCount do
		local previous = rooms[i - 1]
		local candidates = {}
		for _, d in directions do
			local x, z = previous.X + d[1], previous.Z + d[2]
			local clear = not used[x .. ":" .. z]
			for _, adjacent in directions do
				local ax, az = x + adjacent[1], z + adjacent[2]
				if used[ax .. ":" .. az] and (ax ~= previous.X or az ~= previous.Z) then
					clear = false
				end
			end
			if clear then
				table.insert(candidates, { X = x, Z = z })
			end
		end
		-- At this small length there is always an open end; keep failure explicit.
		assert(#candidates > 0, "Dungeon path has no free continuation")
		local room = candidates[rng:NextInteger(1, #candidates)]
		used[room.X .. ":" .. room.Z] = true
		table.insert(rooms, room)
	end
	local boss = rng:NextInteger(1, #Dungeon.Roster)
	for i, room in rooms do
		room.Index = i
		room.Boss = i == Dungeon.RoomCount
		room.GearTier = if room.Boss then rng:NextInteger(4, 5) else math.min(3, math.ceil(i / 1.5))
		room.Theme = if room.Boss then boss else rng:NextInteger(1, #Dungeon.Roster)
		room.Foes = {}
		for n = 1, if room.Boss then 1 else rng:NextInteger(2, 3) do
			table.insert(room.Foes, room.Theme)
		end
		room.Pillars = rng:NextInteger(2, 4)
	end
	return rooms
end
function Dungeon.canEnter(count, leader, allReady)
	if not leader then
		return false, "Only the party leader can queue."
	end
	if count < Dungeon.Min or count > Dungeon.Max then
		return false, "Dungeons need a party of 3–4 players."
	end
	if not allReady then
		return false, "Every party member must mark Ready first."
	end
	return true
end
-- A creature's element resists itself and its weakness hurts it, by the
-- same numbers as everyone's armor (ElementMatchup). Returns the multiplier
-- and "Resist" / "Weak".
function Dungeon.elementMultiplier(main, weakness, incoming)
	return ElementMatchup.versus(incoming, main, weakness)
end
-- Open expedition camps: shared bounded map, no room gates.
Dungeon.OpenRadius = 260
Dungeon.WatchRadius = 11 -- approximately ten feet in Roblox scale
Dungeon.AggroRadius = 32
Dungeon.LeashRadius = 75
function Dungeon.generateOpen(rng)
	local camps = {}
	for i = 1, 9 do
		local angle = (i - 1) / 9 * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local radius = rng:NextInteger(110, 175)
		local theme = rng:NextInteger(1, #Dungeon.Roster)
		local camp = {
			Index = i,
			X = math.cos(angle) * radius / Dungeon.Spacing,
			Z = math.sin(angle) * radius / Dungeon.Spacing,
			Theme = theme,
			Boss = false,
			Bandit = i % 3 == 0,
			GearTier = rng:NextInteger(1, 4),
			Foes = {},
			Pillars = 0,
		}
		for n = 1, rng:NextInteger(2, 3) do
			table.insert(camp.Foes, theme)
		end
		table.insert(camps, camp)
	end
	local boss = rng:NextInteger(1, #Dungeon.Roster)
	table.insert(camps, {
		Index = 10,
		X = 0,
		Z = 0,
		Theme = boss,
		Boss = true,
		GearTier = rng:NextInteger(4, 5),
		Foes = { boss },
		Pillars = 0,
	})
	return camps
end
return Dungeon
