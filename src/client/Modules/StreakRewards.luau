--[[
	StreakRewards: the Arena Caches you earn for Ranked win streaks
	(Shared.ArenaStreak, Systems/ArenaStreaks), and the boss caches a
	beaten Rift or dungeon boss drops (Shared.BossLoot): the same screen,
	headed with the boss, its threat and its element.

	While a cache waits, a gold "ARENA CACHE" button pulses at the top of the
	screen. It opens the cache, every piece on a card in its rarity's colour
	(Rare or Ultra-Rare), drawn in 3D:
	  - the gems, free: all yours (marked YOURS);
	  - six pieces of gear, with their stat rolls, passive and affixes: tap
	    three to keep, CLAIM. The other three go to the Market from the Arena
	    Vault, and you get 25% of each sale; the screen says so.
	A cache unlocking opens the screen straight away.

	The first time a cache opens, its lottery plays first (CacheLottery,
	the mining find's round reel): each free gem rolls through gems and
	lands, then each piece of gear rolls through the cache's armor and
	weapons and lands, its stats filling in beside it. SKIP ALL goes
	straight to the picks.

	  StreakRewards.start()   StreakRewards.open()   StreakRewards.refresh()
	  StreakRewards.show(result)   open a cache list the server just sent
	                               (the DEV panel's test caches)
	  StreakRewards.isOpen() -> bool   (Combat frees the cursor for it)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaStreak = require(ReplicatedStorage.Shared.ArenaStreak)
local BossLoot = require(ReplicatedStorage.Shared.BossLoot)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local CacheLottery = require(script.Parent.CacheLottery)
local UiKit = require(script.Parent.UiKit)

local StreakRewards = {}

local new = IronUi.new
local GOLD = Color3.fromRGB(255, 200, 80)
local INK = Color3.fromRGB(8, 10, 16)
local CARD = Color3.fromRGB(20, 24, 36)
local TEXT = Color3.fromRGB(238, 242, 247)
local DIM = Color3.fromRGB(150, 160, 180)

-- A piece's rarity: its colour and its name on the card.
local function rarityOf(entry)
	local tier = entry.Rarity or (entry.Item.Gem and entry.Item.Gem.Tier) or "Rare"
	return GemConfig.TierColors[tier] or GOLD, string.upper(GemConfig.TierLabels[tier] or tier)
end

local gui: ScreenGui? = nil
local launcher: TextButton? = nil
local screen: Frame? = nil
local state = { Caches = {}, Streak = 0, Next = nil }
local busy = false
local rolled = {} -- caches whose roll has played (this session)

local function commas(n: number): string
	local text = tostring(math.floor(n + 0.5))
	while true do
		local swapped, count = string.gsub(text, "^(-?%d+)(%d%d%d)", "%1,%2")
		text = swapped
		if count == 0 then
			return text
		end
	end
end

local function label(parent, value, size, color, font)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color or TEXT,
		Font = font or Enum.Font.GothamBold,
		TextWrapped = true,
	}, parent)
	return t
end

local function close()
	if screen then
		screen:Destroy()
		screen = nil
	end
end

local function drawLauncher()
	if not launcher then
		return
	end
	local count, bosses = #state.Caches, 0
	for _, cache in state.Caches do
		if cache.Kind == "Boss" then
			bosses += 1
		end
	end
	launcher.Visible = count > 0 and screen == nil
	launcher.Text = if count == 1 and bosses == 1
		then "🏆  BOSS CACHE READY"
		elseif count == 1 then "🏆  ARENA CACHE READY"
		elseif bosses == count then string.format("🏆  %d BOSS CACHES READY", count)
		elseif bosses == 0 then string.format("🏆  %d ARENA CACHES READY", count)
		else string.format("🏆  %d CACHES READY", count)
end

function StreakRewards.isOpen(): boolean
	return screen ~= nil
end

-- Where a boss cache's boss fell (its kicker).
local BOSS_FROM = { Rift = "RIFT BOSS DEFEATED", Dungeon = "DUNGEON BOSS DEFEATED" }

function StreakRewards.refresh()
	task.spawn(function()
		local result = GemClient.request("StreakCaches")
		if result.Ok then
			state = result
			drawLauncher()
			if #state.Caches > 0 then
				-- (the gear's 3D previews, built before the cache is opened)
				StreakRewards.prewarm()
			end
		end
	end)
end

-- One piece on a card: its rarity on a ribbon, its own round reel (the
-- piece in 3D: the gem from its data, the gear from its server preview), its
-- name and its stats: a gem's Size, Clarity and Cut as bars; a piece of
-- gear's quality as a bar, then its stat rolls, passive and affixes.
-- Ultra-Rare cards carry a stronger edge and a tinted face.
-- Rolling (`lot`), the reel spins with the rest of the grid; the card shows
-- what rolls past and fills in on landing. Gear whose 3D preview isn't
-- built yet shows its silhouette until Upgrade draws it.
local gearLines = CacheLottery.gearLines

local GEAR_H, GEM_H = 272, 226 -- (card heights)
local WINDOW = 104 -- (px: the reel's round window)
local OFF = Color3.fromRGB(38, 46, 62) -- (an unlit bar segment)

local function card(parent, entry, onToggle, cacheId: string, lot)
	local item = entry.Item
	local free = entry.Free == true
	local isGem = item.Kind == "Gem"
	local tier = entry.Rarity or (item.Gem and item.Gem.Tier) or "Rare"
	-- The row lays out a plain cell; the card sits centred in it.
	local cell = new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromOffset(150, if isGem then GEM_H else GEAR_H) },
		parent
	)
	local b = new("TextButton", {
		Name = "Piece",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = CARD,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, cell)
	UiKit.round(b, 12)
	-- (Border mode: on a TextButton the stroke would otherwise trace its text.)
	local edge = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	local ribbon = label(b, "", 10, INK, Enum.Font.GothamBlack)
	ribbon.BackgroundTransparency = 0
	ribbon.Position, ribbon.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 18)
	UiKit.round(ribbon, 6)
	local art = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 32),
		Size = UDim2.fromOffset(WINDOW, WINDOW),
	}, b)
	local window = CacheLottery.window(art)
	local tick = label(b, if free then "YOURS" else "KEEP", 12, INK, Enum.Font.GothamBlack)
	tick.BackgroundColor3, tick.BackgroundTransparency = if free then Color3.fromRGB(110, 220, 140) else GOLD, 0
	tick.AnchorPoint = Vector2.new(0.5, 0)
	tick.Position, tick.Size = UDim2.new(0.5, 0, 0, 124), UDim2.fromOffset(64, 20)
	tick.ZIndex = 4
	tick.Visible = false
	UiKit.round(tick, 6)
	local name = label(b, "", 13, TEXT, Enum.Font.GothamBlack)
	name.Position, name.Size = UDim2.fromOffset(8, 148), UDim2.new(1, -16, 0, 30)

	-- Bars: rows of segments under the name.
	local bars = {}
	local function bar(key, caption, y, count, width, gap)
		local text = label(b, caption, 9, DIM, Enum.Font.GothamBold)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Position, text.Size = UDim2.fromOffset(10, y - 2), UDim2.fromOffset(42, 12)
		local segments = {}
		local x = 150 - 10 - count * width - (count - 1) * gap
		for i = 1, count do
			local segment = new("Frame", {
				BackgroundColor3 = OFF,
				Position = UDim2.fromOffset(x + (i - 1) * (width + gap), y),
				Size = UDim2.fromOffset(width, 8),
			}, b)
			UiKit.round(segment, 2)
			segments[i] = segment
		end
		bars[key] = { Segments = segments, Shown = -1 }
	end
	local function showBar(key, amount: number, color)
		local row = bars[key]
		amount = math.clamp(math.floor(amount), 0, #row.Segments)
		if row.Shown == amount and row.Color == color then
			return
		end
		row.Shown, row.Color = amount, color
		for i, segment in row.Segments do
			segment.BackgroundColor3 = if i <= amount then color else OFF
		end
	end
	local sub, statLine, passiveLine, affixLine
	if isGem then
		bar("Size", "SIZE", 184, 10, 7, 2)
		bar("Clarity", "CLARITY", 198, 10, 7, 2)
		bar("Cut", "CUT", 212, 10, 7, 2)
	else
		sub = label(b, "", 10, DIM, Enum.Font.GothamBold)
		sub.Position, sub.Size = UDim2.fromOffset(8, 178), UDim2.new(1, -16, 0, 12)
		bar("Quality", "QUALITY", 196, 4, 19, 3)
		statLine = label(b, "", 11, Color3.fromRGB(120, 230, 150), Enum.Font.GothamBold)
		statLine.Position, statLine.Size = UDim2.fromOffset(8, 210), UDim2.new(1, -16, 0, 26)
		passiveLine = label(b, "", 10, GOLD, Enum.Font.GothamBold)
		passiveLine.Position, passiveLine.Size = UDim2.fromOffset(8, 238), UDim2.new(1, -16, 0, 13)
		affixLine = label(b, "", 10, Color3.fromRGB(140, 200, 255), Enum.Font.GothamBold)
		affixLine.Position, affixLine.Size = UDim2.fromOffset(8, 253), UDim2.new(1, -16, 0, 13)
	end

	-- The card's colours for a rarity.
	local face, rest = CARD, { 1.5, 0.55 }
	local function paint(shown: string, dim: boolean?)
		local tint = GemConfig.TierColors[shown] or GOLD
		local ultra = shown == "UltraRare"
		face = if ultra and not dim then CARD:Lerp(tint, 0.1) else CARD
		rest = if ultra then { 2, 0.15 } else { 1.5, 0.55 }
		b.BackgroundColor3 = face
		edge.Color, edge.Thickness, edge.Transparency = tint, rest[1], rest[2]
		local word = string.upper(GemConfig.TierLabels[shown] or shown)
		ribbon.Text = if ultra then "★ " .. word .. " ★" else word
		ribbon.BackgroundColor3 = if dim then tint:Lerp(CARD, 0.35) else tint
		window.paint(shown)
		return tint
	end

	-- What it is, all filled in; `fill` animates the bars in.
	local alive = true
	local function showReal(fill: boolean?)
		local tint = paint(tier)
		window.paint(tier, true)
		name.Text, name.TextColor3 = entry.Name, TEXT
		local color = if isGem and item.Gem.Flawless then GOLD else tint
		local goals = if isGem
			then { Size = item.Gem.Size or 0, Clarity = item.Gem.Clarity or 0, Cut = item.Gem.Cut or 0 }
			else { Quality = item.Quality or 1 }
		for key in bars do
			showBar(key, if fill then 0 else goals[key], color)
		end
		if fill then
			-- (row after row, a segment at a time)
			task.spawn(function()
				for step = 1, 14 do
					task.wait(0.035)
					if not alive then
						return
					end
					for row, key in { "Size", "Clarity", "Cut", "Quality" } do
						if bars[key] then
							showBar(key, math.min(goals[key], step - (row - 1) * 2), color)
						end
					end
				end
				for key in bars do
					showBar(key, goals[key], color)
				end
			end)
		end
		if not isGem then
			sub.Text = string.upper((Slots.Definitions[item.Slot] or {}).Label or item.Slot or "Gear")
			local stats, passive, affixes = gearLines(item)
			statLine.Text = if stats ~= "" then stats else "Base stats"
			passiveLine.Text = if passive then "◆ " .. passive else ""
			affixLine.Text = if affixes > 0
				then string.format("%d elemental affix%s", affixes, if affixes == 1 then "" else "es")
				else ""
		end
		if free then
			tick.Visible = true -- (yours, whatever you pick)
		end
	end

	-- Gear drawn flat (its 3D preview wasn't built yet) is redrawn by Upgrade.
	local flat = false
	if lot then
		-- Rolling: blank until its reel starts, then what rolls past.
		paint(tier, true)
		ribbon.Text, name.Text, name.TextColor3 = "· · ·", "", DIM
		lot.add(window, entry, {
			Center = function(option)
				paint(option.Tier, true)
				name.Text = option.Name or ""
				local dim = (GemConfig.TierColors[option.Tier] or DIM):Lerp(CARD, 0.4)
				if isGem then
					local grades = option.Grades or {}
					for key in bars do
						showBar(key, grades[key] or 0, dim)
					end
				else
					sub.Text = string.upper(option.Label or "")
					showBar("Quality", option.Quality or 1, dim)
					statLine.Text, passiveLine.Text, affixLine.Text = "· · ·", "", ""
				end
			end,
			Land = function(own)
				flat = own.Flat == true
				showReal(true)
			end,
		})
	else
		if isGem then
			window.still(CacheLottery.gemView(item.Gem))
		else
			local view
			view, flat = CacheLottery.gearView(entry, cacheId .. "/" .. entry.OfferId)
			window.still(view)
		end
		showReal(false)
	end
	cell.Destroying:Connect(function()
		alive = false
	end)

	b.Activated:Connect(function()
		if onToggle then
			onToggle(entry.OfferId)
		end
	end)
	return {
		-- The gear previews arrived: a piece drawn flat is redrawn in 3D.
		Upgrade = function()
			if flat and not isGem then
				local view, stillFlat = CacheLottery.gearView(entry, cacheId .. "/" .. entry.OfferId)
				if stillFlat then
					view:Destroy()
				else
					flat = false
					window.still(view)
				end
			end
		end,
		Mark = function(on: boolean)
			if free then
				return -- (yours already: nothing to pick)
			end
			edge.Thickness, edge.Transparency = if on then 3 else rest[1], if on then 0 else rest[2]
			edge.Color = if on then GOLD else (GemConfig.TierColors[tier] or GOLD)
			b.BackgroundColor3 = if on then face:Lerp(GOLD, 0.14) else face
			tick.Visible = on
		end,
	}
end

-- Ask the server for 3D previews of every cache's gear, retrying while it's
-- busy building something else; then onReady().
-- (Every caller is told when they're ready: a request already running when
-- the cache opened, say the one started as the cache list loaded, used to
-- swallow the screen's callback, so its gear never turned 3D.)
local fetching, waiting = false, {}
local function fetchPreviews(onReady: (() -> ())?)
	if onReady then
		table.insert(waiting, onReady)
	end
	if fetching then
		return
	end
	fetching = true
	task.spawn(function()
		local done = false
		for _ = 1, 20 do
			local result = GemClient.request("StreakPreviews")
			if result.Ok and result.Done then
				done = true
				break
			end
			task.wait(1)
		end
		if not done then
			warn("[StreakRewards] the Arena Cache's 3D gear previews weren't built in time; showing silhouettes")
		end
		fetching = false
		local callbacks = waiting
		waiting = {}
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end)
end

function StreakRewards.prewarm()
	fetchPreviews(nil)
end

-- The first cache in line, or the one `id` names.
function StreakRewards.open(id: string?)
	local cache = state.Caches[1]
	for _, c in state.Caches do
		if c.Id == id then
			cache = c
		end
	end
	if not gui or not cache then
		return
	end
	close()
	local m = ArenaStreak.get(cache.Wins)
	local picks = cache.Picks or ArenaStreak.Picks
	local chosen, cards, order = {}, {}, {}
	local rolling = not rolled[cache.Id]
	rolled[cache.Id] = true
	screen = new("Frame", {
		Name = "ArenaCache",
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.12,
		Size = UDim2.fromScale(1, 1),
		Active = true,
	}, gui)
	local shown = screen :: Frame
	-- The gear's 3D previews (usually built already, see refresh), for the
	-- lottery's reel and then the cards.
	local previewsIn, drawn = false, {}
	fetchPreviews(function()
		previewsIn = true
		if screen == shown then
			for _, c in drawn do
				c.Upgrade()
			end
		end
	end)

	-- Two rows on one board, scaled to fit the screen (phones included): the
	-- free gems (all yours), then the gear to choose from. The first time a
	-- cache opens, every card's reel rolls at once and lands in turn, the
	-- gems first (CacheLottery); a tap lands them all.
	do
		local gemEntries, gearEntries = {}, {}
		for _, entry in cache.Items do
			table.insert(if entry.Free then gemEntries else gearEntries, entry)
		end
		picks = math.min(picks, #gearEntries)
		local width = math.max(880, #gearEntries * 150 + (#gearEntries - 1) * 12 + 20)
		local gemTop = 112
		local gearLabelAt = if #gemEntries > 0 then gemTop + GEM_H + 16 else 92
		local gearTop = gearLabelAt + 22
		local claimAt = gearTop + GEAR_H + 20
		local height = claimAt + 52
		local board = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, height),
		}, shown)
		local fit = new("UIScale", {}, board)
		local function scale()
			local s = shown.AbsoluteSize
			if s.X > 0 then
				fit.Scale = math.min(1, (s.X - 24) / width, (s.Y - 16) / height)
			end
		end
		scale()
		shown:GetPropertyChangedSignal("AbsoluteSize"):Connect(scale)

		local boss = cache.Kind == "Boss"
		local kicker = label(
			board,
			(if cache.Dev then "DEV TEST  ·  " else "")
				.. if boss
					then string.format(
						"%s  ·  THREAT %s",
						BOSS_FROM[cache.Source] or "BOSS DEFEATED",
						BossLoot.numeral(cache.Threat or 2)
					)
					else string.format("%d RANKED WINS IN A ROW", cache.Wins),
			14,
			GOLD,
			Enum.Font.GothamBlack
		)
		kicker.Size = UDim2.new(1, 0, 0, 18)
		local title = label(
			board,
			(if boss then "BOSS CACHE  ·  " else "ARENA CACHE  ·  ") .. string.upper(cache.Boss or cache.Name or ""),
			34,
			TEXT,
			Enum.Font.GothamBlack
		)
		title.Position, title.Size = UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 40)
		local extras = {}
		if m and m.Coins and not boss then
			table.insert(extras, "+" .. commas(m.Coins) .. " coins")
		end
		if m and m.Title and not boss then
			table.insert(extras, "a new title")
		end
		local focus = cache.Focus and Slots.Definitions[Slots.ByKind[cache.Focus]]
		local sub = label(
			board,
			if boss
				then "All its gems are "
					.. GemConfig.elementName(cache.Element or "")
					.. (if focus then "  ·  Its favourite gear: " .. focus.Label else "")
				elseif cache.Dev then "A test roll: no coins or title, and the gear you don't keep is dropped, not sold."
				elseif #extras > 0 then "Already yours: " .. table.concat(extras, " and ") .. "."
				else "",
			14,
			if boss then GemConfig.ElementColors[cache.Element] or DIM else DIM,
			Enum.Font.GothamMedium
		)
		sub.Position, sub.Size = UDim2.fromOffset(0, 64), UDim2.new(1, 0, 0, 20)

		-- A row of cards, centred.
		local function row(top: number, cardHeight: number)
			local frame = new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, top),
				Size = UDim2.new(1, 0, 0, cardHeight),
			}, board)
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, frame)
			return frame
		end
		local function heading(text: string, top: number, color)
			local h = label(board, text, 12, color, Enum.Font.GothamBlack)
			h.Position, h.Size = UDim2.fromOffset(0, top), UDim2.new(1, 0, 0, 16)
		end
		local gemRow, gearRow = nil, nil
		if #gemEntries > 0 then
			heading(
				if #gemEntries == 1 then "FREE  ·  THIS GEM IS YOURS" else "FREE  ·  THESE GEMS ARE ALL YOURS",
				92,
				Color3.fromRGB(110, 220, 140)
			)
			gemRow = row(gemTop, GEM_H)
		end
		heading(
			if cache.Dev
				then string.format("PICK %d OF %d", picks, #gearEntries)
				else string.format(
					"PICK %d OF %d  ·  THE OTHER %d GO TO THE MARKET: YOU GET %d%% OF EACH SALE",
					picks,
					#gearEntries,
					#gearEntries - picks,
					math.floor(ArenaStreak.Commission * 100 + 0.5)
				),
			gearLabelAt,
			GOLD
		)
		gearRow = row(gearTop, GEAR_H)

		local claim
		local skip = false
		local function redraw()
			for id, c in cards do
				c.Mark(chosen[id] == true)
			end
			local n = #order
			claim.Text = if rolling
				then "ROLLING  ·  TAP TO REVEAL"
				elseif n == picks then "CLAIM THESE " .. picks
				else string.format("PICK %d MORE", picks - n)
			claim.BackgroundColor3 = if n == picks and not rolling then GOLD else Color3.fromRGB(70, 74, 90)
		end
		local function toggle(id)
			if rolling then
				skip = true -- (a tap lands the whole roll)
				return
			end
			if chosen[id] then
				chosen[id] = nil
				table.remove(order, table.find(order, id))
			else
				if #order >= picks then
					-- (the oldest pick gives way)
					chosen[table.remove(order, 1)] = nil
				end
				chosen[id] = true
				table.insert(order, id)
			end
			redraw()
		end
		local lot = if rolling
			then CacheLottery.new(cache, {
				Ready = function()
					return previewsIn
				end,
			})
			else nil
		for _, entry in gemEntries do
			cards[entry.OfferId] = card(gemRow, entry, function()
				-- (free: nothing to pick; a tap only lands the roll)
				if rolling then
					skip = true
				end
			end, cache.Id, lot)
			table.insert(drawn, cards[entry.OfferId])
		end
		for _, entry in gearEntries do
			cards[entry.OfferId] = card(gearRow, entry, toggle, cache.Id, lot)
			table.insert(drawn, cards[entry.OfferId])
		end
		if previewsIn then
			for _, c in drawn do
				c.Upgrade()
			end
		end

		claim = new("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, claimAt),
			Size = UDim2.fromOffset(300, 52),
			Font = Enum.Font.GothamBlack,
			TextSize = 18,
			TextColor3 = INK,
			Text = "",
		}, board)
		UiKit.round(claim, 10)
		claim:SetAttribute("UiSound", "Confirm")
		claim.Activated:Connect(function()
			if rolling then
				skip = true
				return
			end
			if busy or #order ~= picks then
				return
			end
			busy = true
			local result = GemClient.request("StreakClaim", cache.Id, order)
			busy = false
			UiKit.toast(result.Message or "", if result.Ok then GOLD else nil)
			if result.Ok then
				state = result
				close()
				drawLauncher()
			end
		end)
		local later = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(110, 30),
			BackgroundColor3 = CARD,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = DIM,
			Text = "LATER",
		}, board)
		UiKit.round(later, 8)
		later.Activated:Connect(function()
			close()
			drawLauncher()
		end)
		redraw()
		drawLauncher()

		if lot then
			task.spawn(function()
				local ok, err = pcall(lot.run, function()
					return screen == shown
				end, function()
					return skip
				end)
				if not ok then
					warn("[StreakRewards] the cache's roll failed: " .. tostring(err))
				end
				lot.destroy()
				if screen == shown then
					rolling = false
					redraw()
					if previewsIn then
						for _, c in drawn do
							c.Upgrade()
						end
					end
				end
			end)
		end
	end
