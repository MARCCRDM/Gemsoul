--[[
	Inventory v2: the miner owns the screen.

	  Top        back to the lobby, the other screens, your coins / season /
	             free pick
	  Left       who you are: miner 1 / 2 / 3, name, level, a big rating, four
	             stat bars, your armor set, and your elements: a radar of
	             what you attack with and what you resist, with what you're
	             strong against and weak to
	  Centre     your miner, large, on a lit floor
	  Right      what you wear: six rows (armor, then sword and shield), each
	             with its gem socket. Click one and the column turns into
	             that piece: the piece and its gem, its perk, then the gems
	             (or spare pieces) you could swap in. Hover one to see what
	             it would change; click it, then SOCKET or EQUIP
	  Bottom     the Surge Array (Q / E / R); click one to change its gem

	Drag a gem from the grid onto any row or Q / E / R card to socket it.
	The server checks every move (the same requests as the first Inventory).

	The default Inventory. The first one (Modules/InventoryScreen, v1) is
	kept and still built; the DEV panel can switch back to it (player
	attribute InventoryVersion: 1 for v1, 2 or unset for this one). What v1
	was and how to restore it: docs/v2-defaults.md.

	  InventoryV2.mount(gui)       builds it inside the Dashboard ScreenGui
	  InventoryV2.setActive(on)    shows it (and redraws) or hides it
	  InventoryV2.cancelDrag()
	  InventoryV2.version(player)  1 or 2: which Inventory this player sees
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ArmorFamilies = require(ReplicatedStorage.Shared.ArmorFamilies)
local ArmorSignatures = require(ReplicatedStorage.Shared.ArmorSignatures)
local ElementMatchup = require(ReplicatedStorage.Shared.ElementMatchup)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
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
local LiveLooks = require(script.Parent.LiveLooks)
local StatRadar = require(script.Parent.StatRadar)
local GemVault = require(script.Parent.GemVault)
local Wardrobe = require(script.Parent.Wardrobe)
local ShopArt = require(script.Parent.ShopArt)
local SurgeIcons = require(script.Parent.SurgeIcons)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new

local InventoryV2 = {}

-- Which Inventory a player gets when nothing has picked one (DEV panel).
-- Set to 1 to make the first Inventory (Modules/InventoryScreen) the default again.
InventoryV2.DefaultVersion = 2
function InventoryV2.version(player: Player): number
	local picked = player:GetAttribute("InventoryVersion")
	return if picked == 1 or picked == 2 then picked else InventoryV2.DefaultVersion
end

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
-- The Q / E / R triad (Shared.GemTraits): each key has a job and a colour,
-- and reads one socket: Q the sword's gem, E the core gem, R the shield's.
local Traits = Tech.Traits
local KEY_COLORS = {
	Q = Color3.fromRGB(255, 138, 92),
	E = Color3.fromRGB(122, 196, 255),
	R = Color3.fromRGB(120, 230, 170),
}
local LANE_WORDS = { Q = "OFFENSE", E = "ABILITY", R = "DEFENSE" }
local function triadOn(loadout): boolean
	return Traits.active(loadout)
end
-- A pouch gem as a key would fire it (its trait for that key).
local function keyGem(gem, key: string, loadout)
	if gem and triadOn(loadout) and not gem.TraitKey then
		return Traits.project(gem, key)
	end
	return gem
end
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
	-- (with the triad a gem is three moves, so it goes by its own name)
	if Traits.active(GemClient.Profile and GemClient.Profile.Character) then
		return GemConfig.displayName(gem)
	end
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
	for _, gem in GemInventory.available(profile) do
		local fits = not forKey
			or (if triadOn(loadoutNow()) then Traits.traitFor(gem, "E") ~= nil else Tech.surgeStats(gem) ~= nil)
		if gem.Cut ~= nil and fits then
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
-- "Health +12 · Power −3": what each stat does if this piece goes on.
local function statDeltas(loadout, slot: string, id: string): string
	local before = ratings(loadout)
	local trial = table.clone(loadout)
	trial[slot] = id
	local profile = profileNow()
	trial[slot .. "Quality"] = profile and profile.Owned and profile.Owned[Slots.Definitions[slot].Kind][id]
	trial[slot .. "Gem"] = (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id]) or nil
	local after = ratings(trial)
	if not before or not after then
		return ""
	end
	local parts = {}
	for _, stat in Classes.StatNames do
		local d = (after[stat].Base + after[stat].Bonus) - (before[stat].Base + before[stat].Bonus)
		if math.abs(d) >= 0.5 then
			table.insert(parts, string.format(
				'<font color="#%s">%s %s%s</font>',
				(if d > 0 then C.Good else C.Bad):ToHex(),
				stat,
				if d > 0 then "+" else "−",
				whole(math.abs(d))
			))
		end
	end
	return table.concat(parts, "  ·  ")
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
-- What a dragged gem can land on: a worn piece's socket, or a Q / E / R key
-- (with the triad: any gem with a move for that key), and the request it sends.
local function acceptsSlot(slot: string, item): boolean
	return item.Kind == "Gem" and item.Gem.Cut ~= nil and loadoutNow()[slot] ~= nil
end
local function acceptsKey(key: string, item): boolean
	if item.Kind ~= "Gem" or item.Gem.Cut == nil then
		return false
	end
	if Traits.active(loadoutNow()) then
		return Traits.traitFor(item.Gem, key) ~= nil
	end
	return Tech.surgeStats(item.Gem) ~= nil
end
local function socketInto(target: string, item)
	-- Profile updates may remove a stone while the pointer is still held.
	local gem = item.Gem and GemInventory.find(profileNow(), item.Gem.Id)
	if not gem or gem.Cut == nil then return end
	if table.find(KEYS, target) then
		request("SocketSurge", (item.Gem :: any).Id, target)
	else
		request("SocketGem", (item.Gem :: any).Id, target)
	end
end
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
	local was = state.Detail
	state.Detail = target
	state.Tab = "Gems"
	state.Pick, state.Hover = nil, nil
	if InventoryV2.hideTip then
		InventoryV2.hideTip()
	end
	-- The column slides a little as it changes, so the change reads.
	local panel = if target then ui.Detail else ui.List
	if panel and (was == nil) ~= (target == nil) then
		panel.Position = UDim2.fromOffset(if target then 22 else -22, 0)
		TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new() }):Play()
	end
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
	-- Back to the lobby: a solid gold button, the one way out, never missed.
	local back = new("TextButton", {
		Name = "BackToLobby",
		Text = "‹   BACK TO LOBBY",
		TextSize = 13,
		Font = HEAVY,
		TextColor3 = Color3.fromRGB(26, 18, 6),
		AutoButtonColor = false,
		BackgroundColor3 = C.Gold,
	}, canvas)
	place(back, 0, 8, 186, 40)
	round(back, 10)
	local backEdge = stroke(back, Color3.fromRGB(255, 226, 160), 1, 0.6)
	back:SetAttribute("UiSound", "Back")
	back.MouseEnter:Connect(function()
		back.BackgroundColor3 = Color3.fromRGB(255, 212, 128)
		backEdge.Transparency = 0.1
	end)
	back.MouseLeave:Connect(function()
		back.BackgroundColor3 = C.Gold
		backEdge.Transparency = 0.6
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
	place(tabs, 216, 8, 820, 40)
	local list = UiKit.list(tabs, 28, true)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	-- The keyboard keys the Dashboard binds (K, L, J), shown where there's a keyboard.
	local keyboard = UserInputService.KeyboardEnabled
	for order, spec in {
		{ "INVENTORY", nil },
		{ "SURGES", open("SurgeArrayUI", "toggle"), "L" },
		{ "AUGMENTS", open("AugmentTreeUI", "toggle"), "K" },
		{ "SEASON", open("SeasonUI", "toggle"), "J" },
		{ "MARKET", open("MarketBoardUI", "open") },
		{ "STORE", open("ShopUI", "toggle") },
	} do
		local on = spec[2] == nil
		-- The tab: its name, then (with a keyboard) its key in a small keycap.
		local slot = new("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			LayoutOrder = order,
		}, tabs)
		local inner = UiKit.list(slot, 6, true)
		inner.VerticalAlignment = Enum.VerticalAlignment.Center
		local b = new("TextButton", {
			Text = spec[1],
			TextSize = 13,
			Font = HEADING,
			TextColor3 = if on then C.Text else C.Dim,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			LayoutOrder = 1,
		}, slot)
		b:SetAttribute("UiSound", "Click")
		local bar = frame(b, C.Gold)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0, 1)
		bar.Size = UDim2.new(1, 0, 0, 2)
		if spec[3] and keyboard then
			local cap = text(slot, spec[3], 9, C.Dim, HEAVY)
			cap.Size = UDim2.fromOffset(16, 16)
			cap.LayoutOrder = 2
			cap.TextXAlignment = Enum.TextXAlignment.Center
			round(cap, 4)
			stroke(cap, C.Faint, 1, 0.3)
		end
		if not on then
			bar.BackgroundTransparency = 1
			b.MouseEnter:Connect(function()
				b.TextColor3 = C.Text
				bar.BackgroundTransparency = 0.6
			end)
			b.MouseLeave:Connect(function()
				b.TextColor3 = C.Dim
				bar.BackgroundTransparency = 1
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
	-- Elements: the radar (attack in gold, resistance in teal) and the verdict.
	local elementRule = frame(canvas, C.Line, 0.93)
	place(elementRule, x, 562, w + 90, 1)
	place(text(canvas, "ELEMENTS", 11, C.Dim, HEADING), x, 574, 80, 16)
	for i, spec in { { "ATTACK", C.Gold }, { "RESIST", C.Teal } } do
		local swatch = frame(canvas, spec[2], 0.2)
		place(swatch, x + 236 + (i - 1) * 84, 579, 14, 6)
		round(swatch, 3)
		place(text(canvas, spec[1], 10, C.Dim, HEADING), x + 256 + (i - 1) * 84, 574, 64, 16)
	end
	local axes = {}
	for i, element in ELEMENTS do
		axes[i] = { Name = string.upper(GemConfig.elementName(element)), Color = GemConfig.ElementColors[element] or C.Text }
	end
	local RADIUS = 68
	ui.AttackRadar = StatRadar.create(canvas, axes, RADIUS, C.Gold)
	ui.ResistRadar = StatRadar.create(canvas, axes, RADIUS, C.Teal, { Web = false, Labels = false })
	for _, radar in { ui.AttackRadar, ui.ResistRadar } do
		radar.Frame.Position = UDim2.fromOffset(x + 56, 626)
	end
	-- Every gem you wear, by element: the mix behind the shapes.
	ui.Mix = place(text(canvas, "", 11, C.Dim, HEADING), x, 794, w + 100, 16)
	ui.Mix.RichText = true
	place(text(canvas, "Each element beats the next one, clockwise.", 10, C.Faint, MEDIUM), x, 814, w + 100, 14)
	-- The verdict, beside the radar.
	ui.Verdict = {}
	for i, caption in { "STRONG VS", "WEAK TO", "RESISTS" } do
		local y = 612 + (i - 1) * 62
		local vx = x + 236
		place(text(canvas, caption, 10, C.Dim, HEADING), vx, y, 170, 14)
		-- (the last row sits beside the Q card, so it stays narrower)
		local value = place(text(canvas, "", if i == 3 then 12 else 15, C.Text, HEADING), vx, y + 15, if i == 3 then 162 else 220, 20)
		value.RichText = true
		local detail = place(text(canvas, "", 10, C.Faint, MEDIUM), vx, y + 36, 180, 14)
		ui.Verdict[i] = { Value = value, Detail = detail }
	end
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
	ui.MinerYaw = 0
	-- Drag across the miner to turn them.
	local turn = new("TextButton", { Name = "TurnMiner", Text = "", AutoButtonColor = false, BackgroundTransparency = 1 }, canvas)
	place(turn, 560, 110, 480, 600)
	turn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ui.Turning = { X = input.Position.X, Touch = input.UserInputType == Enum.UserInputType.Touch }
		end
	end)
	local hint = place(text(canvas, "DRAG TO TURN", 10, C.Faint, HEADING), 700, 728, 200, 14)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextTransparency = 0.3
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
	local halo = frame(socket, C.Gold, 0.9)
	halo.Name = "EmptySocketGlow"
	halo.Position = UDim2.fromOffset(-5, -5)
	halo.Size = UDim2.new(1, 10, 1, 10)
	round(halo, 23)
	halo.Visible = false
	local ring = stroke(socket, C.Faint, 1.5, 0.3)
	local gemHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4) }, socket)
	local plus = text(socket, "+", 16, C.Faint, HEADING)
	plus.Size = UDim2.fromScale(1, 1)
	plus.TextXAlignment = Enum.TextXAlignment.Center
	local enchant = place(text(row, "ADD STONE TO ENCHANT  ·  DRAG & DROP", 10, C.Gold, HEADING), 82, 52, RIGHT_W - 96, 14)
	enchant.Name, enchant.Visible = "EnchantHint", false
	row:SetAttribute("UiSound", "Click")
	row.Activated:Connect(function()
		if os.clock() < suppressClickUntil then
			return
		end
		if state.Detail ~= slot then
			openDetail(slot)
		end
	end)
	local entry = { Row = row, Tint = tint, Edge = edge, Rail = rail, Art = art, Name = name, Meta = meta, Ring = ring, Gem = gemHolder, Plus = plus, Halo = halo, Enchant = enchant }
	row.MouseEnter:Connect(function()
		entry.Hovered = true
		InventoryV2.paintRow(slot)
		if not drag and InventoryV2.showTip then
			InventoryV2.showTip(slot, row)
		end
	end)
	row.MouseLeave:Connect(function()
		entry.Hovered = false
		InventoryV2.paintRow(slot)
		if InventoryV2.hideTip then
			InventoryV2.hideTip()
		end
	end)
	table.insert(dropTargets, {
		Frame = row,
		Stroke = edge,
		Accepts = function(item: Item)
			return acceptsSlot(slot, item)
		end,
		Drop = function(item: Item)
			socketInto(slot, item)
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
	-- Under the list: available stones, in the gem window (GemVault).
	local gems = new("TextButton", {
		Name = "GemsButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, list)
	-- GEMS and SKINS share the row (the Q/E/R cards reach in under this column).
	local half = (RIGHT_W - 10) / 2
	place(gems, 0, y + 12, half, 56)
	round(gems, 10)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(38, 31, 60), Color3.fromRGB(16, 20, 31)),
	}, gems)
	local gemsEdge = stroke(gems, Color3.fromRGB(190, 120, 255), 1, 0.55)
	local gemsIcon = frame(gems, Color3.fromRGB(255, 255, 255), 0.95)
	place(gemsIcon, 10, 8, 40, 40)
	round(gemsIcon, 20)
	ui.GemsIcon = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gemsIcon)
	place(text(gems, "GEMS", 15, C.Text, HEAVY), 62, 10, 160, 20)
	ui.GemsCount = place(text(gems, "", 10, C.Dim, HEADING), 62, 31, half - 70, 14)
	local review = place(text(gems, "›", 18, Color3.fromRGB(200, 150, 255), HEAVY), half - 26, 16, 16, 22)
	review.TextXAlignment = Enum.TextXAlignment.Right
	gems:SetAttribute("UiSound", "Click")
	gems.MouseEnter:Connect(function()
		gemsEdge.Transparency = 0.1
	end)
	gems.MouseLeave:Connect(function()
		gemsEdge.Transparency = 0.55
	end)
	gems.Activated:Connect(function()
		if ui.Canvas then
			GemVault.open(ui.Canvas, nil, InventoryV2.beginGemDrag)
		end
	end)
	-- Beside it: the miner's suit and weapon skin, in the Wardrobe.
	local skins = new("TextButton", {
		Name = "SkinsButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, list)
	place(skins, half + 10, y + 12, half, 56)
	round(skins, 10)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(56, 30, 48), Color3.fromRGB(16, 20, 31)),
	}, skins)
	local skinsEdge = stroke(skins, Color3.fromRGB(255, 120, 190), 1, 0.55)
	local skinsIcon = frame(skins, Color3.fromRGB(255, 255, 255), 0.95)
	place(skinsIcon, 10, 8, 40, 40)
	round(skinsIcon, 20)
	ui.SkinsIcon = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, skinsIcon)
	place(text(skins, "SKINS", 15, C.Text, HEAVY), 62, 10, 120, 20)
	ui.SkinsCount = place(text(skins, "", 10, C.Dim, HEADING), 62, 31, half - 70, 14)
	ui.SkinsCount.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = 10 }, ui.SkinsCount)
	local wardrobe = place(text(skins, "›", 18, Color3.fromRGB(255, 150, 205), HEAVY), half - 26, 16, 16, 22)
	wardrobe.TextXAlignment = Enum.TextXAlignment.Right
	skins:SetAttribute("UiSound", "Click")
	skins.MouseEnter:Connect(function()
		skinsEdge.Transparency = 0.1
	end)
	skins.MouseLeave:Connect(function()
		skinsEdge.Transparency = 0.55
	end)
	skins.Activated:Connect(function()
		if ui.Canvas then
			Wardrobe.open(ui.Canvas)
		end
	end)
	y += 68
	-- Under that: what's still empty, and a button straight to it.
	local nudge = frame(list, C.Gold, 0.94)
	nudge.Name = "Nudge"
	place(nudge, 0, y + 12, RIGHT_W, 64)
	round(nudge, 12)
	stroke(nudge, C.Gold, 1, 0.75)
	ui.NudgeTitle = place(text(nudge, "", 12, C.Gold, HEAVY), 16, 12, RIGHT_W - 170, 18)
	ui.NudgeText = place(text(nudge, "", 10, C.Dim, MEDIUM), 16, 32, RIGHT_W - 170, 22)
	ui.NudgeText.TextWrapped = true
	ui.NudgeText.TextYAlignment = Enum.TextYAlignment.Top
	ui.NudgeGo = new("TextButton", {
		Name = "FillNext",
		Text = "FILL NEXT  ›",
		TextSize = 12,
		Font = HEAVY,
		TextColor3 = Color3.fromRGB(26, 18, 6),
		AutoButtonColor = true,
		BackgroundColor3 = C.Gold,
	}, nudge)
	place(ui.NudgeGo, RIGHT_W - 142, 14, 128, 36)
	round(ui.NudgeGo, 9)
	ui.NudgeGo:SetAttribute("UiSound", "Click")
	ui.NudgeGo.Activated:Connect(function()
		if ui.NudgeTarget then
			openDetail(ui.NudgeTarget)
		end
	end)
	ui.Nudge = nudge
	ui.List = list
	-- The detail (one piece, or one surge key).
	local detail = new("Frame", { Name = "Detail", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, column)
	ui.Detail = detail
	-- Along the top: back, then every slot and key, so you can hop between
	-- them without going back to the list.
	local back = new("TextButton", {
		Name = "Back",
		Text = "‹",
		TextSize = 24,
		Font = HEADING,
		TextColor3 = C.Dim,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
	}, detail)
	place(back, 0, 0, 32, 34)
	back:SetAttribute("UiSound", "Back")
	back.MouseEnter:Connect(function()
		back.TextColor3 = C.Text
	end)
	back.MouseLeave:Connect(function()
		back.TextColor3 = C.Dim
	end)
	back.Activated:Connect(function()
		openDetail(nil)
	end)
	ui.Strip = {}
	local sx = 40
	for _, slot in Slots.Order do
		local tile = new("TextButton", {
			Name = "Hop" .. slot,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.95,
		}, detail)
		place(tile, sx, 0, 34, 34)
		round(tile, 8)
		local edge = stroke(tile, C.Line, 1, 0.9)
		local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, tile)
		tile:SetAttribute("UiSound", "Tab")
		tile.Activated:Connect(function()
			if state.Detail ~= slot then
				openDetail(slot)
			end
		end)
		ui.Strip[slot] = { Tile = tile, Edge = edge, Icon = holder }
		table.insert(dropTargets, {
			Frame = tile,
			Stroke = edge,
			Accepts = function(item: Item)
				return acceptsSlot(slot, item)
			end,
			Drop = function(item: Item)
				socketInto(slot, item)
			end,
		})
		sx += 38
		if slot == "Boots" then
			sx += 8
		end
	end
	sx += 8
	for _, key in KEYS do
		local tile = new("TextButton", {
			Name = "Hop" .. key,
			Text = key,
			TextSize = 12,
			Font = HEAVY,
			TextColor3 = C.Dim,
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.95,
		}, detail)
		place(tile, sx, 0, 30, 34)
		round(tile, 8)
		local edge = stroke(tile, C.Line, 1, 0.9)
		tile:SetAttribute("UiSound", "Tab")
		tile.Activated:Connect(function()
			if state.Detail ~= key then
				openDetail(key)
			end
		end)
		ui.Strip[key] = { Tile = tile, Edge = edge }
		table.insert(dropTargets, {
			Frame = tile,
			Stroke = edge,
			Accepts = function(item: Item)
				return acceptsKey(key, item)
			end,
			Drop = function(item: Item)
				socketInto(key, item)
			end,
		})
		sx += 34
	end
	-- The card: piece + gem (or the surge), and the perk.
	local card = frame(detail, Color3.fromRGB(255, 255, 255), 0.965)
	place(card, 0, 46, RIGHT_W, 262)
	round(card, 14)
	local cardEdge = stroke(card, C.Line, 1, 0.92)
	card.Name = "DetailCard"
	ui.Card = card
	table.insert(dropTargets, {
		Frame = card,
		Stroke = cardEdge,
		Accepts = function(item: Item)
			local target = state.Detail
			if not target then
				return false
			end
			return if table.find(KEYS, target) then acceptsKey(target, item) else acceptsSlot(target, item)
		end,
		Drop = function(item: Item)
			if state.Detail then
				socketInto(state.Detail, item)
			end
		end,
	})
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
	-- The triad: a read-only display of the gem's three traits, with this key lit.
	ui.TraitStrip = new("Frame", { Name = "Traits", BackgroundTransparency = 1, Visible = false }, card)
	place(ui.TraitStrip, 18, 124, RIGHT_W - 36, 40)
	ui.TraitChips = {}
	local chipW = math.floor((RIGHT_W - 36 - 12) / 3)
	for i, key in KEYS do
		local chip = new("Frame", {
			Name = "Trait" .. key,
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.5,
		}, ui.TraitStrip)
		place(chip, (i - 1) * (chipW + 6), 0, chipW, 40)
		round(chip, 8)
		local edge = stroke(chip, C.Line, 1, 0.5)
		local badge = text(chip, key, 11, C.Ink, HEAVY)
		place(badge, 7, 11, 18, 18)
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.BackgroundTransparency = 0
		round(badge, 4)
		local lane = place(text(chip, "", 8, C.Dim, HEAVY), 31, 5, chipW - 36, 11)
		local name = place(text(chip, "", 11, C.Text, HEADING), 31, 18, chipW - 36, 16)

		local entry = { Chip = chip, Edge = edge, Badge = badge, Lane = lane, Name = name, Key = key }
		ui.TraitChips[key] = entry
	end
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
	place(ui.Tabs, 0, 320, 230, 24)
	ui.Filters = new("Frame", { BackgroundTransparency = 1 }, detail)
	place(ui.Filters, RIGHT_W - 150, 320, 150, 24)
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
	place(ui.Grid, 0, 352, RIGHT_W, 144)
	-- What a pick (or the hovered one) would change, and the buttons.
	ui.Compare = frame(detail, C.Gold, 0.93)
	place(ui.Compare, 0, 504, RIGHT_W, 60)
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
		place(b, x, 572, w, 44)
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
	-- Left edge clear of the elements panel; they reach right under the
	-- equipment column (which ends above them), room for the whole info line.
	local cardW, gap = 248, 12
	local x0 = 441
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
		badge.Position = UDim2.fromOffset(3, 3)
		badge.Size = UDim2.fromOffset(20, 18)
		badge.ZIndex = icon.ZIndex + 2
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
				return acceptsKey(key, item)
			end,
			Drop = function(item: Item)
				-- (with the triad on, the server sockets it in the sword, the core or the shield)
				socketInto(key, item)
			end,
		})
		-- The key's job, above its name (OFFENSE / ABILITY / DEFENSE).
		local lane = place(text(card, "", 9, C.Dim, HEAVY), 68, 4, cardW - 80, 12)
		lane.TextTransparency = 0.1
		ui.Keys[key] = { Card = card, Edge = edge, Icon = icon, Glyph = glyph, Name = name, Info = info, Line = line, Badge = badge, Lane = lane }
	end
