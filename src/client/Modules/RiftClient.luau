--[[
	The Rift on your screen (Server.RiftServer runs it; Shared.RiftRun has
	the rules).

	  The gate     a Rift Gate's prompt (PromptKind Rift) opens its lobby:
	               which biome's Rift it is (its element) and what's
	               through it; YOUR PARTY, its four places (each member's
	               face, LEADER, READY or NOT READY, where they are: at the
	               gate, in the Outpost, in the Rift), an open place to
	               invite into; CHOOSE YOUR BOSS: the biome's ladder
	               (RiftRun.Ladders) as cards, each boss's portrait (its
	               body, from ReplicatedStorage.RiftPortraits), its threat
	               (pips) and level, its favourite gear and how often
	               you've beaten it, a locked one a silhouette with what
	               opens it (the leader picks); and beside them who's
	               about, a tab each: IN THE OUTPOST (every miner here, at
	               the gate first, then your friends: INVITE to your party)
	               and FRIENDS (your Roblox friends online, here or not:
	               INVITE, or Roblox's invite for one who isn't here), with
	               INVITE FRIENDS TO THE GAME under them. Alone against a
	               boss built for 2 to 4, a warning sign: BRING FRIENDS.
	               The buttons: on your own, ENTER ALONE; leading a party,
	               ENTER TOGETHER (everyone ready comes in with you, from
	               anywhere in the Outpost: Server.RiftServer); in someone's
	               party, READY and GO IN NOW; one of you in there already,
	               JOIN THEM. It keeps itself up to date (your party, who's
	               where, your friends) while it's open (Shared.RiftLobby).
	  Crossing     the screen goes dark while you go through ("THE RIFT",
	               and the same warning when you're alone), then clears on
	               the other side.
	  In there     everything lit like the place (RiftClient.hellLighting:
	               a burning dusk, no stars, the sky red at its edges and
	               violet overhead; Scenes.outpostLighting puts the
	               Outpost's back), and a strip along the top: which cave
	               (its pips: the four and the throne), how many foes are
	               left, the boss and its level, the gems you've found and how many of
	               you are in. Your combat kit is out the whole way (the
	               server's). Through a way home (PromptKind RiftExit) and
	               you're out.
	  Down         knocked out at the boss: YOU'RE DOWN, the boss still
	               standing, and what now: RESTORE (its cost: your health and
	               your kaiju's), CALL FOR BACKUP (the gate's lobby again:
	               invite your party, the Outpost or a friend to come
	               through a gate to you; BACKUP on the strip opens the
	               same list anywhere on the way) or BACK TO BASE (keeping
	               what you found), the time left to choose running down.

	  RiftClient.start()            watch your Rift attributes (once)
	  RiftClient.openGate(vein, at?)  the gate's lobby (`at`: the gate, for who's at it);
	                                vein "Bounty": Brutus's bounty board, the same lobby
	                                with a tab for each biome's ladder (Shared.Bounties)
	  RiftClient.leave()            through a way home
	  RiftClient.stripText(state) -> (string, string)   the strip's two lines (pure)
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local RiftRun = require(ReplicatedStorage.Shared.RiftRun)
local RiftRealms = require(ReplicatedStorage.Shared.RiftRealms)
local RiftLobby = require(ReplicatedStorage.Shared.RiftLobby)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local Store = require(ReplicatedStorage.Shared.Store)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local MobileLayout = require(script.Parent.MobileLayout)

local RiftClient = {}

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new
local EMBER = Color3.fromRGB(255, 120, 48)
local HELL = Color3.fromRGB(214, 52, 30)
local WARN = Color3.fromRGB(255, 186, 72)
local BOLD, BODY = IronUi.Bold, IronUi.Body

-- The Bounty Board's look (a fantasy MMO's dialog window): a gilt frame
-- on dark stone, serif headings in old gold, words in sentence case, and
-- colour kept for what it means (the boss's element, a level's danger,
-- ready or not).
local Gilt = {
	Gold = Color3.fromRGB(228, 188, 100),
	Bright = Color3.fromRGB(255, 226, 150),
	Brass = Color3.fromRGB(140, 110, 60),
	Bronze = Color3.fromRGB(70, 50, 28),
	Stone = Color3.fromRGB(27, 22, 18),
	Deep = Color3.fromRGB(11, 9, 8),
	Well = Color3.fromRGB(16, 13, 11),
	Ink = Color3.fromRGB(236, 224, 200),
	Faded = Color3.fromRGB(162, 146, 118),
	Dusk = Color3.fromRGB(112, 100, 82),
	Green = Color3.fromRGB(124, 214, 98),
	Red = Color3.fromRGB(214, 92, 70),
	Serif = Enum.Font.Merriweather,
}

-- A recessed well: darker stone in a brass hairline.
function Gilt.well(frame: GuiObject, edge: Color3?): UIStroke
	frame.BackgroundColor3 = Gilt.Well
	UiKit.round(frame, 3)
	return new("UIStroke", {
		Color = edge or Gilt.Brass,
		Thickness = 1,
		Transparency = 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
end

-- A small gilt diamond: the frame's corners, a divider's middle.
function Gilt.stud(parent: Instance, size: number, at: UDim2): Frame
	local stud = new("Frame", {
		Name = "Stud",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size, size),
		Rotation = 45,
		BackgroundColor3 = Gilt.Deep,
		ZIndex = 3,
	}, parent)
	new("UIStroke", { Color = Gilt.Gold, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, stud)
	return stud
end

-- A gilt hairline: fading out to the right, or to both ends (`both`).
function Gilt.rule(parent: Instance, both: boolean?): Frame
	local line = new("Frame", {
		Name = "Rule",
		BackgroundColor3 = Gilt.Gold,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, parent)
	new("UIGradient", {
		Transparency = if both
			then NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			else NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(0.7, 0.85),
				NumberSequenceKeypoint.new(1, 1),
			}),
	}, line)
	return line
end

-- Serif words (a heading, a name, a button's), with a thin dark edge.
function Gilt.words(parent: Instance, value: string, size: number, color: Color3): TextLabel
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = Gilt.Serif,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, size + 6),
	}, parent)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.55 }, label)
	return label
end

-- A section's heading: gold serif words over a gilt rule fading out.
function Gilt.heading(parent: Instance, label: string, order: number, small: boolean): TextLabel
	local row = new("Frame", {
		Name = "Heading",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 18 else 27),
		LayoutOrder = order,
	}, parent)
	local words = Gilt.words(row, label, if small then 12 else 16, Gilt.Gold)
	words.Size = UDim2.new(1, 0, 1, -3)
	local rule = Gilt.rule(row)
	rule.AnchorPoint = Vector2.new(0, 1)
	rule.Position = UDim2.fromScale(0, 1)
	return words
end

-- A button: crimson in a gold rim for the one that matters (`primary`),
-- dark stone in brass for the rest. The rim brightens under the mouse.
function Gilt.button(
	parent: Instance,
	label: string,
	primary: boolean,
	order: number,
	onClick: (() -> ())?,
	tall: number?,
	size: number?
): TextButton
	local b = new("TextButton", {
		Name = "Button",
		Text = label,
		TextSize = size or 16,
		Font = Gilt.Serif,
		TextColor3 = if primary then Gilt.Bright else Gilt.Ink,
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, tall or 40),
		LayoutOrder = order,
	}, parent)
	UiKit.round(b, 3)
	new("UIGradient", {
		Rotation = 90,
		Color = if primary
			then ColorSequence.new(Color3.fromRGB(158, 34, 22), Color3.fromRGB(82, 14, 10))
			else ColorSequence.new(Color3.fromRGB(56, 46, 36), Color3.fromRGB(28, 22, 17)),
	}, b)
	local rim = new("UIStroke", {
		Color = if primary then Gilt.Gold else Gilt.Brass,
		Thickness = if primary then 1.5 else 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, b)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.35 }, b)
	-- (light catching its top edge)
	new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if primary then 0.8 else 0.9,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(2, 1),
		Size = UDim2.new(1, -4, 0, 1),
	}, b)
	local rest = rim.Color
	b.MouseEnter:Connect(function()
		rim.Color = Gilt.Bright
	end)
	b.MouseLeave:Connect(function()
		rim.Color = rest
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function narrow(gui: ScreenGui): boolean
	return gui.AbsoluteSize.X < 700 or gui.AbsoluteSize.Y < 480
end

local function text(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or BODY,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, size + 4),
	}, parent)
end

local function button(
	parent: Instance,
	label: string,
	color: Color3,
	order: number,
	onClick: () -> (),
	tall: number?
): TextButton
	local b, face =
		IronUi.chunk(parent, { Color = color, Size = UDim2.new(1, 0, 0, tall or 44), Radius = 8, Stripes = "None" })
	b.LayoutOrder = order
	IronUi.label(b, face, label, 15, BOLD)
	b.Activated:Connect(onClick)
	return b
end

-- The colours of the place ------------------------------------------------------------------------------------

-- A burning dusk: the sun just down (no disc, no stars), the air glowing
-- at the horizon and bruised overhead, round the scar torn across the sky
-- (World.RiftWorld's); the braziers' fire blooming. Its colours are the
-- realm's (Shared.RiftRealms: the boss's, from the RiftRealm attribute):
-- orange-red for the fire realms, blue for the frost, gold for the shock,
-- green for the poison. Hell is the base every realm's lighting lays
-- over.
RiftClient.Hell = {
	Clock = 17.8,
	Ambient = Color3.fromRGB(96, 42, 40),
	Outdoor = Color3.fromRGB(140, 64, 52),
	Brightness = 1.6,
	Exposure = 0.1,
	Haze = { Density = 0.36, Offset = 0.15, Haze = 2.8, Glare = 0.5 },
	HazeColor = Color3.fromRGB(215, 84, 52),
	HazeDecay = Color3.fromRGB(92, 24, 64),
	Grade = { Contrast = 0.14, Saturation = 0.12, Tint = Color3.fromRGB(255, 222, 205) },
	Bloom = { Intensity = 0.6, Size = 28, Threshold = 1.2 },
	Stars = 0,
}

