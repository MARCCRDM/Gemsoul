local ArenaDrop = require(script.Parent.ArenaDrop)
-- Joining the PvP Arena is explicit; training visitors cannot receive player damage.
-- A Training session (a first fight, the intro rounds) and a practice bout
-- against a rival (PLAY's 1v1 PRACTICE) are fought in a ring of Arena Row
-- in the Outpost, else a private copy of the Arena (Server.PrivateArenas):
-- nobody else's.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Combat = require(ReplicatedStorage.Shared.Combat)
local CombatServer = require(script.Parent.CombatServer)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)
local SeatExit = require(script.Parent.SeatExit)
local RivalPose = require(ReplicatedStorage.Shared.RivalPose)
local PrivateArenas = require(script.Parent.PrivateArenas)
local ArenaSessions = {}
-- Hooks set by the Duelist (a computer rival in PvP); nil when not running.
ArenaSessions.onDungeonLeave = nil
ArenaSessions.onEnter = nil :: ((Player, boolean) -> ())?
ArenaSessions.onLeave = nil :: ((Player) -> ())?
-- Set by Systems/Duels: true while `player` is in a Ranked 1v1 still being
-- fought (no LEAVE out of it).
ArenaSessions.holdIn = nil :: ((Player) -> boolean)?
ArenaSessions.HoldMessage = "No leaving a ranked match: fight it out."
-- A duel's fighter off the floor (backed through the wall, knocked or
-- dashed out) is put back on it, this far in from the edge, instead of the
-- session ending (which forfeits the duel).
ArenaSessions.PullIn = 4
-- Where an off-the-floor fighter at `position` goes back to: straight in,
-- PullIn studs inside the edge of the floor round `center`. Pure.
function ArenaSessions.pullSpot(center: Vector3, radius: number, position: Vector3): Vector3
	local offset = Vector3.new(position.X - center.X, 0, position.Z - center.Z)
	local inward = if offset.Magnitude > 0.1 then offset.Unit else Vector3.new(0, 0, 1)
	return center + inward * math.max(0, radius - ArenaSessions.PullIn) + Vector3.new(0, 4, 0)
end
-- What holds a fighter's body still, by the attributes on them: their pod
-- still landing with them inside (PodLanding: Server.PodServer), the Arena
-- drop (ArenaDropPreparing / ArenaDropUntil, while they're ahead of `now`:
-- Server.ArenaDrop) or a dungeon's choice (DungeonSelecting: Server.Dungeons).
-- nil: nothing should, so a body still anchored is a hold never let go.
-- `get` reads one attribute. Pure.
function ArenaSessions.heldBy(get: (string) -> any, now: number): string?
	if get("PodLanding") ~= nil then
		return "PodLanding"
	end
	for _, name in { "ArenaDropPreparing", "ArenaDropUntil" } do
		local until_ = get(name)
		if type(until_) == "number" and until_ > now then
			return name
		end
	end
	if get("DungeonSelecting") then
		return "DungeonSelecting"
	end
	return nil
