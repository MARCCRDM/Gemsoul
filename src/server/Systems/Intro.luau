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
		local id = if slot == "Weapon" then "MatrixSwords1" else "Armor" .. TUTORIAL_STYLE .. slot .. "1"
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
		state.Version = 3
		PlayerData.sync(player)
	end
	return tutorialReply(profile, true, "Welcome to the Saga.")
end

-- Called only after OutpostServer validates and breaks a real shared rock.
function Intro.tutorialMined(player)
 local profile = PlayerData.get(player)
 local beat = profile and Tutorial.beat(profile)
 if not beat or beat.Id ~= "Mine" then return nil end
 local state = Tutorial.state(profile)
 local gem = tutorialGem(state.Mined + 1)
 if not PlayerData.addGem(player, gem) then return nil end
 state.GemIds = state.GemIds or {}
 state.GemIds[gem.Element] = gem.Id
 state.Mined += 1
 Tutorial.advance(profile, "Mine")
 PlayerData.sync(player)
 return {Gem=gem, Tutorial=true, Rarity=gem.Tier}
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

-- Skip ends guidance without fabricating mining rewards or touching equipment.
local function tutorialSkip(player)
 local profile = PlayerData.get(player)
 if not profile then return reply(false, "Your profile is still loading.") end
 Tutorial.skip(profile)
 PlayerData.sync(player)
 return reply(true, "Tutorial skipped. You're ready to explore.")
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
		table.insert(rows, {
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
		})
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

-- Explicit developer replay: keep owned gear, coins, ranks and existing gems.
local function restartTutorial(player)
	if not TestAdmin.allowed(player.UserId) then
		return reply(false, "This test tool is restricted to test admins.")
	end
	local profile = PlayerData.get(player)
	if not profile then
		return reply(false, "Your profile is still loading.")
	end
	if player:GetAttribute("MatchId") or player:GetAttribute("Expedition") or player:GetAttribute("DuelQueue") then
		return reply(false, "Leave your match, expedition or matchmaking queue first.")
	end
	local occupied = 0
	for _, slot in { "Armor", "Weapon", "Shield", "Surge1", "Surge2", "Surge3" } do
		if profile.Character[slot .. "Gem"] then
			occupied += 1
		end
	end
	for _, slot in { "Armor", "Weapon", "Shield" } do
		local id = if slot == "Weapon" then "MatrixSwords1" else "Armor" .. TUTORIAL_STYLE .. slot .. "1"
		local gems = profile.Character.ItemGems and profile.Character.ItemGems[slot]
		if profile.Character[slot] ~= id and gems and gems[id] then
			occupied += 1
		end
	end
	if #profile.Gems + occupied + #Tutorial.Gems > Config.MaxGems then
		return reply(false, "Make room for your socketed gems plus three tutorial gems first.")
	end
	if player:GetAttribute("CombatSession") then
		require(script.Parent.ArenaSessions).leave(player)
	end
	for _, slot in { "Armor", "Weapon", "Shield", "Surge1", "Surge2", "Surge3" } do
		PlayerData.unsocketGem(player, slot)
	end
	tutorialKit(player)
	-- Starter equipment may already have gems saved on it from an earlier test.
	for _, slot in { "Armor", "Weapon", "Shield" } do
		PlayerData.unsocketGem(player, slot)
	end
	local run = ((profile.Tutorial and profile.Tutorial.Run) or 0) + 1
	profile.Tutorial = { Version = 3, Step = 1, Mined = 0, Done = false, Rocks = {}, Run = run, DevReplay = true }
	profile.Intro.Done = true
	PlayerData.augmentsChanged(player)
	PlayerData.sync(player)
	return reply(true, "Tutorial restarted. Your existing items and progress are kept.")
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
	Shop.register("AdminRestartTutorial", restartTutorial)
	Shop.register("TutorialQueue", tutorialQueue)
	Shop.register("TutorialBegin", tutorialBegin)
	Shop.register("TutorialMine", function() return reply(false, "Click a rock in the mining area.") end)
	Shop.register("TutorialStep", tutorialStep)
	Shop.register("TutorialSkip", tutorialSkip)
end

return Intro
