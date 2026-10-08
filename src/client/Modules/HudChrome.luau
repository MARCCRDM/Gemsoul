--[[
	The combat HUD's frame art and layout: dark steel panels with a gold
	double rule and corner studs, thin bars with diamond end caps, and the
	one action bar along the bottom (surges Q/E/R, an ornament, maneuvers
	1/2/3) with the three vitals above it: Charge on the left, Health in the
	middle, Stamina on the right.

	  HudChrome.dress(frame, opts)        dress a panel; returns its outer stroke
	  HudChrome.diamond(parent, position, size, color)
	  HudChrome.capBar(track)             gold rule and diamond caps on a bar
	  HudChrome.rule(parent, y)           a gold divider fading at both ends
	  HudChrome.actionBar(parent)         the bottom bar: { Frame, SurgeTitle, ManeuverTitle }
	  HudChrome.layoutActionBar(bar, surgeTray, maneuverTray)  sizes it around the trays
	  HudChrome.layoutVitals(hud, parts, width, stacked)  places the three bars;
	    returns the height used
]]
local HudChrome = {}

HudChrome.Gold = Color3.fromRGB(214, 178, 106)
HudChrome.GoldDim = Color3.fromRGB(126, 100, 58)
HudChrome.Ink = Color3.fromRGB(11, 12, 17)
HudChrome.Steel = Color3.fromRGB(36, 38, 48)
HudChrome.Parchment = Color3.fromRGB(236, 224, 196)
HudChrome.Title = Enum.Font.Merriweather -- names and titles, carved-serif

local function make(className: string, props, parent: Instance?)
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

function HudChrome.diamond(parent: Instance, position: UDim2, size: number, color: Color3, z: number?)
	local gem = make("Frame", {
		Name = "Stud",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = position,
		Rotation = 45,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z or 6,
	}, parent)
	make("UIStroke", { Color = HudChrome.Ink, Thickness = 1, Transparency = 0.2 }, gem)
	return gem
end

-- A panel: steel fading to ink, a dark-gold outer rule, a fine gold inner
-- rule and a gold stud on each corner.
function HudChrome.dress(frame: GuiObject, opts)
	opts = opts or {}
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = opts.Transparency or 0.06
	frame.BorderSizePixel = 0
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(opts.Top or HudChrome.Steel, HudChrome.Ink),
	}, frame)
	make("UICorner", { CornerRadius = UDim.new(0, opts.Radius or 4) }, frame)
	local stroke = make("UIStroke", { Color = HudChrome.GoldDim, Thickness = 1.5, Transparency = 0.1 }, frame)
	local inner = make("Frame", {
		Name = "InnerRule",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
	}, frame)
	make("UICorner", { CornerRadius = UDim.new(0, math.max(0, (opts.Radius or 4) - 2)) }, inner)
	make("UIStroke", { Color = HudChrome.Gold, Thickness = 1, Transparency = 0.7 }, inner)
	if opts.Studs ~= false then
		for _, corner in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do
			HudChrome.diamond(frame, UDim2.fromScale(corner[1], corner[2]), 7, HudChrome.Gold)
		end
	end
	return stroke
end

-- A bar track: inked, a gold hairline, and a diamond capping each end.
function HudChrome.capBar(track: GuiObject)
	track.BackgroundColor3 = HudChrome.Ink
	track.BackgroundTransparency = 0.15
	make("UIStroke", { Color = HudChrome.GoldDim, Thickness = 1, Transparency = 0.15 }, track)
	local caps = {}
	for i, x in { 0, 1 } do
		caps[i] = HudChrome.diamond(track, UDim2.fromScale(x, 0.5), 9, HudChrome.Gold, 8)
	end
	return caps
end

function HudChrome.rule(parent: Instance, y: number)
	local line = make("Frame", {
		Name = "Rule",
		BackgroundColor3 = HudChrome.Gold,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 0, y),
		Size = UDim2.new(1, -20, 0, 1),
	}, parent)
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, line)
	return line
end

local function legend(parent: Instance, caption: string)
	local label = make("TextLabel", {
		Name = "Legend",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = HudChrome.Ink,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = HudChrome.Title,
		Text = caption,
		TextColor3 = HudChrome.Gold,
		TextSize = 10,
		Size = UDim2.fromOffset(8 + #caption * 7, 14),
		ZIndex = 7,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 3) }, label)
	make("UIStroke", { Color = HudChrome.GoldDim, Thickness = 1, Transparency = 0.2 }, label)
	return label
end

HudChrome.Pad, HudChrome.Divider = 12, 40

