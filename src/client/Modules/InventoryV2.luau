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

	(Compact, on a phone: the miner on the left with STATS, AUTO, GEMS and
	SKINS, two columns of three rows, Q / E / R under them. STATS opens the
	stats card as a sheet over the screen; a piece's card lists every stat
	on it, since there's no hovering. GEMS is a tab: your loose gems in the
	rows' place, a tab per element, ‹ GEAR to go back; drag one onto a key,
	or start dragging and the rows come back to drop it on a piece. A quick
	swipe up or down over a list scrolls it; a gem is picked up by holding
	it a moment or moving it sideways: InventoryV2.touchScrolls.)

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
local UpgradeHints = require(script.Parent.UpgradeHints)
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
local STATS_X, STATS_W = 460, 262 -- (the stats card's own frame, slid into its sheet)
local COMPACT = false
-- The paper doll's layout (full; chooseLayout sets the compact one): the
-- panel under the top bar and its header, then the doll, the summary column
-- and the bags (full), or the doll and a tabbed side panel (compact).
local PANEL_Y, HEAD_H = 60, 62
local BODY_Y = PANEL_Y + HEAD_H + 14
local DOLL_X, DOLL_W, DOLL_PAD = 16, 600, 18
local MID_X, MID_W = 632, 380
local BAG_X, BAG_W = 1028, 556
local CARD_W, CARD_H = 168, 128
local SIDE_X, SIDE_W = 0, 0 -- (compact: the STATS / GEMS / GEAR panel)

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
-- Every stat on a piece, biggest first, on one line ("+12 Health  ·  +8 Defense").
local function allStats(roll): string
	local stats = {}
	for stat, amount in roll and roll.Stats or {} do
		local weight = if stat == "Critical" or stat == "Cooldown" then amount * 100 else amount
		table.insert(stats, { Text = statText(stat, amount), Weight = weight })
	end
	table.sort(stats, function(a, b)
		if a.Weight ~= b.Weight then
			return a.Weight > b.Weight
		end
		return a.Text < b.Text
	end)
	local out = {}
	for _, entry in stats do
		table.insert(out, entry.Text)
	end
	return table.concat(out, "  ·  ")
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

-- The pieces' 3D art is built by the server on request. Asked until it says
-- it's all built: one lost to its pacing ("Slow down!" when the Inventory's
-- other requests go at the same moment) or made while a build was running
-- used to leave the drawn icons up for good.
local previewAskedAt = -math.huge
local previewsAsking = false
local function askPreviews()
	if previewsAsking then
		return
	end
	previewsAsking = true
	previewAskedAt = os.clock()
	task.spawn(function()
		for attempt = 1, 6 do
			local ok, result = pcall(GemClient.request, "GearPreviews")
			if ok and typeof(result) == "table" and result.Ok and result.Done then
				break
			end
			task.wait(0.4 * attempt)
		end
		previewsAsking = false
	end)
end
local function gearArt(holder: Instance, slot: string, id: string, worn: boolean, color: Color3)
	clear(holder)
	local view = new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 186, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.4, -0.8, -0.6),
	}, holder)
	-- Always the piece in its own look (the server's previews, built bare:
	-- never the skin or suit worn over it), the worn ones too; a weapon put
	-- away for the pick still has its picture. Not built yet: asked for,
	-- and the drawn icon meanwhile.
	local ok, drawn = pcall(GearArt.draw, view, slot, id, false)
	if not (ok and drawn) then
		view:Destroy()
		if os.clock() - previewAskedAt > 4 then
			askPreviews()
		end
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
	StatsOpen = false, -- (full) the stats card open, or folded to STATS, EQUIP BEST and the elements
	PouchFilter = "All", -- your gems (full, left): "All" or an element
	SideTab = "Stats", -- compact: the side panel's page, "Stats", "Gems" or "Gear"
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
	state.Tab = nil -- (drawDetail picks the tab)
	state.Pick, state.Hover = nil, nil
	if InventoryV2.hideTip then
		InventoryV2.hideTip()
	end
	-- The window grows in a little as it opens, so it reads.
	local panel = ui.ModalPanel
	if panel and was == nil and target ~= nil then
		local scale = panel:FindFirstChildOfClass("UIScale") or new("UIScale", {}, panel)
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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
			ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 11, 30)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(8, 8, 19)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 5, 11)),
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
	-- (SURGES, AUGMENTS, SEASON, MARKET and STORE are off the strip for now:
	-- the Market and Store are in the lobby, the rest a key away.)
	for order, spec: { any } in {
		{ "INVENTORY", nil },
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
	-- (your coins open the coin packs: Client CoinShop)
	local coinsHit = hit(ui.Coins)
	coinsHit.Size = UDim2.new(1, 0, 0, 40)
	coinsHit.Activated:Connect(open("CoinShop", "open"))
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
-- stats card (its foot returned). Compact: an AUTO button over the miner,
-- its modes under it.
local function buildAuto(parent: Instance, x: number, y: number, w: number): number
	ui.AutoModes = {}
	local function surgeButton(holder, sx, sy, sw)
		local b = new("TextButton", {
			Name = "UpgradeSurges", Text = "UPGRADE SURGES", TextSize = 12,
			Font = HEAVY, TextColor3 = C.Teal, BackgroundColor3 = C.Ink,
			AutoButtonColor = true,
		}, holder)
		place(b, sx, sy, sw, 30)
		round(b, 8)
		UiKit.fit(b)
		ui.UpgradeSurges = b
		UpgradeHints.bind(b, function(hints) return hints.Surges.Changes > 0 end, C.Teal)
		b.Activated:Connect(function()
			if UpgradeHints.Current.Surges.Changes > 0 then request("UpgradeSurges") end
		end)
		return b
	end
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
		if mode == "Best" then
			UpgradeHints.bind(b, function(hints) return hints.Equipment end, C.Gold)
		end
		return b
	end
	place(text(parent, "AUTO EQUIP", 11, C.Gold, HEAVY), x, y, 110, 14)
	ui.AutoPreview = place(text(parent, "", 10, C.Dim, HEADING), x + 96, y, w - 96, 14)
	ui.AutoPreview.TextXAlignment = Enum.TextXAlignment.Right
	ui.AutoPreview.RichText = true
	UiKit.fit(ui.AutoPreview)
	y += 18
	local half = (w - 6) / 2
	for i, mode in { "Best", "Balanced" } do
		chip(parent, mode, x + (i - 1) * (half + 6), y, half, 24).Activated:Connect(function()
			state.AutoMode = mode
			draw()
		end)
	end
	y += 28
	local quarter = (w - 18) / 4
	for i, mode in ELEMENTS do
		chip(parent, mode, x + (i - 1) * (quarter + 6), y, quarter, 24).Activated:Connect(function()
			state.AutoMode = mode
			draw()
		end)
	end
	y += 30
	ui.AutoGo = new("TextButton", {
		Name = "AutoEquip",
		Text = "AUTO EQUIP",
		TextSize = 13,
		Font = HEAVY,
		TextColor3 = Color3.fromRGB(26, 18, 6),
		AutoButtonColor = true,
		BackgroundColor3 = C.Gold,
	}, parent)
	place(ui.AutoGo, x, y, w, 34)
	round(ui.AutoGo, 9)
	ui.AutoGo:SetAttribute("UiSound", "Confirm")
	ui.AutoGo.Activated:Connect(function()
		if ui.AutoPlan and ui.AutoPlan.Changes > 0 then
			request("AutoEquip", state.AutoMode)
		end
	end)
	ui.UpdateAutoGlow = UpgradeHints.bind(ui.AutoGo, function(hints)
		return hints.Equipment and state.AutoMode == "Best"
	end, C.Gold)
	surgeButton(parent, x, y + 40, w)
	return y + 70
end

-- Compact: there's no room for the stats card beside the miner, so it
-- lives in a sheet over the screen: a scrim, a panel with a title and ×,
-- and inside it a scrolling frame holding the card's box, slid so the
-- card's corner sits at the panel's. STATS over the miner opens it (with
-- your rating on it); a tap outside or on × closes it.
local SHEET_W = STATS_W + 32 + 44 -- (the card, and the level-bonus line that runs a little past it)
local function buildStatsSheet(canvas: Frame): Frame
	local scrim = new("TextButton", {
		Name = "StatsSheet",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
	}, canvas)
	ui.StatsSheet = scrim
	local panel = frame(scrim, C.Deep, 0.02)
	panel.Name = "Panel"
	ui.StatsSheetPanel = panel
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(SHEET_W, H - 12)
	round(panel, 14)
	stroke(panel, C.Teal, 1, 0.5)
	place(text(panel, "YOUR STATS", 12, C.Teal, HEAVY), 16, 10, 200, 18)
	local close = new("TextButton", {
		Name = "Close",
		Text = "×",
		TextSize = 22,
		Font = HEADING,
		TextColor3 = C.Dim,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
	}, panel)
	place(close, SHEET_W - 40, 2, 34, 34)
	close:SetAttribute("UiSound", "Back")
	local scroller = new("ScrollingFrame", {
		Name = "Scroller",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Dim,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
	}, panel)
	place(scroller, 0, 34, SHEET_W, H - 12 - 34)
	-- (the box is laid out in the full layout's coordinates: slid so the
	-- card's left edge and the line above it land at the panel's padding)
	local box = new("Frame", { Name = "Stats", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, H) }, scroller)
	ui.StatsBox, ui.StatsScroller = box, scroller
	local function hide()
		scrim.Visible = false
	end
	scrim.Activated:Connect(hide)
	close.Activated:Connect(hide)
	return box
end

