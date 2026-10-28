--[[
	The store [B], laid out like a shop online: a clean header with the
	categories, product grids with a product page beside them, and bundles
	that show what they hold and what you save.

	  Featured      the front page: the kaiju deals (small: the Starter Rare
	                Roll, then the premium Triskull Trinity), then
	                the bundles: the new-player offer (Starter Pack or Welcome
	                Kit, while it's open), the player bundles (a whole look: suit, weapon
	                skin, helmet, visor, pickaxe) and the premium sets (Royal
	                Treasury, The Vault). Every bundle opens a
	                page listing each piece, what it costs on its own, and
	                what you save.
	  Weapon Skins, Suits, Pickaxes
	                a grid (sort by featured or price, show all or only what
	                you don't own) and the picked look's page: 3D preview,
	                price, buy or wear, and the bundle that saves on it.
	                Looks earned in play show after, saying how.
	  Kaiju         the kaiju sales (Shared.Kaiju.Sale): the Starter Rare
	                Roll (once ever) with its odds, the Triskull Trinity
	                (premium, once ever), and the Kaiju of the Day turning
	                in its view.
	  Free          the group, friends, the login streak and promo codes.

	Buying: a product with a Developer Product id opens Roblox's purchase
	prompt; while testing (Config.TestCosmeticPrice) it's bought for coins
	instead (StoreServer "BuyProduct"). Either way an order confirmation
	follows. Store.canBuy says what can be bought (one-time offers, things
	you own already).
	The Welcome Kit (new players) and the Starter Pack (after your first win)
	also pop up on their own, once.

	  ShopUI.open(tab?)   ShopUI.close()   ShopUI.toggle()   ShopUI.refresh()
	  ShopUI.showWelcome()   ShopUI.showStarter()
]]
local GroupService = game:GetService("GroupService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local FreeRewards = require(ReplicatedStorage.Shared.FreeRewards)
local Referrals = require(ReplicatedStorage.Shared.Referrals)
local Store = require(ReplicatedStorage.Shared.Store)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local CoinShop = require(script.Parent.CoinShop)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local MobileLayout = require(script.Parent.MobileLayout)
local ShopArt = require(script.Parent.ShopArt)
local UiKit = require(script.Parent.UiKit)
local UiSound = require(script.Parent.UiSound)

local player = Players.LocalPlayer
local new = IronUi.new

local ShopUI = {}

-- Whether this player may be pointed to Discord: Roblox allows naming it
-- only where PolicyService says so (AllowedExternalLinkReferences). Off
-- till it does.
local discordOk = false
task.spawn(function()
	local ok, info = pcall(function()
		return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
	end)
	local allowed = ok and type(info) == "table" and info.AllowedExternalLinkReferences
	discordOk = type(allowed) == "table" and table.find(allowed, "Discord") ~= nil
end)

-- Look ---------------------------------------------------------------------------------------------------

local C = {
	Window = Color3.fromRGB(11, 14, 22),
	WindowLow = Color3.fromRGB(7, 9, 15),
	Surface = Color3.fromRGB(20, 25, 37),
	Raised = Color3.fromRGB(27, 34, 50),
	Well = Color3.fromRGB(14, 18, 28),
	Line = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(240, 243, 248),
	Dim = Color3.fromRGB(150, 162, 184),
	Faint = Color3.fromRGB(96, 108, 130),
	Buy = Color3.fromRGB(0, 176, 106),
	BuyHover = Color3.fromRGB(16, 200, 124),
	Sale = Color3.fromRGB(255, 76, 92),
	Gold = Color3.fromRGB(255, 200, 92),
	Good = Color3.fromRGB(96, 214, 140),
	Ink = Color3.fromRGB(8, 10, 16),
}
local BLACK, BOLD, MEDIUM = Enum.Font.GothamBlack, Enum.Font.GothamBold, Enum.Font.GothamMedium
-- On a phone on its side (SHORT) the store is the whole screen instead of a
-- window over the world (MobileLayout.store): drawn 844 wide and as tall as
-- the screen's shape leaves, scaled to fill it, so it fills any phone. The
-- coins and the close button sit at the right end of Roblox's strip across
-- the top, the categories run down a rail on the left, and the page fills
-- the rest: a grid as many columns wide as fit beside the product page, and
-- every sheet sized to fit below Roblox's buttons. These sizes are then the
-- phone's, set each time it's fitted (layoutPhone).
local SHORT = UiKit.short()
local W, H = if SHORT then 844 else 1100, if SHORT then 390 else 660
local HEAD = if SHORT then 58 else 64
local PAGE_X = if SHORT then 148 else 24
local PAGE_Y = HEAD + (if SHORT then 4 else 16)
local PAGE_W, PAGE_H = W - PAGE_X - (if SHORT then 10 else 24), H - PAGE_Y - (if SHORT then 10 else 20)
-- (A phone's small print a size up: it's read at arm's length on a small
-- screen.)
local UP = if SHORT then 1 else 0
local KIND_NAMES = {
	Skin = "Weapon skin",
	Shield = "Shield skin",
	Suit = "Suit",
	Helmet = "Helmet",
	Visor = "Visor",
	Pick = "Pickaxe",
	Trim = "Trim",
	Back = "Back piece",
	Title = "Title",
}
local RARITY_NAMES =
	{ Common = "Common", Uncommon = "Uncommon", Rare = "Rare", UltraRare = "Ultra Rare", Legendary = "Legendary" }
local RANK = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
-- Where to get a look that isn't sold, in a sentence.
local HOW_TO = {
	Invite = "Bring friends to the game: see Free.",
	Group = "Join the game's Roblox group: see Free.",
	Streak = "Log in 7 days in a row: see Free.",
	Code = "From a promo code: they come with game updates and like milestones.",
	CodeDiscord = "From a promo code: watch our Discord and socials.",
	Starter = "Only in the Starter Pack, offered after your first win.",
	Season = "On the Season Path.",
	Default = "Every miner starts with it.",
	Achievement = "Earned by an achievement.",
	Ranked = "A Ranked reward.",
	Raid = "A raid reward.",
	Mining = "Found while mining, by luck.",
	Squad = "From the launch Squad Bundle: no longer sold.",
	Vault = "Only in The Vault.",
}

local state = {
	Tab = "Featured",
	Selected = {} :: { [string]: string }, -- the picked look, per catalog tab
	Sort = "Low",
	Filter = "All",
	Busy = false,
}

-- Small builders -------------------------------------------------------------------------------------------

local function round(object: GuiObject, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end

local function stroke(object: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end

local function box(parent: Instance, color: Color3, x: number, y: number, w: number, h: number, alpha: number?): Frame
	return new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = alpha or 0,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
end

local function text(
	parent: Instance,
	value: string,
	size: number,
	color: Color3,
	font: Enum.Font,
	x: number,
	y: number,
	w: number,
	h: number
): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
end

local function wrap(label: TextLabel): TextLabel
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	return label
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then
			return s
		end
	end
end

local function robux(n: number): string
	return "R$ " .. commas(n)
end

local function clock(seconds: number): string
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

-- A small rounded tag sized to its words.
local function pill(parent: Instance, value: string, color: Color3, filled: boolean?, size: number?): TextLabel
	local tag = new("TextLabel", {
		BackgroundColor3 = color,
		BackgroundTransparency = if filled == false then 0.85 else 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, (size or 10) + 10),
		Text = value,
		Font = BOLD,
		TextSize = size or 10,
		TextColor3 = if filled == false then color:Lerp(C.Text, 0.25) else C.Ink,
	}, parent)
	round(tag, 6)
	new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, tag)
	return tag
end

-- A button: "Primary" (buy), "Secondary" (outlined) or "Quiet" (text).
local function button(
	parent: Instance,
	value: string,
	style: string,
	x: number,
	y: number,
	w: number,
	h: number,
	onClick: (() -> ())?
): TextButton
	local primary, quiet = style == "Primary", style == "Quiet"
	local base = if primary then C.Buy elseif quiet then C.Surface else C.Raised
	local b = new("TextButton", {
		Text = value,
		AutoButtonColor = false,
		Font = BOLD,
		TextSize = if h >= 44 then 16 else 13,
		TextColor3 = if primary then Color3.new(1, 1, 1) elseif quiet then C.Dim else C.Text,
		BackgroundColor3 = base,
		BackgroundTransparency = if quiet then 1 else 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
	}, parent)
	round(b, 10)
	if not primary and not quiet then
		stroke(b, C.Line, 1, 0.82)
	end
	b:SetAttribute("UiSound", if primary then "Confirm" else "Click")
	b.MouseEnter:Connect(function()
		if primary then
			b.BackgroundColor3 = C.BuyHover
		elseif quiet then
			b.TextColor3 = C.Text
		else
			b.BackgroundColor3 = C.Raised:Lerp(C.Line, 0.06)
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = base
		b.TextColor3 = if primary then Color3.new(1, 1, 1) elseif quiet then C.Dim else C.Text
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- A dark well for a product's picture, washed with its colour from below.
local function well(parent: Instance, tint: Color3, x: number, y: number, w: number, h: number): Frame
	local frame = box(parent, Color3.new(1, 1, 1), x, y, w, h)
	frame.ClipsDescendants = true
	round(frame, 10)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(C.Well, C.Well:Lerp(tint, 0.22)),
	}, frame)
	local glow = new("Frame", {
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.9,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.8, 0.8),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	}, frame)
	round(glow, 999)
	return frame
end

-- A product's picture at `size`, centred at (cx, cy) in `parent`.
local function art(parent: Instance, kind: string, id: string?, size: number, cx: number?, cy: number?): GuiObject
	local icon = ShopArt.icon(parent, kind, id, size)
	if cx then
		icon.Position = UDim2.new(cx, 0, cy or 0.5, 0)
	end
	return icon
end

-- Hover: a card lifts its edge.
local function hoverEdge(card: GuiButton, edge: UIStroke, rest: Color3, restAlpha: number)
	card.MouseEnter:Connect(function()
		edge.Color, edge.Transparency = C.Line, 0.55
	end)
	card.MouseLeave:Connect(function()
		edge.Color, edge.Transparency = rest, restAlpha
	end)
end

-- State ---------------------------------------------------------------------------------------------------------

local function profile()
	return GemClient.Profile or {}
end

local function owned(id: string): boolean
	local p = profile()
	return p.Cosmetics ~= nil and p.Cosmetics.Owned ~= nil and p.Cosmetics.Owned[id] == true
end

local function worn(kind: string): string?
	local p = profile()
	return p.Cosmetics and p.Cosmetics[kind] or nil
end

-- The server's clock (the profile carries its time when it was sent).
local syncedAt, serverAt = os.clock(), os.time()
GemClient.Changed:Connect(function()
	local p = profile()
	if p.ServerTime then
		syncedAt, serverAt = os.clock(), p.ServerTime
	end
end)
local function now(): number
	return serverAt + math.floor(os.clock() - syncedAt)
end

local function starterLeft(): number
	local p = profile()
	if not Store.starterOpen(p.StarterOfferAt, p.StarterBought, now()) then
		return 0
	end
	return math.max(0, p.StarterOfferAt + Store.StarterPack.Hours * 3600 - now())
end

local function welcomeLeft(): number
	local p = profile()
	if not Store.welcomeOpen(p.FirstJoin, p.WelcomeBought, now()) then
		return 0
	end
	return math.max(0, p.FirstJoin + Store.WelcomeHours * 3600 - now())
end

