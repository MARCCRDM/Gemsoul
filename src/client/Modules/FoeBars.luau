--[[
	Who you're fighting, kept light (mobile first):

	  Overhead bars   a slim health bar over each foe's head (no stamina or
	                  charge); your locked target's is wider, with a gold edge.
	                  The status icons (StatusBars) sit just above it.
	  Target list     with two or more foes around, a compact list in the top
	                  left (under the "?" and Augment Tree buttons): icon,
	                  name, health. Tap one to lock it.

	Foes come from TargetLock.foes() (empty outside fights), so nothing shows
	in the Outpost or the lobby. Runs on its own once required.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local TargetLock = require(script.Parent.TargetLock)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local FoeBars = {}

FoeBars.MaxRows = 5
local HEALTH = Color3.fromRGB(226, 66, 78)
local TRAIL = Color3.fromRGB(255, 196, 110)
local LOCK = Color3.fromRGB(255, 202, 91)
local INK = Color3.fromRGB(10, 9, 20)
local EDGE = Color3.fromRGB(64, 55, 92)

local function make(class: string, props, parent: Instance?)
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end
local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function nameOf(model: Model): string
	local other = Players:GetPlayerFromCharacter(model)
	if other then
		return other.DisplayName
	end
	return model:GetAttribute("RivalName") or model:GetAttribute("CombatTitle") or model.Name
end
local function tintOf(model: Model): Color3
	local element = model:GetAttribute("RivalElement")
	return element and GemConfig.ElementColors[element] or HEALTH
end
local function healthOf(model: Model): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.MaxHealth <= 0 then
		return 0
	end
	return math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
end
local function dropping(model: Model): boolean
	return (model:GetAttribute("ArenaDropUntil") or 0) > workspace:GetServerTimeNow()
end

-- Overhead bars -----------------------------------------------------------------------------------------

type Bar = {
	Board: BillboardGui,
	Back: Frame,
	Fill: Frame,
	Trail: Frame,
	Stroke: UIStroke,
	Shown: number,
	Trailing: number,
	Label: TextLabel,
	Hidden: { BillboardGui },
}
local bars: { [Model]: Bar } = {}

local function barFor(model: Model): Bar?
	local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local bar = bars[model]
	if bar then
		for _, legacy in bar.Hidden do
			if legacy.Parent then
				legacy.Enabled = false
			end
		end
	end
	if bar and bar.Board.Adornee == head and bar.Board.Parent then
		return bar
	end
	if bar then
		bar.Board:Destroy()
	end
	local board = make("BillboardGui", {
		Name = "FoeHealth",
		Adornee = head,
		Size = UDim2.fromOffset(220, 48),
		StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 1.8, 0),
		MaxDistance = 90,
		AlwaysOnTop = true,
		ResetOnSpawn = false,
	}, player:FindFirstChildOfClass("PlayerGui"))
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Text = nameOf(model),
		TextColor3 = Color3.fromRGB(240, 244, 250),
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeTransparency = 0.35,
	}, board)
	local back = make(
		"Frame",
		{
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.15,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 34),
			Size = UDim2.fromOffset(104, 10),
		},
		board
	)
	local hidden = {}
	for _, child in model:GetDescendants() do
		if child:IsA("BillboardGui") and child.Name == "HealthBar" and child.Enabled then
			child.Enabled = false
			table.insert(hidden, child)
		end
	end
	corner(back, 3)
	local stroke = make("UIStroke", { Color = EDGE, Thickness = 1 }, back)
	local inner = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ClipsDescendants = true,
	}, back)
	local trail = make("Frame", { BackgroundColor3 = TRAIL, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, inner)
	corner(trail, 2)
	local fill = make("Frame", { BackgroundColor3 = HEALTH, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, inner)
	corner(fill, 2)
	-- The default Roblox bar would double up with ours.
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	bar = {
		Label = label,
		Hidden = hidden,
		Board = board,
		Back = back,
		Fill = fill,
		Trail = trail,
		Stroke = stroke,
		Shown = 1,
		Trailing = 1,
	}
	bars[model] = bar
	return bar
end

-- Target list --------------------------------------------------------------------------------------------

local gui = UiKit.gui("FoeList", 7)
gui.Enabled = true
local list = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 62),
	Size = UDim2.fromOffset(180, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
}, gui)
local layout = make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
local _ = layout

