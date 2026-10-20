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
local Trading = require(script.Parent.Systems.Trading)
local Equipment = require(script.Parent.Systems.Equipment)
-- Everyone's body is the rival's rig, before anyone spawns (FighterRig).
require(script.Parent.Systems.FighterRig).start()
-- Bodies pass through each other (nobody stands on their foe) and nobody
-- jumps in a fight (FighterBodies).
require(script.Parent.Systems.FighterBodies).start()

-- Bodies blown apart on death (client ElementalDeath): the flying pieces hit
-- the ground and walls but not each other, so a body that starts packed
-- together doesn't shove itself apart.
do
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		PhysicsService:RegisterCollisionGroup("DeathDebris")
		PhysicsService:CollisionGroupSetCollidable("DeathDebris", "DeathDebris", false)
	end)
end

-- Menu-only mode plays entirely from the dashboard, so the town isn't built
-- (nothing to render or stream). The character still spawns on the
-- place's baseplate so the dashboard can show it wearing its gear.
if Config.MenuOnly then
	require(script.Parent.World.Lighting)(true)
	-- The Moon Mine's expedition site, far from the spawn pad, walked on foot.
	local MiningSite = require(game:GetService("ReplicatedStorage").Shared.MiningSite)
	MiningSite.build(MiningSite.Location, workspace)
	if Config.CombatEnabled then
		local arena = Instance.new("Folder")
		arena.Name = "CombatArena"
		arena.Parent = workspace
		require(script.Parent.World.Zones.Arena).build(arena, CFrame.new(600, 0, 0), Color3.fromRGB(190, 65, 80))
	end
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
-- The onboarding funnel (analytics) listens for loads, so it starts first.
require(script.Parent.Systems.Funnel).start()
PlayerData.start()
Vip.start()
Mining.start()
MineWall.start()
Shop.start()
require(script.Parent.Systems.TrainingRewardsServer).start()
require(script.Parent.Systems.Augments).start()
require(script.Parent.Systems.Presets).start()
Intro.start()
Enchanting.start()
Forge.start()
Trading.start()
require(script.Parent.Systems.MarketBoard).start()
require(script.Parent.Systems.ArenaStreaks).start()
Party.start()
require(script.Parent.Systems.ChatChannels).start()
-- Playtest feedback and error reports (Social > Feedback).
require(script.Parent.Systems.Feedback).start()
StoreServer.start()
require(script.Parent.Systems.Referrals).start()
-- Reward coupons from invites (Shared.Coupons): the INVITE menu spends them.
local CouponServer = require(script.Parent.Systems.CouponServer)
CouponServer.start()
require(script.Parent.Systems.FreeRewards).start()
TopPlayers.start()
Equipment.start()
-- One health-recovery rule for players and computer fighters alike.
require(script.Parent.Systems.HealthRegen).start()
-- The dashboard opens Arena sessions; the full town also enables the Wilds.
if Config.CombatEnabled or not Config.MenuOnly then
	Enemies.start(Config.MenuOnly)
	CombatServer.start()
	require(script.Parent.Systems.ArenaSessions).start()
	-- PvP sessions bring a computer rival with a random loadout.
	require(script.Parent.Systems.Duelist).start()
	-- Player duels: the 1v1 and 2v2 queues, challenges and rated matches.
	require(script.Parent.Systems.Duels).start()
	-- Party Raids: a party of three or more against a raid boss.
	require(script.Parent.Systems.Raids).start()
	require(script.Parent.Systems.Dungeons).start()
	require(script.Parent.Systems.DungeonQueue).start()
end
-- Saga Outpost: the shared mining basin (mine, trade at the Probe, duel).
if Config.Features == nil or Config.Features.Mining ~= false then
	local OutpostServer = require(script.Parent.Systems.OutpostServer)
	OutpostServer.start()
	-- PROBE-7's refills are Robux products: their swings go on the pick.
	StoreServer.addSwings = OutpostServer.addSwings
	-- Swing restores (Shared.SwingRestore): arena streaks, dungeons, coupons.
	require(script.Parent.Systems.Restores).swings = OutpostServer.restoreSwings
	CouponServer.restoreSwings = OutpostServer.restoreSwings
	-- Friendly sparring there: 1 swaps the pick for your combat kit.
	if Config.CombatEnabled or not Config.MenuOnly then
		local SparServer = require(script.Parent.Systems.SparServer)
		SparServer.start()
		-- Mini kaiju: yours beside you, wild ones to hunt, and moon bugs
		-- through rifts round anyone out past the core (the frontier).
		if Config.Features == nil or Config.Features.Kaiju ~= false then
			local KaijuServer = require(script.Parent.Systems.KaijuServer)
			KaijuServer.start()
			-- Revives for Robux (the KaijuRevive product) and Revive coupons.
			StoreServer.reviveKaiju = KaijuServer.reviveAll
			CouponServer.reviveKaiju = KaijuServer.reviveAll
			-- Your kaiju out levels as you mine: EXP for every rock you break.
			OutpostServer.onRockMined = KaijuServer.mined
			-- Kaiju battles: two players' teams placed in a formation, then
			-- fighting it out by themselves.
			require(script.Parent.Systems.KaijuBattles).start()
			local KaijuWilds = require(script.Parent.Systems.KaijuWilds)
			KaijuWilds.start(OutpostServer.site())
			local FrontierServer = require(script.Parent.Systems.FrontierServer)
			FrontierServer.start(OutpostServer.site())
			-- Swings out past the core draw critters; a pick bonks them.
			OutpostServer.onSwing = FrontierServer.swing
			OutpostServer.bonker = KaijuWilds
			-- Gem raids: the gems mined out there are a trip's haul, and a
			-- snatcher's trip knocks you down as a spar's blow would.
			OutpostServer.onGemMined = FrontierServer.mined
			KaijuWilds.knockDown = SparServer.knockDown
			-- A Rift Vein surfacing somewhere new takes its dormant rift (and its
			-- guardian) along; a swing at a vein's rocks wakes its guardian.
			OutpostServer.onVeinMoved = function(index, scar)
				FrontierServer.moveScar(index, scar)
				task.spawn(KaijuWilds.veinMoved, index, scar)
			end
			OutpostServer.onVeinSwing = KaijuWilds.veinSwing
		end
	end
	-- The garage's machines, for driving round the quarry (Config.Features:
	-- off leaves the bays empty).
	if Config.Features == nil or Config.Features.Mechs ~= false then
		require(script.Parent.Systems.OutpostVehicles).start(OutpostServer.site())
	end
end
