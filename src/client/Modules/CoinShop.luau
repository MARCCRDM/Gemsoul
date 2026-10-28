--[[
	The coin packs, in the gilt look (Client GiltUi): coins for Robux
	(Shared.Store.CoinPacks), in a window of their own, apart from the Store
	and the Market. Four packs side by side, each its own treasure (a purse,
	a satchel, a strongbox, a hoard spilling from an open chest) glinting on
	crimson velvet in a burst of light, the bigger ones cheaper per coin:
	each card shows its saving and the price at the first pack's rate struck
	through.

	It opens when you click your coins (the lobby's card and phone pill,
	the Store's wallet, the Inventory's and the Market's coin totals:
	CoinShop.hook), and by itself when you come up short of coins for
	something (a reply's CoinsShort: Server Shop.short; Client GemClient
	.onCoinsShort). Then it says how many more it takes and marks the
	smallest pack that covers it.

	Bought with Roblox's purchase prompt (the coins come with the receipt:
	Server StoreServer.grantProduct), or with coins while testing (the
	store's BuyProduct); not yet on sale says so.

	  CoinShop.open(short?)   shows it (again: redrawn); `short` coins more needed
	  CoinShop.close()
	  CoinShop.isOpen()
	  CoinShop.hook(widget)   a click on `widget` (a coin total) opens it
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Store = require(Shared:WaitForChild("Store"))
local GemClient = require(script.Parent.GemClient)
local Gilt = require(script.Parent.GiltUi)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local new = IronUi.new
local player = Players.LocalPlayer

local CoinShop = {}
CoinShop.Width = 760
-- Each pack's name, smallest to biggest.
CoinShop.Names = { "Purse", "Satchel", "Strongbox", "Hoard" }

local gui: ScreenGui? = nil
local changed: RBXScriptConnection? = nil
local beat: RBXScriptConnection? = nil
local busy = false
-- What moves while it's open: light bursts turning ({ Frame, Speed }) and
-- glints twinkling ({ Frame, Phase }).
local bursts = {}
local glints = {}

-- The gold of the coins themselves: bright face, deep edge, dark rim.
local FACE = Color3.fromRGB(255, 228, 140)
local EDGE = Color3.fromRGB(184, 120, 38)
local RIM = Color3.fromRGB(88, 54, 16)
local WHITE = Color3.new(1, 1, 1)

local function screen(): ScreenGui
	if not gui then
		gui = UiKit.gui("CoinShop", 60)
	end
	return gui :: ScreenGui
end

function CoinShop.close()
	if changed then
		changed:Disconnect()
		changed = nil
	end
	if beat then
		beat:Disconnect()
		beat = nil
	end
	table.clear(bursts)
	table.clear(glints)
	if gui then
		gui:ClearAllChildren()
	end
end

function CoinShop.isOpen(): boolean
	return gui ~= nil and #(gui :: ScreenGui):GetChildren() > 0
end

-- Words in the window: sans serif, warm ivory or faded, centred.
local function line(parent: Instance, value: string, size: number, color: Color3, y: number, height: number?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = IronUi.Body,
		RichText = true,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height or size + 4),
	}, parent)
end

-- A plain shape at (x, y) pixels in `parent`, anchored at its bottom centre.
local function shape(parent: Instance, x: number, y: number, w: number, h: number, z: number, rotation: number?): Frame
	return new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = WHITE,
		Rotation = rotation or 0,
		ZIndex = z,
	}, parent)
end

local function shade(frame: GuiObject, a: Color3, b: Color3, rotation: number?)
	new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(a, b) }, frame)
end

-- A coin lying flat, its face up: `w` wide, its bottom at (x, y).
local function coinFace(parent: Instance, x: number, y: number, w: number, z: number): Frame
	local faceH = math.max(3, math.floor(w * 0.42))
	local face = shape(parent, x, y, w, faceH, z)
	face.Name = "Face"
	UiKit.round(face, faceH)
	shade(face, FACE, EDGE)
	new("UIStroke", { Color = RIM, Thickness = 1, Transparency = 0.15 }, face)
	local ring = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.56),
		BackgroundTransparency = 1,
		ZIndex = z,
	}, face)
	UiKit.round(ring, faceH)
	new("UIStroke", { Color = Color3.fromRGB(255, 246, 206), Thickness = 1, Transparency = 0.45 }, ring)
	return face
