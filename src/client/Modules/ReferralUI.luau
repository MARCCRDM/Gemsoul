--[[
	Bring a friend (Shared.Referrals): invite a friend with Roblox's own game
	invite; once they join through it you earn Kindred Edge, a Legendary
	weapon skin you can't get any other way (then the rest of the ladder:
	2, 3, 4, 5 and 10 friends). The server (Systems/Referrals) counts the
	join and grants the reward, even while you're away or in another
	server; CHECK CLAIM asks it now.

	  ReferralUI.open() / close() / toggle()
	  ReferralUI.invite()   Roblox's invite prompt (the Shop's Free tab too)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Rules = require(ReplicatedStorage.Shared.Referrals)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local ShopArt = require(script.Parent.ShopArt)
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
-- The skin itself, turning in 3D (drawn until the model arrives), with
-- motes of its two colours twinkling round it.
local palette = reward and reward.Palette
local TWIN_A = palette and palette.Glow or TEAL
local TWIN_B = palette and palette.Plate or Color3.fromRGB(244, 172, 40)
local art = ShopArt.icon(stage, "Skin", Rules.Reward, 180)
art.AnchorPoint, art.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, -8)
local motes = {}
for i, spot in { { 0.16, 0.2 }, { 0.84, 0.28 }, { 0.12, 0.66 }, { 0.88, 0.7 }, { 0.5, 0.08 }, { 0.3, 0.86 } } do
	local mote = new("Frame", {
		BackgroundColor3 = if i % 2 == 0 then TWIN_A else TWIN_B,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(spot[1], spot[2]),
		Size = UDim2.fromOffset(5 + (i % 3) * 2, 5 + (i % 3) * 2),
		Rotation = 45,
		ZIndex = 4,
	}, stage)
	motes[i] = mote
end
IronUi.animate(stage, function(t)
	for i, mote in motes do
		mote.BackgroundTransparency = 0.45 + 0.55 * math.abs(math.sin(t * 1.6 + i * 1.3))
	end
end)
local tag = label(stage, "ONLY HERE", 11, Color3.fromRGB(10, 16, 26), IronUi.Heading)
tag.AnchorPoint, tag.Position, tag.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -10), UDim2.fromOffset(110, 22)
tag.BackgroundTransparency, tag.BackgroundColor3 = 0, TWIN_B
tag.ZIndex = 5
tag.TextXAlignment = Enum.TextXAlignment.Center
UiKit.round(tag, 11)

-- The offer, right.
local info = new(
	"Frame",
	{ BackgroundTransparency = 1, Position = UDim2.fromOffset(222, 0), Size = UDim2.new(1, -222, 0, 200) },
	body
)
local kicker = label(
	info,
	string.format("FREE  ·  %s WEAPON SKIN", string.upper(reward and reward.Rarity or "Legendary")),
	11,
	TEAL
)
kicker.Size = UDim2.new(1, 0, 0, 16)
local title = label(info, string.upper(reward and reward.Name or "Kindred Edge"), 23, P.Text, IronUi.Heading)
title.Position, title.Size = UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 34)
local pitch =
	label(info, "Bring a friend into the Saga: your blade, forged for two in teal and gold.", 15, P.Text, IronUi.Body)
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
local checkButton: TextButton
local function draw()
	local profile = GemClient.Profile
	local owned = profile and profile.Cosmetics and profile.Cosmetics.Owned or {}
	local claimed = owned[Rules.Reward] == true
	local wearing = claimed and profile.Cosmetics.Skin == Rules.Reward
	local count = profile and profile.Referrals and profile.Referrals.Count or 0
	-- Before the first reward, that one step; after it, the next rung.
	local target = if claimed then Rules.nextTier(count) else Rules.Tiers[1]
	local done = if claimed then target == nil else Rules.earned(count)
	if not claimed then
		stepText.Text = "Invite a friend who joins through your invite."
	elseif target then
		local nextReward = Cosmetics.get(target.Reward)
		stepText.Text =
			string.format("Next: %s at %d friends.", nextReward and nextReward.Name or target.Reward, target.Friends)
	else
		stepText.Text = "Every friend reward is yours. Thank you!"
	end
	local goal = if target then target.Friends else count
	tick.Text = if done then "✓" else "○"
	tick.TextColor3 = if done then P.Good else P.Dim
	stepEdge.Color = if done then P.Good else P.Edge
	progress.Text = string.format("%d / %d", math.min(count, goal), goal)
	progress.TextColor3 = if done then P.Good else P.Dim
	-- Once it's yours, the second button puts it on or takes it off.
	local caption = if not claimed then "CHECK CLAIM" elseif wearing then "TAKE OFF SKIN" else "EQUIP SKIN"
	if checkLabel and checkLabel.Text ~= caption then
		checkLabel.Text = caption
		checkButton.Text = caption -- (the button's own, unseen text sizes it)
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

-- Roblox's own invite prompt. (Roblox doesn't send invites from a Studio
-- playtest: it says so instead of failing quietly.)
function ReferralUI.invite()
	if RunService:IsStudio() then
		UiKit.toast("Invites open in the live game. Studio playtests can't send them.", P.Gold)
		return
	end
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if not ok or not can then
		UiKit.toast("Invites aren't available on this account or device.", P.Bad)
		return
	end
	local options = nil
	pcall(function()
		local made = Instance.new("ExperienceInviteOptions")
		made.PromptMessage = "Bring a friend: when they join, you get Kindred Edge!"
		options = made
	end)
	local shown = pcall(function()
		if options then
			SocialService:PromptGameInvite(player, options)
		else
			SocialService:PromptGameInvite(player)
		end
	end)
	if not shown then
		UiKit.toast("The invite couldn't open. Try again in a moment.", P.Bad)
	end
end
-- Who you sent it to: a word of thanks, and what happens next.
pcall(function()
	SocialService.GameInvitePromptClosed:Connect(function(who: Instance, recipients: { number })
		if who ~= player or type(recipients) ~= "table" or #recipients == 0 then
			return
		end
		status.Text = string.format(
			"Invite sent to %d friend%s. When one joins, your reward unlocks by itself.",
			#recipients,
			if #recipients == 1 then "" else "s"
		)
		status.TextColor3 = P.Good
	end)
end)

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
		status.TextColor3 = if not result.Ok then P.Bad elseif result.Claimed then P.Good else P.Dim
		draw()
	end)
end

local inviteButton = IronUi.gemButton(actions, "INVITE A FRIEND", TEAL, ReferralUI.invite)
inviteButton.Position, inviteButton.Size = UDim2.fromOffset(0, 0), UDim2.new(0.5, -6, 1, 0)
checkButton = IronUi.button(actions, "CHECK CLAIM", false, check)
checkButton.AnchorPoint = Vector2.new(1, 0)
checkButton.Position, checkButton.Size = UDim2.new(1, 0, 0, 0), UDim2.new(0.5, -6, 1, 0)
-- (IronUi buttons show their words in a child named Label.)
checkLabel = checkButton:FindFirstChild("Label", true) :: TextLabel?

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