-- The lighting for `realm` (a RiftRealms realm; the one you're in when
-- left out): Hell with the realm's colours laid over it.
function RiftClient.lightingFor(realm): any
	realm = realm or RiftRealms.of(player:GetAttribute("RiftRealm"))
	local hell = table.clone(RiftClient.Hell)
	local air = realm and realm.Lighting or {}
	for _, key in { "Clock", "Ambient", "Outdoor", "Brightness", "Exposure", "HazeColor", "HazeDecay" } do
		if air[key] ~= nil then
			hell[key] = air[key]
		end
	end
	hell.Grade = table.clone(hell.Grade)
	hell.Grade.Tint = air.Tint or hell.Grade.Tint
	hell.Grade.Saturation = air.Saturation or hell.Grade.Saturation
	return hell
end

local function effect(kind: string): any
	local found = Lighting:FindFirstChildOfClass(kind)
	if not found then
		found = Instance.new(kind)
		found.Parent = Lighting
	end
	return found
end

function RiftClient.hellLighting(realm)
	local hell = RiftClient.lightingFor(realm)
	Lighting.ClockTime = hell.Clock
	Lighting.Brightness = hell.Brightness
	Lighting.Ambient = hell.Ambient
	Lighting.OutdoorAmbient = hell.Outdoor
	Lighting.ExposureCompensation = hell.Exposure
	local haze = effect("Atmosphere")
	for key, value in hell.Haze do
		haze[key] = value
	end
	haze.Color, haze.Decay = hell.HazeColor, hell.HazeDecay
	local grade = effect("ColorCorrectionEffect")
	grade.Contrast, grade.Saturation, grade.TintColor = hell.Grade.Contrast, hell.Grade.Saturation, hell.Grade.Tint
	local bloom = effect("BloomEffect")
	bloom.Intensity, bloom.Size, bloom.Threshold = hell.Bloom.Intensity, hell.Bloom.Size, hell.Bloom.Threshold
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.StarCount = hell.Stars
		sky.CelestialBodiesShown = false
	end
end

local function outpostLighting()
	local ok, Scenes = pcall(require, script.Parent.Scenes)
	if ok and Scenes then
		Scenes.outpostLighting()
	end
end

-- Screens --------------------------------------------------------------------------------------------------

local gui: ScreenGui? = nil
local cover: ScreenGui? = nil
local strip: Frame? = nil
local gateCard: Frame? = nil
local downCard: Frame? = nil

local function screen(): ScreenGui
	if not gui then
		gui = UiKit.gui("Rift", 30)
	end
	return gui :: ScreenGui
end

-- Closes a card: the whole of it, from its holder on the screen down.
local function close(card: Frame?)
	local node: Instance? = card
	while node and node.Parent and node.Parent ~= gui do
		node = node.Parent
	end
	if node and node.Parent then
		node:Destroy()
	end
end

-- The gilt frame round the Bounty Board (Gilt): dark stone in a bronze
-- border, a gold hairline inside it with a stud at each corner. Its body
-- (a list) to fill.
local function giltFrame(holder: Frame, width: number, compact: boolean?): Frame
	local frame = new("Frame", {
		Name = "Frame",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, holder)
	UiKit.round(frame, 4)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 30, 23)),
			ColorSequenceKeypoint.new(0.3, Gilt.Stone),
			ColorSequenceKeypoint.new(1, Gilt.Deep),
		}),
	}, frame)
	new("UIStroke", { Color = Gilt.Bronze, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	local rim = new("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
	}, frame)
	UiKit.round(rim, 2)
	new("UIStroke", { Color = Gilt.Gold, Thickness = 1, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, rim)
	for _, corner in { UDim2.fromScale(0, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), UDim2.fromScale(1, 1) } do
		Gilt.stud(rim, 7, corner)
	end
	local body = new("Frame", {
		Name = "Panel",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, frame)
	UiKit.pad(body, if compact then 8 else 20)
	UiKit.list(body, if compact then 4 else 10)
	return body
end

-- A card in the middle of the screen over a dimmed backdrop: its panel's
-- body (a list) to fill. `dismiss` closes it from the backdrop; `gilt`
-- frames it the Bounty Board's way (giltFrame).
local function modal(
	name: string,
	width: number,
	accent: Color3,
	dismiss: boolean,
	compact: boolean?,
	gilt: boolean?
): (Frame, Frame)
	local holder = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen())
	local backdrop = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = if gilt then 0.3 else 0.4,
		Size = UDim2.fromScale(1, 1),
	}, holder)
	if dismiss then
		backdrop.Activated:Connect(function()
			holder:Destroy()
		end)
	end
	if gilt then
		return giltFrame(holder, width, compact), holder
	end
	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = P.Frame,
	}, holder)
	UiKit.round(panel, 12)
	new("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 0.1 }, panel)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(accent:Lerp(P.Frame, 0.78), P.Frame),
	}, panel)
	UiKit.pad(panel, if compact then 10 else 14)
	UiKit.list(panel, if compact then 5 else 8)
	return panel, holder
end

