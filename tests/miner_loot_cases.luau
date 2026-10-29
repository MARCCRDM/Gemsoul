-- Your own finds (MinerLoot): a gem rolls on a card, lands on the real gem
-- with its stats as bars; finds that come quickly stack as rows above it.
-- On a computer: compact, in the bottom right corner, two rows at most.
-- On a phone: slim, in the top right under the toast's place (lower while a
-- toast wraps), one row under it (a small phone's once the card's gone).
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
math.randomseed(5)
local function gem(tier, size, clarity, cut)
	return {
		Name = "Crystal Boulder",
		Gem = { Id = "g-" .. tier, Tier = tier, Element = "Frost", Size = size, Clarity = clarity, Cut = cut },
	}
end
local function commas(n)
	local text = tostring(math.floor(n + 0.5))
	repeat
		local count
		text, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end
local function card()
	return live("LootCard")[1]
end
local function lit(frame, color)
	local n = 0
	for _, o in frame:GetDescendants() do
		if o.ClassName == "Frame" and o.Name == "Segment" and o.BackgroundColor3 == color then
			n += 1
		end
	end
	return n
end

-- Nothing found, nothing shown (rocks pay gems only: coins or gear never show).
Loot.push({ Name = "Regolith Chunk" })
Loot.push({ Name = "Regolith Chunk", Coins = 6, Gear = "Titan Visor" })
check(#live("LootCard") == 0 and #live("LootRow") == 0, "A rock with no gem showed something")

-- A rock that couldn't pay its gem (a full pouch) is a row straight away, in red.
Loot.push({ Name = "Regolith Chunk", Full = true })
check(#live("LootRow") == 1 and #live("LootCard") == 0, "A full pouch did not make one row")
check(texts(live("LootRow")[1]):find("Gem pouch full", 1, true), "Full pouch row lost its words")
check(not texts(live("LootRow")[1]):find("◆", 1, true), "A full pouch row shows coins")
check(render:Count() == 1, "No frame loop while something is on show")

-- A gem: it rolls through rarities, then lands on the real one.
local find = gem("UltraRare", 8, 6, 7)
local color = GemConfig.TierColors.UltraRare
Loot.push(find)
check(card() and #live("LootCard") == 1, "A gem did not open the card")
check(texts(card()):find("ROLLING  ·  CRYSTAL BOULDER", 1, true), "Rolling card does not say what it's rolling")
check(not texts(card()):find(GemConfig.shade(find.Gem).Name, 1, true), "Gem named before it landed")
local reel = card():GetDescendants()
local views = 0
for _, o in reel do
	if o.ClassName == "ViewportFrame" then
		views += 1
	end
end
check(views >= 3, "The reel shows no gems")
step(0.5)
check(ticks > 0, "The reel rolled without a sound")
check(not texts(card()):find("≈", 1, true), "Worth shown while rolling")
check(#sounds == 0, "Landed early")
step(1.3)
local words = texts(card())
check(words:find(GemConfig.shade(find.Gem).Name, 1, true), "Landed card lost the gem's name")
check(
	words:find(string.upper(GemConfig.TierLabels.UltraRare), 1, true)
		and words:find(string.upper(GemConfig.elementName("Frost")), 1, true),
	"Landed card lost rarity or element"
)
check(words:find("≈ " .. commas(GemConfig.value(find.Gem)) .. " ◆", 1, true), "Landed card lost the gem's worth")
check(sounds[#sounds] == 4, "Landing did not play the rarity's sound")
-- The bars fill after the landing, each to the gem's own number.
step(1)
check(lit(card(), color) == 8 + 6 + 7, "Bars do not match Size, Clarity and Cut")
words = texts(card())
for _, value in { "8", "6", "7" } do
	check(
		words:find("\n" .. value .. "\n", 1, true) or words:find("\n" .. value .. "$"),
		"Bar missing its number " .. value
	)
end

-- Mining fast: a new gem folds the card into a row and rolls its own.
local before = #live("LootRow")
local first = card()
Loot.push(gem("Common", 3, 4, 2))
step(0.05)
check(first.Destroyed and card() ~= first, "A new gem did not replace the card")
check(#live("LootRow") == before + 1, "The folded card did not become a row")
local newest = Loot.shown().Rows[1]
check(newest.Loot == find, "The folded gem is not the newest row")
check(texts(card()):find("ROLLING", 1, true), "The new card skipped its roll")
-- More finds than fit: never past two rows on a desktop.
for i = 1, 6 do
	Loot.push(if i % 2 == 0 then gem("Rare", 5, 5, 5) else { Name = "Star Geode", Full = true })
	step(0.1)
end
check(#live("LootRow") <= 2 and #Loot.shown().Rows <= 2, "Rows stacked past two")
check(#live("LootCard") == 1, "More than one card")

-- A pouch-full rock says so in red.
Loot.push({ Name = "Crystal Boulder", Full = true })
step(0.05)
local fullRow = nil
for _, row in live("LootRow") do
	if texts(row):find("Gem pouch full", 1, true) then
		fullRow = row
	end
end
check(fullRow ~= nil, "Full pouch not shown")

-- A phone: slim, in the top right under the toast's place (MobileLayout.loot),
-- out of the way of you and the dock: the reel, then the rarity, the name and
-- the worth one under another, no bars, and one row under it. The top is the
-- card's while it's up (the live feed steps aside).
check(not MobileLayout.topClaimed(), "A computer's card claimed a phone's top middle")
local gui = live("MinerLoot")[1]
for _, screen in { { X = 667, Y = 339 }, { X = 844, Y = 332 } } do
	gui.AbsoluteSize = screen
	gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	local holder = live("Stack")[1]
	local spot = MobileLayout.loot(screen)
	local at = screen.X .. "x" .. screen.Y .. ": "
	check(holder.AnchorPoint.Y == 0 and holder.Position.Y.Scale == 0, at .. "the card isn't hung from the top")
	check(
		holder.Position.X.Offset == spot.X and holder.Position.Y.Offset == spot.Y,
		at .. "the card isn't under the toast's place"
	)
	check(holder.Size.X.Offset == spot.W and holder.Size.Y.Offset == spot.H, at .. "the card isn't slim")
	check(holder:FindFirstChildOfClass("UIScale").Scale == 1, at .. "the slim card was scaled down")
	-- (what was on show is built again at the new size)
	check(
		#live("LootCard") == 1 and card().Size.X.Offset == spot.W and card().Size.Y.Offset == spot.H,
		at .. "the card wasn't rebuilt slim"
	)
end
local slimFind = gem("Rare", 9, 9, 9)
Loot.push(slimFind)
step(2)
local slim = card()
local slimSpot = MobileLayout.loot(gui.AbsoluteSize)
check(slim and slim.Size.Y.Offset == slimSpot.H and slimSpot.H <= MobileLayout.Loot.H, "A phone's new card isn't slim")
check(lit(slim, GemConfig.TierColors.Rare) == 0, "A slim card drew the stat bars")
local slimWords = texts(slim)
check(slimWords:find(GemConfig.shade(slimFind.Gem).Name, 1, true), "The slim card lost the gem's name")
check(
	slimWords:find("≈ " .. commas(GemConfig.value(slimFind.Gem)) .. " ◆", 1, true),
	"The slim card lost the gem's worth"
)
check(MobileLayout.topClaimed(), "The card up on a phone didn't claim the top middle")
-- Three lines beside the reel, each the card's width: the worth has one of
-- its own, under the name, so a long name still fits.
local lines = {}
for _, label in slim:GetDescendants() do
	if label.ClassName == "TextLabel" and label.Text ~= "" and label.Visible ~= false then
		table.insert(lines, label)
	end
end
table.sort(lines, function(a, b)
	return a.Position.Y.Offset < b.Position.Y.Offset
end)
check(#lines == 3, "The slim card isn't three lines")
for i, label in lines do
	check(label.Position.Y.Offset + label.Size.Y.Offset <= slimSpot.H, "A slim card's line runs off it")
	check(label.Position.X.Offset + label.Size.X.Offset <= slimSpot.W, "A slim card's line runs off its side")
	check(label.Size.X.Offset == lines[1].Size.X.Offset, "The slim card's lines aren't all its width")
	if i > 1 then
		local above = lines[i - 1]
		check(label.Position.Y.Offset >= above.Position.Y.Offset + above.Size.Y.Offset, "The slim card's lines overlap")
	end
end
check(lines[3].Text:find("◆", 1, true), "The worth isn't the slim card's last line")
-- A toast that wraps past its place pushes the card down while it's up; it
-- goes back once the toast's gone.
local stackHolder = live("Stack")[1]
UiKit.ToastBottom = slimSpot.Y + 20
UiKit.ToastMoved:Fire()
check(
	stackHolder.Position.Y.Offset == slimSpot.Y + 20 + MobileLayout.Loot.Gap,
	"A wrapped toast didn't push the card down"
)
UiKit.ToastBottom = 0
UiKit.ToastMoved:Fire()
check(stackHolder.Position.Y.Offset == slimSpot.Y, "The card didn't go back up when the toast went")
Loot.push(gem("Common", 3, 4, 2))
step(0.1)
check(#live("LootRow") == 1, "A phone kept more than one row")
local row = live("LootRow")[1]
step(0.5)
check(row.Position.Y.Offset >= slimSpot.H, "The row isn't under the slim card")
check(row.Size.X.Offset == card().Size.X.Offset, "The row isn't the card's width")
-- (slim, the row has no room for the rarity's name: its colour says it)
check(not texts(row):find("COMMON", 1, true) and texts(row):find("◆", 1, true), "The slim row's words don't fit")
-- A small phone's card is full height too (nothing's under it at the top
-- right any more): the row shows under it while it's up, then moves up
-- where the card was.
gui.AbsoluteSize = { X = 667, Y = 339 }
gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
local small = MobileLayout.loot(gui.AbsoluteSize)
check(small.H == MobileLayout.Loot.H, "667x339 got a short card")
Loot.push(gem("Uncommon", 4, 4, 4))
step(0.1)
row = live("LootRow")[1]
check(card() and row and not row.Visible, "A small phone's history row overlaps the enlarged card/party controls")
step(5)
row = live("LootRow")[1]
check(card() == nil and row and row.Visible, "The row went once the card folded")
step(0.5)
check(row.Position.Y.Offset + row.Size.Y.Offset <= small.H, "The row isn't where the card was")
Loot.push(gem("Common", 3, 4, 2))
local holder = live("Stack")[1]
gui.AbsoluteSize = { X = 1366, Y = 710 }
gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
-- Back on a computer: the compact card in the bottom right corner, above the
-- key hints, clear of the middle of the screen.
local corner = Loot.Corner
local function inCorner()
	return holder.AnchorPoint.X == 1
		and holder.AnchorPoint.Y == 1
		and holder.Position.X.Scale == 1
		and holder.Position.X.Offset == -corner.Right
		and holder.Position.Y.Scale == 1
		and holder.Position.Y.Offset == -corner.Bottom
end
check(inCorner() and holder:FindFirstChildOfClass("UIScale").Scale == 1, "Desktop fit not restored")
local desk = card()
check(
	desk.Size.X.Offset == 320 and desk.Size.Y.Offset == 108 and lit(desk, GemConfig.TierColors.Common) >= 0,
	"The larger desktop card wasn't rebuilt"
)
check(1366 - corner.Right - desk.Size.X.Offset > 1366 / 2 + 200, "The card reaches into the middle of the screen")
check(not MobileLayout.topClaimed(), "A computer's card kept the top middle")
-- Two rows above it, both clear of the noise ring (halfway down plus Below).
Loot.push(gem("Rare", 5, 5, 5))
step(0.05)
Loot.push(gem("Uncommon", 4, 4, 4))
step(0.05)
Loot.push(gem("Common", 3, 3, 3))
step(0.5)
local deskRows = live("LootRow")
check(#deskRows == 2, "Not two rows above a computer's card: " .. #deskRows)
local cardTop = 710 - corner.Bottom - desk.Size.Y.Offset
for _, row in deskRows do
	check(row.Visible ~= false, "A row hid on a computer with room for it")
	check(row.Position.Y.Offset < 0, "A row isn't above the card")
	check(cardTop + row.Position.Y.Offset >= 710 / 2 + corner.Below, "A row reaches the noise ring")
end
-- A short window: no room above the card, so the row waits until it's gone.
gui.AbsoluteSize = { X = 1100, Y = 560 }
gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
step(0.05)
local shortRows = live("LootRow")
check(card() and #shortRows >= 1, "Nothing to show on a short window")
for _, row in shortRows do
	check(not row.Visible, "A row showed above the card on a short window")
end
step(6)
shortRows = live("LootRow")
check(card() == nil and #shortRows == 1 and shortRows[1].Visible, "The row didn't come back once the card folded")
check(shortRows[1].Position.Y.Offset >= 0, "The row isn't where the card was")
gui.AbsoluteSize = { X = 1366, Y = 710 }
gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
Loot.push(gem("Common", 3, 4, 2))
-- In a mech it stays put: its HOP OUT is bottom middle (MobileLayout.Drive).
localPlayer:SetAttribute("MechPilot", 1)
check(inCorner(), "The card moved in a mech")
local drive = MobileLayout.Drive
check(1366 - corner.Right - desk.Size.X.Offset > 1366 / 2 + drive.W / 2, "The card overlaps HOP OUT")
localPlayer:SetAttribute("MechPilot", nil)
check(inCorner(), "The card moved after hopping out")

-- A Legendary: its window over you as the card lands, not before; nothing
-- for a lesser find.
do
	local before = #legendaries
	Loot.push(gem("UltraRare", 5, 5, 5))
	step(4)
	check(#legendaries == before, "A lesser find opened the Legendary window")
	local at = now
	Loot.push(gem("Legendary", 8, 8, 8))
	step(0.5)
	check(#legendaries == before, "The Legendary window opened before the card landed")
	-- Mined again at once: the card folds, the window still comes.
	Loot.push(gem("Common", 2, 2, 2))
	step(2)
	local shown = legendaries[#legendaries]
	check(#legendaries == before + 1 and shown.Gem.Tier == "Legendary" and shown.Finder == nil, "Your Legendary opened no window")
	check(shown.At - at >= 1.4 and shown.At - at <= 2, "The window didn't come as the card landed: " .. (shown.At - at))
	step(10)
end

-- A menu or a fight has the screen: hidden and silent, then back.
Loot.setBlocked(true)
check(gui.Enabled == false, "Card shown over a menu")
local heard, ticked = #sounds, ticks
Loot.push(gem("Legendary", 9, 9, 9))
step(2)
check(#sounds == heard and ticks == ticked, "Hidden card still played sounds")
Loot.setBlocked(false)
check(gui.Enabled == true, "Card stayed hidden")

-- Left alone, it all goes, and the frame loop stops.
step(15)
check(#live("LootCard") == 0 and #live("LootRow") == 0, "Card or rows stayed after a pause")
check(render:Count() == 0, "Frame loop kept running with nothing on show")

-- Leaving the Outpost clears everything at once.
Loot.push(gem("Rare", 5, 5, 5))
Loot.push({ Name = "Regolith Chunk", Coins = 2 })
Loot.close()
check(#live("LootCard") == 0 and #live("LootRow") == 0 and render:Count() == 0, "Close left loot on screen")
Loot.push(gem("Rare", 5, 5, 5))
check(#live("LootCard") == 1, "No card after closing and mining again")
Loot.close()

print("PASS: " .. checks .. " miner loot card checks")
