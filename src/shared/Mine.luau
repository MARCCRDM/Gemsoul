--[[
	The mine: rules shared by the server (which decides everything) and the
	menu (which shows it). A wall is a grid of rocks. You get a set number
	of swings; each swing chips one rock, and a broken rock gives what was
	inside. Glinting rocks hide gems, speckled ones hide ore. Clear a wall,
	then descend: deeper walls hold better gems and tougher rock.
]]
local Mine = {}

Mine.Columns = 6
Mine.Rows = 4
Mine.Swings = 14 -- per wall
Mine.TutorialSwings = 20
Mine.CritChance = 0.15 -- a crit chips two layers at once
Mine.WallPrice = 40 -- coins per wall once today's free mines are used up

-- Ore found in the mine, as crafting materials (ids in Shared/Crafting).
Mine.Ores = {
	Iron = { Color = Color3.fromRGB(190, 195, 205) },
	Mithril = { Color = Color3.fromRGB(110, 230, 255) },
	Shards = { Color = Color3.fromRGB(230, 120, 255) },
}

-- Gem luck grows with depth (0-1 on top of the source's own luck).
function Mine.luck(depth: number): number
	return math.min(0.45, (depth - 1) * 0.03)
end

-- Extra layers on every rock as you go deeper.
function Mine.toughness(depth: number): number
	return if depth >= 12 then 2 elseif depth >= 5 then 1 else 0
end

-- Chance an ore rock is Mithril instead of Iron (Shards are separate).
function Mine.mithrilChance(depth: number): number
	return math.min(0.35, 0.04 + depth * 0.02)
end

-- Coins in a coin pouch at this depth.
function Mine.pouch(depth: number): (number, number)
	local scale = 1 + (depth - 1) * 0.15
	return math.floor(8 * scale), math.floor(20 * scale)
end

return Mine
