--[[
	Fighters' bodies, in and out of a fight (Shared.FightSpacing):

	  - Bodies pass through one another: players' bodies are in the
	    "Fighters" collision group and computer fighters' (the Arena rival,
	    raid bosses, monsters) in "Foes"; Fighters don't collide with
	    Fighters or Foes (Foes still bump into each other). So nobody can be
	    stood on or climbed, by a hop or anything else. Each client keeps its
	    own body clear of the rest (Client.FighterSpacing).
	  - In a fight (FightSpacing.inFight) jumping is off: JumpPower 0 (the
	    jump button and Space do nothing), back on once it's over.

	  FighterBodies.start()
]]
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FightSpacing = require(ReplicatedStorage.Shared.FightSpacing)

local FighterBodies = {}

FighterBodies.JumpPower = 50 -- out of a fight (Roblox's default)

local function group(model: Instance, name: string)
	local function set(part: Instance)
		if part:IsA("BasePart") then
			part.CollisionGroup = name
		end
	end
	for _, part in model:GetDescendants() do
		set(part)
	end
	model.DescendantAdded:Connect(set)
end

-- Jumping off in a fight, on otherwise.
function FighterBodies.applyJump(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = if FightSpacing.inFight(player) then 0 else FighterBodies.JumpPower
end

function FighterBodies.start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Fighters")
		PhysicsService:RegisterCollisionGroup("Foes")
		PhysicsService:CollisionGroupSetCollidable("Fighters", "Fighters", false)
		PhysicsService:CollisionGroupSetCollidable("Fighters", "Foes", false)
	end)
	local function joined(player: Player)
		local function spawned(character: Model)
			group(character, "Fighters")
			FighterBodies.applyJump(player)
		end
		if player.Character then
			spawned(player.Character)
		end
		player.CharacterAdded:Connect(spawned)
		player:GetAttributeChangedSignal("CombatSession"):Connect(function()
			FighterBodies.applyJump(player)
		end)
		player:GetAttributeChangedSignal("MatchId"):Connect(function()
			FighterBodies.applyJump(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	-- Computer fighters live in workspace.Enemies (made by Enemies.start).
	task.spawn(function()
		local enemies = workspace:WaitForChild("Enemies", math.huge)
		local function added(model: Instance)
			if model:IsA("Model") then
				group(model, "Foes")
			end
		end
		for _, model in enemies:GetChildren() do
			added(model)
		end
		enemies.ChildAdded:Connect(added)
	end)
end

return FighterBodies
