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
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local ArenaScene = require(script.Parent.Modules.ArenaScene)
local CombatGuide = require(script.Parent.Modules.CombatGuide)
local AugmentTreeUI = require(script.Parent.Modules.AugmentTreeUI)
local FirstPerson = require(script.Parent.Modules.FirstPersonCombat)
local TargetLock = require(script.Parent.Modules.TargetLock)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)
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
-- Bottom of the screen: Gem Surges (Q, E, R) on the left, the unit frame
-- (Health over Charge) in the centre, Rig Maneuvers (1, 2, 3) under Stamina
-- on the right.
local hud = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(12, 17, 28),
	BackgroundTransparency = 0.12,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -34),
	Size = UDim2.fromOffset(320, 74),
}, gui)
UiKit.round(hud, 10)
new("UIStroke", { Color = Color3.fromRGB(70, 96, 128), Transparency = 0.45, Thickness = 1 }, hud)
local nameLabel = text(hud, string.upper(player.DisplayName), 12, P.Text, IronUi.Bold)
nameLabel.AutomaticSize, nameLabel.TextWrapped, nameLabel.TextTruncate =
	Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
nameLabel.Position, nameLabel.Size = UDim2.fromOffset(12, 6), UDim2.new(0.6, -12, 0, 16)
local hp = text(hud, "", 11, Color3.fromRGB(150, 225, 255), IronUi.Bold)
hp.AutomaticSize, hp.TextWrapped = Enum.AutomaticSize.None, false
hp.TextXAlignment = Enum.TextXAlignment.Right
hp.Position, hp.Size = UDim2.new(0.4, 0, 0, 6), UDim2.new(0.6, -12, 0, 16)
local row =
	new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1) }, gui)
local healthTrack = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(28, 32, 46),
	Position = UDim2.fromOffset(12, 25),
	Size = UDim2.new(1, -24, 0, 16),
	BorderSizePixel = 0,
}, hud)
UiKit.round(healthTrack, 4)
new("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.4, Thickness = 1 }, healthTrack)
local healthTrail = new(
	"Frame",
	{ BackgroundColor3 = Color3.fromRGB(255, 196, 110), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
	healthTrack
)
UiKit.round(healthTrail, 4)
local healthFill = new(
	"Frame",
	{ BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 },
	healthTrack
)
UiKit.round(healthFill, 4)
local healthGradient = new("UIGradient", { Rotation = 90 }, healthFill)
-- Barrier (shield) absorbs, drawn as a pale band after current health.
local shieldFill = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(190, 240, 255),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(0, 1),
	ZIndex = 3,
}, healthTrack)
local healthText = shadowed(text(healthTrack, "", 11, P.Text, IronUi.Bold))
healthText.AutomaticSize, healthText.TextWrapped = Enum.AutomaticSize.None, false
healthText.TextXAlignment, healthText.Size, healthText.ZIndex = Enum.TextXAlignment.Center, UDim2.fromScale(1, 1), 4
local resourceBars = {}
local function resourceBar(parent, id, x, y)
	local color = Tech.Resources[id].Color
	local label = text(parent, id:upper(), 11, color, IronUi.Bold)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.new(1, -2 * x, 0, 12)
	local value = text(parent, "", 11, P.Text, IronUi.Bold)
	value.AutomaticSize, value.TextWrapped = Enum.AutomaticSize.None, false
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Position, value.Size = UDim2.fromOffset(x, y), UDim2.new(1, -2 * x, 0, 12)
	local track = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 32, 46),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y + 15),
		Size = UDim2.new(1, -2 * x, 0, 8),
	}, parent)
	UiKit.round(track, 3)
	local fill = new(
		"Frame",
		{ BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) },
		track
	)
	UiKit.round(fill, 3)
	fillGradient(fill, color)
	-- Segment ticks every quarter, like a classic resource orb/bar.
	for tick = 1, 3 do
		new("Frame", {
			BackgroundColor3 = Color3.fromRGB(12, 17, 28),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Position = UDim2.new(tick / 4, -1, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			ZIndex = 2,
		}, track)
	end
	resourceBars[id] = { Label = label, Value = value, Fill = fill }
end
resourceBar(hud, "Charge", 12, 47)
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
local surgeTray = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1) }, gui)
local surgeHeader = centered(surgeTray, 11, P.Gold)
surgeHeader.Text = "SURGE ARRAY"
surgeHeader.TextXAlignment = Enum.TextXAlignment.Left
surgeHeader.Position, surgeHeader.Size = UDim2.fromOffset(0, 2), UDim2.new(1, 0, 0, 14)
local maneuverTray = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1) }, gui)
resourceBar(maneuverTray, "Stamina", 0, 0)
-- One ability icon: a round gem socket (surges) or a rounded square (maneuvers).
local function makeIcon(parent, key, round)
	local radius = UDim.new(if round then 0.5 else 0.22, 0)
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
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(70, 82, 110), Color3.fromRGB(30, 34, 50)),
	}, button)
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
	local name = centered(parent, 10, P.Text)
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
	local gap = math.floor(size * 0.16)
	frame.Size = UDim2.fromOffset(size * 3 + gap * 2, 22 + size + 16)
	for i, icon in icons do
		local x = (i - 1) * (size + gap)
		icon.Button.Position, icon.Button.Size = UDim2.fromOffset(x, 22), UDim2.fromOffset(size, size)
		icon.Name.Position, icon.Name.Size = UDim2.fromOffset(x - gap // 2, 24 + size), UDim2.fromOffset(size + gap, 14)
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
local castBar = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(12, 17, 28),
	BackgroundTransparency = 0.15,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, 58),
	Size = UDim2.fromOffset(240, 22),
	Visible = false,
}, gui)
UiKit.round(castBar, 6)
new("UIStroke", { Color = Color3.fromRGB(70, 96, 128), Transparency = 0.3, Thickness = 1 }, castBar)
local castTrack = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(3, 3),
	Size = UDim2.new(1, -6, 1, -6),
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
local targetCard = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(12, 17, 28),
	BackgroundTransparency = 0.12,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.fromOffset(300, 54),
	Visible = false,
}, gui)
UiKit.round(targetCard, 10)
local targetStroke =
	new("UIStroke", { Color = Color3.fromRGB(190, 70, 80), Transparency = 0.4, Thickness = 1 }, targetCard)
