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
	  BodyPoses.settle(char)   a body back from a fight: joints at rest, out of
	                           any stuck state, its animations started afresh
	  BodyPoses.settleOther(p) another player's body back from their fight, on
	                           this screen: joints at rest, leftover animations
	                           stopped
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RivalPose = require(ReplicatedStorage.Shared.RivalPose)
local Matchmaking = require(ReplicatedStorage.Shared.Matchmaking)

local BodyPoses = {}

-- Bodies further than this from the camera aren't posed (too small to see),
-- except your own: the camera is often far off it (the menu's orbit round
-- the moon base, an arena drop's flight) while it's doing something, and a
-- body that stops being posed part-way through a move stays that way.
-- Every other body goes straight back to rest as it leaves the range
-- (RivalPose.relax), never frozen mid-swing.
BodyPoses.Range = 220
-- Heads only turn toward a foe this close.
BodyPoses.LookRange = 60
-- Settling a body (BodyPoses.settle): seconds between stopping its
-- animations and restarting its Animate script.
BodyPoses.RestartDelay = 0.3
-- Another player's body after their fight (BodyPoses.settleOther): which
-- animations count as left over (playing OrphanSnapshot s after the fight
-- ends) and when those still playing are stopped (OrphanCheck s after).
BodyPoses.OrphanSnapshot, BodyPoses.OrphanCheck = 0.5, 1.6

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
-- not swallowed silently, and stands at rest rather than frozen in
-- whatever it was last posed in.
local reported = setmetatable({}, { __mode = "k" })
local function pose(model: Model, ...)
	local ok, problem = pcall(RivalPose.update, model, ...)
	if not ok then
		pcall(RivalPose.relax, model)
		if not reported[model] then
			reported[model] = true
			warn("[BodyPoses] couldn't pose " .. model:GetFullName() .. ": " .. tostring(problem))
		end
	end
end

-- The bodies posed this frame and the last (swapped every frame).
local posed: { [Model]: boolean } = {}
local posing: { [Model]: boolean } = {}

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
		if character and (player == me or near(character, eye)) then
			posing[character] = true
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
			posing[model] = true
			local found, look = pcall(function()
				return lookPoint(model, characterOf(model:GetAttribute("FocusUserId") or model:GetAttribute("RivalOwner")))
			end)
			pose(model, dt, now, clock, nil, nil, if found then look else nil)
		end
	end
	-- Bodies posed last frame and not this one (out of range, or gone):
	-- straight back to rest.
	for model in posed do
		if not posing[model] then
			pcall(RivalPose.relax, model)
		end
	end
	posed, posing = posing, posed
	table.clear(posing)
end

-- Your body coming back from a fight (or the intro's) to the lobby: the
-- server moves the same body back rather than spawning a new one, so
-- whatever it was in the middle of came along (a bent joint, a stride, a
-- seat, a fall, the arena drop's freeze) and sometimes stuck, leaving it
-- crouched or twisted. Settled here: every joint back to rest, out of any
-- seated, fallen or physics state, and its walk and idle animations started
-- afresh.
local SETTLE_STATES = {
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
}
function BodyPoses.settle(character: Model?)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	pcall(RivalPose.reset, character)
	humanoid.PlatformStand = false
	local seated = humanoid:GetState() == Enum.HumanoidStateType.Seated
	if humanoid.SeatPart == nil and (humanoid.Sit or seated) then
		humanoid.Sit = false
		seated = true
	end
	if (seated and humanoid.SeatPart == nil) or SETTLE_STATES[humanoid:GetState()] then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	-- (Its animations: whatever was left playing stops, and the stock Animate
	-- script restarts, picking up idle or walk from where the body is now.
	-- Not at once: as it starts, the stock Animate stops and destroys every
	-- track still playing, and a track destroyed mid-stop didn't always stop
	-- on other players' screens. There the body went on falling, arms up and
	-- out, while it stood normally on its own. RestartDelay lets the stops
	-- finish, and reach everyone, first.)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
	end
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") and animate.Enabled then
		animate.Enabled = false
		task.delay(BodyPoses.RestartDelay, function()
			if animate.Parent then
				animate.Enabled = true
			end
		end)
	end
end

-- Another player's body after their fight. Their own screen settles it
-- (BodyPoses.settle, as the fight ends and again 0.6 s on), but that only
-- reaches this screen as far as Roblox passes their animations on. Here,
-- too, its joints go back to rest, and an animation still playing from
-- before their second settle is stopped once that has had time to arrive
-- (OrphanCheck seconds after the fight ends): their own screen stopped
-- every one of those, so here it would only be left stuck.
local function playingTracks(character: Model): { AnimationTrack }
	local ok, tracks = pcall(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		return if animator then animator:GetPlayingAnimationTracks() else {}
	end)
	return if ok then tracks else {}
end
function BodyPoses.settleOther(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local function still(): boolean
		return player.Character == character and player:GetAttribute("CombatSession") == nil
	end
	pcall(RivalPose.reset, character)
	task.delay(BodyPoses.OrphanSnapshot, function()
		if not still() then
			return
		end
		pcall(RivalPose.reset, character)
		local before = playingTracks(character)
		task.delay(BodyPoses.OrphanCheck - BodyPoses.OrphanSnapshot, function()
			if not still() then
				return
			end
			for _, track in before do
				pcall(function()
					if track.IsPlaying then
						track:Stop(0.2)
					end
				end)
			end
		end)
	end)
end

local started=false
function BodyPoses.start()
 if started then return end
 started=true
	-- Out of a fight: settle the body now, and again once the move back has
	-- landed (a pose written in between can't stick either).
	local me = Players.LocalPlayer
	local wasFighting = me:GetAttribute("CombatSession") ~= nil
	me:GetAttributeChangedSignal("CombatSession"):Connect(function()
		local fighting = me:GetAttribute("CombatSession") ~= nil
		if wasFighting and not fighting then
			BodyPoses.settle(me.Character)
			task.delay(0.6, function()
				if me:GetAttribute("CombatSession") == nil then
					BodyPoses.settle(me.Character)
				end
			end)
		end
		wasFighting = fighting
	end)
	-- Everyone else's, as their fights end (BodyPoses.settleOther).
	local function watch(player: Player)
		if player == me then
			return
		end
		local was = player:GetAttribute("CombatSession") ~= nil
		player:GetAttributeChangedSignal("CombatSession"):Connect(function()
			local fighting = player:GetAttribute("CombatSession") ~= nil
			if was and not fighting then
				BodyPoses.settleOther(player)
			end
			was = fighting
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
 -- After Animator evaluation, before joint transforms are committed to physics.
 -- One owner and one phase prevent render/physics fighting over arm poses.
 RunService.PreSimulation:Connect(function(dt)
  BodyPoses.step(dt)
  RivalPose.holdGuards()
 end)
end

return BodyPoses
