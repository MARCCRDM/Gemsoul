
local checks = 0
local function check(ok, message) checks += 1; assert(ok, message) end
local function gemEntry(offer, tier, id)
	local gem = { Id = id, Element = "Frost", Tier = tier, Size = 8, Clarity = 7, Cut = 6 }
	return { OfferId = offer, Free = true, Rarity = tier, Name = "Gem " .. id, Item = { Kind = "Gem", Gem = gem } }
end
local function gearEntry(offer, slot, tier)
	return { OfferId = offer, Rarity = tier, Name = tier .. " " .. slot,
		Item = { Kind = "Gear", Slot = slot, Id = "Test" .. slot, Quality = 3, Roll = { Stats = { Health = 12, Power = 8 }, Affixes = { {}, {} } } } }
end
local reveals = 0
LotterySound.reveal = function(rank) reveals += 1; table.insert(sounds, rank) end
-- The piece in the middle of a window (its cell at the stop).
local function middle(win)
	for _, o in objects do
		if not o.Destroyed and o.Name == "ReelCell" and o.Parent == win.Holder:FindFirstChildOfClass("CanvasGroup") then
			local y = o.Position.Y.Offset
			if math.abs(y + o.Size.Y.Offset / 2) < 0.01 then
				return o:GetChildren()[1]:GetChildren()[1]
			end
		end
	end
end
-- No picture may sit in two cells at once.
local function cellsDistinct(win)
	local well = win.Holder:FindFirstChildOfClass("CanvasGroup")
	local seen = {}
	for _, cell in well:GetChildren() do
		if cell.Name == "ReelCell" then
			for _, view in cell:GetChildren()[1]:GetChildren() do
				if seen[view] then return false end
				seen[view] = true
			end
		end
	end
	return true
end
local function build(items, ready)
	local cache = { Id = "c1", Wins = 50, Items = items }
	local lot = CacheLottery.new(cache, { Ready = ready })
	local rows = {}
	for i, entry in items do
		local frame = new("Frame", { Name = "Art" .. i, Size = UDim2.fromOffset(104, 104) }, root)
		local win = CacheLottery.window(frame)
		local row = { Entry = entry, Win = win, Frame = frame, Centers = 0 }
		lot.add(win, entry, {
			Center = function(option) row.Centers += 1; row.Last = option end,
			Land = function(own) row.Own = own; row.LandedAt = now end,
		})
		rows[i] = row
	end
	return lot, rows
end
local function start(lot, flags)
	local state = { Done = false }
	task.spawn(function()
		lot.run(function() return not flags.Dead end, function() return flags.Skip == true end)
		state.Done = true
	end)
	return state
end

-- 1. Every reel spins at once and they land in turn: gems first, then gear,
--    each on exactly its own piece, never showing a picture twice.
local items = { gemEntry("1", "UltraRare", "g1"), gemEntry("2", "Rare", "g2") }
for i, slot in { "Helmet", "Weapon", "Shield", "Armor", "Gloves", "Boots" } do
	table.insert(items, gearEntry(tostring(i + 2), slot, if i == 1 then "UltraRare" else "Rare"))
end
local lot, rows = build(items, function() return true end)
local flags = {}
local run = start(lot, flags)
step(0.5)
for i, row in rows do
	check(row.Centers > 0, "Reel " .. i .. " is not spinning with the rest")
	check(not row.Own, "Reel " .. i .. " landed too early")
	check(cellsDistinct(row.Win), "A picture sits in two cells of reel " .. i)
end
local distinctAll = true
for _ = 1, 300 do
	step(1 / 60)
	for _, row in rows do
		if not cellsDistinct(row.Win) then distinctAll = false end
	end
end
check(distinctAll, "A reel showed the same picture in two cells while spinning")
step(1)
check(run.Done, "The roll did not finish")
local order = table.clone(rows)
table.sort(order, function(a, b) return a.LandedAt < b.LandedAt end)
for i, row in order do
	check(row == rows[i], "Landing order should be gems first, then gear in order")
