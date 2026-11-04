--[[
	The intro's finale, after its six rounds (Server.IntroRoundsServer: the
	IntroFinale attribute, "Mines", while it's to do). Short and sweet:

	  1. Mine     out at the foot of the Shelter's ramp (ShelterFront), its
	              welcome rocks round it,
	              arrows to it: HIT THE ROCK, read out too
	  2. Gems     a small window, GEMS & ENCHANTING: mining digs up gems,
	              a gem in your gear enchants it with a move on Q, E or R,
	              better gems are further out; read out; OK
	  3. Minions  a cinematic (letterboxed, the camera over your shoulder on
	              them): three rift portals tear open ahead of you and a rot
	              minion hops out of each, the voice explaining as they come:
	              "These are rot minions. They still try to steal your gems.
	              Your kaijus are trained to fight and defend you." It ends
	              once they've all landed
	  4. Kaiju    the kaiju roll (KaijuRoll), the kaiju out, the minions let
	              loose ("Fight") and the kaiju engage: "Your kaijus will
	              defend you. Train and protect them, and they will protect
	              you."
	  5. Invite   a few seconds after the kaiju's fight, a window: your first
	              dungeon? Its boss (Bombardiro Drago, turning in a
	              viewport), what you'd win as tiles (coins, boss cache
	              gear, a new kaiju, gems, kaiju EXP), ENTER DUNGEON (its
	              gate, the Bounty Board on it) or LATER
	  6. Done     the lobby's yours; then, if they didn't go, the meteor
	              and its Magma Golem (Server.MeteorGolemServer.soon: its
	              own cinematic and fight)

	Every line shows on screen (nothing is read out). Any step that
	can't happen (no rock near, no roll owed) is passed over.

	  IntroFinale.start()   once (Lobby.client)
	  IntroFinale.offerBoss()   FIRST BOSS from the rounds' card: its window
	  IntroFinale.Lines     what's said
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)

local IntroFinale = {}

