--[[
	StreakRewards: the Arena Caches you earn for Ranked win streaks
	(Shared.ArenaStreak, Systems/ArenaStreaks).

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
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaStreak = require(ReplicatedStorage.Shared.ArenaStreak)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local Art = require(script.Parent.LotteryArt)
local CacheLottery = require(script.Parent.CacheLottery)
local GearArt = require(script.Parent.GearArt)
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
	local count = #state.Caches
	launcher.Visible = count > 0 and screen == nil
	launcher.Text = if count > 1 then string.format("🏆  %d ARENA CACHES READY", count) else "🏆  ARENA CACHE READY"
end

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

-- A gem's three grades, short enough for a card.
local function grades(gem): string
	if gem.Flawless then
		return "FLAWLESS  ·  ALL 10s"
	end
	return string.format("Size %d · Clar %d · Prec %d", gem.Size or 0, gem.Clarity or 0, gem.Cut or 0)
end

-- A piece of gear in 3D: the server's preview of it ("Slot|A:<tag>",
-- ArenaStreaks.previews), framed like the Market's. Nil until it's built.
local function gearView(parent, slot: string, tag: string): ViewportFrame?
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(185, 190, 210),
		LightColor = Color3.fromRGB(255, 235, 201),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
	}, parent)
	local ok, drawn = pcall(GearArt.draw, view, slot, "A:" .. tag, false)
	if ok and drawn then
		return view
	end
	view:Destroy()
	return nil
end

-- One piece on a card: its rarity on a ribbon, its picture (3D: the gem
-- from its data, the gear from its server preview), name and what it is;
-- gear adds its stat rolls, passive and affixes. Ultra-Rare cards carry a
-- stronger edge and a tinted face. Gear whose preview isn't built yet shows
-- its silhouette until Upgrade draws it in 3D.
local gearLines = CacheLottery.gearLines

local GEAR_H, GEM_H = 250, 196 -- (card heights)