-- The warning sign and its words (going in alone; `head` and `body` for
-- another warning).
local function warning(parent: Instance, order: number, compact: boolean?, head: string?, body: string?)
	local box = new("Frame", {
		Name = "Warning",
		BackgroundColor3 = Color3.fromRGB(64, 22, 14),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, parent)
	UiKit.round(box, 8)
	new("UIStroke", { Color = WARN, Thickness = 1.5 }, box)
	local sign = if compact then 26 else 34
	new("UIPadding", {
		PaddingTop = UDim.new(0, if compact then 6 else 10),
		PaddingBottom = UDim.new(0, if compact then 6 else 10),
		PaddingLeft = UDim.new(0, sign + 20),
		PaddingRight = UDim.new(0, 10),
	}, box)
	local mark = IronUi.emblem(box, "Warning", WARN, sign)
	mark.Position = UDim2.new(0, -sign - 10, 0.5, -sign / 2)
	-- (The words in a list of their own: a list in the box would stack the
	-- sign above them.)
	local words = new("Frame", {
		Name = "Words",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, box)
	UiKit.list(words, 2)
	local title = text(words, head or "GOING ALONE IS VERY DIFFICULT", if compact then 13 else 15, WARN, BOLD)
	title.LayoutOrder = 1
	local why = text(
		words,
		body or "Invite a friend, or bring your party: up to 4 can go in together.",
		if compact then 11 else 12,
		P.Text
	)
	why.LayoutOrder = 2
	return box
end

-- What to bring against the boss picked (Shared.DungeonRules.elementTips):
-- its element's colour round a heading and a line per tip.
local function tipBox(parent: Instance, order: number, compact: boolean?, head: string, lines: { string }, color: Color3)
	local box = new("Frame", {
		Name = "Tips",
		BackgroundColor3 = Color3.fromRGB(18, 16, 24),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, parent)
	UiKit.round(box, 8)
	new("UIStroke", { Color = color, Thickness = 1.5 }, box)
	new("UIPadding", {
		PaddingTop = UDim.new(0, if compact then 6 else 9),
		PaddingBottom = UDim.new(0, if compact then 6 else 9),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 10),
	}, box)
	UiKit.list(box, 2)
	local title = text(box, head, if compact then 12 else 14, color, BOLD)
	title.LayoutOrder = 1
	for i, line in lines do
		local l = text(box, "•  " .. line, if compact then 10 else 12, P.Text)
		l.LayoutOrder = 1 + i
	end
	return box
end

-- Crossing: dark for a moment while you go through.
local function crossing(alone: boolean): () -> ()
	if cover then
		cover:Destroy()
	end
	local layer = UiKit.gui("RiftCrossing", 40)
	layer.IgnoreGuiInset = true
	cover = layer
	local shade = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(10, 2, 2),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, layer)
	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.8, 0, 0, 44),
		Text = "THE RIFT",
		TextSize = 38,
		Font = IronUi.Heading,
		TextColor3 = EMBER,
		TextTransparency = 1,
	}, shade)
	local sub = new("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0.8, 0, 0, 20),
		Text = "Through the tear, into the critters' world.",
		TextSize = 15,
		Font = BODY,
		TextColor3 = P.Dim,
		TextTransparency = 1,
	}, shade)
	sub.Position = UDim2.new(0.5, 0, 0.42, 36)
	local alert = nil
	if alone then
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.42, 64),
			Size = UDim2.new(0, math.min(420, layer.AbsoluteSize.X - 40), 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, shade)
		alert = warning(holder, 1)
		new("UIListLayout", {}, holder)
		alert.Visible = false
	end
	local fade = TweenInfo.new(0.25)
	TweenService:Create(shade, fade, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(title, fade, { TextTransparency = 0 }):Play()
	TweenService:Create(sub, fade, { TextTransparency = 0 }):Play()
	if alert then
		alert.Visible = true
	end
	return function()
		local out = TweenInfo.new(if alone then 2.2 else 1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(if alone then 1.6 else 0.5, function()
			TweenService:Create(shade, out, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(title, out, { TextTransparency = 1 }):Play()
			TweenService:Create(sub, out, { TextTransparency = 1 }):Play()
			if alert then
				alert.Visible = false
			end
			task.delay(out.Time, function()
				if cover == layer then
					cover = nil
				end
				layer:Destroy()
			end)
		end)
	end
end

local function invite()
	local ok, Referral = pcall(require, script.Parent.ReferralUI)
	if ok and Referral and Referral.invite then
		Referral.invite()
	end
end

-- The gate ----------------------------------------------------------------------------------------------------

-- What going through `vein`'s gate looks like from here: { Party (how many
-- in it), Joining (their trip's on the path), Solo, Biome, Element, Ladder
-- (its bosses), Next (the one to offer), Boss (your party's, joining) }.
local function peek(vein: any): { [string]: any }
	local result = GemClient.request("RiftPeek", vein)
	if type(result) ~= "table" or not result.Ok then
		return { Party = 1, Joining = false, Solo = true, Ladder = {} }
	end
	return result
end

-- Each threat's colour on the gate's cards (its pips).
local THREAT_COLORS = { Color3.fromRGB(110, 220, 140), WARN, Color3.fromRGB(255, 92, 72) }

-- A boss's portrait in `view`: its body as the server built it
-- (ReplicatedStorage.RiftPortraits, Server.RiftServer's portraitOf), seen
-- from the front quarter. (It may still be on its way: it's put in when it
-- comes.)
local function portraitInto(view: ViewportFrame, id: string)
	local function place(source: Instance)
		if not view.Parent or not source:IsA("Model") then
			return
		end
		local model = source:Clone()
		model.Parent = view
		local camera = Instance.new("Camera")
		local cf, size = model:GetBoundingBox()
		local reach = math.max(size.X, size.Y, size.Z)
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(
			cf.Position + Vector3.new(reach * 0.75, reach * 0.3, -reach * 1.45),
			cf.Position + Vector3.new(0, size.Y * 0.04, 0)
		)
		camera.Parent = view
		view.CurrentCamera = camera
	end
	local folder = ReplicatedStorage:FindFirstChild("RiftPortraits")
	local source = folder and folder:FindFirstChild(id)
	if source then
		place(source)
		return
	end
	task.spawn(function()
		local found = folder or ReplicatedStorage:WaitForChild("RiftPortraits", 8)
		local model = found and found:WaitForChild(id, 8)
		if model then
			place(model)
		end
	end)
end

-- One boss on the gate's ladder, as a framed portrait: the boss over a
-- faint glow of its element, its level in its danger's colour, its name
-- and a line under it (its favourite gear, how often you've beaten it).
-- Locked, it's a silhouette with what opens it. Picking it selects it (a
-- locked one just says what opens it).
local function bossCard(parent: Instance, entry, order: number, compact: boolean, onPick: () -> ())
	local accent = GemConfig.ElementColors[entry.Element] or EMBER
	local card = new("TextButton", {
		Name = "Boss_" .. tostring(entry.Id),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(190, 190, 190),
		ClipsDescendants = true,
		LayoutOrder = order,
	}, parent)
	UiKit.round(card, 3)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(accent:Lerp(Gilt.Deep, 0.78), Gilt.Deep),
	}, card)
	local edge = new(
		"UIStroke",
		{ Color = Gilt.Brass, Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		card
	)
	local foot = if compact then 34 else 50
	-- The stage: a glow behind it, then the boss.
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -foot / 2 + 6),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = accent,
		BackgroundTransparency = if entry.Unlocked then 0.86 else 0.95,
	}, card)
	new("UIAspectRatioConstraint", { AspectRatio = 1 }, glow)
	UiKit.round(glow, 999)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 90,
	}, glow)
	local view = new("ViewportFrame", {
		Name = "Portrait",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, if compact then 4 else 8),
		Size = UDim2.new(1, 0, 1, -foot - (if compact then 4 else 8)),
		Ambient = Color3.fromRGB(150, 140, 150),
		LightColor = Color3.fromRGB(255, 236, 220),
		LightDirection = Vector3.new(-0.5, -0.8, 0.6),
		-- (Locked: a silhouette.)
		ImageColor3 = if entry.Unlocked then Color3.new(1, 1, 1) else Color3.fromRGB(8, 6, 10),
		ImageTransparency = if entry.Unlocked then 0 else 0.15,
	}, card)
	portraitInto(view, tostring(entry.Id))
	-- Its level, top right, coloured by how dangerous it is.
	local level = Gilt.words(card, string.format("Level %d", entry.Level or 1), if compact then 10 else 12, if entry.Unlocked
		then THREAT_COLORS[entry.Threat] or Gilt.Ink
		else Gilt.Dusk)
	level.Name = "Level"
	level.TextXAlignment = Enum.TextXAlignment.Right
	level.AnchorPoint = Vector2.new(1, 0)
	level.Position = UDim2.new(1, -8, 0, if compact then 3 else 6)
	level.Size = UDim2.new(1, -16, 0, if compact then 14 else 18)
	-- Its name and its line, along the bottom, under a gilt hairline.
	local shade = new("Frame", {
		Name = "Foot",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, foot),
		BackgroundColor3 = Gilt.Deep,
		BackgroundTransparency = 0.12,
	}, card)
	Gilt.rule(shade, true)
	local name = Gilt.words(shade, entry.Name, if compact then 12 else 15, if entry.Unlocked then Gilt.Ink else Gilt.Dusk)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Position = UDim2.fromOffset(6, if compact then 2 else 6)
	name.Size = UDim2.new(1, -12, 0, if compact then 16 else 20)
	local parts = {}
	if entry.Starter then
		table.insert(parts, "Recommended solo")
	end
	if entry.Unlocked then
		local favour = Slots.Definitions[Slots.ByKind[entry.Loot or ""] or ""]
		if favour then
			table.insert(parts, "Favours: " .. favour.Label)
		end
		if (entry.Beaten or 0) > 0 then
			table.insert(parts, string.format("Beaten: %d", entry.Beaten))
		end
	else
		table.insert(parts, string.format("Beat %s to unlock", entry.Need or "the one before"))
	end
	local sub = text(shade, table.concat(parts, "  ·  "), if compact then 9 else 11, if entry.Unlocked then Gilt.Faded else Gilt.Red)
	sub.AutomaticSize = Enum.AutomaticSize.None
	sub.TextWrapped = false
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.Position = UDim2.fromOffset(6, if compact then 19 else 29)
	sub.Size = UDim2.new(1, -12, 0, if compact then 11 else 14)
	if not entry.Unlocked then
		local lock = Gilt.words(card, "Locked", if compact then 11 else 14, Gilt.Faded)
		lock.TextXAlignment = Enum.TextXAlignment.Center
		lock.AnchorPoint = Vector2.new(0.5, 0.5)
		lock.Position = UDim2.new(0.5, 0, 0.5, -foot / 2)
		lock.Size = UDim2.new(1, 0, 0, 20)
	end
	card.Activated:Connect(onPick)
	return card, edge
end

-- The gate's lobby ----------------------------------------------------------------------------------------------

-- The SocialUI module (your party, your friends online), if it loads.
local function social(): any
	local ok, module = pcall(require, script.Parent.SocialUI)
	return if ok then module else nil
end

local HEADSHOT = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"
local invited: { [number]: number } = {} -- userId -> when you asked them (os.clock)

-- The lobby's view of the server right now (Shared.RiftLobby's `view`).
local function lobbyView(at: Vector3?)
	local mine = player:GetAttribute("PartyId")
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local theirs = other:GetAttribute("PartyId")
			table.insert(others, {
				UserId = other.UserId,
				Name = other.DisplayName,
				Level = other:GetAttribute("MinerLevel"),
				Outpost = other:GetAttribute("Outpost") == true,
				Party = if theirs == nil then nil elseif theirs == mine then "Mine" else "Other",
				InRift = other:GetAttribute("RiftRun") ~= nil,
				Near = at ~= nil and root ~= nil and (root.Position - at).Magnitude <= RiftLobby.Near,
			})
		end
	end
	local recent = {}
	for userId, when in invited do
		if os.clock() - when < 60 then
			recent[userId] = true
		end
	end
	local s = social()
	return {
		Me = player.UserId,
		MeName = player.DisplayName,
		Party = s and s.party(),
		Players = others,
		Friends = s and s.friends(),
		Invited = recent,
		PlaceId = game.PlaceId,
	}
end

-- A round headshot (the first letter under it, for a stand-in with none).
local function headshot(parent: Instance, userId: number, name: string, size: number, ring: Color3): Frame
	local holder = new("Frame", {
		Name = "Face",
		BackgroundColor3 = P.Slot,
		Size = UDim2.fromOffset(size, size),
	}, parent)
	UiKit.round(holder, 999)
	new("UIStroke", { Color = ring, Thickness = 1.5 }, holder)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = string.upper(string.sub(name, 1, 1)),
		TextSize = math.floor(size * 0.45),
		Font = BOLD,
		TextColor3 = P.Dim,
	}, holder)
	local image = new("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = if userId > 0 then string.format(HEADSHOT, userId) else "",
	}, holder)
	UiKit.round(image, 999)
	return holder
end

