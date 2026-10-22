--[[
	Inventory v2: the miner owns the screen.

	  Top        back to the lobby, the other screens, your coins / season /
	             free pick
	  Left       your sword and shield (each with its gem socket), GEMS and
	             SKINS, then every loose gem you have: a tab per element, and
	             each gem with its rarity and its tier level ("T3 II"). Drag
	             one onto a piece or a key; click one for the gem window
	  Centre     your miner, large, on a lit floor. Left of it, who you are:
	             name, level, a big rating, four stat bars, your armor set,
	             what you're strong against and weak to, and AUTO EQUIP
	             (Shared.AutoEquip): BEST, BALANCED or an element, in a tap
	  Right      your four armor pieces, each with its gem socket, then your
	             spare gear: a tab per slot, and each piece with the rating
	             it would add. Click a row (or a spare piece) and the column
	             turns into that piece: the piece and its gem, its perk, then
	             the gems (or spare pieces) you could swap in. Hover one to
	             see what it would change; click it, then SOCKET or EQUIP.
	             A slot's gem stays in the slot: a new piece takes it on
	  Bottom     the Surge Array (Q / E / R); click one to change its gem

	(Compact, on a phone: the miner on the left with GEMS, SKINS and AUTO,
	two columns of three rows, Q / E / R under them.)

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
local AutoEquip = require(ReplicatedStorage.Shared.AutoEquip)
local ElementMatchup = require(ReplicatedStorage.Shared.ElementMatchup)
local Classes = require(ReplicatedStorage.Shared.Classes)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local GemRoller = require(ReplicatedStorage.Shared.GemRoller)
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
-- and reads one socket: Q the sword's gem, E the chest's, R the shield's.
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

-- The layout is drawn at 1600 x 840 and scaled to the screen. Where that
-- would read too small (a phone), it's built compact instead (see
-- chooseLayout): 990 x 380, no stats column, everything else larger.
local W, H = 1600, 840
local TOPBAR, BOTTOM = 58, 36 -- Roblox's own buttons above (UiKit.topbar); chat and DEV below
local RIGHT_X, RIGHT_W = 1170, 390
local LEFT_X, LEFT_W = 40, 390 -- (full: the sword and shield, then your gems)
local STATS_X, STATS_W = 460, 262 -- (full: you, your stats and AUTO EQUIP, left of the miner)
local COMPACT = false

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
		-- (compact, the small print grows: it's drawn smaller on a phone)
		TextSize = if COMPACT then math.max(size, 13) else size,
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
-- The gem a piece would wear in this slot: the slot's gem stays in the slot
-- (it moves onto the new piece: PlayerData.equipGear); an empty slot takes
-- the piece's own, if it kept one.
local function slotGemFor(loadout, slot: string, id: string?)
	return loadout[slot .. "Gem"] or (id and loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id]) or nil
end
-- "Health +12 · Power −3": what each stat does if this piece goes on.
local function statDeltas(loadout, slot: string, id: string): string
	local before = ratings(loadout)
	local trial = table.clone(loadout)
	trial[slot] = id
	local profile = profileNow()
	trial[slot .. "Quality"] = profile and profile.Owned and profile.Owned[Slots.Definitions[slot].Kind][id]
	trial[slot .. "Gem"] = slotGemFor(loadout, slot, id)
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
	trial[slot .. "Gem"] = slotGemFor(loadout, slot, id)
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
	AutoMode = "Best", -- AUTO EQUIP's mode (Shared.AutoEquip.Modes)
	PouchFilter = "All", -- your gems (full, left): "All" or an element
	BagFilter = "All", -- your spare gear (full, right): "All" or a slot
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
		Text = if COMPACT then "‹  LOBBY" else "‹   BACK TO LOBBY",
		TextSize = if COMPACT then 15 else 13,
		Font = HEAVY,
		TextColor3 = Color3.fromRGB(26, 18, 6),
		AutoButtonColor = false,
		BackgroundColor3 = C.Gold,
	}, canvas)
	if COMPACT then
		place(back, 0, 6, 128, 40)
	else
		place(back, 0, 8, 186, 40)
	end
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
	if COMPACT then
		place(tabs, 144, 6, 520, 40)
	else
		place(tabs, 216, 8, 820, 40)
	end
	-- (the row shrinks to fit if a language's words run longer)
	local row = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, tabs)
	local list = UiKit.list(row, if COMPACT then 16 else 28, true)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	UiKit.shrinkRow(row, list)
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
		}, row)
		local inner = UiKit.list(slot, 6, true)
		inner.VerticalAlignment = Enum.VerticalAlignment.Center
		local b = new("TextButton", {
			Text = spec[1],
			TextSize = if COMPACT then 14 else 13,
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
		if spec[3] and keyboard and not COMPACT then
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
	local readW = if COMPACT then 116 else 150
	local function readout(x: number, caption: string)
		local value = text(canvas, "", 18, C.Text, HEAVY)
		place(value, x, 8, readW, 22)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local cap = text(canvas, caption, 10, C.Dim, HEADING)
		place(cap, x, 30, readW, 14)
		cap.TextXAlignment = Enum.TextXAlignment.Right
		if COMPACT then
			UiKit.fit(cap)
		end
		return value, cap
	end
	local step, margin = if COMPACT then 124 else 180, if COMPACT then 0 else 10
	ui.Coins = readout(W - margin - readW - 2 * step, "COINS")
	ui.Season, ui.SeasonCap = readout(W - margin - readW - step, "SEASON")
	ui.Pick, ui.PickCap = readout(W - margin - readW, "FREE PICK")
	local track = frame(canvas, C.Line, 0.92)
	place(track, W - margin - step - 96, 47, 96, 3)
	round(track, 2)
	ui.SeasonFill = frame(track, C.Teal)
	ui.SeasonFill.Size = UDim2.fromScale(0, 1)
	round(ui.SeasonFill, 2)
	local seasonHit = hit(ui.Season)
	seasonHit.Size = UDim2.new(1, 0, 0, 40)
	seasonHit.Activated:Connect(open("SeasonUI", "toggle"))
end

-- AUTO EQUIP (Shared.AutoEquip): BEST, BALANCED, then an element each; the
-- button puts that build on (the server's "AutoEquip"). Full: a block in the
-- stats card. Compact: an AUTO button over the miner, its modes under it.
local function buildAuto(parent: Instance, x: number, y: number, w: number)
	ui.AutoModes = {}
	local function chip(holder: Instance, mode: string, cx: number, cy: number, cw: number, ch: number)
		local b = new("TextButton", {
			Name = "Auto" .. mode,
			Text = AutoEquip.label(mode),
			TextSize = if table.find(ELEMENTS, mode) then 9 else 10,
			Font = HEADING,
			TextColor3 = C.Dim,
			AutoButtonColor = false,
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.4,
		}, holder)
		place(b, cx, cy, cw, ch)
		round(b, 7)
		UiKit.fit(b)
		local edge = stroke(b, C.Line, 1, 0.85)
		b:SetAttribute("UiSound", "Tab")
		ui.AutoModes[mode] = { Button = b, Edge = edge }
		return b
	end
	if COMPACT then
		-- AUTO over the miner; its six modes drop under it, a tap puts one on.
		ui.AutoGo = new("TextButton", {
			Name = "AutoEquip",
			Text = "AUTO",
			TextSize = 13,
			Font = HEAVY,
			TextColor3 = Color3.fromRGB(26, 18, 6),
			AutoButtonColor = true,
			BackgroundColor3 = C.Gold,
		}, parent)
		place(ui.AutoGo, x, y, w, 30)
		round(ui.AutoGo, 8)
		ui.AutoGo:SetAttribute("UiSound", "Click")
		local menu = frame(parent, C.Deep, 0.04)
		menu.Name = "AutoMenu"
		menu.Visible = false
		menu.ZIndex = 8
		place(menu, x + w - 212, y + 36, 212, 120)
		round(menu, 10)
		stroke(menu, C.Gold, 1, 0.5)
		ui.AutoMenu = menu
		for i, mode in AutoEquip.Modes do
			local b = chip(menu, mode, 8 + ((i - 1) % 2) * 100, 8 + math.floor((i - 1) / 2) * 36, 96, 30)
			b.ZIndex = 9
			b.Activated:Connect(function()
				state.AutoMode = mode
				menu.Visible = false
				request("AutoEquip", mode)
			end)
		end
		ui.AutoGo.Activated:Connect(function()
			menu.Visible = not menu.Visible
		end)
		return
	end
	place(text(parent, "AUTO EQUIP", 11, C.Gold, HEAVY), x, y, 110, 14)
	ui.AutoPreview = place(text(parent, "", 10, C.Dim, HEADING), x + 96, y, w - 96, 14)
	ui.AutoPreview.TextXAlignment = Enum.TextXAlignment.Right
	ui.AutoPreview.RichText = true
	UiKit.fit(ui.AutoPreview)
	y += 20
	local half = (w - 6) / 2
	for i, mode in { "Best", "Balanced" } do
		chip(parent, mode, x + (i - 1) * (half + 6), y, half, 26).Activated:Connect(function()
			state.AutoMode = mode
			draw()
		end)
	end
	y += 32
	local quarter = (w - 18) / 4
	for i, mode in ELEMENTS do
		chip(parent, mode, x + (i - 1) * (quarter + 6), y, quarter, 26).Activated:Connect(function()
			state.AutoMode = mode
			draw()
		end)
	end
	y += 34
	ui.AutoGo = new("TextButton", {
		Name = "AutoEquip",
		Text = "AUTO EQUIP",
		TextSize = 14,
		Font = HEAVY,
		TextColor3 = Color3.fromRGB(26, 18, 6),
		AutoButtonColor = true,
		BackgroundColor3 = C.Gold,
	}, parent)
	place(ui.AutoGo, x, y, w, 42)
	round(ui.AutoGo, 10)
	ui.AutoGo:SetAttribute("UiSound", "Confirm")
	ui.AutoGo.Activated:Connect(function()
		if ui.AutoPlan and ui.AutoPlan.Changes > 0 then
			request("AutoEquip", state.AutoMode)
		end
	end)
end

local function buildLeft(canvas: Frame)
	local x, w = STATS_X, STATS_W
	-- Compact keeps only miner 1 / 2 / 3 and the name (over the miner): the
	-- rest is built (the draw code fills it in) but hidden.
	local box = canvas
	if COMPACT then
		box = new(
			"Frame",
			{ Name = "Stats", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false },
			canvas
		)
	end
	-- Miner 1 / 2 / 3 (none while the roster is off: one miner).
	ui.Miners = {}
	for index = 1, if MinerRoster.Enabled then MinerRoster.Count else 0 do
		local b = new("TextButton", {
			Text = tostring(index),
			TextSize = 13,
			Font = HEADING,
			TextColor3 = C.Faint,
			AutoButtonColor = false,
			BackgroundColor3 = C.Gold,
			BackgroundTransparency = 1,
		}, canvas)
		if COMPACT then
			place(b, (index - 1) * 38, 54, 32, 32)
		else
			place(b, x + (index - 1) * 40, 96, 32, 32)
		end
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
	local nameY = if MinerRoster.Enabled then 134 else 96
	if COMPACT then
		local nameX = if MinerRoster.Enabled then 116 else 0
		ui.Name = place(text(canvas, "", 22, C.Text, HEAVY), nameX, 54, RIGHT_X - 12 - nameX, 32)
	else
		ui.Name = place(text(canvas, "", 32, C.Text, HEAVY), x, nameY, w + 40, 38)
	end
	ui.Sub = place(text(box, "", 11, C.Dim, HEADING), x, nameY + 40, w, 16)
	ui.LevelBonus = place(text(box, "", 10, C.Teal, BODY), x, nameY + 58, w + 40, 13)
	UiKit.fit(ui.LevelBonus)
	-- The card: the rating and four stats, the set, the elements, AUTO EQUIP.
	local cardY = nameY + 82
	local card = frame(box, Color3.fromRGB(255, 255, 255), 0.965)
	card.Name = "StatsCard"
	place(card, x - 16, cardY, w + 32, 744 - cardY)
	round(card, 14)
	stroke(card, C.Line, 1, 0.92)
	local y = cardY + 8
	-- The rating, big, with its caption beside it on the same baseline.
	local ratingRow = new("Frame", { BackgroundTransparency = 1 }, box)
	place(ratingRow, x, y, w, 56)
	local rowList = UiKit.list(ratingRow, 12, true)
	rowList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	ui.Rating = text(ratingRow, "0", 48, C.Gold, HEAVY)
	ui.Rating.Size = UDim2.fromOffset(0, 56)
	ui.Rating.AutomaticSize = Enum.AutomaticSize.X
	ui.Rating.TextTruncate = Enum.TextTruncate.None
	ui.Rating.LayoutOrder = 1
	ui.RatingCap = text(ratingRow, "RATING", 11, C.Dim, HEADING)
	ui.RatingCap.Size = UDim2.fromOffset(80, 28)
	ui.RatingCap.LayoutOrder = 2
	y += 66
	-- Four stat bars.
	ui.Stats = {}
	for i, stat in Classes.StatNames do
		local sy = y + (i - 1) * 30
		place(text(box, string.upper(stat), 10, C.Dim, HEADING), x, sy, 70, 16)
		local track = frame(box, C.Line, 0.93)
		place(track, x + 72, sy + 6, w - 72 - 52, 4)
		round(track, 2)
		local fill = frame(track, STAT_COLOR[stat])
		fill.Size = UDim2.fromScale(0, 1)
		round(fill, 2)
		local value = place(text(box, "0", 15, C.Text, HEAVY), x + w - 46, sy - 2, 46, 20)
		value.TextXAlignment = Enum.TextXAlignment.Right
		ui.Stats[stat] = { Fill = fill, Value = value, Last = nil }
	end
	y += 4 * 30
	ui.Vitals = place(text(box, "", 10, C.Teal, HEADING), x, y, w, 14)
	UiKit.fit(ui.Vitals)
	y += 22
	-- The armor set.
	place(frame(box, C.Line, 0.93), x, y, w, 1)
	y += 10
	ui.SetName = place(text(box, "", 11, C.Teal, HEADING), x, y, 170, 16)
	ui.Pips = {}
	for i = 1, 6 do
		local pip = frame(box, C.Line, 0.9)
		place(pip, x + w - 6 * 17 + (i - 1) * 17, y + 6, 12, 4)
		round(pip, 2)
		ui.Pips[i] = pip
	end
	y += 20
	ui.SetBonus = place(text(box, "", 12, C.Text, HEADING), x, y, w, 18)
	ui.SetBonus.RichText = true
	UiKit.fit(ui.SetBonus)
	y += 18
	ui.SetNext = place(text(box, "", 11, C.Dim, BODY), x, y, w, 30)
	ui.SetNext.TextWrapped = true
	ui.SetNext.TextYAlignment = Enum.TextYAlignment.Top
	y += 34
	-- Elements: what you're strong against, weak to and resist (Shared.ElementMatchup).
	place(frame(box, C.Line, 0.93), x, y, w, 1)
	y += 10
	ui.Verdict = {}
	for i, caption in { "STRONG VS", "WEAK TO", "RESISTS" } do
		UiKit.fit(place(text(box, caption, 10, C.Dim, HEADING), x, y + 1, 92, 16))
		local value = place(text(box, "", 12, C.Text, HEADING), x + 98, y, w - 98, 18)
		value.RichText = true
		UiKit.fit(value)
		local detail = text(box, "", 10, C.Faint, MEDIUM)
		detail.Visible = false
		ui.Verdict[i] = { Value = value, Detail = detail }
		y += 22
	end
	-- (the radar and the gem mix: drawn by drawLeft, shown on no layout now)
	local axes = {}
	for i, element in ELEMENTS do
		axes[i] = { Name = string.upper(GemConfig.elementName(element)), Color = GemConfig.ElementColors[element] or C.Text }
	end
	ui.AttackRadar = StatRadar.create(box, axes, 68, C.Gold)
	ui.ResistRadar = StatRadar.create(box, axes, 68, C.Teal, { Web = false, Labels = false })
	for _, radar in { ui.AttackRadar, ui.ResistRadar } do
		radar.Frame.Visible = false
	end
	ui.Mix = text(box, "", 11, C.Dim, HEADING)
	ui.Mix.Visible = false
	-- AUTO EQUIP at the foot of the card.
	y = 744 - 14 - 128
	place(frame(box, C.Line, 0.93), x, y - 12, w, 1)
	if COMPACT then
		-- (over the miner, top right of its column)
		buildAuto(canvas, RIGHT_X - 12 - 96, 92, 96)
	else
		buildAuto(box, x, y, w)
	end
end

local function buildStage(canvas: Frame)
	-- (compact, the miner stands in the left column, under the name: the
	-- same stage at about a third of the size)
	local k = if COMPACT then 0.36 else 1
	-- (full: right of the stats card, between it and your armor)
	local cx, floorY = if COMPACT then (RIGHT_X - 12) / 2 else 942, if COMPACT then 306 else 714
	glow(canvas, cx, if COMPACT then 210 else 430, (if COMPACT then 360 else 290) * k, C.Teal, 1)
	-- The floor: a soft pool of light under the feet and a thin bright line.
	for i = 1, 8 do
		local pool = frame(canvas, C.Teal, 0.975)
		pool.AnchorPoint = Vector2.new(0.5, 0.5)
		place(pool, cx, floorY, (if COMPACT then 140 + i * 60 else 100 + i * 40) * k, (10 + i * 7) * k)
		pool.Position = UDim2.fromOffset(cx, floorY)
		round(pool, 9999)
	end
	local line = frame(canvas, C.Teal, 0.2)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	place(line, cx, floorY, (if COMPACT then 520 else 400) * k, 2)
	line.Position = UDim2.fromOffset(cx, floorY)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, line)
	local horizon = frame(canvas, C.Line, 0.95)
	local reach = if COMPACT then 380 else 220
	place(horizon, cx - reach * k, floorY - 64 * k, 2 * reach * k, 1)
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
	if COMPACT then
		place(ui.MinerView, 0, 90, RIGHT_X - 12, 230)
	else
		place(ui.MinerView, cx - 300, 80, 600, 650)
	end
	ui.MinerSource = nil
	ui.MinerYaw = 0
	-- Drag across the miner to turn them.
	local turn = new("TextButton", { Name = "TurnMiner", Text = "", AutoButtonColor = false, BackgroundTransparency = 1 }, canvas)
	if COMPACT then
		place(turn, 0, 90, RIGHT_X - 12, 230)
	else
		place(turn, cx - 220, 110, 440, 600)
	end
	turn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ui.Turning = { X = input.Position.X, Touch = input.UserInputType == Enum.UserInputType.Touch }
		end
	end)
	local hint = place(text(canvas, "DRAG TO TURN", 10, C.Faint, HEADING), cx - 100, 728, 200, 14)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextTransparency = 0.3
	hint.Visible = not COMPACT
end

-- GEMS (the gem window, GemVault) and SKINS (the Wardrobe), side by side.
-- (full: under the sword and shield; compact: under the miner)
local function buildButtons(holder: Instance, x: number, buttonY: number, totalW: number, buttonH: number, gap: number)
	local gems = new("TextButton", {
		Name = "GemsButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, holder)
	local half = (totalW - gap) / 2
	local iconAt, iconSize, labelX = if COMPACT then 6 else 10, if COMPACT then 32 else 36, if COMPACT then 44 else 58
	place(gems, x, buttonY, half, buttonH)
	round(gems, 10)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(38, 31, 60), Color3.fromRGB(16, 20, 31)),
	}, gems)
	local gemsEdge = stroke(gems, Color3.fromRGB(190, 120, 255), 1, 0.55)
	local gemsIcon = frame(gems, Color3.fromRGB(255, 255, 255), 0.95)
	place(gemsIcon, iconAt, (buttonH - iconSize) / 2, iconSize, iconSize)
	round(gemsIcon, 20)
	ui.GemsIcon = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gemsIcon)
	local gemsTitle = place(text(gems, "GEMS", 15, C.Text, HEAVY), labelX, buttonH / 2 - 18, math.min(160, half - labelX - 6), 20)
	ui.GemsCount = place(text(gems, "", 10, C.Dim, HEADING), labelX, buttonH / 2 + 3, half - labelX - 8, 14)
	if COMPACT then
		UiKit.fit(gemsTitle)
		UiKit.fit(ui.GemsCount)
	end
	local review = place(text(gems, "›", 18, Color3.fromRGB(200, 150, 255), HEAVY), half - 26, buttonH / 2 - 12, 16, 22)
	review.TextXAlignment = Enum.TextXAlignment.Right
	review.Visible = not COMPACT
	gems:SetAttribute("UiSound", "Click")
	gems.MouseEnter:Connect(function()
		gemsEdge.Transparency = 0.1
	end)
	gems.MouseLeave:Connect(function()
		gemsEdge.Transparency = 0.55
	end)
	gems.Activated:Connect(function()
		if ui.Popups then
			GemVault.open(ui.Popups, nil, InventoryV2.beginGemDrag)
		end
	end)
	-- Beside it: the miner's suit and weapon skin, in the Wardrobe.
	local skins = new("TextButton", {
		Name = "SkinsButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, holder)
	place(skins, x + half + gap, buttonY, half, buttonH)
	round(skins, 10)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(56, 30, 48), Color3.fromRGB(16, 20, 31)),
	}, skins)
	local skinsEdge = stroke(skins, Color3.fromRGB(255, 120, 190), 1, 0.55)
	local skinsIcon = frame(skins, Color3.fromRGB(255, 255, 255), 0.95)
	place(skinsIcon, iconAt, (buttonH - iconSize) / 2, iconSize, iconSize)
	round(skinsIcon, 20)
	ui.SkinsIcon = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, skinsIcon)
	local skinsTitle = place(text(skins, "SKINS", 15, C.Text, HEAVY), labelX, buttonH / 2 - 18, math.min(120, half - labelX - 6), 20)
	if COMPACT then
		UiKit.fit(skinsTitle)
	end
	ui.SkinsCount = place(text(skins, "", 10, C.Dim, HEADING), labelX, buttonH / 2 + 3, half - labelX - 8, 14)
	ui.SkinsCount.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = ui.SkinsCount.TextSize }, ui.SkinsCount)
	local wardrobe = place(text(skins, "›", 18, Color3.fromRGB(255, 150, 205), HEAVY), half - 26, buttonH / 2 - 12, 16, 22)
	wardrobe.TextXAlignment = Enum.TextXAlignment.Right
	wardrobe.Visible = not COMPACT
	skins:SetAttribute("UiSound", "Click")
	skins.MouseEnter:Connect(function()
		skinsEdge.Transparency = 0.1
	end)
	skins.MouseLeave:Connect(function()
		skinsEdge.Transparency = 0.55
	end)
	skins.Activated:Connect(function()
		if ui.Popups then
			Wardrobe.open(ui.Popups)
		end
	end)