local targetName = text(targetCard, "", 13, P.Text, IronUi.Bold)
targetName.AutomaticSize, targetName.TextWrapped, targetName.TextTruncate =
	Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
targetName.Position, targetName.Size = UDim2.fromOffset(12, 5), UDim2.new(1, -96, 0, 18)
local targetTag = text(targetCard, "", 10, P.Gold, IronUi.Bold)
targetTag.AutomaticSize, targetTag.TextWrapped = Enum.AutomaticSize.None, false
targetTag.TextXAlignment = Enum.TextXAlignment.Right
targetTag.Position, targetTag.Size = UDim2.new(1, -92, 0, 6), UDim2.fromOffset(80, 16)
local targetTrack = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(28, 32, 46),
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(12, 27),
	Size = UDim2.new(1, -24, 0, 16),
}, targetCard)
UiKit.round(targetTrack, 4)
local targetTrail = new(
	"Frame",
	{ BackgroundColor3 = Color3.fromRGB(255, 196, 110), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
	targetTrack
)
UiKit.round(targetTrail, 4)
local targetFill = new(
	"Frame",
	{ BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 2 },
	targetTrack
)
UiKit.round(targetFill, 4)
fillGradient(targetFill, Color3.fromRGB(200, 55, 66))
local targetText = shadowed(text(targetTrack, "", 11, P.Text, IronUi.Bold))
targetText.AutomaticSize, targetText.TextWrapped = Enum.AutomaticSize.None, false
targetText.TextXAlignment, targetText.Size, targetText.ZIndex = Enum.TextXAlignment.Center, UDim2.fromScale(1, 1), 3
local controlsHint = text(
	gui,
	"LMB Swing | Shift+LMB Off-hand | RMB Guard | Space Dodge | Q/E/R Gem Surges | 1/2/3 Rig Maneuvers | K Tree | Tab Cursor",
	11,
	P.Text
)
controlsHint.AnchorPoint, controlsHint.Position, controlsHint.Size =
	Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -8), UDim2.new(1, -20, 0, 22)
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
	Size = UDim2.fromOffset(250, 246),
	Visible = false,
}, gui)
UiKit.round(rivalPanel, 10)
local rivalStroke =
	new("UIStroke", { Color = Color3.fromRGB(190, 70, 80), Transparency = 0.35, Thickness = 1 }, rivalPanel)