-- One of your party's places: a member in a recessed well (their face in
-- a gilt ring, gold for the leader; their name; where they are; ready or
-- not), or an empty place to invite into. In a party, your own has Leave
-- (`acts.Leave`), and the leader sees a red × on each of the others' to
-- remove them (`acts.Kick`).
local function partySlot(parent: Instance, slot, order: number, compact: boolean, acts)
	local card = new("Frame", {
		Name = if slot then "Member" else "Open",
		LayoutOrder = order,
	}, parent)
	local edge = Gilt.well(card, if slot and slot.Leader then Gilt.Gold else Gilt.Brass)
	if not slot then
		card.BackgroundTransparency = 0.4
		edge.Transparency = 0.75
		local open = Gilt.words(card, "Empty", if compact then 11 else 13, Gilt.Dusk)
		open.TextXAlignment = Enum.TextXAlignment.Center
		open.AnchorPoint = Vector2.new(0.5, 0.5)
		open.Position = UDim2.new(0.5, 0, 0.5, if compact then -6 else -8)
		open.Size = UDim2.new(1, -8, 0, 18)
		local hint = text(card, "Invite from the list", if compact then 9 else 10, Gilt.Dusk)
		hint.TextXAlignment = Enum.TextXAlignment.Center
		hint.AutomaticSize = Enum.AutomaticSize.None
		hint.AnchorPoint = Vector2.new(0.5, 0.5)
		hint.Position = UDim2.new(0.5, 0, 0.5, if compact then 7 else 10)
		hint.Size = UDim2.new(1, -8, 0, 12)
		return card
	end
	local face = if compact then 24 else 34
	local pic = headshot(card, slot.UserId, slot.Name or "?", face, if slot.Leader then Gilt.Gold else Gilt.Brass)
	pic.Position = UDim2.fromOffset(if compact then 6 else 8, if compact then 5 else 9)
	local left = face + (if compact then 11 else 14)
	local name = Gilt.words(card, slot.Name or "?", if compact then 12 else 14, Gilt.Ink)
	name.Position = UDim2.fromOffset(left, if compact then 2 else 6)
	name.Size = UDim2.new(1, -left - 6, 0, if compact then 16 else 20)
	local where = text(card, if slot.You then "You" else slot.Where, if compact then 9 else 11, Gilt.Faded)
	where.AutomaticSize = Enum.AutomaticSize.None
	where.TextWrapped = false
	where.TextTruncate = Enum.TextTruncate.AtEnd
	where.Position = UDim2.fromOffset(left, if compact then 18 else 27)
	where.Size = UDim2.new(1, -left - 6, 0, 13)
	-- (Along the bottom: ready or not, and who leads.)
	local ready = slot.Ready or (slot.Leader and slot.You)
	local marks = new("Frame", {
		Name = "Marks",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, if compact then 6 else 8, 1, if compact then -3 else -7),
		Size = UDim2.new(1, -40, 0, 14),
	}, card)
	UiKit.list(marks, 0, true)
	for i, mark in {
		{ if ready then "Ready" else "Not ready", if ready then Gilt.Green else Gilt.Dusk },
		if slot.Leader then { "  ·  ", Gilt.Dusk } else nil,
		if slot.Leader then { "Leader", Gilt.Gold } else nil,
	} do
		local word = text(marks, mark[1], if compact then 9 else 11, mark[2], BOLD)
		word.AutomaticSize = Enum.AutomaticSize.X
		word.TextWrapped = false
		word.Size = UDim2.new(0, 0, 1, 0)
		word.LayoutOrder = i
	end
	-- (Leave top right on yours; × bottom right on theirs.)
	local act = if slot.You then acts and acts.Leave else acts and acts.Kick
	if act then
		local side = if compact then 18 else 22
		local inset = if compact then 4 else 6
		local b
		if slot.You then
			b = Gilt.button(card, "Leave", false, 0, function()
				act(slot)
			end, side, if compact then 10 else 11)
			b.Name = "Leave"
			b.AnchorPoint = Vector2.new(1, 0)
			b.Position = UDim2.new(1, -inset, 0, inset)
			b.Size = UDim2.fromOffset(if compact then 42 else 50, side)
			name.Size = UDim2.new(1, -left - 6 - b.Size.X.Offset - 4, 0, if compact then 16 else 20)
		else
			b = new("TextButton", {
				Name = "Kick",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -inset, 1, -inset),
				Size = UDim2.fromOffset(side, side),
				BackgroundColor3 = Color3.fromRGB(52, 16, 12),
				Text = "",
				AutoButtonColor = true,
			}, card)
			UiKit.round(b, 3)
			new("UIStroke", { Color = Gilt.Red, Thickness = 1, Transparency = 0.3 }, b)
			IronUi.cross(b, if compact then 7 else 9, Gilt.Ink)
			b.Activated:Connect(function()
				act(slot)
			end)
		end
	end
	return card
end

-- A row in the people list: a face, a name and level, where they are,
-- and Invite (or why not). (Friend after where they are in the Outpost's
-- list; the Friends tab is all friends.)
local function personRow(parent: Instance, row, order: number, compact: boolean, tagFriend: boolean, onInvite: (any) -> ())
	local tall = if compact then 34 else 42
	local line = new("Frame", {
		Name = "Row",
		BackgroundColor3 = Gilt.Ink,
		BackgroundTransparency = if order % 2 == 0 then 1 else 0.96,
		Size = UDim2.new(1, 0, 0, tall),
		LayoutOrder = order,
	}, parent)
	UiKit.round(line, 2)
	local face = tall - 10
	local pic = headshot(line, row.UserId, row.Name, face, if row.Friend then Gilt.Green else Gilt.Brass)
	pic.Position = UDim2.fromOffset(6, 5)
	local actionW = if compact then 70 else 82
	-- (Their name, then their level in a quieter colour.)
	local head = new("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(face + 12, if compact then 2 else 4),
		Size = UDim2.new(1, -face - actionW - 22, 0, if compact then 16 else 18),
	}, line)
	UiKit.list(head, 8, true)
	local name = Gilt.words(head, row.Name, if compact then 12 else 13, Gilt.Ink)
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.new(0, 0, 1, 0)
	name.LayoutOrder = 1
	if row.Level then
		local level = Gilt.words(head, string.format("Level %d", row.Level), if compact then 11 else 12, Gilt.Dusk)
		level.AutomaticSize = Enum.AutomaticSize.X
		level.Size = UDim2.new(0, 0, 1, 0)
		level.LayoutOrder = 2
	end
	local where = text(
		line,
		row.Where .. (if tagFriend and row.Friend then "  ·  Friend" else ""),
		if compact then 9 else 11,
		if row.Where == "At the gate" then Gilt.Green else Gilt.Faded
	)
	where.AutomaticSize = Enum.AutomaticSize.None
	where.TextWrapped = false
	where.TextTruncate = Enum.TextTruncate.AtEnd
	where.Position = UDim2.fromOffset(face + 12, if compact then 18 else 23)
	where.Size = UDim2.new(1, -face - actionW - 22, 0, 13)
	if row.Invite == "Party" or row.Invite == "Game" then
		local b = Gilt.button(line, if row.Invite == "Party" then "Invite" else "Invite ↗", false, 0, function()
			onInvite(row)
		end, tall - 12, if compact then 11 else 13)
		b.Size = UDim2.fromOffset(actionW, tall - 12)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -6, 0.5, 0)
	elseif row.Invite then
		local word = if row.Invite == "Invited" then "Invited" elseif row.Where == "In the Rift" then "In the Rift" else "In a party"
		local tag = text(line, word, if compact then 10 else 11, if row.Invite == "Invited" then Gilt.Gold else Gilt.Dusk, BOLD)
		tag.AutomaticSize = Enum.AutomaticSize.None
		tag.TextXAlignment = Enum.TextXAlignment.Right
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.new(1, -10, 0.5, 0)
		tag.Size = UDim2.fromOffset(actionW, 14)
	end
	return line
end

-- "100%" from a CounterGear.expected value (1 = every bit of its hits).
local function share(value: number?): string
	return string.format("%d%%", math.floor((value or 1) * 100 + 0.5))
end

