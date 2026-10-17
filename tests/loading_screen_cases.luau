-- lune run tests/loading_screen_cases.luau <repo>
-- The loading screen (ReplicatedFirst.LoadingScreen) and when it comes down
-- between scenes (Client LoadingFlow), on a stand-in clock, frames and GUI:
--   * covers: up at once or faded in, held at least Min, never past Max,
--     the newest one's words shown, gone (and not drawn) once they're done;
--   * what's behind counts as ready only once you're alive, somewhere you
--     belong, where you were headed, on loaded ground, with the camera on
--     you and not still being moved, its downloads done or AssetWait spent;
--     a full-screen view of its own (the intro, the Arena drop's screen)
--     takes over at once;
--   * a hold asked for while such a view is already up shows nothing.
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

-- The clock and frames.
local now = 100
local frameHandlers = {}
local bound = {}
local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			handlers[fn] = true
			return {
				Disconnect = function()
					handlers[fn] = nil
				end,
			}
		end,
		Handlers = handlers,
		Fire = function(_, ...)
			for fn in handlers do
				fn(...)
			end
		end,
	}
end
local renderStepped = signal()
local RunService = {
	RenderStepped = renderStepped,
	BindToRenderStep = function(_, name, _, fn)
		bound[name] = fn
	end,
	UnbindFromRenderStep = function(_, name)
		bound[name] = nil
	end,
}
local muted = {}
local function frame(dt)
	now += dt
	for name, fn in bound do
		if not muted[name] then
			fn(dt)
		end
	end
	for fn in renderStepped.Handlers do
		fn(dt)
	end
end
local function run(seconds)
	local target = now + seconds
	while now < target - 1e-9 do
		frame(1 / 60)
	end
end

-- Stand-in instances: properties kept, children by name, signals inert.
local Fake = {}
Fake.__index = function(self, key)
	local method = rawget(Fake, key)
	if method then
		return method
	end
	if key == "AbsoluteSize" then
		return roblox.Vector2.new(1280, 720)
	end
	return rawget(self, "_props")[key]
end
Fake.__newindex = function(self, key, value)
	local props = rawget(self, "_props")
	if key == "Parent" then
		local old = props.Parent
		if old then
			rawget(old, "_children")[self] = nil
		end
		if value then
			rawget(value, "_children")[self] = true
		end
	end
	props[key] = value
end
function Fake.GetPropertyChangedSignal()
	return signal()
end
function Fake.FindFirstChild(self, name)
	for child in rawget(self, "_children") do
		if child.Name == name then
			return child
		end
	end
	return nil
end
function Fake.FindFirstChildOfClass(self, class)
	for child in rawget(self, "_children") do
		if child.ClassName == class then
			return child
		end
	end
	return nil
end
function Fake.IsA(self, class)
	return self.ClassName == class
end
function Fake.GetAttribute(self, name)
	return rawget(self, "_attributes")[name]
end
function Fake.SetAttribute(self, name, value)
	rawget(self, "_attributes")[name] = value
end
local function fake(class)
	return setmetatable({ _props = { ClassName = class, Name = class }, _children = {}, _attributes = {} }, Fake)
end
local Instance = { new = fake }

-- Random, as Roblox has it.
local Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ s = seed or 1 }, Random)
end
function Random:NextNumber(a, b)
	self.s = (self.s * 1103515245 + 12345) % 2147483648
	a, b = a or 0, b or 1
	return a + (b - a) * self.s / 2147483648
end
function Random:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end

local playerGui = fake("PlayerGui")
local player = fake("Player")
player.Character = nil
function player.WaitForChild()
	return playerGui
