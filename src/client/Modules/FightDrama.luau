--[[
	The fight's drama: what makes a 1v1 feel like a bout rather than an
	exchange of numbers. Client only, nothing replicates.

	  Announcer   big words punched onto the middle of the screen and read
	              out by an announcer's voice (Roblox text-to-speech):
	              FIGHT!, FIRST BLOOD, combos (x3, x5, x8), a crushing
	              blow, PERFECT PARRY, LAST STAND, K.O.!, FLAWLESS
	  K.O.        the blow that ends a round or a fight: a white flash, the
	              colour drained for a beat, the view punching in, a shake
	              (an opponent's RoundKO or death: Server Duels, Duelist)
	  Low health  under LowAt: the screen pulses red with a heartbeat that
	              quickens near the end, and the music goes muffled
	  Rivals      the bot you fight (Server Duelist: RivalOwner is you)
	              walks in with VS NAME and its title, says its piece (a
	              bubble over its head and its own voice), and talks back:
	              hurt, nearly beaten, gloating when you're low, crowing
	              when it wins

	Only in 1v1s (Sessions: the Arena, a duel) for the words; the low
	health pulse anywhere you fight.

	  FightDrama.start()           once (Combat.client)
	  FightDrama.setFight(on)      every frame: whether you're fighting
	  FightDrama.contact(info)     your blow landed (Combat's Contact)
	  FightDrama.parry()           you parried (Combat's HighBlock)
	  FightDrama.fight()           a duel's FIGHT (Social "Fight")
	  FightDrama.call(text, opts)  a callout of its own
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)
local CombatFx = require(script.Parent.CombatFx)
local Music = require(script.Parent.Music)

local FightDrama = {}
FightDrama.Enabled = true
FightDrama.Sessions = { Training = true, Duel = true, PvP = true }
FightDrama.AnnouncerVoice = "2" -- (AudioTextToSpeech.VoiceId)
FightDrama.Volume = 1
FightDrama.LowAt = 0.3 -- of your health: the heartbeat starts
FightDrama.LastStandAt = 0.2 -- LAST STAND, once a fight
FightDrama.Combos = { [3] = "COMBO  x3", [5] = "x5  UNSTOPPABLE", [8] = "x8  RELENTLESS" }
-- What each intro rival says (Shared.IntroRounds.Rivals' names), and their voice.
FightDrama.Lines = {
	Pell = {
		Voice = "3",
		Enter = "Go easy on me, okay? It's my first day too.",
		Hurt = "Ow! Okay, okay, I felt that.",
		Low = "Wait, wait, I'm not ready!",
		Gloat = "Huh! I'm actually winning?",
		Win = "I did it! Nobody's going to believe this.",
	},
	["Vera Coppercoil"] = {
		Voice = "4",
		Enter = "Let's see what your gear's made of.",
		Hurt = "Hm. Better than I calculated.",
		Low = "My springs are slipping!",
		Gloat = "Your armour's rattling. Want me to tune it?",
		Win = "Back to the workbench with you.",
	},
	Sable = {
		Voice = "5",
		Enter = "You won't see me coming.",
		Hurt = "Lucky.",
		Low = "This isn't over. I don't lose.",
		Gloat = "Fading already?",
		Win = "Into the dark you go.",
	},
	Korr = {
		Voice = "6",
		Enter = "Feel the storm rising?",
		Hurt = "You call that thunder?",
		Low = "The storm... is breaking.",
		Gloat = "Lightning always finds the weakest point.",
		Win = "Struck down. As foretold.",
	},
	Magmar = {
		Voice = "7",
		Enter = "I was forged in fire. You were forged in a hurry.",
		Hurt = "Hot! You've got some fire in you.",
		Low = "My fire's... going out.",
		Gloat = "You're melting, little miner.",
		Win = "Back to the slag heap.",
	},
	Nova = {
		Voice = "8",
		Enter = "Every champion starts somewhere. You start here. Losing.",
		Hurt = "Finally, a real fight.",
		Low = "Impossible... nobody gets this far!",
		Gloat = "This is the top. Look how far you'll fall.",
		Win = "Come back when you're a legend.",
	},
}
FightDrama.Generic = {
	Voice = "6",
	Enter = "Ready when you are, miner.",
	Hurt = "Not bad.",
	Low = "Okay, you're good.",
	Gloat = "Getting tired?",
	Win = "Better luck next time.",
}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 206, 92)
local RED = Color3.fromRGB(255, 92, 80)
local ICE = Color3.fromRGB(150, 225, 255)
local WHITE = Color3.new(1, 1, 1)

local fighting = false -- (set every frame: Combat.client)
local fightSince = 0
local firstBlood = false
local lastStand = false
local busyUntil, busyRank = 0, 0
local gui: ScreenGui? = nil
local word: TextLabel? = nil
local sub: TextLabel? = nil
local pop: UIScale? = nil
local flash: Frame? = nil
local token = 0

local function inBout(): boolean
	return FightDrama.Enabled and FightDrama.Sessions[player:GetAttribute("CombatSession")] == true
end

local function screen()
	if gui and gui.Parent then
		return
	end
	gui = UiKit.gui("FightDrama", 45)
	local g = gui :: ScreenGui
	g.IgnoreGuiInset = true
	local w = Instance.new("TextLabel")
	w.Name = "Word"
	w.AnchorPoint = Vector2.new(0.5, 0.5)
	w.Position = UDim2.fromScale(0.5, 0.3)
	w.Size = UDim2.new(0.9, 0, 0, 96)
	w.BackgroundTransparency = 1
	w.Font = Enum.Font.GothamBlack
	w.TextScaled = true
	w.TextTransparency = 1
	w.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 84
	limit.Parent = w
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Color, edge.Thickness, edge.Transparency = Color3.fromRGB(10, 10, 16), 4, 1
	edge.Parent = w
	local s = Instance.new("UIScale")
	s.Parent = w
	w.Parent = g
	local under = Instance.new("TextLabel")
	under.Name = "Sub"
	under.AnchorPoint = Vector2.new(0.5, 0)
	under.Position = UDim2.new(0.5, 0, 0.3, 54)
	under.Size = UDim2.new(0.8, 0, 0, 30)
	under.BackgroundTransparency = 1
	under.Font = Enum.Font.GothamBold
	under.TextSize = 24
	under.TextColor3 = Color3.fromRGB(230, 232, 240)
	under.TextTransparency = 1
	under.Text = ""
	local underEdge = Instance.new("UIStroke")
	underEdge.Color, underEdge.Thickness, underEdge.Transparency = Color3.fromRGB(10, 10, 16), 2, 1
	underEdge.Parent = under
	under.Parent = g
	local f = Instance.new("Frame")
	f.Name = "Flash"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ZIndex = 0
	f.Parent = g
	word, sub, pop, flash = w, under, s, f
end

-- A line read out loud (text-to-speech), on this screen only; quiet if it can't.
local function speak(text: string, voiceId: string)
	pcall(function()
		local voice = Instance.new("AudioTextToSpeech")
		voice.Text = text
		voice.VoiceId = voiceId
		voice.Volume = FightDrama.Volume
		local out = Instance.new("AudioDeviceOutput")
		out.Player = player
		local wire = Instance.new("Wire")
		wire.SourceInstance = voice
		wire.TargetInstance = out
		voice.Parent = SoundService
		out.Parent = voice
		wire.Parent = voice
		voice:Play()
		task.delay(8, function()
			voice:Destroy()
		end)
	end)
end

-- Big words in the middle of the screen. opts: Color, Sub, Say (read out by
-- the announcer: true for the words themselves, or a line), Rank (one as
-- high or higher cuts in over one still up; a lower one waits), Hold (seconds).
function FightDrama.call(text: string, opts: any?)
	opts = opts or {}
	local rank = opts.Rank or 1
	local now = os.clock()
	if now < busyUntil and rank < busyRank then
		return false
	end
	screen()
	local w, s, p = word :: TextLabel, sub :: TextLabel, pop :: UIScale
	local hold = opts.Hold or 1.1
	busyUntil, busyRank = now + hold * 0.7, rank
	token += 1
	local mine = token
	w.Text = text
	w.TextColor3 = opts.Color or WHITE
	w.TextTransparency = 0
	local edge = w:FindFirstChild("Edge") :: UIStroke?
	if edge then
		edge.Transparency = 0.1
	end
	s.Text = opts.Sub or ""
	s.TextTransparency = if opts.Sub then 0 else 1
	local subEdge = s:FindFirstChildOfClass("UIStroke")
	if subEdge then
		subEdge.Transparency = if opts.Sub then 0.2 else 1
	end
	p.Scale = 1.7
	TweenService:Create(p, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if opts.Say then
		speak(if type(opts.Say) == "string" then opts.Say else string.lower(text), FightDrama.AnnouncerVoice)
	end
	task.delay(hold, function()
		if token ~= mine then
			return
		end
		TweenService:Create(w, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(s, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		if edge then
			TweenService:Create(edge, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
		if subEdge then
			TweenService:Create(subEdge, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
	end)
	return true
end

local function grade(): ColorCorrectionEffect
	local cc = Lighting:FindFirstChild("FightDramaGrade")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "FightDramaGrade"
		cc.Parent = Lighting
	end
	return cc :: ColorCorrectionEffect
end

-- The blow that ends it: a white flash, the colour drained for a beat, the
-- view punching in, a shake.
local function knockout(text: string, opts: any)
	FightDrama.call(text, opts)
	screen()
	local f = flash :: Frame
	f.BackgroundTransparency = 0.35
	TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	local cc = grade()
	cc.Saturation, cc.Contrast = -0.85, 0.2
	TweenService:Create(cc, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Saturation = 0, Contrast = 0 }):Play()
	local camera = workspace.CurrentCamera
	if camera then
		local base = camera.FieldOfView
		camera.FieldOfView = math.max(30, base - 12)
		TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base }):Play()
	end
	pcall(CombatFx.shake, 0.06, 0.4)
end

-- Your blow landed (the server's Contact: Combo, Crit, Heavy, Kill, Blocked).
function FightDrama.contact(info)
	if not inBout() or type(info) ~= "table" or info.Blocked then
		return
	end
	if not firstBlood then
		firstBlood = true
		FightDrama.call("FIRST BLOOD", { Color = RED, Say = "First blood!", Rank = 2 })
		return
	end
	local combo = tonumber(info.Combo) or 0
	local said = FightDrama.Combos[combo]
	if said then
		FightDrama.call(said, { Color = GOLD, Say = if combo >= 5 then string.lower(string.match(said, "%a+$") or said) else "combo!", Rank = 1 + combo / 10 })
	elseif info.Crit and info.Heavy then
		FightDrama.call("CRUSHING BLOW", { Color = ICE, Rank = 1 })
	end
end

-- You parried: the most skilful move gets its moment.
function FightDrama.parry()
	if not FightDrama.Enabled then
		return
	end
	if inBout() then
		FightDrama.call("PERFECT PARRY", { Color = GOLD, Say = "Perfect parry!", Rank = 2, Hold = 0.9 })
	end
	local cc = grade()
	cc.TintColor, cc.Brightness = Color3.fromRGB(255, 236, 190), 0.12
	TweenService:Create(cc, TweenInfo.new(0.5), { TintColor = WHITE, Brightness = 0 }):Play()
	local camera = workspace.CurrentCamera
	if camera then
		local base = camera.FieldOfView
		camera.FieldOfView = math.max(30, base - 6)
		TweenService:Create(camera, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base }):Play()
	end
end

-- A duel's FIGHT (the count's done).
function FightDrama.fight()
	if FightDrama.Enabled then
		speak("Fight!", FightDrama.AnnouncerVoice)
	end
end

-- Low health: the screen pulses red with a heartbeat, the music muffled.
local muffle: EqualizerSoundEffect? = nil
local lowOn = false
local function setLow(on: boolean)
	if on == lowOn then
		return
	end
	lowOn = on
	pcall(function()
		if on then
			if not muffle or not muffle.Parent then
				local eq = Instance.new("EqualizerSoundEffect")
				eq.Name = "FightDramaMuffle"
				eq.HighGain, eq.MidGain, eq.LowGain = -22, -6, 2
				eq.Parent = Music.group()
				muffle = eq
			end
		elseif muffle then
			muffle:Destroy()
			muffle = nil
		end
	end)
	if not on then
		local cc = grade()
		cc.TintColor, cc.Brightness = WHITE, 0
	end
end
local nextBeat = 0
local function heartbeat(ratio: number)
	local now = os.clock()
	if now < nextBeat then
		return
	end
	-- (quicker as it gets closer: 70 a minute down to 120)
	local k = math.clamp(ratio / FightDrama.LowAt, 0, 1)
	nextBeat = now + 0.5 + 0.36 * k
	local cc = grade()
	cc.TintColor, cc.Brightness = Color3.fromRGB(255, 150, 150), -0.04
	TweenService:Create(cc, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TintColor = Color3.fromRGB(255, 225, 225), Brightness = 0 }):Play()
	pcall(CombatFx.shake, 0.004, 0.12)
end

-- Rivals: the bot you fight, its entrance, its words, its fall.
local rival: Model? = nil
local said: { [string]: boolean } = {}
local function linesOf(model: Model)
	return FightDrama.Lines[model:GetAttribute("RivalName") or ""] or FightDrama.Generic
end
local function bubble(model: Model, text: string)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then
		return
	end
	local old = head:FindFirstChild("RivalSays")
	if old then
		old:Destroy()
	end
	local board = Instance.new("BillboardGui")
	board.Name = "RivalSays"
	board.Size = UDim2.fromOffset(260, 64)
	board.StudsOffset = Vector3.new(0, 3.4, 0)
	board.MaxDistance = 120
	board.AlwaysOnTop = true
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
	frame.BackgroundTransparency = 0.12
	frame.Parent = board
	UiKit.round(frame, 12)
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness = GOLD, 1.5
	edge.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position, label.Size = UDim2.fromOffset(10, 6), UDim2.new(1, -20, 1, -12)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(240, 240, 248)
	label.Text = text
	label.Parent = frame
	board.Parent = head
	task.delay(3.2, function()
		board:Destroy()
	end)
end
local function rivalSays(key: string)
	local model = rival
	if not model or said[key] or not model.Parent then
		return
	end
	said[key] = true
	local lines = linesOf(model)
	local text = lines[key]
	if text then
		bubble(model, text)
		speak(text, lines.Voice or FightDrama.Generic.Voice)
	end
end
local function watchRival(model: Model)
	if rival == model then
		return
	end
	rival = model
	said = {}
	local name = model:GetAttribute("RivalName")
	local title = model:GetAttribute("RivalTitle")
	if FightDrama.Enabled and type(name) == "string" then
		FightDrama.call("VS  " .. string.upper(name), { Color = GOLD, Sub = if type(title) == "string" then title else nil, Rank = 3, Hold = 1.6 })
		task.delay(1.5, rivalSays, "Enter")
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.HealthChanged:Connect(function(health)
		if rival ~= model or not FightDrama.Enabled then
			return
		end
		local ratio = health / math.max(1, humanoid.MaxHealth)
		if ratio <= 0.2 then
			rivalSays("Low")
		elseif ratio <= 0.55 then
			rivalSays("Hurt")
		end
	end)
	humanoid.Died:Connect(function()
		if rival ~= model or not FightDrama.Enabled then
			return
		end
		local mine = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local flawless = mine and mine.Health >= mine.MaxHealth - 0.5
		knockout("K.O.!", { Color = GOLD, Say = if flawless then "Flawless victory!" else "Knockout!", Sub = if flawless then "FLAWLESS VICTORY" else nil, Rank = 5, Hold = 1.8 })
	end)
end
local function findRival(): Model?
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	for _, model in enemies:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("RivalOwner") == player.UserId then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and model:GetAttribute("RivalName") ~= nil then
				return model
			end
		end
	end
	return nil
end

-- A player you're fighting knocked out (a Ranked round's RoundKO, a death):
-- K.O.; you knocked out: KNOCKED OUT.
local function sameMatch(other: Player): boolean
	local match = player:GetAttribute("MatchId")
	return match ~= nil and other:GetAttribute("MatchId") == match and other:GetAttribute("MatchTeam") ~= player:GetAttribute("MatchTeam")
end
local function watchBody(other: Player, character: Model)
	local function down()
		if not FightDrama.Enabled then
			return
		end
		if other == player then
			knockout("KNOCKED OUT", { Color = RED, Say = "Knocked out!", Rank = 5, Hold = 1.6 })
			if rival then
				task.delay(0.8, rivalSays, "Win")
			end
		elseif sameMatch(other) or (player:GetAttribute("CombatSession") == "PvP" and fighting) then
			local mine = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local flawless = mine and mine.Health >= mine.MaxHealth - 0.5
			knockout("K.O.!", { Color = GOLD, Say = if flawless then "Flawless victory!" else "Knockout!", Sub = if flawless then "FLAWLESS VICTORY" else nil, Rank = 5, Hold = 1.8 })
		end
	end
	character:GetAttributeChangedSignal("RoundKO"):Connect(function()
		if character:GetAttribute("RoundKO") then
			down()
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			if other == player and not inBout() and not player:GetAttribute("SparDown") then
				return -- (a death outside a bout isn't a knock-out)
			end
			down()
		end)
	end
end

function FightDrama.setFight(on: boolean)
	if on and not fighting then
		fightSince, firstBlood, lastStand = os.clock(), false, false
	end
	fighting = on
end

local started = false
function FightDrama.start()
	if started then
		return
	end
	started = true
	local function track(other: Player)
		if other.Character then
			task.spawn(watchBody, other, other.Character)
		end
		other.CharacterAdded:Connect(function(character)
			watchBody(other, character)
		end)
	end
	for _, other in Players:GetPlayers() do
		track(other)
	end
	Players.PlayerAdded:Connect(track)
	-- An intro loss knocks you down without RoundKO on a duel: the rival crows.
	player:GetAttributeChangedSignal("SparDown"):Connect(function()
		if player:GetAttribute("SparDown") and rival and rival.Parent then
			knockout("KNOCKED DOWN", { Color = RED, Say = "Down!", Rank = 5, Hold = 1.4 })
			task.delay(0.8, rivalSays, "Win")
		end
	end)
	local scanAt = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		-- your rival (scanned a few times a second)
		if now >= scanAt then
			scanAt = now + 0.3
			local found = if fighting then findRival() else nil
			if found then
				watchRival(found)
			elseif rival and (not rival.Parent or not fighting) then
				rival = nil
			end
		end
		-- low health
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local ratio = if humanoid then humanoid.Health / math.max(1, humanoid.MaxHealth) else 1
		local low = FightDrama.Enabled and fighting and humanoid ~= nil and humanoid.Health > 0 and ratio <= FightDrama.LowAt
		setLow(low)
		if low then
			heartbeat(ratio)
			if inBout() and not lastStand and ratio <= FightDrama.LastStandAt then
				lastStand = true
				FightDrama.call("LAST STAND", { Color = RED, Say = "Last stand!", Rank = 2 })
			end
			if rival then
				rivalSays("Gloat")
			end
		end
	end)
end

return FightDrama