-- The Bounty Board (and a Rift Gate's lobby), in three steps:
--   1 CHOOSE YOUR BOSS   a biome's tab (the board), its ladder as cards
--   2 GET READY          the boss picked: what it hits with, what it's weak
--                        to, its level, and ADJUST ARMOR (Shared.CounterGear
--                        through "RiftGear": resist gems and armor against
--                        its element, from your bag, never your Q, E, R)
--   3 YOUR PARTY         its four places, two by two, and who's about to
--                        invite (an invite says which boss: Party's context)
-- with ENTER under them.
function RiftClient.openGate(vein: any, at: Vector3?)
	if gateCard and gateCard.Parent or player:GetAttribute("RiftRun") then
		return
	end
	local info = peek(vein)
	local ladder = info.Ladder or {}
	local s = screen()
	local small = narrow(s)
	local width = math.min(if small then 820 else 1000, s.AbsoluteSize.X - 24)
	local panel, holder = modal("RiftGate", width, EMBER, true, small, true)
	gateCard = panel

	-- The header: its name in gold serif, centred, where it is under it,
	-- a gilt divider; a close button on the right.
	local header = new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 34 else 56),
		LayoutOrder = 1,
	}, panel)
	local title = Gilt.words(header, if info.Bounty then "Bounty Board" else "Rift Gate", if small then 17 else 26, Gilt.Gold)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Size = UDim2.new(1, 0, 0, if small then 19 else 32)
	local where = if info.Bounty
		then "Brutus's bounties  ·  Every boss behind the Rift Gates"
		else string.format("%s  ·  %s Rift", info.Biome or "", GemConfig.elementName(info.Element or ""))
			.. (if small then "" else string.format("  ·  %d caves, then the boss", RiftRun.Rooms))
	local sub = text(header, where, if small then 10 else 12, if info.Bounty then Gilt.Faded else GemConfig.ElementColors[info.Element or ""] or Gilt.Faded)
	sub.AutomaticSize = Enum.AutomaticSize.None
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.Position = UDim2.fromOffset(0, if small then 18 else 32)
	sub.Size = UDim2.new(1, 0, 0, 14)
	local divider = Gilt.rule(header, true)
	divider.AnchorPoint = Vector2.new(0, 1)
	divider.Position = UDim2.fromScale(0, 1)
	Gilt.stud(header, 7, UDim2.new(0.5, 0, 1, 0))
	local side = if small then 24 else 28
	local cancel = new("TextButton", {
		Name = "Close",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = Gilt.Deep,
		AutoButtonColor = false,
	}, header)
	UiKit.round(cancel, 3)
	local cancelRim = new("UIStroke", { Color = Gilt.Brass, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cancel)
	IronUi.cross(cancel, if small then 9 else 11, Gilt.Faded)
	cancel.MouseEnter:Connect(function()
		cancelRim.Color = Gilt.Bright
	end)
	cancel.MouseLeave:Connect(function()
		cancelRim.Color = Gilt.Brass
	end)
	cancel.Activated:Connect(function()
		close(gateCard)
	end)

	-- Two columns: the boss and getting ready (left), your party (right).
	local gap = if small then 10 else 20
	local right = if small then 268 else 320
	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, panel)
	UiKit.list(body, gap, true).VerticalAlignment = Enum.VerticalAlignment.Top
	local left = new("Frame", {
		Name = "Left",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -right - gap, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
	}, body)
	UiKit.list(left, if small then 4 else 8)
	local column = new("Frame", {
		Name = "Right",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, right, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, body)
	UiKit.list(column, if small then 4 else 8)

	-- The boss: theirs when joining your party's trip, else the leader's pick.
	local picked = info.Next
	local cards = {}
	local view = nil -- (the lobby as last drawn: Shared.RiftLobby)
	local plans: { [string]: any } = {} -- element -> CounterGear.summary, from "RiftGear"
	local asking: { [string]: boolean } = {}
	local function entryOf(id)
		if info.Joining then
			return info.Theirs
		end
		for _, entry in ladder do
			if entry.Id == id then
				return entry
			end
		end
		return nil
	end

	Gilt.heading(left, if info.Joining then "Your party's boss" elseif info.Ladders then "Choose a biome, then your boss" else "Choose your boss", 1, small)
	local readyHead = nil
	local readyCard = nil
	local redrawReady

	if info.Joining then
		local l = text(
			left,
			string.format(
				"Your party's on the path in there, against %s: you'll come in where they've got to.",
				info.Boss or "the boss"
			),
			if small then 11 else 13,
			Gilt.Green,
			BOLD
		)
		l.LayoutOrder = 3
	elseif #ladder > 0 then
		-- Brutus's board: a tab for each biome's ladder.
		local biomeRow = nil
		if info.Ladders then
			biomeRow = new("Frame", {
				Name = "Biomes",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, if small then 24 else 32),
				LayoutOrder = 2,
			}, left)
			new("UIGridLayout", {
				CellSize = UDim2.new(1 / #info.Ladders, -5, 1, 0),
				CellPadding = UDim2.fromOffset(6, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, biomeRow)
		end
		local list = new("Frame", {
			Name = "Ladder",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if small then 84 else 168),
			LayoutOrder = 3,
		}, left)
		local cardGap = if small then 6 else 10
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, cardGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, list)
		local function redrawCards()
			for id, c in cards do
				local on = id == picked
				c.Edge.Color = if on then Gilt.Gold else Gilt.Brass
				c.Edge.Thickness = if on then 2 else 1
				c.Edge.Transparency = if on then 0 else 0.3
				-- (the one picked lit up, the rest a shade darker)
				c.Card.BackgroundColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(170, 170, 170)
			end
		end
		local function buildCards()
			for _, child in list:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			table.clear(cards)
			for i, entry in ladder do
				local card, edge = bossCard(list, entry, i, small, function()
					if view and not view.Lead then
						UiKit.toast("Your party's leader picks the boss.", P.Bad)
						return
					elseif not entry.Unlocked then
						UiKit.toast(string.format("Beat %s first.", entry.Need or "the one before"), P.Bad)
						return
					end
					picked = entry.Id
					redrawCards()
					redrawReady()
				end)
				card.Size = UDim2.new(1 / #ladder, -cardGap * (#ladder - 1) / #ladder, 1, 0)
				cards[entry.Id] = { Card = card, Edge = edge }
			end
			redrawCards()
		end
		local biome = 1
		local function drawBiomes()
			if not biomeRow then
				return
			end
			for _, child in biomeRow:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			-- Engraved tabs: the one open lit, in gold, over its element's bar.
			for i, entry in info.Ladders do
				local on = i == biome
				local tint = GemConfig.ElementColors[entry.Element] or Gilt.Ink
				local b = new("TextButton", {
					Name = entry.Biome,
					Text = entry.Biome,
					TextSize = if small then 11 else 14,
					Font = Gilt.Serif,
					TextColor3 = if on then Gilt.Gold else Gilt.Faded,
					BackgroundColor3 = if on then Color3.fromRGB(44, 36, 28) else Gilt.Well,
					AutoButtonColor = false,
					LayoutOrder = i,
				}, biomeRow)
				UiKit.round(b, 3)
				new("UIStroke", {
					Color = if on then Gilt.Gold else Gilt.Brass,
					Thickness = 1,
					Transparency = if on then 0.2 else 0.6,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border, -- (round the tab, not its word)
				}, b)
				new("Frame", {
					Name = "Bar",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -2),
					Size = UDim2.new(1, -8, 0, if on then 2 else 1),
					BackgroundColor3 = tint,
					BackgroundTransparency = if on then 0 else 0.55,
					BorderSizePixel = 0,
				}, b)
				b.Activated:Connect(function()
					biome = i
					ladder = entry.Ladder or {}
					picked = entry.Next
					drawBiomes()
					buildCards()
					redrawReady()
				end)
			end
		end
		drawBiomes()
		buildCards()
	end

	-- 2: getting ready for the boss picked.
	readyHead = Gilt.heading(left, "Get ready", 4, small)
	readyCard = new("Frame", {
		Name = "Ready",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
	}, left)

	-- ADJUST ARMOR's plan for `element` (asked for once, then kept).
	local function planOf(chosen)
		local element = chosen and chosen.Element
		if not element then
			return nil
		end
		if plans[element] == nil and not asking[element] then
			asking[element] = true
			task.spawn(function()
				local result = GemClient.request("RiftGear", chosen.Id, false)
				asking[element] = nil
				if type(result) == "table" and result.Ok and result.Plan then
					plans[element] = result.Plan
					-- (Deferred: an answer that comes at once mustn't redraw
					-- the card in the middle of drawing it.)
					task.defer(function()
						if panel.Parent then
							redrawReady()
						end
					end)
				end
			end)
		end
		return plans[element]
	end
	local adjusting = false
	local function adjust(chosen)
		if adjusting or not chosen then
			return
		end
		adjusting = true
		task.spawn(function()
			local result = GemClient.request("RiftGear", chosen.Id, true)
			adjusting = false
			if type(result) == "table" and result.Ok then
				if result.Plan and chosen.Element then
					plans[chosen.Element] = result.Plan
				end
				UiKit.toast(result.Message or "Armor set.", P.Good)
			else
				UiKit.toast(type(result) == "table" and result.Message or "Couldn't change your armor.", P.Bad)
			end
			task.defer(function()
				if panel.Parent then
					redrawReady()
				end
			end)
		end)
	end

	-- The boss picked, read like a tooltip: its name and level, what it
	-- hits with, what it's weak to, who it's for, how to beat it; then your
	-- armor against it, and Adjust Armor.
	redrawReady = function()
		local chosen = entryOf(picked)
		readyCard:ClearAllChildren()
		local readyEdge = Gilt.well(readyCard)
		new("UIPadding", {
			PaddingTop = UDim.new(0, if small then 6 else 10),
			PaddingBottom = UDim.new(0, if small then 6 else 10),
			PaddingLeft = UDim.new(0, if small then 8 else 14),
			PaddingRight = UDim.new(0, if small then 8 else 14),
		}, readyCard)
		UiKit.list(readyCard, if small then 2 else 4)
		if not chosen then
			text(readyCard, "Pick a boss to see what it takes.", if small then 11 else 12, Gilt.Faded).LayoutOrder = 1
			return
		end
		local tint = GemConfig.ElementColors[chosen.Element or ""] or EMBER
		readyEdge.Color = tint:Lerp(Gilt.Brass, 0.5)
		-- Two words to a line, one left and one right, like a tooltip's.
		local function line(order: number, tall: number, leftWords: TextLabel, rightWords: TextLabel?)
			local row = new("Frame", {
				Name = "Line",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, tall),
				LayoutOrder = order,
			}, readyCard)
			leftWords.Parent = row
			leftWords.AutomaticSize = Enum.AutomaticSize.None
			leftWords.TextWrapped = false
			leftWords.TextTruncate = Enum.TextTruncate.AtEnd
			leftWords.Size = UDim2.new(if rightWords then 0.66 else 1, 0, 1, 0)
			if rightWords then
				rightWords.Parent = row
				rightWords.AutomaticSize = Enum.AutomaticSize.None
				rightWords.TextWrapped = false
				rightWords.TextXAlignment = Enum.TextXAlignment.Right
				rightWords.AnchorPoint = Vector2.new(1, 0)
				rightWords.Position = UDim2.fromScale(1, 0)
				rightWords.Size = UDim2.new(0.34, 0, 1, 0)
			end
			return row
		end
		local levelWords = if chosen.Level
			then Gilt.words(readyCard, string.format("Level %d", chosen.Level), if small then 12 else 14, THREAT_COLORS[chosen.Threat or 1] or Gilt.Ink)
			else nil
		-- (On a phone the card picked above already names it: its level
		-- goes on the next line instead.)
		if not small then
			line(1, 25, Gilt.words(readyCard, chosen.Name, 19, Gilt.Ink), levelWords)
		end
		local size = if small then 11 else 13
		local who, whoColor
		if small then
			who, whoColor = nil, nil
		elseif chosen.Starter then
			who, whoColor = "First boss  ·  Solo", Gilt.Faded
		elseif chosen.Group then
			local alone = view and view.Size <= 1
			who = string.format("%s  ·  %d-%d players", if alone then "Bring friends" else "Group", RiftRun.Party - 2, RiftRun.Party)
			whoColor = if alone then WARN else Gilt.Faded
		end
		line(
			2,
			size + 5,
			text(readyCard, string.format("Deals %s damage", GemConfig.elementName(chosen.Element or "")), size, tint),
			if small then levelWords elseif who then text(readyCard, who, size, whoColor) else nil
		)
		if chosen.Weakness then
			line(3, size + 5, text(readyCard, "Vulnerable to " .. GemConfig.elementName(chosen.Weakness), size, Gilt.Green))
		end
		-- How to beat it, and what it punishes (the computer's card).
		if not small and chosen.Tips then
			for i, tip in { chosen.Tips[3], chosen.Tips[4] } do
				if tip then
					local l = text(readyCard, tip, 12, Gilt.Faded)
					l.LayoutOrder = 3 + i
				end
			end
		end
		-- Your armor against it: what it takes of its hits now, and after.
		local bar = new("Frame", {
			Name = "Armor",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if small then 38 else 50),
			LayoutOrder = 10,
		}, readyCard)
		local rule = Gilt.rule(bar)
		rule.Position = UDim2.fromOffset(0, if small then 3 else 5)
		local buttonW = if small then 112 else 150
		local head = Gilt.words(bar, "Your armor vs " .. GemConfig.elementName(chosen.Element or ""), if small then 11 else 13, Gilt.Gold)
		head.Position = UDim2.fromOffset(0, if small then 6 else 11)
		head.Size = UDim2.new(1, -buttonW - 12, 0, if small then 15 else 18)
		local plan = planOf(chosen)
		local words, wordsColor
		if not plan then
			words, wordsColor = "Checking your gear...", Gilt.Dusk
		elseif plan.Changes > 0 then
			words = string.format(
				"Takes %s of its hits  ·  %s after (%d change%s)",
				share(plan.Before),
				share(plan.After),
				plan.Changes,
				if plan.Changes == 1 then "" else "s"
			)
			wordsColor = Gilt.Ink
		elseif plan.Before < 0.995 then
			words, wordsColor = string.format("Takes %s of its hits: as little as your gems allow", share(plan.Before)), Gilt.Green
		else
			words, wordsColor = plan.Note or "No gems in your bag resist it", WARN
		end
		local what = text(bar, words, if small then 9 else 11, wordsColor)
		what.AutomaticSize = Enum.AutomaticSize.None
		what.TextWrapped = false
		what.TextTruncate = Enum.TextTruncate.AtEnd
		what.Position = UDim2.fromOffset(0, if small then 22 else 31)
		what.Size = UDim2.new(1, -buttonW - 12, 0, if small then 12 else 15)
		if plan and plan.Changes == 0 then
			local ready = plan.Before < 0.995
			local done = Gilt.words(bar, if ready then "Armor ready" else "No gems for it", if small then 11 else 13, if ready then Gilt.Green else WARN)
			done.TextXAlignment = Enum.TextXAlignment.Right
			done.AnchorPoint = Vector2.new(1, 0.5)
			done.Position = UDim2.new(1, 0, 0.5, if small then 3 else 5)
			done.Size = UDim2.fromOffset(buttonW, 20)
		else
			local b = Gilt.button(bar, "Adjust Armor", false, 0, function()
				adjust(chosen)
			end, if small then 26 else 32, if small then 12 else 14)
			b.Name = "Adjust"
			b.Size = UDim2.fromOffset(buttonW, if small then 26 else 32)
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, 0, 0.5, if small then 3 else 5)
		end
	end

	-- 3: your party, and who's about to invite.
	local partyHead = Gilt.heading(column, "Your party", 1, small)
	local slotRow = new("Frame", {
		Name = "Party",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 104 else 132),
		LayoutOrder = 2,
	}, column)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0.5, -4),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, slotRow)
	local listTall = if small then 98 else (if info.Ladders then 240 else 200)
	local people = new("Frame", {
		Name = "People",
		Size = UDim2.new(1, 0, 0, listTall),
		LayoutOrder = 3,
	}, column)
	Gilt.well(people)
	UiKit.pad(people, if small then 5 else 8)
	local tabTall = if small then 22 else 28
	local tabs = new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tabTall),
	}, people)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, 0, 1, 0),
		CellPadding = UDim2.fromOffset(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabs)
	local inviteAllTall = if small then 24 else 32
	local scroller = new("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, tabTall + 5),
		Size = UDim2.new(1, 0, 1, -tabTall - inviteAllTall - 10),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Gilt.Brass,
		BorderSizePixel = 0,
	}, people)
	UiKit.list(scroller, 4)
	local inviteAll = Gilt.button(people, "Invite Friends to the Game", false, 0, nil, inviteAllTall, if small then 11 else 14)
	inviteAll.Name = "InviteAll"
	inviteAll.AnchorPoint = Vector2.new(0, 1)
	inviteAll.Position = UDim2.fromScale(0, 1)
	inviteAll.Activated:Connect(function()
		local s2 = social()
		if s2 then
			s2.inviteFriends(nil)
		else
			invite()
		end
	end)
	local tab = "Outpost"

	-- The buttons, and a line under them.
	local tall = if small then 34 else 46
	local row = new("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tall),
		LayoutOrder = 4,
	}, panel)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, tall),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local hint = text(panel, "", 11, Gilt.Dusk)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.LayoutOrder = 5
	hint.Visible = not small

	local busy = false
	local function go()
		if busy or not view then
			return
		end
		busy = true
		local together = view.Lead and view.Size > 1 and not view.Trip
		local clear = crossing(view.Size <= 1 and not info.Joining)
		task.wait(0.25)
		local result = GemClient.request("RiftEnter", vein, if info.Joining then nil else picked, together)
		if result.Ok then
			close(gateCard)
		else
			UiKit.toast(result.Message or "The gate won't open.", P.Bad)
			busy = false
		end
		clear()
	end
	local function ready(on: boolean)
		task.spawn(function()
			local result = GemClient.request("PartyReady", on)
			if not result.Ok and result.Message and result.Message ~= "" then
				UiKit.toast(result.Message, P.Bad)
			end
		end)
	end
	-- Out of your party, or (leading it) someone out of it.
	local function leaveParty()
		task.spawn(function()
			local result = GemClient.request("PartyLeave")
			UiKit.toast(result.Message or "", if result.Ok then P.Gold else P.Bad)
		end)
	end
	local function kickMember(slot)
		task.spawn(function()
			local result = GemClient.request("PartyKick", slot.UserId)
			UiKit.toast(result.Message or "", if result.Ok then P.Gold else P.Bad)
		end)
	end
	local function onInvite(person)
		invited[person.UserId] = os.clock()
		if person.Invite == "Game" then
			local s2 = social()
			if s2 then
				s2.inviteFriends(person.UserId)
			end
		else
			task.spawn(function()
				-- (The boss picked goes with it: their card says which.)
				local result = GemClient.request("PartyInvite", person.UserId, { Rift = picked })
				UiKit.toast(result.Message or "", if result.Ok then P.Gold else P.Bad)
				if not result.Ok then
					invited[person.UserId] = nil
				end
			end)
		end
	end

	-- Drawn again whenever your party, the server or your friends change,
	-- and every second while it's open (who's at the gate).
	local mode, drawn = nil, nil
	local function draw(force: boolean?)
		if not panel.Parent then
			return
		end
		local now = RiftLobby.lobby(lobbyView(at))
		-- (Only when something shown has changed: the faces stay put.)
		local sig = { tab }
		for _, slot in now.Slots do
			table.insert(sig, if slot then string.format("%d%s%s%s", slot.UserId, tostring(slot.Ready), tostring(slot.Leader), slot.Where) else "-")
		end
		for _, list in { now.Outpost, now.Friends } do
			for _, person in list do
				table.insert(sig, string.format("%d%s%s%s", person.UserId, person.Name, person.Where, tostring(person.Invite)))
			end
			table.insert(sig, "|")
		end
		table.insert(sig, tostring(now.Known) .. tostring(now.Trip))
		local signature = table.concat(sig, ";")
		if signature == drawn and not force then
			return
		end
		drawn = signature
		view = now
		partyHead.Text = string.format("Your party  ·  %d/%d", view.Size, RiftRun.Party)
		for _, child in slotRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		-- (LEAVE and × only in a party with someone else in it.)
		local mine = view.Slots[1]
		local together = view.Size > 1
		local acts = {
			Leave = if together then leaveParty else nil,
			Kick = if together and mine and mine.Leader then kickMember else nil,
		}
		for i, slot in view.Slots do
			partySlot(slotRow, slot, i, small, acts)
		end
		-- The tabs, with their counts.
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local friendsKnown = view.Known
		-- (Words for tabs, the open one in gold over a gold underline.)
		for i, spec in {
			{ "Outpost", string.format("In the Outpost  %d", #view.Outpost) },
			{ "Friends", if friendsKnown then string.format("Friends  %d", #view.Friends) else "Friends" },
		} do
			local on = tab == spec[1]
			local b = new("TextButton", {
				Name = spec[1],
				Text = spec[2],
				TextSize = if small then 11 else 13,
				Font = Gilt.Serif,
				TextColor3 = if on then Gilt.Gold else Gilt.Dusk,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				LayoutOrder = i,
			}, tabs)
			new("Frame", {
				Name = "Underline",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, -12, 0, if on then 2 else 1),
				BackgroundColor3 = if on then Gilt.Gold else Gilt.Brass,
				BackgroundTransparency = if on then 0 else 0.7,
				BorderSizePixel = 0,
			}, b)
			b.Activated:Connect(function()
				tab = spec[1]
				draw(true)
			end)
		end
		for _, child in scroller:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local rows = if tab == "Outpost" then view.Outpost else view.Friends
		for i, person in rows do
			personRow(scroller, person, i, small, tab == "Outpost", onInvite)
		end
		if #rows == 0 then
			local empty = text(
				scroller,
				if tab == "Outpost"
					then "Nobody else is in the Outpost right now."
					elseif not friendsKnown then "Looking for your friends..."
					else "None of your friends are online. Invite some to the game.",
				if small then 11 else 12,
				Gilt.Faded
			)
			empty.LayoutOrder = 1
		end
		-- The buttons: on your own, leading a party, or in someone's.
		local how = if info.Joining or view.Trip then "Join" elseif view.Size <= 1 then "Alone" elseif view.Lead then "Lead" else "Member"
		local mine = view.Slots[1]
		local key = how .. (if mine and mine.Ready then "+" else "-")
		if key ~= mode then
			mode = key
			row:ClearAllChildren()
			new("UIGridLayout", {
				CellSize = if how == "Member" then UDim2.new(0.5, -4, 0, tall) else UDim2.new(1, 0, 0, tall),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, row)
			local size = if small then 15 else 19
			if how == "Member" then
				if mine and mine.Ready then
					Gilt.button(row, "Not Ready", false, 1, function()
						ready(false)
					end, tall, size)
				else
					Gilt.button(row, "Ready", false, 1, function()
						ready(true)
					end, tall, size)
				end
				Gilt.button(row, "Go In Now", true, 2, go, tall, size)
			else
				local enter = Gilt.button(row, "Enter", true, 1, go, tall, size)
				enter.Name = "Enter"
			end
		end
		local enter = row:FindFirstChild("Enter") :: TextButton?
		if enter then
			enter.Text = if how == "Join"
				then "Join Them"
				elseif how == "Alone" then "Enter Alone"
				elseif view.Ready >= view.Size - 1 then "Enter Together"
				else string.format("Enter  ·  %d of %d ready", view.Ready + 1, view.Size)
		end
		hint.Text = if how == "Join"
			then "Through the gate and you're with them, wherever they've got to."
			elseif how == "Alone" then string.format("Invite miners from the list: up to %d go in together, and an invite takes them straight to you.", RiftRun.Party)
			elseif how == "Lead" then "Everyone ready comes in with you. The rest can follow through any gate."
			else "Your leader takes everyone who's ready in with them."
		redrawReady()
	end
	draw()

	local links = {}
	local s0 = social()
	if s0 then
		table.insert(links, s0.PartyChanged.Event:Connect(draw))
		table.insert(links, s0.FriendsChanged.Event:Connect(draw))
	end
	table.insert(links, Players.PlayerAdded:Connect(draw))
	table.insert(links, Players.PlayerRemoving:Connect(function()
		task.defer(draw)
	end))
	holder.Destroying:Connect(function()
		for _, link in links do
			link:Disconnect()
		end
	end)
	-- Every second: who's at the gate now; and once you're through (your
	-- leader took you in), the card's done.
	task.spawn(function()
		while panel.Parent and gateCard == panel do
			task.wait(1)
			if player:GetAttribute("RiftRun") then
				close(panel)
			elseif panel.Parent then
				draw()
			end
		end
	end)
end

function RiftClient.leave()
	task.spawn(function()
		local result = GemClient.request("RiftLeave")
		if not result.Ok and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, P.Bad)
		end
	end)
end

-- The strip ---------------------------------------------------------------------------------------------------

-- Its two lines from the Rift attributes: { Room, Left, Boss, BossLevel,
-- Found, Runners, Won, ExitIn (seconds till home, once the boss is down) }.
function RiftClient.stripText(state): (string, string)
	local where
	if state.Won and state.ExitIn == nil then
		where = "BOSS DOWN"
	elseif state.Won then
		where = string.format("BOSS DOWN  ·  HOME IN %d:%02d", state.ExitIn // 60, state.ExitIn % 60)
	elseif (state.Room or 1) > RiftRun.Rooms then
		where = string.format("THRONE CAVE  ·  %s", string.upper(state.Boss or "?"))
			.. (if state.BossLevel then string.format("  ·  LV %d", state.BossLevel) else "")
	elseif (state.Left or 0) > 0 then
		where = string.format(
			"CAVE %d OF %d  ·  %d FOE%s LEFT",
			state.Room,
			RiftRun.Rooms,
			state.Left,
			if state.Left == 1 then "" else "S"
		)
	else
		where = string.format("CAVE %d OF %d", state.Room or 1, RiftRun.Rooms)
	end
	local who = if (state.Runners or 1) <= 1 then "ALONE" else string.format("%d IN", state.Runners)
	return where, string.format("FOUND %d  ·  %s", state.Found or 0, who)
end

local function stateOf()
	local exit = player:GetAttribute("RiftExitAt")
	return {
		Room = player:GetAttribute("RiftRoom") or 1,
		Left = player:GetAttribute("RiftLeft") or 0,
		Boss = player:GetAttribute("RiftBoss"),
		BossLevel = player:GetAttribute("RiftBossLevel"),
		Found = player:GetAttribute("RiftFound") or 0,
		Runners = player:GetAttribute("RiftRunners") or 1,
		Won = player:GetAttribute("RiftWon") == true,
		ExitIn = if type(exit) == "number" then math.max(0, math.ceil(exit - serverNow())) else nil,
	}
end

local pips: { Frame } = {}
local whereLabel: TextLabel? = nil
local tallyLabel: TextLabel? = nil

local function buildStrip()
	local s = screen()
	local small = narrow(s)
	-- (On a phone the kaiju strip has the top right while your kit's out,
	-- so this one keeps to the top left, under Roblox's buttons.)
	local bar = new("Frame", {
		Name = "RiftStrip",
		AnchorPoint = if small then Vector2.new(0, 0) else Vector2.new(0.5, 0),
		Position = if small then UDim2.fromOffset(12, 4) else UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(if small then 300 else 430, if small then 44 else 50),
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.12,
	}, s)
	UiKit.round(bar, 10)
	new("UIStroke", { Color = EMBER, Thickness = 1.2, Transparency = 0.25 }, bar)
	local tag = text(bar, "THE RIFT", if small then 10 else 11, EMBER, BOLD)
	tag.AutomaticSize = Enum.AutomaticSize.None
	tag.Position, tag.Size = UDim2.fromOffset(12, 5), UDim2.fromOffset(80, 14)
	-- The caves as pips, the throne's a bigger one: lit up to where you are.
	table.clear(pips)
	for i = 1, RiftRun.Rooms + 1 do
		local throne = i > RiftRun.Rooms
		local size = if throne then 10 else 7
		local pip = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, (if small then 92 else 104) + (i - 1) * 15, 0, 12),
			Size = UDim2.fromOffset(size, size),
			Rotation = 45,
			BackgroundColor3 = P.Slot,
		}, bar)
		table.insert(pips, pip)
	end
	local where = text(bar, "", if small then 12 else 14, P.Text, BOLD)
	where.AutomaticSize, where.TextWrapped = Enum.AutomaticSize.None, false
	where.TextTruncate = Enum.TextTruncate.AtEnd
	where.Position, where.Size = UDim2.fromOffset(12, if small then 21 else 24), UDim2.new(1, -24, 0, 18)
	local tally = text(bar, "", if small then 10 else 11, P.Gold, BOLD)
	tally.AutomaticSize = Enum.AutomaticSize.None
	tally.TextXAlignment = Enum.TextXAlignment.Right
	tally.AnchorPoint = Vector2.new(1, 0)
	tally.Position, tally.Size = UDim2.new(1, -12, 0, 5), UDim2.fromOffset(150, 14)
	-- BACKUP: the list of who you can call in, anywhere on the way.
	local chipW, chipH = if small then 58 else 66, if small then 16 else 18
	where.Size = UDim2.new(1, -24 - chipW - 6, 0, 18)
	local chip = new("TextButton", {
		Name = "Backup",
		Text = "BACKUP",
		TextSize = if small then 9 else 10,
		Font = BOLD,
		TextColor3 = P.Teal,
		BackgroundColor3 = Color3.fromRGB(14, 22, 26),
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -5),
		Size = UDim2.fromOffset(chipW, chipH),
	}, bar)
	UiKit.round(chip, 5)
	new("UIStroke", { Color = P.Teal, Thickness = 1, Transparency = 0.4 }, chip)
	chip.Activated:Connect(RiftClient.openBackup)
	whereLabel, tallyLabel = where, tally
	strip = bar
end

local function refreshStrip()
	if not strip then
		return
	end
	local state = stateOf()
	local where, tally = RiftClient.stripText(state);
	(whereLabel :: TextLabel).Text = where;
	(tallyLabel :: TextLabel).Text = tally
	for i, pip in pips do
		local done = i < state.Room or state.Won
		local here = i == state.Room and not state.Won
		pip.BackgroundColor3 = if done then EMBER elseif here then WARN else P.Slot
		pip.BackgroundTransparency = if here or done then 0 else 0.2
	end
end

-- Down at the boss --------------------------------------------------------------------------------------------

local downClock: TextLabel? = nil
local downFill: Frame? = nil
local restoreButton: TextButton? = nil
-- The backup lists (Shared.RiftLobby.backup), redrawn as the server
-- changes: the down card's, and the BACKUP window's from the strip.
type BackupView = { List: ScrollingFrame, Head: TextLabel, Hint: TextLabel, Small: boolean, Drawn: string? }
local backupViews: { BackupView } = {}
local backupCard: Frame? = nil

local function choose(choice: string)
	task.spawn(function()
		local result = GemClient.request("RiftChoice", choice)
		if not result.Ok and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, P.Bad)
		end
	end)
