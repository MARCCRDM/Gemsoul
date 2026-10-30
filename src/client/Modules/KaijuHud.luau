--[[
	Your mini kaiju on screen (KaijuServer and KaijuWilds run them; see
	docs/kaiju.md). Only in the Outpost.

	  The team strip  your team out, a tile each, the lead first (edged in
	                  gold), then your support (Shared.Kaiju.supportId), a
	                  little apart and edged in green with a plus: its
	                  portrait (the model itself), level, health,
	                  and dots for its Q, E and R, lit when ready (hollow
	                  while asleep); knocked out, DOWN and when it's back by
	                  itself (tap it to revive it now). AUTO HEAL after
	                  them: a Common, how many you have spare, and ON or
	                  OFF; on, your spare Commons heal the team by themselves
	                  (Shared.Kaiju.AutoHeal, KaijuServer). Then the team
	                  keys, 1 to 4 (Shared.Kaiju.Teams): press a number or
	                  tap its chip. The team out's own number calls it back
	                  into its Gemsouls (each tile AWAY) or brings it out
	                  again, fight or no fight (Shared.Kaiju.away); another
	                  team's swaps it in, at once (KaijuServer's
	                  KaijuTeamOut). Tap a
	                  tile for the panel on that kaiju. The team's HYPERBEAM
	                  (KaijuBeamHud, in KaijuHud.beamSlot()): a tile, its rim
	                  its meter; on a computer on the card, its key Z on it,
	                  on a phone a button of its own. Computer: bottom left,
	                  three by two (the kaiju two by two, AUTO HEAL over the
	                  HYPERBEAM). Phone: small, at the top left in a fight too,
	                  two rows (the kaiju in a row, AUTO HEAL a slim row
	                  under them); the team keys off the card, two by two
	                  just above the move stick, under your left thumb,
	                  and the HYPERBEAM just right of them (MobileLayout.kaiju,
	                  keys, beam, kaijuDesk, kaijuCells).
	  TAME            beside the strip (under it on a phone) when a wild
	                  kaiju near you is down to half its health (it glows
	                  gold then: KaijuTaming): the
	                  chance now, and the tries left. It casts the tame
	                  (KaijuTaming's bar), hidden while that's under way.
	  Challenge       a wild kaiju's prompt (hold E beside it): it leaves you
	                  and your kaiju alone till you start on it, here or by
	                  hitting it while you hunt.
	  The panel       every kaiju you have: your team first (all of them
	                  fight; the first leads), then your SUPPORT (it heals
	                  you and the team), then the ones at home, each by its
	                  name (Shared.Kaiju.nameOf) and tagged with its role.
	                  The one picked in full:
	                  its name and RENAME (type a name, SAVE: the server's
	                  KaijuName, Roblox's filter; empty for no name), its kind,
	                  role and level, its enchant's rarity, what it's strong
	                  and weak against, its stats, its moves and when Q and R
	                  wake; and what you can do with it: LEAD (to the front),
	                  SEND OUT (one from home, in place of one of the team you
	                  pick; a support kind can't), SET AS SUPPORT (a support
	                  kind at home, into the support slot), HEAL (REVIVE when
	                  it's down). Its enchant's gem
	                  sits on its portrait.
	  ENCHANT         its enchant (Shared.Kaiju.canSocket: a gem of its own
	                  element only): the one in it at the top (rarity, what it
	                  gives, its gem surge, its stats), then a row for each
	                  rarity of its element, rarest first: the finest of yours
	                  of it, how many you have, what it gives and its surge,
	                  and how that compares with now (a rarity you have none
	                  of, dimmed, and where its element's gems turn up). Pick
	                  one: its stats now and after, then ENCHANT (the old one
	                  back in your pouch). The best upgrade you have is picked
	                  already. Not in a fight.
	  REVIVE          one knocked out: gems don't bring it back. When it's
	                  back by itself (Shared.Kaiju.reviveIn, at half
	                  health), and REVIVE for Robux (the KaijuRevive
	                  product; coins while testing) or COUPON (a Revive
	                  coupon from inviting friends, Shared.Coupons): every
	                  one of yours that's down, back now.
	  HEAL            its health now and after, then your gems in stacks (a
	                  card for each rarity and element, the stone itself, how
	                  many, what each heals: its own element double, its
	                  weakness half; Shared.Kaiju.infusePlan). Opened, your
	                  spare Commons are picked already, as many as bring it
	                  to full (Kaiju.healPick): one tap of HEAL. Tap a card
	                  for one more of it, - for one less; CLEAR, AUTO PICK.
	                  Not while your team out is in a fight (the server's
	                  KaijuDanger: Shared.Kaiju.Danger): IN A FIGHT then.
	  The roll        the starter kaiju are Wren's, at the Kennel (Dialogue
	                  plays KaijuRoll): owed, a word about it once a visit.
	  No nameplates  nothing over a creature's head (yours, others', moon
	                  bugs): its body shows its health, an outline in its
	                  health's colour, a wild kaiju's always and through
	                  rocks (BodyHealth, handed every creature this finds).
	                  A wild kaiju has a slim plate over it too: its name,
	                  level and a health bar (WildBars).

	  KaijuHud.start()     once, from Lobby.client
	  KaijuHud.open(id?, tab?)   the panel, on kaiju `id` (else your lead),
	                       on "Teams", "Details", "Heal" or "Enchant"
	                       (no id and no tab: TEAMS)
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Coupons = require(ReplicatedStorage.Shared.Coupons)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local KaijuRoles = require(ReplicatedStorage.Shared.KaijuRoles)
local KaijuModels = require(ReplicatedStorage.Shared.KaijuModels)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local GemInventory = require(ReplicatedStorage.Shared.GemInventory)
local Spar = require(ReplicatedStorage.Shared.Spar)
local Store = require(ReplicatedStorage.Shared.Store)
local GemArt = require(script.Parent.GemArt)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local KaijuRoll = require(script.Parent.KaijuRoll)
local KaijuTaming = require(script.Parent.KaijuTaming)
local LoadingFlow = require(script.Parent.LoadingFlow)
local LevelUpFx = require(script.Parent.LevelUpFx)
local MobileLayout = require(script.Parent.MobileLayout)
local BodyHealth = require(script.Parent.BodyHealth)
local WildBars = require(script.Parent.WildBars)
local OutpostScene = require(script.Parent.OutpostScene)
local SurgeIcons = require(script.Parent.SurgeIcons)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

local KaijuHud = {}

local INK = Color3.fromRGB(10, 12, 22)
local HEALTH = Color3.fromRGB(96, 214, 120)
local EXP = Color3.fromRGB(176, 132, 255)
local TILE_BACK = Color3.fromRGB(20, 24, 38)
local TAME_RANGE = Kaiju.Tame.Range
-- Its own Q, E and R, and its gem surge (its enchant's E).
local KEYS = { "Q", "E", "R", "Gem" }
-- The support: its slot's colour (a mender's green), and each role's colour
-- for the role tags on the panel's rows.
local SUPPORT = Color3.fromRGB(96, 226, 170)
local ROLE_COLORS = {
	Tank = Color3.fromRGB(120, 172, 236),
	Warrior = Color3.fromRGB(238, 124, 92),
	Ranged = Color3.fromRGB(240, 202, 92),
	Assassin = Color3.fromRGB(192, 126, 242),
	Breaker = Color3.fromRGB(242, 152, 64),
	Warden = SUPPORT,
}
local KEY_EVERY = { Q = Kaiju.QEvery, E = Kaiju.AbilityEvery, R = Kaiju.REvery, Gem = Kaiju.GemSurge.Every }
local CAST_AT = { Q = "KaijuQAt", E = "KaijuAbilityAt", R = "KaijuRAt", Gem = "KaijuGemAt" }

local function elementColor(element: string?): Color3
	return GemConfig.ElementColors[element or ""] or P.Gold
end

local function label(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or P.Text,
		Font = font or IronUi.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

-- A label for a kaiju's name: never translated (Client.Translate skips it),
-- so one named "Ready" stays Ready.
local function nameLabel(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local l = label(nil :: any, text, size, color, font)
	l:SetAttribute("NoTranslate", true)
	l.Parent = parent
	return l
end

local function bar(parent: Instance, color: Color3): (Frame, Frame)
	local back = new("Frame", { BackgroundColor3 = Color3.fromRGB(28, 32, 46) }, parent)
	UiKit.round(back, 3)
	local fill = new("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1) }, back)
	UiKit.round(fill, 3)
	return back, fill
end

local function smallButton(parent: Instance, text: string, color: Color3): TextButton
	local b = new("TextButton", {
		Text = text,
		TextSize = 12,
		Font = IronUi.Heading,
		TextColor3 = P.Text,
		AutoButtonColor = true,
		BackgroundColor3 = color:Lerp(INK, 0.55),
	}, parent)
	UiKit.round(b, 6)
	new("UIStroke", { Color = color, Thickness = 1, Transparency = 0.35 }, b)
	return b
end

local function viewport(parent: Instance, props: { [string]: any }): ViewportFrame
	props.BackgroundColor3 = props.BackgroundColor3 or TILE_BACK
	-- (Lit for a portrait: KaijuModels.Portrait.)
	local look = KaijuModels.Portrait
	props.Ambient, props.LightColor, props.LightDirection = look.Ambient, look.LightColor, look.LightDirection
	return new("ViewportFrame", props, parent)
end

-- Portraits: each kaiju's model is built once per place it's shown (`key`)
-- and kept, so redrawing the panel doesn't rebuild a dozen models.
local built: { [string]: { Look: string, Model: Model } } = {}
local function modelFor(key: string, record): Model
	local look = record.Species .. "/" .. record.Element
	local entry = built[key]
	-- (One destroyed with the frame it was in can't be shown again: Roblox
	-- locks its Parent, so it's built afresh.)
	if entry and entry.Look == look and pcall(function()
		entry.Model.Parent = entry.Model.Parent
	end) then
		return entry.Model
	end
	if entry then
		pcall(entry.Model.Destroy, entry.Model)
	end
	local model = KaijuModels.forPortrait(KaijuModels.build(record.Species, record.Element))
	built[key] = { Look = look, Model = model }
	return model
end

-- A model in a ViewportFrame, framed from the front quarter (the one there
-- before is put aside, not destroyed: it's kept for next time).
local function portrait(frame: ViewportFrame, model: Model?)
	for _, child in frame:GetChildren() do
		if child:IsA("Model") and child ~= model then
			child.Parent = nil
		elseif child:IsA("Camera") then
			child:Destroy()
		end
	end
	if not model then
		return
	end
	model.Parent = frame
	local camera = Instance.new("Camera")
	local cf, size = model:GetBoundingBox()
	local reach = math.max(size.X, size.Y, size.Z)
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(reach * 0.9, reach * 0.35, -reach * 1.25), cf.Position)
	camera.Parent = frame
	frame.CurrentCamera = camera
end

-- The models kept under `prefix` ("row:", "team:") taken out of their
-- frames, so destroying the frames leaves them whole for next time.
local function keepModels(prefix: string)
	for key, entry in built do
		if string.sub(key, 1, #prefix) == prefix then
			pcall(function()
				entry.Model.Parent = nil
			end)
		end
	end
end

local function roster()
	local profile = GemClient.Profile
	return profile and profile.Kaiju
end

-- Your kaiju out in the world, by id.
local function petModels(): { [string]: Model }
	local out = {}
	local folder = workspace:FindFirstChild("Kaiju")
	for _, model in if folder then folder:GetChildren() else {} do
		local id = model:GetAttribute("KaijuId")
		if model:GetAttribute("KaijuOwner") == player.UserId and type(id) == "string" then
			out[id] = model
		end
	end
	return out
end

-- Its health, 0 to 1: the body's while it's out, its kept health at home
-- (it never heals on its own), none while it's down.
local function healthShare(record, model: Model?): number
	if record and record.Down then
		return 0
	end
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
	end
	if not record then
		return 1
	end
	local now, most = Kaiju.health(record)
	return math.clamp(now / math.max(1, most), 0, 1)
end

-- Its record with its health as it is right now: the body's while it's
-- out (the record you're sent catches up only now and then), else kept.
local function liveRecord(record)
	local model = record and not record.Down and petModels()[record.Id]
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return record
	end
	local live = table.clone(record)
	local _, most = Kaiju.health(record)
	live.Health = most * math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
	return live
end

-- "1:05": how long till one knocked out is back by itself (Kaiju.reviveIn).
local function reviveClock(record): string
	local left = math.ceil(Kaiju.reviveIn(record, workspace:GetServerTimeNow()))
	return string.format("%d:%02d", left // 60, left % 60)
end

local function expShare(level: number, exp: number): number
	local need = Kaiju.expToNext(level)
	return if need == math.huge then 1 else math.clamp(exp / need, 0, 1)
end

-- The team strip -------------------------------------------------------------------------------------------

local gui = UiKit.gui("KaijuHud", 6)
gui.Enabled = false

local card = new("Frame", {
	Name = "KaijuCard",
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.12,
	Size = UDim2.fromOffset(300, 62),
}, gui)
UiKit.round(card, 10)
new("UIStroke", { Color = P.Edge, Thickness = 1.2, Transparency = 0.2 }, card)

local tiles = {}
for slot = 1, #Kaiju.SlotLevels + 1 do
	local support = slot == Kaiju.SupportSlot
	local button = new("TextButton", {
		Name = "KaijuTile" .. slot,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = TILE_BACK,
		Visible = false,
	}, card)
	UiKit.round(button, 8)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, button)
	local view = viewport(button, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	-- Its level, top left.
	local levelBack = new("Frame", {
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(30, 13),
		ZIndex = 3,
	}, button)
	UiKit.round(levelBack, 4)
	local level = label(levelBack, "", 9, P.Text, IronUi.Bold)
	level.Size, level.TextXAlignment, level.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 4
	-- Q, E and R down the right edge, and under them its gem surge (a diamond).
	local dots = {}
	for i, key in KEYS do
		local gem = key == "Gem"
		local dot = new("Frame", {
			Name = "Key" .. key,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, if gem then -5 else -4, 0, 4 + (i - 1) * 9 + (if gem then 1 else 0)),
			Size = UDim2.fromOffset(if gem then 6 else 7, if gem then 6 else 7),
			Rotation = if gem then 45 else 0,
			BackgroundColor3 = P.Gold,
			ZIndex = 3,
		}, button)
		UiKit.round(dot, if gem then 1 else 4)
		dots[key] = { Frame = dot, Stroke = new("UIStroke", { Color = P.Gold, Thickness = 1 }, dot) }
	end
	local healthBack, healthFill = bar(button, HEALTH)
	healthBack.AnchorPoint = Vector2.new(0, 1)
	healthBack.Position, healthBack.Size = UDim2.new(0, 4, 1, -4), UDim2.new(1, -8, 0, 4)
	healthBack.ZIndex, healthFill.ZIndex = 3, 3
	-- Its role's symbol above its health, bottom left (RoleIcons: drawn
	-- for whichever kaiju is in the slot, drawTile).
	local roleMark = new("Frame", {
		Name = "RoleMark",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 12, 1, -18),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 4,
	}, button)
	UiKit.round(roleMark, 9)
	-- Knocked out: a veil, DOWN and when it's back by itself.
	local veil = new("Frame", {
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
	}, button)
	UiKit.round(veil, 8)
	local veilText = label(veil, "", 10, P.Bad:Lerp(P.Text, 0.3), IronUi.Bold)
	veilText.Size, veilText.TextXAlignment, veilText.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 6
	local tile = {
		Slot = slot,
		Button = button,
		Edge = edge,
		View = view,
		Level = level,
		Dots = dots,
		HealthFill = healthFill,
		RoleMark = roleMark,
		Role = nil :: string?,
		Veil = veil,
		VeilText = veilText,
		Id = nil :: string?,
		Look = nil :: string?,
	}
	tiles[slot] = tile
	button.Activated:Connect(function()
		local data = roster()
		local record = data and tile.Id and data.List[tile.Id]
		KaijuHud.open(tile.Id, if record and record.Down then "Heal" else nil)
	end)
end

-- AUTO HEAL, at the strip's end: on, your spare Common gems, then your
-- spare Uncommons, heal the team by themselves (Shared.Kaiju.AutoHeal,
-- KaijuServer). It shows the gem it takes next and how many you have
-- spare; a tap switches it.
local autoButton = new("TextButton", {
	Name = "AutoHeal",
	Text = "",
	AutoButtonColor = true,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -5, 0.5, 0),
	Size = UDim2.fromOffset(72, 52),
	BackgroundColor3 = TILE_BACK,
}, card)
UiKit.round(autoButton, 8)
local autoEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, autoButton)
local autoGem = new("Frame", { Name = "Gem", BackgroundTransparency = 1 }, autoButton)
local autoCount = label(autoButton, "", 12, P.Text, IronUi.Bold)
local autoTitle = label(autoButton, "AUTO HEAL", 9, P.Dim, IronUi.Bold)
autoTitle.TextXAlignment = Enum.TextXAlignment.Center
local autoState = label(autoButton, "OFF", 13, P.Dim, Enum.Font.GothamBlack)
autoState.TextXAlignment = Enum.TextXAlignment.Center
local autoWant: boolean? = nil -- (switched here, till the roster says so)
local autoArt: string? = nil

-- The team keys, tabs along the card's top (on a phone, above the move
-- stick: see layout): four chips, 1 to 4 (Kaiju.Teams), the
-- keys that bring each team out. The team out is gold; picked but called
-- back, a gold edge; a team with kaiju in it, plain; one all knocked out, red; an
-- empty one, faint (you fill it on TEAMS: Kaiju.teams). Tap one or press its
-- number: the team out's own calls it back or brings it out again, another
-- team's swaps it in (KaijuServer's KaijuTeamOut), an empty one opens TEAMS.
local teamPad = new("Frame", {
	Name = "Teams",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(72, 52),
}, card)
local teamChips = {}
local pressTeam -- (below: a team's key or its chip)
for n = 1, Kaiju.Teams do
	local chip = new("TextButton", {
		Name = "Team" .. n,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = TILE_BACK,
	}, teamPad)
	UiKit.round(chip, 6)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, chip)
	local number = label(chip, tostring(n), 14, P.Text, Enum.Font.GothamBlack)
	number.Size, number.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	number:SetAttribute("NoTranslate", true)
	-- (On a computer a tab over the card: its number on a key cap, a key
	-- to press, and what the team is doing beside it. See KaijuHud._tabs.shape.)
	local cap = new("Frame", {
		Name = "Cap",
		BackgroundColor3 = Color3.fromRGB(8, 10, 16),
		Size = UDim2.fromOffset(18, 18),
		Visible = false,
		ZIndex = 3,
	}, chip)
	UiKit.round(cap, 4)
	local face = new("Frame", {
		Name = "Face",
		BackgroundColor3 = Color3.fromRGB(58, 66, 88),
		Size = UDim2.new(1, 0, 1, -3),
		ZIndex = 3,
	}, cap)
	UiKit.round(face, 4)
	local word = label(chip, "TEAM", 9, P.Dim, Enum.Font.GothamBlack)
	word.Name, word.Visible, word.ZIndex = "Word", false, 3
	chip.Activated:Connect(function()
		pressTeam(n)
	end)
	teamChips[n] = { Button = chip, Edge = edge, Number = number, Cap = cap, Face = face, Word = word, State = "Empty" }
end
-- The seam where the team out's tab joins the card (a computer's): the
-- card's top edge hidden under it, so tab and card are one.
-- (On the module's table, not a local: its top is at Luau's 200 locals.)
KaijuHud._tabs = { OnTop = false, H = 26, Seam = nil :: Frame?, shape = nil :: any }
KaijuHud._tabs.Seam = new("Frame", {
	Name = "Seam",
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 4,
}, card)

-- The team keys as tabs along the card's top edge (a computer's): each a key
-- cap with its number and a word (OUT, TEAM, AWAY, DOWN, EMPTY); the team out
-- taller, in the card's own colour and outlined in gold, merged into the
-- card. On a phone they stay chips (drawTeams colours them).
function KaijuHud._tabs.shape()
	local tabs = KaijuHud._tabs
	local seam = tabs.Seam :: Frame
	local tabsOnTop, TAB_H = tabs.OnTop, tabs.H
	seam.Visible = false
	for n, chip in teamChips do
		chip.Cap.Visible, chip.Word.Visible = tabsOnTop, tabsOnTop
		chip.Number.Parent = if tabsOnTop then chip.Face else chip.Button
	end
	if not tabsOnTop then
		return
	end
	local width = teamPad.Size.X.Offset
	local gap = 4
	local w = math.floor((width - gap * (Kaiju.Teams - 1)) / Kaiju.Teams)
	for n, chip in teamChips do
		local out = chip.State == "Out"
		local h = if out then TAB_H + 1 else TAB_H - 4
		local x = (n - 1) * (w + gap)
		local button = chip.Button
		button.Position = UDim2.fromOffset(x, TAB_H - h)
		button.Size = UDim2.fromOffset(w, h + (if out then 0 else 0))
		-- (the team out: the card's own colour and a gold outline)
		if out then
			button.BackgroundColor3, button.BackgroundTransparency = INK, 0.12
			chip.Edge.Color, chip.Edge.Transparency, chip.Edge.Thickness = P.Gold, 0, 1.5
			seam.Visible = true
			seam.Position = UDim2.fromOffset(x + 1, -2)
			seam.Size = UDim2.fromOffset(w - 2, 5)
		end
		local cap = chip.Cap
		cap.AnchorPoint = Vector2.new(0, 0.5)
		cap.Position = UDim2.new(0, 6, 0.5, if out then -1 else 0)
		local face = chip.Face
		face.BackgroundColor3 = if out then P.Gold elseif chip.State == "Away" then P.Gold:Lerp(TILE_BACK, 0.55) else Color3.fromRGB(58, 66, 88)
		chip.Number.Size = UDim2.fromScale(1, 1)
		chip.Number.TextSize = 12
		chip.Number.TextColor3 = if out then INK elseif chip.State == "Empty" then P.Dim else P.Text
		chip.Number.TextTransparency = 0
		local word = chip.Word
		word.AnchorPoint = Vector2.new(0, 0.5)
		word.Position = UDim2.new(0, 28, 0.5, if out then -1 else 0)
		word.Size = UDim2.new(1, -30, 0, 12)
		word.TextSize = if out then 10 else 9
		word.Text = ({ Out = "OUT", Away = "AWAY", Down = "DOWN", Empty = "EMPTY", Ready = "TEAM" })[chip.State] or "TEAM"
		word.TextColor3 = if out or chip.State == "Away" then P.Gold
			elseif chip.State == "Down" then P.Bad:Lerp(P.Text, 0.3)
			elseif chip.State == "Empty" then P.Dim
			else P.Text
		word.TextTransparency = if chip.State == "Empty" then 0.35 else 0
	end
end

-- The team's HYPERBEAM, a tile with its meter round it (KaijuBeamHud draws
-- it in here: KaijuHud.beamSlot()): on a computer on the card, under AUTO
-- HEAL; on a phone off the card, a button of its own right of the team
-- keys.
local beamSlot = new("Frame", {
	Name = "BeamSlot",
	BackgroundTransparency = 1,
	ZIndex = 10, -- (over the card's own tiles)
}, card)

-- CATCH: beside the strip, when there's a wild kaiju to catch. A slim
-- pill: a gold disc (the key on a computer, a target on a touch screen),
-- CATCH and the chance on top, its name and the tries left under them.
local tame = new("TextButton", {
	Name = "Tame",
	Text = "",
	AutoButtonColor = true,
	BackgroundColor3 = Color3.fromRGB(16, 18, 28),
	BackgroundTransparency = 0.08,
	Size = UDim2.fromOffset(210, 42),
	Visible = false,
}, gui)
UiKit.round(tame, 21)
local catchStroke = new("UIStroke", { Color = P.Gold, Thickness = 1.5 }, tame)
do
	-- (The disc: gold, with the key in it, or a target's ring and dot.)
	local disc = new("Frame", {
		Name = "Disc",
		BackgroundColor3 = P.Gold,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.fromOffset(32, 32),
	}, tame)
	UiKit.round(disc, 16)
	local key = label(disc, "C", 16, Color3.fromRGB(28, 22, 8), Enum.Font.GothamBlack)
	key.Name, key.Size, key.TextXAlignment = "Key", UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	local ring = new("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Visible = false,
	}, disc)
	UiKit.round(ring, 99)
	new("UIStroke", { Color = Color3.fromRGB(28, 22, 8), Thickness = 2 }, ring)
	local dot = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 22, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
	}, ring)
	UiKit.round(dot, 99)
