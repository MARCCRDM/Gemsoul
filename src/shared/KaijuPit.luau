--[[
	The Kaiju Arena, downstairs (pure, so it can be tested): a hall under the
	Shelter (Server.KaijuPitServer runs it, Server.World.KaijuPitWorld builds
	it) with rows of courts like ping-pong tables. Each court has a pad at
	either end: stand on one and you're waiting for a challenger; someone
	steps onto the other and, once they say FIGHT, your kaiju battle on that
	court (Server.KaijuBattles: formation, then the fight). Anyone else down
	there watches from the aisles and the balcony.

	The hall's frame (KaijuPit.origin): its floor's middle, under the
	Shelter's, x across, z along the courts. Everything here is in it, and
	courts come out of KaijuPit.courts in the world's.

	  Hall              its half sizes, the balcony you arrive on along its
	                    north wall and the stairs down off it
	  Court             a court's half length and width, how far its pads
	                    stand out from its middle, a pad's radius
	  Rows / Columns    where the courts' middles are (z, x): 8 courts
	  Arrive / Leave    where you arrive (the balcony, facing the courts) and
	                    the doorway behind it that takes you back upstairs
	  Stakes            what you can play for: Coins (a choice of amounts)
	                    or a Gem (the challenger matches it with one of the
	                    same rarity or better)

	  KaijuPit.origin(location) -> CFrame        the hall's frame, from the
	                                             Outpost's (Shared.Outpost.Location)
	  KaijuPit.courts(origin) -> { Court }       every court, in the world:
	                                             { Id, Center, Axis, Right,
	                                             HalfLength, HalfWidth, PadA, PadB }
	  KaijuPit.field(court) -> { Center, Axis }  a battle's field on it
	                                             (Shared.KaijuBattle)
	  KaijuPit.padSide(court, position) -> "A" | "B" | nil   on a pad?
	  KaijuPit.offset(court, position) -> (across, along)   in its frame
	  KaijuPit.inCourt(court, position, margin?) -> boolean
	  KaijuPit.clamp(court, position, inset?) -> Vector3   back inside it
	  KaijuPit.inHall(origin, position) -> boolean
	  KaijuPit.nearest(courts, position, wanted) -> court?, side?   the
	                                             nearest pad that's `wanted`
	  KaijuPit.stakeProblem(stake, have) -> string?   why that stake can't be
	                                             set (nil: it can)
	  KaijuPit.matchProblem(stake, offer, have) -> string?   why a challenger
	                                             can't match it
	  KaijuPit.matches(stake, have) -> { gem }   their gems that can, weakest first
	  KaijuPit.stakeText(stake) -> string        "250 coins each", "a Rare gem"
	  KaijuPit.pot(stakeA, stakeB) -> string     what the winner takes
]]
local KaijuPit = {}

-- The hall's floor this far under the quarry's (Shared.Outpost.Location):
-- right under the Shelter, inside the core (Shared.Frontier.Core) so the
-- frontier leaves anyone down here alone.
KaijuPit.Depth = 150

KaijuPit.Hall = {
	HalfX = 108,
	HalfZ = 80,
	Height = 36,
	Balcony = 12, -- the balcony's floor, over the hall's
	BalconyDepth = 16, -- from the north wall
	StairsHalf = 9, -- the stairs down off the balcony: half their width
	StairsRun = 20, -- and their length, on the floor
}

KaijuPit.Court = {
	HalfLength = 17, -- along its axis (z), pad to pad
	HalfWidth = 11, -- across (x)
	Pad = 23, -- each pad's middle, this far out from the court's
	PadRadius = 3.2,
	Inset = 1.2, -- a kaiju keeps this far inside the rails
}

-- The courts' middles: two rows of four (z), four columns (x).
KaijuPit.Rows = { -12, 48 }
KaijuPit.Columns = { -81, -27, 27, 81 }

-- You arrive on the balcony, at the top of the stairs, facing the courts;
-- the doorway in the wall behind you goes back up.
KaijuPit.Arrive = Vector3.new(0, 12, -70)
KaijuPit.Leave = { Center = Vector3.new(0, 12, -78.5), Half = Vector3.new(5, 5, 1.5) }

