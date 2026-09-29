-- Spawns a gem node on every NodeSpawner pad. Nodes are static and do not
-- regenerate: once mined, a node is gone until the server restarts.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Leaderboard = require(script.Parent.Leaderboard)

local SHARDS = {
	{ Size = Vector3.new(1.4, 4, 1.4), Offset = Vector3.zero, Tilt = Vector3.zero },
	{ Size = Vector3.new(1, 2.8, 1), Offset = Vector3.new(1, 0, 0), Tilt = Vector3.new(0, 0, -25) },
	{ Size = Vector3.new(1, 2.4, 1), Offset = Vector3.new(-0.9, 0, 0.4), Tilt = Vector3.new(0, 0, 30) },
	{ Size = Vector3.new(0.8, 2, 0.8), Offset = Vector3.new(0, 0, -0.9), Tilt = Vector3.new(-25, 0, 0) },
}

local Mining = {}

local rng = Random.new()

local function spawnNode(spawner: BasePart, folder: Folder)
	local isVip = spawner:GetAttribute("VIP") == true
	local color = if isVip then Color3.fromHSV(0.88, 0.8, 1) else Color3.fromHSV(rng:NextNumber(0.42, 0.62), 0.8, 1)

	local node = Instance.new("Model")
	node.Name = if isVip then "VipGemNode" else "GemNode"

	local base = CFrame.new(spawner.CFrame.Position + Vector3.new(0, spawner.Size.X / 2, 0))
		* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
	local core: BasePart
	for i, shard in SHARDS do
		local part = Instance.new("Part")
		part.Name = "Shard"
		part.Anchored = true
		part.Size = shard.Size
		part.Color = color
		part.Material = Enum.Material.Neon
		part.Transparency = 0.1
		part.CFrame = base
			* CFrame.new(shard.Offset)
			* CFrame.Angles(math.rad(shard.Tilt.X), 0, math.rad(shard.Tilt.Z))
			* CFrame.new(0, shard.Size.Y / 2, 0)
		part.Parent = node
		if i == 1 then
			core = part
		end
	end
	node.PrimaryPart = core

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Mine"
	prompt.ObjectText = if isVip then "VIP Gem Node" else "Gem Node"
	prompt.HoldDuration = Config.MineHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	local mined = false
	prompt.Triggered:Connect(function(player)
		if mined then
			return
		end
		if isVip and not player:GetAttribute("IsVIP") then
			return
		end
		mined = true
		Leaderboard.addGems(player, if isVip then Config.VipGemValue else Config.GemValue)
		node:Destroy()
	end)

	node.Parent = folder
end

function Mining.start()
	local folder = Instance.new("Folder")
	folder.Name = "GemNodes"
	folder.Parent = workspace

	for _, spawner in CollectionService:GetTagged(Tags.NodeSpawner) do
		spawnNode(spawner, folder)
	end
end

return Mining
