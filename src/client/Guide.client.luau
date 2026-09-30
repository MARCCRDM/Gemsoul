--[[
	The guide: after the intro, a small "NEXT STEP" panel walks new players
	through the game loop, with a glowing trail from them to the place to go:
	  1 mine a crystal in the quarry
	  2 cut a rough stone at Ilsa's Gem Cutter stall
	  3 sell stones to Hilde at the Crafting Hall
	  4 forge or upgrade gear at Borin's anvil
	  5 enchant gear at Vey's Arcanum
	  6 defeat a crystal monster in the Wilds, outside the south gate
	Each step completes from the server's saved milestones. [H] hides it.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GemClient = require(script.Parent.Modules.GemClient)
local UiKit = require(script.Parent.Modules.UiKit)

-- The walking guide points at places in the town; it's off while the game
-- is played from the menu (Shared/Config).
if require(game:GetService("ReplicatedStorage").Shared.Config).MenuOnly then
	return
end

local player = Players.LocalPlayer
local K = UiKit.Colors
local ARRIVED = 18 -- studs: close enough, hide the trail

local STEPS = {
	{ Milestone = "Mined", Target = "Quarry", Text = "Mine a crystal in the quarry at the end of the north road." },
	{
		Milestone = "Cut",
		Target = "Cutting",
		Text = "Cut a rough stone at Ilsa's Gem Cutter stall, beside the Mining Guild.",
	},
	{
		Milestone = "Sold",
		Target = "Quartermaster",
		Text = "Sell stones you don't need to Hilde at the Crafting Hall for Guild Marks.",
	},
	{
		Milestone = "Crafted",
		Target = "Forge",
		Text = "Buy materials from Hilde, then forge or upgrade gear at Borin's anvil.",
	},
	{
		Milestone = "Enchanted",
		Target = "Enchanting",
		Text = "Socket a cut gem into your gear at Vey's Arcanum, east road.",
	},
	{
		Milestone = "Slain",
		Target = "Wilds",
		Text = "Practise on the Arena dummies, then defeat a crystal monster outside the south gate.",
	},
}

local hidden = false

-- Panel ------------------------------------------------------------------------------------

local gui = UiKit.gui("Guide", 2)
gui.Enabled = false
local panel = UiKit.panel(gui, K.Gold)
panel.Position = UDim2.new(0, 16, 0, 70)
panel.Size = UDim2.fromOffset(300, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
UiKit.pad(panel, 10)
UiKit.list(panel, 4)
local heading = UiKit.text(panel, "", 14, K.Gold, Enum.Font.Arcade)
heading.LayoutOrder = 1
local body = UiKit.text(panel, "", 14, K.Text, Enum.Font.Gotham)
body.LayoutOrder = 2
local distance = UiKit.text(panel, "", 12, K.Dim, Enum.Font.GothamBold)
distance.LayoutOrder = 3

-- Trail: a beam from your character to an invisible marker at the target.
local marker = Instance.new("Part")
marker.Name = "GuideMarker"
marker.Anchored = true
marker.CanCollide = false
marker.CanQuery = false
marker.CanTouch = false
marker.Transparency = 1
marker.Size = Vector3.one
local markerAttachment = Instance.new("Attachment")
markerAttachment.Parent = marker

local beam = Instance.new("Beam")
beam.Name = "GuideTrail"
beam.Attachment1 = markerAttachment
beam.Color = ColorSequence.new(K.Gold, K.Accent)
beam.Transparency = NumberSequence.new(0.35, 0.8)
beam.Width0 = 0.5
beam.Width1 = 0.5
beam.FaceCamera = true
beam.LightEmission = 1
beam.Segments = 20
beam.CurveSize0 = 4 -- a gentle arc, so it reads as a path rather than a laser
beam.CurveSize1 = -4

local function landmark(name: string): Vector3?
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local position = landmarks and landmarks:GetAttribute(name)
	return if typeof(position) == "Vector3" then position else nil
end

local function currentStep()
	local profile = GemClient.Profile
	if not profile or not profile.Intro or not profile.Intro.Done then
		return nil, 0
	end
	local milestones = profile.Milestones or {}
	for i, step in STEPS do
		if not milestones[step.Milestone] then
			return step, i
		end
	end
	return nil, #STEPS + 1
end

local step = nil
local function refresh()
	local index
	step, index = currentStep()
	-- Wait for the intro screens to close before guiding.
	local introOpen = player.PlayerGui:FindFirstChild("Intro") ~= nil
	gui.Enabled = step ~= nil and not hidden and not introOpen
	if step then
		heading.Text = string.format("NEXT STEP  %d/%d   [H] hide", index, #STEPS)
		body.Text = step.Text
		local position = landmark(step.Target)
		if position then
			marker.Position = position + Vector3.new(0, 3, 0)
			marker.Parent = workspace
		end
	end
	beam.Enabled = gui.Enabled and marker.Parent ~= nil
end

GemClient.Changed:Connect(refresh)
task.spawn(function()
	local landmarks = ReplicatedStorage:WaitForChild("Landmarks", 30)
	if landmarks then
		landmarks.AttributeChanged:Connect(refresh)
		refresh()
	end
end)
player.PlayerGui.ChildRemoved:Connect(function(child)
	if child.Name == "Intro" then
		task.defer(refresh)
	end
end)

local function attach(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "GuideAttachment"
		attachment.Position = Vector3.new(0, -1.5, 0)
		attachment.Parent = root
		beam.Attachment0 = attachment
		beam.Parent = root
	end
end
if player.Character then
	task.spawn(attach, player.Character)
end
player.CharacterAdded:Connect(attach)

-- Distance readout, and the trail fades out once you've arrived.
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.25 or not gui.Enabled then
		return
	end
	elapsed = 0
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and marker.Parent then
		local away = (marker.Position - root.Position).Magnitude
		distance.Text = if away < ARRIVED then "You're here!" else string.format("%d studs away", away)
		beam.Enabled = away >= ARRIVED
	end
end)

ContextActionService:BindAction("GemsoulGuide", function(_, state)
	if state == Enum.UserInputState.Begin then
		hidden = not hidden
		refresh()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.H)

refresh()
