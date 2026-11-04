--[[
	The first fight's hints (Shared.FastStart): while the server has a new
	player in their first spar (player attribute FirstFight), one control at
	a time pulses, the first time it's useful, until it's been used. No card
	over the fight: just a ring round the button itself (Combat's buttons,
	tagged TutorialTarget, and HintKey on Q / E / R).

	  Swing   from the start, until a hit lands
	  Block   while the partner winds up a quick swing, until you block
	  Dodge   while a Heavy Blow winds up, until you dodge
	  Heavy   while its guard is up, until you throw a heavy
	  Q E R   when you can afford each move, until you use it

	It opens with the narrator (Modules.Narration): "Welcome, Miner. Your
	training begins now.", then the controls' line, a bobbing arrow over each
	button it names: the Q / E / R moves ("Use your abilities to cast."),
	then ATTACK, BLOCK and DODGE ("Swing, block and dodge..."). The hints
	wait till it's done.

	The partner's wind-ups and guard come from the attributes the server sets
	on it (ActionKind, ActionName, ActionStart, ActionAt, GuardUntil); what
	you did, from yours (ActionKind / ActionName on your character, Blocking
	on you) and the partner's health.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FastStart = require(ReplicatedStorage.Shared.FastStart)
if not FastStart.Enabled then
	return
end
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local Narration = require(script.Parent.Modules.Narration)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new
local GOLD, ORANGE, GREEN = Color3.fromRGB(255, 202, 91), Color3.fromRGB(255, 140, 70), Color3.fromRGB(96, 214, 128)

-- The ring, drawn over Combat's own button (same ScreenGui settings, so the
-- button's on-screen position is the ring's too).
local gui = UiKit.gui("FirstFightHints", 9)
gui.Enabled = false
local ring = new("Frame", {
	Name = "HintRing",
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	ZIndex = 20,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
local edge = new("UIStroke", { Color = GOLD, Thickness = 3 }, ring)

-- The button each hint is about (a heavy is ATTACK held: there's no HEAVY
-- button on a touch screen).
local SLOT = { Swing = "Basic", Block = "Block", Dodge = "Dodge", Heavy = "Basic" }
local function findTarget(id: string): GuiObject?
	local hud = player.PlayerGui:FindFirstChild("CombatHud")
	if not hud or not hud:IsA("ScreenGui") or not hud.Enabled then
		return nil
	end
	for _, d in hud:GetDescendants() do
		if d:IsA("GuiObject") and d.Visible and d.AbsoluteSize.X > 4 then
			local tag = d:GetAttribute("TutorialTarget")
			if (SLOT[id] and tag == SLOT[id]) or (tag == "Surge" and d:GetAttribute("HintKey") == id) then
				return d
			end
		end
	end
	return nil
end

-- The opening's arrows: one over each button the narrator names, bobbing.
local ARROWS = {
	Abilities = { "Q", "E", "R" },
	Combat = { "Swing", "Block", "Dodge" },
}
-- (When in the controls' line each set shows: its words' times, seconds.)
local ARROW_TIMES = { { "Abilities", 0, 2.2 }, { "Combat", 2.2, 6.4 } }
local arrowGui = UiKit.gui("FirstFightArrows", 10)
arrowGui.Enabled = false
local arrows: { [string]: TextLabel } = {}
for _, ids in ARROWS do
	for _, id in ids do
		arrows[id] = new("TextLabel", {
			Name = "Arrow" .. id,
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(44, 44),
			Font = Enum.Font.GothamBlack,
			Text = "▼",
			TextColor3 = GOLD,
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(20, 14, 6),
			TextStrokeTransparency = 0.2,
			Visible = false,
			ZIndex = 20,
		}, arrowGui)
	end
end
local pointing: string? = nil -- (the set of arrows up: "Abilities" / "Combat")
local narrating = false -- (the hints wait while the narrator speaks)
local opened = false
local OPEN_WAIT = 25 -- seconds the opening waits for the fight to be in view, at most

-- Round 1's opening: the welcome, then the controls with the arrows.
local function opening()
	if opened then
		return
	end
	opened = true
	narrating = true
	gui.Enabled, shown = false, nil
	-- Not under the loading screen or the drop: once the fight's in view,
	-- its HUD up (the sparring rival's or another new miner's, a matched
	-- first fight: the same opening). At most OpenWait seconds.
	local waited = os.clock()
	while os.clock() - waited < OPEN_WAIT do
		local hud = player.PlayerGui:FindFirstChild("CombatHud")
		local inView = player:GetAttribute("IntroCover") == nil
			and player:GetAttribute("ArenaDropUntil") == nil
			and hud ~= nil
			and (not hud:IsA("ScreenGui") or hud.Enabled)
		if inView or player:GetAttribute("FirstFight") ~= true then
			break
		end
		task.wait(0.1)
	end
	if player:GetAttribute("FirstFight") ~= true then
		narrating = false
		return
	end
	pcall(Narration.say, "TrainingBegins")
	if player:GetAttribute("FirstFight") == true then
		local ok, seconds = pcall(Narration.play, "Controls")
		if ok and type(seconds) == "number" and seconds > 0 then
			local started = os.clock()
			arrowGui.Enabled = true
			while player:GetAttribute("FirstFight") == true do
				local t = os.clock() - started
				local now = nil
				for _, span in ARROW_TIMES do
					if t >= span[2] and t < span[3] then
						now = span[1]
					end
				end
				if not now and t >= ARROW_TIMES[#ARROW_TIMES][3] then
					break
				end
				pointing = now
				task.wait(0.05)
			end
		end
	end
	pointing = nil
	arrowGui.Enabled = false
	narrating = false
end

-- Your Q / E / R moves: name, cost and what pays for it.
local function moves()
	local loadout = GemClient.Profile and GemClient.Profile.Character or {}
	local list = {}
	for _, key in { "Q", "E", "R" } do
		local gem = Tech.surgeGem(loadout, key)
		local stats = gem and Tech.surgeStats(gem)
		if stats then
			list[key] = { Name = stats.Name, Cost = stats.Cost or 0, Resource = stats.Resource or "Charge" }
		end
	end
	return list
end

-- The sparring rival, or (a first fight against another new player, the
-- intro queue: Shared.AutoQueue) the opponent's character: both carry the
-- same action attributes.
local function partner(): Model?
	local folder = workspace:FindFirstChild("Enemies")
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("RivalOwner") == player.UserId then
			return model
		end
	end
	local mine = player:GetAttribute("MatchId")
	if mine then
		for _, other in Players:GetPlayers() do
			if other ~= player and other:GetAttribute("MatchId") == mine and other.Character then
				return other.Character
			end
		end
	end
	return nil
end

local done = {}
local shown, shownAt = nil, 0
local flashUntil = 0 -- (the green "done" flash, before the next hint)
local lastHealth, lastPartner = nil, nil

local function complete(event: string)
	if player:GetAttribute("FirstFight") ~= true then
		return
	end
	local was = shown
	FastStart.complete(done, event)
	if was and done[was] then
		-- Got it: a green flash, then the next one.
		edge.Color = GREEN
		shown = nil
		flashUntil = os.clock() + 0.6
		task.delay(0.6, function()
			if not shown then
				gui.Enabled = false
			end
		end)
	end
end

-- What you do: your swings, heavies, dodges and casts (on your character),
-- and your guard.
local function watch(character: Model)
	character:GetAttributeChangedSignal("ActionStart"):Connect(function()
		local kind, name = character:GetAttribute("ActionKind"), character:GetAttribute("ActionName")
		if kind == "Heavy" then
			complete("Heavy")
		elseif kind == "Dodge" then
			complete("Dodge")
		end
		if type(name) == "string" then
			for key, move in moves() do
				if move.Name == name then
					complete(key)
				end
			end
		end
	end)
end
if player.Character then
	watch(player.Character)
end
player.CharacterAdded:Connect(watch)
player:GetAttributeChangedSignal("Blocking"):Connect(function()
	if player:GetAttribute("Blocking") == true then
		complete("Block")
	end
end)

local target: GuiObject?, targetFor, lookedAt = nil, nil, 0
local function show(id: string)
	if shown ~= id then
		shown, shownAt = id, os.clock()
	end
	edge.Color = if FastStart.Urgent[id] == true then ORANGE else GOLD
	gui.Enabled = true
end

-- Every frame of the opening: each arrow over its button, bobbing.
local arrowTargets: { [string]: GuiObject? } = {}
local arrowsLooked = 0
RunService.RenderStepped:Connect(function()
	if not arrowGui.Enabled then
		return
	end
	local now = os.clock()
	if now - arrowsLooked > 0.5 then
		arrowsLooked = now
		for id in arrows do
			arrowTargets[id] = findTarget(id)
		end
	end
	local bob = math.abs(math.sin(now * 5)) * 10
	for set, ids in ARROWS do
		for _, id in ids do
			local arrow, button = arrows[id], arrowTargets[id]
			if set == pointing and button and button.Parent and button.Visible then
				local top = button.AbsolutePosition + Vector2.new(button.AbsoluteSize.X / 2, 0)
				arrow.Position = UDim2.fromOffset(top.X, top.Y - 4 - bob)
				arrow.Visible = true
			else
				arrow.Visible = false
			end
		end
	end
end)

-- Every frame while a hint is up: the ring round its button, breathing.
RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	local now = os.clock()
	local id = shown
	-- (A fresh look for the button twice a second at most: the HUD is big.)
	if id and (id ~= targetFor or now - lookedAt > 0.5) then
		target, targetFor, lookedAt = findTarget(id), id, now
	end
	local button = target
	if not button or not button.Parent or not button.Visible or (not id and now >= flashUntil) then
		ring.Visible = false
		return
	end
	local pulse = (math.sin(now * 6) + 1) / 2
	local size = math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y) + 12 + pulse * 10
	local centre = button.AbsolutePosition + button.AbsoluteSize / 2
	ring.Visible = true
	ring.Size = UDim2.fromOffset(size, size)
	ring.Position = UDim2.fromOffset(centre.X, centre.Y)
	edge.Transparency = 0.05 + pulse * 0.45
end)

local nextTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextTick or now < flashUntil then
		return
	end
	nextTick = now + 0.1
	if player:GetAttribute("FirstFight") ~= true or FastStart.finished(done) or narrating then
		gui.Enabled, shown = false, nil
		return
	end
	local model = partner()
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	-- A hit that lands: the partner's health drops.
	if humanoid then
		if lastPartner == model and lastHealth and humanoid.Health < lastHealth - 0.5 then
			complete("Hit")
		end
		lastPartner, lastHealth = model, humanoid.Health
	end
	local serverNow = workspace:GetServerTimeNow()
	local winding = false
	local heavy = false
	local guard = false
	if model then
		local at = model:GetAttribute("ActionAt")
		local start = model:GetAttribute("ActionStart")
		if type(at) == "number" and type(start) == "number" and serverNow >= start and serverNow < at + 0.05 then
			heavy = model:GetAttribute("ActionName") == "Heavy Blow"
			winding = not heavy and model:GetAttribute("ActionKind") == "Slash"
		end
		guard = (model:GetAttribute("GuardUntil") or 0) > serverNow
	end
	local list = moves()
	local ready = {}
	for key, move in list do
		local have = player:GetAttribute(move.Resource) or 0
		ready[key] = have >= move.Cost
	end
	local id = FastStart.hint({ FoeSlash = winding, FoeHeavy = heavy, FoeGuard = guard, Ready = ready }, done)
	-- An urgent hint stays a moment after the threat, so it can be read.
	if not id and shown and FastStart.Urgent[shown] and now - shownAt < 0.8 then
		return
	end
	if id then
		show(id)
	else
		gui.Enabled, shown = false, nil
	end
end)

-- Round 1 starts (the server marks your first fight): the opening.
local function begin()
	if player:GetAttribute("FirstFight") == true then
		task.spawn(opening)
	end
end
player:GetAttributeChangedSignal("FirstFight"):Connect(begin)
begin()
