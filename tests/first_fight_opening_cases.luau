-- lune run tests/first_fight_opening_cases.luau <repo>
-- A new miner's first fight (Client FirstFight): no lesson in it any more
-- (the basics are a video of their own before the element roll: Client
-- Intro, Modules.BasicsScreen), so nothing's read and the controls' hint
-- rings come up at once. Driven on a clock of its own, with Combat's HUD
-- faked. And Intro: the video, then the roll.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local Instance, Vector2 = roblox.Instance, roblox.Vector2
local checks = 0
local function check(value, message)
	checks += 1
	if not value then
		require("@lune/stdio").ewrite("FAIL: " .. tostring(message) .. "\n")
		process.exit(1)
	end
end

-- A clock, threads that wait on it, and each frame.
local now = 0
local sleeping = {}
local fakeTask = {}
function fakeTask.wait(seconds)
	table.insert(sleeping, { At = now + (seconds or 0), Thread = coroutine.running() })
	return coroutine.yield()
end
function fakeTask.spawn(fn, ...)
	local thread = coroutine.create(fn)
	local ok, problem = coroutine.resume(thread, ...)
	check(ok, "A thread failed: " .. tostring(problem))
	return thread
end
function fakeTask.delay(seconds, fn, ...)
	local args = { ... }
	fakeTask.spawn(function()
		fakeTask.wait(seconds)
		fn(table.unpack(args))
	end)
end
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, fn in list do
				fn(...)
			end
		end,
	}
end
local renderStepped, heartbeat = signal(), signal()
local function step(seconds)
	local stop = now + seconds
	while now < stop - 1e-9 do
		now += 1 / 60
		local due = {}
		for i = #sleeping, 1, -1 do
			if sleeping[i].At <= now then
				table.insert(due, table.remove(sleeping, i))
			end
		end
		for _, s in due do
			local ok, problem = coroutine.resume(s.Thread)
			check(ok, "A thread failed: " .. tostring(problem))
		end
		heartbeat:Fire(1 / 60)
		renderStepped:Fire(1 / 60)
	end
end

-- The player: attributes, and a PlayerGui with Combat's HUD in it (its
-- buttons tagged as Combat tags them).
local attributes, changed = {}, {}
local playerGui = Instance.new("Folder")
playerGui.Name = "PlayerGui"
local player = {
	UserId = 1,
	PlayerGui = playerGui,
	Character = nil,
	CharacterAdded = signal(),
}
function player:GetAttribute(name)
	return attributes[name]
end
function player:SetAttribute(name, value)
	attributes[name] = value
	if changed[name] then
		changed[name]:Fire()
	end
end
function player:GetAttributeChangedSignal(name)
	changed[name] = changed[name] or signal()
	return changed[name]
end
local hud = Instance.new("ScreenGui")
hud.Name = "CombatHud"
hud.Parent = playerGui
-- (by name: lune hands back a fresh object for each look at an instance)
local spots = {}
local function button(name, tag, key, x)
	local b = Instance.new("TextButton")
	b.Name = name
	b:SetAttribute("TutorialTarget", tag)
	if key then
		b:SetAttribute("HintKey", key)
	end
	b.Parent = hud
	spots[name] = Vector2.new(x, 600)
	return b
end
button("Q", "Surge", "Q", 100)
button("E", "Surge", "E", 200)
button("R", "Surge", "R", 300)
button("Attack", "Basic", nil, 900)
button("Block", "Block", nil, 1000)
button("Dodge", "Dodge", nil, 1100)

