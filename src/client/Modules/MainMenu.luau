--[[
	The main menu, on the title screen (Client Splash) once its intro has
	played: two matching panels side by side.

	  left    the logo, PLAY (Enter / A too), then GUIDE, UPDATES, FEEDBACK
	          and CREDITS, the version and SETTINGS along the bottom
	  right   the banners (Shared.MainMenuContent), one at a time, on by
	          themselves every SlideSeconds (held a while after a touch):
	          its picture, tag, words and button, arrows and dots; or a page
	          (GUIDE, UPDATES, FEEDBACK, CREDITS) with a BACK

	A banner's button: a code redeemed there and then (its answer where its
	words were), a page, or (Bounty, Ranked, Booth) in, and then the bounty
	board, the PLAY picker, or arrows to the DEV booth, once you're standing
	in the Outpost (not in the middle of the intro).

	A desk screen's layout is drawn for 1600 x 900 and a phone's for
	844 x 390, each scaled to fit (UIScale).

	  MainMenu.build(parent, { OnPlay = fn }) -> menu
	    menu.Root                 its frame
	    menu.show(index)          that banner
	    menu.page(name?)          GUIDE / UPDATES / FEEDBACK / CREDITS, nil: the banners
	    menu.destroy()
	  MainMenu.layout(screen) -> "Desk" | "Phone", scale     (pure)
	  MainMenu.after(action)      runs a banner's in-game action once in
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Content = require(ReplicatedStorage.Shared.MainMenuContent)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new

local MainMenu = {}

MainMenu.SlideSeconds = 6
MainMenu.HoldAfterTouch = 12 -- (seconds the banners stay put after you touch them)
MainMenu.LogoId = 123729911771910 -- (the title art: Client Splash's)

local GOLD = Color3.fromRGB(255, 202, 91)
local GOLD_DARK = Color3.fromRGB(214, 150, 40)
local INK = Color3.fromRGB(10, 12, 20)
local PANEL = Color3.fromRGB(10, 12, 20)
local BUTTON = Color3.fromRGB(22, 26, 38)
local EDGE = Color3.fromRGB(70, 78, 98)
local TEXT = Color3.fromRGB(240, 244, 250)
local DIM = Color3.fromRGB(170, 176, 190)
local FAINT = Color3.fromRGB(120, 126, 140)
local GOOD = Color3.fromRGB(96, 236, 170)
local BAD = Color3.fromRGB(255, 120, 110)

-- The two layouts, in their own pixels (scaled to fit).
local LAYOUTS = {
	Desk = {
		W = 1600, H = 900, Top = 110, Bottom = 790, Side = 100, Gap = 40, Inset = 60,
		Logo = 300, LogoTop = -20, PlayTop = 300, Play = 92, PlayText = 34, Caption = 16,
		Grid = 56, GridGap = 16, GridText = 21, Foot = 14,
		Pad = 14, ArtShare = 0.55, Tag = 16, Title = 36, Line = 19, Button = 46, ButtonText = 18,
		Dot = 12, Radius = 20, PageTitle = 28, PageText = 18, PageHead = 22,
	},
	Phone = {
		W = 844, H = 390, Top = 30, Bottom = 360, Side = 44, Gap = 16, Inset = 20,
		Logo = 120, LogoTop = -10, PlayTop = 100, Play = 52, PlayText = 22, Caption = 11,
		Grid = 36, GridGap = 8, GridText = 14, Foot = 11,
		Pad = 8, ArtShare = 0.5, Tag = 11, Title = 20, Line = 12, Button = 30, ButtonText = 12,
		Dot = 9, Radius = 14, PageTitle = 18, PageText = 12, PageHead = 14,
	},
}
MainMenu.Layouts = LAYOUTS

-- Which layout a screen `screen` big gets, and how far it's scaled.
function MainMenu.layout(screen: Vector2, touch: boolean?): (string, number)
	local short = math.min(screen.X, screen.Y)
	local name = if short < 560 or (touch and short < 700) then "Phone" else "Desk"
	local L = LAYOUTS[name]
	local scale = math.min(screen.X / L.W, screen.Y / L.H)
	return name, math.clamp(scale, 0.3, 1.6)
end

local function round(object: GuiObject, radius: number)
	UiKit.round(object, radius)
end
local function stroke(object: GuiObject, color: Color3, thickness: number, transparency: number?)
	return new("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0 }, object)
end
local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?, props: { [string]: any }?): TextLabel
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}, parent)
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	return l
end

