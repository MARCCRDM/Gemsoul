-- Creates the RemoteEvents/Functions the client uses, in ReplicatedStorage.Remotes.
--   Profile (event, server -> client): the player's coins, gems and quota
--   Notify (event, server -> client): a short message to pop up
--   Request (function, client -> server): shop and cutting actions
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local Remotes = {
	Profile = Instance.new("RemoteEvent"),
	Notify = Instance.new("RemoteEvent"),
	Request = Instance.new("RemoteFunction"),
}
for name, remote in Remotes do
	remote.Name = name
	remote.Parent = folder
end
folder.Parent = ReplicatedStorage

return Remotes
