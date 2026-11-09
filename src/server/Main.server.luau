-- Server entry point: build the world, then start the gameplay systems that
-- hook into it through CollectionService tags.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
-- Errors are caught from here on (DEV > ERRORS: Systems/Feedback), before
-- anything else is built.
local Feedback = require(script.Parent.Systems.Feedback)
-- One system failing to start must never stop the rest (a stranded server:
-- no Outpost, everyone left on the old base). Each start runs on its own;
-- a failure is warned and noted for DEV > ERRORS, and the next goes on.
local function safe(name: string, fn: () -> ())
	local ok, problem = pcall(fn)
	if not ok then
		warn("[Main] " .. name .. " failed to start: " .. tostring(problem))
		pcall(Feedback.note, "Server", "Start failed: " .. name, tostring(problem))
	end
end
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
safe("FighterRig", function() require(script.Parent.Systems.FighterRig).start() end)
-- The fallen miners in the dungeons and the Rift wear that rig too, in
-- random gear (FallenCrew), before any of those worlds is built.
safe("FallenCrew", function() require(script.Parent.Systems.FallenCrew).start() end)
-- Bodies pass through each other (nobody stands on their foe) and nobody
-- jumps in a fight (FighterBodies).
safe("FighterBodies", function() require(script.Parent.Systems.FighterBodies).start() end)

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
	safe("MiningSite", function() MiningSite.build(MiningSite.Location, workspace) end)
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
	safe("WorldBuilder", function() WorldBuilder.build() end)
end
-- The onboarding funnel (analytics) listens for loads, so it starts first.
safe("Funnel", function() require(script.Parent.Systems.Funnel).start() end)
safe("VoiceVolume", function() require(game:GetService("ReplicatedStorage").Shared.VoiceVolume).start() end) -- (voice chat louder, fading gently; the client runs it too)
-- A new player's first session as a journey (Systems/Journey: Creator Dashboard > Journeys).
safe("Journey", function() require(script.Parent.Systems.Journey).listen() end)
-- Coins, feature events and the Store funnel (Creator Dashboard > Analytics).
safe("Analytics", function()
	require(script.Parent.Systems.Analytics).start(
		require(script.Parent.Systems.Remotes).Funnel,
		require(game:GetService("ReplicatedStorage").Shared.Store).productKey
	)
end)
-- The game's own event log, in its own DataStore (tools/telemetry: the dashboard).
-- Dev and test accounts are left out of every number (Systems/DevAccounts).
safe("DevAccounts", function() require(script.Parent.Systems.DevAccounts).start() end)
safe("Telemetry", function() require(script.Parent.Systems.Telemetry).start(require(script.Parent.Systems.Remotes).Telemetry) end)
safe("PlayerData", function() PlayerData.start() end)
safe("Vip", function() Vip.start() end)
safe("Mining", function() Mining.start() end)
safe("MineWall", function() MineWall.start() end)
safe("Shop", function() Shop.start() end)
safe("TrainingRewardsServer", function() require(script.Parent.Systems.TrainingRewardsServer).start() end)
safe("Augments", function() require(script.Parent.Systems.Augments).start() end)
safe("SkillTreeServer", function() require(script.Parent.Systems.SkillTreeServer).start() end)
safe("Presets", function() require(script.Parent.Systems.Presets).start() end)
safe("Intro", function() Intro.start() end)
safe("Enchanting", function() Enchanting.start() end)
safe("Forge", function() Forge.start() end)
safe("Trading", function() Trading.start() end)
safe("MarketBoard", function() require(script.Parent.Systems.MarketBoard).start() end)
safe("ArenaStreaks", function() require(script.Parent.Systems.ArenaStreaks).start() end)
safe("Party", function() Party.start() end)
safe("ChatChannels", function() require(script.Parent.Systems.ChatChannels).start() end)
-- Playtest feedback and error reports (Social > Feedback).
safe("Feedback", function() require(script.Parent.Systems.Feedback).start() end)
safe("StoreServer", function() StoreServer.start() end)
safe("Referrals", function() require(script.Parent.Systems.Referrals).start() end)
-- Reward coupons from invites (Shared.Coupons): the INVITE menu spends them.
local CouponServer = require(script.Parent.Systems.CouponServer)
safe("CouponServer", function() CouponServer.start() end)
safe("FreeRewards", function() require(script.Parent.Systems.FreeRewards).start() end)
-- Another player's gear, to look at (GEAR on the card beside them).
safe("GearInspect", function() require(script.Parent.Systems.GearInspect).start() end)
-- The Kaiju Daycare: kaiju boarded (stored or trained), in a pen by the Kennel.
safe("DaycareServer", function() require(script.Parent.Systems.DaycareServer).start() end)
-- A new miner's intro rounds: six wins in the Arena, a piece of gear each.
safe("IntroRoundsServer", function() require(script.Parent.Systems.IntroRoundsServer).start() end)
-- The Owners hear (and see) whenever someone joins, any server.
safe("DevAlerts", function() require(script.Parent.Systems.DevAlerts).start() end)
-- A player's settings (music, sound), saved with their profile.
safe("SettingsServer", function() require(script.Parent.Systems.SettingsServer).start() end)
-- The Owners' ANALYTICS window: this server, today, the last 7 days.
safe("AnalyticsPanel", function() require(script.Parent.Systems.AnalyticsPanel).start() end)
-- DEV > SPECTATE: an Owner watches a player in third person (Systems/DevSpectate).
safe("DevSpectate", function() require(script.Parent.Systems.DevSpectate).start() end)
-- The DEV desk in the Shelter: lit while an Owner's in (Systems/DevDesk).
safe("DevDesk", function() require(script.Parent.Systems.DevDesk).start() end)
-- What players tap and open (Systems/UiTrack), into the log the ANALYTICS window reads.
safe("UiTrack", function() require(script.Parent.Systems.UiTrack).start() end)
safe("TopPlayers", function() TopPlayers.start() end)
safe("Equipment", function() Equipment.start() end)
-- One health-recovery rule for players and computer fighters alike.
safe("HealthRegen", function() require(script.Parent.Systems.HealthRegen).start() end)
-- The dashboard opens Arena sessions; the full town also enables the Wilds.
if Config.CombatEnabled or not Config.MenuOnly then
	safe("Enemies", function() Enemies.start(Config.MenuOnly) end)
	safe("CombatServer", function() CombatServer.start() end)
	safe("ArenaSessions", function() require(script.Parent.Systems.ArenaSessions).start() end)
	safe("PrivateArenas", function() require(script.Parent.Systems.PrivateArenas).start() end)
	-- PvP sessions bring a computer rival with a random loadout.
	safe("Duelist", function() require(script.Parent.Systems.Duelist).start() end)
	-- Player duels: the 1v1 and 2v2 queues, challenges and rated matches.
	safe("Duels", function() require(script.Parent.Systems.Duels).start() end)
	-- Party Raids: a party of three or more against a raid boss.
	safe("Raids", function() require(script.Parent.Systems.Raids).start() end)
	safe("Dungeons", function() require(script.Parent.Systems.Dungeons).start() end)
	safe("DungeonQueue", function() require(script.Parent.Systems.DungeonQueue).start() end)
