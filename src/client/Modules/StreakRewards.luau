--[[
	StreakRewards: the Arena Caches you earn for Ranked win streaks
	(Shared.ArenaStreak, Systems/ArenaStreaks).

	While a cache waits, a gold "ARENA CACHE" button pulses at the top of the
	screen. It opens the cache: every piece on a card (gems and gear, Rare
	or Ultra-Rare, in that rarity's colour), tap two to keep, CLAIM. The rest go to the Market from the Arena
	Vault, and the screen says so before you claim. A cache unlocking opens
	the screen straight away.

	  StreakRewards.start()   StreakRewards.open()   StreakRewards.refresh()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaStreak = require(ReplicatedStorage.Shared.ArenaStreak)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local Art = require(script.Parent.LotteryArt)
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

-- One piece on a card: its rarity on a ribbon, its picture, name and what
-- it is. Ultra-Rare cards carry a stronger edge and a tinted face.
local function card(parent, entry, onToggle)
	local item = entry.Item
	local tint, rarity = rarityOf(entry)
	local ultra = rarity ~= "RARE"
	local face = if ultra then CARD:Lerp(tint, 0.1) else CARD
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = face,
		Size = UDim2.fromOffset(150, 196),
	}, parent)
	UiKit.round(b, 12)
	-- (Border mode: on a TextButton the stroke would otherwise trace its text.)
	local rest = if ultra then { 2, 0.15 } else { 1.5, 0.55 }
	local edge = new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = tint,
		Thickness = rest[1],
		Transparency = rest[2],
	}, b)
	local ribbon = label(b, if ultra then "★ " .. rarity .. " ★" else rarity, 10, INK, Enum.Font.GothamBlack)
	ribbon.BackgroundColor3, ribbon.BackgroundTransparency = tint, 0
	ribbon.Position, ribbon.Size = UDim2.fromOffset(8, 8), UDim2.new(1, -16, 0, 18)
	UiKit.round(ribbon, 6)
	local art = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 32),
		Size = UDim2.fromOffset(110, 90),
	}, b)
	if item.Kind == "Gem" then
		pcall(Art.show, art, item.Gem, nil, GemConfig.ElementColors[item.Gem.Element] or tint, false)
	else
		-- The slot's silhouette in its rarity's colour, scaled up (Art.show would
		-- draw whatever you're wearing in that slot, not this piece).
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(38, 36),
		}, art)
		new("UIScale", { Scale = 2.3 }, holder)
		pcall(GearArt.icon, holder, item.Slot, {}, tint)
	end
	local name = label(b, entry.Name, 13, TEXT, Enum.Font.GothamBlack)
	name.Position, name.Size = UDim2.fromOffset(8, 124), UDim2.new(1, -16, 0, 34)
	local kind = if item.Kind == "Gem"
		then grades(item.Gem)
		else string.upper(item.Slot or "Gear") .. "  ·  QUALITY " .. tostring(item.Quality or 1)
	local sub = label(b, kind, 10, if item.Kind == "Gem" and item.Gem.Flawless then GOLD else DIM, Enum.Font.GothamBold)
	sub.Position, sub.Size = UDim2.fromOffset(8, 164), UDim2.new(1, -16, 0, 14)
	local tick = label(b, "KEEP", 12, INK, Enum.Font.GothamBlack)
	tick.BackgroundColor3, tick.BackgroundTransparency = GOLD, 0
	tick.AnchorPoint = Vector2.new(0.5, 0)
	tick.Position, tick.Size = UDim2.new(0.5, 0, 0, 100), UDim2.fromOffset(64, 20)
	tick.Visible = false
	UiKit.round(tick, 6)
	b.Activated:Connect(function()
		onToggle(entry.OfferId)
	end)
	return function(on: boolean)
		edge.Thickness, edge.Transparency = if on then 3 else rest[1], if on then 0 else rest[2]
		edge.Color = if on then GOLD else tint
		b.BackgroundColor3 = if on then face:Lerp(GOLD, 0.14) else face
		tick.Visible = on
	end
end

function StreakRewards.open()
	local cache = state.Caches[1]
	if not gui or not cache then
		return
	end
	close()
	local m = ArenaStreak.get(cache.Wins)
	local picks = cache.Picks or ArenaStreak.Picks
	local chosen, marks, order = {}, {}, {}
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

	local kicker = label(board, string.format("%d RANKED WINS IN A ROW", cache.Wins), 14, GOLD, Enum.Font.GothamBlack)
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
		string.format(
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
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, gridHeight),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
	}, board)
	local layout = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 196),
		CellPadding = UDim2.fromOffset(14, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local _ = layout

	local claim
	local function redraw()
		for id, mark in marks do
			mark(chosen[id] == true)
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
	for _, entry in cache.Items do
		marks[entry.OfferId] = card(grid, entry, toggle)
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
