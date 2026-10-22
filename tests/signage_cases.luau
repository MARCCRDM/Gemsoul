-- The base's signs (Server.OutpostWorld, Server.KaijuPitWorld), built for
-- real on Roblox instances (lune's roblox library). A sign names a place in
-- a word, the words the HUD uses (STORE, MARKET, ARENA, EXIT, QUARRY...),
-- painted on or on a bare plate: no line under a name, no colour bar down
-- its side, no invented names, none of the old taglines back (KAIJU ARENA /
-- DOWNSTAIRS: TAKE THE WEST STAIRS, ARENA UPLINK, MECH GARAGE, the FIELD
-- GUIDE board...). PROBE-7 and Brutus are crew now, with no station or
-- gate to put a word on. Out in the quarry no sign names
-- a biome, and crossing into a band or a biome shows no title card. Run by
-- tests/run_signage.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local R = require("@lune/roblox")
local ROOT = process.args[1] or "."

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

-- A seeded Random (lune has none).
local Rand = {}
Rand.__index = Rand
function Rand.new(seed)
	return setmetatable({ x = (seed or 7) % 2147483647 + 1 }, Rand)
end
function Rand:_n()
	self.x = (self.x * 48271) % 2147483647
	return self.x / 2147483647
end
function Rand:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_n()
end
function Rand:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_n())
end

local loaded = {}
local function load(path: string, name: string)
	local env
	env = setmetatable({
		game = {
			GetService = function(_, service)
				if service == "ReplicatedStorage" then
					return { Shared = setmetatable({}, { __index = function(_, k) return { Name = k } end }) }
				end
				return nil
			end,
		},
		Instance = R.Instance,
		CFrame = R.CFrame,
		Vector3 = R.Vector3,
		Vector2 = R.Vector2,
		Color3 = R.Color3,
		UDim = R.UDim,
		UDim2 = R.UDim2,
		Enum = R.Enum,
		NumberRange = R.NumberRange,
		NumberSequence = R.NumberSequence,
		NumberSequenceKeypoint = R.NumberSequenceKeypoint,
		ColorSequence = R.ColorSequence,
		ColorSequenceKeypoint = R.ColorSequenceKeypoint,
		PhysicalProperties = R.PhysicalProperties,
		Random = Rand,
		script = { Parent = { FindFirstChild = function() return nil end } },
		require = function(target)
			local key = type(target) == "table" and target.Name or nil
			if key and loaded[key] then
				return loaded[key]
			end
			error("no require offline: " .. tostring(key))
		end,
	}, { __index = _G })
	return luau.load(fs.readFile(ROOT .. "/" .. path), { debugName = name, environment = env })()
end
loaded.Frontier = load("src/shared/Frontier.luau", "Frontier")
loaded.KaijuPit = load("src/shared/KaijuPit.luau", "KaijuPit")
loaded.Outpost = load("src/shared/Outpost.luau", "Outpost")
local OutpostWorld = load("src/server/World/OutpostWorld.luau", "OutpostWorld")
OutpostWorld.Frontier, OutpostWorld.Rules = loaded.Frontier, loaded.Outpost
local KaijuPitWorld = load("src/server/World/KaijuPitWorld.luau", "KaijuPitWorld")

local holder = R.Instance.new("Folder")
local site = OutpostWorld.build(R.CFrame.new(0, 0, 7000), holder)
check(site and site.Model, "The Outpost didn't build")
local pit = R.Instance.new("Folder")
KaijuPitWorld.build(R.CFrame.new(0, -60, 7000), pit)

-- Every word written on a surface, built.
local function words(root: Instance): { { Text: string, Gui: Instance } }
	local out = {}
	for _, d in root:GetDescendants() do
		if d.ClassName == "SurfaceGui" then
			for _, label in d:GetDescendants() do
				if (label.ClassName == "TextLabel" or label.ClassName == "TextButton") and label.Text ~= "" then
					table.insert(out, { Text = label.Text, Gui = d })
				end
			end
		end
	end
	return out
end

-- The places' words; a bay's or a court's number; nothing else.
local ALLOWED = {
	SHELTER = true, QUARRY = true, ARENA = true, EXIT = true, INFO = true, STORE = true, MARKET = true,
}
local function allowed(text: string): boolean
	return ALLOWED[text] == true or text:match("^%d%d?$") ~= nil
