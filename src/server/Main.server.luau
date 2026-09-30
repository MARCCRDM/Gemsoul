-- Server entry point: build the world, then start the gameplay systems that
-- hook into it through CollectionService tags.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local WorldBuilder = require(script.Parent.World.WorldBuilder)
local PlayerData = require(script.Parent.Systems.PlayerData)
local Vip = require(script.Parent.Systems.Vip)
local Mining = require(script.Parent.Systems.Mining)
local MineWall = require(script.Parent.Systems.MineWall)
local Shop = require(script.Parent.Systems.Shop)
local Intro = require(script.Parent.Systems.Intro)
local Enchanting = require(script.Parent.Systems.Enchanting)
local Forge = require(script.Parent.Systems.Forge)
local Enemies = require(script.Parent.Systems.Enemies)
local CombatServer = require(script.Parent.Systems.CombatServer)
local Party = require(script.Parent.Systems.Party)
local StoreServer = require(script.Parent.Systems.StoreServer)
local TopPlayers = require(script.Parent.Systems.TopPlayers)
local Equipment = require(script.Parent.Systems.Equipment)

-- Menu-only mode plays entirely from the dashboard, so the town isn't built
-- (nothing to render or stream). The character still spawns on the
-- place's baseplate so the dashboard can show it wearing its gear.
if Config.MenuOnly then
	require(script.Parent.World.Lighting)(true)
	-- No baseplate spawn in this place? A small hidden pad to stand on.
	if not workspace:FindFirstChildWhichIsA("SpawnLocation") then
		local pad = Instance.new("SpawnLocation")
		pad.Name = "LobbyPad"
		pad.Anchored = true
		pad.Size = Vector3.new(16, 1, 16)
		pad.Transparency = 1
		pad.Parent = workspace
	end
else
	WorldBuilder.build()
end
PlayerData.start()
Vip.start()
Mining.start()
MineWall.start()
Shop.start()
Intro.start()
Enchanting.start()
Forge.start()
Party.start()
StoreServer.start()
TopPlayers.start()
Equipment.start()
-- Combat is paused in menu-only mode (see Config.MenuOnly).
if not Config.MenuOnly then
	Enemies.start()
	CombatServer.start()
end
