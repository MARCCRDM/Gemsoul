--[[
	Joining: the loading screen (LoadingScreen) from the very first frame,
	in place of Roblox's own, until there's something ready to look at:
	  1. the game itself loaded,
	  2. your miner spawned,
	  3. the title screen (Client/Splash) built, with its art and music
	     downloaded, so it starts clean instead of popping in.
	A second at least, so it never just blinks. If the title screen never
	turns up, it lets go anyway; past the title, Modules/LoadingFlow covers
	the hand-over into the game.
]]
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local LoadingScreen = require(script.Parent:WaitForChild("LoadingScreen"))

local MIN = 1.2 -- seconds up at least
local TITLE_WAIT = 8 -- seconds to wait for the title screen once loaded
local ASSET_WAIT = 6 -- seconds to wait for its art and music

local join = LoadingScreen.cover("Join", { Status = "Loading the game", Instant = true, Min = MIN, Max = 60 })
LoadingScreen.progress(0.05)
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

-- (Waits on a condition with a deadline, never forever.)
local function waitUntil(condition: () -> boolean, seconds: number): boolean
	local deadline = os.clock() + seconds
	while not condition() do
		if os.clock() > deadline then
			return false
		end
		task.wait(0.05)
	end
	return true
end

-- 1. The game.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
LoadingScreen.progress(0.35)

-- 2. Your miner.
join.status("Getting your miner ready")
local player = Players.LocalPlayer
waitUntil(function()
	local character = player.Character
	return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
end, 20)
LoadingScreen.progress(0.6)

-- 3. The title screen, and what it needs downloaded.
join.status("Almost there")
local playerGui = player:WaitForChild("PlayerGui")
local title: Instance? = nil
waitUntil(function()
	title = playerGui:FindFirstChild("Splash")
	return title ~= nil and title:GetAttribute("Built") == true
end, TITLE_WAIT)
if title then
	local done = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ title :: Instance }, function()
				LoadingScreen.progress(0.6 + 0.35 * (1 - math.min(ContentProvider.RequestQueueSize, 20) / 20))
			end)
		end)
		done = true
	end)
	waitUntil(function()
		return done
	end, ASSET_WAIT)
end
LoadingScreen.progress(1)
join.release()
