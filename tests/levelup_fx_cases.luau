-- Levelling up on screen (Client LevelUpFx) on Roblox instances (lune's
-- roblox library): the column of light shoots up out of the ground and
-- fades, two rings run out over the ground one after the other, the
-- sparks spiral up round the body and close in, the flash dies away, the
-- plate pops in over the head and fades at the end, and it's all gone
-- after Seconds, following the body it's on. Also: the server sends a
-- level up for a miner (Progress) and a kaiju (KaijuServer), and the
-- client's handlers are wired (Combat.client). Run by
-- tests/run_levelup_fx.py.
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
}, { __index = _G })
local Fx = load("LevelUpFx")

-- A level up on a body 5 studs tall standing at (10, 0, 20).
local color = Color3.fromRGB(255, 202, 91)
local feet = CFrame.new(10, 0, 20)
local effect = Fx.build(feet, 5, color, "LEVEL UP", 7)
local model = effect.Model
check(model:IsA("Model") and effect.Column and effect.Core and #effect.Rings == 2, "The level up's parts")
check(#effect.Motes == Fx.Motes and Fx.Motes >= 10, "Not enough sparks")
for _, part in model:GetDescendants() do
	if part:IsA("BasePart") then
		check(
			not part.CanCollide and not part.CanQuery and not part.CanTouch and part.Anchored,
			"A part you could bump into or click"
		)
		check(not part.CastShadow, "A part casting a shadow")
	end
end
local plate = effect.Plate
check(plate and plate:IsA("BillboardGui") and plate.AlwaysOnTop, "No plate over the head")
local title, level = nil, nil
for _, d in plate:GetDescendants() do
	if d:IsA("TextLabel") then
		if d.Name == "Title" then
			title = d
		elseif d.Name == "Level" then
			level = d
		end
	end
end
check(
	title and title.Text == "LEVEL UP" and level and level.Text == "LEVEL 7",
	"The plate doesn't say LEVEL UP and LEVEL 7"
)

-- Over time.
local function columnTop(t)
	Fx.pose(effect, t)
	return effect.Column.Size.X, effect.Column.Transparency
end
local tall0 = columnTop(0.02)
local tallUp, seen = columnTop(0.4)
check(tallUp > tall0 * 4 and tallUp >= 5 * 2.6, "The column doesn't shoot up past the body: " .. tallUp)
check(seen < 0.6, "The column isn't bright as it rises")
local _, gone = columnTop(1.3)
check(gone >= 0.99, "The column hasn't faded by 1.3s")
-- (It stands on the feet: its bottom at the ground.)
Fx.pose(effect, 0.5)
local bottom = effect.Column.CFrame.Position.Y - effect.Column.Size.X / 2
check(math.abs(bottom - 0) < 0.01, "The column doesn't rise out of the ground")
-- The rings run out, the second after the first.
Fx.pose(effect, 0.1)
local r1a, r2a = effect.Rings[1].Size.Y, effect.Rings[2].Size.Y
Fx.pose(effect, 0.5)
local r1b, r2b = effect.Rings[1].Size.Y, effect.Rings[2].Size.Y
check(r1b > r1a and r2b > r2a, "The rings don't run out")
check(r1b > r2b, "The second ring isn't behind the first")
check(effect.Rings[1].CFrame.Position.Y < 0.2, "A ring off the ground")
Fx.pose(effect, 1.2)
check(effect.Rings[1].Transparency >= 0.99 and effect.Rings[2].Transparency >= 0.99, "The rings linger")
-- The sparks spiral up and close in.
Fx.pose(effect, 0.4)
local low, wide = 0, 0
for _, mote in effect.Motes do
	local p = mote.CFrame.Position - feet.Position
	low += p.Y
	wide += Vector3.new(p.X, 0, p.Z).Magnitude
end
Fx.pose(effect, 1.3)
local high, narrow = 0, 0
for _, mote in effect.Motes do
	local p = mote.CFrame.Position - feet.Position
	high += p.Y
	narrow += Vector3.new(p.X, 0, p.Z).Magnitude
end
check(high > low and narrow < wide, "The sparks don't spiral up and in")
-- The flash dies away.
Fx.pose(effect, 0.05)
local bright = effect.Light.Brightness
Fx.pose(effect, 1)
check(bright > 4 and effect.Light.Brightness == 0, "The flash doesn't die away")
-- The plate pops in, settles, and fades at the very end.
Fx.pose(effect, 0)
local small = effect.Pop.Scale
Fx.pose(effect, 0.12)
local big = effect.Pop.Scale
Fx.pose(effect, 0.6)
check(small < 0.8 and big > 1.05 and effect.Pop.Scale == 1, "The plate doesn't pop in")
check(effect.Group.GroupTransparency == 0, "The plate isn't there in the middle")
Fx.pose(effect, Fx.Seconds - 0.01)
check(effect.Group.GroupTransparency > 0.9, "The plate doesn't fade at the end")
check(plate.StudsOffset.Y > 5, "The plate isn't over the head")

-- A kaiju's, at its size: smaller, its own colour.
local small = Fx.build(feet, 2, Color3.fromRGB(80, 200, 255), "EMBERCLAW", 5)
Fx.pose(small, 0.4)
check(
	small.Column.Size.Y < effect.Column.Size.Y and small.Column.Color == Color3.fromRGB(80, 200, 255),
	"A kaiju's isn't at its size, in its colour"
)

-- Stepped: it follows its body and is gone after Seconds.
local body = R.Instance.new("Part")
body.CFrame = CFrame.new(0, 3, 0)
body.Parent = workspace
local followed = Fx.build(CFrame.new(0, 0, 0), 5, color, "LEVEL UP", 2)
followed.Follow, followed.Below = body, 3
followed.Model.Parent = workspace
table.insert(Fx._live, followed)
Fx.step(0.1)
body.CFrame = CFrame.new(12, 3, 0)
Fx.step(0.1)
check((followed.Feet.Position - Vector3.new(12, 0, 0)).Magnitude < 1e-6, "It doesn't follow its body")
for _ = 1, math.ceil(Fx.Seconds / 0.1) + 2 do
	Fx.step(0.1)
end
local ok, parent = pcall(function()
	return followed.Model.Parent
end)
check(#Fx._live == 0 and (not ok or parent == nil), "Still there after its time")

-- The server sends them, and the client draws them.
local progress = fs.readFile(ROOT .. "/src/server/Systems/Progress.luau")
check(progress:find('"LevelUp"', 1, true) and progress:find('"Miner"', 1, true), "A miner's level up isn't sent")
local kaiju = fs.readFile(ROOT .. "/src/server/Systems/KaijuServer.luau")
check(kaiju:find('fx%(%s*"LevelUp",%s*pet%.Model') ~= nil, "A kaiju's level up isn't sent")
check(kaiju:find('fx("CallBack"', 1, true) and kaiju:find('fx("Deploy"', 1, true), "Call back and deploy aren't sent")
local combat = fs.readFile(ROOT .. "/src/client/Combat.client.luau")
for _, name in { "LevelUp", "CallBack", "Deploy" } do
	check(
		combat:find("handlers." .. name .. " = require(script.Parent.Modules.LevelUpFx)", 1, true) ~= nil,
		name .. " isn't drawn"
	)
end
local sound = fs.readFile(ROOT .. "/src/client/Modules/CombatSound.luau")
for _, name in { "LevelUp", "KaijuLevelUp", "CallBack", "Deploy" } do
	check(
		sound:find("\t" .. name .. " = 0, --", 1, true) and sound:find("\t" .. name .. " = {", 1, true),
		name .. " has no sound"
	)
end

-- Your card (the banner): where it goes, a computer's and a phone's.
local Vector2 = R.Vector2
local MobileLayout = load("MobileLayout")
local desk = Fx.cardLayout(Vector2.new(1366, 710), false)
check(
	math.abs(desk.X + desk.W / 2 - 683) <= 1 and desk.Y >= 60 and not desk.Stacked,
	"A computer's card isn't across the top middle"
)
local function inside(r, screen)
	return r.X >= 0 and r.Y >= 0 and r.X + r.W <= screen.X and r.Y + r.H <= screen.Y
end
for _, size in { { 667, 339 }, { 736, 378 }, { 812, 317 }, { 844, 332 }, { 896, 356 }, { 932, 372 } } do
	local screen = Vector2.new(size[1], size[2])
	local L = Fx.cardLayout(screen, true)
	local what = size[1] .. "x" .. size[2]
	check(inside(L, screen), what .. ": the card runs off the screen")
	check(L.Y <= 8 and L.H <= screen.Y * 0.45, what .. ": the card isn't at the top, or is too tall")
	for name, r in
		{
			["pick card"] = MobileLayout.card(),
			toast = MobileLayout.toast(screen),
			["loot card"] = MobileLayout.loot(screen),
		}
	do
		check(not MobileLayout.overlaps(L, r), what .. ": the card covers the " .. name)
	end
	check(L.Stacked == (L.W < Fx.Card.Wide), what .. ": side by side without the room")
end

-- At rest: the medal with the new level (the old one ready to roll out),
-- what it says, a kaiju's name kept as it is (not translated).
local function find(root, name)
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end
local mine = Fx.card(12, { "+1 augment point, +5 max health. Spend points with K." }, Fx.Miner, nil, desk)
check(mine.Root.Name == "LevelUpCard" and mine.Number.Text == "12" and mine.Old.Text == "11", "The medal's numbers")
check(
	find(mine.Root, "Kicker").Text == "YOU REACHED LEVEL 12" and find(mine.Root, "Headline").Text == "LEVEL UP!",
	"Your card doesn't say LEVEL UP! and the level"
)
check(find(mine.Root, "Detail") ~= nil and find(mine.Root, "Detail").TextWrapped, "What it brought isn't there")
check(find(mine.Root, "Headline"):GetAttribute("NoTranslate") == nil, "LEVEL UP! isn't translated")
local pet = Fx.card(10, { "Its R move, Magma Breaker, awakens." }, Color3.fromRGB(255, 96, 64), "THERMAL BULWARK", desk)
check(
	find(pet.Root, "Headline").Text == "THERMAL BULWARK"
		and find(pet.Root, "Headline"):GetAttribute("NoTranslate") == true
		and find(pet.Root, "Kicker").Text == "YOUR KAIJU REACHED LEVEL 10",
	"A kaiju's card doesn't say its name and level"
)
check(
	pet.Ring.Color == Color3.fromRGB(255, 96, 64) and pet.Timer.BackgroundColor3 == Color3.fromRGB(255, 96, 64),
	"A kaiju's card isn't in its colour"
)
check(#mine.Rays >= 4 and #mine.Sparks >= 8, "The medal has no rays or sparks")
local level1 = Fx.card(1, nil, Fx.Miner, nil, desk)
check(level1.Old.Text == "" and find(level1.Root, "Detail") == nil, "Level 1 rolls up from a 0, or shows an empty line")

-- Over time: it comes in from above, the number turns over with a burst of
-- sparks, the line runs down, and it's gone at the end.
local function y(card)
	return card.Root.Position.Y.Offset
end
Fx.poseCard(mine, 0)
check(mine.Body.GroupTransparency >= 0.99 and y(mine) < desk.Y, "The card doesn't come in from above")
Fx.poseCard(mine, 0.3)
check(mine.Old.TextTransparency < 0.5 and mine.Number.TextTransparency > 0.9, "The old level isn't showing first")
Fx.poseCard(mine, 1.2)
check(mine.Body.GroupTransparency == 0 and math.abs(y(mine) - desk.Y) < 0.5, "The card isn't in place")
check(mine.Number.TextTransparency == 0 and mine.Old.TextTransparency >= 0.99, "The number hasn't turned over")
check(math.abs(mine.BadgePop.Scale - 1) < 0.05, "The medal hasn't settled")
local rayTurn = mine.Rays[1].Rotation
Fx.poseCard(mine, Fx.Flip + 0.3)
local sparked = 0
for _, spark in mine.Sparks do
	if spark.BackgroundTransparency < 0.9 then
		sparked += 1
	end
end
check(sparked == #mine.Sparks, "No sparks as the number turns over")
check(mine.Rays[1].Rotation ~= rayTurn, "The rays don't turn")
Fx.poseCard(mine, 1)
local early = mine.Timer.Size.X.Scale
Fx.poseCard(mine, 2.5)
check(mine.Timer.Size.X.Scale < early, "The line doesn't run down")
Fx.poseCard(mine, Fx.CardSeconds - 0.01)
check(
	mine.Body.GroupTransparency > 0.95 and mine.Glow.BackgroundTransparency > 0.95,
	"The card doesn't fade at the end"
)
-- In Spanish too.
local es = load("LangEs")
for _, key in { "LEVEL UP!", "YOU REACHED LEVEL {1}", "YOUR KAIJU REACHED LEVEL {1}", "LV" } do
	check(type(es[key]) == "string", "No Spanish for " .. key)
end

print(
	string.format(
		"PASS: %d level up checks (the column, the rings, the sparks, the flash, the plate, a kaiju's at its size, following its body, gone after %.1fs, sent and drawn, its sounds; your card on a computer and a phone, clear of the top corners, its medal turning over, in Spanish)",
		checks,
		Fx.Seconds
	)
)