IntroFinale.Lines = {
	Mine = "Hit the rock to mine it.",
	Gems = "Mining digs up gems. Put a gem in your gear to enchant it: each one gives you a move on Q, E or R. Better gems hide further out.",
	Minions = "These are rot minions. They still try to steal your gems. Your kaijus are trained to fight and defend you.",
	Fight = "Your kaijus will defend you. Train and protect them, and they will protect you.",
	Invite = "You're ready for your first dungeon. Its boss is Bombardiro Drago. Beat him for coins, gear, gems and a new kaiju. Want to go?",
	Hunt = "Your next event: hunt the bounty. Bombardiro Drago waits at the end of your first dungeon. Beat him for a thousand coins, gear, gems and a new kaiju.",
	Reward = "Bounty claimed! Your reward: a new kaiju.",
	Finish = "Recommended: finish your intro fights. Each one wins you another piece of your gear set.",
	Done = "Well done, miner. Welcome to the Outpost.",
}
IntroFinale.Commons = { Field = true, Common = true } -- (the plain rocks: IntroGuide's)
IntroFinale.MineFor = 90 -- seconds before the rock step moves on by itself
IntroFinale.FightFor = 75 -- and the minions' fight
IntroFinale.Hit = 24 -- a rock losing health this close to you: you hit it
IntroFinale.Near = 60 -- a rock this near counts as one by you (else it waits for one to stream in)
IntroFinale.FindFor = 6 -- seconds it waits for one
IntroFinale.CinematicSeconds = 7 -- at least (till every minion's landed)
IntroFinale.MeteorWait = 25 -- seconds the first boss's window waits for the meteor to come
IntroFinale.GolemFor = 6 * 60 -- and for its golem's fight
IntroFinale.GemsFor = 30 -- seconds the gems window waits for OK before it moves on by itself
IntroFinale.InviteFor = 45 -- and the first dungeon's window (then: LATER)
IntroFinale.InviteAfter = 3 -- seconds after the kaiju's first fight before it's asked
IntroFinale.HuntAgain = 6 -- seconds after the HUNT BOUNTY window before it can come again (the gate's up by then)
IntroFinale.HuntLater = 180 -- seconds it stays away after LATER (or X, Esc): the Bounty Board and PLAY have it meanwhile
IntroFinale.FinishFor = 40 -- seconds the "finish your intro fights" window waits (then: LATER)

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(240, 186, 92)
local INK = Color3.fromRGB(7, 10, 17)

local gui: ScreenGui? = nil
local function screen(): ScreenGui
	if not gui then
		gui = UiKit.gui("IntroFinale", 60)
		gui.IgnoreGuiInset = true
	end
	return gui :: ScreenGui
end

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where they are in it, for the DEV spectator (Server.IntroRoundsServer
-- puts it on them as IntroFinaleStep).
local function step(name: string)
	task.spawn(function()
		pcall(GemClient.request, "IntroFinale", "Step", name)
	end)
end

-- Waits for a window's answer: `picked()` set by its buttons, Enter, Space
-- or a controller's A for `key`, or `late` after `seconds` (never stuck
-- behind a window: a locked mouse, something over the button). Its buttons
-- free the mouse while it's up (Modal).
local function answer(buttons: { TextButton }, picked: () -> string?, key: string, late: string, seconds: number, shade: Instance): string
	for _, b in buttons do
		b.Modal = true
	end
	local keyed: string? = nil
	local keys = UserInputService.InputBegan:Connect(function(input)
		local k = input.KeyCode
		if k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter or k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonA then
			keyed = key
		end
	end)
	local started = os.clock()
	while not picked() and not keyed and shade.Parent and os.clock() - started < seconds do
		task.wait(0.1)
	end
	keys:Disconnect()
	return picked() or keyed or late
end

-- A strip at the top: a big line and a small one under it.
local bannerFrame: Frame? = nil
local function banner(title: string?, sub: string?)
	if bannerFrame then
		bannerFrame:Destroy()
		bannerFrame = nil
	end
	if not title then
		return
	end
	local f = Instance.new("Frame")
	f.Name = "Banner"
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Position = UDim2.new(0.5, 0, 0, 70)
	f.Size = UDim2.fromOffset(520, 74)
	f.BackgroundColor3 = INK
	f.BackgroundTransparency = 0.25
	f.Parent = screen()
	UiKit.round(f, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Transparency = GOLD, 1.5, 0.3
	stroke.Parent = f
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position, t.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 32)
	t.Font, t.TextSize, t.TextColor3 = Enum.Font.GothamBlack, 26, GOLD
	t.Text = title
	t.Parent = f
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Position, s.Size = UDim2.fromOffset(12, 42), UDim2.new(1, -24, 0, 22)
	s.Font, s.TextSize, s.TextColor3 = Enum.Font.GothamMedium, 15, Color3.fromRGB(230, 236, 246)
	s.TextWrapped = true
	s.Text = sub or ""
	s.Parent = f
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = f
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	bannerFrame = f
end

-- 1. The rock ------------------------------------------------------------------------------------------
local function nearestRock(at: Vector3): (Instance?, Vector3?)
	local best, bestAt, bestD = nil, nil, math.huge
	for _, rock in CollectionService:GetTagged("OutpostNode") do
		local part = if rock:IsA("Model") then rock.PrimaryPart else nil
		if part and IntroFinale.Commons[rock:GetAttribute("Zone") or ""] then
			local d = (part.Position - at).Magnitude
			if d < bestD then
				best, bestAt, bestD = rock, part.Position, d
			end
		end
	end
	return best, bestAt
end

local function mine()
	local r = root()
	if not r then
		return
	end
	-- Out at the foot of the Shelter's ramp (its welcome rocks round it:
	-- the ShelterFront landmark), facing the quarry.
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local front = landmarks and landmarks:GetAttribute("ShelterFront")
	if typeof(front) == "CFrame" then
		pcall(function()
			player:RequestStreamAroundAsync(front.Position, 4)
		end)
		pcall(function()
			(player.Character :: Model):PivotTo(front + Vector3.new(0, 1, 0))
		end)
		task.wait(0.3)
		r = root() or r
	end
	-- (The rocks round you stream in a moment after you land: wait for one
	-- close by before picking, so the arrows don't lead off to a far one.)
	local rock, at = nearestRock(r.Position)
	local waited = os.clock()
	while os.clock() - waited < IntroFinale.FindFor and (not at or (at - r.Position).Magnitude > IntroFinale.Near) do
		task.wait(0.25)
		r = root() or r
		rock, at = nearestRock(r.Position)
	end
	if not rock or not at then
		return
	end
	if typeof(front) ~= "CFrame" then
		-- (no landmark: put out by the nearest rock, a few steps off, facing it)
		local away = Vector3.new(r.Position.X - at.X, 0, r.Position.Z - at.Z)
		away = if away.Magnitude > 0.5 then away.Unit else Vector3.new(0, 0, 1)
		local stand = at + away * 11 + Vector3.new(0, 4, 0)
		pcall(function()
			(player.Character :: Model):PivotTo(CFrame.lookAt(stand, Vector3.new(at.X, stand.Y, at.Z)))
		end)
	end
	banner("HIT THE ROCK", "Swing your pick at it: click, or tap")
	-- The arrows always lead to the rock nearest you now (a rock mined out or
	-- one nearer as you walk: the way follows).
	local GroundGuide = nil
	pcall(function()
		GroundGuide = require(script.Parent.GroundGuide)
		local looked = 0
		GroundGuide.set("IntroFinale", function()
			local me = root()
			if me and os.clock() - looked > 0.5 then
				looked = os.clock()
				local _, near = nearestRock(me.Position)
				if near then
					at = near
				end
			end
			return at
		end, 0)
	end)
	-- A hit on any rock close to you counts.
	local hit = false
	local watches = {}
	local function watch(node: Instance)
		if watches[node] then
			return
		end
		local last = node:GetAttribute("Hp")
		watches[node] = node:GetAttributeChangedSignal("Hp"):Connect(function()
			local hp = node:GetAttribute("Hp")
			local me = root()
			local part = if node:IsA("Model") then node.PrimaryPart else nil
			if
				type(hp) == "number"
				and type(last) == "number"
				and hp < last
				and me
				and part
				and (me.Position - part.Position).Magnitude < IntroFinale.Hit
			then
				hit = true
			end
			last = hp
		end)
	end
	for _, node in CollectionService:GetTagged("OutpostNode") do
		watch(node)
	end
	local added = CollectionService:GetInstanceAddedSignal("OutpostNode"):Connect(watch)
	local started = os.clock()
	while not hit and os.clock() - started < IntroFinale.MineFor do
		task.wait(0.2)
	end
	added:Disconnect()
	for _, c in watches do
		c:Disconnect()
	end
	if GroundGuide then
		pcall(GroundGuide.clear, "IntroFinale")
	end
	banner(nil)
end

-- 2. Gems and enchanting ---------------------------------------------------------------------------------
local function gems()
	local shade = Instance.new("TextButton")
	shade.Name = "GemsIntro"
	shade.AutoButtonColor = false
	shade.Text = ""
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.Parent = screen()
	TweenService:Create(shade, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(460, 318)
	card.BackgroundColor3 = Color3.fromRGB(15, 21, 31)
	card.Parent = shade
	UiKit.round(card, 18)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = GOLD, 2
	edge.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local function text(value: string, y: number, size: number, color: Color3, font: Enum.Font, h: number)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position, t.Size = UDim2.fromOffset(28, y), UDim2.new(1, -56, 0, h)
		t.Font, t.TextSize, t.TextColor3 = font, size, color
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = value
		t.Parent = card
		return t
	end
	local title = text("GEMS & ENCHANTING", 22, 26, GOLD, Enum.Font.GothamBlack, 32)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local rows = {
		{ "◆", "Mining digs up gems.", Color3.fromRGB(94, 206, 221) },
		{ "✦", "Put a gem in your gear to enchant it: each gives you a move on Q, E or R.", Color3.fromRGB(255, 140, 90) },
		{ "▲", "Better gems, stronger moves. They hide further out.", Color3.fromRGB(150, 230, 120) },
	}
	for i, row in rows do
		local y = 72 + (i - 1) * 56
		local mark = text(row[1], y, 24, row[3], Enum.Font.GothamBlack, 40)
		mark.Size = UDim2.fromOffset(30, 40)
		local line = text(row[2], y, 17, Color3.fromRGB(230, 236, 246), Enum.Font.GothamMedium, 46)
		line.Position = UDim2.fromOffset(66, y)
		line.Size = UDim2.new(1, -94, 0, 46)
	end
	local done = false
	local ok = Instance.new("TextButton")
	ok.Name = "Ok"
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -20)
	ok.Size = UDim2.fromOffset(200, 50)
	ok.BackgroundColor3 = GOLD
	ok.Font, ok.TextSize, ok.TextColor3 = Enum.Font.GothamBlack, 22, INK
	ok.Text = "OK"
	ok.Parent = card
	UiKit.round(ok, 12)
	ok:SetAttribute("UiSound", "Click")
	ok.Activated:Connect(function()
		done = true
	end)
	answer({ ok }, function()
		return if done then "Ok" else nil
	end, "Ok", "Ok", IntroFinale.GemsFor, shade)
	shade:Destroy()
end

-- Off in a fight (a 1v1, the Arena, a queue, the Rift): the lobby's intro
-- stops where it is and picks up from that step once they're back.
local AWAY = "[IntroFinale] away in a fight"
local function away(): boolean
	return player:GetAttribute("CombatSession") ~= nil
		or player:GetAttribute("MatchId") ~= nil
		or player:GetAttribute("DuelQueue") ~= nil
		or player:GetAttribute("RiftRun") ~= nil
end
IntroFinale._away = away
local stepsDone: { [string]: boolean } = {} -- (this visit: steps already through)

-- 3. The rot minions, in a cinematic -----------------------------------------------------------------------
local function minions(): boolean
	local result = GemClient.request("IntroFinale", "Critters")
	if not (result and result.Ok) then
		return false
	end
	local portals = result.Portals or {}
	local r = root()
	local camera = workspace.CurrentCamera
	if not r or not camera or #portals == 0 then
		return true
	end
	local mid = Vector3.zero
	for _, portal in portals do
		mid += portal.At
	end
	mid /= #portals
	local toward = Vector3.new(mid.X - r.Position.X, 0, mid.Z - r.Position.Z)
	toward = if toward.Magnitude > 0.5 then toward.Unit else Vector3.new(0, 0, -1)
	local was = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	-- Over your shoulder, all three portals in view, easing in as they come.
	local up = Vector3.new(0, 6, 0)
	local from = CFrame.lookAt(r.Position - toward * 10 + Vector3.new(0, 7, 0), mid + up)
	local to = CFrame.lookAt(r.Position + toward * 4 + Vector3.new(0, 6, 0), mid + up * 0.6)
	camera.CFrame = from
	TweenService:Create(camera, TweenInfo.new(IntroFinale.CinematicSeconds, Enum.EasingStyle.Sine), { CFrame = to }):Play()
	-- Letterboxed, the line along the bottom.
	local bars = {}
	for i, y in { 0, 1 } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0, y)
		bar.Position = UDim2.fromScale(0, y)
		bar.Size = UDim2.new(1, 0, 0, 0)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Parent = screen()
		TweenService:Create(bar, TweenInfo.new(0.5), { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
		bars[i] = bar
	end
	local caption = Instance.new("TextLabel")
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -18)
	caption.Size = UDim2.new(0.8, 0, 0.1, 0)
	caption.BackgroundTransparency = 1
	caption.Font, caption.TextColor3 = Enum.Font.GothamBold, Color3.fromRGB(240, 244, 250)
	caption.TextScaled = true
	caption.TextWrapped = true
	caption.Text = IntroFinale.Lines.Minions
	caption.ZIndex = 3
	caption.Parent = screen()
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 26
	cap.Parent = caption
	-- Till every minion's through and landed (and the line's had its time).
	local started = os.clock()
	local deployed = tonumber(result.Deployed) or 0
	while os.clock() - started < IntroFinale.CinematicSeconds or workspace:GetServerTimeNow() < deployed do
		if os.clock() - started > 20 or away() then
			break
		end
		task.wait(0.1)
	end
	for _, bar in bars do
		TweenService:Create(bar, TweenInfo.new(0.4), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	end
	caption:Destroy()
	camera.CameraType = if was == Enum.CameraType.Scriptable then Enum.CameraType.Custom else was
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	task.delay(0.5, function()
		for _, bar in bars do
			bar:Destroy()
		end
	end)
	return true
end

-- 4. The kaiju roll, then the fight -------------------------------------------------------------------------
local function kaiju(fight: boolean?)
	local profile = GemClient.Profile
	if profile and Kaiju.rollsOwed(profile) > 0 then
		local KaijuRoll = require(script.Parent.KaijuRoll)
		local rolled = false
		task.spawn(function()
			KaijuRoll.play(function()
				rolled = true
			end)
		end)
		local started = os.clock()
		while not rolled and os.clock() - started < 120 do
			task.wait(0.2)
		end
		task.wait(1.5) -- (they come out round you)
	end
	if fight == false then
		return
	end
	GemClient.request("IntroFinale", "Fight")
	local started = os.clock()
	while os.clock() - started < IntroFinale.FightFor and not away() do
		task.wait(2)
		local left = GemClient.request("IntroFinale", "Left")
		if left and left.Ok and (left.Left or 0) <= 0 then
			break
		end
	end
end

-- 5. Your first dungeon -------------------------------------------------------------------------------------
-- Asked right after the first mining and the kaiju's first fight: GO takes
-- you to the dungeon's gate (the Bounty Board on its boss), LATER leaves it
-- on the board. What you'd win shows as tiles (the real numbers: a boss
-- run's coins and kaiju EXP, Shared.RiftRun; its cache, Shared.BossLoot's
-- threat I floor; a kaiju roll for every boss beaten). HUNT BOUNTY's (the
-- first dungeon): IntroRounds.FirstDungeonCoins.
IntroFinale.Boss = "Drago" -- (its figure: ReplicatedStorage.RiftPortraits)
-- `hunt`: the first dungeon (HUNT BOUNTY): its own purse (IntroRounds.
-- FirstDungeonCoins).
function IntroFinale.rewards(hunt: boolean?)
	local RiftRun = require(ReplicatedStorage.Shared.RiftRun)
	local IntroRounds = require(ReplicatedStorage.Shared.IntroRounds)
	return {
		{ Icon = "●", Value = tostring(if hunt then IntroRounds.FirstDungeonCoins else RiftRun.rewardCoins(RiftRun.Rooms)), Label = "COINS", Color = Color3.fromRGB(255, 206, 92) },
		{ Icon = "◆", Value = "UNCOMMON+", Label = "BOSS CACHE GEAR", Color = Color3.fromRGB(110, 224, 140) },
		{ Icon = "▲", Value = "+1", Label = "NEW KAIJU", Color = Color3.fromRGB(150, 200, 255) },
		-- (The first dungeon has no caves, straight to the boss: its gem.)
		if hunt
			then { Icon = "◆", Value = "GEM", Label = "FROM THE BOSS", Color = Color3.fromRGB(94, 206, 221) }
			else { Icon = "◆", Value = "GEMS", Label = "IN EVERY CAVE", Color = Color3.fromRGB(94, 206, 221) },
	}, RiftRun.Reward.Exp