-- The bottom bar. The trays go in its Frame; layoutActionBar sizes it.
function HudChrome.actionBar(parent: Instance)
	local frame = make("Frame", {
		Name = "ActionBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
	}, parent)
	HudChrome.dress(frame, { Radius = 6, Studs = false })
	-- Pointed ends: a large gold diamond on each side, half outside the bar.
	for _, x in { 0, 1 } do
		HudChrome.diamond(frame, UDim2.fromScale(x, 0.5), 16, HudChrome.GoldDim, 2)
		HudChrome.diamond(frame, UDim2.fromScale(x, 0.5), 8, HudChrome.Gold, 3)
	end
	-- The centre ornament between the two groups: a gem between two rules.
	local ornament = make("Frame", {
		Name = "Ornament",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, HudChrome.Divider, 1, 0),
	}, frame)
	for _, x in { 0.25, 0.75 } do
		local line = make("Frame", {
			BackgroundColor3 = HudChrome.GoldDim,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(x, 0, 0, 10),
			Size = UDim2.new(0, 1, 1, -20),
		}, ornament)
		make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, line)
	end
	HudChrome.diamond(ornament, UDim2.fromScale(0.5, 0.5), 10, HudChrome.Gold)
	return {
		Frame = frame,
		SurgeTitle = legend(frame, "SURGES"),
		ManeuverTitle = legend(frame, "MANEUVERS"),
	}
end

function HudChrome.layoutActionBar(bar, surgeTray: Frame, maneuverTray: Frame)
	if not maneuverTray.Visible then
		local pad = HudChrome.Pad
		surgeTray.AnchorPoint = Vector2.zero
		surgeTray.Position = UDim2.fromOffset(pad, 11)
		bar.Frame.Size = UDim2.fromOffset(2 * pad + surgeTray.Size.X.Offset, surgeTray.Size.Y.Offset + 15)
		bar.SurgeTitle.Position = UDim2.fromOffset(bar.Frame.Size.X.Offset / 2, 0)
		bar.ManeuverTitle.Visible = false
		local ornament = bar.Frame:FindFirstChild("Ornament")
		if ornament then
			ornament.Visible = false
		end
		return bar.Frame.Size.X.Offset, bar.Frame.Size.Y.Offset
	end
	local pad, divider = HudChrome.Pad, HudChrome.Divider
	local trayWidth, trayHeight = surgeTray.Size.X.Offset, surgeTray.Size.Y.Offset
	surgeTray.AnchorPoint, maneuverTray.AnchorPoint = Vector2.zero, Vector2.zero
	surgeTray.Position = UDim2.fromOffset(pad, 11)
	maneuverTray.Position = UDim2.fromOffset(pad + trayWidth + divider, 11)
	bar.Frame.Size = UDim2.fromOffset(2 * (pad + trayWidth) + divider, trayHeight + 15)
	bar.SurgeTitle.Position = UDim2.fromOffset(pad + trayWidth / 2, 0)
	bar.ManeuverTitle.Position = UDim2.fromOffset(pad + trayWidth * 1.5 + divider, 0)
	return bar.Frame.Size.X.Offset, bar.Frame.Size.Y.Offset
end

-- parts: { Name, Shield, Health (track), Bars = { Charge, Stamina } with
-- Label, Value, Track, Fill }. Health drains from both ends toward the
-- middle; Charge and Stamina drain from their outer ends.
function HudChrome.layoutVitals(hud: Frame, parts, width: number, stacked: boolean): number
	local gap = 22
	local side = if stacked then (width - gap) / 2 else math.floor(width * 0.25)
	local middle = if stacked then width else width - 2 * (side + gap)
	local middleX = if stacked then 0 else side + gap
	parts.Name.Position, parts.Name.Size = UDim2.fromOffset(middleX, 0), UDim2.fromOffset(middle, 15)
	parts.Shield.Position, parts.Shield.Size = UDim2.fromOffset(middleX, 1), UDim2.fromOffset(middle - 4, 14)
	parts.Health.Position, parts.Health.Size = UDim2.fromOffset(middleX, 18), UDim2.fromOffset(middle, 14)
	local rowY = if stacked then 40 else 6
	for id, x in { Charge = 0, Stamina = width - side } do
		local bar = parts.Bars[id]
		if bar then
			local left = id == "Charge"
			bar.Label.Position, bar.Label.Size = UDim2.fromOffset(x, rowY), UDim2.fromOffset(side, 12)
			bar.Value.Position, bar.Value.Size = UDim2.fromOffset(x, rowY), UDim2.fromOffset(side, 12)
			bar.Label.TextXAlignment = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
			bar.Value.TextXAlignment = if left then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
			bar.Track.Position, bar.Track.Size = UDim2.fromOffset(x, rowY + 14), UDim2.fromOffset(side, 10)
			bar.Fill.AnchorPoint = Vector2.new(if left then 1 else 0, 0)
			bar.Fill.Position = UDim2.fromScale(if left then 1 else 0, 0)
		end
	end
	local height = if stacked then rowY + 24 else 34
	hud.Size = UDim2.fromOffset(width, height)
	return height
end

return HudChrome
