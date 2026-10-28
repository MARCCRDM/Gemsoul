-- Small helpers so every Saga Miners screen shares the same look.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MobileLayout = require(script.Parent.MobileLayout)
local UiSound = require(script.Parent.UiSound)

local UiKit = {}

UiKit.Colors = {
	Background = Color3.fromRGB(12, 10, 25),
	Row = Color3.fromRGB(36, 29, 52),
	Text = Color3.fromRGB(235, 242, 249),
	Dim = Color3.fromRGB(153, 172, 191),
	Accent = Color3.fromRGB(58, 203, 233),
	Gold = Color3.fromRGB(255, 202, 91),
	Bad = Color3.fromRGB(255, 90, 90),
}
local K = UiKit.Colors

-- A short screen: a phone on its side. Windows lay out shorter for it.
-- Judged by the screen's shorter side, so a phone counts either way up:
-- the game turns phones sideways (first.Orientation), but screens built as
-- it starts can see it still upright for a moment, tall and narrow, and
-- would lay out for a computer, shrunk to a third. (Before the camera
-- knows the screen, a touch screen without a keyboard counts as one.)
UiKit.PhoneSide = 500
function UiKit.short(): boolean
	local camera = workspace.CurrentCamera
	-- (pcall: a stand-in camera in tests may have no screen size)
	local ok, size = pcall(function()
		return if camera then camera.ViewportSize else Vector2.zero
	end)
	if not ok or size.Y <= 2 then
		local found, touch = pcall(function()
			local input = game:GetService("UserInputService")
			return input.TouchEnabled and not input.KeyboardEnabled
		end)
		return found and touch
	end
	return math.min(size.X, size.Y) < UiKit.PhoneSide
end

