--[[
	NEXT STEP: a new miner's first steps after the first fight (Shared.FirstSteps),
	one card at the top of the play screen: what to do, why, and a button that
	does it (or shows how):

	  BREAK A GLOWING ROCK      HOW?        a toast: walk up and swing
	  SOCKET YOUR GEM           SOCKET IT   EQUIP BEST (Server.Forge: the best
	                                        gems into your gear), else the Inventory
	  READY A SURGE             SET IT      UPGRADE SURGES, else the Inventory
	  TRY YOUR GEMS IN A DUEL   PLAY        the PLAY menu

	It pops (a bounce and a sound) each time the step changes, so the first gem
	landing reads as "now socket it". Shown with the lobby's HUD (Lobby.client:
	in the Outpost, not fighting), never over a window (UiKit.watchCovers) or
	the PLAY menu;
	× hides it for this session. Only for accounts the onboarding funnel
	counts, until their second duel; then it's gone for good.

	  FirstStepsCoach.start()          once (Lobby.client)
	  FirstStepsCoach.setVisible(on)   with the lobby HUD (Lobby.client)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FirstSteps = require(ReplicatedStorage.Shared.FirstSteps)
local Lang = require(ReplicatedStorage.Shared.Lang)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local UiKit = require(script.Parent.UiKit)
local UiSound = require(script.Parent.UiSound)
local UpgradeHints = require(script.Parent.UpgradeHints)

local FirstStepsCoach = {}

local P = IronUi.Colors
local new = IronUi.new
local PANEL = Color3.fromRGB(16, 22, 38)
local PANEL_LOW = Color3.fromRGB(8, 11, 22)
local player = Players.LocalPlayer

local gui: ScreenGui? = nil
local card: Frame
local scale: UIScale
local kicker: TextLabel
local title: TextLabel
local line: TextLabel
local go: TextButton
local hud, covered, dismissed, busy, picking = false, false, false, false, false
local shownId: string? = nil

local function current()
	local hints = UpgradeHints.Current or {}
	local view = FirstSteps.view(GemClient.Profile, {
		Duels = player:GetAttribute("DuelsPlayed"),
		SocketOpen = hints.Equipment == true,
		SurgeOpen = hints.Surges ~= nil and (hints.Surges.Changes or 0) > 0,
	})
	return FirstSteps.current(view)
end

local function layout()
	if not gui then
		return
	end
	local screen = gui.AbsoluteSize
	if screen.X <= 0 then
		return
	end
	local phone = UiKit.handheld(screen)
	local top = UiKit.topbar(screen.X)
	local w = if phone then math.clamp(screen.X * 0.36, 240, 320) else 380
	local h = if phone then 54 else 68
	card.Size = UDim2.fromOffset(w, h)
	card.Position = UDim2.new(0.5, 0, 0, if phone then top + 4 else top + 14)
	local bw = if phone then 82 else 108
	go.Size = UDim2.fromOffset(bw, h - (if phone then 18 else 24))
	go.Position = UDim2.new(1, -bw - 9, 0.5, 0)
	go.TextSize = if phone then 12 else 15
	kicker.TextSize = if phone then 9 else 11
	title.TextSize = if phone then 13 else 17
	line.TextSize = if phone then 10 else 13
	local textW = w - bw - 34
	kicker.Size = UDim2.fromOffset(textW, if phone then 11 else 13)
	title.Size = UDim2.fromOffset(textW, if phone then 16 else 20)
	line.Size = UDim2.fromOffset(textW, if phone then 13 else 16)
	kicker.Position = UDim2.fromOffset(16, if phone then 5 else 7)
	title.Position = UDim2.fromOffset(16, if phone then 17 else 21)
	line.Position = UDim2.fromOffset(16, if phone then 35 else 43)
end

local function build()
	local g = UiKit.gui("FirstSteps", 6)
	g.IgnoreGuiInset = true
	card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = PANEL,
		Visible = false,
	}, g)
	UiKit.round(card, 10)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(PANEL, PANEL_LOW) }, card)
	new("UIStroke", { Color = P.Gold, Thickness = 1.5, Transparency = 0.25 }, card)
	scale = new("UIScale", { Scale = 1 }, card)
	-- The gold bar down its left edge.
	local bar = new("Frame", { BackgroundColor3 = P.Gold, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 8), Size = UDim2.new(0, 3, 1, -16) }, card)
	UiKit.round(bar, 2)
	local function label(font, color)
		local l = new("TextLabel", {
			BackgroundTransparency = 1,
			Font = font,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, card)
		return l
	end
	kicker = label(IronUi.Heading, P.Gold)
	title = label(IronUi.Heading, P.Text)
	line = label(IronUi.Body, P.Dim)
	title:SetAttribute("NoTranslate", true)
	go = new("TextButton", {
		Name = "Go",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = P.Gold,
		Font = IronUi.Heading,
		TextColor3 = Color3.fromRGB(26, 18, 6),
		AutoButtonColor = true,
	}, card)
	UiKit.round(go, 8)
	go:SetAttribute("UiSound", "Confirm")
	IronUi.juice(go)
	IronUi.shine(go, 3.5) -- (a slow sweep of light across the button: press me)
	-- × hides it for this session.
	local close = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -6),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = PANEL_LOW,
		Text = "×",
		Font = IronUi.Heading,
		TextSize = 14,
		TextColor3 = P.Dim,
	}, card)
	UiKit.round(close, 10)
	new("UIStroke", { Color = P.Edge, Thickness = 1 }, close)
	close.Activated:Connect(function()
		dismissed = true
		card.Visible = false
	end)
	g:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	UiKit.onTopbar(layout)
	gui = g
	layout()