end

-- Drag and drop ----------------------------------------------------------------------------------------
-- (as in the first Inventory: mouse in screen space, touch as reported)

-- Where the pointer is, in the screen space the Dashboard's frames use
-- (it ignores the top-bar inset). The mouse reads in that space already; a
-- touch is reported from under the top bar, so the inset is added back.
local function pointOf(input: InputObject, touch: boolean): Vector2
	local point = if touch
		then Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
		else UserInputService:GetMouseLocation()
	if gui and not gui.IgnoreGuiInset then
		point -= GuiService:GetGuiInset()
	end
	return point
end
-- On screen for real: it and everything it sits in are visible. (A frame
-- can be Visible inside a hidden panel: the equipment rows behind the
-- detail panel must never catch a drop.)
local function shown(object: Instance?): boolean
	while object and object:IsA("GuiObject") do
		if not object.Visible then
			return false
		end
		object = object.Parent
	end
	return object ~= nil and (not object:IsA("ScreenGui") or object.Enabled)
end
local function inside(f: GuiObject, point: Vector2): boolean
	local p, size = f.AbsolutePosition, f.AbsoluteSize
	return point.X >= p.X and point.Y >= p.Y and point.X < p.X + size.X and point.Y < p.Y + size.Y
end
-- The drop target under the pointer: the smallest one that takes the item
-- (a strip tile over the detail card, a key over the panel).
local function targetAt(point: Vector2, item: Item)
	local best, bestArea = nil, math.huge
	for _, target in dropTargets do
		local f = target.Frame
		if shown(f) and inside(f, point) and target.Accepts(item) then
			local area = f.AbsoluteSize.X * f.AbsoluteSize.Y
			if area < bestArea then
				best, bestArea = target, area
			end
		end
	end
	return best
