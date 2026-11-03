--[[
	Accounts left out of the numbers: nothing of theirs goes to Roblox's
	Analytics (Server.Analytics: funnels, custom events, the economy; the
	onboarding funnel, Server.Funnel) or the game's own log (Server.Telemetry),
	so playtests (and DEV > NEW PLAYER's fresh starts) never show up as players.

	Left out:
	  - in Studio, everyone
	  - the Owners and Testers (Config.Playtest), and NoAnalytics (more UserIds:
	    test accounts)
	  - an account marked NOT COUNTED in the ANALYTICS window (an Owner's
	    choice, kept on the account: profile.NoAnalytics, through DEV resets)
	  - an account that has used DEV > NEW PLAYER (its save keeps DevBackup)

	  DevAccounts.excluded(player | userId) -> bool
	  DevAccounts.set(player, excluded)   mark an account (and the log row the
	                                      reports go by: Telemetry.mark)
	  DevAccounts.listed() -> { [userId] = true }   Owners, Testers, NoAnalytics
	  DevAccounts.start()                 hooks it into Analytics, Funnel and
	                                      Telemetry (before they send anything)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local DevAccounts = {}

DevAccounts.Studio = true -- everyone in Studio is left out

function DevAccounts.listed(): { [number]: boolean }
	local out = {}
	local playtest = Config.Playtest or {}
	for _, list in { playtest.Owners, playtest.Testers, playtest.NoAnalytics } do
		for _, id in list or {} do
			if type(id) == "number" then
				out[id] = true
			end
		end
	end
	return out
end

function DevAccounts.excluded(who: any): boolean
	if DevAccounts.Studio and RunService:IsStudio() then
		return true
	end
	local player = who
	local userId = nil
	if type(who) == "number" then
		userId = who
		player = Players:GetPlayerByUserId(who)
	elseif typeof(who) == "Instance" and who:IsA("Player") then
		userId = who.UserId
	else
		return false
	end
	if DevAccounts.listed()[userId] then
		return true
	end
	local profile = player and PlayerData.get(player) :: any
	return profile ~= nil and (profile.NoAnalytics == true or profile.DevBackup ~= nil)
end

function DevAccounts.set(player: Player, excluded: boolean): boolean
	local profile = PlayerData.get(player) :: any
	if not profile then
		return false
	end
	profile.NoAnalytics = if excluded then true else nil
	pcall(function()
		require(script.Parent.Telemetry).mark(player.UserId, excluded)
	end)
	return true
end

local started = false
function DevAccounts.start()
	if started then
		return
	end
	started = true
	require(script.Parent.Analytics).excluded = DevAccounts.excluded
	require(script.Parent.Funnel).excluded = DevAccounts.excluded
	require(script.Parent.Journey).excluded = DevAccounts.excluded
	require(script.Parent.Telemetry).excluded = DevAccounts.excluded
end

return DevAccounts
