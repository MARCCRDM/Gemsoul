--[[
	The frontier on screen: a banner as you cross from one band of the
	Outpost into another (the server's FrontierBand on your Player: Core,
	Fringe, Edge; Shared.Frontier), in the band's colour, so you know where
	the rifts start and how rich the rocks run. The same band's banner
	doesn't come back for a while (crossing to and fro at a boundary).

	  FrontierHud.start()
	  FrontierHud.Lines[band] -> title, subtitle   (pure, for tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Frontier = require(ReplicatedStorage.Shared.Frontier)

local FrontierHud = {}

FrontierHud.Lines = {
	Core = { "OUTPOST CORE", "Safe from the rifts" },
	Fringe = { "THE FRINGE", "Rifts tear open out here  ·  the rocks run richer" },
	Edge = { "THE EDGE", "The richest veins  ·  the most rifts" },
}
FrontierHud.Again = 20 -- seconds before the same band's banner shows again
FrontierHud.Hold = 2.6

local shown: { [string]: number } = {}

function FrontierHud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "FrontierBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.17)
	frame.Size = UDim2.fromOffset(460, 58)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local function label(y: number, height: number, size: number, font: Enum.Font): TextLabel
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(0, y)
		text.Size = UDim2.new(1, 0, 0, height)
		text.Font = font
		text.TextSize = size
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeColor3 = Color3.new(0, 0, 0)
		text.TextStrokeTransparency = 0.35
		text.TextTransparency = 1
		text.TextStrokeTransparency = 1
		text.Parent = frame
		return text
	end
	local title = label(0, 32, 28, Enum.Font.GothamBlack)
	local subtitle = label(34, 20, 14, Enum.Font.GothamBold)
	local rule = Instance.new("Frame")
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.new(0.5, 0, 0, 32)
	rule.Size = UDim2.fromOffset(0, 2)
	rule.BorderSizePixel = 0
	rule.BackgroundTransparency = 1
	rule.Parent = frame
	local token = 0
	local function fade(to: number, seconds: number)
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad)
		for _, text in { title, subtitle } do
			TweenService:Create(text, info, { TextTransparency = to, TextStrokeTransparency = 0.35 + 0.65 * to }):Play()
		end
		TweenService:Create(rule, info, { BackgroundTransparency = to }):Play()
	end
	local function show(band: string)
		local lines = FrontierHud.Lines[band]
		local now = os.clock()
		if not lines or (shown[band] and now - shown[band] < FrontierHud.Again) then
			return
		end
		shown[band] = now
		token += 1
		local mine = token
		local color = Frontier.Bands[band].Color
		title.Text, subtitle.Text = lines[1], lines[2]
		title.TextColor3 = color
		rule.BackgroundColor3 = color
		rule.Size = UDim2.fromOffset(0, 2)
		gui.Enabled = true
		fade(0, 0.35)
		TweenService:Create(rule, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(220, 2) }):Play()
		task.delay(FrontierHud.Hold, function()
			if mine == token then
				fade(1, 0.6)
				task.delay(0.65, function()
					if mine == token then
						gui.Enabled = false
					end
				end)
			end
		end)
	end
	local last = player:GetAttribute("FrontierBand")
	player:GetAttributeChangedSignal("FrontierBand"):Connect(function()
		local band = player:GetAttribute("FrontierBand")
		-- (Arriving in the Outpost isn't crossing into the core.)
		if type(band) == "string" and last ~= nil then
			show(band)
		end
		last = band
	end)
end

return FrontierHud