end

-- One stack of `count` coins seen from the side, its face on top, standing
-- on `floor` at `x` (pixels) in `parent`, `w` wide.
local function stack(parent: Instance, x: number, floor: number, w: number, count: number, z: number)
	local thick = math.max(3, math.floor(w * 0.17))
	local step = thick - 1
	for i = 1, count do
		local coin = shape(parent, x, floor - (i - 1) * step, w, thick + 1, z)
		coin.Name = "Coin"
		UiKit.round(coin, thick)
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, EDGE),
				ColorSequenceKeypoint.new(0.32, FACE),
				ColorSequenceKeypoint.new(0.6, EDGE),
				ColorSequenceKeypoint.new(1, RIM),
			}),
		}, coin)
		new("UIStroke", { Color = RIM, Thickness = 1, Transparency = 0.25 }, coin)
	end
	local faceH = math.floor(w * 0.42)
	coinFace(parent, x, floor - (count - 1) * step - thick + math.floor(faceH * 0.45), w, z)
end

-- A gem lying in the heap: a cut stone of `color`, `s` across.
local function gem(parent: Instance, x: number, y: number, s: number, color: Color3, z: number)
	local stone = shape(parent, x, y, s, s, z, 45)
	stone.Name = "Gem"
	UiKit.round(stone, 2)
	shade(stone, color:Lerp(WHITE, 0.55), color, 135)
	new("UIStroke", { Color = color:Lerp(Color3.new(0, 0, 0), 0.6), Thickness = 1 }, stone)
	local facet = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.36, 0.36),
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
		ZIndex = z,
	}, stone)
	UiKit.round(facet, 2)
end