end
local W_CARD, H_CARD = 620, 470
local function bossView(card: Frame)
	local view = Instance.new("ViewportFrame")
	view.Name = "Boss"
	view.Position, view.Size = UDim2.fromOffset(18, 18), UDim2.fromOffset(196, 236)
	view.BackgroundColor3 = Color3.fromRGB(40, 16, 14)
	view.Ambient, view.LightColor = Color3.fromRGB(150, 120, 110), Color3.fromRGB(255, 220, 200)
	view.Parent = card
	UiKit.round(view, 14)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.Parent = view
	view.CurrentCamera = camera
	-- (its figure may still be on its way from the server: put in when it comes)
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("RiftPortraits", 10)
		local source = folder and folder:WaitForChild(IntroFinale.Boss, 10)
		if not (source and source:IsA("Model")) or not view.Parent then
			return
		end
		local body = source:Clone()
		body:PivotTo(CFrame.new())
		body.Parent = view
		local _, size = body:GetBoundingBox()
		local reach = math.max(size.X, size.Y, size.Z)
		local spin = 0
		while view.Parent do
			spin += 0.02
			local at = CFrame.Angles(0, math.rad(200) + math.sin(spin) * 0.5, 0) * Vector3.new(0, size.Y * 0.08, reach * 1.7)
			camera.CFrame = CFrame.lookAt(at, Vector3.new(0, 0, 0))
			task.wait(1 / 30)
		end
	end)
