--[[
	Saga Outpost: the shared mining basin (Shared.Outpost has the rules,
	World.OutpostWorld the place). Everyone in the server mines the same
	rocks, sees each other swing, trades at the Market and challenges each
	other to duels. Request actions:

	  "OutpostEnter"           go to the Outpost (the free Survey Pick recharges)
	  "OutpostLeave"           back to base
	  "OutpostHit", nodeId     swing at a rock (wears your pick; the last hit
	                           pops it and pays out one gem, never coins or
	                           gear; refused while the gem pouch is full)
	  (Garrick's swing refills are Robux products, Outpost.Refills: StoreServer
	  grants their swings through OutpostServer.addSwings, on top of the
	  free pick's charge; swing restores, Shared.SwingRestore, through
	  OutpostServer.restoreSwings: never past its full charge)
	  "OutpostBonk", model     bonk a rift's critter with your pick
	                           (Shared.Frontier.Bonk: it costs no swings)
	  "OutpostState"           your picks and record

	Rocks are shared: a rock's first hitter keeps it while they keep
	swinging (Outpost.ClaimSeconds). A mined-out rock grows back where it
	was after its respawn time, so the outcrops stay where they are
	(Shared.Frontier). Further out the rocks run richer: their zone
	(Outpost.Zones) adds its Luck to every gem, and their crystals glow in
	the band's colour.

	The three Rift Veins move: a vein's rocks don't grow back, so once one
	is mined out (a moment after its last rock pops), and every ten minutes
	or so anyway (put off while someone is mining it), whatever is left of
	it goes and it surfaces at another site by the walls with room
	(site.VeinSites), away from the other two: fresh rocks, its marks and
	Rift Gate (OutpostWorld.veinMarks: the way into the Rift, Server.RiftServer), its dormant rift and its
	guardian (OutpostServer.onVeinMoved: FrontierServer, KaijuWilds), and
	word round the Outpost (workspace's VeinNews and VeinNewsAt:
	FrontierHud's banner). A swing at a vein's rock tells its guardian
	(OutpostServer.onVeinSwing: KaijuWilds). Rocks carry their state as attributes (Hp,
	MaxHp, Zone, ClaimedBy, LastHitBy, LastCrit, Popped) so every client
	can show every swing; prompts carry PromptKind (Mine, Store, Market,
	Spar, Duel, Party) for the client to act on. The Shelter's crew
	(site.Crew: Ilsa the gem buyer, Brutus for duels, Marlo for bounties, Garrick
	for refills, Tamsin, Borin and INFO-9) are Builder.vendor robots: their
	Talk prompt opens Client.Dialogue.

	Every swing out past the core makes noise (OutpostServer.onSwing:
	FrontierServer.swing, which brings the critters). A player Rift Charged
	(RiftCharged, server time) mines luckier gems (Shared.Frontier.Charged).

	The leaderboard billboard shows the top gear scores and duel wins
	(TopPlayers' Gear and Wins boards), refreshed every 30 seconds.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Outpost)
local Frontier = require(ReplicatedStorage.Shared.Frontier)
local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Mine = require(ReplicatedStorage.Shared.Mine)
local PickaxeLooks = require(ReplicatedStorage.Shared.PickaxeLooks)
local Spar = require(ReplicatedStorage.Shared.Spar)
local MechPilot = require(ReplicatedStorage.Shared.MechPilot)
local SwingRestore = require(ReplicatedStorage.Shared.SwingRestore)
local Vendors = require(ReplicatedStorage.Shared.Vendors)
local Builder = require(script.Parent.Parent.World.Builder)
local OutpostWorld = require(script.Parent.Parent.World.OutpostWorld)
local ChatChannels = require(script.Parent.ChatChannels)
local Gems = require(script.Parent.Gems)
local MiningRolls = require(script.Parent.MiningRolls)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Shop = require(script.Parent.Shop)
local TopPlayers = require(script.Parent.TopPlayers)
local HallOfFame = require(ReplicatedStorage.Shared.HallOfFame)
local Bounties = require(ReplicatedStorage.Shared.Bounties)

local reply = Shop.reply

local OutpostServer = {}

OutpostServer.Tag = "OutpostNode"

local site = nil
local healingSpots = {}
local Heal = Rules.Heal
local nodesFolder: Folder? = nil
local nodes = {} -- [id] = { Id, Spot, Size, Hp, MaxHp, Model, ClaimedBy, ClaimUntil, Ready }
local freeSpots: { [number]: boolean } = {}
local fieldSpots: { [number]: boolean } = {}
local nextId = 0
local lastSwing: { [Player]: number } = {}
local lastBonk: { [Player]: number } = {}
-- The Rift Veins: { Site (index into site.VeinSites), Spots, Due (os.clock
-- it next moves), Marks (its model) }; which vein a spot is in; and each
-- spot's epoch, bumped when its vein moves (a rock popped before then
-- doesn't grow back on top of the new one).
local veins = {}
local veinOf: { [number]: number } = {}
local spotEpoch: { [number]: number } = {}
local veinFolder: Folder? = nil

-- Main wires these to the frontier (FrontierServer, KaijuWilds) when it runs:
-- a swing's noise, and a pick's bonk on a critter.
OutpostServer.onSwing = function(_player: Player, _swings: number) end
OutpostServer.bonker = nil :: any -- KaijuWilds: critterOf(model) -> enemy?, bonk(enemy, player, from)
-- A vein surfaced somewhere new: its index and its dormant rift's CFrame.
OutpostServer.onVeinMoved = function(_index: number, _scar: CFrame) end
-- Someone swung at one of vein `index`'s rocks (its guardian wakes).
OutpostServer.onVeinSwing = function(_index: number, _player: Player) end
-- A swing at any rock (its spot's position): a pack holding that patch
-- comes for the miner (KaijuWilds.rockSwing); and how much luckier a rock
-- there rolls (KaijuWilds.patchLuck).
OutpostServer.onRockSwing = function(_position: Vector3, _player: Player) end
OutpostServer.patchLuck = function(_position: Vector3): number
	return 0
end
-- A gem `player` mined (FrontierServer keeps this trip's haul: a gem raid's snatchers take from it).
OutpostServer.onGemMined = function(_player: Player, _gem) end
local secretParts: { [string]: BasePart } = {}
local rng = Random.new()

-- A player's Outpost record, the free pick's regained swings added.
local function record(profile)
	profile.Outpost = profile.Outpost or { Picks = {}, Active = "Survey", Rocks = 0 }
	local o = profile.Outpost
	o.Picks = o.Picks or {}
	o.Rocks = o.Rocks or 0
	-- Picks no longer sold (refills are now): their swings
	-- become extra swings on the free pick.
	local legacy = Rules.legacySwings(o.Picks)
	for id in Rules.LegacyPicks do
		o.Picks[id] = nil
	end
	if legacy > 0 then
		o.Picks.Extra = (o.Picks.Extra or 0) + legacy
	end
	-- (Refills bought before they had their own bank sat on top of the
	-- charge: past full, they move to the bank.)
	local full = Rules.Picks.Survey.Swings
	if (o.Picks.Survey or 0) > full then
		o.Picks.Extra = (o.Picks.Extra or 0) + o.Picks.Survey - full
		o.Picks.Survey = full
	end
	if o.SurveyAt == nil then
		-- A new miner (or one from before the refill) starts with it full.
		o.Picks.Survey = math.max(o.Picks.Survey or 0, Rules.Picks.Survey.Swings)
	end
	local swings
	swings, o.SurveyAt = Rules.refillSurvey(o.Picks.Survey or 0, o.SurveyAt or os.time(), os.time())
	-- (A worn-out pick stays gone until a swing comes back.)
	o.Picks.Survey = if swings > 0 then swings else o.Picks.Survey
	if not Rules.Picks[o.Active] then
		o.Active = Rules.PickOrder[1]
	end
	return o
end

local function stateOf(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local o = record(profile)
	local secrets = 0
	for _ in o.Secrets or {} do
		secrets += 1
	end
	return {
		Picks = o.Picks,
		Active = o.Active,
		Rocks = o.Rocks,
		Secrets = secrets,
		SecretsTotal = if site then #(site.Secrets or {}) else 0,
		-- The free pick's charge clock (Outpost.surveyCharge projects it), and
		-- seconds until its next swing (nil when full).
		SurveyAt = o.SurveyAt,
		NextSwingIn = select(2, Rules.surveyCharge(o.Picks.Survey or 0, o.SurveyAt or os.time(), os.time())),
	}
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- The pickaxe skin this miner holds, if it owns it and it has a look.
local function wornPick(profile): string?
	local cosmetics = profile and profile.Cosmetics
	local skin = cosmetics and cosmetics.Pick
	if skin and cosmetics.Owned and cosmetics.Owned[skin] and PickaxeLooks.Looks[skin] then
		return skin
	end
	return nil
end

-- The pick in hand, seen by everyone; the weapon is put away meanwhile.
-- It wears the miner's pickaxe skin (Cosmetics Kind "Pick"), if any, and
-- otherwise its tier's own colour. PickSkin says which, for the hit effect
-- every client draws (OutpostScene).
local function pickModel(player: Player)
	local character = player.Character
	local hand = character and character:FindFirstChild("RightHand") :: BasePart?
	if not character or not hand then
		return
	end
	local old = character:FindFirstChild("OutpostPick")
	if old then
		old:Destroy()
	end
	local profile = PlayerData.get(player)
	local spec = Rules.Picks[profile and record(profile).Active or "Survey"] or Rules.Picks.Survey
	local skin = wornPick(profile)
	local model = Instance.new("Model")
	model.Name = "OutpostPick"
	local grip = hand.CFrame * CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-120), 0, 0)
	PickaxeLooks.build(model, grip, skin, spec.Color, hand, spec.Power > 1)
	model:SetAttribute("PickSkin", skin)
	model.Parent = character
end

-- A part's transparency as it should be. While an Arena drop has the body
-- staged (hidden in its pod, ArenaDrop) the real value waits in the
-- InsertionTransparency attribute until the reveal, so that is what changes.
local function shownAs(part: BasePart): number
	local staged = part:GetAttribute("InsertionTransparency")
	return if type(staged) == "number" then staged else part.Transparency
end
local function setShown(part: BasePart, value: number)
	if type(part:GetAttribute("InsertionTransparency")) == "number" then
		part:SetAttribute("InsertionTransparency", value)
	else
		part.Transparency = value
	end
end

local function weaponVisible(player: Player, visible: boolean)
	local character = player.Character
	local gear = character and character:FindFirstChild("GemsoulGear")
	-- The sword and the shield both go away: a miner works with the pick.
	local stowed = {}
	for _, name in { "Weapon", "Shield" } do
		local component = gear and gear:FindFirstChild(name)
		for _, part in component and component:GetDescendants() or {} do
			table.insert(stowed, part)
		end
	end
	for _, part in stowed do
		if part:IsA("BasePart") then
			if visible then
				local was = part:GetAttribute("OutpostTransparency")
				if was ~= nil then
					setShown(part, was)
					part:SetAttribute("OutpostTransparency", nil)
				end
			elseif part:GetAttribute("OutpostTransparency") == nil then
				part:SetAttribute("OutpostTransparency", shownAs(part))
				setShown(part, 1)
			end
		end
	end
end

-- Mining kit on while at the Outpost and not in a fight; off otherwise
-- (a fight, or a friendly spar with the combat kit out: Shared.Spar).
local function refreshKit(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local mining = player:GetAttribute("Outpost") == true
		and player:GetAttribute("CombatSession") == nil
		and not Spar.sparring(player)
	weaponVisible(player, not mining)
	local pick = character:FindFirstChild("OutpostPick")
	if mining then
		pickModel(player)
	elseif pick then
		pick:Destroy()
	end
end

-- "Ask to spar" (Z), "Challenge to a duel" (G), "Invite to party" (F) and
-- "Kaiju battle" (V) on each visitor, for others.
local function socialPrompts(player: Player, on: boolean)
	local root = rootOf(player)
	if not root then
		return
	end
	for _, name in { "OutpostSpar", "OutpostDuel", "OutpostParty", "OutpostKaiju" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	-- Never on someone in a fight: they're busy, and in a duel the prompts
	-- popped up over the foe every time the fighters closed in. (Nor on
	-- someone sparring, for the same reason.)
	if
		not on
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or Spar.sparring(player)
		or player:GetAttribute("KaijuBattle") ~= nil
	then
		return
	end
	for _, spec in
		{
			{ "OutpostSpar", "Spar", "Ask to spar", Enum.KeyCode.Z, Enum.KeyCode.ButtonY },
			{ "OutpostDuel", "Duel", "Challenge to a duel", Enum.KeyCode.G, Enum.KeyCode.ButtonX },
			{ "OutpostParty", "Party", "Invite to party", Enum.KeyCode.F, Enum.KeyCode.ButtonB },
			{ "OutpostKaiju", "Kaiju", "Kaiju battle", Enum.KeyCode.V, Enum.KeyCode.ButtonL1 },
		}
	do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = spec[1]
		prompt.ActionText = spec[3]
		prompt.ObjectText = player.DisplayName
		prompt.KeyboardKeyCode = spec[4]
		-- (Each its own gamepad button, so all four stay live together.)
		prompt.GamepadKeyCode = spec[5]
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		-- Drawn by the client as one card beside the miner (PlayerCard), not
		-- as four of Roblox's panels stacked over them.
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt:SetAttribute("PromptKind", spec[2])
		prompt:SetAttribute("TargetUserId", player.UserId)
		prompt.Parent = root
	end
end

-- Rocks ---------------------------------------------------------------------------

-- A rock on a free spot: the welcome field first, then the field round the
-- middle, else anywhere; `want` (a spot) when a rock grows back where it was.
local function spawnNode(field: boolean?, want: number?)
	local spots = {}
	for index in freeSpots do
		if (fieldSpots[index] == true) == (field == true) then
			table.insert(spots, index)
		end
	end
	if #spots == 0 or not site or not nodesFolder then
		return
	end
	local index = spots[rng:NextInteger(1, #spots)]
	-- Keep the welcome field stocked, then the field round the middle, before
	-- filling distant quarry sites. These still use the same node cap, loot
	-- and respawn timers as other rocks.
	local near = {}
	for _, nearIndex in site.NearSpots or {} do
		if freeSpots[nearIndex] and (fieldSpots[nearIndex] == true) == (field == true) then
			table.insert(near, nearIndex)
		end
	end
	if #near > 0 then
		index = near[rng:NextInteger(1, #near)]
	end
	for _, arrivalIndex in site.ArrivalSpots or {} do
		if freeSpots[arrivalIndex] and (fieldSpots[arrivalIndex] == true) == (field == true) then
			index = arrivalIndex
			break
		end
	end
	if want and freeSpots[want] then
		index = want
	end
	freeSpots[index] = nil
	nextId += 1
	-- Each zone grows its own mix (Shared.Outpost.Zones), its crystals in its
	-- band's colour out along the trails (Shared.Frontier.Bands), its stone
	-- its biome's (Shared.Frontier.Biomes).
	local zone = site.Zones and site.Zones[index]
	local healing = healingSpots[index] == true
	local size = if healing then "Boulder" else Rules.rollSize(rng:NextNumber(), zone)
	local spec = Rules.Sizes[size]
	local band = zone and Frontier.Bands[zone]
	local biome = Frontier.biomeAt(site.Spots[index].Position - Rules.Location.Position)
	local model = OutpostWorld.rock(
		size,
		site.Spots[index],
		rng,
		if healing then Color3.fromRGB(70, 240, 95) elseif band then band.Color else nil,
		if not healing and biome then biome.Stone else nil
	)
	local hp = if healing then Heal.Hp else spec.Hp
	model:SetAttribute("HealRock", healing)
	model:SetAttribute("OutpostHeal", healing)
	model.Name = "Rock" .. nextId
	model:SetAttribute("NodeId", nextId)
	model:SetAttribute("Size", size)
	model:SetAttribute("Zone", zone)
	model:SetAttribute("Hp", hp)
	model:SetAttribute("MaxHp", hp)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if healing then "Click to heal - FREE" else "Click to mine"
	prompt.ObjectText = ""
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Rules.Reach + spec.Scale / 2
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("PromptKind", "Mine")
	prompt:SetAttribute("NodeId", nextId)
	prompt.Parent = model.PrimaryPart
	CollectionService:AddTag(model, OutpostServer.Tag)
	model.Parent = nodesFolder
	nodes[nextId] = {
		Id = nextId,
		Spot = index,
		Size = size,
		Zone = zone,
		Hp = hp,
		MaxHp = hp,
		Healing = healing,
		Model = model,
		Ready = true,
	}
end

-- A rock popped: it lingers a moment (for the burst), then grows back later.
local function popNode(node, player: Player)
	node.Ready = false
	nodes[node.Id] = nil
	local model = node.Model
	model:SetAttribute("Popped", player.UserId)
	local prompt = model.PrimaryPart and model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end
	task.delay(0.9, function()
		model:Destroy()
	end)
	-- A vein's rock doesn't grow back: once its last one goes, the vein
	-- moves on, a moment later, and grows afresh somewhere else.
	local v = veinOf[node.Spot]
	if v then
		task.delay(4, function()
			if OutpostServer._minedOut(v) then
				OutpostServer.moveVein(v)
			end
		end)
		return
	end
	-- Any other grows back where it was (an outcrop stays where it is): its
	-- spot stays its own until then.
	local epoch = spotEpoch[node.Spot]
	task.delay(if node.Healing then Heal.Regrow else Rules.Sizes[node.Size].Respawn, function()
		if spotEpoch[node.Spot] ~= epoch then
			return
		end
		freeSpots[node.Spot] = true
		spawnNode(fieldSpots[node.Spot] == true, node.Spot)
	end)
end

-- Rift Veins --------------------------------------------------------------------------------------

local function nodeOn(spot: number)
	for _, node in nodes do
		if node.Spot == spot then
			return node
		end
	end
	return nil
end

function OutpostServer._minedOut(v: number): boolean
	for _, spot in veins[v].Spots do
		if nodeOn(spot) then
			return false
		end
	end
	return true
end

-- Someone is mining it right now (its rocks claimed).
local function worked(v: number, now: number): boolean
	for _, spot in veins[v].Spots do
		local node = nodeOn(spot)
		if node and node.ClaimUntil and node.ClaimUntil > now then
			return true
		end
	end
	return false
end

local function nextDue(): number
	local v = Frontier.Veins
	return os.clock() + v.Every + rng:NextNumber(-v.Wobble, v.Wobble)
end

local function markVein(vein)
	if vein.Marks then
		vein.Marks:Destroy()
	end
	local guarded = vein == veins[Frontier.Veins.Guarded]
	local color = if guarded then Frontier.Bands.Guarded.Color else nil
	vein.Marks = OutpostWorld.veinMarks(veinFolder, site.VeinSites[vein.Site].Scar, rng, color, table.find(veins, vein))
end

-- Vein `v` surfaces at another site: whatever's left of it goes, fresh
-- rocks grow there, and its marks and dormant rift move with it. Returns
-- whether it moved (there's always a site, unless the Outpost had too few).
function OutpostServer.moveVein(v: number): boolean
	local vein = veins[v]
	if not vein or not site then
		return false
	end
	local angles, taken, others = {}, {}, {}
	for i, siteInfo in site.VeinSites do
		angles[i] = siteInfo.Angle
	end
	for i, other in veins do
		taken[other.Site] = true
		if i ~= v then
			table.insert(others, angles[other.Site])
		end
	end
	local index = Frontier.pickSite(angles, taken, others, rng)
	if not index then
		vein.Due = os.clock() + 60
		return false
	end
	vein.Site = index
	local siteInfo = site.VeinSites[index]
	for k, spot in vein.Spots do
		spotEpoch[spot] = (spotEpoch[spot] or 0) + 1
		local node = nodeOn(spot)
		if node then
			nodes[node.Id] = nil
			node.Ready = false
			node.Model:Destroy()
		end
		site.Spots[spot] = siteInfo.Rocks[k]
		freeSpots[spot] = true
		spawnNode(fieldSpots[spot] == true, spot)
	end
	vein.Due = nextDue()
	markVein(vein)
	OutpostServer.onVeinMoved(v, siteInfo.Scar)
	local what = if v == Frontier.Veins.Guarded then "A guarded Rift Vein" else "A Rift Vein"
	workspace:SetAttribute("VeinNews", what .. " surfaced to the " .. Frontier.compass(siteInfo.Angle))
	workspace:SetAttribute("VeinNewsAt", workspace:GetServerTimeNow())
	return true
end

-- Every few seconds: a vein whose time has come moves (put off while it's
-- being mined).
function OutpostServer._veinTick(now: number)
	for v, vein in veins do
		if now >= vein.Due then
			if worked(v, now) then
				vein.Due = now + 20
			else
				OutpostServer.moveVein(v)
			end
		end
	end
end

-- What a popped rock pays: one gem, every time (a Common at worst; bigger
-- rocks roll luckier). Never coins, never gear: mining is for gems. (`hit`
-- won't swing with a full pouch, so there's always room for it.)
local function loot(player: Player, node, profile)
 local tutorialLoot = require(script.Parent.Intro).tutorialMined(player)
 if tutorialLoot then
  record(profile).Rocks += 1
  Progress.mined(player)
  PlayerData.milestone(player, "Mined")
  PlayerData.count(player, "GemsMined")
  return tutorialLoot
 end
	local spec = Rules.Sizes[node.Size]
	local result = { Size = node.Size, Name = spec.Name, Zone = node.Zone }
	-- Further out in the frontier, luckier (its zone's Luck).
	local zone = node.Zone and Rules.Zones[node.Zone]
	local luck = Mine.luck(spec.Depth) + (spec.Luck or 0) + (zone and zone.Luck or 0)
	-- Rift Charged (a wandering rift cleared): luckier for a while.
	if (player:GetAttribute("RiftCharged") or 0) > workspace:GetServerTimeNow() then
		luck += Frontier.Charged.Luck
	end
	-- Out in one of the biomes, its element comes up more (Frontier.Biome).
	local spot = site and site.Spots[node.Spot]
	local biome = spot and Frontier.biomeAt(spot.Position - Rules.Location.Position)
	-- A patch a wild pack holds (Kaiju.Wild.Claim): luckier, for the trouble.
	if spot then
		luck += OutpostServer.patchLuck(spot.Position)
	end
	local gem = Gems.award(player, "MiningNode", {
		Luck = luck,
		Silent = true,
		Home = biome and biome.Element,
		Bias = Frontier.Biome.Bias,
	})
	if gem then
		result.Gem = gem
		result.Rarity = gem.Tier
		result.Text = GemConfig.displayName(gem)
		PlayerData.milestone(player, "Mined")
		PlayerData.count(player, "GemsMined")
		OutpostServer.onGemMined(player, gem)
		-- Ultra Rare and Legendary finds are called out to the whole server.
		if (GemConfig.TierRank[gem.Tier] or 0) >= 4 then
			ChatChannels.announce(
				"Loot",
				string.format("%s unearthed [%s] at the Outpost!", player.DisplayName, result.Text)
			)
		end
	else
		result.Full = true
	end
	-- XP for you (less the more you've mined lately), none for your kaiju:
	-- they level by fighting (Shared.Levelling).
	Progress.mined(player)
	record(profile).Rocks += 1
	return result
end

local function hit(player: Player, nodeId: any)
	if player:GetAttribute("Outpost") ~= true or player:GetAttribute("CombatSession") then
		return reply(false, "Head to the Outpost to mine.")
	end
	if Spar.sparring(player) then
		return reply(
			false,
			if Spar.hunting(player) then "Press X for your pick to mine." else "Press X to end the spar and mine."
		)
	end
	-- On foot with your pick, or from a mech's cockpit (Outpost.Machines,
	-- Mine): bigger strikes, sooner, each spending its swings.
	local piloted = MechPilot.mech(player)
	local machineId = MechPilot.kind(piloted)
	local machine = machineId and Rules.Machines[machineId]
	local mech = if machine and machine.Mine then piloted else nil
	if MechPilot.of(player) and not mech then
		return reply(false, "Hop out of the machine to mine.")
	end
	local now = os.clock()
	if now - (lastSwing[player] or 0) < (if mech then machine.Mine.Cooldown else Rules.SwingCooldown) then
		return reply(false, "")
	end
	local node = type(nodeId) == "number" and nodes[nodeId] or nil
	if not node or not node.Ready then
		return reply(false, "That rock is mined out.")
	end
	local root = rootOf(player)
	local body = node.Model.PrimaryPart
	local spec = Rules.Sizes[node.Size]
	local apart = if root and body then root.Position - body.Position else Vector3.zero
	local tooFar = if mech
		then Vector3.new(apart.X, 0, apart.Z).Magnitude > Rules.MechReach + spec.Scale
		else apart.Magnitude > Rules.Reach + spec.Scale
	if not root or not body or tooFar then
		return reply(false, if mech then "Walk the mech up to the rock." else "Get closer to the rock.")
	end
	if not Rules.claimHolder(node, player.UserId, now) then
		local holder = Players:GetPlayerByUserId(node.ClaimedBy)
		return reply(false, (if holder then holder.DisplayName else "Someone") .. " is mining that one.")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your data is still loading.")
	end
	-- Healing has no gem payout or pick charge: usable even with an empty pick/full pouch.
	if node.Healing then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or Spar.isDown(player) then
			return reply(false, "")
		end
		lastSwing[player] = now
		node.Hp = math.max(0, node.Hp - 1)
		local broke = node.Hp <= 0
		local before = humanoid.Health
		humanoid.Health = math.min(humanoid.MaxHealth, before + humanoid.MaxHealth * (Heal.Swing + (if broke then Heal.Pop else 0)))
		node.Model:SetAttribute("LastHitBy", player.UserId)
		node.Model:SetAttribute("LastCrit", false)
		node.Model:SetAttribute("Hp", node.Hp)
		local t = workspace:GetServerTimeNow()
		character:SetAttribute("ActionKind", "Mine")
		character:SetAttribute("ActionStart", t - 0.12)
		character:SetAttribute("ActionAt", t + 0.05)
		local mended = 0
		if broke then
			mended = require(script.Parent.KaijuServer).mend(player, Heal.Kaiju)
			popNode(node, player)
		end
		return reply(true, "", { Healed = math.floor(humanoid.Health - before + 0.5), Broke = broke, Kaiju = mended, Hp = node.Hp, MaxHp = node.MaxHp })
	end
	-- Every rock pays a gem, so a full pouch would waste it: no swinging
	-- (or spending the pick) until there's room.
	if #(profile.Gems or {}) >= Config.MaxGems then
		return reply(
			false,
			string.format("Gem pouch full (%d)! Sell or socket gems to keep mining.", Config.MaxGems),
			{ PouchFull = true }
		)
	end
	local o = record(profile)
	local pickId = o.Active
	local held = if pickId == "Survey" then Rules.surveySwings(o.Picks) else o.Picks[pickId] or 0
	if held <= 0 then
		local _, nextIn = Rules.surveyCharge(o.Picks.Survey or 0, o.SurveyAt or os.time(), os.time())
		return reply(
			false,
			if nextIn
				then "Free pick recharging: +1 swing in "
					.. Rules.clock(nextIn)
					.. ". Buy a refill from Garrick to keep mining."
				else "Out of swings! Buy a refill from Garrick.",
			{ NoPick = true, State = stateOf(player) }
		)
	end
	lastSwing[player] = now
	local strikes = if mech then Rules.mechStrikes(machineId, held) else 1
	-- Noise out past the core: the frontier's critters come for it (and a
	-- vein's guardian for a swing at its rocks).
	task.spawn(OutpostServer.onSwing, player, strikes)
	if veinOf[node.Spot] then
		task.spawn(OutpostServer.onVeinSwing, veinOf[node.Spot], player)
	end
	local swungSpot = site and site.Spots[node.Spot]
	if swungSpot then
		task.spawn(OutpostServer.onRockSwing, swungSpot.Position, player)
	end
	if pickId == "Survey" then
		Rules.spendSurvey(o.Picks, strikes)
	else
		o.Picks[pickId] -= strikes
	end
	local pick = Rules.Picks[pickId]
	local crit = rng:NextNumber() < Rules.CritChance + pick.Crit
	node.Hp = math.max(0, node.Hp - Rules.damage(pickId, crit) * strikes)
	node.ClaimedBy, node.ClaimUntil = player.UserId, now + Rules.ClaimSeconds
	local model = node.Model
	model:SetAttribute("ClaimedBy", player.UserId)
	model:SetAttribute("LastHitBy", player.UserId)
	model:SetAttribute("LastCrit", crit)
	model:SetAttribute("Hp", node.Hp)
	-- The pick chop (RivalPose "Mine": overhead and down), for everyone to see.
	local character = player.Character
	if mech then
		-- The mech's own strike (MechAnimation), for everyone to see.
		mech:SetAttribute("MechStrikeTarget", body.Position + Vector3.new(0, body.Size.Y * 0.3, 0))
		mech:SetAttribute("MechStrikeStart", workspace:GetServerTimeNow() - 0.1)
	elseif character then
		local t = workspace:GetServerTimeNow()
		character:SetAttribute("ActionKind", "Mine")
		character:SetAttribute("ActionStart", t - 0.12)
		character:SetAttribute("ActionAt", t + 0.05)
	end
	local broke = (if pickId == "Survey" then Rules.surveySwings(o.Picks) else o.Picks[pickId]) <= 0
	if broke then
		o.Picks[pickId] = nil
		record(profile)
		pickModel(player)
	end
	local result = {
		Hp = node.Hp,
		MaxHp = node.MaxHp,
		Crit = crit,
		Tension = Rules.tension(node.Hp, node.MaxHp),
		PickBroke = if broke then pick.Name else nil,
		Strikes = strikes,
		State = stateOf(player),
	}
	if node.Hp <= 0 then
		result.Loot = loot(player, node, profile)
		MiningRolls.publish(player, body.Position + Vector3.new(0, body.Size.Y * 0.5, 0), result.Loot)
		popNode(node, player)
		PlayerData.training(player, "Mine")
        if result.Loot and result.Loot.Gem then
            PlayerData.training(player, "MineGem")
            local rank = GemConfig.TierRank[result.Loot.Gem.Tier] or 0
            if rank >= 3 then PlayerData.training(player, "RareGem") end
            if rank >= 5 then PlayerData.training(player, "LegendGem") end
        end
	end
	-- A whole profile goes to the client only when it changed beyond the
	-- pick's swings (a pop pays out, a pick breaks): the reply's State carries
	-- the swings, and a full sync on every swing (three a second) was heavy.
	if node.Hp <= 0 or broke then
		PlayerData.sync(player)
	end
	return reply(true, "", result)
end

-- "OutpostBonk": your pick on a rift's critter (never a wild kaiju), on
-- foot, close, with nothing between you; it shares the rock swing's
-- cooldown and costs no swings (Shared.Frontier.Bonk).
local function bonk(player: Player, model: any)
	local bonker = OutpostServer.bonker
	if not bonker or player:GetAttribute("Outpost") ~= true or player:GetAttribute("CombatSession") then
		return reply(false, "")
	end
	if MechPilot.of(player) or player:GetAttribute("SparWith") ~= nil or Spar.isDown(player) then
		return reply(false, "")
	end
	local now = os.clock()
	local swung, bonked = now - (lastSwing[player] or 0), now - (lastBonk[player] or 0)
	if swung < Rules.SwingCooldown or bonked < Frontier.Bonk.Cooldown then
		return reply(false, "")
	end
	local enemy = typeof(model) == "Instance" and bonker.critterOf(model) or nil
	if not enemy or not enemy.Alive then
		return reply(false, "")
	end
	local root = rootOf(player)
	if not root or (enemy.Root.Position - root.Position).Magnitude > Frontier.Bonk.Reach + 2 then
		return reply(false, "Get closer to it.")
	end
	-- (Nothing solid between you: no bonking through a rock.)
	local blocked = false
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance, model }
		local between = enemy.Root.Position - root.Position
		local hit = workspace:Raycast(root.Position, between, params)
		blocked = hit ~= nil and hit.Instance.CanCollide and hit.Distance < between.Magnitude - 1.5
	end)
	if blocked then
		return reply(false, "")
	end
	lastSwing[player], lastBonk[player] = now, now
	bonker.bonk(enemy, player, root.Position)
	local character = player.Character
	if character then
		local t = workspace:GetServerTimeNow()
		character:SetAttribute("ActionKind", "Mine")
		character:SetAttribute("ActionStart", t - 0.12)
		character:SetAttribute("ActionAt", t + 0.05)
	end
	return reply(true, "", { Bonk = true })
end

-- Swings bought for the free pick (a swing refill, for Robux: StoreServer
-- grants it): into their own bank, stacked on the charge. The free charge
-- is spent first, so it keeps regaining underneath them.
function OutpostServer.addSwings(player: Player, swings: number): boolean
	local profile = PlayerData.get(player)
	if not profile or swings <= 0 then
		return false
	end
	local o = record(profile)
	o.Picks.Extra = (o.Picks.Extra or 0) + swings
	o.Active = "Survey"
	if player:GetAttribute("Outpost") then
		pickModel(player)
	end
	PlayerData.sync(player)
	return true
end

-- A swing restore (Shared.SwingRestore: an arena streak, a dungeon, a
-- coupon): `share` of the free pick's full charge back, never past full.
-- Returns the swings added (0 when it's full already, or no profile).
function OutpostServer.restoreSwings(player: Player, share: number): number
	local profile = PlayerData.get(player)
	if not profile or type(share) ~= "number" or share <= 0 then
		return 0
	end
	local o = record(profile)
	local swings, added = SwingRestore.apply(o.Picks.Survey or 0, share, Rules.Picks.Survey.Swings)
	if added <= 0 then
		return 0
	end
	o.Picks.Survey = swings
	if swings >= Rules.Picks.Survey.Swings then
		-- (Full: its recharge clock waits till a swing is spent.)
		o.SurveyAt = os.time()
	end
	if player:GetAttribute("Outpost") then
		pickModel(player)
	end
	PlayerData.sync(player)
	return added
end

-- How full the free pick is: swings, its full charge.
function OutpostServer.charge(player: Player): (number, number)
	local profile = PlayerData.get(player)
	local full = Rules.Picks.Survey.Swings
	if not profile then
		return 0, full
	end
	return Rules.surveySwings(record(profile).Picks), full
end

local function enter(player: Player)
	if player:GetAttribute("CombatSession") or player:GetAttribute("MatchId") then
		return reply(false, "Finish your fight first.")
	end
	if player:GetAttribute("Expedition") then
		return reply(false, "Return from your expedition first.")
	end
	local root = rootOf(player)
	if not site or not root or not PlayerData.get(player) then
		return reply(false, "The Outpost isn't ready yet. Try again in a moment.")
	end
	pcall(function()
		player:RequestStreamAroundAsync(site.Spawn.Position)
	end)
	local character = player.Character :: Model
	-- (A little apart from each other, the Mole drill still straight ahead.)
	local spawn = site.Spawn * CFrame.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
 local profile = PlayerData.get(player)
 local tutorial = require(ReplicatedStorage.Shared.Tutorial).beat(profile)
 if tutorial and tutorial.Id == "Mine" then
  local closest, distance = nil, math.huge
  for _, node in nodes do
   local body = node.Model.PrimaryPart
   if node.Ready and body and not node.ClaimedBy then
    local d = (body.Position - site.Spawn.Position).Magnitude
    if d < distance then closest, distance = body, d end
   end
  end
  if closest then
   local rock = closest.Position
   local direction = Vector3.new(site.Spawn.Position.X-rock.X,0,site.Spawn.Position.Z-rock.Z)
   direction = if direction.Magnitude > 0.1 then direction.Unit else Vector3.new(0,0,1)
   local at = rock + direction * 9
   local params = RaycastParams.new()
   params.FilterType = Enum.RaycastFilterType.Exclude
   params.FilterDescendantsInstances = {character, nodesFolder}
   local floor = workspace:Raycast(at + Vector3.new(0,60,0), Vector3.new(0,-150,0), params)
   if floor then at = floor.Position + Vector3.new(0,4,0) end
   spawn = CFrame.lookAt(at, Vector3.new(rock.X,at.Y,rock.Z))
  end
 end
 character:PivotTo(spawn)
	player:SetAttribute("Outpost", true)
	refreshKit(player)
	socialPrompts(player, true)
	return reply(true, "Welcome to Saga Outpost.", { State = stateOf(player) })
end

local function leave(player: Player)
	player:SetAttribute("Outpost", nil)
	refreshKit(player)
	socialPrompts(player, false)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if player.Character then
		player.Character:PivotTo(if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(0, 6, 0))
	end
	return reply(true, "Back at base.")
end

-- The Hall of Fame on the Shelter's east wall (Shared.HallOfFame): the PvP
-- and PvE boards, from TopPlayers.
local function drawBoard()
	local face = site and site.Board
	if not face then
		return
	end
	local gui = face:FindFirstChild("Board") :: SurfaceGui?
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = HallOfFame.Canvas
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.Parent = face
	end
	local boards = {}
	local key = tostring(TopPlayers.isGlobal())
	for _, spec in HallOfFame.Boards do
		boards[spec.Id] = TopPlayers.board(spec.Id)
		for _, row in boards[spec.Id] do
			key ..= "|" .. tostring(row.Name) .. ":" .. tostring(row.Value)
		end
	end
	-- (Only when something's changed: it's a few hundred instances.)
	if gui:GetAttribute("Drawn") == key then
		return
	end
	gui:SetAttribute("Drawn", key)
	HallOfFame.draw(gui :: SurfaceGui, boards, TopPlayers.isGlobal())
end

-- An Easter egg found: paid once per player (and a bonus for the full set),
-- told to the whole server. Found again, it just shows its story.
local function secret(player: Player, id: any)
	if player:GetAttribute("Outpost") ~= true then
		return reply(false, "")
	end
	local spec = type(id) == "string" and Rules.Secrets[id] or nil
	local part = spec and secretParts[id]
	if not spec or not part then
		return reply(false, "")
	end
	local root = rootOf(player)
	if not root or (root.Position - part.CFrame.Position).Magnitude > 20 then
		return reply(false, "Get closer.")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your data is still loading.")
	end
	local o = record(profile)
	o.Secrets = o.Secrets or {}
	local new = not o.Secrets[id]
	o.Secrets[id] = true
	local found = 0
	for _ in o.Secrets do
		found += 1
	end
	local total = #Rules.SecretOrder
	local coins, bonus = 0, 0
	if new then
		coins = Rules.SecretReward
		bonus = if found >= total then Rules.SecretBonus else 0
		PlayerData.addCoins(player, coins + bonus)
		ChatChannels.announce(
			"System",
			string.format("%s discovered a secret: %s! (%d/%d)", player.DisplayName, spec.Name, found, total)
		)
		if bonus > 0 then
			ChatChannels.announce("Loot", player.DisplayName .. " has found every secret on the moon!")
		end
	end
	return reply(true, "", {
		Secret = {
			Id = id,
			Name = spec.Name,
			Lore = spec.Lore,
			New = new,
			Found = found,
			Total = total,
			Coins = coins,
			Bonus = bonus,
		},
		State = stateOf(player),
	})
end

function OutpostServer.start()
	site = OutpostWorld.build(Rules.Location, workspace)
	local folder = Instance.new("Folder")
	folder.Name = "Nodes"
	folder.Parent = site.Model
	nodesFolder = folder
	for index in site.Spots do
		freeSpots[index] = true
	end
	for _, index in site.FieldSpots or {} do
		fieldSpots[index] = true
	end
	-- The Rift Veins: their marks, and when each moves on.
	local marks = Instance.new("Folder")
	marks.Name = "Veins"
	marks.Parent = site.Model
	veinFolder = marks
	for v, vein in site.Veins or {} do
		veins[v] = { Site = vein.Site, Spots = vein.Spots, Due = nextDue() }
		for _, spot in vein.Spots do
			veinOf[spot] = v
		end
		markVein(veins[v])
	end
	task.spawn(function()
		while true do
			task.wait(5)
			local ok, err = pcall(OutpostServer._veinTick, os.clock())
			if not ok then
				warn("[Outpost] veins:", err)
			end
		end
	end)
	-- Reserve spaced, reachable mining sites for the healing boulders: round
	-- the welcome field first, then out across the quarry (Outpost.Heal).
	local selected = {}
	local candidates = table.clone(site.NearSpots or {})
	for i in site.Spots do table.insert(candidates, i) end
	for _, index in candidates do
		if #selected >= Heal.Count then break end
		local clear = not veinOf[index] and not healingSpots[index]
		for _, previous in selected do
			if (site.Spots[index].Position - site.Spots[previous].Position).Magnitude < Heal.Apart then clear = false end
		end
		if clear then
			healingSpots[index] = true
			table.insert(selected, index)
			spawnNode(fieldSpots[index] == true, index)
		end
	end
	for _ = 1, math.min(Rules.NodeCount, #site.Spots - #(site.FieldSpots or {})) do
		spawnNode()
	end
	for _ = 1, math.min(Rules.FieldNodeCount, #(site.FieldSpots or {})) do
		spawnNode(true)
	end
	-- Prompts at the Shelter's Store and player Market counters, the
	-- bounty office's counter (the Bounty Board: Client.RiftClient) and
	-- Brutus's duel counter (the duel queue: Client.SocialUI). (The
	-- refills are Garrick's: talk to him.)
	local stations = site.Stations or {}
	local bounty = site.Bounty or {}
	local duel = site.Duel or {}
	for _, spec in
		{
			{ stations.Store, "Store", "Open the Store", "STORE" },
			{ stations.Market, "Market", "Open the Market", "PLAYER MARKET" },
			{ bounty.Counter, "Bounty", "Bounty Board", "BOUNTY OFFICE" },
			{ duel.Counter, "Duels", "Find a duel", "BRUTUS'S DUELS" },
		}
	do
		if not spec[1] then
			continue
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = spec[3], spec[4]
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("PromptKind", spec[2])
		prompt.Parent = spec[1]
	end
	-- The WANTED posters behind Marlo: every boss behind the Rift Gates,
	-- each biome's ladder in turn (Shared.Bounties).
	local posted = 0
	for _, entry in Bounties.list() do
		for _, boss in entry.Bosses do
			posted += 1
			local sheet = (bounty.Posters or {})[posted]
			if sheet then
				local gui = Instance.new("SurfaceGui")
				gui.Name = "Poster"
				gui.Face = Enum.NormalId.Front
				gui.CanvasSize = Bounties.Poster
				gui.LightInfluence = 0.8
				gui.Parent = sheet
				Bounties.poster(gui, boss, entry.Element)
			end
		end
	end
	-- The Shelter's crew, where the Shelter puts them: talk to them (E) for
	-- their lines and stations (Shared.Vendors, Client.Dialogue).
	local crew = Instance.new("Folder")
	crew.Name = "Crew"
	crew.Parent = site.Model
	for _, spot in site.Crew or {} do
		local info = Vendors[spot.Id]
		if info then
			Builder.vendor(crew, spot.CFrame, spot.Id, info)
		end
	end
	-- The hidden Easter eggs: a prompt that says nothing about what it is.
	for _, part in site.Secrets or {} do
		local id = part:GetAttribute("SecretId")
		secretParts[id] = part
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText, prompt.ObjectText = "Inspect", "???"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("PromptKind", "Secret")
		prompt:SetAttribute("SecretId", id)
		prompt.Parent = part
	end
	-- Where a finished duel brings an Outpost visitor back to (ArenaSessions.leave).
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	if not landmarks then
		landmarks = Instance.new("Folder")
		landmarks.Name = "Landmarks"
		landmarks.Parent = ReplicatedStorage
	end
	landmarks:SetAttribute("OutpostSpawn", site.Spawn)

	Shop.register("OutpostEnter", enter)
	Shop.register("OutpostLeave", leave)
	Shop.register("OutpostHit", hit)
	Shop.register("OutpostBonk", bonk)
	Shop.register("OutpostSecret", secret)
	Shop.register("OutpostState", function(player)
		return reply(true, "", { State = stateOf(player) })
	end)

	local function watch(player: Player)
		-- A fight takes the social prompts off (and its end puts them back,
		-- for someone still at the Outpost).
		local function fightChanged()
			refreshKit(player)
			socialPrompts(player, player:GetAttribute("Outpost") == true)
		end
		player:GetAttributeChangedSignal("CombatSession"):Connect(fightChanged)
		player:GetAttributeChangedSignal("MatchId"):Connect(fightChanged)
		-- The combat kit out for a spar, or away again (SparServer).
		player:GetAttributeChangedSignal("Spar"):Connect(fightChanged)
		-- In a kaiju battle, or out of it (KaijuBattles).
		player:GetAttributeChangedSignal("KaijuBattle"):Connect(fightChanged)
		player.CharacterAdded:Connect(function(character)
			-- Back on your feet at the Outpost after a respawn (out of the Rift
			-- too: Server.RiftServer has sent them home).
			if player:GetAttribute("Outpost") then
				task.wait(0.5)
				if player.Character == character and site then
					character:PivotTo(site.Spawn)
					refreshKit(player)
					socialPrompts(player, true)
				end
			end
		end)
		player.CharacterAdded:Connect(function(character)
			-- A rebuilt outfit brings the weapon back: put it away again.
			character.ChildAdded:Connect(function(child)
				if child.Name == "GemsoulGear" and player:GetAttribute("Outpost") then
					task.defer(refreshKit, player)
				end
			end)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	-- A new pickaxe skin (or a switch to a miner with another) goes into
	-- the hand straight away.
	PlayerData.CharacterChanged:Connect(function(player: Player)
		local character = player.Character
		local pick = character and character:FindFirstChild("OutpostPick")
		if pick and pick:GetAttribute("PickSkin") ~= wornPick(PlayerData.get(player)) then
			pickModel(player)
		end
	end)

	-- Never stranded in the world: someone in the Outpost (not fighting)
	-- who has fallen through the floor or wandered far outside the basin is
	-- put back at the spawn.
	task.spawn(function()
		local centre = Rules.Location.Position
		while true do
			task.wait(2)
			if site then
				for _, player in Players:GetPlayers() do
					local root = rootOf(player)
					if
						root
						and player:GetAttribute("Outpost")
						and not player:GetAttribute("CombatSession")
						and not player:GetAttribute("MatchId")
						and not player:GetAttribute("DungeonId")
						and not player:GetAttribute("RiftRun") -- (away in the Rift: Server.RiftServer)
						and not player:GetAttribute("KaijuPit") -- (downstairs: Server.KaijuPitServer)
					then
						local offset = root.Position - centre
						local far = Vector3.new(offset.X, 0, offset.Z).Magnitude > Rules.Radius + 60
						local fell = root.Position.Y < site.Spawn.Position.Y - 120
						if far or fell then
							local character = player.Character :: Model
							character:PivotTo(site.Spawn)
							root.AssemblyLinearVelocity = Vector3.zero
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player], lastBonk[player] = nil, nil
		for _, node in nodes do
			if node.ClaimedBy == player.UserId then
				node.ClaimedBy = nil
			end
		end
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			pcall(drawBoard)
			task.wait(30)
		end
	end)
end

-- For tests.
OutpostServer._hit, OutpostServer._enter, OutpostServer._buy = hit, enter, buy
OutpostServer._secret = secret
OutpostServer._drawBoard = drawBoard
OutpostServer._nodes = nodes
-- For tests.
OutpostServer._veins = veins

function OutpostServer.site()
	return site
end

-- Vein `index`'s Rift Gate: the part its "Enter the Rift" prompt is on.
-- The bounty office's terminal (Server.RiftServer: where a bounty starts from).
function OutpostServer.bountyCounter(): BasePart?
	return site and site.Bounty and site.Bounty.Counter
end

function OutpostServer.veinGate(index: number): BasePart?
	local vein = veins[index]
	local marks = vein and vein.Marks
	local gate = marks and marks:FindFirstChild("RiftGate")
	return gate and gate:FindFirstChild("Heart") :: BasePart?
end

return OutpostServer
