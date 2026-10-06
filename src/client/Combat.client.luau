-- First-person timed attacks, alternating sides, reactive guard and universal dodge.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Combat = require(ReplicatedStorage.Shared.Combat)
local Actions = require(ReplicatedStorage.Shared.CombatActions)
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local SurgeIcons = require(script.Parent.Modules.SurgeIcons)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local ArenaScene = require(script.Parent.Modules.ArenaScene)
local CombatGuide = require(script.Parent.Modules.CombatGuide)
local AugmentTreeUI = require(script.Parent.Modules.AugmentTreeUI)
local FirstPerson = require(script.Parent.Modules.FirstPersonCombat)
local TargetLock = require(script.Parent.Modules.TargetLock)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local StatusBars = require(script.Parent.Modules.StatusBars)
local FoeCastBar = require(script.Parent.Modules.FoeCastBar)
local CombatLogUI = require(script.Parent.Modules.CombatLogUI)
local CombatFx = require(script.Parent.Modules.CombatFx)
local CombatVfx = require(script.Parent.Modules.CombatVfx)
local CombatSound = require(script.Parent.Modules.CombatSound)
local MatchupUI = require(script.Parent.Modules.MatchupUI)
local StatusEffects = require(ReplicatedStorage.Shared.StatusEffects)
local UiKit = require(script.Parent.Modules.UiKit)
local HudChrome = require(script.Parent.Modules.HudChrome)
if Config.MenuOnly and not Config.CombatEnabled then
	return
end
local player = Players.LocalPlayer
local input = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatInput")
local fxEvent = ReplicatedStorage.Remotes:WaitForChild("CombatFx")
local P = IronUi.Colors
local new, text = IronUi.new, IronUi.text
local cooldowns = {}
local attackSide, nextSide, cursorFree = "Right", "Right", false
local feedbackUntil = 0
local guideWasOpen = false
local attackTouch, blockTouch, surgeTouch
local beamKey, nextBeamUpdate = nil, 0 -- the surge key held to channel a beam
local SURGE_KEYS = { "Q", "E", "R" }
local ROMAN = { "I", "II", "III" }
local techCooldowns = {} -- [cooldown key] = { Ready, Total }
local hitUntil, hitCritical = 0, false
local incomingUntil, incomingOrigin = 0, nil
local healthTrailRatio, targetTrailRatio, lastTarget = 1, 1, nil
local cast = nil -- a wind-up in progress: { Name, Start, Duration, Color }
local comboUntil, flashUntil, fightSince = 0, 0, 0
local holding, blockHeld, chargeStarted, nextAttack, nextBlockUpdate = false, false, 0, 0, 0
local gui = UiKit.gui("CombatHud", 5)
-- Low-health / damage vignette: four soft red edges, drawn under everything.
local vignette = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, gui)
for _, edge in
	{
		{ UDim2.fromScale(0, 0), UDim2.new(1, 0, 0.18, 0), 90 },
		{ UDim2.fromScale(0, 0.82), UDim2.new(1, 0, 0.18, 0), 270 },
		{ UDim2.fromScale(0, 0), UDim2.new(0.12, 0, 1, 0), 0 },
		{ UDim2.fromScale(0.88, 0), UDim2.new(0.12, 0, 1, 0), 180 },
	}
do
	local frame = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(190, 20, 30),
		BorderSizePixel = 0,
		Position = edge[1],
		Size = edge[2],
	}, vignette)
	new("UIGradient", { Rotation = edge[3], Transparency = NumberSequence.new(0.35, 1) }, frame)
end
local function shadowed(label)
	label.TextStrokeColor3, label.TextStrokeTransparency = Color3.new(0, 0, 0), 0.45
	return label
end
local function fillGradient(frame, color)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.2)),
	}, frame)
end
-- Bottom of the screen, one stack: the action bar (surges Q/E/R, then
-- maneuvers 1/2/3) and above it the vitals: Charge on the left, Health in
-- the middle (draining from both ends) and Stamina on the right.
local hud = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -120),
	Size = UDim2.fromOffset(600, 34),
}, gui)
local nameLabel = shadowed(text(hud, string.upper(player.DisplayName), 12, HudChrome.Parchment, HudChrome.Title))
nameLabel.AutomaticSize, nameLabel.TextWrapped, nameLabel.TextTruncate =
	Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
nameLabel.TextXAlignment = Enum.TextXAlignment.Center
local hp = shadowed(text(hud, "", 10, Color3.fromRGB(150, 225, 255), IronUi.Bold))
hp.AutomaticSize, hp.TextWrapped = Enum.AutomaticSize.None, false
hp.TextXAlignment = Enum.TextXAlignment.Right
local healthTrack = new("Frame", { BorderSizePixel = 0 }, hud)
UiKit.round(healthTrack, 2)
HudChrome.capBar(healthTrack)
local healthTrail = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(255, 196, 110),
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(1, 1),
}, healthTrack)
UiKit.round(healthTrail, 2)
-- Barrier (shield) absorbs: a pale band either side of current health.
local shieldFill = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(190, 240, 255),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(0, 1),
	ZIndex = 2,
}, healthTrack)
UiKit.round(shieldFill, 2)
local healthFill = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(1, 1),
	ZIndex = 3,
}, healthTrack)
UiKit.round(healthFill, 2)
local healthGradient = new("UIGradient", { Rotation = 90 }, healthFill)
local healthText = shadowed(text(healthTrack, "", 10, P.Text, IronUi.Bold))
healthText.AutomaticSize, healthText.TextWrapped = Enum.AutomaticSize.None, false
healthText.TextXAlignment, healthText.Size, healthText.ZIndex = Enum.TextXAlignment.Center, UDim2.fromScale(1, 1), 4
local resourceBars = {}
local function resourceBar(parent, id)
	local color = Tech.Resources[id].Color
	local label = shadowed(text(parent, id:upper(), 10, color, IronUi.Bold))
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	local value = shadowed(text(parent, "", 10, P.Text, IronUi.Bold))
	value.AutomaticSize, value.TextWrapped = Enum.AutomaticSize.None, false
	local track = new("Frame", { BorderSizePixel = 0 }, parent)
	UiKit.round(track, 2)
	HudChrome.capBar(track)
	local fill = new(
		"Frame",
		{ BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) },
		track
	)
	UiKit.round(fill, 2)
	fillGradient(fill, color)
	-- Segment ticks every quarter.
	for tick = 1, 3 do
		new("Frame", {
			BackgroundColor3 = HudChrome.Ink,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Position = UDim2.new(tick / 4, -1, 0, 0),
			Size = UDim2.new(0, 1, 1, 0),
			ZIndex = 2,
		}, track)
	end
	resourceBars[id] = { Label = label, Value = value, Track = track, Fill = fill }
end
resourceBar(hud, "Charge")
resourceBar(hud, "Stamina")
-- Floating callouts under the crosshair (PERFECT, PARRIED, Not enough Charge...).
local hint = shadowed(text(gui, "", 15, P.Text, IronUi.Bold))
hint.AutomaticSize, hint.TextWrapped = Enum.AutomaticSize.None, false
hint.AnchorPoint, hint.Position, hint.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.5, 30), UDim2.fromOffset(460, 22)
hint.TextXAlignment = Enum.TextXAlignment.Center
local function centered(parent, size, color)
	local label = text(parent, "", size, color, IronUi.Bold)
	label.AutomaticSize, label.TextWrapped, label.TextTruncate = Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end
-- The action bar: Gem Surges (Q, E, R) | ornament | Rig Maneuvers (1, 2, 3).
local actionBar = HudChrome.actionBar(gui)
local surgeTray = new("Frame", { BackgroundTransparency = 1 }, actionBar.Frame)
local maneuverTray = new("Frame", { BackgroundTransparency = 1 }, actionBar.Frame)
-- One ability icon: a round gem socket (surges) or a square slot
-- (maneuvers), each in a fine gold bezel.
local function makeIcon(parent, key, round)
	local radius = UDim.new(if round then 0.5 else 0.12, 0)
	local button = new(
		"TextButton",
		{ Text = "", AutoButtonColor = false, BackgroundColor3 = P.Inset, BackgroundTransparency = 0.08 },
		parent
	)
	new("UICorner", { CornerRadius = radius }, button)
	local stroke =
		new("UIStroke", { Color = P.Dim, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	local glyph = centered(button, 24, P.Text)
	glyph.Position, glyph.Size = UDim2.fromScale(0, 0.1), UDim2.fromScale(1, 0.56)
	local badge = centered(button, 10, P.Gold)
	badge.Position, badge.Size = UDim2.fromScale(0, 0.64), UDim2.fromScale(1, 0.24)
	badge.ZIndex, badge.TextStrokeTransparency = 2, 0.3
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(62, 62, 72), Color3.fromRGB(16, 17, 23)),
	}, button)
	-- The bezel: a gold ring just outside the element-coloured rim.
	local bezel = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 7, 1, 7),
	}, button)
	new("UICorner", { CornerRadius = if round then radius else UDim.new(0.16, 0) }, bezel)
	new("UIStroke", { Color = HudChrome.GoldDim, Thickness = 1, Transparency = 0.1 }, bezel)
	-- Cooldown: a dark wipe that drains from the top as the ability recovers.
	local shade = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
	}, button)
	new("UICorner", { CornerRadius = radius }, shade)
	local wipe = new("UIGradient", { Rotation = 90 }, shade)
	-- Ready flash: a ring that blooms outward when the cooldown ends.
	local flash = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	}, button)
	new("UICorner", { CornerRadius = radius }, flash)
	local flashStroke = new("UIStroke", { Color = P.Gold, Thickness = 3, Transparency = 1 }, flash)
	local timer = centered(button, 18, P.Text)
	timer.Size, timer.ZIndex = UDim2.fromScale(1, 1), 3
	local chip = new("Frame", {
		BackgroundColor3 = P.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.14, 0.14),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 4,
	}, button)
	UiKit.round(chip, 9)
	local keyLabel = centered(chip, 11, P.Inset)
	keyLabel.Text, keyLabel.Size, keyLabel.ZIndex = key, UDim2.fromScale(1, 1), 4
	local name = shadowed(centered(parent, 9, HudChrome.Parchment))
	timer.TextStrokeTransparency = 0.4
	return {
		Button = button,
		Stroke = stroke,
		Glyph = glyph,
		Badge = badge,
		Shade = shade,
		Wipe = wipe,
		Flash = flash,
		FlashStroke = flashStroke,
		Timer = timer,
		Name = name,
	}
