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

	Fighters look each other in the eye: their heads turn to the head of
	whoever they're fighting. Yours follows your lock (setFocus); the
	Arena rival, raid bosses and dungeon fighters follow the player the
	server says they're on (FocusUserId, else RivalOwner); another player
	follows you when you two can fight, else their own rival.

	  BodyPoses.step(dt)       pose every player's body for this frame
	  BodyPoses.start()        every frame from now on
	  BodyPoses.setFocus(fn)   fn() -> the model you're locked on, if any
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RivalPose = require(ReplicatedStorage.Shared.RivalPose)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)

local BodyPoses = {}

-- Bodies further than this from the camera aren't posed (too small to see).
BodyPoses.Range = 220
-- Heads only turn toward a foe this close.
BodyPoses.LookRange = 60

local focus: (() -> Model?)? = nil
function BodyPoses.setFocus(fn: () -> Model?)
	focus = fn
end

-- Where to look on a body: its head, or about head height over its root.
local function headOf(model: Model?): Vector3?
	local humanoid = model and model.Parent and model:FindFirstChildOfClass("Humanoid")
	if not model or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 1.5, 0) else nil
end

-- The foe's head, if it's close enough to look at.
local function lookPoint(from: Model, foe: Model?): Vector3?
	local point, own = headOf(foe), headOf(from)
	if point and own and (point - own).Magnitude <= BodyPoses.LookRange then
		return point
	end
	return nil
end

local function characterOf(userId: any): Model?
	local owner = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	return owner and owner.Character
end

local function near(model: Model, eye: Vector3?): boolean
	if not eye then
		return true
	end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return root == nil or not root:IsA("BasePart") or (root.Position - eye).Magnitude <= BodyPoses.Range
end

-- A body whose posing fails is reported once (in the developer console),
-- not swallowed silently.
local reported = setmetatable({}, { __mode = "k" })
local function pose(model: Model, ...)
	local ok, problem = pcall(RivalPose.update, model, ...)
	if not ok and not reported[model] then
		reported[model] = true
		warn("[BodyPoses] couldn't pose " .. model:GetFullName() .. ": " .. tostring(problem))
	end
end

-- Who another player is fighting, as far as this screen can tell: you, if
-- you're both in a fight and on opposite sides; else their own rival.
local function foeOf(player: Player, enemies: { Instance }): Model?
	local me = Players.LocalPlayer
	if
		me
		and me.Character
		and player:GetAttribute("CombatSession") ~= nil
		and me:GetAttribute("CombatSession") ~= nil
		and Matchmaking.versus(player, me)
	then
		return me.Character
	end
	for _, model in enemies do
		if model:IsA("Model") and Matchmaking.ownsRival(model, player) then
			return model
		end
	end
	return nil
end

function BodyPoses.step(dt: number)
	local now, clock = workspace:GetServerTimeNow(), os.clock()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local folder = workspace:FindFirstChild("Enemies")
	local enemies = if folder then folder:GetChildren() else {}
	local me = Players.LocalPlayer
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and near(character, eye) then
			local fighting = player:GetAttribute("CombatSession") ~= nil
			-- (Who it's looking at never stops the posing: any trouble there
			-- just means no head turn this frame.)
			local ok, foe = pcall(function()
				return if player == me then (if focus then focus() else nil) else foeOf(player, enemies)
			end)
			local look = nil
			if ok then
				local found, point = pcall(lookPoint, character, foe)
				look = if found then point else nil
			end
			-- The server's "Blocking" flag on the player backs up GuardUntil, so
			-- a foe's shield is up for as long as they hold their guard. Only in
			-- a fight: a flag left on after one (a guard move landing just as
			-- the fight ended) held the guard pose, shield arm up, for good.
			pose(
				character,
				dt,
				now,
				clock,
				not fighting,
				fighting and player:GetAttribute("Blocking") == true,
				look
			)
		end
	end
	-- The Arena rival, raid bosses and dungeon fighters: the server marks
	-- them "Posed" and leaves their poses to every client, so they move at
	-- the screen's frame rate instead of the network's.
	for _, model in enemies do
		if model:GetAttribute("Posed") and model:IsA("Model") and near(model, eye) then
			local found, look = pcall(function()
				return lookPoint(model, characterOf(model:GetAttribute("FocusUserId") or model:GetAttribute("RivalOwner")))
			end)
			pose(model, dt, now, clock, nil, nil, if found then look else nil)
		end
	end
end

local started=false
function BodyPoses.start()
 if started then return end
 started=true
 -- After Animator evaluation, before joint transforms are committed to physics.
 -- One owner and one phase prevent render/physics fighting over arm poses.
 RunService.PreSimulation:Connect(function(dt)
  BodyPoses.step(dt)
  RivalPose.holdGuards()
 end)
end

return BodyPoses
