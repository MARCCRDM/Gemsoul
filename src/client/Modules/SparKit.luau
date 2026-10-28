--[[
	Your pick or your combat kit, and friendly sparring (Shared.Spar has the
	rules, the server's SparServer runs them).

	  The kit       X swaps your pick for your combat kit and back (the
	                server's "Hunt"), in the Outpost and in the Rift alike:
	                the kit out, you fight beside your kaiju (and only
	                creatures can hit you); the pick out, you mine (in the
	                Rift, its healing rocks). On a touch screen the kit
	                switch does the same (MobileLayout.kitSwitch: a pill just
	                left of PLAY), showing what a tap swaps to: FIGHT with
	                the pick out, MINE with the kit out. Never while you're
	                down.
	  A spar        is asked for and agreed to: press Z over another player
	                ("Ask to spar", OutpostServer's prompt). They get a card to
	                accept (SocialUI). Once they do, both kits come out; X
	                ends the spar, for both.

	  The spar bar  top centre, while your kit is out: who you're fighting
	                (or HUNTING), and END for a spar or MINE for your pick
	                (the X key; tap or click it too). The kit coming out or
	                going away gets a quick flash, a word and the sound of a
	                blade.
	  A spar        with the kit out the fight view takes over (Combat.client,
	                first person, every move); only your partner can hit you,
	                or be hit.
	  Knocked down  at 0 health: you fall, the view pulls back to watch, and
	                you're up again a few seconds later at full health. Whoever
	                knocked you down gets a banner.
	  Killed        a creature's finishing blow in the Outpost (Killed, from
	                the server): YOU WERE KILLED, darker, and you lie there
	                (robbed first, out past the core) till you're back at
	                base; BACK AT BASE once you are.
	  Who's sparring  while you mine, a crossed-swords mark over anyone in a
	                spar (they can't touch you).

	  SparKit.start()     once, from Lobby.client
	  SparKit.available() whether X does anything right now
	  SparKit.toggle()    swap the pick for the kit (or back), or end your spar
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Spar = require(ReplicatedStorage.Shared.Spar)
local CombatSound = require(script.Parent.CombatSound)
local GemClient = require(script.Parent.GemClient)
local IronUi = require(script.Parent.IronUi)
local MobileLayout = require(script.Parent.MobileLayout)
local OutpostScene = require(script.Parent.OutpostScene)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local P = IronUi.Colors
local new = IronUi.new

local SparKit = {}

-- (1 to 4 are the kaiju team keys: KaijuHud. X was the lock-on key; that's
-- T now, Combat.client. Y, the key before X, still swaps too.)
local KEY, OLD_KEY = Enum.KeyCode.X, Enum.KeyCode.Y
local PICK = Color3.fromRGB(255, 202, 91) -- the pick's gold
local FIGHT = Color3.fromRGB(255, 92, 76) -- the combat kit's red
local GLASS = Color3.fromRGB(12, 14, 26)

-- Screens that have the player's attention: no swapping under them.
local MODAL = {
	Dashboard = true,
	Shop = true,
	Season = true,
	AugmentTree = true,
	SurgeArray = true,
	Social = true,
	ProbeExchange = true,
	WelcomeBundle = true,
	MarketBoard = true,
	Intro = true,
	Tutorial = true,
	Splash = true,
}

local busy = false

local function tween(object: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(object, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		:Play()
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function modalOpen(): boolean
	if player:GetAttribute("MenuOpen") == true then
		return true -- (the PLAY menu, LobbyUI)
	end
	for name in MODAL do
		local screen = playerGui:FindFirstChild(name)
		if screen and screen:IsA("ScreenGui") and screen.Enabled then
			return true
		end
	end
	return false
end

-- Whether X swaps kits now: in the lobby on your feet, out of any fight,
-- seat or menu. (The server checks again.)
function SparKit.available(): boolean
	local h = humanoid()
	return OutpostScene.isActive()
		and player:GetAttribute("Outpost") == true
		and player:GetAttribute("CombatSession") == nil
		and player:GetAttribute("MatchId") == nil
		and player:GetAttribute("DungeonId") == nil
		and player:GetAttribute("Expedition") == nil
		and h ~= nil
		and h.Health > 0
		and h.SeatPart == nil
		and player:GetAttribute("MechPilot") == nil
		and not modalOpen()
end

-- The flash and word on a swap ------------------------------------------------------------------------

local flashGui = UiKit.gui("SparFlash", 40)
flashGui.IgnoreGuiInset = true
local veil = new("Frame", {
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, flashGui)
local edgeGlow = new("UIStroke", {
	Color = FIGHT,
	Thickness = 0,
	Transparency = 1,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, veil)
local word = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(700, 60),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Text = "",
	TextSize = 44,
	TextColor3 = P.Text,
	TextStrokeColor3 = P.Ink,
	TextStrokeTransparency = 0.3,
	TextTransparency = 1,
}, flashGui)
local wordScale = new("UIScale", { Scale = 1 }, word)
local subword = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.42, 40),
	Size = UDim2.fromOffset(700, 24),
	BackgroundTransparency = 1,
	Font = IronUi.Bold,
	Text = "",
	TextSize = 15,
	TextColor3 = P.Dim,
	TextStrokeColor3 = P.Ink,
	TextStrokeTransparency = 0.4,
	TextTransparency = 1,
}, flashGui)

local flashId = 0
local function flash(title: string, sub: string, color: Color3)
	flashId += 1
	local id = flashId
	veil.BackgroundTransparency = 0.55
	edgeGlow.Color, edgeGlow.Thickness, edgeGlow.Transparency = color, 10, 0.25
	tween(veil, 0.35, { BackgroundTransparency = 1 })
	tween(edgeGlow, 0.5, { Thickness = 0, Transparency = 1 })
	word.Text, word.TextColor3, word.TextTransparency = title, color, 0
	subword.Text, subword.TextTransparency = sub, 0
	wordScale.Scale = 1.25
	tween(wordScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.9, function()
		if id == flashId then
			tween(word, 0.35, { TextTransparency = 1 })
			tween(subword, 0.35, { TextTransparency = 1 })
		end
	end)
end

-- The spar bar -------------------------------------------------------------------------------------------
-- Only while you spar: there's nothing to swap otherwise (the kit comes out
-- when a request is accepted). Who you're fighting, and END (1, or a tap).

local barGui = UiKit.gui("SparKit", 7)
barGui.IgnoreGuiInset = false
-- (A slim bar of dark glass: a thin accent in the kit's red, the words,
-- and its one button, the key on a cap and what it does: END in a spar,
-- MINE with the kit out, in the pick's gold. The cap and its rim light up
-- under the mouse.)
local BAR = { W = 200, H = 34, ChipW = 84, ChipH = 24 }
local bar = new("TextButton", {
	Name = "SparBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(BAR.W, BAR.H),
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.18,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
}, barGui)
UiKit.round(bar, 7)
local barEdge = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.84 }, bar)
local barScale = new("UIScale", { Scale = 1 }, bar)
local accent = new("Frame", {
	Name = "Accent",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 8, 0.5, 0),
	Size = UDim2.fromOffset(3, 16),
	BackgroundColor3 = FIGHT,
	BorderSizePixel = 0,
}, bar)
UiKit.round(accent, 2)
local versus = new("TextLabel", {
	Name = "Versus",
	Position = UDim2.fromOffset(18, 0),
	Size = UDim2.new(1, -(18 + BAR.ChipW + 12), 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "SPAR",
	TextSize = 12,
	TextColor3 = P.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, bar)
local endChip = new("Frame", {
	Name = "End",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -5, 0.5, 0),
	Size = UDim2.fromOffset(BAR.ChipW, BAR.ChipH),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.93,
}, bar)
UiKit.round(endChip, 5)
local chipEdge = new("UIStroke", { Color = PICK, Thickness = 1, Transparency = 0.55 }, endChip)
local keyCap = new("TextLabel", {
	Name = "Key",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 5, 0.5, 0),
	Size = UDim2.fromOffset(16, 16),
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.2,
	Font = Enum.Font.GothamBold,
	Text = "X",
	TextSize = 10,
	TextColor3 = P.Text,
}, endChip)
UiKit.round(keyCap, 3)
new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.6 }, keyCap)
local endLabel = new("TextLabel", {
	Name = "Label",
	Position = UDim2.fromOffset(26, 0),
	Size = UDim2.new(1, -30, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "END",
	TextSize = 12,
	TextColor3 = P.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
}, endChip)
bar.MouseEnter:Connect(function()
	endChip.BackgroundTransparency = 0.84
	chipEdge.Transparency = 0.1
	barEdge.Transparency = 0.7
end)
bar.MouseLeave:Connect(function()
	endChip.BackgroundTransparency = 0.93
	chipEdge.Transparency = 0.55
	barEdge.Transparency = 0.84
end)
local caption = new("TextLabel", {
	Name = "Caption",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 6),
	Size = UDim2.fromOffset(640, 18),
	BackgroundTransparency = 1,
	Font = IronUi.Bold,
	Text = "FRIENDLY SPAR  ·  only you two can hit each other",
	TextSize = 11,
	TextColor3 = P.Text,
	TextStrokeColor3 = P.Ink,
	TextStrokeTransparency = 0.45,
	TextTransparency = 1,
}, bar)

