--[[
	What the critters took (Server.Robbery): knocked out out in the quarry
	or in the Rift, you're robbed and sent back to base, and this card tells
	you what went missing. Each gem they grabbed, in 3D (GemArt), its name in
	its rarity's colour, and GONE, or SAVED if someone knocked its thief out
	before it got away. With nothing on you to take, it says so.

	  RobReport.start()               listen for the server's "Robbed" (once)
	  RobReport.show(report)          the card: { Where, Items, Empty }
	  RobReport.lines(report) -> (title, line, footer)   its words (pure)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local CombatSound = require(script.Parent.CombatSound)
local GemArt = require(script.Parent.GemArt)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local RobReport = {}

local P = IronUi.Colors
local new = IronUi.new
local BOLD, BODY = IronUi.Bold, IronUi.Body
local THIEF = Color3.fromRGB(255, 110, 92)

-- The card's words for `report` (a title, a line, a footer). Whole
-- sentences, a line each, so Shared.Lang finds every one.
function RobReport.lines(report): (string, string, string)
	local items = report.Items or {}
	local gone, back = 0, 0
	for _, item in items do
		if item.Back then
			back += 1
		else
			gone += 1
		end
	end
	local rift = report.Where == "Rift"
	if #items == 0 then
		return "NOTHING TAKEN",
			if rift
				then "You went down in the Rift. The critters went through your pouch and found nothing worth taking."
				else "You went down out in the quarry. The critters went through your pouch and found nothing worth taking.",
			"You're back at base, on your feet."
	end
	local title = if gone == 0 then "ROBBED, BUT YOU GOT IT BACK" else "ROBBED!"
	local count = string.format(if #items == 1 then "%d gem taken" else "%d gems taken", #items)
	if back > 0 then
		count ..= string.format(", %d knocked loose again", back)
	end
	local line = (
		if rift
			then "You went down in the Rift and the critters went through your pouch."
			else "You went down out in the quarry and the critters went through your pouch."
	)
		.. "\n"
		.. count
		.. "."
	local footer = if rift
		then "You're back at base, on your feet. Down in the Rift, they take what you found in there."
		else "You're back at base, on your feet. What you mine out there is safe once you're back in the core."
	return title, line, footer
end

local gui: ScreenGui? = nil
local card: Frame? = nil

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

local function close()
	if card and card.Parent then
		(card.Parent :: Instance):Destroy()
	end
	card = nil
end

-- One gem they grabbed: the stone, its name, GONE or SAVED.
local function gemTile(parent: Instance, item, order: number, small: boolean)
	local tier = GemConfig.TierColors[item.Tier] or P.Edge
	local tile = new("Frame", {
		Name = "Gem" .. order,
		LayoutOrder = order,
		BackgroundColor3 = P.Inset,
	}, parent)
	UiKit.round(tile, 10)
	new("UIStroke", { Color = tier, Thickness = 1.2, Transparency = if item.Back then 0.1 else 0.45 }, tile)
	local view = GemArt.viewport(tile, {
		Id = item.Id,
		Tier = item.Tier,
		Element = item.Element,
		Size = item.Size,
		Clarity = item.Clarity,
		Cut = item.Cut,
	})
	view.AnchorPoint = Vector2.new(0.5, 0)
	view.Position = UDim2.new(0.5, 0, 0, 6)
	view.Size = UDim2.fromOffset(if small then 52 else 64, if small then 52 else 64)
	if not item.Back then
		view.ImageTransparency = 0.35 -- (gone: it's only a memory now)
	end
	local name = text(tile, item.Name or "Gem", if small then 10 else 11, tier, BOLD)
	name.AutomaticSize = Enum.AutomaticSize.None
	name.TextXAlignment = Enum.TextXAlignment.Center
	-- (Two lines: "Uncommon Cryo Gem" won't fit on one.)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.LineHeight = 0.95
	name.Position = UDim2.new(0, 4, 0, if small then 60 else 74)
	name.Size = UDim2.new(1, -8, 0, if small then 22 else 26)
	local tag = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(64, 16),
		BackgroundColor3 = if item.Back then P.Good else THIEF,
		BackgroundTransparency = 0.15,
		Text = if item.Back then "SAVED" else "GONE",
		Font = BOLD,
		TextSize = 10,
		TextColor3 = P.Ink,
	}, tile)
	UiKit.round(tag, 8)
end

function RobReport.show(report)
	close()
	if type(report) ~= "table" then
		return
	end
	gui = gui or UiKit.gui("RobReport", 31)
	local screen = gui :: ScreenGui
	local small = screen.AbsoluteSize.X < 700 or screen.AbsoluteSize.Y < 480
	local holder = new("Frame", { Name = "Robbed", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, screen)
	local backdrop = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
	}, holder)
	local width = math.min(if small then 420 else 480, screen.AbsoluteSize.X - 32)
	local panel = new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = P.Frame,
	}, holder)
	card = panel
	UiKit.round(panel, 12)
	new("UIStroke", { Color = THIEF, Thickness = 1.5, Transparency = 0.1 }, panel)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(THIEF:Lerp(P.Frame, 0.8), P.Frame) }, panel)
	UiKit.pad(panel, if small then 10 else 16)
	UiKit.list(panel, if small then 6 else 9)
	local title, line, footer = RobReport.lines(report)
	local heading = text(panel, title, if small then 20 else 26, if report.Empty then P.Gold else THIEF, IronUi.Heading)
	heading.LayoutOrder = 1
	local body = text(panel, line, if small then 12 else 13, P.Text)
	body.LayoutOrder = 2
	local items = report.Items or {}
	if #items > 0 then
		local tile = if small then 84 else 100
		local tall = tile + (if small then 26 else 30)
		-- (Its height worked out here: tiles in rows across the card.)
		local across = math.max(1, math.floor((width - 2 * (if small then 10 else 16) + 8) / (tile + 8)))
		local rows = math.ceil(#items / across)
		local row = new("Frame", {
			Name = "Gems",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, rows * tall + (rows - 1) * 8),
			LayoutOrder = 3,
		}, panel)
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(tile, tall),
			CellPadding = UDim2.fromOffset(8, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)
		for i, item in items do
			gemTile(row, item, i, small)
		end
	end
	local foot = text(panel, footer, 11, P.Dim)
	foot.LayoutOrder = 4
	local ok, face = IronUi.chunk(
		panel,
		{ Color = P.Gold, Size = UDim2.new(1, 0, 0, if small then 38 else 44), Radius = 8, Stripes = "None" }
	)
	ok.LayoutOrder = 5
	IronUi.label(ok, face, "BACK TO IT", 15, BOLD)
	ok.Activated:Connect(close)
	backdrop.Activated:Connect(close)
	-- In with a little jolt.
	local scale = new("UIScale", { Scale = 0.85 }, panel)
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	pcall(CombatSound.play, "KnockDown")
end

local started = false
function RobReport.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx")
		fx.OnClientEvent:Connect(function(kind, report)
			if kind == "Robbed" then
				-- (A beat after landing back at base, so the arrival reads first.)
				task.delay(0.6, RobReport.show, report)
			end
		end)
	end)
	Players.LocalPlayer.CharacterAdded:Connect(close)
end

return RobReport