-- A strongbox `cw` wide standing on `floor` at `x`: banded dark wood with a
-- gold lock, shut (`open` false) or thrown open and heaped with coins and
-- gems.
local function chest(parent: Instance, x: number, floor: number, cw: number, open: boolean, z: number)
	local ch = math.floor(cw * 0.52)
	local wood, dark = Color3.fromRGB(122, 66, 30), Color3.fromRGB(54, 26, 12)
	local goldA, goldB = Color3.fromRGB(255, 220, 120), Color3.fromRGB(176, 112, 34)
	local lidH = math.floor(ch * 0.62)
	-- The lid: shut on top, or thrown back behind the heap.
	local lid = shape(parent, x, floor - ch + (if open then 2 else math.floor(lidH * 0.45)), cw, lidH, if open then z - 1 else z)
	lid.Name = "Lid"
	if open then
		lid.Rotation = -6
		lid.Position = UDim2.fromOffset(x - 2, floor - ch - math.floor(lidH * 0.35))
	end
	UiKit.round(lid, math.floor(lidH * 0.5))
	shade(lid, wood:Lerp(WHITE, 0.08), dark)
	new("UIStroke", { Color = Color3.fromRGB(34, 16, 6), Thickness = 1 }, lid)
	for _, at in { 0.22, 0.78 } do
		local strap = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(at, 0),
			Size = UDim2.new(0, math.max(2, math.floor(cw * 0.07)), 1, 0),
			BackgroundColor3 = WHITE,
			ZIndex = lid.ZIndex,
		}, lid)
		shade(strap, goldA, goldB, 0)
	end
	-- The heap in it.
	if open then
		local coin = math.floor(cw * 0.22)
		for row, count in { 5, 4, 2 } do
			for i = 1, count do
				local across = (i - (count + 1) / 2) * coin * 0.78
				coinFace(parent, math.floor(x + across), floor - ch + 4 - (row - 1) * math.floor(coin * 0.24), coin, z + row)
			end
		end
		gem(parent, x - math.floor(cw * 0.2), floor - ch - math.floor(coin * 0.38), math.floor(coin * 0.5), Color3.fromRGB(230, 50, 64), z + 4)
		gem(parent, x + math.floor(cw * 0.16), floor - ch - math.floor(coin * 0.5), math.floor(coin * 0.44), Color3.fromRGB(70, 150, 255), z + 4)
		gem(parent, x + math.floor(cw * 0.02), floor - ch - math.floor(coin * 0.78), math.floor(coin * 0.4), Color3.fromRGB(96, 220, 120), z + 4)
	end
	-- The box.
	local box = shape(parent, x, floor, cw, ch, z + 5)
	box.Name = "Box"
	UiKit.round(box, 3)
	shade(box, wood, dark)
	new("UIStroke", { Color = Color3.fromRGB(34, 16, 6), Thickness = 1 }, box)
	local rim = new("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, math.max(2, math.floor(ch * 0.1))),
		BackgroundColor3 = WHITE,
		ZIndex = z + 5,
	}, box)
	shade(rim, goldA, goldB)
	for _, at in { 0.22, 0.78 } do
		local strap = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(at, 0),
			Size = UDim2.new(0, math.max(2, math.floor(cw * 0.07)), 1, 0),
			BackgroundColor3 = WHITE,
			ZIndex = z + 5,
		}, box)
		shade(strap, goldA, goldB, 0)
	end
	local lock = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.04),
		Size = UDim2.fromOffset(math.floor(cw * 0.15), math.floor(ch * 0.36)),
		BackgroundColor3 = WHITE,
		ZIndex = z + 6,
	}, box)
	UiKit.round(lock, 2)
	shade(lock, goldA, goldB)
	new("UIStroke", { Color = RIM, Thickness = 1 }, lock)
	local hole = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.26, 0.34),
		BackgroundColor3 = Color3.fromRGB(30, 14, 4),
		ZIndex = z + 6,
	}, lock)
	UiKit.round(hole, 2)
end

-- A burst of light behind the treasure: rays fading out from the middle,
-- turning slowly (faster, and brighter, on the pack that stands out).
local function burst(parent: Instance, x: number, y: number, size: number, strength: number, speed: number)
	local holder = new("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, parent)
	for i = 0, 7 do
		local ray = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, math.max(4, math.floor(size * 0.07))),
			Rotation = i * 22.5,
			BackgroundColor3 = Color3.fromRGB(255, 214, 120),
			BorderSizePixel = 0,
			ZIndex = 1,
		}, holder)
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 1 - strength),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, ray)
	end
	-- (and a warm pool of light at its heart)
	for ring = 1, 3 do
		local pool = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.2 + ring * 0.14, 0.2 + ring * 0.14),
			BackgroundColor3 = Color3.fromRGB(255, 196, 96),
			BackgroundTransparency = 1 - strength * 0.22,
			ZIndex = 1,
		}, holder)
		UiKit.round(pool, math.floor(size))
	end
	table.insert(bursts, { Frame = holder, Speed = speed })
	return holder
end

-- A glint on the gold: a four-pointed star that twinkles.
local function glint(parent: Instance, x: number, y: number, s: number, phase: number)
	local star = new("Frame", {
		Name = "Glint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(s, s),
		BackgroundTransparency = 1,
		ZIndex = 40,
	}, parent)
	for _, spec in { { 1, 0.16 }, { 0.16, 1 } } do
		local arm = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(spec[1], spec[2]),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 40,
		}, star)
		UiKit.round(arm, s)
	end
	table.insert(glints, { Frame = star, Phase = phase })
end

