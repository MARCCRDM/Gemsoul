--[[
	StreakRewards: the Arena Caches you earn for Ranked win streaks
	(Shared.ArenaStreak, Systems/ArenaStreaks).

	While a cache waits, a gold "ARENA CACHE" button pulses at the top of the
	screen. It opens the cache: every piece on a card (gems and gear, Rare
	or Ultra-Rare, in that rarity's colour), tap two to keep, CLAIM. The rest
	go to the Market from the Arena Vault, and the screen says so before you
	claim. A cache unlocking opens the screen straight away.

	The first time a cache opens, it rolls: every card flicks through Rare
	and Ultra-Rare gems and gear, then they land one by one, left to right,
	on what the server rolled (an Ultra-Rare lands with a flash). Tap during
	the roll to land them all at once.

	  StreakRewards.start()   StreakRewards.open()   StreakRewards.refresh()
	  StreakRewards.show(result)   open a cache list the server just sent
	                               (the DEV panel's test caches)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ArenaStreak = require(ReplicatedStorage.Shared.ArenaStreak)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local Art = require(script.Parent.LotteryArt)
local GearArt = require(script.Parent.GearArt)
local UiKit = require(script.Parent.UiKit)
local UiSound = require(script.Parent.UiSound)

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

-- What the reel flicks through while a cache rolls: every Rare and
-- Ultra-Rare gem shade, and every Rare and Ultra-Rare piece of gear.
local REEL = nil
local function reelPool()
	if REEL then
		return REEL
	end
	REEL = { Gems = {}, Gear = {} }
	for _, shades in GemConfig.Shades do
		for _, shade in shades do
			if shade.Tier == "Rare" or shade.Tier == "UltraRare" then
				table.insert(REEL.Gems, shade)
			end
		end
	end
	local ok, Slots = pcall(require, ReplicatedStorage.Shared.EquipmentSlots)
	local okT, Traits = pcall(require, ReplicatedStorage.Shared.ExpandedItemTraits)
	local okA, Armor = pcall(require, ReplicatedStorage.Shared.ArmorFamilies)
	local function scan(kind, list)
		for _, gear in list or {} do
			if type(gear) == "table" and (gear.RarityTier == 3 or gear.RarityTier == 4) then
				table.insert(REEL.Gear, {
					Slot = ok and Slots.ByKind[kind] or kind,
					Name = gear.Name,
					Tier = if gear.RarityTier == 4 then "UltraRare" else "Rare",
				})
			end
		end
	end
	if okT then
		scan("Weapons", Traits.Catalog.Weapons)
	end
	if okA and ok then
		for _, kind in Slots.Kinds do
			if kind ~= "Weapons" then
				scan(kind, Armor.Catalog[kind])
			end
		end
	end
	return REEL
end

-- A cut gem drawn flat (quick enough to recolour every reel tick).
local function flatGem(parent)
	local white = Color3.new(1, 1, 1)
	local gem = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = white,
		Rotation = 45,
	}, parent)
	UiKit.round(gem, 6)
	local shading = new("UIGradient", { Rotation = -45 }, gem)
	local edge = new("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, gem)
	local facet = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.46),
		BackgroundTransparency = 0.25,
	}, gem)
	UiKit.round(facet, 3)
	local glint = new("Frame", {
		Position = UDim2.fromScale(0.14, 0.14),
		Size = UDim2.fromScale(0.2, 0.2),
		BackgroundColor3 = white,
		BackgroundTransparency = 0.2,
	}, gem)
	UiKit.round(glint, 2)
	return function(color: Color3, rim: Color3)
		shading.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(white, 0.55)),
			ColorSequenceKeypoint.new(0.5, color),
			ColorSequenceKeypoint.new(1, color:Lerp(INK, 0.55)),
		})
		facet.BackgroundColor3 = color:Lerp(white, 0.35)
		edge.Color = rim
	end,
		gem
end