end
playerGui.Parent = player
local env = {
	Instance = Instance,
	Random = Random,
	Enum = roblox.Enum,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Vector2 = roblox.Vector2,
	Vector3 = roblox.Vector3,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	os = {
		clock = function()
			return now
		end,
	},
	task = {
		wait = function()
			frame(1 / 60)
		end,
		spawn = function(fn, ...)
			fn(...)
		end,
	},
}
local services = {
	Players = { LocalPlayer = player },
	RunService = RunService,
	ContentProvider = { RequestQueueSize = 0 },
	ReplicatedStorage = { Shared = { Config = "Config" } },
}
local LoadingScreen
services.ReplicatedFirst = {
	FindFirstChild = function()
		return "LoadingScreen"
	end,
	WaitForChild = function()
		return "LoadingScreen"
	end,
}
local function load(path, extra)
	local environment = {}
	for key, value in env do
		environment[key] = value
	end
	for key, value in extra or {} do
		environment[key] = value
	end
	environment = setmetatable(environment, { __index = _G })
	environment.game = {
		GetService = function(_, name)
			return services[name]
		end,
	}
	return luau.load(fs.readFile(ROOT .. path), { debugName = path, environment = environment })()
end
LoadingScreen = load("/src/first/LoadingScreen.luau")

-- 1. The rules (pure).
local function cover(since, released, min, max, status)
	return { Since = since, Released = released, Min = min, Max = max, Status = status }
end
check(LoadingScreen.wanted({}, 0) == false, "nothing wanted it, yet it's up")
check(LoadingScreen.wanted({ cover(0, false, 1, 10) }, 5) == true, "a cover still held came down")
check(LoadingScreen.wanted({ cover(0, true, 1, 10) }, 0.5) == true, "a cover released early came down before its Min")
check(LoadingScreen.wanted({ cover(0, true, 1, 10) }, 1.5) == false, "a released cover stayed past its Min")
check(LoadingScreen.wanted({ cover(0, false, 1, 10) }, 10.5) == false, "a cover stayed past its Max")
local _, says = LoadingScreen.wanted({ cover(0, false, 1, 10, "Old"), cover(2, false, 1, 10, "New") }, 3)
check(says == "New", "the newest cover's words aren't the ones shown")

-- 2. Up at once, held, then faded away.
local join = LoadingScreen.cover("Join", { Status = "Loading the game", Instant = true, Min = 1.2, Max = 60 })
local gui = playerGui:FindFirstChild("LoadingScreen")
check(gui ~= nil and gui.Enabled == true, "the loading screen isn't shown")
check(LoadingScreen.covered(), "an instant cover isn't opaque at once")
local backdrop = gui:FindFirstChild("Backdrop")
check(backdrop.BackgroundTransparency == 0 and backdrop.Active == true, "the backdrop doesn't cover and take clicks")
frame(1 / 60)
local statusLabel
local function find(root, test)
	for child in rawget(root, "_children") do
		if test(child) then
			return child
		end
		local inner = find(child, test)
		if inner then
			return inner
		end
	end
	return nil
end
statusLabel = find(gui, function(c)
	return c.ClassName == "TextLabel" and c.Font == roblox.Enum.Font.GothamMedium
end)
check(statusLabel and statusLabel.Text == "LOADING THE GAME", "the status line doesn't say what's loading")
local tipLabel = find(gui, function(c)
	return c.ClassName == "TextLabel" and type(c.Text) == "string" and string.find(c.Text, "TIP", 1, true) == 1
end)
check(tipLabel ~= nil, "no tip is shown")
local firstTip = tipLabel.Text
run(LoadingScreen.TipSeconds + 0.1)
check(tipLabel.Text ~= firstTip, "the tip never changes")

-- The tips follow how far you've got: a new player gets the basics, a miner
-- learns about gems, an old hand about sets and Ranked.
check(LoadingScreen.stage(nil) == 1 and LoadingScreen.stage({}) == 1, "nothing known isn't a new player")
check(LoadingScreen.stage({ Rocks = 4 }) == 1, "a few rocks with no gem moved past the start")
check(
	LoadingScreen.stage({ Mined = true }) == 2 and LoadingScreen.stage({ Rocks = 10 }) == 2,
	"a first gem (or 10 rocks) didn't move on"
)
check(LoadingScreen.stage({ Mined = true, Level = 5 }) == 3, "level 5 isn't an old hand")
check(
	LoadingScreen.stage({ Fights = 5 }) == 3 and LoadingScreen.stage({ Rocks = 150 }) == 3,
	"fights or rocks don't make an old hand"
)
local function has(list, words)
	for _, text in list do
		if string.find(text, words, 1, true) then
			return true
		end
	end
	return false