-- The full stats card: in a sheet over the screen (both layouts), opened by
-- ALL STATS. It holds every number the summary can't: the level bonus,
-- max stamina and charge, the set and its next bonus, the elements, and
-- AUTO EQUIP with its modes.
local function buildLeft(canvas: Frame)
	local x, w = STATS_X, STATS_W
	local box = buildStatsSheet(canvas)
	local nameY = 96
	ui.LevelBonus = place(text(box, "", 10, C.Teal, BODY), x, nameY + 58, w + 40, 13)
	UiKit.fit(ui.LevelBonus)
	-- The card: the rating and four stats, the set, the elements, AUTO EQUIP,
	-- packed close and as tall as what's in it (its height set at the foot).
	local cardY = nameY + 78
	local card = frame(box, Color3.fromRGB(255, 255, 255), 0.965)
	card.Name = "StatsCard"
	place(card, x - 16, cardY, w + 32, 0)
	round(card, 14)
	stroke(card, C.Line, 1, 0.92)
	local y = cardY + 8
	-- The rating, big, with its caption beside it on the same baseline.
	local ratingRow = new("Frame", { BackgroundTransparency = 1 }, box)
	place(ratingRow, x, y, w, 44)
	local rowList = UiKit.list(ratingRow, 10, true)
	rowList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	ui.Rating = text(ratingRow, "0", 38, C.Gold, HEAVY)
	ui.Rating.Size = UDim2.fromOffset(0, 44)
	ui.Rating.AutomaticSize = Enum.AutomaticSize.X
	ui.Rating.TextTruncate = Enum.TextTruncate.None
	ui.Rating.LayoutOrder = 1
	ui.RatingCap = text(ratingRow, "RATING", 11, C.Dim, HEADING)
	ui.RatingCap.Size = UDim2.fromOffset(80, 24)
	ui.RatingCap.LayoutOrder = 2
	y += 48
	-- Four stats, two by two: the name and the value over a thin bar.
	ui.Stats = {}
	local cellW = (w - 16) / 2
	for i, stat in Classes.StatNames do
		local sx, sy = x + ((i - 1) % 2) * (cellW + 16), y + (i - 1) // 2 * 30
		place(text(box, string.upper(stat), 10, C.Dim, HEADING), sx, sy + 3, cellW - 48, 14)
		local value = place(text(box, "0", 15, C.Text, HEAVY), sx + cellW - 46, sy, 46, 18)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local track = frame(box, C.Line, 0.93)
		place(track, sx, sy + 21, cellW, 4)
		round(track, 2)
		local fill = frame(track, STAT_COLOR[stat])
		fill.Size = UDim2.fromScale(0, 1)
		round(fill, 2)
		ui.Stats[stat] = { Fill = fill, Value = value, Last = nil }
	end
	y += 60
	ui.Vitals = place(text(box, "", 10, C.Teal, HEADING), x, y, w, 14)
	UiKit.fit(ui.Vitals)
	y += 18
	-- The armor set.
	place(frame(box, C.Line, 0.93), x, y, w, 1)
	y += 8
	ui.SetName = place(text(box, "", 11, C.Teal, HEADING), x, y, 170, 16)
	ui.Pips = {}
	for i = 1, 6 do
		local pip = frame(box, C.Line, 0.9)
		place(pip, x + w - 6 * 17 + (i - 1) * 17, y + 6, 12, 4)
		round(pip, 2)
		ui.Pips[i] = pip
	end
	y += 18
	ui.SetBonus = place(text(box, "", 12, C.Text, HEADING), x, y, w, 16)
	ui.SetBonus.RichText = true
	UiKit.fit(ui.SetBonus)
	y += 17
	ui.SetNext = place(text(box, "", 11, C.Dim, BODY), x, y, w, 26)
	ui.SetNext.TextWrapped = true
	ui.SetNext.TextYAlignment = Enum.TextYAlignment.Top
	y += 28
	-- Elements: what you're strong against, weak to and resist (Shared.ElementMatchup).
	place(frame(box, C.Line, 0.93), x, y, w, 1)
	y += 8
	ui.Verdict = {}
	for i, caption in { "STRONG VS", "WEAK TO", "RESISTS" } do
		UiKit.fit(place(text(box, caption, 10, C.Dim, HEADING), x, y + 1, 92, 14))
		local value = place(text(box, "", 12, C.Text, HEADING), x + 98, y, w - 98, 16)
		value.RichText = true
		UiKit.fit(value)
		local detail = text(box, "", 10, C.Faint, MEDIUM)
		detail.Visible = false
		ui.Verdict[i] = { Value = value, Detail = detail }
		y += 18
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
	-- AUTO EQUIP, right under the rest; the card ends with it.
	place(frame(box, C.Line, 0.93), x, y, w, 1)
	y += 8
	y = buildAuto(box, x, y, w)
	card.Size = UDim2.fromOffset(w + 32, y + 10 - cardY)
	-- The box slid into the sheet, the sheet as tall as the card (up to the
	-- screen), scrolling as far as the card.
	local top = nameY + 58 - 10
	box.Position = UDim2.fromOffset(-(x - 16) + 12, -top)
	local inner = y + 10 - top + 12
	ui.StatsScroller.CanvasSize = UDim2.fromOffset(0, inner)
	local sheetH = math.min(H - 12, inner + 34 + 6)
	ui.StatsSheetPanel.Size = UDim2.fromOffset(SHEET_W, sheetH)
	ui.StatsScroller.Size = UDim2.fromOffset(SHEET_W, sheetH - 34)
end
local function openStats()
	InventoryV2.cancelDrag()
	ui.StatsSheet.Visible = true
end

-- The look: a deep violet panel under the top bar, its boxes framed in a
-- thin line, the paper doll's corners marked in gold.
local P = {
	Panel = Color3.fromRGB(14, 15, 31),
	Box = Color3.fromRGB(9, 10, 22),
	Edge = Color3.fromRGB(104, 86, 186),
	BoxEdge = Color3.fromRGB(62, 58, 112),
	HeadA = Color3.fromRGB(62, 38, 118),
	HeadB = Color3.fromRGB(24, 19, 50),
	Bracket = Color3.fromRGB(222, 184, 112),
}
local function panelBox(parent: Instance, x: number, y: number, w: number, h: number): Frame
	local f = frame(parent, P.Box, 0.1)
	place(f, x, y, w, h)
	round(f, 12)
	stroke(f, P.BoxEdge, 1, 0.2)
	return f
end
local function boxTitle(parent: Instance, value: string, x: number, y: number, w: number): TextLabel
	local t = place(text(parent, value, if COMPACT then 12 else 12, C.Text, HEAVY), x, y, w, 16)
	return t
end
-- An L of gold at each corner of the paper doll.
local function brackets(parent: Instance, w: number, h: number)
	local arm, inset = 22, 8
	for _, corner in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
		local cx = if corner[1] == 0 then inset else w - inset - arm
		local cy = if corner[2] == 0 then inset else h - inset - arm
		local across = frame(parent, P.Bracket, 0.15)
		place(across, cx, if corner[2] == 0 then cy else cy + arm - 2, arm, 2)
		local down = frame(parent, P.Bracket, 0.15)
		place(down, if corner[1] == 0 then cx else cx + arm - 2, cy, 2, arm)
	end
end
-- A plain button (the header's, the STATS tab's).
local function plainButton(parent: Instance, label: string, x: number, y: number, w: number, h: number, primary: boolean?, tint: Color3?): TextButton
	local b = new("TextButton", {
		Text = label,
		TextSize = if COMPACT then 12 else 12,
		Font = HEAVY,
		TextColor3 = if primary then Color3.fromRGB(26, 18, 6) elseif tint then tint:Lerp(C.Text, 0.45) else C.Text,
		AutoButtonColor = true,
		BackgroundColor3 = if primary then C.Gold else Color3.fromRGB(22, 24, 35),
		BackgroundTransparency = 0,
	}, parent)
	place(b, x, y, w, h)
	round(b, 9)
	if primary then
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(214, 200, 176)) }, b)
	else
		stroke(b, C.Line, 1, 0.86)
		if tint then
			-- (its colour: a short bar along the foot)
			local bar = new("Frame", { BackgroundColor3 = tint, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(0.4, 0, 0, 2) }, b)
			round(bar, 1)
		end
	end
	UiKit.fit(b)
	b:SetAttribute("UiSound", if primary then "Confirm" else "Click")
	return b
end

-- EQUIP BEST, then a build per element (a tap puts it on at once: the best
-- gems of that element), as AUTO EQUIP's modes in the stats sheet do.
local function buildQuickEquip(parent: Instance, x: number, y: number, bestW: number, chipW: number, h: number, gap: number)
	local best = plainButton(parent, "EQUIP BEST", x, y, bestW, h, true)
	best.Name = "EquipBest"
	UpgradeHints.bind(best, function(hints) return hints.Equipment end, C.Gold)
	best.Activated:Connect(function()
		state.AutoMode = "Best"
		request("AutoEquip", "Best")
	end)
	for i, element in ELEMENTS do
		local tint = GemConfig.ElementColors[element] or C.Text
		local b = plainButton(parent, AutoEquip.label(element), x + bestW + gap + (i - 1) * (chipW + gap), y, chipW, h, false, tint)
		b.Name = "Equip" .. element
		b.TextSize = if COMPACT then 11 else 11
		b.Activated:Connect(function()
			state.AutoMode = element
			request("AutoEquip", element)
		end)
	end
end

-- GEMS (the gem window, GemVault) and SKINS (the Wardrobe), side by side
-- (full: the header's right end).
local function buildButtons(holder: Instance, x: number, buttonY: number, totalW: number, buttonH: number, gap: number)
	local gems = new("TextButton", {
		Name = "GemsButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, holder)
	local half = (totalW - gap) / 2
	local iconAt, iconSize, labelX = 8, 34, 50
	place(gems, x, buttonY, half, buttonH)
	round(gems, 10)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(38, 31, 60), Color3.fromRGB(16, 20, 31)),
	}, gems)
	local gemsEdge = stroke(gems, Color3.fromRGB(190, 120, 255), 1, 0.55)
	ui.GemsEdge = gemsEdge
	local gemsIcon = frame(gems, Color3.fromRGB(255, 255, 255), 0.95)
	place(gemsIcon, iconAt, (buttonH - iconSize) / 2, iconSize, iconSize)
	round(gemsIcon, 20)
	ui.GemsIcon = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gemsIcon)
	place(text(gems, "GEM VAULT", 14, C.Text, HEAVY), labelX, buttonH / 2 - 17, half - labelX - 24, 18)
	ui.GemsCount = place(text(gems, "", 10, C.Dim, HEADING), labelX, buttonH / 2 + 2, half - labelX - 24, 14)
	local review = place(text(gems, "›", 18, Color3.fromRGB(200, 150, 255), HEAVY), half - 22, buttonH / 2 - 12, 14, 22)
	review.TextXAlignment = Enum.TextXAlignment.Right
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
	place(text(skins, "SKINS", 14, C.Text, HEAVY), labelX, buttonH / 2 - 17, half - labelX - 24, 18)
	ui.SkinsCount = place(text(skins, "", 10, C.Dim, HEADING), labelX, buttonH / 2 + 2, half - labelX - 24, 14)
	ui.SkinsCount.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = ui.SkinsCount.TextSize }, ui.SkinsCount)
	local wardrobe = place(text(skins, "›", 18, Color3.fromRGB(255, 150, 205), HEAVY), half - 22, buttonH / 2 - 12, 14, 22)
	wardrobe.TextXAlignment = Enum.TextXAlignment.Right
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

-- The panel and (full) its header: your level, name and sets, EQUIP BEST and
-- a build per element, then the gem vault and the wardrobe.
local function buildHeader(canvas: Frame)
	local panel = frame(canvas, P.Panel, 0.08)
	panel.Name = "InventoryPanel"
	place(panel, 0, PANEL_Y, W, H - PANEL_Y)
	round(panel, 16)
	stroke(panel, P.Edge, 1.5, 0.35)
	ui.Miners = {}
	if COMPACT then
		return
	end
	local head = frame(panel, Color3.new(1, 1, 1))
	head.Name = "Header"
	place(head, 0, 0, W, HEAD_H)
	round(head, 16)
	new("UIGradient", { Color = ColorSequence.new(P.HeadA, P.HeadB) }, head)
	-- (its lower corners square, a line under it)
	local foot = frame(head, Color3.new(1, 1, 1))
	place(foot, 0, HEAD_H - 16, W, 16)
	new("UIGradient", { Color = ColorSequence.new(P.HeadA, P.HeadB) }, foot)
	local rule = frame(head, P.Edge, 0.4)
	place(rule, 0, HEAD_H - 1, W, 1)
	-- Your level in a gold ring.
	local badge = frame(head, C.Ink, 0.2)
	place(badge, 16, 10, 42, 42)
	round(badge, 21)
	stroke(badge, C.Gold, 2, 0.1)
	ui.LevelBadge = text(badge, "1", 16, C.Gold, HEAVY)
	ui.LevelBadge.Size = UDim2.fromScale(1, 1)
	ui.LevelBadge.TextXAlignment = Enum.TextXAlignment.Center
	ui.Name = place(text(head, "", 24, C.Text, HEAVY), 72, 8, 420, 28)
	ui.Sub = place(text(head, "", 11, Color3.fromRGB(196, 182, 240), HEADING), 72, 36, 460, 16)
	UiKit.fit(ui.Sub)
	-- Miner 1 / 2 / 3 (none while the roster is off: one miner).
	for index = 1, if MinerRoster.Enabled then MinerRoster.Count else 0 do
		local b = new("TextButton", {
			Text = tostring(index),
			TextSize = 13,
			Font = HEADING,
			TextColor3 = C.Faint,
			AutoButtonColor = false,
			BackgroundColor3 = C.Gold,
			BackgroundTransparency = 1,
		}, head)
		place(b, 500 + (index - 1) * 38, 15, 32, 32)
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
	buildQuickEquip(head, 616, 12, 150, 94, 38, 8)
	buildButtons(head, W - 16 - 380, 7, 380, 48, 10)