end
-- The rings practice against a rival takes first (Shared.Outpost.Settlement.Stages).
ArenaSessions.PracticeRings = { "DuelRingNorthWest", "DuelRingNorthEast", "DuelRingWest", "DuelRingEast" }
local busy = {}
local function enter(player, pvp)
	if busy[player] or player:GetAttribute("CombatSession") then
		return Shop.reply(false, "Leave your current Arena session first.")
	end
	if player:GetAttribute("Expedition") then
		return Shop.reply(false, "Return from your expedition before entering the Arena.")
	end
	if player:GetAttribute("RiftRun") then
		return Shop.reply(false, "Leave the Rift first.")
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local center = landmarks and landmarks:GetAttribute("ArenaFloor")
	if not PlayerData.get(player) or not humanoid or humanoid.Health <= 0 or typeof(center) ~= "Vector3" then
		return Shop.reply(false, "The Arena isn't ready yet.")
	end
	-- In a ring of Arena Row, out in the Outpost: training (a new miner's
	-- intro fights) the Intro Ring first; practice against a rival (PLAY's
	-- 1v1 PRACTICE) the duel rings first, leaving the Intro Ring and the
	-- Grand Arena for the intro and the duels.
	center = PrivateArenas.claim(player, if pvp then ArenaSessions.PracticeRings else nil) or center
	busy[player] = true
	ArenaDrop.prepare(player)
	local angle = math.rad((player.UserId % 8) * 45)
	local spot = center + Vector3.new(math.cos(angle) * 22, 4, math.sin(angle) * 22)
	local ok = pcall(function()
		player:RequestStreamAroundAsync(spot)
		if player.Character ~= character or humanoid.Health <= 0 then
			error("Character changed")
		end
		character:PivotTo(CFrame.lookAt(spot, center + Vector3.new(0, 4, 0)))
	end)
	busy[player] = nil
	if not ok then
		PrivateArenas.release(player)
		ArenaDrop.cancel(character)
		return Shop.reply(false, "Couldn't enter the Arena. Try again.")
	end
	player:SetAttribute("PvPEnabled", pvp == true)
	CombatServer.reset(player)
	player:SetAttribute("CombatSession", if pvp then "PvP" else "Training")
	local protection = Instance.new("ForceField")
	protection.Visible = false
	protection.Parent = character
	Debris:AddItem(protection, 3)
	if ArenaSessions.onEnter then
		task.spawn(ArenaSessions.onEnter, player, pvp == true)
	end
	return Shop.reply(
		true,
		if pvp
			then "Practice: a rival miner steps in. Win for coins."
			else "Training Arena: a sparring partner steps in. Player damage is off."
	)
