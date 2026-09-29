-- Spawns glowing gems around the map. Touching one adds to the player's Gems
-- stat, and the gem respawns after a short delay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local gemFolder = Instance.new("Folder")
gemFolder.Name = "Gems"
gemFolder.Parent = workspace

local function randomPosition(): Vector3
	local angle = math.random() * math.pi * 2
	local distance = math.random() * Config.SpawnRadius
	return Vector3.new(math.cos(angle) * distance, 3, math.sin(angle) * distance)
end

local function makeGem(): Part
	local gem = Instance.new("Part")
	gem.Name = "Gem"
	gem.Shape = Enum.PartType.Ball
	gem.Size = Vector3.new(2, 2, 2)
	gem.Material = Enum.Material.Neon
	gem.Color = Color3.fromHSV(math.random(), 0.8, 1)
	gem.Anchored = true
	gem.CanCollide = false
	gem.Position = randomPosition()

	local light = Instance.new("PointLight")
	light.Color = gem.Color
	light.Range = 8
	light.Parent = gem

	local collected = false
	gem.Touched:Connect(function(hit)
		if collected then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		collected = true

		local gems = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Gems")
		if gems then
			gems.Value += Config.GemValue
		end

		gem.Transparency = 1
		light.Enabled = false
		task.wait(Config.GemRespawnSeconds)
		gem.Position = randomPosition()
		gem.Transparency = 0
		light.Enabled = true
		collected = false
	end)

	gem.Parent = gemFolder
	return gem
end

for _ = 1, Config.GemCount do
	makeGem()
end