-- Seconds off your pad before your wait (or a challenge) ends.
KaijuPit.Grace = 1.5
-- What you can play for. Coins: one of these each; a Gem: one loose gem
-- (not on your gear), matched by one of the same rarity or better.
KaijuPit.CoinStakes = { 50, 100, 250, 500, 1000 }
KaijuPit.TierRank = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
local TIER_NAMES =
	{ Common = "Common", Uncommon = "Uncommon", Rare = "Rare", UltraRare = "Ultra Rare", Legendary = "Legendary" }
-- "a Rare gem", "an Uncommon gem".
local function aGem(tier: string?): string
	local name = TIER_NAMES[tier or ""] or ""
	return (if string.match(name, "^[AEIOU]") then "an " else "a ") .. name .. " gem"
end

export type Court = {
	Id: number,
	Center: Vector3,
	Axis: Vector3,
	Right: Vector3,
	HalfLength: number,
	HalfWidth: number,
	PadA: Vector3,
	PadB: Vector3,
}

function KaijuPit.origin(location: CFrame): CFrame
	return location * CFrame.new(0, -KaijuPit.Depth, 0)
end

-- Every court, numbered along the first row then the second, in the world.
function KaijuPit.courts(origin: CFrame): { Court }
	local spec = KaijuPit.Court
	local list = {}
	for _, z in KaijuPit.Rows do
		for _, x in KaijuPit.Columns do
			local center = origin * Vector3.new(x, 0, z)
			local axis = origin:VectorToWorldSpace(Vector3.new(0, 0, 1))
			local right = origin:VectorToWorldSpace(Vector3.new(1, 0, 0))
			table.insert(list, {
				Id = #list + 1,
				Center = center,
				Axis = axis,
				Right = right,
				HalfLength = spec.HalfLength,
				HalfWidth = spec.HalfWidth,
				PadA = center - axis * spec.Pad,
				PadB = center + axis * spec.Pad,
			})
		end
	end
	return list
end

-- A battle's field on the court: its middle, and its axis from pad A to B.
function KaijuPit.field(court: Court)
	return { Center = court.Center, Axis = court.Axis }
end

-- `position` in the court's frame: across (x) and along (z) from its middle.
function KaijuPit.offset(court: Court, position: Vector3): (number, number)
	local d = position - court.Center
	return d:Dot(court.Right), d:Dot(court.Axis)
end

-- Which pad `position` stands on ("A" or "B"), if either: inside its ring
-- and on the floor (not above it on a bench or up on the balcony).
function KaijuPit.padSide(court: Court, position: Vector3): string?
	local radius = KaijuPit.Court.PadRadius
	for _, side in { "A", "B" } do
		local pad = if side == "A" then court.PadA else court.PadB
		local d = position - pad
		if Vector3.new(d.X, 0, d.Z).Magnitude <= radius and d.Y > -2 and d.Y < 6 then
			return side
		end
	end
	return nil
end

function KaijuPit.inCourt(court: Court, position: Vector3, margin: number?): boolean
	local across, along = KaijuPit.offset(court, position)
	local m = margin or 0
	return math.abs(across) <= court.HalfWidth + m and math.abs(along) <= court.HalfLength + m
end

-- `position` brought back inside the court, `inset` in from its rails
-- (Court.Inset unless given), at its own height.
function KaijuPit.clamp(court: Court, position: Vector3, inset: number?): Vector3
	local keep = inset or KaijuPit.Court.Inset
	local across, along = KaijuPit.offset(court, position)
	local a = math.clamp(across, -court.HalfWidth + keep, court.HalfWidth - keep)
	local b = math.clamp(along, -court.HalfLength + keep, court.HalfLength - keep)
	local flat = court.Center + court.Right * a + court.Axis * b
	return Vector3.new(flat.X, position.Y, flat.Z)
end

-- Inside the hall (its walls, floor to roof).
function KaijuPit.inHall(origin: CFrame, position: Vector3): boolean
	local p = origin:PointToObjectSpace(position)
	local hall = KaijuPit.Hall
	return math.abs(p.X) <= hall.HalfX and math.abs(p.Z) <= hall.HalfZ and p.Y > -8 and p.Y < hall.Height + 4
