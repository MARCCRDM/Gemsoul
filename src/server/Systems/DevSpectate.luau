--[[
	DEV > SPECTATE (Client DungeonPlaytest): an Owner watches another player
	in this server, the camera behind them in third person, to see what they
	do and where they get stuck. Their surroundings stream to the Owner as
	they move (the Owner's ReplicationFocus follows them).

	  "DevSpectate", userId?   start watching that player (nil: stop)

	Owners only (Config.Playtest.Owners, checked here on every request).
	Watching changes nothing for the one watched, and they aren't told.

	  DevSpectate.start()
]]
local Players = game:GetService("Players")

local DevAlerts = require(script.Parent.DevAlerts)
local Shop = require(script.Parent.Shop)

local DevSpectate = {}

local watching: { [Player]: Player } = {} -- Owner -> who they're watching

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The Owner's streaming follows who they watch (their own character's back on stop).
local function focus(owner: Player)
	local target = watching[owner]
	local root = target and rootOf(target)
	pcall(function()
		owner.ReplicationFocus = root
	end)
	if root then
		pcall(owner.RequestStreamAroundAsync, owner, root.Position, 2)
	end
end

function DevSpectate.request(owner: Player, userId: any)
	if not DevAlerts.owner(owner.UserId) then
		return Shop.reply(false, "Spectating is for the game's owners.")
	end
	if userId == nil then
		watching[owner] = nil
		focus(owner)
		return Shop.reply(true, "Back to you.")
	end
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId) or nil
	if not target or target == owner then
		return Shop.reply(false, "They're not in this server.")
	end
	watching[owner] = target
	focus(owner)
	return Shop.reply(true, "Watching " .. target.DisplayName .. ".")
end

local started = false
function DevSpectate.start()
	if started then
		return
	end
	started = true
	Shop.register("DevSpectate", DevSpectate.request)
	-- (the one watched respawns or leaves: follow the new body, or stop)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				for owner, target in watching do
					if target == player then
						focus(owner)
					end
				end
			end)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			task.defer(function()
				for owner, target in watching do
					if target == player then
						focus(owner)
					end
				end
			end)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		watching[player] = nil
		for owner, target in watching do
			if target == player then
				watching[owner] = nil
				focus(owner)
			end
		end
	end)
	-- (streaming round them as they move)
	task.spawn(function()
		while true do
			task.wait(2)
			for owner in watching do
				focus(owner)
			end
		end
	end)
end

return DevSpectate