end
-- (`stay`: out of the session where they stand, no trip back: a new
-- miner after a first fight, their round's card up)
local function leave(player, stay: boolean?)
	if player.Character then
		ArenaDrop.cancel(player.Character)
	end
	player:SetAttribute("ArenaInserted", nil)
	player:SetAttribute("ArenaDropPreparing", nil)
	if ArenaSessions.onDungeonLeave then
		ArenaSessions.onDungeonLeave(player)
	end
	if ArenaSessions.onLeave then
		ArenaSessions.onLeave(player)
	end
	CombatServer.reset(player)
	player:SetAttribute("PvPEnabled", false)
	player:SetAttribute("CombatSession", nil)
	player:SetAttribute("RaidId", nil)
	player:SetAttribute("Blocking", false)
	PrivateArenas.release(player)
	-- The same body goes back (no respawn), so free it first: out of any
	-- seat, unfrozen (the arena drop anchors it), still, and with no fight
	-- pose left on it for anyone's screen to draw. (The client settles its
	-- joints and animations as the session ends: BodyPoses.settle.)
	-- (Never in the way of leaving: anything odd about the body is skipped.)
	local character = player.Character
	if character then
		pcall(SeatExit.detach, character)
		pcall(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.PlatformStand = false
				humanoid.Sit = false
			end
		end)
		pcall(function()
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.Anchored = false
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end)
		pcall(function()
			for _, name in RivalPose.Attributes do
				character:SetAttribute(name, nil)
			end
		end)
	end
	if stay then
		return Shop.reply(true, "")
	end
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	-- Came from the Saga Outpost (a duel challenged there): back to it.
	local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
	local outpost = landmarks and landmarks:GetAttribute("OutpostSpawn")
	-- (to your pod's ramp: Server.PodServer)
	local pod = player:GetAttribute("PodSpawn")
	if typeof(pod) == "CFrame" then
		outpost = pod
	end
	if player.Character then
		if player:GetAttribute("Outpost") and typeof(outpost) == "CFrame" then
			player.Character:PivotTo(outpost)
			return Shop.reply(true, "Back at the Outpost.")
		end
		player.Character:PivotTo(if spawn then spawn.CFrame + Vector3.new(0, 4, 0) else CFrame.new(0, 6, 0))
	end
	return Shop.reply(true, "Back at base.")
end
-- Back to the menu (a finished duel uses this too).
ArenaSessions.leave = leave
ArenaSessions.enterTraining = function(player)
	return enter(player, false)
end
function ArenaSessions.start()
	Shop.register("ArenaTraining", function(player)
		return enter(player, false)
	end)
	Shop.register("ArenaPvP", function(player)
		return enter(player, true)
	end)
	Shop.register("ArenaLeave", function(player)
		-- (A new miner's intro rounds: all six won before the lobby.
		-- IntroRoundsLeft: Server.IntroRoundsServer.)
		if player:GetAttribute("IntroRoundsLeft") and player:GetAttribute("CombatSession") == "Training" then
			return Shop.reply(false, "Finish your intro rounds first.")
		end
		if ArenaSessions.holdIn and ArenaSessions.holdIn(player) then
			return Shop.reply(false, ArenaSessions.HoldMessage)
		end
		return leave(player)
	end)
	local function watch(player)
		player.CharacterAdded:Connect(function()
			if player:GetAttribute("DungeonSelecting") then return end
			player:SetAttribute("ArenaInserted", nil)
			player:SetAttribute("ArenaDropUntil", nil)
			player:SetAttribute("ArenaDropFocus", nil)
			if ArenaSessions.onLeave then
				ArenaSessions.onLeave(player)
			end
			player:SetAttribute("PvPEnabled", false)
			player:SetAttribute("CombatSession", nil)
			player:SetAttribute("RaidId", nil)
			PrivateArenas.release(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		if ArenaSessions.onLeave then
			ArenaSessions.onLeave(player)
		end
	end)
	-- Back onto the floor: straight in from where they are, PullIn studs
	-- inside its edge, facing the way they were, and still.
	local function pullBack(player: Player, root: BasePart)
		local center = Combat.arenaCenter(player)
		local landmarks = ReplicatedStorage:FindFirstChild("Landmarks")
		local radius = landmarks and landmarks:GetAttribute("ArenaRadius")
		if not center or type(radius) ~= "number" then
			return false
		end
		local at = ArenaSessions.pullSpot(center, radius, root.Position)
		local ok = pcall(function()
			player.Character:PivotTo(CFrame.new(at) * root.CFrame.Rotation)
			root.AssemblyLinearVelocity = Vector3.zero
		end)
		return ok
	end
	ArenaSessions.pullBack = pullBack
	-- Leaving the floor ends PvP eligibility; re-entry requires an explicit session.
	-- (Not a duel's: its fighters are put back on it. LEAVE, a knock-out or a
	-- respawn are the ways out of a duel.)
	local timer = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		timer += dt
		if timer < 0.25 then
			return
		end
		timer = 0
		local serverNow = workspace:GetServerTimeNow()
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			-- In a fight you can always walk: a body still anchored with
			-- nothing holding it (a hold from before the fight never let go:
			-- the pod's landing, say) is set free.
			if
				player:GetAttribute("CombatSession")
				and root
				and root.Anchored
				and not player:GetAttribute("DungeonId")
				and not player:GetAttribute("RaidId")
				and ArenaSessions.heldBy(function(name)
					return player:GetAttribute(name)
				end, serverNow) == nil
			then
				root.Anchored = false
			end
			if
				player:GetAttribute("CombatSession")
				and root
				and not player:GetAttribute("DungeonId")
				and not Combat.inArena(root.Position)
			then
				if
					not (
						player:GetAttribute("CombatSession") == "Duel"
						and player:GetAttribute("MatchId")
						and pullBack(player, root :: BasePart)
					)
				then
					leave(player)
				end
			end
		end
	end)
end
return ArenaSessions