end

-- The paper doll: your miner in the middle, your armor on the left and your
-- weapons on the right, each piece a card with its gem socket under it.
-- Click a card for the piece's window; drop a gem on it to socket it.
-- Item window -----------------------------------------------------------------------------------------
-- A click on anything (a worn piece or its socket, a Q / E / R card, a
-- backpack gem, a spare piece) opens just that item, laid out to read: a
-- slot shows its piece and its gem side by side, a backpack gem its grades
-- and every move it gives. Changing things is drag and drop; the window's
-- one button EQUIPs a spare piece or TAKEs a socketed gem OUT.
local Info: any = { Window = nil, Roman = { "I", "II", "III" } }
function Info.close()
	if Info.Window then
		Info.Window:Destroy()
		Info.Window = nil
	end
end
-- A card: its title, then rows top to bottom (it scrolls when they're long).
function Info.card(parent: Instance, x: number, y: number, w: number, h: number, title: string)
	local box = panelBox(parent, x, y, w, h)
	place(text(box, title, 11, C.Dim, HEAVY), 16, 10, w - 32, 16)
	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -24, 1, -42),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Faint,
	}, box)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, list)
	return { List = list, W = w - 40, N = 0 }
end
function Info.row(c, h: number): Frame
	c.N += 1
	return new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(c.W, h), LayoutOrder = c.N }, c.List)
