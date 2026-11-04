--[[
	The Kennel's sales, in the windows' look (Client GiltUi): opened from the
	Daily Kaiju Sale's plinth (Client KennelLife) or from Wren, the kennel
	keeper (Dialogue). Three offers, each for Robux (Shared.Store), as the
	Store has them:

	  Starter Rare Roll   one roll on the rarest kinds, once ever: played on
	                      the roll screen (Client KaijuRoll) as soon as you
	                      have room; four of them together in its picture
	                      (Kaiju.Sale.Showcase)
	  Triskull Trinity    the premium trio, once ever: three Triskulls, one
	                      in each element, side by side

	Each picture is a lit stage (Client Showcase): the element's colour
	behind them, a glow, a disc to stand on and a rim of light.
	  Daily Kaiju Sale    today's Kaiju of the Day (Shared.KaijuKennel
	                      .special), one each a day, turning in its view,
	                      its kind, element, role and the time left

	Bought with Roblox's purchase prompt (the grant comes with the receipt:
	Server StoreServer, KaijuServer.saleGrant), or with coins while testing
	(the store's BuyProduct). What's yours already says so, not a button.

	  KennelSale.open()   shows it (again: redrawn)
	  KennelSale.close()
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kaiju = require(Shared:WaitForChild("Kaiju"))
local Kennel = require(Shared:WaitForChild("KaijuKennel"))
local KaijuModels = require(Shared:WaitForChild("KaijuModels"))
local GemConfig = require(Shared:WaitForChild("GemConfig"))
local Store = require(Shared:WaitForChild("Store"))
local GemClient = require(script.Parent.GemClient)
local Gilt = require(script.Parent.GiltUi)
local IronUi = require(script.Parent.IronUi)
local Showcase = require(script.Parent.Showcase)
local UiKit = require(script.Parent.UiKit)

local new = IronUi.new
local player = Players.LocalPlayer

local KennelSale = {}
KennelSale.Width = 640

local gui: ScreenGui? = nil

local function screen(): ScreenGui
	if not gui then
		gui = UiKit.gui("KennelSale", 45)
	end
	return gui :: ScreenGui
end

function KennelSale.close()
	if gui then
		gui:ClearAllChildren()
	end
end

-- Plain words in the window: warm ivory or faded, wrapped.
local function prose(parent: Instance, value: string, size: number, color: Color3, order: number): TextLabel
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = IronUi.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, size + 4),
		LayoutOrder = order,
	}, parent)
	return l
end

-- Hours and minutes to the next midnight (UTC: KaijuKennel.day).
local function untilMidnight(now: number): string
	local left = math.max(0, (Kennel.day(now) + 1) * Kennel.DaySeconds - now)
	local h, m = math.floor(left / 3600), math.floor(left % 3600 / 60)
	return if h > 0 then string.format("%dh %02dm", h, m) else string.format("%dm", math.max(1, m))
end

-- A kaiju on a lit stage filling `parent`, in its element's colour, turning.
local function portrait(parent: Instance, species: string, element: string)
	local tint = GemConfig.ElementColors[element] or Gilt.Gold
	local stage = Showcase.stage(parent, tint)
	Showcase.model(stage, KaijuModels.forPortrait(KaijuModels.build(species, element)), { Tint = tint, Spin = true, Turn = 0.6, Aspect = 1.6 })
end

-- Kaiju together on one lit stage filling `parent`, under a `tint`.
local function gallery(parent: Instance, kaiju: { { Species: string, Element: string } }, tint: Color3)
	local stage = Showcase.stage(parent, tint)
	local models = {}
	for _, shown in kaiju do
		table.insert(models, KaijuModels.forPortrait(KaijuModels.build(shown.Species, shown.Element)))
	end
	Showcase.group(stage, models, { Tint = tint, Turn = 0.35, Fill = 0.92, Aspect = 1.6 })
end

-- Buys `key`: Roblox's prompt, or coins while testing, or not yet on sale.
local function buy(key: string)
	local id = Store.RobuxProducts[key] or 0
	if id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, id)
		return
	end
	if not Store.testPrice(key) then
		UiKit.toast("Coming soon: the Kennel's sales open shortly.", Gilt.Faded)
		return
	end
	task.spawn(function()
		local result = GemClient.request("BuyProduct", key)
		if result and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, if result.Ok then Gilt.Green else Gilt.Red)
		end
		if result and result.Ok then
			KennelSale.close()
		end
	end)
end

