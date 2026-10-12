--[[
	Inventory v2: the miner owns the screen.

	  Top        back to the lobby, the other screens, your coins / season /
	             free pick
	  Left       who you are: miner 1 / 2 / 3, name, level, a big rating, four
	             stat bars and your armor set
	  Centre     your miner, large, on a lit floor
	  Right      what you wear: six rows (armor, then sword and shield), each
	             with its gem socket. Click one and the column turns into
	             that piece: the piece and its gem, its perk, then the gems
	             (or spare pieces) you could swap in. Hover one to see what
	             it would change; click it, then SOCKET or EQUIP
	  Bottom     the Surge Array (Q / E / R); click one to change its gem

	Drag a gem from the grid onto any row or Q / E / R card to socket it.
	The server checks every move (the same requests as the first Inventory).

	A test build next to Modules/InventoryScreen (v1): the DEV panel flips
	between them (player attribute InventoryVersion, 1 or 2).

	  InventoryV2.mount(gui)       builds it inside the Dashboard ScreenGui
	  InventoryV2.setActive(on)    shows it (and redraws) or hides it
	  InventoryV2.cancelDrag()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local ArmorSignatures = require(ReplicatedStorage.Shared.ArmorSignatures)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local MinerRoster = require(ReplicatedStorage.Shared.MinerRoster)
local OutpostRules = require(ReplicatedStorage.Shared.Outpost)
local Season = require(ReplicatedStorage.Shared.Season)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local ChargeMeter = require(script.Parent.ChargeMeter)
local GearArt = require(script.Parent.GearArt)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local InventoryPose = require(script.Parent.InventoryPose)
local IronUi = require(script.Parent.IronUi)
local SurgeIcons = require(script.Parent.SurgeIcons)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new

local InventoryV2 = {}

-- Look -------------------------------------------------------------------------------------------------

local C = {
	Ink = Color3.fromRGB(5, 7, 12),
	Deep = Color3.fromRGB(8, 11, 19),
	Text = Color3.fromRGB(238, 242, 247),
	Dim = Color3.fromRGB(139, 155, 177),
	Faint = Color3.fromRGB(74, 90, 112),
	Line = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(242, 189, 94),
	Teal = Color3.fromRGB(76, 195, 214),
	Good = Color3.fromRGB(95, 208, 138),
	Bad = Color3.fromRGB(255, 122, 107),
}
InventoryV2.Colors = C
local STAT_COLOR = {
	Health = Color3.fromRGB(95, 208, 138),
	Power = Color3.fromRGB(255, 122, 89),
	Defense = Color3.fromRGB(91, 184, 255),
	Speed = Color3.fromRGB(197, 139, 255),
}
local HEAVY, HEADING, MEDIUM, BODY = Enum.Font.GothamBlack, Enum.Font.GothamBold, Enum.Font.GothamMedium, Enum.Font.Gotham
local SLOT_NAME =
	{ Helmet = "HELMET", Armor = "CHEST", Gloves = "GLOVES", Boots = "BOOTS", Weapon = "SWORD", Shield = "SHIELD" }
local KEYS = { "Q", "E", "R" }
local GEM_RARITY = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 }
local ELEMENTS = { "Fire", "Frost", "Shock", "Poison" }

-- The layout is drawn at 1600 x 840 and scaled to the screen.
local W, H = 1600, 840
local TOPBAR, BOTTOM = 54, 36 -- Roblox's own buttons above; chat and DEV below
local RIGHT_X, RIGHT_W = 1170, 390
local LEFT_X, LEFT_W = 40, 330

-- Small builders ---------------------------------------------------------------------------------------

local function round(object: GuiObject, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end
local function stroke(object: GuiObject, color: Color3, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, object)
end
local function place(object: GuiObject, x: number, y: number, w: number, h: number)
	object.Position = UDim2.fromOffset(x, y)
	object.Size = UDim2.fromOffset(w, h)
	return object
end
local function text(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or HEADING,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end
local function frame(parent: Instance, color: Color3, transparency: number?): Frame
	return new("Frame", { BackgroundColor3 = color, BackgroundTransparency = transparency or 0 }, parent)
end
local function hit(parent: Instance): TextButton
	return new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	}, parent)
end
local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end
local function whole(value: number): string
	return tostring(math.floor(value + 0.5))
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

-- Data -------------------------------------------------------------------------------------------------

local function profileNow()
	return GemClient.Profile
end
local function loadoutNow()
	local profile = profileNow()
	return profile and profile.Character or {}
end
local function gearOf(loadout, slot: string, id: string?)
	local gearId = id or loadout[slot]
	return gearId and loadout.Class and Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, gearId) or nil
end
local function rarityOf(loadout, slot: string, id: string?): number
	local roll = GearRolls.get(loadout, slot, id)
	return if roll then roll.Rarity else 1
end
local function rarityColor(rarity: number): Color3
	local entry = GearRolls.Rarities[rarity]
	return if entry then entry.Color else GearRolls.Rarities[1].Color
end
local function rarityName(rarity: number): string
	local entry = GearRolls.Rarities[rarity]
	return string.upper(entry and entry.Name or "Common")
end
local function gemRarity(gem): number
	return GEM_RARITY[gem.Tier] or 1
end
local function gemColor(gem): Color3
	return GemConfig.ElementColors[gem.Element] or C.Text
end
local function gemName(gem): string
	if gem.Cut then
		local surge = Tech.surgeStats(gem)
		if surge then
			return surge.Name
		end
	end
	return GemConfig.displayName(gem)
end
local function statText(stat: string, amount: number): string
	if stat == "Critical" or stat == "Cooldown" then
		return string.format("+%s%% %s", whole(amount * 100), stat)
	end
	return string.format("+%s %s", whole(amount), stat)
end
local function topStat(roll): string?
	local best, amount = nil, 0
	for stat, value in roll and roll.Stats or {} do
		local weight = if stat == "Critical" or stat == "Cooldown" then value * 100 else value
		if weight > amount then
			best, amount = stat, weight
		end
	end
	return best and statText(best, roll.Stats[best]) or nil
end
local function request(action: string, ...)
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		if result and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, if result.Ok then C.Good else C.Bad)
		end
	end)
end
local function ratings(loadout)
	if not loadout.Class then
		return nil
	end
	local ok, result = pcall(Classes.ratings, loadout)
	return if ok then result else nil
end
local function totalRating(loadout): number
	local r = ratings(loadout)
	local sum = 0
	for _, stat in Classes.StatNames do
		sum += if r then r[stat].Base + r[stat].Bonus else 0
	end
	return sum
end
-- The perk a piece would have with this gem: its signature (armor), else its
-- passive and the gem's own lines (the sword).
local function perkOf(loadout, slot: string, id: string?, gem)
	local roll = GearRolls.get(loadout, slot, id)
	local signature = ArmorSignatures.resolve(roll, gem)
	if signature then
		return signature
	end
	return nil
end
local function perkValue(signature): string
	local d = signature.Definition
	local v = signature.Value
	return if d.Percent then string.format("%.1f%%", v * 100) else string.format("%.1f %s", v, d.Unit or "")
end
local function perkBase(signature): string
	local d = signature.Definition
	local v = signature.Base
	return if d.Percent then string.format("%.1f%%", v * 100) else string.format("%.1f", v)
end
-- Gems that fit a gear socket (cut), or a surge key (cut with a surge).
local function gemsFor(forKey: boolean, filter: string)
	local profile = profileNow()
	local list = {}
	for _, gem in profile and profile.Gems or {} do
		if gem.Cut ~= nil and (not forKey or Tech.surgeStats(gem) ~= nil) then
			if filter == "All" or gem.Element == filter then
				table.insert(list, gem)
			end
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = gemRarity(a), gemRarity(b)
		if ra ~= rb then
			return ra > rb
		end
		if (a.Element or "") ~= (b.Element or "") then
			return (a.Element or "") < (b.Element or "")
		end
		return a.Id < b.Id
	end)
	return list
end
local function sparesFor(slot: string)
	local profile = profileNow()
	local loadout = loadoutNow()
	local kind = Slots.Definitions[slot].Kind
	local list = {}
	for id in (profile and profile.Owned and profile.Owned[kind]) or {} do
		local gear = gearOf(loadout, slot, id)
		if gear and id ~= loadout[slot] and not MinerRoster.owner(profile, slot, id) then
			table.insert(list, { Slot = slot, Id = id, Gear = gear, Rarity = rarityOf(loadout, slot, id) })
		end
	end
	table.sort(list, function(a, b)
		if a.Rarity ~= b.Rarity then
			return a.Rarity > b.Rarity
		end
		return a.Id < b.Id
	end)
	return list