end
local function layoutTray(frame, icons, size)
	local gap = math.floor(size * 0.2)
	frame.Size = UDim2.fromOffset(size * 3 + gap * 2, size + 15)
	for i, icon in icons do
		local x = (i - 1) * (size + gap)
		icon.Button.Position, icon.Button.Size = UDim2.fromOffset(x, 0), UDim2.fromOffset(size, size)
		icon.Name.Position, icon.Name.Size = UDim2.fromOffset(x - gap // 2, size + 3), UDim2.fromOffset(size + gap, 12)
		icon.Glyph.TextSize = math.floor(size * 0.38)
	end
end
-- usable: learned and affordable; lacking: only the resource is short.
local function setIcon(icon, color, cd, usable, active, lacking)
	local remaining = if cd then math.max(0, cd.Ready - os.clock()) else 0
	local share = if cd and remaining > 0 then math.clamp(remaining / math.max(0.05, cd.Total), 0.002, 0.998) else 0
	icon.Shade.Visible = share > 0
	if share > 0 then
		icon.Wipe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(share, 0.3),
			NumberSequenceKeypoint.new(math.min(0.999, share + 0.001), 0.85),
			NumberSequenceKeypoint.new(1, 0.85),
		})
	end
	icon.Timer.Text = if remaining >= 1
		then tostring(math.ceil(remaining))
		elseif remaining > 0 then string.format("%.1f", remaining)
		else ""
	if icon.Cooling and remaining <= 0 then
		-- Just came off cooldown: bloom a ring.
		icon.Flash.Size, icon.FlashStroke.Transparency = UDim2.fromScale(1, 1), 0
		TweenService
			:Create(icon.Flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1.35, 1.35) })
			:Play()
		TweenService:Create(icon.FlashStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
	end
	icon.Cooling = remaining > 0
	icon.Stroke.Color = if active then P.Gold elseif lacking then Color3.fromRGB(90, 120, 220) else color
	icon.Stroke.Thickness = if active then 3 else 2
	icon.Stroke.Transparency = if (usable or active) and remaining <= 0 then 0 else 0.55
	icon.Glyph.TextTransparency = if usable then 0 else 0.5
	SurgeIcons.dim(icon.Button, not usable)
	icon.Badge.TextColor3 = if lacking then Color3.fromRGB(255, 120, 120) else P.Gold
end
local reticle = text(gui, "·", 24, P.Text, IronUi.Bold)
reticle.AnchorPoint, reticle.Position, reticle.Size =
	Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(40, 40)
reticle.TextXAlignment = Enum.TextXAlignment.Center
local hitMarker = text(gui, "×", 38, P.Text, IronUi.Bold)
hitMarker.AnchorPoint, hitMarker.Position, hitMarker.Size =
	Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(48, 48)
hitMarker.TextXAlignment = Enum.TextXAlignment.Center
hitMarker.Visible = false
local incomingMarker = text(gui, "▲", 24, Color3.fromRGB(255, 100, 110), IronUi.Bold)
incomingMarker.AnchorPoint, incomingMarker.Size = Vector2.new(0.5, 0.5), UDim2.fromOffset(36, 36)
incomingMarker.TextXAlignment = Enum.TextXAlignment.Center
incomingMarker.Visible = false
-- Cast bar: heavy-attack charge, surge/maneuver wind-ups and channels.
-- Your buffs and debuffs, just above the unit frame: "🔥 Burning (Thermal) 3s".
local selfStatusRow = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -150),
	Size = UDim2.fromOffset(760, 26),
}, gui)
local selfStatuses = StatusBars.strip(selfStatusRow, false)
local selfStatusIcons = StatusBars.strip(selfStatusRow, true) -- narrow screens: icons only
-- Compact warning tucked below the top target frame, clear of the crosshair.
local foeWarning = FoeCastBar.widget(gui, 220, false)
local foeCast = foeWarning.Panel
foeCast.AnchorPoint = Vector2.new(0.5, 0)
foeCast.Position = UDim2.new(0.5, 0, 0, 84)
foeCast.Visible = false
local lastFoeCast, foeWarned = nil, false
local function drawFoeCast(model, serverNow)
	-- The rival; in PvP, the nearest other player who is casting.
	local cast = FoeCastBar.read(model, serverNow)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not cast and myRoot then
		local nearest = 60
		for _, other in Players:GetPlayers() do
			local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local theirs = root and FoeCastBar.read(other.Character, serverNow)
			if theirs and (root.Position - myRoot.Position).Magnitude < nearest then
				cast, model, nearest = theirs, other.Character, (root.Position - myRoot.Position).Magnitude
			end
		end
	end
	foeCast.Visible = cast ~= nil
	if not cast then
		return
	end
	-- A new cast: hear it wind up.
	local start = model:GetAttribute("ActionStart")
	if start ~= lastFoeCast then
		lastFoeCast, foeWarned = start, false
		local root = model:FindFirstChild("HumanoidRootPart")
		CombatSound.play("Cast", if root then root.Position else nil, { Volume = 0.9 })
	end
	local urgent = FoeCastBar.draw(foeWarning, cast, false)
	if urgent and not foeWarned then
		foeWarned = true
		CombatSound.play("Warn")
	end
	return model
end

-- The combat log (bottom left), with fight details on L.
local combatLog = CombatLogUI.new(gui)
local logRival = nil
-- New effects on you or the rival become log lines too.
local function logStatuses(fresh, text, dir, who)
	if #fresh == 0 then
		return
	end
	local values = {}
	for _, status in StatusEffects.decode(text) do
		values[status.Id] = status.Value
	end
	for _, id in fresh do
		combatLog:add({ Kind = "Status", Dir = dir, Who = who, Status = id, Value = values[id] })
	end
end
local castBar = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(12, 17, 28),
	BackgroundTransparency = 0.15,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, 58),
	Size = UDim2.fromOffset(260, 24),
	Visible = false,
}, gui)
HudChrome.dress(castBar, { Studs = false, Transparency = 0.12 })
local castTrack = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(1, -8, 1, -8),
}, castBar)
local chargeFill = new(
	"Frame",
	{ BackgroundColor3 = P.Gold, BackgroundTransparency = 0.15, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) },
	castTrack
)
UiKit.round(chargeFill, 4)
local perfectWindow = new("Frame", {
	BackgroundColor3 = P.Gold,
	BackgroundTransparency = 0.7,
	BorderSizePixel = 0,
	Position = UDim2.fromScale((Actions.PerfectAt - Actions.PerfectWindow) / Actions.OverchargeAt, 0),
	Size = UDim2.fromScale(2 * Actions.PerfectWindow / Actions.OverchargeAt, 1),
	ZIndex = 2,
}, castTrack)
new("UIStroke", { Color = P.Gold, Thickness = 1, Transparency = 0.15 }, perfectWindow)
local castLabel = shadowed(text(castBar, "", 11, P.Text, IronUi.Bold))
castLabel.AutomaticSize, castLabel.TextWrapped = Enum.AutomaticSize.None, false
castLabel.TextXAlignment, castLabel.Size, castLabel.ZIndex = Enum.TextXAlignment.Center, UDim2.fromScale(1, 1), 3
-- Combo counter, beside the crosshair.
local comboLabel = shadowed(text(gui, "", 26, P.Gold, IronUi.Bold))
comboLabel.AutomaticSize, comboLabel.TextWrapped = Enum.AutomaticSize.None, false
comboLabel.AnchorPoint, comboLabel.Position, comboLabel.Size =
	Vector2.new(0, 0.5), UDim2.new(0.5, 44, 0.5, -6), UDim2.fromOffset(140, 30)
local comboScale = new("UIScale", {}, comboLabel)
local comboWord = shadowed(text(comboLabel, "COMBO", 10, P.Text, IronUi.Bold))
comboWord.AutomaticSize, comboWord.Position, comboWord.Size =
	Enum.AutomaticSize.None, UDim2.fromOffset(2, 26), UDim2.fromOffset(80, 12)
-- Your target, top centre: its name over a long thin bar that drains from
-- both ends, the numbers under it.
local targetCard = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.fromOffset(380, 52),
	Visible = false,
}, gui)
local targetName = shadowed(text(targetCard, "", 15, HudChrome.Parchment, HudChrome.Title))
targetName.AutomaticSize, targetName.TextWrapped, targetName.TextTruncate =
	Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
targetName.TextXAlignment = Enum.TextXAlignment.Center
targetName.Position, targetName.Size = UDim2.fromOffset(60, 0), UDim2.new(1, -120, 0, 20)
local targetTag = shadowed(text(targetCard, "", 10, P.Gold, IronUi.Bold))
targetTag.AutomaticSize, targetTag.TextWrapped = Enum.AutomaticSize.None, false
targetTag.TextXAlignment = Enum.TextXAlignment.Right
targetTag.Position, targetTag.Size = UDim2.new(1, -86, 0, 4), UDim2.fromOffset(80, 14)
-- Under the target bar when several targets are close: X (or tap) switches.
local switchHint = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 4),
	Size = UDim2.fromOffset(230, 18),
	BackgroundColor3 = Color3.fromRGB(16, 22, 32),
	BackgroundTransparency = 0.25,
	TextColor3 = Color3.fromRGB(101, 210, 228),
	TextSize = 11,
	Font = IronUi.Bold,
	AutoButtonColor = false,
	Visible = false,
}, targetCard)
UiKit.round(switchHint, 9)
switchHint.Activated:Connect(function()
	TargetLock.switch()
end)
local targetTrack = new("Frame", {
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(8, 24),
	Size = UDim2.new(1, -16, 0, 10),
}, targetCard)
UiKit.round(targetTrack, 2)
local targetCaps = HudChrome.capBar(targetTrack)
local targetTrail = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(255, 196, 110),
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(1, 1),
}, targetTrack)
UiKit.round(targetTrail, 2)
local targetFill = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(1, 1),
	ZIndex = 2,
}, targetTrack)
UiKit.round(targetFill, 2)
fillGradient(targetFill, Color3.fromRGB(200, 55, 66))
local targetText = shadowed(text(targetCard, "", 10, Color3.fromRGB(215, 205, 185), IronUi.Bold))
targetText.AutomaticSize, targetText.TextWrapped = Enum.AutomaticSize.None, false
targetText.TextXAlignment = Enum.TextXAlignment.Center
targetText.Position, targetText.Size = UDim2.fromOffset(0, 37), UDim2.new(1, 0, 0, 13)
-- Its Charge (left) and Stamina (right) under that, when it has them (the
-- rival, another player): a dry Charge means no surge is coming; a low
-- Stamina means its guard is about to break.
local targetPools = {}
for i, id in { "Charge", "Stamina" } do
	local left = i == 1
	local anchor = Vector2.new(if left then 0 else 1, 0)
	local track = new("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = anchor,
		Position = UDim2.new(if left then 0 else 1, if left then 8 else -8, 0, 54),
		Size = UDim2.new(0.5, -18, 0, 6),
	}, targetCard)
	UiKit.round(track, 2)
	HudChrome.capBar(track)
	local fill = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(if left then 1 else 0, 0),
		Position = UDim2.fromScale(if left then 1 else 0, 0),
		Size = UDim2.fromScale(1, 1),
	}, track)
	UiKit.round(fill, 2)
	fillGradient(fill, Tech.Resources[id].Color)
	local label = shadowed(text(targetCard, "", 9, Tech.Resources[id].Color, IronUi.Bold))
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	label.TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
	label.AnchorPoint, label.Position, label.Size =
		anchor, UDim2.new(if left then 0 else 1, if left then 6 else -6, 0, 62), UDim2.new(0.5, -14, 0, 12)
	targetPools[id] = { Track = track, Fill = fill, Label = label }
end
local controlsHint = text(
	gui,
	"LMB Swing | Shift+LMB Off-hand | RMB Guard | Space Hop · Space×2 Roll | Q/E/R Surges | 1/2/3 Maneuvers | X Switch Target | K Tree | L Log",
	10,
	Color3.fromRGB(205, 198, 182)
)
controlsHint.AnchorPoint, controlsHint.Position, controlsHint.Size =
	Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -3), UDim2.new(1, -20, 0, 16)
controlsHint.TextXAlignment = Enum.TextXAlignment.Center
shadowed(controlsHint)
local cursorModal =
	new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Modal = false }, gui)
local slots = {}
-- Rival panel (top-right): the Arena rival's loadout, its surge cooldown and
-- what it's about to do. Fed by attributes the server sets on the rival.
local rivalPanel = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(12, 17, 28),
	BackgroundTransparency = 0.12,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 62),
	Size = UDim2.fromOffset(250, 344),
	Visible = false,
}, gui)
local rivalStroke = HudChrome.dress(rivalPanel, { Top = Color3.fromRGB(44, 34, 36) })
new("UIScale", { Name = "Fit" }, rivalPanel) -- shrinks on short screens
HudChrome.rule(rivalPanel, 42)
HudChrome.rule(rivalPanel, 130)
local function rivalLabel(size, color, x, y, w, h)
	local label = shadowed(text(rivalPanel, "", size, color, IronUi.Bold))
	label.AutomaticSize, label.TextWrapped, label.TextTruncate = Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	return label
end
local rivalName = rivalLabel(14, P.Text, 12, 7, 160, 19)
rivalName.Font = HudChrome.Title
local rivalTag = rivalLabel(10, Color3.fromRGB(255, 120, 120), 172, 10, 66, 14)
rivalTag.TextXAlignment = Enum.TextXAlignment.Right
local rivalInfo = rivalLabel(10, P.Dim, 12, 27, 226, 14)
-- Each piece: its name in its rarity's colour, and on the right the gem
-- enchanting it in the element's colour: its element, then one ◆ per tier
-- (◆ Common up to ◆◆◆◆◆ Legendary).
local rivalGear, rivalGems = {}, {}
for i = 1, 6 do
	rivalGear[i] = rivalLabel(10, P.Text, 12, 44 + (i - 1) * 14, 142, 14)
	local gem = rivalLabel(10, P.Dim, 154, 44 + (i - 1) * 14, 84, 14)
	gem.TextXAlignment = Enum.TextXAlignment.Right
	rivalGems[i] = gem
