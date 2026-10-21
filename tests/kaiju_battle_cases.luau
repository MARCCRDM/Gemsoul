-- lune run tests/kaiju_battle_cases.luau <repo>
-- Kaiju battles' rules (Shared.KaijuBattle): the field between the two,
-- each side's six places (left and right as that side sees them), the
-- default formation (the sturdy kinds in front, a Razorback behind), a
-- formation checked, who wins, and why one can't ask. And the Kaiju Arena
-- downstairs (Shared.KaijuPit): its courts in their rows, inside the hall
-- and the core, clear of each other and the stairs, every place inside
-- its court, the pads, kaiju kept in, and the stakes. And the yellow
-- arrows on the ground that lead you there (Client GroundGuide).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local Vector3 = roblox.Vector3

local loaded = {}
local env
local function shared(name)
	if loaded[name] == nil then
		local source = fs.readFile(ROOT .. "/src/shared/" .. name .. ".luau")
		loaded[name] = luau.load(source, { debugName = name, environment = env })()
	end
	return loaded[name]
end
env = setmetatable({
	Color3 = roblox.Color3,
	Vector3 = Vector3,
	CFrame = roblox.CFrame,
	script = { Parent = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}) },
	require = function(name)
		return shared(name)
	end,
}, { __index = _G })

local Battle = shared("KaijuBattle")
local Kaiju = shared("Kaiju")
local function near(a, b, within)
	return (a - b).Magnitude <= (within or 1e-4)
end

-- The rules' numbers.
check(Battle.FormationSeconds >= 8 and Battle.FormationSeconds <= 30, "A formation phase isn't a few moments")
check(Battle.BattleSeconds > Battle.FormationSeconds, "The battle's shorter than placing")
check(Battle.Exp.Win > Battle.Exp.Draw and Battle.Exp.Draw > Battle.Exp.Lose and Battle.Exp.Lose > 0, "EXP")
check(Battle.Leash > Battle.Range, "You can ask from further than you can stand")