-- Timers on screen, ticked every second: { Label, Left = fn, Prefix }.
local timers = {}
local function timer(label: TextLabel, left: () -> number, prefix: string)
	table.insert(timers, { Label = label, Left = left, Prefix = prefix })
	label.Text = prefix .. clock(left())
end

-- Buying ---------------------------------------------------------------------------------------------------

local showReceipt -- (forward)
local refresh -- (forward)

local function live(key: string): boolean
	return (Store.RobuxProducts[key] or 0) ~= 0
end

-- Buys a product: Roblox's prompt for Robux, or coins while testing.
local function buy(key: string)
	if state.Busy then
		return
	end
	local ok, why = Store.canBuy(key, profile(), now())
	if not ok then
		UiKit.toast(why or "That isn't for sale.", C.Dim)
		return
	end
	if live(key) then
		MarketplaceService:PromptProductPurchase(player, Store.RobuxProducts[key])
		return
	end
	if not Store.testPrice(key) then
		UiKit.toast("Coming soon: this isn't on sale yet.", C.Dim)
		return
	end
	state.Busy = true
	task.spawn(function()
		local result = GemClient.request("BuyProduct", key)
		state.Busy = false
		if result.Ok then
			showReceipt(key)
		else
			UiKit.toast(result.Message or "That didn't go through.", C.Sale)
		end
		refresh()
	end)
end

local function equip(kind: string, id: string?)
	if state.Busy then
		return
	end
	state.Busy = true
	task.spawn(function()
		local result = GemClient.request("EquipCosmetic", kind, id)
		state.Busy = false
		UiKit.toast(result.Message or "", if result.Ok then C.Good else C.Sale)
		refresh()
	end)
end

-- A purchase that went through on Roblox's prompt: the confirmation, once
-- the profile has caught up.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if userId ~= player.UserId or not purchased then
		return
	end
	local key = Store.productKey(productId)
	-- (A swing refill is Garrick's: OutpostScene confirms those. A coin
	-- pack is the coin window's: CoinShop.)
	if key and not Store.refill(key) and not Store.coinPack(key) then
		task.delay(0.8, function()
			showReceipt(key)
			refresh()
		end)
	end
end)

-- The window ------------------------------------------------------------------------------------------------

local gui = UiKit.gui("Shop", 10)
gui.Enabled = false
gui.IgnoreGuiInset = true
-- (A phone: the window keeps inside the screen's notch and rounded corners,
-- and the shade behind it is the store's own dark, out to the edges.)
if SHORT then
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)
end
local shade = new("TextButton", {
	Name = "Shade",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = if SHORT then C.WindowLow else Color3.new(0, 0, 0),
	BackgroundTransparency = if SHORT then 0 else 0.4,
	Position = if SHORT then UDim2.fromOffset(-120, -120) else UDim2.new(),
	Size = if SHORT then UDim2.new(1, 240, 1, 240) else UDim2.fromScale(1, 1),
}, gui)
local panel = new("Frame", {
	Name = "Store",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Active = true,
}, gui)
-- (a phone: the whole screen, square to its edges)
if not SHORT then
	round(panel, 16)
	stroke(panel, C.Line, 1, 0.86)
end
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Window, C.WindowLow) }, panel)
local scale = new("UIScale", {}, panel)

-- Header: the name, the categories, an offer while one's open, coins, close.
-- (A phone: Roblox's strip across the top is the header, with the coins and
-- the close button at its right end, and the categories run down a rail on
-- the left, the picked one lit with a gold edge.)
if not SHORT then
	local brand = text(panel, "STORE", 20, C.Text, BLACK, 28, 14, 120, 26)
	brand.Name = "Brand"
	text(panel, "KAIJU  ·  LOOKS  ·  BUNDLES", 9, C.Faint, BOLD, 28, 40, 150, 12).Name = "Promise"
end
local band = if SHORT then box(panel, C.Ink, 0, 0, W, HEAD, 0.45) else nil
if band then
	band.Name = "Strip"
end
local nav = new("Frame", {
	Name = if SHORT then "Rail" else "Nav",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(196, 0),
	Size = UDim2.fromOffset(600, HEAD),
}, panel)
-- (Eight tabs: close together, so the offer's clock on the right never
-- covers the last of them.)
local navList = UiKit.list(nav, if SHORT then MobileLayout.Store.TabGap else 12, not SHORT)
if not SHORT then
	navList.VerticalAlignment = Enum.VerticalAlignment.Center
end
local navButtons = {}
local navLabels = {} -- (the button itself, or on a phone the name in it)
local dealTag: TextLabel? = nil -- (a phone: SALE on Featured while the offer's open)
for i, id in Store.Tabs do
	local b = new("TextButton", {
		Name = id .. "Tab",
		Text = if SHORT then "" else Store.TabNames[id],
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BackgroundColor3 = C.Raised,
		AutomaticSize = if SHORT then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, HEAD),
		Font = BOLD,
		TextSize = 14,
		TextColor3 = C.Dim,
		LayoutOrder = i,
	}, nav)
	local label: TextLabel | TextButton = b
	local underline
	if SHORT then
		round(b, 10)
		label = text(b, Store.TabNames[id], 14, C.Dim, BOLD, 16, 0, 0, 0)
		label.Size = UDim2.new(1, -20, 1, 0)
		label.TextTruncate = Enum.TextTruncate.AtEnd
		underline = box(b, C.Gold, 0, 0, 4, 0)
		underline.AnchorPoint = Vector2.new(0, 0.5)
		underline.Position = UDim2.new(0, 5, 0.5, 0)
		underline.Size = UDim2.new(0, 4, 0.55, 0)
		if id == "Featured" then
			dealTag = pill(b, "SALE", C.Sale, true, 9)
			local tag = dealTag :: TextLabel
			tag.Name = "DealTag"
			tag.AnchorPoint = Vector2.new(1, 0.5)
			tag.Position = UDim2.new(1, -8, 0.5, 0)
			tag.Visible = false
		end
	else
		underline = box(b, C.Gold, 0, HEAD - 4, 0, 3)
		underline.Size = UDim2.new(1, 0, 0, 3)
	end
	underline.Name = "Underline"
	round(underline, 2)
	b:SetAttribute("UiSound", "Tab")
	b.MouseEnter:Connect(function()
		label.TextColor3 = C.Text
	end)
	b.MouseLeave:Connect(function()
		label.TextColor3 = if state.Tab == id then C.Text else C.Dim
	end)
	b.Activated:Connect(function()
		if state.Tab ~= id then
			state.Tab = id
			refresh()
		end
	end)
	navButtons[id] = b
	navLabels[id] = label
end
local headerRule = box(panel, C.Line, 0, HEAD, W, 1, 0.92)
headerRule.Name = "HeaderRule"

local close = new("TextButton", {
	Name = "Close",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = C.Surface,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -20, 0, (HEAD - 36) / 2),
	Size = UDim2.fromOffset(36, 36),
}, panel)
IronUi.cross(close, if SHORT then 15 else 14, C.Dim)
round(close, if SHORT then 20 else 18)
close:SetAttribute("UiSound", "Back")
-- Right of the categories: the offer (while one's open), then coins.
local corner = new("Frame", {
	Name = "Corner",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -68, 0, (HEAD - 36) / 2),
	Size = UDim2.fromOffset(if SHORT then 160 else 400, 36),
}, panel)
local cornerList = UiKit.list(corner, 10, true)
cornerList.HorizontalAlignment = Enum.HorizontalAlignment.Right
cornerList.VerticalAlignment = Enum.VerticalAlignment.Center
local wallet = new("Frame", {
	Name = "Wallet",
	BackgroundColor3 = C.Surface,
	Size = UDim2.fromOffset(0, 36),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
}, corner)
round(wallet, 18)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 14) }, wallet)
UiKit.list(wallet, 8, true).VerticalAlignment = Enum.VerticalAlignment.Center
local walletCoin =
	new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1 }, wallet)
ShopArt.coin(walletCoin, 18)
local walletValue = text(wallet, "0", 15, C.Text, BLACK, 0, 0, 0, 36)
walletValue.AutomaticSize = Enum.AutomaticSize.X
walletValue.LayoutOrder = 2
-- (a + to top it up: the coin packs, Client CoinShop)
local walletPlus = text(wallet, "+", 16, C.Ink, BLACK, 0, 0, 20, 20)
walletPlus.Name = "TopUp"
walletPlus.TextXAlignment = Enum.TextXAlignment.Center
walletPlus.BackgroundTransparency = 0
walletPlus.BackgroundColor3 = Color3.fromRGB(255, 202, 91)
walletPlus.LayoutOrder = 3
round(walletPlus, 10)
CoinShop.hook(wallet)
-- While the Starter Pack (or the Welcome Kit) is open: a deal, with its clock.
local deal = new("TextButton", {
	Name = "Deal",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = C.Sale,
	LayoutOrder = 1,
	Size = UDim2.fromOffset(0, 30),
	AutomaticSize = Enum.AutomaticSize.X,
	Font = BOLD,
	TextSize = 12,
	TextColor3 = Color3.new(1, 1, 1),
	Visible = false,
}, corner)
round(deal, 15)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, deal)
deal:SetAttribute("UiSound", "Tab")

local page = new("Frame", {
	Name = "Page",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(PAGE_X, PAGE_Y),
	Size = UDim2.fromOffset(PAGE_W, PAGE_H),
}, panel)

-- Fitting it to the screen. The screen is the window's own size, unless
-- that disagrees with the camera on which way up the phone is: a window
-- built while the phone was still upright can keep that size while it's
-- hidden, and the Store came out fitted to an upright phone, a third of
-- the size, once turned.
local function screenSize(): Vector2
	local screen = gui.AbsoluteSize
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else screen
	if view.X > 2 and view.Y > 2 and (screen.X <= 2 or (view.X > view.Y) ~= (screen.X > screen.Y)) then
		return view
	end
	return screen
end

-- A phone: the whole screen (MobileLayout.store), redrawn when its shape
-- changes.
local phone = nil
local function layoutPhone(screen: Vector2)
	-- (Roblox's strip is measured across the whole screen; the window sits
	-- inside the notches, as far in from each side.)
	local camera = workspace.CurrentCamera
	local whole = if camera then math.max(camera.ViewportSize.X, screen.X) else screen.X
	local top, _, right = UiKit.topbar(whole)
	local fitted = MobileLayout.store(screen, top, right - (whole - screen.X) / 2)
	local moved = phone == nil or phone.W ~= fitted.W or phone.H ~= fitted.H or phone.Strip ~= fitted.Strip
	phone = fitted
	W, H, HEAD = fitted.W, fitted.H, fitted.Strip
	PAGE_X, PAGE_Y, PAGE_W, PAGE_H = fitted.Page.X, fitted.Page.Y, fitted.Page.W, fitted.Page.H
	panel.Size = UDim2.fromOffset(W, H)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	scale.Scale = fitted.Scale
	if band then
		band.Size = UDim2.fromOffset(W, HEAD)
	end
	headerRule.Position = UDim2.fromOffset(0, HEAD)
	headerRule.Size = UDim2.fromOffset(W, 1)
	local rail = fitted.Rail
	nav.Position = UDim2.fromOffset(rail.X, rail.Y)
	nav.Size = UDim2.fromOffset(rail.W, rail.H)
	for _, b in navButtons do
		b.Size = UDim2.fromOffset(rail.W, fitted.TabH)
	end
	local x = fitted.Close
	close.AnchorPoint = Vector2.zero
	close.Position = UDim2.fromOffset(x.X, x.Y)
	close.Size = UDim2.fromOffset(x.W, x.H)
	corner.Position = UDim2.fromOffset(fitted.Wallet.Right, x.Y)
	corner.Size = UDim2.fromOffset(160, fitted.Wallet.H)
	page.Size = UDim2.fromOffset(PAGE_W, PAGE_H)
	if moved and gui.Enabled then
		refresh()
	end