end
-- Wrapped text, as tall as it needs.
function Info.para(c, value: string, size: number, color: Color3, font: Enum.Font?, rich: boolean?)
	c.N += 1
	local t = text(c.List, value, size, color, font or BODY)
	t.LayoutOrder = c.N
	t.TextWrapped, t.TextTruncate, t.RichText = true, Enum.TextTruncate.None, rich == true
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.Size = UDim2.fromOffset(c.W, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	return t
end
function Info.heading(c, value: string, color: Color3?)
	local r = Info.row(c, 24)
	place(text(r, value, 11, color or C.Gold, HEAVY), 0, 6, c.W, 14)
	place(frame(r, color or C.Gold, 0.75), 0, 23, c.W, 1)
end
-- A label on the left, its value on the right.
function Info.pair(c, label: string, value: string, color: Color3?)
	local r = Info.row(c, 20)
	place(text(r, label, 13, C.Dim, MEDIUM), 0, 0, c.W * 0.62, 20)
	local v = place(text(r, value, 13, color or C.Text, HEAVY), c.W * 0.38, 0, c.W * 0.62, 20)
	v.TextXAlignment = Enum.TextXAlignment.Right
end
-- The item itself: its art in a well, its name, a few lines under it.
function Info.top(c, color: Color3, art: (Frame) -> (), name: string, lines: { { any } })
	local r = Info.row(c, 104)
	local well = frame(r, C.Ink, 0.35)
	place(well, 0, 0, 100, 100)
	round(well, 12)
	stroke(well, color, 1.5, 0.3)
	art(well)
	local title = place(text(r, name, 18, color, HEAVY), 114, 2, c.W - 114, 44)
	title.TextWrapped, title.TextTruncate = true, Enum.TextTruncate.AtEnd
	title.TextYAlignment = Enum.TextYAlignment.Top
	for i, line in lines do
		local l = place(text(r, line[1], 12, line[2] or C.Dim, HEADING), 114, 34 + i * 17, c.W - 114, 16)
		UiKit.fit(l)
	end
end
-- A grade (Size, Clarity, Cut) as a bar out of 10 and what it does.
function Info.grade(c, label: string, value: number?, effect: string, color: Color3)
	local r = Info.row(c, 30)
	place(text(r, label, 13, C.Text, HEADING), 0, 0, 80, 16)
	local note = place(text(r, effect, 11, C.Dim, MEDIUM), 80, 0, c.W - 140, 16)
	note.TextXAlignment = Enum.TextXAlignment.Right
	local num = place(text(r, if value then tostring(value) .. "/10" else "—", 13, color, HEAVY), c.W - 56, 0, 56, 16)
	num.TextXAlignment = Enum.TextXAlignment.Right
	local track = frame(r, C.Ink, 0.1)
	place(track, 0, 21, c.W, 6)
	round(track, 3)
	local fill = frame(track, color)
	fill.Size = UDim2.fromScale(math.clamp((value or 0) / 10, 0, 1), 1)
	round(fill, 3)
end
-- A move a gem gives a key: its icon with the key on the corner, its name,
-- tier and rank, cost and cooldown, then what it does.
function Info.move(c, key: string?, gem, loadout)
	local triad = triadOn(loadout)
	local cast = if key then keyGem(gem, key, loadout) else gem
	local surge = cast and Tech.surgeStats(cast)
	local tint = gemColor(gem)
	local keyColor = if key and triad then KEY_COLORS[key] else C.Gold
	local r = Info.row(c, 54)
	local tile = frame(r, C.Ink, 0.2)
	place(tile, 0, 2, 50, 50)
	round(tile, 10)
	stroke(tile, keyColor, 1.5, 0.2)
	local glyph = text(tile, if surge then "◆" else "–", 22, tint, HEAVY)
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	if surge then
		pcall(SurgeIcons.apply, glyph, surge, tint)
	end
	if key then
		local badge = text(tile, key, 10, C.Ink, HEAVY)
		badge.BackgroundTransparency, badge.BackgroundColor3, badge.ZIndex = 0, keyColor, 6
		badge.TextXAlignment = Enum.TextXAlignment.Center
		place(badge, -5, -5, 18, 16)
		round(badge, 4)
	end
	place(text(r, if surge then surge.Name else "No move for " .. (key or "this key"), 15, C.Text, HEAVY), 62, 2, c.W - 62, 20)
	if not surge then
		return
	end
	local tier = math.clamp(tonumber(surge.Tier) or 1, 1, 4)
	local rank = math.clamp(tonumber(surge.Rank) or 1, 1, 3)
	local move = Tech.Catalog[cast.Surge or ""]
	local sub = place(text(r, string.format(
		"%sT%d %s  ·  RANK %s%s",
		if key then (if triad then LANE_WORDS[key] else "SURGE") .. "  ·  " else "",
		tier,
		string.upper(GemRoller.TierNames[tier] or ""),
		Info.Roman[rank],
		if move and move.Rare then "  ·  ★ SIGNATURE" else ""
	), 11, keyColor, HEADING), 62, 23, c.W - 62, 14)
	UiKit.fit(sub)
	place(text(r, string.format(
		"%s %s  ·  %ss COOLDOWN%s",
		whole(surge.Cost or 0),
		string.upper(surge.Resource or "Charge"),
		whole(surge.Cooldown or 0),
		if surge.Triad then string.format("  ·  %s%% POWER", whole((surge.Output or 1) * 100)) else ""
	), 11, C.Dim, MEDIUM), 62, 38, c.W - 62, 14)
	if (surge.Description or "") ~= "" then
		Info.para(c, surge.Description, 12, C.Text)
	end
	if surge.Flourished and surge.Flourish and surge.Flourish.Text then
		Info.para(c, "✦ " .. surge.Flourish.Text, 12, C.Gold, HEADING)
	end
end
-- A piece: what it is, every stat on it, its perk, what makes this roll its own.
function Info.piece(c, slot: string, id: string?, spare: boolean, gem, loadout)
	local gear = id and gearOf(loadout, slot, id)
	if not gear then
		Info.para(c, "Nothing worn here.", 15, C.Text, HEAVY)
		Info.para(c, "Spare pieces wait in your bag on the right: open one to wear it.", 13, C.Dim, MEDIUM)
		return
	end
	local rarity = rarityOf(loadout, slot, id)
	local color = rarityColor(rarity)
	local roll = GearRolls.get(loadout, slot, id)
	local lines = { { rarityName(rarity) .. "  ·  " .. SLOT_NAME[slot], color } }
	if spare then
		local gain = ratingGain(loadout, slot, id :: string)
		table.insert(lines, { string.format("RATING %s%d IF WORN", if gain >= 0 then "+" else "", gain), if gain >= 0 then C.Good else C.Bad })
	else
		table.insert(lines, { "WORN", C.Good })
	end
	Info.top(c, color, function(well)
		gearArt(well, slot, id :: string, not spare, color)
	end, gear.Name, lines)
	Info.heading(c, "STATS")
	local stats = {}
	for stat, amount in roll and roll.Stats or {} do
		local percent = stat == "Critical" or stat == "Cooldown"
		table.insert(stats, { Stat = stat, Text = if percent then "+" .. whole(amount * 100) .. "%" else "+" .. whole(amount), Weight = if percent then amount * 100 else amount })
	end
	table.sort(stats, function(a, b)
		if a.Weight ~= b.Weight then
			return a.Weight > b.Weight
		end
		return a.Stat < b.Stat
	end)
	for _, s in stats do
		Info.pair(c, (s.Stat:gsub("(%l)(%u)", "%1 %2")), s.Text, STAT_COLOR[s.Stat] or C.Good)
	end
	if #stats == 0 then
		Info.para(c, "No stats on this piece.", 12, C.Dim, MEDIUM)
	end
	if spare then
		local deltas = statDeltas(loadout, slot, id :: string)
		if deltas ~= "" then
			Info.heading(c, "IF YOU WEAR IT", C.Teal)
			Info.para(c, deltas, 13, C.Text, HEADING, true)
		end
	end
	local signature = perkOf(loadout, slot, id, gem)
	if signature then
		Info.heading(c, "PERK")
		Info.pair(c, signature.Definition.Name, perkValue(signature), C.Gold)
		Info.para(c, signature.Definition.Trigger or "", 12, C.Text)
	elseif type(gear.Passive) == "table" and gear.Passive.Name then
		Info.heading(c, "PERK")
		Info.para(c, gear.Passive.Name, 14, C.Gold, HEAVY)
		Info.para(c, gear.Passive.Text or "", 12, C.Text)
	end
	local identity = GearRolls.identity(roll)
	if identity ~= "" then
		Info.heading(c, "THIS ROLL", C.Dim)
		Info.para(c, identity, 12, C.Dim, MEDIUM)
	end
end
-- A gem: what it is, its grades, and (in a sword, chest or shield) the move
-- it gives that key.
function Info.gem(c, gem, slot: string?, key: string?, loadout)
	if not gem then
		Info.para(c, "Empty socket.", 15, C.Text, HEAVY)
		Info.para(c, "Drag a gem from your backpack onto this piece to fill it."
			.. (if key then " Its " .. string.lower(LANE_WORDS[key]) .. " move becomes your " .. key .. "." else ""), 13, C.Dim, MEDIUM)
		return
	end
	local color = gemColor(gem)
	local lines = { { rarityName(gemRarity(gem)) .. "  ·  " .. string.upper(GemConfig.elementName(gem.Element)), color } }
	if gem.Cut == nil then
		table.insert(lines, { "ROUGH: CUT IT TO USE IT", C.Gold })
	end
	local okWorth, worth = pcall(GemConfig.value, gem)
	if okWorth and type(worth) == "number" then
		table.insert(lines, { "WORTH " .. commas(worth) .. " COINS", C.Dim })
	end
	if slot and not key then
		table.insert(lines, { "POWERS THIS PIECE'S PERK", C.Teal })
	end
	Info.top(c, color, function(well)
		gemArt(well, gem)
	end, gemName(gem), lines)
	Info.heading(c, "GRADES")
	local function share(value: number?, weight: number): string
		return string.format("%.1f%%", weight * (math.clamp(tonumber(value) or 1, 1, 10) - 1) / 9 * 100)
	end
	Info.grade(c, "Size", gem.Size, "+" .. share(gem.Size, Traits.SizePotency) .. " potency", color)
	Info.grade(c, "Clarity", gem.Clarity, "+" .. share(gem.Clarity, Traits.ClarityDuration) .. " duration", color)
	Info.grade(c, "Cut", gem.Cut, "−" .. share(gem.Cut, Traits.CutCooldown) .. " cooldown", color)
	if key then
		Info.heading(c, key .. "  ·  YOUR " .. LANE_WORDS[key] .. " MOVE", KEY_COLORS[key])
		Info.move(c, key, gem, loadout)
	end
end
-- item: { Slot } a worn slot, { Slot, Id } a spare piece, { Gem } a backpack
-- gem; Key, when a Q / E / R card opened it.
function Info.open(item)
	Info.close()
	local canvas = ui.Canvas
	if not canvas then
		return
	end
	if InventoryV2.hideTip then
		InventoryV2.hideTip()
	end
	local loadout = loadoutNow()
	local triad = triadOn(loadout)
	local slot, spareId = item.Slot, item.Id
	local pieceId = if slot then spareId or loadout[slot] else nil
	local gem = item.Gem
	if slot then
		gem = if spareId then slotGemFor(loadout, slot, spareId) else loadout[slot .. "Gem"]
	end
	local key = item.Key or (if slot and triad then Traits.KeyOfSocket[slot] else nil)
	local gear = slot and pieceId and gearOf(loadout, slot, pieceId)
	local color = if gear then rarityColor(rarityOf(loadout, slot, pieceId)) elseif gem then gemColor(gem) else C.Text
	local scrim = new("TextButton", {
		Name = "ItemWindow",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3,
		ZIndex = 30,
	}, canvas)
	place(scrim, -W, -H, W * 3, H * 3)
	scrim.Activated:Connect(Info.close)
	Info.Window = scrim
	local pw, ph = math.min(940, W - 20), math.min(600, H - 8)
	local panel = new("TextButton", { Name = "Panel", Text = "", AutoButtonColor = false, BackgroundColor3 = P.Panel, BackgroundTransparency = 0.02 }, scrim)
	place(panel, W + (W - pw) / 2, H + (H - ph) / 2, pw, ph)
	round(panel, 16)
	stroke(panel, P.Edge, 1.5, 0.2)
	local grow = new("UIScale", { Scale = 0.94 }, panel)
	TweenService:Create(grow, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- The title: what kind of item and where it is, then its name.
	local headH = if COMPACT then 50 else 62
	local band = frame(panel, Color3.new(1, 1, 1))
	place(band, 0, 0, pw, headH)
	round(band, 16)
	new("UIGradient", { Color = ColorSequence.new(P.HeadA, P.HeadB) }, band)
	place(frame(band, color, 0.2), 0, headH - 2, pw, 2)
	local kicker = if slot
		then SLOT_NAME[slot] .. (if spareId then "  ·  IN YOUR BAG" else "  ·  WORN")
			.. (if key then "  ·  " .. key .. " " .. LANE_WORDS[key] else "")
		else "GEM  ·  IN YOUR BACKPACK"
	place(text(band, kicker, 11, Color3.fromRGB(196, 182, 240), HEAVY), 20, if COMPACT then 6 else 10, pw - 90, 14)
	local title = if slot then (if gear then gear.Name else "Nothing worn") else gemName(gem)
	local titleLabel = place(text(band, title, if COMPACT then 18 else 22, color, HEAVY), 20, if COMPACT then 22 else 28, pw - 90, if COMPACT then 22 else 26)
	UiKit.fit(titleLabel)
	local close = new("TextButton", {
		Name = "Close",
		Text = "×",
		TextSize = 28,
		Font = HEADING,
		TextColor3 = C.Dim,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
	}, band)
	place(close, pw - 52, (headH - 44) / 2, 44, 44)
	close:SetAttribute("UiSound", "Back")
	close.MouseEnter:Connect(function()
		close.TextColor3 = C.Text
	end)
	close.MouseLeave:Connect(function()
		close.TextColor3 = C.Dim
	end)
	close.Activated:Connect(Info.close)
	-- The one thing to do here, if there is one.
	local action, primary, act = nil, false, nil
	if slot and spareId then
		action, primary = "EQUIP", true
		act = function()
			request("EquipGear", Slots.Definitions[slot].Kind, spareId)
		end
	elseif slot and gem then
		action = "TAKE GEM OUT"
		act = function()
			request("UnsocketGem", slot)
		end
	end
	local footH = if action then (if COMPACT then 46 else 58) else 0
	local bodyY = headH + 12
	local bodyH = ph - bodyY - 12 - footH
	local gap = 14
	local cw = (pw - 28 - gap) / 2
	local left = Info.card(panel, 14, bodyY, cw, bodyH, if slot then (if spareId then "SPARE PIECE" else "PIECE") else "GEM")
	local right = Info.card(panel, 14 + cw + gap, bodyY, cw, bodyH, if slot then "ITS GEM" else "ITS MOVES")
	if slot then
		Info.piece(left, slot, pieceId, spareId ~= nil, gem, loadout)
		Info.gem(right, gem, slot, key, loadout)
	elseif gem then
		Info.gem(left, gem, nil, nil, loadout)
		if gem.Cut == nil then
			Info.para(right, "A rough gem has no moves yet. Cut it, then drag it onto your sword (Q), chest (E) or shield (R).", 13, C.Dim, MEDIUM)
		elseif triad then
			for _, k in KEYS do
				Info.heading(right, k .. "  ·  " .. LANE_WORDS[k] .. "  ·  IN YOUR " .. string.upper(Traits.SocketNames[k]), KEY_COLORS[k])
				Info.move(right, k, gem, loadout)
			end
		else
			Info.move(right, nil, gem, loadout)
		end
	end
	if action and act then
		local bw = if primary then 220 else 200
		local b = plainButton(panel, action, pw - 14 - bw, ph - footH, bw, footH - 14, primary, if primary then nil else C.Bad)
		b.Activated:Connect(function()
			act()
			Info.close()
		end)
	end
end
InventoryV2.openItem = Info.open
InventoryV2.closeItem = Info.close

local DOLL_SLOTS = {
	{ "Helmet", 1, 1 },
	{ "Armor", 1, 2 },
	{ "Gloves", 1, 3 },
	{ "Weapon", 2, 1 },
	{ "Shield", 2, 2 },
	{ "Boots", 2, 3 },
}

-- One slot's card: its piece (art, name, rarity), its key's surge for Q / E /
-- R, and the gem socket (full: a line under the card; compact: its foot).
local function buildRow(parent: Instance, slot: string, x: number, y: number)
	local cw, ch = CARD_W, CARD_H
	if not COMPACT then
		local label = place(text(parent, SLOT_NAME[slot], 11, C.Dim, HEAVY), x, y - 18, cw, 14)
		label.TextXAlignment = Enum.TextXAlignment.Center
	end
	local row = new("TextButton", {
		Name = "Row" .. slot,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
	}, parent)
	place(row, x, y, cw, ch)
	round(row, 10)
	local tint = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(26, 26, 44), Color3.fromRGB(12, 12, 24)),
		Transparency = NumberSequence.new(0.05, 0.15),
	}, row)
	local edge = stroke(row, C.Gold, 1.5, 1)
	-- (a bar in the piece's rarity along the top)
	local rail = frame(row, C.Text)
	place(rail, 12, 0, cw - 24, 3)
	round(rail, 2)
	local well = frame(row, C.Ink, 0)
	local wellEdge = stroke(well, C.Line, 1, 0.8)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.35) }, well)
	if COMPACT then
		place(well, 8, 8, 46, 46)
	else
		place(well, (cw - 66) / 2, 10, 66, 66)
	end
	round(well, 8)
	local art = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, well)
	local name, meta
	if COMPACT then
		local slotName = place(text(row, SLOT_NAME[slot], 9, C.Dim, HEAVY), 60, 7, cw - 66, 11)
		slotName.Name = "SlotName"
		name = place(text(row, "", 12, C.Text, HEADING), 60, 19, cw - 66, 28)
		meta = place(text(row, "", 9, C.Dim, HEADING), 60, 47, cw - 66, 11)
	else
		name = place(text(row, "", 12, C.Text, HEADING), 8, 80, cw - 16, 30)
		name.TextXAlignment = Enum.TextXAlignment.Center
		meta = place(text(row, "", 10, C.Dim, HEADING), 8, 110, cw - 16, 13)
		meta.TextXAlignment = Enum.TextXAlignment.Center
	end
	name.TextWrapped = true
	name.TextYAlignment = Enum.TextYAlignment.Top
	meta.RichText = true
	-- The sword's, chest's and shield's cards show the surge their gem gives
	-- Q, E or R (its icon, its key, a line in the gem's colour), top right.
	local key = Traits.KeyOfSocket[slot]
	local surgeTile, surgeGlyph, surgeBadge, surgeLine, surgeEdge
	if key then
		local size = if COMPACT then 26 else 32
		surgeTile = frame(row, C.Ink, 0.3)
		surgeTile.Name = "SurgeTile"
		place(surgeTile, cw - size - 6, 8, size, size)
		round(surgeTile, 7)
		surgeEdge = stroke(surgeTile, C.Line, 1, 0.4)
		surgeGlyph = text(surgeTile, "+", 14, C.Faint, HEADING)
		surgeGlyph.Name = "Glyph"
		surgeGlyph.Size = UDim2.fromScale(1, 1)
		surgeGlyph.TextXAlignment = Enum.TextXAlignment.Center
		surgeBadge = text(surgeTile, key, 9, C.Ink, HEAVY)
		surgeBadge.Name = "Key"
		surgeBadge.BackgroundTransparency = 0
		surgeBadge.BackgroundColor3 = KEY_COLORS[key]
		surgeBadge.TextXAlignment = Enum.TextXAlignment.Center
		surgeBadge.ZIndex = 4
		place(surgeBadge, -5, -5, 14, 14)
		round(surgeBadge, 4)
		surgeLine = frame(surgeTile, C.Faint, 0.6)
		surgeLine.Name = "Line"
		surgeLine.ZIndex = 4
		place(surgeLine, 5, size - 4, size - 10, 2)
		round(surgeLine, 1)
	end
	-- The gem socket: the stone (or a +), then its name (or the ask).
	local socketRow = new("TextButton", { Name = "Socket", Text = "", AutoButtonColor = false, BackgroundTransparency = 1 }, if COMPACT then row else parent)
	if COMPACT then
		place(socketRow, 8, ch - 30, cw - 16, 24)
	else
		place(socketRow, x, y + ch + 6, cw, 24)
	end
	local socket = frame(socketRow, C.Ink, 0.4)
	place(socket, 0, 0, 24, 24)
	round(socket, 12)
	local halo = frame(socket, C.Gold, 0.94)
	halo.Name = "EmptySocketGlow"
	halo.Position = UDim2.fromOffset(-4, -4)
	halo.Size = UDim2.new(1, 8, 1, 8)
	round(halo, 16)
	halo.Visible = false
	local ring = stroke(socket, C.Faint, 1.5, 0.3)
	local gemHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(1, 1), Size = UDim2.new(1, -2, 1, -2) }, socket)
	local plus = text(socket, "+", 14, C.Faint, HEADING)
	plus.Size = UDim2.fromScale(1, 1)
	plus.TextXAlignment = Enum.TextXAlignment.Center
	local enchant = place(text(socketRow, "ADD A GEM", 10, C.Gold:Lerp(C.Dim, 0.35), HEADING), 30, 0, cw - (if COMPACT then 46 else 30), 24)
	enchant.Name, enchant.Visible = "EnchantHint", false
	-- (the gem in it, and with the triad the move it gives this key)
	local moveLine = place(text(socketRow, "", 10, C.Dim, HEADING), 30, 0, cw - (if COMPACT then 46 else 30), 24)
	moveLine.Name, moveLine.RichText, moveLine.Visible = "SurgeName", true, false
	local function open()
		if os.clock() < suppressClickUntil then
			return
		end
		Info.open({ Slot = slot })
	end
	row:SetAttribute("UiSound", "Click")
	row.Activated:Connect(open)
	socketRow.Activated:Connect(open)
	local entry = { Row = row, Tint = tint, Edge = edge, Rail = rail, Well = well, WellEdge = wellEdge, Art = art, Name = name, Meta = meta, Ring = ring, Gem = gemHolder, Plus = plus, Halo = halo, Enchant = enchant }
	entry.Key, entry.SurgeTile, entry.SurgeGlyph, entry.SurgeBadge, entry.SurgeLine, entry.SurgeEdge =
		key, surgeTile, surgeGlyph, surgeBadge, surgeLine, surgeEdge
	entry.MoveLine, entry.Socket = moveLine, socketRow
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
	for _, target in { row, socketRow } do
		table.insert(dropTargets, {
			Frame = target,
			Stroke = edge,
			Accepts = function(item: Item)
				return acceptsSlot(slot, item)
			end,
			Drop = function(item: Item)
				socketInto(slot, item)
			end,
		})
	end
	return entry