-- Your partner's name while you spar.
local function partnerName(): string
	local id = Spar.partner(player)
	local other = id and Players:GetPlayerByUserId(id)
	return if other then other.DisplayName else "your partner"
end

local shown = false
local captionUntil = 0
local function refreshBar()
	-- (Not in the Rift: your kit is out there as a matter of course, its
	-- strip has the top, and the kit switch stays by your thumb.)
	local sparring = Spar.sparring(player) and player:GetAttribute("RiftRun") == nil
	bar.Visible = sparring
	if not sparring then
		shown = false
		caption.TextTransparency = 1
		return
	end
	-- (Hunting: the kit out alone, against the Outpost's creatures.)
	local hunting = Spar.hunting(player)
	versus.Text = if hunting then "KIT OUT" else "SPAR vs " .. string.upper(partnerName())
	endLabel.Text = if hunting then "MINE" else "END"
	-- (its button in what it brings out: the pick's gold to mine, the kit's red to end)
	chipEdge.Color = if hunting then PICK else FIGHT
	caption.Text = if hunting
		then "KIT OUT  ·  only creatures can hit you  ·  X for your pick"
		else "FRIENDLY SPAR  ·  only you two can hit each other"
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	-- (Touch: no key to show; the chip itself is the button.)
	keyCap.Visible = not touch
	endLabel.Position = UDim2.fromOffset(if touch then 0 else 26, 0)
	endLabel.Size = if touch then UDim2.fromScale(1, 1) else UDim2.new(1, -30, 1, 0)
	endLabel.TextXAlignment = if touch then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	barScale.Scale = if viewport.Y < 430 then 0.82 else 1
	-- In the Rift its strip has the top middle (Client.RiftClient): the bar
	-- sits just under it, never over it.
	local top = 10
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local riftGui = playerGui and playerGui:FindFirstChild("Rift")
	local riftStrip = riftGui and riftGui:FindFirstChild("RiftStrip") :: GuiObject?
	if riftStrip and riftStrip.Visible then
		top = riftStrip.AbsolutePosition.Y + riftStrip.AbsoluteSize.Y - barGui.AbsolutePosition.Y + 6
	end
	-- Kit out on a computer: beside the kaiju card (bottom left), where the
	-- X switch sits, with its line above it; else top middle.
	local dock = if hunting and not touch and not (riftStrip and riftStrip.Visible) then UiKit.besideKaiju(barGui) else nil
	if dock then
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromOffset(dock.X, dock.Y)
		caption.AnchorPoint = Vector2.new(0, 1)
		caption.Position = UDim2.new(0, 0, 0, -6)
		caption.TextXAlignment = Enum.TextXAlignment.Left
	else
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 0, top)
		caption.AnchorPoint = Vector2.new(0.5, 0)
		caption.Position = UDim2.new(0.5, 0, 1, 6)
		caption.TextXAlignment = Enum.TextXAlignment.Center
	end
	-- The rule, for the first few seconds of a spar.
	if not shown then
		shown = true
		captionUntil = os.clock() + 5
		caption.TextTransparency = 0
	end
	if os.clock() > captionUntil and caption.TextTransparency < 1 then
		tween(caption, 0.4, { TextTransparency = 1 })
	end
