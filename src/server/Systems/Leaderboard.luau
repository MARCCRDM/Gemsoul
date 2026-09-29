-- Gives every player a "Gems" stat on the leaderboard plus quota tracking.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Leaderboard = {}

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = 0
	gems.Parent = leaderstats

	leaderstats.Parent = player

	-- Not saved yet: resets when the player rejoins.
	player:SetAttribute("GemsMinedToday", 0)
	player:SetAttribute("DailyQuota", Config.DailyQuota)
end

function Leaderboard.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function Leaderboard.addGems(player: Player, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	local gems = leaderstats and leaderstats:FindFirstChild("Gems")
	if gems then
		gems.Value += amount
	end
	player:SetAttribute("GemsMinedToday", (player:GetAttribute("GemsMinedToday") or 0) + 1)
end

return Leaderboard