end

-- Calling someone in from down there: a party invite (they come to you
-- through any Rift Gate), or Roblox's invite for a friend who isn't here.
local function callIn(person)
	invited[person.UserId] = os.clock()
	for _, view in backupViews do
		view.Drawn = nil
	end
	if person.Invite == "Game" then
		local s = social()
		if s then
			s.inviteFriends(person.UserId)
		end
	else
		task.spawn(function()
			local result = GemClient.request("PartyInvite", person.UserId)
			UiKit.toast(result.Message or "", if result.Ok then P.Gold else P.Bad)
			if not result.Ok then
				invited[person.UserId] = nil
				for _, view in backupViews do
					view.Drawn = nil
				end
			end
		end)
	end
end

-- The backup list in `parent` (a box the caller sizes): its head, the
-- scrolling rows and the hint along the bottom. Registered for refreshes
-- until its box is gone.
local function backupPanel(parent: Frame, small: boolean): BackupView
	local headH, hintH = 18, if small then 26 else 30
	local head = text(parent, "CALL FOR BACKUP", if small then 11 else 12, P.Teal, BOLD)
	head.AutomaticSize = Enum.AutomaticSize.None
	head.Size = UDim2.new(1, 0, 0, headH)
	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, headH + 4),
		Size = UDim2.new(1, 0, 1, -(headH + 4 + hintH + 4)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = P.Dim,
	}, parent)
	UiKit.list(list, 4)
	local hint = text(parent, "", if small then 9 else 10, P.Dim)
	hint.AutomaticSize = Enum.AutomaticSize.None
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.fromScale(0, 1)
	hint.Size = UDim2.new(1, 0, 0, hintH)
	local view: BackupView = { List = list, Head = head, Hint = hint, Small = small, Drawn = nil }
	table.insert(backupViews, view)
	return view