end
-- Saga Outpost: the shared mining basin (mine, trade at the Market, duel).
if Config.Features == nil or Config.Features.Mining ~= false then
	local OutpostServer = require(script.Parent.Systems.OutpostServer)
	safe("OutpostServer", function() OutpostServer.start() end)
	-- A pod for everyone on the settlement's pads: where you start and come back
	-- to; it lands with you inside the first time you come in.
	local PodServer = require(script.Parent.Systems.PodServer)
	safe("PodServer", function() PodServer.start(OutpostServer.site()) end)
	OutpostServer.podArrival = PodServer.land
	-- Its style (Shared.PodStyle) and its showcase's kaiju, from the profile;
	-- MY POD (Client.PodUI) reads them and sets them.
	local PodStyle = require(game:GetService("ReplicatedStorage").Shared.PodStyle)
	local function kaijuOf(player, id)
		local profile = PlayerData.get(player) :: any
		local list = profile and profile.Kaiju and profile.Kaiju.List
		local record = list and list[id]
		return if type(record) == "table" then record else nil
	end
	PodServer.kaijuOf = kaijuOf
	PodServer.styleOf = function(player)
		local profile = PlayerData.get(player) :: any
		return profile and profile.Pod
	end
	-- The pieces you've rolled (profile.PodOwned: { ["Kind:Id"] = true }).
	local function ownedOf(player)
		local profile = PlayerData.get(player) :: any
		if not profile then
			return nil
		end
		if type(profile.PodOwned) ~= "table" then
			profile.PodOwned = {}
		end
		return profile.PodOwned
	end
	PodServer.ownedOf = ownedOf
	-- The pod roll on its first landing ever: a piece unlocked and put on.
	-- (Once only: after that it lands in the style you've picked, MY POD.)
	PodServer.rollFor = function(player)
		local owned = ownedOf(player)
		local profile = PlayerData.get(player) :: any
		if not owned or not profile or profile.PodRolled then
			return nil
		end
		profile.PodRolled = true
		local piece = PodStyle.roll(owned, Random.new())
		owned[piece.Kind .. ":" .. piece.Id] = true
		profile.Pod = PodStyle.equip(PodStyle.clean(profile.Pod, function(id)
			return kaijuOf(player, id) ~= nil
		end, owned), piece)
		return piece
	end
	Shop.register("PodStyleState", function(player)
		local profile = PlayerData.get(player) :: any
		if not profile then
			return Shop.reply(false, "Your pod's not ready yet.")
		end
		local kaiju = {}
		for id, record in (profile.Kaiju and profile.Kaiju.List) or {} do
			if type(record) == "table" then
				table.insert(kaiju, { Id = id, Species = record.Species, Element = record.Element, Name = record.Name, Level = record.Level })
			end
		end
		table.sort(kaiju, function(a, b)
			return (a.Level or 0) > (b.Level or 0)
		end)
		local owned = ownedOf(player)
		local style = PodStyle.clean(profile.Pod, function(id)
			return kaijuOf(player, id) ~= nil
		end, owned)
		return Shop.reply(true, "", { Style = style, Kaiju = kaiju, Owned = owned })
	end)
	Shop.register("PodStyle", function(player, wanted)
		local profile = PlayerData.get(player) :: any
		if not profile then
			return Shop.reply(false, "Your pod's not ready yet.")
		end
		local owned = ownedOf(player)
		if type(wanted) == "table" then
			for kind, slots in { Hull = { "Hull" }, Glow = { "Glow" }, Decor = { "Left", "Right" } } do
				for _, slot in slots do
					if PodStyle.find(kind, wanted[slot]) and not PodStyle.owns(owned, kind, wanted[slot]) then
						return Shop.reply(false, "Locked: your pod rolls new pieces each time it lands.")
					end
				end
			end
		end
		profile.Pod = PodStyle.clean(wanted, function(id)
			return kaijuOf(player, id) ~= nil
		end, owned)
		PodServer.restyle(player)
		return Shop.reply(true, "", { Style = profile.Pod })
	end)
	-- Arena Row: copies of the Arena out in the open, for fights to take
	-- (Server.PrivateArenas: Training first, the Intro Ring then the Grand Arena).
	if Config.CombatEnabled or not Config.MenuOnly then
		local Outpost = require(game:GetService("ReplicatedStorage").Shared.Outpost)
		local PrivateArenas = require(script.Parent.Systems.PrivateArenas)
		for _, spec in Outpost.Settlement.Stages do
			PrivateArenas.stage(spec.Name, (Outpost.Location * CFrame.new(spec.X, 0, spec.Z)).Position, Outpost.Settlement.StageReach - 1)
		end
	end
	-- The swing refills are Robux products: their swings go on the pick.
	StoreServer.addSwings = OutpostServer.addSwings
	-- Swing restores (Shared.SwingRestore): arena streaks, dungeons, coupons.
	require(script.Parent.Systems.Restores).swings = OutpostServer.restoreSwings
	CouponServer.restoreSwings = OutpostServer.restoreSwings
	-- Friendly sparring there: 1 swaps the pick for your combat kit.
	if Config.CombatEnabled or not Config.MenuOnly then
		local SparServer = require(script.Parent.Systems.SparServer)
		safe("SparServer", function() SparServer.start() end)
		-- Mini kaiju: yours beside you, wild ones to hunt, and moon bugs
		-- through rifts round anyone out past the core (the frontier).
		if Config.Features == nil or Config.Features.Kaiju ~= false then
			local KaijuServer = require(script.Parent.Systems.KaijuServer)
			safe("KaijuServer", function() KaijuServer.start() end)
			-- Revives for Robux (the KaijuRevive product) and Revive coupons.
			StoreServer.reviveKaiju = KaijuServer.reviveAll
			StoreServer.kaijuSale = KaijuServer.saleGrant
			CouponServer.reviveKaiju = KaijuServer.reviveAll
			-- The team's HYPERBEAM: their mana, SAVE CHARGE and the blast.
			safe("KaijuBeamServer", function() require(script.Parent.Systems.KaijuBeamServer).start() end)
			-- Kaiju battles: two players' teams placed in a formation, then
			-- fighting it out by themselves.
			safe("KaijuBattles", function() require(script.Parent.Systems.KaijuBattles).start() end)
			local KaijuWilds = require(script.Parent.Systems.KaijuWilds)
			safe("KaijuWilds", function() KaijuWilds.start(OutpostServer.site()) end)
			local FrontierServer = require(script.Parent.Systems.FrontierServer)
			safe("FrontierServer", function() FrontierServer.start(OutpostServer.site()) end)
			-- Swings out past the core draw critters; a pick bonks them.
			-- A new miner's first swings out there also start the Meteor
			-- Golem's clock (once, theirs alone: Systems/MeteorGolemServer).
			local MeteorGolemServer = require(script.Parent.Systems.MeteorGolemServer)
			safe("MeteorGolemServer", function() MeteorGolemServer.start() end)
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
			-- (home from a trip, the pod not down yet: it lands with them in it)
			RiftServer.podArrival = function(player)
				if OutpostServer.podArrival then
					OutpostServer.podArrival(player)
				end
			end
			safe("RiftServer", function() RiftServer.start(OutpostServer.site()) end)
			-- The Kaiju Arena, down the Shelter's stairs: rows of courts, a pad
			-- at each end to wait on, stakes, and every kaiju battle fought there.
			safe("KaijuPitServer", function() require(script.Parent.Systems.KaijuPitServer).start(OutpostServer.site()) end)
		end
	end
	-- The garage's machines, for driving round the quarry (Config.Features:
	-- off leaves the bays empty).
	if Config.Features == nil or Config.Features.Mechs ~= false then
		safe("OutpostVehicles", function() require(script.Parent.Systems.OutpostVehicles).start(OutpostServer.site()) end)
	end
end