end
-- Every place the item could go lights gold; the one under the pointer, brighter.
local function lightTargets(item: Item?, over: any?)
	for _, target in dropTargets do
		if target.Base == nil then
			target.Base = { target.Stroke.Color, target.Stroke.Transparency, target.Stroke.Thickness }
		end
		local ok = item ~= nil and shown(target.Frame) and target.Accepts(item)
		local hot = ok and target == over
		target.Stroke.Color = if ok then C.Gold else target.Base[1]
		target.Stroke.Transparency = if hot then 0 elseif ok then 0.25 else target.Base[2]
		target.Stroke.Thickness = if hot then 3 elseif ok then 2 else target.Base[3]
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
	if ui.Grid then
		ui.Grid.ScrollingEnabled = true
	end
	if was then
		lightTargets(nil)
	end
	if gui then
		draw()
	end
end
local function startDrag(item: Item, input: InputObject)
	if drag or not state.Active or not gui or not gui.Enabled then return end
	local touch = input.UserInputType == Enum.UserInputType.Touch
	drag = { Item = item, Start = pointOf(input, touch), Active = false, Touch = touch, Input = input } :: any
end
function InventoryV2.beginGemDrag(gem, input: InputObject)
	if gem.Cut ~= nil and GemInventory.find(profileNow(), gem.Id) then
		startDrag({ Kind = "Gem", Gem = gem }, input)
	end
