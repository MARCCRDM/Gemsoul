-- Marks VIP players with the IsVIP attribute. The client lets VIPs walk
-- through the mine's energy gate.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Vip = {}

local function isVip(player: Player): boolean
	if RunService:IsStudio() and Config.VipInStudio then
		return true
	end
	if Config.VipGamePassId == 0 then
		return false
	end
	local ok, owns =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, Config.VipGamePassId)
	return ok and owns
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("IsVIP", isVip(player))
end

function Vip.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.VipGamePassId then
			player:SetAttribute("IsVIP", true)
		end
	end)
end

return Vip