end

-- Swapping, and ending a spar ---------------------------------------------------------------------------

local function send(action: string, ...: any)
	busy = true
	local args = table.pack(...)
	task.spawn(function()
		local result = GemClient.request(action, table.unpack(args, 1, args.n))
		busy = false
		if result.Message and result.Message ~= "" then
			UiKit.toast(result.Message, if result.Ok then P.Gold else P.Bad)
		end
		refreshBar()
	end)
end

-- 1 (or the kit switch): in a spar, end it; otherwise swap the pick for the
-- combat kit, or back. (Down, nothing: the server says so too.)
function SparKit.toggle()
	if busy then
		return
	end
	if Spar.partner(player) then
		send("Spar", false)
		return
	end
	if not SparKit.available() or Spar.isDown(player) then
		return
	end
	send("Hunt", not Spar.hunting(player))
end

-- The kit comes out when both agree, and goes away when either ends it
-- (or the spar stops making sense): a flash either way.
local wasSparring, wasHunting = false, false
local function sparChanged()
	local sparring = Spar.sparring(player)
	if sparring == wasSparring then
		return
	end
	wasSparring = sparring
	if sparring then
		wasHunting = Spar.hunting(player)
		if wasHunting then
			flash("FIGHT", "your kit is out  ·  fight beside your kaiju  ·  X for your pick", FIGHT)
		else
			flash("SPAR", "vs " .. partnerName() .. "  ·  only you two can hit each other  ·  X to stop", FIGHT)
		end
		CombatSound.play("Draw")
	else
		flash(
			"PICKAXE",
			if wasHunting then "back to mining  ·  X for your kit" else "Spar over  ·  back to mining",
			PICK
		)
		CombatSound.play("Sheathe")
	end