end

-- The nearest pad to `position` that `wanted(court, side)` likes.
function KaijuPit.nearest(courts: { Court }, position: Vector3, wanted: (Court, string) -> boolean): (Court?, string?)
	local best, bestSide, bestDistance = nil, nil, math.huge
	for _, court in courts do
		for _, side in { "A", "B" } do
			if wanted(court, side) then
				local pad = if side == "A" then court.PadA else court.PadB
				local d = (pad - position).Magnitude
				if d < bestDistance then
					best, bestSide, bestDistance = court, side, d
				end
			end
		end
	end
	return best, bestSide
end

-- Stakes ----------------------------------------------------------------------------------------------
-- A stake: nil (just for the glory), { Kind = "Coins", Coins = n } or
-- { Kind = "Gem", Tier, Gem = { Id, ... } }. `have`: { Coins = n, Gems =
-- { [id]: gem } } (their loose gems).

function KaijuPit.stakeProblem(stake, have): string?
	if stake == nil then
		return nil
	end
	if type(stake) ~= "table" then
		return "That isn't a stake."
	end
	if stake.Kind == "Coins" then
		if not table.find(KaijuPit.CoinStakes, stake.Coins) then
			return "That isn't a stake."
		end
		if (have.Coins or 0) < stake.Coins then
			return "You don't have that many coins."
		end
		return nil
	elseif stake.Kind == "Gem" then
		local id = stake.Gem and stake.Gem.Id
		local gem = id and (have.Gems or {})[id]
		if not gem then
			return "That gem isn't loose in your pouch."
		end
		return nil
	end
	return "That isn't a stake."
end

-- Can a challenger match `stake` with `offer` (a gem id, for a gem stake)?
function KaijuPit.matchProblem(stake, offer, have): string?
	if stake == nil then
		return nil
	end
	if stake.Kind == "Coins" then
		if (have.Coins or 0) < stake.Coins then
			return string.format("You need %d coins to match the stake.", stake.Coins)
		end
		return nil
	end
	local gem = type(offer) == "string" and (have.Gems or {})[offer] or nil
	local need = KaijuPit.TierRank[stake.Tier] or 1
	if not gem then
		-- (Any loose gem good enough?)
		for _, g in have.Gems or {} do
			if (KaijuPit.TierRank[g.Tier] or 0) >= need then
				return "Pick one of your gems to match the stake."
			end
		end
		return string.format("You need %s or better to match the stake.", aGem(stake.Tier))
	end
	if (KaijuPit.TierRank[gem.Tier] or 0) < need then
		return string.format("Match it with %s or better.", aGem(stake.Tier))
	end
	return nil
end

-- Which of `have`'s gems can match `stake`, weakest first.
function KaijuPit.matches(stake, have): { any }
	local list = {}
	if not stake or stake.Kind ~= "Gem" then
		return list
	end
	local need = KaijuPit.TierRank[stake.Tier] or 1
	for _, gem in have.Gems or {} do
		if (KaijuPit.TierRank[gem.Tier] or 0) >= need then
			table.insert(list, gem)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = KaijuPit.TierRank[a.Tier] or 0, KaijuPit.TierRank[b.Tier] or 0
		if ra ~= rb then
			return ra < rb
		end
		return tostring(a.Id) < tostring(b.Id)
	end)
	return list
end

function KaijuPit.stakeText(stake): string
	if stake == nil then
		return "No stake"
	elseif stake.Kind == "Coins" then
		return string.format("%d coins each", stake.Coins)
	end
	return aGem(stake.Tier) .. " each"
end

-- What the winner takes, both stakes in.
function KaijuPit.pot(stakeA, stakeB): string
	if stakeA == nil and stakeB == nil then
		return "Just the glory"
	elseif stakeA and stakeA.Kind == "Coins" then
		return string.format("%d coins", stakeA.Coins + (if stakeB and stakeB.Coins then stakeB.Coins else 0))
	end
	return "Both gems"
end

return KaijuPit
