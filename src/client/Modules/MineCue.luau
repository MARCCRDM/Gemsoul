--[[
	Pointing a miner at the rocks (Client OutpostScene drives it, Shared
	Outpost.MineCue): the rocks around you glow with a soft outline so you
	see where to go, the one in reach glows amber, pulsing, with its label
	over it saying how ("Click to mine", "Tap to mine", "X to mine"; a
	healing crystal "... to heal"). A click or tap on the label swings. On
	foot and in a mech alike: a mech reaches further and its label is a
	size up (its camera sits further back).

	  MineCue.near(rocks, at, flat, range, max) -> { Model }   nearest first
	  MineCue.words(inputType, heal) -> string
	  MineCue.show(target, near, opts)   opts: { Label: boolean, Mech: boolean, Input: Enum.UserInputType? }
	  MineCue.hide()
	  MineCue.onSwing(fn)   a click or tap on the label: fn(nodeId)
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local new = IronUi.new

local MineCue = {}

-- (cyan: a rock to go to; amber: the one you'd hit; green: a healing crystal)
MineCue.Glow = Color3.fromRGB(118, 211, 230)
MineCue.Target = Color3.fromRGB(255, 206, 84)
MineCue.Heal = Color3.fromRGB(70, 240, 95)

-- The rocks within `range` of `at` (flat: across the ground only, as a
-- mech's cockpit sits high), the nearest `max`, nearest first. Popped ones
-- are gone already.
function MineCue.near(rocks: { Model }, at: Vector3, flat: boolean, range: number, max: number): { Model }
	local found = {}
	for _, model in rocks do
		local body = model.PrimaryPart
		if body and model:GetAttribute("Popped") == nil then
			local apart = body.Position - at
			local d = if flat then Vector3.new(apart.X, 0, apart.Z).Magnitude else apart.Magnitude
			if d <= range then
				table.insert(found, { Model = model, Apart = d })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.Apart < b.Apart
	end)
	local out = {}
	for i = 1, math.min(max, #found) do
		out[i] = found[i].Model
	end
	return out
end

-- How to swing, for the way you play.
function MineCue.words(input: Enum.UserInputType?, heal: boolean?): string
	local verb = if heal then "heal" else "mine"
	if input == Enum.UserInputType.Touch then
		return "Tap to " .. verb
	elseif input and string.find(input.Name, "Gamepad", 1, true) then
		return "X to " .. verb
	end
	return "Click to " .. verb
end

local outlines: { [Model]: Highlight } = {}
local pulse: Tween? = nil
local pulsing: Highlight? = nil
local label: BillboardGui? = nil
local button: TextButton? = nil
local labelled: Model? = nil
local swing: ((number?) -> ())? = nil

function MineCue.onSwing(fn: (number?) -> ())
	swing = fn
end

local function colourOf(rock: Model, target: boolean): Color3
	if rock:GetAttribute("HealRock") then
		return MineCue.Heal
	end
	return if target then MineCue.Target else MineCue.Glow
end

-- A rock's outline: soft for one to go to, bright and filled for the target.
local function outline(rock: Model, target: boolean)
	local glow = outlines[rock]
	if not glow or glow.Parent ~= rock then
		glow = new("Highlight", {
			Name = "MineCue",
			Adornee = rock,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		}, rock)
		outlines[rock] = glow
	end
	local colour = colourOf(rock, target)
	glow.OutlineColor = colour
	glow.FillColor = colour
	glow.OutlineTransparency = if target then 0 else 0.35
	if target then
		if pulsing ~= glow then
			if pulse then
				pulse:Cancel()
			end
			glow.FillTransparency = 0.88
			pulsing = glow
			pulse = TweenService:Create(
				glow,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ FillTransparency = 0.62 }
			)
			pulse:Play()
		end
	else
		if pulsing == glow then
			if pulse then
				pulse:Cancel()
			end
			pulse, pulsing = nil, nil
		end
		glow.FillTransparency = 1
	end
end

local function unlabel()
	if label then
		label.Enabled = false
	end
	labelled = nil
end

-- The label over the target: how to swing, a click or tap on it swings.
local function labelOn(rock: Model, opts)
	local body = rock.PrimaryPart
	if not body then
		return unlabel()
	end
	local player = Players.LocalPlayer
	if not label or not label.Parent then
		label = new("BillboardGui", {
			Name = "MineCue",
			AlwaysOnTop = true,
			Active = true,
			ResetOnSpawn = false,
			LightInfluence = 0,
			Size = UDim2.fromOffset(150, 36),
		}, player:WaitForChild("PlayerGui"))
		local b = new("TextButton", {
			Name = "Swing",
			Text = "",
			Font = IronUi.Bold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(230, 248, 255),
			AutoButtonColor = false,
			Active = true,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(9, 25, 34),
			BackgroundTransparency = 0.1,
		}, label)
		UiKit.round(b, 9)
		new("UIStroke", {
			Name = "Edge",
			Color = MineCue.Target,
			Thickness = 1.5,
			Transparency = 0.15,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, b)
		b.Activated:Connect(function()
			local rockNow = labelled
			if swing and rockNow then
				swing(rockNow:GetAttribute("NodeId"))
			end
		end)
		button = b
	end
	local gui = label :: BillboardGui
	local b = button :: TextButton
	local heal = rock:GetAttribute("HealRock") == true
	b.Text = MineCue.words(opts.Input, heal)
	b.TextSize = if opts.Mech then 18 else 15
	local edge = b:FindFirstChild("Edge") :: UIStroke?
	if edge then
		edge.Color = if heal then MineCue.Heal else MineCue.Target
	end
	gui.Size = if opts.Mech then UDim2.fromOffset(180, 44) else UDim2.fromOffset(150, 36)
	-- (over the rock's top, whatever its size)
	gui.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 1.4, 0)
	gui.Adornee = body
	gui.Enabled = true
	labelled = rock
end

-- This tick's cue: `near` glowing soft, `target` (the one in reach, if
-- any) bright, with its label when `opts.Label`.
function MineCue.show(target: Model?, near: { Model }, opts)
	local keep = {}
	for _, rock in near do
		keep[rock] = true
	end
	if target then
		keep[target] = true
	end
	for rock, glow in outlines do
		if not keep[rock] or rock.Parent == nil then
			if pulsing == glow then
				if pulse then
					pulse:Cancel()
				end
				pulse, pulsing = nil, nil
			end
			glow:Destroy()
			outlines[rock] = nil
		end
	end
	for rock in keep do
		outline(rock, rock == target)
	end
	if target and opts.Label then
		labelOn(target, opts)
	else
		unlabel()
	end
end

function MineCue.hide()
	MineCue.show(nil, {}, {})
end

return MineCue
