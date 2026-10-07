--[[
	Your own body in a crowd (Shared.FightSpacing): bodies pass through each
	other (Server.FighterBodies), so this keeps yours a body's width from
	every other fighter, with a soft push each physics step, so you can
	neither stand on your opponent nor walk into them. And in a fight your
	body can't jump at all (the server also sets JumpPower 0).

	  FighterSpacing.start()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FightSpacing = require(ReplicatedStorage.Shared.FightSpacing)

local FighterSpacing = {}

local player = Players.LocalPlayer

local function rootOf(model: Instance?): BasePart?
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function alive(model: Instance): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function step(dt: number)
	local character = player.Character
	local root = rootOf(character)
	if not root or not character or not alive(character) or root.Anchored then
		return
	end
	local mine = root.Position
	local total = Vector3.zero
	local function keepClear(model: Instance)
		local other = rootOf(model)
		if other and model ~= character and alive(model) and (other.Position - mine).Magnitude < FightSpacing.Range then
			total += FightSpacing.push(mine, other.Position, FightSpacing.gap(other), root.CFrame.LookVector)
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			keepClear(other.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		if model:IsA("Model") then
			keepClear(model)
		end
	end
	if total.Magnitude > 0.001 then
		-- Eased: most of the overlap goes in a few frames, never a jolt.
		root.CFrame += total * math.min(1, dt * 14)
	end
end

local function applyJump()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not FightSpacing.inFight(player))
	end
end

function FighterSpacing.start()
	RunService.Stepped:Connect(function(_, dt)
		pcall(step, dt)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		applyJump()
	end)
	player:GetAttributeChangedSignal("CombatSession"):Connect(applyJump)
	player:GetAttributeChangedSignal("MatchId"):Connect(applyJump)
	applyJump()
end

return FighterSpacing
