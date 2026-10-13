local checks = 0
local function check(ok, message) checks += 1; assert(ok, message) end
local function loot(tier, id)
	return { Gem = { Id = id or tier, Element = "Frost", Tier = tier, Size = 8, Clarity = 7, Cut = 6 }, Coins = 4 }
end
local function winner()
	for _, o in objects do
		if not o.Destroyed and o.Name == "ReelCell" and math.abs(o.Position.Y.Offset - 23) < 0.01 then
			for _, child in o:GetChildren() do
				if child.Name == "Stone" then return child:FindFirstChildOfClass("ViewportFrame").Gem end
			end
		end
	end
end
-- Cosmetic RNG always rolls Common here: it must still stop on the server gem.
for rank, tier in GemConfig.TierOrder do
	local result = loot(tier)
	Reveal.push(result)
	check(liveCount("ScreenGui") == 1, "Missing/duplicate reel")
	step(3)
	check(winner() == result.Gem, "Reel landed on cosmetic preview instead of awarded gem")
	check(sounds[#sounds] == rank and labelWith(string.upper(GemConfig.TierLabels[tier])), "Wrong rarity label/sound")
	check(liveCount("ViewportFrame") <= 13, "Reel allocates unbounded viewports")
	check(liveCount("Frame") > 0 and labelWith("Added to your gem inventory  ·  +4 coins"), "Reward information omitted")
	find("RevealOrContinue").Activated:Fire()
	step(0.3)
	check(liveCount("ScreenGui") == 0 and liveCount("ViewportFrame") == 0, "Reveal leaked UI or templates")
end
-- Rapid consecutive rewards queue; revealing early cannot choose/reroll the gem.
Reveal.push(loot("Legendary", "first"))
Reveal.push(loot("Uncommon", "second"))
check(liveCount("ScreenGui") == 1, "Simultaneous finds overlap")
find("RevealOrContinue").Activated:Fire()
step(0.1)
check(winner().Id == "first", "Skip discarded first find")
find("RevealOrContinue").Activated:Fire()
step(0.3)
find("RevealOrContinue").Activated:Fire()
step(0.1)
check(winner().Id == "second", "Queued gem was overwritten")
Reveal.close()
step(1)
check(liveCount("ViewportFrame") == 0 and #pending == 0, "Close left animations alive")
-- Phone sizing, rotation and cancel/reopen while the old worker is sleeping.
viewport = { X = 390, Y = 740 }
Reveal.push(loot("Rare", "old"))
local anchor = find("ResponsiveBoard")
local fit = anchor:FindFirstChildOfClass("UIScale")
check(660 * fit.Scale <= 366 and 342 * fit.Scale < 708, "Phone layout clips")
local screen = find("MiningGemRoll")
screen.AbsoluteSize = { X = 844, Y = 390 }
screen:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(342 * fit.Scale <= 358, "Landscape phone clips vertically")
Reveal.close()
Reveal.push(loot("UltraRare", "new"))
step(3)
check(winner().Id == "new", "Old worker cancelled or rewrote a new reveal")
Reveal.close()
step(1)
check(liveCount("ViewportFrame") == 0 and liveCount("ScreenGui") == 0 and #pending == 0, "Final cleanup leaked")
print("PASS: " .. checks .. " mining reel checks; all rarities, exact awards, queue, skip, responsive fit and cancellation")
