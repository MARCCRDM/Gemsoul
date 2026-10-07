--[[
	Every player's body is the same simple rig the Arena rival uses (Duelist's
	buildBody: a standard R15 layout, rigid Motor6D joints at known spots, no
	rotation baked into them), given to Roblox as the StarterCharacter.

	Why: fighting poses are drawn on every screen by bending each body's
	joints (Shared.RivalPose). The rival's own rig always bent cleanly; a
	player's Roblox avatar didn't (upgraded or physics-driven joints, R6 or
	rotated joint frames, depending on the avatar and the place's settings),
	so a foe's swings, guard and casts showed as a shrug or not at all. With
	the rival's rig for everyone, a player's moves read exactly like the
	rival's. Players wear full armour anyway; the avatar's skin colours are
	kept (FighterRig.dress).

	  FighterRig.build(skin)   a fresh body (Model), as Duelist builds the rival
	  FighterRig.start()       makes it everyone's StarterCharacter
]]
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local FighterRig = {}

-- The same layout as the rival's body (Duelist): name, size, centre
-- relative to the root's centre. Feet rest 1.9 studs below its bottom.
FighterRig.BODY = {
	{ "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.2, 0) },
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.8, 0) },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2.2, 0) },
	{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.85, 0) },
	{ "RightLowerArm", Vector3.new(1, 1, 1), Vector3.new(1.5, -0.15, 0) },
	{ "RightHand", Vector3.new(1, 0.3, 1), Vector3.new(1.5, -0.75, 0) },
	{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.85, 0) },
	{ "LeftLowerArm", Vector3.new(1, 1, 1), Vector3.new(-1.5, -0.15, 0) },
	{ "LeftHand", Vector3.new(1, 0.3, 1), Vector3.new(-1.5, -0.75, 0) },
	{ "RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -0.9, 0) },
	{ "RightLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(0.5, -2.05, 0) },
	{ "RightFoot", Vector3.new(1, 0.3, 1), Vector3.new(0.5, -2.75, 0) },
	{ "LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -0.9, 0) },
	{ "LeftLowerLeg", Vector3.new(1, 1.1, 1), Vector3.new(-0.5, -2.05, 0) },
	{ "LeftFoot", Vector3.new(1, 0.3, 1), Vector3.new(-0.5, -2.75, 0) },
}
-- name, parent part, child part, joint position (relative to the root)
FighterRig.JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, 0, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 0, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 1.6, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1.5, 1.35, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(1.5, 0.35, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(1.5, -0.6, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1.5, 1.35, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(-1.5, 0.35, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(-1.5, -0.6, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.5, -0.3, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0.5, -1.5, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0.5, -2.6, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.5, -0.3, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(-0.5, -1.5, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(-0.5, -2.6, 0) },
}

local SKIN = Color3.fromRGB(204, 142, 105)

function FighterRig.build(skin: Color3?): Model
	local rig = Instance.new("Model")
	local parts = {}
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CFrame = CFrame.new()
	root.Parent = rig
	parts.HumanoidRootPart = root
	rig.PrimaryPart = root
	for _, spec in FighterRig.BODY do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[2]
		part.CFrame = CFrame.new(spec[3])
		part.Color = skin or SKIN
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.CanCollide = spec[1] == "UpperTorso" or spec[1] == "LowerTorso" or spec[1] == "Head"
		part.Parent = rig
		parts[spec[1]] = part
	end
	for _, spec in FighterRig.JOINTS do
		local part0, part1 = parts[spec[2]], parts[spec[3]]
		local at = CFrame.new(spec[4])
		local motor = Instance.new("Motor6D")
		motor.Name = spec[1]
		motor.Part0, motor.Part1 = part0, part1
		motor.C0 = part0.CFrame:Inverse() * at
		motor.C1 = part1.CFrame:Inverse() * at
		motor.Parent = part1
	end
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = parts.Head
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 1.9
	humanoid.AutomaticScalingEnabled = false
	humanoid.Parent = rig
	Instance.new("Animator").Parent = humanoid
	return rig
end

-- The player's own avatar skin colours on their fighter's body (armour
-- covers most of it; the colour still shows at the neck and hands).
local COLOR_PARTS = {
	HeadColor = { "Head" },
	TorsoColor = { "UpperTorso", "LowerTorso" },
	LeftArmColor = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
	RightArmColor = { "RightUpperArm", "RightLowerArm", "RightHand" },
	LeftLegColor = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
	RightLegColor = { "RightUpperLeg", "RightLowerLeg", "RightFoot" },
}
function FighterRig.dress(player: Player, character: Model)
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(1, player.UserId))
	end)
	if not ok or not description or player.Character ~= character then
		return
	end
	for property, names in COLOR_PARTS do
		local color = (description :: any)[property]
		for _, name in names do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") and typeof(color) == "Color3" then
				part.Color = color
			end
		end
	end
end

function FighterRig.start()
	-- Not the avatar's bundle or accessories: those would rebuild the body
	-- (and its joints) as Roblox's avatar rig again.
	StarterPlayer.LoadCharacterAppearance = false
	local template = FighterRig.build()
	template.Name = "StarterCharacter"
	template:SetAttribute("FighterRig", true) -- (carried by every body spawned from it)
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	template.Parent = StarterPlayer
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(FighterRig.dress, player, character)
		end)
		-- Spawned before this ran (Studio's quick start): respawn as a fighter.
		local character = player.Character
		if character and not character:GetAttribute("FighterRig") then
			player:LoadCharacter()
		elseif character then
			task.spawn(FighterRig.dress, player, character)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return FighterRig
