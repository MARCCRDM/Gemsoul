--[[
	Kaiju battles (pure, so it can be tested): two players near each other in
	the Outpost set their teams of kaiju against each other, and the kaiju
	fight it out by themselves. The server's KaijuBattles runs one; the
	client's KaijuBattleUI shows it.

	  Ask        one asks (KAIJU on the other's player card), the other
	             accepts within AskSeconds.
	  Formation  FormationSeconds to place your kaiju: each on one of your
	             side's six cells, three across the front row and three
	             across the back (defaultFormation puts the sturdy ones in
	             front, FrontKinds, and the rest behind: a Razorback shoots
	             from there, a Scythe leaps from there). You can't see
	             where your foe puts theirs till it starts. READY from both
	             starts it early.
	  Battle     the kaiju fight by themselves (auto battle), each by its
	             role (Shared.KaijuRoles, Server.KaijuBattleBrain), for up
	             to BattleSeconds.
	  Over       the side with kaiju still up wins; out of time, the side
	             with more of its health left (winner). Every kaiju in it
	             gains EXP (Exp: more for the winners').

	A battle is fought at full health and leaves every kaiju as it was:
	each side's whole team comes to it full (the knocked out too), and once
	it's over each goes back to the health it had before, win or lose
	(Server.KaijuServer.battleStart / battleEnd). Your kaiju need to be out
	(not put away): at least one each.

	The two sides are told apart by colour everywhere (Sides): A is BLUE
	(the court's blue half and pad), B is RED.

	Off a court, the field lies between the two players: its middle halfway
	between them, its axis from the asker's side (A) to the other's (B).
	Its studs are a pet kaiju's (they're knee high).

	  KaijuBattle.cells(): { Cell }             the six cells of a side
	  KaijuBattle.cellSpot(field, side, cellId) -> Vector3   where a cell is
	  KaijuBattle.facing(field, side) -> Vector3   the way a side faces
	  KaijuBattle.defaultFormation(records) -> { [kaijuId]: cellId }
	  KaijuBattle.formation(wanted, records) -> formation?, problem?
	  KaijuBattle.field(posA, posB) -> field     the field between them
	  KaijuBattle.winner(a, b, timedOut) -> "A" | "B" | "Draw"
	  KaijuBattle.askProblem(state) -> string?   why one can't ask (nil: can)
	  KaijuBattle.Sides[side] -> { Name, Color }  BLUE (A) or RED (B)
]]
local KaijuRoles = require(script.Parent.KaijuRoles)

local KaijuBattle = {}

KaijuBattle.Sides = {
	A = { Name = "BLUE", Color = Color3.fromRGB(70, 160, 255) },
	B = { Name = "RED", Color = Color3.fromRGB(255, 84, 72) },
}

KaijuBattle.AskSeconds = 20 -- an ask stands this long
KaijuBattle.AskGap = 1.5 -- seconds between your asks
KaijuBattle.AskAgain = 20 -- after a no, before you can ask them again
KaijuBattle.Range = 40 -- studs: how near you must be to ask
KaijuBattle.FormationSeconds = 25
KaijuBattle.BattleSeconds = 90
KaijuBattle.OverSeconds = 12 -- the result stays up this long (time to ask for a rematch)
KaijuBattle.Leash = 70 -- studs from the field's middle: walk off further and you forfeit
KaijuBattle.Exp = { Win = 40, Lose = 14, Draw = 24 }

-- The field (studs): each row's distance from the middle line (Front,
-- Back), and the places' spacing across.
KaijuBattle.Field = { Front = 4.5, Back = 9.5, Across = 5.5 }

export type Cell = { Id: string, Row: string, Column: number }

local CELLS: { Cell } = {
	{ Id = "FrontLeft", Row = "Front", Column = -1 },
	{ Id = "FrontCentre", Row = "Front", Column = 0 },
	{ Id = "FrontRight", Row = "Front", Column = 1 },
	{ Id = "BackLeft", Row = "Back", Column = -1 },
	{ Id = "BackCentre", Row = "Back", Column = 0 },
	{ Id = "BackRight", Row = "Back", Column = 1 },
}
local BY_ID: { [string]: Cell } = {}
for _, cell in CELLS do
	BY_ID[cell.Id] = cell
end

function KaijuBattle.cells(): { Cell }
	return CELLS
end

function KaijuBattle.cell(id: any): Cell?
	return if type(id) == "string" then BY_ID[id] else nil
end

-- Kinds that go in front by default (they take hits: a tank, a warrior,
-- a breaker; Shared.KaijuRoles' Front); the rest behind.
KaijuBattle.FrontKinds = {}
for species, role in KaijuRoles.Species do
	if KaijuRoles.Roles[role].Front then
		KaijuBattle.FrontKinds[species] = true
	end
end

export type Field = { Center: Vector3, Axis: Vector3 }

-- The field between the asker (A, at `posA`) and the other (B): its
-- middle halfway, its axis from A to B, flat.
function KaijuBattle.field(posA: Vector3, posB: Vector3): Field
	local mid = (posA + posB) / 2
	local axis = Vector3.new(posB.X - posA.X, 0, posB.Z - posA.Z)
	axis = if axis.Magnitude > 0.05 then axis.Unit else Vector3.new(0, 0, -1)
	return { Center = Vector3.new(mid.X, math.min(posA.Y, posB.Y), mid.Z), Axis = axis }
end

-- The way `side` faces (toward the other).
function KaijuBattle.facing(field: Field, side: string): Vector3
	return if side == "A" then field.Axis else -field.Axis
end

-- Where `cellId` of `side` is: its row back from the middle line, its
-- column across, left and right as that side sees them facing its foe.
function KaijuBattle.cellSpot(field: Field, side: string, cellId: string): Vector3
	local cell = BY_ID[cellId] or BY_ID.FrontCentre
	local facing = KaijuBattle.facing(field, side)
	local right = facing:Cross(Vector3.new(0, 1, 0))
	local spec = KaijuBattle.Field
	local back = if cell.Row == "Front" then spec.Front else spec.Back
	return field.Center - facing * back + right * cell.Column * spec.Across
end

local FRONT_ORDER = { "FrontCentre", "FrontLeft", "FrontRight" }
local BACK_ORDER = { "BackCentre", "BackLeft", "BackRight" }

-- Where your kaiju start: the sturdy kinds in front (FrontKinds), the
-- rest (a Razorback, a Scythe) behind; a row full, the other.
function KaijuBattle.defaultFormation(records: { any }): { [string]: string }
	local formation, used = {}, {}
	local function take(order: { string }, fallback: { string }): string?
		for _, id in order do
			if not used[id] then
				used[id] = true
				return id
			end
		end
		for _, id in fallback do
			if not used[id] then
				used[id] = true
				return id
			end
		end
		return nil
	end
	for _, record in records do
		local front = KaijuBattle.FrontKinds[record.Species] == true
		local cellId = if front then take(FRONT_ORDER, BACK_ORDER) else take(BACK_ORDER, FRONT_ORDER)
		if cellId then
			formation[record.Id] = cellId
		end
	end
	return formation
end

-- A formation you asked for (`wanted`: { [kaijuId]: cellId }), checked
-- against your kaiju in the battle (`records`): every one of them placed,
-- each on a cell of its own. Returns it, or nil and what's wrong.
function KaijuBattle.formation(wanted: any, records: { any }): ({ [string]: string }?, string?)
	if type(wanted) ~= "table" then
		return nil, "That isn't a formation."
	end
	local mine, taken, formation = {}, {}, {}
	for _, record in records do
		mine[record.Id] = true
	end
	local count = 0
	for id, cellId in wanted do
		if not mine[id] then
			return nil, "That kaiju isn't in this battle."
		end
		if not BY_ID[cellId] then
			return nil, "That isn't a place on the field."
		end
		if taken[cellId] then
			return nil, "Two kaiju can't share a place."
		end
		taken[cellId] = true
		formation[id] = cellId
		count += 1
	end
	if count ~= #records then
		return nil, "Place every kaiju."
	end
	return formation, nil
end

-- Who won: each side's { Up = kaiju still up, Share = the health they have
-- left over all they brought (0 to 1) }. One side down: the other. Out of
-- time (or both down at once): the more health left, by a clear margin.
function KaijuBattle.winner(a, b, timedOut: boolean?): string
	if a.Up > 0 and b.Up <= 0 then
		return "A"
	elseif b.Up > 0 and a.Up <= 0 then
		return "B"
	end
	if not timedOut and a.Up > 0 and b.Up > 0 then
		return "Draw" -- (not over: callers only ask once it is)
	end
	if math.abs(a.Share - b.Share) < 0.02 then
		return "Draw"
	end
	return if a.Share > b.Share then "A" else "B"
end

-- Why you can't ask someone (nil: you can). state = { Here (they're in
-- the Outpost), Name, Distance, Mine / Theirs (how many could battle: the
-- team, down ones too, Server.KaijuServer.battleable),
-- MyBattle / TheirBattle (in one), Busy / TheirBusy (a fight, a spar),
-- Asked (already asked them), Wait (seconds before you can again) }.
function KaijuBattle.askProblem(state): string?
	if not state.Here then
		return "They aren't here."
	end
	if state.MyBattle then
		return "You're in a kaiju battle already."
	elseif state.TheirBattle then
		return state.Name .. " is in a kaiju battle."
	elseif state.Busy then
		return "Finish what you're doing first."
	elseif state.TheirBusy then
		return state.Name .. " is busy."
	elseif (state.Mine or 0) <= 0 then
		return "You need your kaiju out to battle."
	elseif (state.Theirs or 0) <= 0 then
		return state.Name .. " has no kaiju out to battle."
	elseif (state.Distance or math.huge) > KaijuBattle.Range then
		return "Get closer to " .. state.Name .. "."
	elseif state.Asked then
		return "You've asked " .. state.Name .. " already."
	elseif state.Wait and state.Wait > 0 then
		return string.format("Wait %d seconds before asking them again.", math.ceil(state.Wait))
	end
	return nil
end

return KaijuBattle