end
local function ratingGain(loadout, slot: string, id: string): number
	local trial = table.clone(loadout)
	trial[slot] = id
	local profile = profileNow()
	trial[slot .. "Quality"] = profile and profile.Owned and profile.Owned[Slots.Definitions[slot].Kind][id]
	trial[slot .. "Gem"] = (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id]) or nil
	local ok, gain = pcall(function()
		return totalRating(trial) - totalRating(loadout)
	end)
	return if ok then math.floor(gain + 0.5) else 0
end

-- Art --------------------------------------------------------------------------------------------------

local function gearArt(holder: Instance, slot: string, id: string, worn: boolean, color: Color3)
	clear(holder)
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 186, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -0.8, -0.6),
	}, holder)
	local ok, drawn = pcall(GearArt.draw, view, slot, id, worn)
	if not (ok and drawn) then
		view:Destroy()
		local gear = gearOf(loadoutNow(), slot, id)
		if gear then
			local okIcon, icon = pcall(GearArt.icon, holder, slot, gear, color)
			if okIcon and icon then
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.5)
			end
		end
	end
end
local function gemArt(holder: Instance, gem)
	clear(holder)
	pcall(GemArt.viewport, holder, gem, false)
end

-- State ------------------------------------------------------------------------------------------------

type Item = { Kind: string, Gem: any?, Slot: string?, Id: string? }
local state = {
	Active = false,
	Detail = nil :: string?, -- a gear slot ("Armor") or a key ("Q")
	Tab = "Gems", -- in a gear slot's detail: "Gems" or "Pieces"
	Filter = "All",
	Pick = nil :: Item?, -- clicked in the grid (sticky)
	Hover = nil :: Item?, -- under the pointer in the grid
}
local gui: ScreenGui? = nil
local ui: any = {}
local draw -- (below)
local dropTargets = {}
local drag: any = nil
local suppressClickUntil = 0

local function sameItem(a: Item?, b: Item?): boolean
	if not a or not b or a.Kind ~= b.Kind then
		return false
	end
	if a.Kind == "Gem" then
		return (a.Gem :: any).Id == (b.Gem :: any).Id
	end
	return a.Slot == b.Slot and a.Id == b.Id
end
local function openDetail(target: string?)
	state.Detail = target
	state.Tab = "Gems"
	state.Pick, state.Hover = nil, nil
	draw()
end

-- Build ------------------------------------------------------------------------------------------------

local function buildBackground(parent: Instance)
	local back = new("Frame", {
		Name = "V2Backdrop",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
	}, parent)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 11, 19)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(6, 9, 15)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 6, 10)),
		}),
	}, back)
	return back
end

-- A soft round glow: rings of light, faintest outside.
local function glow(parent: Instance, cx: number, cy: number, radius: number, color: Color3, strength: number)
	-- Many faint discs, so the steps between them don't show.
	for i = 1, 12 do
		local r = radius * (0.3 + i * 0.06)
		local disc = frame(parent, color, 1 - strength * 0.022)
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromOffset(cx, cy)
		disc.Size = UDim2.fromOffset(r * 2, r * 2 * 0.85)
		round(disc, 9999)
	end
end

local function buildTop(canvas: Frame)
	local back = new("TextButton", {
		Text = "‹  LOBBY",
		TextSize = 13,
		Font = HEADING,
		TextColor3 = C.Dim,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, canvas)
	place(back, 0, 8, 110, 40)
	back:SetAttribute("UiSound", "Back")
	back.MouseEnter:Connect(function()
		back.TextColor3 = C.Text
	end)
	back.MouseLeave:Connect(function()
		back.TextColor3 = C.Dim
	end)
	back.Activated:Connect(function()
		InventoryV2.cancelDrag()
		local LobbyUI = require(script.Parent.LobbyUI) :: any
		if LobbyUI.closeDashboard then
			LobbyUI.closeDashboard()
		end
	end)
	local function open(name: string, method: string)
		return function()
			InventoryV2.cancelDrag()
			local module = require(script.Parent:FindFirstChild(name) :: ModuleScript) :: any
			module[method]()
		end
	end
	local tabs = new("Frame", { BackgroundTransparency = 1 }, canvas)
	place(tabs, 130, 8, 760, 40)
	local list = UiKit.list(tabs, 30, true)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	for order, spec in {
		{ "INVENTORY", nil },
		{ "SURGES", open("SurgeArrayUI", "toggle") },
		{ "AUGMENTS", open("AugmentTreeUI", "toggle") },
		{ "SEASON", open("SeasonUI", "toggle") },
		{ "MARKET", open("MarketBoardUI", "open") },
		{ "STORE", open("ShopUI", "toggle") },
	} do
		local on = spec[2] == nil
		local b = new("TextButton", {
			Text = spec[1],
			TextSize = 13,
			Font = HEADING,
			TextColor3 = if on then C.Text else C.Faint,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			LayoutOrder = order,
		}, tabs)
		b:SetAttribute("UiSound", "Click")
		if on then
			local bar = frame(b, C.Gold)
			bar.AnchorPoint = Vector2.new(0, 1)
			bar.Position = UDim2.fromScale(0, 1)
			bar.Size = UDim2.new(1, 0, 0, 2)
		else
			b.MouseEnter:Connect(function()
				b.TextColor3 = C.Text
			end)
			b.MouseLeave:Connect(function()
				b.TextColor3 = C.Faint
			end)
			b.Activated:Connect(spec[2])
		end
	end
	-- Wallet: three quiet readouts, right-aligned.
	local function readout(x: number, caption: string)
		local value = text(canvas, "", 18, C.Text, HEAVY)
		place(value, x, 8, 150, 22)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local cap = text(canvas, caption, 10, C.Dim, HEADING)
		place(cap, x, 30, 150, 14)
		cap.TextXAlignment = Enum.TextXAlignment.Right
		return value, cap
	end
	ui.Coins = readout(W - 520, "COINS")
	ui.Season, ui.SeasonCap = readout(W - 340, "SEASON")
	ui.Pick, ui.PickCap = readout(W - 160, "FREE PICK")
	local track = frame(canvas, C.Line, 0.92)
	place(track, W - 96 - 340 + 150, 47, 96, 3)
	round(track, 2)
	ui.SeasonFill = frame(track, C.Teal)
	ui.SeasonFill.Size = UDim2.fromScale(0, 1)
	round(ui.SeasonFill, 2)
	local seasonHit = hit(ui.Season)
	seasonHit.Size = UDim2.new(1, 0, 0, 40)
	seasonHit.Activated:Connect(open("SeasonUI", "toggle"))
end

local function buildLeft(canvas: Frame)
	local x, w = LEFT_X, LEFT_W
	-- Miner 1 / 2 / 3.
	ui.Miners = {}
	for index = 1, MinerRoster.Count do
		local b = new("TextButton", {
			Text = tostring(index),
			TextSize = 13,
			Font = HEADING,
			TextColor3 = C.Faint,
			AutoButtonColor = false,
			BackgroundColor3 = C.Gold,
			BackgroundTransparency = 1,
		}, canvas)
		place(b, x + (index - 1) * 40, 96, 32, 32)
		round(b, 8)
		local edge = stroke(b, C.Line, 1, 0.9)
		b:SetAttribute("UiSound", "Tab")
		b.Activated:Connect(function()
			InventoryV2.cancelDrag()
			state.Pick, state.Hover = nil, nil
			request("MinerSelect", index)
		end)
		ui.Miners[index] = { Button = b, Edge = edge }
	end
	ui.Name = place(text(canvas, "", 40, C.Text, HEAVY), x, 140, w + 120, 44)
	ui.Sub = place(text(canvas, "", 11, C.Dim, HEADING), x, 188, w + 120, 16)
	-- The rating, big, with its caption beside it on the same baseline.
	local ratingRow = new("Frame", { BackgroundTransparency = 1 }, canvas)
	place(ratingRow, x, 220, w, 64)
	local rowList = UiKit.list(ratingRow, 12, true)
	rowList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	ui.Rating = text(ratingRow, "0", 58, C.Gold, HEAVY)
	ui.Rating.Size = UDim2.fromOffset(0, 64)
	ui.Rating.AutomaticSize = Enum.AutomaticSize.X
	ui.Rating.TextTruncate = Enum.TextTruncate.None
	ui.Rating.LayoutOrder = 1
	ui.RatingCap = text(ratingRow, "RATING", 11, C.Dim, HEADING)
	ui.RatingCap.Size = UDim2.fromOffset(80, 30)
	ui.RatingCap.LayoutOrder = 2
	-- Four stat bars.
	ui.Stats = {}
	for i, stat in Classes.StatNames do
		local y = 312 + (i - 1) * 34
		place(text(canvas, string.upper(stat), 10, C.Dim, HEADING), x, y, 80, 16)
		local track = frame(canvas, C.Line, 0.93)
		place(track, x + 84, y + 6, 196, 4)
		round(track, 2)
		local fill = frame(track, STAT_COLOR[stat])
		fill.Size = UDim2.fromScale(0, 1)
		round(fill, 2)
		local value = place(text(canvas, "0", 16, C.Text, HEAVY), x + w - 44, y - 2, 44, 20)
		value.TextXAlignment = Enum.TextXAlignment.Right
		ui.Stats[stat] = { Fill = fill, Value = value, Last = nil }
	end
	-- The armor set.
	local rule = frame(canvas, C.Line, 0.93)
	place(rule, x, 456, w, 1)
	ui.SetName = place(text(canvas, "", 11, C.Teal, HEADING), x, 470, 220, 16)
	ui.Pips = {}
	for i = 1, 6 do
		local pip = frame(canvas, C.Line, 0.9)
		place(pip, x + w - 6 * 19 + (i - 1) * 19, 476, 14, 4)
		round(pip, 2)
		ui.Pips[i] = pip
	end
	ui.SetBonus = place(text(canvas, "", 12, C.Text, HEADING), x, 494, w, 18)
	ui.SetBonus.RichText = true
	ui.SetNext = place(text(canvas, "", 12, C.Dim, BODY), x, 514, w, 34)
	ui.SetNext.TextWrapped = true
	ui.SetNext.TextYAlignment = Enum.TextYAlignment.Top
end

local function buildStage(canvas: Frame)
	glow(canvas, 800, 430, 360, C.Teal, 1)
	-- The floor: a soft pool of light under the feet and a thin bright line.
	for i = 1, 8 do
		local pool = frame(canvas, C.Teal, 0.975)
		pool.AnchorPoint = Vector2.new(0.5, 0.5)
		place(pool, 800, 714, 140 + i * 60, 10 + i * 7)
		pool.Position = UDim2.fromOffset(800, 714)
		round(pool, 9999)
	end
	local line = frame(canvas, C.Teal, 0.2)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	place(line, 800, 714, 520, 2)
	line.Position = UDim2.fromOffset(800, 714)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, line)
	local horizon = frame(canvas, C.Line, 0.95)
	place(horizon, 420, 650, 760, 1)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, horizon)
	ui.MinerView = new("ViewportFrame", {
		Name = "MinerView",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 165, 190),
		LightColor = Color3.fromRGB(235, 245, 255),
		LightDirection = Vector3.new(-0.5, -0.8, 0.6),
	}, canvas)
	place(ui.MinerView, 470, 80, 660, 650)
	ui.MinerSource = nil