end

-- A row of filter tabs (full: over your gems and over your spare gear):
-- { key, label, colour? }; the one picked is lit, with a line under it.
local function filterTabs(holder: Frame, entries: { { any } }, picked: string, pick: (string) -> ())
	clear(holder)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, holder)
	local list = UiKit.list(row, 14, true)
	UiKit.shrinkRow(row, list)
	for order, entry in entries do
		local on = entry[1] == picked
		local tint = entry[3] or C.Text
		local b = new("TextButton", {
			Name = "Filter" .. entry[1],
			Text = entry[2],
			TextSize = 10,
			Font = HEADING,
			TextColor3 = if on then tint elseif entry[3] then tint:Lerp(C.Faint, 0.45) else C.Faint,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			LayoutOrder = order,
		}, row)
		b:SetAttribute("UiSound", "Tab")
		local bar = frame(b, if entry[3] then tint else C.Gold)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0, 1)
		bar.Size = UDim2.new(1, 0, 0, 2)
		bar.BackgroundTransparency = if on then 0 else 1
		b.Activated:Connect(function()
			pick(entry[1])
		end)
	end
end

-- Full, under your armor: your spare gear (every slot), a tab per slot.
-- Each piece shows the rating it would add; click one and the column
-- turns into its slot, with it picked (EQUIP).
local function buildBag(list: Frame, y: number)
	place(text(list, "SPARE GEAR", 11, C.Dim, HEADING), 0, y, 200, 16)
	ui.BagCount = place(text(list, "", 10, C.Faint, HEADING), RIGHT_W - 220, y, 220, 16)
	ui.BagCount.TextXAlignment = Enum.TextXAlignment.Right
	ui.BagTabs = new("Frame", { Name = "BagTabs", BackgroundTransparency = 1 }, list)
	place(ui.BagTabs, 0, y + 20, RIGHT_W, 26)
	ui.Bag = new("ScrollingFrame", {
		Name = "Bag",
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Faint,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, list)
	place(ui.Bag, 0, y + 54, RIGHT_W, 644 - (y + 54))
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
	ui.Rows = {}
	local y = 26
	-- (compact: the middle of the screen, two columns of three rows over Q/E/R)
	if COMPACT then
		place(column, RIGHT_X, 56, W - RIGHT_X, 324)
	else
		place(column, RIGHT_X, 96, RIGHT_W, 640)
	end
	-- The list.
	local list = new("Frame", { Name = "List", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, column)
	if COMPACT then
		for i, slot in { "Helmet", "Armor", "Gloves", "Boots", "Weapon", "Shield" } do
			local entry = buildRow(list, slot, ((i - 1) % 3) * 78)
			entry.Row.Position = UDim2.fromOffset(if i > 3 then RIGHT_W + 10 else 0, ((i - 1) % 3) * 78)
			entry.Enchant.Text = "TAP + TO ADD A GEM"
			ui.Rows[slot] = entry
		end
	else
		place(text(list, "EQUIPMENT", 11, C.Dim, HEADING), 0, 0, 200, 16)
		local hint = place(text(list, "CLICK TO CHANGE", 10, C.Faint, HEADING), RIGHT_W - 200, 0, 200, 16)
		hint.TextXAlignment = Enum.TextXAlignment.Right
		-- (the sword and shield are in the left column: buildWeapons)
		for _, slot in { "Helmet", "Armor", "Gloves", "Boots" } do
			ui.Rows[slot] = buildRow(list, slot, y)
			y += 80
		end
	end
	-- Under the rows (full): your spare gear. (Compact: GEMS and SKINS under
	-- the miner, in the left column.)
	if COMPACT then
		buildButtons(canvas, 0, 326, RIGHT_X - 12, 54, 8)
	else
		buildBag(list, y + 6)
	end
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
	-- (compact, a little tighter: R ran past the card into the grid's column)
	local sx, group = if COMPACT then 34 else 40, if COMPACT then 4 else 8
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
			sx += group
		end
	end
	sx += group
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
		place(sub, cx, 146, if COMPACT then 170 else 180, 14)
		sub.Position = UDim2.fromOffset(cx, 146)
		sub.TextXAlignment = Enum.TextXAlignment.Center
		local tap = hit(holder)
		tap:SetAttribute("UiSound", "Click")
		return { Holder = holder, Edge = edge, Art = art, Empty = empty, Name = name, Sub = sub, Tap = tap }
	end
	ui.PieceWell = well(RIGHT_W * 0.27, false)
	ui.GemWell = well(RIGHT_W * 0.73, true)
	-- (a key: either well opens the gem window on that gem, with all three of
	-- its moves)
	local function openKeyGem()
		local gem = ui.KeyGem
		if gem and ui.Popups then
			GemVault.open(ui.Popups, gem.SourceId or gem.Id, InventoryV2.beginGemDrag)
		end
	end
	ui.PieceWell.Tap.Activated:Connect(function()
		if not state.Detail then
			return
		elseif table.find(KEYS, state.Detail) then
			openKeyGem()
		else
			state.Tab, state.Pick, state.Hover = "Pieces", nil, nil
			draw()
		end
	end)
	ui.GemWell.Tap.Activated:Connect(function()
		if state.Detail and table.find(KEYS, state.Detail) then
			openKeyGem()
		else
			state.Tab, state.Pick, state.Hover = "Gems", nil, nil
			draw()
		end
	end)
	ui.Plus = text(card, "+", 18, C.Faint, HEADING)
	ui.Plus.AnchorPoint = Vector2.new(0.5, 0.5)
	place(ui.Plus, RIGHT_W / 2, 68, 30, 30)
	ui.Plus.Position = UDim2.fromOffset(RIGHT_W / 2, 68)
	ui.Plus.TextXAlignment = Enum.TextXAlignment.Center
	-- A key: the square holds the move's icon, with the key on its corner, and
	-- the round one the gem it comes from (as a piece and its gem).
	ui.MoveGlyph = text(ui.PieceWell.Holder, "", 34, C.Faint, HEADING)
	place(ui.MoveGlyph, 6, 6, 88, 88)
	ui.MoveGlyph.TextXAlignment = Enum.TextXAlignment.Center
	round(ui.MoveGlyph, 8)
	ui.KeyBadge = text(ui.PieceWell.Holder, "", 13, C.Ink, HEAVY)
	place(ui.KeyBadge, -7, -7, 26, 26)
	ui.KeyBadge.TextXAlignment = Enum.TextXAlignment.Center
	ui.KeyBadge.BackgroundTransparency = 0
	ui.KeyBadge.ZIndex = 4
	round(ui.KeyBadge, 7)
	-- The perk band (or the surge's description).
	local rule = frame(card, C.Line, 0.92)
	place(rule, 18, 170, RIGHT_W - 36, 1)
	ui.PerkName = place(text(card, "", 10, C.Gold, HEADING), 18, 182, RIGHT_W - 36, 14)
	-- (a key: its cost, cooldown and output, on the right of that line)
	ui.PerkStats = place(text(card, "", 10, C.Dim, HEADING), 128, 182, RIGHT_W - 146, 14)
	ui.PerkStats.TextXAlignment = Enum.TextXAlignment.Right
	UiKit.fit(ui.PerkStats)
	ui.PerkText = place(text(card, "", 12, C.Dim, BODY), 18, 198, RIGHT_W - 36, 30)
	ui.PerkText.TextWrapped = true
	ui.PerkText.TextYAlignment = Enum.TextYAlignment.Top
	ui.PerkValue = place(text(card, "", 18, C.Good, HEAVY), 18, 228, RIGHT_W - 36, 26)
	ui.PerkValue.RichText = true
	-- Under the card (compact: beside it): the tabs and the element filter,
	-- the grid, what a pick would change, and the buttons.
	local lower = new("Frame", { Name = "Lower", BackgroundTransparency = 1 }, detail)
	if COMPACT then
		place(lower, RIGHT_W + 10, 0, RIGHT_W, 324)
	else
		place(lower, 0, 320, RIGHT_W, 296)
	end
	local gridH = if COMPACT then 160 else 144
	ui.ButtonY = 32 + gridH + 76
	ui.Tabs = new("Frame", { BackgroundTransparency = 1 }, lower)
	place(ui.Tabs, 0, 0, 230, 24)
	ui.Filters = new("Frame", { BackgroundTransparency = 1 }, lower)
	place(ui.Filters, RIGHT_W - 150, 0, 150, 24)
	-- The grid.
	ui.Grid = new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Faint,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, lower)
	place(ui.Grid, 0, 32, RIGHT_W, gridH)
	-- What a pick (or the hovered one) would change, and the buttons.
	ui.Compare = frame(lower, C.Gold, 0.93)
	place(ui.Compare, 0, 32 + gridH + 8, RIGHT_W, 60)
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
		}, lower)
		place(b, x, ui.ButtonY, w, 44)
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

-- Full, the left column: your sword and shield, GEMS and SKINS, then every
-- loose gem you have (a tab per element). Drag a gem onto a piece or a key;
-- click one for the gem window.
local function buildWeapons(canvas: Frame)
	local column = new("Frame", { Name = "Weapons", BackgroundTransparency = 1 }, canvas)
	place(column, LEFT_X, 96, LEFT_W, 728)
	place(text(column, "WEAPONS", 11, C.Dim, HEADING), 0, 0, 200, 16)
	local hint = place(text(column, "CLICK TO CHANGE", 10, C.Faint, HEADING), LEFT_W - 200, 0, 200, 16)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	local y = 26
	for _, slot in { "Weapon", "Shield" } do
		ui.Rows[slot] = buildRow(column, slot, y)
		y += 80
	end
	buildButtons(column, 0, y + 2, LEFT_W, 50, 10)
	y += 66
	place(text(column, "YOUR GEMS", 11, C.Dim, HEADING), 0, y, 200, 16)
	ui.PouchCount = place(text(column, "", 10, C.Faint, HEADING), LEFT_W - 240, y, 240, 16)
	ui.PouchCount.TextXAlignment = Enum.TextXAlignment.Right
	ui.PouchTabs = new("Frame", { Name = "PouchTabs", BackgroundTransparency = 1 }, column)
	place(ui.PouchTabs, 0, y + 20, LEFT_W, 26)
	ui.Pouch = new("ScrollingFrame", {
		Name = "Pouch",
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Faint,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, column)
	place(ui.Pouch, 0, y + 54, LEFT_W, 728 - (y + 54))
end

-- Q / E / R.
local function buildSurges(canvas: Frame)
	ui.Keys = {}
	-- Left edge clear of the elements panel; they reach right under the
	-- equipment column (which ends above them), room for the whole info line.
	local cardW, gap = 248, 12
	local x0, y0 = 441, 750
	if COMPACT then
		-- (a row under the equipment, as wide as it)
		gap = 10
		cardW = math.floor((W - RIGHT_X - 2 * gap) / 3)
		x0, y0 = RIGHT_X, 292
	end
	for i, key in KEYS do
		local card = new("TextButton", {
			Name = "Key" .. key,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(10, 14, 22),
			BackgroundTransparency = 0.2,
		}, canvas)
		place(card, x0 + (i - 1) * (cardW + gap), y0, cardW, 66)
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
		if COMPACT then
			UiKit.fit(info)
		end
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
				-- (with the triad on, the server sockets it in the sword, the chest or the shield)
				socketInto(key, item)
			end,
		})
		-- The key's job, above its name (OFFENSE / ABILITY / DEFENSE).
		local lane = place(text(card, "", 9, C.Dim, HEAVY), 68, 4, cardW - 80, 12)
		lane.TextTransparency = 0.1
		if COMPACT then
			UiKit.fit(lane)
		end
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
	ui.Sub.Text = if MinerRoster.Enabled
		then string.format("MINER %d  ·  LEVEL %d", active, level)
		else string.format("LEVEL %d", level)
	local vitals = Tree.vitals(profile, player:GetAttribute("MatchStats"))
	ui.LevelBonus.Text = if player:GetAttribute("MatchStats") == "Even" then "EVEN STATS · LEVEL BONUSES NORMALIZED"
		else string.format("LEVEL BONUS  +%d HP · +%d STAMINA · +%d CHARGE", vitals.Health, vitals.Stamina - 100, vitals.Charge - 100)
	ui.Vitals.Text = string.format("MAX STAMINA %d     MAX CHARGE %d", vitals.Stamina, vitals.Charge)
	local r = ratings(loadout)
	local total = 0
	for _, stat in Classes.StatNames do
		local value = if r then r[stat].Base + r[stat].Bonus else 0
		total += value
		if stat == "Health" then value = Classes.maxHealth(value) + vitals.Health end
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
	resists.Detail.Text = if #parts > 0 then "Half strength on perk pieces" else "Gems in armor add resists"
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
	ui.Pick.Text = ChargeMeter.count(charged)
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
		-- The triad: the sword gives Q its move, the chest E, the shield R.
		local rowKey = if triadOn(loadout) then Traits.KeyOfSocket[slot] else nil
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
	if not ui.Nudge then
		return -- (AUTO EQUIP and the glowing empty sockets do its job now)
	end
	local empty, first = {}, nil
	for _, slot in NUDGE_ORDER do
		if loadout[slot] ~= nil and loadout[slot .. "Gem"] == nil then
			table.insert(empty, SLOT_NAME[slot])
			first = first or slot
		end
	end
	local spare = #GemInventory.available(profile)
	-- (compact has no room for it: the rows' empty sockets glow instead)
	ui.Nudge.Visible = #empty > 0 and not COMPACT
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
			elseif COMPACT then "TAP TO ADD A GEM"
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
			-- (its tier level, top right)
			local level = place(text(cell, GemRoller.levelLabel(item.Gem), 9, tierColor, HEAVY), 26, 3, 38, 12)
			level.TextXAlignment = Enum.TextXAlignment.Right
			level.ZIndex = 3
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
			local itsGem = slotGemFor(loadout, target, item.Id)
			local after = perkOf(loadout, target, item.Id, itsGem)
			local deltas = statDeltas(loadout, target, item.Id :: string)
			textValue = string.format(
				'<b>%s</b>  ·  rating <font color="#%s">%s%d</font>%s\n%s',
				item.Gear and item.Gear.Name or "This piece",
				if gain >= 0 then good else bad,
				if gain >= 0 then "+" else "",
				gain,
				if deltas ~= "" then "  ·  " .. deltas else "",
				if after then after.Definition.Name .. " " .. perkValue(after) .. ". The slot's gem moves onto it." elseif loadout[target .. "Gem"] then "The slot's gem moves onto it." else ""
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
	ui.Secondary.Position = UDim2.fromOffset(if ui.Primary.Visible then 262 else 0, ui.ButtonY)
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
	-- (compact, the open piece takes the Q / E / R row's place too: its strip
	-- still hops to them)
	for _, entry in ui.Keys do
		entry.Card.Visible = not (COMPACT and target ~= nil)
	end
	if not target then
		return
	end
	paintStrip(loadout)
	local isKey = table.find(KEYS, target) ~= nil
	-- (both show the same two wells: a key's move and its gem, or a piece and
	-- its gem)
	ui.PieceWell.Art.Visible = not isKey
	ui.MoveGlyph.Visible = isKey
	ui.KeyBadge.Visible = isKey
	ui.PerkStats.Visible = isKey
	ui.PerkText.RichText = isKey
	ui.PerkText.TextSize = if COMPACT then 13 else 12
	local pick = state.Pick
	local gold = C.Gold:ToHex()
	if isKey then
		local triad = triadOn(loadout)
		local current = Tech.surgeGem(loadout, target)
		local trying = if pick and pick.Kind == "Gem" then keyGem(pick.Gem, target, loadout) else nil
		local gem = trying or current
		local surge = gem and Tech.surgeStats(gem)
		local tint = if gem then gemColor(gem) else C.Faint
		local keyColor = if triad then KEY_COLORS[target] else C.Gold
		ui.KeyGem = gem
		-- The move: only this key's, its icon with the key on the corner.
		local well = ui.PieceWell
		local shown = if surge then gem.Id .. tostring(gem.Surge) else ""
		if ui.MoveShown ~= shown then
			ui.MoveShown = shown
			ui.MoveGlyph.Text = if surge then "◆" else ""
			ui.MoveGlyph.TextColor3 = tint
			if surge then
				SurgeIcons.apply(ui.MoveGlyph, surge, tint)
			else
				local art = ui.MoveGlyph:FindFirstChild("AbilityArt")
				if art then
					art:Destroy()
				end
			end
		end
		well.Empty.Visible = surge == nil
		well.Edge.Color = if trying then C.Gold elseif surge then keyColor else C.Line
		well.Edge.Transparency = if trying then 0 elseif surge then 0.2 else 0.85
		ui.KeyBadge.Text = target
		ui.KeyBadge.BackgroundColor3 = keyColor
		well.Name.Text = if surge then surge.Name else "No surge on " .. target
		-- (★ a signature move: it rolls at half the odds)
		local move = gem and Tech.Catalog[gem.Surge or ""]
		well.Sub.Text = target
			.. "  ·  "
			.. (if triad then LANE_WORDS[target] else "SURGE")
			.. (if move and move.Rare then "  ·  ★" else "")
		well.Sub.TextColor3 = keyColor
		-- The gem it comes from.
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
		gw.Edge.Color = if trying then C.Gold elseif gem then tint else C.Line
		gw.Edge.Transparency = if gem then 0 else 0.85
		gw.Name.Text = if gem
			then gemName(gem)
			elseif triad then "No gem in your " .. string.lower(Traits.SocketNames[target])
			else "Empty socket"
		if trying then
			gw.Sub.Text = "TRYING ON"
			gw.Sub.TextColor3 = C.Gold
		else
			gw.Sub.Text = if gem
				then string.upper(GemConfig.elementName(gem.Element)) .. "  ·  " .. rarityName(gemRarity(gem))
				else "PICK ONE BELOW"
			gw.Sub.TextColor3 = if gem then tint else C.Dim
		end
		-- What it does, with its cost, cooldown and output on the right.
		ui.PerkName.Text = if surge then "WHAT IT DOES" else ""
		ui.PerkStats.Text = if surge
			then string.format(
				"%s %s  ·  %ss%s",
				whole(surge.Cost or 0),
				string.upper(surge.Resource or "Charge"),
				whole(surge.Cooldown or 0),
				if surge.Triad then string.format("  ·  %s%% OUTPUT", whole((surge.Output or 1) * 100)) else ""
			)
			else ""
		-- (a Legendary gem's flourish: a gold line under it)
		local flourish = if surge and surge.Flourished and surge.Flourish then surge.Flourish.Text else nil
		ui.PerkText.Text = if surge
			then (surge.Description or "") .. (if flourish
				then string.format('\n<font color="#%s">✦ %s</font>', gold, flourish)
				else "")
			elseif triad then string.format(
				"%s fires the %s of the gem in your %s. Any cut gem fits.",
				target,
				string.lower(Traits.Lanes[target]),
				string.lower(Traits.SocketNames[target])
			)
			else "Surges are cast with Q, E and R in a fight. Any cut gem with a surge fits."
		ui.PerkText.Size = UDim2.fromOffset(RIGHT_W - 36, 60)
		-- (compact, a little smaller for the longest, so four lines hold it)
		if COMPACT and surge and #(surge.Description or "") + #(flourish or "") > 130 then
			ui.PerkText.TextSize = 11
		end
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
		-- A pick is tried on in place: its piece (with the slot's gem, which
		-- moves onto it), or its gem in this piece.
		local tryPiece = if pick and pick.Kind == "Piece" then pick.Id else nil
		local tryGem = if pick and pick.Kind == "Gem" then pick.Gem else nil
		local viewId = tryPiece or wornId
		local gem = if tryGem then tryGem
			elseif tryPiece then slotGemFor(loadout, slot, tryPiece)
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
		-- The triad: the sword's gem is your Q, the chest's your E, the shield's your R.
		local slotKey = if triadOn(loadout) then Traits.KeyOfSocket[slot] else nil
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
		if COMPACT then
			return -- (a touch screen: a tap opens the piece instead)
		end
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
			-- The trait in plain words: what it does with its number in it,
			-- its stamina cost, what Charge is for, and what it rolls between.
			-- (Each wrapped line sized by a rough characters-per-line.)
			local function para(value: string, size: number, color3: Color3, font: Enum.Font)
				local perLine = math.floor((TIP_W - 32) / (size * 0.56))
				local lines = math.max(1, math.ceil(#value / perLine))
				line(value, size, color3, font, lines * (size + 3), true)
			end
			local plain = ArmorSignatures.explain(signature)
			y += 4
			line(string.upper(signature.Definition.Name), 10, C.Gold, HEADING, 12)
			para(plain.Effect, 12, C.Good, HEADING)
			if plain.Cost then
				para(plain.Cost, 11, C.Bad, MEDIUM)
			end
			if plain.Note then
				para(plain.Note, 10, C.Dim, MEDIUM)
			end
			para(plain.Range, 10, C.Faint, MEDIUM)
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
local profileStamp = 0 -- (counts profile changes: AUTO EQUIP's plan is worked out again after one)
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
	ui.GemsCount.Text = string.format(if COMPACT then "%d SPARE" else "%d AVAILABLE", #available)
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
	ui.SkinsCount.Text = if COMPACT
		then string.format("%d OWNED", suits + skins + picks)
		else count(suits, "SUIT") .. "  ·  " .. count(skins, "SKIN") .. "  ·  " .. count(picks, "PICK")
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

-- Full, left: your loose gems, rarest first, a tab per element. Each shows
-- its tier level ("T3 II": its surge tier and rank) in its rarity's colour.
local pouchKey = ""
local function drawPouch(profile)
	if not ui.Pouch then
		return
	end
	local all, counts = {}, { All = 0 }
	for _, gem in GemInventory.available(profile) do
		table.insert(all, gem)
		counts.All += 1
		counts[gem.Element or ""] = (counts[gem.Element or ""] or 0) + 1
	end
	local filter = state.PouchFilter
	local tabsKey = filter .. "|" .. counts.All
	for _, element in ELEMENTS do
		tabsKey ..= "|" .. (counts[element] or 0)
	end
	if ui.PouchTabsKey ~= tabsKey then
		ui.PouchTabsKey = tabsKey
		local entries = { { "All", string.format("ALL %d", counts.All) } }
		for _, element in ELEMENTS do
			table.insert(entries, {
				element,
				string.format("%s %d", string.upper(GemConfig.elementName(element)), counts[element] or 0),
				GemConfig.ElementColors[element],
			})
		end
		filterTabs(ui.PouchTabs, entries, filter, function(key)
			state.PouchFilter = key
			draw()
		end)
	end
	ui.PouchCount.Text = if counts.All > 0 then "DRAG ONTO A PIECE OR A KEY" else ""
	local shown, levels = {}, {}
	for _, gem in all do
		if filter == "All" or gem.Element == filter then
			table.insert(shown, gem)
			local ok, tier, rank = pcall(GemRoller.surge, gem)
			levels[gem] = if ok then tier * 10 + rank else 0
		end
	end
	table.sort(shown, function(a, b)
		local ra, rb = gemRarity(a), gemRarity(b)
		if ra ~= rb then
			return ra > rb
		end
		if levels[a] ~= levels[b] then
			return levels[a] > levels[b]
		end
		if (a.Element or "") ~= (b.Element or "") then
			return (a.Element or "") < (b.Element or "")
		end
		return tostring(a.Id) < tostring(b.Id)
	end)
	local parts = { filter }
	for _, gem in shown do
		table.insert(parts, tostring(gem.Id) .. ":" .. tostring(gem.Cut))
	end
	local key = table.concat(parts, ",")
	if key == pouchKey then
		return
	end
	pouchKey = key
	clear(ui.Pouch)
	if #shown == 0 then
		local note = text(
			ui.Pouch,
			if filter == "All" then "No loose gems. Mine some in the Outpost." else "None of this element loose.",
			12,
			C.Faint,
			MEDIUM
		)
		note.Size = UDim2.new(1, 0, 0, 60)
		note.TextWrapped = true
		note.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(72, 88),
		CellPadding = UDim2.fromOffset(7, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, ui.Pouch)
	for order, gem in shown do
		local color = rarityColor(gemRarity(gem))
		local cut = gem.Cut ~= nil
		local cell = new("TextButton", {
			Name = "Gem" .. order,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = color:Lerp(C.Ink, 0.86),
			BackgroundTransparency = 0.15,
			LayoutOrder = order,
		}, ui.Pouch)
		round(cell, 10)
		local edge = stroke(cell, color, 1, 0.6)
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(52, 52) }, cell)
		gemArt(art, gem)
		local level = place(text(cell, GemRoller.levelLabel(gem), 12, color, HEAVY), 0, 57, 72, 14)
		level.TextXAlignment = Enum.TextXAlignment.Center
		local rarity = place(text(cell, if cut then rarityName(gemRarity(gem)) else "UNCUT", 8, C.Dim, HEADING), 2, 71, 68, 10)
		rarity.TextXAlignment = Enum.TextXAlignment.Center
		UiKit.fit(rarity)
		local bar = frame(cell, gemColor(gem))
		place(bar, 12, 84, 48, 2)
		round(bar, 1)
		cell:SetAttribute("UiSound", "Click")
		cell.MouseEnter:Connect(function()
			edge.Transparency = 0.05
		end)
		cell.MouseLeave:Connect(function()
			edge.Transparency = 0.6
		end)
		cell.InputBegan:Connect(function(input)
			if cut and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				startDrag({ Kind = "Gem", Gem = gem }, input)
			end
		end)
		cell.Activated:Connect(function()
			if os.clock() < suppressClickUntil then
				return
			end
			if ui.Popups then
				GemVault.open(ui.Popups, gem.Id, InventoryV2.beginGemDrag)
			end
		end)
	end
end

-- Full, right: your spare gear, a tab per slot, the best swap first. Each
-- piece shows the rating it would add; click one to try it on (EQUIP).
local BAG_SLOTS = { "Helmet", "Armor", "Gloves", "Boots", "Weapon", "Shield" }
local bagKey = ""
local function drawBag(loadout)
	if not ui.Bag then
		return
	end
	local filter = state.BagFilter
	local items, total = {}, 0
	for _, slot in BAG_SLOTS do
		for _, spare in sparesFor(slot) do
			total += 1
			if filter == "All" or filter == slot then
				spare.Gain = ratingGain(loadout, slot, spare.Id)
				table.insert(items, spare)
			end
		end
	end
	if ui.BagTabsKey ~= filter then
		ui.BagTabsKey = filter
		local entries = { { "All", "ALL" } }
		for _, slot in BAG_SLOTS do
			table.insert(entries, { slot, SLOT_NAME[slot] })
		end
		filterTabs(ui.BagTabs, entries, filter, function(key)
			state.BagFilter = key
			draw()
		end)
	end
	ui.BagCount.Text = if total == 1 then "1 PIECE" else string.format("%d PIECES", total)
	table.sort(items, function(a, b)
		if a.Gain ~= b.Gain then
			return a.Gain > b.Gain
		end
		if a.Rarity ~= b.Rarity then
			return a.Rarity > b.Rarity
		end
		return a.Id < b.Id
	end)
	local parts = { filter, tostring(ui.ArtVersion or 0) }
	for _, spare in items do
		table.insert(parts, spare.Slot .. "/" .. spare.Id .. "/" .. spare.Gain)
	end
	local key = table.concat(parts, ",")
	if key == bagKey then
		return
	end
	bagKey = key
	clear(ui.Bag)
	if #items == 0 then
		local note = text(
			ui.Bag,
			if total == 0 then "No spare gear yet. Rift bosses and the Market have more." else "No spare piece for this slot.",
			12,
			C.Faint,
			MEDIUM
		)
		note.Size = UDim2.new(1, 0, 0, 60)
		note.TextWrapped = true
		note.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(72, 88),
		CellPadding = UDim2.fromOffset(7, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, ui.Bag)
	for order, spare in items do
		local color = rarityColor(spare.Rarity)
		local cell = new("TextButton", {
			Name = "Spare" .. order,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = color:Lerp(C.Ink, 0.88),
			BackgroundTransparency = 0.15,
			LayoutOrder = order,
		}, ui.Bag)
		round(cell, 10)
		local edge = stroke(cell, color, 1, 0.6)
		local art = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(52, 52) }, cell)
		gearArt(art, spare.Slot, spare.Id, false, color)
		local gain = place(
			text(cell, if spare.Gain > 0 then "+" .. spare.Gain elseif spare.Gain < 0 then "−" .. -spare.Gain else "±0", 12, if spare.Gain > 0 then C.Good elseif spare.Gain < 0 then C.Bad else C.Dim, HEAVY),
			0,
			57,
			72,
			14
		)
		gain.TextXAlignment = Enum.TextXAlignment.Center
		local slotName = place(text(cell, SLOT_NAME[spare.Slot], 8, C.Dim, HEADING), 2, 71, 68, 10)
		slotName.TextXAlignment = Enum.TextXAlignment.Center
		UiKit.fit(slotName)
		local bar = frame(cell, color)
		place(bar, 12, 84, 48, 2)
		round(bar, 1)
		cell:SetAttribute("UiSound", "Click")
		cell.MouseEnter:Connect(function()
			edge.Transparency = 0.05
		end)
		cell.MouseLeave:Connect(function()
			edge.Transparency = 0.6
		end)
		cell.Activated:Connect(function()
			openDetail(spare.Slot)
			state.Tab = "Pieces"
			state.Pick = { Kind = "Piece", Slot = spare.Slot, Id = spare.Id, Gear = spare.Gear } :: any
			draw()
		end)
	end
end

-- AUTO EQUIP: the mode picked, and what that build would change.
local autoKey = nil
local function drawAuto(profile)
	if not ui.AutoGo then
		return
	end
	local mode = state.AutoMode
	local key = mode .. "|" .. profileStamp
	if autoKey ~= key then
		autoKey = key
		local ok, plan = pcall(AutoEquip.plan, profile, mode)
		ui.AutoPlan = if ok then plan else nil
	end
	for m, chip in ui.AutoModes do
		local on = m == mode
		local tint = GemConfig.ElementColors[m] or C.Gold
		chip.Button.BackgroundColor3 = if on then tint else C.Ink
		chip.Button.BackgroundTransparency = if on then 0 else 0.4
		chip.Button.TextColor3 = if on then C.Ink elseif GemConfig.ElementColors[m] then tint else C.Dim
		chip.Edge.Color = tint
		chip.Edge.Transparency = if on then 1 else 0.7
	end
	if COMPACT then
		return
	end
	local plan = ui.AutoPlan
	local changes = plan and plan.Changes or 0
	local ready = changes > 0
	ui.AutoGo.AutoButtonColor = ready
	ui.AutoGo.BackgroundColor3 = if ready then C.Gold else C.Ink
	ui.AutoGo.TextColor3 = if ready then Color3.fromRGB(26, 18, 6) else C.Faint
	if not plan then
		ui.AutoPreview.Text = ""
	elseif not ready then
		ui.AutoPreview.Text = "NOTHING TO CHANGE"
		ui.AutoPreview.TextColor3 = C.Faint
	else
		local gain = math.floor(plan.Gain + 0.5)
		local parts = {}
		if gain ~= 0 then
			table.insert(parts, string.format("%s%d RATING", if gain > 0 then "+" else "−", math.abs(gain)))
		end
		if #plan.Gear > 0 then
			table.insert(parts, string.format("%d GEAR", #plan.Gear))
		end
		if #plan.Gems > 0 then
			table.insert(parts, if #plan.Gems == 1 then "1 GEM" else string.format("%d GEMS", #plan.Gems))
		end
		ui.AutoPreview.Text = table.concat(parts, "  ·  ")
		ui.AutoPreview.TextColor3 = if gain > 0 then C.Good elseif gain < 0 then C.Bad else C.Dim
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
		drawPouch(profile)
		drawBag(loadout)
		drawAuto(profile)
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
	-- (drawn for the full 1600 x 840 layout, on the popup layer when compact)
	place(shade, -400, -200, 1600 + 800, 840 + 400)
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
		{ "E", "ABILITY", "Your chest's gem", "Your elemental surge: a strike, a dash or an aura that helps while it's ready. Pays Charge." },
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
	local moved = profile.TriadSeen ~= true and (profile.TriadNotice or 0) > 0
	local show = state.Active == true and triadOn(loadout) and (moved or profile.CoreNotice ~= nil) and not introDone
	ui.Intro.Visible = show
	if show then
		local core = if profile.CoreNotice == "Chest"
			then "Your E now comes from your chest: your old core gem is on your chest."
			elseif profile.CoreNotice == "Stash" then "Your E now comes from your chest: your old core gem is in your stash, so socket it in your chest."
			else nil
		ui.IntroNote.Text = if moved
			then string.format("Your old Q and R surge gems (%d) are back in your stash, safe: socket them in a sword, a chest or a shield.", profile.TriadNotice)
			else core or "Socket gems in your sword, your chest and your shield to fill Q, E and R."
	end
end

-- Mount ------------------------------------------------------------------------------------------------

-- Compact when the full layout would show at under 70% of its size (a
-- phone, a small window): chosen once, as the Inventory is built.
local function chooseLayout(host: ScreenGui)
	local screen = host.AbsoluteSize
	if screen.X <= 0 and workspace.CurrentCamera then
		screen = workspace.CurrentCamera.ViewportSize
	end
	if screen.X > 0 and math.min(screen.X / W, (screen.Y - TOPBAR - BOTTOM) / H) < 0.7 then
		-- The miner's column on the left (224 wide), two columns of rows.
		COMPACT = true
		W, H = 990, 380
		RIGHT_X, RIGHT_W = 236, 372
		BOTTOM = 12 -- (no chat box under it on a phone)
	end
end

local root: Frame? = nil
function InventoryV2.mount(host: ScreenGui)
	gui = host
	chooseLayout(host)
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
	-- What opens over the Inventory (the gem vault, the wardrobe, the triad
	-- intro) is drawn for the full layout. Compact, it gets a full-screen
	-- layer of its own, scaled as large as the screen allows.
	ui.Popups = canvas
	local popups: Frame? = nil
	local popupScale: UIScale? = nil
	if COMPACT then
		popups = new("Frame", {
			Name = "Popups",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(1600, 840),
			ZIndex = 3,
		}, holder)
		popupScale = new("UIScale", {}, popups)
		ui.Popups = popups
	end
	local function fit()
		if not gui then
			return
		end
		local screen = gui.AbsoluteSize
		TOPBAR = (UiKit.topbar(screen.X))
		safe.Position = UDim2.fromOffset(0, TOPBAR)
		safe.Size = UDim2.new(1, 0, 1, -TOPBAR - BOTTOM)
		if screen.X > 0 and screen.Y > TOPBAR + BOTTOM then
			-- (compact, the canvas can fill the width: keep a gutter at each side)
			local wide = if COMPACT then screen.X - 32 else screen.X
			scale.Scale = math.min(wide / W, (screen.Y - TOPBAR - BOTTOM) / H)
			if popups and popupScale then
				-- (the vault and the wardrobe are 1360 x 720, centred, clear of
				-- Roblox's buttons at the top)
				local s = math.min(screen.X / 1360, screen.Y / 720)
				local room, at = UiKit.clearTopbar(screen, Vector2.new(1360, 720) * s)
				popupScale.Scale = s * room
				popups.Position = at
			end
		end
	end
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	UiKit.onTopbar(fit)
	fit()
	buildStage(canvas)
	buildTop(canvas)
	buildLeft(canvas)
	buildRight(canvas)
	if not COMPACT then
		buildWeapons(canvas)
	end
	buildSurges(canvas)
	buildIntro(ui.Popups)
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
	profileStamp += 1
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
