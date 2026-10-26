--[[
	Lobby-first: the Saga Outpost is the lobby.

	  New players   after the splash and the starter launch, straight into a
	                first 1v1 (one match), then into the lobby. The intro
	                queue (Shared.AutoQueue) finds another new player, else
	                calls one from the lobby, else the sparring rival steps in
	  Everyone else straight into the lobby
	  The lobby     LobbyUI's PLAY button and tiles show while you're in the
	                Outpost and not fighting; a finished match returns you
	                there (ArenaSessions sends Outpost players back)
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ArenaScene = require(script.Parent.Modules.ArenaScene)
local GemClient = require(script.Parent.Modules.GemClient)
local LoadingFlow = require(script.Parent.Modules.LoadingFlow)
local LobbyUI = require(script.Parent.Modules.LobbyUI)
local OutpostScene = require(script.Parent.Modules.OutpostScene)
local UiKit = require(script.Parent.Modules.UiKit)
local SparKit = require(script.Parent.Modules.SparKit)
local Spar = require(game:GetService("ReplicatedStorage").Shared.Spar)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The loading screen over every change of place (fights, respawns, jumps).
-- (Never at the lobby's expense: if it can't start, the lobby still runs.)
local loadingStarted, loadingProblem = pcall(LoadingFlow.start)
if not loadingStarted then
	warn("[Lobby] loading screens off: " .. tostring(loadingProblem))
end
-- Its tips follow how far you've got (your first gem, your level, your fights).
if GemClient.Profile then
	LoadingFlow.progress(GemClient.Profile)
end
GemClient.Changed:Connect(LoadingFlow.progress)

-- Friendly sparring (Z asks someone) and the kit switch: 1, or the phone's
-- button, swaps the pick for your combat kit and back (SparKit).
SparKit.start()
-- Robbed while down: what the critters took (RobReport).
require(script.Parent.Modules.RobReport).start()
-- The quarry's edge, for now: a dome that says the expansion's coming.
require(script.Parent.Modules.EdgeDome).start()

-- Your mini kaiju: its card, RECALL, HUNT and TAME, and the kaiju panel.
if Config.Features == nil or Config.Features.Kaiju ~= false then
	require(script.Parent.Modules.KaijuHud).start()
	-- The team's HYPERBEAM: its button by the strip, and the blast itself.
	require(script.Parent.Modules.KaijuBeamHud).start()
	require(script.Parent.Modules.KaijuBeamFx).start()
	-- Kaiju battles: the formation board, the battle bar and the result.
	require(script.Parent.Modules.KaijuBattleUI).start()
	-- Each kaiju in a battle on a ring in its side's colour (BLUE or RED).
	require(script.Parent.Modules.KaijuTeamRings).start()
	-- The Kaiju Arena downstairs: its boards, the stake on show, your pad's card.
	require(script.Parent.Modules.KaijuPitClient).start()
	-- Yellow arrows on the ground, to a pad, the stairs down, the Rift's way on.
	require(script.Parent.Modules.GroundGuide).start()
end
-- After the intro's first fight: arrows to a mech, a few rocks, then out.
require(script.Parent.Modules.IntroGuide).start()
-- Who a Rift or raid boss is on right now: a red diamond over them (or their kaiju).
require(script.Parent.Modules.BossFocus).start()

-- The lobby HUD: in the Outpost, not fighting (or sparring), not in a kaiju
-- battle, not inside a menu, and not away in the Rift (even with the pick
-- out there, for its healing rocks). Checked a few times a second, and only
-- applied when it changes.
local shown = nil
local nextCheck = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextCheck then
		return
	end
	nextCheck = now + 0.2
	-- (In a kaiju battle the court's overview and the battle's own bar and
	-- result have the screen: KaijuBattleUI.)
	local on = OutpostScene.isActive()
		and not Spar.fighting(player)
		and player:GetAttribute("RiftRun") == nil
		and player:GetAttribute("KaijuBattle") == nil
		and not playerGui:FindFirstChild("Intro")
	if on ~= shown then
		shown = on
		LobbyUI.setVisible(on)
	end
end)

-- A respawn in the lobby puts you back in the Outpost, not at the old base.
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	if OutpostScene.isActive() and player:GetAttribute("Outpost") then
		GemClient.request("OutpostEnter")
	end
end)