-- (a loop that lasts while `alive` is on screen)
local function forever(alive: Instance, info: TweenInfo, object: Instance, goal: { [string]: any })
	local tween = TweenService:Create(object, info, goal)
	tween:Play()
	alive.AncestryChanged:Connect(function()
		if not alive:IsDescendantOf(game) then
			tween:Cancel()
		end
	end)
end

-- A shine running across `parent` now and then (a white streak, clipped).
local function shine(parent: GuiObject, every: number)
	parent.ClipsDescendants = true
	local streak = new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(-0.3, 0, 0.5, 0),
		Size = UDim2.new(0, 26, 2, 0),
		Rotation = 20,
		ZIndex = (parent.ZIndex or 1) + 6,
	}, parent)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, streak)
	task.spawn(function()
		while streak.Parent and streak:IsDescendantOf(game) do
			streak.Position = UDim2.new(-0.3, 0, 0.5, 0)
			TweenService:Create(streak, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Position = UDim2.new(1.3, 0, 0.5, 0) }):Play()
			task.wait(every)
		end
	end)
end

-- A pill of words: `fill` behind, `ink` on it, tilted by `tilt`.
local function pill(parent: Instance, value: string, fill: Color3, ink: Color3, size: number, tilt: number?): TextLabel
	local p = new("TextLabel", {
		Name = "Pill",
		Text = value,
		TextSize = size,
		Font = Gilt.Display,
		TextColor3 = ink,
		BackgroundColor3 = fill,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 10),
		Rotation = tilt or 0,
		ZIndex = 8,
	}, parent)
	UiKit.round(p, 999)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, p)
	new("UIStroke", { Color = fill:Lerp(Color3.new(1, 1, 1), 0.5), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	return p
end

-- One offer, as a special: a card in its colour with a glowing, breathing
-- edge; its picture with a ribbon (opts.Ribbon) and what's in it (opts.
-- Sticker); its words; a big shining button (or the line saying it's yours);
-- and, on a clock, the time left (opts.Ends).
local function offer(body: Instance, order: number, opts)
	local theme = opts.Edge or Gilt.Gold
	local card = new("Frame", {
		Name = opts.Name,
		BackgroundColor3 = theme:Lerp(Color3.fromRGB(10, 12, 22), 0.82),
		Size = UDim2.new(1, 0, 0, opts.Height + 20),
		LayoutOrder = order,
	}, body)
	UiKit.round(card, 12)
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165)),
	}, card)
	local edge = new("UIStroke", { Color = theme, Thickness = 2, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	forever(card, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), edge, { Transparency = 0.65 })
	local row = new("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 1, -20),
	}, card)
	local wide = opts.WellWidth or opts.Height
	local well = new("Frame", {
		Name = "Well",
		Size = UDim2.fromOffset(wide, opts.Height),
	}, row)
	Gilt.well(well, theme)
	opts.Art(well)
	if opts.Ribbon then
		local ribbon = pill(well, opts.Ribbon, opts.RibbonColor or theme, Color3.fromRGB(24, 12, 2), 12, -6)
		ribbon.Name = "Ribbon"
		ribbon.Position = UDim2.fromOffset(-6, -8)
		forever(ribbon, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), ribbon, { Rotation = -2 })
	end
	if opts.Sticker then
		local sticker = pill(well, opts.Sticker, Color3.fromRGB(16, 18, 30), theme:Lerp(Color3.new(1, 1, 1), 0.35), 11)
		sticker.Name = "Sticker"
		sticker.AnchorPoint = Vector2.new(1, 1)
		sticker.Position = UDim2.new(1, -6, 1, -6)
		sticker.BackgroundTransparency = 0.15
	end
	local words = new("Frame", {
		Name = "Words",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(wide + 16, 0),
		Size = UDim2.new(1, -(wide + 16), 1, 0),
	}, row)
	local list = UiKit.list(words, 4)
	-- (the card as tall as its words, if they run past the picture)
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		card.Size = UDim2.new(1, 0, 0, math.max(opts.Height, list.AbsoluteContentSize.Y) + 20)
	end)
	local name = Gilt.words(words, opts.Title, 24, Gilt.Bright or Gilt.Ink)
	name.Font = Gilt.Display
	name.LayoutOrder = 1
	local sub = Gilt.words(words, opts.Sub, 13, theme:Lerp(Color3.new(1, 1, 1), 0.45))
	sub.LayoutOrder = 2
	sub.Font = IronUi.Body
	if opts.Ends then
		-- (the time left, ticking, in a hot pill)
		local clock = pill(words, "", Color3.fromRGB(255, 92, 70), Color3.new(1, 1, 1), 12)
		clock.Name = "Ends"
		clock.LayoutOrder = 3
		task.spawn(function()
			while clock:IsDescendantOf(game) or clock.Parent do
				clock.Text = "ENDS IN " .. opts.Ends()
				if not clock:IsDescendantOf(game) then
					break
				end
				task.wait(20)
			end
		end)
	end
	prose(words, opts.About, 13, Gilt.Ink, 4)
	local spacer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 5 }, words)
	spacer.Name = "Gap"
	if opts.Owned then
		local done = Gilt.words(words, "✓  " .. opts.Owned, 14, Gilt.Green)
		done.LayoutOrder = 6
	else
		local button = Gilt.button(words, opts.Button, true, 6, function()
			buy(opts.Key)
		end, 42, 17)
		button.Size = UDim2.new(0, 240, 0, 42)
		pcall(IronUi.juice, button, 1.06, 0.95)
		shine(button, 2.6)
	end
	-- (it pops in)
	local pop = new("UIScale", { Name = "Pop", Scale = 0.86 }, card)
	task.delay(0.06 * order, function()
		TweenService:Create(pop, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	return card
end

function KennelSale.open()
	KennelSale.close()
	local profile = GemClient.Profile or {}
	local phone = UiKit.short()
	local holder = new("Frame", { Name = "Sale", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen())
	local backdrop = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
	}, holder)
	backdrop.Activated:Connect(KennelSale.close)
	local body = Gilt.frame(holder, KennelSale.Width, phone)
	local frame = body.Parent :: Frame
	-- (on a short screen it shrinks to fit, never past the edges)
	local fit = new("UIScale", {}, frame)
	local function refit()
		local size = (gui :: ScreenGui).AbsoluteSize
		local height = math.max(1, frame.AbsoluteSize.Y / math.max(fit.Scale, 0.01))
		fit.Scale = math.min(1, (size.X - 32) / KennelSale.Width, (size.Y - 24) / height)
	end

	-- The heading, as a special: a hot banner (magenta into amber) with a
	-- shine across it, KAIJU SPECIALS on it, and Wren's line under it.
	local head = new("Frame", { Name = "Head", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 70), LayoutOrder = 1 }, body)
	UiKit.round(head, 12)
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 50, 210)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 96, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 186, 64)),
		}),
	}, head)
	new("UIStroke", { Color = Color3.fromRGB(255, 226, 160), Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, head)
	shine(head, 3.4)
	local title = Gilt.words(head, "⚡ KAIJU SPECIALS ⚡", 30, Color3.new(1, 1, 1))
	title.Font = Gilt.Display
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position, title.Size = UDim2.fromOffset(0, 6), UDim2.new(1, 0, 0, 36)
	title.ZIndex = 3
	new("UIStroke", { Color = Color3.fromRGB(70, 16, 60), Thickness = 2, Transparency = 0.2 }, title)
	local by = Gilt.words(head, "Wren's limited offers  ·  grab them before they're gone", 13, Color3.fromRGB(255, 244, 228))
	by.TextXAlignment = Enum.TextXAlignment.Center
	by.Font = IronUi.Body
	by.Position, by.Size = UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 16)
	by.ZIndex = 3
	-- (a few sparkles, twinkling)
	for i, at in { UDim2.new(0.08, 0, 0.3, 0), UDim2.new(0.2, 0, 0.72, 0), UDim2.new(0.82, 0, 0.26, 0), UDim2.new(0.93, 0, 0.7, 0) } do
		local spark = new("Frame", {
			Name = "Spark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at,
			Size = UDim2.fromOffset(7, 7),
			Rotation = 45,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.1,
			ZIndex = 3,
		}, head)
		forever(spark, TweenInfo.new(0.6 + i * 0.17, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), spark, { BackgroundTransparency = 0.9, Size = UDim2.fromOffset(3, 3) })
	end
	local closeButton = new("TextButton", {
		Name = "Close",
		Text = "×",
		TextSize = 26,
		Font = Gilt.Serif,
		TextColor3 = Color3.fromRGB(255, 240, 230),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 0),
		Size = UDim2.fromOffset(32, 32),
		ZIndex = 4,
	}, head)
	closeButton.MouseEnter:Connect(function()
		closeButton.TextColor3 = Color3.new(1, 1, 1)
	end)
	closeButton.MouseLeave:Connect(function()
		closeButton.TextColor3 = Color3.fromRGB(255, 240, 230)
	end)
	closeButton.Activated:Connect(KennelSale.close)

	-- The Starter Rare Roll: four of the rarest kinds in its picture.
	local rare = Kaiju.Sale.Rare
	local tall = if phone then 124 else 156
	offer(body, 3, {
		Name = "Rare",
		Height = tall,
		WellWidth = math.floor(tall * 1.6),
		Edge = Color3.fromRGB(176, 120, 255),
		Key = rare.Product,
		Ribbon = "✦ ONCE ONLY",
		RibbonColor = Color3.fromRGB(206, 160, 255),
		Sticker = "+ RARE GEMSOUL",
		Art = function(well)
			gallery(well, Kaiju.Sale.Showcase, Color3.fromRGB(176, 120, 255))
		end,
		Title = "A roll on the rarest kinds",
		Sub = string.format("%d kinds  ·  any element  ·  traits %d or better", #Kaiju.rareKinds(), rare.TraitFloor),
		About = "One roll on the starter roll's reels. It comes with a Rare Gemsoul holding its element's best surge. Once per miner.",
		Button = string.format("Roll  ·  R$ %d", Store.robuxPrice(rare.Product) or 0),
		Owned = if profile[rare.Once] then "Claimed. Thank you for your support." else nil,
	})

	-- The premium trio, side by side.
	local premium = Kaiju.Sale.Premium
	local trio = {}
	local elements = {}
	for _, element in premium.Elements do
		table.insert(trio, { Species = premium.Species, Element = element })
		table.insert(elements, GemConfig.elementName(element))
	end
	offer(body, 5, {
		Name = "Premium",
		Height = tall,
		WellWidth = math.floor(tall * 1.6),
		Edge = Gilt.Gold,
		Key = premium.Product,
		Ribbon = "★ BEST VALUE",
		RibbonColor = Color3.fromRGB(255, 206, 84),
		Sticker = "3 KAIJU  +  3 ULTRA RARE GEMS",
		Art = function(well)
			gallery(well, trio, Color3.fromRGB(96, 124, 255))
		end,
		Title = premium.Name,
		Sub = string.format("3 Triskulls  ·  %s  ·  traits %d or better", table.concat(elements, ", "), premium.TraitFloor),
		About = "Three-headed breakers, one in each element, each with an Ultra Rare Gemsoul holding its element's best Q, E and R.",
		Button = string.format("Buy  ·  R$ %d", Store.robuxPrice(premium.Product) or 0),
		Owned = if profile[premium.Once] then "Yours. Thank you for your support." else nil,
	})

	-- The Daily Kaiju Sale.
	local now = workspace:GetServerTimeNow()
	local day = Kennel.day(now)
	local special = Kennel.special(day)
	local kind = Kaiju.species(special.Species)
	local daily = Kaiju.Sale.Daily
	offer(body, 7, {
		Name = "Daily",
		Height = tall,
		WellWidth = math.floor(tall * 1.6),
		Edge = GemConfig.ElementColors[special.Element],
		Key = daily.Product,
		Ribbon = "🔥 TODAY ONLY",
		RibbonColor = Color3.fromRGB(255, 140, 84),
		Sticker = string.format("TRAITS %d+", daily.TraitFloor),
		Ends = function()
			return untilMidnight(workspace:GetServerTimeNow())
		end,
		Art = function(well)
			portrait(well, special.Species, special.Element)
		end,
		Title = kind and kind.Name or special.Species,
		Sub = string.format("%s  ·  %s  ·  a new kaiju every day", GemConfig.elementName(special.Element), kind and kind.Role or "Kaiju"),
		About = string.format(
			"One of the rarest kinds, on sale for today only, one each. Its traits are never poor: %d or better in all four.",
			daily.TraitFloor
		),
		Button = string.format("Buy  ·  R$ %d", Store.robuxPrice(daily.Product) or 0),
		Owned = if Kaiju.dailyBought(profile, day) then "Yours today. A new one comes at midnight." else nil,
	})

	-- (what happens to them)
	local note = prose(body, "Kaiju from the Kennel join your reserves: swap them into a team from YOUR KAIJU.", 12, Gilt.Dusk, 8)
	note.TextXAlignment = Enum.TextXAlignment.Center
	task.defer(refit)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
end

-- Bought: the window closes, a word of thanks while the receipt lands.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if not purchased or userId ~= player.UserId then
		return
	end
	local key = Store.productKey(productId)
	if key == Kaiju.Sale.Daily.Product or key == Kaiju.Sale.Rare.Product or key == Kaiju.Sale.Premium.Product then
		KennelSale.close()
	end
end)

return KennelSale