end

-- One equipment row: art, name, rarity / slot / perk, and the gem socket.
local function buildRow(parent: Instance, slot: string, y: number)
	local row = new("TextButton", {
		Name = "Row" .. slot,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
	}, parent)
	place(row, 0, y, RIGHT_W, 72)
	round(row, 10)
	local tint = new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(20, 25, 34), Color3.fromRGB(11, 14, 21)),
		Transparency = NumberSequence.new(0.15, 0.55),
	}, row)
	local edge = stroke(row, C.Gold, 1, 1)
	local rail = frame(row, C.Text)
	place(rail, 0, 14, 3, 44)
	round(rail, 2)
	local well = frame(row, Color3.fromRGB(255, 255, 255), 0.96)
	place(well, 8, 6, 60, 60)
	round(well, 8)
	local art = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, well)
	local name = place(text(row, "", 15, C.Text, HEADING), 82, 16, RIGHT_W - 82 - 56, 20)
	local meta = place(text(row, "", 10, C.Dim, HEADING), 82, 40, RIGHT_W - 82 - 56, 14)
	meta.RichText = true
	local socket = frame(row, C.Ink, 0.4)
	socket.AnchorPoint = Vector2.new(1, 0.5)
	place(socket, RIGHT_W - 14, 36, 36, 36)
	socket.Position = UDim2.fromOffset(RIGHT_W - 14, 36)
	round(socket, 18)
	local ring = stroke(socket, C.Faint, 1.5, 0.3)
	local gemHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4) }, socket)
	local plus = text(socket, "+", 16, C.Faint, HEADING)
	plus.Size = UDim2.fromScale(1, 1)
	plus.TextXAlignment = Enum.TextXAlignment.Center
	row:SetAttribute("UiSound", "Click")
	row.Activated:Connect(function()
		if os.clock() < suppressClickUntil then
			return
		end
		if state.Detail ~= slot then
			openDetail(slot)
		end
	end)
	local entry = { Row = row, Tint = tint, Edge = edge, Rail = rail, Art = art, Name = name, Meta = meta, Ring = ring, Gem = gemHolder, Plus = plus }
	row.MouseEnter:Connect(function()
		entry.Hovered = true
		draw()
	end)
	row.MouseLeave:Connect(function()
		entry.Hovered = false
		draw()
	end)
	table.insert(dropTargets, {
		Frame = row,
		Stroke = edge,
		Accepts = function(item: Item)
			return item.Kind == "Gem" and loadoutNow()[slot] ~= nil
		end,
		Drop = function(item: Item)
			request("SocketGem", (item.Gem :: any).Id, slot)
		end,
	})
	return entry
end

