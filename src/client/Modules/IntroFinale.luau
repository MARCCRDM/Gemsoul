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
	  4½. Meteor  a little after the minions, the meteor and its Magma Golem
	              (Server.MeteorGolemServer.soon: its own cinematic and fight)
	  5. Invite   a window: your first boss, Bombardiro Drago, its rewards,
	              GO (the Bounty Board on it) or LATER
	  6. Done     the lobby's yours

	Every line shows on screen and is read out (VoiceOver). Any step that
	can't happen (no rock near, no roll owed) is passed over.

	  IntroFinale.start()   once (Lobby.client)
	  IntroFinale.Lines     what's said
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local GemClient = require(script.Parent.GemClient)
local UiKit = require(script.Parent.UiKit)
local VoiceOver = require(script.Parent.VoiceOver)

local IntroFinale = {}

IntroFinale.Lines = {
	Mine = "Hit the rock to mine it.",
	Gems = "Mining digs up gems. Put a gem in your gear to enchant it: each one gives you a move on Q, E or R. Better gems hide further out.",
	Minions = "These are rot minions. They still try to steal your gems. Your kaijus are trained to fight and defend you.",
	Fight = "Your kaijus will defend you. Train and protect them, and they will protect you.",
	Invite = "You're ready for your first boss: Bombardiro Drago. Take him on from the Bounty Board.",
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
	VoiceOver.say(IntroFinale.Lines.Mine)
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
	banner("NICE HIT!", "That's how you mine")
	task.wait(1.4)
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
	VoiceOver.say(IntroFinale.Lines.Gems)
	while not done and shade.Parent do
		task.wait(0.1)
	end
	VoiceOver.stop()
	shade:Destroy()
end

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
	VoiceOver.say(IntroFinale.Lines.Minions)
	-- Till every minion's through and landed (and the line's had its time).
	local started = os.clock()
	local deployed = tonumber(result.Deployed) or 0
	while os.clock() - started < IntroFinale.CinematicSeconds or workspace:GetServerTimeNow() < deployed do
		if os.clock() - started > 20 then
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
local function kaiju()
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
	GemClient.request("IntroFinale", "Fight")
	banner("YOUR KAIJU DEFEND YOU", "Train and protect them, and they'll protect you")
	VoiceOver.say(IntroFinale.Lines.Fight)
	local started = os.clock()
	while os.clock() - started < IntroFinale.FightFor do
		task.wait(2)
		local left = GemClient.request("IntroFinale", "Left")
		if left and left.Ok and (left.Left or 0) <= 0 then
			break
		end
	end
end

-- 5. Your first boss ----------------------------------------------------------------------------------------
IntroFinale.Rewards = {
	{ "◆", "A boss cache: a Helmet piece, Uncommon or better", Color3.fromRGB(255, 196, 90) },
	{ "✦", "Gems for your gear", Color3.fromRGB(94, 206, 221) },
	{ "▲", "A new kaiju: one for every boss you beat", Color3.fromRGB(150, 230, 120) },
}
local function invite()
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
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(480, 360)
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
	local function text(value: string, x: number, y: number, w: number, h: number, size: number, color: Color3, font: Enum.Font, center: boolean?)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position, t.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
		t.Font, t.TextSize, t.TextColor3 = font, size, color
		t.TextWrapped = true
		t.TextXAlignment = if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
		t.Text = value
		t.Parent = card
		return t
	end
	text("YOUR FIRST BOSS", 0, 20, 480, 18, 14, Color3.fromRGB(255, 150, 120), Enum.Font.GothamBold, true)
	text("BOMBARDIRO DRAGO", 0, 40, 480, 36, 32, GOLD, Enum.Font.GothamBlack, true)
	text("Level 2  ·  Recommended solo  ·  in the Ashfall", 0, 78, 480, 18, 14, Color3.fromRGB(220, 200, 196), Enum.Font.GothamMedium, true)
	text("REWARDS", 30, 112, 420, 18, 13, Color3.fromRGB(255, 150, 120), Enum.Font.GothamBold)
	for i, row in IntroFinale.Rewards do
		local y = 134 + (i - 1) * 40
		text(row[1], 30, y, 28, 34, 22, row[3], Enum.Font.GothamBlack)
		text(row[2], 66, y, 386, 34, 16, Color3.fromRGB(236, 238, 244), Enum.Font.GothamMedium)
	end
	local choice = nil
	local function button(label: string, x: number, w: number, primary: boolean, pick: string)
		local b = Instance.new("TextButton")
		b.Name = pick
		b.Position, b.Size = UDim2.fromOffset(x, 290), UDim2.fromOffset(w, 50)
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
	end
	button("LATER", 30, 130, false, "Later")
	button("TAKE HIM ON", 176, 274, true, "Go")
	VoiceOver.say(IntroFinale.Lines.Invite)
	while not choice and shade.Parent do
		task.wait(0.1)
	end
	VoiceOver.stop()
	shade:Destroy()
	if choice == "Go" then
		pcall(function()
			require(script.Parent.RiftClient).openGate("Bounty")
		end)
	end
end

local running = false
local function run()
	if running then
		return
	end
	running = true
	local ok, problem = pcall(function()
		mine()
		gems()
		if minions() then
			kaiju()
		end
	end)
	if not ok then
		warn("[IntroFinale] " .. tostring(problem))
	end
	local done = GemClient.request("IntroFinale", "Done")
	banner("WELL DONE, MINER", "The Outpost is yours")
	VoiceOver.say(IntroFinale.Lines.Done)
	task.wait(3)
	banner(nil)
	-- A little after, the meteor (its Magma Golem: Server.MeteorGolemServer):
	-- its fight first, then the first boss's window.
	if done and done.Meteor then
		local started = os.clock()
		while player:GetAttribute("MeteorGolem") == nil and os.clock() - started < IntroFinale.MeteorWait do
			task.wait(0.5)
		end
		started = os.clock()
		while player:GetAttribute("MeteorGolem") ~= nil and os.clock() - started < IntroFinale.GolemFor do
			task.wait(1)
		end
		task.wait(2)
	end
	pcall(invite)
	running = false
end

-- In the Outpost, nothing else up: the finale's turn.
local function ready(): boolean
	if player:GetAttribute("IntroFinale") ~= "Mines" or player:GetAttribute("Outpost") ~= true then
		return false
	end
	if player:GetAttribute("CombatSession") ~= nil or player:GetAttribute("MatchId") ~= nil then
		return false
	end
	local busy = false
	pcall(function()
		busy = require(script.Parent.LoadingFlow).active() or require(script.Parent.IntroRoundsUI).busy()
	end)
	return not busy and root() ~= nil
end

local started = false
function IntroFinale.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			task.wait(0.5)
			if not running and ready() then
				task.wait(1) -- (a beat in the Outpost first)
				if ready() then
					run()
				end
			end
		end
	end)
end

return IntroFinale