end

-- A computer: the window, scaled down to fit when the screen is small, and
-- clear of Roblox's buttons. (The opening's little grow runs to the fitted
-- size; a fit while it runs takes over.)
local pop: Tween? = nil
local fittedScale = 1
local function fit()
	local screen = screenSize()
	if screen.X <= 0 or screen.Y <= 0 then
		return
	end
	if SHORT then
		layoutPhone(screen)
		return
	end
	local s = math.min(1, (screen.X - 24) / W, (screen.Y - (if screen.Y < 500 then 12 else 24)) / H)
	local room, at = UiKit.clearTopbar(screen, Vector2.new(W, H) * s)
	panel.Position = at
	if pop and s * room == fittedScale then
		return
	end
	if pop then
		pop:Cancel()
		pop = nil
	end
	fittedScale = s * room
	scale.Scale = fittedScale
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
UiKit.onTopbar(fit)
local function watchCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end
watchCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)

-- Over everything: a bundle's page, or an order confirmation.
local overlay = new("TextButton", {
	Name = "Overlay",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.25,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 20,
}, panel)
if not SHORT then
	round(overlay, 16)
end

local function closeOverlay()
	overlay.Visible = false
	IronUi.clear(overlay)
end
overlay.Activated:Connect(closeOverlay)

-- A card in the overlay, centred, with a close button.
local function overlayCard(w: number, h: number): Frame
	IronUi.clear(overlay)
	overlay.Visible = true
	local card = new("TextButton", {
		Name = "Sheet",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Window,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, if SHORT then HEAD / 2 else 0),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 21,
	}, overlay)
	round(card, 16)
	stroke(card, C.Line, 1, 0.8)
	-- (never bigger than the store itself; a phone's, below Roblox's strip)
	local room = H - (if SHORT then HEAD else 0)
	new("UIScale", { Scale = math.min(1, (W - 16) / w, (room - 16) / h) }, card)
	local x = new("TextButton", {
		Name = "CloseSheet",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Surface,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(32, 32),
		ZIndex = 30,
	}, card)
	IronUi.cross(x, 13, C.Dim)
	round(x, 16)
	x.Activated:Connect(closeOverlay)
	return card
end

-- Prices ------------------------------------------------------------------------------------------------------------

-- A product's price line: what its looks cost one by one (struck through),
-- its price, and the saving, side by side.
local function priceRow(parent: Instance, key: string, x: number, y: number, size: number, badge: boolean?): Frame
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(0, size + 6),
		AutomaticSize = Enum.AutomaticSize.X,
	}, parent)
	local list = UiKit.list(row, 8, true)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local price = Store.robuxPrice(key) or 0
	local reward = Store.contents(key)
	local separate = if reward and not Cosmetics.get(key) then Store.separatePrice(reward) else 0
	local now_ = text(row, robux(price), size, C.Text, BLACK, 0, 0, 0, size + 6)
	now_.AutomaticSize = Enum.AutomaticSize.X
	now_.LayoutOrder = 1
	if separate > price then
		local was = text(row, "<s>" .. robux(separate) .. "</s>", math.max(11, size - 6), C.Faint, BOLD, 0, 0, 0, size)
		was.RichText = true
		was.AutomaticSize = Enum.AutomaticSize.X
		was.LayoutOrder = 2
		if badge ~= false then
			pill(row, "-" .. Store.savings(key) .. "%", C.Sale, true, math.max(10, math.floor(size * 0.5))).LayoutOrder =
				3
		end
	end
	return row
end

-- What a reward holds, counted: "4 looks · 1 extra · 1,000 coins".
local function counts(reward: Store.Reward): string
	local looks, extras = 0, 0
	for _, id in reward.Cosmetics or {} do
		local cosmetic = Cosmetics.get(id)
		if cosmetic and Cosmetics.isMinerKind(cosmetic.Kind) then
			looks += 1
		else
			extras += 1
		end
	end
	local parts = {}
	if looks > 0 then
		table.insert(parts, string.format("%d look%s", looks, if looks == 1 then "" else "s"))
	end
	if extras > 0 then
		table.insert(parts, string.format("%d extra%s", extras, if extras == 1 then "" else "s"))
	end
	if reward.Coins then
		table.insert(parts, commas(reward.Coins) .. " coins")
	end
	if reward.XPBoostMinutes then
		table.insert(
			parts,
			if reward.XPBoostMinutes >= 60
				then string.format("%dh 2x XP", reward.XPBoostMinutes // 60)
				else string.format("%dm 2x XP", reward.XPBoostMinutes)
		)
	end
	return table.concat(parts, " · ")
end

-- The buy button's words for a product: its price, or why it can't be had.
local function buyWords(key: string): (string, boolean)
	local ok, why = Store.canBuy(key, profile(), now())
	if ok then
		return "Buy  ·  " .. robux(Store.robuxPrice(key) or 0), true
	end
	if why and (string.find(why, "own") or string.find(why, "already")) then
		return "Owned", false
	end
	return "Unavailable", false
end

local function buyButton(parent: Instance, key: string, x: number, y: number, w: number, h: number): TextButton
	local words, ok = buyWords(key)
	local b = button(parent, words, if ok then "Primary" else "Secondary", x, y, w, h, function()
		buy(key)
	end)
	b.Name = "Buy"
	if not ok then
		b.TextColor3 = C.Dim
		b.AutoButtonColor = false
	end
	return b
end

-- A few of a reward's looks, small, stacked down the right of a well.
local function thumbs(parent: Frame, ids: { string }, skip: string?, size: number, max: number)
	local n = 0
	for _, id in ids do
		if id ~= skip and n < max then
			n += 1
			local slot = box(parent, C.Ink, 0, 0, size, size, 0.45)
			slot.AnchorPoint = Vector2.new(1, 0)
			slot.Position = UDim2.new(1, -8, 0, 8 + (n - 1) * (size + 6))
			round(slot, 8)
			art(slot, "Cosmetic", id, size - 6)
		end
	end
end

-- Bundle page -----------------------------------------------------------------------------------------------------

local showBundle -- (forward)

-- One line of a bundle's page: the piece, what it is, what it costs alone.
local function contentRow(parent: Instance, item: Store.RewardItem, order: number)
	local row = box(parent, C.Surface, 0, 0, 0, 56)
	row.Size = UDim2.new(1, -8, 0, 56)
	row.LayoutOrder = order
	row.ZIndex = 22
	round(row, 10)
	local slot = box(row, C.Well, 8, 8, 40, 40)
	slot.ZIndex = 22
	round(slot, 8)
	art(slot, item.Kind, item.Id, 36)
	local cosmetic = item.Id and Cosmetics.get(item.Id)
	local name = text(row, item.Text, 14, C.Text, BOLD, 60, 9, 250, 20)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local sub = if cosmetic
		then (KIND_NAMES[cosmetic.Kind] or cosmetic.Kind) .. "  ·  " .. (RARITY_NAMES[cosmetic.Rarity] or cosmetic.Rarity)
		elseif item.Kind == "Coins" then commas(item.Count or 0) .. " coins"
		else "Boost"
	text(row, sub, 11, if cosmetic then Cosmetics.rarityColor(cosmetic) or C.Dim else C.Dim, MEDIUM, 60, 29, 250, 16)
	local right = if cosmetic and cosmetic.Robux
		then robux(cosmetic.Robux)
		elseif cosmetic and cosmetic.Exclusive then "Exclusive"
		elseif cosmetic then "Bundle extra"
		else "Included"
	local value = text(row, right, 13, if cosmetic and cosmetic.Robux then C.Text else C.Gold, BOLD, 0, 0, 120, 56)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, -14, 0, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
	if cosmetic and owned(cosmetic.Id) then
		local have = pill(row, "OWNED", C.Good, false)
		have.AnchorPoint = Vector2.new(1, 0.5)
		have.Position = UDim2.new(1, -110, 0.5, 0)
	end
	for _, d in row:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 23
		end
	end
end

-- A bundle's (or kits') page: every piece, the totals, buy.
function showBundle(key: string)
	local reward = Store.contents(key)
	if not reward then
		return
	end
	-- (a short screen: the sheet is shorter, its summary stacked tighter)
	-- (a phone: shorter still, and the buy button goes under the list)
	local Y = if SHORT
		then { Card = 320, List = 172, Pic = 70, Art = 60, Name = 78, About = 108, Lines = 146, Buy = 258 }
		else { Card = 540, List = 440, Pic = 150, Art = 130, Name = 162, About = 214, Lines = 268, Buy = 412 }
	local card = overlayCard(860, Y.Card)
	local items = Store.items(reward, function(id)
		local cosmetic = Cosmetics.get(id)
		return if cosmetic then cosmetic.Name else id
	end)
	text(card, "What's inside", 20, C.Text, BLACK, 26, 22, 300, 28).ZIndex = 22
	text(card, string.format("%d items", #items), 12, C.Dim, MEDIUM, 26, 50, 300, 16).ZIndex = 22
	local list = new("ScrollingFrame", {
		Name = "Contents",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(26, 78),
		Size = UDim2.fromOffset(500, Y.List),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Faint,
		ZIndex = 22,
	}, card)
	UiKit.list(list, 8)
	for i, item in items do
		contentRow(list, item, i)
	end
	-- The summary.
	local bundle = Store.bundle(key)
	local kits = Store.kitsOf(key)
	local hero = if bundle
		then bundle.Hero
		elseif key == "StarterPack" then Store.StarterPack.Hero
		elseif kits then kits[1].Contents.Cosmetics[1]
		else (reward.Cosmetics or {})[1]
	local tint = if bundle
		then bundle.Color
		elseif key == "StarterPack" then Store.StarterPack.Color
		elseif kits then kits[1].Color
		else C.Gold
	local side = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(548, 64),
		Size = UDim2.fromOffset(286, Y.Card - 80),
		ZIndex = 22,
	}, card)
	local pic = well(side, tint, 0, 0, 286, Y.Pic)
	pic.ZIndex = 22
	if hero then
		art(pic, "Cosmetic", hero, Y.Art)
	end
	local name = wrap(
		text(side, Store.productName(key), if SHORT then 18 else 21, C.Text, BLACK, 0, Y.Name, 286, if SHORT then 26 else 54)
	)
	local tagline = if bundle
		then bundle.Tagline
		elseif key == "StarterPack" then Store.StarterPack.Tagline
		elseif kits and not MinerRoster.Enabled then "Your miner wears the first; the rest wait in your Wardrobe."
		elseif kits and #kits == #Store.Kits then "All three squad kits, one per miner, and the FULL SQUAD title."
		elseif kits then "Each kit dresses one of your miners."
		else ""
	local about = wrap(text(side, tagline, 12, C.Dim, MEDIUM, 0, Y.About, 286, if SHORT then 34 else 46))
	local price = Store.robuxPrice(key) or 0
	local separate = Store.separatePrice(reward)
	local y = Y.Lines
	local function line(left: string, right: string, color: Color3, bold: boolean?)
		text(side, left, 13, C.Dim, MEDIUM, 0, y, 180, 20).ZIndex = 22
		local r = text(side, right, 13, color, if bold then BLACK else BOLD, 106, y, 180, 20)
		r.TextXAlignment = Enum.TextXAlignment.Right
		r.ZIndex = 22
		y += 24
	end
	if separate > 0 then
		line("Looks bought one by one", robux(separate), C.Dim)
	end
	line("Bundle price", robux(price), C.Text, true)
	if separate > price then
		box(side, C.Line, 0, y + 2, 286, 1, 0.9).ZIndex = 22
		y += 8
		line("You save", string.format("%s  (%d%%)", robux(separate - price), Store.savings(key)), C.Sale, true)
	end
	local have, total = Store.ownedCount(reward, profile().Cosmetics and profile().Cosmetics.Owned)
	if have > 0 and have < total then
		local note = wrap(
			text(
				side,
				string.format("You own %d of these already: each becomes %d coins.", have, Store.DuplicateRefund),
				11,
				C.Gold,
				BOLD,
				0,
				y + 4,
				286,
				30
			)
		)
		note.ZIndex = 22
	end
	local b = if SHORT then buyButton(card, key, 26, Y.Buy, 500, 44) else buyButton(side, key, 0, Y.Buy, 286, 46)
	b.ZIndex = 23
	for _, d in { name, about } do
		d.ZIndex = 22
	end
	for _, d in side:GetDescendants() do
		if d:IsA("GuiObject") and d.ZIndex < 22 then
			d.ZIndex = 22
		end
	end