type Row = {
	Button: TextButton,
	Stroke: UIStroke,
	Icon: TextLabel,
	Name: TextLabel,
	Fill: Frame,
	Percent: TextLabel,
	Model: Model?,
}
local rows: { Row } = {}
for i = 1, FoeBars.MaxRows do
	local button = make("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.18,
		Size = UDim2.fromOffset(180, 34),
		LayoutOrder = i,
		Visible = false,
	}, list)
	corner(button, 6)
	button:SetAttribute("UiSound", "Tab")
	local stroke =
		make("UIStroke", { Color = EDGE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	local icon = make("TextLabel", {
		BackgroundColor3 = HEALTH,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(24, 24),
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
	}, button)
	corner(icon, 12)
	local name = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(35, 3),
		Size = UDim2.fromOffset(104, 15),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(235, 242, 249),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
	}, button)
	local percent = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(139, 3),
		Size = UDim2.fromOffset(36, 15),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(170, 176, 200),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, button)
	local track = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 33, 61),
		BorderSizePixel = 0,
		Visible = false, -- health is shown only above the fighter
		Position = UDim2.fromOffset(35, 21),
		Size = UDim2.fromOffset(140, 6),
	}, button)
	corner(track, 3)
	local fill = make("Frame", { BackgroundColor3 = HEALTH, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, track)
	corner(fill, 3)
	local row: Row = { Button = button, Stroke = stroke, Icon = icon, Name = name, Fill = fill, Percent = percent }
	button.Activated:Connect(function()
		if row.Model then
			TargetLock.select(row.Model)
		end
	end)
	rows[i] = row
end

-- Phones: a little smaller, still clear of Roblox's own buttons.
local function fit()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	-- Under the fight's corner buttons (the guide "?" and the Augment Tree).
	list.Position = UDim2.fromOffset(if touch then 10 else 12, 62)
	local scale = list:FindFirstChildOfClass("UIScale") or make("UIScale", {}, list)
	scale.Scale = if touch then 0.9 else 1
end
fit()

-- Updating -------------------------------------------------------------------------------------------------

local foes: { Model } = {}
local nextScan = 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	if now >= nextScan then
		nextScan = now + 0.1
		foes = TargetLock.foes()
		-- Bars for foes only; the rest come down.
		local keep = {}
		for _, model in foes do
			if not dropping(model) and barFor(model) then
				keep[model] = true
			end
		end
		for model, bar in bars do
			if not keep[model] then
				for _, legacy in bar.Hidden do
					if legacy.Parent then
						legacy.Enabled = not dropping(model)
					end
				end
				bar.Board:Destroy()
				bars[model] = nil
			end
		end
	end
	local target = TargetLock.target()
	-- Overhead bars: smooth fill, a trail that catches up, the target wider.
	for model, bar in bars do
		local share = healthOf(model)
		bar.Shown = share
		bar.Trailing = if share >= bar.Trailing
			then share
			else bar.Trailing + (share - bar.Trailing) * (1 - math.exp(-dt * 3))
		bar.Fill.Size = UDim2.fromScale(share, 1)
		bar.Trail.Size = UDim2.fromScale(bar.Trailing, 1)
		local locked = model == target
		bar.Back.Size = if locked then UDim2.fromOffset(120, 11) else UDim2.fromOffset(100, 9)
		bar.Label.Text = nameOf(model)
		local head = bar.Board.Adornee
		if head then
			bar.Board.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 1.8, 0)
		end
		bar.Stroke.Color = if locked then LOCK else EDGE
		bar.Stroke.Thickness = if locked then 1.5 else 1
		bar.Fill.BackgroundColor3 = if share <= 0.3 then Color3.fromRGB(255, 96, 96) else HEALTH
	end
	-- The list: only with two or more foes.
	list.Visible = #foes >= 2
	for i, row in rows do
		local model = if list.Visible then foes[i] else nil
		row.Model = model
		row.Button.Visible = model ~= nil
		if model then
			local share = healthOf(model)
			local name = nameOf(model)
			local locked = model == target
			row.Name.Text = (if locked then "◎ " else "") .. name
			row.Name.TextColor3 = if locked then LOCK else Color3.fromRGB(235, 242, 249)
			row.Icon.Text = string.upper(string.sub(name, 1, 1))
			row.Icon.BackgroundColor3 = tintOf(model)
			row.Fill.Size = UDim2.fromScale(share, 1)
			row.Fill.BackgroundColor3 = if share <= 0.3 then Color3.fromRGB(255, 96, 96) else HEALTH
			row.Percent.Text = string.format("%d%%", math.ceil(share * 100))
			row.Stroke.Color = if locked then LOCK else EDGE
			row.Stroke.Thickness = if locked then 1.5 else 1
		end
	end
end)

return FoeBars
