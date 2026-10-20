-- lune run tests/kaiju_battle_cases.luau <repo>
-- Kaiju battles' rules (Shared.KaijuBattle): the field between the two,
-- each side's six places (left and right as that side sees them), the
-- default formation (the sturdy kinds in front, a Razorback behind), a
-- formation checked, who wins, and why one can't ask.
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

print(
	string.format(
		"PASS: %d kaiju battle checks (the field, places, default formation, formations, winners, asks)",
		checks
	)
)