-- Roblox's own buttons along the top of the screen: the Roblox button, then
-- its menu, chat and voice, on the left. GuiService.TopbarInset is the rest
-- of that strip: Min.X is where those buttons end, Max.Y how tall it is. It
-- reads empty for a moment after our screens are built, until Roblox has
-- drawn them, so until then we assume the usual size; anything laid out
-- around them listens for the real one (UiKit.onTopbar).
local ASSUMED_TOP, ASSUMED_LEFT = 58, 290
local reservedRight = 0 -- (our own button at the strip's right end: DEV)
local listeners = {}
local watching = false

-- The strip on a screen `width` wide: its height, where Roblox's buttons on
-- the left end, and where its free part ends on the right.
function UiKit.topbar(width: number): (number, number, number)
	-- (read whole, in a pcall: a screen must never fail to build over this)
	local ok, height, ends, free = pcall(function()
		local bar = game:GetService("GuiService").TopbarInset
		return bar.Max.Y, bar.Min.X, bar.Max.X
	end)
	local top, left, right = ASSUMED_TOP, ASSUMED_LEFT, width
	if ok and type(height) == "number" and height > 0 then
		top, left = height, ends
		if free > ends then
			right = math.min(width, free)
		end
	end
	return top, left, right - reservedRight
end

local function topbarChanged()
	for _, fn in listeners do
		task.spawn(fn)
	end
end

-- Calls `fn` whenever the strip changes: Roblox draws its buttons, opens or
-- closes its menu, or our own button at its end comes or goes. Returns a
-- function that stops it.
function UiKit.onTopbar(fn: () -> ()): () -> ()
	table.insert(listeners, fn)
	if not watching then
		watching = true
		pcall(function()
			game:GetService("GuiService"):GetPropertyChangedSignal("TopbarInset"):Connect(topbarChanged)
		end)
	end
	return function()
		local at = table.find(listeners, fn)
		if at then
			table.remove(listeners, at)
		end
	end
end

-- Keeps `width` at the strip's right end for our own button (DEV).
function UiKit.reserveTopbar(width: number)
	reservedRight = width
	topbarChanged()
end

-- A box centred on a screen that ignores the top bar's inset. A big box
-- reaches the top, under Roblox's buttons there (or our DEV button), so it
-- moves beside them or shrinks to fit below them, whichever leaves it bigger.
-- `size` is the box as already scaled to fit. Returns a further scale (1 or
-- less) and the box's Position for an AnchorPoint of 0.5, 0.5. Whatever uses
-- it calls it again on UiKit.onTopbar.
function UiKit.clearTopbar(screen: Vector2, size: Vector2): (number, UDim2)
	local centre = UDim2.fromScale(0.5, 0.5)
	if screen.Y <= 0 then
		return 1, centre
	end
	local top, left, right = UiKit.topbar(screen.X)
	left += 8
	right -= 8
	-- Clear already: below the strip, or between the buttons at its ends.
	local edge = (screen.X - size.X) / 2
	if (screen.Y - size.Y) / 2 >= top or (edge >= left and screen.X - edge <= right) then
		return 1, centre
	end
	-- Beside: between the buttons on the left and any on the right.
	local beside = math.min(1, (right - left) / size.X)
	-- Below: from the bar down to the screen's edge.
	local below = math.min(1, (screen.Y - top - 8) / size.Y)
	if beside >= below then
		local half = size.X * beside / 2
		local x = math.clamp(screen.X / 2, left + half, math.max(left + half, right - half))
		return beside, UDim2.new(0.5, x - screen.X / 2, 0.5, 0)
	end
	return below, UDim2.new(0.5, 0, 0.5, (top - 8) / 2)
end

-- The screens that cover the play view (by their ScreenGui's name): the
-- Inventory, the Store, the big windows. What sits over the play view steps
-- aside while one is up: PartyUI's teammate bars, SocialUI's queue tab (on a
-- phone it sat on the Store's coins and its close button).
UiKit.Covers = {
	Dashboard = true, Shop = true, Season = true, AugmentTree = true, SurgeArray = true,
	Social = true, WelcomeBundle = true, Welcome = true, Intro = true, Tutorial = true,
	MarketBoard = true, ChallengeChooser = true, Character = true, Party = true,
	Referral = true, TopPlayers = true, EquipmentTrade = true, KaijuPanel = true,
	Rift = true, Guide = true, GemPouch = true, KaijuRoll = true, KaijuPit = true,
	KennelSale = true,
}
local coverWatch = nil -- { Up = { [ScreenGui]: true }, Listeners = { fn } }
-- Calls `fn(covered)` now, and again each time one of them opens or closes.
function UiKit.watchCovers(fn: (boolean) -> ())
	if not coverWatch then
		local watch = { Up = {}, Listeners = {} }
		coverWatch = watch
		local function tell()
			local covered = next(watch.Up) ~= nil
			for _, listener in watch.Listeners do
				task.spawn(listener, covered)
			end
		end
		local function follow(screen: Instance)
			if not screen:IsA("ScreenGui") or not UiKit.Covers[screen.Name] then
				return
			end
			local function update()
				local up = if screen.Parent and screen.Enabled then true else nil
				if watch.Up[screen] ~= up then
					watch.Up[screen] = up
					tell()
				end
			end
			screen:GetPropertyChangedSignal("Enabled"):Connect(update)
			screen.AncestryChanged:Connect(update)
			update()
		end
		local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
		playerGui.ChildAdded:Connect(follow)
		for _, screen in playerGui:GetChildren() do
			follow(screen)
		end
	end
	table.insert(coverWatch.Listeners, fn)
	fn(next(coverWatch.Up) ~= nil)
end

function UiKit.gui(name: string, order: number?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order or 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- Just right of the kaiju card (bottom left: Client.KaijuHud), in `gui`'s
-- own offsets: its left edge and its bottom, for a button docked beside it
-- (the X kit switch, the KIT OUT bar). nil while the card isn't up.
function UiKit.besideKaiju(gui: LayerCollector): Vector2?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("KaijuHud")
	local card = hud and hud:FindFirstChild("KaijuCard")
	if not (hud and hud:IsA("ScreenGui") and hud.Enabled and card and card:IsA("GuiObject") and card.Visible) then
		return nil
	end
	if card.AbsoluteSize.X < 1 then
		return nil
	end
	local origin = gui.AbsolutePosition
	return Vector2.new(
		card.AbsolutePosition.X + card.AbsoluteSize.X + 14 - origin.X,
		card.AbsolutePosition.Y + card.AbsoluteSize.Y - origin.Y
	)
end

function UiKit.round(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

-- One line at its own size, or smaller when the text doesn't fit (a
-- translation can run longer than the English).
function UiKit.fit(label: TextLabel): TextLabel
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = label.TextSize
	limit.Parent = label
	label.TextScaled = true
	return label
end

-- A row laid out by `list` (side by side) shrinks to the width of the row's
-- parent when its contents grow past it (a longer translation, say), and
-- returns to full size when they fit.
function UiKit.shrinkRow(row: GuiObject, list: UIListLayout)
	local parent = row.Parent :: GuiObject
	local scale = Instance.new("UIScale")
	scale.Parent = row
	local function fit()
		-- (the content's size includes this scale: undo it for its own width)
		local natural = list.AbsoluteContentSize.X / scale.Scale
		local room = parent.AbsoluteSize.X
		if natural > 0 and room > 0 then
			scale.Scale = math.min(1, room / natural)
		end
	end
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

function UiKit.pad(parent: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = parent
end

function UiKit.list(parent: GuiObject, gap: number, horizontal: boolean?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	if horizontal then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	layout.Parent = parent
	return layout
end

-- A dark rounded panel with a glowing outline.
function UiKit.panel(parent: Instance, accent: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = K.Background
	frame.BackgroundTransparency = 0.06
	frame.Parent = parent
	UiKit.round(frame)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Thickness = 1
	stroke.Transparency = 0.55
	stroke.Color = accent or K.Accent
	stroke.Parent = frame
	return frame
end

function UiKit.text(parent: Instance, text: string, size: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = font or Enum.Font.Gotham
	label.TextSize = size
	label.TextColor3 = color or K.Text
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

function UiKit.button(parent: Instance, text: string, color: Color3?, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.AutomaticSize = Enum.AutomaticSize.XY
	button.BackgroundColor3 = K.Row
	button.Font = Enum.Font.Gotham
	button.TextSize = 18
	button.TextColor3 = color or K.Text
	button.Text = text
	button.Parent = parent
	UiKit.round(button, 6)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = button
	button.Activated:Connect(onClick)
	return button
end

-- A colour chip for a gem: its colour, a two-tone gradient for fusion
-- stones, or a shifting rainbow for prismatic ones.
function UiKit.swatch(parent: Instance, shade: { [string]: any }, size: number): Frame
	local chip = Instance.new("Frame")
	chip.Size = UDim2.fromOffset(size, size)
	chip.BackgroundColor3 = if shade.Color2 or shade.Prismatic then Color3.new(1, 1, 1) else shade.Color
	chip.Rotation = 45
	chip.Parent = parent
	UiKit.round(chip, 4)
	if shade.Color2 then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(shade.Color, shade.Color2)
		gradient.Parent = chip
	elseif shade.Prismatic then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, shade.Color),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(80, 200, 255)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 80, 220)),
			ColorSequenceKeypoint.new(1, shade.Color),
		})
		gradient.Parent = chip
		TweenService:Create(gradient, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
			Rotation = 360,
		}):Play()
	end
	return chip
end

-- Toasts: short messages that stack at the top of the screen and fade out.
local toastGui: ScreenGui? = nil
local toastHolder: Frame? = nil
local toastCount = 0
local toastListeners: { () -> () } = {}

-- Hears when the toasts' height changes (one comes or goes, or wraps).
function UiKit.onToastMoved(listener: () -> ())
	table.insert(toastListeners, listener)
end

-- How far down the toasts reach on a phone, in a ScreenGui's space (0:
-- none up, or not a phone): the loot card sits under them (MinerLoot).
function UiKit.toastBottom(): number
	if not (toastHolder and toastGui) or toastHolder.AnchorPoint.X ~= 1 then
		return 0
	end
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			return toastHolder.AbsolutePosition.Y - toastGui.AbsolutePosition.Y + toastHolder.AbsoluteSize.Y
		end
	end
	return 0
end

-- Phones (a short landscape screen): one small toast at a time, left of
-- your coins (MobileLayout.toast: under your health on a phone too narrow
-- for that), as wide as its words, clear of the fight in the middle and
-- the thumb buttons lower down.
local function phone(): boolean
	local camera = workspace.CurrentCamera
	return game:GetService("UserInputService").TouchEnabled
		or (camera ~= nil and camera.ViewportSize.Y > 0 and camera.ViewportSize.Y < 540)
end
local TOAST_LIMIT = 3
local PHONE_TOAST_LIMIT = 1

function UiKit.toast(message: string, color: Color3?)
	if type(message) ~= "string" or message == "" then
		return
	end
	-- The same message twice in a row is one message.
	if toastHolder then
		for _, child in toastHolder:GetChildren() do
			if child:IsA("Frame") and child:GetAttribute("Message") == message then
				return
			end
		end
	end
	UiSound.play(if UiSound.isAlert(color) then "Error" else "Notify")
	if not toastHolder then
		toastGui = UiKit.gui("Toasts", 20)
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0)
		holder.Position = UDim2.new(0.5, 0, 0, 56)
		holder.Size = UDim2.new(0.9, 0, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.Parent = toastGui
		local layout = UiKit.list(holder, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			for _, listener in toastListeners do
				task.spawn(listener)
			end
		end)
		toastHolder = holder
	end
	-- A chunky dark pill: coloured rim and edge stripe, white outlined text.
	-- It pops in, then fades and floats away.
	local accent = color or K.Gold
	local small = phone()
	local layout = toastHolder:FindFirstChildOfClass("UIListLayout")
	local screen = toastGui.AbsoluteSize
	if screen.X <= 0 then
		local camera = workspace.CurrentCamera
		screen = if camera then camera.ViewportSize else Vector2.new(844, 332)
	end
	local slot = MobileLayout.toast(screen)
	toastHolder.AnchorPoint = if small then Vector2.new(1, 0) else Vector2.new(0.5, 0)
	toastHolder.Position = if small then UDim2.fromOffset(slot.X + slot.W, slot.Y) else UDim2.new(0.5, 0, 0, 12)
	toastHolder.Size = if small then UDim2.fromOffset(slot.W, 0) else UDim2.new(0.9, 0, 0, 0)
	if layout then
		layout.HorizontalAlignment = if small then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Center
	end
	-- Only the newest few stay; the oldest goes first.
	local shown = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(shown, child)
		end
	end
	table.sort(shown, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #shown - ((if small then PHONE_TOAST_LIMIT else TOAST_LIMIT) - 1) do
		shown[i]:Destroy()
	end
	toastCount += 1
	local toast = Instance.new("Frame")
	toast.AutomaticSize = Enum.AutomaticSize.XY
	toast.Size = UDim2.fromOffset(0, 0)
	toast.BackgroundColor3 = Color3.new(1, 1, 1)
	toast.LayoutOrder = toastCount
	toast:SetAttribute("Message", message)
	toast.Parent = toastHolder
	UiKit.round(toast, 14)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(K.Row, K.Background)
	shade.Parent = toast
	local rim = Instance.new("UIStroke")
	rim.Color = accent
	rim.Thickness = 1
	rim.Transparency = 0.5
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = toast
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, if small then 6 else 10)
	padding.PaddingBottom = UDim.new(0, if small then 6 else 10)
	padding.PaddingLeft = UDim.new(0, if small then 18 else 26)
	padding.PaddingRight = UDim.new(0, if small then 12 else 18)
	padding.Parent = toast
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(if small then slot.W else 620, math.huge)
	constraint.Parent = toast
	local stripe = Instance.new("Frame")
	stripe.BackgroundColor3 = accent
	stripe.Position = UDim2.new(0, if small then -12 else -18, 0, -2)
	stripe.Size = UDim2.new(0, 6, 1, 4)
	stripe.Parent = toast
	UiKit.round(stripe, 3)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(0, 0)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Font = Enum.Font.GothamMedium
	label.TextSize = if small then 12 else 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = message
	label.TextWrapped = small
	if small then
		-- (as wide as its words, wrapping past the toast's place; the
		-- translated words, too, as the translator sets them)
		label.TextXAlignment = Enum.TextXAlignment.Left
		local wrap = Instance.new("UISizeConstraint")
		wrap.MaxSize = Vector2.new(slot.W - 30, math.huge)
		wrap.Parent = label
	end
	label.Parent = toast
	local ink = Instance.new("UIStroke")
	ink.Color = Color3.fromRGB(12, 8, 18)
	ink.Thickness = 1
	ink.Transparency = 1
	ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ink.Parent = label
	local pop = Instance.new("UIScale")
	pop.Scale = 0.6
	pop.Parent = toast
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	task.delay(if small then 3 else 4, function()
		if not toast.Parent then
			return
		end
		local fade = TweenInfo.new(0.5)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stripe, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(ink, fade, { Transparency = 1 }):Play()
		TweenService:Create(rim, fade, { Transparency = 1 }):Play()
		TweenService:Create(pop, fade, { Scale = 0.9 }):Play()
		task.wait(0.5)
		toast:Destroy()
	end)
end

return UiKit