local function buildRight(canvas: Frame)
	local column = new("Frame", { Name = "Equipment", BackgroundTransparency = 1 }, canvas)
	place(column, RIGHT_X, 96, RIGHT_W, 640)
	-- The list.
	local list = new("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, column)
	place(text(list, "EQUIPMENT", 11, C.Dim, HEADING), 0, 0, 200, 16)
	local hint = place(text(list, "CLICK TO CHANGE", 10, C.Faint, HEADING), RIGHT_W - 200, 0, 200, 16)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	ui.Rows = {}
	local y = 26
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots" } do
		ui.Rows[slot] = buildRow(list, slot, y)
		y += 80
	end
	local divider = frame(list, C.Line, 0.93)
	place(divider, 0, y + 4, RIGHT_W, 1)
	y += 14
	for _, slot in { "Weapon", "Shield" } do
		ui.Rows[slot] = buildRow(list, slot, y)
		y += 80
	end
	ui.List = list
	-- The detail (one piece, or one surge key).
	local detail = new("Frame", { Name = "Detail", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, column)
	ui.Detail = detail
	local crumb = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
	}, detail)
	place(crumb, 0, 0, RIGHT_W, 18)
	crumb:SetAttribute("UiSound", "Back")
	crumb.Activated:Connect(function()
		openDetail(nil)
	end)
	ui.Crumb = text(crumb, "", 11, C.Dim, HEADING)
	ui.Crumb.Size = UDim2.fromScale(1, 1)
	ui.Crumb.RichText = true
	-- The card: piece + gem (or the surge), and the perk.
	local card = frame(detail, Color3.fromRGB(255, 255, 255), 0.965)
	place(card, 0, 26, RIGHT_W, 262)
	round(card, 14)
	stroke(card, C.Line, 1, 0.92)
	ui.Card = card
	local function well(cx: number, circle: boolean)
		local holder = frame(card, C.Ink, 0.45)
		holder.AnchorPoint = Vector2.new(0.5, 0)
		place(holder, cx, 18, 100, 100)
		holder.Position = UDim2.fromOffset(cx, 18)
		round(holder, if circle then 50 else 12)
		local edge = stroke(holder, C.Line, if circle then 2 else 1, 0.85)
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12) }, holder)
		local empty = text(holder, "+", 30, C.Faint, HEADING)
		empty.Size = UDim2.fromScale(1, 1)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		local name = text(card, "", 14, C.Text, HEADING)
		name.AnchorPoint = Vector2.new(0.5, 0)
		place(name, cx, 126, 170, 18)
		name.Position = UDim2.fromOffset(cx, 126)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local sub = text(card, "", 10, C.Dim, HEADING)
		sub.AnchorPoint = Vector2.new(0.5, 0)
		place(sub, cx, 146, 180, 14)
		sub.Position = UDim2.fromOffset(cx, 146)
		sub.TextXAlignment = Enum.TextXAlignment.Center
		local tap = hit(holder)
		tap:SetAttribute("UiSound", "Click")
		return { Holder = holder, Edge = edge, Art = art, Empty = empty, Name = name, Sub = sub, Tap = tap }
	end
	ui.PieceWell = well(RIGHT_W * 0.27, false)
	ui.GemWell = well(RIGHT_W * 0.73, true)
	ui.PieceWell.Tap.Activated:Connect(function()
		if state.Detail and not table.find(KEYS, state.Detail) then
			state.Tab, state.Pick, state.Hover = "Pieces", nil, nil
			draw()
		end
	end)
	ui.GemWell.Tap.Activated:Connect(function()
		state.Tab, state.Pick, state.Hover = "Gems", nil, nil
		draw()
	end)
	ui.Plus = text(card, "+", 18, C.Faint, HEADING)
	ui.Plus.AnchorPoint = Vector2.new(0.5, 0.5)
	place(ui.Plus, RIGHT_W / 2, 68, 30, 30)
	ui.Plus.Position = UDim2.fromOffset(RIGHT_W / 2, 68)
	ui.Plus.TextXAlignment = Enum.TextXAlignment.Center
	-- The surge view (a key): one big icon on the left, words on the right.
	ui.SurgeIcon = frame(card, C.Ink, 0.4)
	place(ui.SurgeIcon, 18, 18, 100, 100)
	round(ui.SurgeIcon, 14)
	ui.SurgeIconEdge = stroke(ui.SurgeIcon, C.Line, 1.5, 0.6)
	ui.SurgeGlyph = text(ui.SurgeIcon, "", 34, C.Faint, HEADING)
	ui.SurgeGlyph.Size = UDim2.fromScale(1, 1)
	ui.SurgeGlyph.TextXAlignment = Enum.TextXAlignment.Center
	ui.SurgeName = place(text(card, "", 18, C.Text, HEAVY), 134, 30, RIGHT_W - 150, 24)
	ui.SurgeMeta = place(text(card, "", 10, C.Dim, HEADING), 134, 58, RIGHT_W - 150, 14)
	ui.SurgeMeta.RichText = true
	ui.SurgeGem = place(text(card, "", 11, C.Dim, HEADING), 134, 80, RIGHT_W - 150, 30)
	ui.SurgeGem.TextWrapped = true
	ui.SurgeGem.TextYAlignment = Enum.TextYAlignment.Top
	-- The perk band (or the surge's description).
	local rule = frame(card, C.Line, 0.92)
	place(rule, 18, 170, RIGHT_W - 36, 1)
	ui.PerkName = place(text(card, "", 10, C.Gold, HEADING), 18, 182, RIGHT_W - 36, 14)
	ui.PerkText = place(text(card, "", 12, C.Dim, BODY), 18, 198, RIGHT_W - 36, 30)
	ui.PerkText.TextWrapped = true
	ui.PerkText.TextYAlignment = Enum.TextYAlignment.Top
	ui.PerkValue = place(text(card, "", 18, C.Good, HEAVY), 18, 228, RIGHT_W - 36, 26)
	ui.PerkValue.RichText = true
	-- Tabs and the element filter.
	ui.Tabs = new("Frame", { BackgroundTransparency = 1 }, detail)
	place(ui.Tabs, 0, 302, 230, 24)
	ui.Filters = new("Frame", { BackgroundTransparency = 1 }, detail)
	place(ui.Filters, RIGHT_W - 150, 302, 150, 24)
	-- The grid.
	ui.Grid = new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Faint,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, detail)
	place(ui.Grid, 0, 334, RIGHT_W, 156)
	-- What a pick (or the hovered one) would change, and the buttons.
	ui.Compare = frame(detail, C.Gold, 0.93)
	place(ui.Compare, 0, 500, RIGHT_W, 64)
	round(ui.Compare, 10)
	ui.CompareEdge = stroke(ui.Compare, C.Gold, 1, 0.75)
	ui.CompareText = text(ui.Compare, "", 12, C.Dim, MEDIUM)
	ui.CompareText.Position = UDim2.fromOffset(14, 8)
	ui.CompareText.Size = UDim2.new(1, -28, 1, -16)
	ui.CompareText.TextWrapped = true
	ui.CompareText.RichText = true
	ui.CompareText.TextYAlignment = Enum.TextYAlignment.Top
	local function button(x: number, w: number, primary: boolean)
		local b = new("TextButton", {
			Text = "",
			TextSize = 12,
			Font = HEADING,
			AutoButtonColor = true,
			TextColor3 = if primary then Color3.fromRGB(26, 18, 6) else C.Dim,
			BackgroundColor3 = if primary then C.Gold else C.Ink,
			BackgroundTransparency = if primary then 0 else 0.5,
		}, detail)
		place(b, x, 576, w, 44)
		round(b, 10)
		if not primary then
			stroke(b, C.Faint, 1, 0.2)
		end
		return b
	end
	ui.Primary = button(0, 250, true)
	ui.Primary:SetAttribute("UiSound", "Confirm")
	ui.Secondary = button(262, RIGHT_W - 262, false)
	ui.Secondary:SetAttribute("UiSound", "Back")
	ui.Primary.Activated:Connect(function()
		local pick = state.Pick
		local target = state.Detail
		if not pick or not target then
			return
		end
		if table.find(KEYS, target) then
			request("SocketSurge", (pick.Gem :: any).Id, target)
		elseif pick.Kind == "Gem" then
			request("SocketGem", (pick.Gem :: any).Id, target)
		elseif pick.Kind == "Piece" then
			request("EquipGear", Slots.Definitions[pick.Slot :: string].Kind, pick.Id)
		end
		state.Pick, state.Hover = nil, nil
		draw()
	end)
	ui.Secondary.Activated:Connect(function()
		local target = state.Detail
		if state.Pick then
			state.Pick, state.Hover = nil, nil
			draw()
		elseif target and table.find(KEYS, target) then
			request("UnsocketSurge", target)
		elseif target then
			request("UnsocketGem", target)
		end
	end)
end

-- Q / E / R.
local function buildSurges(canvas: Frame)
	ui.Keys = {}
	local cardW, gap = 230, 14
	local x0 = 800 - (3 * cardW + 2 * gap) / 2
	for i, key in KEYS do
		local card = new("TextButton", {
			Name = "Key" .. key,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(10, 14, 22),
			BackgroundTransparency = 0.2,
		}, canvas)
		place(card, x0 + (i - 1) * (cardW + gap), 750, cardW, 66)
		round(card, 12)
		local edge = stroke(card, C.Line, 1, 0.9)
		local icon = frame(card, C.Ink, 0.3)
		place(icon, 9, 9, 48, 48)
		round(icon, 9)
		local glyph = text(icon, "+", 18, C.Faint, HEADING)
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.TextXAlignment = Enum.TextXAlignment.Center
		local name = place(text(card, "", 14, C.Text, HEADING), 68, 14, cardW - 80, 18)
		local info = place(text(card, "", 10, C.Dim, MEDIUM), 68, 36, cardW - 80, 14)
		local badge = text(card, key, 11, C.Text, HEAVY)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.5, 0, 0, 0)
		badge.Size = UDim2.fromOffset(24, 18)
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = C.Ink
		round(badge, 5)
		stroke(badge, C.Faint, 1, 0)
		local line = frame(card, C.Faint)
		line.AnchorPoint = Vector2.new(0, 1)
		line.Position = UDim2.new(0, 16, 1, 0)
		line.Size = UDim2.new(1, -32, 0, 2)
		round(line, 1)
		card:SetAttribute("UiSound", "Click")
		card.Activated:Connect(function()
			if os.clock() < suppressClickUntil then
				return
			end
			if state.Detail ~= key then
				openDetail(key)
			end
		end)
		table.insert(dropTargets, {
			Frame = card,
			Stroke = edge,
			Accepts = function(item: Item)
				return item.Kind == "Gem" and Tech.surgeStats(item.Gem) ~= nil
			end,
			Drop = function(item: Item)
				request("SocketSurge", (item.Gem :: any).Id, key)
			end,
		})
		ui.Keys[key] = { Card = card, Edge = edge, Icon = icon, Glyph = glyph, Name = name, Info = info, Line = line }
	end
end

-- Drag and drop ----------------------------------------------------------------------------------------
-- (as in the first Inventory: mouse in screen space, touch as reported)

local function pointOf(input: InputObject, touch: boolean): Vector2
	return if touch then Vector2.new(input.Position.X, input.Position.Y) else UserInputService:GetMouseLocation()
