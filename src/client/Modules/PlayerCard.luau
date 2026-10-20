-- Another miner near you: one small card beside them with DUEL, SPAR,
-- PARTY and KAIJU (a kaiju battle), in place of Roblox's prompt panels
-- stacked up over their head (hard to read, and on a phone they covered the
-- middle of the screen).
--
-- The server still puts a prompt for each on the miner (OutpostServer,
-- socialPrompts), drawn by nothing (Custom style): they decide who's in
-- range and take the keys (G, Z, F, V). OutpostScene passes on when they show
-- and hide; the card is what you see, click or tap.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local PlayerCard = {}

local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

-- In the card's order, left to right.
-- (Key and Pad: the prompts' keyboard key and gamepad button, OutpostServer.)
PlayerCard.Actions = {
	{ Kind = "Duel", Label = "DUEL", Icon = "⚔", Key = "G", Pad = "X", Color = P.Gold },
	{ Kind = "Spar", Label = "SPAR", Icon = "✦", Key = "Z", Pad = "Y", Color = P.Teal },
	{ Kind = "Party", Label = "PARTY", Icon = "+", Key = "F", Pad = "B", Color = P.Good },
	{ Kind = "Kaiju", Label = "KAIJU", Icon = "◆", Key = "V", Pad = "LB", Color = Color3.fromRGB(255, 132, 64) },
}

type Card = {
	Gui: BillboardGui,
	Shown: { [ProximityPrompt]: boolean },
	Fills: { [string]: Frame },
}
local cards: { [number]: Card } = {}
local blocked = false
local onAction: ((kind: string, target: number) -> ())? = nil

-- What happens on a click or tap (OutpostScene: the same as the key).
function PlayerCard.onAction(fn: (kind: string, target: number) -> ())
	onAction = fn
end

-- One line at a fixed size (IronUi.text wraps and grows by default).
local function line(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font): TextLabel
	local label = IronUi.text(parent, value, size, color, font)
	label.AutomaticSize, label.TextWrapped = Enum.AutomaticSize.None, false
	return label
end

local function build(root: BasePart, target: number, inputType: Enum.ProximityPromptInputType?): Card
	-- Bigger buttons for a thumb, and no keys on them.
	local touch = inputType == Enum.ProximityPromptInputType.Touch
		or (inputType == nil and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
	local pad = inputType == Enum.ProximityPromptInputType.Gamepad
	local buttonW, buttonH = if touch then 92 else 100, if touch then 44 else 34
	local gap, edge, nameH = 6, 8, 16
	local count = #PlayerCard.Actions
	local width = buttonW * count + gap * (count - 1) + edge * 2
	local height = edge + nameH + 4 + buttonH + edge
	local gui = new("BillboardGui", {
		Name = "PlayerCard",
		Adornee = root,
		AlwaysOnTop = true,
		Active = true,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Size = UDim2.fromOffset(width, height),
		-- Beside them at chest height: clear of the name and title over their
		-- head, and of their body.
		SizeOffset = Vector2.new(0.66, 0.15),
		StudsOffsetWorldSpace = Vector3.new(0, 0.4, 0),
		Enabled = not blocked,
	}, player:WaitForChild("PlayerGui"))
	local panel = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 14, 24),
		BackgroundTransparency = 0.12,
	}, gui)
	UiKit.round(panel, 10)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.82, Thickness = 1 }, panel)

	local other = Players:GetPlayerByUserId(target)
	local name = line(panel, if other then other.DisplayName else "Miner", 13, P.Text, IronUi.Bold)
	name.Position, name.Size = UDim2.fromOffset(edge + 2, edge - 1), UDim2.fromOffset(width - edge * 2 - 4, nameH)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name:SetAttribute("NoTranslate", true)

	local fills = {}
	for i, action in PlayerCard.Actions do
		local button = new("TextButton", {
			Name = action.Kind,
			Text = "",
			AutoButtonColor = false,
			Position = UDim2.fromOffset(edge + (i - 1) * (buttonW + gap), edge + nameH + 4),
			Size = UDim2.fromOffset(buttonW, buttonH),
			BackgroundColor3 = action.Color:Lerp(Color3.fromRGB(14, 18, 28), 0.74),
			ClipsDescendants = true,
		}, panel)
		UiKit.round(button, 8)
		local outline = new("UIStroke", { Color = action.Color, Transparency = 0.45, Thickness = 1 }, button)
		button:SetAttribute("UiSound", "Click")
		-- Filled left to right while a key is held (the prompts' hold time).
		local fill = new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = action.Color,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
		}, button)
		fills[action.Kind] = fill
		-- The icon and the word apart, so the word is translated (Translate).
		local keyW = if touch then 0 else 18
		local icon = line(button, action.Icon, 13, action.Color, IronUi.Heading)
		icon.Position, icon.Size = UDim2.fromOffset(if touch then 10 else 7, 0), UDim2.new(0, 14, 1, 0)
		icon.TextXAlignment, icon.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
		icon:SetAttribute("NoTranslate", true)
		local label = line(button, action.Label, 13, action.Color, IronUi.Heading)
		label.Position = UDim2.fromOffset(if touch then 26 else 24, 0)
		label.Size = UDim2.new(1, (if touch then -36 else -30) - keyW, 1, 0)
		label.TextXAlignment = if touch then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		UiKit.fit(label)
		if not touch then
			local cap = line(button, if pad then action.Pad else action.Key, 10, P.Text, IronUi.Bold)
			cap.AnchorPoint = Vector2.new(1, 0.5)
			cap.Position, cap.Size = UDim2.new(1, -6, 0.5, 0), UDim2.fromOffset(16, 16)
			cap.TextXAlignment = Enum.TextXAlignment.Center
			cap.BackgroundColor3, cap.BackgroundTransparency = Color3.fromRGB(30, 36, 52), 0
			cap:SetAttribute("NoTranslate", true)
			UiKit.round(cap, 4)
		end
		button.MouseEnter:Connect(function()
			outline.Transparency = 0.1
		end)
		button.MouseLeave:Connect(function()
			outline.Transparency = 0.45
		end)
		button.Activated:Connect(function()
			if onAction then
				onAction(action.Kind, target)
			end
		end)
	end
	return { Gui = gui, Shown = {}, Fills = fills }