local UiKit = {
	gui = function(name)
		local g = Instance.new("ScreenGui")
		g.Name = name
		g.Parent = playerGui
		return g
	end,
}
local IronUi = {
	new = function(class, props, parent)
		local i = Instance.new(class)
		for k, v in props or {} do
			i[k] = v
		end
		i.Parent = parent
		return i
	end,
}
local stubs = {
	UiKit = UiKit,
	IronUi = IronUi,
	GemClient = { Profile = { Character = {} } },
	FastStart = {
		Enabled = true,
		Urgent = {},
		complete = function() end,
		finished = function()
			return false
		end,
		-- (the controls' hints: a Swing ring the moment one's allowed)
		hint = function()
			return "Swing"
		end,
	},
	CombatTechnology = {
		surgeGem = function() return nil end,
	},
}
local names = setmetatable({}, { __index = function(_, k) return k end })
names.Modules = names
names.Shared = names
local source = fs.readFile(ROOT .. "/src/client/FirstFight.client.luau")
-- (Lune's instances have no on-screen size or place: Combat's buttons', here.)
source = source:gsub("([%w_]+)%.AbsoluteSize", "__size(%1)"):gsub("([%w_]+)%.AbsolutePosition", "__pos(%1)")
local env = setmetatable({
	game = {
		GetService = function(_, name)
			if name == "Players" then
				return { LocalPlayer = player, GetPlayers = function() return { player } end }
			elseif name == "RunService" then
				return { RenderStepped = renderStepped, Heartbeat = heartbeat }
			elseif name == "ReplicatedStorage" then
				return { Shared = names }
			end
			return {}
		end,
	},
	workspace = {
		FindFirstChild = function() return nil end,
		GetServerTimeNow = function() return now end,
	},
	script = { Parent = names },
	require = function(name)
		return stubs[name] or error("no stub for " .. tostring(name))
	end,
	task = fakeTask,
	os = { clock = function() return now end, time = os.time },
	Instance = Instance,
	Vector2 = Vector2,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
	__size = function(i)
		return if i:IsA("TextButton") and spots[i.Name] then Vector2.new(64, 64) else Vector2.new(0, 0)
	end,
	__pos = function(i)
		return (i:IsA("TextButton") and spots[i.Name]) or Vector2.new(0, 0)
	end,
}, { __index = _G })
luau.load(source, { debugName = "FirstFight", environment = env })()

local ringGui = playerGui:FindFirstChild("FirstFightHints")
check(ringGui, "No hint rings")
check(playerGui:FindFirstChild("FirstFightArrows") == nil, "The lesson's arrows are still in the fight")

-- Nothing before the fight.
step(1)
check(not ringGui.Enabled, "A hint ring before the first fight")

-- Round 1 starts: the hint rings at once (no welcome, no lesson to wait for).
player:SetAttribute("FirstFight", true)
step(0.3)
check(ringGui.Enabled, "The hint rings didn't come up as the first fight started")

-- Intro: the basics' video first (a fresh miner's, not a rejoin with a
-- kit rolled already), then the element roll.
do
	local intro = fs.readFile(ROOT .. "/src/client/Intro.client.luau")
	local block = intro:find("\nif not FastStart.Pick then\n\t%-%- First the combat basics")
	check(block, "Intro doesn't open the no-picker flow with the basics' video")
	local fresh = intro:find("if not savedKit then", block, true)
	local video = intro:find("pcall(BasicsScreen.run, function()", block, true)
	local loaded = intro:find("LoadingFlow.active()", block, true)
	local roll = intro:find('GemClient.request("PrepareStarterLottery")', block, true)
	check(fresh and video and roll and fresh < video and video < roll, "The basics' video doesn't come before the element roll")
	check(loaded and loaded > video and loaded < roll, "The basics' video doesn't wait for the loading screen")
	-- No music till it's over: Intro marks it (IntroVideo), Music goes quiet.
	local quiet = intro:find('me:SetAttribute("IntroVideo", true)', block, true)
	check(quiet and quiet < video, "The music isn't held from the start of the intro")
	local music = fs.readFile(ROOT .. "/src/client/Music.client.luau")
	check(music:find('"IntroVideo"', 1, true) and music:find('if attributes.IntroVideo then\n\t\tmood = "Silence"', 1, true), "Music plays over the basics' video")
end

-- A friend request lets the mouse go (the combat view held it in the middle:
-- Roblox's pop-up couldn't be clicked without knowing Tab), and says where.
do
	local combat = fs.readFile(ROOT .. "/src/client/Combat.client.luau")
	local at = combat:find("player.FriendStatusChanged:Connect", 1, true)
	local body = at and combat:sub(at, combat:find("\nend %-%- ", at) or #combat) or ""
	check(body:find("Enum.FriendStatus.FriendRequestReceived", 1, true) and body:find("FirstPerson.setCursorFree(true)", 1, true) and body:find("UiKit.toast(", 1, true), "A friend request leaves the mouse locked")
end

print(string.format("PASS: %d first fight opening checks (the basics' video before the roll, after the loading, no music under it; no lesson in the fight, the hint rings at once)", checks))
process.exit(0)
