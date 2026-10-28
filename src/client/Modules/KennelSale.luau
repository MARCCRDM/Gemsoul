--[[
	The Kennel's sales, in the gilt look (Client GiltUi): opened from the
	Daily Kaiju Sale's plinth (Client KennelLife) or from Wren, the kennel
	keeper (Dialogue). Three offers, each for Robux (Shared.Store), as the
	Store has them:

	  Starter Rare Roll   one roll on the rarest kinds, once ever: played on
	                      the roll screen (Client KaijuRoll) as soon as you
	                      have room; four of them in its picture
	                      (Kaiju.Sale.Showcase)
	  Triskull Trinity    the premium trio, once ever: three Triskulls, one
	                      in each element, turning side by side
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
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kaiju = require(Shared:WaitForChild("Kaiju"))
local Kennel = require(Shared:WaitForChild("KaijuKennel"))
local KaijuModels = require(Shared:WaitForChild("KaijuModels"))
local GemConfig = require(Shared:WaitForChild("GemConfig"))
local Store = require(Shared:WaitForChild("Store"))
local GemClient = require(script.Parent.GemClient)
local Gilt = require(script.Parent.GiltUi)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local new = IronUi.new
local player = Players.LocalPlayer

local KennelSale = {}
KennelSale.Width = 560

local gui: ScreenGui? = nil
local spin: RBXScriptConnection? = nil
-- The kaiju turning in their views: { Model, Center, Rest }.
local turning = {}

local function screen(): ScreenGui
	if not gui then
		gui = UiKit.gui("KennelSale", 45)
	end
	return gui :: ScreenGui
end

function KennelSale.close()
	if spin then
		spin:Disconnect()
		spin = nil
	end
	table.clear(turning)
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

-- A kaiju in a view filling `parent`, turning unless `still`.
local function portrait(parent: Instance, species: string, element: string, still: boolean?): ViewportFrame
	local model = KaijuModels.forPortrait(KaijuModels.build(species, element))
	local cf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y * 1.2, size.Z)
	local view = new("ViewportFrame", {
		Name = "KaijuView",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = KaijuModels.Portrait.Ambient,
		LightColor = KaijuModels.Portrait.LightColor,
		LightDirection = KaijuModels.Portrait.LightDirection,
	}, parent)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(reach * 0.55, reach * 0.35, -reach * 1.45), cf.Position)
	camera.Parent = view
	view.CurrentCamera = camera
	model.Parent = view
	if not still then
		table.insert(turning, { Model = model, Center = CFrame.new(cf.Position), Rest = model:GetPivot() })
		spin = spin
			or RunService.RenderStepped:Connect(function()
				local angle = (os.clock() * 0.5) % (math.pi * 2)
				for _, turn in turning do
					turn.Model:PivotTo(turn.Center * CFrame.Angles(0, angle, 0) * turn.Center:Inverse() * turn.Rest)
				end
			end)
	end
	return view
end