local function rivalLabel(size, color, x, y, w, h)
	local label = shadowed(text(rivalPanel, "", size, color, IronUi.Bold))
	label.AutomaticSize, label.TextWrapped, label.TextTruncate = Enum.AutomaticSize.None, false, Enum.TextTruncate.AtEnd
	label.Position, label.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	return label
end
local rivalName = rivalLabel(14, P.Text, 12, 8, 160, 18)
local rivalTag = rivalLabel(10, Color3.fromRGB(255, 120, 120), 172, 10, 66, 14)
rivalTag.TextXAlignment = Enum.TextXAlignment.Right
local rivalInfo = rivalLabel(10, P.Dim, 12, 27, 226, 14)
local rivalGear = {}
for i = 1, 6 do
	local row = rivalLabel(10, P.Text, 12, 44 + (i - 1) * 14, 226, 14)
	rivalGear[i] = row
end
-- The surge: a socket with a draining cooldown, its name and its state.
local rivalSocket = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(30, 34, 50),
	Position = UDim2.fromOffset(12, 134),
	Size = UDim2.fromOffset(46, 46),
}, rivalPanel)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, rivalSocket)
local rivalSocketStroke = new("UIStroke", { Color = P.Gold, Thickness = 2 }, rivalSocket)
local rivalIcon = rivalLabel(20, P.Text, 0, 0, 46, 46)
rivalIcon.Parent, rivalIcon.TextXAlignment = rivalSocket, Enum.TextXAlignment.Center
rivalIcon.TextYAlignment = Enum.TextYAlignment.Center
local rivalShade = new("Frame", {
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 2,
}, rivalSocket)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, rivalShade)
local rivalWipe = new("UIGradient", { Rotation = 90 }, rivalShade)
local rivalSurgeName = rivalLabel(12, P.Text, 66, 136, 172, 16)
local rivalSurgeTier = rivalLabel(10, P.Dim, 66, 152, 172, 12)
local rivalSurgeState = rivalLabel(13, P.Good, 66, 165, 172, 16)
-- What it's doing right now, as a warning strip.
local rivalStance = rivalLabel(12, P.Text, 0, 0, 250, 26)
rivalStance.Position, rivalStance.Size = UDim2.fromOffset(0, 192), UDim2.new(1, 0, 0, 26)
rivalStance.TextXAlignment = Enum.TextXAlignment.Center
rivalStance.TextYAlignment = Enum.TextYAlignment.Center
local rivalHealth = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(28, 32, 46),
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(12, 226),
	Size = UDim2.new(1, -24, 0, 8),
}, rivalPanel)
UiKit.round(rivalHealth, 3)
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
}
local SLOT_SHORT =
	{ Helmet = "HEAD", Armor = "CHEST", Gloves = "HANDS", Boots = "FEET", Weapon = "WEAPON", Shield = "SHIELD" }
