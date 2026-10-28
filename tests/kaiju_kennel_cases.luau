-- lune run tests/kaiju_kennel_cases.luau <repo>
-- The Kaiju Kennel (Shared.KaijuKennel, Client.KennelLife, Server
-- OutpostWorld): today's residents and the Kaiju of the Day come from the
-- rarest batch, change with the day, and never overlap; each resident
-- walks only in its own wedge of the pen, inside the fence, smoothly (no
-- jumps from one moment to the next), and stops to sniff, look, rest,
-- sleep or roar; every client works out the same. The hologram is off,
-- the pen is built on its stage, Wren keeps it, and CreatureAnimation
-- walks its kaiju.
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

local Kaiju = shared("Kaiju")
local Kennel = shared("KaijuKennel")
local Vector3 = roblox.Vector3

-- Who's there -------------------------------------------------------------------------------
local specials = {}
for day = 20000, 20060 do
	local special = Kennel.special(day)
	check(Kaiju.batch(special.Species) == 1, "The Kaiju of the Day isn't of the rarest batch: " .. special.Species)
	check(table.find(Kaiju.Elements, special.Element) ~= nil, "The Kaiju of the Day has no element")
	specials[special.Species] = (specials[special.Species] or 0) + 1
	local residents = Kennel.residents(day)
	check(#residents == Kennel.Count, "Not a full pen on day " .. day)
	local seen = {}
	for _, r in residents do
		check(Kaiju.batch(r.Species) == 1, r.Species .. " in the pen isn't of the rarest batch")
		check(r.Species ~= special.Species, "The Kaiju of the Day is in the pen as well")
		check(not seen[r.Species], r.Species .. " is in the pen twice")
		seen[r.Species] = true
		check(table.find(Kaiju.Elements, r.Element) ~= nil, r.Species .. " has no element")
	end
end
local kinds = 0
for _, n in specials do
	kinds += 1
	check(n <= 3, "One kind is the Kaiju of the Day too often in two months")
end
check(kinds >= 25, "The Kaiju of the Day doesn't go through the batch")
local a, b = Kennel.residents(20000), Kennel.residents(20001)
local same = 0
for _, r in a do
	for _, s in b do
		if r.Species == s.Species then
			same += 1
		end
	end
end
check(same < Kennel.Count, "The pen doesn't change from one day to the next")
check(Kennel.day(86400 * 20000 + 5) == 20000 and Kennel.day(86400 * 20001 - 1) == 20000, "Days don't turn at midnight")

-- Where they go -----------------------------------------------------------------------------
local pen = Kennel.Pen
local count = Kennel.Count
local moods, walked = {}, 0
for i = 1, count do
	local wedge = math.pi * 2 / count
	local last = nil
	for step = 0, 3000 do
		local now = 1.7e9 + step * 0.1
		local s = Kennel.state(i, count, now)
		local off = (s.Position - pen.Middle) * Vector3.new(1, 0, 1)
		check(off.Magnitude <= pen.Outer + 0.01, "A kaiju walked out past the pen's edge")
		check(off.Magnitude < pen.Fence - 2, "A kaiju is up against the fence")
		check(math.abs(s.Position.Y - pen.Middle.Y) < 1e-6, "A kaiju isn't on the pen's floor")
		local angle = math.atan2(off.Z, off.X) % (math.pi * 2)
		local lo, hi = (i - 1) * wedge, i * wedge
		check(angle >= lo - 0.02 and angle <= hi + 0.02, "A kaiju left its own wedge of the pen")
		if s.Speed > 0 then
			walked += 1
			check(s.Speed >= Kennel.Speed - 1e-6, "Walking slower than a kaiju walks")
		else
			moods[s.Mood or "Stand"] = true
		end
		if last then
			local moved = (s.Position - last.Position).Magnitude
			check(moved <= math.max(last.Speed, s.Speed, Kennel.Speed) * 0.1 + 0.05, "A kaiju jumped from one place to another")
			local turn = math.abs((s.Yaw - last.Yaw + math.pi) % (math.pi * 2) - math.pi)
			check(turn <= math.pi * 0.1 / Kennel.Turn + 0.05 or moved < 0.01 and s.Speed == 0, "A kaiju spun round at once")
		end
		last = s
		-- (Every client works it out the same.)
		local again = Kennel.state(i, count, now)
		check(again.Position == s.Position and again.Yaw == s.Yaw and again.Mood == s.Mood, "Two clients would see it differently")
	end
end
check(walked > 2000, "The kennel's kaiju hardly walk")
for _, mood in { "Sniff", "Look", "Rest", "Sleep", "Roar" } do
	check(moods[mood], "A kennel kaiju never does " .. mood)
end
-- No two residents ever closer than a kaiju's width.
for step = 0, 2000 do
	local now = 1.8e9 + step * 0.25
	local spots = {}
	for i = 1, count do
		spots[i] = Kennel.state(i, count, now).Position
	end
	for i = 1, count do
		for j = i + 1, count do
			check((spots[i] - spots[j]).Magnitude > 1.5, "Two kennel kaiju walked into each other")
		end
	end
end

-- The world and the client ------------------------------------------------------------------
local world = fs.readFile(ROOT .. "/src/server/World/OutpostWorld.luau")
check(world:find('"KENNEL"', 1, true) ~= nil and world:find('"KennelBed"', 1, true) ~= nil, "The kennel isn't built on the stage")
check(world:find('"ProjectorLens"', 1, true) == nil, "The hologram's lens is still on the stage")
check(world:find('Id = "KaijuKeeper"', 1, true) ~= nil, "No keeper by the kennel")
local vendors = fs.readFile(ROOT .. "/src/shared/Vendors.luau")
check(vendors:find("Vendors.KaijuKeeper", 1, true) ~= nil and vendors:find('Action = "KennelToday"', 1, true) ~= nil, "Wren can't say who's in the pen")
local dialogue = fs.readFile(ROOT .. "/src/client/Dialogue.client.luau")
check(dialogue:find("function actions.KennelToday", 1, true) ~= nil and dialogue:find("function actions.KaijuMarket", 1, true) ~= nil, "Wren's options do nothing")
local life = fs.readFile(ROOT .. "/src/client/Modules/ShelterLife.luau")
check(life:find("ShelterLife.Hologram = false", 1, true) ~= nil, "The hologram is still on")
local anim = fs.readFile(ROOT .. "/src/client/CreatureAnimation.client.luau")
check(anim:find('"KaijuKennel"', 1, true) ~= nil and anim:find('"PacedSpeed"', 1, true) ~= nil, "CreatureAnimation doesn't walk the kennel's kaiju")
local scene = fs.readFile(ROOT .. "/src/client/Modules/OutpostScene.luau")
check(scene:find("KennelLife.mount(shelterFrame)", 1, true) ~= nil and scene:find("KennelLife.step(dt)", 1, true) ~= nil, "The kennel's kaiju aren't drawn")
local client = fs.readFile(ROOT .. "/src/client/Modules/KennelLife.luau")
check(client:find("CanQuery", 1, true) ~= nil and client:find("root.Anchored = true", 1, true) ~= nil, "Kennel kaiju can be clicked or fall")

print(string.format("PASS: %d Kaiju Kennel checks (residents and the Kaiju of the Day by day, wedges, no collisions, smooth walks, moods, the pen, Wren)", checks))