end

-- The kit switch on a touch screen ------------------------------------------------------------------------
-- A pill just left of PLAY (MobileLayout.kitSwitch), wherever 1 would swap:
-- what a tap swaps to, ⚔ FIGHT with the pick out, ⛏ MINE with the kit out.
-- (Short of room, round, with just its icon: on a small phone, with the kit
-- out, to leave the fight's vitals room.)

local switchGui = UiKit.gui("KitSwitch", 8)
switchGui.IgnoreGuiInset = false
local switch = new("TextButton", {
	Name = "KitSwitch",
	AutoButtonColor = false,
	Text = "",
	BackgroundColor3 = FIGHT:Lerp(GLASS, 0.82),
	BackgroundTransparency = 0.1,
	Visible = false,
}, switchGui)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, switch)
local switchStroke = new("UIStroke", { Color = FIGHT, Thickness = 2, Transparency = 0.1 }, switch)
local switchIcon = new("TextLabel", {
	Name = "Icon",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Font = Enum.Font.GothamBold,
	Text = "⚔",
	TextScaled = true,
	TextColor3 = FIGHT,
}, switch)
local switchLabel = new("TextLabel", {
	Name = "Label",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 0.5),
	Font = IronUi.Heading,
	Text = "FIGHT",
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = P.Text,
}, switch)
new("UITextSizeConstraint", { MaxTextSize = 15 }, switchLabel)
local switchScale = new("UIScale", { Scale = 1 }, switch)
local switchArmed: boolean? = nil
local function refreshSwitch()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local can = Spar.partner(player) == nil and SparKit.available() and not Spar.isDown(player)
	-- (On a computer the key strip's X chip is the switch: OutpostScene.)
	OutpostScene.showKit(Spar.hunting(player), can)
	local want = touch and can
	switch.Visible = want
	if not want then
		return
	end
	-- (With the kit out, the fight's vitals keep to its right: it may be
	-- round then, to leave them room.)
	local armed = Spar.hunting(player)
	local camera = workspace.CurrentCamera
	local rect = MobileLayout.kitSwitch(switchGui.AbsoluteSize, if armed and camera then camera.ViewportSize else nil)
	switch.Position, switch.Size = UDim2.fromOffset(rect.X, rect.Y), UDim2.fromOffset(rect.W, rect.H)
	-- The icon and its word side by side; short of room, the icon alone,
	-- in the middle.
	local worded = rect.W >= MobileLayout.KitSwitch.Icon
	local icon = rect.H - 18
	switchLabel.Visible = worded
	switchIcon.Size = UDim2.fromOffset(icon, icon)
	switchIcon.Position = if worded then UDim2.new(0, 12, 0.5, 0) else UDim2.new(0.5, -icon / 2, 0.5, 0)
	switchLabel.Position = UDim2.new(0, 12 + icon + 6, 0.5, 0)
	switchLabel.Size = UDim2.new(1, -(12 + icon + 6 + 10), 0, 16)
	if armed == switchArmed then
		return
	end
	switchArmed = armed
	local color = if armed then PICK else FIGHT
	switchIcon.Text = if armed then "⛏" else "⚔"
	switchLabel.Text = if armed then "MINE" else "FIGHT"
	switchIcon.TextColor3, switchStroke.Color = color, color
	switch.BackgroundColor3 = color:Lerp(GLASS, 0.82)
	-- (A little pop as it turns over.)
	switchScale.Scale = 1.18
	tween(switchScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Knocked down -------------------------------------------------------------------------------------------

local downGui = UiKit.gui("SparDown", 39)
downGui.IgnoreGuiInset = true
downGui.Enabled = false
local downVeil = new("Frame", {
	BackgroundColor3 = Color3.fromRGB(60, 6, 10),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, downGui)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.75),
		NumberSequenceKeypoint.new(1, 0),
	}),
}, downVeil)
local downTitle = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromOffset(700, 56),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Text = "KNOCKED DOWN",
	TextSize = 46,
	TextColor3 = Color3.fromRGB(255, 120, 104),
	TextStrokeColor3 = P.Ink,
	TextStrokeTransparency = 0.25,
}, downGui)
local downBy = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.36, 42),
	Size = UDim2.fromOffset(700, 24),
	BackgroundTransparency = 1,
	Font = IronUi.Bold,
	Text = "",
	TextSize = 17,
	TextColor3 = P.Text,
	TextStrokeColor3 = P.Ink,
	TextStrokeTransparency = 0.35,
}, downGui)
local downCount = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.36, 76),
	Size = UDim2.fromOffset(700, 22),
	BackgroundTransparency = 1,
	Font = IronUi.Bold,
	Text = "",
	TextSize = 15,
	TextColor3 = P.Dim,
	TextStrokeColor3 = P.Ink,
	TextStrokeTransparency = 0.4,
}, downGui)

