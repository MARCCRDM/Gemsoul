-- Server-owned launch lottery; prepare persists rewards, finish grants nine sockets once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
local GemGenerator = require(script.Parent.GemGenerator)
local Gems = require(script.Parent.Gems)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local TestAdmin = require(script.Parent.TestAdmin)
local Players = game:GetService("Players")

local STARTER_GEMS = 3
local STARTER_MIN_CUT, STARTER_MAX_CUT = 5, 8
local FIRST_STONE_MAX_SIZE = 4 -- a modest first discovery

local reply = Shop.reply

local Intro = {}
local Lottery = require(ReplicatedStorage.Shared.StarterLottery)
local ExpandedTraits = require(ReplicatedStorage.Shared.ExpandedItemTraits)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)

local function newGem(source: string, luck: number?): GemConfig.Gem
	return GemGenerator.generate(Gems.random(), source, {
		Id = PlayerData.newGemId(),
		Time = os.time(),
		Luck = luck,
	})
end

-- Three already-cut gems, like a lottery. At least one is Uncommon or better.
local function generateStarterGems(): { GemConfig.Gem }
	local rng = Gems.random()
	local gems = {}
	for i = 1, STARTER_GEMS do
		local gem = newGem("StarterSpin")
		if i == STARTER_GEMS then
			local allCommon = true
			for _, other in gems do
				allCommon = allCommon and other.Tier == "Common"
			end
			local tries = 0
			while allCommon and gem.Tier == "Common" and tries < 20 do
				gem = newGem("StarterSpin", 1)
				tries += 1
			end
		end
		gem.Cut = rng:NextInteger(STARTER_MIN_CUT, STARTER_MAX_CUT)
		gem.CutMethod = "Starter"
		table.insert(gems, gem)
	end
	return gems
end

-- Replace only the first three loose cargo stones; equipped gems stay intact.
local lastGemRegeneration: { [Player]: number } = {}
local function regenerateStarterGems(player: Player)
	if not TestAdmin.allowed(player.UserId) then
		return reply(false, "This test tool is restricted to the test admin.")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	local now = os.clock()
	if lastGemRegeneration[player] and now - lastGemRegeneration[player] < 3 then
		return reply(false, "Wait three seconds before regenerating again.")
	end
	local gems = generateStarterGems()
	lastGemRegeneration[player] = now
	for i, gem in gems do
		profile.Gems[i] = gem
	end
	PlayerData.sync(player)
	return reply(true, "First three cargo gemstones regenerated.", { Gems = gems })
end

-- Sets the class (Config.OnlyClass) with its starter kit, unless it's set.
local function giveStarterKit(player: Player)
	local character = PlayerData.character(player)
	local classId = Config.OnlyClass or (character and character.Class) or "Warrior"
	local class = Classes.get(classId)
	if class and (not character or character.Class ~= classId) then
		PlayerData.setLoadout(player, classId, Classes.starterWeapon(class, Random.new()).Id, class.Armors[1].Id)
	elseif class and character and not ExpandedTraits.obtainable(Classes.weapon(classId, character.Weapon)) then
		-- An older save still holding a weapon that's switched off (a pistol):
		-- the lottery hands it a fresh weapon roll instead.
		local weapon = Classes.starterWeapon(class, Random.new())
		local profile = PlayerData.get(player)
		local owned = profile and profile.Owned.Weapons[weapon.Id]
		PlayerData.setGearQuality(player, "Weapons", weapon.Id, owned or 1)
		PlayerData.equipGear(player, "Weapons", weapon.Id)
	end
end

-- The ship intro's first step: put on the suit and pick up your starter weapon.
local function suitUp(player: Player)
	local intro = PlayerData.intro(player)
	if not intro or intro.Done then
		return reply(false, "You're already suited up.")
	end
	giveStarterKit(player)
	return reply(true, "Suited up.")
end

