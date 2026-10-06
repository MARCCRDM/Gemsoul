--[[
	Puts each player's class armor and weapon on their avatar, built from
	parts welded to the body so every player sees them. Works with R15 and
	R6 avatars; sizes follow the avatar's own body parts.

	Rebuilt on every spawn and whenever the class, gear or socketed gem
	changes, and sets walk speed and max health from the character's
	ratings. Socketed gems glow in their own colour: on the weapon, and at
	the centre of the chest for an armor gem.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Classes = require(ReplicatedStorage.Shared.Classes)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Tags = require(ReplicatedStorage.Shared.Tags)
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

-- A socketed gem: a cut stone set in a metal bezel with four prongs, facing
-- out of the socket (the mount's -Z). A glowing core (SocketedGem, which
-- carries the gem's light) sits under a glassy faceted crown and a flat
-- table facet, so it reads as a gem rather than a glowing block. Ultra
-- Rare two-tone shades show their second colour in the crown; prismatic
-- stones glow mint-white at the core.
local SETTING = Color3.fromRGB(176, 150, 96)
local function gemSocket(folder: Instance, anchor: BasePart, mount: CFrame, at: Vector3, gem, size: number)
	local base = mount * CFrame.new(at)
	-- The bezel: a short metal ring the stone sits in.
	local bezel = piece(
		folder,
		anchor,
		base * CFrame.new(0, 0, size * 0.14) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(size * 0.32, size * 1.42, size * 1.42),
		if gem then SETTING else IRON,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	bezel.Name = "GemSetting"
	if not gem then
		-- An empty socket: the bare setting with a dark hollow.
		local hollow = piece(
			folder,
			anchor,
			base * CFrame.new(0, 0, size * 0.02) * CFrame.Angles(0, math.rad(90), 0),
			Vector3.new(size * 0.1, size * 1.05, size * 1.05),
			Color3.fromRGB(24, 26, 32),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		hollow.Name = "GemSetting"
		return
	end
	local shade = GemConfig.shade(gem)
	local color = if shade.Prismatic then Color3.fromRGB(120, 255, 200) else shade.Color
	local crownColor = shade.Color2 or shade.Color
	-- Four prongs gripping the stone's four points.
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		local prong = piece(
			folder,
			anchor,
			base
				* CFrame.new(math.cos(angle) * size * 0.5, math.sin(angle) * size * 0.5, -size * 0.26)
				* CFrame.Angles(0, 0, angle),
			Vector3.new(size * 0.26, size * 0.12, size * 0.12),
			SETTING,
			Enum.Material.Metal
		)
		prong.Name = "GemSetting"
	end
	-- The glowing heart of the stone.
	local core = neon(
		folder,
		anchor,
		base * CFrame.new(0, 0, -size * 0.05) * CFrame.Angles(0, 0, math.rad(45)),
		Vector3.new(size * 0.62, size * 0.62, size * 0.4),
		color
	)
	core.Name = "SocketedGem"
	-- The crown: a faceted glass shell over the core, turned so its edges
	-- catch the light.
	local crown = piece(
		folder,
		anchor,
		base * CFrame.new(0, 0, -size * 0.12) * CFrame.Angles(math.rad(10), math.rad(10), math.rad(45)),
		Vector3.new(size * 0.78, size * 0.78, size * 0.5),
		crownColor,
		Enum.Material.Glass
	)
	crown.Name = "GemFacet"
	crown.Transparency = 0.35
	crown.Reflectance = 0.3
	crown.CastShadow = false
	-- The table: the flat top facet, a lighter flash of the colour.
	local table_ = piece(
		folder,
		anchor,
		base * CFrame.new(0, 0, -size * 0.38) * CFrame.Angles(0, 0, math.rad(45)),
		Vector3.new(size * 0.34, size * 0.34, size * 0.05),
		shade.Color:Lerp(Color3.new(1, 1, 1), 0.6),
		Enum.Material.Glass
	)
	table_.Name = "GemFacet"
	table_.Transparency = 0.1
	table_.Reflectance = 0.4
	table_.CastShadow = false
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
-- A sword gripped in the fist, blade out past the thumb at right angles to
-- the forearm (tipped 30 degrees down when the arm hangs), for bodies posed
-- by RivalPose (models with the FistGrip attribute): in its stance the
-- blade points up and out at its foe, upright behind the shield on guard,
-- back over the shoulder winding up, and at the foe as a blow lands.
-- (UPRIGHT lays the blade back along the forearm, which on a bent arm sticks
-- it out sideways or behind.)
local FIST_GRIP = CFrame.Angles(math.rad(-120), 0, 0)

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
	-- The shield's face (its -Z: plates, rim and gem) turns out, away from
	-- the forearm. On a body posed by RivalPose (FistGrip) it's angled a
	-- further 20 degrees forward, so in its guard (forearm raised across the
	-- chest) the face meets its foe.
	local turn = if character:GetAttribute("FistGrip") then 110 else 90
	local mount = CFrame.new(-(arm.Size.X / 2 + 0.2), 0, 0) * CFrame.Angles(0, math.rad(turn), 0)
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
local function enchant(parts: { BasePart }, gem, main: BasePart?, quiet: boolean?)
	local color = GemConfig.ElementColors[gem.Element]
	local strength = GemConfig.strength(gem)
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
	if target and not quiet then
		particles(target, gem.Element, strength)
	end
end

-- Rarity shows at a glance: each piece glows in its element's colour (its
-- own gem's, else the weapon gem's, else the rarity's colour), and the rarer
-- it is the shinier the metal, the brighter the glow and the more sparkles.
--   reflectance, glow brightness, glow range, sparkles per second
local SHINE = {
	{ 0, 0, 0, 0 }, -- Common: plain
	{ 0.03, 0.25, 5, 0 }, -- Uncommon: glowing trims, a faint glow
	{ 0.06, 0.4, 6, 1 }, -- Rare
	{ 0.09, 0.6, 7, 2 }, -- Ultra Rare
	{ 0.12, 0.9, 9, 4 }, -- Legendary (kept soft: metal mirrors the sky)
}
local SHINY = {
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Plastic] = true,
	[Enum.Material.Foil] = true,
	[Enum.Material.Glass] = true,
}
local function rarityShine(component: Instance, rarity: number, color: Color3)
	local tier = math.clamp(math.floor(rarity or 1), 1, #SHINE)
	local spec = SHINE[tier]
	if tier <= 1 then
		return
	end
	local biggest, biggestSize = nil, 0
	for _, part in component:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "SocketedGem" then
			if part.Material == Enum.Material.Neon then
				part.Color = color -- trims glow in the element's colour
			elseif SHINY[part.Material] then
				part.Reflectance = math.max(part.Reflectance, spec[1])
			end
			local size = part.Size.X * part.Size.Y * part.Size.Z
			if size > biggestSize then
				biggest, biggestSize = part, size
			end
		end
	end
	if not biggest then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "RarityGlow"
	light.Color = color
	light.Brightness = spec[2]
	light.Range = spec[3]
	light.Shadows = false
	light.Parent = biggest
	if spec[4] > 0 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "RarityShine"
		sparkles.Texture = SPARK_TEXTURE
		sparkles.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.18 + tier * 0.03),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Transparency = NumberSequence.new(0.1, 1)
		sparkles.Lifetime = NumberRange.new(0.6, 1.2)
		sparkles.Speed = NumberRange.new(0.2, 0.8)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Rate = spec[4]
		sparkles.Shape = Enum.ParticleEmitterShape.Box
		sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		sparkles.Parent = biggest
	end
end

-- A gem in a piece of gear (armor, shield or weapon) enchants it with the
-- gem's element. Two layers:
--   * a Highlight outline around the piece in the element's colour, the
--     rarer the gem the bolder (faint at Common, solid at Legendary). Outline
--     only, no fill, so the armor keeps its own generated colours;
--   * the element's own effect pouring off its biggest plate:
--       Thermal    flames licking upward, embers, a flickering heat-glow
--       Cryo       a crust of ice crystals on the plate, falling snow and
--                  cold mist, a slow cold glow
--       Ion        crackling sparks and flashes, a strobing light
--       Corrosive  billowing clouds of green toxic gas, curling wisps and
--                  rising bubbles
--     busier and brighter up the tiers.
--   highlight fill transparency, highlight outline transparency, light
--   brightness, light range, particles per second, ice crystals (Cryo).
--   The light stays soft so it doesn't tint the armor's own colours.
local GEM_GLOW = {
	{ 1, 0.85, 0.35, 6, 4, 2 }, -- Common
	{ 1, 0.75, 0.5, 7, 6, 3 }, -- Uncommon
	{ 1, 0.6, 0.65, 8, 8, 4 }, -- Rare
	{ 1, 0.45, 0.8, 9, 11, 5 }, -- Ultra Rare
	{ 1, 0.3, 1, 10, 15, 6 }, -- Legendary
}
-- How each element's light moves: seconds per pulse, and how far it dims.
local GEM_PULSE = {
	Fire = { 0.16, 0.55 }, -- flicker
	Frost = { 1.6, 0.7 }, -- slow and cold
	Shock = { 0.07, 0.25 }, -- strobe
	Poison = { 1.0, 0.5 }, -- sickly throb
}
-- Each element's signature: what pours off enchanted armor.
local SIGNATURE: { [string]: { any } } = {
	Fire = {
		{
			Texture = FIRE_TEXTURE,
			Colors = { Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 50, 15) },
			Size = 0.9,
			Lifetime = NumberRange.new(0.3, 0.55),
			Speed = NumberRange.new(1, 2.5),
			Acceleration = Vector3.new(0, 8, 0),
			Spread = 20,
			Transparency = 0.1,
			Light = 1,
			Share = 1,
		},
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(255, 235, 150), Color3.fromRGB(255, 90, 30) },
			Size = 0.2,
			Lifetime = NumberRange.new(0.8, 1.5),
			Speed = NumberRange.new(1.5, 3.5),
			Acceleration = Vector3.new(0, 4, 0),
			Spread = 60,
			Transparency = 0,
			Light = 1,
			Share = 0.6,
		},
	},
	Frost = {
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(245, 253, 255), Color3.fromRGB(110, 190, 255) },
			Size = 0.3,
			Lifetime = NumberRange.new(1.2, 2),
			Speed = NumberRange.new(0.1, 0.4),
			Acceleration = Vector3.new(0, -2, 0),
			Spread = 180,
			Transparency = 0,
			Light = 1,
			Share = 1,
			Spin = true,
		},
		{
			Texture = SMOKE_TEXTURE,
			Colors = { Color3.fromRGB(220, 245, 255), Color3.fromRGB(140, 200, 255) },
			Size = 1.2,
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(0.1, 0.4),
			Acceleration = Vector3.new(0, -1.4, 0),
			Spread = 50,
			Transparency = 0.65,
			Light = 0.3,
			Share = 0.35,
		},
	},
	Shock = {
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(255, 255, 235), Color3.fromRGB(255, 215, 30) },
			Size = 0.35,
			Lifetime = NumberRange.new(0.05, 0.15),
			Speed = NumberRange.new(7, 12),
			Acceleration = Vector3.zero,
			Spread = 180,
			Transparency = 0,
			Light = 1,
			Share = 1.6,
			Locked = true,
		},
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(255, 255, 220), Color3.fromRGB(255, 235, 90) },
			Size = 0.8,
			Lifetime = NumberRange.new(0.04, 0.09),
			Speed = NumberRange.new(0),
			Acceleration = Vector3.zero,
			Spread = 0,
			Transparency = 0,
			Light = 1,
			Share = 0.45,
			Locked = true,
		},
	},
	Poison = {
		{
			-- Billowing clouds of toxic gas.
			Texture = SMOKE_TEXTURE,
			Colors = { Color3.fromRGB(170, 255, 90), Color3.fromRGB(40, 140, 40) },
			Size = 1.7,
			Lifetime = NumberRange.new(1.6, 2.6),
			Speed = NumberRange.new(0.3, 0.9),
			Acceleration = Vector3.new(0, 0.6, 0),
			Spread = 180,
			Transparency = 0.4,
			Light = 0.4,
			Share = 0.6,
			Spin = true,
		},
		{
			-- Wisps of gas curling off it.
			Texture = SMOKE_TEXTURE,
			Colors = { Color3.fromRGB(200, 255, 140), Color3.fromRGB(90, 200, 70) },
			Size = 0.7,
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(0.8, 1.6),
			Acceleration = Vector3.new(0, 1.5, 0),
			Spread = 70,
			Transparency = 0.3,
			Light = 0.6,
			Share = 0.6,
			Spin = true,
		},
		{
			-- Toxic bubbles rising through it.
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(210, 255, 150), Color3.fromRGB(70, 210, 80) },
			Size = 0.26,
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(0.3, 0.9),
			Acceleration = Vector3.new(0, 1.8, 0),
			Spread = 40,
			Transparency = 0.05,
			Light = 0.8,
			Share = 0.4,
		},
	},
}
local function gemTier(gem): number
	for index, tier in GemConfig.TierOrder do
		if tier == gem.Tier then
			return index
		end
	end
	return 1