end
local tameTitle = label(tame, "CATCH", 13, P.Gold, Enum.Font.GothamBlack)
local tameOdds = label(tame, "", 13, P.Text, Enum.Font.GothamBlack)
tameOdds.TextXAlignment = Enum.TextXAlignment.Right
local tameTries = label(tame, "", 10, P.Dim, IronUi.Body)
tameTries.TextXAlignment = Enum.TextXAlignment.Right
local catchName = nameLabel(tame, "", 11, P.Text, IronUi.Bold)

-- Where the card and TAME go: see the header.
local function layout()
	local screen = gui.AbsoluteSize
	if screen.X <= 0 then
		return
	end
	local function place(frame: GuiObject, rect)
		frame.AnchorPoint = Vector2.zero
		frame.Position = UDim2.fromOffset(rect.X, rect.Y)
		frame.Size = UDim2.fromOffset(rect.W, rect.H)
	end
	local phone = UiKit.short()
	local hunting = Spar.hunting(player)
	-- One card (MobileLayout.kaiju, kaijuDesk, kaijuCells): on a computer
	-- the kaiju two by two, AUTO HEAL over the HYPERBEAM; on a phone small,
	-- the kaiju in a row over AUTO HEAL, the team keys and the HYPERBEAM
	-- apart.
	local spot = if phone then MobileLayout.kaiju(screen, hunting) else MobileLayout.kaijuDesk(screen)
	card.Position = UDim2.fromOffset(spot.X, spot.Y)
	card.Size = UDim2.fromOffset(spot.W, spot.H)
	-- (On a phone the card's own back is see-through, the world showing
	-- round the tiles; the tiles and AUTO HEAL keep theirs.)
	card.BackgroundTransparency = if phone then MobileLayout.Kaiju.Back else 0.12
	local cells = MobileLayout.kaijuCells(spot)
	for slot, tile in tiles do
		local rect = if slot == Kaiju.SupportSlot then cells.Support else cells.Fighters[slot]
		if rect then
			place(tile.Button, rect)
			-- (its role's mark: on a phone's small tile smaller and just above
			-- its health, clear of its level)
			local mark = math.clamp(math.floor(rect.H * 0.34), 12, 18)
			tile.RoleMark.Size = UDim2.fromOffset(mark, mark)
			tile.RoleMark.Position = if rect.H < 46 then UDim2.new(0, 10, 1, -9 - mark / 2) else UDim2.new(0, 12, 1, -18)
			-- Q, E, R and its gem surge down the right edge, spaced to fit
			-- (not on a phone: too small to read there; the panel has them).
			local step = math.clamp(math.floor((rect.H - 12) / 4), 5, 9)
			for i, key in KEYS do
				local gem = key == "Gem"
				local size = math.min(if gem then 6 else 7, step - 1)
				local dot = tile.Dots[key].Frame
				dot.Visible = not phone
				dot.Size = UDim2.fromOffset(size, size)
				dot.Position = UDim2.new(1, if gem then -5 else -4, 0, 3 + (i - 1) * step + (if gem then 1 else 0))
			end
		end
	end
	-- The four team keys: on a computer tabs along the card's top edge, the
	-- team out's merged into it (_tabs.shape); on a phone two by two off the
	-- card, just above the move stick, under your left thumb
	-- (MobileLayout.keys).
	KaijuHud._tabs.OnTop = not phone
	place(autoButton, cells.Auto)
	if phone then
		local keys = MobileLayout.keys(screen)
		local gap, across, rect = keys.Gap, keys.Across, keys
		teamPad.Parent = gui
		place(teamPad, rect)
		local down = math.ceil(Kaiju.Teams / across)
		local w = math.floor((rect.W - gap * (across - 1)) / across)
		local h = math.floor((rect.H - gap * (down - 1)) / down)
		for n, chip in teamChips do
			local col, row = (n - 1) % across, (n - 1) // across
			chip.Button.Position = UDim2.fromOffset(col * (w + gap), row * (h + gap))
			chip.Button.Size = UDim2.fromOffset(w, h)
			chip.Number.TextSize = math.clamp(math.floor(math.min(w, h) * 0.55), 10, 18)
		end
	else
		teamPad.Parent = card
		place(teamPad, { X = 0, Y = -KaijuHud._tabs.H, W = spot.W, H = KaijuHud._tabs.H })
	end
	KaijuHud._tabs.shape()
	-- The HYPERBEAM: on a computer on the card, under AUTO HEAL; on a phone
	-- off the card, just right of the team keys (MobileLayout.beam).
	if phone then
		beamSlot.Parent = gui
		place(beamSlot, MobileLayout.beam(screen))
	else
		beamSlot.Parent = card
		place(beamSlot, cells.Beam)
	end
	-- CATCH: a readable, non-modal prompt, under the card on touch, above
	-- the combat HUD at center on a computer.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touch then
		local at = MobileLayout.kaiju(screen, hunting)
		tame.Size = UDim2.fromOffset(at.TameW, at.TameH)
		tame.Position = UDim2.fromOffset(at.TameX, at.TameY)
	else
		tame.Size = UDim2.fromOffset(210, 42)
		tame.Position = UDim2.fromOffset(math.floor((screen.X - 210) / 2), math.max(12, screen.Y - 196))
	end
	do
		-- (Inside: the disc, then two rows: CATCH and the chance, its name
		-- and the tries left.)
		local h = tame.Size.Y.Offset
		local d = h - 10
		local disc = tame:FindFirstChild("Disc") :: Frame
		disc.Size = UDim2.fromOffset(d, d)
		disc.Key.Visible, disc.Ring.Visible = not touch, touch
		disc.Key.TextSize = math.floor(d * 0.5)
		local x0, right = d + 13, 14
		local top = math.floor((h - 26) / 2)
		tameTitle.Position, tameTitle.Size = UDim2.fromOffset(x0, top), UDim2.new(0, 60, 0, 14)
		tameOdds.Position, tameOdds.Size = UDim2.new(1, -right - 50, 0, top), UDim2.fromOffset(50, 14)
		catchName.Position, catchName.Size = UDim2.fromOffset(x0, top + 14), UDim2.new(1, -x0 - right - 50, 0, 12)
		tameTries.Position, tameTries.Size = UDim2.new(1, -right - 50, 0, top + 14), UDim2.fromOffset(50, 12)
	end
	-- AUTO HEAL: a Common and how many you have spare, then its name, ON or
	-- OFF (on a short cell two lines: the gem, then AUTO ON; on a phone's
	-- slim row across the card, one line: the gem and how many on the left,
	-- AUTO HEAL in the middle, ON or OFF on the right).
	local th = cells.Auto.H
	local slim = th < 30
	local small = th < 46
	-- (Compact: no room for its name, so the state says AUTO ON itself.)
	card:SetAttribute("Compact", small and not slim)
	if slim then
		local gemSize = th - 6
		autoTitle.Visible = true
		autoGem.Position, autoGem.Size = UDim2.fromOffset(5, 3), UDim2.fromOffset(gemSize, gemSize)
		autoCount.Position, autoCount.Size = UDim2.fromOffset(8 + gemSize, 0), UDim2.new(0, 40, 1, 0)
		autoCount.TextSize = 10
		autoTitle.Position, autoTitle.Size, autoTitle.TextSize = UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), 9
		autoState.Position, autoState.Size = UDim2.new(1, -40, 0, 0), UDim2.new(0, 36, 1, 0)
		autoState.TextSize = 10
		autoState.TextXAlignment = Enum.TextXAlignment.Right
		return
	end
	autoState.TextXAlignment = Enum.TextXAlignment.Center
	autoTitle.Visible = not small
	local gemSize, gemY = if small then 13 else 16, 4
	autoGem.Position, autoGem.Size = UDim2.fromOffset(5, gemY), UDim2.fromOffset(gemSize, gemSize)
	autoCount.Position, autoCount.Size = UDim2.fromOffset(8 + gemSize, gemY), UDim2.new(1, -12 - gemSize, 0, gemSize)
	autoCount.TextSize = if small then 10 else 12
	autoTitle.Position = UDim2.fromOffset(0, gemY + gemSize + 1)
	autoTitle.Size, autoTitle.TextSize = UDim2.new(1, 0, 0, if small then 9 else 11), if small then 7 else 9
	local stateH = if small then 12 else 14
	autoState.Position = UDim2.new(0, 0, 1, -(if small then 3 else 1) - stateH)
	autoState.Size, autoState.TextSize = UDim2.new(1, 0, 0, stateH), if small then 10 else 13
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
MobileLayout.onParty(layout) -- (CATCH keeps short of your loot card, under your teammates' rows)
player:GetAttributeChangedSignal("Hunt"):Connect(layout)

-- Your spare Commons, then Uncommons (what AUTO HEAL uses, in that order:
-- Kaiju.autoHealPick): loose, never one a saved loadout names, never a
-- Gemsoul.
local spareCommons = {}
local function countCommons()
	local list = {}
	for _, tier in Kaiju.AutoHeal.Tiers do
		for _, gem in GemInventory.spare(GemClient.Profile, tier) do
			if not Kaiju.isSoul(gem) then
				table.insert(list, gem)
			end
		end
	end
	spareCommons = list
end

-- AUTO HEAL as it stands: ON (green) or OFF, and the gem it takes next (a
-- Common of the lead's element, those heal it double; an Uncommon once
-- the Commons are gone) with how many you have spare.
local function drawAuto(lead)
	local on = Kaiju.autoHealOn(roster())
	if autoWant ~= nil and autoWant ~= on then
		on = autoWant
	else
		autoWant = nil
	end
	autoButton.BackgroundColor3 = if on then P.Good:Lerp(INK, 0.72) else TILE_BACK
	autoEdge.Color = if on then P.Good else P.Edge
	autoState.Text = (if card:GetAttribute("Compact") then "AUTO " else "") .. (if on then "ON" else "OFF")
	autoState.TextColor3 = if on then P.Good else P.Dim
	autoTitle.TextColor3 = if on then P.Text else P.Dim
	autoCount.Text = "×" .. #spareCommons
	autoCount.TextColor3 = if #spareCommons > 0 then P.Text else P.Bad:Lerp(P.Text, 0.3)
	local element = (lead and lead.Element) or "Fire"
	local sample = nil
	local first = spareCommons[1] and spareCommons[1].Tier
	for _, gem in spareCommons do
		if gem.Element == element and gem.Tier == first then
			sample = gem
			break
		end
	end
	sample = sample
		or spareCommons[1]
		or {
			Id = "AutoHeal" .. element,
			Element = element,
			Tier = Kaiju.AutoHeal.Tiers[1],
			Size = 6,
			Clarity = 6,
			Cut = 5,
		}
	if autoArt ~= sample.Id then
		autoArt = sample.Id
		for _, child in autoGem:GetChildren() do
			child:Destroy()
		end
		pcall(GemArt.viewport, autoGem, sample, false)
	end
end

-- The team chips as they stand (see teamPad).
local function drawTeams()
	local data = roster()
	local out, away = Kaiju.outTeam(data), Kaiju.away(data)
	for n, chip in teamChips do
		local ids = Kaiju.teamOf(data, n)
		local standing = 0
		for _, id in ids do
			if not data.List[id].Down then
				standing += 1
			end
		end
		local filled = #ids > 0
		local back, edge, text = TILE_BACK, P.Edge, P.Text
		if filled and n == out and not away then
			back, edge, text = P.Gold, P.Gold, INK
		elseif filled and n == out then
			edge, text = P.Gold, P.Gold
		elseif filled and standing == 0 then
			edge, text = P.Bad:Lerp(P.Edge, 0.5), P.Bad:Lerp(P.Text, 0.3)
		elseif not filled then
			text = P.Dim
		end
		chip.Button.BackgroundColor3 = back
		chip.Button.BackgroundTransparency = if filled then 0 else 0.55
		chip.Button.AutoButtonColor = filled
		chip.Edge.Color, chip.Edge.Transparency = edge, if filled then 0 else 0.55
		chip.Number.TextColor3, chip.Number.TextTransparency = text, if filled then 0 else 0.45
		chip.State = if not filled then "Empty"
			elseif n == out and not away then "Out"
			elseif n == out then "Away"
			elseif standing == 0 then "Down"
			else "Ready"
		-- (as a tab, not the team out: dark, set back from the card)
		if KaijuHud._tabs.OnTop and chip.State ~= "Out" then
			chip.Button.BackgroundColor3 = TILE_BACK
			chip.Button.BackgroundTransparency = if filled then 0.15 else 0.45
			chip.Edge.Color = if chip.State == "Away" then P.Gold else edge
			chip.Edge.Transparency = if filled then 0.2 else 0.6
		end
	end
	KaijuHud._tabs.shape()
end

local function drawTile(tile, record, model: Model?, lead: boolean)
	tile.Id = record.Id
	local color = elementColor(record.Element)
	local look = record.Id .. "/" .. record.Species .. "/" .. record.Element
	if tile.Look ~= look then
		tile.Look = look
		portrait(tile.View, modelFor("hud:" .. tile.Slot, record))
	end
	local support = tile.Slot == Kaiju.SupportSlot
	local roleId = KaijuRoles.of(record.Species)
	if tile.Role ~= roleId then
		tile.Role = roleId
		local RoleIcons = require(script.Parent.RoleIcons) -- (here: the module's top is at Luau's 200 locals)
		tile.RoleMark:ClearAllChildren()
		UiKit.round(tile.RoleMark, 9)
		local icon = RoleIcons.draw(tile.RoleMark, roleId, 12, ROLE_COLORS[roleId] or P.Dim, 5)
		icon.AnchorPoint, icon.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		tile.RoleMark.Visible = RoleIcons.has(roleId)
	end
	tile.Edge.Color = if lead then P.Gold elseif support then SUPPORT else color:Lerp(P.Edge, 0.35)
	tile.Edge.Thickness = if lead or support then 2 else 1.5
	local level = (model and model:GetAttribute("KaijuLevel")) or record.Level
	tile.Level.Text = string.format("Lv %d", level)
	local share = healthShare(record, model)
	tile.HealthFill.Size = UDim2.fromScale(share, 1)
	tile.HealthFill.BackgroundColor3 = if share < 0.3 then P.Bad else HEALTH
	-- Q, E, R and its gem surge: lit when ready, faint while recharging,
	-- hollow asleep (skipped where they're hidden: a phone).
	local now = workspace:GetServerTimeNow()
	for key, dot in if tile.Dots.Q.Frame.Visible then tile.Dots else {} do
		local awake = if key ~= "Gem"
			then select(2, Kaiju.kitMove(record.Species, key, level))
			elseif Kaiju.isSupport(record.Species) then Kaiju.supportGuard(record) ~= nil
			else Kaiju.gemSurge(record.Soul) ~= nil
		local at = model and model:GetAttribute(CAST_AT[key])
		local ready = awake and model ~= nil and (type(at) ~= "number" or now - at >= KEY_EVERY[key])
		dot.Frame.BackgroundColor3, dot.Stroke.Color = color, color
		dot.Frame.BackgroundTransparency = if ready then 0 elseif awake then 0.65 else 1
		dot.Stroke.Transparency = if awake then 0 else 0.45
	end
	local away = Kaiju.away(roster())
	tile.Veil.Visible = record.Down == true or away
	if record.Down then
		tile.VeilText.Text = "DOWN " .. reviveClock(record)
		tile.VeilText.TextColor3 = P.Bad:Lerp(P.Text, 0.3)
	elseif away then
		tile.VeilText.Text = "AWAY"
		tile.VeilText.TextColor3 = P.Dim
	end
end

-- The panel -------------------------------------------------------------------------------------------------------

-- (On a phone on its side, a window of its own, drawn near full size: the
-- one picked scrolls, and HEAL's gems take the width.)
local SHORT = UiKit.short()
local W, H = if SHORT then 860 else 800, if SHORT then 340 else 512
local window = IronUi.window("KaijuPanel", 11, W, H, "K", P.Gold)
window.Title.Text = "YOUR KAIJU"
window.Subtitle.Text = "Arrange your teams, then look after each kaiju: details, healing, enchants."
window.Close.Activated:Connect(function()
	window.Gui.Enabled = false
end)
window.Shade.Activated:Connect(function()
	window.Gui.Enabled = false
end)

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(if SHORT then 12 else 20, if SHORT then 70 else 78),
	Size = UDim2.new(1, if SHORT then -24 else -40, 1, if SHORT then -78 else -96),
}, window.Panel)

-- Left: every kaiju you have, your team first.
local LIST_W = if SHORT then 214 else 256
local listFrame = new("ScrollingFrame", {
	Name = "KaijuList",
	BackgroundTransparency = 1,
	Size = UDim2.new(0, LIST_W, 1, 0),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, body)
UiKit.list(listFrame, 6)

-- Right: the one picked, or healing it.
local right = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(LIST_W + 14, 0),
	Size = UDim2.new(1, -(LIST_W + 14), 1, 0),
}, body)
local tabRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) }, right)
UiKit.list(tabRow, 8, true)