end

-- Order confirmation ------------------------------------------------------------------------------------------------

function showReceipt(key: string)
	-- (A kaiju joins your reserves, or its roll plays on the roll screen:
	-- the store gets out of its way. A revive is back on its feet now.)
	local bought = Store.contents(key) or {}
	if bought.KaijuSale then
		ShopUI.close()
		UiKit.toast("Thank you! " .. Store.productName(key) .. ": yours.", C.Good)
		return
	elseif bought.KaijuRevive then
		UiKit.toast("Your kaiju are back on their feet.", C.Good)
		return
	end
	if not gui.Enabled then
		UiKit.toast("Thanks! " .. Store.productName(key) .. " is yours.", C.Good)
		return
	end
	local card = overlayCard(560, 380)
	local tick = box(card, C.Good, 252, 30, 56, 56)
	tick.ZIndex = 22
	round(tick, 28)
	local mark = text(tick, "✓", 30, C.Ink, BLACK, 0, 0, 56, 56)
	mark.TextXAlignment = Enum.TextXAlignment.Center
	mark.ZIndex = 23
	local head = text(card, "Thank you!", 26, C.Text, BLACK, 0, 98, 560, 32)
	head.TextXAlignment = Enum.TextXAlignment.Center
	head.ZIndex = 22
	local sub = text(card, "Order complete: " .. Store.productName(key), 14, C.Dim, MEDIUM, 30, 132, 500, 20)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.ZIndex = 22
	local reward = Store.contents(key) or {}
	local strip = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 170),
		Size = UDim2.fromOffset(500, 84),
		ZIndex = 22,
	}, card)
	local layout = UiKit.list(strip, 10, true)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	for i, item in Store.items(reward) do
		if i > 6 then
			break
		end
		local slot = box(strip, C.Surface, 0, 0, 72, 72)
		slot.LayoutOrder = i
		slot.ZIndex = 22
		round(slot, 10)
		art(slot, item.Kind, item.Id, 60)
	end
	local note = text(
		card,
		if Store.kitsOf(key) and MinerRoster.Enabled
			then "Your miners are wearing their kits. Change looks anytime in the Wardrobe."
			elseif key == "Vault" then "Everything is in your Wardrobe."
			else "It's on. Change looks anytime in the Wardrobe.",
		12,
		C.Faint,
		MEDIUM,
		30,
		266,
		500,
		18
	)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.ZIndex = 22
	local done = button(card, "Continue shopping", "Primary", 160, 302, 240, 46, closeOverlay)
	done.ZIndex = 23
	for _, d in card:GetDescendants() do
		if d:IsA("GuiObject") and d.ZIndex < 22 then
			d.ZIndex = 22
		end
	end
	UiSound.play("Reward")
end

-- Catalog: weapon skins, suits, pickaxes --------------------------------------------------------------------

-- (A phone's grid is as many columns as fit beside the product page, its
-- sizes set as each page is drawn: MobileLayout.storeGrid.)
local CARD_W, GAP = 163, if SHORT then MobileLayout.StoreGrid.Gap else 12
local COLS = 4
-- Where a card's parts sit, top to bottom (smaller on a phone).
local CARD = if SHORT
	then { H = 172, Pic = 88, Art = 74, Name = 100, Kind = 119, Price = 138 }
	else { H = 226, Pic = 128, Art = 104, Name = 142, Kind = 161, Price = 186 }
local CARD_H = CARD.H
local GRID_W = COLS * CARD_W + (COLS - 1) * GAP
local PRODUCT_X = GRID_W + 20

-- The looks of a kind: sold ones (sorted and filtered), then the earned.
local function catalog(kind: string): ({ string }, { string })
	local sold, earned = {}, {}
	for _, id in Cosmetics.ofKind(kind) do
		local cosmetic = Cosmetics.List[id]
		if state.Filter == "NotOwned" and owned(id) then
			continue
		end
		table.insert(if cosmetic.Robux then sold else earned, id)
	end
	table.sort(sold, function(a, b)
		local x, y = Cosmetics.List[a], Cosmetics.List[b]
		if state.Sort == "Low" and x.Robux ~= y.Robux then
			return x.Robux < y.Robux
		elseif state.Sort == "High" and x.Robux ~= y.Robux then
			return x.Robux > y.Robux
		end
		local rx, ry = RANK[x.Rarity] or 0, RANK[y.Rarity] or 0
		if rx ~= ry then
			return rx > ry
		end
		if x.Robux ~= y.Robux then
			return x.Robux > y.Robux
		end
		return x.Name < y.Name
	end)
	return sold, earned
end

local function productCard(parent: Instance, id: string, order: number, tab: string)
	local cosmetic = Cosmetics.List[id]
	local color = Cosmetics.rarityColor(cosmetic) or C.Dim
	local picked = state.Selected[tab] == id
	local mine, isWorn = owned(id), worn(cosmetic.Kind) == id
	local card = new("TextButton", {
		Name = id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if picked then C.Raised else C.Surface,
		LayoutOrder = order,
	}, parent)
	round(card, 12)
	local edge = stroke(card, if picked then C.Gold else C.Line, if picked then 2 else 1, if picked then 0 else 0.9)
	if not picked then
		hoverEdge(card, edge, C.Line, 0.9)
	end
	local pic = well(card, color, 6, 6, CARD_W - 12, CARD.Pic)
	art(pic, "Cosmetic", id, CARD.Art)
	local rarity = pill(card, string.upper(RARITY_NAMES[cosmetic.Rarity] or ""), color, false, 9 + UP)
	rarity.Position = UDim2.fromOffset(12, 12)
	-- (a phone: no room beside the rarity, and the price line says so)
	if (isWorn or mine) and not SHORT then
		local tag = pill(card, if isWorn then "WEARING" else "OWNED", if isWorn then C.Gold else C.Good, true, 9 + UP)
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -12, 0, 12)
	end
	local name = text(card, cosmetic.Name, 14 + UP, C.Text, BOLD, 12, CARD.Name, CARD_W - 24, 18)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	text(card, KIND_NAMES[cosmetic.Kind] or "", 11 + UP, C.Dim, MEDIUM, 12, CARD.Kind, CARD_W - 24, 14)
	if cosmetic.Robux and not mine then
		text(card, robux(cosmetic.Robux), 17 + UP, C.Text, BLACK, 12, CARD.Price, CARD_W - 24, 26)
	elseif mine then
		text(
			card,
			if isWorn then "✓  Wearing" elseif SHORT then "✓  Owned" else "✓  In your collection",
			12 + UP,
			C.Good,
			BOLD,
			12,
			CARD.Price,
			CARD_W - 24,
			26
		)
	else
		local how =
			wrap(text(card, "Earn  ·  " .. Cosmetics.source(cosmetic), 11 + UP, C.Gold, BOLD, 12, CARD.Price, CARD_W - 24, 30))
		how.TextTruncate = Enum.TextTruncate.AtEnd
	end
	card:SetAttribute("UiSound", "Click")
	card.Activated:Connect(function()
		state.Selected[tab] = id
		refresh()
	end)
end

-- A segmented control: options side by side, one on.
local function segmented(parent: Instance, order: number, options: { { string } }, on: string, pick)
	local frame = box(parent, C.Surface, 0, 0, 0, 30)
	frame.LayoutOrder = order
	frame.AutomaticSize = Enum.AutomaticSize.X
	round(frame, 9)
	new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, frame)
	UiKit.list(frame, 2, true).VerticalAlignment = Enum.VerticalAlignment.Center
	for i, option in options do
		local active = option[1] == on
		local b = new("TextButton", {
			Name = option[1],
			Text = option[2],
			AutoButtonColor = false,
			Font = BOLD,
			TextSize = 12 + UP,
			TextColor3 = if active then C.Ink else C.Dim,
			BackgroundColor3 = C.Text,
			BackgroundTransparency = if active then 0 else 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			LayoutOrder = i,
		}, frame)
		round(b, 7)
		new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, b)
		b:SetAttribute("UiSound", "Tab")
		b.Activated:Connect(function()
			pick(option[1])
		end)
	end
	return frame
end