local rivalModel, nextRivalScan = nil, 0
local function findRival()
	local folder = workspace:FindFirstChild("Enemies")
	for _, model in folder and folder:GetChildren() or {} do
		if model:GetAttribute("RivalOwner") == player.UserId then
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
	rivalPanel.Visible = humanoid ~= nil and humanoid.Health > 0 and viewport.X >= 700
	if not rivalPanel.Visible then
		return
	end
	local element = model:GetAttribute("RivalElement")
	local color = GemConfig.ElementColors[element] or P.Gold
	rivalName.Text, rivalName.TextColor3 = model:GetAttribute("RivalName") or model.Name, color
	rivalTag.Text = if model:GetAttribute("RivalSparring") then "SPARRING" else "RIVAL"
	rivalStroke.Color = color
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
	end
	-- Surge cooldown, from server time so it matches the real thing.
	local serverNow = workspace:GetServerTimeNow()
	local readyAt = model:GetAttribute("SurgeReadyAt") or 0
	local total = math.max(1, model:GetAttribute("SurgeCooldown") or 10)
	local remaining = math.max(0, readyAt - serverNow)
	local share = math.clamp(remaining / total, 0, 0.998)
	rivalShade.Visible = share > 0
	if share > 0 then
		rivalWipe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(math.max(0.001, share), 0.3),
			NumberSequenceKeypoint.new(math.min(0.999, share + 0.001), 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	rivalIcon.Text, rivalIcon.TextColor3 = model:GetAttribute("RivalSurgeIcon") or "◆", color
	rivalSocketStroke.Color = color
	rivalSurgeName.Text = model:GetAttribute("RivalSurge") or "Gem Surge"
	rivalSurgeTier.Text = string.format(
		"%s  ·  RANK %s",
		string.upper(Tech.TierNames[model:GetAttribute("RivalSurgeTier") or 1] or ""),
		ROMAN[model:GetAttribute("RivalSurgeRank") or 1] or "I"
	)
	local castAgo = serverNow - (model:GetAttribute("SurgeCastAt") or -100)
	if castAgo < 1.2 then
		rivalSurgeState.Text, rivalSurgeState.TextColor3 = "CASTING!", P.Gold
		rivalSocketStroke.Thickness = 3
	elseif remaining > 0 then
		rivalSurgeState.Text, rivalSurgeState.TextColor3 = string.format("Ready in %.1fs", remaining), P.Dim
		rivalSocketStroke.Thickness = 2
	else
		rivalSurgeState.Text, rivalSurgeState.TextColor3 = "READY  ·  watch out", Color3.fromRGB(255, 120, 120)
		rivalSocketStroke.Thickness = 2
	end
	local stance = STANCES[model:GetAttribute("Stance") or ""]
	rivalStance.Text = if stance then stance[1] else ""
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
	return Actions.resolve(
		Classes.setState(loadout).Counts,
		if weapon and weapon.Attack.Kind == "Melee" then "Sword" else "Pistol",
		1 - (effects.CooldownMult or 1)
	)
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
local function dodge()
	if cursorFree or not canFight() then
		return
	end
	local cd = cooldowns.Dodge
	if cd and os.clock() < cd.Ready then
		return
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
		if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then humanoid.MoveDirection else root.CFrame.LookVector
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
		row,
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
local dodgeButton = makeSlot("Dodge", "DODGE", "TAP", UDim2.new(1, -56, 1, -210))
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
local lastActive = false
RunService.RenderStepped:Connect(function(dt)
	-- The combat HUD never draws over the menu dashboard.
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	local fight = canFight() == true and not (dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled)
	gui.Enabled = fight
	TargetLock.setActive(fight and not cursorFree and not CombatGuide.isOpen() and not AugmentTreeUI.isOpen())
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
	local guideOpen = CombatGuide.isOpen() or AugmentTreeUI.isOpen()
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
	local iconSize = if portrait
		then math.clamp(math.floor((viewport.X - 76) / 6.6), 36, 52)
		elseif short then 50
		else 62
	layoutTray(surgeTray, surgeIcons, iconSize)
	layoutTray(maneuverTray, maneuverIcons, iconSize)
	surgeTray.Position, maneuverTray.Position = UDim2.new(0, 16, 1, -12), UDim2.new(1, -16, 1, -12)
	-- The Health/Charge panel sits between the trays, or above them when narrow.
	local trayWidth, trayHeight = surgeTray.Size.X.Offset, surgeTray.Size.Y.Offset
	local between = viewport.X - 2 * (trayWidth + 32)
	local stacked = portrait or between < 240
	local hudBottom = if stacked then 22 + trayHeight else 34
	local hudWidth = if stacked then math.min(300, viewport.X - 32) else math.min(300, between)
	hud.AnchorPoint, hud.Position, hud.Size =
		Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -hudBottom), UDim2.fromOffset(hudWidth, 74)
	-- Touch players get on-screen swing, guard and dodge buttons above the panel.
	local slotWidth = math.min(80, (viewport.X - 32) / 4 - 8)
	for index, id in { "Basic", "Heavy", "Block", "Dodge" } do
		local slot = slots[id]
		slot.Button.Visible = touch
		slot.Button.Size = UDim2.fromOffset(slotWidth, 70)
		slot.Button.Position = UDim2.new(0.5, (index - 2.5) * (slotWidth + 8), 1, -(hudBottom + 84))
	end
	controlsHint.Position = UDim2.new(0.5, 0, 1, -(hudBottom + 82))
	controlsHint.Size = UDim2.fromOffset(math.min(760, viewport.X - 32), 22)
	leave.Position, leave.Size =
		UDim2.new(1, -12, 0, if portrait then 80 else 16), UDim2.fromOffset(if portrait then 130 else 160, 38)
	targetCard.Size = UDim2.fromOffset(if portrait then math.min(220, viewport.X - 150) else 300, 54)
	targetName.TextSize = if portrait then 11 else 13
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
		shieldFill.Position = UDim2.fromScale(ratio, 0)
		shieldFill.Size = UDim2.fromScale(math.min(shield / maxHealth, 1 - ratio), 1)
		healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), math.ceil(humanoid.MaxHealth))
		hp.Text = if shield > 0 then string.format("◈ SHIELD %d", shield) else ""
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
			icon.Glyph.Text, icon.Glyph.TextColor3 = definition.Icon or "◆", color
			icon.Badge.Text = string.format("T%d · %s", definition.Tier, ROMAN[definition.Rank] or "I")
			icon.Name.Text = definition.Name
			local usable = (player:GetAttribute("Charge") or 0) >= cost
			setIcon(icon, color, techCooldowns["Surge" .. key], usable, beamKey == key, not usable)
		else
			icon.Glyph.Text, icon.Glyph.TextColor3 = "+", P.Dim
			icon.Badge.Text, icon.Name.Text = "", "EMPTY"
			setIcon(icon, P.Dim, nil, false, false)
		end
	end
	local shielded = loadout and Classes.gear(loadout.Class, "Shields", loadout.Shield)
	for slot, icon in maneuverIcons do
		local id = maneuverOn(slot)
		local definition = id and Tree.techStats(profile, id)
		local color = Tech.Resources.Stamina.Color
		if definition then
			local learned = Tree.isLearned(profile, id)
			icon.Glyph.Text, icon.Glyph.TextColor3 = definition.Icon or "✦", color
			icon.Name.Text = definition.Name
			icon.Badge.Text = if learned then string.format("%d ST", math.floor(definition.Cost + 0.5)) else "LOCKED"
			local affordable = (player:GetAttribute("Stamina") or 0) >= definition.Cost
			local usable = learned and affordable and (not definition.Shield or shielded ~= nil)
			setIcon(icon, color, techCooldowns[id], usable, false, learned and not affordable)
		else
			icon.Glyph.Text, icon.Glyph.TextColor3 = "+", P.Dim
			icon.Badge.Text, icon.Name.Text = "", "EMPTY"
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
		castLabel.Text = string.format("%s  ·  %.1fs", cast.Name:upper(), cast.Start + cast.Duration - now)
	elseif beamKey then
		local gem = Tech.surgeGem(loadout, beamKey)
		local definition = gem and Tech.surgeStats(gem)
		castColor = if gem then GemConfig.ElementColors[gem.Element] or P.Gold else P.Gold
		local charge = player:GetAttribute("Charge") or 0
		chargeFill.Size = UDim2.fromScale(math.clamp(charge / (player:GetAttribute("MaxCharge") or 100), 0, 1), 1)
		castLabel.Text = (if definition then definition.Name:upper() else "CHANNEL") .. "  ·  CHANNELING"
	else
		cast = nil
	end
	perfectWindow.Visible = holding
	castBar.Visible = holding or cast ~= nil or beamKey ~= nil
	chargeFill.BackgroundColor3 = castColor
	drawRival(now, viewport)
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
		targetStroke.Color = if lockedTarget then Color3.fromRGB(101, 210, 228) else Color3.fromRGB(190, 70, 80)
		targetFill.Size = UDim2.fromScale(ratio, 1)
		targetTrail.Size = UDim2.fromScale(targetTrailRatio, 1)
		targetText.Text = string.format(
			"%d / %d  (%d%%)",
			math.ceil(enemyHumanoid.Health),
			math.ceil(enemyHumanoid.MaxHealth),
			math.ceil(ratio * 100)
		)
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
			then (if id == "Dodge" then "TAP" else "HOLD")
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