end

-- A little bounce: the step changed.
local function pop()
	scale.Scale = 0.82
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	UiSound.play("Notify")
end

local function refresh()
	if not gui then
		return
	end
	local step, index, total = current()
	local show = step ~= nil and hud and not covered and not dismissed and not picking
	-- (FINISH YOUR INTRO FIGHTS waits while the first dungeon or the lobby's
	-- intro is still on: Client IntroFinale)
	if step and step.Id == "Rounds" and player:GetAttribute("IntroFinale") ~= nil then
		show = false
	end
	if step then
		kicker.Text = Lang.format("NEXT STEP  ·  {1} / {2}", index, total)
		title.Text = Lang.translate(step.Title)
		line.Text = if step.Id == "Rounds"
			then Lang.format(step.Line, FirstSteps.view(GemClient.Profile).Round, require(ReplicatedStorage.Shared.IntroRounds).Count)
			else Lang.translate(if UiKit.touchOnly() and step.Mobile then step.Mobile else step.Line)
		go.Text = Lang.translate(step.Button)
	end
	card.Visible = show
	local id = step and step.Id
	if id ~= shownId then
		shownId = id
		if show and id then
			pop()
		end
	end
end

local function act(step)
	if busy then
		return
	end
	local LobbyUI = require(script.Parent.LobbyUI)
	if step.Id == "Mine" then
		UiKit.toast(Lang.translate(if UiKit.touchOnly() then "Find a glowing rock nearby, walk up to it and tap to swing." else "Find a glowing rock nearby, walk up to it and click it (or press E)."), P.Gold)
	elseif step.Id == "Socket" or step.Id == "Surge" then
		local hints = UpgradeHints.Current or {}
		local action = if step.Id == "Socket"
			then (if hints.Equipment then "AutoEquip" else nil)
			else (if hints.Surges and (hints.Surges.Changes or 0) > 0 then "UpgradeSurges" else nil)
		if not action then
			LobbyUI.openDashboard()
			return
		end
		busy = true
		task.spawn(function()
			local result = if action == "AutoEquip" then GemClient.request(action, "Best") else GemClient.request(action)
			busy = false
			if result and result.Ok then
				UiSound.play("Enchant")
				UiKit.toast(Lang.translate(if step.Id == "Socket" then "Gem socketed: you're stronger. Open INVENTORY to see it." else "Surge ready: cast it in a fight with Q, E or R."), P.Good)
			else
				-- (it didn't take: let them do it by hand)
				LobbyUI.openDashboard()
			end
		end)
	elseif step.Id == "Duel" then
		LobbyUI.openPicker()
	elseif step.Id == "Rounds" then
		busy = true
		task.spawn(function()
			local result = GemClient.request("IntroRoundNext")
			busy = false
			if result and not result.Ok then
				UiKit.toast(Lang.translate(result.Message or "Couldn't start the round."), P.Bad)
			end
		end)
	end
end

function FirstStepsCoach.setVisible(on: boolean)
	if hud ~= on then
		hud = on
		refresh()
	end
end

local started = false
function FirstStepsCoach.start()
	if started then
		return
	end
	started = true
	build()
	go.Activated:Connect(function()
		local step = current()
		if step then
			act(step)
		end
	end)
	GemClient.Changed:Connect(refresh)
	UpgradeHints.Changed:Connect(refresh)
	player:GetAttributeChangedSignal("DuelsPlayed"):Connect(refresh)
	player:GetAttributeChangedSignal("IntroFinale"):Connect(refresh)
	UiKit.watchCovers(function(on)
		covered = on
		refresh()
	end)
	-- Out of the way while the PLAY menu is up (LobbyUI's ModePickerOpen).
	task.spawn(function()
		local lobby = player:WaitForChild("PlayerGui"):WaitForChild("LobbyHud", 30)
		if not lobby then
			return
		end
		local function watch()
			picking = lobby:GetAttribute("ModePickerOpen") == true
			refresh()
		end
		lobby:GetAttributeChangedSignal("ModePickerOpen"):Connect(watch)
		watch()
	end)
	refresh()
end

return FirstStepsCoach
