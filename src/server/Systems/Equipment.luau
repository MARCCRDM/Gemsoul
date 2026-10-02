--[[
	Puts each player's class armor and weapon on their avatar, built from
	parts welded to the body so every player sees them. Works with R15 and
	R6 avatars; sizes follow the avatar's own body parts.

	Rebuilt on every spawn and whenever the class, gear or socketed gem
	changes, and sets walk speed and max health from the character's
	ratings. Socketed gems glow in their own colour: on the weapon, and at
	the centre of the chest for an armor gem.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Classes = require(ReplicatedStorage.Shared.Classes)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local ArmorKits = require(script.Parent.ArmorKits)
local FrontierAssets = require(script.Parent.FrontierAssets)
local SuitTraits = require(ReplicatedStorage.Shared.SuitTraits)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local PlayerData = require(script.Parent.PlayerData)
local Shop = require(script.Parent.Shop)

local FOLDER_NAME = "GemsoulGear"

local Equipment = {}

local STEEL = Color3.fromRGB(165, 170, 180)
local IRON = Color3.fromRGB(95, 98, 106)
local WOOD = Color3.fromRGB(110, 76, 48)
local DARK_WOOD = Color3.fromRGB(70, 48, 32)

-- Body parts, R15 first then R6.
local function bodyPart(character: Model, r15: string, r6: string): BasePart?
	return (character:FindFirstChild(r15) or character:FindFirstChild(r6)) :: BasePart?
end

local function piece(
	folder: Instance,
	anchor: BasePart,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): BasePart
	local part = Instance.new("Part")
	part.Name = "Gear"
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = math.max(size.X, size.Y, size.Z) > 0.6
	part.CFrame = anchor.CFrame * cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function neon(folder: Instance, anchor: BasePart, cframe: CFrame, size: Vector3, color: Color3): BasePart
	local part = piece(folder, anchor, cframe, size, color, Enum.Material.Neon)
	part.CastShadow = false
	return part
end

-- Weapons -----------------------------------------------------------------------------
-- Weapons are built along +Y with the grip at the origin, then mounted in a hand.

local function gemSocket(folder: Instance, anchor: BasePart, mount: CFrame, at: Vector3, gem, size: number)
	if gem then
		local shade = GemConfig.shade(gem)
		local color = if shade.Prismatic then Color3.fromRGB(120, 255, 200) else shade.Color
		local stone = neon(
			folder,
			anchor,
			mount * CFrame.new(at) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Vector3.one * size,
			color
		)
		stone.Name = "SocketedGem"
	else
		piece(
			folder,
			anchor,
			mount * CFrame.new(at),
			Vector3.one * size * 0.8,
			IRON,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
	end
end

-- A pointed blade tip: two wedges meeting on the blade's centre line.
local function bladeTip(folder: Instance, hand: BasePart, at: CFrame, width: number, length: number, color: Color3)
	for _, side in { -1, 1 } do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Gear"
		wedge.Size = Vector3.new(0.06, length, width / 2)
		wedge.Color = color
		wedge.Material = Enum.Material.Metal
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.Massless = true
		wedge.CastShadow = false
		wedge.CFrame = hand.CFrame
			* at
			* CFrame.new(side * width / 4, length / 2, 0)
			* CFrame.Angles(0, math.rad(-90 * side), 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = wedge
		weld.Parent = wedge
		wedge.Parent = folder
	end
end

-- A knightly longsword: leather grip, brass pommel, a crossguard with
-- rounded ends and a pointed blade with a fuller down the middle. An
-- enchanted blade's fuller glows in its gem's element.
local LEATHER_GRIP = Color3.fromRGB(62, 40, 28)
local BRASS = Color3.fromRGB(184, 144, 70)
local function sword(folder: Instance, hand: BasePart, mount: CFrame, _accent: Color3, gem, bladeLength: number)
	piece(folder, hand, mount, Vector3.new(0.18, 0.86, 0.18), LEATHER_GRIP, Enum.Material.Leather)
	for _, y in { -0.2, 0.2 } do
		piece(folder, hand, mount * CFrame.new(0, y, 0), Vector3.new(0.21, 0.05, 0.21), BRASS, Enum.Material.Metal)
	end
	piece(
		folder,
		hand,
		mount * CFrame.new(0, -0.5, 0),
		Vector3.one * 0.3,
		BRASS,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	piece(folder, hand, mount * CFrame.new(0, 0.5, 0), Vector3.new(1.0, 0.12, 0.16), STEEL, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		piece(
			folder,
			hand,
			mount * CFrame.new(side * 0.52, 0.52, 0),
			Vector3.one * 0.18,
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
	end
	local tip = 0.45
	local body = bladeLength - tip
	piece(
		folder,
		hand,
		mount * CFrame.new(0, 0.56 + body / 2, 0),
		Vector3.new(0.26, body, 0.06),
		STEEL,
		Enum.Material.Metal
	)
	bladeTip(folder, hand, mount * CFrame.new(0, 0.56 + body, 0), 0.26, tip, STEEL)
	local fuller = Vector3.new(0.05, body * 0.8, 0.07)
	local fullerAt = mount * CFrame.new(0, 0.6 + body * 0.42, 0)
	if gem then
		neon(folder, hand, fullerAt, fuller, GemConfig.ElementColors[gem.Element] or STEEL)
	else
		piece(folder, hand, fullerAt, fuller, IRON, Enum.Material.Metal)
	end
	gemSocket(folder, hand, mount, Vector3.new(0, 0.5, -0.1), gem, 0.2)
end

local function shield(folder: Instance, arm: BasePart, side: number, width: number, height: number, accent: Color3, gem)
	local mount = CFrame.new(side * (arm.Size.X / 2 + 0.2), 0, 0) * CFrame.Angles(0, math.rad(90 * side), 0)
	piece(folder, arm, mount, Vector3.new(width, height, 0.2), STEEL, Enum.Material.Metal)
	piece(
		folder,
		arm,
		mount * CFrame.new(0, 0, -0.12),
		Vector3.new(width * 0.8, height * 0.8, 0.06),
		Color3.fromRGB(60, 70, 110),
		Enum.Material.Fabric
	)
	for _, y in { -height / 2, height / 2 } do
		neon(folder, arm, mount * CFrame.new(0, y, -0.1), Vector3.new(width, 0.08, 0.05), accent)
	end
	gemSocket(folder, arm, mount, Vector3.new(0, 0, -0.2), gem, 0.4)
end

local WEAPONS: { [string]: (Instance, Model, BasePart, BasePart, Color3, any) -> () } = {}

-- `right` / `left` are grip points in each hand; mounts are relative to them.
local HELD_FORWARD = CFrame.Angles(math.rad(-110), 0, 0) -- pointing forward and a little down
local UPRIGHT = CFrame.Angles(math.rad(-12), 0, 0)

-- The Saga Miner's iconic kit: a blaster in the right hand and a riot
-- shield on the left forearm. The pistol's energy cell and the shield's rim
-- glow in the accent colour (an enchanting gem recolours them).
local GUNMETAL = Color3.fromRGB(58, 62, 72)
local function pistolKit(folder, _character, right, accent, gem, finish: Color3, heavy: boolean)
	-- In the held frame +Y points out along the barrel and +Z is up. K scales
	-- the whole pistol, so it reads clearly at a distance.
	local m = HELD_FORWARD
	local K = if heavy then 1.35 else 1.15
	local function at(x: number, y: number, z: number): CFrame
		return m * CFrame.new(x * K, y * K, z * K)
	end
	piece(folder, right, at(0, 0, -0.05), Vector3.new(0.2, 0.26, 0.5) * K, GUNMETAL, Enum.Material.SmoothPlastic)
	piece(folder, right, at(0, 0.3, 0.26), Vector3.new(0.26, 0.95, 0.32) * K, finish, Enum.Material.SmoothPlastic)
	piece(folder, right, at(0, 0.86, 0.3), Vector3.new(0.3, 0.22, 0.3) * K, GUNMETAL, Enum.Material.SmoothPlastic)
	piece(folder, right, at(0, 0.35, 0.48), Vector3.new(0.12, 0.58, 0.06) * K, GUNMETAL, Enum.Material.SmoothPlastic)
	for y = 0, 2 do
		piece(
			folder,
			right,
			at(0.14, 0.35 + y * 0.14, 0.3),
			Vector3.new(0.035, 0.06, 0.16) * K,
			GUNMETAL,
			Enum.Material.SmoothPlastic
		)
	end
	neon(folder, right, at(0, 0.12, 0.44), Vector3.new(0.14, 0.4, 0.08) * K, accent)
	neon(folder, right, at(0, 1.12, 0.3), Vector3.new(0.2, 0.04, 0.2) * K, accent)
	gemSocket(folder, right, m, Vector3.new(0.15, 0.3, 0.26) * K, gem, 0.2)
end

local function _shieldKit(folder, character, accent, gem, finish: Color3, heavy: boolean)
	local arm = bodyPart(character, "LeftLowerArm", "Left Arm")
	if arm then
		local mount = CFrame.new(-(arm.Size.X / 2 + 0.25), 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
		local shieldHeight = if heavy then 2.6 else 2.2
		piece(folder, arm, mount, Vector3.new(1.7, shieldHeight, 0.18), finish, Enum.Material.SmoothPlastic)
		piece(folder, arm, mount * CFrame.new(0, 0, -0.09), Vector3.new(1.3, 1.8, 0.05), GUNMETAL, Enum.Material.Metal)
		-- A viewing slit near the top, and a glowing rim.
		piece(
			folder,
			arm,
			mount * CFrame.new(0, 0.62, -0.12),
			Vector3.new(0.9, 0.12, 0.04),
			Color3.fromRGB(20, 28, 40),
			Enum.Material.Glass
		)
		for _, y in { -shieldHeight / 2, shieldHeight / 2 } do
			piece(
				folder,
				arm,
				mount * CFrame.new(0, y, -0.02),
				Vector3.new(1.72, 0.12, 0.22),
				GUNMETAL,
				Enum.Material.SmoothPlastic
			)
		end
		for _, x in { -0.85, 0.85 } do
			piece(
				folder,
				arm,
				mount * CFrame.new(x, 0, -0.02),
				Vector3.new(0.12, shieldHeight, 0.22),
				GUNMETAL,
				Enum.Material.SmoothPlastic
			)
			neon(folder, arm, mount * CFrame.new(x, 0.35, -0.15), Vector3.new(0.055, 0.5, 0.035), accent)
		end
		-- A Saga Stone emblem in the middle.
		neon(
			folder,
			arm,
			mount * CFrame.new(0, -0.1, -0.13) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(0.34, 0.34, 0.04),
			Color3.fromRGB(255, 184, 72)
		)
		gemSocket(folder, arm, mount, Vector3.new(0, -0.1, -0.2), gem, 0.25)
	end
end

-- The fallback uses the same sidearm geometry as rarity-aware runtime builds.
WEAPONS.CleanSidearm = function(folder, _character, right, _left, accent, gem)
	FrontierAssets.sidearm(folder, right, HELD_FORWARD, 1, accent, STEEL)
	gemSocket(folder, right, HELD_FORWARD, Vector3.new(0.15, 0.12, 0.23), gem, 0.15)
end
local function frontierShield(folder, character, accent, gem, finish, rarity, family)
	local arm = bodyPart(character, "LeftLowerArm", "Left Arm")
	if not arm then
		return
	end
	local mount = CFrame.new(-(arm.Size.X / 2 + 0.2), 0, 0) * CFrame.Angles(0, math.rad(-90), 0)
	FrontierAssets.shield(folder, arm, mount, rarity, accent, finish, family)
	gemSocket(folder, arm, mount, Vector3.new(0, 0.1, -0.28), gem, 0.19)
end

WEAPONS.PistolShield = function(folder, character, right, _left, accent, gem)
	pistolKit(folder, character, right, accent, gem, Color3.fromRGB(218, 146, 59), false)
end
WEAPONS.SurveyorKit = function(folder, character, right, _left, accent, gem)
	pistolKit(folder, character, right, accent, gem, Color3.fromRGB(97, 161, 177), false)
	piece(
		folder,
		right,
		HELD_FORWARD * CFrame.new(0, 0.38, 0.7),
		Vector3.new(0.22, 0.5, 0.18),
		GUNMETAL,
		Enum.Material.SmoothPlastic
	)
end
WEAPONS.BulwarkKit = function(folder, character, right, _left, accent, gem)
	pistolKit(folder, character, right, accent, gem, Color3.fromRGB(210, 220, 229), true)
end

WEAPONS.Sword = function(folder, _character, right, _left, accent, gem)
	sword(folder, right, HELD_FORWARD, accent, gem, 3)
end

WEAPONS.TwinBlades = function(folder, _character, right, left, accent, gem)
	sword(folder, right, HELD_FORWARD, accent, gem, 2.2)
	sword(folder, left, HELD_FORWARD, accent, nil, 2.2)
end

WEAPONS.Greataxe = function(folder, _character, right, _left, accent, gem)
	local m = UPRIGHT * CFrame.new(0, -1, 0)
	piece(folder, right, m * CFrame.new(0, 1.6, 0), Vector3.new(0.24, 4.4, 0.24), WOOD, Enum.Material.Wood)
	piece(folder, right, m * CFrame.new(0, 3.3, -0.55), Vector3.new(0.14, 1.5, 1), STEEL, Enum.Material.Metal)
	piece(folder, right, m * CFrame.new(0, 3.3, 0.3), Vector3.new(0.14, 0.7, 0.5), IRON, Enum.Material.Metal)
	neon(folder, right, m * CFrame.new(0, 3.3, -1.07), Vector3.new(0.05, 1.4, 0.05), accent)
	gemSocket(folder, right, m, Vector3.new(0, 3.3, 0), gem, 0.3)
end

WEAPONS.Warhammer = function(folder, _character, right, _left, accent, gem)
	local m = UPRIGHT * CFrame.new(0, -1, 0)
	piece(folder, right, m * CFrame.new(0, 1.6, 0), Vector3.new(0.26, 4.4, 0.26), WOOD, Enum.Material.Wood)
	piece(folder, right, m * CFrame.new(0, 3.5, 0), Vector3.new(0.8, 0.8, 1.6), IRON, Enum.Material.Metal)
	neon(folder, right, m * CFrame.new(0, 3.5, 0), Vector3.new(0.84, 0.1, 1.64), accent)
	gemSocket(folder, right, m, Vector3.new(0.42, 3.5, 0), gem, 0.34)
end

WEAPONS.Staff = function(folder, _character, right, _left, accent, gem)
	local m = CFrame.new(0, -1.8, 0)
	piece(folder, right, m * CFrame.new(0, 2.4, 0), Vector3.new(0.24, 6, 0.24), DARK_WOOD, Enum.Material.Wood)
	for _, a in { 0, 90 } do
		piece(
			folder,
			right,
			m * CFrame.new(0, 5.55, 0) * CFrame.Angles(0, math.rad(a), 0),
			Vector3.new(0.8, 0.12, 0.12),
			STEEL,
			Enum.Material.Metal
		)
	end
	neon(folder, right, m * CFrame.new(0, 4.5, 0), Vector3.new(0.3, 0.1, 0.3), accent)
	gemSocket(folder, right, m, Vector3.new(0, 5.8, 0), gem, 0.5)
end

WEAPONS.WandTome = function(folder, _character, right, left, accent, gem)
	local m = CFrame.Angles(math.rad(-100), 0, 0)
	piece(folder, right, m * CFrame.new(0, 0.5, 0), Vector3.new(0.14, 1.5, 0.14), DARK_WOOD, Enum.Material.Wood)
	gemSocket(folder, right, m, Vector3.new(0, 1.35, 0), gem, 0.24)
	local book = CFrame.new(0, 0, -0.35) * CFrame.Angles(math.rad(-70), 0, 0)
	piece(folder, left, book, Vector3.new(0.95, 1.2, 0.3), Color3.fromRGB(90, 40, 60), Enum.Material.Leather)
	piece(
		folder,
		left,
		book * CFrame.new(0.04, 0, 0),
		Vector3.new(0.88, 1.1, 0.32),
		Color3.fromRGB(235, 225, 200),
		Enum.Material.SmoothPlastic
	)
	neon(folder, left, book * CFrame.new(0, 0, -0.17), Vector3.new(0.5, 0.5, 0.02), accent)
end

WEAPONS.Orb = function(folder, _character, right, _left, accent, gem)
	local m = CFrame.new(0, 0.3, -0.9)
	local orb =
		piece(folder, right, m, Vector3.one * 1, Color3.fromRGB(170, 220, 255), Enum.Material.Glass, Enum.PartType.Ball)
	orb.Transparency = 0.45
	piece(
		folder,
		right,
		m * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.1, 1.3, 1.3),
		accent,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	).Transparency =
		0.5
	gemSocket(folder, right, m, Vector3.zero, gem, 0.34)
end

local function bow(folder: Instance, hand: BasePart, length: number, accent: Color3, gem)
	-- Held beside the left hand (outside the arm) so it's easy to see.
	local grip = CFrame.new(-0.6, 0, -0.15)
	for _, side in { -1, 1 } do
		piece(
			folder,
			hand,
			grip * CFrame.new(0, side * length * 0.26, 0.12) * CFrame.Angles(math.rad(side * 14), 0, 0),
			Vector3.new(0.16, length * 0.52, 0.2),
			WOOD,
			Enum.Material.Wood
		)
		neon(folder, hand, grip * CFrame.new(0, side * length * 0.5, 0.3), Vector3.new(0.12, 0.12, 0.12), accent)
	end
	local string_ = piece(
		folder,
		hand,
		grip * CFrame.new(0, 0, 0.36),
		Vector3.new(0.04, length * 0.98, 0.04),
		Color3.fromRGB(230, 230, 220),
		Enum.Material.SmoothPlastic
	)
	string_.CastShadow = false
	piece(folder, hand, grip, Vector3.new(0.24, 0.6, 0.26), DARK_WOOD, Enum.Material.Leather)
	gemSocket(folder, hand, grip, Vector3.new(0, 0, -0.18), gem, 0.22)
end

WEAPONS.Longbow = function(folder, _character, _right, left, accent, gem)
	bow(folder, left, 5, accent, gem)
end

WEAPONS.Shortbow = function(folder, _character, _right, left, accent, gem)
	bow(folder, left, 3.4, accent, gem)
end

WEAPONS.Crossbow = function(folder, _character, right, _left, accent, gem)
	local m = CFrame.Angles(math.rad(-90), 0, 0)
	piece(folder, right, m * CFrame.new(0, 0.6, 0), Vector3.new(0.3, 2.2, 0.3), WOOD, Enum.Material.Wood)
	piece(folder, right, m * CFrame.new(0, 1.6, 0), Vector3.new(2.2, 0.16, 0.22), STEEL, Enum.Material.Metal)
	piece(
		folder,
		right,
		m * CFrame.new(0, 1.2, 0.05),
		Vector3.new(2, 0.04, 0.04),
		Color3.fromRGB(230, 230, 220),
		Enum.Material.SmoothPlastic
	)
	neon(folder, right, m * CFrame.new(0, 1.2, -0.16), Vector3.new(0.06, 1.2, 0.04), accent)
	gemSocket(folder, right, m, Vector3.new(0, 1.6, -0.18), gem, 0.24)
end

WEAPONS.SwordShield = function(folder, character, right, _left, accent, gem)
	sword(folder, right, HELD_FORWARD, accent, nil, 2.8)
	local arm = bodyPart(character, "LeftLowerArm", "Left Arm")
	if arm then
		shield(folder, arm, -1, 1.8, 2.2, accent, gem)
	end
end

WEAPONS.MaceShield = function(folder, character, right, _left, accent, gem)
	local m = HELD_FORWARD
	piece(folder, right, m * CFrame.new(0, 0.7, 0), Vector3.new(0.22, 2.2, 0.22), WOOD, Enum.Material.Wood)
	piece(folder, right, m * CFrame.new(0, 2, 0), Vector3.new(0.7, 0.7, 0.7), IRON, Enum.Material.Metal)
	neon(folder, right, m * CFrame.new(0, 2, 0), Vector3.new(0.74, 0.1, 0.74), accent)
	local arm = bodyPart(character, "LeftLowerArm", "Left Arm")
	if arm then
		shield(folder, arm, -1, 2, 3.4, accent, gem)
	end
end

-- Newer weapons: a spear, a storm scepter, throwing knives and a halberd.

WEAPONS.Spear = function(folder, _character, right, _left, accent, gem)
	local m = HELD_FORWARD * CFrame.new(0, -1.2, 0)
	piece(folder, right, m * CFrame.new(0, 1.8, 0), Vector3.new(0.2, 6, 0.2), WOOD, Enum.Material.Wood)
	-- Leaf-shaped head: a blade with a crossguard beneath it.
	piece(folder, right, m * CFrame.new(0, 5.3, 0), Vector3.new(0.34, 1.4, 0.08), STEEL, Enum.Material.Metal)
	piece(folder, right, m * CFrame.new(0, 4.55, 0), Vector3.new(0.7, 0.14, 0.18), IRON, Enum.Material.Metal)
	neon(folder, right, m * CFrame.new(0, 5.3, -0.045), Vector3.new(0.05, 1.2, 0.02), accent)
	gemSocket(folder, right, m, Vector3.new(0, 4.4, -0.14), gem, 0.22)
end

WEAPONS.Scepter = function(folder, _character, right, _left, accent, gem)
	local m = CFrame.Angles(math.rad(-20), 0, 0)
	piece(folder, right, m * CFrame.new(0, 0.9, 0), Vector3.new(0.18, 2.4, 0.18), DARK_WOOD, Enum.Material.Wood)
	-- A ring cage holding the crackling core.
	for _, a in { 0, 60, 120 } do
		piece(
			folder,
			right,
			m * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, math.rad(a), 0),
			Vector3.new(0.9, 0.9, 0.1),
			STEEL,
			Enum.Material.Metal
		).Transparency =
			0.2
	end
	neon(folder, right, m * CFrame.new(0, 2.5, 0), Vector3.new(0.4, 0.4, 0.4), accent)
	gemSocket(folder, right, m, Vector3.new(0, 2.05, -0.12), gem, 0.2)
end

WEAPONS.Knives = function(folder, character, right, left, accent, gem)
	-- A knife in each hand, and a bandolier of spares across the chest.
	for _, hand in { right, left } do
		local m = CFrame.Angles(math.rad(-100), 0, 0)
		piece(folder, hand, m * CFrame.new(0, 0.2, 0), Vector3.new(0.14, 0.4, 0.14), DARK_WOOD, Enum.Material.Leather)
		piece(folder, hand, m * CFrame.new(0, 0.75, 0), Vector3.new(0.18, 0.7, 0.05), STEEL, Enum.Material.Metal)
	end
	local torso = bodyPart(character, "UpperTorso", "Torso")
	if torso then
		local strap = CFrame.new(0, 0, -torso.Size.Z / 2 - 0.12) * CFrame.Angles(0, 0, math.rad(40))
		piece(folder, torso, strap, Vector3.new(0.35, torso.Size.Y * 1.35, 0.1), DARK_WOOD, Enum.Material.Leather)
		for i = -2, 2 do
			piece(
				folder,
				torso,
				strap * CFrame.new(0, i * 0.35, -0.08),
				Vector3.new(0.12, 0.3, 0.05),
				STEEL,
				Enum.Material.Metal
			)
		end
		neon(folder, torso, strap * CFrame.new(0, 0, -0.06), Vector3.new(0.05, torso.Size.Y * 1.3, 0.02), accent)
		gemSocket(folder, torso, strap, Vector3.new(0, 0.9, -0.14), gem, 0.22)
	end
end

WEAPONS.Halberd = function(folder, _character, right, _left, accent, gem)
	local m = UPRIGHT * CFrame.new(0, -1.4, 0)
	piece(folder, right, m * CFrame.new(0, 2, 0), Vector3.new(0.22, 6.2, 0.22), WOOD, Enum.Material.Wood)
	-- Axe blade on one side, a hook on the other, a spike on top.
	piece(folder, right, m * CFrame.new(0, 4.6, -0.55), Vector3.new(0.12, 1.3, 0.9), STEEL, Enum.Material.Metal)
	piece(folder, right, m * CFrame.new(0, 4.8, 0.4), Vector3.new(0.12, 0.35, 0.6), IRON, Enum.Material.Metal)
	piece(folder, right, m * CFrame.new(0, 5.6, 0), Vector3.new(0.14, 1, 0.14), STEEL, Enum.Material.Metal)
	neon(folder, right, m * CFrame.new(0, 4.6, -1.02), Vector3.new(0.05, 1.2, 0.05), accent)
	gemSocket(folder, right, m, Vector3.new(0, 4.6, 0), gem, 0.26)
end

-- Back pieces (cosmetics) ---------------------------------------------------------------------
-- Built behind the torso; `m` is the middle of the back, facing backward.

local BACKS: { [string]: (Instance, BasePart, CFrame, Color3, Color3) -> () } = {}

BACKS.Pack = function(folder, torso, m, glow, _accent)
	piece(folder, torso, m * CFrame.new(0, -0.1, -0.35), Vector3.new(1.4, 1.6, 0.7), DARK_WOOD, Enum.Material.Leather)
	piece(folder, torso, m * CFrame.new(0, 0.85, -0.4), Vector3.new(1.5, 0.35, 0.8), WOOD, Enum.Material.Fabric)
	-- A pick strapped to the side.
	piece(
		folder,
		torso,
		m * CFrame.new(0.85, 0.2, -0.3) * CFrame.Angles(0, 0, math.rad(15)),
		Vector3.new(0.12, 2.4, 0.12),
		WOOD,
		Enum.Material.Wood
	)
	piece(folder, torso, m * CFrame.new(1.1, 1.3, -0.3), Vector3.new(0.9, 0.18, 0.18), IRON, Enum.Material.Metal)
	neon(folder, torso, m * CFrame.new(0, -0.1, -0.72), Vector3.new(0.3, 0.3, 0.05), glow)
end

BACKS.Banner = function(folder, torso, m, glow, accent)
	piece(folder, torso, m * CFrame.new(0.6, 1.4, -0.3), Vector3.new(0.14, 5, 0.14), DARK_WOOD, Enum.Material.Wood)
	local cloth = piece(
		folder,
		torso,
		m * CFrame.new(0.6 - 0.75, 2.6, -0.3),
		Vector3.new(1.4, 2, 0.05),
		accent:Lerp(Color3.new(0, 0, 0), 0.25),
		Enum.Material.Fabric
	)
	cloth.Name = "Banner"
	neon(folder, torso, m * CFrame.new(0.6 - 0.75, 1.65, -0.3), Vector3.new(1.4, 0.1, 0.07), glow)
	neon(folder, torso, m * CFrame.new(0.6, 3.95, -0.3), Vector3.new(0.3, 0.3, 0.3), glow)
end

BACKS.Geode = function(folder, torso, m, glow, _accent)
	piece(
		folder,
		torso,
		m * CFrame.new(0, 0, -0.4),
		Vector3.new(1.8, 1.8, 0.8),
		Color3.fromRGB(90, 84, 96),
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
	for i = 0, 4 do
		local angle = math.rad(i * 72)
		neon(
			folder,
			torso,
			m * CFrame.new(math.cos(angle) * 0.45, math.sin(angle) * 0.45, -0.8) * CFrame.Angles(0, 0, angle),
			Vector3.new(0.25, 0.5, 0.25),
			glow
		)
	end
end

BACKS.Cape = function(folder, torso, m, glow, accent)
	local length = torso.Size.Y * 1.9
	piece(
		folder,
		torso,
		m * CFrame.new(0, torso.Size.Y / 2 - length / 2 + 0.3, -0.15) * CFrame.Angles(math.rad(-6), 0, 0),
		Vector3.new(torso.Size.X * 0.95, length, 0.08),
		accent:Lerp(Color3.new(0, 0, 0), 0.55),
		Enum.Material.Fabric
	)
	neon(
		folder,
		torso,
		m * CFrame.new(0, torso.Size.Y / 2 - length + 0.35, -0.22) * CFrame.Angles(math.rad(-6), 0, 0),
		Vector3.new(torso.Size.X * 0.95, 0.12, 0.09),
		glow
	)
end

BACKS.Wings = function(folder, torso, m, glow, _accent)
	for _, side in { -1, 1 } do
		for i, size in { 2.6, 2, 1.4 } do
			neon(
				folder,
				torso,
				m
					* CFrame.new(side * (0.5 + i * 0.35), 0.5 + i * 0.15, -0.3 - i * 0.1)
					* CFrame.Angles(0, 0, math.rad(side * (-50 + i * 18))),
				Vector3.new(0.35, size, 0.08),
				glow
			).Transparency =
				0.25
		end
	end
end

BACKS.Halo = function(folder, torso, m, glow, _accent)
	local center = m * CFrame.new(0, torso.Size.Y / 2 + 0.9, -0.3)
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		neon(
			folder,
			torso,
			center
				* CFrame.new(math.cos(angle) * 1.1, math.sin(angle) * 1.1, 0)
				* CFrame.Angles(0, 0, angle + math.rad(45)),
			Vector3.one * 0.3,
			if i % 2 == 0 then glow else Color3.new(1, 1, 1)
		)
	end
end

-- Elemental effects ----------------------------------------------------------------------
-- An enchanted item takes on its gem's element: its glowing trim turns the
-- element's colour, the gem lights up its surroundings, and particles pour
-- off the item (flames, frost motes, sparks or poison fumes).

local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

type ParticleStyle = {
	Texture: string,
	Colors: { Color3 },
	Size: number,
	Lifetime: NumberRange,
	Speed: NumberRange,
	Acceleration: Vector3,
	Rate: number,
	Transparency: number,
	Spread: number,
}

local PARTICLES: { [string]: ParticleStyle } = {
	Fire = {
		Texture = FIRE_TEXTURE,
		Colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20) },
		Size = 0.45,
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(0.5, 1.5),
		Acceleration = Vector3.new(0, 5, 0),
		Rate = 22,
		Transparency = 0.25,
		Spread = 20,
	},
	Frost = {
		Texture = SPARK_TEXTURE,
		Colors = { Color3.fromRGB(230, 250, 255), Color3.fromRGB(120, 200, 255) },
		Size = 0.3,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(0.2, 0.6),
		Acceleration = Vector3.new(0, -1.5, 0),
		Rate = 14,
		Transparency = 0.1,
		Spread = 180,
	},
	Shock = {
		Texture = SPARK_TEXTURE,
		Colors = { Color3.fromRGB(255, 255, 200), Color3.fromRGB(255, 220, 40) },
		Size = 0.28,
		Lifetime = NumberRange.new(0.1, 0.25),
		Speed = NumberRange.new(4, 7),
		Acceleration = Vector3.zero,
		Rate = 26,
		Transparency = 0,
		Spread = 180,
	},
	Poison = {
		Texture = SMOKE_TEXTURE,
		Colors = { Color3.fromRGB(170, 255, 110), Color3.fromRGB(60, 140, 40) },
		Size = 0.5,
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(0.2, 0.5),
		Acceleration = Vector3.new(0, -1, 0),
		Rate = 10,
		Transparency = 0.45,
		Spread = 60,
	},
}

-- Particles from the whole volume of `part`. Rate is per item, so a bigger
-- enchantment (higher potency) is a little busier.
local function particles(part: BasePart, element: string, strength: number)
	local style = PARTICLES[element]
	if not style then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Enchantment"
	emitter.Texture = style.Texture
	emitter.Color = ColorSequence.new(style.Colors[1], style.Colors[2])
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, style.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, style.Transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = style.Lifetime
	emitter.Speed = style.Speed
	emitter.SpreadAngle = Vector2.new(style.Spread, style.Spread)
	emitter.Acceleration = style.Acceleration
	emitter.Rate = style.Rate * (0.6 + 0.4 * strength)
	emitter.LightEmission = if element == "Poison" then 0.2 else 1
	emitter.LockedToPart = element == "Shock"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Parent = part
end

-- Recolours an item's glowing trim, lights its gem and adds particles to its
-- biggest piece (the blade, head, staff or chest).
local function enchant(parts: { BasePart }, gem, main: BasePart?)
	local color = GemConfig.ElementColors[gem.Element]
	local strength = math.clamp(GemConfig.potency(gem) / 150, 0, 1)
	local biggest, biggestSize = nil, 0
	for _, part in parts do
		if part.Name == "SocketedGem" then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 5 + strength * 5
			light.Brightness = 1.2
			light.Shadows = false
			light.Parent = part
		elseif part.Material == Enum.Material.Neon then
			part.Color = color
		elseif part.Name == "Armor" and part.Color == ArmorKits.Brass then
			-- Plate armor's brass trim glows with the gem's element.
			part.Material = Enum.Material.Neon
			part.Color = color
			part.CastShadow = false
		elseif part.Transparency < 1 then
			local size = part.Size.X * part.Size.Y * part.Size.Z
			if size > biggestSize then
				biggest, biggestSize = part, size
			end
		end
	end
	if biggest and gem.Element == "Frost" then
		-- Rime creeps over a frost-enchanted item.
		biggest.Color = biggest.Color:Lerp(Color3.fromRGB(190, 230, 255), 0.45)
	end
	local target = main or biggest
	if target then
		particles(target, gem.Element, strength)
	end
end

-- Where a hand grips: the hand itself on R15, the bottom of the arm on R6.
local function gripPoint(character: Model, side: string): (BasePart?, CFrame)
	local hand = character:FindFirstChild(side .. "Hand") :: BasePart?
	if hand then
		return hand, CFrame.new(0, -0.1, 0)
	end
	local arm = character:FindFirstChild(side .. " Arm") :: BasePart?
	return arm, CFrame.new(0, -0.9, 0)
end

-- Grip points as tiny invisible parts, so weapon code can treat them like hands.
local function gripAnchor(folder: Instance, character: Model, side: string): BasePart?
	local part, offset = gripPoint(character, side)
	if not part then
		return nil
	end
	local anchor = piece(folder, part, offset, Vector3.one * 0.05, Color3.new(), Enum.Material.SmoothPlastic)
	anchor.Name = side .. "Grip"
	anchor.Transparency = 1
	return anchor
end

-- Hats, hair and face accessories would poke through helms and hoods.
local HEAD_ATTACHMENTS = { "HatAttachment", "HairAttachment", "FaceFrontAttachment", "FaceCenterAttachment" }
local function removeHeadwear(character: Model)
	for _, accessory in character:GetChildren() do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			for _, name in HEAD_ATTACHMENTS do
				if handle and handle:FindFirstChild(name) then
					accessory:Destroy()
					break
				end
			end
		end
	end
end

-- Ratings drive the avatar: Speed sets walk speed and Health sets max
-- health, so gear and gems are felt straight away.
local function applyStats(character: Model, loadout)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local ratings = Classes.ratings(loadout)
	-- Agile armor (Fleet) adds a little on top.
	local extra = Classes.effects(loadout).SpeedAdd or 0
	humanoid.WalkSpeed = Classes.walkSpeed(ratings.Speed.Base + ratings.Speed.Bonus) + extra
	local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	humanoid.MaxHealth = Classes.maxHealth(ratings.Health.Base + ratings.Health.Bonus)
	humanoid.Health = humanoid.MaxHealth * fraction
end

-- Builds the gear folder for a loadout on a character (not parented yet).
-- `only` limits it to one slot, for item previews.
local function dress(character: Model, loadout, cosmetics, userId: number, only: string?): Folder?
	local class = Classes.get(loadout.Class)
	local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
	local armor = Classes.armor(loadout.Class, loadout.Armor)
	if not class or not weapon or not armor then
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	-- A trim (cosmetic) recolours the class glow.
	local trim = cosmetics and Cosmetics.get(cosmetics.Trim)
	local accent = if trim then trim.Color else class.Color

	removeHeadwear(character)
	local armorSlots = {}
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots" } do
		local gear = (not only or only == slot)
			and Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, loadout[slot])
		if gear then
			local component = Instance.new("Folder")
			component.Name = slot
			component.Parent = folder
			armorSlots[slot] = component
			ArmorKits.build(
				component,
				character,
				gear.Look,
				accent,
				loadout[slot .. "Quality"],
				if GearRolls.get(loadout, slot)
					then GearRolls.appearance(GearRolls.get(loadout, slot))
					else SuitTraits.forSuit(userId, gear.Id),
				slot,
				gear.Id
			)
			local gem = loadout[slot .. "Gem"]
			if gem and slot ~= "Armor" then
				local parts = {}
				for _, part in component:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(parts, part)
					end
				end
				enchant(parts, gem, nil)
			end
		end
	end
	if trim then
		-- A trim (cosmetic) lights plate armor's brass bands in its colour.
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Armor" and part.Color == ArmorKits.Brass then
				part.Material = Enum.Material.Neon
				part.Color = accent
				part.CastShadow = false
			end
		end
	end
	-- An armor gem glows at the centre of the chest.
	local torso = bodyPart(character, "UpperTorso", "Torso")
	if torso and loadout.ArmorGem and (not only or only == "Armor") then
		gemSocket(
			folder,
			torso,
			CFrame.new(),
			Vector3.new(0, torso.Size.Y * 0.12, -torso.Size.Z * 0.5 - 0.2),
			loadout.ArmorGem,
			0.3
		)
	end
	local armorParts = {}
	for _, part in (armorSlots.Armor or folder):GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(armorParts, part)
		end
	end

	-- A back piece (cosmetic), worn behind the armor.
	local back = cosmetics and Cosmetics.get(cosmetics.Back)
	local build = back and back.Look and BACKS[back.Look]
	if torso and build and not only then
		local mount = CFrame.new(0, 0, torso.Size.Z / 2 + 0.55) * CFrame.Angles(0, math.rad(180), 0)
		build(folder, torso, mount, back.Color, accent)
	end

	-- The weapon gets its own folder, so its parts are easy to tell apart.
	local weaponFolder = Instance.new("Folder")
	weaponFolder.Name = "Weapon"
	weaponFolder.Parent = folder
	local right = gripAnchor(weaponFolder, character, "Right")
	local left = gripAnchor(weaponFolder, character, "Left")
	local buildWeapon = WEAPONS[weapon.Look]
	if only and only ~= "Weapon" then
		right, left = nil, nil
	end
	if weapon.Look == "FrontierSword" and right then
		local roll = GearRolls.get(loadout, "Weapon")
		local rarity = if roll then roll.Rarity else weapon.RarityTier or 1
		local finish = if roll then GearRolls.appearance(roll).FinishColor else STEEL
		local mount = UPRIGHT * CFrame.Angles(0, 0, math.rad(-12))
		FrontierAssets.sword(weaponFolder, right, mount, rarity, accent, finish)
		gemSocket(weaponFolder, right, mount, Vector3.new(0, 0.39, -0.18), loadout.WeaponGem, 0.17)
	elseif weapon.Look == "CleanSidearm" and right then
		local roll = GearRolls.get(loadout, "Weapon")
		local rarity = if roll then roll.Rarity else weapon.RarityTier or 1
		local finish = if roll then GearRolls.appearance(roll).FinishColor else STEEL
		FrontierAssets.sidearm(weaponFolder, right, HELD_FORWARD, rarity, accent, finish)
		gemSocket(weaponFolder, right, HELD_FORWARD, Vector3.new(0.15, 0.12, 0.23), loadout.WeaponGem, 0.15)
	elseif buildWeapon and right and left then
		buildWeapon(weaponFolder, character, right, left, accent, loadout.WeaponGem)
	end
	local shieldItem = (not only or only == "Shield") and Classes.gear(loadout.Class, "Shields", loadout.Shield)
	if shieldItem then
		local component = Instance.new("Folder")
		component.Name = "Shield"
		component.Parent = folder
		local shieldRoll = GearRolls.get(loadout, "Shield")
		local traits = if shieldRoll
			then GearRolls.appearance(shieldRoll)
			else SuitTraits.forSuit(userId, shieldItem.Id)
		frontierShield(
			component,
			character,
			accent,
			loadout.ShieldGem,
			ArmorKits.tint(traits.FinishColor, loadout.ShieldQuality),
			if shieldRoll then shieldRoll.Rarity else shieldItem.RarityTier or 1,
			shieldItem.ArmorFamily
		)
		if loadout.ShieldGem then
			local parts = {}
			for _, part in component:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(parts, part)
				end
			end
			enchant(parts, loadout.ShieldGem, nil)
		end
	end
	local weaponRoll = GearRolls.get(loadout, "Weapon")
	if weaponRoll and right and weapon.Look ~= "FrontierSword" then
		local appearance = GearRolls.appearance(weaponRoll)
		for _, part in weaponFolder:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Gear" and part.Material == Enum.Material.SmoothPlastic then
				part.Color = if weapon.Look == "CleanSidearm"
					then part.Color:Lerp(appearance.FinishColor, 0.18)
					else appearance.FinishColor
			end
		end
		local variant = if weapon.Look == "CleanSidearm" then 0 else weaponRoll.Variant
		if variant == 1 then
			piece(
				weaponFolder,
				right,
				HELD_FORWARD * CFrame.new(0, 0.45, 0.72),
				Vector3.new(0.3, 0.62, 0.15),
				GUNMETAL,
				Enum.Material.SmoothPlastic
			)
		elseif variant == 2 then
			for _, side in { -1, 1 } do
				piece(
					weaponFolder,
					right,
					HELD_FORWARD * CFrame.new(side * 0.22, 0.5, 0.34),
					Vector3.new(0.12, 0.8, 0.18),
					GUNMETAL,
					Enum.Material.SmoothPlastic
				)
			end
		elseif variant == 3 then
			piece(
				weaponFolder,
				right,
				HELD_FORWARD * CFrame.new(0, 0.15, -0.24),
				Vector3.new(0.42, 0.45, 0.25),
				GUNMETAL,
				Enum.Material.SmoothPlastic
			)
		else
			piece(
				weaponFolder,
				right,
				HELD_FORWARD * CFrame.new(0, 1.35, 0.34),
				Vector3.new(0.24, 0.44, 0.24),
				GUNMETAL,
				Enum.Material.SmoothPlastic
			)
		end
	end
	-- Crafted quality shows on the weapon's metal.
	if (loadout.WeaponQuality or 1) > 1 then
		for _, part in weaponFolder:GetDescendants() do
			if
				part:IsA("BasePart")
				and (part.Material == Enum.Material.Metal or part.Material == Enum.Material.DiamondPlate)
			then
				part.Color = ArmorKits.tint(part.Color, loadout.WeaponQuality, part.Color == IRON)
			end
		end
	end

	-- Enchanted gear takes on its gem's element.
	if loadout.ArmorGem and (not only or only == "Armor") then
		enchant(armorParts, loadout.ArmorGem, torso)
	end
	if loadout.WeaponGem then
		local weaponParts = {}
		for _, part in weaponFolder:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(weaponParts, part)
			end
		end
		enchant(weaponParts, loadout.WeaponGem, nil)
	end
	return folder
end

function Equipment.apply(player: Player)
	local character = player.Character
	local loadout = PlayerData.character(player)
	if not character or not loadout then
		return
	end
	local existing = character:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local profile = PlayerData.get(player)
	local folder = dress(character, loadout, profile and profile.Cosmetics, player.UserId)
	if not folder then
		return
	end
	folder.Parent = character
	applyStats(character, loadout)
end

-- Item previews ----------------------------------------------------------------------------
-- Spare equipment is shown in the Armory as the real 3D item: each one is
-- built on a plain mannequin by the same code that dresses players, then its
-- parts are stored (relative to the mannequin) in a hidden ScreenGui in the
-- owner's PlayerGui, which only that player receives.
local PREVIEW_GUI = "GearPreviews"
local mannequinTemplate: Model? = nil
local building: { [Player]: boolean } = {}

local function mannequin(): Model?
	if not mannequinTemplate then
		local ok, rig = pcall(function()
			return Players:CreateHumanoidModelFromDescription(
				Instance.new("HumanoidDescription"),
				Enum.HumanoidRigType.R15
			)
		end)
		if not ok or not rig then
			return nil
		end
		rig.Name = "PreviewMannequin"
		mannequinTemplate = rig
	end
	local rig = (mannequinTemplate :: Model):Clone()
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = true
	end
	-- Far above the moon base, where the joints settle the limbs into place.
	rig:PivotTo(CFrame.new(0, 5000, 0))
	rig.Parent = workspace
	return rig
end

-- What a preview depends on; it's rebuilt only when this changes.
local function previewKey(loadout, slot: string, id: string, quality: number): string
	local roll = GearRolls.get(loadout, slot, id)
	local gem = loadout.ItemGems and loadout.ItemGems[slot] and loadout.ItemGems[slot][id]
	return table.concat({
		tostring(quality),
		if roll then string.format("%d-%d-%d-%d", roll.Rarity, roll.Finish, roll.Helmet, roll.Variant) else "-",
		if gem then gem.Element .. tostring(gem.Id) else "-",
	}, "|")
end

-- Builds previews for every owned item not being worn. Returns true when
-- they're all up to date.
function Equipment.previews(player: Player): boolean
	local profile = PlayerData.get(player)
	local loadout = PlayerData.character(player)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not profile or not loadout or not playerGui or building[player] then
		return false
	end
	local store = playerGui:FindFirstChild(PREVIEW_GUI)
	if not store then
		local gui = Instance.new("ScreenGui")
		gui.Name = PREVIEW_GUI
		gui.Enabled = false
		gui.ResetOnSpawn = false
		gui.Parent = playerGui
		store = gui
	end
	local wanted = {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		for id, quality in profile.Owned[kind] or {} do
			if id ~= loadout[slot] and Classes.gear(loadout.Class, kind, id) then
				wanted[slot .. "|" .. id] = { Slot = slot, Id = id, Quality = quality }
			end
		end
	end
	for _, child in (store :: Instance):GetChildren() do
		local item = wanted[child.Name]
		if item and child:GetAttribute("Key") == previewKey(loadout, item.Slot, item.Id, item.Quality) then
			wanted[child.Name] = nil
		else
			child:Destroy()
		end
	end
	if next(wanted) == nil then
		return true
	end
	building[player] = true
	local rig = mannequin()
	if not rig then
		building[player] = nil
		return false
	end
	task.wait()
	local origin = rig:GetPivot()
	for name, item in wanted do
		local trial = table.clone(loadout)
		local gems = loadout.ItemGems and loadout.ItemGems[item.Slot]
		trial[item.Slot] = item.Id
		trial[item.Slot .. "Quality"] = item.Quality
		trial[item.Slot .. "Gem"] = gems and gems[item.Id]
		local ok, folder = pcall(dress, rig, trial, nil, player.UserId, item.Slot)
		local source = ok and folder and folder:FindFirstChild(item.Slot)
		if source then
			local preview = Instance.new("Folder")
			preview.Name = name
			preview:SetAttribute("Slot", item.Slot)
			preview:SetAttribute("Key", previewKey(loadout, item.Slot, item.Id, item.Quality))
			local parts = {}
			for _, part in source:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					table.insert(parts, part)
				end
			end
			for _, part in parts do
				-- Remember which body part it sat on (the thumbnail filter uses it).
				local weld = part:FindFirstChildOfClass("WeldConstraint")
				local anchor = weld and weld.Part0
				part:SetAttribute("Anchor", if anchor then anchor.Name else "")
				for _, child in part:GetChildren() do
					if child:IsA("JointInstance") or child:IsA("WeldConstraint") then
						child:Destroy()
					end
				end
				part.Anchored = true
				part.CFrame = origin:ToObjectSpace(part.CFrame)
				part.Parent = preview
			end
			preview.Parent = store
		end
		if ok and folder then
			folder:Destroy()
		end
	end
	rig:Destroy()
	building[player] = nil
	return true
end

local function watch(player: Player)
	player.CharacterAppearanceLoaded:Connect(function()
		-- The profile may still be loading on the first spawn.
		for _ = 1, 20 do
			if PlayerData.character(player) then
				break
			end
			task.wait(0.5)
		end
		Equipment.apply(player)
	end)
end

function Equipment.start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
		task.spawn(Equipment.apply, player)
	end
	PlayerData.CharacterChanged:Connect(Equipment.apply)
	Players.PlayerRemoving:Connect(function(player)
		building[player] = nil
	end)
	-- The Armory asks for previews when it opens and when the gear changes.
	Shop.register("GearPreviews", function(player)
		local done = Equipment.previews(player)
		return Shop.reply(true, "", { Done = done })
	end)
end

return Equipment