local function floorUnder(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder, player.Character :: Instance }
	local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position + Vector3.new(0, 0.15, 0) else position
end

local numbers = 0
local function damageNumber(position: Vector3, amount: number, crit: boolean, color: Color3?)
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
		Text = (if crit then "CRIT " else "") .. tostring(amount),
		TextSize = if crit then 32 else 24,
		TextColor3 = color or Color3.new(1, 1, 1),
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
function handlers.HitConfirm(crit)
	hitUntil, hitCritical = os.clock() + 0.18, crit == true
end
function handlers.IncomingDamage(origin)
	incomingOrigin, incomingUntil = origin, os.clock() + 0.65
	flashUntil = os.clock() + 0.3
end
function handlers.TechStatus(message)
	hint.Text, feedbackUntil = message, os.clock() + 1
end
function handlers.TechCooldown(id, duration)
	techCooldowns[id] = { Ready = os.clock() + duration, Total = duration }
	nextAttack = math.max(nextAttack, os.clock() + duration)
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
	if stats and stats.Windup then
		cast = {
			Name = stats.Name,
			Start = os.clock(),
			Duration = stats.Windup,
			Color = if gem then GemConfig.ElementColors[gem.Element] or P.Gold else Tech.Resources.Stamina.Color,
		}
	end