-- The picked look's page, beside the grid.
local function productPage(id: string, x: number)
	local cosmetic = Cosmetics.List[id]
	local color = Cosmetics.rarityColor(cosmetic) or C.Dim
	local w = PAGE_W - x
	local side = box(page, C.Surface, x, 0, w, PAGE_H)
	side.Name = "ProductPage"
	round(side, 14)
	local inner = w - 36
	-- Where each part sits, top to bottom. (A phone: from the bottom up, the
	-- note, buy, the price, the words and the name, and the picture takes
	-- whatever the page's height leaves above them.)
	local buyAt = PAGE_H - 22 - 8 - 44
	local Y = if SHORT
		then {
			Pic = buyAt - 36 - 48 - 26 - 22,
			Art = math.min(buyAt - 36 - 48 - 26 - 42, 150),
			Name = buyAt - 36 - 48 - 26,
			NameSize = 20,
			Desc = buyAt - 36 - 48,
			DescH = 44,
			Price = buyAt - 36,
			PriceSize = 24,
			Buy = buyAt,
			BuyH = 44,
			Note = PAGE_H - 22,
			How = buyAt - 10,
			Free = buyAt + 28,
			Offer = nil,
			OfferH = 54,
		}
		else {
			Pic = 216,
			Art = 184,
			Name = 242,
			Desc = 274,
			DescH = 44,
			Price = 322,
			Buy = 364,
			BuyH = 46,
			NameSize = 24,
			PriceSize = 28,
			Note = 416,
			How = 356,
			Free = 400,
			Offer = PAGE_H - 108,
			OfferH = 64,
		}
	local pic = well(side, color, 14, 14, w - 28, Y.Pic)
	local hero = art(pic, "Cosmetic", id, Y.Art)
	IronUi.animate(hero, function(t)
		hero.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 1.6) * 4)
	end)
	pill(pic, string.upper(RARITY_NAMES[cosmetic.Rarity] or ""), color, true, 10 + UP).Position = UDim2.fromOffset(12, 12)
	local kindTag = pill(pic, string.upper(KIND_NAMES[cosmetic.Kind] or ""), C.Text, false, 10 + UP)
	kindTag.AnchorPoint = Vector2.new(1, 0)
	kindTag.Position = UDim2.new(1, -12, 0, 12)
	text(side, cosmetic.Name, Y.NameSize, C.Text, BLACK, 18, Y.Name, inner, 30).Name = "ProductName"
	-- (Not a size up on a phone: the longest are two lines there as it is.)
	wrap(text(side, cosmetic.Description or "", 12, C.Dim, MEDIUM, 18, Y.Desc, inner, Y.DescH)).TextTruncate =
		Enum.TextTruncate.AtEnd
	local mine, isWorn = owned(id), worn(cosmetic.Kind) == id
	if cosmetic.Robux and not mine then
		text(side, robux(cosmetic.Robux), Y.PriceSize, C.Text, BLACK, 18, Y.Price, inner, 34).Name = "Price"
		if not SHORT then
			local yours =
				text(side, "One-time purchase  ·  yours to keep", 11, C.Faint, MEDIUM, 18, Y.Price, inner, 34)
			yours.TextXAlignment = Enum.TextXAlignment.Right
		end
		buyButton(side, id, 18, Y.Buy, inner, Y.BuyH)
		if not live(id) and Store.testPrice(id) then
			text(
				side,
				string.format("TESTING: buys for %d coins until Robux is switched on", Store.testPrice(id) :: number),
				10,
				C.Faint,
				BOLD,
				18,
				Y.Note,
				inner,
				16
			).Name =
				"TestNote"
		end
	elseif mine then
		text(
			side,
			if isWorn then "✓  You're wearing this" else "✓  In your collection",
			15,
			C.Good,
			BOLD,
			18,
			Y.Price + 2,
			inner,
			30
		)
		if isWorn then
			button(side, "Take it off", "Secondary", 18, Y.Buy, inner, Y.BuyH, function()
				equip(cosmetic.Kind, nil)
			end)
		else
			button(side, "Wear it", "Primary", 18, Y.Buy, inner, Y.BuyH, function()
				equip(cosmetic.Kind, id)
			end).Name =
				"Wear"
		end
	else
		text(side, "Not sold", 15, C.Gold, BOLD, 18, Y.Price + 2, inner, 30)
		wrap(
			text(
				side,
				(if cosmetic.Exclusive == "Code" and discordOk then HOW_TO.CodeDiscord else nil)
					or HOW_TO[cosmetic.Exclusive or ""]
					or cosmetic.How
					or "Earned in game.",
				13,
				C.Dim,
				MEDIUM,
				18,
				Y.How,
				inner,
				if SHORT then 34 else 40
			)
		)
		if cosmetic.Exclusive == "Invite" or cosmetic.Exclusive == "Group" or cosmetic.Exclusive == "Streak" then
			button(side, "See Free rewards", "Secondary", 18, Y.Free, inner, if SHORT then 34 else 40, function()
				state.Tab = "Free"
				refresh()
			end).Name =
				"SeeFree"
		end
	end
	-- The bundle that saves on it.
	-- (no room for it on a phone's product page: the Bundles page has them)
	local deals = if cosmetic.Robux and not mine and Y.Offer then Store.bundlesWith(id) else {}
	if #deals > 0 then
		local key = deals[1]
		local offer = box(side, C.Sale, 18, Y.Offer, inner, Y.OfferH, 0.88)
		offer.Name = "BundleDeal"
		round(offer, 10)
		stroke(offer, C.Sale, 1, 0.55)
		text(offer, string.format("SAVE %d%% IN A BUNDLE", Store.savings(key)), 10, C.Sale, BOLD, 12, 9, inner - 90, 14)
		local about = text(
			offer,
			string.format(
				"%s  ·  %s for %s",
				Store.productName(key),
				counts(Store.contents(key) or {}),
				robux(Store.robuxPrice(key) or 0)
			),
			11,
			C.Text,
			MEDIUM,
			12,
			26,
			inner - 96,
			30
		)
		wrap(about)
		button(offer, "View", "Secondary", inner - 76, (Y.OfferH - 32) / 2, 64, 32, function()
			if Store.kitsOf(key) then
				state.Tab = "Featured"
				refresh()
			end
			showBundle(key)
		end).Name =
			"ViewBundle"
	end
	-- (a phone: only where the testing note and the Free button aren't)
	if SHORT and (side:FindFirstChild("TestNote") or side:FindFirstChild("SeeFree")) then
		return
	end
	text(
		side,
		if MinerRoster.Enabled
			then "✓ Looks only, never stats     ✓ Any of your miners can wear it"
			else "✓ Looks only, never stats",
		10 + UP,
		C.Faint,
		BOLD,
		18,
		PAGE_H - (if SHORT then 20 else 30),
		inner,
		16
	)
end

local function drawCatalog(tab: string)
	local kind = Store.TabKinds[tab]
	local sold, earned = catalog(kind)
	local all = Cosmetics.ofKind(kind)
	local have = 0
	for _, id in all do
		if owned(id) then
			have += 1
		end
	end
	if not state.Selected[tab] or not Cosmetics.get(state.Selected[tab]) then
		state.Selected[tab] = sold[1] or earned[1] or all[1]
	end
	if SHORT then
		local grid = MobileLayout.storeGrid(PAGE_W)
		COLS, CARD_W, GRID_W, PRODUCT_X = grid.Cols, grid.CardW, grid.GridW, grid.ProductX
	end
	-- (a phone: the tab is the title, and the sorting sits on top of the grid)
	local top = if SHORT then 38 else 54
	if not SHORT then
		text(page, Store.TabNames[tab], 22, C.Text, BLACK, 0, 0, 300, 28).Name = "PageTitle"
		text(page, string.format("%d looks  ·  you own %d", #all, have), 12, C.Dim, MEDIUM, 0, 28, 300, 16)
	end
	-- (a phone: from the grid's left edge, short of the product page)
	local controls = new("Frame", {
		Name = "Controls",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(if SHORT then 0 else GRID_W - 480, if SHORT then 0 else 6),
		Size = UDim2.fromOffset(if SHORT then PRODUCT_X - 12 else 480, 30),
	}, page)
	UiKit.list(controls, if SHORT then 8 else 10, true).HorizontalAlignment = if SHORT
		then Enum.HorizontalAlignment.Left
		else Enum.HorizontalAlignment.Right
	segmented(
		controls,
		1,
		{ { "Featured", "Featured" }, { "Low", "Price: low" }, { "High", "Price: high" } },
		state.Sort,
		function(v)
			state.Sort = v
			refresh()
		end
	)
	segmented(controls, 2, { { "All", "All" }, { "NotOwned", "Not owned" } }, state.Filter, function(v)
		state.Filter = v
		refresh()
	end)
	local list = new("ScrollingFrame", {
		Name = "Products",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.fromOffset(GRID_W + 10, PAGE_H - top),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Faint,
	}, page)
	UiKit.list(list, 12)
	local function section(title: string, ids: { string }, order: number)
		if #ids == 0 then
			return
		end
		local head = text(list, title, 11 + UP, C.Dim, BOLD, 0, 0, GRID_W, 16)
		head.LayoutOrder = order
		local rows = math.ceil(#ids / COLS)
		local grid = new("Frame", {
			Name = "Grid",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(GRID_W, rows * CARD_H + (rows - 1) * GAP + 2),
			LayoutOrder = order + 1,
		}, list)
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(CARD_W, CARD_H),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		for i, id in ids do
			productCard(grid, id, i, tab)
		end
	end
	section(string.format("IN THE STORE  ·  %d", #sold), sold, 1)
	section(string.format("EARNED IN GAME  ·  %d", #earned), earned, 3)
	if #sold + #earned == 0 then
		local empty = text(list, "You own every look here. Nice.", 14, C.Dim, MEDIUM, 0, 0, GRID_W, 40)
		empty.LayoutOrder = 1
	end
	productPage(state.Selected[tab], PRODUCT_X)
end

-- Bundles page --------------------------------------------------------------------------------------------------

local function sectionHead(parent: Instance, order: number, title: string, blurb: string)
	local head = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(PAGE_W - 12, 44),
		LayoutOrder = order,
	}, parent)
	text(head, title, 18, C.Text, BLACK, 0, 0, PAGE_W, 24)
	text(head, blurb, 12, C.Dim, MEDIUM, 0, 24, PAGE_W, 18)
	return head
end

-- The new-player offer, while it's open: the Starter Pack, or else the
-- Welcome Kit.
local function offerKey(): string?
	if starterLeft() > 0 then
		return "StarterPack"
	elseif welcomeLeft() > 0 then
		return "Welcome"
	end
	return nil
end

local function offerBanner(parent: Instance, key: string, w: number, order: number?): Frame
	local offer = Store.bundle(key) or Store.StarterPack
	local reward = Store.contents(key) or {}
	local banner = box(parent, Color3.new(1, 1, 1), 0, 0, w, 196)
	banner.Name = "Offer"
	banner.LayoutOrder = order or 0
	round(banner, 14)
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new(C.Surface:Lerp(offer.Color, 0.28), C.Surface),
	}, banner)
	stroke(banner, offer.Color, 1, 0.55)
	-- (a phone: a narrower picture and price box, the words between)
	local picW, boxW = if SHORT then 196 else 290, if SHORT then 214 else 240
	local x = picW + 32
	local tw = w - x - boxW - 28
	local pic = well(banner, offer.Color, 10, 10, picW, 176)
	art(pic, "Cosmetic", offer.Hero, if SHORT then 120 else 150, 0.4, 0.5)
	thumbs(pic, reward.Cosmetics or {}, offer.Hero, if SHORT then 40 else 48, 3)
	local left = if key == "StarterPack" then starterLeft else welcomeLeft
	local kicker = wrap(text(banner, "", 11, C.Gold, BOLD, x, 22, if SHORT then tw else 420, if SHORT then 28 else 14))
	kicker.Name = "OfferClock"
	timer(
		kicker,
		left,
		if key == "StarterPack" then "ONE-TIME OFFER  ·  ENDS IN " else "NEW MINERS ONLY  ·  ENDS IN "
	)
	local nameY = if SHORT then 52 else 40
	text(banner, offer.Name, if SHORT then 22 else 30, C.Text, BLACK, x, nameY, if SHORT then tw else 420, if SHORT then 28 else 36)
	wrap(text(banner, offer.Tagline, if SHORT then 12 else 13, C.Dim, MEDIUM, x, nameY + (if SHORT then 30 else 40), tw, 40))
	text(banner, counts(reward), 12, C.Text, BOLD, x, 132, if SHORT then tw else 420, 16).TextTruncate =
		Enum.TextTruncate.AtEnd
	button(banner, "See everything inside", "Quiet", x - 6, 152, 170, 28, function()
		showBundle(key)
	end).TextXAlignment =
		Enum.TextXAlignment.Left
	-- The price box.
	local priceBox = box(banner, C.Window, w - boxW - 14, 14, boxW, 168, 0.15)
	round(priceBox, 12)
	text(priceBox, "BUNDLE PRICE", 10, C.Dim, BOLD, 16, 14, 200, 14)
	-- (the saving up beside the caption: price, old price and badge in one
	-- row are wider than the box)
	priceRow(priceBox, key, 16, 34, if SHORT then 26 else 30, false)
	local separate = Store.separatePrice(reward)
	if separate > (Store.robuxPrice(key) or 0) then
		local save = pill(priceBox, "-" .. Store.savings(key) .. "%", C.Sale, true, 12)
		save.AnchorPoint = Vector2.new(1, 0)
		save.Position = UDim2.new(1, -14, 0, 10)
	end
	text(
		priceBox,
		if separate > 0 then "Worth " .. robux(separate) .. " bought one by one" else "",
		11,
		C.Faint,
		MEDIUM,
		16,
		76,
		boxW - 30,
		14
	)
	buyButton(priceBox, key, 16, 106, boxW - 32, 46)
	return banner
end

local function lookCard(parent: Instance, bundle: Store.Bundle, order: number, w: number)
	local reward = bundle.Contents
	local have, total = Store.ownedCount(reward, profile().Cosmetics and profile().Cosmetics.Owned)
	local card = new("TextButton", {
		Name = bundle.Id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Surface,
		Size = UDim2.fromOffset(w, 318),
		LayoutOrder = order,
	}, parent)
	round(card, 14)
	local edge = stroke(card, C.Line, 1, 0.9)
	hoverEdge(card, edge, C.Line, 0.9)
	local pic = well(card, bundle.Color, 6, 6, w - 12, 132)
	art(pic, "Cosmetic", bundle.Hero, 104, 0.4, 0.52)
	thumbs(pic, reward.Cosmetics or {}, bundle.Hero, 36, 3)
	local save = Store.savings(bundle.Id)
	if save > 0 then
		pill(pic, "-" .. save .. "%", C.Sale, true, 10).Position = UDim2.fromOffset(8, 8)
	end
	text(card, bundle.Name, 15, C.Text, BLACK, 12, 146, w - 24, 20).TextTruncate = Enum.TextTruncate.AtEnd
	text(card, counts(reward), 11, C.Dim, MEDIUM, 12, 168, w - 24, 14).TextTruncate = Enum.TextTruncate.AtEnd
	wrap(text(card, bundle.Tagline, 11, C.Faint, MEDIUM, 12, 186, w - 24, 42)).TextTruncate = Enum.TextTruncate.AtEnd
	priceRow(card, bundle.Id, 12, 232, 17, false)
	if have > 0 and have < total then
		text(card, string.format("You own %d of %d", have, total), 10, C.Gold, BOLD, 12, 252, w - 24, 12)
	end
	buyButton(card, bundle.Id, 12, 266, w - 24, 40)
	card:SetAttribute("UiSound", "Click")
	card.Activated:Connect(function()
		showBundle(bundle.Id)
	end)
end

local function premiumCard(parent: Instance, bundle: Store.Bundle, order: number, w: number)
	local reward = bundle.Contents
	local card = new("TextButton", {
		Name = bundle.Id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(w, 232),
		LayoutOrder = order,
	}, parent)
	round(card, 14)
	new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new(C.Surface:Lerp(bundle.Color, 0.16), C.Surface),
	}, card)
	local edge = stroke(card, bundle.Color, 1, 0.6)
	hoverEdge(card, edge, bundle.Color, 0.6)
	local pic = well(card, bundle.Color, 8, 8, 216, 216)
	art(pic, "Cosmetic", bundle.Hero, 150, 0.42, 0.5)
	thumbs(pic, reward.Cosmetics or {}, bundle.Hero, 44, 4)
	local x = 242
	local tw = w - x - 18
	if bundle.Once then
		pill(card, "ONE PER ACCOUNT", C.Gold, false, 9).Position = UDim2.fromOffset(x, 16)
	else
		pill(card, "BEST FOR COLLECTORS", bundle.Color, false, 9).Position = UDim2.fromOffset(x, 16)
	end
	text(card, bundle.Name, 22, C.Text, BLACK, x, 40, tw, 28)
	wrap(text(card, bundle.Tagline, 12, C.Dim, MEDIUM, x, 72, tw, 46))
	text(card, counts(reward), 11, C.Gold, BOLD, x, 124, tw, 16).TextTruncate = Enum.TextTruncate.AtEnd
	priceRow(card, bundle.Id, x, 146, 22)
	buyButton(card, bundle.Id, x, 180, tw - 102, 40)
	button(card, "Details", "Secondary", x + tw - 94, 180, 94, 40, function()
		showBundle(bundle.Id)
	end)
	card:SetAttribute("UiSound", "Click")
	card.Activated:Connect(function()
		showBundle(bundle.Id)
	end)
end

-- Kaiju ----------------------------------------------------------------------------------------------------------
-- The kaiju sales (Shared.Kaiju.Sale), here as well as at the Kennel
-- (Client KennelSale): the Starter Rare Roll, once ever, then the premium
-- Triskull Trinity, once ever, then today's Kaiju of the Day, turning in its
-- view. The Kaiju page shows them big, with what each brings; Featured
-- leads with the first two, smaller. (A kaiju bought joins your reserves,
-- or its roll plays on the roll screen: showReceipt closes the store for
-- it. The team revive is sold from the kaiju panel, when one's down.)
local KaijuDeals = {}
do
	local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
	local Kennel = require(ReplicatedStorage.Shared.KaijuKennel)
	local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
	local GemConfig = require(ReplicatedStorage.Shared.GemConfig)

	-- Kaiju turning in their views: { Model, Center, Rest } (cleared with
	-- the page).
	local turning = {}
	KaijuDeals.Turning = turning
	RunService.RenderStepped:Connect(function()
		if #turning == 0 or not gui.Enabled then
			return
		end
		local angle = (os.clock() * 0.5) % (math.pi * 2)
		for _, spin in turning do
			spin.Model:PivotTo(spin.Center * CFrame.Angles(0, angle, 0) * spin.Center:Inverse() * spin.Rest)
		end
	end)

	-- A kaiju in a view filling `parent`, turning if `turn`.
	local function view(parent: Instance, species: string, element: string, turn: boolean?): ViewportFrame
		local model = KaijuModels.forPortrait(KaijuModels.build(species, element))
		local cf, size = model:GetBoundingBox()
		local reach = math.max(size.X, size.Y * 1.2, size.Z)
		local frame = new("ViewportFrame", {
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
		camera.Parent = frame
		frame.CurrentCamera = camera
		model.Parent = frame
		if turn then
			table.insert(turning, { Model = model, Center = CFrame.new(cf.Position), Rest = model:GetPivot() })
		end
		return frame
	end

	-- Seconds to the next Kaiju of the Day (midnight UTC: KaijuKennel.day).
	local function untilNext(): number
		return math.max(0, (Kennel.day(now()) + 1) * Kennel.DaySeconds - now())
	end

	-- A sale's card, `w` by `h`: its picture in a well on the left (`fill`
	-- draws it), a tag, its name and lines on the right, the price and the
	-- buy button at the foot. `opts`: { Name, Key, Tint, Tag, TagColor,
	-- Title, Sub, About?, Clock? (a label to tick), Fill, Short = { Tag,
	-- Title, Sub } (the words for a narrow card) }.
	local function saleCard(parent: Instance, w: number, h: number, order: number, opts): Frame
		local small = h < 240
		local card = box(parent, Color3.new(1, 1, 1), 0, 0, w, h)
		card.Name = opts.Name
		card.LayoutOrder = order
		round(card, 14)
		new("UIGradient", {
			Rotation = 0,
			Color = ColorSequence.new(C.Surface:Lerp(opts.Tint, 0.2), C.Surface),
		}, card)
		stroke(card, opts.Tint, 1, 0.62)
		local side = math.min(h - 16, math.floor(w * 0.42))
		local pic = well(card, opts.Tint, 8, 8, side, h - 16)
		opts.Fill(pic)
		local x = side + 24
		local tw = w - x - 16
		local words = if tw < 200 and opts.Short then opts.Short else opts
		pill(card, words.Tag, opts.TagColor, false, 9).Position = UDim2.fromOffset(x, 14)
		local nameSize = if small then 20 else 26
		-- (a long name shrinks to fit rather than run off)
		local name = text(card, words.Title, nameSize, C.Text, BLACK, x, 40, tw, nameSize + 6)
		name.TextScaled = true
		new("UITextSizeConstraint", { MaxTextSize = nameSize, MinTextSize = 12 }, name)
		local y = 40 + nameSize + 8
		local sub = text(card, words.Sub, 12 + UP, C.Dim, BOLD, x, y, tw, 16)
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		y += 22
		if opts.About and not small then
			wrap(text(card, opts.About, 12 + UP, C.Faint, MEDIUM, x, y, tw, 50))
			y += 56
		end
		if opts.Clock then
			local tick = text(card, "", 10 + UP, C.Gold, BOLD, x, y, tw, 14)
			tick.Name = "Clock"
			timer(tick, opts.Clock, "NEW KAIJU IN ")
		end
		local bh = if small then 38 else 44
		local priceSize = if small then 20 else 24
		priceRow(card, opts.Key, x, h - 12 - bh - 8 - (priceSize + 6), priceSize, false)
		buyButton(card, opts.Key, x, h - 12 - bh, tw, bh)
		return card
	end

	-- Today's Kaiju of the Day.
	function KaijuDeals.daily(parent: Instance, w: number, h: number, order: number): Frame
		local sale = Kaiju.Sale.Daily
		local special = Kennel.special(Kennel.day(now()))
		local kind = Kaiju.species(special.Species)
		return saleCard(parent, w, h, order, {
			Name = "KaijuDaily",
			Key = sale.Product,
			Tint = GemConfig.ElementColors[special.Element] or C.Gold,
			Tag = "DAILY KAIJU SALE",
			TagColor = C.Gold,
			Title = kind and kind.Name or special.Species,
			Sub = string.format("%s  ·  %s  ·  Traits %d+", GemConfig.elementName(special.Element), kind and kind.Role or "Kaiju", sale.TraitFloor),
			About = string.format(
				"One of the rarest kinds, on sale today only, one per miner. Its traits are never poor: %d or better in all four.",
				sale.TraitFloor
			),
			Clock = untilNext,
			Fill = function(pic)
				view(pic, special.Species, special.Element, true)
			end,
			Short = {
				Tag = "DAILY SALE",
				Title = kind and kind.Name or special.Species,
				Sub = GemConfig.elementName(special.Element) .. "  ·  " .. (kind and kind.Role or "Kaiju"),
			},
		})
	end

	-- The Starter Rare Roll: four of the rare kinds in its well (its
	-- showcase, Kaiju.Sale.Showcase).
	function KaijuDeals.rare(parent: Instance, w: number, h: number, order: number): Frame
		local sale = Kaiju.Sale.Rare
		local kinds = Kaiju.rareKinds()
		return saleCard(parent, w, h, order, {
			Name = "KaijuRareRoll",
			Key = sale.Product,
			Tint = Color3.fromRGB(176, 120, 255),
			Tag = "STARTER RARE ROLL  ·  ONCE ONLY",
			TagColor = Color3.fromRGB(196, 160, 255),
			Title = "Starter Rare Roll",
			Sub = string.format("%d kinds  ·  any element  ·  Traits %d+", #kinds, sale.TraitFloor),
			About = string.format(
				"One roll on the starter roll's reels, every rare kind as likely as the next (1 in %d). It comes with a Rare Gemsoul holding its element's best surge.",
				#kinds
			),
			Fill = function(pic)
				local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, pic)
				new("UIGridLayout", {
					CellSize = UDim2.fromScale(0.5, 0.5),
					CellPadding = UDim2.fromOffset(0, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, grid)
				for i, shown in Kaiju.Sale.Showcase do
					local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i }, grid)
					view(cell, shown.Species, shown.Element)
				end
			end,
			Short = { Tag = "ONCE ONLY", Title = "Starter Rare Roll", Sub = string.format("%d rarest kinds", #kinds) },
		})
	end

	-- The premium trio: its three kaiju side by side in its well, one in
	-- each element, turning.
	function KaijuDeals.premium(parent: Instance, w: number, h: number, order: number): Frame
		local sale = Kaiju.Sale.Premium
		local kind = Kaiju.species(sale.Species)
		local names = {}
		for _, element in sale.Elements do
			table.insert(names, GemConfig.elementName(element))
		end
		local gold = Color3.fromRGB(255, 196, 80)
		return saleCard(parent, w, h, order, {
			Name = "KaijuPremium",
			Key = sale.Product,
			Tint = gold,
			Tag = "PREMIUM  ·  ONCE ONLY",
			TagColor = gold,
			Title = sale.Name,
			Sub = string.format("3 %ss  ·  %s  ·  Traits %d+", kind and kind.Name or sale.Species, table.concat(names, ", "), sale.TraitFloor),
			About = string.format(
				"Three %ss, one in each element. Each comes with an Ultra Rare Gemsoul holding its element's best moves: Q, E and R.",
				kind and kind.Name or sale.Species
			),
			Fill = function(pic)
				local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, pic)
				new("UIGridLayout", {
					CellSize = UDim2.fromScale(1 / #sale.Elements, 1),
					CellPadding = UDim2.fromOffset(0, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, row)
				for i, element in sale.Elements do
					local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i }, row)
					view(cell, sale.Species, element, true)
				end
			end,
			Short = { Tag = "PREMIUM", Title = sale.Name, Sub = "3 kaiju  ·  Ultra Rare Gemsouls" },
		})
	end

	-- The Kaiju page.
	function KaijuDeals.draw()
		local list = new("ScrollingFrame", {
			Name = "Kaiju",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(PAGE_W + 8, PAGE_H),
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = C.Faint,
		}, page)
		UiKit.list(list, 14)
		new("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 12),
		}, list)
		local w = PAGE_W - 12
		sectionHead(list, 1, "Kaiju", "The rarest kinds. Kaiju bought here join your reserves.")
		-- (side by side on a computer, one under the other on a phone: the
		-- starter roll first, then the premium trio)
		local cardH = if SHORT then 210 else 312
		local cw = if SHORT then w else math.floor((w - 14) / 2)
		local row = new("Frame", {
			Name = "Sales",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(w, if SHORT then cardH * 2 + 14 else cardH),
			LayoutOrder = 2,
		}, list)
		UiKit.list(row, 14, not SHORT)
		KaijuDeals.rare(row, cw, cardH, 1)
		KaijuDeals.premium(row, cw, cardH, 2)
		sectionHead(list, 3, "Kaiju of the Day", "One of the rarest kinds, a new one every midnight (UTC).")
		local daily = KaijuDeals.daily(list, w, if SHORT then 210 else 240, 4)
		daily.LayoutOrder = 4
		local note = wrap(
			text(
				list,
				"Also on sale from Wren at the Kennel, in the Shelter's hall. A new Kaiju of the Day comes at midnight (UTC). Swap kaiju into a team from YOUR KAIJU.",
				11 + UP,
				C.Faint,
				MEDIUM,
				0,
				0,
				w,
				32
			)
		)
		note.LayoutOrder = 5
	end

	-- Featured's row of the two sales, smaller, with a way to the Kaiju page.
	function KaijuDeals.strip(list: Instance, order: number)
		local w = PAGE_W - 12
		local head = sectionHead(list, order, "Kaiju deals", "The Starter Rare Roll and the Triskull Trinity.")
		local all = button(head, "See all kaiju  ›", "Quiet", w - 140, 6, 140, 28, function()
			state.Tab = "Kaiju"
			refresh()
		end)
		all.TextXAlignment = Enum.TextXAlignment.Right
		local cardH = if SHORT then 196 else 200
		local cw = math.floor((w - 14) / 2)
		local row = new("Frame", {
			Name = "KaijuDeals",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(w, cardH),
			LayoutOrder = order + 1,
		}, list)
		UiKit.list(row, 14, true)
		KaijuDeals.rare(row, cw, cardH, 1)
		KaijuDeals.premium(row, cw, cardH, 2)
	end
end

local function drawBundles()
	local list = new("ScrollingFrame", {
		Name = "Bundles",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(PAGE_W + 8, PAGE_H),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Faint,
	}, page)
	UiKit.list(list, 14)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 12),
	}, list)
	local key = offerKey()
	if key then
		offerBanner(list, key, PAGE_W - 12, 1)
	end
	KaijuDeals.strip(list, 10)
	local looks, premium = {}, {}
	for _, bundle in Store.Bundles do
		if bundle.Section == "Look" then
			table.insert(looks, bundle)
		elseif bundle.Section == "Premium" then
			table.insert(premium, bundle)
		end
	end
	sectionHead(list, 20, "Player bundles", "A whole look for your miner: suit, weapon skin, helmet, visor and pickaxe.")
	-- (three to a row; then the premium sets, one to a row on a phone)
	local perRow = math.min(3, #looks)
	local rows = math.ceil(#looks / math.max(1, perRow))
	local cw = math.floor((PAGE_W - 12 - (perRow - 1) * 12) / math.max(1, perRow))
	local row = new("Frame", {
		Name = "Looks",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(PAGE_W - 12, rows * 318 + (rows - 1) * 12),
		LayoutOrder = 21,
	}, list)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cw, 318),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	for i, bundle in looks do
		lookCard(row, bundle, i, cw)
	end
	sectionHead(list, 30, "Premium", "The biggest sets in the store, at the biggest savings.")
	local pw = if SHORT then PAGE_W - 12 else math.floor((PAGE_W - 12 - 14) / 2)
	local prows = if SHORT then #premium else 1
	local prow = new("Frame", {
		Name = "Premium",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(PAGE_W - 12, prows * 232 + (prows - 1) * 14),
		LayoutOrder = 31,
	}, list)
	UiKit.list(prow, 14, not SHORT)
	for i, bundle in premium do
		premiumCard(prow, bundle, i, pw)
	end
end

-- Free ---------------------------------------------------------------------------------------------------------------
-- Free looks for growing the crew: the group, friends, a login streak and
-- promo codes. The server's state (FreeRewards) is fetched on opening.

local freeState = nil
local freeFetching = false
local function fetchFree()
	if freeFetching then
		return
	end
	freeFetching = true
	task.spawn(function()
		local result = GemClient.request("FreeRewards")
		freeFetching = false
		if result.Ok then
			freeState = result
			if gui.Enabled and state.Tab == "Free" then
				refresh()
			end
		end
	end)
end

local function freeAction(action: string, ...)
	if state.Busy then
		return
	end
	state.Busy = true
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		state.Busy = false
		UiKit.toast(result.Message or "", if result.Ok then C.Good else C.Sale)
		freeState = nil
		refresh()
	end)
end

local freeHost: GuiObject? = nil -- (the page, or on a short screen a scroller in it)
local function freeCard(
	x: number,
	y: number,
	w: number,
	h: number,
	tint: Color3,
	title: string,
	blurb: string,
	wide: boolean?
): Frame
	local card = box(freeHost or page, C.Surface, x, y, w, h)
	round(card, 14)
	local rail = box(card, tint, 18, 0, w - 36, 3)
	round(rail, 2)
	text(card, title, 18, C.Text, BLACK, 20, 18, w - 160, 24)
	-- (`wide`: nothing beside it, the reward tiles are under it)
	wrap(text(card, blurb, 12, C.Dim, MEDIUM, 20, 44, if wide then w - 40 else w - 170, 34))
	return card
end

local function rewardTile(card: Frame, id: string, have: boolean, x: number, y: number, size: number)
	local cosmetic = Cosmetics.get(id)
	local tile = well(card, cosmetic and Cosmetics.rarityColor(cosmetic) or C.Dim, x, y, size, size)
	art(tile, "Cosmetic", id, size - 14)
	if have then
		local tag = pill(tile, "OWNED", C.Good, true, 9)
		tag.AnchorPoint = Vector2.new(0.5, 1)
		tag.Position = UDim2.new(0.5, 0, 1, -4)
	end
	return tile
end

local function drawFree()
	text(page, "Free", 22, C.Text, BLACK, 0, 0, 300, 28).Name = "PageTitle"
	text(page, "Looks you can't buy: earn them by growing the crew.", 12, C.Dim, MEDIUM, 0, 28, 500, 16)
	if not freeState then
		text(page, "Checking your free rewards…", 14, C.Dim, MEDIUM, 0, 70, PAGE_W, 30)
		fetchFree()
		return
	end
	local info = freeState
	local top = 56
	local half = math.floor((PAGE_W - 14) / 2)
	-- The four cards keep their full size; a short screen scrolls them.
	local cardH = math.floor((560 - top - 14) / 2)
	freeHost = page
	if SHORT then
		freeHost = new("ScrollingFrame", {
			Name = "FreeScroll",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.fromOffset(PAGE_W + 8, PAGE_H - top),
			CanvasSize = UDim2.fromOffset(0, 2 * cardH + 14),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = C.Faint,
		}, page)
		top = 0
	end

	-- 1. The group.
	local group = info.Group or {}
	local skin = Cosmetics.get(group.Reward or FreeRewards.Group.Reward)
	local gCard =
		freeCard(0, top, half, cardH, C.Good, "Join the group", "Join the game's Roblox group for a free weapon skin.")
	rewardTile(gCard, skin and skin.Id or "SkinStarforged", group.Owned == true, half - 130, 18, 112)
	text(gCard, (skin and skin.Name or "") .. "  ·  Weapon skin", 12, C.Gold, BOLD, 20, 86, half - 170, 16)
	if group.Owned then
		pill(gCard, "YOURS: THANKS FOR JOINING!", C.Good, true, 11).Position = UDim2.fromOffset(20, cardH - 46)
	elseif not group.Enabled then
		pill(gCard, "COMING SOON", C.Dim, false, 11).Position = UDim2.fromOffset(20, cardH - 46)
	else
		button(gCard, "Join group", "Primary", 20, cardH - 58, 150, 42, function()
			pcall(function()
				GroupService:PromptJoinAsync(group.Id)
			end)
		end)
		button(gCard, "I've joined", "Secondary", 180, cardH - 58, 130, 42, function()
			freeAction("CheckGroup")
		end)
	end

	-- 2. Friends.
	local invites = info.Invites or { Count = 0, Tiers = {} }
	local iCard = freeCard(
		half + 14,
		top,
		half,
		cardH,
		C.Gold,
		"Bring friends",
		"Each friend who joins through your invite counts. The rewards stack up.",
		true
	)
	local tiers = invites.Tiers or {}
	local tileW = math.min(70, math.floor((half - 40 - math.max(0, #tiers - 1) * 10) / math.max(1, #tiers)))
	for i, tier in tiers do
		local x = 20 + (i - 1) * (tileW + 10)
		rewardTile(iCard, tier.Reward, tier.Owned, x, 80, tileW)
		local need = text(
			iCard,
			string.format("%d FRIEND%s", tier.Friends, if tier.Friends == 1 then "" else "S"),
			9,
			if tier.Owned then C.Good else C.Dim,
			BOLD,
			x - 4,
			83 + tileW,
			tileW + 8,
			12
		)
		need.TextXAlignment = Enum.TextXAlignment.Center
	end
	local nextTier = Referrals.nextTier(invites.Count or 0)
	text(
		iCard,
		if nextTier
			then string.format("%d of %d friends joined", invites.Count or 0, nextTier.Friends)
			else string.format("%d friends joined: every reward is yours!", invites.Count or 0),
		12,
		C.Gold,
		BOLD,
		20,
		cardH - 76,
		half - 40,
		16
	)
	button(iCard, "Invite friends", "Primary", 20, cardH - 54, 160, 40, function()
		-- (The same invite as the Bring a Friend window: it checks first.)
		require(script.Parent.ReferralUI).invite()
	end)
	button(iCard, "Check", "Secondary", 190, cardH - 54, 100, 40, function()
		freeAction("ReferralState")
	end)

	-- 3. The login streak.
	local streak = info.Streak or { Days = 7, Streak = 0 }
	local sCard = freeCard(
		0,
		top + cardH + 14,
		half,
		cardH,
		Color3.fromRGB(90, 170, 255),
		"Login streak",
		string.format("Log in %d days in a row for a free weapon skin.", streak.Days or 7)
	)
	rewardTile(sCard, streak.Reward or FreeRewards.Streak.Reward, streak.Owned == true, half - 130, 18, 112)
	local days = streak.Days or 7
	local pipW = math.floor((half - 170 - (days - 1) * 6) / days)
	for d = 1, days do
		local lit = streak.Owned or d <= (streak.Streak or 0)
		local pip = box(
			sCard,
			if lit then Color3.fromRGB(90, 170, 255) else C.Raised,
			20 + (d - 1) * (pipW + 6),
			92,
			pipW,
			pipW
		)
		round(pip, 8)
		local n = text(pip, tostring(d), 13, if lit then C.Ink else C.Dim, BLACK, 0, 0, pipW, pipW)
		n.TextXAlignment = Enum.TextXAlignment.Center
	end
	text(
		sCard,
		if streak.Owned
			then "Yours. Keep coming back: the daily coins keep coming."
			else string.format("Day %d of %d. Don't break the chain!", streak.Streak or 0, days),
		12,
		if streak.Owned then C.Good else C.Gold,
		BOLD,
		20,
		cardH - 40,
		half - 40,
		16
	)

	-- 4. Promo codes.
	local cCard = freeCard(
		half + 14,
		top + cardH + 14,
		half,
		cardH,
		Color3.fromRGB(190, 120, 255),
		"Promo codes",
		if discordOk
			then "Codes drop in our Discord, on socials and at like milestones."
			else "Codes come with game updates and at like milestones."
	)
	local entry = new("TextBox", {
		Name = "CodeBox",
		BackgroundColor3 = C.Well,
		Position = UDim2.fromOffset(20, 92),
		Size = UDim2.fromOffset(half - 40 - 140, 44),
		Font = BOLD,
		TextSize = 16,
		TextColor3 = C.Text,
		PlaceholderText = "Enter a code",
		PlaceholderColor3 = C.Faint,
		Text = "",
		ClearTextOnFocus = false,
	}, cCard)
	round(entry, 10)
	stroke(entry, C.Line, 1, 0.85)
	button(cCard, "Redeem", "Primary", half - 20 - 130, 92, 130, 44, function()
		if FreeRewards.normalizeCode(entry.Text) then
			freeAction("RedeemCode", entry.Text)
			entry.Text = ""
		else
			UiKit.toast("Type a code first.", C.Dim)
		end
	end).Name =
		"Redeem"
	text(
		cCard,
		string.format("%d code%s redeemed", info.CodesUsed or 0, if info.CodesUsed == 1 then "" else "s"),
		12,
		C.Dim,
		MEDIUM,
		20,
		cardH - 40,
		half - 40,
		16
	)
end

-- Drawing ----------------------------------------------------------------------------------------------------------

local DRAW = {
	Featured = drawBundles,
	Kaiju = function()
		KaijuDeals.draw()
	end,
	Skins = function()
		drawCatalog("Skins")
	end,
	Suits = function()
		drawCatalog("Suits")
	end,
	Helmets = function()
		drawCatalog("Helmets")
	end,
	Visors = function()
		drawCatalog("Visors")
	end,
	Picks = function()
		drawCatalog("Picks")
	end,
	Free = drawFree,
}

local function drawHeader()
	for id, b in navButtons do
		local on = id == state.Tab
		local label = navLabels[id]
		label.TextColor3 = if on then C.Text else C.Dim
		label.Font = if on then BLACK else BOLD
		if SHORT then
			b.BackgroundTransparency = if on then 0 else 1
		end
		local underline = b:FindFirstChild("Underline")
		if underline then
			underline.Visible = on
		end
	end
	walletValue.Text = commas(profile().Coins or 0)
	local key = offerKey()
	-- (a phone: the Featured page leads with it, and its tab says SALE)
	deal.Visible = key ~= nil and not SHORT
	if dealTag then
		dealTag.Visible = key ~= nil
	end
	if key then
		local left = if key == "StarterPack" then starterLeft() else welcomeLeft()
		deal.Text = Store.productName(key) .. "  ·  " .. clock(left)
	end
end

function refresh()
	if not gui.Enabled then
		return
	end
	table.clear(timers)
	table.clear(KaijuDeals.Turning)
	drawHeader()
	IronUi.clear(page)
	DRAW[state.Tab]()
	page.Position = UDim2.fromOffset(PAGE_X, PAGE_Y + 8)
	TweenService:Create(page, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(PAGE_X, PAGE_Y),
	}):Play()
end
ShopUI.refresh = refresh

deal.Activated:Connect(function()
	state.Tab = "Featured"
	refresh()
end)

function ShopUI.open(which: string?)
	-- (Old names for the tabs, from other screens: the bundles are on
	-- Featured, the front page.)
	if which == "Bundles" or which == "Passes" or which == "Backs" or which == "Trims" then
		which = "Featured"
	end
	if which and DRAW[which] then
		state.Tab = which
	end
	freeState = nil
	closeOverlay()
	fit() -- (before it shows: a phone's first fit would draw the page twice)
	gui.Enabled = true
	UiSound.play("Open")
	-- (a computer's window grows in a touch; a phone's is the screen)
	if not SHORT then
		if pop then
			pop:Cancel()
		end
		scale.Scale = fittedScale * 0.96
		local grow = TweenService:Create(
			scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = fittedScale }
		)
		pop = grow
		grow.Completed:Connect(function()
			if pop == grow then
				pop = nil
			end
		end)
		grow:Play()
	end
	refresh()
	-- (and again once it's up: a window that was hidden learns its size then)
	task.defer(fit)
end

function ShopUI.close()
	if gui.Enabled then
		UiSound.play("Close")
	end
	gui.Enabled = false
	closeOverlay()
	IronUi.clear(page)
	table.clear(timers)
	table.clear(KaijuDeals.Turning)
end

function ShopUI.toggle()
	if gui.Enabled then
		ShopUI.close()
	else
		ShopUI.open()
	end
end

close.Activated:Connect(ShopUI.close)
shade.Activated:Connect(function()
	-- (a phone's shade is only the edges past its notch: not a way out)
	if not SHORT then
		ShopUI.close()
	end
end)
GemClient.Changed:Connect(function()
	if gui.Enabled and not state.Busy then
		refresh()
	end
end)

-- The offers, on their own ---------------------------------------------------------------------------------------
-- The Welcome Kit (new players, within a day of joining) and the Starter
-- Pack (once, after your first win) pop up by themselves: the offer, what's
-- inside, and buy.

local function offerPopup(name: string, key: string)
	local popup = UiKit.gui(name, 13)
	popup.IgnoreGuiInset = true
	local dim = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
	}, popup)
	local card = new("Frame", {
		Name = "Offer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 420),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Active = true,
	}, popup)
	round(card, 16)
	stroke(card, C.Line, 1, 0.82)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Window, C.WindowLow) }, card)
	local fitScale = new("UIScale", {}, card)
	local function fitPopup()
		local s = popup.AbsoluteSize
		if s.X > 0 then
			local fitted = math.min(1, (s.X - 24) / 900, (s.Y - 24) / 420)
			local room, at = UiKit.clearTopbar(s, Vector2.new(900, 420) * fitted)
			fitScale.Scale = fitted * room
			card.Position = at
		end
	end
	popup:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPopup)
	UiKit.onTopbar(fitPopup)
	fitPopup()
	text(card, "SPECIAL OFFER", 11, C.Gold, BOLD, 24, 20, 300, 14)
	local x = new("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Surface,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(32, 32),
	}, card)
	IronUi.cross(x, 13, C.Dim)
	round(x, 16)
	local body = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 50),
		Size = UDim2.fromOffset(860, 350),
	}, card)
	local function hide()
		popup.Enabled = false
		table.clear(timers)
	end
	x.Activated:Connect(hide)
	dim.Activated:Connect(hide)
	local function show()
		IronUi.clear(body)
		table.clear(timers)
		offerBanner(body, key, 860)
		local strip = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 212),
			Size = UDim2.fromOffset(860, 138),
		}, body)
		UiKit.list(strip, 12, true)
		for i, item in
			Store.items(Store.contents(key) or {}, function(id)
				local cosmetic = Cosmetics.get(id)
				return if cosmetic then cosmetic.Name else id
			end)
		do
			local tile = box(strip, C.Surface, 0, 0, 132, 134)
			tile.LayoutOrder = i
			round(tile, 12)
			local cosmetic = item.Id and Cosmetics.get(item.Id)
			local pic = well(tile, if cosmetic then Cosmetics.rarityColor(cosmetic) or C.Dim else C.Gold, 6, 6, 120, 92)
			art(pic, item.Kind, item.Id, 78)
			local label = text(tile, item.Text, 11, C.Text, BOLD, 6, 102, 120, 26)
			wrap(label).TextXAlignment = Enum.TextXAlignment.Center
		end
		popup.Enabled = true
		UiSound.play("Open")
	end
	popup.Enabled = false
	return show, popup
