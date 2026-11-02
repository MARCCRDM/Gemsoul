-- The DEV desk's gate in the Shelter (World OutpostWorld, tagged DevGate):
-- the game's Owners walk through it. Collision changes only on this
-- client, so it stays solid for everyone else (as the mine's VipGate).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tags = require(ReplicatedStorage.Shared.Tags)

local player = Players.LocalPlayer
local owner = table.find(Config.Playtest and Config.Playtest.Owners or {}, player.UserId) ~= nil

local function apply(gate: Instance)
	if owner and gate:IsA("BasePart") then
		gate.CanCollide = false
	end
end

if owner then
	for _, gate in CollectionService:GetTagged(Tags.DevGate) do
		apply(gate)
	end
	CollectionService:GetInstanceAddedSignal(Tags.DevGate):Connect(apply)
end
