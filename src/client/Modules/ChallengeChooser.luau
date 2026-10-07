--[[
	Before an Outpost duel challenge goes out, the challenger picks its stats
	(Shared.PvPRules): FULL PROGRESSION (everything both of you have earned,
	which the other player accepts by accepting) or EVEN STATS (the same base
	stats as Casual and Ranked). Used by every "Duel" button: the Outpost
	prompt, the Social window and the chat.

	  ChallengeChooser.open(userId, name?)  shows the choice, then sends
	                                        "DuelChallenge", userId, stats
]]
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local new = IronUi.new

local ChallengeChooser = {}

local gui = UiKit.gui("ChallengeChooser", 40)
gui.Enabled = false

local veil = new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(4, 6, 12),
	BackgroundTransparency = 0.35,
}, gui)
local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 250),
	BackgroundColor3 = P.Frame,
}, veil)
UiKit.round(card, 12)
new("UIStroke", { Color = P.Gold, Thickness = 2 }, card)
local scale = new("UIScale", {}, card)

local function label(value, size, color, font, y, h)
	local l = IronUi.text(card, value, size, color, font)
	l.AutomaticSize = Enum.AutomaticSize.None
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.Position, l.Size = UDim2.fromOffset(16, y), UDim2.new(1, -32, 0, h)
	l.TextWrapped = true
	return l
end
local title = label("⚔  CHALLENGE", 22, P.Text, IronUi.Heading, 14, 28)
label("Pick the stats for this duel. Outpost duels are unrated.", 13, P.Dim, IronUi.Body, 44, 18)

local target: number? = nil

local function send(stats: string)
	local userId = target
	gui.Enabled = false
	target = nil
	if not userId then
		return
	end
	task.spawn(function()
		local result = GemClient.request("DuelChallenge", userId, stats)
		if result and result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, if result.Ok then P.Good else P.Bad)
		end
	end)
end

local function option(x, heading, line, color, stats)
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Position = UDim2.fromOffset(x, 76),
		Size = UDim2.fromOffset(206, 112),
		BackgroundColor3 = color:Lerp(Color3.fromRGB(14, 18, 30), 0.78),
	}, card)
	UiKit.round(b, 10)
	local stroke = new("UIStroke", { Color = color, Thickness = 1.5, Transparency = 0.2 }, b)
	local head = IronUi.text(b, heading, 17, color, IronUi.Heading)
	head.AutomaticSize = Enum.AutomaticSize.None
	head.TextXAlignment = Enum.TextXAlignment.Center
	head.Position, head.Size = UDim2.fromOffset(8, 12), UDim2.new(1, -16, 0, 22)
	local sub = IronUi.text(b, line, 12, P.Dim, IronUi.Body)
	sub.AutomaticSize = Enum.AutomaticSize.None
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.TextWrapped = true
	sub.Position, sub.Size = UDim2.fromOffset(10, 40), UDim2.new(1, -20, 0, 64)
	b.MouseEnter:Connect(function()
		stroke.Thickness, stroke.Transparency = 2.5, 0
	end)
	b.MouseLeave:Connect(function()
		stroke.Thickness, stroke.Transparency = 1.5, 0.2
	end)
	IronUi.juice(b)
	b.Activated:Connect(function()
		send(stats)
	end)
	return b
end
option(16, "EVEN STATS", "Same base stats as Casual and Ranked. Gear, gems and skill decide it.", P.Teal, "Even")
option(
	238,
	"FULL PROGRESSION",
	"Everything you've both earned counts, Augment Tree included. They see this before accepting.",
	P.Gold,
	"Full"
)

local cancel = UiKit.button(card, "Cancel", P.Dim, function()
	gui.Enabled = false
	target = nil
end)
cancel.AnchorPoint = Vector2.new(0.5, 0)
cancel.Position, cancel.Size = UDim2.new(0.5, 0, 0, 202), UDim2.fromOffset(120, 34)
veil.Activated:Connect(function()
	gui.Enabled = false
	target = nil
end)

local function fit()
	local screen = gui.AbsoluteSize
	if screen.X > 0 then
		scale.Scale = math.min(1, (screen.X - 32) / 460, (screen.Y - 24) / 250)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

function ChallengeChooser.open(userId: number, name: string?)
	target = userId
	title.Text = if name then "⚔  CHALLENGE " .. string.upper(name) else "⚔  CHALLENGE"
	fit()
	gui.Enabled = true
end

return ChallengeChooser
