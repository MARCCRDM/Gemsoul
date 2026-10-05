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
local LobbyUI = require(script.Parent.Modules.LobbyUI)
local OutpostScene = require(script.Parent.Modules.OutpostScene)
local UiKit = require(script.Parent.Modules.UiKit)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The lobby HUD: in the Outpost, not fighting, not inside a menu. Checked
-- a few times a second, and only applied when it changes.
local shown = nil
local nextCheck = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now < nextCheck then
		return
	end
	nextCheck = now + 0.2
	local on = OutpostScene.isActive()
		and player:GetAttribute("CombatSession") == nil
		and player:GetAttribute("MatchId") == nil
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
local function firstDuel()
	UiKit.toast("First duel: beat the rival to open the lobby.", Color3.fromRGB(255, 202, 91))
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
			and intro ~= nil
			and intro.Done == true
	end, 3600)
	task.wait(0.5)
	if duelsPlayed() == 0 and not veteran() then
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
			if away >= 3 then
				OutpostScene.ensure()
			end
		else
			away = 0
		end
	end
end)
