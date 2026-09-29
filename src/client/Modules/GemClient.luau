-- The client's copy of its own profile (coins, gems, quota), kept fresh by
-- the server, plus a helper for sending requests to shopkeepers.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiKit = require(script.Parent.UiKit)

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

-- Returns the server's reply: { Ok: boolean, Message: string, ... }.
function GemClient.request(action: string, ...): { [string]: any }
	local ok, result = pcall(requestFunction.InvokeServer, requestFunction, action, ...)
	if not ok or typeof(result) ~= "table" then
		return { Ok = false, Message = "Couldn't reach the server. Try again." }
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
