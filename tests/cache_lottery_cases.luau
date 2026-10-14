
local checks = 0
local function check(ok, message) checks += 1; assert(ok, message) end
-- The piece in the display's window (the reel cell at its stop).
local function landedPiece()
	for _, o in objects do
		if not o.Destroyed and o.Name == "ReelCell" and math.abs(o.Position.Y.Offset - 23) < 0.01 then
			for _, child in o:GetChildren() do
				if child.Name == "Piece" then return child:GetChildren()[1] end
			end
		end
	end
end
local function press(name) find(name).Activated:Fire() end
local function count(name)
	local n = 0
	for _, o in objects do if not o.Destroyed and o.Name == name then n += 1 end end
	return n
end
local function gemEntry(offer, tier, id, flawless)
	local gem = { Id = id, Element = "Frost", Tier = tier, Size = 8, Clarity = 7, Cut = 6 }
	if flawless then gem.Size, gem.Clarity, gem.Cut, gem.Flawless = 10, 10, 10, true end
	return { OfferId = offer, Free = true, Rarity = tier, Name = "Gem " .. id, Item = { Kind = "Gem", Gem = gem } }
end
local function gearEntry(offer, slot, tier, quality, stats)
	return { OfferId = offer, Rarity = tier, Name = tier .. " " .. slot, Item = { Kind = "Gear", Slot = slot,
		Id = "Test" .. slot, Quality = quality, Roll = { Stats = stats or { Health = 12, Power = 8 }, Affixes = { {}, {} } } } }
end
local function cacheOf(items, dev) return { Id = "c1", Wins = 50, Dev = dev, Items = items } end
local function run(cache, ready)
	local parent = new("Frame", { Name = "ArenaCacheScreen" }, root)
	local state = { Done = false, Parent = parent }
	task.spawn(function()
		CacheLottery.play(parent, cache, { Ready = ready or function() return true end })
		state.Done = true
	end)
	return state
end
local UR, R = string.upper(GemConfig.TierLabels.UltraRare), string.upper(GemConfig.TierLabels.Rare)

-- 1. Gems first, then gear, each landing on exactly what the server rolled.
local gearOrder = { "Helmet", "Weapon", "Shield", "Armor", "Gloves", "Boots" }
local items = { gearEntry("3", "Helmet", "UltraRare", 3), gemEntry("1", "UltraRare", "g1"), gemEntry("2", "Rare", "g2", true) }
for i = 2, 6 do table.insert(items, gearEntry(tostring(i + 2), gearOrder[i], "Rare", 2, { Defense = 9 })) end
local run1 = run(cacheOf(items))
check(count("PieceChip") == 8, "One chip per piece in the strip")
check(labelWith("ARENA CACHE  ·  50 WINS"), "The cache is named on the lottery")
step(3)
check(landedPiece() and landedPiece().Gem and landedPiece().Gem.Id == "g1", "First roll did not land on the first free gem")
check(labelWith(UR) and labelWith("FREE GEM  ·  1 OF 2  ·  YOURS"), "Gem landing lacks its rarity or heading")
local function commas(n)
	local text = tostring(math.floor(n + 0.5))
	while true do
		local swapped, k = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = swapped
		if k == 0 then return text end
	end
