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

local function close(card: Frame?)
	if card and card.Parent then
		card.Parent:Destroy()
	end
end

-- A card in the middle of the screen over a dimmed backdrop: its panel's
-- body (a list) to fill. `dismiss` closes it from the backdrop.
local function modal(name: string, width: number, accent: Color3, dismiss: boolean, compact: boolean?): (Frame, Frame)
	local holder = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen())
	local backdrop = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
	}, holder)
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
	if dismiss then
		backdrop.Activated:Connect(function()
			holder:Destroy()
		end)
	end
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

-- One boss on the gate's ladder, as a card: its portrait over a glow of its
-- element, its threat as pips and its level, its name, its favourite gear
-- and how often you've beaten it. Locked, it's a silhouette with what opens
-- it. Picking it selects it (a locked one just says what opens it).
local function bossCard(parent: Instance, entry, order: number, compact: boolean, onPick: () -> ())
	local accent = GemConfig.ElementColors[entry.Element] or EMBER
	local card = new("TextButton", {
		Name = "Boss_" .. tostring(entry.Id),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(20, 16, 20),
		ClipsDescendants = true,
		LayoutOrder = order,
	}, parent)
	UiKit.round(card, 10)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(accent:Lerp(Color3.new(0, 0, 0), 0.62), Color3.fromRGB(16, 12, 16)),
	}, card)
	local edge = new(
		"UIStroke",
		{ Color = P.Dim, Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
		card
	)
	local foot = if compact then 34 else 50
	-- The stage: a glow behind it, then the boss.
	local glow = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -foot / 2 + 6),
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundColor3 = accent,
		BackgroundTransparency = if entry.Unlocked then 0.8 else 0.92,
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
	-- Its threat (pips) and its level, along the top.
	local color = THREAT_COLORS[entry.Threat] or P.Text
	local pips = new("Frame", {
		Name = "Threat",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(if compact then 8 else 10, if compact then 8 else 11),
		Size = UDim2.fromOffset(60, 10),
	}, card)
	for i = 1, 3 do
		local lit = i <= (entry.Threat or 1)
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(4 + (i - 1) * (if compact then 11 else 13), 5),
			Size = UDim2.fromOffset(if compact then 7 else 8, if compact then 7 else 8),
			Rotation = 45,
			BackgroundColor3 = if lit then color else Color3.fromRGB(60, 54, 60),
			BackgroundTransparency = if entry.Unlocked or not lit then 0 else 0.5,
		}, pips)
	end
	local level = new("TextLabel", {
		Name = "Level",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(if compact then 44 else 54, if compact then 18 else 22),
		BackgroundColor3 = Color3.fromRGB(12, 10, 14),
		BackgroundTransparency = 0.15,
		Text = string.format("LV %d", entry.Level or 1),
		TextSize = if compact then 11 else 13,
		Font = BOLD,
		TextColor3 = if entry.Unlocked then P.Text else P.Dim,
	}, card)
	UiKit.round(level, 6)
	new("UIStroke", {
		Color = color,
		Thickness = 1,
		Transparency = if entry.Unlocked then 0.2 else 0.7,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, level)
	-- Its name and its line, along the bottom.
	local shade = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, foot),
		BackgroundColor3 = Color3.fromRGB(10, 8, 12),
		BackgroundTransparency = 0.2,
	}, card)
	local name = text(shade, entry.Name, if compact then 12 else 15, if entry.Unlocked then P.Text else P.Dim, BOLD)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Position = UDim2.fromOffset(6, if compact then 3 else 7)
	name.Size = UDim2.new(1, -12, 0, if compact then 15 else 19)
	local parts = {}
	if entry.Starter then
		table.insert(parts, "RECOMMENDED SOLO")
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
	local sub = text(shade, table.concat(parts, "  ·  "), if compact then 9 else 11, if entry.Unlocked then P.Dim else WARN)
	sub.AutomaticSize = Enum.AutomaticSize.None
	sub.TextWrapped = false
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.Position = UDim2.fromOffset(6, if compact then 18 else 28)
	sub.Size = UDim2.new(1, -12, 0, if compact then 11 else 14)
	if not entry.Unlocked then
		local lock = text(card, "LOCKED", if compact then 11 else 13, P.Dim, BOLD)
		lock.AutomaticSize = Enum.AutomaticSize.None
		lock.TextXAlignment = Enum.TextXAlignment.Center
		lock.AnchorPoint = Vector2.new(0.5, 0.5)
		lock.Position = UDim2.new(0.5, 0, 0.5, -foot / 2)
		lock.Size = UDim2.new(1, 0, 0, 16)
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