end

-- Drawn again only when something shown has changed.
local function refreshBackupView(view: BackupView, lobby)
	local rows = RiftLobby.backup(lobby)
	local sig = { tostring(lobby.Lead), tostring(lobby.Size) }
	for _, row in rows do
		table.insert(sig, string.format("%d%s%s%s", row.UserId, tostring(row.Name), tostring(row.Where), tostring(row.Invite)))
	end
	local signature = table.concat(sig, ";")
	if signature == view.Drawn then
		return
	end
	view.Drawn = signature
	for _, child in view.List:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, person in rows do
		personRow(view.List, person, i, view.Small, true, callIn)
	end
	if #rows == 0 then
		local empty = text(view.List, "Nobody's about: no one else in the Outpost, none of your friends online.", if view.Small then 10 else 11, P.Dim)
		empty.LayoutOrder = 1
	end
	view.Head.Text = string.format("CALL FOR BACKUP  ·  %d/%d IN YOUR PARTY", lobby.Size, RiftRun.Party)
	view.Hint.Text = if not lobby.Lead
		then "Only your party's leader can invite."
		elseif lobby.Size >= RiftRun.Party then "Your party's full: everyone's here or on their way."
		else "INVITE asks them into your party: they come to you through any Rift Gate."
end

-- Every list that's still up, from one look at the server; gone ones dropped.
local function refreshBackups()
	for i = #backupViews, 1, -1 do
		if not backupViews[i].List.Parent then
			table.remove(backupViews, i)
		end
	end
	if #backupViews == 0 then
		return
	end
	local lobby = RiftLobby.lobby(lobbyView(nil))
	for _, view in backupViews do
		refreshBackupView(view, lobby)
	end