local function prepareLottery(player: Player, style, element)
	local profile = PlayerData.get(player)
	if not profile or profile.Intro.Done then
		return reply(false, "Your starter kit is already claimed.")
	end
	if not profile.Intro.Lottery and not Lottery.validChoice(style, element) then
		return reply(false, "Choose an armor style and starter element first.")
	end
	giveStarterKit(player)
	local reward = Lottery.prepareChoice(profile, style, element, function(chosenElement)
		return GemRoller.setElement(newGem("StarterKit"), chosenElement)
	end)
	if reward.Version >= 2 then
		for _, entry in reward.Gear do
			local kind = Slots.Definitions[entry.Slot].Kind
			PlayerData.setGearQuality(player, kind, entry.Id, 1)
			local roll = GearRolls.roll(Random.new(1701), 1, ArmorFamilies.ById[entry.Id])
			roll.Prismatic = nil
			roll.Finish = ({ Prospector = 5, Skirmisher = 3, Juggernaut = 1 })[reward.Style]
			roll.Visor, roll.Variant = 2, 1
			profile.Character.GearRolls[kind][entry.Id] = roll
			PlayerData.equipGear(player, kind, entry.Id)
		end
	end
	PlayerData.sync(player)
	return reply(true, "Your chosen starter kit is ready!", { Lottery = reward })