local fallen = false
-- Your own body is yours to move: it topples back from the blow, and stands
-- again when the server says you're up.
local function fall(from: Vector3?)
	local h = humanoid()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not h or not root or fallen then
		return
	end
	fallen = true
	h.PlatformStand = true
	local away = if from then root.Position - from else -root.CFrame.LookVector
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
	root.AssemblyLinearVelocity = away * 16 + Vector3.new(0, 14, 0)
	root.AssemblyAngularVelocity = away:Cross(Vector3.new(0, 1, 0)) * -6
end
local function rise()
	local h = humanoid()
	if not fallen then
		return
	end
	fallen = false
	if h then
		h.PlatformStand = false
		h:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local lastAttacker: string? = nil
-- (Killed this time: BACK AT BASE once you're up, the death's sound once.)
local wasKilled = false
local KILLED = Color3.fromRGB(255, 72, 64)
local KNOCKED = Color3.fromRGB(255, 120, 104)
local function refreshDown()
	-- Your body follows SparDown alone, whichever card has the screen: down
	-- at the Rift's boss it stays down under the Rift's card, and it's up
	-- the moment you are, by RESTORE or backup too. (It used to get up only
	-- as this card closed, which the Rift's boss never opens: back on your
	-- feet there, you lay on the floor.)
	local floored = Spar.isDown(player)
	if fallen and not floored then
		rise()
	end
	-- (Down at the Rift's boss the Rift's own card has the screen: Client.RiftClient.)
	local down = floored and player:GetAttribute("RiftFallen") == nil
	local killed = down and player:GetAttribute("Killed") ~= nil
	if down and not downGui.Enabled then
		downGui.Enabled = true
		if lastAttacker then
			downBy.Text = "by " .. lastAttacker
		end
		if not killed then
			CombatSound.play("KnockDown")
		end
	elseif not down and downGui.Enabled then
		downGui.Enabled = false
		-- (Still down, the Rift's card taking over, it's no BACK UP.)
		if not floored then
			if wasKilled then
				flash("BACK AT BASE", "On your feet, full health", Color3.fromRGB(110, 230, 150))
			elseif Spar.sparring(player) then
				flash("BACK UP", "Full health  ·  keep going, or 1 to stop", Color3.fromRGB(110, 230, 150))
			end
		end
		lastAttacker = nil
		downBy.Text = ""
	end
	if killed and not wasKilled then
		CombatSound.play("Death")
	end
	wasKilled = if down then wasKilled or killed else false
	if not down then
		return
	end
	-- Killed by a creature in the Outpost: darker, and red; robbed out past
	-- the core (Server.Robbery), then back at base either way.
	downVeil.BackgroundTransparency = if killed then 0.3 else 0.55
	downTitle.TextColor3 = if killed then KILLED else KNOCKED
	local robbed = player:GetAttribute("Robbed")
	if type(robbed) == "number" then
		downTitle.Text = if killed then "YOU WERE KILLED" else "KNOCKED OUT"
		downBy.Text = "The critters are going through your pouch!"
		local left = robbed - workspace:GetServerTimeNow()
		downCount.Text = string.format("Back to base in %d", math.max(1, math.ceil(left)))
	elseif killed then
		downTitle.Text = "YOU WERE KILLED"
		downBy.Text = "Your gems are safe in the Core."
		local left = (player:GetAttribute("SparDown") or 0) - workspace:GetServerTimeNow()
		downCount.Text = string.format("Back to base in %d", math.max(1, math.ceil(left)))
	else
		downTitle.Text = "KNOCKED DOWN"
		local left = (player:GetAttribute("SparDown") or 0) - workspace:GetServerTimeNow()
		downCount.Text = string.format("Back up in %d", math.max(1, math.ceil(left)))
	end