-- One piece on a card: its rarity on a ribbon, its picture, name and what
-- it is. Ultra-Rare cards carry a stronger edge and a tinted face.
-- Rolling, the card starts as a reel (spin() flicks it to another random
-- piece) until land() settles it on the real one.
local function card(parent, entry, onToggle, rolling: boolean?)
	local item = entry.Item
	-- The grid lays out a plain cell; the card sits centred in it, so its
	-- landing pop grows from the middle rather than the top-left corner.
	local cell = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 196) }, parent)
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
	local pop = new("UIScale", {}, b)
	local ribbon = label(b, "", 10, INK, Enum.Font.GothamBlack)
	ribbon.BackgroundTransparency = 0
	ribbon.Position, ribbon.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 18)
	UiKit.round(ribbon, 6)
	local art = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 32),
		Size = UDim2.fromOffset(110, 90),
	}, b)
	local name = label(b, "", 13, TEXT, Enum.Font.GothamBlack)
	name.Position, name.Size = UDim2.fromOffset(8, 124), UDim2.new(1, -16, 0, 34)
	local sub = label(b, "", 10, DIM, Enum.Font.GothamBold)
	sub.Position, sub.Size = UDim2.fromOffset(8, 164), UDim2.new(1, -16, 0, 14)
	local tick = label(b, "KEEP", 12, INK, Enum.Font.GothamBlack)
	tick.BackgroundColor3, tick.BackgroundTransparency = GOLD, 0
	tick.AnchorPoint = Vector2.new(0.5, 0)
	tick.Position, tick.Size = UDim2.new(0.5, 0, 0, 100), UDim2.fromOffset(64, 20)
	tick.Visible = false
	UiKit.round(tick, 6)

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

	-- The real piece.
	local function showReal()
		local tier = entry.Rarity or (item.Gem and item.Gem.Tier) or "Rare"
		local tint = paint(tier)
		for _, child in art:GetChildren() do
			child:Destroy()
		end
		if item.Kind == "Gem" then
			pcall(Art.show, art, item.Gem, nil, GemConfig.ElementColors[item.Gem.Element] or tint, false)
		else
			-- The slot's silhouette in its rarity's colour, scaled up (Art.show
			-- would draw whatever you're wearing in that slot, not this piece).
			local holder = new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(38, 36),
			}, art)
			new("UIScale", { Scale = 2.3 }, holder)
			pcall(GearArt.icon, holder, item.Slot, {}, tint)
		end
		name.Text, name.TextColor3 = entry.Name, TEXT
		sub.Text = if item.Kind == "Gem"
			then grades(item.Gem)
			else string.upper(item.Slot or "Gear") .. "  ·  QUALITY " .. tostring(item.Quality or 1)
		sub.TextColor3 = if item.Kind == "Gem" and item.Gem.Flawless then GOLD else DIM
	end

	-- The reel: a flat gem and one silhouette per slot, shown in turn.
	local recolour, gemShape, slotIcons = nil, nil, {}
	local function spin()
		local pool = reelPool()
		local gear = #pool.Gear > 0 and math.random() < 0.5
		local pick = if gear then pool.Gear[math.random(1, #pool.Gear)] else pool.Gems[math.random(1, #pool.Gems)]
		if not pick then
			return
		end
		local tint = paint(pick.Tier)
		gemShape.Visible = not gear
		if not gear then
			recolour(pick.Color, tint)
		end
		for key, icon in slotIcons do
			icon.Visible = gear and key == pick.Slot .. pick.Tier
		end
		name.Text, name.TextColor3 = pick.Name, DIM
		sub.Text, sub.TextColor3 = "· · ·", DIM
	end
	local function land()
		showReal()
		local tint = GemConfig.TierColors[entry.Rarity or "Rare"] or GOLD
		local ultra = entry.Rarity == "UltraRare"
		pop.Scale = if ultra then 1.16 else 1.08
		cell.ZIndex = 3 -- (over its neighbours while it pops)
		task.delay(0.4, function()
			cell.ZIndex = 1
		end)
		TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		local flash = new("Frame", {
			BackgroundColor3 = if ultra then tint else Color3.new(1, 1, 1),
			BackgroundTransparency = if ultra then 0.15 else 0.45,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
		}, b)
		UiKit.round(flash, 12)
		local fade =
			TweenService:Create(flash, TweenInfo.new(if ultra then 0.6 else 0.35), { BackgroundTransparency = 1 })
		fade.Completed:Connect(function()
			flash:Destroy()
		end)
		fade:Play()
		if ultra then
			pcall(IronUi.shine, b, 1.6)
		end
		UiSound.play(if ultra then "Reward" else "Coin")
	end
	if rolling then
		recolour, gemShape = flatGem(art)
		for _, slot in { "Weapon", "Shield", "Helmet", "Armor", "Gloves", "Boots" } do
			for _, tier in ArenaStreak.Rarities do
				local holder = new("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(38, 36),
					Visible = false,
				}, art)
				new("UIScale", { Scale = 2.3 }, holder)
				pcall(GearArt.icon, holder, slot, {}, GemConfig.TierColors[tier] or GOLD)
				slotIcons[slot .. tier] = holder
			end
		end
		spin()
	else
		showReal()
	end

	b.Activated:Connect(function()
		onToggle(entry.OfferId)
	end)
	return {
		Spin = spin,
		Land = land,
		Mark = function(on: boolean)
			edge.Thickness, edge.Transparency = if on then 3 else rest[1], if on then 0 else rest[2]
			edge.Color = if on then GOLD else (GemConfig.TierColors[entry.Rarity or "Rare"] or GOLD)
			b.BackgroundColor3 = if on then face:Lerp(GOLD, 0.14) else face
			tick.Visible = on
		end,
	}
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
	-- Everything on one board sized to its cards (five to a row), scaled to
	-- fit the screen (phones included).
	local rows = math.max(1, math.ceil(#cache.Items / 5))
	local gridHeight = rows * 196 + (rows - 1) * 14
	local claimAt = 100 + gridHeight + 28
	local height = claimAt + 52
	local board = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(880, height),
	}, screen)
	local fit = new("UIScale", {}, board)
	local function scale()
		local s = screen and screen.AbsoluteSize
		if s and s.X > 0 then
			fit.Scale = math.min(1, (s.X - 24) / 880, (s.Y - 16) / height)
		end
	end
	scale()
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(scale)

	local kicker = label(
		board,
		string.format("%s%d RANKED WINS IN A ROW", if cache.Dev then "DEV TEST  ·  " else "", cache.Wins),
		14,
		GOLD,
		Enum.Font.GothamBlack
	)
	kicker.Size = UDim2.new(1, 0, 0, 18)
	local title = label(board, "ARENA CACHE  ·  " .. string.upper(cache.Name or ""), 34, TEXT, Enum.Font.GothamBlack)
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
			then string.format(
				"Keep %d. A test roll: no coins or title, and the other %d are dropped, not sold.",
				picks,
				math.max(0, #cache.Items - picks)
			)
			else string.format(
				"Keep %d. The other %d go to the Market from the %s.%s",
				picks,
				math.max(0, #cache.Items - picks),
				ArenaStreak.VaultName,
				if #extras > 0 then "  (Already yours: " .. table.concat(extras, " and ") .. ".)" else ""
			),
		14,
		DIM,
		Enum.Font.GothamMedium
	)
	sub.Position, sub.Size = UDim2.fromOffset(0, 64), UDim2.new(1, 0, 0, 20)

	local grid = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, gridHeight + 24), -- (room for a card's landing pop)
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, board)
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) }, grid)
	local layout = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 196),
		CellPadding = UDim2.fromOffset(14, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local _ = layout

	local claim
	local function redraw()
		for id, c in cards do
			c.Mark(chosen[id] == true)
		end
		local n = #order
		claim.Text = if rolling
			then "ROLLING..."
			elseif n == picks then "CLAIM THESE " .. picks
			else string.format("PICK %d MORE", picks - n)
		claim.BackgroundColor3 = if n == picks and not rolling then GOLD else Color3.fromRGB(70, 74, 90)
	end
	local skip = false
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
	local reel = {}
	for _, entry in cache.Items do
		cards[entry.OfferId] = card(grid, entry, toggle, rolling)
		table.insert(reel, cards[entry.OfferId])
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
		if busy or rolling or #order ~= picks then
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

	-- The roll: each card flicks fast, slows as its turn comes, then lands.
	if rolling then
		local mine = screen
		task.spawn(function()
			local started = os.clock()
			local nextFlick, landed = {}, {}
			local function landsAt(i)
				return 1.1 + (i - 1) * 0.32
			end
			local left = #reel
			while screen == mine and left > 0 do
				local t = os.clock() - started
				local flicked = false
				for i, c in reel do
					if not landed[i] then
						if skip or t >= landsAt(i) then
							landed[i] = true
							left -= 1
							c.Land()
						elseif t >= (nextFlick[i] or 0) then
							c.Spin()
							flicked = true
							nextFlick[i] = t + 0.06 + math.max(0, 0.6 - (landsAt(i) - t)) * 0.3
						end
					end
				end
				if flicked then
					UiSound.play("Tab")
				end
				task.wait(0.03)
			end
			if screen == mine then
				rolling = false
				redraw()
			end
		end)
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