end
-- `hunt`: the first dungeon's owed (IntroFinale "Dungeon"): NEXT EVENT ·
-- HUNT BOUNTY, one button, no LATER and no clock (the lobby opens once it's
-- cleared).
local function invite(hunt: boolean?)
	local shade = Instance.new("TextButton")
	shade.Name = "FirstBoss"
	shade.AutoButtonColor = false
	shade.Text = ""
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.Parent = screen()
	TweenService:Create(shade, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(W_CARD, H_CARD)
	card.BackgroundColor3 = Color3.fromRGB(26, 14, 14)
	card.Parent = shade
	UiKit.round(card, 18)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = Color3.fromRGB(255, 110, 80), 2
	edge.Parent = card
	local glow = Instance.new("UIGradient")
	glow.Rotation = 90
	glow.Color = ColorSequence.new(Color3.fromRGB(90, 26, 22), Color3.fromRGB(20, 12, 14))
	glow.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- (a phone: the card fits the screen)
	local camera = workspace.CurrentCamera
	if camera then
		local fit = math.min(1, (camera.ViewportSize.X - 24) / W_CARD, (camera.ViewportSize.Y - 24) / H_CARD)
		local fitScale = Instance.new("UIScale")
		fitScale.Name = "Fit"
		fitScale.Scale = fit
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromOffset(W_CARD, H_CARD)
		holder.Parent = shade
		fitScale.Parent = holder
		card.Parent = holder
	end
	local function text(parent: Instance, value: string, x: number, y: number, w: number, h: number, size: number, color: Color3, font: Enum.Font, center: boolean?)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position, t.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
		t.Font, t.TextSize, t.TextColor3 = font, size, color
		t.TextWrapped = true
		t.TextXAlignment = if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		t.Text = value
		t.Parent = parent
		return t
	end
	local closed = false
	bossView(card)
	local x0 = 234
	text(card, if hunt then "NEXT EVENT  ·  HUNT BOUNTY" else "READY FOR YOUR FIRST DUNGEON?", x0, 26, W_CARD - x0 - 20, 18, 14, Color3.fromRGB(255, 150, 120), Enum.Font.GothamBold).Name = "Heading"
	text(card, "BOMBARDIRO DRAGO", x0, 48, W_CARD - x0 - 20, 70, 34, GOLD, Enum.Font.GothamBlack).Name = "BossName"
	text(card, "Its boss  ·  Level 2  ·  built to beat solo", x0, 122, W_CARD - x0 - 20, 18, 14, Color3.fromRGB(220, 200, 196), Enum.Font.GothamMedium)
	text(card, if hunt then "Your first dungeon. Straight to the boss. Your kaiju fight beside you. The Outpost opens once he's down." else "Your kaiju fight beside you. Four caves, then the boss.", x0, 150, W_CARD - x0 - 20, if hunt then 60 else 40, 14, Color3.fromRGB(190, 176, 172), Enum.Font.GothamMedium)
	-- What you'd win: a tile each.
	local rewards, exp = IntroFinale.rewards(hunt)
	text(card, "POTENTIAL REWARDS", 18, 268, 300, 18, 13, Color3.fromRGB(255, 150, 120), Enum.Font.GothamBold)
	text(card, string.format("+ %d kaiju EXP", exp), W_CARD - 218, 268, 200, 18, 13, Color3.fromRGB(150, 200, 255), Enum.Font.GothamBold).TextXAlignment = Enum.TextXAlignment.Right
	local tileW = (W_CARD - 36 - 3 * 10) / 4
	for i, r in rewards do
		local tile = Instance.new("Frame")
		tile.Name = "Reward" .. i
		tile.Position, tile.Size = UDim2.fromOffset(18 + (i - 1) * (tileW + 10), 292), UDim2.fromOffset(tileW, 96)
		tile.BackgroundColor3 = Color3.fromRGB(14, 10, 14)
		tile.BackgroundTransparency = 0.15
		tile.Parent = card
		UiKit.round(tile, 12)
		local rim = Instance.new("UIStroke")
		rim.Color, rim.Thickness, rim.Transparency = r.Color, 1.5, 0.35
		rim.Parent = tile
		text(tile, r.Icon, 0, 6, tileW, 30, 26, r.Color, Enum.Font.GothamBlack, true)
		text(tile, r.Value, 4, 38, tileW - 8, 24, if #r.Value > 6 then 16 else 22, Color3.fromRGB(246, 246, 250), Enum.Font.GothamBlack, true)
		text(tile, r.Label, 4, 64, tileW - 8, 26, 11, Color3.fromRGB(200, 196, 204), Enum.Font.GothamBold, true)
		-- (in one after another)
		tile.BackgroundTransparency = 1
		task.delay(0.25 + i * 0.12, function()
			if not closed then
				TweenService:Create(tile, TweenInfo.new(0.25), { BackgroundTransparency = 0.15 }):Play()
			end
		end)
	end
	local choice = nil
	local buttons = {}
	local keysOnly = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	local closeX = Instance.new("TextButton")
	closeX.Name = "Close"
	closeX.AnchorPoint = Vector2.new(1, 0)
	closeX.Position, closeX.Size = UDim2.new(1, -10, 0, 10), UDim2.fromOffset(34, 34)
	closeX.BackgroundColor3 = Color3.fromRGB(52, 40, 40)
	closeX.Font, closeX.TextSize, closeX.TextColor3 = Enum.Font.GothamBlack, 18, Color3.fromRGB(230, 220, 216)
	closeX.Text = "X"
	closeX.ZIndex = 5
	closeX.Parent = card
	UiKit.round(closeX, 10)
	closeX:SetAttribute("UiSound", "Click")
	closeX.Activated:Connect(function()
		choice = "Later"
	end)
	table.insert(buttons, closeX)
	local escape = UserInputService.InputBegan:Connect(function(input, typing)
		if not typing and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			choice = "Later"
		end
	end)
	local function button(label: string, x: number, w: number, primary: boolean, pick: string)
		local b = Instance.new("TextButton")
		b.Name = pick
		b.Position, b.Size = UDim2.fromOffset(x, 402), UDim2.fromOffset(w, 52)
		b.BackgroundColor3 = if primary then GOLD else Color3.fromRGB(52, 40, 40)
		b.Font, b.TextSize = Enum.Font.GothamBlack, if primary then 20 else 16
		b.TextColor3 = if primary then INK else Color3.fromRGB(220, 210, 206)
		b.Text = label
		b.Parent = card
		UiKit.round(b, 12)
		b:SetAttribute("UiSound", "Click")
		b.Activated:Connect(function()
			choice = pick
		end)
		table.insert(buttons, b)
	end
	if hunt then
		-- (HUNT BOUNTY, and a way out: LATER, the corner's X or Esc; it's
		-- back in a while, and the Bounty Board has it any time)
		button(if keysOnly then "LATER  [ESC]" else "LATER", 18, 150, false, "Later")
		button(if keysOnly then "HUNT BOUNTY  [ENTER]" else "HUNT BOUNTY", 180, W_CARD - 198, true, "Go")
	else
		button("LATER", 18, 150, false, "Later")
		button(if keysOnly then "ENTER DUNGEON  [ENTER]" else "ENTER DUNGEON", 180, W_CARD - 198, true, "Go")
	end
	-- (Enter takes you in; left alone, LATER: the Bounty Board has it. The
	-- hunt waits for them: no LATER.)
	choice = answer(buttons, function()
		return choice
	end, "Go", if hunt then "Go" else "Later", if hunt then math.huge else IntroFinale.InviteFor, shade)
	if not choice then
		choice = "Later"
	end
	escape:Disconnect()
	closed = true
	shade:Destroy()
	if not hunt then
		pcall(function()
			GemClient.request("IntroFinale", "Invite", choice)
		end)
	end
	if choice == "Go" then
		pcall(function()
			local Rift = require(script.Parent.RiftClient)
			-- (HUNT BOUNTY: straight into Bombardiro Drago's Rift, no board
			-- to pick from and close; the board only if that can't be done)
			local inside = hunt and Rift.enterBounty("Drago")
			if not inside then
				Rift.openGate("Bounty")
			end
		end)
	end
	return choice
end

-- The first dungeon done? (Server.IntroRoundsServer.dungeonCleared)
function IntroFinale.dungeonDone(): boolean
	return player:GetAttribute("IntroDungeonCleared") == true
end

-- 7. Recommended: the intro fights left (the rest of the gear set): CONTINUE
-- FIGHTS (PLAY's own: IntroRoundNext, into the Arena) or LATER.
local function recommend()
	local state = GemClient.request("IntroRoundState")
	local view = state and state.Ok and state.View
	if type(view) ~= "table" or view.Done then
		return nil
	end
	local left = (view.Count or 6) - (view.Won or 0)
	local shade = Instance.new("TextButton")
	shade.Name = "FinishFights"
	shade.AutoButtonColor = false
	shade.Text = ""
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.5
	shade.Parent = screen()
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(460, 250)
	card.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
	card.Parent = shade
	UiKit.round(card, 18)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = GOLD, 2
	edge.Parent = card
	local camera = workspace.CurrentCamera
	if camera then
		local fit = Instance.new("UIScale")
		fit.Scale = math.min(1, (camera.ViewportSize.X - 24) / 460, (camera.ViewportSize.Y - 24) / 250)
		fit.Parent = card
	end
	local function text(value: string, y: number, h: number, size: number, color: Color3, font: Enum.Font)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position, t.Size = UDim2.fromOffset(24, y), UDim2.fromOffset(412, h)
		t.Font, t.TextSize, t.TextColor3 = font, size, color
		t.TextWrapped = true
		t.Text = value
		t.Parent = card
		return t
	end
	text("RECOMMENDED", 20, 18, 13, GOLD, Enum.Font.GothamBold)
	text("FINISH YOUR INTRO FIGHTS", 42, 34, 26, Color3.fromRGB(246, 246, 250), Enum.Font.GothamBlack)
	text(string.format("%d left  ·  each one wins another piece of your gear set", left), 80, 40, 15, Color3.fromRGB(200, 204, 216), Enum.Font.GothamMedium).Name = "Left"
	local choice = nil
	local buttons = {}
	local keysOnly = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	local function button(label: string, x: number, w: number, primary: boolean, pick: string)
		local b = Instance.new("TextButton")
		b.Name = pick
		b.Position, b.Size = UDim2.fromOffset(x, 172), UDim2.fromOffset(w, 52)
		b.BackgroundColor3 = if primary then GOLD else Color3.fromRGB(44, 48, 62)
		b.Font, b.TextSize = Enum.Font.GothamBlack, if primary then 18 else 15
		b.TextColor3 = if primary then INK else Color3.fromRGB(214, 216, 226)
		b.Text = label
		b.Parent = card
		UiKit.round(b, 12)
		b:SetAttribute("UiSound", "Click")
		b.Activated:Connect(function()
			choice = pick
		end)
		table.insert(buttons, b)
	end
	button("LATER", 24, 130, false, "Later")
	button(if keysOnly then "CONTINUE FIGHTS  [ENTER]" else "CONTINUE FIGHTS", 166, 270, true, "Go")
	choice = answer(buttons, function()
		return choice
	end, "Go", "Later", IntroFinale.FinishFor, shade)
	shade:Destroy()
	if choice == "Go" then
		local result = GemClient.request("IntroRoundNext")
		if not (result and result.Ok) then
			UiKit.toast(result and result.Message or "PLAY carries on your intro fights.", GOLD)
		end
	end
	return choice
end

IntroFinale._invite = invite -- (tests)
IntroFinale._recommend = function()
	return recommend()
end

local running = false
local function run()
	if running then
		return
	end
	running = true
	local ok, problem = pcall(function()
		-- The first dungeon's prize first: a new kaiju (the boss's roll,
		-- Kaiju.bossRollsOwed), rolled as soon as they're back.
		if IntroFinale.dungeonDone() and GemClient.Profile and Kaiju.rollsOwed(GemClient.Profile) == 0 and Kaiju.bossRollsOwed(GemClient.Profile) > 0 then
			step("Kaiju")
			local rolled = false
			task.spawn(function()
				require(script.Parent.KaijuRoll).play(function()
					rolled = true
				end)
			end)
			local started = os.clock()
			while not rolled and os.clock() - started < 120 do
				task.wait(0.2)
			end
			banner(nil)
		end
		local function stage(name: string, fn: () -> any): any
			if away() then
				error(AWAY, 0)
			end
			if stepsDone[name] then
				return true
			end
			step(name)
			local result = fn()
			if away() then
				error(AWAY, 0) -- (cut short by a fight: this step again later)
			end
			stepsDone[name] = true
			return result
		end
		stage("Mine", mine)
		stage("Gems", gems)
		local came = stage("Minions", minions)
		-- (the kaiju roll, even if the minions didn't come: nobody's left without one)
		stage("Kaiju", function()
			kaiju(came)
		end)
	end)
	if not ok and problem == AWAY then
		-- Into a fight: stop here, banners down; on from this step once
		-- they're back in the Outpost (due).
		banner(nil)
		step("Away")
		running = false
		return
	end
	if not ok then
		warn("[IntroFinale] " .. tostring(problem))
	end
	-- (The first dungeon comes before the lobby's intro now: HUNT BOUNTY.
	-- Only an older save that came out here first is asked about it.)
	local going = false
	if not IntroFinale.dungeonDone() then
		task.wait(IntroFinale.InviteAfter)
		step("Invite")
		local okInvite, picked = pcall(invite)
		going = okInvite and picked == "Go"
	end
	local done = GemClient.request("IntroFinale", "Done")
	if not going then
		banner(nil)
	end
	-- A little after, the meteor (its Magma Golem: Server.MeteorGolemServer):
	-- its fight first, then the first boss's window.
	if done and done.Meteor and not going then
		local started = os.clock()
		while player:GetAttribute("MeteorGolem") == nil and os.clock() - started < IntroFinale.MeteorWait do
			task.wait(0.5)
		end
		started = os.clock()
		while player:GetAttribute("MeteorGolem") ~= nil and os.clock() - started < IntroFinale.GolemFor do
			task.wait(1)
		end
	end
	-- Recommended next: the rest of the intro fights (if any are left).
	if not going then
		pcall(recommend)
	end
	step("Over")
	running = false
end

-- In the Outpost, nothing else up: the finale's turn.
-- (Held a moment: the first boss chosen from the rounds' card, its window
-- and the gate's lobby first: IntroFinale.offerBoss.)
local heldUntil = 0
local function gateUp(): boolean
	local ok, up = pcall(function()
		return require(script.Parent.RiftClient).gateOpen()
	end)
	return ok and up == true
end
-- (Due: in the Outpost with it to do, out of any fight, the Rift and its gate.)
local function due(): boolean
	if player:GetAttribute("IntroFinale") ~= "Mines" or player:GetAttribute("Outpost") ~= true then
		return false
	end
	if away() then
		return false
	end
	if os.clock() < heldUntil or player:GetAttribute("RiftRun") ~= nil or gateUp() then
		return false
	end
	return root() ~= nil
end
local function ready(): boolean
	if not due() then
		return false
	end
	local busy = false
	pcall(function()
		busy = require(script.Parent.LoadingFlow).active() or require(script.Parent.IntroRoundsUI).busy()
	end)
	return not busy
end
IntroFinale.WaitAtMost = 20 -- seconds it waits for a screen still up (a card, a loading screen) when it's due

-- While the first dungeon's owed (IntroFinale "Dungeon"): the HUNT BOUNTY
-- window, then the Bounty Board's gate; again after a trip that didn't
-- beat the boss, till it's down (Server.RiftServer: IntroRoundsServer.dungeonCleared).
local function huntDue(): boolean
	if player:GetAttribute("IntroFinale") ~= "Dungeon" or player:GetAttribute("Outpost") ~= true then
		return false
	end
	if player:GetAttribute("CombatSession") ~= nil or player:GetAttribute("MatchId") ~= nil then
		return false
	end
	if os.clock() < heldUntil or player:GetAttribute("RiftRun") ~= nil or gateUp() then
		return false
	end
	local busy = false
	pcall(function()
		busy = require(script.Parent.LoadingFlow).active() or require(script.Parent.IntroRoundsUI).busy() or require(script.Parent.KaijuRoll).showing()
	end)
	return not busy and root() ~= nil
end
local hunting = false
local direct = false -- (HUNT BOUNTY pressed on the rounds' card: straight in, no window: offerBoss)
function IntroFinale.hunt()
	if hunting then
		return
	end
	hunting = true
	-- (Never into the dungeon without a kaiju: a starter roll still owed,
	-- a first win from before it was rolled there or a roll cut short,
	-- plays first.)
	if GemClient.Profile and Kaiju.rollsOwed(GemClient.Profile) > 0 then
		step("Kaiju")
		local rolled = false
		task.spawn(function()
			require(script.Parent.KaijuRoll).play(function()
				rolled = true
			end)
		end)
		local started = os.clock()
		while not rolled and os.clock() - started < 150 do
			task.wait(0.2)
		end
		banner(nil)
		task.wait(1.5) -- (they come out round you)
	end
	step("Invite")
	local inside = false
	if direct then
		-- (chosen on the rounds' card, which showed the bounty: straight in)
		direct = false
		local ok, went = pcall(function()
			return require(script.Parent.RiftClient).enterBounty(IntroFinale.Boss)
		end)
		inside = ok and went == true
	end
	local picked = nil
	if not inside then
		local ok, answer = pcall(invite, true) -- (HUNT BOUNTY takes them in: invite)
		picked = ok and answer or nil
	end
	heldUntil = os.clock() + (if picked == "Later" then IntroFinale.HuntLater else IntroFinale.HuntAgain) -- (the gate's lobby opens: huntDue waits on it)
	hunting = false
end

-- FIRST BOSS on the rounds' card (Client IntroRoundsUI): once they're out
-- in the Outpost, the first boss's window (TAKE HIM ON: the Bounty Board's
-- gate). The mines and the kaiju wait till that's done with.
-- `straight`: HUNT BOUNTY pressed on the rounds' card (it showed the
-- bounty): in as soon as they're out in the Outpost, no window first.
function IntroFinale.offerBoss(straight: boolean?)
	-- (the hunt's loop takes it as soon as they're out in the Outpost: huntDue)
	heldUntil = 0
	direct = straight == true
end

local started = false
function IntroFinale.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		local dueSince: number? = nil
		while true do
			task.wait(0.5)
			if running or hunting then
				dueSince = nil
			elseif huntDue() then
				task.wait(0.8) -- (a beat in the Outpost first)
				if huntDue() then
					IntroFinale.hunt()
				end
			elseif ready() then
				task.wait(1) -- (a beat in the Outpost first)
				if ready() then
					dueSince = nil
					run()
				end
			elseif due() then
				-- (Something's held the screen too long: never stuck behind it.)
				dueSince = dueSince or os.clock()
				if os.clock() - dueSince > IntroFinale.WaitAtMost then
					warn("[IntroFinale] starting past a screen still up")
					dueSince = nil
					run()
				end
			else
				dueSince = nil
			end
		end
	end)
end

return IntroFinale
