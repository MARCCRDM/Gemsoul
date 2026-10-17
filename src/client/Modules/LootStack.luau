-- What the miner's loot card shows when finds come quickly (MinerLoot draws
-- it). Pure: no Roblox services, so it's tested on its own.
--
-- A gem opens the card: it rolls, lands, holds, then folds into a one-line
-- row. A gem found while a card is up folds that card at once (its result
-- shows in the row: mining fast skips the suspense) and opens its own. Every
-- rock pays a gem; one that couldn't (the pouch was full) is a row straight
-- away. Rows go after a while, and the oldest go first when there are more
-- than fit.
--
--   LootStack.new() -> stack
--   LootStack.push(stack, loot, now, maxRows) -> the new item, or nil (nothing found)
--   LootStack.update(stack, now, maxRows) -> whether anything changed
--   LootStack.phase(item, now) -> "Rolling" | "Landed" (a card)
local LootStack = {}

LootStack.Roll = 1.4 -- seconds a card rolls before it lands (+ a little per rarity)
LootStack.Hold = 2.6 -- seconds a landed card stays up (+ a little per rarity)
LootStack.RowLife = 6 -- seconds a row stays

local TIER_RANK = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }

export type Item = {
	Id: number,
	Loot: any,
	Rank: number,
	At: number,
	LandAt: number?,
	FoldAt: number?,
	GoneAt: number?,
}
export type Stack = { Card: Item?, Rows: { Item }, Serial: number }

function LootStack.new(): Stack
	return { Card = nil, Rows = {}, Serial = 0 }
end

local function found(loot): boolean
	return type(loot) == "table" and (loot.Gem ~= nil or loot.Full == true)
end

-- Rows newest first; past maxRows the oldest go.
local function addRow(stack: Stack, item: Item, now: number, maxRows: number)
	item.GoneAt = now + LootStack.RowLife
	table.insert(stack.Rows, 1, item)
	while #stack.Rows > maxRows do
		table.remove(stack.Rows)
	end
end

function LootStack.push(stack: Stack, loot, now: number, maxRows: number): Item?
	if not found(loot) then
		return nil
	end
	stack.Serial += 1
	local rank = if loot.Gem then TIER_RANK[loot.Gem.Tier] or 1 else 0
	local item: Item = { Id = stack.Serial, Loot = loot, Rank = rank, At = now }
	if loot.Gem then
		if stack.Card then
			addRow(stack, stack.Card, now, maxRows)
		end
		item.LandAt = now + LootStack.Roll + rank * 0.08
		item.FoldAt = item.LandAt + LootStack.Hold + rank * 0.2
		stack.Card = item
	else
		addRow(stack, item, now, maxRows)
	end
	return item
end

function LootStack.update(stack: Stack, now: number, maxRows: number): boolean
	local changed = false
	local card = stack.Card
	if card and card.FoldAt and now >= card.FoldAt then
		stack.Card = nil
		addRow(stack, card, now, maxRows)
		changed = true
	end
	for i = #stack.Rows, 1, -1 do
		local row = stack.Rows[i]
		if (row.GoneAt and now >= row.GoneAt) or i > maxRows then
			table.remove(stack.Rows, i)
			changed = true
		end
	end
	return changed
end

function LootStack.phase(item: Item, now: number): string
	return if item.LandAt and now < item.LandAt then "Rolling" else "Landed"
end

return LootStack
