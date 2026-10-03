--[[
	Every player's body acts out their fighting (Shared.RivalPose: slashes,
	heavy blows, casts, the guard, dodges, staggers and flinches), posed on
	each client from the attributes the server sets on the character
	(ActionKind, ActionStart, ActionAt, GuardUntil, HurtAt, BlockedAt...).

	Posed here rather than on the server because a player's character belongs
	to its own client: joint changes made on the server reach the other
	players late or not at all, so in a duel your foe would stand stock still
	while the Arena rival (the server's own model, posed there) moved fine.
	Locally it's smooth and on time for everyone.

	In an Arena session (CombatSession) the body holds a fighting stance
	between blows, as the rival's does; elsewhere it stands as its own
	animations have it.

	  BodyPoses.step(dt)   pose every player's body for this frame
	  BodyPoses.start()    every frame from now on
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RivalPose = require(ReplicatedStorage.Shared.RivalPose)

local BodyPoses = {}

function BodyPoses.step(dt: number)
	local now, clock = workspace:GetServerTimeNow(), os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local fighting = player:GetAttribute("CombatSession") ~= nil
			pcall(RivalPose.update, character, dt, now, clock, not fighting)
		end
	end
end

function BodyPoses.start()
	RunService.RenderStepped:Connect(BodyPoses.step)
end

return BodyPoses
