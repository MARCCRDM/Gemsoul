--[[
	The hand-cutting minigame. A marker sweeps back and forth across a bar;
	strike (Space, gamepad A, or the STRIKE button) while it's inside the
	glowing zone. Three strikes; the closer to each zone's centre line, the
	better the cut. Bigger stones have smaller zones and faster markers.

	CuttingGame.play(gem, session) yields until the player finishes (or
	cancels) and returns the strike times, measured from when the bar started.
]]
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local UiKit = require(script.Parent.UiKit)

local K = UiKit.Colors

local CuttingGame = {}

local function verdict(accuracy: number): (string, Color3)
	if accuracy >= GemConfig.Cutting.PerfectAccuracy then
		return "PERFECT", Color3.fromRGB(120, 255, 160)
	elseif accuracy >= 0.75 then
		return "GREAT", K.Accent
	elseif accuracy > 0 then
		return "OK", K.Gold
	end
	return "MISS", K.Bad
end

function CuttingGame.play(gem, session): { number }?
	local shade = GemConfig.shade(gem)
	local gui = UiKit.gui("CuttingGame", 10)

	local panel = UiKit.panel(gui, shade.Color)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.45)
	panel.Size = UDim2.fromScale(0.92, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	UiKit.pad(panel, 16)
	UiKit.list(panel, 10)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, math.huge)
	limit.Parent = panel

	local titleLabel = UiKit.text(panel, "CUTTING: " .. string.upper(shade.Stone), 20, shade.Color, Enum.Font.Arcade)
	titleLabel.LayoutOrder = 1
	local help = UiKit.text(panel, "Strike when the marker crosses the centre line. [SPACE] or STRIKE.", 16, K.Dim)
	help.LayoutOrder = 2

	local bar = Instance.new("Frame")
	bar.LayoutOrder = 3
	bar.Size = UDim2.new(1, 0, 0, 36)
	bar.BackgroundColor3 = K.Row
	bar.ClipsDescendants = true
	bar.Parent = panel
	UiKit.round(bar, 6)

	local zone = Instance.new("Frame")
	zone.AnchorPoint = Vector2.new(0.5, 0)
	zone.Size = UDim2.fromScale(session.Zone, 1)
	zone.BackgroundColor3 = shade.Color
	zone.BackgroundTransparency = 0.45
	zone.Parent = bar
	local centreLine = Instance.new("Frame")
	centreLine.AnchorPoint = Vector2.new(0.5, 0)
	centreLine.Position = UDim2.fromScale(0.5, 0)
	centreLine.Size = UDim2.new(0, 2, 1, 0)
	centreLine.BackgroundColor3 = Color3.new(1, 1, 1)
	centreLine.Parent = zone

	local marker = Instance.new("Frame")
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.Size = UDim2.new(0, 4, 1, 0)
	marker.BackgroundColor3 = Color3.new(1, 1, 1)
	marker.ZIndex = 3
	marker.Parent = bar

	local results = UiKit.text(panel, "", 18, K.Text)
	results.LayoutOrder = 4

	local strikes = {}
	local finished = false
	local startTime = os.clock()

	local function showZone()
		local center = session.Centers[#strikes + 1]
		if center then
			zone.Position = UDim2.fromScale(center, 0)
		end
	end
	showZone()

	local function strike()
		if finished then
			return
		end
		table.insert(strikes, os.clock() - startTime)
		local accuracies = GemConfig.strikeAccuracy(strikes, session.Centers, session.Zone, session.Sweep)
		local parts = {}
		for i, accuracy in accuracies do
			if strikes[i] then
				local word = verdict(accuracy)
				table.insert(parts, word)
			end
		end
		local _, color = verdict(accuracies[#strikes])
		results.TextColor3 = color
		results.Text = table.concat(parts, "  ")
		if #strikes >= #session.Centers then
			finished = true
		else
			showZone()
		end
	end

	local buttons = Instance.new("Frame")
	buttons.LayoutOrder = 5
	buttons.BackgroundTransparency = 1
	buttons.Size = UDim2.new(1, 0, 0, 0)
	buttons.AutomaticSize = Enum.AutomaticSize.Y
	buttons.Parent = panel
	UiKit.list(buttons, 10, true)
	UiKit.button(buttons, "STRIKE", shade.Color, strike).TextSize = 22
	local cancelled = false
	UiKit.button(buttons, "Cancel", K.Dim, function()
		cancelled = true
		finished = true
	end)

	ContextActionService:BindAction("GemsoulStrike", function(_, state)
		if state == Enum.UserInputState.Begin then
			strike()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

	local timeout = GemConfig.Cutting.SessionTimeout - 5
	while not finished do
		local t = os.clock() - startTime
		marker.Position = UDim2.fromScale(GemConfig.markerPosition(t, session.Sweep), 0)
		if t > timeout then
			finished = true
		end
		RunService.RenderStepped:Wait()
	end

	ContextActionService:UnbindAction("GemsoulStrike")
	if not cancelled then
		task.wait(0.8)
	end
	gui:Destroy()
	if cancelled then
		return nil
	end
	return strikes
end

return CuttingGame