-- How wide `text` is in `font` at `size` (buttons are sized to their words
-- by hand: AutomaticSize on a padded TextButton came out zero wide).
local function widthOf(text: string, size: number, font: Enum.Font): number
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(2000, 200))
	end)
	if ok and typeof(bounds) == "Vector2" then
		return math.ceil(bounds.X)
	end
	return math.ceil(#text * size * 0.68)
end
MainMenu.widthOf = widthOf

-- A banner's tag: its live one (the DEV desk lit) or its own.
local function tagOf(banner): string
	if banner.Live == "DevOnline" then
		local desk = workspace:FindFirstChild("DevDesk", true)
		if desk and desk:GetAttribute("DevOnline") == true then
			return banner.LiveTag or banner.Tag
		end
	end
	return banner.Tag
end
MainMenu.tagOf = tagOf

-- In-game actions, once you're in (the loading screen gone, standing in
-- the Outpost, the intro done): the bounty board, the PLAY picker, the
-- way to the DEV booth.
local pendingAfter = nil
function MainMenu.after(action)
	pendingAfter = action
	task.spawn(function()
		local LoadingFlow = require(script.Parent.LoadingFlow)
		task.wait(1)
		LoadingFlow.waitClear(60)
		task.wait(0.5)
		if pendingAfter ~= action then
			return
		end
		pendingAfter = nil
		local profile = GemClient.Profile
		local intro = profile and profile.Intro
		if intro and not intro.Done then
			return -- (still in the intro: it leads the way)
		end
		pcall(function()
			if action.Kind == "Bounty" then
				require(script.Parent.RiftClient).openGate("Bounty")
			elseif action.Kind == "Ranked" then
				require(script.Parent.LobbyUI).openPicker()
			elseif action.Kind == "Booth" then
				local desk = workspace:FindFirstChild("DevDesk", true)
				local at = desk and (if desk:IsA("Model") then desk:GetPivot().Position else nil)
				if not at and desk then
					local part = desk:FindFirstChildWhichIsA("BasePart", true)
					at = part and part.Position
				end
				if at then
					local GroundGuide = require(script.Parent.GroundGuide)
					local until_ = os.clock() + 120
					GroundGuide.set("MenuBooth", function()
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if os.clock() > until_ or (root and (root.Position - at).Magnitude < 14) then
							task.defer(GroundGuide.clear, "MenuBooth")
							return nil
						end
						return at
					end, 5)
				end
			end
		end)
	end)
end

