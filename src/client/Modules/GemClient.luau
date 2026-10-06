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

-- The server turns away requests less than 0.2s apart (Shop.handle:
-- "Slow down!"), so requests are spaced out here: each takes the next free
-- slot, and one that's turned away anyway is sent once more.
-- (Spam, like a held click, isn't queued up: past a second's backlog a
-- request is dropped as before.)
local SPACING = 0.22
local nextSlot = 0
local function pace(): boolean
	local now = os.clock()
	local slot = math.max(now, nextSlot)
	if slot - now > 1 then
		return false
	end
	nextSlot = slot + SPACING
	if slot > now then
		task.wait(slot - now)
	end
	return true
end

-- Returns the server's reply: { Ok: boolean, Message: string, ... }.
function GemClient.request(action: string, ...): { [string]: any }
	if not pace() then
		return { Ok = false, Message = "Slow down!" }
	end
	local ok, result = pcall(requestFunction.InvokeServer, requestFunction, action, ...)
	if ok and typeof(result) == "table" and result.Message == "Slow down!" and pace() then
		ok, result = pcall(requestFunction.InvokeServer, requestFunction, action, ...)
	end
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