end

-- A miner's prompt came into range (ProximityPromptService.PromptShown).
function PlayerCard.shown(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType?)
	local target = prompt:GetAttribute("TargetUserId")
	local root = prompt.Parent
	if type(target) ~= "number" or target == player.UserId or not root or not root:IsA("BasePart") then
		return
	end
	local card = cards[target]
	if card and card.Gui.Adornee ~= root then
		-- (They respawned: a new body.)
		card.Gui:Destroy()
		card = nil
	end
	if not card then
		card = build(root, target, inputType)
		cards[target] = card
	end
	card.Shown[prompt] = true
end

-- ...and went out of range, or away (PromptHidden).
function PlayerCard.hidden(prompt: ProximityPrompt)
	for target, card in cards do
		if card.Shown[prompt] then
			card.Shown[prompt] = nil
			if next(card.Shown) == nil then
				card.Gui:Destroy()
				cards[target] = nil
			end
		end
	end
end

-- A key held on one of a miner's prompts (PromptButtonHoldBegan / Ended).
function PlayerCard.holding(prompt: ProximityPrompt, held: boolean)
	local card = cards[prompt:GetAttribute("TargetUserId") :: any]
	local fill = card and card.Fills[prompt:GetAttribute("PromptKind") :: any]
	if not fill then
		return
	end
	fill.Size = UDim2.fromScale(0, 1)
	if held then
		TweenService:Create(fill, TweenInfo.new(math.max(prompt.HoldDuration, 0.05), Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(1, 1),
		}):Play()
	end
end

-- A menu, a fight or the HUD going away hides every card.
function PlayerCard.setBlocked(on: boolean)
	blocked = on
	for _, card in cards do
		card.Gui.Enabled = not on
	end
end

function PlayerCard.count(): number
	local n = 0
	for _ in cards do
		n += 1
	end
	return n
end

return PlayerCard
