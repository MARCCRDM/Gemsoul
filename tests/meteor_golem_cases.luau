-- The Meteor Golem (Shared.MeteorGolem, Server.MeteorGolemServer, Client.
-- MeteorGolemFx): who it comes for, its blows, the meteor's fall and the
-- cinematic's camera, and its wiring (the first swing's clock, its cache
-- with no kaiju roll, the HUD's effects).
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
local function has(path: string, text: string): boolean
	return source(path):find(text, 1, true) ~= nil
end

local Rules = luau.load(source("src/shared/MeteorGolem.luau"), { debugName = "MeteorGolem" })()

-- Who it comes for: done with the intro, never beaten it, out in the Outpost, nothing else on.
local fresh = { Intro = { Done = true }, Milestones = {} }
check(Rules.eligible(fresh, { Outpost = true }), "A new miner out in the Outpost isn't sent it")
check(not Rules.eligible({ Intro = { Done = false } }, { Outpost = true }), "Sent it mid-intro")
check(not Rules.eligible({ Intro = { Done = true }, Milestones = { MeteorGolem = true } }, { Outpost = true }), "Sent it again after beating it")
check(not Rules.eligible(fresh, { Outpost = false }), "Sent it outside the Outpost")
check(not Rules.eligible(fresh, {}), "Sent it with no Outpost attribute")
for _, busy in { "CombatSession", "MatchId", "FirstFight", "IntroCover", "DungeonId", "MechPilot", "KaijuBattle" } do
	local attrs = { Outpost = true }
	attrs[busy] = "x"
	local ok, why = Rules.eligible(fresh, attrs)
	check(not ok and why == busy, "Sent it during " .. busy)
end
check(not Rules.eligible(nil, { Outpost = true }), "Sent it with no profile")

-- Its blows: a Slam close in, a Rock from further out (never three running), else it walks.
check(Rules.blow(5, 0) == "Slam", "No Slam up close")
check(Rules.blow(Rules.Slam.Reach, 5) == "Slam", "No Slam at its reach")
check(Rules.blow(25, 0) == "Rock" and Rules.blow(25, 1) == "Rock", "No Rock from further out")
check(Rules.blow(25, 2) == nil, "A third Rock running")
check(Rules.blow(Rules.Rock.Reach + 1, 0) == nil, "A Rock from past its reach")

-- Easy, but not that easy: telegraphed, slow, a few blows to go down.
check(Rules.Slam.Windup >= 1 and Rules.Rock.Windup >= 1, "A blow with too short a warning")
check(Rules.Slam.Share * 5 >= 1 and Rules.Slam.Share * 3 < 1, "A Slam's share: 3 to 5 to bring you down")
check(Rules.Rock.Share < Rules.Slam.Share, "A Rock hits harder than a Slam")
check(Rules.Speed < 16, "It outruns you")
check(Rules.Delay == 10, "Not ten seconds after the first swing")
check(Rules.Fall < Rules.Crack and Rules.Crack < Rules.Rise and Rules.Rise < Rules.Awake, "The cinematic's beats out of order")
check(Rules.Boss.Threat == 1 and Rules.Boss.Name == "Magma Golem", "Its cache isn't a threat I boss's")

-- The client: the meteor's fall and the cinematic's camera.
local env = setmetatable({
	Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3,
	game = { GetService = function() return {} end },
	workspace = {},
	script = { Parent = { CombatFx = {}, CombatSound = {} } },
	require = function(m)
		if type(m) == "table" then
			return m
		end
		return Rules
	end,
}, { __index = _G })
env.ReplicatedStorage = nil
local fxSource = source("src/client/Modules/MeteorGolemFx.luau")
	:gsub("require%(ReplicatedStorage%.Shared%.MeteorGolem%)", "require(nil)")
local Fx = luau.load(fxSource, { debugName = "MeteorGolemFx", environment = env })()
local spot, eye = roblox.Vector3.new(100, 0, 50), roblox.Vector3.new(100, 2, 80)
check((Fx.meteorAt(spot, 0) - (spot + Fx.Sky)).Magnitude < 1e-3, "The meteor doesn't start up in the sky")
check((Fx.meteorAt(spot, Rules.Fall) - spot).Magnitude < 1e-3, "The meteor doesn't land on its spot")
check(Fx.meteorAt(spot, Rules.Fall * 0.5).Y > spot.Y, "The meteor's under the ground mid-fall")
local last = math.huge
for i = 0, 10 do
	local y = Fx.meteorAt(spot, Rules.Fall * i / 10).Y
	check(y <= last + 1e-6, "The meteor goes back up")
	last = y
end
for _, t in { 0, 1, Rules.Fall - 0.01, Rules.Fall + 0.1, Rules.Crack + 0.1, Rules.Awake - 0.01 } do
	local shot = Fx.shot(t, spot, eye)
	check(shot ~= nil, "No camera shot at " .. t)
	check(shot.Position.Y > spot.Y, "The camera's in the ground at " .. t)
	check(shot.Position.Y < spot.Y + 40, "The camera's lost up in the sky at " .. t)
end
check(Fx.shot(Rules.Awake, spot, eye) == nil and Fx.shot(-1, spot, eye) == nil, "The cinematic doesn't end at Awake")
-- (the last shot's low, under the golem's head: looking up at it; lune's
-- CFrame.lookAt faces the other way, so not its LookVector)
local final = Fx.shot(Rules.Awake - 0.01, spot, eye)
check(final.Position.Y < spot.Y + 6, "The last shot isn't low, looking up at the golem")
check((final.Position - spot).Magnitude > 12, "The last shot's inside the golem")

-- Wired in.
check(has("src/server/Systems/Remotes.luau", 'MeteorGolem = Instance.new("RemoteEvent")'), "No MeteorGolem remote")
check(has("src/server/Main.server.luau", "MeteorGolemServer.start()"), "Main doesn't start the golem")
check(has("src/server/Main.server.luau", "MeteorGolemServer.swing(player)"), "A swing doesn't start its clock")
check(has("src/server/Main.server.luau", "FrontierServer.swing(player, strikes)"), "The frontier's swing hook lost")
check(has("src/server/Systems/MeteorGolemServer.luau", "{ NoKaijuRoll = true }"), "Its cache comes with a kaiju roll")
check(has("src/server/Systems/MeteorGolemServer.luau", "profile.Milestones[Rules.Id] = true"), "Beating it isn't saved")
check(has("src/server/Systems/ArenaStreaks.luau", "if not (opts and opts.NoKaijuRoll) then"), "bossCache has no NoKaijuRoll")
check(has("src/server/Systems/MeteorGolemServer.luau", "e.OutpostCreature = true"), "Your kaiju don't fight it")
check(has("src/client/Hud.client.luau", "require(script.Parent.Modules.MeteorGolemFx).start()"), "The HUD doesn't start its effects")
check(fxSource:find("Enum.RenderPriority.Camera.Value + 5", 1, true) ~= nil, "The cinematic's camera runs under another")
print(string.format("PASS: %d meteor golem checks (who it's for, its blows, the fall, the cinematic, wired in)", checks))