end
-- Its three surges (Q, E, R): a socket with a draining cooldown, the name and
-- its state.
local rivalSurges = {}
for slot, key in { "Q", "E", "R" } do
	local y = 134 + (slot - 1) * 42
	local socket = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 34, 50),
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.fromOffset(36, 36),
	}, rivalPanel)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, socket)
	local stroke = new("UIStroke", { Color = P.Gold, Thickness = 2 }, socket)
	local icon = rivalLabel(16, P.Text, 0, 0, 36, 36)
	icon.Parent, icon.TextXAlignment, icon.TextYAlignment =
		socket, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
	local shade = new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, socket)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shade)
	local keyLabel = rivalLabel(9, P.Inset, 0, 0, 14, 14)
	keyLabel.Parent, keyLabel.Text, keyLabel.BackgroundTransparency, keyLabel.BackgroundColor3 = socket, key, 0, P.Gold
	keyLabel.TextXAlignment, keyLabel.ZIndex = Enum.TextXAlignment.Center, 3
	UiKit.round(keyLabel, 7)
	rivalSurges[slot] = {
		Socket = socket,
		Stroke = stroke,
		Icon = icon,
		Shade = shade,
		Wipe = new("UIGradient", { Rotation = 90 }, shade),
		Name = rivalLabel(11, P.Text, 56, y + 1, 182, 14),
		Tier = rivalLabel(9, P.Dim, 56, y + 14, 90, 12),
		State = rivalLabel(11, P.Good, 140, y + 13, 98, 16),
	}
	rivalSurges[slot].State.TextXAlignment = Enum.TextXAlignment.Right
end
-- Its controls, mirrored: the keys it presses light up, like yours would.
local RIVAL_KEYS = {
	{ "LMB", 28 },
	{ "RMB", 28 },
	{ "SPACE", 34 },
	{ "Q", 20 },
	{ "E", 20 },
	{ "R", 20 },
	{ "1", 20 },
	{ "2", 20 },
	{ "3", 20 },
}
local rivalCaps = {}
do
	local x = 12
	for _, entry in RIVAL_KEYS do
		local cap = new("Frame", {
			BackgroundColor3 = Color3.fromRGB(30, 34, 50),
			Position = UDim2.fromOffset(x, 262),
			Size = UDim2.fromOffset(entry[2], 20),
		}, rivalPanel)
		UiKit.round(cap, 4)
		local capStroke = new("UIStroke", { Color = Color3.fromRGB(70, 96, 128), Thickness = 1 }, cap)
		local label = rivalLabel(9, P.Text, 0, 0, entry[2], 20)
		label.Parent, label.TextXAlignment, label.TextYAlignment =
			cap, Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
		rivalCaps[entry[1]] = { Cap = cap, Stroke = capStroke, Label = label }
		x += entry[2] + 2
	end
end
local rivalMoves = rivalLabel(9, P.Dim, 12, 286, 226, 12)
-- What it's doing right now, as a warning strip.
local rivalStance = rivalLabel(12, P.Text, 0, 0, 250, 26)
rivalStance.Position, rivalStance.Size = UDim2.fromOffset(0, 300), UDim2.new(1, 0, 0, 24)
rivalStance.TextXAlignment = Enum.TextXAlignment.Center
rivalStance.TextYAlignment = Enum.TextYAlignment.Center
-- The rival's buffs and debuffs, under its panel.
local rivalStatusRow = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 0, 1, 6),
	Size = UDim2.new(1, 0, 0, 34),
}, rivalPanel)
local rivalStatuses = StatusBars.strip(rivalStatusRow, true, Enum.HorizontalAlignment.Right)

-- The matchup (beside the rival panel): you vs it, strengths and weaknesses.
local matchup = MatchupUI.new(gui)
local rivalHealth = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(28, 32, 46),
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(12, 328),
	Size = UDim2.new(1, -24, 0, 8),
}, rivalPanel)
UiKit.round(rivalHealth, 2)
HudChrome.capBar(rivalHealth)
local rivalHealthFill = new(
	"Frame",
	{ BackgroundColor3 = Color3.fromRGB(220, 70, 82), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
	rivalHealth
)
UiKit.round(rivalHealthFill, 3)
local STANCES = {
	Heavy = { "⚠  HEAVY BLOW INCOMING  ·  DODGE", Color3.fromRGB(255, 120, 70) },
	Counter = { "COUNTER-ATTACK!", Color3.fromRGB(255, 90, 100) },
	Lunge = { "LUNGING IN", Color3.fromRGB(255, 170, 80) },
	Guard = { "GUARD UP  ·  USE A HEAVY", Color3.fromRGB(120, 220, 255) },
	Dodge = { "DODGING", Color3.fromRGB(200, 210, 230) },
	Surge = { "CASTING ITS SURGE", P.Gold },
	Maneuver = { "RIG MANEUVER!", Tech.Resources.Stamina.Color },
	Riposte = { "RIPOSTE STANCE  ·  DON'T SWING", P.Gold },
}
local SLOT_SHORT =
	{ Helmet = "HEAD", Armor = "CHEST", Gloves = "HANDS", Boots = "FEET", Weapon = "WEAPON", Shield = "SHIELD" }
local rivalModel, nextRivalScan = nil, 0
local function findRival()
	if player:GetAttribute("DungeonId") then
		local target = TargetLock.target()
		return if target and target:GetAttribute("DungeonId") == player:GetAttribute("DungeonId") then target else nil
	end
	local folder = workspace:FindFirstChild("Enemies")
	for _, model in folder and folder:GetChildren() or {} do
		-- Your own rival, or your raid's boss.
		if require(ReplicatedStorage.Shared.Matchmaking).ownsRival(model, player) then
			return model
		end
	end
	return nil
end
local function drawRival(now, viewport)
	if now >= nextRivalScan or (rivalModel and not rivalModel.Parent) then
		nextRivalScan = now + 0.5
		rivalModel = findRival()
	end
	local model = rivalModel
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	-- (Touch screens keep the fight clear: the top card says enough.)
	rivalPanel.Visible = humanoid ~= nil
		and (model:GetAttribute("ArenaDropUntil") or 0)<=workspace:GetServerTimeNow()
		and humanoid.Health > 0
		and viewport.X >= 700
		and not UserInputService.TouchEnabled
	if not rivalPanel.Visible then
		return
	end
	local element = model:GetAttribute("RivalElement")
	local color = GemConfig.ElementColors[element] or P.Gold
	rivalName.Text, rivalName.TextColor3 = model:GetAttribute("RivalName") or model.Name, color
	rivalTag.Text = if model:GetAttribute("RaidBandit")
		then (if model:GetAttribute("AmbientState") == "Combat" then "HOSTILE BANDIT" else "NEUTRAL BANDIT")
		elseif model:GetAttribute("RivalSparring") then "SPARRING"
		else "RIVAL"
	rivalStroke.Color = color:Lerp(HudChrome.GoldDim, 0.45)
	rivalInfo.Text = string.format(
		"%s  ·  GEAR SCORE %d",
		string.upper(GemConfig.elementName(element or "")),
		model:GetAttribute("RivalScore") or 0
	)
	local entries = string.split(model:GetAttribute("RivalGear") or "", ";")
	for i, row in rivalGear do
		local parts = string.split(entries[i] or "", "|")
		local rarity = GearRolls.Rarities[tonumber(parts[3]) or 1] or GearRolls.Rarities[1]
		row.Text = if parts[2] then (SLOT_SHORT[parts[1]] or parts[1]) .. "  " .. parts[2] else ""
		row.TextColor3 = rarity.Color
		local gemElement, gemTier = parts[4], parts[5]
		local gemLabel = rivalGems[i]
		if gemElement and gemElement ~= "" then
			gemLabel.Text = GemConfig.elementName(gemElement)
				.. " "
				.. string.rep("◆", table.find(GemConfig.TierOrder, gemTier) or 1)
			gemLabel.TextColor3 = GemConfig.ElementColors[gemElement] or P.Dim
		else
			gemLabel.Text = ""
		end
	end
	-- Surge cooldowns, from server time so they match the real thing.
	local serverNow = workspace:GetServerTimeNow()
	for slot, row in rivalSurges do
		local surgeName = model:GetAttribute("RivalSurge" .. slot)
		local surgeColor = GemConfig.ElementColors[model:GetAttribute("RivalSurgeElement" .. slot)] or P.Gold
		row.Socket.Visible = surgeName ~= nil
		row.Name.Text = surgeName or ""
		row.Name.TextColor3 = surgeColor
		row.Icon.Text, row.Icon.TextColor3 = model:GetAttribute("RivalSurgeIcon" .. slot) or "◆", surgeColor
		SurgeIcons.apply(row.Icon, surgeName, surgeColor)
		row.Tier.Text = if surgeName
			then string.format(
				"RANK %s · %s",
				ROMAN[model:GetAttribute("RivalSurgeRank" .. slot) or 1] or "I",
				string.upper(Tech.TierNames[model:GetAttribute("RivalSurgeTier" .. slot) or 1] or "")
			)
			else ""
		local remaining = math.max(0, (model:GetAttribute("SurgeReadyAt" .. slot) or 0) - serverNow)
		local total = math.max(1, model:GetAttribute("SurgeCooldown" .. slot) or 10)
		local share = math.clamp(remaining / total, 0, 0.998)
		row.Shade.Visible = share > 0
		if share > 0 then
			row.Wipe.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(math.max(0.001, share), 0.3),
				NumberSequenceKeypoint.new(math.min(0.999, share + 0.001), 1),
				NumberSequenceKeypoint.new(1, 1),
			})
		end
		row.Stroke.Color = surgeColor
		if serverNow - (model:GetAttribute("SurgeCastAt" .. slot) or -100) < 1.2 then
			row.State.Text, row.State.TextColor3 = "CASTING!", P.Gold
			row.Stroke.Thickness = 3
		elseif remaining > 0 then
			row.State.Text, row.State.TextColor3 = string.format("%.1fs", remaining), P.Dim
			row.Stroke.Thickness = 2
		else
			row.State.Text, row.State.TextColor3 = "READY", Color3.fromRGB(255, 120, 120)
			row.Stroke.Thickness = 2
		end
	end
	-- Mirrored controls: the key it just pressed lights up gold; surge and
	-- maneuver keys count down while they recharge.
	local lastKey = model:GetAttribute("LastKey")
	local pressedRecently = serverNow - (model:GetAttribute("LastKeyAt") or -100) < 0.45
	for key, cap in rivalCaps do
		local cooldown = 0
		local slot = table.find({ "Q", "E", "R" }, key)
		if slot then
			cooldown = (model:GetAttribute("SurgeReadyAt" .. slot) or 0) - serverNow
		elseif tonumber(key) then
			cooldown = (model:GetAttribute("MoveReadyAt" .. key) or 0) - serverNow
		end
		local pressed = pressedRecently and lastKey == key
		cap.Cap.BackgroundColor3 = if pressed then P.Gold else Color3.fromRGB(30, 34, 50)
		cap.Stroke.Color = if pressed then P.Gold else Color3.fromRGB(70, 96, 128)
		cap.Label.Text = if not pressed and cooldown > 0 then tostring(math.ceil(cooldown)) else key
		cap.Label.TextColor3 = if pressed then P.Inset elseif cooldown > 0 then P.Dim else P.Text
	end
	local moveNames = {}
	for slot = 1, 3 do
		local moveName = model:GetAttribute("RivalMove" .. slot)
		if moveName then
			table.insert(moveNames, slot .. " " .. moveName)
		end
	end
	rivalMoves.Text = table.concat(moveNames, "  ·  ")
	local stance = STANCES[model:GetAttribute("Stance") or ""]
	local ambient = model:GetAttribute("AmbientState")
	rivalStance.Text = if ambient and ambient ~= "Combat" then string.upper(ambient) elseif stance then stance[1] else ""
	rivalStance.TextColor3 = if stance then stance[2] else P.Text
	rivalHealthFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
end
local function rootPart()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function canFight()
	local root = rootPart()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid
		and humanoid.Health > 0
		and root
		and not player.PlayerGui:FindFirstChild("Intro")
		and Combat.canFight(root.Position)
		and (not Config.MenuOnly or ArenaScene.isActive())
end
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
local function aimedHit()
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	aimParams.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("CombatFx"), camera }
	return workspace:Raycast(ray.Origin, ray.Direction * 500, aimParams), ray