end

-- Someone was knocked down: a line (a toast, not big words across the
-- screen) if it was you who did it, or for anyone close by.
local function knockedDown(victimId: number, attackerId: number)
	local victim = Players:GetPlayerByUserId(victimId)
	local attacker = Players:GetPlayerByUserId(attackerId)
	if victim == player then
		lastAttacker = attacker and attacker.DisplayName or nil
		downBy.Text = if lastAttacker then "by " .. lastAttacker else ""
		local from = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
		fall(if from then (from :: BasePart).Position else nil)
	elseif attacker == player and victim then
		UiKit.toast("You knocked down " .. victim.DisplayName, P.Gold)
		CombatSound.play("Kill")
	elseif victim and attacker then
		-- (Only for fights you can see.)
		local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local theirs = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if mine and theirs and (mine.Position - theirs.Position).Magnitude < 90 then
			UiKit.toast(attacker.DisplayName .. " knocked down " .. victim.DisplayName, FIGHT)
		end
	end
end

-- Who's armed ----------------------------------------------------------------------------------------------

local marks: { [Player]: BillboardGui } = {}
local function refreshMark(other: Player)
	local head = other.Character and other.Character:FindFirstChild("Head")
	local want = other ~= player and head ~= nil and Spar.sparring(other) and not Spar.sparring(player)
	local mark = marks[other]
	if want and (not mark or mark.Adornee ~= head) then
		if mark then
			mark:Destroy()
		end
		mark = new("BillboardGui", {
			Name = "SparMark",
			Adornee = head,
			AlwaysOnTop = true,
			MaxDistance = 90,
			Size = UDim2.fromOffset(30, 30),
			StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0),
		}, barGui)
		local badge = new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(40, 10, 12),
			BackgroundTransparency = 0.15,
			Font = Enum.Font.GothamBold,
			Text = "⚔",
			TextSize = 17,
			TextColor3 = FIGHT,
		}, mark)
		UiKit.round(badge, 15)
		new("UIStroke", { Color = FIGHT, Thickness = 1.5, Transparency = 0.2 }, badge)
		marks[other] = mark
	elseif not want and mark then
		mark:Destroy()
		marks[other] = nil
	end
