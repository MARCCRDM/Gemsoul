--[[
	The first fight's hints (Shared.FastStart): while the server has a new
	player in their first spar (player attribute FirstFight), one hint at a
	time pops up the first time a control is useful, and goes once it's done:

	  Swing   from the start, until a hit lands
	  Block   while the partner winds up a quick swing, until you block
	  Dodge   while a Heavy Blow winds up, until you dodge
	  Heavy   while its guard is up, until you throw a heavy
	  Q E R   when you can afford each move, until you use it

	The partner's wind-ups and guard come from the attributes the server sets
	on it (ActionKind, ActionName, ActionStart, ActionAt, GuardUntil); what
	you did, from yours (ActionKind / ActionName on your character, Blocking
	on you) and the partner's health.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FastStart = require(ReplicatedStorage.Shared.FastStart)
if not FastStart.Enabled then
	return
end
local Tech = require(ReplicatedStorage.Shared.CombatTechnology)
local GemClient = require(script.Parent.Modules.GemClient)
local IronUi = require(script.Parent.Modules.IronUi)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local new = IronUi.new
local GOLD, ORANGE, GREEN = Color3.fromRGB(255, 202, 91), Color3.fromRGB(255, 140, 70), Color3.fromRGB(96, 214, 128)
local INK, TEXT, DIM = Color3.fromRGB(10, 13, 20), Color3.fromRGB(240, 244, 250), Color3.fromRGB(150, 162, 180)

local gui = UiKit.gui("FirstFightHints", 9)
gui.Enabled = false
local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.74, 0),
	Size = UDim2.fromOffset(420, 66),
	BackgroundColor3 = INK,
	BackgroundTransparency = 0.12,
}, gui)
UiKit.round(card, 14)
local edge = new("UIStroke", { Color = GOLD, Thickness = 2, Transparency = 0.1 }, card)
local scale = new("UIScale", { Scale = 1 }, card)
local line = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 0, 28),
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = TEXT,
	Text = "",
}, card)
local reason = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 38),
	Size = UDim2.new(1, -32, 0, 18),
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextColor3 = DIM,
	Text = "",
}, card)

local function touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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

local function partner(): Model?
	local folder = workspace:FindFirstChild("Enemies")
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("RivalOwner") == player.UserId then
			return model
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
		line.TextColor3 = GREEN
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

local function show(id: string, list)
	local names = {}
	for key, move in list do
		names[key] = move.Name
	end
	local text, why = FastStart.text(id, touch(), names)
	if shown ~= id then
		shown, shownAt = id, os.clock()
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	local urgent = FastStart.Urgent[id] == true
	edge.Color = if urgent then ORANGE else GOLD
	line.TextColor3 = if urgent then ORANGE else TEXT
	line.Text, reason.Text = text, why
	gui.Enabled = true
end

local nextTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextTick or now < flashUntil then
		return
	end
	nextTick = now + 0.1
	if player:GetAttribute("FirstFight") ~= true or FastStart.finished(done) then
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
		show(id, list)
	else
		gui.Enabled, shown = false, nil
	end
end)