end
UserInputService.InputChanged:Connect(function(input)
	local current = drag :: any
	if not current or not gui then
		return
	end
	local moving = (not current.Touch and input.UserInputType == Enum.UserInputType.MouseMovement)
		or (current.Touch and input == current.Input)
	if not moving then
		return
	end
	local point = pointOf(input, current.Touch)
	if not current.Active then
		if (point - current.Start).Magnitude < 8 then
			return
		end
		current.Active = true
		-- Reveal the equipment beneath the vault only once this is a real drag.
		-- A normal click still opens the stone's details.
		if GemVault.isOpen() then
			GemVault.close()
			state.Detail, state.Pick, state.Hover = nil, nil, nil
			ui.List.Visible, ui.Detail.Visible = true, false
		end
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
		-- (A touch drag moves the gem, not the grid.)
		if ui.Grid then
			ui.Grid.ScrollingEnabled = false
		end
		if InventoryV2.hideTip then
			InventoryV2.hideTip()
		end
	end
	if current.Ghost then
		current.Ghost.Position = UDim2.fromOffset(point.X, point.Y - (if current.Touch then 40 else 0))
		local over = targetAt(point, current.Item)
		if over ~= current.Over or not current.Lit then
			current.Over, current.Lit = over, true
			lightTargets(current.Item, over)
		end
	end
end)
-- Let go outside the window (or it lost focus): drop nothing, end the drag.
UserInputService.WindowFocusReleased:Connect(function()
	if drag then
		InventoryV2.cancelDrag()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local current = drag :: any
	if not current then
		return
	end
	local ending = (not current.Touch and input.UserInputType == Enum.UserInputType.MouseButton1)
		or (current.Touch and input == current.Input)
	if not ending then
		return
	end
	drag = nil
	if current.Ghost then
		current.Ghost:Destroy()
	end
	if ui.Grid then
		ui.Grid.ScrollingEnabled = true
	end
	lightTargets(nil)
	if current.Active and input.UserInputState ~= Enum.UserInputState.Cancel and state.Active and gui and gui.Enabled then
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
	LiveLooks.watch(copy) -- (animated skins move here as they do on you)
	local armor = loadout and ArmorFamilies.ById[loadout.Armor]
	pcall(InventoryPose.apply, copy, armor and armor.ArmorFamily)
	local bounds, size = copy:GetBoundingBox()
	local camera = new("Camera", { FieldOfView = 30 }, view)
	local distance = math.max(size.Y * 0.62, size.X * 0.9) / math.tan(math.rad(15))
	ui.MinerOrbit = { Camera = camera, Focus = bounds.Position, Offset = Vector3.new(distance * 0.12, size.Y * 0.04, -distance) }
	InventoryV2.aimMiner()
	view.CurrentCamera = camera
end
-- Points the miner's camera from the current turn (MinerYaw).
function InventoryV2.aimMiner()
	local orbit = ui.MinerOrbit
	if not orbit then
		return
	end
	local offset = CFrame.Angles(0, ui.MinerYaw or 0, 0):VectorToWorldSpace(orbit.Offset)
	orbit.Camera.CFrame = CFrame.lookAt(orbit.Focus + offset, orbit.Focus)
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
	if ui.RatingLast and math.abs(total - ui.RatingLast) >= 0.5 then
		ui.Rating.TextColor3 = if total > ui.RatingLast then C.Good else C.Bad
		TweenService:Create(ui.Rating, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { TextColor3 = C.Gold }):Play()
	end
	ui.RatingLast = total
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
	-- Elements: what you attack with (the sword's gem, and the surges' a
	-- little), what your armor gems resist, and the matchups that follow
	-- (Shared.ElementMatchup, the same rules a fight uses).
	local function grade(gem): number
		local total, count = 0, 0
		for _, metric in { "Size", "Clarity", "Cut" } do
			if type(gem[metric]) == "number" then
				total += gem[metric]
				count += 1
			end
		end
		return if count > 0 then math.clamp(total / count, 1, 10) else 1
	end
	local attack = {}
	local weaponGem = loadout.WeaponGem
	if weaponGem and weaponGem.Element then
		attack[weaponGem.Element] = (attack[weaponGem.Element] or 0) + 0.45 + 0.4 * (grade(weaponGem) - 1) / 9
	end
	-- The triad: Q is the sword's own gem (counted above) and R the shield's
	-- (counted with the armor below); E's surge adds to the attack.
	local triad = triadOn(loadout)
	for _, key in KEYS do
		local gem = if not triad or key == "E" then Tech.surgeGem(loadout, key) else nil
		if gem and gem.Element then
			local weight = if triad then 0.25 else 0.12
			attack[gem.Element] = (attack[gem.Element] or 0) + weight + 0.1 * (grade(gem) - 1) / 9
		end
	end
	local okProfile, armor = pcall(ElementMatchup.profile, loadout)
	if not okProfile or not armor then
		armor = { Resist = {}, Main = nil }
	end
	local weakTo = armor.Main and ElementMatchup.weakTo(armor.Main)
	local attackValues, resistValues, texts = {}, {}, {}
	for i, element in ELEMENTS do
		attackValues[i] = math.clamp(attack[element] or 0, 0, 1)
		local share = armor.Resist[element] or 0
		resistValues[i] = math.clamp(share / ElementMatchup.Cap, 0, 1)
		texts[i] = if element == weakTo
			then "WEAK"
			elseif share > 0 then string.format("−%d%%", math.floor(share * 100 + 0.5))
			else ""
	end
	StatRadar.set(ui.AttackRadar, attackValues, texts)
	StatRadar.set(ui.ResistRadar, resistValues, {})
	if not ui.RadarShown then
		-- The first time, the shapes start where they belong; changes ease after.
		ui.RadarShown = true
		StatRadar.step(ui.AttackRadar, 5)
		StatRadar.step(ui.ResistRadar, 5)
	end
	for i, element in ELEMENTS do
		local label = ui.AttackRadar.Labels[i]
		if label then
			label.Value.TextColor3 = if element == weakTo then C.Bad else C.Teal
			label.Value.TextSize = 11
		end
	end
	local function named(element: string): string
		return string.format(
			'<font color="#%s">%s</font>',
			(GemConfig.ElementColors[element] or C.Text):ToHex(),
			string.upper(GemConfig.elementName(element))
		)
	end
	local strong, weak, resists = ui.Verdict[1], ui.Verdict[2], ui.Verdict[3]
	local victim = weaponGem and weaponGem.Element and ElementMatchup.Beats[weaponGem.Element]
	if victim then
		strong.Value.Text = named(victim) .. " ARMOR"
		strong.Detail.Text = string.format("Your %s sword hits +25%%", GemConfig.elementName(weaponGem.Element))
	else
		strong.Value.Text = "—"
		strong.Detail.Text = "Socket a gem in your sword"
	end
	if weakTo then
		weak.Value.Text = named(weakTo)
		weak.Detail.Text = string.format("Takes +25%% (your armor is %s)", GemConfig.elementName(armor.Main))
	else
		weak.Value.Text = "NOTHING"
		weak.Detail.Text = "No armor element yet"
	end
	local parts, order = {}, table.clone(ELEMENTS)
	table.sort(order, function(a, b)
		return (armor.Resist[a] or 0) > (armor.Resist[b] or 0)
	end)
	for _, element in order do
		local share = armor.Resist[element] or 0
		if share > 0 then
			table.insert(parts, string.format("%s %d%%", named(element), math.floor(share * 100 + 0.5)))
		end
	end
	-- The two strongest fit on the line (the radar shows them all).
	local shownParts = { parts[1], parts[2] }
	resists.Value.Text = if #parts > 0 then table.concat(shownParts, "  ") else "NONE YET"
	resists.Detail.Text = if #parts > 0 then "Half strength from perk pieces" else "Armor gems resist their element"
	-- The mix: every socketed gem (armor, sword and surges), by element.
	local counts = {}
	for _, slot in Slots.Order do
		local gem = loadout[slot .. "Gem"]
		if gem and gem.Element then
			counts[gem.Element] = (counts[gem.Element] or 0) + 1
		end
	end
	for _, key in KEYS do
		local gem = Tech.surgeGem(loadout, key)
		if gem and gem.Element then
			counts[gem.Element] = (counts[gem.Element] or 0) + 1
		end
	end
	local mix = {}
	for _, element in ELEMENTS do
		if counts[element] then
			table.insert(mix, string.format("%s %d", named(element), counts[element]))
		end
	end
	ui.Mix.Text = if #mix > 0
		then string.format('<font color="#%s">YOUR GEMS</font>   %s', C.Faint:ToHex(), table.concat(mix, "   "))
		else string.format('<font color="#%s">YOUR GEMS</font>   none socketed yet', C.Faint:ToHex())

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

-- A row's frame: gold while it's open, lighter under the pointer.
function InventoryV2.paintRow(slot: string)
	local row = ui.Rows and ui.Rows[slot]
	if not row then
		return
	end
	local picked = state.Detail == slot
	row.Rail.BackgroundColor3 = if picked then C.Gold else row.Color or C.Faint
	row.Edge.Color = C.Gold
	row.Edge.Transparency = if picked then 0.35 elseif row.Hovered then 0.45 elseif row.EmptySocket then 0.65 else 1
	row.Tint.Color = if picked
		then ColorSequence.new(Color3.fromRGB(58, 46, 22), Color3.fromRGB(16, 14, 12))
		elseif row.Hovered then ColorSequence.new(Color3.fromRGB(32, 40, 54), Color3.fromRGB(14, 18, 27))
		elseif row.EmptySocket then ColorSequence.new(Color3.fromRGB(38, 33, 24), Color3.fromRGB(13, 17, 25))
		else ColorSequence.new(Color3.fromRGB(20, 25, 34), Color3.fromRGB(11, 14, 21))
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
		local tail: string = if signature then "  ·  " .. string.upper(signature.Definition.Name)
			elseif gear and gear.BuffReady and gear.Passive and gear.Passive.Name and gear.Passive.Name ~= "Signature" then "  ·  " .. string.upper(gear.Passive.Name)
			else ""
		-- The triad: the sword gives Q its move, the shield R.
		local rowKey = if triadOn(loadout) then (if slot == "Weapon" then "Q" elseif slot == "Shield" then "R" else nil) else nil
		if rowKey and gem then
			local move = Tech.Catalog[Traits.traitFor(gem, rowKey) or ""]
			if move then
				tail = string.format('  ·  <font color="#%s">%s %s</font>', KEY_COLORS[rowKey]:ToHex(), rowKey, string.upper(move.Name))
			end
		end
		row.Meta.Text = if gear
			then string.format('<font color="#%s">%s</font>  ·  %s%s', color:ToHex(), rarityName(rarity), SLOT_NAME[slot], tail)
			else SLOT_NAME[slot] .. "  ·  NOTHING WORN"
		row.Color = color
		row.EmptySocket = gear ~= nil and gem == nil
		row.Enchant.Visible, row.Halo.Visible = row.EmptySocket, row.EmptySocket
		row.Name.Position = UDim2.fromOffset(82, if row.EmptySocket then 9 else 16)
		row.Meta.Position = UDim2.fromOffset(82, if row.EmptySocket then 31 else 40)
		InventoryV2.paintRow(slot)
		-- Something changed in this slot (a piece or a gem): a gold flash says it took.
		local shown = tostring(id) .. "|" .. (if gem then gem.Id else "")
		if row.Shown ~= nil and row.Shown ~= shown then
			local flash = frame(row.Row, C.Gold, 0.55)
			flash.Size = UDim2.fromScale(1, 1)
			flash.ZIndex = 6
			round(flash, 10)
			TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
			task.delay(0.85, function()
				flash:Destroy()
			end)
		end
		row.Shown = shown
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
		row.Plus.Visible = row.EmptySocket
		row.Plus.TextColor3 = if row.EmptySocket then C.Gold else C.Faint
		row.Ring.Color = if gem then gemColor(gem) elseif row.EmptySocket then C.Gold else C.Faint
		row.Ring.Transparency = if gem then 0.1 elseif row.EmptySocket then 0.25 else 0.5
	end
end

-- The nudge under the list: empty gem sockets (on worn pieces, and the
-- core socket that gives E its move) and the spare gems that could fill
-- them. Hidden once every socket holds a gem.
local NUDGE_ORDER = { "Weapon", "Shield", "Armor", "Helmet", "Gloves", "Boots" }
local function drawNudge(profile, loadout)
	local empty, first = {}, nil
	for _, slot in NUDGE_ORDER do
		if loadout[slot] ~= nil and loadout[slot .. "Gem"] == nil then
			table.insert(empty, SLOT_NAME[slot])
			first = first or slot
		end
	end
	if triadOn(loadout) and loadout.Surge2Gem == nil then
		table.insert(empty, "CORE (E)")
		first = first or "E"
	end
	local spare = #GemInventory.available(profile)
	ui.Nudge.Visible = #empty > 0
	ui.NudgeTarget = first
	if #empty == 0 then
		return
	end
	ui.NudgeTitle.Text = if #empty == 1 then "1 EMPTY GEM SOCKET" else #empty .. " EMPTY GEM SOCKETS"
	ui.NudgeText.Text = if spare > 0
		then string.format("%s  ·  %d spare gem%s to fill them", table.concat(empty, ", "), spare, if spare == 1 then "" else "s")
		else table.concat(empty, ", ") .. "  ·  mine gems at the Outpost to fill them"
	ui.NudgeGo.Visible = spare > 0
end

local function drawKeys(loadout)
	for _, key in KEYS do
		local entry = ui.Keys[key]
		local gem = Tech.surgeGem(loadout, key)
		local surge = gem and Tech.surgeStats(gem)
		local tint = if gem then gemColor(gem) else C.Faint
		local picked = state.Detail == key
		local triad = triadOn(loadout)
		local keyColor = if triad then KEY_COLORS[key] else C.Text
		entry.Badge.BackgroundColor3 = if triad then keyColor else C.Ink
		entry.Badge.TextColor3 = if triad then C.Ink else C.Text
		entry.Lane.Text = if triad then LANE_WORDS[key] .. "  ·  " .. string.upper(Traits.SocketNames[key]) .. " GEM" else ""
		entry.Lane.TextColor3 = keyColor
		entry.Name.Position = UDim2.fromOffset(68, if triad then 18 else 14)
		entry.Info.Position = UDim2.fromOffset(68, if triad then 38 else 36)
		entry.Name.Text = if surge then surge.Name elseif triad then "No gem in your " .. string.lower(Traits.SocketNames[key]) else "Add a surge"
		entry.Name.TextColor3 = if surge then C.Text else C.Dim
		entry.Info.Text = if surge
			then string.format(
				"%s %s  ·  %s s%s",
				whole(surge.Cost or 0),
				string.lower(surge.Resource or "charge"),
				whole(surge.Cooldown or 0),
				if surge.Triad then "  ·  " .. whole((surge.Output or 1) * 100) .. "% power" else ""
			)
			else "ADD STONE  ·  CLICK OR DRAG & DROP"
		entry.Line.BackgroundColor3 = tint
		entry.Line.BackgroundTransparency = if gem then 0.15 else 0.7
		entry.Edge.Color = if picked or not gem then C.Gold else C.Line
		entry.Edge.Transparency = if picked then 0.2 elseif not gem then 0.55 else 0.9
		local shown = if gem then gem.Id .. tostring(gem.Surge) else ""
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
local gridCells = {}
-- The pick has a gold frame, the cell under the pointer a lighter one.
local function paintCells()
	for _, cell in gridCells do
		local picked = sameItem(cell.Item, state.Pick)
		local hovered = sameItem(cell.Item, state.Hover)
		cell.Edge.Color = if picked then C.Gold else C.Line
		cell.Edge.Thickness = if picked then 1.5 else 1
		cell.Edge.Transparency = if picked then 0 elseif hovered then 0.5 else 0.92
		cell.Button.BackgroundTransparency = if picked then 0.9 elseif hovered then 0.93 else 0.965
	end
end
local function drawGrid(items: { Item }, emptyText: string)
	local parts = { state.Detail or "", state.Tab, state.Filter }
	for _, item in items do
		table.insert(parts, item.Id or (item.Gem and item.Gem.Id .. ":" .. tostring(item.Gem.Cut)) or "")
	end
	local key = table.concat(parts, ",")
	if key == gridKey then
		paintCells()
		return
	end
	gridKey = key
	gridCells = {}
	clear(ui.Grid)
	ui.Grid.CanvasPosition = Vector2.zero
	if #items == 0 then
		local note = text(ui.Grid, emptyText, 12, C.Faint, MEDIUM)
		note.Size = UDim2.new(1, 0, 0, 60)
		note.TextWrapped = true
		note.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(68, 68),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, ui.Grid)
	for order, item in items do
		local cell = new("TextButton", {
			Name = "Cell" .. order,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.965,
			LayoutOrder = order,
		}, ui.Grid)
		round(cell, 10)
		local edge = stroke(cell, C.Line, 1, 0.92)
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 7), Size = UDim2.new(1, -18, 1, -18) }, cell)
		local tierColor
		if item.Kind == "Gem" then
			gemArt(art, item.Gem)
			tierColor = rarityColor(gemRarity(item.Gem))
		else
			tierColor = rarityColor(rarityOf(loadoutNow(), item.Slot :: string, item.Id))
			gearArt(art, item.Slot :: string, item.Id :: string, false, tierColor)
		end
		local tier = frame(cell, tierColor)
		tier.AnchorPoint = Vector2.new(0, 1)
		tier.Position = UDim2.new(0, 10, 1, -5)
		tier.Size = UDim2.new(1, -20, 0, 2)
		round(tier, 1)
		cell:SetAttribute("UiSound", "Click")
		cell.MouseEnter:Connect(function()
			state.Hover = item
			paintCells()
			InventoryV2.drawCompare()
		end)
		cell.MouseLeave:Connect(function()
			if sameItem(state.Hover, item) then
				state.Hover = nil
			end
			paintCells()
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
		table.insert(gridCells, { Item = item, Edge = edge, Button = cell })
	end
	paintCells()
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
-- The trait strip shows the gem's existing moves and highlights the current key.
function InventoryV2.drawTraits(gem, key: string?)
	local strip = ui.TraitStrip
	if not strip then
		return
	end
	local traits = gem and triadOn(loadoutNow()) and Traits.traitsOf(gem)
	strip.Visible = traits ~= nil
	if not traits then
		return
	end
	for k, entry in ui.TraitChips do
		local lit = k == key
		local color = KEY_COLORS[k]
		local move = Tech.Catalog[traits[Traits.Lanes[k]] or ""]
		entry.Badge.BackgroundColor3 = if lit then color else C.Faint
		entry.Name.Text = if move then move.Name else "?"
		-- Smaller for the long names, so the whole name fits the chip.
		local length = #entry.Name.Text
		entry.Name.TextSize = if length <= 11 then 11 elseif length <= 13 then 10 else 9
		entry.Name.TextColor3 = if lit then C.Text else C.Dim
		entry.Lane.Text = LANE_WORDS[k] .. (if move and move.Rare then "  ★" else "") -- (★ a signature move: rolls at half the odds)
		entry.Lane.TextColor3 = if lit then color else C.Faint
		entry.Chip.BackgroundColor3 = if lit then color:Lerp(C.Ink, 0.8) else C.Ink
		entry.Chip.BackgroundTransparency = if lit then 0.1 else 0.5
		entry.Edge.Color = if lit then color else C.Line
		entry.Edge.Transparency = if lit then 0.15 else 0.6
	end
end

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
			local surge = Tech.surgeStats(keyGem(item.Gem, target, loadout))
			local now = current and Tech.surgeStats(current)
			if surge and now and current.Id ~= (item.Gem :: any).Id then
				-- Against what's on the key now: cheaper and quicker is better.
				local function change(new: number, old: number, unit: string): string
					local d = new - old
					if math.abs(d) < 0.5 then
						return whole(new) .. unit
					end
					return string.format('%s%s <font color="#%s">(%s%s)</font>', whole(new), unit, if d < 0 then good else bad, if d < 0 then "−" else "+", whole(math.abs(d)))
				end
				textValue = string.format(
					"<b>%s</b> instead of %s: %s charge  ·  %s cooldown.%s",
					surge.Name,
					now.Name,
					change(surge.Cost or 0, now.Cost or 0, ""),
					change(surge.Cooldown or 0, now.Cooldown or 0, " s"),
					if sameItem(item, state.Pick) then "" else " " .. (surge.Description or "")
				)
			elseif surge then
				textValue = string.format(
					"<b>%s</b> on %s: %s charge  ·  %s s cooldown.%s",
					surge.Name,
					target,
					whole(surge.Cost or 0),
					whole(surge.Cooldown or 0),
					if sameItem(item, state.Pick) then "" else " " .. (surge.Description or "")
				)
			else
				textValue = "This gem has no surge."
			end
		else
			textValue = if current then "Pick a gem above to change " .. target .. ", or drag one onto any key." else "Pick a gem above to put a surge on " .. target .. "."
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
			elseif sameItem(item, state.Pick) then
				-- Tried on: the card above shows what it does.
				textValue = string.format(
					"<b>%s</b>  ·  %s %s%s",
					gemName(item.Gem),
					GemConfig.elementName(item.Gem.Element) .. "  ·",
					(GearRolls.Rarities[gemRarity(item.Gem)] or GearRolls.Rarities[1]).Name,
					if wornGem then ". Replaces " .. gemName(wornGem) .. ", which goes back to your stash." else ". Goes into the empty socket."
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
			local deltas = statDeltas(loadout, target, item.Id :: string)
			textValue = string.format(
				'<b>%s</b>  ·  rating <font color="#%s">%s%d</font>%s\n%s',
				item.Gear and item.Gear.Name or "This piece",
				if gain >= 0 then good else bad,
				if gain >= 0 then "+" else "",
				gain,
				if deltas ~= "" then "  ·  " .. deltas else "",
				if after then after.Definition.Name .. " " .. perkValue(after) .. ". Its own gem comes with it." else "Gems stay on their piece."
			)
		else
			textValue = if state.Tab == "Pieces"
				then "Pick a spare piece to compare it with what you wear."
				else "Pick a gem above, or drag one onto any piece."
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
	ui.Secondary.Position = if ui.Primary.Visible then UDim2.fromOffset(262, 572) else UDim2.fromOffset(0, 572)
	ui.Secondary.Size = if ui.Primary.Visible then UDim2.fromOffset(RIGHT_W - 262, 44) else UDim2.fromOffset(RIGHT_W, 44)
end

-- The strip of slots and keys along the top of the detail.
local function paintStrip(loadout)
	for key, entry in ui.Strip do
		local on = state.Detail == key
		entry.Edge.Color = if on then C.Gold else C.Line
		entry.Edge.Transparency = if on then 0 else 0.9
		entry.Tile.BackgroundTransparency = if on then 0.88 else 0.95
		if entry.Icon then
			local gear = gearOf(loadout, key)
			local color = if gear then rarityColor(rarityOf(loadout, key)) else C.Faint
			local iconKey = tostring(loadout[key]) .. "|" .. tostring(on)
			if entry.Key ~= iconKey then
				entry.Key = iconKey
				clear(entry.Icon)
				if gear then
					pcall(GearArt.icon, entry.Icon, key, gear, if on then C.Gold else color)
				end
			end
		else
			local gem = Tech.surgeGem(loadout, key)
			local keyColor = if triadOn(loadout) then KEY_COLORS[key] else nil
			entry.Tile.TextColor3 = if on then (keyColor or C.Gold) elseif gem then (keyColor or gemColor(gem)) else C.Faint
			if keyColor and on then
				entry.Edge.Color = keyColor
			end
		end
	end
end

local previewAsked = ""
local function drawDetail(loadout)
	local target = state.Detail
	ui.List.Visible = target == nil
	ui.Detail.Visible = target ~= nil
	if not target then
		return
	end
	paintStrip(loadout)
	local isKey = table.find(KEYS, target) ~= nil
	if not isKey then
		InventoryV2.drawTraits(nil)
	end
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
	local pick = state.Pick
	local gold = C.Gold:ToHex()
	if isKey then
		local current = Tech.surgeGem(loadout, target)
		local trying = if pick and pick.Kind == "Gem" then keyGem(pick.Gem, target, loadout) else nil
		local gem = trying or current
		local surge = gem and Tech.surgeStats(gem)
		local tint = if gem then gemColor(gem) else C.Faint
		ui.SurgeName.Text = if surge then surge.Name else "No surge on " .. target
		ui.SurgeMeta.Text = (if trying then string.format('<font color="#%s">TRYING ON</font>  ·  ', gold) else "")
			.. (if surge
				then string.format(
					'<font color="#%s">%s</font>  ·  %s %s  ·  %s S%s',
					tint:ToHex(),
					string.upper(GemConfig.elementName(gem.Element)),
					whole(surge.Cost or 0),
					string.upper(surge.Resource or "Charge"),
					whole(surge.Cooldown or 0),
					if surge.Triad then string.format("  ·  %s%% OUTPUT", whole((surge.Output or 1) * 100)) else ""
				)
				else "PICK A GEM BELOW")
		ui.SurgeGem.Text = if trying and current then "Replaces " .. gemName(current) .. " on " .. target
			elseif gem then "From " .. GemConfig.displayName(gem)
			else ""
		ui.SurgeIconEdge.Color = if trying then C.Gold else tint
		local shown = if gem then gem.Id .. tostring(gem.Surge) else ""
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
		ui.PerkName.Text = if surge
			then (if surge.Flourished and surge.Flourish then "WHAT IT DOES  ·  LEGENDARY FLOURISH" else "WHAT IT DOES")
			else ""
		ui.PerkText.Text = if surge
			then (surge.Description or "") .. (if surge.Flourished and surge.Flourish then "  " .. surge.Flourish.Text else "")
			elseif triadOn(loadout) then string.format("%s fires the %s of the gem in your %s. Any cut gem fits.", target, string.lower(Traits.Lanes[target]), string.lower(Traits.SocketNames[target]))
			else "Surges are cast with Q, E and R in a fight. Any cut gem with a surge fits."
		InventoryV2.drawTraits(gem, target)
		ui.PerkText.Size = UDim2.fromOffset(RIGHT_W - 36, 60)
		ui.PerkValue.Text = ""
		drawTabs({ { "Gems", if triadOn(loadout) then string.upper(Traits.SocketNames[target]) .. " GEMS" else "SURGE GEMS" } })
		drawFilters(true)
		local items = {}
		for _, g in gemsFor(true, state.Filter) do
			table.insert(items, { Kind = "Gem", Gem = g })
		end
		drawGrid(items, "No surge gems yet. Cut a gem at the Outpost to unlock its surge.")
	else
		local slot = target
		local wornId = loadout[slot]
		local wornGem = loadout[slot .. "Gem"]
		-- A pick is tried on in place: its piece (with that piece's own gem),
		-- or its gem in this piece.
		local tryPiece = if pick and pick.Kind == "Piece" then pick.Id else nil
		local tryGem = if pick and pick.Kind == "Gem" then pick.Gem else nil
		local viewId = tryPiece or wornId
		local gem = if tryGem then tryGem
			elseif tryPiece then (loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][tryPiece])
			else wornGem
		local gear = gearOf(loadout, slot, viewId)
		local rarity = if gear then rarityOf(loadout, slot, viewId) else 1
		local color = rarityColor(rarity)
		-- The piece.
		local well = ui.PieceWell
		local pieceKey = tostring(viewId) .. "|" .. tostring(ui.ArtVersion or 0) .. "|" .. tostring(tryPiece ~= nil)
		if well.Key ~= pieceKey then
			well.Key = pieceKey
			if viewId then
				gearArt(well.Art, slot, viewId, tryPiece == nil, color)
			else
				clear(well.Art)
			end
		end
		well.Empty.Visible = gear == nil
		well.Edge.Color = if tryPiece or state.Tab == "Pieces" then C.Gold else color
		well.Edge.Transparency = if tryPiece then 0 elseif state.Tab == "Pieces" then 0.2 else 0.5
		well.Name.Text = if gear then gear.Name else "Nothing worn"
		local stat = topStat(GearRolls.get(loadout, slot, viewId))
		if tryPiece then
			local gain = ratingGain(loadout, slot, tryPiece)
			well.Sub.Text = string.format("TRYING ON  ·  RATING %s%d", if gain >= 0 then "+" else "", gain)
			well.Sub.TextColor3 = C.Gold
		else
			well.Sub.Text = if gear then rarityName(rarity) .. (if stat then "  ·  " .. string.upper(stat) else "") else "PICK ONE BELOW"
			well.Sub.TextColor3 = color
		end
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
		gw.Edge.Color = if tryGem then C.Gold elseif gem then gemColor(gem) else C.Line
		gw.Edge.Transparency = if gem then 0 else 0.85
		gw.Name.Text = if gem then gemName(gem) else "Empty socket"
		if tryGem then
			gw.Sub.Text = "TRYING ON"
			gw.Sub.TextColor3 = C.Gold
		else
			gw.Sub.Text = if gem
				then string.upper(GemConfig.elementName(gem.Element)) .. "  ·  " .. rarityName(gemRarity(gem))
				else "ENCHANTING IS PURE GAIN"
			gw.Sub.TextColor3 = if gem then gemColor(gem) else C.Dim
		end
		-- The triad: the sword's gem is your Q, the shield's your R.
		local slotKey = if triadOn(loadout) then (if slot == "Weapon" then "Q" elseif slot == "Shield" then "R" else nil) else nil
		local move = slotKey and gem and Tech.Catalog[Traits.traitFor(gem, slotKey) or ""]
		if move then
			gw.Sub.Text = slotKey .. "  ·  " .. string.upper(move.Name)
			gw.Sub.TextColor3 = KEY_COLORS[slotKey]
		end
		-- The perk: now, with the gem, or (trying something on) now -> then.
		local signature = gear and perkOf(loadout, slot, viewId, gem)
		local current = perkOf(loadout, slot, nil, wornGem)
		ui.PerkText.Size = UDim2.fromOffset(RIGHT_W - 36, 30)
		ui.PerkValue.TextSize = 18
		ui.PerkValue.TextWrapped = false
		ui.PerkValue.TextYAlignment = Enum.TextYAlignment.Top
		ui.PerkValue.Position = UDim2.fromOffset(18, 228)
		ui.PerkValue.Size = UDim2.fromOffset(RIGHT_W - 36, 26)
		if signature then
			local d = signature.Definition
			ui.PerkName.Text = string.upper(d.Name)
			ui.PerkText.Text = d.Trigger
			if (tryGem or tryPiece) and current and current.Id == signature.Id then
				local better = signature.Value >= current.Value - 1e-6
				ui.PerkValue.Text = string.format(
					'<font color="#%s">NOW %s</font>  <font color="#%s">→</font>  <font color="#%s">%s</font>',
					C.Dim:ToHex(),
					perkValue(current),
					C.Faint:ToHex(),
					(if better then C.Good else C.Bad):ToHex(),
					perkValue(signature)
				)
			elseif gem and signature.Value > signature.Base + 1e-6 then
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
				ui.PerkValue.TextSize = 12
				ui.PerkValue.TextWrapped = true
				ui.PerkValue.TextTruncate = Enum.TextTruncate.None
				ui.PerkValue.Position = UDim2.fromOffset(18, 220)
				ui.PerkValue.Size = UDim2.fromOffset(RIGHT_W - 36, 36)
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
			-- Spare pieces' 3D art comes from the server: ask once per list.
			local askKey = slot .. ":" .. #items
			if #items > 0 and previewAsked ~= askKey then
				previewAsked = askKey
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

-- Item cards: hover a worn piece for everything about it, beside the list.
do
	local TIP_W = 290
	local tip: Frame? = nil
	local tipEdge: UIStroke? = nil
	function InventoryV2.hideTip()
		if tip then
			tip.Visible = false
		end
	end
	function InventoryV2.showTip(slot: string, row: GuiObject)
		local loadout = loadoutNow()
		local gear = gearOf(loadout, slot)
		if not gear or not ui.Canvas then
			InventoryV2.hideTip()
			return
		end
		if not tip then
			tip = frame(ui.Canvas, Color3.fromRGB(12, 16, 25), 0.03)
			local made = tip :: Frame
			made.Name = "ItemCard"
			made.ZIndex = 20
			round(made, 12)
			tipEdge = stroke(made, C.Line, 1, 0.55)
		end
		local card = tip :: Frame
		clear(card)
		local rarity = rarityOf(loadout, slot)
		local color = rarityColor(rarity)
		if tipEdge then
			tipEdge.Color = color
		end
		local y = 14
		local function line(value: string, size: number, color3: Color3, font: Enum.Font, h: number, wrap: boolean?)
			local l = place(text(card, value, size, color3, font), 16, y, TIP_W - 32, h)
			l.RichText = true
			l.ZIndex = 21
			if wrap then
				l.TextWrapped = true
				l.TextTruncate = Enum.TextTruncate.None
				l.TextYAlignment = Enum.TextYAlignment.Top
			end
			y += h + 4
			return l
		end
		line(gear.Name, 16, color, HEAVY, 20)
		line(rarityName(rarity) .. "  ·  " .. SLOT_NAME[slot], 10, C.Dim, HEADING, 12)
		y += 4
		local rule = frame(card, C.Line, 0.9)
		place(rule, 16, y, TIP_W - 32, 1)
		rule.ZIndex = 21
		y += 10
		local roll = GearRolls.get(loadout, slot)
		local stats = {}
		for stat, amount in roll and roll.Stats or {} do
			table.insert(stats, statText(stat, amount))
		end
		table.sort(stats)
		for _, entry in stats do
			line(entry, 13, C.Good, HEADING, 16)
		end
		local gem = loadout[slot .. "Gem"]
		local signature = perkOf(loadout, slot, nil, gem)
		if signature then
			y += 4
			line(string.upper(signature.Definition.Name), 10, C.Gold, HEADING, 12)
			line(signature.Definition.Trigger, 11, C.Dim, MEDIUM, 28, true)
			line(perkValue(signature), 14, C.Good, HEAVY, 18)
		end
		y += 4
		if gem then
			line(string.format("◆  %s  ·  %s", gemName(gem), GemConfig.elementName(gem.Element)), 12, gemColor(gem), HEADING, 16)
		else
			line("◇  Empty gem socket", 12, C.Faint, HEADING, 16)
		end
		local family = ArmorFamilies.ById[loadout[slot]]
		if family and family.ArmorFamily then
			local ok, setState = pcall(Classes.setState, loadout)
			local count = ok and setState.Active[family.ArmorFamily] and setState.Active[family.ArmorFamily].Count or 0
			line(string.format("%s SET  %d/6", string.upper(family.ArmorFamily), count), 10, ArmorFamilies.Families[family.ArmorFamily].Color, HEADING, 12)
		end
		line("CLICK TO CHANGE  ·  DROP A GEM TO SOCKET", 9, C.Faint, HEADING, 12)
		y += 6
		-- Beside the row, inside the screen.
		local rowY = (row.Position.Y.Offset or 0) + 96
		local top = math.clamp(rowY - 8, 70, H - 40 - y)
		card.Position = UDim2.fromOffset(RIGHT_X - TIP_W - 14, top)
		card.Size = UDim2.fromOffset(TIP_W, y)
		card.Visible = true
	end
end

local queued = false
local drawIntro -- (below, with the intro card)
local introDone = false -- dismissed this session (survives the screen being rebuilt)
-- The GEMS button: available stones and the best loose stone on its icon.
local gemsShown = nil
local function drawGemsButton(profile, loadout)
	if not ui.GemsCount then
		return
	end
	local best, bestRank = nil, -1
	local available = GemInventory.available(profile)
	for _, gem in available do
		local rank = (GEM_RARITY[gem.Tier] or 0) * 100 + (gem.Size or 0)
		if rank > bestRank then
			best, bestRank = gem, rank
		end
	end
	ui.GemsCount.Text = string.format("%d AVAILABLE", #available)
	local key = best and best.Id or ""
	if gemsShown ~= key then
		gemsShown = key
		clear(ui.GemsIcon)
		if best then
			gemArt(ui.GemsIcon, best)
		end
	end
end

-- The SKINS button: what this miner wears, and how many looks you own.
local skinsShown = nil
local function drawSkinsButton(profile)
	if not ui.SkinsCount then
		return
	end
	local cosmetics = profile.Cosmetics or {}
	local suits, skins, picks = 0, 0, 0
	for id in cosmetics.Owned or {} do
		local cosmetic = Cosmetics.get(id)
		if cosmetic and cosmetic.Kind == "Suit" then
			suits += 1
		elseif cosmetic and cosmetic.Kind == "Skin" then
			skins += 1
		elseif cosmetic and cosmetic.Kind == "Pick" then
			picks += 1
		end
	end
	local suit, skin = Cosmetics.get(cosmetics.Suit), Cosmetics.get(cosmetics.Skin)
	local function count(n: number, what: string): string
		return string.format("%d %s%s", n, what, if n == 1 then "" else "S")
	end
	ui.SkinsCount.Text = count(suits, "SUIT") .. "  ·  " .. count(skins, "SKIN") .. "  ·  " .. count(picks, "PICK")
	local key = tostring(cosmetics.Suit) .. "/" .. tostring(cosmetics.Skin)
	if skinsShown ~= key then
		skinsShown = key
		clear(ui.SkinsIcon)
		local show = suit or skin
		if show then
			ShopArt.icon(ui.SkinsIcon, "Cosmetic", show.Id, 40)
		else
			local mark = text(ui.SkinsIcon, "◇", 22, Color3.fromRGB(255, 150, 205), HEAVY)
			mark.Size = UDim2.fromScale(1, 1)
			mark.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
end

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
		drawGemsButton(profile, loadout)
		drawSkinsButton(profile)
		drawNudge(profile, loadout)
		drawKeys(loadout)
		drawDetail(loadout)
		drawIntro(profile, loadout)
	end)
end

-- What's new: the triad, explained once ---------------------------------------------------------------

local function buildIntro(canvas: Frame)
	local shade = new("TextButton", {
		Name = "TriadIntro",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(4, 6, 10),
		BackgroundTransparency = 0.25,
		Visible = false,
		ZIndex = 40,
	}, canvas)
	place(shade, -400, -200, W + 800, H + 400)
	local panel = frame(shade, Color3.fromRGB(12, 16, 24), 0.02)
	panel.ZIndex = 41
	place(panel, 400 + 300, 200 + 150, 1000, 520)
	round(panel, 18)
	stroke(panel, C.Gold, 1.5, 0.35)
	local function label(value: string, size: number, color: Color3, font: Enum.Font, x: number, y: number, w: number, h: number)
		local t = place(text(panel, value, size, color, font), x, y, w, h)
		t.ZIndex = 42
		t.TextWrapped = true
		t.TextYAlignment = Enum.TextYAlignment.Top
		return t
	end
	label("NEW  ·  THE TRIAD", 12, C.Gold, HEAVY, 48, 36, 600, 16)
	label("Every key has a job.", 34, C.Text, HEAVY, 48, 58, 900, 42)
	label("Every gem carries three moves: an Offense, an Ability and a Defense. The socket a gem sits in decides which one you use.", 14, C.Dim, MEDIUM, 48, 108, 900, 40)
	local columns = {
		{ "Q", "OFFENSE", "Your sword's gem", "A sword technique: hit harder, wider or smarter. Pays Charge." },
		{ "E", "ABILITY", "Your core gem", "Your elemental surge: a strike, a dash or an aura that helps while it's ready. Pays Charge." },
		{ "R", "DEFENSE", "Your shield's gem", "Survive pressure: walls, shields, cleanses. Pays Stamina, so it works from the first second." },
	}
	for i, column in columns do
		local x = 48 + (i - 1) * 306
		local card = frame(panel, KEY_COLORS[column[1]]:Lerp(C.Ink, 0.85), 0)
		card.ZIndex = 42
		place(card, x, 168, 290, 200)
		round(card, 14)
		stroke(card, KEY_COLORS[column[1]], 1.5, 0.3)
		local badge = place(text(card, column[1], 30, C.Ink, HEAVY), 20, 20, 52, 52)
		badge.ZIndex = 43
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = KEY_COLORS[column[1]]
		round(badge, 12)
		local lane = place(text(card, column[2], 12, KEY_COLORS[column[1]], HEAVY), 88, 24, 190, 16)
		lane.ZIndex = 43
		local from = place(text(card, column[3], 18, C.Text, HEADING), 88, 44, 190, 22)
		from.ZIndex = 43
		local body = place(text(card, column[4], 13, C.Dim, MEDIUM), 20, 92, 250, 90)
		body.ZIndex = 43
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		-- A few of the moves, one per element.
		local lane = Traits.Lanes[column[1]]
		local names = {}
		for _, element in { "Fire", "Frost", "Shock", "Poison" } do
			local move = Tech.Catalog[Traits.Matrix[element][lane][2]]
			if move then
				table.insert(names, string.format('<font color="#%s">%s</font>', GemConfig.ElementColors[element]:ToHex(), move.Name))
			end
		end
		local like = place(text(card, "LIKE  " .. table.concat(names, "  ·  "), 11, C.Faint, HEADING), 20, 152, 250, 34)
		like.ZIndex = 43
		like.RichText = true
		like.TextWrapped = true
		like.TextYAlignment = Enum.TextYAlignment.Top
	end
	label("Rarity sets the power: Common 60% · Uncommon 70% · Rare 80% · Ultra Rare 90% · Legendary 100% and a Flourish.", 13, C.Text, HEADING, 48, 388, 900, 18)
	ui.IntroNote = label("", 13, C.Dim, MEDIUM, 48, 412, 900, 36)
	local ok = new("TextButton", {
		Name = "TriadGotIt",
		Text = "GOT IT",
		Font = HEAVY,
		TextSize = 15,
		TextColor3 = C.Ink,
		AutoButtonColor = false,
		BackgroundColor3 = C.Gold,
		ZIndex = 42,
	}, panel)
	place(ok, 1000 - 48 - 200, 450, 200, 46)
	round(ok, 10)
	ok:SetAttribute("UiSound", "Confirm")
	ok.Activated:Connect(function()
		shade.Visible = false
		introDone = true
		request("TriadSeen")
	end)
	ui.Intro = shade
end
drawIntro = function(profile, loadout)
	if not ui.Intro then
		return
	end
	-- Only for a returning miner whose old surge gems were moved (a new one
	-- learns Q, E and R in the intro), only on the open Inventory (never
	-- behind a loading screen), and once.
	local show = state.Active == true
		and triadOn(loadout)
		and profile.TriadSeen ~= true
		and (profile.TriadNotice or 0) > 0
		and not introDone
	ui.Intro.Visible = show
	if show then
		ui.IntroNote.Text = if (profile.TriadNotice or 0) > 0
			then string.format("Your old Q and R surge gems (%d) are back in your stash, safe: socket them in a sword, a shield or the core.", profile.TriadNotice)
			else "Socket gems in your sword, your shield and the core slot to fill Q, E and R."
	end
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
	ui.Canvas = canvas
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
	buildIntro(canvas)
	host:GetPropertyChangedSignal("Enabled"):Connect(function()
		if host.Enabled then
			draw()
		else
			InventoryV2.cancelDrag()
			InventoryV2.hideTip()
			GemVault.close()
			Wardrobe.close()
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
		if ui.Intro then
			ui.Intro.Visible = false
		end
		InventoryV2.cancelDrag()
		GemVault.close()
		Wardrobe.close()
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
		for _, gem in GemInventory.available(profile) do
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
-- Backspace steps back out of a piece (as the ‹ does).
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and drag then
		InventoryV2.cancelDrag()
		return
	end
	if input.KeyCode == Enum.KeyCode.Backspace and state.Active and gui and gui.Enabled and state.Detail then
		if state.Pick then
			state.Pick, state.Hover = nil, nil
			draw()
		else
			openDetail(nil)
		end
	end
end)
-- Turning the miner: drag across them.
UserInputService.InputChanged:Connect(function(input)
	local turning = ui.Turning
	if not turning then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement or (turning.Touch and input.UserInputType == Enum.UserInputType.Touch) then
		local dx = input.Position.X - turning.X
		turning.X = input.Position.X
		ui.MinerYaw = (ui.MinerYaw or 0) - dx * 0.012
		InventoryV2.aimMiner()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if ui.Turning and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		ui.Turning = nil
	end
end)
-- The element radar eases to new values, and an empty gem socket on a worn
-- piece breathes gold: the next thing to do.
game:GetService("RunService").Heartbeat:Connect(function(dt)
	if state.Active and gui and gui.Enabled and ui.AttackRadar then
		StatRadar.step(ui.AttackRadar, dt)
		StatRadar.step(ui.ResistRadar, dt)
		local loadout = loadoutNow()
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * 3.5)
		for slot, row in ui.Rows or {} do
			if loadout[slot] and not loadout[slot .. "Gem"] then
				row.Ring.Color = C.Gold
				row.Ring.Transparency = 0.35 - 0.25 * pulse
				row.Halo.BackgroundTransparency = 0.92 - 0.12 * pulse
				row.Plus.TextColor3 = C.Gold
			end
		end
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