end
check(rows[1].LandedAt >= 1.4 and rows[1].LandedAt <= 1.6, "First reel should land at about 1.5 s")
check(rows[8].LandedAt - rows[7].LandedAt >= 0.35, "Landings should be staggered")
check(middle(rows[1].Win).Gem == items[1].Item.Gem and middle(rows[2].Win).Gem == items[2].Item.Gem, "Gem reel landed on a preview instead of the awarded gem")
for i = 3, 8 do
	local view = middle(rows[i].Win)
	check(view and view.Name == items[i].Item.Slot .. "|A:c1/" .. items[i].OfferId, "Gear reel " .. i .. " landed on the wrong piece")
	check(rows[i].Own.Tier == items[i].Rarity, "Gear rarity lost")
end
check(reveals == 8, "One reveal sound per landing")
lot.destroy()
check(liveCount("ViewportFrame") == 8, "Only each reel's own piece should stay after the roll (got " .. liveCount("ViewportFrame") .. ")")
for _, row in rows do row.Frame:Destroy() end
check(liveCount("ViewportFrame") == 0, "Cards leaked pictures")

-- 2. A tap lands everything at once, with one sound.
reveals = 0
local lot2, rows2 = build({ gemEntry("1", "Rare", "s1"), gearEntry("2", "Boots", "Rare"), gearEntry("3", "Helmet", "Rare") }, function() return true end)
local flags2 = {}
local run2 = start(lot2, flags2)
step(0.3)
flags2.Skip = true
step(2 / 60)
check(run2.Done and reveals == 1, "Skip should land every reel at once with one sound")
check(middle(rows2[1].Win).Gem.Id == "s1" and middle(rows2[2].Win).Name == "Boots|A:c1/2", "Skip landed on the wrong pieces")
lot2.destroy()
for _, row in rows2 do row.Frame:Destroy() end

-- 3. Gear waits for its 3D previews (3 s at most), then rolls silhouettes.
previewsBuilt = false
local lot3, rows3 = build({ gemEntry("1", "Rare", "w1"), gearEntry("2", "Helmet", "Rare"), gearEntry("3", "Weapon", "UltraRare") }, function() return false end)
local run3 = start(lot3, {})
step(2.8)
check(rows3[1].Own and rows3[2].Centers == 0 and rows3[3].Centers == 0, "Gear rolled before its previews (or the gem waited for them)")
step(0.4)
check(rows3[2].Centers > 0, "Gear never started after 3 s")
step(4)
check(run3.Done and rows3[2].Own.Flat == true and middle(rows3[2].Win).Name == "GearShape", "Gear without previews should land as a silhouette marked flat")
lot3.destroy()
for _, row in rows3 do row.Frame:Destroy() end
previewsBuilt = true

-- 4. The screen closing mid-roll stops it; nothing is left behind.
local lot4, rows4 = build({ gemEntry("1", "Rare", "x1"), gearEntry("2", "Gloves", "Rare") }, function() return true end)
local flags4 = {}
local run4 = start(lot4, flags4)
step(0.6)
flags4.Dead = true
for _, row in rows4 do row.Frame:Destroy() end
step(0.1)
check(run4.Done, "Closing the screen left the roll running")
lot4.destroy()
check(liveCount("ViewportFrame") == 0, "A closed roll leaked pictures")

-- 5. A cache opened again: one still piece in the middle.
local frame = new("Frame", { Size = UDim2.fromOffset(104, 104) }, root)
local win = CacheLottery.window(frame)
local view = CacheLottery.gemView({ Id = "still", Element = "Frost", Tier = "Rare", Size = 5, Clarity = 5, Cut = 5 })
win.still(view)
check(middle(win) == view, "Still piece not centred")
local swap = CacheLottery.gemView({ Id = "swap", Element = "Frost", Tier = "Rare", Size = 5, Clarity = 5, Cut = 5 })
win.still(swap)
check(middle(win) == swap and view.Destroyed, "Swapping the still piece should replace the old one")
frame:Destroy()
print("PASS: " .. checks .. " cache lottery checks; all reels at once, staggered landings (gems first), exact outcomes, no doubled pictures, skip, previews wait, close, still pieces")
