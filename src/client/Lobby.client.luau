--[[
	Lobby-first: the Saga Outpost is the lobby.

	  New players   after the splash and the starter launch, straight into a
	                first 1v1 against a sparring rival (one match), then
	                into the lobby
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

-- Friendly sparring: ask someone (Z, or 1 for the nearest); 1 ends it (SparKit).
SparKit.start()

-- Your mini kaiju: its card, RECALL, HUNT and TAME, and the kaiju panel.
if Config.Features == nil or Config.Features.Kaiju ~= false then
	require(script.Parent.Modules.KaijuHud).start()
	-- Kaiju battles: the formation board, the battle bar and the result.
	require(script.Parent.Modules.KaijuBattleUI).start()
end

-- The lobby HUD: in the Outpost, not fighting (or sparring), not inside a
-- menu. Checked a few times a second, and only applied when it changes.
local shown = nil
local nextCheck = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextCheck then
		return
	end
	nextCheck = now + 0.2
	local on = OutpostScene.isActive()
		and not Spar.fighting(player)
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

-- The intro duel: one match against a sparring rival, then the lobby.
local FastStart = require(game:GetService("ReplicatedStorage").Shared.FastStart)
local function firstDuel()
	UiKit.toast(
		if FastStart.Enabled
			then "Your first fight: an easy sparring partner. Tips pop up as you go."
			else "Combat training: learn the basics, then spar.",
		Color3.fromRGB(255, 202, 91)
	)
	ArenaScene.enter(false)
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
	if require(game:GetService("ReplicatedStorage").Shared.Tutorial).Enabled and fresh and not GemClient.Profile.Tutorial then
		firstDuel()
	elseif FastStart.Enabled and fresh and not (intro and intro.Skipped) then
		firstDuel()
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
