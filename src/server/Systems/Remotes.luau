-- Creates the RemoteEvents/Functions the client uses, in ReplicatedStorage.Remotes.
--   Profile (event, server -> client): the player's coins, gems and quota
--   Notify (event, server -> client): a short message to pop up
--   Request (function, client -> server): shop and cutting actions
--   CombatInput (event, client -> server): attacks and rig maneuvers
--   CombatFx (event, server -> clients): hits, damage numbers, cooldowns
--   Party (event, server -> client): party state and invites
--   Social (event, server -> client): duel queue, challenges and matches
--   Report (event, client -> server): client script errors, for playtests
--   MechInput (event, client -> server): a mech pilot's throttle and steer, for
--             the server to drive with whenever it holds the mech's physics
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local Remotes = {
	Profile = Instance.new("RemoteEvent"),
	Notify = Instance.new("RemoteEvent"),
	Request = Instance.new("RemoteFunction"),
	CombatInput = Instance.new("RemoteEvent"),
	CombatFx = Instance.new("RemoteEvent"),
	MiningRoll = Instance.new("RemoteEvent"), -- server -> everyone: shared world discovery
	Party = Instance.new("RemoteEvent"),
	Social = Instance.new("RemoteEvent"),
	Report = Instance.new("RemoteEvent"),
	MechInput = Instance.new("RemoteEvent"),
}
for name, remote in Remotes do
	remote.Name = name
	remote.Parent = folder
end
folder.Parent = ReplicatedStorage

return Remotes
