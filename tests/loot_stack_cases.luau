-- The miner's loot card (LootStack): a gem rolls, lands, holds and folds into
-- a row; a gem found while a card is up folds it at once; coins and gear are
-- rows straight away; rows go after a while, the oldest first.
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function gem(tier)
	return { Name = "Crystal Boulder", Coins = 4, Gem = { Id = "g-" .. tier, Tier = tier, Element = "Frost" } }
end
local function ids(rows)
	local out = {}
	for i, row in rows do
		out[i] = row.Id
	end
	return table.concat(out, ",")
end

-- Nothing found: nothing shown.
local stack = LootStack.new()
check(LootStack.push(stack, { Name = "Regolith Chunk", Coins = 0 }, 0, 3) == nil, "An empty rock made a card")
check(LootStack.push(stack, nil, 0, 3) == nil, "No loot made a card")
check(stack.Card == nil and #stack.Rows == 0, "Nothing found left something on screen")

-- One gem: it rolls, lands, holds, then folds into a row that goes later.
local card = LootStack.push(stack, gem("Rare"), 10, 3)
check(card and stack.Card == card and #stack.Rows == 0, "A gem did not open the card")
check(
	LootStack.phase(card, 10) == "Rolling" and LootStack.phase(card, card.LandAt - 0.01) == "Rolling",
	"Card landed early"
)
check(LootStack.phase(card, card.LandAt) == "Landed", "Card never landed")
check(card.LandAt > 10 and card.FoldAt > card.LandAt + 2, "Card has no time to roll or be read")
check(not LootStack.update(stack, card.FoldAt - 0.01, 3) and stack.Card == card, "Card folded before it was read")
check(LootStack.update(stack, card.FoldAt, 3), "Folding the card was not a change")
check(stack.Card == nil and ids(stack.Rows) == tostring(card.Id), "A read card did not become a row")
check(not LootStack.update(stack, card.FoldAt + LootStack.RowLife - 0.01, 3) and #stack.Rows == 1, "Row went early")
check(LootStack.update(stack, card.FoldAt + LootStack.RowLife, 3) and #stack.Rows == 0, "Row never went")

-- Rarer gems roll and hold a little longer.
local common = LootStack.push(LootStack.new(), gem("Common"), 0, 3)
local legendary = LootStack.push(LootStack.new(), gem("Legendary"), 0, 3)
check(
	legendary.LandAt > common.LandAt and legendary.FoldAt - legendary.LandAt > common.FoldAt - common.LandAt,
	"Rarity did not add suspense"
)
check(legendary.Rank == 5 and common.Rank == 1, "Wrong rarity rank")
check(legendary.FoldAt < 6, "A Legendary card stays up too long")

-- Mining fast: each new gem folds the card before it (newest row first).
stack = LootStack.new()
local first = LootStack.push(stack, gem("Common"), 0, 3)
local second = LootStack.push(stack, gem("UltraRare"), 0.5, 3)
check(stack.Card == second and ids(stack.Rows) == tostring(first.Id), "A second gem did not fold the first")
check(first.GoneAt == 0.5 + LootStack.RowLife, "A folded card's row is not timed from the fold")
check(LootStack.phase(second, 0.5) == "Rolling", "New card skipped its roll")
local third = LootStack.push(stack, gem("Rare"), 0.9, 3)
check(stack.Card == third and ids(stack.Rows) == second.Id .. "," .. first.Id, "Rows not newest first")
-- Coins and gear go straight to a row; the card stays.
local coins = LootStack.push(stack, { Name = "Regolith Chunk", Coins = 6 }, 1.1, 3)
check(stack.Card == third and stack.Rows[1] == coins, "A coin find replaced the card")
check(coins.LandAt == nil and coins.Rank == 0, "A coin find rolled like a gem")
check(#stack.Rows == 3, "Rows not kept to the limit")
local gear = LootStack.push(stack, { Name = "Star Geode", Gear = "Titan Visor" }, 1.2, 3)
check(
	stack.Rows[1] == gear and #stack.Rows == 3 and ids(stack.Rows) == gear.Id .. "," .. coins.Id .. "," .. second.Id,
	"The oldest row did not go first"
)
-- A pouch-full rock (coins, no gem) is a row too.
local full = LootStack.push(stack, { Name = "Crystal Boulder", Coins = 3, Full = true }, 1.3, 3)
check(stack.Rows[1] == full and stack.Card == third, "A full pouch replaced the card")

-- A shorter screen keeps fewer rows.
check(
	LootStack.update(stack, 1.4, 1) and #stack.Rows == 1 and stack.Rows[1] == full,
	"Rows not trimmed to a short screen"
)
check(not LootStack.update(stack, 1.5, 1), "Nothing changed but update said it did")

-- Ten gems in a row: one card, never more rows than fit.
stack = LootStack.new()
for i = 1, 10 do
	LootStack.push(stack, gem(if i % 4 == 0 then "Legendary" else "Uncommon"), i * 0.3, 3)
	check(#stack.Rows <= 3 and stack.Card ~= nil, "Fast mining stacked past the limit")
end
check(stack.Card.Id == 10 and ids(stack.Rows) == "9,8,7", "Fast mining lost the newest finds")
-- Then a pause: the card folds and every row goes.
LootStack.update(stack, 30, 3)
check(stack.Card == nil and #stack.Rows == 1, "The last card did not fold")
LootStack.update(stack, 60, 3)
check(stack.Card == nil and #stack.Rows == 0, "Rows stayed after a pause")

print("PASS: " .. checks .. " loot stack checks")
