-- lune run tests/first_fight_opening_cases.luau <repo>
-- Round 1's opening (Client FirstFight): once a new miner's first fight is
-- in view (the loading screen and the drop over), the basics on the arena's
-- LED screen (Modules.BasicsScreen), a bobbing arrow over each button a line
-- names: ATTACK, BLOCK, Q / E / R, DODGE. No welcome line before it (the
-- lesson ends on "Your training begins now."). The controls' hint rings wait
-- till it's done. Driven on a clock of its own, with Combat's HUD faked.
-- And the intro's kit roll no longer has a video in front of it.
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

-- The narrator: what's read, in order (its own timing: Narration.Seconds).
local Seconds = { TrainingBegins = 3.5, Controls = 5.9 }
local said = {}
local Narration = {
	play = function(name)
		table.insert(said, { Name = name, At = now })
		return Seconds[name] or 0
	end,
}
function Narration.say(name)
	local seconds = Narration.play(name)
	fakeTask.wait(seconds)
end
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
-- The basics' screen (Modules.BasicsScreen): its lines in turn, two seconds
-- each here, telling the opening which one's up.
local lesson = {}
local BasicsScreen = {
	run = function(onLine)
		for _, line in { "BasicsAttack", "BasicsBlock", "BasicsAbilities", "BasicsDodge", "BasicsResources" } do
			if player:GetAttribute("FirstFight") ~= true then
				break
			end
			table.insert(lesson, line)
			onLine(line)
			fakeTask.wait(2)
		end
		onLine(nil)
	end,
}
local loadingUp = false
local stubs = {
	LoadingFlow = {
		active = function()
			return loadingUp
		end,
	},
	BasicsScreen = BasicsScreen,
	Narration = Narration,
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

local arrowsGui = playerGui:FindFirstChild("FirstFightArrows")
local ringGui = playerGui:FindFirstChild("FirstFightHints")
check(arrowsGui and ringGui, "No arrows or hint rings")
local function up()
	local list = {}
	for _, a in arrowsGui:GetChildren() do
		if arrowsGui.Enabled and a.Visible then
			table.insert(list, (a.Name:gsub("^Arrow", "")))
		end
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- Nothing before the fight.
step(1)
check(#said == 0 and up() == "", "The opening played before the first fight")

-- Round 1 starts, the drop still on (a matched first fight is marked at
-- the match, before its drop), and the loading screen: the lesson waits
-- till the fight's in view.
player:SetAttribute("ArenaDropUntil", 99)
loadingUp = true
player:SetAttribute("FirstFight", true)
step(2)
check(#lesson == 0, "The lesson started under the drop")
player:SetAttribute("ArenaDropUntil", nil)
step(1)
check(#lesson == 0, "The lesson started under the loading screen")
loadingUp = false
step(0.2)
check(#lesson == 0, "The lesson didn't wait a moment once in view")
step(0.6)
check(#said == 0, "A welcome line before the lesson (it ends on its own: \"Your training begins now.\")")
check(lesson[1] == "BasicsAttack", "The basics didn't start once the fight was in view")
check(up() == "Swing", "Attacking: not an arrow on ATTACK: " .. up())
check(not ringGui.Enabled, "A hint ring over the lesson")
local attack = arrowsGui:FindFirstChild("ArrowSwing")
check(attack.Position.X.Offset == 932, "The ATTACK arrow isn't over ATTACK")
step(2)
check(lesson[2] == "BasicsBlock" and up() == "Block", "Blocking: not an arrow on BLOCK: " .. up())
step(2)
check(lesson[3] == "BasicsAbilities" and up() == "E,Q,R", "Abilities: not an arrow on each of Q, E and R: " .. up())
-- (each over its button, a little above)
local q = arrowsGui:FindFirstChild("ArrowQ")
check(q.Position.X.Offset == 132 and q.Position.Y.Offset < 600, "The Q arrow isn't over the Q button")
step(2)
check(lesson[4] == "BasicsDodge" and up() == "Dodge", "Dodging: not an arrow on DODGE: " .. up())
step(2)
check(lesson[5] == "BasicsResources" and up() == "", "Charge and stamina: an arrow on a button")
step(2.2)
check(up() == "" and not arrowsGui.Enabled, "The arrows stayed after the lesson")
step(0.3)
check(ringGui.Enabled, "The hint rings didn't come back after the opening")
check(#said == 0 and #lesson == 5, "Something else was read")

-- Once: a second first fight in the visit has no opening.
player:SetAttribute("FirstFight", nil)
step(0.5)
player:SetAttribute("FirstFight", true)
step(8)
check(#lesson == 5, "The opening played twice")

-- The intro's kit roll: straight to it, no video in front (the lesson's in
-- the arena now), and no music under the lesson (IntroVideo: Client Music).
do
	local intro = fs.readFile(ROOT .. "/src/client/Intro.client.luau")
	check(not intro:find("BasicsScreen", 1, true), "The kit roll still has the basics' video in front of it")
	local screen = fs.readFile(ROOT .. "/src/client/Modules/BasicsScreen.luau")
	check(screen:find('player:SetAttribute("IntroVideo", true)', 1, true) and screen:find('player:SetAttribute("IntroVideo", nil)', 1, true), "The lesson doesn't hold the music")
	local music = fs.readFile(ROOT .. "/src/client/Music.client.luau")
	check(music:find('"IntroVideo"', 1, true) and music:find('if attributes.IntroVideo then\n\t\tmood = "Silence"', 1, true), "Music plays over the lesson")
end

-- A friend request lets the mouse go (the combat view held it in the middle:
-- Roblox's pop-up couldn't be clicked without knowing Tab), and says where.
do
	local combat = fs.readFile(ROOT .. "/src/client/Combat.client.luau")
	local at = combat:find("player.FriendStatusChanged:Connect", 1, true)
	local body = at and combat:sub(at, combat:find("\nend %-%- ", at) or #combat) or ""
	check(body:find("Enum.FriendStatus.FriendRequestReceived", 1, true) and body:find("FirstPerson.setCursorFree(true)", 1, true) and body:find("UiKit.toast(", 1, true), "A friend request leaves the mouse locked")
end

print(string.format("PASS: %d first fight opening checks (the basics on the arena's screen once the fight's in view, an arrow on each line's button: ATTACK, BLOCK, Q/E/R, DODGE; no music under it; no video before the roll)", checks))
process.exit(0)
