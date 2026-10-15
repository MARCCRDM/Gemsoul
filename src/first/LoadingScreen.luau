--[[
	The loading screen: it covers the world while the world isn't ready to
	be seen (joining, the title screen handing over, arriving somewhere new),
	so nothing pops in, flickers or shows half built. It lives in
	ReplicatedFirst so it's up from the very first frame of joining, before
	anything else has loaded. Client scripts use it through
	Modules/LoadingFlow, which knows when each place is ready.

	Several things can want it at once (covers); it shows while any of them
	does, and fades away once they're all done.

	  local cover = LoadingScreen.cover(reason, {
	      Status = "Loading the Outpost",  -- the line under the bar
	      Instant = true,  -- opaque this frame (the view is about to jump)
	      FadeIn = 0.3,    -- else fades in over this long (default 0.2 s)
	      Min = 0.8,       -- up at least this long
	      Max = 15,        -- never longer than this (then it lets go)
	  })
	  cover.release()          -- this cover is done
	  cover.status(text)       -- what it says it's doing
	  LoadingScreen.progress(fraction?)  -- a real bar (nil: a sweep)
	  LoadingScreen.active()             -- anything wants it up
	  LoadingScreen.covered()            -- fully opaque right now
	  LoadingScreen.waitCovered(timeout?)
	  LoadingScreen.waitClear(timeout?)  -- until it's gone
	  LoadingScreen.wanted(covers, now)  -- pure: (wanted, status)
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LoadingScreen = {}

LoadingScreen.FadeIn = 0.2
LoadingScreen.FadeOut = 0.35
LoadingScreen.Min = 0.6
LoadingScreen.Max = 15
LoadingScreen.TipSeconds = 5

-- The Saga palette (the title screen's).
local BACKGROUND = Color3.fromRGB(12, 11, 23)
local GOLD = Color3.fromRGB(255, 202, 91)
local CYAN = Color3.fromRGB(120, 220, 235)
local DIM = Color3.fromRGB(138, 150, 178)
local FAINT = Color3.fromRGB(88, 94, 128)

LoadingScreen.Tips = {
	"Click, tap or press E for each swing. Break rocks to discover gems.",
	"One gem, two ways to build: enchant your gear, or equip it as a Surge.",
	"Land attacks to build Charge, then spend it on your Q, E and R Surges.",
	"Rocks grow back after they're mined out. Rarer gems hide in bigger rocks.",
	"Hold your guard to block. A well-timed block staggers your rival.",
	"Trade gems with other miners at the Market: it pays better than selling.",
}

export type Cover = {
	Reason: string,
	Status: string?,
	Since: number,
	Min: number,
	Max: number,
	FadeIn: number,
	Released: boolean,
	release: () -> (),
	status: (string) -> (),
}

local covers: { Cover } = {}
local alpha = 0 -- 0 hidden .. 1 opaque
local bar: number? = nil

-- Whether any cover wants the screen up at `now`, and what the newest one
-- says it's doing. A released cover still holds until its Min is up; none
-- holds past its Max.
function LoadingScreen.wanted(list: { any }, now: number): (boolean, string?)
	local wanted, status, newest = false, nil, -math.huge
	for _, cover in list do
		local live = now < cover.Since + cover.Max and (not cover.Released or now < cover.Since + cover.Min)
		if live then
			wanted = true
			if cover.Status and cover.Since >= newest then
				newest, status = cover.Since, cover.Status
			end
		end
	end
	return wanted, status
end

-- The screen itself, built the first time it's wanted. Every piece fades
-- with it (its own transparency, scaled), so the text stays crisp.
local gui: ScreenGui? = nil
local faded: { { Object: Instance, Property: string, Base: number } } = {}
local stars: { { Frame: Frame, Speed: number, Offset: number } } = {}
local status: TextLabel? = nil
local tip: TextLabel? = nil
local fill: Frame? = nil
local gem: Frame? = nil
local shimmer: Frame? = nil
local blocker: Frame? = nil
local tipIndex = 0
local tipAt = 0

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end
-- Fades with the screen: `property` at `base` when it's fully up.
local function fades(object: Instance, property: string, base: number?)
	table.insert(faded, { Object = object, Property = property, Base = base or (object :: any)[property] })
end

local function build(): ScreenGui
	local player = Players.LocalPlayer
	local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
	local screen = new("ScreenGui", {
		Name = "LoadingScreen",
		DisplayOrder = 900,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	})
	-- The backdrop also takes the clicks and taps (Active), so nothing behind
	-- it is pressed while it's up.
	local back = new("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BACKGROUND,
		BorderSizePixel = 0,
		Active = true,
	}, screen)
	blocker = back
	fades(back, "BackgroundTransparency", 0)
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(26, 22, 52), Color3.fromRGB(6, 6, 14)),
	}, back)
	-- Stars, twinkling.
	local rng = Random.new(11)
	for _ = 1, 46 do
		local size = rng:NextInteger(2, 3)
		local star = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.02, 0.98), rng:NextNumber(0.02, 0.98)),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = if rng:NextNumber() < 0.5 then CYAN else Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, back)
		table.insert(stars, { Frame = star, Speed = rng:NextNumber(0.7, 2.2), Offset = rng:NextNumber(0, 6.28) })
	end
	-- Everything else sits on a 1280 x 720 stage, scaled to the screen.
	local stage = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1280, 720),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, back)
	local scale = new("UIScale", {}, stage)
	local footScale: UIScale? = nil
	local function fit()
		local size = back.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			local fits = math.min(size.X / 1280, size.Y / 720)
			-- (A phone held sideways: a little bigger, so the words stay readable.)
			if size.Y < 500 then
				fits *= 1.25
			end
			scale.Scale = math.clamp(fits, 0.45, 1.6)
			if footScale then
				footScale.Scale = scale.Scale
			end
		end
	end
	back:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	-- A soft glow behind the title.
	for i, spec in { { 760, 0.94 }, { 520, 0.92 }, { 300, 0.9 } } do
		local disc = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(640, 330),
			Size = UDim2.fromOffset(spec[1], spec[1]),
			BackgroundColor3 = Color3.fromRGB(70, 34, 120),
			BorderSizePixel = 0,
			ZIndex = 3 + i,
		}, stage)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
		fades(disc, "BackgroundTransparency", spec[2])
	end
	-- The gem: a cut stone turning over above the title.
	local stone = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(640, 236),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = CYAN,
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = 8,
	}, stage)
	fades(stone, "BackgroundTransparency", 0.55)
	local edge = new("UIStroke", { Color = GOLD, Thickness = 3 }, stone)
	fades(edge, "Transparency", 0)
	local facet = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 9,
	}, stone)
	fades(facet, "BackgroundTransparency", 0.35)
	gem = stone
	-- The title: SAGA MINERS, stacked like the game's own wordmark.
	local function layer(y: number, color: Color3): TextLabel
		local label = new("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(640, 318 + y),
			Size = UDim2.fromOffset(900, 80),
			BackgroundTransparency = 1,
			Text = "SAGA MINERS",
			Font = Enum.Font.Arcade,
			TextSize = 72,
			TextColor3 = color,
			ZIndex = 10,
		}, stage)
		fades(label, "TextTransparency", 0)
		return label
	end
	layer(9, Color3.fromRGB(59, 27, 109))
	layer(6, Color3.fromRGB(143, 43, 136))
	layer(3, Color3.fromRGB(213, 103, 52))
	local face = layer(0, Color3.new(1, 1, 1))
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 247, 185)),
			ColorSequenceKeypoint.new(0.48, GOLD),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(229, 143, 44)),
		}),
	}, face)
	-- The bar: real progress when it's known, else a sweep.
	local track = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(640, 410),
		Size = UDim2.fromOffset(380, 4),
		BackgroundColor3 = Color3.fromRGB(44, 40, 78),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 10,
	}, stage)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	fades(track, "BackgroundTransparency", 0)
	fill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, track)
	fades(fill :: Frame, "BackgroundTransparency", 0)
	shimmer = new("Frame", {
		Size = UDim2.fromScale(0.28, 1),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, track)
	fades(shimmer :: Frame, "BackgroundTransparency", 0)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, shimmer)
	status = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(640, 428),
		Size = UDim2.fromOffset(700, 22),
		BackgroundTransparency = 1,
		Text = "LOADING",
		Font = Enum.Font.GothamMedium,
		TextSize = 18,
		TextColor3 = DIM,
		ZIndex = 10,
	}, stage)
	fades(status :: TextLabel, "TextTransparency", 0)
	-- The tip sits on the screen's bottom edge (on a phone the stage runs
	-- off it), scaled the same as the stage.
	local foot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(900, 44),
		BackgroundTransparency = 1,
		ZIndex = 3,
	}, back)
	footScale = new("UIScale", {}, foot)
	tip = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 18,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextColor3 = FAINT,
		ZIndex = 10,
	}, foot)
	fades(tip :: TextLabel, "TextTransparency", 0)
	fit()
	screen.Parent = playerGui
	return screen