end
function handlers.TechPulse(_who, from, to, color, radius)
	local distance = (to - from).Magnitude
	if distance > 0.1 then
		local beam = effectPart(Vector3.new(0.16, 0.16, distance), CFrame.lookAt((from + to) / 2, to), color)
		fade(beam, 0.2)
	end
	if radius > 0 then
		for _, axis in { CFrame.new(), CFrame.Angles(math.pi / 2, 0, 0), CFrame.Angles(0, 0, math.pi / 2) } do
			local pulse = effectPart(
				Vector3.new(0.15, radius * 2, radius * 2),
				CFrame.new(to) * axis,
				color,
				Enum.PartType.Cylinder
			)
			pulse.Transparency = 0.88
			fade(pulse, 0.35, pulse.Size * 1.25)
		end
	end
end
function handlers.TechField(who, color)
	local root = who.Character and who.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
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
function handlers.HighBlock()
	hint.Text, feedbackUntil = "HIGH BLOCK - COUNTER!", os.clock() + 1
end
function handlers.Parried(seconds)
	cancel()
	cast = nil
	nextAttack = math.max(nextAttack, os.clock() + seconds)
	hint.Text, feedbackUntil = "PARRIED", os.clock() + 0.9
end
function handlers.AttackTiming(stage, side, combo)
	hint.Text = stage
	feedbackUntil = os.clock() + 0.9
	if combo > 1 then
		comboLabel.Text, comboUntil = "x" .. combo, os.clock() + 2
		comboScale.Scale = 1.4
		TweenService:Create(comboScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	local loadout = GemClient.Profile and GemClient.Profile.Character
	local weapon = loadout and Classes.weapon(loadout.Class, loadout.Weapon)
	if weapon and weapon.Attack.Kind == "Shot" then
		FirstPerson.fire()
	else
		FirstPerson.swing(side)
	end
end

function handlers.Damage(position: Vector3, amount: number, crit: boolean, color: Color3?)
	damageNumber(position, amount, crit, color)
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
	local blades = math.clamp(math.floor(arc / 25), 2, 7)
	local base = math.atan2(-direction.X, -direction.Z)
	for i = 0, blades - 1 do
		local t = if blades > 1 then i / (blades - 1) - 0.5 else 0
		local angle = base + math.rad(arc) * t
		local reach = range * 0.6
		local cf = CFrame.new(origin + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -reach)
		local blade = effectPart(Vector3.new(if big then 0.5 else 0.3, 0.12, range * 0.6), cf, color)
		blade.Transparency = 0.65
		fade(blade, 0.22)
	end
end

function handlers.Shot(_who: Player, from: Vector3, to: Vector3, color: Color3, look: string?)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local isArrow = look == "Longbow"
		or look == "Shortbow"
		or look == "Crossbow"
		or look == "Knives"
		or look == "PowerShot"
	local size = if isArrow then Vector3.new(0.15, 0.15, 2) else Vector3.one * 0.35
	local bolt =
		effectPart(size, CFrame.lookAt(from, to), color, if isArrow then Enum.PartType.Block else Enum.PartType.Ball)
	local travel = math.clamp(distance / 140, 0.05, 0.5)
	TweenService
		:Create(
			bolt,
			TweenInfo.new(travel, Enum.EasingStyle.Linear),
			{ CFrame = CFrame.lookAt(to, to + (to - from).Unit) }
		)
		:Play()
	task.delay(travel, function()
		fade(bolt, 0.15, bolt.Size * 1.8)
	end)
end

function handlers.Nova(center: Vector3, radius: number, color: Color3, delay: number)
	local floor = floorUnder(center)
	if delay and delay > 0 then
		-- Warning circle, then the blast.
		local warn = ring(floor, radius, Color3.fromRGB(255, 60, 40), 0.7)
		task.delay(delay, function()
			warn:Destroy()
			local blast = ring(floor, 1, color, 0.1)
			fade(blast, 0.45, Vector3.new(0.2, radius * 2, radius * 2))
			local pillar = effectPart(Vector3.new(2, 40, 2), CFrame.new(floor + Vector3.new(0, 20, 0)), color)
			fade(pillar, 0.4, Vector3.new(radius, 40, radius))
		end)
		return
	end
	local blast = ring(floor, 1, color, 0.2)
	fade(blast, 0.4, Vector3.new(0.2, radius * 2, radius * 2))
end

function handlers.Zone(center: Vector3, radius: number, duration: number, color: Color3)
	local floor = floorUnder(center)
	local disc = ring(floor, radius, color, 0.75)
	local edge = ring(floor + Vector3.new(0, 0.05, 0), radius, color, 0.4)
	edge.Size = Vector3.new(0.1, radius * 2, radius * 2)
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop and disc.Parent do
			-- Falling streaks: arrows raining, sparks, whatever the class throws.
			local offset = Vector3.new((math.random() - 0.5) * radius * 1.6, 0, (math.random() - 0.5) * radius * 1.6)
			local streak =
				effectPart(Vector3.new(0.15, 3, 0.15), CFrame.new(floor + offset + Vector3.new(0, 12, 0)), color)
			TweenService:Create(streak, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
				CFrame = CFrame.new(floor + offset + Vector3.new(0, 1.5, 0)),
			}):Play()
			Debris:AddItem(streak, 0.35)
			task.wait(0.08)
		end
		fade(disc, 0.3)
		fade(edge, 0.3)
	end)
