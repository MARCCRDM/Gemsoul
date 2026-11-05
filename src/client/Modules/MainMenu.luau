--[[
	The main menu, on the title screen (Client Splash) once its intro has
	played: a console game's title screen, no boxes. A night sky across it;

	  left    the logo, PLAY (a gold plate: Enter / A too), then a list:
	          GUIDE, UPDATES, FEEDBACK, CREDITS, each with a gem and a hint,
	          lit under the mouse
	  right   the banners (Shared.MainMenuContent), one at a time, on by
	          themselves every SlideSeconds (held a while after a touch):
	          its picture big, melting into the night, its tag, title, words
	          and button over its foot, bars and arrows; or a page (GUIDE,
	          UPDATES, FEEDBACK, CREDITS) in a glass panel, with a BACK
	  bottom  what's new, the version and SETTINGS

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

local GOLD = Color3.fromRGB(130, 202, 212)
local GOLD_DARK = Color3.fromRGB(66, 116, 130)
local INK = Color3.fromRGB(10, 12, 20)
local PANEL = Color3.fromRGB(10, 12, 20)
local BUTTON = Color3.fromRGB(22, 26, 38)
local EDGE = Color3.fromRGB(70, 78, 98)
local TEXT = Color3.fromRGB(240, 244, 250)
local DIM = Color3.fromRGB(170, 176, 190)
local FAINT = Color3.fromRGB(120, 126, 140)
local GOOD = Color3.fromRGB(96, 236, 170)
local BAD = Color3.fromRGB(255, 120, 110)

-- The two layouts, in their own pixels (scaled to fit): a title screen,
-- the featured banner's art filling the right and melting into the stars,
-- the logo, PLAY and a list down the left, a strip along the bottom.
local LAYOUTS = {
	Desk = {
		W = 1600, H = 900,
		LeftX = 80, LogoY = 40, LogoW = 560, PlayY = 318, PlayW = 520, Play = 104, PlayText = 52, Caption = 15,
		ListY = 470, Row = 58, RowGap = 6, RowText = 30, Hint = 16, Foot = 14, StripY = 852,
		ArtX = 560, ArtY = 30, ArtW = 1040, ArtH = 640,
		WordsX = 700, TagY = 548, Title = 46, Line = 20, ActY = 726, Button = 52, ButtonText = 19, Dot = 12, Tag = 16,
		PageX = 700, PageY = 70, PageW = 840, PageH = 740,
		Pad = 18, Radius = 18, PageTitle = 28, PageText = 18, PageHead = 22,
	},
	Phone = {
		W = 844, H = 390,
		LeftX = 22, LogoY = 8, LogoW = 250, PlayY = 106, PlayW = 280, Play = 52, PlayText = 26, Caption = 10,
		ListY = 174, Row = 34, RowGap = 4, RowText = 17, Hint = 10, Foot = 11, StripY = 372,
		ArtX = 300, ArtY = 0, ArtW = 544, ArtH = 300,
		WordsX = 330, TagY = 176, Title = 22, Line = 12, ActY = 300, Button = 34, ButtonText = 13, Dot = 9, Tag = 11,
		PageX = 320, PageY = 10, PageW = 504, PageH = 356,
		Pad = 10, Radius = 12, PageTitle = 18, PageText = 12, PageHead = 14,
	},
}
-- (the logo's part of the title art: its words, without the sky around them)
MainMenu.LogoRect = { 55, 330, 880, 335 }
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
	-- (on its edge: a UIStroke on a text button outlines its words otherwise)
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
	}, object)
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
		local crop = Content.Crops and Content.Crops[banner.Id]
		p.Picture.ImageRectOffset = if crop then Vector2.new(crop[1], crop[2]) else Vector2.zero
		p.Picture.ImageRectSize = if crop then Vector2.new(crop[3], crop[4]) else Vector2.zero
		p.Fallback.Visible = id == 0
		p.FallbackWord.Text = banner.Tag
		p.FallbackGlow.BackgroundColor3 = banner.TagColor
		local L = LAYOUTS[drawn or "Desk"]
		p.Tag.Text = tagOf(banner)
		p.TagBack.Size = UDim2.fromOffset(widthOf(p.Tag.Text, L.Tag, Enum.Font.GothamBlack) + 26, L.Tag + 14)
		p.TagBack.BackgroundColor3 = banner.TagColor
		p.Title.Text = banner.Title
		p.Line.Text = if drawn == "Phone" then banner.Short or banner.Line else banner.Line
		p.Line.TextColor3 = Color3.fromRGB(196, 202, 216)
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
		if p.Lay then
			p.Lay()
		end
		-- (a soft fade in)
		p.Picture.ImageTransparency = 1
		TweenService:Create(p.Picture, TweenInfo.new(0.35), { ImageTransparency = 0 }):Play()
	end
	menu.show = show

	-- The title screen, for the current layout.
	draw = function()
		local screen = parent.AbsoluteSize
		local name, scale = MainMenu.layout(screen, UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
		scaler.Scale = scale
		if name == drawn then
			return
		end
		drawn = name
		local L = LAYOUTS[name]
		local phone = name == "Phone"
		IronUi.clear(root) -- (keeps the UIScale)
		root.Size = UDim2.fromOffset(L.W, L.H)
		table.clear(slideParts)
		-- A soft glow: a circle fading out from its middle.
		local function glow(parentOf: Instance, x: number, y: number, r: number, color: Color3, strength: number, z: number)
			local g = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(r * 2, r * 2),
				BackgroundColor3 = color,
				BackgroundTransparency = 1 - strength,
				ZIndex = z,
			}, parentOf)
			round(g, r)
			new("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			}, g)
			return g
		end
		-- A pixel-cut plate: a body, a darker lip under it, a light band on
		-- top (the logo's look, not a web button's).
		local function plate(parentOf: Instance, nameOf: string, x: number, y: number, w: number, h: number, face: Color3, z: number): TextButton
			local lip = new("Frame", {
				Name = nameOf .. "Lip",
				Position = UDim2.fromOffset(x, y + math.max(4, math.floor(h * 0.09))),
				Size = UDim2.fromOffset(w, h),
				BackgroundColor3 = face:Lerp(Color3.new(0, 0, 0), 0.42),
				ZIndex = z,
			}, parentOf)
			round(lip, 4)
			local b = new("TextButton", {
				Name = nameOf,
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(w, h),
				BackgroundColor3 = face,
				AutoButtonColor = true,
				Text = "",
				ZIndex = z + 1,
			}, parentOf)
			round(b, 4)
			local band = new("Frame", {
				Name = "Band",
				Position = UDim2.fromOffset(6, 5),
				Size = UDim2.new(1, -12, 0.4, -5),
				BackgroundColor3 = face:Lerp(Color3.new(1, 1, 1), 0.38),
				BackgroundTransparency = 0.62, -- (light: a button's own words show through it)
				ZIndex = z + 1,
			}, b)
			round(band, 3)
			return b
		end

		-- The night: deep blue into violet, a few nebulae, pixel stars.
		local sky = new("Frame", {
			Name = "Sky",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 20,
		}, root)
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(12, 12, 32), Color3.fromRGB(22, 14, 40)),
		}, sky)
		for _, n in { { 0.18, 0.2, 0.3, Color3.fromRGB(60, 70, 150) }, { 0.55, 0.85, 0.36, Color3.fromRGB(90, 46, 140) }, { 0.85, 0.15, 0.3, Color3.fromRGB(44, 66, 150) } } do
			glow(sky, L.W * n[1], L.H * n[2], math.floor(L.W * n[3]), n[4], 0.45, 20)
		end
		-- (the same stars every time: a little generator of its own)
		local seed = 7
		local function nextNumber(): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
		for i = 1, if phone then 70 else 120 do
			local size = if nextNumber() < 0.8 then 2 else 3
			new("Frame", {
				Name = "Star",
				Position = UDim2.fromOffset(math.floor(nextNumber() * L.W), math.floor(nextNumber() * L.H)),
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = if i % 3 == 0 then Color3.fromRGB(150, 220, 255) else Color3.new(1, 1, 1),
				BackgroundTransparency = 0.15 + nextNumber() * 0.6,
				BorderSizePixel = 0,
				ZIndex = 20,
			}, sky)
		end

		-- Right: the featured banner, its art big, its words over it, and the
		-- pages in a glass panel in its place.
		local right = new("Frame", { Name = "Slides", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21 }, root)
		local slide = new("Frame", { Name = "Slide", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21 }, right)
		slideFrame = slide
		local art = new("Frame", {
			Name = "Art",
			Position = UDim2.fromOffset(L.ArtX, L.ArtY),
			Size = UDim2.fromOffset(L.ArtW, L.ArtH),
			BackgroundTransparency = 1,
			ZIndex = 21,
		}, slide)
		local halo = glow(art, L.ArtW * 0.55, L.ArtH * 0.45, math.floor(L.ArtH * 0.62), GOLD, 0.25, 21)
		local fallback = new("Frame", { Name = "Fallback", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21 }, art)
		local word = label(fallback, "", L.Title * 2, TEXT, Enum.Font.GothamBlack, {
			Size = UDim2.fromScale(1, 0.8),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTransparency = 0.82,
			ZIndex = 22,
		})
		local picture = new("ImageLabel", {
			Name = "Picture",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 23,
		}, art)
		-- (melting into the night on its left and along its bottom)
		new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.32, 0),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}, picture)
		local floor = new("Frame", {
			Name = "Fade",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 0.42),
			BackgroundColor3 = Color3.fromRGB(20, 14, 38),
			ZIndex = 24,
		}, art)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
		}, floor)
		-- The words, over the picture's foot.
		local tagBack = new("Frame", {
			Name = "Tag",
			Position = UDim2.fromOffset(L.WordsX, L.TagY),
			Size = UDim2.fromOffset(100, L.Tag + 14),
			BackgroundColor3 = GOLD,
			ZIndex = 26,
		}, slide)
		round(tagBack, 999)
		local tag = label(tagBack, "", L.Tag, INK, Enum.Font.GothamBlack, {
			Size = UDim2.fromScale(1, 1),
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 27,
		})
		local wordsW = L.W - L.WordsX - L.Pad * 2
		local title = label(slide, "", L.Title, TEXT, Enum.Font.GothamBlack, {
			Name = "Title",
			Position = UDim2.fromOffset(L.WordsX, L.TagY + L.Tag + 24),
			Size = UDim2.fromOffset(wordsW, L.Title + 8),
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 26,
		})
		new("UIStroke", { Color = Color3.fromRGB(8, 6, 18), Thickness = if phone then 1.5 else 2.5, Transparency = 0.25 }, title)
		local line = label(slide, "", L.Line, Color3.fromRGB(214, 218, 232), Enum.Font.GothamMedium, {
			Name = "Line",
			Position = UDim2.fromOffset(L.WordsX, L.TagY + L.Tag + 34 + L.Title),
			Size = UDim2.fromOffset(wordsW, L.Line * 2 + 8),
			ZIndex = 26,
		})
		new("UIStroke", { Color = Color3.fromRGB(8, 6, 18), Thickness = 1, Transparency = 0.5 }, line)
		local button = plate(slide, "Action", L.WordsX, L.ActY, L.Button * 4, L.Button, GOLD, 26)
		button.Font = Enum.Font.GothamBlack
		button.TextSize = L.ButtonText
		button.TextColor3 = INK
		button.Activated:Connect(function()
			act(banners[current])
		end)
		IronUi.juice(button, 1.04, 0.96)
		-- (a code each, when a banner has several: gold plates, side by side)
		local chips = {}
		local chipX = L.WordsX
		for i = 1, 3 do
			local chip = plate(slide, "Code" .. i, chipX, L.ActY, L.Button * 3, L.Button, GOLD, 26)
			chip.Font = Enum.Font.GothamBlack
			chip.TextSize = L.ButtonText
			chip.TextColor3 = INK
			chip.Visible = false
			local lip = slide:FindFirstChild("Code" .. i .. "Lip")
			chip:GetPropertyChangedSignal("Visible"):Connect(function()
				if lip then
					lip.Visible = chip.Visible
				end
			end)
			chip.Activated:Connect(function()
				if chip.Text ~= "" then
					redeem(chip.Text)
				end
			end)
			IronUi.juice(chip, 1.04, 0.96)
			chips[i] = chip
		end
		-- (the chips laid side by side as wide as their codes; the lips follow)
		local function layChips()
			local x = L.WordsX
			for i, chip in chips do
				chip.Position = UDim2.fromOffset(x, L.ActY)
				local lip = slide:FindFirstChild("Code" .. i .. "Lip")
				if lip then
					lip.Position = UDim2.fromOffset(x, L.ActY + math.max(4, math.floor(L.Button * 0.09)))
					lip.Size = chip.Size
					lip.Visible = chip.Visible
				end
				if chip.Visible then
					x += chip.Size.X.Offset + 12
				end
			end
			local actionLip = slide:FindFirstChild("ActionLip")
			if actionLip then
				actionLip.Size = button.Size
				actionLip.Visible = button.Visible
			end
		end
		-- The bars (one a banner, the lit one gold) and the arrows as plates.
		local dots = {}
		local barY = L.ActY + L.Button + (if phone then 14 else 26)
		for i = 1, 8 do
			local dot = new("TextButton", {
				Name = "Dot" .. i,
				Position = UDim2.fromOffset(L.WordsX + (i - 1) * (L.Dot * 5), barY),
				Size = UDim2.fromOffset(L.Dot * 4, math.max(4, math.floor(L.Dot * 0.5))),
				BackgroundColor3 = EDGE,
				Text = "",
				ZIndex = 26,
			}, slide)
			round(dot, 4)
			dot.Activated:Connect(function()
				hold()
				show(i)
			end)
			dots[i] = dot
		end
		for side, step in { [0] = -1, [1] = 1 } do
			local size = L.Button
			local arrow = plate(slide, if step < 0 then "Back" else "Next", L.W - L.Pad * 2 - (2 - side) * (size + 10), barY - size / 2 - 2, size, size, Color3.fromRGB(46, 50, 76), 26)
			arrow.Font = Enum.Font.GothamBlack
			arrow.Text = if step < 0 then "‹" else "›"
			arrow.TextSize = math.floor(size * 0.7)
			arrow.TextColor3 = TEXT
			arrow.Activated:Connect(function()
				hold()
				show(current + step)
			end)
		end
		slideParts = {
			Picture = picture, Fallback = fallback, FallbackWord = word, FallbackGlow = halo,
			Tag = tag, TagBack = tagBack, Title = title, Line = line, Button = button,
			Chips = chips, Dots = dots, Lay = layChips,
		}

		-- Left: the logo, PLAY, the list.
		local left = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 22 }, root)
		-- (a shade behind it, so the words read over the stars and the art)
		local shade = new("Frame", {
			Name = "Shade",
			Size = UDim2.new(0, L.LeftX + L.PlayW + 160, 1, 0),
			BackgroundColor3 = Color3.fromRGB(8, 8, 20),
			ZIndex = 22,
		}, left)
		new("UIGradient", {
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		}, shade)
		local rect = MainMenu.LogoRect
		local logoH = math.floor(L.LogoW * rect[4] / rect[3])
		local logo = new("ImageLabel", {
			Name = "Logo",
			Position = UDim2.fromOffset(L.LeftX, L.LogoY),
			Size = UDim2.fromOffset(L.LogoW, logoH),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. MainMenu.LogoId,
			ImageRectOffset = Vector2.new(rect[1], rect[2]),
			ImageRectSize = Vector2.new(rect[3], rect[4]),
			ResampleMode = Enum.ResamplerMode.Pixelated,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 23,
		}, left)
		-- PLAY: the big matte station-blue plate.
		local play = plate(left, "Play", L.LeftX, L.PlayY, L.PlayW, L.Play, Color3.fromRGB(130, 202, 212), 23)
		play.ClipsDescendants = true
		label(play, "▶  PLAY", L.PlayText, INK, Enum.Font.GothamBlack, {
			Name = "Words",
			Position = UDim2.fromOffset(math.floor(L.Play * 0.36), 0),
			Size = UDim2.new(1, 0, 0.78, 0),
			TextWrapped = false,
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 26,
		})
		label(play, "INTO THE OUTPOST", L.Caption, Color3.fromRGB(30, 65, 77), Enum.Font.GothamBold, {
			Name = "Caption",
			Position = UDim2.new(0, math.floor(L.Play * 0.4), 1, -(L.Caption + math.floor(L.Play * 0.14))),
			Size = UDim2.new(0.6, 0, 0, L.Caption + 4),
			TextWrapped = false,
			ZIndex = 26,
		})
		play:SetAttribute("UiSound", "Open")
		play.Activated:Connect(function()
			onPlay()
		end)
		IronUi.juice(play, 1.03, 0.97)
		playButton = play
		if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
			local key = label(play, "ENTER", L.Foot + 4, Color3.fromRGB(231, 242, 244), Enum.Font.GothamBlack, {
				Name = "Key",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -22, 0.5, -2),
				Size = UDim2.fromOffset((L.Foot + 4) * 5.2, L.Foot + 22),
				BackgroundColor3 = Color3.fromRGB(27, 62, 73),
				BackgroundTransparency = 0.15,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 26,
			})
			round(key, 6)
		end
		-- The list: a gem, the word, a hint; lit under the mouse (or its page open).
		local rows = {}
		local function light()
			for id, row in rows do
				local on = row.Hover or openPage == id
				row.Bar.Visible = on
				row.Gem.BackgroundColor3 = if on then GOLD else Color3.fromRGB(110, 120, 150)
				row.Button.TextColor3 = if on then TEXT else Color3.fromRGB(210, 212, 226)
			end
		end
		menu.light = light
		local hints = { Guide = "How to play", Updates = "What's new", Feedback = "A bug or an idea", Credits = "" }
		for i, entry in { { "GUIDE", "Guide" }, { "UPDATES", "Updates" }, { "FEEDBACK", "Feedback" }, { "CREDITS", "Credits" } } do
			local y = L.ListY + (i - 1) * (L.Row + L.RowGap)
			local bar = new("Frame", {
				Name = "Lit",
				Position = UDim2.fromOffset(L.LeftX, y),
				Size = UDim2.fromOffset(L.PlayW, L.Row),
				BackgroundColor3 = GOLD,
				BackgroundTransparency = 0.6,
				Visible = false,
				ZIndex = 23,
			}, left)
			new("UIGradient", {
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			}, bar)
			new("Frame", { Name = "Edge", Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = GOLD, ZIndex = 24 }, bar)
			local gem = new("Frame", {
				Name = "Gem",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(L.LeftX + math.floor(L.Row * 0.5), y + L.Row / 2),
				Size = UDim2.fromOffset(math.floor(L.RowText * 0.55), math.floor(L.RowText * 0.55)),
				Rotation = 45,
				BackgroundColor3 = Color3.fromRGB(110, 120, 150),
				ZIndex = 24,
			}, left)
			local b = new("TextButton", {
				Name = entry[2],
				Position = UDim2.fromOffset(L.LeftX + L.Row, y),
				Size = UDim2.fromOffset(L.PlayW - L.Row, L.Row),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Text = entry[1],
				TextSize = L.RowText,
				TextColor3 = Color3.fromRGB(210, 212, 226),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 24,
			}, left)
			if hints[entry[2]] ~= "" and not phone then
				label(left, hints[entry[2]], L.Hint, FAINT, Enum.Font.GothamMedium, {
					Name = "Hint",
					Position = UDim2.fromOffset(L.LeftX + L.Row + widthOf(entry[1], L.RowText, Enum.Font.GothamBlack) + 16, y),
					Size = UDim2.fromOffset(240, L.Row),
					TextWrapped = false,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 24,
				})
			end
			b:SetAttribute("UiSound", "Open")
			b.Activated:Connect(function()
				menu.page(entry[2])
			end)
			local row = { Bar = bar, Gem = gem, Button = b, Hover = false }
			rows[entry[2]] = row
			pcall(function()
				b.MouseEnter:Connect(function()
					row.Hover = true
					light()
				end)
				b.MouseLeave:Connect(function()
					row.Hover = false
					light()
				end)
			end)
		end
		-- The strip along the bottom: what's new, the version, SETTINGS.
		new("Frame", {
			Name = "Rule",
			Position = UDim2.fromOffset(L.LeftX, L.StripY - 18),
			Size = UDim2.fromOffset(L.W - 2 * L.LeftX, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			ZIndex = 24,
		}, left)
		if not phone then
			local news = {}
			for _, update in Content.Updates do
				for _, text in update.Lines do
					if #news < 4 then
						table.insert(news, (string.gsub(text, "[%.:].*$", "")))
					end
				end
			end
			label(left, "NEW", L.Foot, GOLD, Enum.Font.GothamBlack, {
				Name = "New",
				Position = UDim2.fromOffset(L.LeftX, L.StripY - 8),
				Size = UDim2.fromOffset(44, L.Foot + 4),
				ZIndex = 24,
			})
			label(left, table.concat(news, "   ◆   "), L.Foot, DIM, Enum.Font.GothamMedium, {
				Name = "News",
				Position = UDim2.fromOffset(L.LeftX + 50, L.StripY - 8),
				Size = UDim2.fromOffset(L.W - 2 * L.LeftX - 320, L.Foot + 4),
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 24,
			})
		end
		label(left, Content.version(Config.Playtest and Config.Playtest.Build), L.Foot, DIM, Enum.Font.GothamBold, {
			Name = "Version",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(L.W - L.LeftX - 130, L.StripY - 8),
			Size = UDim2.fromOffset(80, L.Foot + 4),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 24,
		})
		local settings = new("TextButton", {
			Name = "Settings",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(L.W - L.LeftX, L.StripY - 14),
			Size = UDim2.fromOffset(110, L.Foot + 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "SETTINGS",
			TextSize = L.Foot,
			TextColor3 = DIM,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 24,
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

		-- A page: a glass panel over the art.
		local page = new("Frame", {
			Name = "Page",
			Position = UDim2.fromOffset(L.PageX, L.PageY),
			Size = UDim2.fromOffset(L.PageW, L.PageH),
			BackgroundColor3 = Color3.fromRGB(14, 14, 30),
			BackgroundTransparency = 0.08,
			Visible = false,
			ZIndex = 21,
		}, right)
		round(page, L.Radius)
		stroke(page, GOLD, 1.5, 0.5)
		pageFrame = page
		show(current)
		if openPage then
			local again = openPage
			openPage = nil
			menu.page(again)
		end
		light()
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
		if menu.light then
			menu.light()
		end
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