end
local OLD = {
	"KAIJU ARENA", "DOWNSTAIRS", "WEST STAIRS", "UPLINK", "MECH GARAGE", "BAYS 01", "FIELD GUIDE",
	"SAGA SHELTER", "FORWARD OPERATING", "QUARRY ACCESS", "RIFT ACTIVITY", "QUARRY SURVEY",
	"BANDS AND", "GEM BUYER", "SAGA OUTFITTERS", "MINERS' MARKET", "INFORMATION", "ARENA GUIDE",
	"STAND ON A PAD", "FULL HEALTH", "HOW IT WORKS", "UP TO THE SHELTER", "STATION", "SWING REFILLS",
	"STORMGLASS", "BLIGHTWOOD", "ASHFALL", "RIMEFROST", "GROUND", "CORNER", "·", "DUELS", "PROBE",
	"REFILLS", "GEM GALLERY",
}
local seen = {}
for _, place in { { "the Outpost", site.Model }, { "the arena hall", pit } } do
	for _, entry in words(place[2]) do
		seen[entry.Text] = (seen[entry.Text] or 0) + 1
		check(allowed(entry.Text), string.format("A sign in %s says more than a place's name: %q", place[1], entry.Text))
		for _, old in OLD do
			check(not string.upper(entry.Text):find(string.upper(old), 1, true), "An old sign is back: " .. entry.Text)
		end
		-- (One word to a sign: no line under it. A panel of numbers alone,
		-- the Market's lockers, is a prop, not a sign.)
		local count, worded = 0, false
		for _, label in entry.Gui:GetDescendants() do
			if label.ClassName == "TextLabel" and label.Text ~= "" then
				count += 1
				worded = worded or label.Text:match("^%d+$") == nil
			end
		end
		check(count == 1 or not worded, "A sign with a line under its name: " .. entry.Text)
	end
end
-- The places that keep a word, each once (a bay's number, each bay).
for word, times in {
	SHELTER = 1, QUARRY = 1, ARENA = 2, STORE = 1, MARKET = 1, INFO = 2,
} do
	check(seen[word] == times, string.format("%s is on %d signs, not %d", word, seen[word] or 0, times))
end
check(seen.EXIT == 3, "EXIT isn't over both garage doors and the stairs up: " .. tostring(seen.EXIT))
-- Each bay's number painted over it (the lockers' numbers are their own).
local painted = {}
for _, d in site.Model:GetDescendants() do
	if d.Name == "Painted" then
		local word = d:FindFirstChild("Word", true)
		if word then
			painted[word.Text] = (painted[word.Text] or 0) + 1
		end
	end
end
for bay = 1, 8 do
	check(painted[string.format("%02d", bay)] == 1, "Bay " .. bay .. " has no number painted over it")
end
-- No sign panels left anywhere (the old dark board with a colour bar).
for _, root in { site.Model, pit } do
	for _, d in root:GetDescendants() do
		check(d.Name ~= "Sign", "An old sign board is still built: " .. d:GetFullName())
		if d.ClassName == "Frame" then
			check(d.Name ~= "Bar", "A sign still has its colour bar")
		end
	end
end
-- Out in the quarry: no signs at the spokes naming the biomes.
check(site.Model:FindFirstChild("Crossroads", true) == nil, "The biome signs are back by the roads")
for _, biome in loaded.Frontier.Biomes do
	check(biome.Label == nil and biome.Line == nil, biome.Id .. " still has a sign or a title card line")
end
-- Crossing into a band or a biome: no title card (FrontierHud); the Rift
-- Vein's news still has its banner.
local hud = fs.readFile(ROOT .. "/src/client/Modules/FrontierHud.luau")
check(not hud:find("THE FRINGE", 1, true) and not hud:find("OUTPOST CORE", 1, true), "The bands' title cards are back")
check(not hud:find('GetAttributeChangedSignal("FrontierBiome")', 1, true), "Crossing into a biome shows a title card")
check(hud:find('showLines({ "RIFT VEIN", news }', 1, true) ~= nil, "The Rift Vein news lost its banner")
-- The crew say what places are for, in plain words: no Uplink.
for _, path in { "src/shared/Vendors.luau", "src/server/Systems/OutpostServer.luau" } do
	check(not fs.readFile(ROOT .. "/" .. path):find("Uplink", 1, true), path .. " still talks of the Uplink")
end

print(string.format("PASS: %d signage checks (one word a sign, the HUD's words, painted or on a plate; no taglines, no invented names, no biome signs, no zone title cards)", checks))