end

function handlers.Buff(who: Player, color: Color3)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local halo = ring(root.Position - Vector3.new(0, 2.5, 0), 2, color, 0.2)
		fade(halo, 0.6, Vector3.new(0.2, 9, 9))
	end
end

function handlers.Arc(from: Vector3, to: Vector3, color: Color3)
	local distance = (to - from).Magnitude
	local bolt = effectPart(Vector3.new(0.2, 0.2, distance), CFrame.lookAt((from + to) / 2, to), color)
	fade(bolt, 0.2)
end

function handlers.Death(position: Vector3, color: Color3?)
	for _ = 1, 8 do
		local shard = effectPart(
			Vector3.new(0.5, 0.9, 0.5),
			CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			color or Color3.new(1, 1, 1)
		)
		local fling = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit * 6
		TweenService:Create(shard, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = shard.CFrame + fling,
			Transparency = 1,
		}):Play()
		Debris:AddItem(shard, 0.65)
	end
end

function handlers.EnemySwing(from: Vector3, to: Vector3, color: Color3)
	local mid = from:Lerp(to, 0.7)
	local slash =
		effectPart(Vector3.new(2.5, 0.15, 0.5), CFrame.lookAt(mid, to) * CFrame.Angles(0, 0, math.rad(35)), color)
	fade(slash, 0.25)
end

function handlers.Cooldown(id, seconds)
	cooldowns[id] = { Ready = os.clock() + seconds, Total = seconds }
	if id == "Basic" or id == "Heavy" then
		nextAttack = os.clock() + seconds
	end
end
function handlers.BlockBroken(seconds)
	blockHeld = false
	cooldowns.Block = { Ready = os.clock() + seconds, Total = seconds }
	UiKit.toast("Guard broken!", P.Gold)
end
function handlers.BlockSpark(position, broken)
	local spark = ring(position, if broken then 2 else 1, if broken then Color3.fromRGB(255, 160, 50) else P.Teal, 0.2)
	fade(spark, 0.2, Vector3.new(0.1, 6, 6))
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
	local color = if afterimage then Color3.fromRGB(80, 225, 255) else P.Gold
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