end
local function quickStart(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	if profile.Intro.Done then
		return reply(true, "Your kit is already ready.")
	end
	local prepared = prepareLottery(player)
	if not prepared.Ok then
		return prepared
	end
	local ok, message = Lottery.finish(profile, Config.MaxGems)
	if not ok then
		return reply(false, message)
	end
	PlayerData.augmentsChanged(player)
	return reply(true, "Starter kit equipped. Q / E / R: your Gem Surges.", { Lottery = profile.Intro.Lottery })
end

local function firstStone(player: Player)
	local intro = PlayerData.intro(player)
	if not intro or intro.FirstStone then
		return reply(false, "You've already had your first stone.")
	end
	local gem = newGem("FirstStone")
	gem.Size = math.min(gem.Size, FIRST_STONE_MAX_SIZE)
	if not PlayerData.addGem(player, gem) then
		return reply(false, "Your gem pouch is full.")
	end
	PlayerData.setIntroFlag(player, "FirstStone")
	return reply(true, "Recovered a naturally cut gem. It is ready to enchant your equipment.", { Gem = gem })
end

-- The tutorial (Shared.Tutorial) -------------------------------------------------

-- Everyone starts in the same Common kit; armor identity comes later, from
-- boss drops. (Skirmisher pieces, a sword and a shield.)
local TUTORIAL_STYLE = "Skirmisher"
local function tutorialKit(player: Player)
	local profile = PlayerData.get(player)
	giveStarterKit(player)
	for _, slot in Lottery.GearOrder do
		local id = if slot == "Weapon" then "SwordShield" else "Armor" .. TUTORIAL_STYLE .. slot .. "1"
		local kind = Slots.Definitions[slot].Kind
		if not profile.Owned[kind][id] then
			PlayerData.setGearQuality(player, kind, id, 1)
			local family = ArmorFamilies.ById[id]
			if family then
				local roll = GearRolls.roll(Random.new(1701), 1, family)
				roll.Prismatic = nil
				roll.Finish, roll.Visor, roll.Variant = 3, 2, 1
				profile.Character.GearRolls[kind][id] = roll
			end
		end
		PlayerData.equipGear(player, kind, id)
	end
end

-- The scripted gem a tutorial rock drops (the nth one mined).
local function tutorialGem(index: number): GemConfig.Gem
	local spec = Tutorial.Gems[index]
	local gem = GemRoller.setElement(newGem("Tutorial"), spec.Element)
	gem.Tier = spec.Tier
	local grade = if spec.Tier == "Common" then 3 else 5
	gem.Size, gem.Clarity, gem.Cut = math.min(gem.Size or grade, FIRST_STONE_MAX_SIZE), grade, grade
	gem.CutMethod = "Starter"
	gem.Role = spec.Role
	if spec.Surge then
		gem.Surge = spec.Surge
		gem.SurgeTier, gem.SurgeRank = 1, if spec.Tier == "Common" then 1 else 2
	end
	return gem
end

local function tutorialReply(profile, ok: boolean, message: string, extra)
	local data = extra or {}
	data.Tutorial = Tutorial.state(profile)
	return reply(ok, message, data)
end

local function tutorialBegin(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	local state = Tutorial.state(profile)
	if not profile.Intro.Done then
		tutorialKit(player)
		profile.Intro.Done = true
		state.Step, state.Mined, state.Done, state.Rocks = 1, 0, false, {}
		state.Version = 2
		PlayerData.sync(player)
	end
	return tutorialReply(profile, true, "Welcome to the Saga.")
end

-- Mines tutorial rock `index` (1-5) if you're standing by it.
local function tutorialMine(player: Player, index: any)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	local state = Tutorial.state(profile)
	local beat = Tutorial.beat(profile)
	if not beat or beat.Id ~= "Mine" then
		return tutorialReply(profile, false, "Nothing to mine here.")
	end
	if type(index) ~= "number" or not Tutorial.Rocks[index] then
		return tutorialReply(profile, false, "Pick a rock.")
	end
	state.Rocks = type(state.Rocks) == "table" and state.Rocks or {}
	if state.Rocks[tostring(index)] then
		return tutorialReply(profile, false, "Already mined.")
	end
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local spawn = landmarks and landmarks:GetAttribute("OutpostSpawn")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if typeof(spawn) ~= "CFrame" or not root then
		return tutorialReply(profile, false, "Head to the Outpost first.")
	end
	local at = (spawn * CFrame.new(Tutorial.Rocks[index])).Position
	local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
	if flat.Magnitude > Tutorial.MineReach then
		return tutorialReply(profile, false, "Get closer to the rock.")
	end
	local gem = tutorialGem(state.Mined + 1)
	if not PlayerData.addGem(player, gem) then
		return tutorialReply(profile, false, "Your gem pouch is full.")
	end
	state.Rocks[tostring(index)] = true
	state.Mined += 1
	Tutorial.advance(profile, "Mine")
	PlayerData.sync(player)
	return tutorialReply(profile, true, "Gem found!", { Gem = gem })
end

-- Ticks off the current beat once it's done (the server checks).
local function tutorialStep(player: Player, beatId: any)
	local profile = PlayerData.get(player)
	if not profile or type(beatId) ~= "string" then
		return reply(false, "Try again.")
	end
	if beatId == "Return" and player:GetAttribute("CombatSession") then
		return reply(false, "Return to the Outpost first.")
	end
	local ok = Tutorial.advance(profile, beatId)
	if ok then
		PlayerData.sync(player)
	end
	return tutorialReply(profile, ok, if ok then "Done." else "Not yet.")
end

-- Skip: you still get the whole kit (any gems not yet mined, with the
-- Surge on Q), then straight on.
local function tutorialSkip(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	if not profile.Intro.Done then
		tutorialBegin(player)
	end
	local state = Tutorial.state(profile)
	if not state.Done then
		while state.Mined < #Tutorial.Gems do
			local gem = tutorialGem(state.Mined + 1)
			if not PlayerData.addGem(player, gem) then
				break
			end
			state.Mined += 1
			if gem.Surge == Tutorial.Gems[4].Surge and not profile.Character.Surge1Gem then
				PlayerData.socketSurge(player, gem.Id, "Q")
			end
		end
		for _, gem in table.clone(profile.Gems) do
			if gem.Surge == Tutorial.Gems[4].Surge and not profile.Character.Surge1Gem then
				PlayerData.socketSurge(player, gem.Id, "Q")
			end
			if gem.Surge == Tutorial.Gems[5].Surge and not profile.Character.Surge2Gem then
				PlayerData.socketSurge(player, gem.Id, "E")
			end
		end
		if not state.Won then
			state.Won = true
			PlayerData.addCoins(player, 50)
			PlayerData.setGearQuality(player, "Armors", "ArmorProspectorArmor1", 1)
		end
		Tutorial.skip(profile)
		if player:GetAttribute("FastTutorial") then
			require(script.Parent.ArenaSessions).leave(player)
		end
		PlayerData.augmentsChanged(player)
		PlayerData.sync(player)
	end
	return tutorialReply(profile, true, "Tutorial skipped. Good luck out there.")
end

-- Private onboarding stock: never competes with or enters the player market.
local STOCK = { "ArmorProspectorHelmet1", "ArmorJuggernautGloves1", "ArmorProspectorBoots1" }
function Intro.tutorialStock(player)
	local profile = PlayerData.get(player)
	local beat = profile and Tutorial.beat(profile)
	if not beat or (beat.Id ~= "OpenMarket" and beat.Id ~= "Buy") then
		return nil
	end
	local rows = {}
	for i, id in STOCK do
		local family = ArmorFamilies.ById[id]
		table.insert(
			rows,
			{
				Id = "Tutorial:" .. i,
				Seller = 0,
				SellerName = "PROBE-7",
				Mode = "Sell",
				State = "Open",
				Price = 15,
				Expires = os.time() + 3600,
				Item = {
					Kind = "Gear",
					Slot = ({ "Helmet", "Gloves", "Boots" })[i],
					Id = id,
					Quality = 1,
					Roll = GearRolls.roll(Random.new(i), 1, family),
				},
				Offers = {},
			}
		)
	end
	return rows
end
function Intro.tutorialBuy(player, listingId)
	local rows = Intro.tutorialStock(player)
	local profile = PlayerData.get(player)
	if not rows or Tutorial.beat(profile).Id ~= "Buy" then
		return reply(false, "Follow the tutorial first.")
	end
	for _, row in rows do
		if row.Id == listingId then
			if profile.Coins < row.Price then
				return reply(false, "Not enough coins.")
			end
			local market = require(ReplicatedStorage.Shared.Market)
			if market.cantReceive(profile, row.Item, Config.MaxGems, Config.MaxGear) then
				return reply(false, "Make room in your inventory.")
			end
			if not market.give(profile, row.Item, Config.MaxGems) then
				return reply(false, "Couldn't add that item.")
			end
			profile.Coins -= row.Price
			Tutorial.state(profile).Purchased = true
			Tutorial.advance(profile, "Buy")
			PlayerData.sync(player)
			return reply(true, "Added to your inventory.")
		end
	end
	return reply(false, "Pick a tutorial item.")
end
function Intro.tutorialVictory(player)
	local profile = PlayerData.get(player)
	if not profile or not Tutorial.beat(profile) or Tutorial.beat(profile).Id ~= "Fight" then
		return
	end
	local state = Tutorial.state(profile)
	if state.Won then
		return
	end
	state.Won = true
	PlayerData.addCoins(player, 50)
	PlayerData.setGearQuality(player, "Armors", "ArmorProspectorArmor1", 1)
	Tutorial.advance(profile, "Fight")
	PlayerData.sync(player)
end
local function tutorialQueue(player)
	local profile = PlayerData.get(player)
	local beat = profile and Tutorial.beat(profile)
	if not beat or (beat.Id ~= "Queue" and beat.Id ~= "Fight") then
		return reply(false, "Not yet.")
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local spawn = landmarks and landmarks:GetAttribute("OutpostSpawn")
	if
		not root
		or typeof(spawn) ~= "CFrame"
		or (root.Position - (spawn * CFrame.new(0, 0, -10)).Position).Magnitude > 18
	then
		return reply(false, "Step onto the Rival pad.")
	end
	local state = Tutorial.state(profile)
	if not state.QueueAt or state.QueueAt > os.time() then
		state.QueueAt = os.time()
		return reply(true, "Queued.", { Waiting = true })
	end
	if os.time() - state.QueueAt < 3 then
		return reply(true, "Queued.", { Waiting = true })
	end
	state.Queued = true
	Tutorial.advance(profile, "Queue")
	PlayerData.sync(player)
	return require(script.Parent.ArenaSessions).enterTraining(player)
end

local function finishIntro(player: Player)
	return quickStart(player)
end

function Intro.start()
	Shop.register("AdminRegenerateGems", regenerateStarterGems)
	Players.PlayerRemoving:Connect(function(player)
		lastGemRegeneration[player] = nil
	end)
	Shop.register("ChooseLoadout", function()
		return reply(false, "All players are Warriors. Roll your launch kit instead.")
	end)
	Shop.register("StarterSpin", prepareLottery)
	Shop.register("PrepareStarterLottery", prepareLottery)
	Shop.register("FinishStarterLottery", quickStart)
	Shop.register("FirstStone", firstStone)
	Shop.register("FinishIntro", finishIntro)
	Shop.register("SuitUp", suitUp)
	Shop.register("QuickStart", quickStart)
	Shop.register("TutorialQueue", tutorialQueue)
	Shop.register("TutorialBegin", tutorialBegin)
	Shop.register("TutorialMine", tutorialMine)
	Shop.register("TutorialStep", tutorialStep)
	Shop.register("TutorialSkip", tutorialSkip)
end

return Intro