end
-- Cryo: a crust of ice crystals jutting from the plate's top edge.
local function iceCrust(plate: BasePart, count: number, rng: Random)
	local half = plate.Size / 2
	for i = 1, count do
		local crystal = Instance.new("Part")
		crystal.Name = "GemIce"
		local height = 0.25 + rng:NextNumber() * 0.35
		crystal.Size = Vector3.new(0.12, height, 0.12)
		crystal.Material = Enum.Material.Glass
		crystal.Color = Color3.fromRGB(200, 235, 255)
		crystal.Transparency = 0.25
		crystal.Reflectance = 0.2
		crystal.CanCollide, crystal.CanQuery, crystal.CanTouch = false, false, false
		crystal.Massless, crystal.CastShadow = true, false
		local x = (i - (count + 1) / 2) / count * half.X * 1.6
		crystal.CFrame = plate.CFrame
			* CFrame.new(x, half.Y + height * 0.3, -half.Z * rng:NextNumber())
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.5, 0.5))
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = plate, crystal
		weld.Parent = crystal
		crystal.Parent = plate.Parent
	end
end
local function gemGlow(component: Instance, gem)
	local color = GemConfig.ElementColors[gem.Element]
	if not color then
		return
	end
	local tier = gemTier(gem)
	local spec = GEM_GLOW[tier]
	local plates = {}
	for _, part in component:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "SocketedGem" then
			if part.Material == Enum.Material.Neon then
				part.Color = color -- trims glow in the element's colour
			end
			table.insert(plates, part)
		end
	end
	if #plates == 0 then
		return
	end
	table.sort(plates, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	local biggest = plates[1]
	-- The highlight: brighter and bolder the rarer the gem.
	if component:IsA("Model") then
		local highlight = Instance.new("Highlight")
		highlight.Name = "GemHighlight"
		highlight.FillColor = color
		highlight.FillTransparency = spec[1]
		highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.25)
		highlight.OutlineTransparency = spec[2]
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = component
		CollectionService:AddTag(highlight, Tags.GemOutline)
	end
	-- The light, moving the element's way.
	local pulse = GEM_PULSE[gem.Element] or { 1, 0.5 }
	local light = Instance.new("PointLight")
	light.Name = "GemGlow"
	light.Color = color
	light.Brightness = spec[3]
	light.Range = spec[4]
	light.Shadows = false
	light.Parent = biggest
	TweenService:Create(
		light,
		TweenInfo.new(pulse[1], Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Brightness = spec[3] * pulse[2] }
	):Play()
	if gem.Element == "Frost" and component.Name ~= "Weapon" then
		iceCrust(biggest, spec[6], Random.new(#plates * 7 + tier))
	end
	-- The element's signature particles.
	for _, style in SIGNATURE[gem.Element] or {} do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "GemSignature"
		emitter.Texture = style.Texture
		emitter.Color = ColorSequence.new(style.Colors[1], style.Colors[2])
		emitter.LightEmission = style.Light
		local size = style.Size * (0.8 + tier * 0.1)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.4),
			NumberSequenceKeypoint.new(0.3, size),
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
		emitter.Rate = spec[5] * style.Share
		emitter.LockedToPart = style.Locked == true
		if style.Spin then
			emitter.RotSpeed = NumberRange.new(-120, 120)
			emitter.Rotation = NumberRange.new(0, 360)
		end
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.Parent = biggest
	end
end

-- Rare+ armor with Elemental Affinity Affixes gets a faint aura in its
-- affixes' element colours: a soft light and a few slow motes on its biggest
-- piece. Subtler than a socketed gem's enchantment.
local function affinityGlow(component: Instance, roll)
	local colors = {}
	for _, affix in roll and roll.Affixes or {} do
		local def = GemConfig.AffixById[affix.Id]
		if def then
			table.insert(colors, GemConfig.ElementColors[def.Element])
		end
	end
	if #colors == 0 then
		return
	end
	local biggest, biggestSize = nil, 0
	for _, part in component:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local size = part.Size.X * part.Size.Y * part.Size.Z
			if size > biggestSize then
				biggest, biggestSize = part, size
			end
		end
	end
	if not biggest then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "Affinity"
	light.Color = colors[1]
	light.Range = 3 + #colors
	light.Brightness = 0.5
	light.Shadows = false
	light.Parent = biggest
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new(if #colors == 1 then 0 else (i - 1) / (#colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Affinity"
	motes.Texture = SPARK_TEXTURE
	motes.Color = ColorSequence.new(keypoints)
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	motes.Lifetime = NumberRange.new(1, 1.6)
	motes.Speed = NumberRange.new(0.1, 0.3)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Rate = 1.5 + #colors
	motes.LightEmission = 1
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	motes.Parent = biggest
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
local function applyStats(character: Model, loadout, profile)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local ratings = Classes.ratings(loadout)
	-- Agile armor (Fleet) adds a little on top.
	local extra = Classes.effects(loadout).SpeedAdd or 0
	local augments = Tree.effects(profile)
	humanoid.WalkSpeed = (Classes.walkSpeed(ratings.Speed.Base + ratings.Speed.Bonus) + extra)
		* (1 + (augments.Mobility or 0))
	local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	humanoid.MaxHealth = Classes.maxHealth(ratings.Health.Base + ratings.Health.Bonus)
	humanoid.Health = humanoid.MaxHealth * fraction
end

-- Builds the gear folder for a loadout on a character (not parented yet).
-- `only` limits it to one slot, for item previews.
local function dress(character: Model, loadout, cosmetics, userId: number, only: string?): Folder?
	if not only then
		local weapon = Classes.weapon(loadout.Class, loadout.Weapon)
		character:SetAttribute("CombatWeaponType", weapon and weapon.WeaponType or "OneHanded")
		character:SetAttribute("WeaponBlock", weapon and weapon.WeaponBlock == true or false)
	end
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
			-- A Model (not a Folder) so it can carry its gem's Highlight.
			local component = Instance.new("Model")
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
			affinityGlow(component, GearRolls.get(loadout, slot))
			local gem = loadout[slot .. "Gem"]
			if gem and slot ~= "Armor" then
				local parts = {}
				for _, part in component:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(parts, part)
					end
				end
				enchant(parts, gem, nil, true)
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
	local weaponFolder = Instance.new("Model") -- a Model, to carry its gem's Highlight
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
		local mount = if character:GetAttribute("FistGrip")
			then FIST_GRIP
			else UPRIGHT * CFrame.Angles(0, 0, math.rad(-12))
		FrontierAssets.sword(weaponFolder, right, mount, rarity, accent, finish)
		gemSocket(weaponFolder, right, mount, Vector3.new(0, 0.39, -0.18), loadout.WeaponGem, 0.17)
	elseif weapon.Forge and right then
		-- A Forge weapon (Shared.WeaponForge): its own model, finer with rarity.
		local roll = GearRolls.get(loadout, "Weapon")
		local rarity = if roll then roll.Rarity else weapon.RarityTier or 1
		local finish = if roll then GearRolls.appearance(roll).FinishColor else STEEL
		local mount = if character:GetAttribute("FistGrip")
			then FIST_GRIP
			else UPRIGHT * CFrame.Angles(0, 0, math.rad(-12))
		FrontierAssets.forge(weapon.WeaponType, weaponFolder, right, mount, rarity, accent, finish)
		gemSocket(weaponFolder, right, mount, FrontierAssets.ForgeSockets[weapon.WeaponType], loadout.WeaponGem, 0.17)
		if weapon.WeaponType == "TwinBlades" and left then
			local offMount = if character:GetAttribute("FistGrip")
				then FIST_GRIP
				else UPRIGHT * CFrame.Angles(0, 0, math.rad(12))
			FrontierAssets.forge("TwinBlades", weaponFolder, left, offMount, rarity, accent, finish)
		end
	elseif weapon.Look == "CleanSidearm" and right then
		local roll = GearRolls.get(loadout, "Weapon")
		local rarity = if roll then roll.Rarity else weapon.RarityTier or 1
		local finish = if roll then GearRolls.appearance(roll).FinishColor else STEEL
		FrontierAssets.sidearm(weaponFolder, right, HELD_FORWARD, rarity, accent, finish)
		gemSocket(weaponFolder, right, HELD_FORWARD, Vector3.new(0.15, 0.12, 0.23), loadout.WeaponGem, 0.15)
	elseif buildWeapon and right and left then
		buildWeapon(weaponFolder, character, right, left, accent, loadout.WeaponGem)
	end
	-- A two-handed weapon leaves no hand for the shield (a preview of the
	-- shield on its own still shows it).
	local shieldItem = if only == "Shield"
		then Classes.gear(loadout.Class, "Shields", loadout.Shield)
		elseif not only then Classes.heldShield(loadout)
		else nil
	if shieldItem then
		local component = Instance.new("Model")
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
		affinityGlow(component, shieldRoll)
		if loadout.ShieldGem then
			local parts = {}
			for _, part in component:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(parts, part)
				end
			end
			enchant(parts, loadout.ShieldGem, nil, true)
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
		enchant(armorParts, loadout.ArmorGem, torso, true)
	end
	if loadout.WeaponGem then
		local weaponParts = {}
		for _, part in weaponFolder:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(weaponParts, part)
			end
		end
		enchant(weaponParts, loadout.WeaponGem, nil, true)
	end
	-- Rarity shine on every piece, in its element's colour.
	local mainGem = loadout.WeaponGem
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield", "Weapon" } do
		local component = if slot == "Weapon" then weaponFolder else folder:FindFirstChild(slot)
		if component and (not only or only == slot) then
			local roll = GearRolls.get(loadout, slot)
			local item = if slot == "Weapon"
				then weapon
				else Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, loadout[slot])
			local rarity = if roll then roll.Rarity else (item and item.RarityTier) or 1
			local gem = loadout[slot .. "Gem"] or mainGem
			local color = if gem
				then GemConfig.ElementColors[gem.Element]
				else GearRolls.Rarities[math.clamp(rarity, 1, #GearRolls.Rarities)].Color
			rarityShine(component, rarity, color)
		end
	end
	-- Every gem-enchanted piece (armor, shield and weapon) shows its gem's
	-- element, more the rarer the gem.
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield", "Weapon" } do
		local component = folder:FindFirstChild(slot)
		local gem = loadout[slot .. "Gem"]
		if component and gem and (not only or only == slot) then
			gemGlow(component, gem)
		end
	end
	-- A Prismatic roll (about 1 in 100): its coloured plates shimmer through
	-- every hue (the client's Effects cycle them).
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield", "Weapon" } do
		local component = folder:FindFirstChild(slot)
		local roll = GearRolls.get(loadout, slot)
		if component and roll and roll.Prismatic and (not only or only == slot) then
			for _, part in component:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 and part.Material ~= Enum.Material.Neon then
					local h, s, v = part.Color:ToHSV()
					if s > 0.2 and v > 0.25 then
						part:SetAttribute("PrismaticBase", Color3.fromHSV(h, s, v))
						CollectionService:AddTag(part, Tags.Prismatic)
					end
				end
			end
		end
	end
	return folder
end

-- Dresses any rig (the PvP Duelist) in a loadout, as a player would wear it.
function Equipment.dressModel(model: Model, loadout, seed: number): Folder?
	local folder = dress(model, loadout, nil, seed)
	if folder then
		folder.Parent = model
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
	-- Players' bodies are posed in a fight (Client BodyPoses), like the
	-- rival's, so they hold their weapon in the fist as it does: blade out
	-- past the thumb, which reads right through every swing, cast and guard.
	-- (Laid along the forearm it pointed backwards in a raised wind-up.)
	character:SetAttribute("FistGrip", true)
	local folder = dress(character, loadout, profile and profile.Cosmetics, player.UserId)
	if not folder then
		return
	end
	folder.Parent = character
	applyStats(character, loadout, profile)
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

-- The (hidden) folder in a player's PlayerGui that previews are built into.
local function previewStore(player: Player): Instance?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
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
	return store
end

-- Market previews ("Slot|M:...") belong to marketPreviews, not the bag.
local function isMarket(name: string): boolean
	return string.find(name, "|M:", 1, true) ~= nil
end

-- Dresses the mannequin in each wanted piece and keeps just that piece.
-- wanted[name] = { Slot, Id, Quality, Roll, Gem, Key }.
local function buildPreviews(player: Player, store: Instance, loadout, wanted)
	building[player] = true
	local rig = mannequin()
	if not rig then
		building[player] = nil
		return false
	end
	task.wait()
	local origin = rig:GetPivot()
	for name, item in wanted do
		local kind = Slots.Definitions[item.Slot].Kind
		local trial = table.clone(loadout)
		trial.GearRolls = table.clone(loadout.GearRolls or {})
		trial.GearRolls[kind] = table.clone(trial.GearRolls[kind] or {})
		trial.GearRolls[kind][item.Id] = item.Roll
		trial[item.Slot] = item.Id
		trial[item.Slot .. "Quality"] = item.Quality
		trial[item.Slot .. "Gem"] = item.Gem
		local ok, folder = pcall(dress, rig, trial, nil, player.UserId, item.Slot)
		local source = ok and folder and folder:FindFirstChild(item.Slot)
		if source then
			local preview = Instance.new("Folder")
			preview.Name = name
			preview:SetAttribute("Slot", item.Slot)
			preview:SetAttribute("Key", item.Key)
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

-- Builds previews for every owned item not being worn. Returns true when
-- they're all up to date.
function Equipment.previews(player: Player): boolean
	local profile = PlayerData.get(player)
	local loadout = PlayerData.character(player)
	local store = previewStore(player)
	if not profile or not loadout or not store or building[player] then
		return false
	end
	local wanted = {}
	for _, slot in Slots.Order do
		local kind = Slots.Definitions[slot].Kind
		for id, quality in profile.Owned[kind] or {} do
			if id ~= loadout[slot] and Classes.gear(loadout.Class, kind, id) then
				local gems = loadout.ItemGems and loadout.ItemGems[slot]
				wanted[slot .. "|" .. id] = {
					Slot = slot,
					Id = id,
					Quality = quality,
					Roll = GearRolls.get(loadout, slot, id),
					Gem = gems and gems[id],
					Key = previewKey(loadout, slot, id, quality),
				}
			end
		end
	end
	for _, child in (store :: Instance):GetChildren() do
		local item = wanted[child.Name]
		if item and child:GetAttribute("Key") == item.Key then
			wanted[child.Name] = nil
		elseif not isMarket(child.Name) then
			child:Destroy()
		end
	end
	if next(wanted) == nil then
		return true
	end
	return buildPreviews(player, store :: Instance, loadout, wanted)
end

-- Previews of gear that isn't yours (Market listings and offers), from the
-- piece itself: items[tag] = { Slot, Id, Quality, Roll, Gem }. Each is
-- built as "Slot|M:<tag>" (GearArt.draw(view, slot, "M:" .. tag)); market
-- previews no longer asked for are dropped.
function Equipment.marketPreviews(player: Player, items): (boolean, number?)
	local loadout = PlayerData.character(player)
	local store = previewStore(player)
	if not loadout or not store or building[player] then
		return false
	end
	local wanted = {}
	for tag, item in items do
		local kind = Slots.Definitions[item.Slot] and Slots.Definitions[item.Slot].Kind
		if kind and Classes.gear(loadout.Class, kind, item.Id) then
			local roll = item.Roll
			wanted[item.Slot .. "|M:" .. tag] = {
				Slot = item.Slot,
				Id = item.Id,
				Quality = item.Quality or 1,
				Roll = roll,
				Gem = item.Gem,
				Key = table.concat({
					tostring(item.Quality),
					if roll
						then string.format(
							"%s-%s-%s-%s",
							tostring(roll.Rarity),
							tostring(roll.Finish),
							tostring(roll.Helmet),
							tostring(roll.Variant)
						)
						else "-",
					if item.Gem then tostring(item.Gem.Id) else "-",
				}, "|"),
			}
		end
	end
	for _, child in (store :: Instance):GetChildren() do
		if isMarket(child.Name) then
			local item = wanted[child.Name]
			if item and child:GetAttribute("Key") == item.Key then
				wanted[child.Name] = nil
			else
				child:Destroy()
			end
		end
	end
	local count = 0
	for _ in wanted do
		count += 1
	end
	if count == 0 then
		return true, 0
	end
	local done = buildPreviews(player, store :: Instance, loadout, wanted)
	return done, if done then count else 0
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
