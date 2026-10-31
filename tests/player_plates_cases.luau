-- Other players' plates (Client PlayerPlates): name and level always, the
-- health bar once they're hit (hurt, or within Hold of a blow), in the
-- body's outline colours, Roblox's own name off; started by the HUD.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local ROOT = process.args[1] or "."
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function source(path: string): string
	return fs.readFile(ROOT .. "/" .. path)
end

local BodyHealth = { outlineColor = function(x) return roblox.Color3.new(1 - x, x, 0) end }
local env = setmetatable({
	Instance = roblox.Instance, Color3 = roblox.Color3, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2,
	UDim2 = roblox.UDim2, UDim = roblox.UDim, Enum = roblox.Enum,
	game = { GetService = function() return {} end },
	workspace = {},
	script = { Parent = { BodyHealth = BodyHealth } },
	require = function(m) return m end,
}, { __index = _G })
local Plates = luau.load(source("src/client/Modules/PlayerPlates.luau"), { debugName = "PlayerPlates", environment = env })()

-- When the bar shows.
check(not Plates.showBar(1, nil), "A bar over someone never hit")
check(Plates.showBar(1, 0.5), "No bar right after a blow")
check(Plates.showBar(0.6, 100), "No bar while they're hurt")
check(not Plates.showBar(1, Plates.Hold + 0.1), "The bar stays at full health after its Hold")

-- The plate: name, level, the bar folded till drawn.
local plate = Plates.plate("Kristen", 14)
local title, level, back = plate:FindFirstChild("Title"), plate:FindFirstChild("Level"), plate:FindFirstChild("Back")
check(title and title.Text == "Kristen", "No name on the plate")
check(level and level.Text == "Lv 14", "No level on the plate")
check(back and not back.Visible, "A bar on a fresh plate")
check(plate.AlwaysOnTop and plate.MaxDistance == Plates.Range, "The plate's range")
Plates.draw(plate, 0.4, 0.7, true)
local fill, trail = back:FindFirstChild("Fill"), back:FindFirstChild("Trail")
check(back.Visible and math.abs(fill.Size.X.Scale - 0.4) < 1e-6 and math.abs(trail.Size.X.Scale - 0.7) < 1e-6, "The bar isn't drawn")
check(fill.BackgroundColor3 == BodyHealth.outlineColor(0.4), "The bar isn't the outline's colour")
Plates.draw(plate, 1, 1, false)
check(not back.Visible, "The bar doesn't fold away")
local small = Plates.plate("Kristen", 3, true)
check(small.Size.Y.Offset < plate.Size.Y.Offset and small.Size.X.Offset < plate.Size.X.Offset, "A phone's plate isn't smaller")
check(Plates.plate("X", nil):FindFirstChild("Level").Text == "Lv 1", "No level: not Lv 1")

-- Wired in: started by the HUD, Roblox's own name off, bubbles over it.
local plates = source("src/client/Modules/PlayerPlates.luau")
check(source("src/client/Hud.client.luau"):find("require(script.Parent.Modules.PlayerPlates).start()", 1, true) ~= nil, "The HUD doesn't start the plates")
check(plates:find("DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None", 1, true) ~= nil, "Roblox's own name still shows too")
check(plates:find("if other == Players.LocalPlayer then", 1, true) ~= nil, "A plate over yourself")
check(plates:find("VerticalStudsOffset = PlayerPlates.BubbleLift", 1, true) ~= nil, "Chat bubbles sit on the plates")
print(string.format("PASS: %d player plate checks (name and level, the bar once hit, colours, a phone's, wired in)", checks))
