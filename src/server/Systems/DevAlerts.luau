--[[
	For the game's Owners only (Config.Playtest.Owners): a heads-up whenever
	someone joins the game, in any server. When a player's profile loads,
	their server tells every server (MessagingService, Topic); each server
	passes it on to the Owners playing in it (Remotes.DevAlert), whose screen
	shows it and says it out loud (Client.DevAlerts). New players (their first
	join just now) are called out as new. Owners joining aren't announced.

	  DevAlerts.start()
	  DevAlerts.alert(player, profile) -> { Name, User, New, Players, Server }   (tests)
]]
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local Remotes = require(script.Parent.Remotes)
local TestAdmin = require(script.Parent.TestAdmin)

local DevAlerts = {}

DevAlerts.Topic = "SagaDevJoins"
DevAlerts.NewWithin = 10 * 60 -- seconds: an account this new is a new player

local function owner(userId: number): boolean
	return table.find((TestAdmin.Playtest or {}).Owners or {}, userId) ~= nil
end
DevAlerts.owner = owner

function DevAlerts.alert(player: Player, profile)
	local first = profile and tonumber(profile.FirstJoin) or 0
	return {
		Name = player.DisplayName,
		User = player.Name,
		New = first > 0 and os.time() - first < DevAlerts.NewWithin,
		Players = #Players:GetPlayers(),
		Server = string.sub(game.JobId, 1, 6),
	}
end

-- To the Owners playing in this server.
local function deliver(data)
	for _, other in Players:GetPlayers() do
		if owner(other.UserId) then
			Remotes.DevAlert:FireClient(other, data)
		end
	end
end

local started = false
function DevAlerts.start()
	if started then
		return
	end
	started = true
	-- From the other servers (this server's own joins are delivered at once).
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(DevAlerts.Topic, function(message)
				local data = message and message.Data
				if type(data) == "table" and data.Server ~= string.sub(game.JobId, 1, 6) then
					deliver(data)
				end
			end)
		end)
	end)
	PlayerData.Loaded:Connect(function(player: Player)
		if owner(player.UserId) then
			return
		end
		local data = DevAlerts.alert(player, PlayerData.get(player))
		deliver(data)
		task.spawn(pcall, function()
			MessagingService:PublishAsync(DevAlerts.Topic, data)
		end)
	end)
end

return DevAlerts
