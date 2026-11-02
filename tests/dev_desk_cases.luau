-- lune run tests/dev_desk_cases.luau <root>
-- Server.DevDesk: the Shelter's DEV desk lit while an Owner's in, dark when not.
local fs, luau, roblox, process = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox"), require("@lune/process")
local ROOT = process.args[1] or "."
local R = roblox
local checks = 0
local function check(ok, message)
	checks += 1
	if not ok then
		error("FAIL: " .. message, 2)
	end
end

local PURPLE = R.Color3.fromRGB(170, 90, 255)
local desk = R.Instance.new("Model")
desk.Name = "DevDesk"
local glows = {}
for i = 1, 3 do
	local p = R.Instance.new("Part")
	p.Color, p.Material = PURPLE, R.Enum.Material.Neon
	p:SetAttribute("DevGlow", PURPLE)
	p.Parent = desk
	glows[i] = p
end
local plain = R.Instance.new("Part")
plain.Color = R.Color3.fromRGB(1, 2, 3)
plain.Parent = desk
local sign = R.Instance.new("Part")
sign.Name = "DevSign"
sign.Parent = desk
local gui = R.Instance.new("SurfaceGui")
gui.Name = "Letters"
gui.Parent = sign
local word = R.Instance.new("TextLabel")
word.Name = "Word"
word.Parent = gui
local lamp = R.Instance.new("PointLight")
lamp.Name = "DevLight"
lamp.Parent = sign

local env = setmetatable({
	game = { GetService = function() return { GetPlayers = function() return {} end } end },
	script = { Parent = { DevAlerts = "DevAlerts" } },
	require = function() return { owner = function() return false end } end,
	Color3 = R.Color3, Enum = R.Enum, typeof = R.typeof or typeof,
}, { __index = _G })
local DevDesk = luau.load(fs.readFile(ROOT .. "/src/server/Systems/DevDesk.luau"), { debugName = "DevDesk", environment = env })()

DevDesk.apply(desk, nil)
for _, p in glows do
	check(p.Color == DevDesk.Off and p.Material == R.Enum.Material.SmoothPlastic, "A light stayed on with no Owner in")
end
check(not lamp.Enabled and word.Text == "DEV · OFFLINE" and desk:GetAttribute("DevOnline") == false, "The desk says DEV's in")
check(plain.Color == R.Color3.fromRGB(1, 2, 3), "A part that doesn't glow changed")
DevDesk.apply(desk, "Devvolver")
for _, p in glows do
	check(p.Color == PURPLE and p.Material == R.Enum.Material.Neon, "A light didn't come on for the Owner")
end
check(lamp.Enabled and word.Text == "DEV ONLINE" and desk:GetAttribute("DevOnline") == true, "The sign doesn't say DEV ONLINE")
DevDesk.apply(desk, nil)
check(glows[1].Material == R.Enum.Material.SmoothPlastic and not lamp.Enabled, "The desk stayed lit after the Owner left")
print("PASS: " .. checks .. " DEV desk checks (dark with no Owner in, lit with one, the sign says DEV ONLINE, out again when they go)")