end

local function buildDoll(canvas: Frame)
	local y0 = if COMPACT then PANEL_Y else BODY_Y
	local h = H - y0 - (if COMPACT then 0 else 14)
	local doll = new("Frame", { Name = "Doll", BackgroundTransparency = 1 }, canvas)
	place(doll, DOLL_X, y0, DOLL_W, h)
	ui.List = doll
	local back = panelBox(doll, 0, 0, DOLL_W, h)
	back.Name = "DollBox"
	brackets(back, DOLL_W, h)
	-- The miner, in the middle, on a lit floor.
	local cx = DOLL_W / 2
	local floorY = h - (if COMPACT then 26 else 44)
	glow(doll, cx, h * 0.45, if COMPACT then 120 else 210, C.Teal, 1)
	for i = 1, 6 do
		local pool = frame(doll, C.Teal, 0.975)
		pool.AnchorPoint = Vector2.new(0.5, 0.5)
		place(pool, cx, floorY, (if COMPACT then 60 else 90) + i * (if COMPACT then 18 else 30), 8 + i * 5)
		pool.Position = UDim2.fromOffset(cx, floorY)
		round(pool, 9999)
	end
	local line = frame(doll, C.Teal, 0.2)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	place(line, cx, floorY, if COMPACT then 150 else 260, 2)
	line.Position = UDim2.fromOffset(cx, floorY)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, line)
	ui.MinerView = new("ViewportFrame", {
		Name = "MinerView",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 165, 190),
		LightColor = Color3.fromRGB(235, 245, 255),
		LightDirection = Vector3.new(-0.5, -0.8, 0.6),
	}, doll)
	local viewW = if COMPACT then 220 else 330
	place(ui.MinerView, cx - viewW / 2, if COMPACT then 4 else 24, viewW, floorY - (if COMPACT then 0 else 16))
	ui.MinerSource = nil
	ui.MinerYaw = 0
	-- Drag across the miner to turn them.
	local turn = new("TextButton", { Name = "TurnMiner", Text = "", AutoButtonColor = false, BackgroundTransparency = 1 }, doll)
	local turnW = DOLL_W - 2 * (CARD_W + 2 * DOLL_PAD)
	place(turn, cx - turnW / 2, 20, turnW, floorY - 20)
	turn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			ui.Turning = { X = input.Position.X, Touch = input.UserInputType == Enum.UserInputType.Touch }
		end
	end)
	if not COMPACT then
		local hint = place(text(doll, "DRAG TO TURN  ·  CLICK A SLOT FOR DETAILS", 10, C.Faint, HEADING), cx - 160, h - 26, 320, 14)
		hint.TextXAlignment = Enum.TextXAlignment.Center
		hint.TextTransparency = 0.3
	end
	-- The six slots, three a side.
	ui.Rows = {}
	local blockH = if COMPACT then CARD_H else CARD_H + 18 + 30
	local gap = (h - 3 * blockH) / 4
	for _, spec in DOLL_SLOTS do
		local slot, column, rowIndex = spec[1], spec[2], spec[3]
		local x = if column == 1 then DOLL_PAD else DOLL_W - DOLL_PAD - CARD_W
		local y = gap + (rowIndex - 1) * (blockH + gap) + (if COMPACT then 0 else 18)
		ui.Rows[slot] = buildRow(doll, slot, x, y)
	end
end

-- Q / E / R: a card each, side by side (in the summary column, or the
-- STATS tab on a phone). Click one for its window; drop a gem on it.
local function buildSurges(parent: Instance, x0: number, y0: number, totalW: number, cardH: number)
	ui.Keys = {}
	local gap = 8
	local cardW = math.floor((totalW - 2 * gap) / 3)
	for i, key in KEYS do
		local card = new("TextButton", {
			Name = "Key" .. key,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
		}, parent)
		place(card, x0 + (i - 1) * (cardW + gap), y0, cardW, cardH)
		round(card, 10)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(25, 27, 39), Color3.fromRGB(14, 15, 23)) }, card)
		local edge = stroke(card, C.Line, 1, 0.9)
		local iconSize = if COMPACT then 30 else 34
		local icon = frame(card, C.Ink, 0.3)
		place(icon, 7, 7, iconSize, iconSize)
		round(icon, 8)
		local glyph = text(icon, "+", 16, C.Faint, HEADING)
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.TextXAlignment = Enum.TextXAlignment.Center
		local textX = 7 + iconSize + 7
		local lane = place(text(card, "", 9, C.Dim, HEAVY), textX, 9, cardW - textX - 6, 11)
		lane.TextTransparency = 0.1
		UiKit.fit(lane)
		local name = place(text(card, "", 12, C.Text, HEADING), textX, 22, cardW - textX - 6, 16)
		UiKit.fit(name)
		local info = place(text(card, "", 9, C.Dim, MEDIUM), 7, cardH - 20, cardW - 14, 12)
		UiKit.fit(info)
		local badge = text(card, key, 10, C.Text, HEAVY)
		badge.Position = UDim2.fromOffset(2, 2)
		badge.Size = UDim2.fromOffset(16, 15)
		badge.ZIndex = icon.ZIndex + 2
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = C.Ink
		round(badge, 4)
		stroke(badge, C.Faint, 1, 0)
		local line = frame(card, C.Faint)
		line.AnchorPoint = Vector2.new(0, 1)
		line.Position = UDim2.new(0, 12, 1, 0)
		line.Size = UDim2.new(1, -24, 0, 2)
		round(line, 1)
		card:SetAttribute("UiSound", "Click")
		card.Activated:Connect(function()
			if os.clock() < suppressClickUntil then
				return
			end
			local loadout = loadoutNow()
			if triadOn(loadout) then
				-- (R with no shield reads the weapon's gem)
				local socket = if key == "R" and not loadout.Shield then "Weapon" else Traits.Sockets[key]
				Info.open({ Slot = socket, Key = key })
			else
				local gem = Tech.surgeGem(loadout, key)
				if gem then
					Info.open({ Gem = gem })
				end
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
		ui.Keys[key] = { Card = card, Edge = edge, Icon = icon, Glyph = glyph, Name = name, Info = info, Line = line, Badge = badge, Lane = lane, Fixed = true }
		UpgradeHints.bind(card, function(hints) return hints.Surges.Keys[key] == true end, C.Teal)
	end
end

-- A stat tile: its icon in a ring of its colour, its name, its value and a bar.
local STAT_GLYPH = { Health = "+", Power = "⚡", Defense = "◆", Speed = "»" }
local function statTile(parent: Instance, stat: string, x: number, y: number, w: number, h: number)
	local color = STAT_COLOR[stat]
	local tile = new("TextButton", { Name = "Tile" .. stat, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0 }, parent)
	place(tile, x, y, w, h)
	round(tile, 10)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(25, 27, 39), Color3.fromRGB(14, 15, 23)) }, tile)
	stroke(tile, C.Line, 1, 0.9)
	local size = h - (if COMPACT then 12 else 24)
	local ring = frame(tile, color:Lerp(C.Ink, 0.78), 0)
	place(ring, 8, (h - size) / 2, size, size)
	round(ring, 8)
	stroke(ring, color, 1, 0.55)
	local glyph = text(ring, STAT_GLYPH[stat] or "•", math.floor(size * 0.5), color, HEAVY)
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	local tx = 8 + size + 10
	local label = place(text(tile, string.upper(stat), 10, C.Dim, HEAVY), tx, if COMPACT then 4 else 10, w - tx - 8, 12)
	label.Name = "Label"
	local value = place(text(tile, "0", if COMPACT then 16 else 22, C.Text, HEAVY), tx, if COMPACT then 15 else 23, w - tx - 8, if COMPACT then 18 else 26)
	local track = frame(tile, C.Line, 0.9)
	place(track, tx, h - (if COMPACT then 8 else 14), w - tx - 10, if COMPACT then 3 else 5)
	round(track, 3)
	local fill = frame(track, color)
	fill.Size = UDim2.fromScale(0, 1)
	round(fill, 3)
	tile:SetAttribute("UiSound", "Click")
	tile.Activated:Connect(openStats)
	return { Value = value, Fill = fill, Last = nil }
end