end
local function aimPoint()
	local lockedPoint = TargetLock.point()
	if lockedPoint then
		return lockedPoint
	end
	local hit, ray = aimedHit()
	return if hit then hit.Position else ray.Origin + ray.Direction * 120
end
local function face(aim)
	local root = rootPart()
	if root then
		local flat = Vector3.new(aim.X, root.Position.Y, aim.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
end
local function rules()
	local loadout = GemClient.Profile and GemClient.Profile.Character
	if not loadout then
		return Actions.resolve({}, "Sword", 0)
	end
	local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
	local effects = Classes.effects(loadout)
	return Actions.forWeapon(Classes.setState(loadout).Counts, weapon, effects)
end
local function beginAttack(side)
	if beamKey then
		return
	end
	if cursorFree or not canFight() or blockHeld or holding or os.clock() < nextAttack then
		return
	end
	holding, chargeStarted = true, os.clock()
	attackSide = side or nextSide
	input:FireServer("BeginAttack", attackSide)
end
local function releaseAttack()
	if not holding then
		return
	end
	holding = false
	if not canFight() then
		input:FireServer("CancelAttack")
		return
	end
	local aim = aimPoint()
	face(aim)
	local heavy = Actions.charge(os.clock() - chargeStarted).Heavy
	nextSide = if attackSide == "Right" then "Left" else "Right"
	nextAttack = os.clock() + (if heavy then rules().HeavyCooldown else rules().BasicCooldown)
	input:FireServer("ReleaseAttack", aim)
end
local function setBlock(held)
	if held and (cursorFree or not canFight()) then
		return
	end
	blockHeld = held
	if held then
		beamKey = nil
		input:FireServer("CancelTech")
		holding = false
		input:FireServer("CancelAttack")
	end
	local aim = aimPoint()
	if held then
		face(aim)
	end
	input:FireServer("Block", held, aim)
	nextBlockUpdate = os.clock() + 0.15
end
-- Space once: a quick hop. Space twice: a roll (the hop chains into it).
local lastDodgeTap = nil
local function dodge()
	if cursorFree or not canFight() then
		return
	end
	local now = os.clock()
	local kind = Actions.dodgeKind(lastDodgeTap, now)
	lastDodgeTap = if kind == "Roll" then nil else now
	local cd = cooldowns.Dodge
	if kind == "Roll" and cd and now < cd.Ready then
		return -- the roll is still cooling down
	end
	holding = false
	blockHeld = false
	beamKey = nil
	input:FireServer("CancelTech")
	input:FireServer("CancelAttack")
	input:FireServer("Block", false)
	local root = rootPart()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	input:FireServer(
		"Dodge",
		if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then humanoid.MoveDirection else root.CFrame.LookVector,
		kind
	)
end
local function pressInput(obj)
	return obj.UserInputType == Enum.UserInputType.MouseButton1 or obj.UserInputType == Enum.UserInputType.Touch
end
local function loadoutOf()
	return GemClient.Profile and GemClient.Profile.Character
end
-- The Rig Maneuver on key 1, 2 or 3 (set in the Loadout).
local function maneuverOn(slot)
	local loadout = loadoutOf()
	return (loadout and loadout.Maneuvers or Tech.DefaultManeuvers)[slot]
end
local function techReady(key)
	local cd = techCooldowns[key]
	return not cd or os.clock() >= cd.Ready
end
-- Gem Surges: the gem in Surge Array slot Q, E or R decides what fires.
local function triggerSurge(key)
	if cursorFree or not canFight() or holding or blockHeld or not techReady("Surge" .. key) then
		return
	end
	local loadout = loadoutOf()
	local gem = Tech.surgeGem(loadout, key)
	if not gem then
		hint.Text, feedbackUntil = "Socket a gem in surge slot " .. key .. " (Loadout)", os.clock() + 1.2
		return
	end
	local definition = Tech.surgeStats(gem, Tree.effects(GemClient.Profile))
	if definition and definition.PerSecond then
		beamKey, nextBeamUpdate = key, os.clock() + 0.2
	end
	input:FireServer("Surge", key, aimPoint())
end
local function triggerManeuver(slot)
	if cursorFree or not canFight() or holding or blockHeld then
		return
	end
	local id = maneuverOn(slot)
	if id and techReady(id) then
		input:FireServer("RigManeuver", id, aimPoint())
	end
end
local function stopBeam(key)
	if beamKey and (key == nil or key == beamKey) then
		beamKey = nil
		input:FireServer("CancelTech")
	end
end
local surgeIcons, maneuverIcons = {}, {}
for i, key in SURGE_KEYS do
	local icon = makeIcon(surgeTray, key, true)
	surgeIcons[i] = icon
	icon.Button.InputBegan:Connect(function(obj)
		if pressInput(obj) then
			if obj.UserInputType == Enum.UserInputType.Touch then
				surgeTouch = obj
			end
			triggerSurge(key)
		end
	end)
	icon.Button.InputEnded:Connect(function(obj)
		if pressInput(obj) then
			stopBeam(key)
		end
	end)
end
for slot = 1, Tech.ManeuverSlots do
	local icon = makeIcon(maneuverTray, tostring(slot), false)
	maneuverIcons[slot] = icon
	icon.Button.Activated:Connect(function()
		triggerManeuver(slot)
	end)
end
local function makeSlot(id, label, key, position)
	local button, faceBox = IronUi.chunk(
		gui,
		{ Color = Color3.fromRGB(52, 46, 70), Size = UDim2.fromOffset(80, 70), Radius = 35, Lip = 4, Stripes = "None" }
	)
	button.AnchorPoint, button.Position = Vector2.new(0.5, 1), position
	local name = text(faceBox, label, 12, P.Text, IronUi.Bold)
	name.Position = UDim2.fromOffset(4, 40)
	name.Size = UDim2.new(1, -8, 0, 26)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local keyLabel = text(faceBox, key, 10, P.Gold)
	keyLabel.Position, keyLabel.Size = UDim2.fromOffset(6, 4), UDim2.new(1, -12, 0, 15)
	keyLabel.AutomaticSize, keyLabel.TextWrapped = Enum.AutomaticSize.None, false
	local timer = text(faceBox, "", 18, P.Gold, IronUi.Bold)
	timer.Position = UDim2.fromOffset(4, 17)
	timer.Size = UDim2.new(1, -8, 0, 25)
	timer.TextXAlignment = Enum.TextXAlignment.Center
	slots[id] = { Button = button, Name = name, Timer = timer, Key = keyLabel }
	return button
end
local attackButton = makeSlot("Basic", "LEFT", "HOLD", UDim2.new(0, 56, 1, -32))
local heavyButton = makeSlot("Heavy", "RIGHT", "HOLD", UDim2.new(1, -56, 1, -32))
local dodgeButton = makeSlot("Dodge", "DODGE", "TAP·2×", UDim2.new(1, -56, 1, -210))
local blockButton = makeSlot("Block", "GUARD", "HOLD", UDim2.new(0.5, 0, 1, -32))
attackButton.InputBegan:Connect(function(obj)
	if pressInput(obj) and not holding then
		attackTouch = if obj.UserInputType == Enum.UserInputType.Touch then obj else nil
		beginAttack("Left")
	end
end)
attackButton.InputEnded:Connect(function(obj)
	if pressInput(obj) then
		releaseAttack()
	end
end)
heavyButton.InputBegan:Connect(function(obj)
	if pressInput(obj) and not holding then
		attackTouch = if obj.UserInputType == Enum.UserInputType.Touch then obj else nil
		beginAttack("Right")
	end
end)
heavyButton.InputEnded:Connect(function(obj)
	if pressInput(obj) then
		releaseAttack()
	end
end)
dodgeButton.Activated:Connect(dodge)
blockButton.InputBegan:Connect(function(obj)
	if pressInput(obj) then
		blockTouch = if obj.UserInputType == Enum.UserInputType.Touch then obj else nil
		setBlock(true)
	end
end)
blockButton.InputEnded:Connect(function(obj)
	if pressInput(obj) then
		setBlock(false)
	end
end)
local leave = IronUi.gemButton(gui, "LEAVE ARENA", P.Gold, ArenaScene.leave)
leave.AnchorPoint = Vector2.new(1, 0)
leave.Position = UDim2.new(1, -12, 0, 82)
leave.Size = UDim2.fromOffset(160, 38)
local function cancel()
	cast = nil
	attackTouch, blockTouch, surgeTouch = nil, nil, nil
	beamKey = nil
	input:FireServer("CancelTech")
	holding = false
	blockHeld = false
	input:FireServer("CancelAttack")
	input:FireServer("Block", false)
end
UserInputService.WindowFocusReleased:Connect(cancel)

local function toggleGuide()
	cancel()
	AugmentTreeUI.close()
	CombatGuide.toggle()
	cursorFree = CombatGuide.isOpen()
	FirstPerson.setCursorFree(cursorFree)
end
local function toggleTree()
	cancel()
	CombatGuide.close()
	AugmentTreeUI.toggle()
	cursorFree = AugmentTreeUI.isOpen()
	FirstPerson.setCursorFree(cursorFree)
end
local treeButton = new("TextButton", {
	Text = "AUGMENT TREE · K",
	TextSize = 12,
	TextColor3 = P.Gold,
	BackgroundColor3 = P.Inset,
	Position = UDim2.fromOffset(58, 21),
	Size = UDim2.fromOffset(150, 30),
}, gui)
UiKit.round(treeButton, 8)
treeButton.Activated:Connect(toggleTree)
local guideButton = new("TextButton", {
	Text = "?",
	TextSize = 22,
	TextColor3 = P.Gold,
	BackgroundColor3 = P.Inset,
	Position = UDim2.fromOffset(12, 16),
	Size = UDim2.fromOffset(38, 40),
}, gui)
UiKit.round(guideButton, 10)
guideButton.Activated:Connect(toggleGuide)
ContextActionService:BindActionAtPriority("CombatAugmentTree", function(_, state)
	if not canFight() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		toggleTree()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.K)
ContextActionService:BindActionAtPriority("CombatLogDetails", function(_, state)
	if not canFight() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		combatLog.toggle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.L)
local SURGE_INPUT = { [Enum.KeyCode.Q] = "Q", [Enum.KeyCode.E] = "E", [Enum.KeyCode.R] = "R" }
local MANEUVER_INPUT = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
}
UserInputService.InputBegan:Connect(function(obj, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if SURGE_INPUT[obj.KeyCode] then
		triggerSurge(SURGE_INPUT[obj.KeyCode])
	elseif MANEUVER_INPUT[obj.KeyCode] then
		triggerManeuver(MANEUVER_INPUT[obj.KeyCode])
	elseif obj.UserInputType == Enum.UserInputType.MouseButton1 then
		local offHand = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		beginAttack(if offHand then "Left" else nil)
	elseif obj.UserInputType == Enum.UserInputType.MouseButton2 then
		setBlock(true)
	end
end)
UserInputService.InputEnded:Connect(function(obj)
	if obj == surgeTouch then
		surgeTouch = nil
		stopBeam()
	elseif SURGE_INPUT[obj.KeyCode] then
		stopBeam(SURGE_INPUT[obj.KeyCode])
	end
	if obj == attackTouch then
		attackTouch = nil
		releaseAttack()
	end
	if obj == blockTouch then
		blockTouch = nil
		setBlock(false)
	end
	if obj.UserInputType == Enum.UserInputType.MouseButton1 then
		releaseAttack()
	elseif obj.UserInputType == Enum.UserInputType.MouseButton2 then
		setBlock(false)
	end
end)
ContextActionService:BindActionAtPriority("CombatCursor", function(_, state)
	if not canFight() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		cancel()
		if CombatGuide.isOpen() or AugmentTreeUI.isOpen() then
			CombatGuide.close()
			AugmentTreeUI.close()
			cursorFree = false
		else
			cursorFree = not cursorFree
		end
		FirstPerson.setCursorFree(cursorFree)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Tab)
-- Switch between the targets close around you (within TargetLockRules.SwitchRange).
ContextActionService:BindActionAtPriority("SwitchTarget", function(_, state)
	if not canFight() or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		TargetLock.switch()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.X, Enum.KeyCode.DPadRight)
UserInputService.WindowFocusReleased:Connect(cancel)
ContextActionService:BindActionAtPriority("UniversalDodge", function(_, state)
	if not canFight() or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		dodge()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space)
player.CharacterAdded:Connect(function()
	cancel()
	FirstPerson.stop()
	TargetLock.reset()
	cursorFree = false
	cooldowns, techCooldowns = {}, {}
	nextAttack = 0
end)
player:GetAttributeChangedSignal("CombatSession"):Connect(function()
	TargetLock.setActive(false)
	cancel()
	FirstPerson.stop()
	cursorFree = false
	cooldowns, techCooldowns = {}, {}
	nextAttack = 0
end)
-- Touch screens: the fighting actions under the right thumb, the left side
-- left to the move stick. ATTACK sits in the bottom-right corner; the three
-- surges ring it closest (Q left, E diagonal, R above); GUARD, HEAVY and
-- DODGE make one even outer arc, all round. Your vitals sit bottom-centre,
-- left of the ring, with your maneuvers (round too) in a row just above
-- them. Returns the top of that stack (from the bottom) and its centre.
local thumbReady = false
local THUMB_NAMES = { Basic = "ATTACK", Heavy = "HEAVY", Block = "GUARD", Dodge = "DODGE" }
local function roundAll(button: GuiObject)
	for _, d in button:GetDescendants() do
		if d:IsA("UICorner") then
			d.CornerRadius = UDim.new(0.5, 0)
		end
	end
	local own = button:FindFirstChildOfClass("UICorner")
	if own then
		own.CornerRadius = UDim.new(0.5, 0)
	end
end
local function layoutThumb(viewport: Vector2): (number, number)
	if not thumbReady then
		thumbReady = true
		for _, icon in surgeIcons do
			icon.Button.Parent = gui
			icon.Name.Visible = false
		end
		for _, icon in maneuverIcons do
			icon.Button.Parent = gui
			icon.Name.Visible = false
		end
		for _, slot in slots do
			roundAll(slot.Button)
		end
	end
	-- Maneuver buttons are round on touch screens, ability art included
	-- (the art is added later, when an ability is set).
	for _, icon in maneuverIcons do
		roundAll(icon.Button)
	end
	local k = math.clamp(viewport.Y / 380, 0.8, 1.3)
	local A, S, M, G = math.floor(86 * k), math.floor(58 * k), math.floor(50 * k), math.floor(56 * k)
	local margin = math.floor(14 * k)
	-- The ring's centre, measured from the bottom-right corner.
	local cx, cy = margin + A / 2, margin + A / 2
	local function at(button: GuiObject, size: number, radius: number, degrees: number)
		local a = math.rad(degrees)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Size = UDim2.fromOffset(size, size)
		button.Position =
			UDim2.new(1, -cx + math.floor(radius * math.cos(a)), 1, -cy - math.floor(radius * math.sin(a)))
	end
	at(slots.Basic.Button, A, 0, 0)
	-- Surges, closest.
	local inner = A / 2 + S / 2 + 8 * k
	for i, icon in surgeIcons do
		icon.Button.Visible = true
		at(icon.Button, S, inner, ({ 180, 135, 90 })[i])
		icon.Glyph.TextSize = math.floor(S * 0.38)
		icon.Badge.TextSize = math.floor(9 * k)
	end
	-- The outer arc: guard low by the thumb, heavy, dodge on top.
	local outer = inner + S / 2 + G / 2 + 8 * k
	at(slots.Block.Button, G, outer, 184)
	at(slots.Heavy.Button, M, outer, 140)
	at(slots.Dodge.Button, M, outer, 97)
	-- The round buttons: name centred, cooldown above it, no key hint.
	for id, slot in slots do
		local size = if id == "Basic" then A elseif id == "Block" then G else M
		slot.Button.Visible = true
		slot.Key.Visible = false
		slot.Name.Text = if id == "Block" and player:GetAttribute("Blocking") then "GUARD UP" else THUMB_NAMES[id]
		slot.Name.TextSize = if id == "Basic" then math.floor(15 * k) else math.floor(10 * k)
		slot.Name.Position = UDim2.new(0, 2, 0.5, -math.floor(size * 0.12))
		slot.Name.Size = UDim2.new(1, -4, 0, math.floor(size * 0.3))
		slot.Timer.Position = UDim2.new(0, 2, 0, math.floor(size * 0.06))
		slot.Timer.Size = UDim2.new(1, -4, 0, math.floor(size * 0.3))
		slot.Timer.TextSize = math.floor(size * 0.24)
	end
	-- Vitals: between the move stick's side (the left fifth) and the ring.
	local left = viewport.X * 0.2
	local right = viewport.X - (cx + outer + G / 2 + 14 * k)
	local width = math.clamp(right - left, 240, 420)
	local centre = math.max(left + width / 2, math.min(right - width / 2, viewport.X / 2))
	local stacked = width < 400
	local height = HudChrome.layoutVitals(
		hud,
		{ Name = nameLabel, Shield = hp, Health = healthTrack, Bars = resourceBars },
		width,
		stacked
	)
	hud.Position = UDim2.new(0, centre, 1, -margin)
	local top = margin + height
	-- Maneuvers: a row of round buttons just above the vitals (those you can use).
	local shown = {}
	for _, icon in maneuverIcons do
		icon.Button.Visible = not icon.Locked
		if icon.Button.Visible then
			table.insert(shown, icon)
		end
	end
	local Mv, gap = math.floor(46 * k), math.floor(12 * k)
	for i, icon in shown do
		local x = centre + (i - (#shown + 1) / 2) * (Mv + gap)
		icon.Button.AnchorPoint = Vector2.new(0.5, 1)
		icon.Button.Size = UDim2.fromOffset(Mv, Mv)
		icon.Button.Position = UDim2.new(0, math.floor(x), 1, -(top + 10 * k))
		icon.Glyph.TextSize = math.floor(Mv * 0.38)
		icon.Badge.TextSize = math.floor(8 * k)
	end
	if #shown > 0 then
		top += 10 * k + Mv
	end
	return top, centre
end

local lastActive = false
RunService.RenderStepped:Connect(function(dt)
	-- The combat HUD never draws over the menu dashboard.
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	local fight = canFight() == true and not (dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled)
	gui.Enabled = fight
	-- The lock stays on through menus and a free cursor; only its camera pull pauses.
	TargetLock.setActive(fight)
	TargetLock.setPaused(CombatGuide.isOpen() or AugmentTreeUI.isOpen())
	leave.Visible = ArenaScene.isActive()
	if not fight then
		if lastActive then
			hitUntil, incomingUntil, incomingOrigin = 0, 0, nil
			cancel()
			FirstPerson.stop()
			CombatGuide.close()
			AugmentTreeUI.close()
			guideWasOpen = false
			cursorFree = false
		end
		lastActive = false
		return
	end
	FirstPerson.start()
	local guideOpen = CombatGuide.isOpen() or AugmentTreeUI.isOpen() or player:GetAttribute("DungeonLoot") ~= nil
	if guideOpen ~= guideWasOpen then
		cursorFree = guideOpen
		FirstPerson.setCursorFree(cursorFree)
	end
	guideWasOpen = guideOpen
	if not lastActive then
		fightSince = os.clock()
	end
	lastActive = true
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local portrait = viewport.X < 600
	local short = viewport.Y < 430 and not portrait
	local touch = UserInputService.TouchEnabled
	actionBar.Frame.Visible = not touch
	treeButton.Visible = not touch
	local stackTop, centreX = 0, nil
	local logRoom = 0
	-- Callouts sit under the crosshair; on touch screens above it, clear
	-- of the maneuver row on short phones.
	hint.Position = if touch then UDim2.new(0.5, 0, 0.5, -64) else UDim2.new(0.5, 0, 0.5, 30)
	if touch then
		stackTop, centreX = layoutThumb(viewport)
	else
		local iconSize = if portrait
			then math.clamp(math.floor((viewport.X - 100) / 7), 34, 48)
			elseif short then 44
			else 52
		layoutTray(surgeTray, surgeIcons, iconSize)
		layoutTray(maneuverTray, maneuverIcons, iconSize)
		-- One stack at the bottom: the action bar, the vitals above it, your
		-- buffs above those; on narrow screens Health gets its own row.
		local barWidth, barHeight = HudChrome.layoutActionBar(actionBar, surgeTray, maneuverTray)
		local stacked = portrait or (viewport.X < 760 and not short)
		local hudBottom = 22 + barHeight + 12
		local vitalsWidth = if stacked
			then math.max(barWidth, math.min(viewport.X - 40, 420))
			elseif short then barWidth + 40
			else math.max(barWidth + 120, 600)
		local hudHeight = HudChrome.layoutVitals(
			hud,
			{ Name = nameLabel, Shield = hp, Health = healthTrack, Bars = resourceBars },
			vitalsWidth,
			stacked
		)
		hud.Position = UDim2.new(0.5, 0, 1, -hudBottom)
		stackTop = hudBottom + hudHeight
		-- Mouse and keyboard: no on-screen buttons.
		for _, slot in slots do
			slot.Button.Visible = false
		end
		logRoom = (viewport.X - (if stacked then viewport.X else vitalsWidth)) / 2 - 24
	end
	rivalPanel.Fit.Scale = math.clamp((viewport.Y - 150) / 420, 0.58, 1)
	controlsHint.Position = UDim2.new(0.5, 0, 1, -3)
	-- Your buffs and debuffs ride just above the vitals, wherever they sit.
	selfStatusRow.Position = if centreX
		then UDim2.new(0, centreX, 1, -(stackTop + 6))
		else UDim2.new(0.5, 0, 1, -(stackTop + 8))
	-- The log keeps to the bottom-left corner, clear of the stack (touch
	-- screens leave that corner to the move stick).
	combatLog.LogPanel.Visible = not touch and combatLog.LogPanel.Visible
	combatLog.LogPanel.Position = UDim2.new(0, 12, 1, -12)
	combatLog.LogPanel.Size = UDim2.fromOffset(math.clamp(logRoom, 240, 340), combatLog.LogPanel.Size.Y.Offset)
	controlsHint.Size = UDim2.fromOffset(math.min(760, viewport.X - 32), 16)
	leave.Position, leave.Size =
		UDim2.new(1, -12, 0, if portrait then 80 else 16),
		if touch
			then UDim2.fromOffset(96, 30)
			elseif portrait then UDim2.fromOffset(130, 38)
			else UDim2.fromOffset(160, 38)
	leave.Text = if touch then "LEAVE" else "LEAVE ARENA"
	targetCard.Size = UDim2.fromOffset(if portrait then math.min(260, viewport.X - 40) else 380, 74)
	-- Phones: below the corner buttons.
	targetCard.Position = UDim2.new(0.5, 0, 0, if portrait then 124 else 14)
	targetName.TextSize = if portrait then 12 else 15
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local maxHealth = math.max(1, humanoid.MaxHealth)
		local ratio = math.clamp(humanoid.Health / maxHealth, 0, 1)
		healthFill.Size = UDim2.fromScale(ratio, 1)
		healthTrailRatio = if ratio >= healthTrailRatio
			then ratio
			else healthTrailRatio + (ratio - healthTrailRatio) * (1 - math.exp(-dt * 3))
		healthTrail.Size = UDim2.fromScale(healthTrailRatio, 1)
		local low = ratio <= 0.3
		local top = if low then Color3.fromRGB(255, 110, 110) else Color3.fromRGB(240, 90, 100)
		healthGradient.Color = ColorSequence.new(top, top:Lerp(Color3.new(0, 0, 0), 0.3))
		local shield = player:GetAttribute("Shield") or 0
		shieldFill.Size = UDim2.fromScale(math.min(ratio + shield / maxHealth, 1), 1)
		healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
		hp.Text = if shield > 0 then string.format("◈ %d", shield) else ""
		-- Red edges: pulse below 30% health, flash briefly when hit.
		local now = os.clock()
		vignette.Visible = low or now < flashUntil
		if vignette.Visible then
			local strength = if now < flashUntil then (flashUntil - now) / 0.3 else 0
			if low then
				strength = math.max(strength, 0.55 + 0.25 * math.sin(now * 5))
			end
			for _, edge in vignette:GetChildren() do
				edge.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
			end
		end
	end
	for id, bar in resourceBars do
		local amount, maximum = player:GetAttribute(id) or 0, player:GetAttribute("Max" .. id) or 100
		bar.Value.Text = string.format("%d / %d", math.floor(amount), maximum)
		local ratio = math.clamp(amount / math.max(1, maximum), 0, 1)
		-- Spending is immediate; regeneration eases toward authoritative values.
		bar.Display = if not bar.Display or ratio < bar.Display
			then ratio
			else bar.Display + (ratio - bar.Display) * (1 - math.exp(-dt * 12))
		bar.Fill.Size = UDim2.fromScale(bar.Display, 1)
		bar.Label.Text = id:upper() .. (if ratio <= 0.2 then "  ·  LOW" else "")
		bar.Value.TextColor3 = if ratio <= 0.2 then P.Gold else P.Text
	end
	local profile = GemClient.Profile
	local loadout = profile and profile.Character
	local amps = if profile then Tree.effects(profile) else {}
	for i, key in SURGE_KEYS do
		local icon = surgeIcons[i]
		local gem = Tech.surgeGem(loadout, key)
		local definition = gem and Tech.surgeStats(gem, amps)
		if definition then
			local color = GemConfig.ElementColors[gem.Element] or P.Gold
			local cost = definition.Cost * (if definition.PerSecond then 0.25 else 1)
			icon.Glyph.Text, icon.Glyph.TextColor3 = "◆", color
			if SurgeIcons.apply(icon.Button, definition) then
				icon.Glyph.Text = ""
			end
			icon.Badge.Text = string.format("T%d · %s", definition.Tier, ROMAN[definition.Rank] or "I")
			icon.Name.Text = definition.Name
			local usable = (player:GetAttribute("Charge") or 0) >= cost
			setIcon(icon, color, techCooldowns["Surge" .. key], usable, beamKey == key, not usable)
		else
			icon.Glyph.Text, icon.Glyph.TextColor3 = "+", P.Dim
			SurgeIcons.apply(icon.Button, nil)
			icon.Badge.Text, icon.Name.Text = "", "EMPTY"
			setIcon(icon, P.Dim, nil, false, false)
		end
	end
	local shielded = Classes.heldShield(loadout)
	for slot, icon in maneuverIcons do
		local id = maneuverOn(slot)
		local definition = id and Tree.techStats(profile, id)
		local color = Tech.Resources.Stamina.Color
		if definition then
			local learned = Tree.isLearned(profile, id)
			icon.Glyph.Text, icon.Glyph.TextColor3 = "✦", color
			if SurgeIcons.apply(icon.Button, id) then
				icon.Glyph.Text = ""
			end
			icon.Name.Text = definition.Name
			icon.Badge.Text = if learned then string.format("%d ST", math.floor(definition.Cost + 0.5)) else "LOCKED"
			icon.Locked = not learned
			local affordable = (player:GetAttribute("Stamina") or 0) >= definition.Cost
			local usable = learned and affordable and (not definition.Shield or shielded ~= nil)
			setIcon(icon, color, techCooldowns[id], usable, false, learned and not affordable)
		else
			icon.Glyph.Text, icon.Glyph.TextColor3 = "+", P.Dim
			SurgeIcons.apply(icon.Button, nil)
			icon.Badge.Text, icon.Name.Text = "", "EMPTY"
			icon.Locked = true
			setIcon(icon, P.Dim, nil, false, false)
		end
	end
	if beamKey and os.clock() >= nextBeamUpdate then
		input:FireServer("Surge", beamKey, aimPoint())
		nextBeamUpdate = os.clock() + 0.2
	end
	local now = os.clock()
	hitMarker.Visible = now < hitUntil
	hitMarker.TextColor3 = if hitCritical then P.Gold else P.Text
	hitMarker.TextTransparency = math.clamp(1 - (hitUntil - now) / 0.18, 0, 1)
	incomingMarker.Visible = now < incomingUntil and incomingOrigin ~= nil
	if incomingMarker.Visible then
		local localDirection = camera.CFrame:VectorToObjectSpace(incomingOrigin - camera.CFrame.Position)
		local angle = math.atan2(localDirection.X, -localDirection.Z)
		incomingMarker.Position = UDim2.new(0.5, math.sin(angle) * 94, 0.5, -math.cos(angle) * 94)
		incomingMarker.Rotation = math.deg(angle)
		incomingMarker.TextTransparency = math.clamp(1 - (incomingUntil - now) / 0.65, 0, 1)
	end
	local elapsed = if holding then now - chargeStarted else 0
	local charged = Actions.charge(elapsed)
	-- Cast bar: heavy charge first, then a wind-up, then a held channel.
	local castColor = Color3.fromRGB(83, 174, 204)
	if holding then
		castColor = if charged.Stage == "OVERCHARGED"
			then Color3.fromRGB(233, 70, 70)
			elseif charged.Perfect then P.Gold
			else Color3.fromRGB(83, 174, 204)
		chargeFill.Size = UDim2.fromScale(math.clamp(elapsed / Actions.OverchargeAt, 0, 1), 1)
		castLabel.Text = if charged.Perfect
			then "RELEASE!  PERFECT"
			elseif charged.Stage == "OVERCHARGED" then "OVERCHARGED"
			else attackSide:upper() .. " SWING  ·  RELEASE ON GOLD"
	elseif cast and now < cast.Start + cast.Duration then
		castColor = cast.Color
		chargeFill.Size = UDim2.fromScale(math.clamp((now - cast.Start) / cast.Duration, 0, 1), 1)
		castLabel.Text = string.format(
			"%s  ·  %.1fs%s",
			cast.Name:upper(),
			cast.Start + cast.Duration - now,
			if player:GetAttribute("CastRooted") then "  ·  ROOTED" else ""
		)
	elseif beamKey then
		local gem = Tech.surgeGem(loadout, beamKey)
		local definition = gem and Tech.surgeStats(gem)
		castColor = if gem then GemConfig.ElementColors[gem.Element] or P.Gold else P.Gold
		local charge = player:GetAttribute("Charge") or 0
		chargeFill.Size = UDim2.fromScale(math.clamp(charge / (player:GetAttribute("MaxCharge") or 100), 0, 1), 1)
		castLabel.Text = (if definition then definition.Name:upper() else "CHANNEL") .. "  ·  CHANNELING (SLOWED)"
	else
		cast = nil
	end
	perfectWindow.Visible = holding
	castBar.Visible = holding or cast ~= nil or beamKey ~= nil
	chargeFill.BackgroundColor3 = castColor
	drawRival(now, viewport)
	local serverNow = workspace:GetServerTimeNow()
	local mine = player:GetAttribute("Statuses")
	local narrow = viewport.X < 900
	logStatuses(selfStatuses:update(if narrow then nil else mine, serverNow), mine, "In")
	logStatuses(selfStatusIcons:update(if narrow then mine else nil, serverNow), mine, "In")
	local theirs = rivalModel and rivalModel:GetAttribute("Statuses")
	logStatuses(
		rivalStatuses:update(theirs, serverNow),
		theirs,
		"Foe",
		rivalModel and (rivalModel:GetAttribute("RivalName") or rivalModel.Name)
	)
	local warningModel = drawFoeCast(rivalModel, serverNow)
	FoeCastBar.step(serverNow, warningModel)
	matchup:draw(rivalModel, viewport, rivalPanel.Visible)
	CombatFx.auras(serverNow)
	if rivalModel ~= logRival and rivalModel ~= nil then
		logRival = rivalModel
		combatLog:reset() -- a new rival: a new fight
	end
	combatLog:step(not narrow)
	StatusBars.step(serverNow)
	local trackedTarget = TargetLock.target()
	reticle.TextColor3 = if holding
		then castColor
		elseif blockHeld then P.Gold
		elseif trackedTarget then Color3.fromRGB(101, 210, 228)
		else P.Text
	-- Callouts fade out; idle shows only states that need attention.
	if now > feedbackUntil then
		hint.Text = if cursorFree then "TAB  ·  return to combat" elseif blockHeld then "GUARD UP" else ""
		hint.TextTransparency = 0
	else
		hint.TextTransparency = math.clamp(1 - (feedbackUntil - now) / 0.3, 0, 1)
	end
	comboLabel.Visible = now < comboUntil
	if comboLabel.Visible then
		local fadeOut = math.clamp(1 - (comboUntil - now) / 0.4, 0, 1)
		comboLabel.TextTransparency, comboWord.TextTransparency = fadeOut, fadeOut
	end
	if holding and elapsed > 3 then
		cancel()
	end
	FirstPerson.setPose(blockHeld, elapsed / Actions.OverchargeAt)
	-- Key reminder: shown for the first seconds of a fight, or with a free cursor.
	local hintAge = now - fightSince
	controlsHint.Visible = not UserInputService.TouchEnabled and (cursorFree or hintAge < 13)
	controlsHint.TextTransparency = if cursorFree then 0 else math.clamp(hintAge - 12, 0, 1)
	cursorModal.Modal = cursorFree
	local hit = aimedHit()
	local lockedTarget = trackedTarget
	local target = lockedTarget or (hit and hit.Instance:FindFirstAncestorOfClass("Model"))
	local enemyHumanoid = target and target:FindFirstChildOfClass("Humanoid")
	targetCard.Visible = enemyHumanoid ~= nil
		and (target:GetAttribute("ArenaDropUntil") or 0)<=workspace:GetServerTimeNow()
		and enemyHumanoid.Health > 0
		and target ~= player.Character
		and not game:GetService("CollectionService"):HasTag(target, "Vendor")
	if targetCard.Visible then
		local opponent = Players:GetPlayerFromCharacter(target)
		local ratio = math.clamp(enemyHumanoid.Health / math.max(1, enemyHumanoid.MaxHealth), 0, 1)
		if target ~= lastTarget then
			lastTarget, targetTrailRatio = target, ratio
		end
		targetTrailRatio = if ratio >= targetTrailRatio
			then ratio
			else targetTrailRatio + (ratio - targetTrailRatio) * (1 - math.exp(-dt * 3))
		targetName.Text = if opponent then opponent.DisplayName else target.Name
		targetTag.Text = if lockedTarget then "◎ LOCKED" elseif opponent then "PLAYER" else "ENEMY"
		targetTag.TextColor3 = if lockedTarget then Color3.fromRGB(101, 210, 228) else P.Dim
		local nearby = TargetLock.switchCount()
		switchHint.Visible = lockedTarget ~= nil and nearby >= 2
		switchHint.Text = string.format(
			"%s  SWITCH TARGET  ·  %d NEARBY",
			if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "TAP" else "X",
			nearby
		)
		for _, cap in targetCaps do
			cap.BackgroundColor3 = if lockedTarget then Color3.fromRGB(101, 210, 228) else HudChrome.Gold
		end
		targetFill.Size = UDim2.fromScale(ratio, 1)
		targetTrail.Size = UDim2.fromScale(targetTrailRatio, 1)
		targetText.Text = string.format(
			"%d / %d  (%d%%)",
			math.ceil(enemyHumanoid.Health),
			math.ceil(enemyHumanoid.MaxHealth),
			math.ceil(ratio * 100)
		)
		for id, pool in targetPools do
			-- Another player's own attributes, or the rival's published ones.
			local amount = if opponent then opponent:GetAttribute(id) else target:GetAttribute("Rival" .. id)
			local maximum = (if opponent then opponent:GetAttribute("Max" .. id) else nil) or Tech.Resources[id].Max
			pool.Track.Visible, pool.Label.Visible = amount ~= nil, amount ~= nil
			if amount then
				local share = math.clamp(amount / math.max(1, maximum), 0, 1)
				pool.Fill.Size = UDim2.fromScale(share, 1)
				local low = if share <= 0.2 then (if id == "Stamina" then "GUARD WEAK  ·  " else "  ·  DRY") else ""
				pool.Label.Text = if id == "Charge"
					then string.format("CHARGE  %d / %d%s", amount, maximum, low)
					else string.format("%s%d / %d  STAMINA", low, amount, maximum)
			end
		end
	else
		lastTarget = nil
	end
	if blockHeld and now >= nextBlockUpdate then
		local aim = aimPoint()
		face(aim)
		input:FireServer("Block", true, aim)
		nextBlockUpdate = now + 0.15
	end
	for id, slot in slots do
		local cd = cooldowns[id]
		local remaining = if cd then math.max(0, cd.Ready - now) else 0
		if id == "Basic" or id == "Heavy" then
			remaining = math.max(0, nextAttack - now)
		end
		slot.Key.Text = if UserInputService.TouchEnabled
			then (if id == "Dodge" then "TAP·2×" else "HOLD")
			else ({ Basic = "LMB", Heavy = "SHIFT+LMB", Block = "HOLD RMB", Dodge = "SPACE" })[id]
		slot.Timer.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
		local pressed = (id == "Block" and blockHeld)
			or (holding and ((id == "Basic" and attackSide == "Left") or (id == "Heavy" and attackSide == "Right")))
		slot.Name.TextColor3 = if pressed then P.Gold elseif remaining > 0 then P.Dim else P.Text
	end
	slots.Block.Name.Text = if player:GetAttribute("Blocking") then "GUARD UP" else "GUARD"
end)
local fxFolder = Instance.new("Folder")
fxFolder.Name = "CombatFx"
fxFolder.Parent = workspace

local function effectPart(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	if shape then
		part.Shape = shape
	end
	part.CFrame = cframe
	part.Parent = fxFolder
	return part
end

local function fade(part: BasePart, seconds: number, grow: Vector3?)
	local goal: { [string]: any } = { Transparency = 1 }
	if grow then
		goal.Size = grow
	end
	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(part, seconds + 0.05)
end

-- A flat ring on the ground: a thin disc (cylinders lie along X).
local function ring(center: Vector3, radius: number, color: Color3, transparency: number): Part
	local disc = effectPart(
		Vector3.new(0.2, radius * 2, radius * 2),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.PartType.Cylinder
	)
	disc.Transparency = transparency
	return disc
end

-- The ground under a spot: not a fighter standing on it (a blast aimed at
-- an enemy would ring its head) or anything you can walk through.
local function floorUnder(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local skip: { Instance } = { fxFolder, workspace:FindFirstChild("Enemies") or fxFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position + Vector3.new(0, 0.15, 0) else position
end

local numbers = 0
local function damageNumber(position: Vector3, amount: number, crit: boolean, color: Color3?, matchTag: string?)
	if numbers >= 24 then
		return -- plenty on screen already
	end
	numbers += 1
	local anchor =
		effectPart(Vector3.one * 0.1, CFrame.new(position + Vector3.new(math.random() - 0.5, 0, 0)), Color3.new())
	anchor.Transparency = 1
	local board = new("BillboardGui", {
		Size = UDim2.fromOffset(140, 48),
		AlwaysOnTop = true,
		MaxDistance = 120,
		StudsOffset = Vector3.zero,
	}, anchor)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		-- RESIST / WEAK!: the element against the target's armor (ElementMatchup).
		Text = (if crit then "CRIT " else "")
			.. tostring(amount)
			.. (if matchTag == "Weak" then " WEAK!" elseif matchTag == "Resist" then " RESIST" else ""),
		TextSize = if crit then 32 else 24,
		TextColor3 = if matchTag == "Resist"
			then Color3.fromRGB(165, 168, 180)
			elseif matchTag == "Weak" then Color3.fromRGB(255, 150, 60)
			else color or Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2,
	}, board)
	local punch = new("UIScale", { Scale = 1.35 }, label)
	TweenService:Create(punch, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(board, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 3, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.95, function()
		numbers -= 1
		anchor:Destroy()
	end)
end

local handlers = {}
function handlers.Log(entry)
	if type(entry) ~= "table" then
		return
	end
	combatLog:add(entry)
	if entry.Kind == "Heal" and (entry.Amount or 0) > 0 then
		-- A green shimmer on whoever healed.
		local model = if entry.Dir == "Foe" then rivalModel else player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if root then
			CombatFx.burst(root.Position, Color3.fromRGB(110, 235, 140), "Frost", 1.2)
			CombatSound.play("Heal", root.Position)
		end
	elseif entry.Kind == "Kill" then
		CombatSound.play("Kill")
	end
end
function handlers.HitConfirm(crit)
	hitUntil, hitCritical = os.clock() + 0.18, crit == true
end
function handlers.IncomingDamage(origin)
	incomingOrigin, incomingUntil = origin, os.clock() + 0.65
	if typeof(origin) == "Vector3" then
		TargetLock.engageNear(origin) -- whatever hit you gets locked
	end
	flashUntil = os.clock() + 0.3
	CombatSound.play("Hurt")
	CombatFx.shake(0.018, 0.22)
	CombatVfx.screen("Hurt")
end
function handlers.TechStatus(message)
	hint.Text, feedbackUntil = message, os.clock() + 1
end
-- `duration`: this ability's own cooldown; `lockout`: the short pause
-- before anything else (its Recovery).
function handlers.TechCooldown(id, duration, lockout)
	techCooldowns[id] = { Ready = os.clock() + duration, Total = duration }
	nextAttack = math.max(nextAttack, os.clock() + (lockout or duration))
	local definition = Tech.Catalog[id]
	if definition and definition.Resource == "Stamina" then
		FirstPerson.swing("Right")
	end
	-- Wind-ups (Solar Flare, Supernova, Breach Hammer...) fill the cast bar.
	local profile = GemClient.Profile
	local key = string.match(id, "^Surge(%a)$")
	local gem = key and Tech.surgeGem(profile and profile.Character, key)
	local stats = if gem
		then Tech.surgeStats(gem, profile and Tree.effects(profile))
		elseif definition then Tree.techStats(profile, id)
		else nil
	-- Every cast takes as long as anyone's (Actions.castTime, the same as
	-- the rival's): the cast bar fills and, in first person, your hands cast it.
	local castTime = if stats then Actions.castTime(stats) else 0
	local castColor = if gem then GemConfig.ElementColors[gem.Element] or P.Gold else Tech.Resources.Stamina.Color
	if castTime > 0 then
		cast = { Name = stats.Name, Start = os.clock(), Duration = castTime, Color = castColor }
	end
	if gem then
		FirstPerson.cast(castTime, castColor, Actions.castPose(stats))
	end
end
local signatureLive = 0
function handlers.AbilitySignature(_who, from, to, color, pattern, radius)
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - to).Magnitude > 160 or signatureLive >= 80 then
		return
	end
	local delta = to - from
	if delta.Magnitude < 0.05 then
		return
	end
	local axis = CFrame.lookAt(from, to)
	local count = if pattern == "Helix" then 16 else 10
	local spread = math.clamp(radius or 3, 2, 9)
	for i = 1, count do
		local p = i / count
		local at, size
		if pattern == "Rail" then
			at = axis
				* CFrame.new(math.cos(p * math.pi * 4) * 0.4, math.sin(p * math.pi * 4) * 0.4, -delta.Magnitude * p)
			size = Vector3.new(0.09, 0.09, 0.8 + p)
		elseif pattern == "Crescent" then
			local angle = (p - 0.5) * math.pi * 0.9
			at = axis
				* CFrame.new(math.sin(angle) * 5, -0.4, -math.cos(angle) * 5)
				* CFrame.Angles(0, -angle, math.pi / 4)
			size = Vector3.new(0.12, 0.35, 1.4)
		elseif pattern == "Spikes" then
			local angle = p * math.pi * 2
			at = CFrame.new(to + Vector3.new(math.cos(angle) * spread * 0.55, -1, math.sin(angle) * spread * 0.55))
				* CFrame.Angles(0.2, angle, 0.22)
			size = Vector3.new(0.22, 1 + (i % 3) * 0.65, 0.22)
		elseif pattern == "Helix" then
			local strand = if i % 2 == 0 then 0 else math.pi
			local angle = p * math.pi * 4 + strand
			at = axis * CFrame.new(math.cos(angle) * 0.8, math.sin(angle) * 0.8, -delta.Magnitude * p)
			size = Vector3.new(0.18, 0.18, 0.65)
		else
			return
		end
		local shard = effectPart(size, at, color)
		shard.Transparency = 0.25
		signatureLive += 1
		fade(shard, 0.35, size * 1.5)
		task.delay(0.4, function()
			signatureLive = math.max(0, signatureLive - 1)
		end)
	end
end
function handlers.TechPulse(_who, from, to, color, radius)
	-- The cast (its element's own release when it has one) and the landing.
	local element = CombatSound.elementOf(color)
	if element then
		CombatSound.element("Cast", element, from)
		CombatSound.element("Impact", element, to, { Volume = 0.8 })
	else
		CombatSound.play("Cast", from)
	end
	if (to - from).Magnitude > 6 then
		CombatSound.play("Beam", from, { Volume = 0.6 })
	end
	-- A flickering beam with a white core, a burst and shockwave where it lands.
	CombatVfx.beam(from, to, color, radius)
	if radius > 0 then
		-- Its reach, flat on the ground under where it lands.
		local pulse = ring(floorUnder(to), radius, color, 0.7)
		fade(pulse, 0.35, Vector3.new(0.1, radius * 2.5, radius * 2.5))
	end
end
function handlers.TechField(who, color)
	local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	CombatSound.play("Shield", root.Position)
	CombatSound.element("Cast", CombatSound.elementOf(color), root.Position, { Volume = 0.6 })
	CombatFx.burst(root.Position, color, "Frost", 0.8)
	CombatVfx.aura(root, color)
	for index = 1, 6 do
		local angle = index * math.pi / 3
		local panel = effectPart(
			Vector3.new(0.12, 1.5, 0.6),
			CFrame.new(root.Position) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -1.5),
			color
		)
		panel.Transparency = 0.4
		fade(panel, 0.5)
	end
end
function handlers.Interrupted(seconds)
	-- Your cast was jabbed: it's gone and your surges are locked a moment.
	cast = nil
	CombatSound.play("GuardBreak", nil, { Volume = 0.6 })
	CombatVfx.screen("Stun", 0.3)
	hint.Text, feedbackUntil = string.format("INTERRUPTED  ·  SURGES LOCKED %ds", seconds), os.clock() + 1.4
end
function handlers.Combo(name)
	local combo = require(ReplicatedStorage.Shared.ElementCombos).List[name]
	if combo then
		hint.Text, feedbackUntil = combo.Text, os.clock() + 1
		hint.TextColor3 = combo.Color
		task.delay(1, function()
			hint.TextColor3 = P.Text
		end)
		CombatFx.shake(0.03, 0.2)
	end
end
function handlers.HighBlock()
	hint.Text, feedbackUntil = "HIGH BLOCK - COUNTER!", os.clock() + 1
	CombatSound.play("Parry")
	local root = rootPart()
	if root then
		CombatVfx.parry(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), P.Gold)
	end
	CombatVfx.screen("Parry")
end
function handlers.Parried(seconds)
	CombatSound.play("GuardBreak", nil, { Volume = 0.7 })
	CombatFx.shake(0.02, 0.25)
	CombatVfx.screen("Stun", seconds)
	CombatSound.play("Stun", nil, { Volume = 0.7 })
	cancel()
	cast = nil
	nextAttack = math.max(nextAttack, os.clock() + seconds)
	hint.Text, feedbackUntil = "PARRIED", os.clock() + 0.9
end
function handlers.AttackTiming(stage, side, combo)
	hint.Text = stage
	feedbackUntil = os.clock() + 0.9
	if combo > 1 then
		-- A ringing tick that climbs with the combo.
		CombatSound.play("Combo", nil, { Pitch = 1 + (combo - 2) * 0.15 })
		comboLabel.Text, comboUntil = "x" .. combo, os.clock() + 2
		comboScale.Scale = 1.4
		TweenService:Create(comboScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	local loadout = GemClient.Profile and GemClient.Profile.Character
	local weapon = loadout and Classes.weapon(loadout.Class, loadout.Weapon)
	if weapon and weapon.Attack.Kind == "Shot" then
		FirstPerson.fire()
	else
		FirstPerson.swing(side, stage == "CHARGED" or stage == "PERFECT")
	end
end

function handlers.Damage(position: Vector3, amount: number, crit: boolean, color: Color3?, matchTag: string?)
	damageNumber(position, amount, crit, color, matchTag)
	if amount <= 0 then
		return
	end
	-- Sparks in the hit's colour; crits burst bigger, ring out and shake a little.
	local tint = color or Color3.new(1, 1, 1)
	CombatVfx.impact(position - Vector3.new(0, 0.6, 0), tint, crit, amount >= 30)
	-- An elemental hit shows its element: flame, ice spikes, arcs or a splash.
	local element = CombatSound.elementOf(color)
	CombatVfx.element(position - Vector3.new(0, 0.6, 0), element, if crit then 1.4 else 1)
	-- The blow (a crit rings out, a big one lands heavy), plus its element.
	CombatSound.play(if crit then "Crit" elseif amount >= 30 then "HeavyHit" else "Hit", position)
	CombatSound.element("Impact", element, position, { Volume = 0.65 })
	if crit and CombatFx.nearMe(position, 30) then
		CombatFx.shake(0.012, 0.15)
		CombatVfx.screen("Crit")
	end
end

-- A fan of glowing blades across the swing's arc.
function handlers.Swing(
	_who: Player,
	origin: Vector3,
	direction: Vector3,
	range: number,
	arc: number,
	color: Color3,
	big: boolean
)
	CombatSound.play(if big then "HeavySwing" else "Swing", origin)
	-- A crescent trail swept across the arc, alternating sides swing to swing.
	CombatVfx.slash(origin, direction, range, arc, color, big)
end

function handlers.Shot(_who: Player, from: Vector3, to: Vector3, color: Color3, look: string?)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local fireball = look == "Fireball"
	CombatSound.play(if fireball then "Bolt" else "Shot", from)
	if fireball then
		CombatSound.element("Cast", "Fire", from, { Volume = 0.5 })
	end
	-- A glowing round (or fireball) with a trail, and an impact where it lands.
	CombatVfx.projectile(from, to, color, fireball)
end

-- A ground blast. With a delay: a warning ring with its zones marked (the
-- core that stuns, the middle that staggers, the edge that only grazes),
-- pulsing faster as it comes, then the burst: a flash dome, two shockwaves
-- racing out along the ground, a pillar of light, embers, smoke and debris,
-- and a shake that's harder the closer to the centre you are.
function handlers.Nova(center: Vector3, radius: number, color: Color3, delay: number)
	local floor = floorUnder(center)
	if delay and delay > 0 then
		local red = Color3.fromRGB(255, 60, 40)
		local warn = ring(floor, radius, red, 0.7)
		local middle = ring(
			floor + Vector3.new(0, 0.04, 0),
			radius * Actions.Blast.StaggerZone,
			Color3.fromRGB(255, 130, 40),
			0.75
		)
		local core =
			ring(floor + Vector3.new(0, 0.08, 0), radius * Actions.Blast.StunZone, Color3.fromRGB(255, 220, 90), 0.55)
		CombatSound.play("NovaWarn", floor)
		-- The rings pulse faster as the blast comes; the core flickers hardest.
		task.spawn(function()
			local stop = os.clock() + delay
			while warn.Parent and os.clock() < stop do
				local left = stop - os.clock()
				local wave = 0.5 + 0.5 * math.sin(os.clock() * (8 + 30 * (1 - left / delay)))
				warn.Transparency = 0.45 + 0.35 * wave
				middle.Transparency = 0.55 + 0.3 * wave
				core.Transparency = 0.25 + 0.45 * wave
				task.wait()
			end
		end)
		task.delay(delay, function()
			warn:Destroy()
			middle:Destroy()
			core:Destroy()
			-- A flash dome bursting out of the centre.
			local dome = effectPart(Vector3.one * radius * 0.4, CFrame.new(floor), color, Enum.PartType.Ball)
			dome.Transparency = 0.15
			fade(dome, 0.35, Vector3.one * radius * 2)
			-- Two shockwaves racing out along the ground.
			local wave = ring(floor + Vector3.new(0, 0.1, 0), 1, color:Lerp(Color3.new(1, 1, 1), 0.35), 0.05)
			fade(wave, 0.3, Vector3.new(0.3, radius * 2.1, radius * 2.1))
			local after = ring(floor + Vector3.new(0, 0.12, 0), 1, color, 0.35)
			fade(after, 0.65, Vector3.new(0.2, radius * 2.5, radius * 2.5))
			-- A scorch mark with a glowing rim that cools, then fades.
			CombatVfx.scorch(floor, radius, color)
			local pillar = effectPart(Vector3.new(2, 40, 2), CFrame.new(floor + Vector3.new(0, 20, 0)), color)
			fade(pillar, 0.45, Vector3.new(radius * 0.8, 46, radius * 0.8))
			CombatFx.burst(floor + Vector3.new(0, 1, 0), color, "Embers", 1.8 + radius / 6)
			CombatFx.burst(floor + Vector3.new(0, 0.6, 0), color, "Sparks", 1.5 + radius / 8)
			CombatFx.burst(floor + Vector3.new(0, 0.5, 0), Color3.fromRGB(120, 110, 100), "Smoke", 1.8 + radius / 10)
			CombatFx.burst(floor + Vector3.new(0, 0.5, 0), Color3.fromRGB(110, 100, 92), "Shards", 1.4)
			CombatFx.flash(floor + Vector3.new(0, 3, 0), color, 8, radius * 3, 0.45)
			CombatSound.play("Blast", floor, { Volume = 1.2 })
			CombatSound.element("Impact", CombatSound.elementOf(color), floor, { Volume = 0.9 })
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local offset = root.Position - floor
				local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if distance <= radius + 14 then
					local closeness = 1 - math.clamp(distance / (radius + 14), 0, 1)
					CombatFx.shake(0.02 + 0.05 * closeness, 0.3 + 0.3 * closeness)
				end
			end
		end)
		return
	end
	local blast = ring(floor, 1, color, 0.2)
	fade(blast, 0.4, Vector3.new(0.2, radius * 2, radius * 2))
	CombatFx.burst(floor + Vector3.new(0, 1, 0), color, "Sparks", 1 + radius / 10)
	CombatSound.play("Blast", floor, { Volume = 0.6, Pitch = 1.3 })
end

-- A ground blast caught you: stunned (and thrown out of it) at its core,
-- staggered further out.
function handlers.Blasted(kind: string, seconds: number, push: Vector3?)
	cancel()
	cast = nil
	nextAttack = math.max(nextAttack, os.clock() + seconds)
	local stunned = kind == "Stunned"
	hint.Text, feedbackUntil = if stunned then "STUNNED!" else "STAGGERED", os.clock() + seconds + 0.3
	CombatFx.shake(if stunned then 0.06 else 0.035, if stunned then 0.5 else 0.3)
	CombatVfx.screen("Stun", seconds)
	CombatSound.play(if stunned then "Stun" else "Hurt", nil, { Volume = if stunned then 1 else 0.7 })
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and push and push.Magnitude > 0.1 then
		root.AssemblyLinearVelocity = push + Vector3.new(0, push.Magnitude * 0.45, 0)
	end
end

function handlers.Zone(center: Vector3, radius: number, duration: number, color: Color3)
	local floor = floorUnder(center)
	CombatSound.play("Corrode", floor)
	CombatFx.burst(floor + Vector3.new(0, 0.5, 0), color, "Smoke", 1 + radius / 8)
	local disc = ring(floor, radius, color, 0.75)
	local edge = ring(floor + Vector3.new(0, 0.05, 0), radius, color, 0.4)
	edge.Size = Vector3.new(0.1, radius * 2, radius * 2)
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop and disc.Parent do
			-- A churning pool: gas puffing up and bubbles rising and popping,
			-- its edge breathing.
			edge.Transparency = 0.3 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 5))
			local offset = Vector3.new((math.random() - 0.5) * radius * 1.6, 0, (math.random() - 0.5) * radius * 1.6)
			CombatFx.burst(floor + offset + Vector3.new(0, 0.4, 0), color, "Smoke", 0.6)
			local bubble = effectPart(
				Vector3.one * 0.5,
				CFrame.new(floor + offset),
				color:Lerp(Color3.new(1, 1, 1), 0.3),
				Enum.PartType.Ball
			)
			bubble.Transparency = 0.3
			fade(bubble, 0.5, Vector3.one * 0.9)
			TweenService:Create(bubble, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
				CFrame = CFrame.new(floor + offset + Vector3.new(0, 2.5, 0)),
			}):Play()
			task.wait(0.12)
		end
		fade(disc, 0.3)
		fade(edge, 0.3)
	end)
