-- lune run tests/boss_focus_cases.luau <repo>
-- BossFocus: which creature is a fight's boss, who sees its mark, the words
-- on it and its beat (the pure half of src/client/Modules/BossFocus.luau).
local process = require("@lune/process")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local ROOT = process.args[1] or "."
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local services = {
	Players = { LocalPlayer = nil },
	RunService = { RenderStepped = { Connect = function() end } },
}
local BossFocus = luau.load(fs.readFile(ROOT .. "/src/client/Modules/BossFocus.luau"), {
	debugName = "BossFocus",
	environment = setmetatable({
		game = { GetService = function(_, name)
			return services[name]
		end },
		workspace = { FindFirstChild = function()
			return nil
		end },
		Color3 = roblox.Color3,
		Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		Instance = roblox.Instance,
	}, { __index = _G }),
})()

local function attrs(t)
	return function(name)
		return t[name]
	end
end

-- 1. The boss, not the room's fighters.
check(BossFocus.isBoss(attrs({ RaidId = "R1" })), "a party raid's boss isn't marked")
check(BossFocus.isBoss(attrs({ RaidId = "R2", RiftRun = "R2", RiftBoss = true })), "a Rift boss isn't marked")
check(BossFocus.isBoss(attrs({ RaidId = "D3", DungeonId = "D3", DungeonBoss = "Sahur" })), "a dungeon boss isn't marked")
check(not BossFocus.isBoss(attrs({ RaidId = "D3", DungeonId = "D3" })), "a dungeon room's fighter is marked")
check(not BossFocus.isBoss(attrs({ RaidId = "R2", RiftRun = "R2" })), "a Rift room's fighter is marked")
check(not BossFocus.isBoss(attrs({ RivalOwner = 7 })), "an Arena rival is marked")

-- 2. Only the players in its fight see the mark.
local boss = attrs({ RaidId = "R2", RiftRun = "R2", RiftBoss = true })
check(BossFocus.inFight(boss, attrs({ RiftRun = "R2" })), "a runner in the Rift trip doesn't see it")
check(BossFocus.inFight(boss, attrs({ RaidId = "R2" })), "a raider in the raid doesn't see it")
check(not BossFocus.inFight(boss, attrs({ RiftRun = "R9" })), "another trip's runner sees it")
check(not BossFocus.inFight(boss, attrs({ Outpost = true })), "a lobby player sees it")
check(not BossFocus.inFight(attrs({}), attrs({})), "no fight at all still matches")

-- 3. The words: yours call out, the rest just say TARGET.
check(BossFocus.text(true, false) == "ON YOU", "over you it doesn't say ON YOU")
check(BossFocus.text(true, true) == "ON YOUR KAIJU", "over your kaiju it doesn't say so")
check(BossFocus.text(false, false) == "TARGET", "over another player it isn't TARGET")
check(BossFocus.text(false, true) == "TARGET", "over another's kaiju it isn't TARGET")

-- 4. Yours beats, between 1.15 and 1.35; everyone else's holds at 1.
local low, high = math.huge, -math.huge
for i = 0, 40 do
	local s = BossFocus.scale(i * BossFocus.Pulse / 40, true)
	low, high = math.min(low, s), math.max(high, s)
end
check(low >= 1.15 - 1e-6 and high <= 1.35 + 1e-6, "your mark's beat leaves its range")
check(high - low > 0.15, "your mark doesn't beat")
check(BossFocus.scale(0.3, false) == 1 and BossFocus.scale(0.9, false) == 1, "another's mark beats")

-- 5. The wiring: the server names the kaiju it's on, the client faces it
-- and marks it, from the lobby (Rift) and in combat (raids, dungeons).
local duelist = fs.readFile(ROOT .. "/src/server/Systems/Duelist.luau")
check(duelist:find('SetAttribute("FocusKaiju", focusKaiju)', 1, true) ~= nil, "Duelist doesn't publish FocusKaiju")
check(duelist:find("petTarget.Record.Id", 1, true) ~= nil, "FocusKaiju isn't the kaiju's id")
local poses = fs.readFile(ROOT .. "/src/client/Modules/BodyPoses.luau")
check(poses:find('GetAttribute("FocusKaiju")', 1, true) ~= nil, "BodyPoses doesn't face the kaiju the boss is on")
for _, path in { "/src/client/Lobby.client.luau", "/src/client/Combat.client.luau" } do
	check(fs.readFile(ROOT .. path):find("Modules.BossFocus).start()", 1, true) ~= nil, path .. " doesn't start BossFocus")
end
local lang = fs.readFile(ROOT .. "/src/shared/LangEs.luau")
for _, key in { "TARGET", "ON YOU", "ON YOUR KAIJU" } do
	check(lang:find('["' .. key .. '"] =', 1, true) ~= nil, "no Spanish for " .. key)
end

print(string.format("boss focus: %d checks passed", checks))
