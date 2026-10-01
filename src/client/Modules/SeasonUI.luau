--[[
	The Season Path [J]: your level, XP bar and a scrolling track of 30
	levels, each with a reward to claim. Claim one at a time or all at once.
	Lists what earns XP, and shows a running 2x XP boost.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local Season = require(ReplicatedStorage.Shared.Season)
local Store = require(ReplicatedStorage.Shared.Store)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local BOLD, HEADING = IronUi.Bold, IronUi.Heading
local new, text, box, button, clear = IronUi.new, IronUi.text, IronUi.box, IronUi.button, IronUi.clear

local WIDTH, HEIGHT = 1000, 560
local XP_LABELS = {
	{ "Mine", "Mine a crystal" },
	{ "Sell", "Sell a gem" },
	{ "Enchant", "Enchant" },
	{ "SlayCrawler", "Slay a Crawler" },
	{ "SlayBrute", "Slay a Brute" },
	{ "Daily", "Daily reward" },
}

local SeasonUI = {}

local window = IronUi.window("Season", 10, WIDTH, HEIGHT, "⭐")
local gui, panel = window.Gui, window.Panel
window.Title.Text = "SEASON PATH"
window.Subtitle.Text = Season.Name

local busy = false
local body = new("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 76),
	Size = UDim2.fromOffset(WIDTH - 48, HEIGHT - 100),
}, panel)

local function cosmeticName(id: string): string
	local c = Cosmetics.get(id)
	return if c then c.Name else id
end

local function icon(reward): string
	if reward.Cosmetics then
		return "✨"
	elseif reward.Crates then
		return "📦"
	elseif reward.Coins then
		return "💰"
	elseif reward.Marks then
		return "🎖️"
	end
	return "⚒️"
end

local function claim(which: any)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		local result = GemClient.request("ClaimSeason", which)
		UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
		busy = false
		SeasonUI.refresh()
	end)
end