local DETAIL_H = 410 -- (on a phone: the height of what scrolls)
local detail = new(if SHORT then "ScrollingFrame" else "Frame", {
	Name = "Detail",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
}, right)
if SHORT then
	detail.CanvasSize = UDim2.fromOffset(0, DETAIL_H)
	detail.ScrollBarThickness = 4
	detail.ScrollingDirection = Enum.ScrollingDirection.Y
end
local HERO = 184
local heroView = viewport(detail, { Size = UDim2.fromOffset(168, HERO) })
UiKit.round(heroView, 10)
local heroEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.2 }, heroView)
local heroGlow = new("UIGradient", { Rotation = 90 }, heroView)
-- Its enchant (the gem it lives in), on the portrait's corner, edged in its rarity.
local soulBadge = new("Frame", {
	Name = "Enchant",
	Position = UDim2.fromOffset(168 - 58, HERO - 58),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.15,
	ZIndex = 3,
}, detail)
UiKit.round(soulBadge, 26)
local soulEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, soulBadge)
local soulArt: string? = nil
local info = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(180, 0),
	Size = UDim2.new(1, -180, 0, HERO),
}, detail)
-- Its name, and RENAME beside it (the box and SAVE / CANCEL while you
-- type: heroUi).
local heroName = nameLabel(info, "", 20, P.Text, Enum.Font.GothamBlack)
heroName.Size = UDim2.new(1, -96, 0, 24)
UiKit.fit(heroName)
local heroUi: { [string]: any } = { Editing = false }
heroUi.Rename = smallButton(info, "RENAME", P.Teal)
heroUi.Rename.Name = "Rename"
heroUi.Rename.AnchorPoint = Vector2.new(1, 0)
heroUi.Rename.Position, heroUi.Rename.Size = UDim2.new(1, 0, 0, 1), UDim2.fromOffset(88, 22)
heroUi.Rename.TextSize = 11
heroUi.Box = new("TextBox", {
	Name = "NameBox",
	Visible = false,
	Text = "",
	PlaceholderText = string.format("Name it (up to %d letters)", Kaiju.NameMax),
	PlaceholderColor3 = P.Dim,
	ClearTextOnFocus = false,
	TextSize = 15,
	Font = IronUi.Bold,
	TextColor3 = P.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundColor3 = P.Inset,
	Size = UDim2.new(1, -142, 0, 24),
}, info)
UiKit.round(heroUi.Box, 6)
new("UIStroke", { Color = P.Teal, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, heroUi.Box)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, heroUi.Box)
heroUi.Save = smallButton(info, "SAVE", P.Good)
heroUi.Save.Name = "SaveName"
heroUi.Save.AnchorPoint, heroUi.Save.Visible = Vector2.new(1, 0), false
heroUi.Save.Position, heroUi.Save.Size = UDim2.new(1, -68, 0, 1), UDim2.fromOffset(64, 22)
heroUi.Save.TextSize = 11
heroUi.Cancel = smallButton(info, "CANCEL", P.Edge)
heroUi.Cancel.Name = "CancelName"
heroUi.Cancel.AnchorPoint, heroUi.Cancel.Visible = Vector2.new(1, 0), false
heroUi.Cancel.Position, heroUi.Cancel.Size = UDim2.new(1, 0, 0, 1), UDim2.fromOffset(64, 22)
heroUi.Cancel.TextSize = 11
local heroTag = label(info, "", 11, P.Dim, IronUi.Bold)
heroTag.Position, heroTag.Size = UDim2.fromOffset(0, 27), UDim2.new(1, 0, 0, 14)
-- Its enchant's rarity (as wide as it says).
local pill = new("Frame", {
	Position = UDim2.fromOffset(0, 46),
	Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = INK,
}, info)
UiKit.round(pill, 10)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, pill)
local pillEdge = new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.2 }, pill)
local pillText = label(pill, "", 10, P.Text, Enum.Font.GothamBlack)
pillText.Size, pillText.AutomaticSize = UDim2.new(0, 0, 1, 0), Enum.AutomaticSize.X
pillText.TextTruncate = Enum.TextTruncate.None
-- What it's strong and weak against (Shared.ElementMatchup), a pill each
-- in that element's colour.
heroUi.Matchup = new("Frame", {
	Name = "Matchup",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 70),
	Size = UDim2.new(1, 0, 0, 16),
}, info)
UiKit.list(heroUi.Matchup, 6, true)
heroUi.Beats = require(ReplicatedStorage.Shared.ElementMatchup).Beats
for order, key in { "Strong", "Weak" } do
	local chip = new("Frame", {
		Name = key,
		LayoutOrder = order,
		BackgroundColor3 = INK,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
	}, heroUi.Matchup)
	UiKit.round(chip, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, chip)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.4 }, chip)
	local text = label(chip, "", 9, P.Text, Enum.Font.GothamBlack)
	text.Size, text.AutomaticSize = UDim2.new(0, 0, 1, 0), Enum.AutomaticSize.X
	text.TextTruncate = Enum.TextTruncate.None
	heroUi[key] = { Chip = chip, Edge = edge, Text = text }
end
-- Its traits (Shared Kaiju.traits): what makes it unlike any other of its
-- kind and level. Its Grade, then each of the four, coloured by how good.
-- (Grade chips: S gold, A violet, B blue, C grey; a poor trait's red. On
-- heroUi: this file is out of room for top-level locals.)
heroUi.TraitColors = {
	Low = Color3.fromRGB(240, 120, 110),
	S = Color3.fromRGB(255, 204, 92),
	A = Color3.fromRGB(200, 150, 255),
	B = Color3.fromRGB(120, 190, 255),
	C = Color3.fromRGB(170, 170, 178),
}
heroUi.Traits = new("Frame", {
	Name = "Traits",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 89),
	Size = UDim2.new(1, 0, 0, 16),
}, info)
UiKit.list(heroUi.Traits, 4, true)
heroUi.TraitChips = {}
for order, key in { "Grade", table.unpack(Kaiju.Traits.Names) } do
	local chip = new("Frame", {
		Name = key,
		LayoutOrder = order,
		BackgroundColor3 = if key == "Grade" then P.Gold else P.Inset,
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
	}, heroUi.Traits)
	UiKit.round(chip, 5)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, chip)
	local text = label(chip, "", 9, if key == "Grade" then INK else P.Text, Enum.Font.GothamBlack)
	text.Size, text.AutomaticSize = UDim2.new(0, 0, 1, 0), Enum.AutomaticSize.X
	text.TextTruncate = Enum.TextTruncate.None
	heroUi.TraitChips[key] = { Chip = chip, Text = text }
end
local heroBlurb = label(info, "", 10, P.Dim, IronUi.Body)
heroBlurb.Position, heroBlurb.Size = UDim2.fromOffset(0, 107), UDim2.new(1, 0, 0, 12)
heroBlurb.TextTruncate = Enum.TextTruncate.AtEnd
heroBlurb.TextYAlignment = Enum.TextYAlignment.Top
-- Health, damage, speed.
local statRow = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 120),
	Size = UDim2.new(1, 0, 0, 40),
}, info)
UiKit.list(statRow, 8, true)
local statValues = {}
for order, name in { "HEALTH", "DAMAGE", "SPEED" } do
	local chip = new("Frame", {
		LayoutOrder = order,
		BackgroundColor3 = P.Inset,
		Size = UDim2.new(1 / 3, -6, 1, 0),
	}, statRow)
	UiKit.round(chip, 8)
	local value = label(chip, "", 16, P.Text, Enum.Font.GothamBlack)
	value.Position, value.Size = UDim2.fromOffset(10, 3), UDim2.new(1, -16, 0, 20)
	local word = label(chip, name, 9, P.Dim, IronUi.Bold)
	word.Position, word.Size = UDim2.fromOffset(10, 23), UDim2.new(1, -16, 0, 12)
	statValues[order] = value
end
local expText = label(info, "", 11, P.Dim, IronUi.Bold)
expText.Position, expText.Size = UDim2.fromOffset(0, 164), UDim2.new(1, 0, 0, 12)
local expBack, expFill = bar(info, EXP)
expBack.Position, expBack.Size = UDim2.fromOffset(0, 178), UDim2.new(1, 0, 0, 6)

-- Its moves: its kind's own (E from the start, Q and R as it levels), and
-- its gem surge, its enchant's E.
local ROW_H = 32
local moveBox = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, HERO + 10),
	Size = UDim2.new(1, 0, 0, 4 * ROW_H + 3 * 4),
}, detail)
UiKit.list(moveBox, 4)
local moveRows = {}
for order, key in { "E", "Q", "R", "Gem" } do
	local row = new("Frame", {
		Name = "Move" .. key,
		LayoutOrder = order,
		BackgroundColor3 = P.Inset,
		Size = UDim2.new(1, 0, 0, ROW_H),
	}, moveBox)
	UiKit.round(row, 8)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.6 }, row)
	local chip = new("Frame", {
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = P.Gold,
	}, row)
	UiKit.round(chip, 6)
	local chipEdge = new("UIStroke", { Color = P.Dim, Thickness = 1, Transparency = 1 }, chip)
	local mark = if key == "Gem" then "G" else key
	local letter = label(chip, mark, 13, INK, Enum.Font.GothamBlack)
	letter.Size, letter.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	-- (Over the move's icon, when it has one: its key on the corner.)
	local badge = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 3, 1, 3),
		Size = UDim2.fromOffset(13, 13),
		BackgroundColor3 = P.Gold,
		Visible = false,
		ZIndex = 3,
	}, chip)
	UiKit.round(badge, 4)
	local badgeLetter = label(badge, mark, 9, INK, Enum.Font.GothamBlack)
	badgeLetter.Size, badgeLetter.TextXAlignment, badgeLetter.ZIndex =
		UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 4
	local name = label(row, "", 13, P.Text, IronUi.Bold)
	name.Position, name.Size = UDim2.fromOffset(38, 2), UDim2.new(1, -170, 0, 16)
	local about = label(row, "", 10, P.Dim, IronUi.Body)
	about.Position, about.Size = UDim2.fromOffset(38, 18), UDim2.new(1, -170, 0, 13)
	-- (Wide enough for DESCARGA DE GEMA.)
	local state = label(row, "", 10, P.Good, Enum.Font.GothamBlack)
	state.AnchorPoint, state.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	state.Position, state.Size = UDim2.new(1, -10, 0, 0), UDim2.new(0, 126, 1, 0)
	moveRows[key] = {
		Frame = row,
		Edge = edge,
		Chip = chip,
		ChipEdge = chipEdge,
		Letter = letter,
		Badge = badge,
		BadgeLetter = badgeLetter,
		Name = name,
		About = about,
		State = state,
	}
end

-- What you can do with it.
local actionBar = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 40),
}, detail)
if SHORT then
	-- (At the foot of what scrolls.)
	actionBar.AnchorPoint, actionBar.Position = Vector2.zero, UDim2.fromOffset(0, DETAIL_H - 40)
end
local actionText = label(actionBar, "", 11, P.Dim, IronUi.Body)
actionText.Size = UDim2.new(1, 0, 1, 0)
actionText.TextWrapped = true
local actionButtons = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.fromScale(1, 1),
}, actionBar)
local actionList = UiKit.list(actionButtons, 6, true)
actionList.HorizontalAlignment = Enum.HorizontalAlignment.Right

-- Healing the one picked: gems from your pouch heal it, or bring it back
-- when it's down. Its health now and after at the top, your gems in stacks
-- below, HEAL at the bottom.
local healPane = new("Frame", {
	Name = "Heal",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	Visible = false,
}, right)
local HEAD_H = if SHORT then 46 else 58
local healHead = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, 0, 0, HEAD_H) }, healPane)
UiKit.round(healHead, 10)
local healName = label(healHead, "", 14, P.Text, IronUi.Bold)
healName.Position, healName.Size = UDim2.fromOffset(12, if SHORT then 4 else 7), UDim2.new(1, -184, 0, 18)
local healNumbers = label(healHead, "", 12, P.Text, IronUi.Bold)
healNumbers.AnchorPoint, healNumbers.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
healNumbers.Position, healNumbers.Size = UDim2.new(1, -12, 0, if SHORT then 4 else 7), UDim2.fromOffset(170, 18)
local healBack = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(28, 32, 46),
	Position = UDim2.fromOffset(12, if SHORT then 25 else 32),
	Size = UDim2.new(1, -24, 0, if SHORT then 14 else 16),
}, healHead)
UiKit.round(healBack, 8)
-- (After the heal, lighter, under its health now.)
local healAfter = new("Frame", { BackgroundColor3 = HEALTH, BackgroundTransparency = 0.55 }, healBack)
UiKit.round(healAfter, 8)
local healNow = new("Frame", { BackgroundColor3 = HEALTH }, healBack)
UiKit.round(healNow, 8)
local healBarText = label(healBack, "", 10, P.Text, Enum.Font.GothamBlack)
healBarText.Size, healBarText.TextXAlignment, healBarText.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 3
-- Whether AUTO HEAL is on.
local healHint = label(healPane, "", if SHORT then 11 else 10, P.Dim, IronUi.Bold)
healHint.Position, healHint.Size = UDim2.fromOffset(2, HEAD_H + 4), UDim2.new(1, -4, 0, 14)
-- Your gems, a card for each rarity and element.
local CARD_W, CARD_H = if SHORT then 141 else 150, 84
local stacksY, footH = HEAD_H + 22, if SHORT then 44 else 48
local stackList = new("ScrollingFrame", {
	Name = "GemStacks",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, stacksY),
	Size = UDim2.new(1, 0, 1, -stacksY - footH - 4),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, healPane)
new("UIGridLayout", {
	CellSize = UDim2.fromOffset(CARD_W, CARD_H),
	CellPadding = UDim2.fromOffset(8, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, stackList)
local healFoot = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, footH),
}, healPane)
local healSummary = label(healFoot, "", 13, P.Text, IronUi.Bold)
healSummary.Position, healSummary.Size = UDim2.fromOffset(2, 5), UDim2.new(1, -276, 0, 18)
local healNote = label(healFoot, "", 10, P.Dim, IronUi.Body)
healNote.Position, healNote.Size = UDim2.fromOffset(2, 23), UDim2.new(1, -276, 0, 24)
healNote.TextWrapped, healNote.TextYAlignment = true, Enum.TextYAlignment.Top
local healButton = smallButton(healFoot, "HEAL", P.Good)
healButton.AnchorPoint = Vector2.new(1, 0.5)
healButton.Position, healButton.Size = UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(150, 40)
healButton.TextSize = 16
local resetButton = smallButton(healFoot, "CLEAR", P.Edge)
resetButton.AnchorPoint = Vector2.new(1, 0.5)
resetButton.Position, resetButton.Size = UDim2.new(1, -158, 0.5, 0), UDim2.fromOffset(106, 40)
-- Knocked out: no gems bring it back, so in their place when it's back by
-- itself, and how to bring it back now (REVIVE and COUPON, below).
local reviveCard = new("Frame", {
	Name = "Revive",
	BackgroundColor3 = P.Inset,
	Position = UDim2.fromOffset(0, stacksY),
	Size = UDim2.new(1, 0, 1, -stacksY - footH - 4),
	Visible = false,
}, healPane)
UiKit.round(reviveCard, 10)
new("UIStroke", { Color = P.Bad:Lerp(P.Edge, 0.45), Thickness = 1.5 }, reviveCard)
local function centred(text: string, size: number, color: Color3, font: Enum.Font, y: number, h: number): TextLabel
	local l = label(reviveCard, text, size, color, font)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.Position, l.Size = UDim2.fromOffset(8, y), UDim2.new(1, -16, 0, h)
	return l
end
local reviveCaption = centred("BACK BY ITSELF IN", 11, P.Dim, IronUi.Bold, if SHORT then 7 else 36, 14)
local reviveTime = centred("", if SHORT then 32 else 46, P.Text, Enum.Font.GothamBlack, if SHORT then 20 else 54, if SHORT then 36 else 54)
local reviveLine = centred("", 12, P.Text, IronUi.Bold, if SHORT then 58 else 118, 16)
local reviveCoupon = centred("", 11, P.Gold, IronUi.Bold, if SHORT then 78 else 144, 16)

