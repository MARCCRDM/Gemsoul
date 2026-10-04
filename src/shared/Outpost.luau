--[[
	Saga Outpost: the shared mining basin on the moon. Everyone in the
	server mines the same rocks, sees each other, trades at the Probe and
	challenges each other to duels. The rules, shared by the server (which
	decides everything) and the client (which shows it).

	Rocks come in four sizes. Bigger ones take more hits, hide better finds
	and take longer to grow back once mined out (like ore nodes in an MMO).
	Swinging wears your pick: every swing costs one point of durability, and
	a pick at zero breaks. A free Survey Pick is issued every day; better
	picks are bought at the Probe with coins.

	  Outpost.Sizes / Outpost.SizeOrder      the rocks
	  Outpost.Picks / Outpost.PickOrder      the picks
	  Outpost.rollSize(roll)                 a new rock's size, 0 <= roll < 1
	  Outpost.damage(pick, crit)             how many layers a swing chips
	  Outpost.tension(hp, maxHp)             0 (fresh) .. 1 (about to pop): how
	                                         loud and high the hit sound rings
	  Outpost.claimHolder(node, userId, now) may this player hit this rock?
	                                         (its first hitter keeps it a while)
	  Outpost.freePickDue(lastDay, today)    is today's free pick still to come?
]]
local Outpost = {}

-- Where the basin is in the world (its centre, on the ground).
Outpost.Location = CFrame.new(0, 0, 7000)
Outpost.Radius = 150 -- the walkable floor
Outpost.NodeCount = 46 -- rocks out at once
Outpost.ClaimSeconds = 8 -- a rock stays with its first hitter this long after each swing
Outpost.Reach = 11 -- studs from the rock you can swing from
Outpost.SwingCooldown = 0.32
Outpost.CritChance = 0.15

-- Rocks, smallest to rarest. `Depth` is how deep a wall of the old mine
-- this matches, for gem luck and gear finds.
Outpost.Sizes = {
	Pebble = {
		Name = "Regolith Chunk",
		Hp = 4,
		Respawn = 40,
		Weight = 44,
		Scale = 3.6,
		Depth = 2,
		Gem = 0.45,
		Coins = { 6, 14 },
		Gear = 0.04,
	},
	Boulder = {
		Name = "Crystal Boulder",
		Hp = 7,
		Respawn = 75,
		Weight = 34,
		Scale = 6,
		Depth = 5,
		Gem = 0.7,
		Coins = { 12, 26 },
		Gear = 0.1,
	},
	Monolith = {
		Name = "Saga Monolith",
		Hp = 11,
		Respawn = 120,
		Weight = 17,
		Scale = 8.5,
		Depth = 9,
		Gem = 0.9,
		Coins = { 24, 48 },
		Gear = 0.2,
	},
	Geode = {
		Name = "Star Geode",
		Hp = 16,
		Respawn = 240,
		Weight = 5,
		Scale = 7,
		Depth = 14,
		Gem = 1,
		Coins = { 60, 120 },
		Gear = 0.4,
		Luck = 0.35, -- on top of its depth
	},
}
Outpost.SizeOrder = { "Pebble", "Boulder", "Monolith", "Geode" }

-- Picks: swings before they break, layers per swing, extra crit chance.
Outpost.Picks = {
	Survey = {
		Name = "Survey Pick",
		Swings = 60,
		Power = 1,
		Crit = 0,
		Price = 0,
		Color = Color3.fromRGB(176, 150, 120),
	},
	Titan = {
		Name = "Titan Pick",
		Swings = 160,
		Power = 1,
		Crit = 0.08,
		Price = 180,
		Color = Color3.fromRGB(150, 196, 225),
	},
	Plasma = {
		Name = "Plasma Drill",
		Swings = 360,
		Power = 2,
		Crit = 0.12,
		Price = 450,
		Color = Color3.fromRGB(255, 120, 230),
	},
}
Outpost.PickOrder = { "Survey", "Titan", "Plasma" }

function Outpost.rollSize(roll: number): string
	local total = 0
	for _, id in Outpost.SizeOrder do
		total += Outpost.Sizes[id].Weight
	end
	local pick = roll * total
	for _, id in Outpost.SizeOrder do
		pick -= Outpost.Sizes[id].Weight
		if pick < 0 then
			return id
		end
	end
	return Outpost.SizeOrder[1]
end

function Outpost.damage(pickId: string, crit: boolean): number
	local pick = Outpost.Picks[pickId] or Outpost.Picks.Survey
	return pick.Power * (if crit then 2 else 1)
end

function Outpost.tension(hp: number, maxHp: number): number
	if maxHp <= 0 then
		return 1
	end
	return math.clamp(1 - hp / maxHp, 0, 1)
end

-- `node`: { ClaimedBy: number?, ClaimUntil: number? }. True when this player
-- may swing at it now.
function Outpost.claimHolder(node, userId: number, now: number): boolean
	return node.ClaimedBy == nil or node.ClaimedBy == userId or now >= (node.ClaimUntil or 0)
end

function Outpost.freePickDue(lastDay: number?, today: number): boolean
	return lastDay == nil or lastDay < today
end

return Outpost