-- Each pack's treasure in its well (`w` x `h` pixels): tier 1 to 4.
local function treasure(well: Instance, tier: number, w: number, h: number)
	local floor = h - math.floor(h * 0.12)
	local cx = math.floor(w / 2)
	-- (the small ones drawn bigger, so every treasure fills its well)
	local unit = math.floor(math.min(w, h * 1.5) * 0.17 * (({ 1.45, 1.22, 1, 1 })[tier] or 1))
	-- (a soft shadow on the velvet)
	local shadow = shape(well, cx, floor + 3, math.floor(w * (0.46 + tier * 0.1)), 6, 2)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.6
	UiKit.round(shadow, 3)
	if tier == 1 then
		stack(well, cx - math.floor(unit * 0.55), floor, unit, 3, 6)
		stack(well, cx + math.floor(unit * 0.6), floor, unit, 2, 7)
		coinFace(well, cx + math.floor(unit * 0.05), floor + 2, unit, 8)
	elseif tier == 2 then
		stack(well, cx - math.floor(unit * 1.1), floor, unit, 3, 6)
		stack(well, cx, floor - 2, unit, 6, 5)
		stack(well, cx + math.floor(unit * 1.1), floor, unit, 4, 6)
		coinFace(well, cx - math.floor(unit * 0.55), floor + 3, unit, 9)
		coinFace(well, cx + math.floor(unit * 0.6), floor + 3, unit, 9)
	elseif tier == 3 then
		chest(well, cx, floor - 2, math.floor(unit * 2.6), false, 10)
		stack(well, cx - math.floor(unit * 1.75), floor + 1, unit, 5, 20)
		stack(well, cx + math.floor(unit * 1.75), floor + 1, unit, 4, 20)
		coinFace(well, cx + math.floor(unit * 0.5), floor + 4, unit, 22)
	else
		chest(well, cx, floor - 2, math.floor(unit * 2.9), true, 10)
		stack(well, cx - math.floor(unit * 1.95), floor + 1, unit, 6, 20)
		stack(well, cx + math.floor(unit * 1.95), floor + 1, unit, 5, 20)
		coinFace(well, cx - math.floor(unit * 0.8), floor + 4, unit, 22)
		coinFace(well, cx + math.floor(unit * 0.75), floor + 5, unit, 22)
	end
	-- Glints on the gold, more on the bigger ones.
	local spots = {
		{ -0.5, -0.9 },
		{ 0.6, -0.5 },
		{ -0.1, -1.6 },
		{ 1.2, -1.2 },
		{ -1.3, -0.6 },
	}
	for i = 1, tier do
		local spot = spots[i]
		glint(well, cx + math.floor(spot[1] * unit), floor + math.floor(spot[2] * unit), math.max(6, math.floor(unit * 0.38)), i * 1.7)
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
		UiKit.toast("Coming soon: coin packs go on sale shortly.", Gilt.Faded)
		return
	end
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request("BuyProduct", key)
		busy = false
		if result and result.Ok then
			CoinShop.close()
			UiKit.toast("Thank you! " .. Store.productName(key) .. " added to your purse.", Gilt.Gold)
		elseif result and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, Gilt.Red)
		end
	end)
end

