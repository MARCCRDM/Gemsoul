--[[
	The menu mine. Request actions:
	  "MineState"            the wall you're digging (if any) and today's free mines
	  "MineStart", tutorial? start a wall at depth 1 (or resume the current one)
	  "MineDescend"          a new wall one level deeper
	  "MineHit", index       swing at a rock (1..Columns*Rows)
	  "MineLeave"            stop digging (depth goes back to 1)
	Each wall costs a free mine (or Mine.WallPrice coins once they're gone).
	Everything is rolled and checked here: the client never learns what a
	rock holds until it breaks, only its hint (glint, gold glint, speck).
	New players get one free tutorial wall with their first stone in it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Crafting = require(ReplicatedStorage.Shared.Crafting)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Mine = require(ReplicatedStorage.Shared.Mine)
local GemGenerator = require(script.Parent.GemGenerator)
local Gems = require(script.Parent.Gems)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Shop = require(script.Parent.Shop)

local reply = Shop.reply

type Tile = {
	Kind: string, -- Stone | Ore | Coins | Gem | Lucky
	Hp: number,
	MaxHp: number,
	Hint: string?, -- Glint | Gold | Speck
	Ore: string?,
	Loot: { [string]: any }?,
}
type Wall = { Depth: number, Swings: number, Tiles: { Tile }, Tutorial: boolean }

local MineWall = {}

local walls: { [Player]: Wall } = {}

local function count(): number
	return Mine.Columns * Mine.Rows
end

-- What the client may see of a rock: its layers and hint, and its loot
-- once it's broken.
local function view(tile: Tile)
	return {
		Hp = tile.Hp,
		MaxHp = tile.MaxHp,
		Hint = if tile.Hp > 0 then tile.Hint else nil,
		OreColor = if tile.Hp > 0 and tile.Ore then Mine.Ores[tile.Ore].Color else nil,
		Loot = tile.Loot,
	}
end

local function wallView(wall: Wall)
	local tiles = {}
	for i, tile in wall.Tiles do
		tiles[i] = view(tile)
	end
	return { Depth = wall.Depth, Swings = wall.Swings, Tiles = tiles, Tutorial = wall.Tutorial }
end

local function quotaInfo(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return nil
	end
	local quota = profile.Quota
	return {
		FreeLeft = math.max(0, math.min(Config.DailyQuota - quota.UsedToday, Config.WeeklyQuota - quota.UsedThisWeek)),
		Daily = Config.DailyQuota,
		Price = Mine.WallPrice,
		BestDepth = profile.Stats and profile.Stats.BestDepth or 0,
	}
end

local function newTile(kind: string, depth: number, rng: Random): Tile
	local tough = Mine.toughness(depth)
	local hp = if kind == "Stone"
		then 1 + tough
		elseif kind == "Coins" then 1 + tough
		elseif kind == "Ore" then 2 + tough
		elseif kind == "Gem" then 3 + tough
		else 4 + tough
	local tile: Tile = { Kind = kind, Hp = hp, MaxHp = hp }
	if kind == "Gem" then
		tile.Hint = "Glint"
	elseif kind == "Lucky" then
		tile.Hint = "Gold"
	elseif kind == "Ore" then
		tile.Hint = "Speck"
		local roll = rng:NextNumber()
		tile.Ore = if roll < Mine.mithrilChance(depth) then "Mithril" elseif roll > 0.85 then "Shards" else "Iron"
	end
	return tile
end

local function buildWall(depth: number, tutorial: boolean): Wall
	local rng = Gems.random()
	local kinds = {}
	local function add(kind: string, n: number)
		for _ = 1, n do
			table.insert(kinds, kind)
		end
	end
	if tutorial then
		add("Gem", 1)
		add("Ore", 3)
		add("Coins", 2)
	else
		local gems = 1
			+ (if rng:NextNumber() < 0.35 then 1 else 0)
			+ (if depth >= 5 and rng:NextNumber() < 0.25 then 1 else 0)
		add("Gem", gems)
		add("Ore", rng:NextInteger(4, 6))
		add("Coins", rng:NextInteger(2, 3))
		if rng:NextNumber() < 0.15 + math.min(0.15, depth * 0.01) then
			add("Lucky", 1)
		end
	end
	add("Stone", count() - #kinds)
	-- Shuffle.
	for i = #kinds, 2, -1 do
		local j = rng:NextInteger(1, i)
		kinds[i], kinds[j] = kinds[j], kinds[i]
	end
	if tutorial then
		-- Put the first stone somewhere obvious, near the middle.
		local middle = (math.floor(Mine.Rows / 2) - 1) * Mine.Columns + math.floor(Mine.Columns / 2)
		local at = table.find(kinds, "Gem") :: number
		kinds[at], kinds[middle] = kinds[middle], kinds[at]
	end
	local tiles = {}
	for i, kind in kinds do
		tiles[i] = newTile(kind, depth, rng)
		if tutorial and kind == "Gem" then
			tiles[i].Hp, tiles[i].MaxHp = 2, 2
		end
	end
	return {
		Depth = depth,
		Swings = if tutorial then Mine.TutorialSwings else Mine.Swings,
		Tiles = tiles,
		Tutorial = tutorial,
	}
end

-- Pays for a wall: a free mine, or coins. Returns false with a message.
local function payForWall(player: Player): (boolean, string?)
	if PlayerData.useFreeMine(player) then
		return true
	end
	if PlayerData.spendCoins(player, Mine.WallPrice) then
		return true
	end
	return false, string.format("No free mines left today. A new wall costs %d coins.", Mine.WallPrice)
end

local function recordDepth(player: Player, depth: number)
	local profile = PlayerData.get(player)
	if profile then
		profile.Stats = profile.Stats or { Kills = 0, BestGem = 0 }
		if depth > (profile.Stats.BestDepth or 0) then
			profile.Stats.BestDepth = depth
		end
	end
end

-- Gives what a broken rock held. Returns the loot description.
local function grant(player: Player, wall: Wall, tile: Tile)
	local rng = Gems.random()
	local profile = PlayerData.get(player)
	if not profile then
		return { Kind = "Stone", Text = "Rubble" }
	end
	if tile.Kind == "Gem" or tile.Kind == "Lucky" then
		local gem
		if wall.Tutorial then
			gem = GemGenerator.generate(rng, "FirstStone", { Id = PlayerData.newGemId(), Time = os.time() })
			gem.Size = math.min(gem.Size, 4)
			if PlayerData.addGem(player, gem) then
				PlayerData.setIntroFlag(player, "FirstStone")
			else
				gem = nil
			end
		else
			local luck = Mine.luck(wall.Depth) + (if tile.Kind == "Lucky" then 0.35 else 0)
			gem = Gems.award(player, "MiningNode", { Luck = luck })
		end
		if not gem then
			return { Kind = "Full", Text = "Pouch full!" }
		end
		PlayerData.milestone(player, "Mined")
		Progress.addXP(player, "Mine")
		local loot = {
			Kind = "Gem",
			Text = GemConfig.displayName(gem),
			Gem = gem,
			Rarity = gem.Tier,
			Lucky = tile.Kind == "Lucky",
		}
		if tile.Kind == "Lucky" then
			local lo, hi = Mine.pouch(wall.Depth)
			local coins = rng:NextInteger(lo, hi) * 2
			PlayerData.addCoins(player, coins)
			loot.Coins = coins
		end
		return loot
	elseif tile.Kind == "Ore" then
		local id = tile.Ore or "Iron"
		local amount = if id == "Iron" then rng:NextInteger(1, 3) else 1
		profile.Materials[id] = (profile.Materials[id] or 0) + amount
		PlayerData.sync(player)
		local material = Crafting.Materials[id]
		return { Kind = "Ore", Material = id, Count = amount, Text = (if material then material.Name else id) }
	elseif tile.Kind == "Coins" then
		local lo, hi = Mine.pouch(wall.Depth)
		local coins = rng:NextInteger(lo, hi)
		PlayerData.addCoins(player, coins)
		return { Kind = "Coins", Count = coins, Text = "Coin pouch" }
	end
	-- Plain stone: sometimes a coin or two in the rubble.
	if rng:NextNumber() < 0.3 then
		local coins = rng:NextInteger(1, 3)
		PlayerData.addCoins(player, coins)
		return { Kind = "Coins", Count = coins, Text = "Loose coins" }
	end
	return { Kind = "Stone", Text = "Rubble" }
end

local function mineState(player: Player)
	local wall = walls[player]
	return reply(true, "", { Wall = wall and wallView(wall), Quota = quotaInfo(player) })
end

local function mineStart(player: Player, tutorial: any)
	local current = walls[player]
	if current and current.Swings > 0 then
		return reply(true, "Back to the rock face.", { Wall = wallView(current), Quota = quotaInfo(player) })
	end
	if tutorial == true then
		local intro = PlayerData.intro(player)
		if not intro or intro.Done or intro.FirstStone then
			return reply(false, "You've already dug your first stone.")
		end
		walls[player] = buildWall(1, true)
		return reply(true, "Your first dig!", { Wall = wallView(walls[player]), Quota = quotaInfo(player) })
	end
	local ok, message = payForWall(player)
	if not ok then
		return reply(false, message :: string, { Quota = quotaInfo(player) })
	end
	walls[player] = buildWall(1, false)
	recordDepth(player, 1)
	return reply(true, "Depth 1. Swing away!", { Wall = wallView(walls[player]), Quota = quotaInfo(player) })
end

local function mineDescend(player: Player)
	local current = walls[player]
	if not current then
		return mineStart(player, false)
	end
	if current.Tutorial then
		return reply(false, "Finish your first dig first.")
	end
	local ok, message = payForWall(player)
	if not ok then
		return reply(false, message :: string, { Quota = quotaInfo(player) })
	end
	local depth = current.Depth + 1
	walls[player] = buildWall(depth, false)
	recordDepth(player, depth)
	return reply(true, string.format("Depth %d!", depth), { Wall = wallView(walls[player]), Quota = quotaInfo(player) })
end

local function mineHit(player: Player, index: any)
	local wall = walls[player]
	if not wall then
		return reply(false, "Start a wall first.")
	end
	if typeof(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > count() then
		return reply(false, "Pick a rock.")
	end
	local tile = wall.Tiles[index]
	if tile.Hp <= 0 then
		return reply(false, "Already broken.")
	end
	if wall.Swings <= 0 then
		return reply(false, "Out of swings. Descend for a new wall!")
	end
	wall.Swings -= 1
	local crit = Gems.random():NextNumber() < Mine.CritChance
	tile.Hp = math.max(0, tile.Hp - (if crit then 2 else 1))
	local loot = nil
	if tile.Hp == 0 then
		loot = grant(player, wall, tile)
		tile.Loot = loot
	end
	return reply(true, "", {
		Index = index,
		Tile = view(tile),
		Crit = crit,
		Loot = loot,
		Swings = wall.Swings,
		Quota = quotaInfo(player),
	})
end

local function mineLeave(player: Player)
	walls[player] = nil
	return reply(true, "See you at the rock face.")
end

function MineWall.clear(player: Player)
	walls[player] = nil
end

function MineWall.start()
	Shop.register("MineState", mineState)
	Shop.register("MineStart", mineStart)
	Shop.register("MineDescend", mineDescend)
	Shop.register("MineHit", mineHit)
	Shop.register("MineLeave", mineLeave)
	game:GetService("Players").PlayerRemoving:Connect(MineWall.clear)
end

return MineWall
