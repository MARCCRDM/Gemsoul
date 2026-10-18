-- Your own finds (MinerLoot): a gem rolls on a card, lands on the real gem
-- with its stats as bars; finds that come quickly stack as rows above it.
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
		if
			o.ClassName == "Frame"
			and o.Size.X.Offset == 11
			and o.Size.Y.Offset == 8
			and o.BackgroundColor3 == color
		then
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
-- More finds than fit: never past three rows on a desktop.
for i = 1, 6 do
	Loot.push(if i % 2 == 0 then gem("Rare", 5, 5, 5) else { Name = "Star Geode", Full = true })
	step(0.1)
end
check(#live("LootRow") <= 3 and #Loot.shown().Rows <= 3, "Rows stacked past three")
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

-- A phone: above the dock, smaller, one row.
local gui = live("MinerLoot")[1]
gui.AbsoluteSize = { X = 844, Y = 332 }
gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
local holder = live("Stack")[1]
check(holder.Position.Y.Offset == -104 and holder:FindFirstChildOfClass("UIScale").Scale < 1, "Phone fit missing")
step(0.1)
check(#live("LootRow") <= 1, "A phone kept more than one row")
gui.AbsoluteSize = { X = 1366, Y = 710 }
gui:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(
	holder.Position.Y.Offset == -64 and holder:FindFirstChildOfClass("UIScale").Scale == 1,
	"Desktop fit not restored"
)
-- In a mech: above its driving card (MobileLayout.Drive), then back down.
local drive = MobileLayout.Drive
localPlayer:SetAttribute("MechPilot", 1)
check(holder.Position.Y.Offset == -(drive.Bottom + drive.H + 10), "The card sits on the mech's driving card")
localPlayer:SetAttribute("MechPilot", nil)
check(holder.Position.Y.Offset == -64, "The card stayed up after hopping out")

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