-- A small pill: a word on a tint of `color`.
local function pill(parent: Instance, value: string, color: Color3, size: number): TextLabel
	local label = new("TextLabel", {
		Name = "Pill",
		BackgroundColor3 = color:Lerp(P.Frame, 0.72),
		Size = UDim2.fromOffset(0, size + 8),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = value,
		TextSize = size,
		Font = BOLD,
		TextColor3 = color,
	}, parent)
	UiKit.round(label, 6)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, label)
	return label
end

-- One of your party's places: a member, or an open place to invite into.
-- In a party, your own card has LEAVE (`acts.Leave`), and the leader sees a
-- red × on each of the others' to remove them (`acts.Kick`).
local function partySlot(parent: Instance, slot, order: number, compact: boolean, acts)
	local card = new("Frame", {
		Name = if slot then "Member" else "Open",
		BackgroundColor3 = if slot then Color3.fromRGB(26, 22, 30) else Color3.fromRGB(16, 14, 20),
		LayoutOrder = order,
	}, parent)
	UiKit.round(card, 8)
	new("UIStroke", {
		Color = if not slot then P.Edge elseif slot.Ready or slot.You then P.Good else P.Edge,
		Thickness = if slot and (slot.Ready or slot.You) then 1.5 else 1,
		Transparency = if slot then 0.15 else 0.6,
	}, card)
	if not slot then
		local open = text(card, "OPEN", if compact then 11 else 12, P.Dim, BOLD)
		open.TextXAlignment = Enum.TextXAlignment.Center
		open.AutomaticSize = Enum.AutomaticSize.None
		open.AnchorPoint = Vector2.new(0.5, 0.5)
		open.Position = UDim2.new(0.5, 0, 0.5, if compact then -6 else -8)
		open.Size = UDim2.new(1, -8, 0, 14)
		local hint = text(card, "Invite from the list", if compact then 9 else 10, P.Dim)
		hint.TextXAlignment = Enum.TextXAlignment.Center
		hint.AutomaticSize = Enum.AutomaticSize.None
		hint.AnchorPoint = Vector2.new(0.5, 0.5)
		hint.Position = UDim2.new(0.5, 0, 0.5, if compact then 7 else 9)
		hint.Size = UDim2.new(1, -8, 0, 12)
		return card
	end
	local face = if compact then 24 else 34
	local pic = headshot(card, slot.UserId, slot.Name or "?", face, if slot.Leader then P.Gold else P.Edge)
	pic.Position = UDim2.fromOffset(if compact then 6 else 8, if compact then 5 else 9)
	local left = face + (if compact then 11 else 14)
	local name = text(card, slot.Name or "?", if compact then 12 else 14, P.Text, BOLD)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Position = UDim2.fromOffset(left, if compact then 3 else 8)
	name.Size = UDim2.new(1, -left - 6, 0, if compact then 15 else 18)
	local where = text(card, if slot.You then "YOU" else string.upper(slot.Where), if compact then 9 else 10, P.Dim, BOLD)
	where.AutomaticSize = Enum.AutomaticSize.None
	where.TextWrapped = false
	where.TextTruncate = Enum.TextTruncate.AtEnd
	where.Position = UDim2.fromOffset(left, if compact then 17 else 27)
	where.Size = UDim2.new(1, -left - 6, 0, 12)
	-- (Along the bottom: ready or not, and who leads.)
	local pills = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, if compact then 6 else 8, 1, if compact then -4 else -8),
		Size = UDim2.new(1, -12, 0, if compact then 15 else 18),
	}, card)
	UiKit.list(pills, 4, true)
	local ready = slot.Ready or (slot.Leader and slot.You)
	pill(pills, if ready then "READY" else "NOT READY", if ready then P.Good else P.Dim, if compact then 8 else 10).LayoutOrder = 1
	if slot.Leader then
		pill(pills, "LEADER", P.Gold, if compact then 8 else 10).LayoutOrder = 2
	end
	-- (LEAVE top right on yours; × bottom right on theirs, by the READY pill,
	-- so where they are keeps the whole line.)
	local act = if slot.You then acts and acts.Leave else acts and acts.Kick
	if act then
		local side = if compact then 18 else 22
		local inset = if compact then 4 else 6
		local b = new("TextButton", {
			Name = if slot.You then "Leave" else "Kick",
			AnchorPoint = if slot.You then Vector2.new(1, 0) else Vector2.new(1, 1),
			Position = if slot.You then UDim2.new(1, -inset, 0, inset) else UDim2.new(1, -inset, 1, -inset),
			Size = if slot.You then UDim2.fromOffset(if compact then 40 else 46, side) else UDim2.fromOffset(side, side),
			BackgroundColor3 = P.Bad:Lerp(P.Frame, 0.6),
			Text = if slot.You then "LEAVE" else "",
			TextSize = if compact then 9 else 10,
			Font = BOLD,
			TextColor3 = P.Text,
			AutoButtonColor = true,
		}, card)
		UiKit.round(b, 6)
		new("UIStroke", { Color = P.Bad, Thickness = 1, Transparency = 0.35 }, b)
		b.Activated:Connect(function()
			act(slot)
		end)
		if slot.You then
			-- (your name makes room for it)
			name.Size = UDim2.new(1, -left - 6 - b.Size.X.Offset - 4, 0, if compact then 15 else 18)
		else
			IronUi.cross(b, if compact then 7 else 9, P.Text)
		end
	end
	return card
