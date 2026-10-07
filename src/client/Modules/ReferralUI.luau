--[[
	Bring a friend (Shared.Referrals): invite a friend with Roblox's own game
	invite; once they join through it you earn the Crusader's Standard, an exclusive weapon. The server
	(Systems/Referrals) counts the join and grants the reward, even while
	you're away; CHECK CLAIM asks it now.

	  ReferralUI.open() / close() / toggle()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Rules = require(ReplicatedStorage.Shared.Referrals)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local new = IronUi.new
local player = Players.LocalPlayer

local WIDTH, HEIGHT = 600, 400
local TEAL = Color3.fromRGB(60, 210, 240)

local ReferralUI = {}

local reward = Classes.weapon("Warrior", Rules.Reward)
local window = IronUi.window("Referral", 12, WIDTH, HEIGHT, "🤝", TEAL)
local gui, panel = window.Gui, window.Panel
window.Title.Text = "BRING A FRIEND"
window.Subtitle.Text = "A gift for every recruiter"

local function label(parent, value, size, color, font)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font or IronUi.Bold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
end

local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 84),
	Size = UDim2.new(1, -48, 1, -104),
}, panel)

-- The reward on a lit plinth, left.
local stage = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(14, 22, 34),
	Size = UDim2.fromOffset(200, 200),
}, body)
UiKit.round(stage, 10)
new("UIStroke", { Color = TEAL, Thickness = 1.5, Transparency = 0.3 }, stage)
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(26, 70, 86), Color3.fromRGB(10, 16, 26)),
}, stage)
-- The weapon, drawn: a spear shaft with a black and gold war banner.
local GOLD, CLOTH = Color3.fromRGB(214, 160, 52), Color3.fromRGB(18, 18, 22)
local art = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.46),
	Size = UDim2.fromOffset(150, 160),
	Rotation = 8,
}, stage)
local function bar(x, y, w, h, color, rotation)
	return new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rotation or 0,
	}, art)
end
bar(40, 86, 6, 150, Color3.fromRGB(95, 98, 106))
bar(40, 162, 10, 6, GOLD)
bar(40, 10, 11, 22, Color3.fromRGB(205, 210, 220), 45)
bar(40, 22, 14, 4, GOLD)
bar(40, 12, 2, 16, TEAL)
bar(76, 34, 78, 5, GOLD)
local flag = bar(76, 70, 66, 66, CLOTH)
new("UIStroke", { Color = GOLD, Thickness = 2 }, flag)
for _, x in { 60, 92 } do
	local tail = bar(x, 112, 30, 22, CLOTH)
	new("UIStroke", { Color = GOLD, Thickness = 2 }, tail)
end
bar(76, 68, 22, 22, GOLD, 45)
bar(76, 68, 46, 4, TEAL)
local tag = label(stage, "EXCLUSIVE", 11, Color3.fromRGB(10, 16, 26), IronUi.Heading)
tag.AnchorPoint, tag.Position, tag.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(110, 22)
tag.BackgroundTransparency, tag.BackgroundColor3 = 0, TEAL
tag.TextXAlignment = Enum.TextXAlignment.Center
UiKit.round(tag, 11)

-- The offer, right.
local info = new(
	"Frame",
	{ BackgroundTransparency = 1, Position = UDim2.fromOffset(222, 0), Size = UDim2.new(1, -222, 0, 200) },
	body
)
local kicker = label(info, "FREE  ·  EXCLUSIVE WEAPON", 11, TEAL)
kicker.Size = UDim2.new(1, 0, 0, 16)
local title = label(info, string.upper(reward and reward.Name or "Crusader's Standard"), 23, P.Text, IronUi.Heading)
title.Position, title.Size = UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 34)
local pitch = label(info, "Bring a friend into the Saga and fight under the war banner.", 15, P.Text, IronUi.Body)
pitch.Position, pitch.Size = UDim2.fromOffset(0, 56), UDim2.new(1, 0, 0, 40)
-- The one step, ticked off when it's done.
local step = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(14, 22, 34),
	Position = UDim2.fromOffset(0, 108),
	Size = UDim2.new(1, 0, 0, 44),
}, info)
UiKit.round(step, 8)
local stepEdge = new("UIStroke", { Color = P.Edge, Thickness = 1 }, step)
local tick = label(step, "○", 18, P.Dim, IronUi.Heading)
tick.Position, tick.Size = UDim2.fromOffset(12, 0), UDim2.fromOffset(20, 44)
local stepText = label(step, "Invite a friend who joins through your invite.", 13, P.Text, IronUi.Body)
stepText.Position, stepText.Size = UDim2.fromOffset(38, 0), UDim2.new(1, -96, 1, 0)
local progress = label(step, "0 / 1", 13, P.Dim, IronUi.Heading)
progress.AnchorPoint, progress.Position, progress.Size =
	Vector2.new(1, 0), UDim2.new(1, -12, 0, 0), UDim2.fromOffset(52, 44)