local function card(parent, entry, onToggle, cacheId: string)
	local item = entry.Item
	local free = entry.Free == true
	-- The row lays out a plain cell; the card sits centred in it.
	local cell = new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.fromOffset(150, if item.Kind == "Gear" then GEAR_H else GEM_H) },
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
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.fromOffset(126, 96),
	}, b)
	local name = label(b, "", 13, TEXT, Enum.Font.GothamBlack)
	name.Position, name.Size = UDim2.fromOffset(8, 126), UDim2.new(1, -16, 0, 34)
	local sub = label(b, "", 10, DIM, Enum.Font.GothamBold)
	sub.Position, sub.Size = UDim2.fromOffset(8, 164), UDim2.new(1, -16, 0, 14)
	local tick = label(b, if free then "YOURS" else "KEEP", 12, INK, Enum.Font.GothamBlack)
	tick.BackgroundColor3, tick.BackgroundTransparency = if free then Color3.fromRGB(110, 220, 140) else GOLD, 0
	tick.AnchorPoint = Vector2.new(0.5, 0)
	tick.Position, tick.Size = UDim2.new(0.5, 0, 0, 104), UDim2.fromOffset(64, 20)
	tick.Visible = false
	UiKit.round(tick, 6)
	-- Gear: its stats, passive and affixes under the name.
	local statLine, passiveLine, affixLine
	if item.Kind == "Gear" then
		statLine = label(b, "", 11, Color3.fromRGB(120, 230, 150), Enum.Font.GothamBold)
		statLine.Position, statLine.Size = UDim2.fromOffset(8, 182), UDim2.new(1, -16, 0, 28)
		passiveLine = label(b, "", 10, GOLD, Enum.Font.GothamBold)
		passiveLine.Position, passiveLine.Size = UDim2.fromOffset(8, 212), UDim2.new(1, -16, 0, 14)
		affixLine = label(b, "", 10, Color3.fromRGB(140, 200, 255), Enum.Font.GothamBold)
		affixLine.Position, affixLine.Size = UDim2.fromOffset(8, 228), UDim2.new(1, -16, 0, 14)
	end

	-- The card's colours for a rarity.
	local face, rest = CARD, { 1.5, 0.55 }
	local function paint(tier: string)
		local tint = GemConfig.TierColors[tier] or GOLD
		local ultra = tier == "UltraRare"
		face = if ultra then CARD:Lerp(tint, 0.1) else CARD
		rest = if ultra then { 2, 0.15 } else { 1.5, 0.55 }
		b.BackgroundColor3 = face
		edge.Color, edge.Thickness, edge.Transparency = tint, rest[1], rest[2]
		local word = string.upper(GemConfig.TierLabels[tier] or tier)
		ribbon.Text = if ultra then "★ " .. word .. " ★" else word
		ribbon.BackgroundColor3 = tint
		return tint
	end

	-- The real piece. Gear without its 3D preview yet shows its silhouette
	-- (flat) until Upgrade can draw it.
	local flat = false
	local realArt = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, art)
	local function drawGear(tint)
		for _, child in realArt:GetChildren() do
			child:Destroy()
		end
		if gearView(realArt, item.Slot, cacheId .. "/" .. entry.OfferId) then
			flat = false
			return
		end
		flat = true
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(38, 36),
		}, realArt)
		new("UIScale", { Scale = 2.3 }, holder)
		pcall(GearArt.icon, holder, item.Slot, {}, tint)
	end
	local function showReal()
		local tier = entry.Rarity or (item.Gem and item.Gem.Tier) or "Rare"
		local tint = paint(tier)
		realArt.Visible = true
		if item.Kind == "Gem" then
			pcall(Art.show, realArt, item.Gem, nil, GemConfig.ElementColors[item.Gem.Element] or tint, false)
		else
			drawGear(tint)
		end
		name.Text, name.TextColor3 = entry.Name, TEXT
		sub.Text = if item.Kind == "Gem"
			then grades(item.Gem)
			else string.upper(item.Slot or "Gear") .. "  ·  QUALITY " .. tostring(item.Quality or 1)
		sub.TextColor3 = if item.Kind == "Gem" and item.Gem.Flawless then GOLD else DIM
		if statLine then
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

	showReal()

	b.Activated:Connect(function()
		if onToggle then
			onToggle(entry.OfferId)
		end
	end)
	return {
		-- The gear previews arrived: draw it in 3D.
		Upgrade = function()
			if flat and item.Kind == "Gear" then
				drawGear(GemConfig.TierColors[entry.Rarity or "Rare"] or GOLD)
			end
		end,
		Mark = function(on: boolean)
			if free then
				return -- (yours already: nothing to pick)
			end
			edge.Thickness, edge.Transparency = if on then 3 else rest[1], if on then 0 else rest[2]
			edge.Color = if on then GOLD else (GemConfig.TierColors[entry.Rarity or "Rare"] or GOLD)
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

function StreakRewards.open()
	local cache = state.Caches[1]
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

	-- The pick screen. Two rows on one board, scaled to fit the screen
	-- (phones included): the free gems (all yours), then the gear to choose
	-- from.
	local function pickScreen()
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

		local kicker = label(
			board,
			string.format("%s%d RANKED WINS IN A ROW", if cache.Dev then "DEV TEST  ·  " else "", cache.Wins),
			14,
			GOLD,
			Enum.Font.GothamBlack
		)
		kicker.Size = UDim2.new(1, 0, 0, 18)
		local title =
			label(board, "ARENA CACHE  ·  " .. string.upper(cache.Name or ""), 34, TEXT, Enum.Font.GothamBlack)
		title.Position, title.Size = UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 40)
		local extras = {}
		if m and m.Coins then
			table.insert(extras, "+" .. commas(m.Coins) .. " coins")
		end
		if m and m.Title then
			table.insert(extras, "a new title")
		end
		local sub = label(
			board,
			if cache.Dev
				then "A test roll: no coins or title, and the gear you don't keep is dropped, not sold."
				elseif #extras > 0 then "Already yours: " .. table.concat(extras, " and ") .. "."
				else "",
			14,
			DIM,
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
		local function redraw()
			for id, c in cards do
				c.Mark(chosen[id] == true)
			end
			local n = #order
			claim.Text = if n == picks then "CLAIM THESE " .. picks else string.format("PICK %d MORE", picks - n)
			claim.BackgroundColor3 = if n == picks then GOLD else Color3.fromRGB(70, 74, 90)
		end
		local function toggle(id)
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
		for _, entry in gemEntries do
			cards[entry.OfferId] = card(gemRow, entry, nil, cache.Id)
			table.insert(drawn, cards[entry.OfferId])
		end
		for _, entry in gearEntries do
			cards[entry.OfferId] = card(gearRow, entry, toggle, cache.Id)
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
	end

	-- The first time a cache opens, its lottery plays first (CacheLottery):
	-- the free gems, then the gear, rolled and landed one by one.
	if rolling then
		task.spawn(function()
			local ok, err = pcall(CacheLottery.play, shown, cache, {
				Ready = function()
					return previewsIn
				end,
			})
			if not ok then
				warn("[StreakRewards] the cache's lottery failed: " .. tostring(err))
			end
			if screen == shown then
				pickScreen()
			end
		end)
	else
		pickScreen()
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
	launcher.Activated:Connect(StreakRewards.open)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Social").OnClientEvent:Connect(function(kind: string, a: any)
		if kind == "StreakReward" then
			-- Fetch the new cache, then show it (after the match result).
			task.delay(2.5, function()
				local result = GemClient.request("StreakCaches")
				if result.Ok then
					state = result
					StreakRewards.open()
				end
			end)
			local _ = a
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