end

-- A row in the people list: a face, a name and where they are, an action.
-- (FRIEND after where they are in the Outpost's list; the Friends tab is
-- all friends.)
local function personRow(parent: Instance, row, order: number, compact: boolean, tagFriend: boolean, onInvite: (any) -> ())
	local tall = if compact then 34 else 42
	local line = new("Frame", {
		Name = "Row",
		BackgroundColor3 = Color3.fromRGB(22, 20, 28),
		BackgroundTransparency = if order % 2 == 0 then 0.35 else 0,
		Size = UDim2.new(1, 0, 0, tall),
		LayoutOrder = order,
	}, parent)
	UiKit.round(line, 6)
	local face = tall - 10
	local pic = headshot(line, row.UserId, row.Name, face, if row.Friend then P.Teal else P.Edge)
	pic.Position = UDim2.fromOffset(6, 5)
	local actionW = if compact then 74 else 88
	local name = text(
		line,
		row.Name .. (if row.Level then string.format("  ·  LV %d", row.Level) else ""),
		if compact then 12 else 13,
		P.Text,
		BOLD
	)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Position = UDim2.fromOffset(face + 12, if compact then 3 else 5)
	name.Size = UDim2.new(1, -face - actionW - 22, 0, if compact then 15 else 17)
	local where = text(
		line,
		row.Where .. (if tagFriend and row.Friend then "  ·  FRIEND" else ""),
		if compact then 9 else 11,
		if row.Where == "At the gate" then P.Good else P.Dim
	)
	where.AutomaticSize = Enum.AutomaticSize.None
	where.TextWrapped = false
	where.TextTruncate = Enum.TextTruncate.AtEnd
	where.Position = UDim2.fromOffset(face + 12, if compact then 18 else 23)
	where.Size = UDim2.new(1, -face - actionW - 22, 0, 13)
	if row.Invite == "Party" or row.Invite == "Game" then
		local b, f = IronUi.chunk(line, {
			Color = P.Teal,
			Size = UDim2.fromOffset(actionW, tall - 10),
			Radius = 6,
			Stripes = "None",
			Lip = 3,
		})
		IronUi.label(b, f, if row.Invite == "Party" then "INVITE" else "INVITE ↗", if compact then 11 else 12, BOLD)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -6, 0.5, 0)
		b.Activated:Connect(function()
			onInvite(row)
		end)
	elseif row.Invite then
		local word = if row.Invite == "Invited" then "INVITED" elseif row.Where == "In the Rift" then "IN THE RIFT" else "IN A PARTY"
		local tag = pill(line, word, if row.Invite == "Invited" then P.Teal else P.Dim, if compact then 9 else 10)
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.new(1, -8, 0.5, 0)
	end
	return line