progress.TextXAlignment = Enum.TextXAlignment.Right
local wear = label(
	info,
	"Equip it from your Inventory. A badge of honour: same power as a starter blade.",
	11,
	P.Dim,
	IronUi.Body
)
wear.Position, wear.Size = UDim2.fromOffset(0, 160), UDim2.new(1, 0, 0, 30)

-- The buttons and the status line.
local actions = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 216),
	Size = UDim2.new(1, 0, 0, 52),
}, body)
local status = label(body, "", 12, P.Dim, IronUi.Body)
status.Position, status.Size = UDim2.fromOffset(0, 274), UDim2.new(1, 0, 0, 18)

local busy = false
local function draw()
	local profile = GemClient.Profile
	local claimed = profile ~= nil
		and profile.Owned ~= nil
		and profile.Owned.Weapons ~= nil
		and profile.Owned.Weapons[Rules.Reward] ~= nil
	local count = profile and profile.Referrals and profile.Referrals.Count or 0
	local done = claimed or Rules.earned(count)
	tick.Text = if done then "✓" else "○"
	tick.TextColor3 = if done then P.Good else P.Dim
	stepEdge.Color = if done then P.Good else P.Edge
	progress.Text = string.format("%d / %d", math.min(count, Rules.Needed), Rules.Needed)
	progress.TextColor3 = if done then P.Good else P.Dim
	if claimed then
		status.Text = "Unlocked! Thanks for bringing a friend."
		status.TextColor3 = P.Good
	elseif status.Text == "" then
		status.Text = "Your friend needs to join through your invite. It unlocks automatically."
		status.TextColor3 = P.Dim
	end
end

local function invite()
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		pcall(SocialService.PromptGameInvite, SocialService, player)
	else
		UiKit.toast("Invites aren't available on this device or account.", P.Bad)
	end
end

local function check()
	if busy then
		return
	end
	busy = true
	status.Text, status.TextColor3 = "Checking…", P.Dim
	task.spawn(function()
		local result = GemClient.request("ReferralState")
		busy = false
		status.Text = result.Message or ""
		status.TextColor3 = if result.Ok then P.Good else P.Dim
		draw()
	end)
end

local inviteButton = IronUi.gemButton(actions, "INVITE A FRIEND", TEAL, invite)
inviteButton.Position, inviteButton.Size = UDim2.fromOffset(0, 0), UDim2.new(0.5, -6, 1, 0)
local checkButton = IronUi.button(actions, "CHECK CLAIM", false, check)
checkButton.AnchorPoint = Vector2.new(1, 0)
checkButton.Position, checkButton.Size = UDim2.new(1, 0, 0, 0), UDim2.new(0.5, -6, 1, 0)

function ReferralUI.open()
	gui.Enabled = true
	window.Fit()
	status.Text = ""
	draw()
end

function ReferralUI.close()
	gui.Enabled = false
end

function ReferralUI.toggle()
	if gui.Enabled then
		ReferralUI.close()
	else
		ReferralUI.open()
	end
end

window.Close.Activated:Connect(ReferralUI.close)
window.Shade.Activated:Connect(ReferralUI.close)
GemClient.Changed:Connect(function()
	if gui.Enabled then
		draw()
	end
end)

return ReferralUI