function SeasonUI.refresh()
	if not gui.Enabled then
		return
	end
	clear(body)
	local profile = GemClient.Profile or {}
	local season = profile.Season or { XP = 0, Claimed = {} }
	local level, into, need = Season.levelFor(season.XP)

	-- Level, XP bar, boost and Claim All.
	local header = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60) }, body)
	local badge = IronUi.badge(header, tostring(level), 56, P.Gold)
	badge.Position = UDim2.fromOffset(0, 0)
	local label = text(header, string.format("LEVEL %d", level), 20, P.Gold, HEADING)
	label.Position = UDim2.fromOffset(70, 2)
	label.Size = UDim2.fromOffset(300, 22)
	local track = new("Frame", {
		BackgroundColor3 = P.Slot,
		Position = UDim2.fromOffset(70, 32),
		Size = UDim2.fromOffset(420, 16),
	}, header)
	UiKit.round(track, 8)
	local fill = new("Frame", {
		BackgroundColor3 = P.Gold,
		Size = UDim2.fromScale(if level >= Season.MaxLevel then 1 else math.clamp(into / need, 0, 1), 1),
	}, track)
	UiKit.round(fill, 8)
	local xpText = text(
		track,
		if level >= Season.MaxLevel then "MAX" else string.format("%d / %d XP", into, need),
		11,
		Color3.new(1, 1, 1),
		BOLD
	)
	xpText.Size = UDim2.fromScale(1, 1)
	xpText.AutomaticSize = Enum.AutomaticSize.None
	xpText.TextXAlignment = Enum.TextXAlignment.Center
	local boostLeft = (profile.Boosts and profile.Boosts.XPUntil or 0) - (profile.ServerTime or os.time())
	if boostLeft > 0 then
		local boost = text(header, string.format("⚡ 2x XP: %d min left", math.ceil(boostLeft / 60)), 14, P.Good, BOLD)
		boost.Position = UDim2.fromOffset(510, 30)
		boost.Size = UDim2.fromOffset(200, 18)
	end
	local unclaimed = 0
	for l = 1, level do
		if not season.Claimed[tostring(l)] then
			unclaimed += 1
		end
	end
	if unclaimed > 0 then
		local all = button(header, string.format("CLAIM ALL (%d)", unclaimed), true, function()
			claim("all")
		end)
		all.AnchorPoint = Vector2.new(1, 0)
		all.Position = UDim2.new(1, 0, 0, 12)
	end

	-- The track: one card per level.
	local strip = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 250),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = P.Edge,
	}, body)
	UiKit.list(strip, 10, true)
	new("UIPadding", { PaddingBottom = UDim.new(0, 10) }, strip)
	for l = 1, Season.MaxLevel do
		local reward = Season.reward(l)
		local reached = l <= level
		local claimed = season.Claimed[tostring(l)] == true
		local special = reward.Cosmetics ~= nil
		local card = box(
			strip,
			UDim2.new(),
			UDim2.fromOffset(128, 226),
			if special then Color3.fromRGB(46, 36, 60) else P.Inset,
			10
		)
		card.LayoutOrder = l
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		stroke.Color = if claimed
			then P.Good
			elseif reached then P.Gold
			elseif special then Color3.fromRGB(170, 120, 255)
			else P.Edge
		stroke.Thickness = if reached and not claimed then 3 else 1.5
		local number = text(card, "LV " .. l, 14, if reached then P.Gold else P.Dim, BOLD)
		number.Position = UDim2.fromOffset(0, 8)
		number.TextXAlignment = Enum.TextXAlignment.Center
		local glyph = new("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 56),
			Text = icon(reward),
			TextSize = 44,
			Font = BOLD,
			TextTransparency = if reached then 0 else 0.5,
		}, card)
		glyph.Name = "Icon"
		local what = text(card, table.concat(Store.describe(reward, cosmeticName), "\n"), 11, P.Text, BOLD)
		what.Position = UDim2.fromOffset(6, 96)
		what.Size = UDim2.new(1, -12, 0, 0)
		what.TextXAlignment = Enum.TextXAlignment.Center
		if claimed then
			local done = text(card, "✓ CLAIMED", 12, P.Good, BOLD)
			done.AnchorPoint = Vector2.new(0, 1)
			done.Position = UDim2.new(0, 0, 1, -12)
			done.TextXAlignment = Enum.TextXAlignment.Center
		elseif reached then
			local b = button(card, "CLAIM", true, function()
				claim(l)
			end)
			b.AnchorPoint = Vector2.new(0.5, 1)
			b.Position = UDim2.new(0.5, 0, 1, -10)
		else
			local lock = text(card, "🔒", 16, P.Dim, BOLD)
			lock.AnchorPoint = Vector2.new(0, 1)
			lock.Position = UDim2.new(0, 0, 1, -12)
			lock.TextXAlignment = Enum.TextXAlignment.Center
		end
	end

	-- What earns XP.
	local ways = {}
	for _, entry in XP_LABELS do
		table.insert(ways, string.format("%s +%d", entry[2], Season.XP[entry[1]]))
	end
	local earn = text(body, "EARN XP:  " .. table.concat(ways, "   •   "), 13, P.Dim, BOLD)
	earn.Position = UDim2.fromOffset(0, 340)
	local hint = text(
		body,
		"Special levels (5, 10, 15, 20, 25, 30) unlock trims and back pieces you can't buy. Wear them from the Shop.",
		13,
		P.Text
	)
	hint.Position = UDim2.fromOffset(0, 390)
end

function SeasonUI.open()
	gui.Enabled = true
	window.Fit()
	SeasonUI.refresh()
end

function SeasonUI.close()
	gui.Enabled = false
	clear(body)
end

function SeasonUI.toggle()
	if gui.Enabled then
		SeasonUI.close()
	else
		SeasonUI.open()
	end
end

window.Close.Activated:Connect(SeasonUI.close)
window.Shade.Activated:Connect(SeasonUI.close)
GemClient.Changed:Connect(function()
	if gui.Enabled and not busy then
		SeasonUI.refresh()
	end
end)

return SeasonUI