end
check(labelWith("≈ " .. commas(GemConfig.value(items[2].Item.Gem)) .. " coins"), "Gem worth missing")
step(1)
check(labelWith("8/10") and labelWith("7/10") and labelWith("6/10"), "Size, Clarity and Cut bars did not fill")
check(find("RevealOrNext").Text == "NEXT  ›", "Landed piece should offer NEXT")
press("RevealOrNext")
step(0.1)
check(find("RevealOrNext").Text == "REVEAL  ›", "NEXT did not move on to the next roll")
press("RevealOrNext") -- (REVEAL: land it now)
step(0.05)
check(landedPiece().Gem.Id == "g2", "REVEAL landed somewhere other than the awarded gem")
check(labelWith("Flawless: every grade a 10. Free, it's yours."), "Flawless gem not called out")
press("RevealOrNext")
step(0.1)
check(labelWith("GEAR  ·  1 OF 6"), "Gear roll did not follow the gems")
step(2.2)
local piece = landedPiece()
check(piece and piece.Name == "Helmet|A:c1/3", "Gear roll landed on the wrong piece: " .. tostring(piece and piece.Name))
step(1.2)
check(labelWith("+12 Health  ·  +8 Power") and labelWith("◆ Bulwark") and labelWith("2 elemental affixes"), "Gear stats, passive or affixes missing")
check(labelWith("3/4") and labelWith(UR), "Gear quality bar or rarity missing")
check(labelWith("≈ 12,000 coins"), "Gear Market price missing")
check(labelWith("Keep it, or it sells on the Market and you get 25% (≈ 3,000 coins)."), "Commission line missing")
check(drawnGear == 6, "Every piece of the cache's gear should be drawn once for the reel")
for n = 2, 6 do
	press("RevealOrNext") -- (NEXT, then REVEAL)
	step(0.05)
	press("RevealOrNext")
	step(0.05)
	check(landedPiece().Name == gearOrder[n] .. "|A:c1/" .. (n + 2), "Gear " .. n .. " landed on the wrong piece")
	check(labelWith("GEAR  ·  " .. n .. " OF 6"), "Gear counter wrong")
end
check(find("RevealOrNext").Text == "TO YOUR PICKS  ›", "Last piece should lead to the picks")
check(not run1.Done, "Lottery ended before the last piece was seen")
press("RevealOrNext")
step(0.5)
check(run1.Done, "Lottery did not finish after the last piece")
check(liveCount("ViewportFrame") == 0 and count("CacheLottery") == 0 and #run1.Parent:GetChildren() == 0, "Lottery leaked UI or templates")

-- 2. SKIP ALL ends it at once, mid-roll.
local run2 = run(cacheOf({ gemEntry("1", "Rare", "s1"), gearEntry("2", "Boots", "Rare", 2) }))
step(0.5)
press("SkipAll")
step(0.5)
check(run2.Done and liveCount("ViewportFrame") == 0 and #run2.Parent:GetChildren() == 0, "SKIP ALL did not end and clean up")

-- 3. Previews not built: it waits (3 s at most), then rolls silhouettes.
previewsBuilt = false
local run3 = run(cacheOf({ gearEntry("1", "Helmet", "Rare", 2), gearEntry("2", "Weapon", "UltraRare", 4) }, true), function() return false end)
step(2)
check(labelWith("Bringing out the gear...") and not landedPiece(), "Gear rolled before waiting for its previews")
step(1.5)
check(count("GearShape") >= 2, "Missing previews should roll as silhouettes")
press("RevealOrNext")
step(0.05)
check(landedPiece().Name == "GearShape" and labelWith("Keep it, or it's dropped (a test roll)."), "Dev cache landing wrong")
step(20)
check(run3.Done and #run3.Parent:GetChildren() == 0, "Silhouette run did not finish by itself")
previewsBuilt = true

-- 4. The screen closing mid-roll (a fight starting) stops it cleanly.
local run4 = run(cacheOf({ gemEntry("1", "Rare", "x1"), gearEntry("2", "Gloves", "Rare", 2) }))
step(1)
run4.Parent:Destroy()
step(1)
check(run4.Done and liveCount("ViewportFrame") == 0, "Closing the screen left the lottery running")

-- 5. Phone sizes: the card fits.
viewport = { X = 390, Y = 740 }
local run5 = run(cacheOf({ gemEntry("1", "Rare", "p1") }))
local fit = find("CacheLottery"):FindFirstChildOfClass("UIScale")
check(660 * fit.Scale <= 366 and 396 * fit.Scale <= 708, "Phone portrait clips")
run5.Parent.AbsoluteSize = { X = 844, Y = 390 }
run5.Parent:GetPropertyChangedSignal("AbsoluteSize"):Fire()
check(396 * fit.Scale <= 358 and 660 * fit.Scale <= 820, "Phone landscape clips")
press("SkipAll")
step(0.5)
check(run5.Done, "Phone run did not end")
print("PASS: " .. checks .. " cache lottery checks; gems then gear, exact outcomes, stats, reveal/next/skip, previews wait, close, phone fit")