-- One pack's card, `w` x `h`, at `x` in the row.
local function card(row: Instance, pack: Store.CoinPack, tier: number, x: number, w: number, h: number, marked: boolean, phone: boolean)
	local best = pack.Tag == "Best value"
	local box = new("Frame", {
		Name = pack.Key,
		Position = UDim2.fromOffset(x, 12),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = WHITE,
	}, row)
	UiKit.round(box, 4)
	shade(box, Color3.fromRGB(48, 37, 27), Color3.fromRGB(15, 11, 9))
	local restEdge = if marked then Color3.fromRGB(150, 230, 120) elseif pack.Tag then Gilt.Gold else Gilt.Brass
	local edge = new("UIStroke", {
		Color = restEdge,
		Thickness = if marked or best then 2 else 1,
		Transparency = if marked or pack.Tag then 0 else 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, box)
	-- (a gold hairline just inside, as on the window)
	local inner = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
	}, box)
	UiKit.round(inner, 3)
	new("UIStroke", { Color = Gilt.Gold, Thickness = 1, Transparency = 0.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inner)

	-- The treasure, on crimson velvet in a burst of light.
	local wellH = if phone then 92 else 122
	local well = new("Frame", {
		Name = "Well",
		Position = UDim2.fromOffset(7, 7),
		Size = UDim2.fromOffset(w - 14, wellH),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
	}, box)
	UiKit.round(well, 3)
	shade(well, Color3.fromRGB(96, 26, 22), Color3.fromRGB(26, 8, 8))
	new("UIStroke", { Color = Color3.fromRGB(10, 4, 3), Thickness = 1, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, well)
	burst(
		well,
		(w - 14) / 2,
		wellH * 0.55,
		math.floor((w - 14) * 1.25),
		if best or marked then 0.34 else 0.12 + tier * 0.04,
		if best or marked then 9 else 3
	)
	treasure(well, tier, w - 14, wellH)
	-- (velvet darkening to the edges)
	local vignette = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 30,
	}, well)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.8, 1),
			NumberSequenceKeypoint.new(1, 0.5),
		}),
	}, vignette)

	-- Its ribbon across the top edge: what it covers, or its tag.
	local ribbonText = if marked then "Covers it" else pack.Tag
	if ribbonText then
		local ribbon = new("TextLabel", {
			Name = "Ribbon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.fromOffset(math.min(w - 20, 118), 24),
			BackgroundColor3 = WHITE,
			Text = ribbonText,
			TextSize = 13,
			Font = Gilt.Serif,
			TextColor3 = Gilt.Bright,
			ZIndex = 50,
		}, box)
		UiKit.round(ribbon, 3)
		shade(
			ribbon,
			if marked then Color3.fromRGB(72, 140, 52) elseif best then Color3.fromRGB(196, 140, 40) else Color3.fromRGB(168, 38, 24),
			if marked then Color3.fromRGB(26, 62, 18) elseif best then Color3.fromRGB(110, 62, 12) else Color3.fromRGB(84, 14, 10)
		)
		ribbon.TextStrokeColor3, ribbon.TextStrokeTransparency = Color3.new(0, 0, 0), 0.5
		new("UIStroke", { Color = Gilt.Bright, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, ribbon)
		Gilt.stud(ribbon, 5, UDim2.fromScale(0, 0.5)).ZIndex = 51
		Gilt.stud(ribbon, 5, UDim2.fromScale(1, 0.5)).ZIndex = 51
	end

	-- How many: a coin, then the number in gold.
	local y = 7 + wellH + 6
	local amount = new("Frame", {
		Name = "Amount",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, if phone then 28 else 34),
	}, box)
	local amountList = UiKit.list(amount, 5, true)
	amountList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	amountList.VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = new("Frame", {
		Name = "Coin",
		Size = UDim2.fromOffset(if phone then 16 else 20, if phone then 16 else 20),
		BackgroundColor3 = WHITE,
		LayoutOrder = 1,
	}, amount)
	UiKit.round(icon, 12)
	shade(icon, FACE, EDGE, 135)
	new("UIStroke", { Color = RIM, Thickness = 1 }, icon)
	local number = new("TextLabel", {
		Name = "Number",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Text = Store.commas(pack.Coins),
		TextSize = if phone then 24 else 30,
		Font = Gilt.Serif,
		TextColor3 = WHITE,
		LayoutOrder = 2,
	}, amount)
	shade(number, Color3.fromRGB(255, 240, 190), Color3.fromRGB(226, 160, 56))
	new("UIStroke", { Color = Color3.fromRGB(40, 22, 6), Thickness = 1, Transparency = 0.2 }, number)
	y += if phone then 28 else 34
	local name = Gilt.words(box, CoinShop.Names[tier] or "Coins", 13, Gilt.Faded)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Position, name.Size = UDim2.fromOffset(0, y - 2), UDim2.new(1, 0, 0, 18)
	y += 18

	-- The deal: its saving and what it would cost at the first pack's rate.
	local saving = Store.coinSaving(pack)
	local deal = if saving > 0
		then string.format(
			'<font color="#7CD662"><b>Save %d%%</b></font>   <font color="#706452"><s>R$ %s</s></font>',
			saving,
			Store.commas(pack.Coins / Store.CoinRate)
		)
		else string.format('<font color="#706452">%s coins a Robux</font>', Store.commas(Store.CoinRate))
	line(box, deal, 13, Gilt.Ink, y, 18).Font = IronUi.Heading

	-- The button: its price (a click says when, before it's on sale).
	local onSale = (Store.RobuxProducts[pack.Key] or 0) ~= 0 or Store.testPrice(pack.Key) ~= nil
	local holder = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, if phone then 34 else 40),
	}, box)
	local button = Gilt.button(holder, "R$ " .. Store.commas(pack.Robux), true, 1, function()
		buy(pack.Key)
	end, if phone then 34 else 40, if phone then 16 else 18)
	button.Name = "Buy"
	if not onSale then
		button.TextTransparency = 0.2
	end
	-- (the whole card buys it too, and lights up under the mouse)
	local hit = new("TextButton", {
		Name = "Hit",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, if phone then -46 else -52),
		ZIndex = 60,
	}, box)
	hit.Activated:Connect(function()
		buy(pack.Key)
	end)
	hit.MouseEnter:Connect(function()
		edge.Color = Gilt.Bright
	end)
	hit.MouseLeave:Connect(function()
		edge.Color = restEdge
	end)
	return box
