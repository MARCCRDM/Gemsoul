-- VIP players can walk through the mine's energy gate. Collision is changed
-- only on this client, so the gate stays solid for everyone else.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local player = Players.LocalPlayer

local function apply()
	local isVip = player:GetAttribute("IsVIP") == true
	for _, gate in CollectionService:GetTagged(Tags.VipGate) do
		gate.CanCollide = not isVip
	end
end

player:GetAttributeChangedSignal("IsVIP"):Connect(apply)
CollectionService:GetInstanceAddedSignal(Tags.VipGate):Connect(apply)
apply()
