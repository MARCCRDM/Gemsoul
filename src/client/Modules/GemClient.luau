-- The client's copy of its own profile (coins, gems, quota), kept fresh by
-- the server, plus a helper for sending requests to shopkeepers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiKit = require(script.Parent.UiKit)
local UiSound = require(script.Parent.UiSound)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local profileEvent = remotes:WaitForChild("Profile") :: RemoteEvent
local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local requestFunction = remotes:WaitForChild("Request") :: RemoteFunction

local GemClient = {}

GemClient.Profile = nil :: { [string]: any }?

local changed = Instance.new("BindableEvent")
GemClient.Changed = changed.Event

local function setProfile(profile)
	if profile then
		GemClient.Profile = profile
		changed:Fire(profile)
	end
end

-- The menu sound for a request's reply (a failed one plays the error sound).
local REPLY_SOUNDS = {
	Craft = "Craft",
	SalvageGems = "Craft",
	AutoCut = "Craft",
	SocketGem = "Enchant",
	EquipGear = "Equip",
	EquipCosmetic = "Equip",
	SellGems = "Coin",
	MarketSell = "Coin",
	BuyMaterial = "Coin",
	BuyCosmetic = "Coin",
	BuyCrate = "Coin",
	BuyBundle = "Reward",
	ClaimSeason = "Reward",
}

-- Returns the server's reply: { Ok: boolean, Message: string, ... }.
function GemClient.request(action: string, ...): { [string]: any }
	local ok, result = pcall(requestFunction.InvokeServer, requestFunction, action, ...)
	if not ok or typeof(result) ~= "table" then
		return { Ok = false, Message = "Couldn't reach the server. Try again." }
	end
	local sound = REPLY_SOUNDS[action]
	if sound and result.Message ~= "Slow down!" then
		UiSound.play(if result.Ok then sound else "Error")
	end
	return result
end

profileEvent.OnClientEvent:Connect(setProfile)
notifyEvent.OnClientEvent:Connect(function(message)
	if typeof(message) == "string" then
		UiKit.toast(message)
	end
end)

-- In case the first profile update arrived before this script was listening.
task.spawn(function()
	while not GemClient.Profile do
		local reply = GemClient.request("GetProfile")
		setProfile(reply.Profile)
		if not GemClient.Profile then
			task.wait(1)
		end
	end
end)

return GemClient