end

function handlers.Buff(who: Player, color: Color3)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		CombatSound.play("Shield", root.Position)
		CombatSound.element("Cast", CombatSound.elementOf(color), root.Position, { Volume = 0.6 })
		CombatFx.burst(root.Position, color, "Frost", 1)
		CombatVfx.aura(root, color)
	end
end

function handlers.Arc(from: Vector3, to: Vector3, color: Color3)
	-- A forked, flickering bolt.
	CombatVfx.lightning(from, to, color)
	CombatSound.play("Zap", to)
	CombatSound.element("Impact", "Shock", to, { Volume = 0.6 })
end

function handlers.Death(position: Vector3, color: Color3?, element: string?, model: Model?)
	-- The body blows apart: burning, arcing, melting or shattering by the
	-- element that killed it, a plain blast without one.
	if not require(script.Parent.Modules.ElementalDeath).play(model, element, color) then
		CombatVfx.death(position, color or Color3.new(1, 1, 1))
	end
	CombatSound.play("Death", position)
end

function handlers.EnemySwing(from: Vector3, to: Vector3, color: Color3)
	CombatSound.play("Swing", from, { Pitch = 0.85 })
	local offset = to - from
	CombatVfx.slash(
		from,
		offset,
		math.max(3, offset.Magnitude),
		100,
		color,
		false,
		if math.random() < 0.5 then 1 else -1
	)