end
local function targetAt(point: Vector2, item: Item)
	for _, target in dropTargets do
		local f = target.Frame
		local p, s = f.AbsolutePosition, f.AbsoluteSize
		if f.Visible and target.Accepts(item) and point.X >= p.X and point.Y >= p.Y and point.X < p.X + s.X and point.Y < p.Y + s.Y then
			return target
		end
	end
	return nil
end
local function lightTargets(item: Item?)
	for _, target in dropTargets do
		if target.Base == nil then
			target.Base = { target.Stroke.Color, target.Stroke.Transparency, target.Stroke.Thickness }
		end
		local ok = item ~= nil and target.Accepts(item)
		target.Stroke.Color = if ok then C.Gold else target.Base[1]
		target.Stroke.Transparency = if ok then 0.1 else target.Base[2]
		target.Stroke.Thickness = if ok then 2 else target.Base[3]
	end
	if item == nil then
		for _, target in dropTargets do
			target.Base = nil
		end
	end
end
function InventoryV2.cancelDrag()
	if drag and drag.Ghost then
		drag.Ghost:Destroy()
	end
	local was = drag ~= nil
	drag = nil
	if was then
		lightTargets(nil)
	end
	if gui then
		draw()
	end
end
local function startDrag(item: Item, input: InputObject)
	local touch = input.UserInputType == Enum.UserInputType.Touch
	drag = { Item = item, Start = pointOf(input, touch), Active = false, Touch = touch } :: any
end
UserInputService.InputChanged:Connect(function(input)
	local current = drag :: any
	if not current or not gui then
		return
	end
	local moving = input.UserInputType == Enum.UserInputType.MouseMovement
		or (current.Touch and input.UserInputType == Enum.UserInputType.Touch)
	if not moving then
		return
	end
	local point = pointOf(input, current.Touch)
	if not current.Active then
		if (point - current.Start).Magnitude < 8 then
			return
		end
		current.Active = true
		local ghost = frame(gui, C.Ink, 0.15)
		ghost.Name = "V2DragGhost"
		ghost.Size = UDim2.fromOffset(60, 60)
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.ZIndex = 50
		round(ghost, 30)
		stroke(ghost, C.Gold, 2, 0)
		local art = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 51 }, ghost)
		if current.Item.Gem then
			gemArt(art, current.Item.Gem)
		end
		current.Ghost = ghost
		lightTargets(current.Item)
	end
	if current.Ghost then
		current.Ghost.Position = UDim2.fromOffset(point.X, point.Y - (if current.Touch then 40 else 0))
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local current = drag :: any
	if not current then
		return
	end
	local ending = input.UserInputType == Enum.UserInputType.MouseButton1
		or (current.Touch and input.UserInputType == Enum.UserInputType.Touch)
	if not ending then
		return
	end
	drag = nil
	if current.Ghost then
		current.Ghost:Destroy()
	end
	lightTargets(nil)
	if current.Active then
		suppressClickUntil = os.clock() + 0.25
		local target = targetAt(pointOf(input, current.Touch), current.Item)
		if target then
			target.Drop(current.Item)
		end
	end
	draw()
end)

-- Draw -------------------------------------------------------------------------------------------------

local function renderMiner(view: ViewportFrame, source: Model, loadout)
	view:ClearAllChildren()
	local world = new("WorldModel", {}, view)
	local copy = source:Clone()
	copy.Parent = world
	copy:PivotTo(CFrame.new())
	local armor = loadout and ArmorFamilies.ById[loadout.Armor]
	pcall(InventoryPose.apply, copy, armor and armor.ArmorFamily)
	local bounds, size = copy:GetBoundingBox()
	local camera = new("Camera", { FieldOfView = 30 }, view)
	local distance = math.max(size.Y * 0.62, size.X * 0.9) / math.tan(math.rad(15))
	camera.CFrame = CFrame.lookAt(
		bounds.Position + Vector3.new(distance * 0.12, size.Y * 0.04, -distance),
		bounds.Position
	)
	view.CurrentCamera = camera
end

local function flashValue(entry, value: number)
	local before = entry.Last
	entry.Last = value
	if before == nil or math.abs(value - before) < 0.5 then
		return
	end
	entry.Value.TextColor3 = if value > before then C.Good else C.Bad
	TweenService:Create(entry.Value, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { TextColor3 = C.Text }):Play()
end

local SET_WORDS = {
	Health = "%s HP",
	Power = "%s Power",
	Defense = "%s Defense",
	Speed = "%s Speed",
	Critical = "%s%% crit",
	Cooldown = "%s%% cooldown",
	HealingReceived = "%s%% healing",
	DamageAfterDodge = "%s%% damage after a dodge",
	DamageReduction = "%s%% damage taken",
	ThreatGeneration = "%s%% threat",
}
local SET_PERCENT = { Critical = true, Cooldown = true, HealingReceived = true, DamageAfterDodge = true, DamageReduction = true, ThreatGeneration = true }
local function setWords(bonus): string
	local parts = {}
	for stat, amount in bonus or {} do
		local shown = if SET_PERCENT[stat] then amount * 100 else amount
		local sign = if stat == "DamageReduction" or stat == "Cooldown" then "−" else "+"
		table.insert(parts, string.format(SET_WORDS[stat] or ("%s " .. stat), sign .. tostring(math.floor(shown * 10 + 0.5) / 10)))
	end
	table.sort(parts)
	return table.concat(parts, "  ·  ")
end

local function drawLeft(profile, loadout)
	local roster = profile.Miners
	local active = roster and roster.Active or 1
	for index, m in ui.Miners do
		local on = index == active
		m.Button.BackgroundTransparency = if on then 0 else 1
		m.Button.TextColor3 = if on then Color3.fromRGB(26, 18, 6) else C.Faint
		m.Edge.Transparency = if on then 1 else 0.88
	end
	ui.Name.Text = string.upper(player.DisplayName)
	local level = Tree.level(profile.Augments and profile.Augments.XP or 0)
	ui.Sub.Text = string.format("MINER %d  ·  LEVEL %d", active, level)
	local r = ratings(loadout)
	local total = 0
	for _, stat in Classes.StatNames do
		local value = if r then r[stat].Base + r[stat].Bonus else 0
		total += value
		local entry = ui.Stats[stat]
		entry.Value.Text = whole(value)
		entry.Fill.Size = UDim2.fromScale(math.clamp(value / 140, 0, 1), 1)
		flashValue(entry, value)
	end
	ui.Rating.Text = whole(total)
	-- The set you wear most of.
	local best, count = nil, 0
	local ok, setState = pcall(Classes.setState, loadout)
	for _, family in ArmorFamilies.Order do
		local s = ok and setState.Active[family]
		if s and s.Count > count then
			best, count = family, s.Count
		end
	end
	local color = if best then ArmorFamilies.Families[best].Color else C.Dim
	ui.SetName.Text = if best then string.upper(best) .. " SET" else "NO ARMOR SET"
	ui.SetName.TextColor3 = color
	for i, pip in ui.Pips do
		pip.BackgroundColor3 = if i <= count then color else C.Line
		pip.BackgroundTransparency = if i <= count then 0 else 0.9
	end
	if best then
		local sets = ArmorFamilies.Sets[best]
		local tier = if count >= 6 then 6 elseif count >= 4 then 4 elseif count >= 2 then 2 else nil
		ui.SetBonus.Text = if tier then setWords(sets[tier]) else "No bonus yet"
		ui.SetBonus.TextColor3 = if tier then C.Text else C.Dim
		local nextTier = if count < 2 then 2 elseif count < 4 then 4 elseif count < 6 then 6 else nil
		ui.SetNext.Text = if nextTier
			then string.format("Wear %d for %s.", nextTier, setWords(sets[nextTier]))
			else "Full set: every bonus is on."
	else
		ui.SetBonus.Text = ""
		ui.SetNext.Text = "Wear two pieces of one family for a set bonus."
	end
	-- The miner.
	local store = player.PlayerGui:FindFirstChild("MinerPreviews")
	local source = store and store:FindFirstChild(tostring(active))
	if source and source:IsA("Model") and ui.MinerSource ~= source then
		ui.MinerSource = source
		renderMiner(ui.MinerView, source, loadout)
	elseif not (source and source:IsA("Model")) and not ui.PreviewAsked then
		-- No mannequin yet: ask the server for the three (as the first Inventory does).
		ui.PreviewAsked = true
		task.spawn(function()
			pcall(GemClient.request, "MinerPreviews")
			task.wait(5)
			ui.PreviewAsked = false
		end)
	end
end