end

local function apply()
	for _, entry in faded do
		(entry.Object :: any)[entry.Property] = entry.Base + (1 - entry.Base) * (1 - alpha)
	end
	if blocker then
		blocker.Active = alpha > 0.5
	end
end

local function nextTip()
	tipIndex = tipIndex % #LoadingScreen.Tips + 1
	if tip then
		tip.Text = "TIP  ·  " .. LoadingScreen.Tips[tipIndex]
	end
end

local stepping: RBXScriptConnection? = nil
local function frame(dt: number)
	local now = os.clock()
	local wanted, says = LoadingScreen.wanted(covers, now)
	-- Covers that are done are dropped.
	for i = #covers, 1, -1 do
		local cover = covers[i]
		if now >= cover.Since + cover.Max or (cover.Released and now >= cover.Since + cover.Min) then
			table.remove(covers, i)
		end
	end
	if wanted then
		local fadeIn = LoadingScreen.FadeIn
		for _, cover in covers do
			fadeIn = cover.FadeIn
		end
		alpha = if fadeIn <= 0 then 1 else math.min(1, alpha + dt / fadeIn)
	else
		alpha = math.max(0, alpha - dt / LoadingScreen.FadeOut)
	end
	apply()
	if status and says then
		status.Text = string.upper(says)
	end
	for _, star in stars do
		star.Frame.BackgroundTransparency = 1
			- (1 - (0.35 + 0.55 * (0.5 + 0.5 * math.sin(now * star.Speed + star.Offset)))) * alpha
	end
	if gem then
		gem.Rotation = 45 + (now * 90) % 360
		local pulse = 1 + 0.08 * math.sin(now * 4)
		gem.Size = UDim2.fromOffset(46 * pulse, 46 * pulse)
	end
	if fill and shimmer then
		if bar then
			fill.Size = UDim2.fromScale(math.clamp(bar, 0, 1), 1)
			shimmer.Visible = false
		else
			fill.Size = UDim2.fromScale(0, 1)
			shimmer.Visible = true
			shimmer.Position = UDim2.fromScale(((now * 0.6) % 1.4) - 0.28, 0)
		end
	end
	if now >= tipAt then
		tipAt = now + LoadingScreen.TipSeconds
		nextTip()
	end
	if not wanted and alpha <= 0 then
		if gui then
			gui.Enabled = false
		end
		bar = nil
		if stepping then
			stepping:Disconnect()
			stepping = nil
		end
	end