end

function handlers.Cooldown(id, seconds)
	cooldowns[id] = { Ready = os.clock() + seconds, Total = seconds }
	if id == "Basic" or id == "Heavy" then
		nextAttack = os.clock() + seconds
	end
end
function handlers.BlockBroken(seconds, reason)
	blockHeld = false
	cooldowns.Block = { Ready = os.clock() + seconds, Total = seconds }
	if reason == "Exhausted" then
		-- Out of Stamina: the guard can't hold (or can't go up at all).
		hint.Text, feedbackUntil = "OUT OF STAMINA", os.clock() + 1.2
		CombatSound.play("Winded")
		UiKit.toast("Out of Stamina: your guard drops!", Tech.Resources.Stamina.Color)
	else
		UiKit.toast("Guard broken!", P.Gold)
	end
end
function handlers.BlockSpark(position, broken)
	CombatSound.play(if broken then "GuardBreak" else "Block", position)
	CombatFx.burst(
		position + Vector3.new(0, 1, 0),
		if broken then Color3.fromRGB(255, 160, 50) else Color3.fromRGB(200, 240, 255),
		"Sparks",
		if broken then 1.8 else 1.1
	)
	if broken and CombatFx.nearMe(position, 20) then
		CombatFx.shake(0.03, 0.3)
	end
	-- A shield of light where the blow met the guard; a broken one shatters.
	local camera = workspace.CurrentCamera
	CombatVfx.guard(position + Vector3.new(0, 1, 0), if camera then camera.CFrame.Position - position else nil, broken)