-- Full, the middle: who you are (your avatar, name, gear score and sets),
-- Q / E / R, then your combat ratings, the elements, and ALL STATS (the
-- sheet). Compact: the STATS tab of the panel right of the doll.
local function buildSummary(canvas: Frame)
	ui.Tiles = {}
	if COMPACT then
		local side = new("Frame", { Name = "Side", BackgroundTransparency = 1 }, canvas)
		place(side, SIDE_X, PANEL_Y + 6, SIDE_W, H - PANEL_Y - 8)
		ui.Side = side
		-- The tabs: STATS, GEMS, GEAR.
		ui.SideTabs = {}
		local tabW = (SIDE_W - 16) / 3
		for i, spec in { { "Stats", "STATS" }, { "Gems", "GEMS" }, { "Gear", "GEAR" } } do
			local b = new("TextButton", {
				Name = "Tab" .. spec[1],
				Text = spec[2],
				TextSize = 13,
				Font = HEAVY,
				TextColor3 = C.Dim,
				AutoButtonColor = false,
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = 0.3,
			}, side)
			place(b, (i - 1) * (tabW + 8), 0, tabW, 30)
			round(b, 8)
			local edge = stroke(b, C.Line, 1, 0.8)
			b:SetAttribute("UiSound", "Tab")
			b.Activated:Connect(function()
				InventoryV2.cancelDrag()
				state.SideTab = spec[1]
				draw()
			end)
			ui.SideTabs[spec[1]] = { Button = b, Edge = edge }
		end
		local pageH = H - PANEL_Y - 8 - 38
		local function page(name: string): Frame
			local f = new("Frame", { Name = name, BackgroundTransparency = 1, Visible = false }, side)
			place(f, 0, 38, SIDE_W, pageH)
			return f
		end
		local stats = page("StatsPage")
		ui.StatsPage = stats
		ui.Name = place(text(stats, "", 18, C.Text, HEAVY), 0, 0, 250, 22)
		ui.Sub = place(text(stats, "", 10, Color3.fromRGB(196, 182, 240), HEADING), 0, 23, 260, 14)
		UiKit.fit(ui.Sub)
		local cap = place(text(stats, "GEAR SCORE", 9, C.Dim, HEAVY), SIDE_W - 170, 0, 170, 11)
		cap.TextXAlignment = Enum.TextXAlignment.Right
		ui.Score = place(text(stats, "0", 24, C.Gold, HEAVY), SIDE_W - 170, 10, 170, 28)
		ui.Score.TextXAlignment = Enum.TextXAlignment.Right
		buildSurges(stats, 0, 44, SIDE_W, 56)
		local tileW = (SIDE_W - 8) / 2
		for i, stat in Classes.StatNames do
			ui.Tiles[stat] = statTile(stats, stat, ((i - 1) % 2) * (tileW + 8), 106 + (i - 1) // 2 * 44, tileW, 38)
		end
		local by = 196
		local best = plainButton(stats, "EQUIP BEST", 0, by, 150, 32, true)
		best.Name = "EquipBest"
		UpgradeHints.bind(best, function(hints) return hints.Equipment end, C.Gold)
		best.Activated:Connect(function()
			state.AutoMode = "Best"
			request("AutoEquip", "Best")
		end)
		local all = plainButton(stats, "ALL STATS", 158, by, 146, 32, false)
		all.Name = "AllStats"
		all.Activated:Connect(openStats)
		local skins = plainButton(stats, "SKINS", 312, by, SIDE_W - 312, 32, false)
		skins.Name = "SkinsButton"
		skins.Activated:Connect(function()
			if ui.Popups then
				Wardrobe.open(ui.Popups)
			end
		end)
		local chipW = (SIDE_W - 24) / 4
		for i, element in ELEMENTS do
			local tint = GemConfig.ElementColors[element] or C.Text
			local b = plainButton(stats, AutoEquip.label(element), (i - 1) * (chipW + 8), by + 38, chipW, 28, false, tint)
			b.Name = "Equip" .. element
			b.TextSize = 11
			b.Activated:Connect(function()
				state.AutoMode = element
				request("AutoEquip", element)
			end)
		end
		-- GEMS: your loose gems (drag one onto a slot, tap one for the gem
		-- window); VAULT opens the gem window on them all.
		local gems = page("GemsPage")
		ui.GemsPage = gems
		ui.PouchTabs = new("Frame", { Name = "PouchTabs", BackgroundTransparency = 1 }, gems)
		place(ui.PouchTabs, 0, 0, SIDE_W - 96, 26)
		local vault = plainButton(gems, "VAULT  ›", SIDE_W - 88, 0, 88, 26, false, Color3.fromRGB(200, 150, 255))
		vault.Name = "GemsButton"
		vault.Activated:Connect(function()
			if ui.Popups then
				GemVault.open(ui.Popups, nil, InventoryV2.beginGemDrag)
			end
		end)
		ui.PouchCount = place(text(gems, "", 10, C.Faint, HEADING), 0, 30, SIDE_W, 14)
		ui.Pouch = new("ScrollingFrame", {
			Name = "Pouch",
			BackgroundTransparency = 1,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = C.Faint,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, gems)
		place(ui.Pouch, 0, 48, SIDE_W, pageH - 48)
		-- GEAR: your spare pieces, a tab per slot.
		local gear = page("GearPage")
		ui.GearPage = gear
		ui.BagTabs = new("Frame", { Name = "BagTabs", BackgroundTransparency = 1 }, gear)
		place(ui.BagTabs, 0, 0, SIDE_W - 90, 26)
		ui.BagCount = place(text(gear, "", 10, C.Faint, HEADING), SIDE_W - 90, 0, 90, 26)
		ui.BagCount.TextXAlignment = Enum.TextXAlignment.Right
		ui.Bag = new("ScrollingFrame", {
			Name = "Bag",
			BackgroundTransparency = 1,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = C.Faint,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, gear)
		place(ui.Bag, 0, 32, SIDE_W, pageH - 32)
		return
	end
	-- Who you are.
	local card = panelBox(canvas, MID_X, BODY_Y, MID_W, 196)
	card.Name = "Portrait"
	-- (no avatar picture: your name, then your gear score, across the card)
	ui.PName = place(text(card, "", 20, C.Text, HEAVY), 16, 14, MID_W - 32, 24)
	ui.PTitle = place(text(card, "", 10, C.Teal, HEAVY), 16, 40, MID_W - 32, 13)
	place(text(card, "GEAR SCORE", 10, C.Dim, HEAVY), 16, 64, 160, 12)
	ui.Score = place(text(card, "0", 40, C.Gold, HEAVY), 16, 76, MID_W - 32, 44)
	ui.PSets = place(text(card, "", 10, C.Dim, HEADING), 16, 118, MID_W - 32, 13)
	UiKit.fit(ui.PSets)
	-- The set you wear most of: its name, six pips, its bonus.
	local setRule = frame(card, C.Line, 0.92)
	place(setRule, 14, 142, MID_W - 28, 1)
	ui.SumSetName = place(text(card, "", 11, C.Teal, HEAVY), 14, 150, 200, 14)
	ui.SumPips = {}
	for i = 1, 6 do
		local pip = frame(card, C.Line, 0.9)
		place(pip, MID_W - 14 - 6 * 17 + (i - 1) * 17, 155, 12, 4)
		round(pip, 2)
		ui.SumPips[i] = pip
	end
	ui.SumSetBonus = place(text(card, "", 11, C.Text, HEADING), 14, 170, MID_W - 28, 14)
	ui.SumSetBonus.RichText = true
	UiKit.fit(ui.SumSetBonus)
	-- Q / E / R.
	local sy = BODY_Y + 206
	place(text(canvas, "SURGES", 11, C.Dim, HEAVY), MID_X + 2, sy, 120, 14)
	local hint = place(text(canvas, "Q · E · R", 10, C.Faint, HEADING), MID_X + MID_W - 120, sy, 118, 14)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	buildSurges(canvas, MID_X, sy + 18, MID_W, 72)
	-- Combat ratings.
	local cy = sy + 18 + 72 + 12
	local box = panelBox(canvas, MID_X, cy, MID_W, H - 14 - cy)
	box.Name = "CombatRatings"
	boxTitle(box, "COMBAT RATINGS", 14, 12, 200)
	local pill = frame(box, C.Gold, 0.85)
	place(pill, MID_W - 14 - 150, 8, 150, 24)
	round(pill, 12)
	stroke(pill, C.Gold, 1, 0.3)
	ui.Pill = text(pill, "", 12, C.Gold, HEAVY)
	ui.Pill.Size = UDim2.fromScale(1, 1)
	ui.Pill.TextXAlignment = Enum.TextXAlignment.Center
	local tileW = (MID_W - 28 - 10) / 2
	for i, stat in Classes.StatNames do
		ui.Tiles[stat] = statTile(box, stat, 14 + ((i - 1) % 2) * (tileW + 10), 42 + (i - 1) // 2 * 80, tileW, 72)
	end
	-- What you're strong against, weak to and resist.
	local vy = 210
	ui.SumVerdict = {}
	for i, caption in { "STRONG VS", "WEAK TO", "RESISTS" } do
		UiKit.fit(place(text(box, caption, 10, C.Dim, HEAVY), 14, vy + 1, 90, 14))
		local value = place(text(box, "", 12, C.Text, HEADING), 108, vy, MID_W - 122, 16)
		value.RichText = true
		UiKit.fit(value)
		ui.SumVerdict[i] = value
		vy += 20
	end
	-- Max stamina, max charge and what your level adds.
	ui.Chips = {}
	local chipW = (MID_W - 28 - 16) / 3
	for i = 1, 3 do
		local chip = frame(box, C.Teal, 0.9)
		place(chip, 14 + (i - 1) * (chipW + 8), vy + 6, chipW, 24)
		round(chip, 12)
		stroke(chip, C.Teal, 1, 0.55)
		local label = text(chip, "", 10, C.Teal, HEAVY)
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		UiKit.fit(label)
		ui.Chips[i] = label
	end
	local all = plainButton(box, "ALL STATS  ·  AUTO EQUIP  ›", 14, vy + 40, MID_W - 28, 34, false, C.Teal)
	all.Name = "AllStats"
	all.Activated:Connect(openStats)
end

-- A row of filter tabs (over your gems and over your spare gear):
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
			TextSize = if COMPACT then 12 else 10,
			Font = HEADING,
			TextColor3 = if on then tint elseif entry[3] then tint:Lerp(C.Faint, 0.45) else C.Faint,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, if COMPACT then 26 else 24),
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

-- Full, the right: your gem backpack (every loose gem, a tab per element)
-- over your equipment inventory (every spare piece, a tab per slot).
local function buildBags(canvas: Frame)
	if COMPACT then
		return -- (the GEMS and GEAR tabs: buildSummary)
	end
	local gemH = 330
	local gems = panelBox(canvas, BAG_X, BODY_Y, BAG_W, gemH)
	gems.Name = "GemBackpack"
	boxTitle(gems, "GEM BACKPACK", 14, 12, 220)
	ui.PouchCount = place(text(gems, "", 10, C.Faint, HEADING), BAG_W - 14 - 300, 13, 300, 14)
	ui.PouchCount.TextXAlignment = Enum.TextXAlignment.Right
	ui.PouchTabs = new("Frame", { Name = "PouchTabs", BackgroundTransparency = 1 }, gems)
	place(ui.PouchTabs, 14, 34, BAG_W - 28, 24)
	ui.Pouch = new("ScrollingFrame", {
		Name = "Pouch",
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Faint,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, gems)
	place(ui.Pouch, 14, 66, BAG_W - 22, gemH - 76)
	local by = BODY_Y + gemH + 12
	local bagH = H - 14 - by
	local bag = panelBox(canvas, BAG_X, by, BAG_W, bagH)
	bag.Name = "EquipmentInventory"
	boxTitle(bag, "EQUIPMENT INVENTORY", 14, 12, 260)
	ui.BagCount = place(text(bag, "", 10, C.Faint, HEADING), BAG_W - 14 - 200, 13, 200, 14)
	ui.BagCount.TextXAlignment = Enum.TextXAlignment.Right
	ui.BagTabs = new("Frame", { Name = "BagTabs", BackgroundTransparency = 1 }, bag)
	place(ui.BagTabs, 14, 34, BAG_W - 28, 24)
	ui.Bag = new("ScrollingFrame", {
		Name = "Bag",
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.Faint,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, bag)
	place(ui.Bag, 14, 66, BAG_W - 22, bagH - 76)
end

-- The window: one piece (or one surge key) over the screen. Along its top
-- every slot and key (hop between them); on the left the piece and its gem
-- (or the move and its gem) with its perk; on the right the spare pieces
-- and the gems you could put in, what a pick would change, and the buttons.
-- A tap outside, × or Backspace closes it.
local DETAIL_W = 0 -- (set as it's built: two columns and the gap)
local function buildRight(canvas: Frame)
	DETAIL_W = RIGHT_W * 2 + 10
	local scrim = new("TextButton", {
		Name = "DetailWindow",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 20,
	}, canvas)
	-- (past the canvas, so the whole screen dims)
	place(scrim, -W, -H, W * 3, H * 3)
	scrim.Activated:Connect(function()
		openDetail(nil)
	end)
	ui.Modal = scrim
	local padX, titleH = 20, 50
	local contentH = 318
	local panelW, panelH = DETAIL_W + 2 * padX, titleH + contentH + 14
	local panel = new("TextButton", { Name = "Panel", Text = "", AutoButtonColor = false, BackgroundColor3 = P.Panel, BackgroundTransparency = 0.02 }, scrim)
	place(panel, W + (W - panelW) / 2, H + math.max(2, (H - panelH) / 2), panelW, panelH)
	round(panel, 16)
	stroke(panel, P.Edge, 1.5, 0.2)
	ui.ModalPanel = panel
	local band = frame(panel, Color3.new(1, 1, 1))
	place(band, 0, 0, panelW, titleH)
	round(band, 16)
	new("UIGradient", { Color = ColorSequence.new(P.HeadA, P.HeadB) }, band)
	local bandFoot = frame(band, Color3.new(1, 1, 1))
	place(bandFoot, 0, titleH - 16, panelW, 16)
	new("UIGradient", { Color = ColorSequence.new(P.HeadA, P.HeadB) }, bandFoot)
	ui.ModalTitle = place(text(band, "", 16, C.Text, HEAVY), padX, 7, panelW - 2 * padX - 50, 20)
	ui.ModalSub = place(text(band, "", 10, Color3.fromRGB(196, 182, 240), HEADING), padX, 28, panelW - 2 * padX - 50, 14)
	UiKit.fit(ui.ModalSub)
	local close = new("TextButton", {
		Name = "Close",
		Text = "×",
		TextSize = 26,
		Font = HEADING,
		TextColor3 = C.Dim,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
	}, band)
	place(close, panelW - 48, 3, 44, 44)
	close:SetAttribute("UiSound", "Back")
	close.MouseEnter:Connect(function()
		close.TextColor3 = C.Text
	end)
	close.MouseLeave:Connect(function()
		close.TextColor3 = C.Dim
	end)
	close.Activated:Connect(function()
		openDetail(nil)
	end)
	local detail = new("Frame", { Name = "Detail", BackgroundTransparency = 1, Visible = false }, panel)
	place(detail, padX, titleH + 8, DETAIL_W, contentH)
	ui.Detail = detail
	-- Along the top: every slot and key, so you can hop between them.
	ui.Strip = {}
	local sx, group = 0, if COMPACT then 4 else 8
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
		elseif state.Detail and loadoutNow()[state.Detail .. "Gem"] and ui.Popups then
			-- (a socketed gem: the gem window on it, with every property)
			GemVault.open(ui.Popups, loadoutNow()[state.Detail .. "Gem"].Id, InventoryV2.beginGemDrag)
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
	-- Beside the card: the tabs and the element filter, the grid, what a
	-- pick would change, and the buttons.
	local lower = new("Frame", { Name = "Lower", BackgroundTransparency = 1 }, detail)
	place(lower, RIGHT_W + 10, 0, RIGHT_W, contentH)
	local gridH = contentH - 32 - 76 - 44 - 6
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
	drag = { Item = item, Start = pointOf(input, touch), Active = false, Touch = touch, Input = input, At = os.clock() } :: any
end
-- On a phone a finger moving straight up or down over a list scrolls it;
-- a gem (or a piece) is picked up by holding it a moment (DragHold) or by
-- moving it sideways first (pure).
InventoryV2.DragHold = 0.3
function InventoryV2.touchScrolls(moved: Vector2, held: number): boolean
	return held < InventoryV2.DragHold and math.abs(moved.Y) >= math.abs(moved.X)
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
		if current.Touch and InventoryV2.touchScrolls(point - current.Start, os.clock() - (current.At or 0)) then
			drag = nil -- (a swipe: the list scrolls, nothing's picked up)
			return
		end
		current.Active = true
		-- Reveal the equipment beneath the vault only once this is a real drag.
		-- A normal click still opens the stone's details.
		if GemVault.isOpen() then
			GemVault.close()
			state.Detail, state.Pick, state.Hover = nil, nil, nil
			ui.List.Visible, ui.Detail.Visible = true, false
			if ui.Modal then
				ui.Modal.Visible = false
			end
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
	if ui.LevelBadge then
		ui.LevelBadge.Text = tostring(level)
	end
	if ui.PName then
		ui.PName.Text = string.upper(player.DisplayName)
		ui.PTitle.Text = if MinerRoster.Enabled
			then string.format("SAGA MINER %d  ·  LEVEL %d", active, level)
			else string.format("SAGA MINER  ·  LEVEL %d", level)
	end
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
		local tile = ui.Tiles and ui.Tiles[stat]
		if tile then
			tile.Value.Text = whole(value)
			tile.Fill.Size = entry.Fill.Size
			flashValue(tile, value)
		end
	end
	ui.Rating.Text = whole(total)
	if ui.Score then
		ui.Score.Text = whole(total)
	end
	if ui.Pill then
		ui.Pill.Text = "RATING  " .. whole(total)
	end
	if ui.Chips then
		ui.Chips[1].Text = string.format("MAX STAMINA %d", vitals.Stamina)
		ui.Chips[2].Text = string.format("MAX CHARGE %d", vitals.Charge)
		ui.Chips[3].Text = if player:GetAttribute("MatchStats") == "Even" then "EVEN STATS" else string.format("LEVEL +%d HP", vitals.Health)
	end
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
	-- Every set you wear two or more of, most first ("PROSPECTOR 3/6").
	local worn = {}
	for _, family in ArmorFamilies.Order do
		local s = ok and setState.Active[family]
		if s and s.Count >= 2 then
			table.insert(worn, { Name = family, Count = s.Count })
		end
	end
	table.sort(worn, function(a, b)
		return a.Count > b.Count
	end)
	local setParts = {}
	for _, entry in worn do
		table.insert(setParts, string.format("%s %d/6", string.upper(entry.Name), entry.Count))
	end
	local setsText = table.concat(setParts, "  ·  ")
	ui.Sub.Text = string.format("LEVEL %d", level) .. (if setsText ~= "" then "  ·  " .. setsText else "")
	if ui.PSets then
		ui.PSets.Text = if setsText ~= "" then "SETS  " .. setsText else "SETS  wear two of a family"
	end
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
	-- (the summary's set line: the same name, pips and bonus)
	if ui.SumSetName then
		ui.SumSetName.Text = ui.SetName.Text
		ui.SumSetName.TextColor3 = color
		for i, pip in ui.SumPips do
			pip.BackgroundColor3 = ui.Pips[i].BackgroundColor3
			pip.BackgroundTransparency = ui.Pips[i].BackgroundTransparency
		end
		ui.SumSetBonus.Text = if ui.SetBonus.Text ~= "" then ui.SetBonus.Text else ui.SetNext.Text
		ui.SumSetBonus.TextColor3 = if ui.SetBonus.Text ~= "" and ui.SetBonus.Text ~= "No bonus yet" then C.Text else C.Dim
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
	for i, value in ui.SumVerdict or {} do
		value.Text = ui.Verdict[i].Value.Text
	end
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
	local charged, nextIn, _, extra = ChargeMeter.read(outpost and outpost.Picks, outpost and outpost.SurveyAt)
	ui.Pick.Text = ChargeMeter.count(charged, extra)
	ui.PickCap.Text = if nextIn then "FREE PICK  ·  " .. OutpostRules.clock(nextIn) else "FREE PICK  ·  FULL"
end

function InventoryV2.paintRow(slot: string)
	local row = ui.Rows and ui.Rows[slot]
	if not row then
		return
	end
	-- Every card the same dark plate; the piece's rarity is its rail, its
	-- words and the well its art sits in. Gold while its window is open, a
	-- little lighter (edged in its rarity) under the pointer.
	local picked = state.Detail == slot
	local color = row.Color or C.Faint
	row.Rail.BackgroundColor3 = if picked then C.Gold else color
	row.Edge.Color = if picked then C.Gold elseif row.Hovered then color else C.Line
	row.Edge.Transparency = if picked then 0.15 elseif row.Hovered then 0.35 else 0.9
	row.Tint.Color = if picked
		then ColorSequence.new(Color3.fromRGB(46, 38, 22), Color3.fromRGB(20, 16, 11))
		elseif row.Hovered then ColorSequence.new(Color3.fromRGB(34, 37, 52), Color3.fromRGB(18, 20, 30))
		else ColorSequence.new(Color3.fromRGB(25, 27, 39), Color3.fromRGB(13, 14, 22))
	row.Well.BackgroundColor3 = color:Lerp(C.Ink, 0.7)
	row.WellEdge.Color = color
	row.WellEdge.Transparency = if row.Hovered or picked then 0.35 else 0.6
end

local function drawRows(loadout)
	for slot, row in ui.Rows do
		local id = loadout[slot]
		local gear = gearOf(loadout, slot)
		local gem = loadout[slot .. "Gem"]
		local rarity = if gear then rarityOf(loadout, slot) else 1
		local color = if gear then rarityColor(rarity) else C.Faint
		row.Name.Text = if gear then gear.Name else "Nothing worn"
		row.Name.TextColor3 = if gear then color:Lerp(C.Text, 0.35) else C.Faint
		local signature = gear and perkOf(loadout, slot, nil, gem)
		row.Meta.Text = if gear
			then rarityName(rarity) .. (if signature and not COMPACT then "  ·  " .. string.upper(signature.Definition.Name) else "")
			else "EMPTY SLOT"
		row.Meta.TextColor3 = if gear then color else C.Faint
		-- The socket line: the gem in it (with the triad, the move it gives
		-- the key: the sword's is Q, the chest's E, the shield's R), or the ask.
		local rowKey = if triadOn(loadout) then Traits.KeyOfSocket[slot] else nil
		local socketText = nil
		if gem then
			local move = rowKey and Tech.Catalog[Traits.traitFor(gem, rowKey) or ""]
			socketText = if move
				then string.format('<font color="#%s">%s</font>  <font color="#%s">%s</font>', KEY_COLORS[rowKey]:ToHex(), rowKey, gemColor(gem):ToHex(), string.upper(move.Name))
				else string.format('<font color="#%s">%s</font>', gemColor(gem):ToHex(), string.upper(gemName(gem)))
		end
		row.MoveLine.Text = socketText or ""
		row.MoveLine.Visible = socketText ~= nil
		row.Color = color
		row.EmptySocket = gear ~= nil and gem == nil
		row.Enchant.Visible, row.Halo.Visible = row.EmptySocket, row.EmptySocket
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
		-- Its key's surge (the move the gem gives Q, E or R), as on the key cards.
		if row.SurgeTile then
			local triad = triadOn(loadout)
			row.SurgeTile.Visible = triad
			local surgeGem = if triad then Tech.surgeGem(loadout, row.Key) else nil
			local surge = surgeGem and Tech.surgeStats(surgeGem)
			local tint = if surgeGem then gemColor(surgeGem) else C.Faint
			local surgeKey = if surge then surgeGem.Id .. tostring(surgeGem.Surge) .. tostring(surge.Id) else ""
			if row.SurgeKey ~= surgeKey then
				row.SurgeKey = surgeKey
				row.SurgeGlyph.Text = if surge then "◆" else "+"
				row.SurgeGlyph.TextColor3 = if surge then tint else C.Faint
				if surge then
					SurgeIcons.apply(row.SurgeGlyph, surge, tint)
				else
					local old = row.SurgeGlyph:FindFirstChild("AbilityArt")
					if old then
						old:Destroy()
					end
				end
			end
			row.SurgeLine.BackgroundColor3 = tint
			row.SurgeLine.BackgroundTransparency = if surge then 0.1 else 0.7
			row.SurgeEdge.Color = if surge then tint else C.Line
			row.SurgeEdge.Transparency = if surge then 0.45 else 0.6
			row.SurgeBadge.BackgroundTransparency = if surge then 0 else 0.35
		end
		row.Ring.Color = if gem then gemColor(gem) elseif row.EmptySocket then C.Gold else C.Faint
		row.Ring.Transparency = if gem then 0.1 elseif row.EmptySocket then 0.45 else 0.5
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
		entry.Lane.Text = if triad then LANE_WORDS[key] .. (if entry.Fixed then "" else "  ·  " .. string.upper(Traits.SocketNames[key]) .. " GEM") else ""
		entry.Lane.TextColor3 = keyColor
		if not entry.Fixed then
			entry.Name.Position = UDim2.fromOffset(68, if triad then 18 else 14)
			entry.Info.Position = UDim2.fromOffset(68, if triad then 38 else 36)
		end
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
			elseif entry.Fixed then "CLICK OR DROP A GEM"
			else "ADD STONE  ·  CLICK OR DRAG & DROP"
		entry.Line.BackgroundColor3 = tint
		entry.Line.BackgroundTransparency = if gem then 0.15 else 0.7
		entry.Edge.Color = if picked or not gem then C.Gold else C.Line
		entry.Edge.Transparency = if picked then 0.2 elseif not gem then 0.7 else 0.9
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
				then "Pick a spare piece to compare. Drag gems from your bag onto equipment."
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
	ui.Detail.Visible = target ~= nil
	if ui.Modal then
		ui.Modal.Visible = target ~= nil
	end
	if not target then
		return
	end
	paintStrip(loadout)
	local isKey = table.find(KEYS, target) ~= nil
	-- The window's title: the slot and what's in it, or the key and its job.
	if ui.ModalTitle then
		if isKey then
			local gem = Tech.surgeGem(loadout, target)
			local surge = gem and Tech.surgeStats(gem)
			ui.ModalTitle.Text = target .. "  ·  " .. (if surge then surge.Name else "No surge")
			ui.ModalSub.Text = if triadOn(loadout)
				then LANE_WORDS[target] .. "  ·  FROM YOUR " .. string.upper(Traits.SocketNames[target]) .. "'S GEM"
				else "SURGE"
		else
			local gear = gearOf(loadout, target)
			ui.ModalTitle.Text = SLOT_NAME[target] .. "  ·  " .. (if gear then gear.Name else "Nothing worn")
			ui.ModalSub.Text = if gear
				then rarityName(rarityOf(loadout, target)) .. "  ·  SWAP THE PIECE OR ITS GEM"
				else "PICK A SPARE PIECE"
		end
	end
	-- (both show the same two wells: a key's move and its gem, or a piece and
	-- its gem)
	ui.PieceWell.Art.Visible = not isKey
	ui.MoveGlyph.Visible = isKey
	ui.KeyBadge.Visible = isKey
	ui.PerkStats.Visible = true -- (a key: its cost line; a piece: every stat on it)
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
		ui.PerkName.Size = UDim2.fromOffset(RIGHT_W - 36, 14)
		ui.PerkStats.Position = UDim2.fromOffset(128, 182)
		ui.PerkStats.Size = UDim2.fromOffset(RIGHT_W - 146, 14)
		ui.PerkStats.TextColor3 = C.Dim
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
		state.Tab = "Gems"
		drawTabs({ { "Gems", if triadOn(loadout) then string.upper(Traits.SocketNames[target]) .. " GEMS" else "SURGE GEMS" } })
		drawFilters(true)
		local items = {}
		for _, g in gemsFor(true, state.Filter) do
			table.insert(items, { Kind = "Gem", Gem = g })
		end
		drawGrid(items, "No surge gems yet. Cut a gem at the Outpost to unlock its surge.")
	else
		local slot = target
		-- Two tabs: its spare pieces, and the gems that fit its socket (first
		-- when the socket is empty and there's a gem to put in it).
		if state.Tab ~= "Pieces" and state.Tab ~= "Gems" then
			state.Tab = if loadout[slot] and not loadout[slot .. "Gem"] and #gemsFor(false, "All") > 0 then "Gems" else "Pieces"
		end
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
		local roll = GearRolls.get(loadout, slot, viewId)
		local stat = topStat(roll)
		-- Every stat on it (the hover card's list, here for a tap on a phone),
		-- right of the perk's name, which makes room for it.
		local statsText = allStats(roll)
		ui.PerkStats.Text = statsText
		ui.PerkStats.TextColor3 = if tryPiece then C.Gold else C.Good
		-- (the stats take what they need, up to most of the line; the name the rest)
		local need = math.clamp(math.floor(#statsText * ui.PerkStats.TextSize * 0.62) + 10, 60, RIGHT_W - 36 - 90)
		ui.PerkStats.Position = UDim2.fromOffset(RIGHT_W - 18 - need, 182)
		ui.PerkStats.Size = UDim2.fromOffset(need, 14)
		ui.PerkName.Size = UDim2.fromOffset(RIGHT_W - 36 - need - 6, 14)
		ui.PerkName.TextTruncate = Enum.TextTruncate.AtEnd
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
		drawTabs({ { "Pieces", SLOT_NAME[slot] .. " PIECES" }, { "Gems", "GEMS" } })
		drawFilters(state.Tab == "Gems")
		local items = {}
		if state.Tab == "Gems" then
			for _, g in gemsFor(false, state.Filter) do
				table.insert(items, { Kind = "Gem", Gem = g })
			end
			drawGrid(items, "No loose gems that fit. Mine some at the Outpost.")
		elseif state.Tab == "Pieces" then
			for _, spare in sparesFor(slot) do
				table.insert(items, { Kind = "Piece", Slot = slot, Id = spare.Id, Gear = spare.Gear } :: any)
			end
			-- Spare pieces' 3D art comes from the server: ask once per list.
			local askKey = slot .. ":" .. #items
			if #items > 0 and previewAsked ~= askKey then
				previewAsked = askKey
				askPreviews()
			end
			drawGrid(items, "No spare " .. string.lower(SLOT_NAME[slot]) .. " pieces. Mine and trade for more.")
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
		line("CLICK FOR DETAILS  ·  DROP A GEM TO SOCKET", 9, C.Faint, HEADING, 12)
		y += 6
		-- Beside the card (outward of the doll's middle), inside the screen.
		local doll = ui.List
		local rx = doll.Position.X.Offset + row.Position.X.Offset
		local ry = doll.Position.Y.Offset + row.Position.Y.Offset
		local leftColumn = row.Position.X.Offset < DOLL_W / 2
		local top = math.clamp(ry - 8, 70, H - 40 - y)
		card.Position = UDim2.fromOffset(if leftColumn then rx + CARD_W + 14 else rx - TIP_W - 14, top)
		card.Size = UDim2.fromOffset(TIP_W, y)
		card.Visible = true
	end
end

local queued = false
local profileStamp = 0 -- (counts profile changes: AUTO EQUIP's plan is worked out again after one)
local drawIntro -- (below, with the intro card)
local drawSide -- (below)
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

-- Your loose gems, rarest first, a tab per element (full: the left column;
-- compact: the GEMS tab). Each shows its tier level ("T3 II": its surge
-- tier and rank) in its rarity's colour.
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
	ui.PouchCount.Text = if counts.All == 0 then ""
		elseif COMPACT then "DRAG ONTO A SLOT  ·  TAP FOR DETAILS"
		else string.format("%d LOOSE  ·  DRAG ONTO A SLOT", counts.All)
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
			Info.open({ Gem = gem })
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
	ui.BagCount.Text = string.format("%d STORED", total)
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
			Info.open({ Slot = spare.Slot, Id = spare.Id })
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
	if ui.UpdateAutoGlow then ui.UpdateAutoGlow() end
	if ui.UpgradeSurges then
		local count = UpgradeHints.Current.Surges.Changes
		ui.UpgradeSurges.Text = if count > 0 then "UPGRADE SURGES  ↑" else "NO SURGE UPGRADES"
		ui.UpgradeSurges.TextColor3 = if count > 0 then C.Teal else C.Faint
		ui.UpgradeSurges.AutoButtonColor = count > 0
	end
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
		-- (Q, E and R apart: a new ability is worth saying so)
		local abilities = plan.Abilities or 0
		local others = #plan.Gems - abilities
		if abilities > 0 then
			table.insert(parts, if abilities == 1 then "1 ABILITY" else string.format("%d ABILITIES", abilities))
		end
		if others > 0 then
			table.insert(parts, if others == 1 then "1 GEM" else string.format("%d GEMS", others))
		end
		ui.AutoPreview.Text = table.concat(parts, "  ·  ")
		ui.AutoPreview.TextColor3 = if gain > 0 then C.Good elseif gain < 0 then C.Bad else C.Dim
	end
end

-- Compact: the side panel shows one page (STATS, GEMS or GEAR), its tab lit.
function drawSide()
	if not ui.SideTabs then
		return
	end
	for name, tab in ui.SideTabs do
		local on = state.SideTab == name
		tab.Button.TextColor3 = if on then C.Ink else C.Dim
		tab.Button.BackgroundColor3 = if on then C.Gold else C.Ink
		tab.Button.BackgroundTransparency = if on then 0 else 0.3
		tab.Edge.Transparency = if on then 1 else 0.8
	end
	ui.StatsPage.Visible = state.SideTab == "Stats"
	ui.GemsPage.Visible = state.SideTab == "Gems"
	ui.GearPage.Visible = state.SideTab == "Gear"
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
		drawSide()
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
		-- The doll on the left (no header: your name is on the STATS page),
		-- the STATS / GEMS / GEAR panel on the right.
		PANEL_Y, HEAD_H = 52, 0
		BODY_Y = PANEL_Y
		DOLL_X, DOLL_W, DOLL_PAD = 0, 530, 8
		CARD_W, CARD_H = 168, 100
		SIDE_X, SIDE_W = 542, 448
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
	buildHeader(canvas)
	buildDoll(canvas)
	buildTop(canvas)
	buildSummary(canvas)
	buildBags(canvas)
	buildLeft(canvas)
	buildRight(canvas)
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
	if on then
		askPreviews() -- (every piece's art up to date before it's looked at)
	else
		if ui.Intro then
			ui.Intro.Visible = false
		end
		InventoryV2.cancelDrag()
		GemVault.close()
		Wardrobe.close()
		Info.close()
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
UpgradeHints.Changed:Connect(function()
	-- The recommendation is calculated after the profile arrives.
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
	-- A preview arrives, then its parts: once a moment after the last one
	-- lands, everything showing art redraws (the worn slots too).
	local due = false
	store.DescendantAdded:Connect(function()
		if due then
			return
		end
		due = true
		task.delay(0.25, function()
			due = false
			gearChanged()
			if state.Tab == "Pieces" then
				gridKey = ""
				draw()
			end
		end)
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
	if input.KeyCode == Enum.KeyCode.Escape and Info.Window then
		Info.close()
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and state.Active and gui and gui.Enabled and state.Detail then
		openDetail(nil)
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
