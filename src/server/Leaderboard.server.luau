-- Gives every player a "Gems" stat on the leaderboard.
local Players = game:GetService("Players")

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = 0
	gems.Parent = leaderstats

	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
