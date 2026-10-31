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
-- The fallen miners in the dungeons and the Rift wear that rig too, in
-- random gear (FallenCrew), before any of those worlds is built.
require(script.Parent.Systems.FallenCrew).start()
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
-- Coins, feature events and the Store funnel (Creator Dashboard > Analytics).
require(script.Parent.Systems.Analytics).start(
	require(script.Parent.Systems.Remotes).Funnel,
	require(game:GetService("ReplicatedStorage").Shared.Store).productKey
)
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
-- Saga Outpost: the shared mining basin (mine, trade at the Market, duel).
if Config.Features == nil or Config.Features.Mining ~= false then
	local OutpostServer = require(script.Parent.Systems.OutpostServer)
	OutpostServer.start()
	-- The swing refills are Robux products: their swings go on the pick.
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
			StoreServer.kaijuSale = KaijuServer.saleGrant
			CouponServer.reviveKaiju = KaijuServer.reviveAll
			-- The team's HYPERBEAM: their mana, SAVE CHARGE and the blast.
			require(script.Parent.Systems.KaijuBeamServer).start()
			-- Kaiju battles: two players' teams placed in a formation, then
			-- fighting it out by themselves.
			require(script.Parent.Systems.KaijuBattles).start()
			local KaijuWilds = require(script.Parent.Systems.KaijuWilds)
			KaijuWilds.start(OutpostServer.site())
			local FrontierServer = require(script.Parent.Systems.FrontierServer)
			FrontierServer.start(OutpostServer.site())
			-- Swings out past the core draw critters; a pick bonks them.
			-- A new miner's first swings out there also start the Meteor
			-- Golem's clock (once, theirs alone: Systems/MeteorGolemServer).
			local MeteorGolemServer = require(script.Parent.Systems.MeteorGolemServer)
			MeteorGolemServer.start()
			OutpostServer.onSwing = function(player, strikes)
				FrontierServer.swing(player, strikes)
				MeteorGolemServer.swing(player)
			end
			OutpostServer.bonker = KaijuWilds
			-- Gem raids: the gems mined out there are a trip's haul (no
			-- knock-downs in the Outpost: you're killed or you're not).
			OutpostServer.onGemMined = FrontierServer.mined
			-- Knocked out out there, the critters come to rob you (Server.Robbery).
			SparServer.onKnockedOut = FrontierServer.knockedOut
			-- ...and back at base, it's your pick that's out (miner mode).
			FrontierServer.kitAway = SparServer.unpair
			-- A Rift Vein surfacing somewhere new takes its dormant rift (and its
			-- guardian) along; a swing at a vein's rocks wakes its guardian.
			OutpostServer.onVeinMoved = function(index, scar)
				FrontierServer.moveScar(index, scar)
				task.spawn(KaijuWilds.veinMoved, index, scar)
			end
			OutpostServer.onVeinSwing = KaijuWilds.veinSwing
			-- A pack holding an outcrop comes for whoever mines it; its rocks
			-- roll luckier meanwhile.
			OutpostServer.onRockSwing = KaijuWilds.rockSwing
			OutpostServer.patchLuck = KaijuWilds.patchLuck
			-- The Rift: through a vein's gate into the critters' world, a
			-- pathway of islands to a brainrot boss (your kaiju come too).
			local RiftServer = require(script.Parent.Systems.RiftServer)
			RiftServer.gateAt = OutpostServer.veinGate
			-- (RESTORE when down at its boss, for Robux: the RiftRestore product)
			StoreServer.riftRestore = RiftServer.restoreBought
			-- (and Brutus's bounty board: any boss, from his counter)
			RiftServer.bountyAt = OutpostServer.bountyCounter
			RiftServer.start(OutpostServer.site())
			-- The Kaiju Arena, down the Shelter's stairs: rows of courts, a pad
			-- at each end to wait on, stakes, and every kaiju battle fought there.
			require(script.Parent.Systems.KaijuPitServer).start(OutpostServer.site())
		end
	end
	-- The garage's machines, for driving round the quarry (Config.Features:
	-- off leaves the bays empty).
	if Config.Features == nil or Config.Features.Mechs ~= false then
		require(script.Parent.Systems.OutpostVehicles).start(OutpostServer.site())
	end
end