-- The places: three across the front, three across the back, all different.
local cells = Battle.cells()
check(#cells == 6, "Not six places a side")
local rows, ids = { Front = 0, Back = 0 }, {}
for _, cell in cells do
	rows[cell.Row] += 1
	check(not ids[cell.Id], "Two places share a name")
	ids[cell.Id] = true
	check(Battle.cell(cell.Id) == cell, "A place can't be found by its name")
end
check(rows.Front == 3 and rows.Back == 3, "Not three in each row")
check(Battle.cell("Moon") == nil and Battle.cell(nil) == nil, "A place that isn't one")

-- The field between them: its middle halfway, its axis from A to B.
local posA, posB = Vector3.new(10, 5, 0), Vector3.new(10, 3, 30)
local field = Battle.field(posA, posB)
check(near(field.Center, Vector3.new(10, 3, 15)), "The field isn't halfway, on the lower ground")
check(near(field.Axis, Vector3.new(0, 0, 1)), "The field's axis isn't A to B")
check(
	near(Battle.facing(field, "A"), field.Axis) and near(Battle.facing(field, "B"), -field.Axis),
	"The sides don't face each other"
)
local same = Battle.field(posA, posA)
check(same.Axis.Magnitude > 0.99, "Two on one spot: no axis")
-- Each side's places on its own half; the front row nearer the middle; left
-- and right as that side sees them, facing its foe.
local spec = Battle.Field
for _, side in { "A", "B" } do
	local facing = Battle.facing(field, side)
	local right = facing:Cross(Vector3.new(0, 1, 0))
	for _, cell in cells do
		local at = Battle.cellSpot(field, side, cell.Id)
		local ahead = (at - field.Center):Dot(facing)
		check(ahead < 0, side .. ": " .. cell.Id .. " is on the other half")
		local depth = if cell.Row == "Front" then spec.Front else spec.Back
		check(math.abs(-ahead - depth) < 1e-4, side .. ": " .. cell.Id .. " isn't in its row")
		check(
			math.abs((at - field.Center):Dot(right) - cell.Column * spec.Across) < 1e-4,
			side .. ": " .. cell.Id .. " isn't in its column"
		)
		check(math.abs(at.Y - field.Center.Y) < 1e-4, "A place off the field's ground")
	end
	-- Every place clear of every other, wider apart than a pet kaiju.
	for i, c1 in cells do
		for j, c2 in cells do
			if i < j then
				local gap = (Battle.cellSpot(field, side, c1.Id) - Battle.cellSpot(field, side, c2.Id)).Magnitude
				check(gap >= 4, "Two places too close: " .. c1.Id .. ", " .. c2.Id)
			end
		end
	end
end
-- The two front rows apart, so the battle opens with a closing in.
local gapFronts = (Battle.cellSpot(field, "A", "FrontCentre") - Battle.cellSpot(field, "B", "FrontCentre")).Magnitude
check(math.abs(gapFronts - spec.Front * 2) < 1e-4 and gapFronts >= 6, "The front rows start on top of each other")
-- (A's left is B's right, across the field.)
local leftA, rightB = Battle.cellSpot(field, "A", "FrontLeft"), Battle.cellSpot(field, "B", "FrontRight")
check(math.abs((leftA - rightB):Dot(Vector3.new(1, 0, 0))) < 1e-4, "A's left isn't across from B's right")

-- The default formation: the sturdy kinds in front, a Razorback behind;
-- every kaiju placed, never two on one place.
local function team(...)
	local list = {}
	for i, species in { ... } do
		list[i] = { Id = "k" .. i, Species = species }
	end
	return list
end
for _, kinds in
	{
		{ "Bulwark", "Razorback", "Carapace" },
		{ "Razorback", "Razorback", "Razorback" },
		{ "Bulwark", "Bulwark", "Carapace" },
		{ "Carapace" },
		{ "Razorback", "Bulwark" },
	}
do
	local records = team(table.unpack(kinds))
	local formation = Battle.defaultFormation(records)
	local used = {}
	for _, record in records do
		local cellId = formation[record.Id]
		local cell = Battle.cell(cellId)
		check(cell ~= nil, "A kaiju left without a place: " .. table.concat(kinds, ","))
		check(not used[cellId], "Two on one place by default")
		used[cellId] = true
		check(
			(cell.Row == "Front") == (Battle.FrontKinds[record.Species] == true),
			record.Species .. " isn't in its row by default"
		)
	end
	check(Battle.formation(formation, records) ~= nil, "The default formation isn't a formation")
end
-- One alone stands in the middle of its row.
check(Battle.defaultFormation(team("Bulwark")).k1 == "FrontCentre", "One alone isn't in the middle")
check(Battle.defaultFormation(team("Razorback")).k1 == "BackCentre", "A Razorback alone isn't in the middle behind")
-- Every kind has a row it goes in.
for _, id in Kaiju.Order do
	check(Battle.FrontKinds[id] ~= nil or id == "Razorback", id .. " has no row")
end
check(not Battle.FrontKinds.Razorback, "A Razorback goes in front")

-- A formation asked for: every kaiju placed, each on a place of its own,
-- only yours, only places on the field.
local records = team("Bulwark", "Razorback", "Carapace")
check(
	Battle.formation({ k1 = "BackLeft", k2 = "FrontLeft", k3 = "BackRight" }, records) ~= nil,
	"A good formation refused"
)
for _, bad in
	{
		{ k1 = "FrontLeft", k2 = "FrontLeft", k3 = "BackLeft" },
		{ k1 = "FrontLeft", k2 = "BackLeft" },
		{ k1 = "FrontLeft", k2 = "BackLeft", k3 = "BackRight", k4 = "FrontRight" },
		{ k1 = "FrontLeft", k2 = "BackLeft", k3 = "Moon" },
		{ k1 = "FrontLeft", k2 = "BackLeft", k3 = 3 },
		"FrontLeft",
	}
do
	local formation, problem = Battle.formation(bad, records)
	check(formation == nil and type(problem) == "string" and problem ~= "", "A bad formation taken")
end

-- Who won.
check(Battle.winner({ Up = 2, Share = 0.4 }, { Up = 0, Share = 0 }) == "A", "Their side down: not a win")
check(Battle.winner({ Up = 0, Share = 0 }, { Up = 1, Share = 0.05 }) == "B", "Your side down: not a loss")
check(Battle.winner({ Up = 0, Share = 0 }, { Up = 0, Share = 0 }) == "Draw", "Both down at once: not a draw")
check(
	Battle.winner({ Up = 3, Share = 0.3 }, { Up = 1, Share = 0.6 }, true) == "B",
	"Out of time: more kaiju beat more health"
)
check(
	Battle.winner({ Up = 2, Share = 0.51 }, { Up = 2, Share = 0.5 }, true) == "Draw",
	"Out of time, as good as even: not a draw"
)
check(
	Battle.winner({ Up = 2, Share = 0.7 }, { Up = 2, Share = 0.5 }, true) == "A",
	"Out of time, more health left: not a win"
)

-- Why one can't ask.
local ok = { Here = true, Name = "Ana", Distance = 10, Mine = 3, Theirs = 2 }
check(Battle.askProblem(ok) == nil, "A fair ask refused")
local function with(changes)
	local state = table.clone(ok)
	for k, v in changes do
		state[k] = v
	end
	return Battle.askProblem(state)
end
check(with({ Here = false }) ~= nil, "Asked someone not here")
check(with({ Mine = 0 }) ~= nil, "Asked with no kaiju up")
check(with({ Theirs = 0 }) ~= nil, "Asked someone with no kaiju out")
check(with({ Distance = Battle.Range + 1 }) ~= nil, "Asked from too far")
check(with({ MyBattle = true }) ~= nil and with({ TheirBattle = true }) ~= nil, "Asked mid-battle")
check(with({ Busy = true }) ~= nil and with({ TheirBusy = true }) ~= nil, "Asked mid-fight")
check(with({ Asked = true }) ~= nil, "Asked twice")
local wait = with({ Wait = 4.2 })
check(wait ~= nil and string.find(wait, "5", 1, true) ~= nil, "A wait isn't said in whole seconds")

-- The Kaiju Arena: two rows of four courts in the hall under the Shelter.
local Pit = shared("KaijuPit")
local Frontier = shared("Frontier")
local CFrame = roblox.CFrame
local location = CFrame.new(0, 0, 7000)
local origin = Pit.origin(location)
check(math.abs(origin.Position.Y + Pit.Depth) < 1e-6, "The hall isn't under the quarry")
local courts = Pit.courts(origin)
check(#courts == #Pit.Rows * #Pit.Columns and #courts == 8, "Not eight courts")
local spec, hall = Pit.Court, Pit.Hall
for i, court in courts do
	check(court.Id == i, "The courts aren't numbered in order")
	-- In the hall, and every bit of it inside the core (no rifts, no critters).
	for _, corner in { court.PadA, court.PadB, court.Center + court.Right * (spec.HalfWidth + 10) } do
		check(Pit.inHall(origin, corner), "Court " .. i .. " reaches out of the hall")
		local off = corner - origin.Position
		check(Vector3.new(off.X, 0, off.Z).Magnitude < Frontier.Core - 8, "Court " .. i .. " is out past the core")
	end
	-- Each side's six places inside the court, its pad outside it, behind its
	-- own kaiju; the field is the court's.
	local field = Pit.field(court)
	check(near(field.Center, court.Center) and near(field.Axis, court.Axis), "The field isn't the court's")
	for _, side in { "A", "B" } do
		local pad = if side == "A" then court.PadA else court.PadB
		check(not Pit.inCourt(court, pad), "A pad inside its court")
		check(Pit.padSide(court, pad) == side, "Standing on a pad isn't on it")
		check(Pit.padSide(court, pad + Vector3.new(0, 3, 0)) == side, "Stood on a pad (up a body's height) isn't on it")
		check(Pit.padSide(court, pad + court.Right * (spec.PadRadius + 0.5)) == nil, "Beside a pad is on it")
		check(Pit.padSide(court, pad + Vector3.new(0, hall.Balcony + 3, 0)) == nil, "Over a pad counts as on it")
		for _, cell in cells do
			local at = Battle.cellSpot(field, side, cell.Id)
			check(Pit.inCourt(court, at, -spec.Inset - 1), "A place on court " .. i .. " is at its rails")
			check(
				(at - pad).Magnitude < (at - (if side == "A" then court.PadB else court.PadA)).Magnitude,
				"A side's places by the other's pad"
			)
		end
	end
	check(Pit.padSide(court, court.Center) == nil, "The middle of a court is a pad")
	-- Clear of every other court (pads and all) and of the stairs off the balcony.
	for j, other in courts do
		if j ~= i then
			local a1, b1 = Pit.offset(court, other.Center)
			check(
				math.abs(a1) >= spec.HalfWidth * 2 + 20 or math.abs(b1) >= (spec.Pad + spec.PadRadius) * 2 + 4,
				"Courts " .. i .. " and " .. j .. " overlap"
			)
		end
	end
	local foot = origin * Vector3.new(0, 0, -hall.HalfZ + hall.BalconyDepth + hall.StairsRun)
	local across, along = Pit.offset(court, foot)
	check(
		math.abs(across) > spec.HalfWidth + hall.StairsHalf or math.abs(along) > spec.Pad + spec.PadRadius + 2,
		"Court " .. i .. " is in the stairs' way"
	)
end
-- You arrive on the balcony, clear of the way back up.
local arrive = origin * Pit.Arrive
check(Pit.inHall(origin, arrive), "You arrive outside the hall")
local leave = Pit.Leave
check(math.abs((Pit.Arrive - leave.Center).Z) > leave.Half.Z + 4, "You arrive in the doorway back up")
-- Kept in: a kaiju past the rails is brought back inside them, at its height.
local court = courts[3]
local out = court.Center
	+ court.Right * (spec.HalfWidth + 6)
	+ court.Axis * (spec.HalfLength + 9)
	+ Vector3.new(0, 2, 0)
check(not Pit.inCourt(court, out), "Out past the rails is in")
local back = Pit.clamp(court, out)
check(
	Pit.inCourt(court, back, -spec.Inset + 1e-4) and math.abs(back.Y - out.Y) < 1e-6,
	"Not brought back inside the rails"
)
check(
	near(Pit.clamp(court, court.Center + court.Right * 2), court.Center + court.Right * 2),
	"Moved a kaiju already inside"
)
-- The nearest pad that's wanted.
local found, side = Pit.nearest(courts, court.PadB + Vector3.new(1, 0, 1), function()
	return true
end)
check(found == court and side == "B", "The nearest pad isn't the one beside you")
found = Pit.nearest(courts, court.PadB, function(c)
	return c ~= court
end)
check(found ~= nil and found ~= court, "An unwanted court was picked")

-- Stakes: coins from the list, that you have; a gem loose in your pouch.
local have = {
	Coins = 300,
	Gems = {
		g1 = { Id = "g1", Tier = "Rare" },
		g2 = { Id = "g2", Tier = "Common" },
		g3 = { Id = "g3", Tier = "Legendary" },
	},
}
check(Pit.stakeProblem(nil, have) == nil, "No stake refused")
check(Pit.stakeProblem({ Kind = "Coins", Coins = 250 }, have) == nil, "A stake you can cover refused")
check(Pit.stakeProblem({ Kind = "Coins", Coins = 500 }, have) ~= nil, "A stake you can't cover taken")
check(Pit.stakeProblem({ Kind = "Coins", Coins = 77 }, have) ~= nil, "A stake that isn't on the list taken")
check(
	Pit.stakeProblem({ Kind = "Gem", Tier = "Rare", Gem = { Id = "g1" } }, have) == nil,
	"A loose gem refused as a stake"
)
check(
	Pit.stakeProblem({ Kind = "Gem", Tier = "Rare", Gem = { Id = "nope" } }, have) ~= nil,
	"A gem you don't have taken"
)
check(
	Pit.stakeProblem({ Kind = "Moon" }, have) ~= nil and Pit.stakeProblem("x", have) ~= nil,
	"Nonsense taken as a stake"
)
-- Matching: as many coins; a gem as rare or rarer.
local gemStake = { Kind = "Gem", Tier = "Rare", Gem = { Id = "x" } }
check(Pit.matchProblem({ Kind = "Coins", Coins = 250 }, nil, have) == nil, "Couldn't match coins you have")
check(Pit.matchProblem({ Kind = "Coins", Coins = 1000 }, nil, have) ~= nil, "Matched coins you don't have")
check(
	Pit.matchProblem(gemStake, "g1", have) == nil and Pit.matchProblem(gemStake, "g3", have) == nil,
	"A gem as good or better refused"
)
check(Pit.matchProblem(gemStake, "g2", have) ~= nil, "Matched a Rare with a Common")
check(Pit.matchProblem(gemStake, nil, have) ~= nil, "Matched a gem without picking one")
check(
	Pit.matchProblem(gemStake, nil, { Coins = 0, Gems = { g2 = have.Gems.g2 } }) ~= nil,
	"No gem good enough, and no word"
)
local matches = Pit.matches(gemStake, have)
check(#matches == 2 and matches[1].Id == "g1" and matches[2].Id == "g3", "The gems that match, weakest first")
check(#Pit.matches({ Kind = "Coins", Coins = 50 }, have) == 0, "Gems offered for a coin stake")
-- What it says.
check(
	Pit.stakeText(nil) ~= "" and Pit.stakeText({ Kind = "Coins", Coins = 250 }) == "250 coins each",
	"The stake isn't said"
)
check(Pit.stakeText({ Kind = "Gem", Tier = "Rare" }) == "a Rare gem each", "A gem stake isn't said")
check(Pit.stakeText({ Kind = "Gem", Tier = "Uncommon" }) == "an Uncommon gem each", '"a Uncommon gem"')
check(
	Pit.matchProblem({ Kind = "Gem", Tier = "UltraRare" }, nil, { Gems = {} })
		== "You need an Ultra Rare gem or better to match the stake.",
	'"a Ultra Rare gem"'
)
check(
	Pit.pot({ Kind = "Coins", Coins = 250 }, { Kind = "Coins", Coins = 250 }) == "500 coins",
	"The pot isn't both stakes"
)
check(Pit.pot(gemStake, gemStake) == "Both gems", "A gem pot isn't both gems")

-- The yellow arrows on the ground (Client GroundGuide): spaced along the
-- way from just ahead of you, facing along it, never past its end, round a
-- corner, lying flat on a slope; and quiet.
do
	local guideEnv = setmetatable({
		game = {
			GetService = function(_, name)
				return { Name = name }
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Enum = roblox.Enum,
		Color3 = roblox.Color3,
		Vector3 = Vector3,
		-- (Lune's lookAt turns the wrong way along Z: where it stands and faces is what counts.)
		CFrame = setmetatable({
			lookAt = function(at, target)
				return { Position = at, LookVector = (target - at).Unit }
			end,
		}, { __index = roblox.CFrame }),
	}, { __index = _G })
	local source = fs.readFile(ROOT .. "/src/client/Modules/GroundGuide.luau")
	local Guide = luau.load(source, { debugName = "GroundGuide", environment = guideEnv })()
	local from, to = Vector3.new(0, 3, 0), Vector3.new(0, 3, -20)
	local spots = Guide.trail(from, to, 7, 3.4)
	check(#spots == 6, "The arrows don't stop at the end of the way (" .. #spots .. ")")
	for i, cf in spots do
		check(near(cf.Position, from + Vector3.new(0, 0, -3.4 * (i - 1)), 1e-3), "An arrow's off the way")
		check(cf.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.999, "An arrow doesn't point the way to go")
	end
	-- Round a corner: the ones past the bend turn with it.
	local bend = Guide.along({ Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, -10) }, 7, 3, 1)
	check(#bend == 7, "Not every arrow round the corner")
	check(bend[1].CFrame.LookVector:Dot(Vector3.new(1, 0, 0)) > 0.999, "The first leg's arrows don't face along it")
	check(near(bend[5].CFrame.Position, Vector3.new(10, 0, -3), 1e-3), "An arrow past the bend isn't on the second leg")
	check(bend[5].CFrame.LookVector:Dot(Vector3.new(0, 0, -1)) > 0.999, "The arrows don't turn the corner")
	for i = 2, #bend do
		check(bend[i].Share > bend[i - 1].Share and bend[i].Share <= 1, "How far along isn't in order")
	end
	-- Up a slope they still lie flat.
	local slope = Guide.along({ Vector3.new(0, 0, 0), Vector3.new(0, 6, -8) }, 3, 2, 0)
	check(#slope == 3 and math.abs(slope[2].CFrame.LookVector.Y) < 1e-3, "An arrow tips up off the floor on a slope")
	check(#Guide.along({ from, from }, 7, 3.4, 0) == 0, "Arrows on a way that goes nowhere")
	-- Each chevron points the way: its two arms meet in front, one each side.
	local arms = Guide.arms(roblox.CFrame.new(0, 0, 0)) -- (facing -Z)
	check(#arms == 2, "A chevron isn't two arms")
	local tips = {}
	for _, arm in arms do
		local a, b = arm * Vector3.new(0, 0, -0.75), arm * Vector3.new(0, 0, 0.75)
		local inner, outer =
			if math.abs(a.X) < math.abs(b.X) then a else b, if math.abs(a.X) < math.abs(b.X) then b else a
		check(inner.Z < outer.Z - 0.5, "A chevron points back the way you came")
		check(math.abs(inner.X) < 0.2, "A chevron's arms don't meet")
		table.insert(tips, outer.X)
	end
	check(tips[1] < -0.5 and tips[2] > 0.5, "A chevron's arms aren't one each side")
	-- Subtle: see-through, a short trail, and gone once you're there.
	check(Guide.Transparency >= 0.3 and Guide.Transparency < 0.8, "The arrows aren't subtle (or can't be seen)")
	check(Guide.Count * Guide.Spacing <= 30, "The trail's too long to be subtle")
	check(Guide.Arrive > Guide.Ahead, "The arrows stay once you're there")
end

-- The sides' colours: A blue (the court's blue half), B red; and the ring
-- each kaiju stands on in its side's colour (Client KaijuTeamRings), a
-- little wider than it is.
do
	local blue, red = Battle.Sides.A.Color, Battle.Sides.B.Color
	check(Battle.Sides.A.Name == "BLUE" and Battle.Sides.B.Name == "RED", "The sides aren't BLUE and RED")
	check(blue.B > blue.R + 0.3 and red.R > red.B + 0.3, "Blue isn't blue or red isn't red")
	-- (Services that hand back whatever's asked of them: only the rules are used.)
	local function anything()
		return setmetatable({}, {
			__index = function()
				return anything()
			end,
		})
	end
	local ringEnv = setmetatable({
		game = {
			GetService = function()
				return anything()
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Enum = roblox.Enum,
		script = { Parent = {} },
		require = function()
			return Battle
		end,
	}, { __index = _G })
	local source = fs.readFile(ROOT .. "/src/client/Modules/KaijuTeamRings.luau")
	local Rings = luau.load(source, { debugName = "KaijuTeamRings", environment = ringEnv })()
	check(Rings.size(5) > 5 and Rings.size(5) < 7, "A ring isn't a little wider than its kaiju")
	check(Rings.size(0.5) >= 4 and Rings.size(40) <= 10, "A ring's too small to see or too big for the court")
end

-- The battle's camera (Client KaijuBattleCam): over your end of the court,
-- high enough to look down on it, past the floodlights, both sides' every
-- place in view; inside the hall downstairs whichever court, side, swing or
-- zoom.
do
	local camEnv = setmetatable({
		game = {
			GetService = function(_, name)
				return { Name = name }
			end,
		},
		Enum = roblox.Enum,
		Vector3 = Vector3,
		-- (Lune's lookAt turns the wrong way along Z: where it stands and faces is what counts.)
		CFrame = setmetatable({
			lookAt = function(at, target)
				return { Position = at, LookVector = (target - at).Unit }
			end,
		}, { __index = roblox.CFrame }),
	}, { __index = _G })
	local source = fs.readFile(ROOT .. "/src/client/Modules/KaijuBattleCam.luau")
	local Cam = luau.load(source, { debugName = "KaijuBattleCam", environment = camEnv })()
	local hall = Pit.Hall
	-- (On a screen 16:10 or wider, clear of the battle bar along its top.)
	local tall = math.tan(math.rad(Cam.Fov / 2))
	local wide = tall * 1.6
	local function sees(view, spot)
		local look = view.LookVector
		local right = look:Cross(Vector3.new(0, 1, 0)).Unit
		local up = right:Cross(look)
		local to = spot - view.Position
		local ahead = to:Dot(look)
		return ahead > 0 and math.abs(to:Dot(right)) / ahead < wide * 0.95 and math.abs(to:Dot(up)) / ahead < tall * 0.8
	end
	for _, court in Pit.courts(roblox.CFrame.new()) do
		local field = Pit.field(court)
		for _, side in { "A", "B" } do
			local home = if side == "A" then -court.Axis else court.Axis
			for _, yaw in { -Cam.Yaw, 0, Cam.Yaw } do
				for _, zoom in { Cam.Zoom[1], 1, Cam.Zoom[2] } do
					local view = Cam.view(court.Center, court.Axis, side, nil, yaw, zoom)
					local eye = view.Position
					check(
						math.abs(eye.X) < hall.HalfX - 3
							and math.abs(eye.Z) < hall.HalfZ - 3
							and eye.Y < hall.Height - 3,
						string.format(
							"The battle camera's outside the hall (court %d, %s): %s",
							court.Id,
							side,
							tostring(eye)
						)
					)
					local flat = Vector3.new(eye.X - court.Center.X, 0, eye.Z - court.Center.Z)
					check(flat.Magnitude > court.HalfLength - 2, "The battle camera's under the floodlights")
					check(eye.Y > 10 and view.LookVector.Y < -0.3, "The battle camera doesn't look down on the court")
					if yaw == 0 then
						check(flat.Unit:Dot(home) > 0.99, "The battle camera isn't over your end")
					end
					for _, who in { "A", "B" } do
						for _, cell in Battle.cells() do
							local spot = Battle.cellSpot(field, who, cell.Id)
							check(
								sees(view, spot) and sees(view, spot + Vector3.new(0, 3, 0)),
								string.format("A kaiju at %s %s is out of the battle camera's view", who, cell.Id)
							)
						end
					end
				end
			end
		end
	end
	check(Cam.Reach > Pit.Court.Pad + 10, "The battle camera lets go of you on your pad")
end

print(
	string.format(
		"PASS: %d kaiju battle checks (the field, places, default formation, formations, winners, asks; the arena's courts, pads, kept in, stakes; the ground arrows; the sides' colours and rings; the battle camera)",
		checks
	)
)