-- ENCHANT (Kaiju.canSocket: its own element only): the one in it at the top,
-- a line on the rule, a row for each rarity of its element below, rarest
-- first (the finest of yours of it, or dimmed when you have none), and
-- what the one picked does at the foot, with ENCHANT.
local soulUi: { [string]: any } = {}
local ENCH_H = if SHORT then 50 else 66
soulUi.soulPane = new("Frame", {
	Name = "Enchant",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	Visible = false,
}, right)
soulUi.soulHead = new("Frame", { BackgroundColor3 = P.Inset, Size = UDim2.new(1, 0, 0, ENCH_H) }, soulUi.soulPane)
UiKit.round(soulUi.soulHead, 10)
soulUi.soulHeadEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.25 }, soulUi.soulHead)
soulUi.soulHeadArt = new("Frame", {
	Name = "Gem",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 4),
	Size = UDim2.fromOffset(ENCH_H - 8, ENCH_H - 8),
}, soulUi.soulHead)
soulUi.soulHeadTag = label(soulUi.soulHead, "ENCHANT NOW", 9, P.Dim, IronUi.Bold)
soulUi.soulHeadTag.Position = UDim2.fromOffset(ENCH_H + 4, if SHORT then 3 else 6)
soulUi.soulHeadTag.Size = UDim2.new(1, -ENCH_H - 12, 0, 11)
soulUi.soulHeadName = label(soulUi.soulHead, "", if SHORT then 13 else 15, P.Text, Enum.Font.GothamBlack)
soulUi.soulHeadName.Position = UDim2.fromOffset(ENCH_H + 4, if SHORT then 14 else 18)
soulUi.soulHeadName.Size = UDim2.new(1, -ENCH_H - 12, 0, 18)
soulUi.soulHeadLine = label(soulUi.soulHead, "", if SHORT then 10 else 11, P.Good, IronUi.Bold)
soulUi.soulHeadLine.Position = UDim2.fromOffset(ENCH_H + 4, if SHORT then 32 else 37)
soulUi.soulHeadLine.Size = UDim2.new(1, -ENCH_H - 12, 0, 14)
soulUi.soulHeadStats = label(soulUi.soulHead, "", 10, P.Dim, IronUi.Bold)
soulUi.soulHeadStats.Position = UDim2.fromOffset(ENCH_H + 4, 51)
soulUi.soulHeadStats.Size = UDim2.new(1, -ENCH_H - 12, 0, 12)
soulUi.soulHeadStats.Visible = not SHORT
soulUi.soulHeadArtId = nil
-- The rule, in its element's colour.
soulUi.soulHint = label(soulUi.soulPane, "", if SHORT then 10 else 11, P.Dim, IronUi.Bold)
soulUi.soulHint.Name = "Rule"
soulUi.soulHint.RichText = true
soulUi.soulHint.Position, soulUi.soulHint.Size = UDim2.fromOffset(2, ENCH_H + 5), UDim2.new(1, -4, 0, 14)
local RULE_Y = ENCH_H + 24
local ENCH_FOOT = if SHORT then 44 else 50
soulUi.soulList = new("ScrollingFrame", {
	Name = "EnchantGems",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, RULE_Y),
	Size = UDim2.new(1, 0, 1, -RULE_Y - ENCH_FOOT - 6),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
}, soulUi.soulPane)
UiKit.list(soulUi.soulList, if SHORT then 4 else 5)
soulUi.soulFoot = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, ENCH_FOOT),
}, soulUi.soulPane)
soulUi.soulSummary = label(soulUi.soulFoot, "", 13, P.Text, IronUi.Bold)
soulUi.soulSummary.Position, soulUi.soulSummary.Size = UDim2.fromOffset(2, 4), UDim2.new(1, -170, 0, 18)
soulUi.soulNote = label(soulUi.soulFoot, "", 10, P.Dim, IronUi.Body)
soulUi.soulNote.RichText = true
soulUi.soulNote.Position, soulUi.soulNote.Size = UDim2.fromOffset(2, 22), UDim2.new(1, -170, 0, 26)
soulUi.soulNote.TextWrapped, soulUi.soulNote.TextYAlignment = true, Enum.TextYAlignment.Top
soulUi.soulButton = smallButton(soulUi.soulFoot, "ENCHANT", P.Gold)
soulUi.soulButton.Name = "EnchantButton"
soulUi.soulButton.AnchorPoint = Vector2.new(1, 0.5)
soulUi.soulButton.Position, soulUi.soulButton.Size = UDim2.new(1, 0, 0.5, 0), UDim2.fromOffset(150, 40)
soulUi.soulButton.TextSize = 16

local tab = "Details"
local selected: string? = nil
local swapping = false -- choose the exact deployed kaiju from its roster card
local swapTarget: string? = nil
-- HEAL's picks: how many of each stack. Made for you (pickFresh, a new
-- kaiju, or its health changed while you hadn't touched them), else yours.
local pickCounts: { [string]: number } = {}
local pickFresh, pickFor, pickSig, manual = true, nil :: string?, nil :: string?, false
local healChosen, healReady = {}, false
local tabButtons = {}
local rowLive = {} -- [id] = the bits of its row that change while you look
local drawPanel

-- DRAG AND DROP: every kaiju in the panel, a card on the left (team,
-- support, reserves) or a place in TEAMS, can be picked up and dropped on
-- another: two of your fighters swap places (KaijuSwap: teams and
-- reserves alike); a support kind dropped on the support card takes the
-- support slot (KaijuSupport). A press that doesn't move past teamsUi.Drag.Slop
-- stays a tap (pick it / tap-to-swap, as before).
local teamsUi = {} -- (one table: this file is at Luau's 200 locals)
teamsUi.Drag = { Slop = 8, Targets = {}, Active = nil :: any, SuppressUntil = 0 }
function teamsUi.Drag.point(input: InputObject): Vector2
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y) + game:GetService("GuiService"):GetGuiInset()
	end
	return UserInputService:GetMouseLocation() -- (the panel ignores the inset)
end
function teamsUi.Drag.inside(f: GuiObject, point: Vector2): boolean
	local p, size = f.AbsolutePosition, f.AbsoluteSize
	return point.X >= p.X and point.Y >= p.Y and point.X < p.X + size.X and point.Y < p.Y + size.Y
end
-- A kaiju's card or place to drop on: `clip`, if given, is what it scrolls
-- in (a drop only counts where it shows); `support` for the support card,
-- `place` ({Team=,Slot=}) for an empty place in TEAMS, `bench` for the bench.
function teamsUi.Drag.target(frame: GuiObject, id: string?, clip: GuiObject?, support: boolean?, place: any?, bench: boolean?)
	for i = #teamsUi.Drag.Targets, 1, -1 do
		if not teamsUi.Drag.Targets[i].Frame.Parent then
			table.remove(teamsUi.Drag.Targets, i)
		end
	end
	table.insert(teamsUi.Drag.Targets, { Frame = frame, Id = id, Clip = clip, Support = support == true, Place = place, Bench = bench == true })
end
function teamsUi.Drag.under(point: Vector2)
	for _, t in teamsUi.Drag.Targets do
		local f = t.Frame
		if f.Parent and f.Visible and f:IsDescendantOf(window.Gui) and teamsUi.Drag.inside(f, point) and (not t.Clip or teamsUi.Drag.inside(t.Clip, point)) then
			local hidden = false
			local up = f.Parent
			while up and up:IsA("GuiObject") do
				if not up.Visible then
					hidden = true
					break
				end
				up = up.Parent
			end
			if not hidden then
				return t
			end
		end
	end
	return nil
end
-- Makes `frame` (a kaiju's) draggable.
function teamsUi.Drag.source(frame: GuiObject, id: string)
	frame.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		if teamsUi.Drag.Active then
			return
		end
		teamsUi.Drag.Active = { Id = id, Input = input, From = teamsUi.Drag.point(input), Started = false }
	end)
end
function teamsUi.Drag.paintHover(target)
	if teamsUi.Drag.Glow then
		teamsUi.Drag.Glow:Destroy()
		teamsUi.Drag.Glow = nil
	end
	if target and target.Id ~= (teamsUi.Drag.Active and teamsUi.Drag.Active.Id) then
		teamsUi.Drag.Glow = new("UIStroke", { Name = "DropGlow", Color = P.Gold, Thickness = 2.5, Transparency = 0 }, target.Frame)
	end
end
function teamsUi.Drag.begin(drag, point: Vector2)
	local data = roster()
	local record = data and data.List[drag.Id]
	if not record then
		teamsUi.Drag.Active = nil
		return
	end
	drag.Started = true
	teamsUi.Drag.SuppressUntil = math.huge -- (no taps till it's dropped)
	listFrame.ScrollingEnabled = false
	teamsUi.Pane.ScrollingEnabled = false
	local color = elementColor(record.Element)
	local ghost = new("Frame", {
		Name = "KaijuDragGhost",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(150, 34),
		BackgroundColor3 = color:Lerp(INK, 0.7),
		BackgroundTransparency = 0.05,
		ZIndex = 60,
	}, window.Gui)
	UiKit.round(ghost, 8)
	new("UIStroke", { Color = color, Thickness = 2 }, ghost)
	local name = label(ghost, Kaiju.nameOf(record), 12, color:Lerp(P.Text, 0.4), IronUi.Bold)
	name.Size, name.TextXAlignment, name.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 61
	drag.Ghost = ghost
	teamsUi.Drag.move(point)
end
function teamsUi.Drag.move(point: Vector2)
	local drag = teamsUi.Drag.Active
	if drag and drag.Ghost then
		drag.Ghost.Position = UDim2.fromOffset(point.X, point.Y - 22)
		teamsUi.Drag.paintHover(teamsUi.Drag.under(point))
	end
end
function teamsUi.Drag.finish(point: Vector2?)
	local drag = teamsUi.Drag.Active
	teamsUi.Drag.Active = nil
	listFrame.ScrollingEnabled = true
	teamsUi.Pane.ScrollingEnabled = true
	teamsUi.Drag.paintHover(nil)
	if not drag or not drag.Started then
		return
	end
	teamsUi.Drag.SuppressUntil = os.clock() + 0.25 -- (the release isn't a tap)
	if drag.Ghost then
		drag.Ghost:Destroy()
	end
	local target = point and teamsUi.Drag.under(point)
	if not target or target.Id == drag.Id then
		return
	end
	local data = roster()
	local a = data and data.List[drag.Id]
	local b = target.Id and data.List[target.Id]
	if not a then
		return
	end
	local aSupport = Kaiju.isSupport(a.Species)
	local request, args
	if target.Support or (b and Kaiju.isSupport(b.Species)) then
		if not aSupport then
			UiKit.toast("Only a support kind goes in the support slot.", P.Gold)
			return
		end
		request, args = "KaijuSupport", { drag.Id }
	elseif aSupport then
		UiKit.toast("A support goes in the support slot, not a team.", P.Gold)
		return
	elseif b then
		request, args = "KaijuSwap", { drag.Id, target.Id }
	elseif target.Place then
		request, args = "KaijuPlace", { drag.Id, target.Place.Team, target.Place.Slot }
	elseif target.Bench then
		if not Kaiju.teamNumber(data, drag.Id) then
			return -- (it's on the bench already)
		end
		request, args = "KaijuBench", { drag.Id }
	else
		return
	end
	task.spawn(function()
		local result = GemClient.request(request, table.unpack(args))
		if result and not result.Ok and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, P.Bad)
		end
		teamsUi.Pick = nil
		if window.Gui.Enabled and drawPanel then
			drawPanel()
		end
	end)
end
UserInputService.InputChanged:Connect(function(input)
	local drag = teamsUi.Drag.Active
	if not drag then
		return
	end
	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.MouseMovement and not (kind == Enum.UserInputType.Touch and input == drag.Input) then
		return
	end
	local point = teamsUi.Drag.point(input)
	if not drag.Started then
		if (point - drag.From).Magnitude >= teamsUi.Drag.Slop then
			teamsUi.Drag.begin(drag, point)
		end
		return
	end
	teamsUi.Drag.move(point)
end)
UserInputService.InputEnded:Connect(function(input)
	local drag = teamsUi.Drag.Active
	if not drag then
		return
	end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or (kind == Enum.UserInputType.Touch and input == drag.Input) then
		teamsUi.Drag.finish(teamsUi.Drag.point(input))
	end
end)
window.Gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not window.Gui.Enabled and teamsUi.Drag.Active then
		teamsUi.Drag.finish(nil)
	end
end)

-- TEAMS (the panel's first page, the whole width): your four teams side by
-- side (Kaiju.teams), each a card with its places (Kaiju.slots; the first
-- LEADS, an empty one says so), its key and what it's doing (OUT, CALLED
-- BACK, READY, EMPTY) and a button to bring it out or call it back
-- (pressTeam, as its key does). Under them your BENCH (Kaiju.bench: in no
-- team) and your SUPPORT (its own slot). To arrange them: tap a kaiju, then
-- where it goes: an empty place (PUT HERE: KaijuPlace), another kaiju (SWAP:
-- KaijuSwap, the bench's too) or the bench (SEND TO BENCH: KaijuBench). Or
-- tap an empty place first, then who fills it. Dragging one onto a place,
-- a kaiju or the bench does the same. AUTO FILL fills the empty places from
-- the bench (KaijuAutoFill). The bar at the top says what's picked, with
-- DETAILS (its page) and CANCEL.
teamsUi.Pane = new("ScrollingFrame", {
	Name = "Teams",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	CanvasSize = UDim2.new(),
	ScrollBarThickness = if SHORT then 3 else 0,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Visible = false,
}, right)
teamsUi.Gold = Color3.fromRGB(255, 202, 91)
teamsUi.Card = Color3.fromRGB(18, 22, 36)
teamsUi.Place = Color3.fromRGB(26, 31, 48)
-- The bar: what to do now (or what's picked), and its buttons.
teamsUi.Bar = new("Frame", { BackgroundColor3 = teamsUi.Card, Size = UDim2.new(1, 0, 0, if SHORT then 28 else 34) }, teamsUi.Pane)
UiKit.round(teamsUi.Bar, 8)
teamsUi.BarEdge = new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.5 }, teamsUi.Bar)
teamsUi.Hint = label(teamsUi.Bar, "", if SHORT then 11 else 13, P.Text, IronUi.Bold)
teamsUi.Hint.RichText = true
teamsUi.Hint.Position = UDim2.fromOffset(12, 0)
teamsUi.Buttons = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -5, 0.5, 0),
	Size = UDim2.new(0, 320, 1, -8),
}, teamsUi.Bar)
do
	local list = UiKit.list(teamsUi.Buttons, 6, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.VerticalAlignment = Enum.VerticalAlignment.Center
end
function teamsUi.barButton(text: string, color: Color3, order: number, onClick: () -> ()): TextButton
	local b = smallButton(teamsUi.Buttons, text, color)
	b.LayoutOrder = order
	b.Size = UDim2.new(0, if SHORT then 74 else 92, 1, 0)
	b.TextSize = if SHORT then 10 else 11
	b.Activated:Connect(onClick)
	return b
end
teamsUi.Rows = new("Frame", { Name = "Cards", BackgroundTransparency = 1 }, teamsUi.Pane)
teamsUi.BenchBox = new("Frame", { Name = "Bench", BackgroundColor3 = teamsUi.Card }, teamsUi.Pane)
UiKit.round(teamsUi.BenchBox, 10)
teamsUi.BenchEdge = new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.5 }, teamsUi.BenchBox)
teamsUi.Pick = nil :: any -- { Id = id } or { Team = n, Slot = k } (an empty place)

-- Doing it: the request, then the page again (a toast if it couldn't).
function teamsUi.send(request: string, ...)
	local args = table.pack(...)
	teamsUi.Pick = nil
	task.spawn(function()
		local result = GemClient.request(request, table.unpack(args, 1, args.n))
		if result and not result.Ok and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, P.Bad)
		end
		if window.Gui.Enabled and tab == "Teams" then
			teamsUi.draw(roster())
		end
	end)
	teamsUi.draw(roster())
end

-- A tap on a kaiju (`id`), an empty place (`place`: { Team, Slot }) or the
-- bench: picks it, or finishes the move picked.
function teamsUi.tap(id: string?, place: any?, bench: boolean?)
	if os.clock() < teamsUi.Drag.SuppressUntil then
		return
	end
	local pick = teamsUi.Pick
	local data = roster()
	if not data then
		return
	end
	if pick == nil then
		if bench then
			return
		end
		teamsUi.Pick = if id then { Id = id } else place
	elseif pick.Id and id == pick.Id then
		teamsUi.Pick = nil
	elseif pick.Team and place and place.Team == pick.Team and place.Slot == pick.Slot then
		teamsUi.Pick = nil
	elseif pick.Id and id then
		local a, b = data.List[pick.Id], data.List[id]
		if a and b and (Kaiju.isSupport(a.Species) or Kaiju.isSupport(b.Species)) then
			if Kaiju.isSupport(a.Species) and Kaiju.isSupport(b.Species) then
				teamsUi.send("KaijuSupport", if Kaiju.supportId(data) == pick.Id then id else pick.Id)
			else
				UiKit.toast("A support goes in the support slot, not a team.", teamsUi.Gold)
				teamsUi.Pick = nil
			end
			return
		end
		teamsUi.send("KaijuSwap", pick.Id, id)
		return
	elseif pick.Id and place then
		teamsUi.send("KaijuPlace", pick.Id, place.Team, place.Slot)
		return
	elseif pick.Id and bench then
		if Kaiju.teamNumber(data, pick.Id) then
			teamsUi.send("KaijuBench", pick.Id)
		else
			teamsUi.Pick = nil
		end
		return
	elseif pick.Team and id then
		local record = data.List[id]
		if record and Kaiju.isSupport(record.Species) then
			UiKit.toast("A support goes in the support slot, not a team.", teamsUi.Gold)
			return
		end
		teamsUi.send("KaijuPlace", id, pick.Team, pick.Slot)
		return
	else
		teamsUi.Pick = if id then { Id = id } elseif place then place else nil
	end
	teamsUi.draw(data)
end

-- A kaiju's face, name, level and role, and its health (`w` by `h`, as a
-- place in a team or a card on the bench).
function teamsUi.face(parent: GuiObject, record, key: string, compact: boolean)
	local color = elementColor(record.Element)
	local h = parent.Size.Y.Offset
	local face = h - 8
	local view = viewport(parent, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(face, face) })
	UiKit.round(view, 6)
	portrait(view, modelFor(key, record))
	local left = face + 10
	local name = nameLabel(parent, Kaiju.nameOf(record), if compact then 11 else 13, color:Lerp(P.Text, 0.45), IronUi.Bold)
	name.Position, name.Size = UDim2.fromOffset(left, if compact then 3 else 6), UDim2.new(1, -left - 6, 0, if compact then 13 else 16)
	local spec = Kaiju.Species[record.Species]
	local role = spec and spec.Role or ""
	local line = label(parent, "", if compact then 9 else 10, P.Dim, IronUi.Bold)
	line.RichText = true
	line.Text = if record.Down
		then '<font color="#F05C5C">DOWN</font>  ·  LV ' .. tostring(record.Level or 1)
		else "LV " .. tostring(record.Level or 1) .. (if compact or role == "" then "" else '  ·  <font color="#' .. (ROLE_COLORS[role] or P.Dim):ToHex() .. '">' .. string.upper(role) .. "</font>")
	line.Position, line.Size = UDim2.fromOffset(left, if compact then 16 else 23), UDim2.new(1, -left - 6, 0, 12)
	if not compact then
		local back, fill = bar(parent, HEALTH)
		back.Position, back.Size = UDim2.new(0, left, 1, -10), UDim2.new(1, -left - 8, 0, 4)
		fill.Size = UDim2.fromScale(healthShare(record, nil), 1)
	end
	return color
end

-- A badge on a place or card, a ribbon along its portrait's foot (clear of
-- the name): what a tap does now (PUT HERE, SWAP, MOVING) or LEAD.
function teamsUi.badge(parent: GuiObject, text: string, color: Color3, dark: boolean?)
	local face = parent.Size.Y.Offset - 8
	local b = label(parent, text, 8, if dark then INK else color, Enum.Font.GothamBlack)
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, 4, 1, -4)
	b.Size = UDim2.fromOffset(face, 13)
	b.TextXAlignment = Enum.TextXAlignment.Center
	b.BackgroundTransparency = if dark then 0 else 0.1
	b.BackgroundColor3 = if dark then color else INK
	b.ZIndex = 4
	UiKit.round(b, 4)
	return b
end

