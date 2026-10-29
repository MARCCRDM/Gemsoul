-- lune run tests/bounty_board_cases.luau <repo>
-- The bounty board on the Shelter's hall floor (Shared.Bounties.Board,
-- Client.BountyBoard): its two faces show one bounty each, never the same
-- one, every bounty in turn, changing every Period seconds for everyone at
-- once; it stands in the open where the floor's inlay bands cross, clear of
-- the booths, the Hall of Fame, the crew and the Kennel; each player's client
-- builds it with a face each way and a prompt that opens the bounty board;
-- every bounty's boss is ready to show on it.
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
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Enum = roblox.Enum,
	UDim2 = roblox.UDim2,
	UDim = roblox.UDim,
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	Instance = roblox.Instance,
	game = { GetService = function() return setmetatable({}, { __index = function() return {} end }) end },
	script = { Parent = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	}) },
	require = function(name)
		return shared(name)
	end,
}, { __index = _G })

local Bounties = shared("Bounties")
local Kennel = shared("KaijuKennel")
local Vector3 = roblox.Vector3

-- What the faces show -----------------------------------------------------------------------
local list = Bounties.entries()
local count = 0
for _, entry in Bounties.list() do
	count += #entry.Bosses
end
check(#list == count and #list >= 2, "The board doesn't go through every bounty")
for _, entry in list do
	check(entry.Boss and entry.Boss.Id and entry.Element and entry.Biome, "A bounty on the board without its boss, element or biome")
end
local period = Bounties.Board.Period
check(period >= 6 and period <= 30, "A bounty's up on the board too briefly, or too long")
local fronts, backs = {}, {}
local t0 = 1_700_000_000
local last = nil
for step = 0, #list * 4 * 2 - 1 do
	local now = t0 + step * period / 4
	local front, back, share = Bounties.boardAt(now)
	check(front and back, "A face of the board shows nothing")
	check(front.Boss.Id ~= back.Boss.Id, "Both faces show the same bounty")
	check(share >= 0 and share < 1, "The time left on a bounty is off")
	fronts[front.Boss.Id], backs[back.Boss.Id] = true, true
	-- (a turn changes only on Period's boundary, and both faces with it)
	local again = Bounties.boardAt(now + period * 0.01)
	if share < 0.98 then
		check(again.Boss.Id == front.Boss.Id, "A bounty changed before its time was up")
	end
	if last and step % 4 == 0 then
		check(last ~= front.Boss.Id, "The board didn't move on to the next bounty")
	end
	if step % 4 == 0 then
		last = front.Boss.Id
	end
end
for _, entry in list do
	check(fronts[entry.Boss.Id] and backs[entry.Boss.Id], entry.Boss.Id .. " never comes up on the board")
end
-- (everyone at once: the same clock gives the same faces)
local a1, b1 = Bounties.boardAt(t0 + 123.4)
local a2, b2 = Bounties.boardAt(t0 + 123.4)
check(a1.Boss.Id == a2.Boss.Id and b1.Boss.Id == b2.Boss.Id, "Two players see different bounties")

-- Where it stands ---------------------------------------------------------------------------
-- (the Shelter's hall frame, as OutpostWorld lays it out: half 84 wide, 60
-- deep, the garage barrier at z -14; the inlay bands along x 28 and across
-- z 32; the Hall of Fame and the bounty office on the east wall, Brutus's
-- booth on the south wall; INFO-9 by its kiosk)
local spot = Bounties.Board.Spot
check(spot.X == 28 and spot.Z == 32, "The board isn't where the floor's bands cross")
check(spot.X + 7 < 84 and spot.X - 7 > -84 and spot.Z - 4 > -14 and spot.Z + 4 < 60, "The board isn't inside the hall")
local function clear(x, z, room, what)
	check((Vector3.new(x, 0, z) - Vector3.new(spot.X, 0, spot.Z)).Magnitude > room, "The board is in the way of " .. what)
end
clear(84, 10, 20, "the Hall of Fame")
clear(84, 46, 20, "the bounty office")
clear(52, 60, 18, "Brutus's booth")
clear(84 - 11.5, 10, 14, "the Hall of Fame's rope")
clear(15, 41, 10, "INFO-9")
clear(0, 60, 16, "the main door")
clear(Kennel.Pen.Middle.X, Kennel.Pen.Middle.Z, Kennel.Pen.Fence + 10, "the Kennel")
clear(Kennel.Display.X, Kennel.Display.Z, 10, "the Daily Kaiju Sale")

-- Built by each client, a face each way, its prompt -----------------------------------------
local client = fs.readFile(ROOT .. "/src/client/Modules/BountyBoard.luau")
check(client:find('"FaceFront"', 1, true) and client:find('"FaceBack"', 1, true), "The board hasn't a face each way")
check(client:find("Bounties.boardAt(", 1, true) ~= nil, "The board doesn't show the bounties' turns")
check(client:find('openGate("Bounty"', 1, true) ~= nil, "The board's prompt doesn't open the bounty board")
check(client:find("RiftPortraits", 1, true) ~= nil, "The board doesn't show the bosses")
check(client:find("LightInfluence = 0", 1, true) ~= nil, "The board's screen isn't lit")
-- (the boss a real figure on a ledge: a ViewportFrame doesn't draw on a board out in the world)
check(client:find('new("ViewportFrame"', 1, true) == nil and client:find('Instance.new("ViewportFrame"', 1, true) == nil, "The board draws its boss in a ViewportFrame, which doesn't show out in the world")
check(client:find(":ScaleTo(", 1, true) ~= nil and client:find('"Ledge"', 1, true) ~= nil, "The boss isn't a figure on a ledge")
check(client:find("part.Transparency < 0.95", 1, true) ~= nil, "The figure's size counts parts no one sees")
local scene = fs.readFile(ROOT .. "/src/client/Modules/OutpostScene.luau")
for _, call in { "BountyBoard.mount(shelterFrame)", "BountyBoard.show(active)", "BountyBoard.step(dt)" } do
	check(scene:find(call, 1, true) ~= nil, "The Outpost doesn't put the board up: " .. call)
end
local rift = fs.readFile(ROOT .. "/src/server/Systems/RiftServer.luau")
check(rift:find("for _, entry in Bounties.entries() do\n\t\t\tportraitOf(entry.Boss)", 1, true) ~= nil, "The bosses' portraits aren't ready for the board")
-- (its words in Spanish too)
local es = fs.readFile(ROOT .. "/src/shared/LangEs.luau")
for _, words in { '["Take a bounty"]', '["SOLO OR PARTY"]', '["Bounty"]', '["WANTED"]', '["BRING A PARTY"]', '["Bounties"]' } do
	check(es:find(words, 1, true) ~= nil, "No Spanish for " .. words)
end

print(string.format("PASS: %d bounty board checks (one bounty a face, never the same, every bounty in turn, in the open on the hall floor, built with its prompt, in Spanish)", checks))