local function drawWallet(profile)
	ui.Coins.Text = commas(profile.Coins or 0)
	local seasonData = profile.Season or { XP = 0 }
	local level, into, need = Season.levelFor(seasonData.XP or 0)
	ui.Season.Text = "LV " .. level
	ui.SeasonFill.Size = UDim2.fromScale(if level >= Season.MaxLevel then 1 else math.clamp(into / need, 0, 1), 1)
	local outpost = profile.Outpost
	local charged, nextIn = ChargeMeter.read(outpost and outpost.Picks, outpost and outpost.SurveyAt)
	ui.Pick.Text = string.format("%d/%d", charged, ChargeMeter.Full)
	ui.PickCap.Text = if nextIn then "FREE PICK  ·  " .. OutpostRules.clock(nextIn) else "FREE PICK  ·  FULL"
end

local function drawRows(loadout)
	for slot, row in ui.Rows do
		local id = loadout[slot]
		local gear = gearOf(loadout, slot)
		local gem = loadout[slot .. "Gem"]
		local rarity = if gear then rarityOf(loadout, slot) else 1
		local color = rarityColor(rarity)
		local picked = state.Detail == slot
		row.Name.Text = if gear then gear.Name else "Empty"
		row.Name.TextColor3 = if gear then C.Text else C.Faint
		local signature = gear and perkOf(loadout, slot, nil, gem)
		local tail = if signature then "  ·  " .. string.upper(signature.Definition.Name)
			elseif gear and gear.BuffReady and gear.Passive and gear.Passive.Name and gear.Passive.Name ~= "Signature" then "  ·  " .. string.upper(gear.Passive.Name)
			else ""
		row.Meta.Text = if gear
			then string.format('<font color="#%s">%s</font>  ·  %s%s', color:ToHex(), rarityName(rarity), SLOT_NAME[slot], tail)
			else SLOT_NAME[slot] .. "  ·  NOTHING WORN"
		row.Rail.BackgroundColor3 = if picked then C.Gold else color
		row.Edge.Transparency = if picked then 0.35 elseif row.Hovered then 0.8 else 1
		row.Tint.Color = if picked
			then ColorSequence.new(Color3.fromRGB(58, 46, 22), Color3.fromRGB(16, 14, 12))
			elseif row.Hovered then ColorSequence.new(Color3.fromRGB(30, 37, 50), Color3.fromRGB(13, 17, 25))
			else ColorSequence.new(Color3.fromRGB(20, 25, 34), Color3.fromRGB(11, 14, 21))
		local artKey = tostring(id) .. "|" .. tostring(row.ArtVersion or 0)
		if row.ArtKey ~= artKey then
			row.ArtKey = artKey
			if id then
				gearArt(row.Art, slot, id, true, color)
			else
				clear(row.Art)
			end
		end
		local gemKey = if gem then gem.Id .. ":" .. tostring(gem.Cut) else ""
		if row.GemKey ~= gemKey then
			row.GemKey = gemKey
			clear(row.Gem)
			if gem then
				gemArt(row.Gem, gem)
			end
		end
		row.Plus.Visible = gem == nil
		row.Ring.Color = if gem then gemColor(gem) else C.Faint
		row.Ring.Transparency = if gem then 0.1 else 0.5
	end
end

local function drawKeys(loadout)
	for _, key in KEYS do
		local entry = ui.Keys[key]
		local gem = Tech.surgeGem(loadout, key)
		local surge = gem and Tech.surgeStats(gem)
		local tint = if gem then gemColor(gem) else C.Faint
		local picked = state.Detail == key
		entry.Name.Text = if surge then surge.Name else "Add a surge"
		entry.Name.TextColor3 = if surge then C.Text else C.Dim
		entry.Info.Text = if surge
			then string.format("%s charge  ·  %s s", whole(surge.Cost or 0), whole(surge.Cooldown or 0))
			else "Click to pick a gem"
		entry.Line.BackgroundColor3 = tint
		entry.Line.BackgroundTransparency = if gem then 0.15 else 0.7
		entry.Edge.Color = if picked then C.Gold else C.Line
		entry.Edge.Transparency = if picked then 0.2 else 0.9
		local shown = if gem then gem.Id else ""
		if entry.Shown ~= shown then
			entry.Shown = shown
			entry.Glyph.Text = if surge then "◆" else "+"
			entry.Glyph.TextColor3 = tint
			if surge then
				SurgeIcons.apply(entry.Glyph, surge, tint)
			else
				local art = entry.Glyph:FindFirstChild("AbilityArt")
				if art then
					art:Destroy()
				end
			end
		end
	end
end

-- The grid: gems (for a gear slot or a key) or spare pieces (for a gear slot).
local gridKey = ""
local function drawGrid(items: { Item }, emptyText: string)
	local parts = { state.Detail or "", state.Tab, state.Filter, state.Pick and (state.Pick.Id or (state.Pick.Gem and state.Pick.Gem.Id)) or "" }
	for _, item in items do
		table.insert(parts, item.Id or (item.Gem and item.Gem.Id .. ":" .. tostring(item.Gem.Cut)) or "")
	end
	local key = table.concat(parts, ",")
	if key == gridKey then
		return
	end
	gridKey = key
	clear(ui.Grid)
	if #items == 0 then
		local note = text(ui.Grid, emptyText, 12, C.Faint, MEDIUM)
		note.Size = UDim2.new(1, 0, 0, 60)
		note.TextWrapped = true
		note.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	local layout = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(70, 70),
		CellPadding = UDim2.fromOffset(9, 9),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, ui.Grid)
	local _ = layout
	for order, item in items do
		local cell = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.965,
			LayoutOrder = order,
		}, ui.Grid)
		round(cell, 10)
		local picked = sameItem(item, state.Pick)
		local edge = stroke(cell, if picked then C.Gold else C.Line, if picked then 1.5 else 1, if picked then 0 else 0.92)
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 7), Size = UDim2.new(1, -18, 1, -18) }, cell)
		local tierColor
		if item.Kind == "Gem" then
			gemArt(art, item.Gem)
			tierColor = rarityColor(gemRarity(item.Gem))
		else
			gearArt(art, item.Slot :: string, item.Id :: string, false, rarityColor(rarityOf(loadoutNow(), item.Slot :: string, item.Id)))
			tierColor = rarityColor(rarityOf(loadoutNow(), item.Slot :: string, item.Id))
		end
		local tier = frame(cell, tierColor)
		tier.AnchorPoint = Vector2.new(0, 1)
		tier.Position = UDim2.new(0, 10, 1, -5)
		tier.Size = UDim2.new(1, -20, 0, 2)
		round(tier, 1)
		cell:SetAttribute("UiSound", "Click")
		cell.MouseEnter:Connect(function()
			state.Hover = item
			if not picked then
				edge.Transparency = 0.6
			end
			InventoryV2.drawCompare()
		end)
		cell.MouseLeave:Connect(function()
			if sameItem(state.Hover, item) then
				state.Hover = nil
			end
			if not picked then
				edge.Transparency = 0.92
			end
			InventoryV2.drawCompare()
		end)
		cell.InputBegan:Connect(function(input)
			if item.Kind == "Gem" and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				startDrag(item, input)
			end
		end)
		cell.Activated:Connect(function()
			if os.clock() < suppressClickUntil then
				return
			end
			state.Pick = item
			draw()
		end)
	end
end