end

local showWelcomePopup, welcomeGui = offerPopup("WelcomeBundle", "Welcome")
local showStarterPopup, starterGui = offerPopup("StarterPack", "StarterPack")

function ShopUI.showWelcome()
	if welcomeLeft() > 0 then
		showWelcomePopup()
	end
end

function ShopUI.showStarter()
	if starterLeft() > 0 then
		showStarterPopup()
	end
end

-- After the first win, back out of the fight: put the Starter Pack on offer
-- and show it, once.
local starterAsked = false
local function maybeOfferStarter()
	local p = profile()
	local duel = p.Duel or {}
	local wins = (duel.Wins or 0) + (duel.RivalWins or 0)
	if starterAsked or wins < 1 or p.StarterBought or p.StarterOfferAt then
		return
	end
	if player:GetAttribute("CombatSession") or player:GetAttribute("FirstFight") then
		return
	end
	starterAsked = true
	task.spawn(function()
		task.wait(1.5)
		local result = GemClient.request("StarterOffer")
		if result.Ok and not result.Bought then
			if result.OfferedAt then
				p.StarterOfferAt = result.OfferedAt
			end
			ShopUI.showStarter()
		end
	end)
end
GemClient.Changed:Connect(maybeOfferStarter)
player:GetAttributeChangedSignal("CombatSession"):Connect(maybeOfferStarter)

-- Tick the clocks once a second.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 1 then
		return
	end
	elapsed = 0
	for _, t in timers do
		if t.Label.Parent then
			local left = t.Left()
			t.Label.Text = if left > 0 then t.Prefix .. clock(left) else "OFFER ENDED"
		end
	end
	if gui.Enabled then
		local key = offerKey()
		deal.Visible = key ~= nil and not SHORT -- (a phone: the Bundles page leads with it)
		if dealTag then
			dealTag.Visible = key ~= nil
		end
		if key then
			local left = if key == "StarterPack" then starterLeft() else welcomeLeft()
			deal.Text = Store.productName(key) .. "  ·  " .. clock(left)
		end
	end
	if welcomeGui.Enabled and welcomeLeft() <= 0 then
		welcomeGui.Enabled = false
	end
	if starterGui.Enabled and starterLeft() <= 0 then
		starterGui.Enabled = false
	end
end)

return ShopUI