end

-- A step's heading: its number in a ring, then what it is.
local function stepHead(parent: Instance, n: number, label: string, order: number, small: boolean): TextLabel
	local row = new("Frame", {
		Name = "Step" .. n,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 16 else 22),
		LayoutOrder = order,
	}, parent)
	local ring = new("TextLabel", {
		BackgroundColor3 = EMBER:Lerp(P.Frame, 0.55),
		Size = UDim2.fromOffset(if small then 16 else 22, if small then 16 else 22),
		Text = tostring(n),
		TextSize = if small then 10 else 13,
		Font = BOLD,
		TextColor3 = P.Text,
	}, row)
	UiKit.round(ring, 999)
	new("UIStroke", { Color = EMBER, Thickness = 1 }, ring)
	local words = text(row, label, if small then 11 else 13, P.Gold, BOLD)
	words.AutomaticSize = Enum.AutomaticSize.None
	words.TextWrapped = false
	words.TextTruncate = Enum.TextTruncate.AtEnd
	words.Position = UDim2.fromOffset(if small then 22 else 30, 0)
	words.Size = UDim2.new(1, if small then -22 else -30, 1, 0)
	return words
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
	local panel, holder = modal("RiftGate", width, EMBER, true, small)
	gateCard = panel

	-- The header: what this is and where, a close button on the right.
	local header = new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if small then 34 else 46),
		LayoutOrder = 1,
	}, panel)
	local title = text(header, if info.Bounty then "BOUNTY BOARD" else "RIFT GATE", if small then 18 else 24, EMBER, IronUi.Heading)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Size = UDim2.new(1, -50, 0, if small then 20 else 28)
	local where = if info.Bounty
		then "BRUTUS'S BOUNTIES  ·  EVERY BOSS BEHIND THE RIFT GATES"
		else string.upper(string.format("%s  ·  %s Rift", info.Biome or "", GemConfig.elementName(info.Element or "")))
			.. (if small then "" else string.format("  ·  %d CAVES, THEN THE BOSS", RiftRun.Rooms))
	local sub = text(
		header,
		where,
		if small then 10 else 12,
		if info.Bounty then WARN else GemConfig.ElementColors[info.Element or ""] or P.Text,
		BOLD
	)
	sub.AutomaticSize = Enum.AutomaticSize.None
	sub.Position = UDim2.fromOffset(0, if small then 21 else 29)
	sub.Size = UDim2.new(1, -50, 0, 14)
	local side = if small then 30 else 36
	local cancel = new("TextButton", {
		Name = "Close",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = Color3.fromRGB(26, 22, 30),
		AutoButtonColor = true,
	}, header)
	UiKit.round(cancel, 8)
	new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.3 }, cancel)
	IronUi.cross(cancel, if small then 10 else 12, P.Dim)
	cancel.Activated:Connect(function()
		close(gateCard)
	end)

	-- Two columns: the boss and getting ready (left), your party (right).
	local gap = if small then 8 else 14
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

	stepHead(left, 1, if info.Joining then "YOUR PARTY'S BOSS" elseif info.Ladders then "CHOOSE A BIOME, THEN YOUR BOSS" else "CHOOSE YOUR BOSS", 1, small)
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
			P.Good,
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
				Size = UDim2.new(1, 0, 0, if small then 22 else 30),
				LayoutOrder = 2,
			}, left)
			new("UIGridLayout", {
				CellSize = UDim2.new(1 / #info.Ladders, -6, 1, 0),
				CellPadding = UDim2.fromOffset(8, 0),
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
				c.Edge.Color = if on then EMBER else P.Dim
				c.Edge.Thickness = if on then 2.5 else 1
				c.Edge.Transparency = if on then 0 else 0.55
				c.Card.BackgroundColor3 = if on then Color3.fromRGB(44, 26, 22) else Color3.fromRGB(20, 16, 20)
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
			for i, entry in info.Ladders do
				local on = i == biome
				local tint = GemConfig.ElementColors[entry.Element] or P.Text
				local b = new("TextButton", {
					Name = entry.Biome,
					Text = string.upper(entry.Biome),
					TextSize = if small then 10 else 12,
					Font = BOLD,
					TextColor3 = if on then P.Text else tint,
					BackgroundColor3 = if on then tint:Lerp(Color3.new(0, 0, 0), 0.62) else Color3.fromRGB(20, 16, 20),
					AutoButtonColor = false,
					LayoutOrder = i,
				}, biomeRow)
				UiKit.round(b, 6)
				new("UIStroke", {
					Color = tint,
					Thickness = if on then 2 else 1,
					Transparency = if on then 0 else 0.6,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border, -- (round the tab, not its word)
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
	readyHead = stepHead(left, 2, "GET READY", 4, small)
	readyCard = new("Frame", {
		Name = "Ready",
		BackgroundColor3 = Color3.fromRGB(18, 16, 24),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
	}, left)
	UiKit.round(readyCard, 10)
	local readyEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, readyCard)
	new("UIPadding", {
		PaddingTop = UDim.new(0, if small then 6 else 10),
		PaddingBottom = UDim.new(0, if small then 6 else 10),
		PaddingLeft = UDim.new(0, if small then 8 else 12),
		PaddingRight = UDim.new(0, if small then 8 else 12),
	}, readyCard)

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

	redrawReady = function()
		local chosen = entryOf(picked)
		readyCard:ClearAllChildren()
		readyEdge = new("UIStroke", { Color = P.Edge, Thickness = 1.5 }, readyCard)
		new("UIPadding", {
			PaddingTop = UDim.new(0, if small then 6 else 10),
			PaddingBottom = UDim.new(0, if small then 6 else 10),
			PaddingLeft = UDim.new(0, if small then 8 else 12),
			PaddingRight = UDim.new(0, if small then 8 else 12),
		}, readyCard)
		UiKit.list(readyCard, if small then 4 else 6)
		readyHead.Text = if chosen then "GET READY FOR " .. string.upper(chosen.Name) else "GET READY"
		if not chosen then
			readyEdge.Color = P.Edge
			text(readyCard, "Pick a boss to see what it takes.", if small then 11 else 12, P.Dim).LayoutOrder = 1
			return
		end
		local tint = GemConfig.ElementColors[chosen.Element or ""] or EMBER
		readyEdge.Color = tint
		-- What it is: its element, what beats it, its level, built for how many.
		local chips = new("Frame", {
			Name = "Chips",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if small then 16 else 20),
			LayoutOrder = 1,
		}, readyCard)
		UiKit.list(chips, 5, true)
		local size = if small then 9 else 11
		pill(chips, "HITS WITH " .. string.upper(GemConfig.elementName(chosen.Element or "")), tint, size).LayoutOrder = 1
		if chosen.Weakness then
			local weak = GemConfig.ElementColors[chosen.Weakness] or P.Good
			pill(chips, "WEAK TO " .. string.upper(GemConfig.elementName(chosen.Weakness)), weak, size).LayoutOrder = 2
		end
		if chosen.Level then
			pill(chips, string.format("LV %d", chosen.Level), THREAT_COLORS[chosen.Threat or 1] or P.Text, size).LayoutOrder = 3
		end
		if chosen.Starter then
			pill(chips, "FIRST BOSS · SOLO", P.Good, size).LayoutOrder = 4
		elseif chosen.Group then
			local alone = view and view.Size <= 1
			pill(chips, if alone then "BRING FRIENDS · 2-4" else "FOR 2-4", if alone then WARN else P.Dim, size).LayoutOrder = 4
		end
		-- How to beat it, and what it punishes (the computer's card).
		if not small and chosen.Tips then
			for i, line in { chosen.Tips[3], chosen.Tips[4] } do
				if line then
					local l = text(readyCard, "•  " .. line, 12, P.Text)
					l.LayoutOrder = 1 + i
				end
			end
		end
		-- ADJUST ARMOR: what your armor takes of its hits now, and after.
		local bar = new("Frame", {
			Name = "Armor",
			BackgroundColor3 = Color3.fromRGB(26, 24, 34),
			Size = UDim2.new(1, 0, 0, if small then 36 else 48),
			LayoutOrder = 10,
		}, readyCard)
		UiKit.round(bar, 8)
		new("UIStroke", { Color = P.Teal, Thickness = 1, Transparency = 0.55 }, bar)
		local buttonW = if small then 112 else 156
		local head = text(
			bar,
			"YOUR ARMOR VS " .. string.upper(GemConfig.elementName(chosen.Element or "")),
			if small then 10 else 12,
			P.Text,
			BOLD
		)
		head.AutomaticSize = Enum.AutomaticSize.None
		head.TextWrapped = false
		head.TextTruncate = Enum.TextTruncate.AtEnd
		head.Position = UDim2.fromOffset(10, if small then 3 else 6)
		head.Size = UDim2.new(1, -buttonW - 24, 0, if small then 14 else 16)
		local plan = planOf(chosen)
		local line, lineColor
		if not plan then
			line, lineColor = "Checking your gear...", P.Dim
		elseif plan.Changes > 0 then
			line = string.format(
				"Takes %s of its hits  ·  %s after (%d change%s)",
				share(plan.Before),
				share(plan.After),
				plan.Changes,
				if plan.Changes == 1 then "" else "s"
			)
			lineColor = P.Teal
		elseif plan.Before < 0.995 then
			line, lineColor = string.format("Takes %s of its hits: as little as your gems allow", share(plan.Before)), P.Good
		else
			line, lineColor = plan.Note or "No gems in your bag resist it", WARN
		end
		local what = text(bar, line, if small then 9 else 11, lineColor)
		what.AutomaticSize = Enum.AutomaticSize.None
		what.TextWrapped = false
		what.TextTruncate = Enum.TextTruncate.AtEnd
		what.Position = UDim2.fromOffset(10, if small then 18 else 25)
		what.Size = UDim2.new(1, -buttonW - 24, 0, if small then 12 else 15)
		if plan and plan.Changes == 0 then
			local ready = plan.Before < 0.995
			local done = pill(bar, if ready then "✓ ARMOR READY" else "NO GEMS FOR IT", if ready then P.Good else WARN, if small then 10 else 12)
			done.AnchorPoint = Vector2.new(1, 0.5)
			done.Position = UDim2.new(1, -8, 0.5, 0)
		else
			local b, f = IronUi.chunk(bar, {
				Color = P.Teal,
				Size = UDim2.fromOffset(buttonW, if small then 28 else 36),
				Radius = 6,
				Stripes = "None",
				Lip = 3,
			})
			b.Name = "Adjust"
			IronUi.label(b, f, "ADJUST ARMOR", if small then 11 else 13, BOLD)
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, -6, 0.5, 0)
			b.Activated:Connect(function()
				adjust(chosen)
			end)
		end
	end

	-- 3: your party, and who's about to invite.
	local partyHead = stepHead(column, 3, "YOUR PARTY", 1, small)
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
		BackgroundColor3 = Color3.fromRGB(14, 12, 18),
		Size = UDim2.new(1, 0, 0, listTall),
		LayoutOrder = 3,
	}, column)
	UiKit.round(people, 10)
	new("UIStroke", { Color = P.Edge, Thickness = 1, Transparency = 0.5 }, people)
	UiKit.pad(people, if small then 5 else 8)
	local tabTall = if small then 22 else 28
	local tabs = new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tabTall),
	}, people)
	new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -3, 1, 0),
		CellPadding = UDim2.fromOffset(6, 0),
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
		ScrollBarImageColor3 = P.Dim,
		BorderSizePixel = 0,
	}, people)
	UiKit.list(scroller, 4)
	local inviteAll, inviteFace = IronUi.chunk(people, {
		Color = P.Teal,
		Size = UDim2.new(1, 0, 0, inviteAllTall),
		Radius = 6,
		Stripes = "None",
		Lip = 3,
	})
	IronUi.label(inviteAll, inviteFace, "INVITE FRIENDS TO THE GAME", if small then 10 else 13, BOLD)
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
	local hint = text(panel, "", 11, P.Dim)
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
		partyHead.Text = string.format("YOUR PARTY  ·  %d/%d", view.Size, RiftRun.Party)
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
		for i, spec in {
			{ "Outpost", string.format("IN THE OUTPOST  %d", #view.Outpost) },
			{ "Friends", if friendsKnown then string.format("FRIENDS  %d", #view.Friends) else "FRIENDS" },
		} do
			local on = tab == spec[1]
			local b = new("TextButton", {
				Name = spec[1],
				Text = spec[2],
				TextSize = if small then 10 else 12,
				Font = BOLD,
				TextColor3 = if on then P.Text else P.Dim,
				BackgroundColor3 = if on then P.Slot else Color3.fromRGB(18, 16, 24),
				AutoButtonColor = false,
				LayoutOrder = i,
			}, tabs)
			UiKit.round(b, 6)
			if on then
				new("UIStroke", { Color = P.Teal, Thickness = 1, Transparency = 0.3 }, b)
			end
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
				P.Dim
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
			if how == "Member" then
				if mine and mine.Ready then
					button(row, "NOT READY", P.Edge, 1, function()
						ready(false)
					end, tall)
				else
					button(row, "READY", P.Good, 1, function()
						ready(true)
					end, tall)
				end
				button(row, "GO IN NOW", HELL, 2, go, tall)
			else
				local enter = button(row, "ENTER", HELL, 1, go, tall)
				enter.Name = "Enter"
			end
		end
		local enter = row:FindFirstChild("Enter") :: TextButton?
		if enter then
			enter.Text = if how == "Join"
				then "JOIN THEM"
				elseif how == "Alone" then "ENTER ALONE"
				elseif view.Ready >= view.Size - 1 then "ENTER TOGETHER"
				else string.format("ENTER  ·  %d OF %d READY", view.Ready + 1, view.Size)
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
	local cost = player:GetAttribute("RiftRestore") or RiftRun.Restore.Coins
	local tall = if small then 36 else 44
	restoreButton = button(left, string.format("RESTORE  ·  %d COINS", cost), P.Gold, 3, function()
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
		local cost = player:GetAttribute("RiftRestore") or RiftRun.Restore.Coins
		restoreButton.Text = string.format("RESTORE  ·  %d COINS", cost)
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
