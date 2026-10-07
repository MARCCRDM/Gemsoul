--[[
	Bring a friend (Shared.Referrals): invite a friend with Roblox's own game
	invite; once they join through it you earn Crusader Gold, an exclusive weapon skin. The server
	(Systems/Referrals) counts the join and grants the reward, even while
	you're away; CHECK CLAIM asks it now.

	  ReferralUI.open() / close() / toggle()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
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

local reward = Cosmetics.get(Rules.Reward)
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
-- The skin, drawn on a blade: gold and obsidian, white-hot edges, sparks.
local GOLD, OBSIDIAN = Color3.fromRGB(226, 172, 58), Color3.fromRGB(20, 18, 26)
local HOT = reward and reward.Color or Color3.fromRGB(255, 214, 110)
local art = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(150, 160),
	Rotation = 35,
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
-- Glow behind the blade.
local glow = bar(75, 62, 46, 130, HOT)
glow.BackgroundTransparency = 0.82
UiKit.round(glow, 23)
bar(75, 62, 20, 112, GOLD) -- blade
bar(75, 4, 14, 14, GOLD, 45) -- point
bar(68, 64, 3, 108, HOT) -- white-hot edges
bar(82, 64, 3, 108, HOT)
bar(75, 62, 4, 96, Color3.fromRGB(150, 104, 30)) -- fuller
bar(75, 122, 62, 10, OBSIDIAN) -- crossguard
bar(75, 122, 54, 3, GOLD)
bar(75, 122, 12, 12, HOT, 45) -- gem
bar(75, 142, 9, 26, OBSIDIAN) -- grip
bar(75, 157, 14, 14, GOLD, 45) -- pommel
-- Sparks.
local sparks = {}
for i, spot in { { 40, 30 }, { 112, 52 }, { 44, 92 }, { 108, 108 }, { 56, 10 } } do
	local spark = bar(spot[1], spot[2], 6 + (i % 2) * 3, 6 + (i % 2) * 3, HOT, 45)
	sparks[i] = spark
end
IronUi.animate(art, function(t)
	for i, spark in sparks do
		spark.BackgroundTransparency = 0.5 + 0.5 * math.sin(t * 3 + i * 1.7)
	end
	glow.BackgroundTransparency = 0.78 + 0.08 * math.sin(t * 2)
end)
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
local kicker = label(info, "FREE  ·  EXCLUSIVE WEAPON SKIN", 11, TEAL)
kicker.Size = UDim2.new(1, 0, 0, 16)
local title = label(info, string.upper(reward and reward.Name or "Crusader Gold"), 23, P.Text, IronUi.Heading)
title.Position, title.Size = UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 34)
local pitch = label(info, "Bring a friend into the Saga. Your weapon turns to burnished gold.", 15, P.Text, IronUi.Body)
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
local wear =
	label(info, "Works on any weapon you hold. Pure style: it never changes your stats.", 11, P.Dim, IronUi.Body)
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
local checkLabel: TextLabel? = nil -- the second button's caption
local function draw()
	local profile = GemClient.Profile
	local claimed = profile ~= nil
		and profile.Cosmetics ~= nil
		and profile.Cosmetics.Owned ~= nil
		and profile.Cosmetics.Owned[Rules.Reward] == true
	local wearing = claimed and profile.Cosmetics.Skin == Rules.Reward
	local count = profile and profile.Referrals and profile.Referrals.Count or 0
	local done = claimed or Rules.earned(count)
	tick.Text = if done then "✓" else "○"
	tick.TextColor3 = if done then P.Good else P.Dim
	stepEdge.Color = if done then P.Good else P.Edge
	progress.Text = string.format("%d / %d", math.min(count, Rules.Needed), Rules.Needed)
	progress.TextColor3 = if done then P.Good else P.Dim
	-- Once it's yours, the second button puts it on or takes it off.
	if checkLabel then
		checkLabel.Text = if not claimed then "CHECK CLAIM" elseif wearing then "TAKE OFF SKIN" else "EQUIP SKIN"
	end
	if claimed then
		status.Text = if wearing
			then "On your weapon now. Thanks for bringing a friend!"
			else "Unlocked! Equip it to put it on your weapon."
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
	local profile = GemClient.Profile
	if profile and profile.Cosmetics and profile.Cosmetics.Owned[Rules.Reward] == true then
		-- Owned: toggle it on the weapon.
		busy = true
		local wearing = profile.Cosmetics.Skin == Rules.Reward
		task.spawn(function()
			local result = GemClient.request("EquipCosmetic", "Skin", if wearing then nil else Rules.Reward)
			busy = false
			if not result.Ok then
				status.Text, status.TextColor3 = result.Message or "Try again.", P.Bad
			end
			draw()
		end)
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
checkLabel = checkButton:FindFirstChildWhichIsA("TextLabel", true)

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