end

-- BACKUP, from the strip: the list on its own, anywhere in the Rift (on
-- the way or at the boss), to be closed again.
function RiftClient.openBackup()
	if backupCard and backupCard.Parent then
		return
	end
	local s = screen()
	local small = narrow(s)
	local panel, holder = modal("RiftBackup", math.min(if small then 440 else 480, s.AbsoluteSize.X - 24), P.Teal, true, small)
	backupCard = panel
	local title = text(panel, "BACKUP", if small then 18 else 22, P.Teal, IronUi.Heading)
	title.LayoutOrder = 1
	local line = text(panel, "Call miners in from the Outpost: they come to you through any Rift Gate.", if small then 11 else 12, P.Text)
	line.LayoutOrder = 2
	local box = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, if small then 190 else 280), LayoutOrder = 3 }, panel)
	backupPanel(box, small)
	local closeButton = button(panel, "CLOSE", P.Edge, 4, function()
		holder:Destroy()
	end, if small then 34 else 40)
	closeButton.Name = "Close"
	refreshBackups()
end

-- RESTORE's price: Robux once its product is on, coins till then.
local function restoreLabel(): string
	if (Store.RobuxProducts.RiftRestore or 0) ~= 0 then
		return string.format("RESTORE  ·  R$ %d", Store.RobuxPrices.RiftRestore)
	end
	return string.format("RESTORE  ·  %d COINS", player:GetAttribute("RiftRestore") or RiftRun.Restore.Coins)
end

-- Down at the boss: on the left what you can do for yourself (RESTORE,
-- BACK TO BASE, the clock running down); on the right who you can call
-- in, the gate's lobby again (your party, the Outpost, your friends).
local function showDown()
	if downCard and downCard.Parent then
		return
	end
	local s = screen()
	local small = narrow(s)
	local width = math.min(if small then 660 else 780, s.AbsoluteSize.X - 24)
	local panel = modal("RiftDown", width, HELL, false, small)
	downCard = panel
	local title = text(panel, "YOU'RE DOWN", if small then 20 else 24, P.Bad, IronUi.Heading)
	title.LayoutOrder = 1
	local boss = player:GetAttribute("RiftBoss") or "The boss"
	local line = text(
		panel,
		string.format("%s is still standing. Your kaiju fight on without you: get back up, call for backup, or head home.", boss),
		if small then 11 else 13,
		P.Text
	)
	line.LayoutOrder = 2
	local columns = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 200 else 300),
		LayoutOrder = 3,
	}, panel)
	local leftW = 0.42
	local left = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(leftW, -6, 1, 0) }, columns)
	UiKit.list(left, if small then 5 else 8)
	local right = new("Frame", {
		Name = "Backup",
		BackgroundColor3 = Color3.fromRGB(14, 12, 18),
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(1 - leftW, -6, 1, 0),
	}, columns)
	UiKit.round(right, 8)
	new("UIStroke", { Color = P.Teal, Thickness = 1, Transparency = 0.5 }, right)
	UiKit.pad(right, if small then 6 else 8)
	-- The time left to choose, running down.
	local track = new("Frame", {
		BackgroundColor3 = P.Slot,
		Size = UDim2.new(1, 0, 0, 6),
		LayoutOrder = 1,
	}, left)
	UiKit.round(track, 3)
	local fill = new("Frame", { BackgroundColor3 = HELL, Size = UDim2.fromScale(1, 1) }, track)
	UiKit.round(fill, 3)
	local clock = text(left, "", if small then 11 else 12, P.Dim, BOLD)
	clock.LayoutOrder = 2
	downClock, downFill = clock, fill
	local tall = if small then 36 else 44
	restoreButton = button(left, restoreLabel(), P.Gold, 3, function()
		choose("Restore")
	end, tall)
	local note = text(left, "You and your kaiju, back to full health, right here.", if small then 10 else 11, P.Dim)
	note.LayoutOrder = 4
	button(left, "BACK TO BASE", P.Edge, 5, function()
		choose("Home")
	end, tall)
	local keep = text(left, "Home with the gems you found.", if small then 10 else 11, P.Dim)
	keep.LayoutOrder = 6
	-- Who you can call in.
	backupPanel(right, small)
	-- (The BACKUP window, if it was open: this card has it now.)
	if backupCard and backupCard.Parent then
		close(backupCard)
		backupCard = nil
	end
end

local function refreshDown()
	local deadline = player:GetAttribute("RiftFallen")
	if type(deadline) ~= "number" then
		close(downCard)
		downCard = nil
		return
	end
	showDown()
	local left = math.max(0, deadline - serverNow())
	if downClock then
		downClock.Text =
			string.format("Back to base by itself in %d:%02d", math.floor(left) // 60, math.floor(left) % 60)
	end
	if downFill then
		downFill.Size = UDim2.fromScale(math.clamp(left / RiftRun.Fallen, 0, 1), 1)
	end
	if restoreButton then
		restoreButton.Text = restoreLabel()
	end
end

-- Watching your attributes ------------------------------------------------------------------------------------

local inside = false
local ticking = false

local function tick()
	if ticking then
		return
	end
	ticking = true
	task.spawn(function()
		while inside do
			refreshStrip()
			refreshDown()
			refreshBackups()
			task.wait(0.25)
		end
		ticking = false
	end)
end

local function changed()
	local now = player:GetAttribute("RiftRun") ~= nil
	if now and not inside then
		inside = true
		-- (Brought in by your party's leader: the crossing all the same.)
		if not cover then
			crossing(false)()
		end
		close(gateCard)
		RiftClient.hellLighting()
		buildStrip()
		MobileLayout.claimTop("Rift", true)
		tick()
	elseif not now and inside then
		inside = false
		if strip then
			strip:Destroy()
			strip = nil
		end
		close(downCard)
		downCard = nil
		MobileLayout.claimTop("Rift", false)
		outpostLighting()
	end
	if inside then
		refreshStrip()
		refreshDown()
	end
end

local started = false
function RiftClient.start()
	if started then
		return
	end
	started = true
	for _, key in
		{
			"RiftRun",
			"RiftRoom",
			"RiftLeft",
			"RiftBoss",
			"RiftFound",
			"RiftRunners",
			"RiftWon",
			"RiftFallen",
			"RiftRestore",
		}
	do
		player:GetAttributeChangedSignal(key):Connect(changed)
	end
	changed()
end

return RiftClient
