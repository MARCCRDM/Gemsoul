-- A gem raid's stones on screen (Client CritterFx) on Roblox instances
-- (lune's roblox library): what a snatcher holds over its head is the
-- very gem it took, built by GemArt from what the server puts on its
-- model (KaijuWilds' CarriedGem*), the same stone as in the pouch, at a
-- size you can see; it's over the snatcher's head, turning; it goes when
-- the snatcher lets go. A recovered gem flies back as the stone itself
-- too (FrontierServer sends its look). Run by tests/run_critter_fx.py.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local R = roblox
local ROOT = process.args[1] or "."
local CFrame, Vector3, Color3 = R.CFrame, R.Vector3, R.Color3

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local mods = {}
local function proxy(name)
	return setmetatable({ __mod = name }, {
		__index = function(_, key)
			if key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, child)
					return proxy(child)
				end
			end
			return proxy(key)
		end,
	})
end
local env
local function load(name)
	if mods[name] then
		return mods[name]
	end
	local path = ROOT .. "/src/shared/" .. name .. ".luau"
	if not fs.isFile(path) then
		path = ROOT .. "/src/client/Modules/" .. name .. ".luau"
	end
	mods[name] = luau.load(fs.readFile(path), { debugName = name, environment = env })()
	return mods[name]
end
local workspace = R.Instance.new("Folder")
workspace.Name = "Workspace"
env = setmetatable({
	Instance = R.Instance,
	CFrame = R.CFrame,
	Vector3 = R.Vector3,
	Vector2 = R.Vector2,
	Color3 = R.Color3,
	Enum = R.Enum,
	UDim = R.UDim,
	UDim2 = R.UDim2,
	ColorSequence = R.ColorSequence,
	NumberSequence = R.NumberSequence,
	NumberSequenceKeypoint = R.NumberSequenceKeypoint,
	NumberRange = R.NumberRange,
	workspace = workspace,
	game = {
		GetService = function(_, service)
			return proxy(service)
		end,
	},
	script = { Parent = proxy("Modules") },
	require = function(p)
		return load(p.__mod)
	end,
	typeof = R.typeof or typeof,
	-- (Roblox's seeded Random, as GemShapes uses it.)
	Random = {
		new = function(seed)
			local x = (math.floor(seed or 7) % 2147483646) + 1
			local r = {}
			local function n()
				x = (x * 48271) % 2147483647
				return x / 2147483647
			end
			function r:NextNumber(a, b)
				a, b = a or 0, b or 1
				return a + (b - a) * n()
			end
			function r:NextInteger(a, b)
				return math.floor(a + (b - a + 1) * n())
			end
			return r
		end,
	},
}, { __index = _G })
local Fx = load("CritterFx")
local GemArt = load("GemArt")

local gem = { Id = "haul-4", Element = "Frost", Tier = "Rare", Size = 7, Clarity = 8, Cut = 6 }
-- The stone is the gem itself: GemArt's model of it, part for part, scaled.
local stone = Fx.stone(gem, 0.9)
check(stone ~= nil, "No stone for a stolen gem")
local art = GemArt.model(gem, false)
local artParts = 0
for _, d in art:GetDescendants() do
	if d:IsA("BasePart") then
		artParts += 1
	end
end
check(#stone.Parts == artParts and artParts > 10, "Not the gem's own model: " .. #stone.Parts .. " of " .. artParts)
for _, part in stone.Parts do
	check(
		part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,
		"A stone part you could bump or click"
	)
end
check(Fx.stone({ Id = "x", Element = "Nope" }, 1) == nil, "A stone for an element that doesn't exist")
check(Fx.stone(nil, 1) == nil, "A stone for nothing")

-- What a snatcher carries is read off its model.
local thief = R.Instance.new("Model")
thief:SetAttribute("CarryingGem", "Rare")
thief:SetAttribute("CarriedGemId", "haul-4")
thief:SetAttribute("CarriedGemElement", "Frost")
thief:SetAttribute("CarriedGemSize", 7)
thief:SetAttribute("CarriedGemClarity", 8)
thief:SetAttribute("CarriedGemCut", 6)
local read = Fx.carriedGem(thief)
check(
	read and read.Id == "haul-4" and read.Element == "Frost" and read.Tier == "Rare",
	"The carried gem isn't read off the snatcher"
)
check(read.Size == 7 and read.Clarity == 8 and read.Cut == 6, "The carried gem's grades are lost")
thief:SetAttribute("CarriedGemId", nil)
check(Fx.carriedGem(thief) == nil, "A gem read off a snatcher that let go")

-- Placed: every part kept where it sits in the stone, round the spot.
local spot = CFrame.new(5, 9, -3)
Fx.place(stone, spot)
local sum = Vector3.new()
for _, part in stone.Parts do
	sum += part.CFrame.Position
end
local middle = sum / #stone.Parts
check((middle - spot.Position).Magnitude < 1.5, "The stone isn't where it was put")

-- The server's side: it puts the gem on the snatcher, not a made-up stone.
local wilds = fs.readFile(ROOT .. "/src/server/Systems/KaijuWilds.luau")
check(wilds:find('SetAttribute("CarriedGemId"', 1, true) ~= nil, "The server doesn't say which gem it took")
check(wilds:find('piece("StolenGem"', 1, true) == nil, "The made-up glass stone is back")
local frontier = fs.readFile(ROOT .. "/src/server/Systems/FrontierServer.luau")
check(
	frontier:find('"GemRecovered",', 1, true) and frontier:find("Cut = gem.Cut", 1, true),
	"A recovered gem's look isn't sent"
)
local combat = fs.readFile(ROOT .. "/src/client/Combat.client.luau")
check(
	combat:find("require(script.Parent.Modules.CritterFx).start()", 1, true) ~= nil,
	"The carried stones aren't drawn"
)

print(
	string.format(
		"PASS: %d critter fx checks (the stolen gem itself over a snatcher's head, read off its model, placed, the server's side)",
		checks
	)
)