local function drawTabs(entries: { { string } })
	local key = table.concat({ state.Tab, state.Detail or "", tostring(#entries) }, "|")
	if ui.TabsKey == key then
		return
	end
	ui.TabsKey = key
	clear(ui.Tabs)
	local list = UiKit.list(ui.Tabs, 22, true)
	local _ = list
	for order, entry in entries do
		local on = entry[1] == state.Tab
		local b = new("TextButton", {
			Text = entry[2],
			TextSize = 11,
			Font = HEADING,
			TextColor3 = if on then C.Text else C.Faint,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			LayoutOrder = order,
		}, ui.Tabs)
		b:SetAttribute("UiSound", "Tab")
		if on then
			local bar = frame(b, C.Gold)
			bar.AnchorPoint = Vector2.new(0, 1)
			bar.Position = UDim2.fromScale(0, 1)
			bar.Size = UDim2.new(1, 0, 0, 2)
		end
		b.Activated:Connect(function()
			state.Tab, state.Pick, state.Hover = entry[1], nil, nil
			draw()
		end)
	end
end

local function drawFilters(show: boolean)
	ui.Filters.Visible = show
	local key = state.Filter
	if ui.FiltersKey == key then
		return
	end
	ui.FiltersKey = key
	clear(ui.Filters)
	local list = UiKit.list(ui.Filters, 8, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local all = new("TextButton", {
		Text = "ALL",
		TextSize = 10,
		Font = HEADING,
		TextColor3 = if state.Filter == "All" then C.Text else C.Faint,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(28, 22),
		LayoutOrder = 0,
	}, ui.Filters)
	all.Activated:Connect(function()
		state.Filter = "All"
		draw()
	end)
	for order, element in ELEMENTS do
		local on = state.Filter == element
		local dot = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = GemConfig.ElementColors[element] or C.Text,
			BackgroundTransparency = if state.Filter == "All" or on then 0 else 0.65,
			Size = UDim2.fromOffset(if on then 16 else 12, if on then 16 else 12),
			LayoutOrder = order,
		}, ui.Filters)
		round(dot, 8)
		if on then
			stroke(dot, C.Text, 1.5, 0)
		end
		dot:SetAttribute("UiSound", "Tab")
		dot.Activated:Connect(function()
			state.Filter = if on then "All" else element
			draw()
		end)
	end
end

-- The words in the compare box, and the two buttons.
function InventoryV2.drawCompare()
	if not ui.Compare then
		return
	end
	local target = state.Detail
	local loadout = loadoutNow()
	local item = state.Hover or state.Pick
	local good, bad = C.Good:ToHex(), C.Bad:ToHex()
	local textValue
	if not target then
		return
	elseif table.find(KEYS, target) then
		local current = Tech.surgeGem(loadout, target)
		if item and item.Gem then
			local surge = Tech.surgeStats(item.Gem)
			textValue = if surge
				then string.format(
					"<b>%s</b> on %s: %s charge · %s s cooldown. %s",
					surge.Name,
					target,
					whole(surge.Cost or 0),
					whole(surge.Cooldown or 0),
					surge.Description or ""
				)
				else "This gem has no surge."
		else
			textValue = if current then "Pick a gem below to change " .. target .. ", or drag one onto any key." else "Pick a gem below to put a surge on " .. target .. "."
		end
	else
		local wornGem = loadout[target .. "Gem"]
		local current = perkOf(loadout, target, nil, wornGem)
		if item and item.Kind == "Gem" then
			local after = perkOf(loadout, target, nil, item.Gem)
			if after and current and after.Id == current.Id then
				local diff = after.Value - current.Value
				local d = after.Definition
				local diffText = if d.Percent then string.format("%+.1f%%", diff * 100) else string.format("%+.1f", diff)
				textValue = string.format(
					'<b>%s</b> instead: %s <b>%s</b> <font color="#%s">(%s)</font>%s',
					gemName(item.Gem),
					string.lower(d.Name),
					perkValue(after),
					if diff >= -1e-6 then good else bad,
					diffText,
					if wornGem then ". " .. gemName(wornGem) .. " goes back to your stash." else "."
				)
			else
				local lines = {}
				for _, l in GemConfig.lines(item.Gem, target) do
					table.insert(lines, l.Text)
				end
				textValue = string.format("<b>%s</b> enchants it: %s", gemName(item.Gem), table.concat(lines, " · "))
			end
		elseif item and item.Kind == "Piece" then
			local gain = ratingGain(loadout, target, item.Id :: string)
			local itsGem = loadout.ItemGems and loadout.ItemGems[target] and loadout.ItemGems[target][item.Id]
			local after = perkOf(loadout, target, item.Id, itsGem)
			textValue = string.format(
				'<b>%s</b>: rating <font color="#%s">%s%d</font>%s. Gems stay on their piece.',
				item.Gear and item.Gear.Name or "This piece",
				if gain >= 0 then good else bad,
				if gain >= 0 then "+" else "",
				gain,
				if after then ", perk " .. after.Definition.Name .. " " .. perkValue(after) else ""
			)
		else
			textValue = if state.Tab == "Pieces"
				then "Pick a spare piece to compare it with what you wear."
				else "Pick a gem below, or drag one onto any piece."
		end
	end
	ui.CompareText.Text = textValue
	local picking = state.Pick ~= nil
	ui.Compare.BackgroundTransparency = if item then 0.93 else 0.97
	ui.CompareEdge.Transparency = if item then 0.7 else 0.92
	-- Buttons.
	local hasGem = if table.find(KEYS, target) then Tech.surgeGem(loadout, target) ~= nil else loadout[target .. "Gem"] ~= nil
	if picking then
		local pick = state.Pick :: Item
		ui.Primary.Visible = true
		ui.Primary.Text = if pick.Kind == "Piece"
			then "EQUIP"
			elseif table.find(KEYS, target) then "SET ON " .. target
			else "SOCKET " .. string.upper(gemName(pick.Gem))
		ui.Secondary.Visible = true
		ui.Secondary.Text = "KEEP CURRENT"
	else
		ui.Primary.Visible = false
		ui.Secondary.Visible = hasGem
		ui.Secondary.Text = if table.find(KEYS, target) then "CLEAR " .. target else "REMOVE GEM"
	end
	ui.Secondary.Position = if ui.Primary.Visible then UDim2.fromOffset(262, 576) else UDim2.fromOffset(0, 576)
	ui.Secondary.Size = if ui.Primary.Visible then UDim2.fromOffset(RIGHT_W - 262, 44) else UDim2.fromOffset(RIGHT_W, 44)
end

local function drawDetail(loadout)
	local target = state.Detail
	ui.List.Visible = target == nil
	ui.Detail.Visible = target ~= nil
	if not target then
		return
	end
	local isKey = table.find(KEYS, target) ~= nil
	for _, name in { "PieceWell", "GemWell" } do
		ui[name].Holder.Visible = not isKey
		ui[name].Name.Visible = not isKey
		ui[name].Sub.Visible = not isKey
	end
	ui.Plus.Visible = not isKey
	ui.SurgeIcon.Visible = isKey
	ui.SurgeName.Visible = isKey
	ui.SurgeMeta.Visible = isKey
	ui.SurgeGem.Visible = isKey
	if isKey then
		ui.Crumb.Text = string.format('‹  <font color="#%s">SURGE %s</font>', C.Text:ToHex(), target)
		local gem = Tech.surgeGem(loadout, target)
		local surge = gem and Tech.surgeStats(gem)
		local tint = if gem then gemColor(gem) else C.Faint
		ui.SurgeName.Text = if surge then surge.Name else "No surge on " .. target
		ui.SurgeMeta.Text = if surge
			then string.format('<font color="#%s">%s</font>  ·  %s CHARGE  ·  %s S', tint:ToHex(), string.upper(GemConfig.elementName(gem.Element)), whole(surge.Cost or 0), whole(surge.Cooldown or 0))
			else "PICK A GEM BELOW"
		ui.SurgeGem.Text = if gem then "From " .. GemConfig.displayName(gem) else ""
		ui.SurgeIconEdge.Color = tint
		local shown = if gem then gem.Id else ""
		if ui.SurgeShown ~= shown then
			ui.SurgeShown = shown
			ui.SurgeGlyph.Text = if surge then "◆" else "+"
			ui.SurgeGlyph.TextColor3 = tint
			local art = ui.SurgeGlyph:FindFirstChild("AbilityArt")
			if art then
				art:Destroy()
			end
			if surge then
				SurgeIcons.apply(ui.SurgeGlyph, surge, tint)
			end
		end
		ui.PerkName.Text = if surge then "WHAT IT DOES" else ""
		ui.PerkText.Text = if surge then surge.Description or "" else "Surges are cast with Q, E and R in a fight. Any cut gem with a surge fits."
		ui.PerkText.Size = UDim2.fromOffset(RIGHT_W - 36, 60)
		ui.PerkValue.Text = ""
		drawTabs({ { "Gems", "SURGE GEMS" } })
		drawFilters(true)
		local items = {}
		for _, g in gemsFor(true, state.Filter) do
			table.insert(items, { Kind = "Gem", Gem = g })
		end
		drawGrid(items, "No surge gems yet. Cut a gem at the Outpost to unlock its surge.")
	else
		local slot = target
		local gear = gearOf(loadout, slot)
		local gem = loadout[slot .. "Gem"]
		local rarity = if gear then rarityOf(loadout, slot) else 1
		local color = rarityColor(rarity)
		ui.Crumb.Text = string.format(
			'‹  <font color="#%s">%s</font>  ·  %s',
			C.Text:ToHex(),
			SLOT_NAME[slot],
			string.upper(gear and gear.Name or "nothing worn")
		)
		-- The piece.
		local well = ui.PieceWell
		local pieceKey = tostring(loadout[slot]) .. "|" .. tostring(ui.ArtVersion or 0)
		if well.Key ~= pieceKey then
			well.Key = pieceKey
			if loadout[slot] then
				gearArt(well.Art, slot, loadout[slot], true, color)
			else
				clear(well.Art)
			end
		end
		well.Empty.Visible = gear == nil
		well.Edge.Color = if state.Tab == "Pieces" then C.Gold else color
		well.Edge.Transparency = if state.Tab == "Pieces" then 0.2 else 0.5
		well.Name.Text = if gear then gear.Name else "Nothing worn"
		local roll = GearRolls.get(loadout, slot)
		local stat = topStat(roll)
		well.Sub.Text = if gear then rarityName(rarity) .. (if stat then "  ·  " .. string.upper(stat) else "") else "PICK ONE BELOW"
		well.Sub.TextColor3 = color
		-- The gem.
		local gw = ui.GemWell
		local gemKey = if gem then gem.Id .. ":" .. tostring(gem.Cut) else ""
		if gw.Key ~= gemKey then
			gw.Key = gemKey
			clear(gw.Art)
			if gem then
				gemArt(gw.Art, gem)
			end
		end
		gw.Empty.Visible = gem == nil
		gw.Edge.Color = if gem then gemColor(gem) else C.Line
		gw.Edge.Transparency = if gem then 0 else 0.85
		gw.Name.Text = if gem then gemName(gem) else "Empty socket"
		gw.Sub.Text = if gem
			then string.upper(GemConfig.elementName(gem.Element)) .. "  ·  " .. rarityName(gemRarity(gem))
			else "ENCHANTING IS PURE GAIN"
		gw.Sub.TextColor3 = if gem then gemColor(gem) else C.Dim
		-- The perk.
		local signature = gear and perkOf(loadout, slot, nil, gem)
		ui.PerkText.Size = UDim2.fromOffset(RIGHT_W - 36, 30)
		ui.PerkValue.TextSize = 18
		ui.PerkValue.TextWrapped = false
		if signature then
			local d = signature.Definition
			ui.PerkName.Text = string.upper(d.Name)
			ui.PerkText.Text = d.Trigger
			if gem and signature.Value > signature.Base + 1e-6 then
				ui.PerkValue.Text = string.format(
					'<font color="#%s">%s</font>  <font color="#%s">→</font>  %s',
					C.Dim:ToHex(),
					perkBase(signature),
					C.Faint:ToHex(),
					perkValue(signature)
				)
			else
				ui.PerkValue.Text = string.format('%s  <font color="#%s">· add a gem to strengthen it</font>', perkValue(signature), C.Faint:ToHex())
			end
		elseif gear then
			local passive = gear.Passive
			local planned = not gear.BuffReady or (passive and passive.Name == "Signature")
			ui.PerkName.Text = if planned then "ENCHANTMENT" else string.upper(passive and passive.Name or "PERK")
			ui.PerkText.Text = if planned then "What a gem socketed here adds." else passive and passive.Text or ""
			if gem then
				local lines = {}
				for _, l in GemConfig.lines(gem, slot) do
					table.insert(lines, l.Text)
				end
				ui.PerkValue.Text = string.format('<font color="#%s">%s</font>', gemColor(gem):ToHex(), table.concat(lines, "  ·  "))
				ui.PerkValue.TextSize = 13
				ui.PerkValue.TextWrapped = true
			else
				ui.PerkValue.Text = string.format('<font color="#%s">Add a gem to enchant it</font>', C.Faint:ToHex())
				ui.PerkValue.TextSize = 13
			end
		else
			ui.PerkName.Text = ""
			ui.PerkText.Text = "Nothing worn here. Pick a spare piece below."
			ui.PerkValue.Text = ""
		end
		drawTabs({ { "Gems", "GEMS" }, { "Pieces", SLOT_NAME[slot] .. " PIECES" } })
		drawFilters(state.Tab == "Gems")
		local items = {}
		if state.Tab == "Pieces" then
			for _, spare in sparesFor(slot) do
				table.insert(items, { Kind = "Piece", Slot = slot, Id = spare.Id, Gear = spare.Gear } :: any)
			end
			if #items > 0 then
				task.spawn(function()
					pcall(GemClient.request, "GearPreviews")
				end)
			end
			drawGrid(items, "No spare " .. string.lower(SLOT_NAME[slot]) .. " pieces. Mine and trade for more.")
		else
			for _, g in gemsFor(false, state.Filter) do
				table.insert(items, { Kind = "Gem", Gem = g })
			end
			drawGrid(items, "No cut gems yet. Mine the Outpost and cut what you find.")
		end
	end
	InventoryV2.drawCompare()
end

local queued = false
function draw()
	if queued then
		return
	end
	queued = true
	task.defer(function()
		queued = false
		local profile = profileNow()
		if not state.Active or not gui or not gui.Enabled or not profile or (drag and drag.Active) then
			return
		end
		local loadout = profile.Character or {}
		drawWallet(profile)
		drawLeft(profile, loadout)
		drawRows(loadout)
		drawKeys(loadout)
		drawDetail(loadout)
	end)
end

-- Mount ------------------------------------------------------------------------------------------------

local root: Frame? = nil
function InventoryV2.mount(host: ScreenGui)
	gui = host
	local holder = new("Frame", { Name = "InventoryV2", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 2 }, host)
	root = holder
	buildBackground(holder)
	local safe = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, TOPBAR),
		Size = UDim2.new(1, 0, 1, -TOPBAR - BOTTOM),
	}, holder)
	local canvas = new("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
	}, safe)
	local scale = new("UIScale", {}, canvas)
	local function fit()
		if not gui then
			return
		end
		local screen = gui.AbsoluteSize
		if screen.X > 0 and screen.Y > TOPBAR + BOTTOM then
			scale.Scale = math.min(screen.X / W, (screen.Y - TOPBAR - BOTTOM) / H)
		end
	end
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	buildStage(canvas)
	buildTop(canvas)
	buildLeft(canvas)
	buildRight(canvas)
	buildSurges(canvas)
	host:GetPropertyChangedSignal("Enabled"):Connect(function()
		if host.Enabled then
			draw()
		else
			InventoryV2.cancelDrag()
			state.Detail, state.Pick, state.Hover = nil, nil, nil
		end
	end)