local function duelsPlayed(): number
	local fromAttribute = player:GetAttribute("DuelsPlayed")
	if type(fromAttribute) == "number" then
		return fromAttribute
	end
	local record = GemClient.Profile and GemClient.Profile.Duel
	return if record then record.Played or 0 else 0
end

-- Someone who has fought before (before duels were counted) skips the intro duel.
local function veteran(): boolean
	local profile = GemClient.Profile
	local record = profile and profile.Duel
	local stats = profile and profile.Stats
	return (record ~= nil and ((record.Wins or 0) + (record.Losses or 0)) > 0)
		or (stats ~= nil and (stats.Kills or 0) > 0)
end

local function waitFor(condition: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while not condition() do
		if os.clock() > deadline then
			return false
		end
		task.wait(0.2)
	end
	return true
end

-- The card over the intro queue: who it's looking for, and the sparring
-- partner's promise. Returns (setLine, close).
local GOLD = Color3.fromRGB(255, 202, 91)
local function searchCard(): ((string) -> (), () -> ())
	local gui = UiKit.gui("IntroSearch", 25)
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 72)
	card.Size = UDim2.fromOffset(440, 92)
	card.BackgroundColor3 = Color3.fromRGB(16, 20, 32)
	card.BackgroundTransparency = 0.08
	card.Parent = gui
	UiKit.round(card, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = GOLD, 1.5
	stroke.Parent = card
	local title = UiKit.text(card, "FINDING YOUR FIRST OPPONENT", 17, GOLD, Enum.Font.GothamBlack)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Position, title.Size = UDim2.fromOffset(0, 14), UDim2.new(1, 0, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local line = UiKit.text(card, "", 13, Color3.fromRGB(196, 204, 220))
	line.AutomaticSize = Enum.AutomaticSize.None
	line.Position, line.Size = UDim2.fromOffset(16, 42), UDim2.new(1, -32, 0, 36)
	line.TextXAlignment = Enum.TextXAlignment.Center
	return function(value: string)
		line.Text = value
	end, function()
		gui:Destroy()
	end
end

-- The intro duel: one match, then the lobby. The intro queue (Shared.AutoQueue)
-- pairs two new players at once; alone, a lobby player is called in; still
-- alone, the sparring rival steps in (the server sends it all).
local FastStart = require(game:GetService("ReplicatedStorage").Shared.FastStart)
local AutoQueue = require(game:GetService("ReplicatedStorage").Shared.AutoQueue)
local function firstDuel()
	UiKit.toast(
		if FastStart.Enabled
			then "Your first fight: another new miner if one's here, else an easy sparring partner. Tips pop up as you go."
			else "Combat training: learn the basics, then spar.",
		GOLD
	)
	local result = GemClient.request("IntroQueue")
	if not (result and result.Ok) then
		-- (A save that has fought before, or the Arena isn't ready: the old
		-- way in, straight to a sparring partner.)
		ArenaScene.enter(false)
	else
		local setLine, close = searchCard()
		local started = os.clock()
		local deadline = started + AutoQueue.Intro.BotAfter + 20
		while player:GetAttribute("CombatSession") == nil and os.clock() < deadline do
			local waited = os.clock() - started
			local phase = AutoQueue.introPhase(waited)
			setLine(
				if phase == "Bot"
					then "A sparring partner is stepping in…"
					elseif phase == "Call" then string.format(
						"Calling a miner from the lobby…  a sparring partner steps in at %ds",
						AutoQueue.Intro.BotAfter
					)
					else string.format(
						"Looking for another new miner…  %ds\nIf nobody comes, a sparring partner steps in.",
						math.max(0, math.ceil(AutoQueue.Intro.BotAfter - waited))
					)
			)
			task.wait(0.2)
		end
		close()
	end
	if not waitFor(function()
		return player:GetAttribute("CombatSession") ~= nil
	end, 12) then
		return -- the Arena wasn't ready: straight to the lobby
	end
	-- Finished (won or lost), or left early.
	waitFor(function()
		return duelsPlayed() > 0 or player:GetAttribute("CombatSession") == nil
	end, 900)
	task.wait(3)
	if player:GetAttribute("CombatSession") ~= nil then
		GemClient.request("ArenaLeave")
	end
	waitFor(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil and humanoid.Health > 0
	end, 15)
end

task.spawn(function()
	while not GemClient.Profile do
		GemClient.Changed:Wait()
	end
	-- After the splash and the starter launch.
	task.wait(1)
	waitFor(function()
		local intro = GemClient.Profile.Intro
		return not playerGui:FindFirstChild("Splash")
			and not playerGui:FindFirstChild("Intro")
			and (
				(not require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled and not FastStart.Enabled)
				or (intro ~= nil and intro.Done == true)
			)
	end, 3600)
	task.wait(0.5)
	-- The tutorial (Tutorial.client) starts in the Outpost: go there first
	-- and let it run.
	local function tutorialDone(): boolean
		local tutorial = GemClient.Profile.Tutorial
		return not require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled or tutorial == nil or tutorial.Done == true
	end
	if not tutorialDone() then
		for _ = 1, 5 do
			OutpostScene.enter()
			if waitFor(OutpostScene.isActive, 6) then
				break
			end
		end
		waitFor(tutorialDone, 3600)
		task.wait(1.5)
	end
	-- A first fight for someone new: after the mining tutorial when that's on,
	-- or straight after the fast start's pick (not for saves that skipped it).
	local intro = GemClient.Profile.Intro
	local fresh = duelsPlayed() == 0 and not veteran()
	local hadFirstDuel = false
	if require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled and fresh and not GemClient.Profile.Tutorial then
		firstDuel()
		hadFirstDuel = true
	elseif FastStart.Enabled and fresh and not (intro and intro.Skipped) then
		firstDuel()
		hadFirstDuel = true
	end
	for _ = 1, 5 do
		if OutpostScene.isActive() then
			break
		end
		OutpostScene.enter()
		if waitFor(OutpostScene.isActive, 6) then
			break
		end
	end
	-- Straight after the intro: into the ranked 1v1 queue, so the SEARCHING
	-- card (SocialUI's banner, with CANCEL) is up while they look round the
	-- Outpost. (A few tries: the server says no until they're back and
	-- standing in the lobby.)
	if hadFirstDuel then
		task.spawn(function()
			waitFor(function()
				return player:GetAttribute("Outpost") == true
			end, 20)
			for _ = 1, 6 do
				if player:GetAttribute("DuelQueue") or player:GetAttribute("MatchId") then
					break
				end
				local queued = GemClient.request("DuelReturnQueue")
				if queued and queued.Ok then
					UiKit.toast("Searching ranked 1v1: keep mining. You'll be asked before joining.", GOLD)
					break
				end
				task.wait(2)
			end
		end)
	end
	-- Never stranded: whenever you're free (no fight, match, dungeon,
	-- expedition or intro, and alive), you belong in the Outpost. If you
	-- aren't there for a few seconds in a row (a menu, a failed request, a
	-- fight that didn't send you back), you're put back.
	local function free(): boolean
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return humanoid ~= nil
			and humanoid.Health > 0
			and not playerGui:FindFirstChild("Splash")
			and not playerGui:FindFirstChild("Intro")
			and player:GetAttribute("CombatSession") == nil
			and player:GetAttribute("MatchId") == nil
			and player:GetAttribute("DungeonId") == nil
			and player:GetAttribute("Expedition") == nil
	end
	local away = 0
	while true do
		task.wait(1)
		if free() and not (OutpostScene.isActive() and player:GetAttribute("Outpost")) then
			away += 1
			-- (Sooner behind the loading screen: it's waiting on this.)
			if away >= (if LoadingFlow.active() then 1 else 3) then
				OutpostScene.ensure()
			end
		else
			away = 0
		end
	end
end)
