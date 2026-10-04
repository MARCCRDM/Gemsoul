--[[
	Every player's body acts out their fighting (Shared.RivalPose: slashes,
	heavy blows, casts, the guard, dodges, staggers and flinches), posed on
	each client from the attributes the server sets on the character
	(ActionKind, ActionStart, ActionAt, GuardUntil, HurtAt, BlockedAt...).

	The Arena rival, raid bosses and dungeon fighters are posed here too
	(the server marks them "Posed"): joint changes made on the server are
	streamed at the network rate, so posing them there looked choppy.

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

-- Bodies further than this from the camera aren't posed (too small to see).
BodyPoses.Range = 220

local function near(model: Model, eye: Vector3?): boolean
	if not eye then
		return true
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return root == nil or not root:IsA("BasePart") or (root.Position - eye).Magnitude <= BodyPoses.Range
end

function BodyPoses.step(dt: number)
	local now, clock = workspace:GetServerTimeNow(), os.clock()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and near(character, eye) then
			local fighting = player:GetAttribute("CombatSession") ~= nil
			pcall(RivalPose.update, character, dt, now, clock, not fighting)
		end
	end
	-- The Arena rival, raid bosses and dungeon fighters: the server marks
	-- them "Posed" and leaves their poses to every client, so they move at
	-- the screen's frame rate instead of the network's.
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		if model:GetAttribute("Posed") and model:IsA("Model") and near(model, eye) then
			pcall(RivalPose.update, model, dt, now, clock)
		end
	end
end

function BodyPoses.start()
	RunService.RenderStepped:Connect(BodyPoses.step)
end

return BodyPoses