function MainMenu.build(parent: GuiObject, options: { [string]: any })
	local onPlay: () -> () = options.OnPlay or function() end
	local connections = {}
	local alive = true
	local menu: { [string]: any } = {}

	local root = new("Frame", {
		Name = "MainMenu",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 20,
	}, parent)
	local scaler = new("UIScale", { Scale = 1 }, root)
	menu.Root = root

	local banners = Content.live(os.time())
	local current = 1
	local heldUntil = 0
	local openPage: string? = nil

	-- Everything below is drawn for one layout; a screen that changes
	-- layout (a phone turned, a window resized across) draws it again.
	local drawn: string? = nil
	local slideParts: { [string]: any } = {}
	local pageFrame: Frame? = nil
	local slideFrame: Frame? = nil
	local playButton: TextButton? = nil
	local draw: () -> ()

	local function hold()
		heldUntil = os.clock() + MainMenu.HoldAfterTouch
	end

	-- A banner's button, by its Action.
	local function message(text: string, color: Color3)
		local line = slideParts.Line
		if line then
			line.Text = text
			line.TextColor3 = color
		end
	end
	local function redeem(code: string)
		hold()
		message("Redeeming " .. code .. "...", DIM)
		task.spawn(function()
			local ok, result = pcall(GemClient.request, "RedeemCode", code)
			if not alive then
				return
			end
			if ok and type(result) == "table" then
				message(result.Message or (if result.Ok then "Redeemed!" else "That didn't work."), if result.Ok then GOOD else BAD)
			else
				message("Couldn't reach the server. Try again in a moment.", BAD)
			end
		end)
	end
	local function act(banner)
		local action = banner.Action or {}
		if action.Kind == "Redeem" and action.Code then
			redeem(action.Code)
		elseif action.Kind == "Page" then
			menu.page(action.Page)
		elseif action.Kind == "Bounty" or action.Kind == "Ranked" or action.Kind == "Booth" then
			MainMenu.after(action)
			onPlay()
		end
	end

	-- The banner at `index`, into the right panel.
	local function show(index: number)
		if #banners == 0 then
			return
		end
		current = ((index - 1) % #banners) + 1
		local banner = banners[current]
		local p = slideParts
		if not p.Title then
			return
		end
		local id = Content.Images[banner.Id] or 0
		p.Picture.Image = if id ~= 0 then "rbxassetid://" .. id else ""
		p.Fallback.Visible = id == 0
		p.FallbackWord.Text = banner.Tag
		p.FallbackGlow.BackgroundColor3 = banner.TagColor
		local L = LAYOUTS[drawn or "Desk"]
		p.Tag.Text = tagOf(banner)
		p.TagBack.Size = UDim2.fromOffset(widthOf(p.Tag.Text, L.Tag, Enum.Font.GothamBlack) + 26, L.Tag + 14)
		p.TagBack.BackgroundColor3 = banner.TagColor
		p.Title.Text = banner.Title
		p.Line.Text = if drawn == "Phone" then banner.Short or banner.Line else banner.Line
		p.Line.TextColor3 = DIM
		-- (several codes: a button for each; else the banner's own button)
		local codes = Content.codesOf(banner, os.time())
		local several = #codes > 1
		p.Button.Visible = not several
		p.Button.Text = string.upper(banner.Button or "") .. "  ›"
		p.Button.Size = UDim2.fromOffset(widthOf(p.Button.Text, L.ButtonText, Enum.Font.GothamBlack) + 48, L.Button)
		for i, chip in p.Chips do
			chip.Visible = several and codes[i] ~= nil
			chip.Text = codes[i] or ""
			chip.Size = UDim2.fromOffset(widthOf(chip.Text, L.ButtonText, Enum.Font.GothamBlack) + 30, L.Button)
		end
		for i, dot in p.Dots do
			dot.Visible = i <= #banners
			dot.BackgroundColor3 = if i == current then GOLD else EDGE
		end
		-- (a soft fade in)
		p.Picture.ImageTransparency = 1
		TweenService:Create(p.Picture, TweenInfo.new(0.35), { ImageTransparency = 0 }):Play()
	end
	menu.show = show

	-- The left panel and the right one's frame, for the current layout.
	draw = function()
		local screen = parent.AbsoluteSize
		local name, scale = MainMenu.layout(screen, UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		scaler.Scale = scale
		if name == drawn then
			return
		end
		drawn = name
		local L = LAYOUTS[name]
		IronUi.clear(root) -- (keeps the UIScale)
		root.Size = UDim2.fromOffset(L.W, L.H)
		table.clear(slideParts)
		local colW = math.floor((L.W - 2 * L.Side - L.Gap) / 2)
		local height = L.Bottom - L.Top
		local function panel(x: number, nameOf: string): Frame
			local f = new("Frame", {
				Name = nameOf,
				Position = UDim2.fromOffset(x, L.Top),
				Size = UDim2.fromOffset(colW, height),
				BackgroundColor3 = PANEL,
				BackgroundTransparency = 0.08,
				ZIndex = 20,
			}, root)
			round(f, L.Radius)
			stroke(f, GOLD, 2, 0.75)
			return f
		end

		-- Left: logo, PLAY, the four, the version and SETTINGS.
		local left = panel(L.Side, "Menu")
		new("ImageLabel", {
			Name = "Logo",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, L.LogoTop),
			Size = UDim2.fromOffset(L.Logo, L.Logo),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. MainMenu.LogoId,
			ResampleMode = Enum.ResamplerMode.Pixelated,
			ZIndex = 21,
		}, left)
		local inner = colW - 2 * L.Inset
		local play = new("TextButton", {
			Name = "Play",
			Position = UDim2.fromOffset(L.Inset, L.PlayTop),
			Size = UDim2.fromOffset(inner, L.Play),
			BackgroundColor3 = GOLD,
			AutoButtonColor = true,
			Font = Enum.Font.GothamBlack,
			Text = "PLAY",
			TextSize = L.PlayText,
			TextColor3 = INK,
			ZIndex = 22,
		}, left)
		round(play, 14)
		local lip = new("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = GOLD_DARK,
			ZIndex = 21,
		}, play)
		round(lip, 6)
		play:SetAttribute("UiSound", "Open")
		play.Activated:Connect(function()
			onPlay()
		end)
		IronUi.juice(play, 1.03, 0.97)
		-- (a slow breath, so the eye finds it)
		IronUi.animate(play, function(t)
			play.BackgroundColor3 = GOLD:Lerp(Color3.fromRGB(255, 226, 150), (math.sin(t * 2.4) + 1) / 2 * 0.35)
		end)
		playButton = play
		if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
			local key = label(play, "ENTER", math.floor(L.Foot * 0.9), INK, Enum.Font.GothamBold, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 8),
				Size = UDim2.fromOffset(60, L.Foot + 6),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 23,
			})
			round(key, 5)
			stroke(key, INK, 1, 0.3)
		end
		local captionText = "Into the Outpost"
		label(left, captionText, L.Caption, DIM, Enum.Font.GothamMedium, {
			Name = "Caption",
			Position = UDim2.fromOffset(0, L.PlayTop + L.Play + 8),
			Size = UDim2.new(1, 0, 0, L.Caption + 4),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 21,
		})
		local gridTop = L.PlayTop + L.Play + L.Caption + 24
		local bw = math.floor((inner - L.GridGap) / 2)
		for i, entry in { { "GUIDE", "Guide" }, { "UPDATES", "Updates" }, { "FEEDBACK", "Feedback" }, { "CREDITS", "Credits" } } do
			local col, row = (i - 1) % 2, (i - 1) // 2
			local b = new("TextButton", {
				Name = entry[2],
				Position = UDim2.fromOffset(L.Inset + col * (bw + L.GridGap), gridTop + row * (L.Grid + L.GridGap)),
				Size = UDim2.fromOffset(bw, L.Grid),
				BackgroundColor3 = BUTTON,
				AutoButtonColor = true,
				Font = Enum.Font.GothamBlack,
				Text = entry[1],
				TextSize = L.GridText,
				TextColor3 = TEXT,
				ZIndex = 22,
			}, left)
			round(b, 12)
			stroke(b, EDGE, 2)
			b:SetAttribute("UiSound", "Open")
			b.Activated:Connect(function()
				menu.page(entry[2])
			end)
			IronUi.juice(b, 1.03, 0.97)
		end
		local foot = height - L.Foot - 26
		label(left, Content.version(Config.Playtest and Config.Playtest.Build), L.Foot, FAINT, Enum.Font.GothamMedium, {
			Name = "Version",
			Position = UDim2.fromOffset(L.Inset, foot),
			Size = UDim2.fromOffset(inner / 2, L.Foot + 4),
			ZIndex = 21,
		})
		local settings = new("TextButton", {
			Name = "Settings",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(L.Inset + inner, foot - 6),
			Size = UDim2.fromOffset(110, L.Foot + 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "SETTINGS",
			TextSize = L.Foot,
			TextColor3 = DIM,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 22,
		}, left)
		settings.Activated:Connect(function()
			pcall(function()
				local SettingsUI = require(script.Parent.SettingsUI)
				SettingsUI.open()
				-- (over the title screen while it's up)
				local window = player.PlayerGui:FindFirstChild("Settings")
				if window and window:IsA("ScreenGui") then
					window.DisplayOrder = math.max(window.DisplayOrder, 600)
				end
			end)
		end)

		-- Right: the banners, and the pages in their place.
		local right = panel(L.Side + colW + L.Gap, "Slides")
		right.ClipsDescendants = true
		local slide = new("Frame", { Name = "Slide", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21 }, right)
		slideFrame = slide
		local artH = math.floor(height * L.ArtShare)
		local art = new("Frame", {
			Name = "Art",
			Position = UDim2.fromOffset(L.Pad, L.Pad),
			Size = UDim2.new(1, -2 * L.Pad, 0, artH),
			BackgroundColor3 = Color3.fromRGB(16, 18, 30),
			ClipsDescendants = true,
			ZIndex = 21,
		}, slide)
		round(art, L.Radius - 6)
		local fallback = new("Frame", { Name = "Fallback", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21 }, art)
		local glow = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(1.2, 1.4),
			BackgroundColor3 = GOLD,
			BackgroundTransparency = 0.55,
			ZIndex = 21,
		}, fallback)
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
		}, glow)
		local word = label(fallback, "", L.Title * 2, TEXT, Enum.Font.GothamBlack, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTransparency = 0.82,
			ZIndex = 22,
		})
		local picture = new("ImageLabel", {
			Name = "Picture",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Fit, -- (whole: a phone's box is wider than the pictures)
			ZIndex = 23,
		}, art)
		local tagBack = new("Frame", {
			Name = "Tag",
			Position = UDim2.fromOffset(L.Pad + 14, L.Pad + 14),
			Size = UDim2.fromOffset(100, L.Tag + 14),
			BackgroundColor3 = GOLD,
			ZIndex = 24,
		}, slide)
		round(tagBack, 8)
		local tag = label(tagBack, "", L.Tag, INK, Enum.Font.GothamBlack, {
			Size = UDim2.fromScale(1, 1),
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 25,
		})
		-- (the arrows, over the picture's sides)
		for side, step in { [0] = -1, [1] = 1 } do
			local arrow = new("TextButton", {
				Name = if step < 0 then "Back" else "Next",
				AnchorPoint = Vector2.new(side, 0.5),
				Position = UDim2.new(side, if step < 0 then L.Pad + 6 else -L.Pad - 6, 0, L.Pad + artH / 2),
				Size = UDim2.fromOffset(math.floor(L.Title * 0.75), math.floor(L.Title * 1.4)),
				BackgroundColor3 = INK,
				BackgroundTransparency = 0.25,
				Font = Enum.Font.GothamBlack,
				Text = if step < 0 then "‹" else "›",
				TextSize = math.floor(L.Title * 0.9),
				TextColor3 = TEXT,
				ZIndex = 26,
			}, slide)
			round(arrow, 8)
			arrow.Activated:Connect(function()
				hold()
				show(current + step)
			end)
		end
		local textTop = L.Pad + artH + math.floor(L.Title * 0.6)
		local textLeft = L.Pad + 14
		local title = label(slide, "", L.Title, TEXT, Enum.Font.GothamBlack, {
			Name = "Title",
			Position = UDim2.fromOffset(textLeft, textTop),
			Size = UDim2.new(1, -2 * textLeft, 0, L.Title + 6),
			TextWrapped = false,
			TextScaled = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 22,
		})
		local line = label(slide, "", L.Line, DIM, Enum.Font.GothamMedium, {
			Name = "Line",
			Position = UDim2.fromOffset(textLeft, textTop + L.Title + 14),
			Size = UDim2.new(1, -2 * textLeft, 0, L.Line * 3 + 8),
			ZIndex = 22,
		})
		local bottom = height - L.Pad - 14 - L.Button
		local button = new("TextButton", {
			Name = "Action",
			Position = UDim2.fromOffset(textLeft, bottom),
			Size = UDim2.fromOffset(L.Button * 4, L.Button),
			BackgroundColor3 = PANEL,
			Font = Enum.Font.GothamBlack,
			Text = "",
			TextSize = L.ButtonText,
			TextColor3 = GOLD,
			ZIndex = 22,
		}, slide)
		round(button, 10)
		stroke(button, GOLD, 2)
		button.Activated:Connect(function()
			act(banners[current])
		end)
		IronUi.juice(button, 1.03, 0.97)
		-- (a code each, when a banner has several)
		local chips = {}
		local chipRow = new("Frame", {
			Name = "Codes",
			Position = UDim2.fromOffset(textLeft, bottom),
			Size = UDim2.new(1, -2 * textLeft - 5 * (L.Dot + 12), 0, L.Button),
			BackgroundTransparency = 1,
			ZIndex = 22,
		}, slide)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 10),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, chipRow)
		for i = 1, 3 do
			local chip = new("TextButton", {
				Name = "Code" .. i,
				Size = UDim2.fromOffset(L.Button * 3, L.Button),
				BackgroundColor3 = GOLD,
				Font = Enum.Font.GothamBlack,
				Text = "",
				TextSize = L.ButtonText,
				TextColor3 = INK,
				Visible = false,
				ZIndex = 23,
			}, chipRow)
			round(chip, 10)
			chip.Activated:Connect(function()
				if chip.Text ~= "" then
					redeem(chip.Text)
				end
			end)
			chips[i] = chip
		end
		local dots = {}
		for i = 1, 8 do
			local dot = new("TextButton", {
				Name = "Dot" .. i,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(L.Pad + 14) - (8 - i) * (L.Dot + 12), 0, bottom + L.Button / 2),
				Size = UDim2.fromOffset(L.Dot, L.Dot),
				BackgroundColor3 = EDGE,
				Text = "",
				ZIndex = 22,
			}, slide)
			round(dot, L.Dot)
			dot.Activated:Connect(function()
				hold()
				show(i)
			end)
			dots[i] = dot
		end
		-- (the dots in use, packed to the right)
		local function packDots()
			local n = math.min(#banners, #dots)
			for i, dot in dots do
				local k = n - i
				dot.Position = UDim2.new(1, -(L.Pad + 14) - k * (L.Dot + 12), 0, bottom + L.Button / 2)
			end
		end
		packDots()
		slideParts = {
			Picture = picture, Fallback = fallback, FallbackWord = word, FallbackGlow = glow,
			Tag = tag, TagBack = tagBack, Title = title, Line = line, Button = button,
			Chips = chips, Dots = dots,
		}

		-- A page in the banners' place: its title, BACK, and what's on it.
		local page = new("Frame", { Name = "Page", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 21 }, right)
		pageFrame = page
		show(current)
		if openPage then
			local again = openPage
			openPage = nil
			menu.page(again)
		end
	end

	-- The pages ------------------------------------------------------------
	local function scroller(page: Frame, L): ScrollingFrame
		local s = new("ScrollingFrame", {
			Name = "List",
			Position = UDim2.fromOffset(L.Pad + 14, L.PageTitle + 44),
			Size = UDim2.new(1, -2 * (L.Pad + 14), 1, -(L.PageTitle + 44) - L.Pad - 10),
			BackgroundTransparency = 1,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = EDGE,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ZIndex = 22,
		}, page)
		new("UIListLayout", { Padding = UDim.new(0, math.floor(L.PageText * 0.6)), SortOrder = Enum.SortOrder.LayoutOrder }, s)
		return s
	end
	local function section(list: ScrollingFrame, L, order: number, head: string, lines: { string })
		label(list, head, L.PageHead, GOLD, Enum.Font.GothamBlack, {
			LayoutOrder = order * 100,
			Size = UDim2.new(1, -12, 0, L.PageHead + 6),
			ZIndex = 22,
		})
		for i, text in lines do
			label(list, "·  " .. text, L.PageText, TEXT, Enum.Font.GothamMedium, {
				LayoutOrder = order * 100 + i,
				Size = UDim2.new(1, -12, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				ZIndex = 22,
			})
		end
		new("Frame", { LayoutOrder = order * 100 + 99, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, math.floor(L.PageText * 0.6)) }, list)
	end
	local function feedbackForm(page: Frame, L)
		local kind = "Bug"
		local top = L.PageTitle + 44
		local left = L.Pad + 14
		label(page, "What's it about?", L.PageText, DIM, Enum.Font.GothamMedium, {
			Position = UDim2.fromOffset(left, top),
			Size = UDim2.new(1, -2 * left, 0, L.PageText + 6),
			ZIndex = 22,
		})
		local kinds = {}
		local function paint()
			for k, b in kinds do
				b.BackgroundColor3 = if k == kind then GOLD else BUTTON
				b.TextColor3 = if k == kind then INK else TEXT
			end
		end
		for i, entry in { { "Bug", "A BUG" }, { "Idea", "AN IDEA" } } do
			local b = new("TextButton", {
				Name = entry[1],
				Position = UDim2.fromOffset(left + (i - 1) * (L.Button * 3 + 10), top + L.PageText + 12),
				Size = UDim2.fromOffset(L.Button * 3, L.Button),
				Font = Enum.Font.GothamBlack,
				Text = entry[2],
				TextSize = L.ButtonText,
				ZIndex = 22,
			}, page)
			round(b, 10)
			stroke(b, EDGE, 2)
			b.Activated:Connect(function()
				kind = entry[1]
				paint()
			end)
			kinds[entry[1]] = b
		end
		paint()
		local boxTop = top + L.PageText + 24 + L.Button
		local box = new("TextBox", {
			Name = "Words",
			Position = UDim2.fromOffset(left, boxTop),
			Size = UDim2.new(1, -2 * left, 1, -(boxTop + L.Button + L.Pad + 40)),
			BackgroundColor3 = BUTTON,
			ClearTextOnFocus = false,
			MultiLine = true,
			Font = Enum.Font.GothamMedium,
			PlaceholderText = "Tell us what happened, or what you'd love to see...",
			PlaceholderColor3 = FAINT,
			Text = "",
			TextSize = L.PageText,
			TextColor3 = TEXT,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 22,
		}, page)
		round(box, 10)
		stroke(box, EDGE, 2)
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
		}, box)
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if #box.Text > 600 then
				box.Text = string.sub(box.Text, 1, 600)
			end
		end)
		local status = label(page, "Read by the devs. Never shown to other players.", L.PageText, FAINT, Enum.Font.GothamMedium, {
			Name = "Status",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, left + L.Button * 3 + 20, 1, -(L.Pad + 14)),
			Size = UDim2.new(1, -(2 * left + L.Button * 3 + 20), 0, L.Button),
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 22,
		})
		local send = new("TextButton", {
			Name = "Send",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, left, 1, -(L.Pad + 14)),
			Size = UDim2.fromOffset(L.Button * 3, L.Button),
			BackgroundColor3 = GOLD,
			Font = Enum.Font.GothamBlack,
			Text = "SEND",
			TextSize = L.ButtonText,
			TextColor3 = INK,
			ZIndex = 22,
		}, page)
		round(send, 10)
		local sending = false
		send.Activated:Connect(function()
			if sending then
				return
			end
			sending = true
			status.Text = "Sending..."
			status.TextColor3 = DIM
			task.spawn(function()
				local ok, result = pcall(GemClient.request, "SendFeedback", kind, box.Text)
				sending = false
				if not alive then
					return
				end
				if ok and type(result) == "table" and result.Ok then
					box.Text = ""
					status.Text = "Thanks! The devs will read it."
					status.TextColor3 = GOOD
				else
					status.Text = (ok and type(result) == "table" and result.Message) or "Couldn't send it. Try again in a moment."
					status.TextColor3 = BAD
				end
			end)
		end)
	end

	function menu.page(name: string?)
		if not pageFrame or not slideFrame then
			openPage = name
			return
		end
		local L = LAYOUTS[drawn or "Desk"]
		local page = pageFrame :: Frame
		IronUi.clear(page)
		openPage = name
		slideFrame.Visible = name == nil
		page.Visible = name ~= nil
		if not name then
			show(current)
			return
		end
		local titles = { Guide = "GUIDE", Updates = "UPDATES", Feedback = "FEEDBACK", Credits = "CREDITS" }
		label(page, titles[name] or string.upper(name), L.PageTitle, TEXT, Enum.Font.GothamBlack, {
			Name = "Title",
			Position = UDim2.fromOffset(L.Pad + 14, L.Pad + 12),
			Size = UDim2.new(1, -2 * (L.Pad + 14), 0, L.PageTitle + 6),
			ZIndex = 22,
		})
		local back = new("TextButton", {
			Name = "Close",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -(L.Pad + 14), 0, L.Pad + 8),
			Size = UDim2.fromOffset(L.Button * 2.6, L.Button * 0.8),
			BackgroundColor3 = BUTTON,
			Font = Enum.Font.GothamBlack,
			Text = "‹  BACK",
			TextSize = L.ButtonText,
			TextColor3 = TEXT,
			ZIndex = 23,
		}, page)
		round(back, 10)
		stroke(back, EDGE, 2)
		back.Activated:Connect(function()
			menu.page(nil)
		end)
		if name == "Feedback" then
			feedbackForm(page, L)
			return
		end
		local list = scroller(page, L)
		if name == "Guide" then
			for i, entry in Content.Guide do
				section(list, L, i, entry.Title, entry.Lines)
			end
		elseif name == "Updates" then
			for i, entry in Content.Updates do
				local head = if entry.Version then string.format("%s  ·  %s", entry.Version, string.upper(entry.Date or "")) else string.upper(entry.Date or "")
				section(list, L, i, head, entry.Lines)
			end
		elseif name == "Credits" then
			for i, entry in Content.Credits do
				section(list, L, i, entry.Title, entry.Lines)
			end
		end
	end

	-- PLAY from the keyboard or a controller (not while typing feedback).
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter or k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.ButtonStart then
			if not processed or k ~= Enum.KeyCode.ButtonA then
				onPlay()
			end
		elseif k == Enum.KeyCode.Escape or k == Enum.KeyCode.ButtonB then
			if openPage then
				menu.page(nil)
			end
		elseif (k == Enum.KeyCode.Right or k == Enum.KeyCode.DPadRight) and not openPage then
			hold()
			show(current + 1)
		elseif (k == Enum.KeyCode.Left or k == Enum.KeyCode.DPadLeft) and not openPage then
			hold()
			show(current - 1)
		end
	end))

	-- On by themselves, unless touched a moment ago or a page is up.
	local nextAt = os.clock() + MainMenu.SlideSeconds
	table.insert(connections, RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if openPage or now < heldUntil then
			nextAt = math.max(nextAt, heldUntil + MainMenu.SlideSeconds * 0.5)
			return
		end
		if now >= nextAt then
			nextAt = now + MainMenu.SlideSeconds
			show(current + 1)
		end
	end))

	draw()
	table.insert(connections, parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(draw))

	function menu.destroy()
		if not alive then
			return
		end
		alive = false
		for _, c in connections do
			c:Disconnect()
		end
		root:Destroy()
	end
	menu.banners = banners
	menu.current = function()
		return current
	end
	menu.playButton = function()
		return playButton
	end
	return menu
end

return MainMenu