end

-- Open a cache list the server just sent (the DEV panel's test caches),
-- rolling the newest one.
function StreakRewards.show(result)
	if result and result.Caches then
		state = result
		drawLauncher()
		StreakRewards.open()
	end
end

function StreakRewards.start()
	if gui then
		return
	end
	gui = UiKit.gui("StreakRewards", 40)
	launcher = new("TextButton", {
		Name = "CacheReady",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(260, 40),
		BackgroundColor3 = GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = INK,
		Text = "",
		Visible = false,
	}, gui)
	UiKit.round(launcher, 10)
	pcall(IronUi.shine, launcher, 2.5)
	launcher.Activated:Connect(function()
		StreakRewards.open()
	end)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Social").OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "StreakReward" or kind == "BossCache" then
			-- Fetch the new cache, then show it (after the match result, or
			-- the boss's fall).
			task.delay(if kind == "BossCache" then 3 else 2.5, function()
				local result = GemClient.request("StreakCaches")
				if result.Ok then
					state = result
					StreakRewards.open(if type(a) == "table" then a.Id else nil)
				end
			end)
		elseif kind == "MatchEnd" then
			StreakRewards.refresh()
		end
	end)
	StreakRewards.refresh()
	Players.LocalPlayer:GetAttributeChangedSignal("CombatSession"):Connect(function()
		-- No cache screen mid-fight.
		if Players.LocalPlayer:GetAttribute("CombatSession") ~= nil then
			close()
		end
		drawLauncher()
	end)
end

return StreakRewards