end

function CoinShop.open(short: number?)
	CoinShop.close()
	local phone = UiKit.short()
	local width = CoinShop.Width
	local holder = new("Frame", { Name = "Coins", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen())
	local backdrop = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
	}, holder)
	backdrop.Activated:Connect(CoinShop.close)
	local body = Gilt.frame(holder, width, phone)
	local frame = body.Parent :: Frame
	-- (on a short screen it shrinks to fit, never past the edges)
	local fit = new("UIScale", {}, frame)
	local function refit()
		local size = (gui :: ScreenGui).AbsoluteSize
		local height = math.max(1, frame.AbsoluteSize.Y / math.max(fit.Scale, 0.01))
		fit.Scale = math.min(1, (size.X - 32) / width, (size.Y - 24) / height)
	end

	-- The heading: Coins between two coins, and what's in your purse now.
	local head = new("Frame", { Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 62), LayoutOrder = 1 }, body)
	local titleRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34) }, head)
	local titleList = UiKit.list(titleRow, 10, true)
	titleList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	titleList.VerticalAlignment = Enum.VerticalAlignment.Center
	for order = 1, 3, 2 do
		local emblem = new("Frame", { Size = UDim2.fromOffset(22, 22), BackgroundColor3 = WHITE, LayoutOrder = order }, titleRow)
		UiKit.round(emblem, 12)
		shade(emblem, FACE, EDGE, 135)
		new("UIStroke", { Color = RIM, Thickness = 1 }, emblem)
		local ring = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			BackgroundTransparency = 1,
		}, emblem)
		UiKit.round(ring, 12)
		new("UIStroke", { Color = Color3.fromRGB(255, 246, 206), Thickness = 1, Transparency = 0.4 }, ring)
	end
	local title = Gilt.words(titleRow, "Coins", 28, Gilt.Gold)
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.new(0, 0, 0, 34)
	title.LayoutOrder = 2
	-- (your purse, in a little well)
	local pursePill = new("Frame", {
		Name = "Purse",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 34),
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
	}, head)
	Gilt.well(pursePill)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, pursePill)
	local purse = new("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Text = "",
		TextSize = 13,
		Font = IronUi.Body,
		TextColor3 = Gilt.Faded,
		RichText = true,
	}, pursePill)
	local function showPurse()
		local coins = GemClient.Profile and GemClient.Profile.Coins or 0
		purse.Text = string.format('Your purse   <font color="#FFE296"><b>◆ %s</b></font>', Store.commas(coins))
	end
	showPurse()
	changed = GemClient.Changed:Connect(showPurse)
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
	closeButton.Activated:Connect(CoinShop.close)

	-- Short of coins: how many more it takes, and the pack marked that covers it.
	local marked: string? = nil
	if short and short > 0 then
		marked = Store.coinPackFor(short).Key
		local note = new("Frame", {
			Name = "Short",
			Size = UDim2.new(1, 0, 0, 44),
			LayoutOrder = 2,
			BackgroundColor3 = WHITE,
		}, body)
		UiKit.round(note, 3)
		shade(note, Color3.fromRGB(70, 22, 16), Color3.fromRGB(34, 10, 8))
		new("UIStroke", { Color = Color3.fromRGB(196, 84, 60), Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, note)
		local mark = new("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Color3.fromRGB(214, 92, 70),
			Text = "!",
			TextSize = 16,
			Font = Gilt.Serif,
			TextColor3 = WHITE,
		}, note)
		UiKit.round(mark, 12)
		local words = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -56, 1, 0),
		}, note)
		local top = line(words, string.format('You need <font color="#FFE296">◆ %s</font> more for that.', Store.commas(short)), 15, Gilt.Ink, 5, 18)
		top.Font, top.TextXAlignment = IronUi.Heading, Enum.TextXAlignment.Left
		local under = line(words, "The pack marked Covers it is enough, and your coins land the moment it goes through.", 12, Gilt.Faded, 23, 15)
		under.TextXAlignment = Enum.TextXAlignment.Left
	end

	-- The four packs, side by side.
	local count = #Store.CoinPacks
	local gap = 12
	local inner = width - 2 * (if phone then 8 else 20)
	local cardW = math.floor((inner - gap * (count - 1)) / count)
	local cardH = if phone then 218 else 264
	local row = new("Frame", {
		Name = "Packs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, cardH + 16),
		LayoutOrder = 3,
	}, body)
	for i, pack in Store.CoinPacks do
		card(row, pack, i, (i - 1) * (cardW + gap), cardW, cardH, pack.Key == marked, phone)
	end

	-- What they're for.
	local foot = line(
		body,
		if phone
			then "Coins pay for Market buys, kaiju battle stakes, Rift restores and more."
			else "Coins pay for Market buys, kaiju battle stakes, Rift restores and more. They're in your purse the moment the purchase goes through.",
		12,
		Gilt.Dusk,
		0,
		if phone then 16 else 32
	)
	foot.LayoutOrder = 4
	task.defer(refit)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	-- The light turning and the gold glinting.
	local started = os.clock()
	beat = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		for _, entry in bursts do
			entry.Frame.Rotation = (t * entry.Speed) % 360
		end
		for _, entry in glints do
			local wave = math.sin(t * 2.2 + entry.Phase)
			local glow = math.max(0, wave) ^ 3
			entry.Frame.Rotation = t * 40 + entry.Phase * 30
			for _, arm in entry.Frame:GetChildren() do
				if arm:IsA("Frame") then
					arm.BackgroundTransparency = 1 - glow * 0.95
				end
			end
		end
	end)
end

-- A click on `widget` (a coin total) opens the coin packs: the widget itself
-- if it's a button, else a clear button laid over it.
function CoinShop.hook(widget: GuiObject): GuiButton
	local button: GuiButton
	if widget:IsA("GuiButton") then
		button = widget :: GuiButton
	else
		button = new("TextButton", {
			Name = "CoinShopHit",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = widget.ZIndex + 5,
		}, widget)
		widget.Active = true
	end
	button.Activated:Connect(function()
		CoinShop.open()
	end)
	return button
end

-- Short of coins for something: the packs, saying how many more.
GemClient.onCoinsShort = function(short: number)
	CoinShop.open(short)
end

-- Bought: the window closes, and thanks while the coins land.
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if not purchased or userId ~= player.UserId then
		return
	end
	local key = Store.productKey(productId)
	local pack = key and Store.coinPack(key)
	if pack then
		CoinShop.close()
		UiKit.toast("Thank you! " .. Store.commas(pack.Coins) .. " coins added to your purse.", Gilt.Gold)
	end
end)

return CoinShop