end
function handlers.BlockRaise(who)
	local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local plate = effectPart(Vector3.new(2.4, 2.5, 0.1), root.CFrame * CFrame.new(0, 0, -2), P.Teal)
		plate.Transparency = 0.6
		fade(plate, 0.2)
	end
end
function handlers.BlockGem(who, element)
	local colors = {
		Fire = Color3.fromRGB(255, 100, 55),
		Frost = Color3.fromRGB(90, 195, 255),
		Poison = Color3.fromRGB(100, 230, 130),
		Shock = Color3.fromRGB(255, 230, 80),
	}
	handlers.Buff(who, colors[element] or P.Teal)
end
function handlers.DodgeRoll(who, origin, direction, distance, afterimage)
	-- A hop is short; a roll goes the distance and kicks up more dust.
	local hop = distance < 10
	CombatSound.play(if hop then "Hop" else "Roll", origin)
	CombatFx.burst(origin - Vector3.new(0, 2.5, 0), Color3.fromRGB(170, 160, 145), "Smoke", if hop then 0.6 else 1.1)
	local color = if afterimage then Color3.fromRGB(80, 225, 255) else P.Gold
	CombatVfx.dash(origin, direction, distance, color)
	for i = 0, 4 do
		task.delay(i * 0.05, function()
			local cf = CFrame.lookAt(origin + direction * distance * i / 4, origin + direction * (distance * i / 4 + 1))
			local ghost =
				effectPart(if afterimage then Vector3.new(1.4, 2.6, 0.4) else Vector3.new(1.8, 0.15, 1), cf, color)
			ghost.Transparency = 0.55
			fade(ghost, 0.25)
		end)
	end
	if who == player then
		holding = false
	end
end
fxEvent.OnClientEvent:Connect(function(kind, ...)
	local handler = handlers[kind]
	if handler then
		handler(...)
	end
end)
