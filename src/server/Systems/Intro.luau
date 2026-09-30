--[[
	Server side of the new-player intro. Each step is a request action:
	  "ChooseLoadout", classId, weaponId, armorId   pick class and starter gear
	  "StarterSpin"                                 three random cut gems, once
	  "FirstStone"                                  a small rough stone to learn
	                                                cutting on, once
	  "FinishIntro"                                 done: gear appears in the world
	  "QuickStart"                                  the short intro's finish: the
	                                                class (Config.OnlyClass), starter
	                                                gems if not had yet, and done
	Socketing the first gem is Enchanting's "SocketGem".
	Everything is validated here; the client only asks.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemGenerator = require(script.Parent.GemGenerator)
local Gems = require(script.Parent.Gems)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local STARTER_GEMS = 3
local STARTER_MIN_CUT, STARTER_MAX_CUT = 5, 8
local FIRST_STONE_MAX_SIZE = 4 -- small stones are easier to cut by hand

local reply = Shop.reply

local Intro = {}

local function newGem(source: string, luck: number?): GemConfig.Gem
	return GemGenerator.generate(Gems.random(), source, {
		Id = PlayerData.newGemId(),
		Time = os.time(),
		Luck = luck,
	})
end

local function chooseLoadout(player: Player, classId: any, weaponId: any, armorId: any)
	local intro = PlayerData.intro(player)
	if intro and intro.Done then
		return reply(false, "Your class is already chosen. Class trainers will offer changes later.")
	end
	if Config.OnlyClass and classId ~= Config.OnlyClass then
		return reply(false, "Only the " .. Config.OnlyClass .. " is available for now.")
	end
	if not Classes.get(classId) or not Classes.weapon(classId, weaponId) or not Classes.armor(classId, armorId) then
		return reply(false, "That class and gear don't go together.")
	end
	PlayerData.setLoadout(player, classId, weaponId, armorId)
	return reply(true, "Loadout saved.")
end

-- Three already-cut gems, like a lottery. At least one is Uncommon or better.
local function rollStarterGems(player: Player): { GemConfig.Gem }
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
	for _, gem in gems do
		PlayerData.addGem(player, gem)
	end
	PlayerData.setIntroFlag(player, "Spun")
	return gems
end

local function starterSpin(player: Player)
	local intro = PlayerData.intro(player)
	if not intro or intro.Spun then
		return reply(false, "You've already spun for your starter gems.")
	end
	return reply(true, "Your starter gems!", { Gems = rollStarterGems(player) })
end

-- The short intro's last step: set the class, hand out the starter gems
-- (once), and finish.
local function quickStart(player: Player)
	local intro = PlayerData.intro(player)
	if not intro then
		return reply(false, "Try again in a moment.")
	end
	local character = PlayerData.character(player)
	local classId = Config.OnlyClass or (character and character.Class) or "Warrior"
	local class = Classes.get(classId)
	if class and (not character or character.Class ~= classId) then
		PlayerData.setLoadout(player, classId, class.Weapons[1].Id, class.Armors[1].Id)
	end
	local gems = if intro.Spun then {} else rollStarterGems(player)
	PlayerData.setIntroFlag(player, "Done")
	return reply(true, "Welcome to Gemsoul!", { Gems = gems })
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
	return reply(true, "Here's a rough stone to practise on.", { Gem = gem })
end

local function finishIntro(player: Player)
	local character = PlayerData.character(player)
	if not character or not character.Class then
		return reply(false, "Choose a class first.")
	end
	PlayerData.setIntroFlag(player, "Done")
	return reply(true, "Welcome to Gemsoul!")
end

function Intro.start()
	Shop.register("ChooseLoadout", chooseLoadout)
	Shop.register("StarterSpin", starterSpin)
	Shop.register("FirstStone", firstStone)
	Shop.register("FinishIntro", finishIntro)
	Shop.register("QuickStart", quickStart)
end

return Intro
