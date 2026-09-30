-- Is a player standing near one of the shopkeepers? Shops use this so their
-- counters only work in person.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Tags)

local Nearby = {}

function Nearby.vendor(player: Player, vendorIds: { string }, range: number): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	for _, vendor in CollectionService:GetTagged(Tags.Vendor) do
		local torso = vendor:FindFirstChild("Torso")
		local id = torso and torso:GetAttribute("VendorId")
		if vendor:IsA("Model") and table.find(vendorIds, id) then
			if (vendor:GetPivot().Position - root.Position).Magnitude <= range then
				return true
			end
		end
	end
	return false
end

return Nearby
