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

local function prepareLottery(player: Player)
	local profile = PlayerData.get(player)
	if not profile or profile.Intro.Done then
		return reply(false, "Your starter kit is already claimed.")
	end
	giveStarterKit(player)
	local reward = Lottery.prepare(profile, Gems.random(), function(element)
		return GemRoller.setElement(newGem("StarterSpin"), element)
	end)
	PlayerData.sync(player)
	return reply(true, "Your launch lottery is ready!", { Lottery = reward })
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
	return reply(true, "Nine gemstones attuned. Welcome to Saga Miners!", { Lottery = profile.Intro.Lottery })
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
end

return Intro