end
local function refreshMarks()
	for _, other in Players:GetPlayers() do
		refreshMark(other)
	end
end

-- Start -------------------------------------------------------------------------------------------------------

local started = false
function SparKit.start()
	if started then
		return
	end
	started = true
	ContextActionService:BindActionAtPriority("SparKit", function(_, state)
		if UserInputService:GetFocusedTextBox() or not (SparKit.available() or Spar.sparring(player)) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			SparKit.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 20, KEY, OLD_KEY, Enum.KeyCode.DPadUp)
	bar.Activated:Connect(SparKit.toggle)
	switch.Activated:Connect(SparKit.toggle)
	OutpostScene.toggleKit = SparKit.toggle
	for _, name in { "Spar", "Hunt", "SparDown", "Outpost", "CombatSession", "MatchId", "ChatOpen", "MenuOpen" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refreshBar()
			refreshDown()
			refreshMarks()
			refreshSwitch()
		end)
	end
	-- Mid-spar, E is a fight key: no world prompts (rocks, the crew, the
	-- spar, duel and party invites) pop up or fire until the kit is away.
	player:GetAttributeChangedSignal("Spar"):Connect(function()
		ProximityPromptService.Enabled = not Spar.sparring(player)
		sparChanged()
	end)
	local function watch(other: Player)
		if other == player then
			return
		end
		other:GetAttributeChangedSignal("Spar"):Connect(function()
			refreshMark(other)
		end)
		other.CharacterAdded:Connect(function()
			task.defer(refreshMark, other)
		end)
		refreshMark(other)
	end
	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(other)
		if marks[other] then
			marks[other]:Destroy()
			marks[other] = nil
		end
	end)
	player.CharacterAdded:Connect(function()
		fallen = false
		downGui.Enabled = false
		wasKilled = false
	end)
	task.spawn(function()
		local fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx")
		fx.OnClientEvent:Connect(function(kind, a, b)
			if kind == "SparKO" and type(a) == "number" and type(b) == "number" then
				knockedDown(a, b)
			end
		end)
	end)
	-- Menus open and close, seats are taken: a light check a few times a second.
	local nextCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextCheck then
			return
		end
		nextCheck = now + 0.2
		refreshBar()
		refreshDown()
		refreshSwitch()
	end)
	refreshBar()
end

return SparKit