end
local seen, all = {}, 0
for stage = 1, 3 do
	local list = LoadingScreen.tipsFor(stage)
	check(#list >= 3, "stage " .. stage .. " has too few tips")
	for _, text in list do
		check(#text <= 140, "a tip too long for its two lines: " .. text)
		if not seen[text] then
			seen[text], all = true, all + 1
		end
	end
end
check(all == #LoadingScreen.Tips and all == 10, "every tip shows at some stage")
local new, miner, old = LoadingScreen.tipsFor(1), LoadingScreen.tipsFor(2), LoadingScreen.tipsFor(3)
check(has(new, "Mine gems") and not has(new, "graded") and not has(new, "Ranked"), "a new player gets the wrong tips")
check(string.find(miner[1], "rarer the gem", 1, true) ~= nil, "a miner's tips don't lead with what's new to them")
check(
	has(miner, "graded") and has(miner, "Mine gems") and not has(miner, "build Charge"),
	"a miner gets the wrong tips"
)
check(
	has(old, "Ranked") and has(old, "armor set") and not has(old, "Mine gems") and has(old, "parry"),
	"an old hand gets the wrong tips"
)
-- A new stage takes over from the next tip.
LoadingScreen.setStage(3)
run(LoadingScreen.TipSeconds + 0.1)
check(tipLabel.Text == "TIP  ·  " .. old[1], "a new stage didn't start from its first tip")
run(LoadingScreen.TipSeconds + 0.1)
check(tipLabel.Text == "TIP  ·  " .. old[2], "the tips stopped rotating")
LoadingScreen.setStage(3)
run(LoadingScreen.TipSeconds + 0.1)
check(tipLabel.Text == "TIP  ·  " .. old[3], "the same stage again started over")
LoadingScreen.setStage(1)
join.release()
check(LoadingScreen.active() == false, "a cover released past its Min still wants the screen")
frame(1 / 60)
check(not LoadingScreen.covered() and gui.Enabled == true, "the screen didn't start fading")
run(LoadingScreen.FadeOut + 0.05)
check(gui.Enabled == false, "the screen is still drawn after fading away")
check(next(renderStepped.Handlers) == nil, "the screen still runs every frame once gone")
check(backdrop.Active == false, "a gone screen still takes clicks")

-- 3. Faded in; a quick release still holds its Min; Max lets go.
local trip = LoadingScreen.cover("Trip", { FadeIn = 0.3, Min = 1, Max = 15 })
frame(1 / 60)
check(not LoadingScreen.covered(), "a fading cover was opaque at once")
run(0.32)
check(LoadingScreen.covered(), "a fading cover isn't opaque after its FadeIn")
trip.release()
run(0.3)
check(LoadingScreen.covered(), "a cover released early came down before its Min")
run(1 + LoadingScreen.FadeOut)
check(gui.Enabled == false, "a released cover stayed up")
LoadingScreen.cover("Stuck", { Instant = true, Max = 2 })
run(2 + LoadingScreen.FadeOut + 0.05)
check(gui.Enabled == false, "a cover nobody released stayed past its Max")
LoadingScreen.progress(0.5)
LoadingScreen.cover("Bar", { Instant = true, Min = 0 }).release()
frame(1 / 60)
local fill = find(gui, function(c)
	return c.ClassName == "Frame" and c.Size and c.Size.X.Scale == 0.5 and c.Size.Y.Scale == 1
end)
check(fill ~= nil, "a known progress isn't drawn on the bar")
run(1)

-- 4. When what's behind is ready (pure).
local Config = { MenuOnly = true }
-- The world LoadingFlow reads: the camera, the ground under you, whether
-- the Outpost scene is on (MineScene.isActive counts it).
local outpostActive, groundLoaded = false, true
local camera = { CFrame = roblox.CFrame.new(0, 300, 0) }
local LoadingFlow = load("/src/client/Modules/LoadingFlow.luau", {
	require = function(name)
		if name == "Config" then
			return Config
		elseif name == "LoadingScreen" then
			return LoadingScreen
		elseif name == "MineScene" then
			return {
				isActive = function()
					return outpostActive
				end,
			}
		end
		return require(name)
	end,
	script = { Parent = { MineScene = "MineScene" } },
	workspace = {
		GetServerTimeNow = function()
			return now
		end,
		Raycast = function()
			return if groundLoaded then {} else nil
		end,
		CurrentCamera = camera,
	},
	RaycastParams = {
		new = function()
			return {}
		end,
	},
	setmetatable = setmetatable,
	typeof = function(value)
		return typeof(value)
	end,
})
local function snap(changes)
	local s = {
		Owned = false,
		Alive = true,
		Scene = true,
		Arrived = true,
		Grounded = true,
		Camera = true,
		Settling = false,
		Queue = 0,
	}
	for key, value in changes or {} do
		s[key] = value
	end
	return s
end
check(LoadingFlow.ready(snap()) == true, "a ready world isn't ready")
check(
	LoadingFlow.ready(snap({ Owned = true, Alive = false, Scene = false })) == true,
	"a full-screen view of its own isn't ready"
)
local ok, why = LoadingFlow.ready(snap({ Alive = false }))
check(not ok and why == "Waiting for your miner", "no miner yet counts as ready")
check(LoadingFlow.ready(snap({ Scene = false })) == false, "nowhere you belong (the menu's view) counts as ready")
check(LoadingFlow.ready(snap({ Arrived = false })) == false, "not yet where you were headed counts as ready")
ok, why = LoadingFlow.ready(snap({ Grounded = false }))
check(not ok and why == "Loading the area", "no ground loaded under you counts as ready")
check(LoadingFlow.ready(snap({ Camera = false })) == false, "the camera elsewhere counts as ready")
check(LoadingFlow.ready(snap({ Settling = true })) == false, "still being moved counts as ready")

-- 5. Holds, a frame at a time (on a stand-in world: the game's own
-- per-frame step is muted).
muted.LoadingFlowHolds = true
local world = snap()
local function look()
	return table.clone(world)
end
local function step(seconds)
	local target = now + seconds
	while now < target - 1e-9 do
		frame(1 / 60)
		LoadingFlow.step(now, look)
	end
end
-- On its way: not before Min, even though it's ready at once.
world = snap({ Arrived = false })
local outbound = LoadingFlow.hold("Outpost", { Instant = true })
check(LoadingScreen.covered(), "a hold doesn't put the screen up")
step(0.5)
check(LoadingScreen.active(), "a hold still on its way came down")
world = snap({ Settling = true }) -- (just landed)
step(0.2)
check(LoadingScreen.active(), "a hold came down while you were still being moved")
world = snap({ Queue = 12 }) -- (landed; textures and meshes still coming)
step(1)
check(LoadingScreen.active(), "a hold came down with the area still downloading")
step(LoadingFlow.AssetWait)
check(not LoadingScreen.active(), "a hold waited on downloads past AssetWait")
check(outbound.Done, "a finished hold isn't marked done")
run(1)
-- Ready at once: held Min, no more.
world = snap()
LoadingFlow.hold("Arena", { Instant = true })
step(LoadingFlow.Min - 0.1)
check(LoadingScreen.active(), "a hold came down before its Min")
step(0.15)
check(not LoadingScreen.active(), "a ready hold stayed past its Min")
run(1)
-- A full-screen view of its own takes over at once.
world = snap({ Scene = false })
LoadingFlow.hold("Intro", { Instant = true })
step(0.2)
world = snap({ Owned = true })
step(1 / 60)
check(not LoadingScreen.active(), "a hold stayed up over the Arena drop's own screen")
run(1)
-- Never past Max.
world = snap({ Alive = false })
LoadingFlow.hold("Respawn", { Instant = true, Max = 3 })
step(2.9)
check(LoadingScreen.active(), "a hold waiting on your miner came down early")
step(0.2)
check(not LoadingScreen.active(), "a hold stayed past its Max")
run(1)
-- A request that failed: down at once.
world = snap({ Arrived = false })
local failed = LoadingFlow.hold("Outpost", { Instant = true })
step(0.1)
failed.cancel()
step(1 / 60)
check(not LoadingScreen.active(), "a cancelled hold stayed up")
run(1)
-- What it says follows what it's waiting on.
world = snap({ Grounded = false })
LoadingFlow.hold("Teleport", { Instant = true, Status = "Loading the area" })
step(0.1)
check(statusLabel.Text == "LOADING THE AREA", "the status doesn't say what it's waiting on")
world = snap({ Alive = false })
step(0.1)
check(statusLabel.Text == "WAITING FOR YOUR MINER", "the status didn't follow what it's waiting on")
world = snap()
step(LoadingFlow.Min)
run(1)

-- 6. Where you're headed when free: the Outpost, unless you're busy elsewhere.
local landmarks = fake("Folder")
landmarks:SetAttribute("OutpostSpawn", roblox.CFrame.new(10, 20, 30))
services.ReplicatedStorage.FindFirstChild = function(_, name)
	return if name == "Landmarks" then landmarks else nil
end
player.GetAttribute = function(_, name)
	return rawget(player, "_attributes")[name]
end
local home = LoadingFlow.home()
check(home and home == roblox.Vector3.new(10, 20, 30), "the way home isn't the Outpost's spawn")
player:SetAttribute("CombatSession", "Duel")
check(LoadingFlow.home() == nil, "a fighter is sent home to the Outpost")
player:SetAttribute("CombatSession", nil)
Config.MenuOnly = false
check(LoadingFlow.home() == nil, "with the town back on, there's still an Outpost to head to")

-- 7. A hold asked for while a full-screen view of its own is up (the
-- intro) shows nothing; once that view is closing, it covers.
Config.MenuOnly = true
muted.LoadingFlowHolds = nil
services.ContentProvider.PreloadAsync = function() end
local intro = fake("ScreenGui")
intro.Name, intro.Enabled = "Intro", true
intro.Parent = playerGui
LoadingFlow.hold("Teleport", { Instant = true })
check(not LoadingScreen.active(), "the loading screen went up over the intro")
intro:SetAttribute("Closing", true)
LoadingFlow.hold("Intro", { Instant = true, Min = 0.2 })
check(LoadingScreen.covered(), "the loading screen didn't take over from the closing intro")
intro.Parent = nil
run(0.3)

-- 8. The game's own reading of the world: a fight ends, you're moved back
-- to the Outpost, the area loads round you; and a jump nothing covered.
local character = fake("Model")
local root = fake("Part")
root.Name, root.Position = "HumanoidRootPart", roblox.Vector3.new(500, 0, 500) -- (in the arena)
rawset(root, "IsA", function(_, class)
	return class == "BasePart" or class == "Part"
end)
root.Parent = character
local humanoid = fake("Humanoid")
humanoid.Health = 100
humanoid.Parent = character
player.Character = character
local changed = {}
rawset(player, "GetAttributeChangedSignal", function(_, name)
	changed[name] = changed[name] or signal()
	return changed[name]
end)
rawset(player, "SetAttribute", function(self, name, value)
	rawget(self, "_attributes")[name] = value
	if changed[name] then
		changed[name]:Fire()
	end
end)
player.CharacterAdded = signal()
playerGui.ChildRemoved = signal()
player:SetAttribute("CombatSession", "Training")
camera.CFrame = roblox.CFrame.new(510, 5, 500)
LoadingFlow.start()
frame(1 / 60)
check(not LoadingScreen.active(), "the loading screen is up mid-fight")
player:SetAttribute("CombatSession", nil) -- (the fight's over)
check(LoadingScreen.covered(), "the end of a fight isn't covered at once")
run(1)
check(LoadingScreen.active(), "the cover came down before you were moved")
root.Position = roblox.Vector3.new(10, 20, 30) -- (the server moves you back)
outpostActive = true
camera.CFrame = roblox.CFrame.new(10, 30, 45)
groundLoaded = false
run(0.5)
check(LoadingScreen.active(), "the cover came down with no ground loaded under you")
groundLoaded = true
run(LoadingFlow.Settle + 0.05)
check(not LoadingScreen.active(), "the cover stayed up once you were standing in the Outpost")
run(1)
-- A jump nobody covered: covered before the frame is drawn, down once landed.
root.Position = roblox.Vector3.new(10, 20, 600)
camera.CFrame = roblox.CFrame.new(10, 30, 615)
frame(1 / 60)
check(LoadingScreen.covered(), "a long jump wasn't covered at once")
run(LoadingFlow.Min + LoadingFlow.Settle)
check(not LoadingScreen.active(), "a covered jump stayed up once landed")
run(1)
-- Walking about isn't a jump.
for _ = 1, 30 do
	root.Position += roblox.Vector3.new(0.3, 0, 0)
	frame(1 / 60)
end
check(not LoadingScreen.active(), "walking put the loading screen up")
-- A new body is covered until it's back in the Outpost.
root.Position = roblox.Vector3.new(0, 0, 0)
player.CharacterAdded:Fire(character)
check(LoadingScreen.covered(), "a respawn isn't covered")
run(2)
check(LoadingScreen.active(), "the respawn cover came down before you were back in the Outpost")
root.Position = roblox.Vector3.new(10, 20, 30)
camera.CFrame = roblox.CFrame.new(10, 30, 45)
run(LoadingFlow.Min + LoadingFlow.Settle)
check(not LoadingScreen.active(), "the respawn cover stayed up once back in the Outpost")

-- 9. Never in the game's way. With the screen missing from the place (not
-- synced), or broken, the scenes that ask for it carry on uncovered: the
-- title, the lobby and the Outpost once waited for it forever, and the game
-- sat there unstarted.
local warned = {}
local function flowWith(replicatedFirst, requireScreen)
	services.ReplicatedFirst = replicatedFirst
	return load("/src/client/Modules/LoadingFlow.luau", {
		require = function(name)
			if name == "Config" then
				return Config
			elseif name == "LoadingScreen" then
				return requireScreen()
			end
			return require(name)
		end,
		warn = function(message)
			table.insert(warned, message)
		end,
		script = { Parent = {} },
		setmetatable = setmetatable,
	})
end
local missing = flowWith({
	FindFirstChild = function()
		return nil
	end,
	WaitForChild = function()
		return nil -- (as Roblox does once the timeout's up)
	end,
}, function()
	error("Attempted to call require with invalid argument(s).")
end)
check(#warned == 1, "a missing loading screen isn't reported")
local started = now
local hold = missing.hold("Outpost", { Instant = true })
missing.waitCovered(1)
missing.waitClear(60)
check(now == started, "a scene waited on a loading screen that isn't there")
check(hold.Done and not missing.active(), "a missing loading screen counts as up")
hold.cancel()
local broken = flowWith(services.ReplicatedFirst, function()
	error("LoadingScreen:12: something broke")
end)
check(#warned == 2, "a broken loading screen isn't reported")
check(broken.hold("Mine", {}).Done and not broken.active(), "a broken loading screen counts as up")
-- A screen that errors mid-frame takes itself away.
local tips = LoadingScreen.TipSeconds
LoadingScreen.TipSeconds = nil :: any -- (the next tip can't be timed: the frame errors)
LoadingScreen.cover("Breaks", { Instant = true, Max = 60 })
run(LoadingScreen.TipSeconds or 6)
check(gui.Enabled == false and not LoadingScreen.active(), "a broken loading screen stayed up")
LoadingScreen.TipSeconds = tips

print(
	string.format("PASS: %d loading screen checks (covers held, timed and taken down once the scene's ready)", checks)
)