end

local function show()
	if not gui then
		gui = build()
	end
	(gui :: ScreenGui).Enabled = true
	if not stepping then
		stepping = RunService.RenderStepped:Connect(frame)
	end
end

function LoadingScreen.cover(reason: string, options: { [string]: any }?): Cover
	local o = options or {}
	local cover = {
		Reason = reason,
		Status = o.Status,
		Since = os.clock(),
		Min = o.Min or LoadingScreen.Min,
		Max = o.Max or LoadingScreen.Max,
		FadeIn = if o.Instant then 0 else (o.FadeIn or LoadingScreen.FadeIn),
		Released = false,
	} :: any
	function cover.release()
		cover.Released = true
	end
	function cover.status(text: string)
		cover.Status = text
	end
	table.insert(covers, cover)
	show()
	if o.Instant then
		alpha = 1
		apply()
		if status and cover.Status then
			status.Text = string.upper(cover.Status)
		end
	end
	if tipAt == 0 then
		tipAt = os.clock() + LoadingScreen.TipSeconds
		nextTip()
	end
	return cover
end

function LoadingScreen.progress(fraction: number?)
	bar = fraction
end

function LoadingScreen.active(): boolean
	return (LoadingScreen.wanted(covers, os.clock()))
end

function LoadingScreen.covered(): boolean
	return alpha >= 1
end

local function waitFor(condition: () -> boolean, timeout: number?)
	local deadline = os.clock() + (timeout or 30)
	while not condition() and os.clock() < deadline do
		task.wait()
	end
end

function LoadingScreen.waitCovered(timeout: number?)
	waitFor(function()
		return alpha >= 1 or not LoadingScreen.active()
	end, timeout or 2)
end

function LoadingScreen.waitClear(timeout: number?)
	waitFor(function()
		return alpha <= 0 and not LoadingScreen.active()
	end, timeout)
end

return LoadingScreen