-- Views laid out in a grid filling `parent`, `cols` across.
local function gallery(parent: Instance, kaiju: { { Species: string, Element: string } }, cols: number, still: boolean?)
	local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local rows = math.ceil(#kaiju / cols)
	new("UIGridLayout", {
		CellSize = UDim2.fromScale(1 / cols, 1 / rows),
		CellPadding = UDim2.fromOffset(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	for i, shown in kaiju do
		local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i }, grid)
		portrait(cell, shown.Species, shown.Element, still)
	end
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

-- One offer: a well (the view or an emblem) beside its words, its button
-- under them, or the line saying it's yours.
local function offer(body: Instance, order: number, opts)
	local row = new("Frame", {
		Name = opts.Name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, opts.Height),
		LayoutOrder = order,
	}, body)
	local wide = opts.WellWidth or opts.Height
	local well = new("Frame", {
		Name = "Well",
		Size = UDim2.fromOffset(wide, opts.Height),
	}, row)
	Gilt.well(well, opts.Edge)
	opts.Art(well)
	local words = new("Frame", {
		Name = "Words",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(wide + 16, 0),
		Size = UDim2.new(1, -(wide + 16), 1, 0),
	}, row)
	local list = UiKit.list(words, 4)
	-- (the row as tall as its words, if they run past the well)
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		row.Size = UDim2.new(1, 0, 0, math.max(opts.Height, list.AbsoluteContentSize.Y))
	end)
	local name = Gilt.words(words, opts.Title, 22, Gilt.Ink)
	name.LayoutOrder = 1
	local sub = Gilt.words(words, opts.Sub, 13, Gilt.Faded)
	sub.LayoutOrder = 2
	sub.Font = IronUi.Body
	prose(words, opts.About, 13, Gilt.Ink, 3)
	local spacer = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 2), LayoutOrder = 4 }, words)
	spacer.Name = "Gap"
	if opts.Owned then
		local done = Gilt.words(words, opts.Owned, 14, Gilt.Green)
		done.LayoutOrder = 5
	else
		local button = Gilt.button(words, opts.Button, true, 5, function()
			buy(opts.Key)
		end, 36, 15)
		button.Size = UDim2.new(0, 220, 0, 36)
	end
	return row
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

	-- The heading: the Kennel's name and Wren's, a stud on a rule under it.
	local head = new("Frame", { Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = 1 }, body)
	local title = Gilt.words(head, "The Kennel", 26, Gilt.Gold)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Size = UDim2.new(1, 0, 0, 32)
	local by = Gilt.words(head, "Wren's sales", 13, Gilt.Faded)
	by.TextXAlignment = Enum.TextXAlignment.Center
	by.Font = IronUi.Body
	by.Position, by.Size = UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 16)
	local rule = Gilt.rule(head, true)
	rule.AnchorPoint, rule.Position = Vector2.new(0, 1), UDim2.fromScale(0, 1)
	Gilt.stud(head, 7, UDim2.new(0.5, 0, 1, 0)).ZIndex = 4
	local closeButton = new("TextButton", {
		Name = "Close",
		Text = "×",
		TextSize = 26,
		Font = Gilt.Serif,
		TextColor3 = Gilt.Faded,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 4, 0, -6),
		Size = UDim2.fromOffset(32, 32),
	}, head)
	closeButton.MouseEnter:Connect(function()
		closeButton.TextColor3 = Gilt.Bright
	end)
	closeButton.MouseLeave:Connect(function()
		closeButton.TextColor3 = Gilt.Faded
	end)
	closeButton.Activated:Connect(KennelSale.close)

	-- The Starter Rare Roll: four of the rarest kinds in its picture.
	local rare = Kaiju.Sale.Rare
	local tall = if phone then 112 else 132
	Gilt.heading(body, "Starter Rare Roll  ·  once only", 2, false)
	offer(body, 3, {
		Name = "Rare",
		Height = tall,
		Key = rare.Product,
		Art = function(well)
			gallery(well, Kaiju.Sale.Showcase, 2, true)
		end,
		Title = "A roll on the rarest kinds",
		Sub = string.format("%d kinds  ·  any element  ·  traits %d or better", #Kaiju.rareKinds(), rare.TraitFloor),
		About = "One roll on the starter roll's reels. It comes with a Rare Gemsoul holding its element's best surge. Once per miner.",
		Button = string.format("Roll  ·  R$ %d", Store.robuxPrice(rare.Product) or 0),
		Owned = if profile[rare.Once] then "Claimed. Thank you for your support." else nil,
	})

	-- The premium trio, side by side, turning.
	local premium = Kaiju.Sale.Premium
	local trio = {}
	local elements = {}
	for _, element in premium.Elements do
		table.insert(trio, { Species = premium.Species, Element = element })
		table.insert(elements, GemConfig.elementName(element))
	end
	Gilt.heading(body, "Premium  ·  once only", 4, false)
	offer(body, 5, {
		Name = "Premium",
		Height = tall,
		WellWidth = math.floor(tall * 1.5),
		Edge = Gilt.Gold,
		Key = premium.Product,
		Art = function(well)
			gallery(well, trio, #trio)
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
	Gilt.heading(body, "Daily Kaiju Sale", 6, false)
	offer(body, 7, {
		Name = "Daily",
		Height = tall,
		Key = daily.Product,
		Art = function(well)
			portrait(well, special.Species, special.Element)
		end,
		Title = kind and kind.Name or special.Species,
		Sub = string.format("%s  ·  %s  ·  New kaiju in %s", GemConfig.elementName(special.Element), kind and kind.Role or "Kaiju", untilMidnight(now)),
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