end

function InventoryV2.setActive(on: boolean)
	state.Active = on
	if root then
		root.Visible = on
	end
	if not on then
		InventoryV2.cancelDrag()
	end
	draw()
end

function InventoryV2.isActive(): boolean
	return state.Active
end

-- Keep up with the profile, the worn gear's art and the miner previews.
GemClient.Changed:Connect(function()
	local profile = profileNow()
	if state.Pick and state.Pick.Kind == "Gem" and profile then
		local still = false
		for _, gem in profile.Gems or {} do
			if gem.Id == (state.Pick.Gem :: any).Id then
				still = true
			end
		end
		if not still then
			state.Pick = nil
		end
	end
	draw()
end)
local artPending = false
local function gearChanged()
	if artPending then
		return
	end
	artPending = true
	task.delay(0.3, function()
		artPending = false
		ui.ArtVersion = (ui.ArtVersion or 0) + 1
		for _, row in ui.Rows or {} do
			row.ArtVersion = ui.ArtVersion
		end
		ui.MinerSource = nil
		draw()
	end)
end
local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child.Name == "GemsoulGear" then
			gearChanged()
		end
	end)
	gearChanged()
end
if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)
local playerGui = player:WaitForChild("PlayerGui")
local function watchStore(store: Instance)
	store.DescendantAdded:Connect(function()
		ui.MinerSource = nil
		draw()
	end)
	store.ChildRemoved:Connect(function()
		ui.MinerSource = nil
		draw()
	end)
end
local function watchPreviews(store: Instance)
	store.ChildAdded:Connect(function()
		if state.Tab == "Pieces" then
			gridKey = ""
			draw()
		end
	end)
end
if playerGui:FindFirstChild("MinerPreviews") then
	watchStore(playerGui.MinerPreviews)
end
if playerGui:FindFirstChild("GearPreviews") then
	watchPreviews(playerGui:FindFirstChild("GearPreviews") :: Instance)
end
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "MinerPreviews" then
		watchStore(child)
	elseif child.Name == "GearPreviews" then
		watchPreviews(child)
	end
end)
-- The free pick's clock.
task.spawn(function()
	while true do
		task.wait(1)
		local profile = profileNow()
		if state.Active and gui and gui.Enabled and profile and ui.Pick then
			drawWallet(profile)
		end
	end
end)

return InventoryV2