function teamsUi.draw(data)
	keepModels("team:") -- (the portraits are kept for the next draw)
	for _, child in teamsUi.Rows:GetChildren() do
		child:Destroy()
	end
	for _, child in teamsUi.BenchBox:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
	for _, child in teamsUi.Buttons:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local teams, bench, size = Kaiju.teams(data), Kaiju.bench(data), Kaiju.slots(data)
	local out, away = Kaiju.outTeam(data), Kaiju.away(data)
	local support = Kaiju.supportId(data)
	-- (A pick that's gone, a kaiju sold or a team shrunk: let it go.)
	local pick = teamsUi.Pick
	if pick and pick.Id and not data.List[pick.Id] then
		pick, teamsUi.Pick = nil, nil
	end
	local picked = pick and pick.Id and data.List[pick.Id]
	local pickedSupport = picked and Kaiju.isSupport(picked.Species)
	local pickedPlaced = picked and Kaiju.teamNumber(data, pick.Id) ~= nil

	-- The bar.
	if picked then
		teamsUi.Hint.Text = string.format(
			'<font color="#FFCA5B">MOVING %s</font>  ·  %s',
			string.upper(Kaiju.nameOf(picked)),
			if pickedSupport
				then "tap another support to make it your support"
				elseif pickedPlaced then "tap a place, a kaiju to swap with, or the bench"
				else "tap a place or a kaiju to put it in a team"
		)
		teamsUi.barButton("DETAILS", P.Edge, 1, function()
			selected, tab, teamsUi.Pick = pick.Id, "Details", nil
			drawPanel()
		end)
		teamsUi.barButton("CANCEL", P.Bad, 2, function()
			teamsUi.Pick = nil
			teamsUi.draw(roster())
		end)
	elseif pick and pick.Team then
		teamsUi.Hint.Text = string.format('<font color="#FFCA5B">TEAM %d, PLACE %d</font>  ·  tap a kaiju to put it here', pick.Team, pick.Slot)
		teamsUi.barButton("CANCEL", P.Bad, 2, function()
			teamsUi.Pick = nil
			teamsUi.draw(roster())
		end)
	else
		teamsUi.Hint.Text = "Tap a kaiju, then tap where it should go."
		if #bench > 0 then
			teamsUi.barButton("AUTO FILL", teamsUi.Gold, 1, function()
				teamsUi.send("KaijuAutoFill")
			end)
		end
	end
	teamsUi.Hint.Size = UDim2.new(1, -(if picked then (if SHORT then 170 else 206) elseif pick or #bench > 0 then 110 else 16), 1, 0)
	teamsUi.BarEdge.Color = if pick then teamsUi.Gold else P.Edge
	teamsUi.BarEdge.Transparency = if pick then 0.2 else 0.5

	-- The four teams, side by side.
	local width = teamsUi.Pane.AbsoluteSize.X
	if width <= 0 then
		width = if SHORT then 590 else 760
	end
	local gap = if SHORT then 6 else 10
	local cardW = math.floor((width - 4 - gap * (Kaiju.Teams - 1)) / Kaiju.Teams)
	local headH, placeH, placeGap, footH = if SHORT then 22 else 30, if SHORT then 34 else 56, if SHORT then 3 else 5, if SHORT then 24 else 30
	local top = (if SHORT then 28 else 34) + (if SHORT then 6 else 10)
	local benchGap, benchH = if SHORT then 6 else 10, if SHORT then 64 else 96
	-- (Places as tall as fit: the teams and the bench on the page at once.)
	local room = teamsUi.Pane.AbsoluteSize.Y
	if room > 0 then
		local fixed = top + headH + (size - 1) * placeGap + footH + (if SHORT then 10 else 16) + benchGap + benchH + 4
		placeH = math.clamp(math.floor((room - fixed) / size), if SHORT then 30 else 40, placeH)
	end
	local cardH = headH + size * placeH + (size - 1) * placeGap + footH + (if SHORT then 10 else 16)
	teamsUi.Rows.Position, teamsUi.Rows.Size = UDim2.fromOffset(0, top), UDim2.new(1, 0, 0, cardH)
	for n = 1, Kaiju.Teams do
		local team = teams[n]
		local isOut = n == out and #team > 0
		local card = new("Frame", {
			Name = "Team" .. n,
			BackgroundColor3 = if isOut and not away then teamsUi.Gold:Lerp(teamsUi.Card, 0.88) else teamsUi.Card,
			Position = UDim2.fromOffset((n - 1) * (cardW + gap), 0),
			Size = UDim2.fromOffset(cardW, cardH),
		}, teamsUi.Rows)
		UiKit.round(card, 10)
		new("UIStroke", { Color = if isOut then teamsUi.Gold else P.Edge, Thickness = if isOut then 1.5 else 1, Transparency = if isOut then 0.1 else 0.55 }, card)
		-- Its name and key, and what it's doing.
		local title = label(card, "TEAM " .. n, if SHORT then 12 else 15, if isOut then teamsUi.Gold else P.Text, Enum.Font.GothamBlack)
		title.Position, title.Size = UDim2.fromOffset(if SHORT then 8 else 10, if SHORT then 3 else 6), UDim2.new(0.6, 0, 0, headH - 6)
		local stateText, stateColor
		if #team == 0 then
			stateText, stateColor = "EMPTY", P.Dim
		elseif isOut and away then
			stateText, stateColor = "CALLED BACK", P.Dim
		elseif isOut then
			stateText, stateColor = "OUT", teamsUi.Gold
		else
			stateText, stateColor = "READY", P.Good
		end
		local state = label(card, stateText, if SHORT then 8 else 10, stateColor, Enum.Font.GothamBlack)
		state.AnchorPoint = Vector2.new(1, 0)
		state.TextXAlignment = Enum.TextXAlignment.Right
		state.Position, state.Size = UDim2.new(1, -8, 0, if SHORT then 4 else 8), UDim2.fromOffset(cardW * 0.5, headH - 8)
		-- Its places.
		for k = 1, size do
			local id = team[k]
			local record = id and data.List[id]
			local y = headH + 4 + (k - 1) * (placeH + placeGap)
			local isPicked = pick ~= nil and ((pick.Id ~= nil and pick.Id == id) or (pick.Team == n and pick.Slot == k and not id))
			local cell = new("TextButton", {
				Name = "Place" .. k,
				Text = "",
				AutoButtonColor = true,
				BackgroundColor3 = if isPicked then teamsUi.Gold:Lerp(INK, 0.6) elseif record then teamsUi.Place else INK,
				BackgroundTransparency = if record or isPicked then 0 else 0.35,
				Position = UDim2.fromOffset(if SHORT then 4 else 6, y),
				Size = UDim2.fromOffset(cardW - (if SHORT then 8 else 12), placeH),
			}, card)
			UiKit.round(cell, 7)
			local canDrop = pick ~= nil and not isPicked and not pickedSupport and (picked ~= nil or record ~= nil)
			new("UIStroke", {
				Color = if isPicked or canDrop then teamsUi.Gold elseif record then elementColor(record.Element) else P.Edge,
				Thickness = if isPicked then 2 else 1,
				Transparency = if isPicked then 0 elseif canDrop then 0.35 elseif record then 0.55 else 0.6,
			}, cell)
			if record then
				teamsUi.face(cell, record, "team:" .. id, SHORT)
				if isPicked then
					teamsUi.badge(cell, "MOVING", teamsUi.Gold, true)
				elseif canDrop then
					teamsUi.badge(cell, "SWAP", teamsUi.Gold)
				elseif k == 1 and not SHORT then
					teamsUi.badge(cell, "LEAD", teamsUi.Gold)
				end
				teamsUi.Drag.source(cell, id)
				teamsUi.Drag.target(cell, id, teamsUi.Pane)
				cell.Activated:Connect(function()
					teamsUi.tap(id, nil, nil)
				end)
			else
				local word = label(cell, if canDrop then "PUT HERE" elseif isPicked then "PICK A KAIJU" else "+  EMPTY", if SHORT then 10 else 12, if canDrop or isPicked then teamsUi.Gold else P.Dim, Enum.Font.GothamBlack)
				word.Size, word.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
				local place = { Team = n, Slot = k }
				teamsUi.Drag.target(cell, nil, teamsUi.Pane, nil, place)
				cell.Activated:Connect(function()
					teamsUi.tap(nil, place, nil)
				end)
			end
		end
		-- Bring it out (its key), or call it back.
		local foot = smallButton(card, "", teamsUi.Gold)
		foot.AnchorPoint = Vector2.new(0.5, 1)
		foot.Position = UDim2.new(0.5, 0, 1, if SHORT then -4 else -7)
		foot.Size = UDim2.new(1, if SHORT then -8 else -12, 0, footH)
		foot.TextSize = if SHORT then 10 else 12
		foot.Font = Enum.Font.GothamBlack
		local keyHint = if SHORT then "" else "  [" .. n .. "]"
		if #team == 0 then
			-- (Its first place picked: tap a kaiju to put it in.)
			foot.Text = "FILL"
			foot.TextColor3, foot.BackgroundColor3 = teamsUi.Gold, INK
		elseif isOut and not away then
			foot.Text = "CALL BACK" .. keyHint
			foot.BackgroundColor3 = P.Edge:Lerp(INK, 0.5)
		else
			foot.Text = (if isOut then "SEND OUT" else "BRING OUT") .. keyHint
			foot.BackgroundColor3 = teamsUi.Gold
			foot.TextColor3 = INK
		end
		foot:SetAttribute("NoTranslate", true)
		foot.Activated:Connect(function()
			pressTeam(n)
		end)
	end

	-- The bench and the support.
	local benchY = top + cardH + benchGap
	teamsUi.BenchBox.Position, teamsUi.BenchBox.Size = UDim2.fromOffset(0, benchY), UDim2.new(1, -4, 0, benchH)
	local benchDrop = picked ~= nil and pickedPlaced and not pickedSupport
	teamsUi.BenchEdge.Color = if benchDrop then teamsUi.Gold else P.Edge
	teamsUi.BenchEdge.Transparency = if benchDrop then 0.2 else 0.5
	local supportW = if SHORT then 150 else 196
	local head = label(teamsUi.BenchBox, "", if SHORT then 10 else 12, if benchDrop then teamsUi.Gold else P.Dim, Enum.Font.GothamBlack)
	head.Text = if benchDrop then "SEND TO BENCH" else string.format("BENCH  ·  %d", #bench)
	head.Position, head.Size = UDim2.fromOffset(10, 4), UDim2.new(1, -supportW - 30, 0, 16)
	-- (the whole box is a place to drop one: the bench)
	local benchHit = new("TextButton", {
		Name = "BenchHit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -supportW - 12, 1, 0),
	}, teamsUi.BenchBox)
	benchHit.Activated:Connect(function()
		teamsUi.tap(nil, nil, true)
	end)
	teamsUi.Drag.target(benchHit, nil, teamsUi.Pane, nil, nil, true)
	local strip = new("ScrollingFrame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, if SHORT then 20 else 24),
		Size = UDim2.new(1, -supportW - 28, 1, if SHORT then -24 else -30),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
		ZIndex = 2,
	}, teamsUi.BenchBox)
	UiKit.list(strip, 6, true)
	if #bench == 0 then
		local none = label(strip, if benchDrop then "Tap here to bench it" else "Everyone's in a team.", if SHORT then 10 else 12, P.Dim, IronUi.Body)
		none.Size = UDim2.new(1, 0, 1, 0)
	end
	local benchCardW = if SHORT then 132 else 168
	for i, id in bench do
		local record = data.List[id]
		local isPicked = pick ~= nil and pick.Id == id
		local canDrop = pick ~= nil and not isPicked and not pickedSupport
		local cell = new("TextButton", {
			Name = "Bench" .. i,
			Text = "",
			LayoutOrder = i,
			AutoButtonColor = true,
			BackgroundColor3 = if isPicked then teamsUi.Gold:Lerp(INK, 0.6) else teamsUi.Place,
			Size = UDim2.new(0, benchCardW, 1, -6),
			ZIndex = 3,
		}, strip)
		UiKit.round(cell, 7)
		new("UIStroke", {
			Color = if isPicked or canDrop then teamsUi.Gold else elementColor(record.Element),
			Thickness = if isPicked then 2 else 1,
			Transparency = if isPicked then 0 elseif canDrop then 0.35 else 0.55,
		}, cell)
		cell.Size = UDim2.fromOffset(benchCardW, benchH - (if SHORT then 28 else 36))
		teamsUi.face(cell, record, "team:" .. id, true)
		if isPicked then
			teamsUi.badge(cell, "MOVING", teamsUi.Gold, true)
		elseif canDrop and picked then
			teamsUi.badge(cell, "SWAP", teamsUi.Gold)
		elseif canDrop then
			teamsUi.badge(cell, "PUT HERE", teamsUi.Gold)
		end
		teamsUi.Drag.source(cell, id)
		teamsUi.Drag.target(cell, id, strip)
		cell.Activated:Connect(function()
			teamsUi.tap(id, nil, nil)
		end)
	end
	-- SUPPORT: its own slot, at the bench's right (others of its kind beside it).
	local supportBox = new("Frame", {
		Name = "Support",
		BackgroundColor3 = SUPPORT:Lerp(INK, 0.86),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.new(0, supportW, 1, -12),
		ZIndex = 2,
	}, teamsUi.BenchBox)
	UiKit.round(supportBox, 8)
	new("UIStroke", { Color = SUPPORT, Thickness = 1, Transparency = 0.4 }, supportBox)
	local supportWord = label(supportBox, "SUPPORT", if SHORT then 9 else 10, SUPPORT, Enum.Font.GothamBlack)
	supportWord.Position, supportWord.Size = UDim2.fromOffset(8, 2), UDim2.new(1, -16, 0, 14)
	supportWord.ZIndex = 3
	local supportRecord = support and data.List[support]
	if supportRecord then
		local cell = new("TextButton", {
			Name = "SupportKaiju",
			Text = "",
			BackgroundColor3 = if pick and pick.Id == support then teamsUi.Gold:Lerp(INK, 0.6) else teamsUi.Place,
			Position = UDim2.fromOffset(4, if SHORT then 16 else 18),
			Size = UDim2.fromOffset(supportW - 8, benchH - (if SHORT then 34 else 36)),
			ZIndex = 3,
		}, supportBox)
		UiKit.round(cell, 7)
		teamsUi.face(cell, supportRecord, "team:" .. support, true)
		teamsUi.Drag.target(cell, support, nil, true)
		cell.Activated:Connect(function()
			teamsUi.tap(support, nil, nil)
		end)
	else
		local none = label(supportBox, "Catch a support kind", if SHORT then 9 else 10, P.Dim, IronUi.Body)
		none.Position, none.Size = UDim2.fromOffset(8, 18), UDim2.new(1, -16, 1, -22)
		none.ZIndex = 3
	end
	-- Other supports of yours, to swap in: on the bench strip, after the fighters.
	for id, record in data.List do
		if Kaiju.isSupport(record.Species) and id ~= support then
			local cell = new("TextButton", {
				Name = "OtherSupport",
				Text = "",
				LayoutOrder = 1000,
				BackgroundColor3 = SUPPORT:Lerp(INK, 0.8),
				Size = UDim2.fromOffset(benchCardW, benchH - (if SHORT then 28 else 36)),
				ZIndex = 3,
			}, strip)
			UiKit.round(cell, 7)
			new("UIStroke", { Color = SUPPORT, Thickness = 1, Transparency = 0.5 }, cell)
			teamsUi.face(cell, record, "team:" .. id, true)
			teamsUi.Drag.source(cell, id)
			cell.Activated:Connect(function()
				teamsUi.send("KaijuSupport", id)
			end)
		end
	end
	teamsUi.Pane.CanvasSize = UDim2.fromOffset(0, benchY + benchH + 4)
end

for order, entry in { { "Teams", "TEAMS" }, { "Details", "DETAILS" }, { "Heal", "HEAL" }, { "Soul", "ENCHANT" } } do
	local b = smallButton(tabRow, entry[2], P.Gold)
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(if SHORT then 104 else 112, 28)
	b.Activated:Connect(function()
		tab = entry[1]
		swapping = false
		pickFresh = true
		if heroUi.Editing then
			heroUi.setEditing(false)
		end
		drawPanel()
	end)
	tabButtons[entry[1]] = b
	if entry[1] == "Soul" then
		-- (Lit when you've a better gem of its element for it: soulUi.upgrade.)
		soulUi.TabDot = new("Frame", {
			Name = "Upgrade",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = P.Good,
			Visible = false,
			ZIndex = 4,
		}, b)
		UiKit.round(soulUi.TabDot, 5)
		new("UIStroke", { Color = INK, Thickness = 1.5 }, soulUi.TabDot)
	end
end

local function moveName(id: string?): string
	local move = Kaiju.moveInfo(id)
	return if move then move.Name else "?"
end

-- Its name as the panel shows it: as you typed it, or its kind's title in
-- capitals.
function heroUi.shown(record): string
	if type(record.Name) == "string" and record.Name ~= "" then
		return record.Name
	end
	return string.upper(Kaiju.title(record))
end


-- Your gems for a heal, in stacks: one for each rarity and element (they
-- heal alike), the cheapest first (Commons, then rarer), its own element
-- first in each rarity. Never one on your gear, never a Gemsoul. In each
-- stack the spare ones first (none a saved loadout names), then the least
-- valuable, so a heal spends what you'd miss least.
local TIER_RANK = {}
for rank, tier in GemConfig.TierOrder do
	TIER_RANK[tier] = rank
end
local function stackKey(gem): string
	return (gem.Tier or "Common") .. "/" .. tostring(gem.Element)
end
local function healStacks(record)
	local profile = GemClient.Profile
	local spare = {}
	for _, tier in GemConfig.TierOrder do
		for _, gem in GemInventory.spare(profile, tier) do
			spare[gem.Id] = true
		end
	end
	local stacks, byKey = {}, {}
	for _, gem in GemInventory.available(profile) do
		if not Kaiju.isSoul(gem) then
			local key = stackKey(gem)
			local stack = byKey[key]
			if not stack then
				stack = {
					Key = key,
					Tier = gem.Tier or "Common",
					Element = gem.Element,
					Power = Kaiju.infusePower(gem, record),
					Gems = {},
				}
				byKey[key] = stack
				table.insert(stacks, stack)
			end
			table.insert(stack.Gems, gem)
		end
	end
	local worth = {}
	for _, stack in stacks do
		for _, gem in stack.Gems do
			local ok, value = pcall(GemConfig.value, gem)
			worth[gem] = if ok and type(value) == "number" then value else 0
		end
		table.sort(stack.Gems, function(a, b)
			if (spare[a.Id] == true) ~= (spare[b.Id] == true) then
				return spare[a.Id] == true
			end
			if worth[a] ~= worth[b] then
				return worth[a] < worth[b]
			end
			return a.Id < b.Id
		end)
	end
	table.sort(stacks, function(a, b)
		local ra, rb = TIER_RANK[a.Tier] or 0, TIER_RANK[b.Tier] or 0
		if ra ~= rb then
			return ra < rb
		end
		if a.Power ~= b.Power then
			return a.Power > b.Power
		end
		return tostring(a.Element) < tostring(b.Element)
	end)
	return stacks
end

local function totalPicked(): number
	local n = 0
	for _, count in pickCounts do
		n += count
	end
	return n
end

-- Actions ----------------------------------------------------------------------------------------------------------

local busy = false
local function act(fn: () -> ())
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local ok, err = pcall(fn)
		busy = false
		if not ok then
			warn("[KaijuHud]", err)
		end
	end)
end

local function say(result)
	if result and result.Message and result.Message ~= "" then
		UiKit.toast(result.Message, if result.Ok then P.Good else P.Gold)
	end
end

-- RENAME: the box in place of its name, SAVE (or Enter) and CANCEL.
function heroUi.setEditing(on: boolean)
	heroUi.Editing = on
	heroUi.Box.Visible, heroUi.Save.Visible, heroUi.Cancel.Visible = on, on, on
	heroUi.Rename.Visible = not on
	heroName.Visible = not on
	if not on then
		pcall(function()
			heroUi.Box:ReleaseFocus()
		end)
	end
end
heroUi.Rename.Activated:Connect(function()
	local data = roster()
	local record = selected and data and data.List[selected]
	if not record then
		return
	end
	heroUi.Box.Text = if type(record.Name) == "string" then record.Name else ""
	heroUi.EditFor = record.Id
	heroUi.setEditing(true)
	pcall(function()
		heroUi.Box:CaptureFocus()
	end)
end)
heroUi.Cancel.Activated:Connect(function()
	heroUi.setEditing(false)
end)
function heroUi.save()
	local target = heroUi.EditFor
	if not heroUi.Editing or not target then
		return
	end
	-- (Its rules here first, the server's filter after: Shared.Kaiju.cleanName.)
	local name, why = Kaiju.cleanName(heroUi.Box.Text)
	if not name then
		UiKit.toast(why or "That isn't a name.", P.Bad)
		return
	end
	act(function()
		local result = GemClient.request("KaijuName", target, name)
		say(result)
		if result and result.Ok then
			heroUi.setEditing(false)
			if window.Gui.Enabled then
				drawPanel()
			end
		end
	end)
end
heroUi.Save.Activated:Connect(heroUi.save)
heroUi.Box.FocusLost:Connect(function(enter: boolean)
	if enter then
		heroUi.save()
	end
end)

-- The panel's list ------------------------------------------------------------------------------------------------

local function clearList()
	keepModels("row:") -- (the rows' models are kept for next time)
	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(rowLive)
end

local function heading(order: number, text: string, note: string)
	local frame = new("Frame", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 18),
	}, listFrame)
	local title = label(frame, text, 11, P.Gold, Enum.Font.GothamBlack)
	title.Size = UDim2.fromScale(0.6, 1)
	local side = label(frame, note, 10, P.Dim, IronUi.Bold)
	side.AnchorPoint, side.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	side.Position, side.Size = UDim2.fromScale(1, 0), UDim2.fromScale(0.5, 1)
end

-- What a row says under its name: its level and where it is.
local function rowStatus(record, slot: number?): (string, Color3)
	if record.Down then
		return string.format("Lv %d  ·  DOWN: REVIVE IT", record.Level), P.Bad:Lerp(P.Text, 0.3)
	elseif slot == Kaiju.SupportSlot then
		return string.format("Lv %d  ·  HEALS YOU", record.Level), SUPPORT
	elseif slot == 1 then
		return string.format("Lv %d  ·  LEADER", record.Level), P.Gold
	elseif slot then
		return string.format("Lv %d  ·  DEPLOYED", record.Level), P.Good
	end
	return string.format("Lv %d  ·  RESERVE", record.Level), P.Dim
end

local function kaijuRow(order: number, record, slot: number?, models)
	local color = elementColor(record.Element)
	local chosen = record.Id == selected or (swapping and record.Id == swapTarget)
	local row = new("TextButton", {
		Name = "Kaiju_" .. record.Id,
		LayoutOrder = order,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if chosen then color:Lerp(INK, 0.72) else P.Inset,
		Size = UDim2.new(1, -8, 0, 76),
	}, listFrame)
	UiKit.round(row, 8)
	new("UIStroke", { Color = color, Thickness = 1.5, Transparency = if chosen then 0 else 1 }, row)
	local view = viewport(row, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(46, 46) })
	UiKit.round(view, 8)
	portrait(view, modelFor("row:" .. record.Id, record))
	if slot then
		-- Its place in the team: 1 leads; the support's a plus.
		local support = slot == Kaiju.SupportSlot
		local badge = new("Frame", {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = if slot == 1 then P.Gold elseif support then SUPPORT else P.Slot,
			ZIndex = 3,
		}, row)
		UiKit.round(badge, 8)
		local n = label(badge, if support then "+" else tostring(slot), if support then 13 else 10, if slot == 1 or support then INK else P.Text, Enum.Font.GothamBlack)
		n.Size, n.TextXAlignment, n.ZIndex = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, 4
	end
	-- Its role, tagged in the role's colour (Shared.KaijuRoles).
	local roleId = KaijuRoles.of(record.Species)
	local roleColor = ROLE_COLORS[roleId] or P.Dim
	local tag = new("Frame", {
		Name = "Role",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 22),
		Size = UDim2.fromOffset(76, 14),
		BackgroundColor3 = roleColor:Lerp(INK, 0.78),
		ZIndex = 3,
	}, row)
	UiKit.round(tag, 4)
	new("UIStroke", { Color = roleColor, Thickness = 1, Transparency = 0.35 }, tag)
	-- (Its symbol at the front, as on its HUD tile: RoleIcons.)
	local roleIcon = require(script.Parent.RoleIcons).draw(tag, roleId, 10, roleColor, 4)
	roleIcon.AnchorPoint, roleIcon.Position = Vector2.new(0, 0.5), UDim2.new(0, 5, 0.5, 0)
	local roleText = label(tag, KaijuRoles.Roles[roleId] and KaijuRoles.Roles[roleId].Name or "", 9, roleColor, IronUi.Bold)
	roleText.Position, roleText.Size = UDim2.fromOffset(14, 0), UDim2.new(1, -16, 1, 0)
	roleText.TextXAlignment, roleText.ZIndex = Enum.TextXAlignment.Center, 4
	if soulUi.upgrade(record, soulUi.Gems or {}) then
		-- (A better gem of its element in your pouch: ENCHANT.)
		local dot = new("Frame", {
			Name = "Upgrade",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = P.Good,
			ZIndex = 3,
		}, row)
		UiKit.round(dot, 4)
	end
	local name = nameLabel(row, Kaiju.nameOf(record), 13, color:Lerp(P.Text, 0.35), IronUi.Bold)
	name.Position, name.Size = UDim2.fromOffset(60, 6), UDim2.new(1, -66, 0, 16)
	local statusText, statusColor = rowStatus(record, slot)
	local status = label(row, statusText, 10, statusColor, IronUi.Bold)
	status.Position, status.Size = UDim2.fromOffset(60, 23), UDim2.new(1, -66, 0, 13)
	local species = Kaiju.species(record.Species)
	local identity = label(row, (species and species.Name or record.Species) .. " / " .. tostring(record.Element), 10, P.Dim, IronUi.Body)
	identity.Position, identity.Size = UDim2.fromOffset(60, 37), UDim2.new(1, -66, 0, 13)
	local live = { Record = record, Slot = slot, Status = status }
	if swapping and slot then
		local cue = label(row, if record.Id == swapTarget then "REPLACING" else "TAP TO REPLACE", 9, P.Gold, IronUi.Bold)
		cue.Position, cue.Size = UDim2.fromOffset(6, 57), UDim2.fromOffset(100, 13)
	end
	-- Its health, out or at home (kept: it never heals on its own).
	local back, fill = bar(row, HEALTH)
	back.Position, back.Size = UDim2.fromOffset(112, 58), UDim2.new(1, -124, 0, 5)
	fill.Size = UDim2.fromScale(healthShare(record, models[record.Id]), 1)
	live.Health = fill
	local expBar, expBarFill = bar(row, EXP)
	expBar.Position, expBar.Size = UDim2.fromOffset(112, 67), UDim2.new(1, -124, 0, 3)
	expBarFill.Size = UDim2.fromScale(expShare(record.Level, record.Exp or 0), 1)
	rowLive[record.Id] = live
	teamsUi.Drag.source(row, record.Id)
	teamsUi.Drag.target(row, record.Id, listFrame, slot == Kaiju.SupportSlot)
	row.Activated:Connect(function()
		if os.clock() < teamsUi.Drag.SuppressUntil then
			return
		end
		if swapping and slot then
			swapTarget = record.Id
		else
			selected = record.Id
			swapping, swapTarget = false, nil
		end
		drawPanel()
	end)
end

local function drawList(data, team: { string })
	clearList()
	local models = petModels()
	local inTeam = {}
	heading(1, if swapping then "CHOOSE REPLACEMENT" else "DEPLOYED TEAM", string.format("%d / %d", #team, Kaiju.slots(data)))
	for slot, id in team do
		inTeam[id] = slot
		kaijuRow(1 + slot, data.List[id], slot, models)
	end
	-- Your support: out with the team, healing you (Kaiju.supportId).
	local supportId = Kaiju.supportId(data)
	if supportId then
		inTeam[supportId] = Kaiju.SupportSlot
		heading(10, "SUPPORT", "HEALS YOU + TEAM")
		kaijuRow(11, data.List[supportId], Kaiju.SupportSlot, models)
	end
	local home = {}
	for id, record in (data and data.List) or {} do
		if not inTeam[id] then
			table.insert(home, record)
		end
	end
	table.sort(home, function(a, b)
		return if a.Level ~= b.Level then a.Level > b.Level else a.Id < b.Id
	end)
	if #home > 0 then
		heading(20, "RESERVES", tostring(#home))
	end
	for i, record in home do
		kaijuRow(20 + i, record, nil, models)
	end
	local note = label(
		listFrame,
		string.format(
			"%d of %d kaiju kept. Catch more in the far quarry: wear one down to half health without killing it.",
			Kaiju.count(data),
			Kaiju.MaxOwned
		),
		10,
		P.Dim,
		IronUi.Body
	)
	note.LayoutOrder = 99
	note.Size = UDim2.new(1, -8, 0, 40)
	note.TextWrapped = true
	note.TextYAlignment = Enum.TextYAlignment.Top
	-- (Prune the models of kaiju you no longer have.)
	for key, entry in built do
		local id = string.match(key, "^row:(.+)$")
		if id and not (data and data.List[id]) then
			entry.Model:Destroy()
			built[key] = nil
		end
	end
end

-- The rows' health and knockouts, as they change.
local function liveRows()
	local models = petModels()
	for id, live in rowLive do
		if live.Health then
			live.Health.Size = UDim2.fromScale(healthShare(live.Record, models[id]), 1)
		end
		local text, color = rowStatus(live.Record, live.Slot)
		live.Status.Text, live.Status.TextColor3 = text, color
	end
end

-- The one picked ---------------------------------------------------------------------------------------------------

local function actionButton(order: number, text: string, color: Color3, width: number, onClick: () -> ())
	local b = smallButton(actionButtons, text, color)
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(width, 34)
	b.Activated:Connect(onClick)
	return b
end

local function drawActions(data, record, team: { string })
	for _, child in actionButtons:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local slot = table.find(team, record.Id)
	local supportId = Kaiju.supportId(data)
	local support = Kaiju.isSupport(record.Species)
	-- (A support goes in the support slot, never one of the team.)
	if swapping and not slot and not support then
		local replacing = swapTarget and data.List[swapTarget]
		local targetSlot = swapTarget and table.find(team, swapTarget)
		actionText.Size = UDim2.new(1, -206, 1, 0)
		actionText.Text = if replacing and targetSlot
			then string.format("%s replaces %s in slot %d.", Kaiju.nameOf(record), Kaiju.nameOf(replacing), targetSlot)
			else "Choose the deployed kaiju to replace from the cards on the left."
		if targetSlot then
			actionButton(1, "CONFIRM", P.Gold, 100, function()
				local incoming, outgoing = record.Id, swapTarget
				act(function()
					local current = roster()
					local ids = Kaiju.teamIds(current)
					local index = table.find(ids, outgoing)
					if not index or table.find(ids, incoming) then
						swapping, swapTarget = false, nil
						UiKit.toast("Your team changed. Choose a replacement again.", P.Gold)
						drawPanel()
						return
					end
					ids[index] = incoming
					local result = GemClient.request("KaijuTeam", ids)
					say(result)
					if result and result.Ok then swapping, swapTarget = false, nil end
					drawPanel()
				end)
			end)
		end
		actionButton(2, "CANCEL", P.Edge, 90, function()
			swapping, swapTarget = false, nil
			drawPanel()
		end)
		return
	end
	actionText.Size = UDim2.new(1, -240, 1, 0)
	if slot == 1 then
		actionText.Text = "Leads your team: the first to fight."
	elseif slot then
		actionText.Text = string.format("Out with you, in place %d of your team.", slot)
		actionButton(1, "LEAD", P.Gold, 100, function()
			act(function()
				say(GemClient.request("KaijuActive", record.Id))
			end)
		end)
	elseif record.Id == supportId then
		actionText.Text = "Your support: it floats behind you and heals you and your team."
	elseif support then
		actionText.Text = "A support: it goes in the support slot, not the team."
		actionButton(1, "SET AS SUPPORT", SUPPORT, 130, function()
			act(function()
				say(GemClient.request("KaijuSupport", record.Id))
			end)
		end)
	else
		actionText.Text = "In reserve. Choose exactly who it replaces."
		actionButton(1, "SWAP IN", P.Teal, 100, function()
			swapping, swapTarget = true, nil
			listFrame.CanvasPosition = Vector2.zero
			drawPanel()
		end)
	end
	if record.Down then
		actionText.Text = string.format("Knocked out: back by itself in %s, or revive it now.", reviveClock(record))
	end
	actionButton(2, if record.Down then "REVIVE" else "HEAL", if record.Down then P.Bad else P.Good, 100, function()
		tab = "Heal"
		pickFresh = true
		drawPanel()
	end)
end

local function drawDetail(data, record, team: { string })
	local color = elementColor(record.Element)
	local species = Kaiju.species(record.Species)
	local soul = record.Soul
	local tier = (soul and soul.Tier) or "Common"
	local tierColor = GemConfig.TierColors[tier] or P.Text
	local slot = table.find(team, record.Id)
	portrait(heroView, modelFor("hero", record))
	heroEdge.Color = color
	heroGlow.Color = ColorSequence.new(color:Lerp(INK, 0.55), INK)
	if heroUi.Editing and heroUi.EditFor ~= record.Id then
		heroUi.setEditing(false)
	end
	local named = type(record.Name) == "string" and record.Name ~= ""
	heroName.Text = heroUi.shown(record)
	heroName.TextColor3 = color:Lerp(P.Text, 0.25)
	heroTag.Text = string.format(
		"%s%s  ·  %s %d  ·  %s",
		if named then string.upper(Kaiju.title(record)) .. "  ·  " else "",
		string.upper(
			(species and KaijuRoles.Roles[species.Role] and KaijuRoles.Roles[species.Role].Name) or (species and species.Role) or ""
		),
		if named then "LV" else "LEVEL",
		record.Level,
		if record.Down then "DOWN"
			elseif slot == 1 then "LEADS"
			elseif slot then "OUT"
			elseif Kaiju.supportId(data) == record.Id then "SUPPORT"
			else "AT HOME"
	)
	local attuned = Kaiju.attuned(record)
	pillText.Text = string.upper(GemConfig.TierLabels[tier] or tier)
		.. " ENCHANT"
		.. (if attuned then "" else "  ·  NOT ITS ELEMENT")
	pillText.TextColor3 = if attuned then tierColor else P.Gold
	pillEdge.Color = if attuned then tierColor else P.Gold
	pill.BackgroundColor3 = tierColor:Lerp(INK, 0.75)
	-- Strong against the element it beats, weak to the one that beats it.
	local beats = heroUi.Beats[record.Element or ""]
	local beatenBy = nil
	for attack, victim in heroUi.Beats do
		if victim == record.Element then
			beatenBy = attack
		end
	end
	for key, element in { Strong = beats, Weak = beatenBy } do
		local chip = heroUi[key]
		chip.Chip.Visible = element ~= nil
		if element then
			local c = elementColor(element)
			chip.Text.Text = string.upper(
				string.format("%s %s", if key == "Strong" then "Strong vs" else "Weak to", GemConfig.elementName(element))
			)
			chip.Text.TextColor3 = c:Lerp(P.Text, 0.2)
			chip.Edge.Color = c
			chip.Chip.BackgroundColor3 = c:Lerp(INK, 0.82)
		end
	end
	soulBadge.Visible = soul ~= nil
	soulEdge.Color = tierColor
	local soulKey = soul and (soul.Id or record.Id) or nil
	if soulArt ~= soulKey then
		soulArt = soulKey
		for _, child in soulBadge:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		if soul then
			pcall(GemArt.viewport, soulBadge, soul, true)
		end
	end
	heroBlurb.Text = if species then species.Blurb else ""
	local traits = Kaiju.traits(record)
	if traits then
		local grade = Kaiju.grade(traits)
		heroUi.TraitChips.Grade.Text.Text = "Grade " .. grade
		heroUi.TraitChips.Grade.Chip.BackgroundColor3 = heroUi.TraitColors[grade] or P.Gold
		for _, name in Kaiju.Traits.Names do
			local chip = heroUi.TraitChips[name]
			local n = traits[name]
			chip.Text.Text = string.format("%s %d", name, n)
			-- (over Mid green, under it red, about Mid plain)
			chip.Text.TextColor3 = if n >= Kaiju.Traits.Mid + 4
				then P.Good
				elseif n <= Kaiju.Traits.Mid - 4 then heroUi.TraitColors.Low
				else P.Text
		end
	end
	local stats = Kaiju.recordStats(record)
	if stats then
		-- (Its health as it is: kept, out or home, none while it's down.)
		local most = math.floor(stats.Health + 0.5)
		local now = math.floor(healthShare(record, petModels()[record.Id]) * most + 0.5)
		statValues[1].Text = if now < most then string.format("%d/%d", now, most) else tostring(most)
		statValues[2].Text = tostring(math.floor(stats.Damage + 0.5))
		statValues[3].Text = tostring(math.floor(stats.Speed + 0.5))
	end
	local need = Kaiju.expToNext(record.Level)
	expText.Text = if need == math.huge
		then string.format("EXP %d / MAX", record.Exp or 0)
		else string.format("EXP %d / %d", record.Exp or 0, need)
	expFill.Size = UDim2.fromScale(expShare(record.Level, record.Exp or 0), 1)
	for key, row in moveRows do
		-- (Its own moves, its role's: Kaiju.kitMove. And its gem's move from
		-- the start: a fighter's gem surge, its enchant's E; a support's, its
		-- enchant's R, on you and itself: Kaiju.gemMove.)
		local gem = key == "Gem"
		local support = Kaiju.isSupport(record.Species)
		local id, awake
		if gem then
			id = Kaiju.gemMove(record)
			awake = id ~= nil
		else
			id, awake = Kaiju.kitMove(record.Species, key, record.Level)
		end
		local move = Kaiju.moveInfo(id)
		row.Name.Text = if gem and not id then (if support then "No gem R" else "No gem surge") else moveName(id)
		row.Name.TextColor3 = if awake then P.Text else P.Dim
		row.About.Text = if gem and not id
			then string.format(
				"Its enchant isn't its element: enchant it with %s %s gem (ENCHANT).",
				Kaiju.article(GemConfig.elementName(record.Element)),
				GemConfig.elementName(record.Element)
			)
			elseif gem and support then "On you and on itself, when you're worn in a fight: a shield or ward on you both, a mend for you both, or a ring round you."
			else move and move.Description or ""
		row.Chip.BackgroundColor3 = if awake then color else INK
		row.ChipEdge.Transparency = if awake then 1 else 0
		row.Letter.TextColor3 = if awake then INK else P.Dim
		-- Its icon (hollow and greyed while it sleeps), the key on its corner.
		local ok, drawn = pcall(SurgeIcons.apply, row.Chip, move, color)
		drawn = ok and drawn
		if drawn then
			pcall(SurgeIcons.dim, row.Chip, not awake)
		end
		row.Letter.Visible = not drawn
		row.Badge.Visible = drawn
		row.Badge.BackgroundColor3 = if awake then color else INK
		row.BadgeLetter.TextColor3 = if awake then INK else P.Dim
		row.Edge.Color = if awake then color else P.Edge
		row.Edge.Transparency = if awake then 0.45 else 0.7
		row.Frame.BackgroundColor3 = if awake then color:Lerp(INK, 0.82) else P.Inset
		row.State.Text = if gem and support
			then "GEM R"
			elseif gem then "GEM SURGE"
			elseif awake then "READY"
			else string.format("WAKES AT LV %d", Kaiju.MoveLevels[key] or 1)
		row.State.TextSize = if awake then 10 else 9
		-- (The gem surge in its enchant's rarity.)
		row.State.TextColor3 = if gem then tierColor elseif awake then P.Good else P.Dim
	end
	drawActions(data, record, team)
end

-- A stack's card in HEAL (kept between draws: its gem is a 3D view).
local stackCards: { [string]: any } = {}
local function stackCard(key: string)
	local entry = stackCards[key]
	if entry then
		return entry
	end
	local b = new("TextButton", {
		Name = "Gems_" .. key,
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = P.Inset,
	}, stackList)
	UiKit.round(b, 10)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1.5, Transparency = 0.25 }, b)
	local art = new("Frame", {
		Name = "Gem",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 5),
		Size = UDim2.fromOffset(46, 46),
	}, b)
	local have = label(b, "", 12, P.Text, IronUi.Bold)
	have.AnchorPoint, have.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	have.Position, have.Size = UDim2.new(1, -8, 0, 5), UDim2.fromOffset(60, 15)
	local gain = label(b, "", 17, HEALTH, Enum.Font.GothamBlack)
	gain.AnchorPoint, gain.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	gain.Position, gain.Size = UDim2.new(1, -8, 0, 20), UDim2.fromOffset(70, 20)
	local each = label(b, "EACH", 9, P.Dim, IronUi.Bold)
	each.AnchorPoint, each.TextXAlignment = Vector2.new(1, 0), Enum.TextXAlignment.Right
	each.Position, each.Size = UDim2.new(1, -8, 0, 40), UDim2.fromOffset(80, 11)
	local kind = label(b, "", 10, P.Dim, IronUi.Bold)
	kind.Position, kind.Size = UDim2.fromOffset(8, 53), UDim2.new(1, -16, 0, 12)
	local pill = new("Frame", {
		BackgroundColor3 = P.Good,
		Position = UDim2.fromOffset(8, 66),
		Size = UDim2.fromOffset(70, 15),
		Visible = false,
	}, b)
	UiKit.round(pill, 7)
	local pillLabel = label(pill, "", 9, INK, Enum.Font.GothamBlack)
	pillLabel.Size, pillLabel.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	local minus = smallButton(b, "-", P.Bad)
	minus.Name = "Less"
	minus.AnchorPoint = Vector2.new(1, 0)
	minus.Position, minus.Size = UDim2.new(1, -8, 0, 64), UDim2.fromOffset(30, 18)
	minus.TextSize = 15
	minus.Visible = false
	entry = {
		Button = b,
		Edge = edge,
		Art = art,
		ArtId = nil :: string?,
		Have = have,
		Gain = gain,
		Each = each,
		Kind = kind,
		Pill = pill,
		PillLabel = pillLabel,
		Minus = minus,
		Stack = nil :: any,
	}
	b.Activated:Connect(function()
		local stack = entry.Stack
		local n = pickCounts[key] or 0
		if stack and n < #stack.Gems and totalPicked() < Kaiju.Infuse.Batch then
			pickCounts[key] = n + 1
			manual = true
			drawPanel()
		end
	end)
	minus.Activated:Connect(function()
		local n = pickCounts[key] or 0
		if n > 0 then
			pickCounts[key] = if n > 1 then n - 1 else nil
			manual = true
			drawPanel()
		end
	end)
	stackCards[key] = entry
	return entry
end

-- A heal's share as the HEAL tab shows it: 7.5%, 15%, 30% (to the half).
local function percent(value: number): string
	local half = math.floor(value * 2 + 0.5) / 2
	return if half % 1 == 0 then string.format("%d%%", half) else string.format("%.1f%%", half)
end

local function drawHeal(record)
	record = liveRecord(record)
	local down = record.Down == true
	local now, most = Kaiju.health(record)
	local full = not down and now >= most - 0.5
	local stacks = healStacks(record)
	-- Picked for you: your spare Commons, as many as bring it to full (or
	-- back, if it's down: Kaiju.healPick). Again whenever its health changes,
	-- unless you've picked your own.
	local sig = record.Id .. (if down then "/down" else "/" .. math.floor(now))
	local suggested = Kaiju.healPick(record, spareCommons, true)
	if pickFresh or pickFor ~= record.Id or (pickSig ~= sig and not manual) then
		pickFresh, pickFor, pickSig, manual = false, record.Id, sig, false
		table.clear(pickCounts)
		for _, gem in suggested do
			local key = stackKey(gem)
			pickCounts[key] = (pickCounts[key] or 0) + 1
		end
	end
	if full then
		table.clear(pickCounts)
	end
	-- The cards, in order, and what's picked of each.
	local seen, chosen = {}, {}
	for order, stack in stacks do
		seen[stack.Key] = true
		local n = math.min(pickCounts[stack.Key] or 0, #stack.Gems)
		pickCounts[stack.Key] = if n > 0 then n else nil
		for i = 1, n do
			table.insert(chosen, stack.Gems[i])
		end
		local c = stackCard(stack.Key)
		c.Stack = stack
		c.Button.LayoutOrder = order
		local shown = stack.Gems[1]
		if c.ArtId ~= shown.Id then
			c.ArtId = shown.Id
			for _, child in c.Art:GetChildren() do
				child:Destroy()
			end
			pcall(GemArt.viewport, c.Art, shown, false)
		end
		c.Have.Text = "×" .. #stack.Gems
		local base = Kaiju.Infuse.Power[stack.Tier] or Kaiju.Infuse.Power.Common
		c.Gain.Text = if down
			then string.format("+%g", stack.Power)
			else "+" .. percent(stack.Power * Kaiju.Infuse.Mend * 100)
		c.Gain.TextColor3 = if stack.Power > base then P.Gold elseif stack.Power < base then P.Dim else HEALTH
		c.Each.Text = if down then "POWER EACH" else "EACH"
		c.Kind.Text = string.upper(
			GemConfig.elementName(stack.Element) .. " · " .. (GemConfig.TierLabels[stack.Tier] or stack.Tier)
		)
		c.Kind.TextColor3 = (GemConfig.TierColors[stack.Tier] or P.Dim):Lerp(P.Text, 0.15)
		c.Pill.Visible, c.Minus.Visible = n > 0, n > 0
		c.PillLabel.Text = string.format("%d PICKED", n)
		c.Edge.Color = if n > 0 then P.Good else elementColor(stack.Element):Lerp(P.Edge, 0.5)
		c.Edge.Thickness = if n > 0 then 2 else 1.5
		c.Button.BackgroundColor3 = if n > 0 then P.Good:Lerp(INK, 0.8) else P.Inset
	end
	for key, c in stackCards do
		if not seen[key] then
			c.Button:Destroy()
			stackCards[key] = nil
		end
	end
	for key in pickCounts do
		if not seen[key] then
			pickCounts[key] = nil
		end
	end
	-- The strongest first, so the heal spends the fewest.
	table.sort(chosen, function(a, b)
		local pa, pb = Kaiju.infusePower(a, record), Kaiju.infusePower(b, record)
		return if pa ~= pb then pa > pb else a.Id < b.Id
	end)
	local plan = Kaiju.infusePlan(record, chosen)
	local share = math.floor(plan.Health / math.max(1, most) * 100 + 0.5)
	-- (Out beside you in a fight: no healing till it's over, KaijuDanger.)
	local fighting = not down and player:GetAttribute("KaijuDanger") == true and petModels()[record.Id] ~= nil
	stackList.Visible, reviveCard.Visible = not down, down
	-- The head: its name, its health now and (lighter) after.
	healName.Text = string.format("%s  ·  LV %d", heroUi.shown(record), record.Level)
	healName.TextColor3 = elementColor(record.Element):Lerp(P.Text, 0.3)
	if down then
		local wait = Kaiju.reviveSeconds(record)
		local left = Kaiju.reviveIn(record, workspace:GetServerTimeNow())
		healNumbers.Text = "KNOCKED OUT"
		healNumbers.TextColor3 = P.Bad:Lerp(P.Text, 0.3)
		healNow.Size = UDim2.fromScale(0, 1)
		healAfter.Size = UDim2.fromScale(math.clamp(1 - left / math.max(1, wait), 0, 1), 1)
		healAfter.BackgroundColor3 = P.Gold
		healBarText.Text = "BACK IN " .. reviveClock(record)
	else
		healNumbers.Text = string.format("%d / %d HEALTH", math.floor(now + 0.5), most)
		healNumbers.TextColor3 = P.Text
		healNow.Size = UDim2.fromScale(math.clamp(now / math.max(1, most), 0, 1), 1)
		healNow.BackgroundColor3 = if now / math.max(1, most) < 0.3 then P.Bad else HEALTH
		healAfter.Size = UDim2.fromScale(math.clamp(plan.Health / math.max(1, most), 0, 1), 1)
		healAfter.BackgroundColor3 = HEALTH
		healBarText.Text = ""
	end
	local on = Kaiju.autoHealOn(roster())
	healHint.Text = if down
		then "Gems and AUTO HEAL don't bring back one that's knocked out."
		elseif on then "AUTO HEAL is on: your spare Commons, then Uncommons, heal your team between fights."
		else "Switch on AUTO HEAL by your team and your spare Commons, then Uncommons, heal them by themselves."
	healHint.TextColor3 = if on and not down then P.Good else P.Dim
	if down then
		-- Knocked out: back by itself, or REVIVE (Robux) or COUPON now.
		local coupons = Coupons.count(GemClient.Profile, "Revive")
		local onSale = (Store.RobuxProducts.KaijuRevive or 0) ~= 0 or Store.testPrice("KaijuRevive") ~= nil
		reviveTime.Text = reviveClock(record)
		reviveLine.Text = string.format(
			"It comes back weak, at %d%% health: heal it with gems.",
			math.floor(Kaiju.Revive.Health * 100 + 0.5)
		)
		reviveCoupon.Text = if coupons > 0
			then string.format("You have %d Revive coupon%s: COUPON brings it back free.", coupons, if coupons == 1 then "" else "s")
			elseif Coupons.Enabled then "Invite a friend: a free Revive coupon for each one who joins."
			else ""
		healSummary.Text = "Knocked out"
		healNote.Text = "Revive now: every one of yours that's down, back at once, at half health."
		healReady = onSale
		healChosen = {}
		healButton.Text = if onSale then "REVIVE  ·  R$ " .. tostring(Store.robuxPrice("KaijuRevive") or 0) else "COMING SOON"
		healButton.AutoButtonColor = onSale
		healButton.BackgroundColor3 = P.Gold:Lerp(INK, if onSale then 0.3 else 0.78)
		healButton.TextColor3 = if onSale then P.Text else P.Dim
		resetButton.Text = string.format("COUPON ×%d", coupons)
		resetButton.Visible = coupons > 0
		return
	end
	-- Under the gems: what the heal does, and HEAL.
	if #stacks == 0 then
		healSummary.Text = "No gems in your pouch"
		healNote.Text = "Mine some: every rock pays a gem."
	elseif full then
		healSummary.Text = "Full health"
		healNote.Text = "Nothing to heal."
	elseif #chosen == 0 then
		healSummary.Text = "Tap your gems to pick them"
		healNote.Text = "A gem of its own element heals double, its weakness half."
	else
		healSummary.Text = string.format(
			"%s  ·  %s %d%%",
			if #plan.Used < #chosen
				then string.format("%d of %d gems", #plan.Used, #chosen)
				else string.format("%d gem%s", #plan.Used, if #plan.Used == 1 then "" else "s"),
			"heals to",
			share
		)
		healNote.Text = if manual
			then "A gem of its own element heals double, its weakness half."
			else "Picked for you from your spare Commons. Tap a gem for one more, - for one less."
	end
	if fighting and not full then
		healNote.Text = "In a fight: get clear of the critters to heal."
	end
	healReady = not full and #chosen > 0 and not fighting
	healChosen = chosen
	healButton.Text = if full then "FULL" elseif fighting then "IN A FIGHT" else "HEAL"
	healButton.AutoButtonColor = healReady
	healButton.BackgroundColor3 = P.Good:Lerp(INK, if healReady then 0.3 else 0.78)
	healButton.TextColor3 = if healReady then P.Text else P.Dim
	resetButton.Text = if next(pickCounts) then "CLEAR" else "AUTO PICK"
	resetButton.Visible = #stacks > 0 and not full and (next(pickCounts) ~= nil or #suggested > 0)
end

-- ENCHANT's rows (kept between draws: their gems are 3D views), the one
-- picked, and for whom.
soulUi.soulCards = {}

-- Where each element's gems turn up most: out in its biome, by its look
-- (Shared.Frontier.Biomes).
soulUi.Find = {
	Fire = "the burnt ground",
	Frost = "the snow fields",
	Shock = "the salt flats",
	Poison = "the mud flats",
}

local function round(n: number): number
	return math.floor(n + 0.5)
end

-- A rarity's stat bonus, in whole percent (Kaiju.SoulBonus).
function soulUi.bonus(tier: string?): number
	return round(((Kaiju.SoulBonus[tier or "Common"] or 1) - 1) * 100)
end

-- A row for each rarity of its element, rarest first: the finest of yours
-- of it (any loose gem, a kaiju's dropped enchant too) and how many you
-- have, or none.
function soulUi.soulStacks(record)
	local byTier = {}
	for _, gem in GemInventory.available(GemClient.Profile) do
		if gem.Element == record.Element then
			local tier = gem.Tier or "Common"
			local ok, value = pcall(GemConfig.value, gem)
			value = if ok and type(value) == "number" then value else 0
			local stack = byTier[tier]
			if not stack then
				stack = { Key = tier, Tier = tier, Gem = gem, Value = value, Count = 0 }
				byTier[tier] = stack
			end
			stack.Count += 1
			if value > stack.Value then
				stack.Gem, stack.Value = gem, value
			end
		end
	end
	local rows = {}
	for i = #GemConfig.TierOrder, 1, -1 do
		local tier = GemConfig.TierOrder[i]
		table.insert(rows, byTier[tier] or { Key = tier, Tier = tier, Count = 0 })
	end
	return rows
end

-- Whether you've a gem that would make `record` stronger: one of its
-- element rarer than its enchant, or any of its element when its enchant
-- isn't. (`gems`: your loose gems, GemInventory.available.)
function soulUi.upgrade(record, gems): boolean
	if not record then
		return false
	end
	local attuned = Kaiju.attuned(record)
	local now = soulUi.bonus(record.Soul and record.Soul.Tier)
	for _, gem in gems do
		if gem.Element == record.Element and (not attuned or soulUi.bonus(gem.Tier) > now) then
			return true
		end
	end
	return false
end

function soulUi.soulCard(key: string)
	local entry = soulUi.soulCards[key]
	if entry then
		return entry
	end
	local tall = if SHORT then 40 else 42
	local b = new("TextButton", {
		Name = "Enchant_" .. key,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = P.Inset,
		Size = UDim2.new(1, -6, 0, tall),
	}, soulUi.soulList)
	UiKit.round(b, 8)
	local edge = new("UIStroke", { Color = P.Edge, Thickness = 1.2, Transparency = 0.4 }, b)
	local art = new("Frame", {
		Name = "Gem",
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.35,
		Position = UDim2.fromOffset(5, 4),
		Size = UDim2.fromOffset(tall - 8, tall - 8),
	}, b)
	UiKit.round(art, 6)
	local x = tall + 4
	local title = label(b, "", 13, P.Text, Enum.Font.GothamBlack)
	title.Position, title.Size = UDim2.fromOffset(x, if SHORT then 3 else 4), UDim2.new(1, -x - 124, 0, 17)
	local sub = label(b, "", 10, P.Dim, IronUi.Bold)
	sub.Position, sub.Size = UDim2.fromOffset(x, if SHORT then 21 else 23), UDim2.new(1, -x - 124, 0, 13)
	local delta = new("Frame", {
		Name = "Versus",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(108, 22),
		BackgroundColor3 = P.Good,
	}, b)
	UiKit.round(delta, 11)
	local deltaText = label(delta, "", 10, INK, Enum.Font.GothamBlack)
	deltaText.Size, deltaText.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	entry = {
		Button = b,
		Edge = edge,
		Art = art,
		ArtId = nil :: string?,
		Title = title,
		Sub = sub,
		Delta = delta,
		DeltaText = deltaText,
		Have = false,
	}
	b.Activated:Connect(function()
		if entry.Have then
			soulUi.soulPick = key
			drawPanel()
		end
	end)
	soulUi.soulCards[key] = entry
	return entry
end

function soulUi.drawSoul(record)
	record = liveRecord(record)
	local soul = record.Soul
	local tier = (soul and soul.Tier) or "Common"
	local tierColor = GemConfig.TierColors[tier] or P.Text
	local color = elementColor(record.Element)
	local own = GemConfig.elementName(record.Element)
	local attuned = Kaiju.attuned(record)
	local percent = round((Kaiju.Attuned.Power - 1) * 100)
	-- The one in it now: its rarity, what it gives, its surge, its stats.
	soulUi.soulHead.BackgroundColor3 = color:Lerp(P.Inset, 0.86)
	soulUi.soulHeadName.Text = string.upper(
		string.format(
			"%s %s enchant",
			GemConfig.TierLabels[tier] or tier,
			GemConfig.elementName(soul and soul.Element or record.Element)
		)
	)
	soulUi.soulHeadName.TextColor3 = tierColor
	soulUi.soulHeadEdge.Color = if attuned then color else P.Gold
	local surge = Kaiju.gemMove(record)
	soulUi.soulHeadLine.Text = if attuned
		then string.format(
			if Kaiju.isSupport(record.Species)
				then "+%d%% stats  ·  +%d%% damage  ·  Gem R: %s"
				else "+%d%% stats  ·  +%d%% damage  ·  Gem surge: %s",
			soulUi.bonus(tier),
			percent,
			moveName(surge)
		)
		else string.format("Not its element: no gem surge. Enchant it with %s %s gem.", Kaiju.article(own), own)
	soulUi.soulHeadLine.TextColor3 = if attuned then P.Good else P.Gold
	local stats = Kaiju.recordStats(record)
	soulUi.soulHeadStats.Text = if stats
		then string.format("Health %d  ·  Damage %d  ·  Speed %d", round(stats.Health), round(stats.Damage), round(stats.Speed))
		else ""
	local soulKey = soul and (soul.Id or record.Id) or nil
	if soulUi.soulHeadArtId ~= soulKey then
		soulUi.soulHeadArtId = soulKey
		for _, child in soulUi.soulHeadArt:GetChildren() do
			child:Destroy()
		end
		if soul then
			pcall(GemArt.viewport, soulUi.soulHeadArt, soul, true)
		end
	end
	soulUi.soulHint.Text = string.format("Only %s gems can enchant %s %s kaiju.", own, Kaiju.article(own), own)
	soulUi.soulHint.TextColor3 = color:Lerp(P.Text, 0.3)
	-- A row for each rarity of its element. (The best upgrade you have is
	-- picked when you come to it.)
	local rows = soulUi.soulStacks(record)
	if soulUi.soulPickFor ~= record.Id then
		soulUi.soulPickFor, soulUi.soulPick = record.Id, nil
		for _, row in rows do
			if row.Gem and (not attuned or soulUi.bonus(row.Tier) > soulUi.bonus(tier)) then
				soulUi.soulPick = row.Key
				break
			end
		end
	end
	soulUi.soulChosen = nil
	local have = 0
	for order, row in rows do
		local c = soulUi.soulCard(row.Key)
		c.Button.LayoutOrder = order
		c.Have = row.Gem ~= nil
		local rowColor = GemConfig.TierColors[row.Tier] or P.Text
		c.Title.Text = string.upper(GemConfig.TierLabels[row.Tier] or row.Tier)
		c.Title.TextColor3 = if row.Gem then rowColor else rowColor:Lerp(INK, 0.55)
		local artId = row.Gem and row.Gem.Id or nil
		if c.ArtId ~= artId then
			c.ArtId = artId
			for _, child in c.Art:GetChildren() do
				if not child:IsA("UICorner") then
					child:Destroy()
				end
			end
			if row.Gem then
				pcall(GemArt.viewport, c.Art, row.Gem, false)
			end
		end
		c.Delta.Visible = row.Gem ~= nil
		if row.Gem then
			have += 1
			local would = Kaiju.enchanted(record, row.Gem)
			c.Sub.Text = string.format(
				if Kaiju.isSupport(record.Species) then "×%d  ·  +%d%% stats  ·  Gem R: %s" else "×%d  ·  +%d%% stats  ·  Surge: %s",
				row.Count,
				soulUi.bonus(row.Tier),
				moveName(would and would.Surge)
			)
			c.Sub.TextColor3 = P.Dim
			local diff = soulUi.bonus(row.Tier) - soulUi.bonus(tier)
			if not attuned then
				c.DeltaText.Text, c.Delta.BackgroundColor3 = "+ ITS SURGE", P.Good
			elseif diff > 0 then
				c.DeltaText.Text, c.Delta.BackgroundColor3 = string.format("%d%% STRONGER", diff), P.Good
			elseif diff < 0 then
				c.DeltaText.Text, c.Delta.BackgroundColor3 = string.format("%d%% WEAKER", -diff), P.Bad:Lerp(P.Text, 0.15)
			else
				c.DeltaText.Text, c.Delta.BackgroundColor3 = "SAME AS NOW", P.Edge:Lerp(P.Text, 0.25)
			end
		else
			c.Sub.Text = "None in your pouch"
			c.Sub.TextColor3 = P.Dim:Lerp(INK, 0.35)
		end
		local picked = soulUi.soulPick == row.Key and row.Gem ~= nil
		c.Edge.Color = if picked then P.Gold elseif row.Gem then rowColor:Lerp(P.Edge, 0.45) else P.Edge
		c.Edge.Thickness = if picked then 2.5 else 1.2
		c.Edge.Transparency = if picked then 0 elseif row.Gem then 0.25 else 0.7
		c.Button.BackgroundColor3 = if picked then P.Gold:Lerp(INK, 0.8) else P.Inset
		c.Button.BackgroundTransparency = if row.Gem then 0 else 0.5
		c.Button.AutoButtonColor = row.Gem ~= nil
		if picked then
			soulUi.soulChosen = row.Gem
		end
	end
	-- What ENCHANT would do.
	local fighting = player:GetAttribute("KaijuDanger") == true
	local chosen = soulUi.soulChosen
	if chosen then
		local after = (Kaiju.enchanted(record, chosen) or {}).Stats
		soulUi.soulSummary.Text = string.format("%s %s gem", GemConfig.TierLabels[chosen.Tier] or chosen.Tier, own)
		soulUi.soulNote.Text = if stats and after
			then string.format(
				"Health %d to %d  ·  Damage %d to %d. Its enchant now goes back to your pouch.",
				round(stats.Health),
				round(after.Health),
				round(stats.Damage),
				round(after.Damage)
			)
			else "Its enchant now goes back to your pouch."
	elseif have == 0 then
		soulUi.soulSummary.Text = string.format("No %s gems yet", own)
		soulUi.soulNote.Text = string.format("%s gems turn up most out in %s.", own, soulUi.Find[record.Element] or "the quarry")
	else
		soulUi.soulSummary.Text = "Pick a gem"
		soulUi.soulNote.Text = "The rarer the gem, the stronger it gets."
	end
	if fighting then
		soulUi.soulNote.Text = "In a fight: get clear of the critters to change its enchant."
	end
	local ready = chosen ~= nil and not fighting
	soulUi.soulButton.Text = if fighting then "IN A FIGHT" else "ENCHANT"
	soulUi.soulButton.AutoButtonColor = ready
	soulUi.soulButton.BackgroundColor3 = P.Gold:Lerp(INK, if ready then 0.3 else 0.78)
	soulUi.soulButton.TextColor3 = if ready then P.Text else P.Dim
end

soulUi.soulButton.Activated:Connect(function()
	local target, gem = selected, soulUi.soulChosen
	if not target or not gem or player:GetAttribute("KaijuDanger") == true then
		return
	end
	act(function()
		local result = GemClient.request("KaijuSocket", target, gem.Id)
		say(result)
		if result and result.Ok then
			soulUi.soulPick, soulUi.soulPickFor = nil, nil
			if window.Gui.Enabled then
				drawPanel()
			end
		end
	end)
end)

function drawPanel()
	local data = roster()
	local team = Kaiju.teamIds(data)
	if not (selected and data and data.List[selected]) then
		selected = team[1]
	end
	local record = selected and data.List[selected]
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == tab then P.Gold:Lerp(INK, 0.15) else P.Gold:Lerp(INK, 0.8)
		b.TextColor3 = if name == tab then INK else P.Text
	end
	soulUi.Gems = GemInventory.available(GemClient.Profile)
	if soulUi.TabDot then
		soulUi.TabDot.Visible = soulUi.upgrade(record, soulUi.Gems)
	end
	drawList(data, team)
	detail.Visible = tab == "Details" and record ~= nil
	healPane.Visible = tab == "Heal" and record ~= nil
	soulUi.soulPane.Visible = tab == "Soul" and record ~= nil
	teamsUi.Pane.Visible = tab == "Teams" and data ~= nil
	-- (TEAMS takes the panel's whole width: no list beside it.)
	local wide = tab == "Teams" and data ~= nil
	listFrame.Visible = not wide
	right.Position = if wide then UDim2.new() else UDim2.fromOffset(LIST_W + 14, 0)
	right.Size = if wide then UDim2.fromScale(1, 1) else UDim2.new(1, -(LIST_W + 14), 1, 0)
	if tab == "Teams" and data then
		teamsUi.draw(data)
		if record then
			portrait(heroView, nil)
		end
		return
	end
	if not record then
		portrait(heroView, nil)
		return
	end
	if tab == "Heal" then
		drawHeal(record)
	elseif tab == "Soul" then
		soulUi.drawSoul(record)
	else
		drawDetail(data, record, team)
	end
end

-- Your knocked-out kaiju back now: Roblox's purchase prompt for the
-- KaijuRevive product (the revive comes with the receipt: StoreServer), or
-- coins while testing (the store's BuyProduct).
local function buyRevive()
	local productId = Store.RobuxProducts.KaijuRevive or 0
	if productId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, productId)
		return
	end
	if not Store.testPrice("KaijuRevive") then
		UiKit.toast("Coming soon: revives aren't on sale yet.", P.Dim)
		return
	end
	act(function()
		say(GemClient.request("BuyProduct", "KaijuRevive"))
	end)
end
MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
	if purchased and userId == player.UserId and Store.productKey(productId) == "KaijuRevive" then
		-- (The receipt lands a moment after the prompt closes.)
		task.delay(1, function()
			UiKit.toast("Your kaiju are back on their feet!", P.Good)
		end)
	end
end)

local function selectedDown(): boolean
	local data = roster()
	local record = selected and data and data.List[selected]
	return record ~= nil and record.Down == true
end

resetButton.Activated:Connect(function()
	if selectedDown() then
		act(function()
			say(GemClient.request("UseCoupon", "Revive"))
		end)
		return
	end
	if next(pickCounts) then
		table.clear(pickCounts)
		manual = true
	else
		pickFresh = true
	end
	drawPanel()
end)

healButton.Activated:Connect(function()
	local target = selected
	if selectedDown() then
		if healReady then
			buyRevive()
		end
		return
	end
	if not healReady or #healChosen == 0 or not target then
		return
	end
	local ids = {}
	for _, gem in healChosen do
		table.insert(ids, gem.Id)
	end
	act(function()
		local result = GemClient.request("KaijuInfuse", ids, target)
		say(result)
		if result and result.Ok then
			pickFresh = true
			if window.Gui.Enabled then
				drawPanel()
			end
		end
	end)
end)

function KaijuHud.open(id: string?, onTab: string?)
	tab = if onTab == "Heal" or onTab == "Infuse"
		then "Heal"
		elseif onTab == "Soul" or onTab == "Enchant" then "Soul"
		elseif onTab == "Teams" or (onTab == nil and id == nil) then "Teams"
		else "Details"
	swapping = false
	pickFresh = true
	selected = id
	teamsUi.Pick = nil
	drawPanel()
	window.Gui.Enabled = true
end

-- In a fight or out of it (KaijuDanger): HEAL follows.
player:GetAttributeChangedSignal("KaijuDanger"):Connect(function()
	if window.Gui.Enabled and (tab == "Heal" or tab == "Soul") then
		drawPanel()
	end
end)

-- The revive countdown, while it's on screen.
local function tickRevive()
	if not (window.Gui.Enabled and reviveCard.Visible and healPane.Visible) then
		return
	end
	local data = roster()
	local record = selected and data and data.List[selected]
	if record and record.Down then
		reviveTime.Text = reviveClock(record)
		healBarText.Text = "BACK IN " .. reviveClock(record)
		local left = Kaiju.reviveIn(record, workspace:GetServerTimeNow())
		healAfter.Size = UDim2.fromScale(math.clamp(1 - left / math.max(1, Kaiju.reviveSeconds(record)), 0, 1), 1)
	end
end

countCommons()
GemClient.Changed:Connect(function()
	countCommons()
	if window.Gui.Enabled then
		-- (The pouch or the roster changed: HEAL's picks are trimmed to what's left.)
		drawPanel()
	end
end)

-- The strip, the roll and TAME --------------------------------------------------------------------------------------

-- The wild kaiju you could try to tame now: the weakest near you.
local catchCooldowns = setmetatable({}, { __mode = "k" })
local function tameTarget(): (Model?, number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local enemies = workspace:FindFirstChild("Enemies")
	if not root or not enemies then
		return nil, 0
	end
	local body = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local data = GemClient.Profile and GemClient.Profile.Kaiju
	if not body or body.Health <= 0 or not data or Kaiju.count(data) >= Kaiju.MaxOwned then
		return nil, 0
	end
	local best, bestChance = nil, 0
	for _, model in enemies:GetChildren() do
		if model:IsA("Model") and KaijuTaming.ready(model) and os.clock() >= (catchCooldowns[model] or 0) then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local body = model.PrimaryPart
			if humanoid and body and (body.CFrame.Position - root.CFrame.Position).Magnitude <= TAME_RANGE then
				local chance = Kaiju.tameChance(humanoid.Health, humanoid.MaxHealth)
				if chance > bestChance then
					best, bestChance = model, chance
				end
			end
		end
	end
	return best, bestChance
end

local tameModel: Model? = nil
local wantShown = false

local function refresh()
	local profile = GemClient.Profile
	local data = profile and profile.Kaiju
	local team = Kaiju.teamIds(data)
	local inOutpost = OutpostScene.isActive() and player:GetAttribute("Outpost") == true
	local blocked = player.PlayerGui:FindFirstChild("Intro") ~= nil
		or KaijuRoll.showing()
		or player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	local menu = dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled or player:GetAttribute("MenuOpen") == true
	-- The starter roll is Wren's, at the Kennel (Dialogue: the free roll):
	-- a word about it once a visit, once they're in the Outpost and free.
	if not heroUi.WrenTold and inOutpost and not blocked and not menu and Kaiju.rollsOwed(profile) > 0
		and not LoadingFlow.active() and player:GetAttribute("IntroCover") ~= true then
		heroUi.WrenTold = true
		task.delay(4, function()
			UiKit.toast("Free kaiju: see Wren at the Kaiju Kennel to roll your first team.", Color3.fromRGB(124, 214, 98))
		end)
	end
	-- A boss roll (one kaiju for each boss beaten: Kaiju.bossRollsOwed),
	-- each in turn, once you're back in the Outpost with nothing over it.
	if not heroUi.BossRolling and inOutpost and not blocked and not menu and Kaiju.bossRollsOwed(profile) > 0
		and not LoadingFlow.active() and os.clock() >= (heroUi.BossRollAt or 0) then
		heroUi.BossRolling = true
		heroUi.BossRollAt = os.clock() + 4 -- (a beat between two, and no hammering if it fails)
		task.spawn(KaijuRoll.play, function()
			heroUi.BossRolling = false
		end)
	end
	if window.Gui.Enabled then
		liveRows()
	end
	wantShown = #team > 0 and inOutpost and not blocked and not menu
	gui.Enabled = wantShown
	if not wantShown then
		tameModel, tame.Visible = nil, false
		return
	end
	local models = petModels()
	local supportId = Kaiju.supportId(data)
	for slot, tile in tiles do
		local id = if slot == Kaiju.SupportSlot then supportId else team[slot]
		local record = id and data.List[id]
		tile.Button.Visible = record ~= nil
		if record then
			drawTile(tile, record, models[id], slot == 1)
		end
	end
	drawAuto(team[1] and data.List[team[1]])
	drawTeams()
	-- TAME.
	local target, chance = tameTarget()
	tameModel = target
	tame.Visible = target ~= nil and not KaijuTaming.casting() and not window.Gui.Enabled
		and player:GetAttribute("MechPilot") == nil
	if target then
		catchName.Text = target:GetAttribute("KaijuName") or target.Name
		catchStroke.Transparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 4))
		tameOdds.Text = string.format("%d%%", math.floor(chance * 100 + 0.5))
		local left = Kaiju.TameTries - (target:GetAttribute("KaijuTries") or 0)
		tameTries.Text = string.format("%d tr%s left", left, if left == 1 then "y" else "ies")
	end
end

-- Creatures show their health on their bodies (BodyHealth): wild kaiju
-- and moon bugs (the server's HealthBar over them stays off), and every
-- kaiju out. A wild kaiju has its plate over it too (WildBars).
local function bodies()
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		if model:IsA("Model") and (model:GetAttribute("KaijuWild") or model:GetAttribute("MoonBug")) then
			BodyHealth.watch(model)
			if model:GetAttribute("KaijuWild") then
				WildBars.watch(model)
			end
		end
	end
	local kaiju = workspace:FindFirstChild("Kaiju")
	for _, model in if kaiju then kaiju:GetChildren() else {} do
		if model:IsA("Model") then
			BodyHealth.watch(model)
		end
	end
end

autoButton.Activated:Connect(function()
	local data = roster()
	if not data or busy then
		return
	end
	local want = not (if autoWant ~= nil then autoWant else Kaiju.autoHealOn(data))
	autoWant = want
	pcall(refresh)
	act(function()
		local result = GemClient.request("KaijuAutoHeal", want)
		say(result)
		if not (result and result.Ok) then
			autoWant = nil -- (as it was)
		end
	end)
end)
-- A team's key or chip (see teamPad): an empty team says how they fill.
function pressTeam(n: number)
	local data = roster()
	if not data or busy or not n then
		return
	end
	local members = Kaiju.teamOf(data, n)
	if #members == 0 then
		-- (An empty team's key: TEAMS, its first place picked to fill.)
		if not (window.Gui.Enabled and tab == "Teams") then
			UiKit.toast(string.format("Team %d is empty: put kaiju in it on the TEAMS page.", n), P.Gold)
			KaijuHud.open(nil, "Teams")
		end
		teamsUi.Pick = { Team = n, Slot = #members + 1 }
		drawPanel()
		return
	end
	act(function()
		say(GemClient.request("KaijuTeamOut", n))
		pcall(refresh)
	end)
end
-- A wild kaiju's Challenge prompt: your kaiju go in (KaijuWilds).
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player or prompt:GetAttribute("PromptKind") ~= "KaijuChallenge" then
		return
	end
	local model = prompt.Parent and prompt.Parent.Parent
	act(function()
		say(GemClient.request("KaijuChallenge", model))
	end)
end)
local function catchReady()
	if not gui.Enabled or not tame.Visible or busy or KaijuTaming.casting() then
		return
	end
	local target = tameTarget()
	if not target or target ~= tameModel then
		return
	end
	act(function()
		local result = GemClient.request("KaijuTame", target)
		if result and result.Casting then
			catchCooldowns[target] = os.clock() + Kaiju.TameCooldown
			-- The cast is on: its bar shows how it goes (KaijuTaming).
			KaijuTaming.cast(target, result.Chance or 0, result.Seconds or Kaiju.Tame.Cast)
			tame.Visible = false
		else
			say(result)
		end
	end)
end
tame.Activated:Connect(catchReady)

local started = false
-- Where the team's HYPERBEAM goes (KaijuBeamHud): on a computer its pill on
-- the card's bottom edge (the card, its parent, carries its meter); on a
-- phone a button of its own (its Apart attribute: its meter round it).
function KaijuHud.beamSlot(): Frame
	return beamSlot
end

-- Your team out of its Gemsouls as you come in. The server plays each
-- one's deploy as it comes out (KaijuServer), but arriving (getting into
-- the game, a respawn, back from a fight) that's often under the loading
-- screen: once the screen's gone, each that came out under it, its deploy
-- long over, plays it again where you can see it.
local DEPLOY_SECONDS = 0.8 -- (its shard and its burst: LevelUpFx.deploy)
local UNDER_COVER = 30 -- (out longer ago than this: it was out all along)
local function deployAfterLoading()
	local folder = workspace:FindFirstChild("Kaiju")
	local character = player.Character
	local from = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local now = workspace:GetServerTimeNow()
	local radius = 4 * Kaiju.size(Kaiju.Scale.Pet)
	for _, model in if folder then folder:GetChildren() else {} do
		local outAt = model:GetAttribute("KaijuOutAt")
		if model:IsA("Model") and model:GetAttribute("KaijuOwner") == player.UserId and type(outAt) == "number" then
			local ago = now - outAt
			local root = model.PrimaryPart
			if root and ago >= DEPLOY_SECONDS and ago <= UNDER_COVER then
				local tint = GemConfig.ElementColors[model:GetAttribute("KaijuElement") or ""]
				LevelUpFx.deploy(root.Position, radius, tint, from and from.Position)
			end
		end
	end
end
KaijuHud._deployAfterLoading = deployAfterLoading

function KaijuHud.start()
	if started then
		return
	end
	started = true
	-- (The loading screen going: your team's deploy, as above.)
	task.spawn(function()
		local covered = LoadingFlow.active()
		while true do
			task.wait(0.25)
			local now = LoadingFlow.active()
			if covered and not now then
				task.wait(0.35) -- (as the screen fades)
				deployAfterLoading()
			end
			covered = now
		end
	end)
	ContextActionService:BindActionAtPriority("KaijuCatch", function(_, state)
		if UserInputService:GetFocusedTextBox() or not gui.Enabled or not tame.Visible then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then catchReady() end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.C)
	-- The team keys: 1 to 4 bring a team out (pressTeam). (The kit switch,
	-- SparKit, is on Y.)
	local TEAM_KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4 }
	ContextActionService:BindActionAtPriority("KaijuTeams", function(_, state, input)
		if UserInputService:GetFocusedTextBox() or not gui.Enabled or not card.Visible then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			pressTeam(TEAM_KEYS[input.KeyCode])
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four)
	KaijuTaming.start()
	BodyHealth.start()
	WildBars.start()
	layout()
	local ok, err = pcall(refresh)
	if not ok then
		warn("[KaijuHud]", err)
	end
	local nextTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextTick then
			return
		end
		nextTick = now + 0.2
		local ok, err = pcall(refresh)
		if not ok then
			warn("[KaijuHud]", err)
		end
		pcall(bodies)
		pcall(tickRevive)
	end)
end

return KaijuHud
