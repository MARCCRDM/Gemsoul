--[[
	The free Survey Pick as a charge: one swing back every
	Outpost.FreeSwingSeconds, up to its full swings. Drawn the same way on
	the Outpost HUD, in the refills window and on the dashboard.

	  ChargeMeter.read(picks, surveyAt)   swings (free + bought), seconds to
	                                      the next free one (nil when full),
	                                      progress 0..1, bought swings
	  ChargeMeter.new(parent, x, y, w)    a meter; meter.set(swings, nextIn,
	                                      progress) redraws it
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Outpost)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local P = IronUi.Colors
local new = IronUi.new

local ChargeMeter = {}

ChargeMeter.Full = Rules.Picks.Survey.Swings
ChargeMeter.Charging = P.Teal
ChargeMeter.Charged = P.Gold
ChargeMeter.Height = 44

-- The charge now, from a profile's or the server state's picks and clock.
-- No clock yet means a new miner, whose free pick starts full.
-- Bought swings (picks.Extra) stack on top: the charge keeps regaining
-- under them.
function ChargeMeter.read(picks: { [string]: number }?, surveyAt: number?): (number, number?, number, number)
	local extra = picks and picks.Extra or 0
	if surveyAt == nil then
		return ChargeMeter.Full + extra, nil, 1, extra
	end
	local free, nextIn, progress = Rules.surveyCharge(picks and picks.Survey or 0, surveyAt, workspace:GetServerTimeNow())
	return free + extra, nextIn, progress, extra
end

-- The swings as a count: "23 / 600", or with refills on top "23 + 140".
function ChargeMeter.count(swings: number, extra: number?): string
	extra = extra or math.max(0, swings - ChargeMeter.Full)
	if extra > 0 then
		return string.format("%d + %d", swings - extra, extra)
	end
	return string.format("%d / %d", swings, ChargeMeter.Full)
end

-- "+1 swing in 1:42 · full in 46:00", "Fully charged", and with refills on
-- top "· 140 extra" (the charge keeps regaining under them).
function ChargeMeter.status(swings: number, nextIn: number?, extra: number?): string
	extra = extra or math.max(0, swings - ChargeMeter.Full)
	local tail = if extra > 0 then string.format(" · %d extra", extra) else ""
	if not nextIn then
		return "Fully charged" .. tail
	end
	local fullIn = nextIn + (ChargeMeter.Full - (swings - extra) - 1) * Rules.FreeSwingSeconds
	return string.format("+1 swing in %s · full in %s", Rules.clock(nextIn), Rules.clock(fullIn)) .. tail
end

local function label(parent, value, size, color, font, x, y, w, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size,
		TextColor3 = color,
		Font = font,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, size + 2),
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
end

function ChargeMeter.new(parent: GuiObject, x: number, y: number, w: number)
	local root = new("Frame", {
		Name = "ChargeMeter",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, ChargeMeter.Height),
	}, parent)
	local title = label(root, "⚡ FREE PICK CHARGE", 11, ChargeMeter.Charging, IronUi.Bold, 0, 0, w - 70)
	local count = label(root, "", 13, P.Text, IronUi.Bold, w - 70, -1, 70, Enum.TextXAlignment.Right)
	local track = new("Frame", {
		Position = UDim2.fromOffset(0, 17),
		Size = UDim2.fromOffset(w, 9),
		BackgroundColor3 = Color3.fromRGB(28, 34, 50),
		ClipsDescendants = true,
	}, root)
	UiKit.round(track, 4)
	local glow = new("UIStroke", { Color = ChargeMeter.Charged, Thickness = 1.5, Transparency = 1 }, track)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = ChargeMeter.Charging }, track)
	UiKit.round(fill, 4)
	-- The swing being charged now: a lighter sliver growing past the fill.
	local next = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = ChargeMeter.Charging,
		BackgroundTransparency = 0.55,
	}, track)
	-- Notches every 10 swings.
	for i = 1, ChargeMeter.Full // 10 - 1 do
		new("Frame", {
			Position = UDim2.new(i * 10 / ChargeMeter.Full, -1, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Color3.fromRGB(14, 18, 30),
			BackgroundTransparency = 0.25,
			ZIndex = 3,
		}, track)
	end
	local status = label(root, "", 11, P.Dim, IronUi.Body, 0, 30, w)

	local meter = { Frame = root }
	function meter.set(swings: number, nextIn: number?, progress: number, extra: number?)
		local full = nextIn == nil
		local color = if full then ChargeMeter.Charged else ChargeMeter.Charging
		local share = math.clamp((swings - (extra or 0)) / ChargeMeter.Full, 0, 1)
		fill.Size = UDim2.fromScale(share, 1)
		fill.BackgroundColor3 = color
		next.Visible = not full
		next.Position = UDim2.fromScale(share, 0)
		next.Size = UDim2.fromScale(math.clamp(progress, 0, 1) / ChargeMeter.Full, 1)
		glow.Transparency = if full then 0.1 else 1
		title.TextColor3 = color
		local short = w < 240 -- a narrow card: just the state
		title.Text = if full
			then (if short then "⚡ CHARGED" else "⚡ FREE PICK CHARGED")
			else (if short then "⚡ CHARGING" else "⚡ FREE PICK CHARGING")
		count.Text = ChargeMeter.count(swings, extra)
		count.TextColor3 = if swings > 0 then P.Text else P.Bad
		status.Text = ChargeMeter.status(swings, nextIn, extra)
		status.TextColor3 = if full then ChargeMeter.Charged else P.Dim
	end
	meter.set(ChargeMeter.Full, nil, 1)
	return meter
end

return ChargeMeter
