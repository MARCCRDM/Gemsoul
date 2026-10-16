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

local Classes = require(ReplicatedStorage.Shared.Classes)
local Tree = require(ReplicatedStorage.Shared.AugmentTree)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
local Tags = require(ReplicatedStorage.Shared.Tags)
local Cosmetics = require(ReplicatedStorage.Shared.Cosmetics)
local PickaxeLooks = require(ReplicatedStorage.Shared.PickaxeLooks)
local ArmorKits = require(script.Parent.ArmorKits)
local HelmetLooks = require(script.Parent.HelmetLooks)
local FrontierAssets = require(script.Parent.FrontierAssets)
local SuitTraits = require(ReplicatedStorage.Shared.SuitTraits)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local GearRolls = require(ReplicatedStorage.Shared.GearRolls)
local PvPRules = require(ReplicatedStorage.Shared.PvPRules)
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
	-- further 20 degrees forward and stood on end across the forearm, so in
	-- its guard (forearm level across the chest) the shield stands upright
	-- in front of the body with its face to the foe, as your own does in
	-- first person.
	local fist = character:GetAttribute("FistGrip") == true
	local mount = CFrame.new(-(arm.Size.X / 2 + (if fist then 0.2 else 0.1)), 0, 0)
		* CFrame.Angles(0, math.rad(if fist then 110 else 90), 0)
		* CFrame.Angles(0, 0, if fist then math.rad(-90) else 0)
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

-- Glowing trim (a cosmetic's seams, a blade's edge) is made of real parts:
-- thin neon strips set into the plate, welded where the plate is. They hide
-- behind the armour in front of them, as the armour does, and show the same
-- in the world, first person, the Inventory and the Store. (They were
-- SelectionBoxes, which Roblox draws as all twelve edges of the box, through
-- whatever is in front, so a suit read as a tangle of wireframe; and a
-- ViewportFrame doesn't draw them at all, so previews lost them.)
-- A palette's SeamFx animates them on every client (SeamVisibility):
-- "Pulse" breathes, "Shift" swings between the seam colour and the glow,
-- "Flicker" crackles like a live wire, "Rainbow" runs through every hue.

-- The parts of a set gem (gemSocket and its element's crystals): suits,
-- skins and rarity shine leave them as they are.
local GEM_PARTS = { SocketedGem = true, GemSetting = true, GemFacet = true, GemIce = true }

-- What a gear part hangs on: the body part (or a weapon's grip) at the end
-- of its welds.
local function anchorOf(part: BasePart, container: Instance): BasePart?
	local current = part
	for _ = 1, 6 do
		local weld = current:FindFirstChildOfClass("WeldConstraint")
		local next0 = weld and weld.Part0
		if not next0 then
			return nil
		end
		if not next0:IsDescendantOf(container) or next0.Name == "RightGrip" or next0.Name == "LeftGrip" then
			return next0
		end
		current = next0
	end
	return nil
end

-- Each plate's strips share a seed, so an animated frame moves as one.
local seamSeed = 0
local function seamStrip(
	plate: BasePart,
	anchor: BasePart,
	local_: CFrame,
	size: Vector3,
	color: Color3,
	palette,
	seed: number?
)
	local strip = piece(
		plate.Parent :: Instance,
		anchor,
		anchor.CFrame:ToObjectSpace(plate.CFrame * local_),
		size,
		color,
		Enum.Material.Neon
	)
	strip.Name = "SkinSeam"
	strip.CastShadow = false
	-- (SeamA is the seam's own colour, which a client that animated it goes
	-- back to when it's restyled to a still one.)
	strip:SetAttribute("SeamFx", palette and palette.SeamFx or nil)
	strip:SetAttribute("SeamA", color)
	strip:SetAttribute("SeamB", if palette and palette.SeamFx then palette.Glow else nil)
	strip:SetAttribute("SeamSeed", seed or seamSeed)
	CollectionService:AddTag(strip, Tags.SkinSeam)
	return strip
end

local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
-- A size with `runs`, `across` and `n` (the three axes, 1-3) set.
local function sized(runs: number, length: number, across: number, width: number, n: number, depth: number): Vector3
	local v = { 0, 0, 0 }
	v[runs], v[across], v[n] = length, width, depth
	return Vector3.new(v[1], v[2], v[3])
end

-- A plate's outward face: on a thin plate its broad side facing away from
-- what it's worn on, on a block whichever face that direction leaves by.
-- Returns the face's axis (1-3) and side (1 or -1), or nil for no face.
local function outwardFace(plate: BasePart, anchor: BasePart?): (number, number)
	local dims = { plate.Size.X, plate.Size.Y, plate.Size.Z }
	local from = if anchor then plate.CFrame.Position - anchor.CFrame.Position else Vector3.zero
	if from.Magnitude < 0.05 and anchor then
		from = anchor.CFrame.LookVector -- (centred on it: its front)
	end
	local out = plate.CFrame:VectorToObjectSpace(from)
	local comps = { out.X, out.Y, out.Z }
	local thin = 1
	for i = 2, 3 do
		if dims[i] < dims[thin] then
			thin = i
		end
	end
	local others = math.huge
	for i = 1, 3 do
		if i ~= thin then
			others = math.min(others, dims[i])
		end
	end
	local axis = thin
	if dims[thin] >= 0.6 * others then
		local best = -1
		for i = 1, 3 do
			local score = math.abs(comps[i]) / math.max(dims[i] / 2, 0.01)
			if score > best then
				axis, best = i, score
			end
		end
	end
	return axis, if comps[axis] < 0 then -1 else 1
end

-- Neon trim round a plate's outward face (both broad faces, `twoSided`, for
-- a blade): four strips just inside the face's edges, standing a little
-- proud of it. Skipped on a face too small to frame. Returns how many
-- strips, and the strips.
local function inlay(plate: BasePart, container: Instance, color: Color3, width: number, palette, twoSided: boolean?)
	local anchor = anchorOf(plate, container)
	local strips: { BasePart } = {}
	if not anchor then
		return 0, strips
	end
	local n, side = outwardFace(plate, anchor)
	local dims = { plate.Size.X, plate.Size.Y, plate.Size.Z }
	local a, b = n % 3 + 1, (n + 1) % 3 + 1
	local w = math.clamp(width * 1.6, 0.035, 0.06)
	local deep = w * 0.6
	local made = 0
	seamSeed = (seamSeed + 1) % 17
	if math.min(dims[a], dims[b]) < w * 3 + 0.08 then
		-- Too narrow to frame: one glowing line down the middle of it, if
		-- it's long enough to carry one.
		local wide = dims[a] >= dims[b]
		local runs, across = if wide then a else b, if wide then b else a
		if dims[runs] < 0.3 or dims[across] < w * 1.5 then
			return 0, strips
		end
		for _, s in if twoSided then { side, -side } else { side } do
			local at = AXES[n] * s * (dims[n] / 2 + deep * 0.3)
			table.insert(
				strips,
				seamStrip(
					plate,
					anchor,
					CFrame.new(at),
					sized(runs, dims[runs] * 0.8, across, w, n, deep),
					color,
					palette
				)
			)
			made += 1
		end
		return made, strips
	end
	for _, s in if twoSided then { side, -side } else { side } do
		local lift = AXES[n] * s * (dims[n] / 2 + deep * 0.3)
		for _, pair in { { a, b }, { b, a } } do
			local runs, across = pair[1], pair[2]
			-- The long pair runs the full length; the short pair fits between.
			local long = dims[runs] >= dims[across]
			local length = if long then dims[runs] else dims[runs] - 2 * w
			for _, edge in { -1, 1 } do
				local at = lift + AXES[across] * edge * (dims[across] / 2 - w / 2)
				table.insert(
					strips,
					seamStrip(plate, anchor, CFrame.new(at), sized(runs, length, across, w, n, deep), color, palette)
				)
				made += 1
			end
		end
	end
	return made, strips
end

-- A blade's glowing edge: a strip down each of its long narrow sides (its
-- cutting edges), wrapping the edge a little proud of it, both faces.
local function edgeLines(blade: BasePart, container: Instance, color: Color3, width: number, palette)
	local anchor = anchorOf(blade, container)
	if not anchor then
		return
	end
	local dims = { blade.Size.X, blade.Size.Y, blade.Size.Z }
	local order = { 1, 2, 3 }
	table.sort(order, function(i, j)
		return dims[i] > dims[j]
	end)
	local runs, across, through = order[1], order[2], order[3]
	local w = math.clamp(width * 1.4, 0.04, 0.07)
	seamSeed = (seamSeed + 1) % 17
	for _, edge in { -1, 1 } do
		local at = AXES[across] * edge * (dims[across] / 2 + w * 0.2)
		local size = sized(runs, dims[runs] * 0.97, across, w, through, dims[through] + w * 0.5)
		seamStrip(blade, anchor, CFrame.new(at), size, color, palette)
	end
end

-- A palette's seam colour and width (Cosmetics.Palette: SeamColor, SeamWidth).
local function seamStyle(palette): (Color3, number)
	return palette.SeamColor or palette.Glow, palette.SeamWidth or 0.025
end

-- Weapon skins (cosmetics): restyle whatever weapon is held, after its
-- rarity, quality and gem have had their say.
local SKINS = {}

SKINS.Crusader = function(weaponFolder: Instance, color: Color3)
	local gold = Color3.fromRGB(226, 172, 58)
	local obsidian = Color3.fromRGB(20, 18, 26)
	local biggest, biggestSize = nil, 0
	for _, part in weaponFolder:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency >= 1 or GEM_PARTS[part.Name] then
			continue
		end
		CollectionService:RemoveTag(part, Tags.Prismatic)
		part:SetAttribute("PrismaticBase", nil) -- (or a copy of it would shimmer: LiveLooks)
		local _, _, value = part.Color:ToHSV()
		if part.Material == Enum.Material.Neon then
			part.Color = color -- white-hot edges
		elseif value < 0.45 or part.Material == Enum.Material.Wood or part.Material == Enum.Material.Leather then
			part.Color, part.Material, part.Reflectance = obsidian, Enum.Material.SmoothPlastic, 0.2
		else
			part.Color, part.Material, part.Reflectance = gold, Enum.Material.Foil, 0.25
		end
		local size = part.Size.X * part.Size.Y * part.Size.Z
		if size > biggestSize then
			biggest, biggestSize = part, size
		end
	end
	if not biggest then
		return
	end
	-- A gold edge round the blade that burns to crusader red and back (the
	-- Crusader Plate suit's seams).
	edgeLines(
		biggest,
		weaponFolder,
		Color3.fromRGB(255, 184, 40),
		0.045,
		{ SeamFx = "Shift", Glow = Color3.fromRGB(230, 40, 56) }
	)
	-- Sparks drifting off the blade, a warm glow, and a gold trail along its
	-- length that streaks through every swing.
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "SkinSparks"
	sparks.Color = ColorSequence.new(color, gold)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Rate = 14
	sparks.Speed = NumberRange.new(0.5, 1.5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, 1.5, 0)
	sparks.Parent = biggest
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = color, 6, 0.8, false
	light.Parent = biggest
	local size = biggest.Size
	local axis = if size.Y >= size.X and size.Y >= size.Z
		then Vector3.yAxis * size.Y
		elseif size.X >= size.Z then Vector3.xAxis * size.X
		else Vector3.zAxis * size.Z
	local tip, base = Instance.new("Attachment"), Instance.new("Attachment")
	tip.Name, base.Name = "SkinTrailTip", "SkinTrailBase"
	tip.Position, base.Position = axis * 0.5, axis * -0.5
	tip.Parent, base.Parent = biggest, biggest
	local trail = Instance.new("Trail")
	trail.Name = "SkinTrail"
	trail.Attachment0, trail.Attachment1 = tip, base
	trail.Color = ColorSequence.new(color, gold)
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = 0.2
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.Parent = biggest
end

-- Which plates take a palette's Accent colour (see Cosmetics.Palette):
--   Camo     patches, the same on both sides (picked by the plate's size)
--   Stripes  bands across the body, by height
--   Trim     the smaller plates: edges, straps, rivets, veins
local function accented(pattern: string?, part: BasePart, index: number, median: number): boolean
	local size = part.Size
	if pattern == "Camo" then
		local key = math.floor(size.X * 37 + size.Y * 61 + size.Z * 89 + index % 3)
		return key % 5 < 2
	elseif pattern == "Stripes" then
		return math.floor(part.CFrame.Position.Y / 0.55) % 2 == 1
	elseif pattern == "Trim" then
		return size.X * size.Y * size.Z < median
	end
	return false
end

local SEAM_LIMIT = 9 -- trimmed plates per armor piece, broadest face first
local WEAPON_SEAMS = 2 -- and per weapon (the blade's edge is its own)

-- A suit keeps the armour's own light and shade: each part takes the
-- palette's colour at its own relative brightness (a lighter edge stays
-- lighter, a deep trim deeper), so the armour's detail still reads. And a
-- suit never blacks the armour out: a part keeps at least a share of its
-- own brightness (KEEP: most of it under the plates, over half on them),
-- and nothing goes below the floors.
local SUIT_PLATE_REF, SUIT_UNDER_REF = 0.62, 0.25
local SUIT_PLATE_FLOOR, SUIT_UNDER_FLOOR = 0.27, 0.15
local SUIT_PLATE_KEEP, SUIT_UNDER_KEEP = 0.55, 0.85
local function shaded(color: Color3, ratio: number, floor: number, own: number?): Color3
	local h, sat, v = color:ToHSV()
	return Color3.fromHSV(h, sat, math.clamp(math.max(v * ratio, own or 0), floor, 1))
end

-- Repaints every part under `container` in a cosmetic Palette (skins and
-- suits): neon takes the glow, dark parts and wood/leather the under-colour,
-- the rest the plate colour and material (or the Accent, in its Pattern).
-- Plain blocks get glowing Seams when the palette asks: neon trim round
-- their outward faces (inlay), the broadest faces first. Returns the biggest
-- part (for particles, trails and a blade's look). `suit`: armour, shaded
-- (above), its visor left as it is (parts marked Visor, see ArmorKits).
-- A set gem keeps its own colours, whatever's worn.
local function repaint(container: Instance, palette, limit: number?, suit: boolean?): BasePart?
	local biggest, biggestSize = nil, 0
	local plates = {}
	local shades: { [BasePart]: number } = {}
	for _, part in container:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency >= 1 or GEM_PARTS[part.Name] or part.Name == "SkinSeam" then
			continue
		end
		if suit and part:GetAttribute("Visor") then
			continue
		end
		CollectionService:RemoveTag(part, Tags.Prismatic)
		part:SetAttribute("PrismaticBase", nil) -- (or a copy of it would shimmer: LiveLooks)
		local _, _, value = part.Color:ToHSV()
		if part.Material == Enum.Material.Neon then
			part.Color = palette.Glow
		elseif value < 0.45 or part.Material == Enum.Material.Wood or part.Material == Enum.Material.Leather then
			part.Color = if suit
				then shaded(
					palette.Under,
					math.clamp(value / SUIT_UNDER_REF, 0.7, 1.5),
					SUIT_UNDER_FLOOR,
					value * SUIT_UNDER_KEEP
				)
				else palette.Under
			part.Material = palette.UnderMaterial or Enum.Material.SmoothPlastic
			part.Reflectance = 0
		else
			local ratio = if suit then math.clamp(value / SUIT_PLATE_REF, 0.8, 1.2) else 1
			part.Color = if suit
				then shaded(palette.Plate, ratio, SUIT_PLATE_FLOOR, value * SUIT_PLATE_KEEP)
				else palette.Plate
			part.Material = palette.PlateMaterial
			part.Reflectance = palette.Reflect or 0
			shades[part] = value
			table.insert(plates, part)
		end
		local size = part.Size.X * part.Size.Y * part.Size.Z
		if size > biggestSize then
			biggest, biggestSize = part, size
		end
	end
	if palette.Accent and palette.Pattern then
		local volumes = {}
		for _, part in plates do
			table.insert(volumes, part.Size.X * part.Size.Y * part.Size.Z)
		end
		table.sort(volumes)
		local median = volumes[math.ceil(#volumes / 2)] or 0
		for index, part in plates do
			if accented(palette.Pattern, part, index, median) then
				local own = shades[part] or SUIT_PLATE_REF
				part.Color = if suit
					then shaded(
						palette.Accent,
						math.clamp(own / SUIT_PLATE_REF, 0.8, 1.2),
						SUIT_PLATE_FLOOR,
						own * SUIT_PLATE_KEEP
					)
					else palette.Accent
				part.Material = palette.AccentMaterial or palette.PlateMaterial
			end
		end
	end
	if palette.Seams then
		local blocks = {}
		for _, part in plates do
			if
				part.ClassName == "Part"
				and part.Shape == Enum.PartType.Block
				and not part:FindFirstChildOfClass("SpecialMesh")
			then
				table.insert(blocks, part)
			end
		end
		-- Broadest faces first (a plate's two biggest sides).
		local function face(part: BasePart): number
			local s = part.Size
			return s.X * s.Y * s.Z / math.min(s.X, s.Y, s.Z)
		end
		table.sort(blocks, function(a, b)
			return face(a) > face(b)
		end)
		local color, width = seamStyle(palette)
		local trimmed = 0
		for _, block in blocks do
			if trimmed >= (limit or SEAM_LIMIT) then
				break
			end
			if inlay(block, container, color, width, palette, not suit) > 0 then
				trimmed += 1
			end
		end
	end
	return biggest
end

local function drift(part: BasePart, color: Color3, rate: number)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "SkinSparks"
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.Lifetime = NumberRange.new(0.5, 1)
	sparks.Rate = rate
	sparks.Speed = NumberRange.new(0.4, 1.2)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, 1.5, 0)
	sparks.Parent = part
end

-- A weapon skin given as a Palette (Cosmetics): repainted, with its sparks,
-- a glow, and a trail through every swing.
SKINS.Palette = function(weaponFolder: Instance, color: Color3, palette)
	local biggest = repaint(weaponFolder, palette, WEAPON_SEAMS)
	if not biggest then
		return
	end
	-- The blade (the biggest part) is the skin's hero: its own colour and
	-- material, and a glowing edge.
	if palette.Blade then
		biggest.Color = palette.Blade
		biggest.Material = palette.BladeMaterial or palette.PlateMaterial
		biggest.Reflectance = palette.Reflect or 0
	end
	if palette.Edge then
		local seam, width = seamStyle(palette)
		edgeLines(biggest, weaponFolder, seam, math.max(0.04, width * 1.4), palette)
	end
	if palette.Sparks then
		drift(biggest, palette.Sparks, 12)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = palette.Glow, 6, 0.8, false
	light.Parent = biggest
	if palette.Trail then
		local size = biggest.Size
		local axis = if size.Y >= size.X and size.Y >= size.Z
			then Vector3.yAxis * size.Y
			elseif size.X >= size.Z then Vector3.xAxis * size.X
			else Vector3.zAxis * size.Z
		local tip, base = Instance.new("Attachment"), Instance.new("Attachment")
		tip.Name, base.Name = "SkinTrailTip", "SkinTrailBase"
		tip.Position, base.Position = axis * 0.5, axis * -0.5
		tip.Parent, base.Parent = biggest, biggest
		local trail = Instance.new("Trail")
		trail.Name = "SkinTrail"
		trail.Attachment0, trail.Attachment1 = tip, base
		trail.Color = ColorSequence.new(palette.Glow, color)
		trail.LightEmission = 1
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.Lifetime = 0.2
		trail.MinLength = 0.05
		trail.FaceCamera = true
		trail.Parent = biggest
	end
end

-- Solar Flare: a palette skin whose blade is on fire, flames licking the
-- whole length of it.
SKINS.Solar = function(weaponFolder: Instance, color: Color3, palette)
	SKINS.Palette(weaponFolder, color, palette)
	local blade = nil
	for _, part in weaponFolder:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part:FindFirstChild("SkinTrailTip") then
			blade = part
		end
	end
	if not blade then
		return
	end
	local flames = Instance.new("ParticleEmitter")
	flames.Name = "SkinFlames"
	flames.Shape = Enum.ParticleEmitterShape.Box
	flames.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	flames.Color = ColorSequence.new(Color3.fromRGB(255, 236, 160), Color3.fromRGB(255, 80, 20))
	flames.LightEmission = 1
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
	flames.Transparency = NumberSequence.new(0.2, 1)
	flames.Lifetime = NumberRange.new(0.25, 0.5)
	flames.Rate = 36
	flames.Speed = NumberRange.new(0.8, 2)
	flames.SpreadAngle = Vector2.new(25, 25)
	flames.Acceleration = Vector3.new(0, 4, 0)
	flames.Parent = blade
	local light = blade:FindFirstChildOfClass("PointLight")
	if light then
		light.Range, light.Brightness = 9, 1.4
	end
end

-- Kindred Edge (bring a friend): a starlit blade forged for two. The palette
-- does the blade, its edge pulsing with starlight, the teal motes and the
-- trail; on top, two strands of light - teal (the glow) and gold (the
-- hilt's), half a turn apart - wind up the blade round each other from the
-- guard to the point (built from short neon links, so they show in
-- previews and first person too), and gold motes rise with the teal ones.
SKINS.Kindred = function(weaponFolder: Instance, color: Color3, palette)
	SKINS.Palette(weaponFolder, color, palette)
	local blade = nil
	for _, part in weaponFolder:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part:FindFirstChild("SkinTrailTip") then
			blade = part
		end
	end
	if not blade then
		return
	end
	-- The blade's own axes: along it, across its flat, through it.
	local size = blade.Size
	local axes = {
		{ Vector3.xAxis, size.X },
		{ Vector3.yAxis, size.Y },
		{ Vector3.zAxis, size.Z },
	}
	table.sort(axes, function(a, b)
		return a[2] > b[2]
	end)
	local along, across, through = axes[1][1], axes[2][1], axes[3][1]
	local length = axes[1][2]
	local wide, deep = axes[2][2] / 2 + 0.07, axes[3][2] / 2 + 0.07
	local LINKS, TURNS = 22, 1.25
	for strand, strandColor in { palette.Glow, palette.Plate } do
		local phase = (strand - 1) * math.pi
		local function at(t: number): Vector3
			local angle = phase + t * TURNS * 2 * math.pi
			return along * (length * (t * 0.86 - 0.42))
				+ across * (wide * math.cos(angle))
				+ through * (deep * math.sin(angle))
		end
		for i = 0, LINKS - 1 do
			-- (Round links, overlapping a little, so the strand reads as one
			-- smooth thread. A cylinder runs along its X axis.)
			local from, to = at(i / LINKS), at((i + 1) / LINKS)
			local run = (to - from).Unit
			local side = run:Cross(through)
			side = if side.Magnitude > 1e-3 then side.Unit else run:Cross(across).Unit
			local link = neon(
				weaponFolder,
				blade,
				CFrame.fromMatrix((from + to) / 2, run, side:Cross(run).Unit),
				Vector3.new((to - from).Magnitude + 0.05, 0.065, 0.065),
				strandColor
			)
			link.Shape = Enum.PartType.Cylinder
			link.Name = "KindredStrand"
		end
	end
	-- Gold motes rising with the teal ones.
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "SkinSparks"
	motes.Color = ColorSequence.new(palette.Plate)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new(0.1, 1)
	motes.Lifetime = NumberRange.new(0.6, 1.1)
	motes.Rate = 10
	motes.Speed = NumberRange.new(0.3, 1)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Acceleration = Vector3.new(0, 1.8, 0)
	motes.Parent = blade
	-- Its swing streaks from one colour into the other.
	local trail = blade:FindFirstChild("SkinTrail") :: Trail?
	if trail then
		trail.Color = ColorSequence.new(palette.Glow, palette.Plate)
	end
end

-- Shape skins (the Brainrot collection) swap the weapon's model for their
-- own, held the same way: the old parts are hidden and the new one is built
-- along the old blade, from the grip outwards.
local function swapShape(weaponFolder: Instance): (BasePart?, CFrame, number)
	local grip = weaponFolder:FindFirstChild("RightGrip") :: BasePart?
	local blade, bladeSize = nil, 0
	for _, part in weaponFolder:GetDescendants() do
		if part:IsA("BasePart") and part ~= grip and part.Transparency < 1 then
			local size = part.Size.X * part.Size.Y * part.Size.Z
			if size > bladeSize then
				blade, bladeSize = part, size
			end
		end
	end
	if not grip or not blade then
		return nil, CFrame.identity, 0
	end
	-- The blade's long axis, pointing away from the hand, sets the new
	-- weapon's up; its far end sets the length.
	local rel = grip.CFrame:ToObjectSpace(blade.CFrame)
	local size = blade.Size
	local axis = if size.Y >= size.X and size.Y >= size.Z
		then rel.UpVector
		elseif size.X >= size.Z then rel.RightVector
		else rel.LookVector
	local half = math.max(size.X, size.Y, size.Z) / 2
	if rel.Position:Dot(axis) < 0 then
		axis = -axis
	end
	local length = math.max(rel.Position:Dot(axis) + half, 2.4)
	local side = axis:Cross(Vector3.zAxis)
	if side.Magnitude < 0.1 then
		side = axis:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local mount = CFrame.fromMatrix(Vector3.zero, side, axis)
	-- (What to hide is listed first: its effects are destroyed as it goes.)
	local hide, drop = {}, {}
	for _, part in weaponFolder:GetDescendants() do
		if part:IsA("BasePart") and part ~= grip then
			table.insert(hide, part)
		elseif part:IsA("Highlight") then
			table.insert(drop, part)
		end
	end
	for _, part in hide do
		part.Transparency = 1
		for _, effect in part:GetChildren() do
			if
				effect:IsA("ParticleEmitter")
				or effect:IsA("Trail")
				or effect:IsA("SelectionBox")
				or effect:IsA("Light")
			then
				effect:Destroy()
			end
		end
	end
	for _, highlight in drop do
		highlight:Destroy()
	end
	return grip, mount, length
end

local function meshed(part: BasePart, meshType: Enum.MeshType): BasePart
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = meshType
	mesh.Parent = part
	return part
end

-- Bonk Bat: a fat cartoon baseball bat, red tape on the grip.
SKINS.Bonk = function(weaponFolder: Instance, _color: Color3, palette)
	local grip, mount, length = swapShape(weaponFolder)
	if not grip then
		return
	end
	local wood, tape = palette.Plate, palette.Under
	local handle = length * 0.36
	meshed(
		piece(
			weaponFolder,
			grip,
			mount * CFrame.new(0, handle / 2 - 0.25, 0),
			Vector3.new(0.2, handle, 0.2),
			tape,
			Enum.Material.Fabric
		),
		Enum.MeshType.Cylinder
	)
	meshed(
		piece(
			weaponFolder,
			grip,
			mount * CFrame.new(0, -0.27, 0),
			Vector3.new(0.3, 0.1, 0.3),
			wood,
			palette.PlateMaterial
		),
		Enum.MeshType.Cylinder
	)
	-- The barrel swells towards the end, in three steps, then a round cap.
	local y = handle - 0.25
	for step, width in { 0.26, 0.36, 0.46 } do
		local h = (length - handle) / 3
		local part = piece(
			weaponFolder,
			grip,
			mount * CFrame.new(0, y + h / 2, 0),
			Vector3.new(width, h + 0.04, width),
			wood,
			palette.PlateMaterial
		)
		meshed(part, Enum.MeshType.Cylinder)
		y += h
		if step == 3 then
			meshed(
				piece(
					weaponFolder,
					grip,
					mount * CFrame.new(0, y, 0),
					Vector3.new(width, 0.24, width),
					wood,
					palette.PlateMaterial
				),
				Enum.MeshType.Sphere
			)
		end
	end
	-- Neon bands: round the sweet spot, the knob and where the tape ends.
	local band = palette.SeamColor or palette.Glow
	for _, ring in
		{
			{ y - 0.35, 0.48, 0.08 },
			{ y - 0.6, 0.46, 0.04 },
			{ handle - 0.25, 0.25, 0.05 },
			{ -0.33, 0.32, 0.04 },
		}
	do
		local part = piece(
			weaponFolder,
			grip,
			mount * CFrame.new(0, ring[1], 0),
			Vector3.new(ring[2], ring[3], ring[2]),
			band,
			Enum.Material.Neon
		)
		meshed(part, Enum.MeshType.Cylinder)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = band, 5, 0.7, false
	light.Parent = grip
end

-- Banana Blade: a banana, curved like one, stem out of the fist. It still cuts.
SKINS.Banana = function(weaponFolder: Instance, _color: Color3, palette)
	local grip, mount, length = swapShape(weaponFolder)
	if not grip then
		return
	end
	local peel, stem = palette.Plate, palette.Under
	meshed(
		piece(
			weaponFolder,
			grip,
			mount * CFrame.new(0, -0.15, 0),
			Vector3.new(0.16, 0.4, 0.16),
			stem,
			Enum.Material.SmoothPlastic
		),
		Enum.MeshType.Cylinder
	)
	-- Seven plump segments along a gentle arc, thickest in the middle.
	local segments = 9
	local bend = math.rad(40)
	local radius = length / bend
	for i = 0, segments - 1 do
		local t = (i + 0.5) / segments
		local angle = t * bend
		local x, yy = radius * (1 - math.cos(angle)), radius * math.sin(angle)
		local thick = 0.26 + 0.12 * math.sin(math.pi * t)
		local part = piece(
			weaponFolder,
			grip,
			mount * CFrame.new(x, yy, 0) * CFrame.Angles(0, 0, -angle),
			Vector3.new(thick, length / segments * 2.4, thick),
			peel,
			palette.PlateMaterial
		)
		meshed(part, Enum.MeshType.Sphere)
	end
	-- The tip glows, and neon stripes run round the peel.
	local band = palette.SeamColor or palette.Glow
	local x, yy = radius * (1 - math.cos(bend)), radius * math.sin(bend)
	meshed(
		piece(weaponFolder, grip, mount * CFrame.new(x, yy, 0), Vector3.new(0.14, 0.16, 0.14), band, Enum.Material.Neon),
		Enum.MeshType.Sphere
	)
	for _, t in { 0.22, 0.5, 0.78 } do
		local angle = t * bend
		local bx, by = radius * (1 - math.cos(angle)), radius * math.sin(angle)
		local thick = (0.26 + 0.12 * math.sin(math.pi * t)) * 1.06
		meshed(
			piece(
				weaponFolder,
				grip,
				mount * CFrame.new(bx, by, 0) * CFrame.Angles(0, 0, -angle),
				Vector3.new(thick, 0.05, thick),
				band,
				Enum.Material.Neon
			),
			Enum.MeshType.Cylinder
		)
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = band, 5, 0.7, false
	light.Parent = grip
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

-- The Crusader's Standard (bring 3 friends): a black war banner on an iron
-- pole, a gold crossbar and spear finial, gold edging and a glowing gold
-- emblem. Its own colours, whatever your class.
BACKS.Standard = function(folder, torso, m, glow, _accent)
	local gold = Color3.fromRGB(214, 164, 60)
	local pole = m * CFrame.new(0.55, 1.5, -0.32)
	piece(folder, torso, pole, Vector3.new(0.16, 5.4, 0.16), Color3.fromRGB(46, 48, 56), Enum.Material.Metal)
	piece(folder, torso, pole * CFrame.new(0, 2.75, 0), Vector3.new(0.22, 0.5, 0.22), gold, Enum.Material.Foil)
	piece(folder, torso, pole * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(0.26, 0.26, 0.1), gold, Enum.Material.Foil)
	piece(folder, torso, pole * CFrame.new(-0.85, 2.25, 0), Vector3.new(1.9, 0.12, 0.12), gold, Enum.Material.Foil)
	local cloth = piece(folder, torso, pole * CFrame.new(-0.85, 1.15, 0), Vector3.new(1.6, 2.1, 0.05), Color3.fromRGB(18, 16, 22), Enum.Material.Fabric)
	cloth.Name = "Banner"
	for _, x in { -0.8, 0.8 } do
		piece(folder, torso, pole * CFrame.new(-0.85 + x, 1.15, 0), Vector3.new(0.08, 2.1, 0.07), gold, Enum.Material.Foil)
	end
	piece(folder, torso, pole * CFrame.new(-0.85, 0.1, 0), Vector3.new(1.6, 0.08, 0.07), gold, Enum.Material.Foil)
	-- The emblem: a glowing cross.
	neon(folder, torso, pole * CFrame.new(-0.85, 1.25, -0.04), Vector3.new(0.16, 0.9, 0.04), glow)
	neon(folder, torso, pole * CFrame.new(-0.85, 1.4, -0.04), Vector3.new(0.6, 0.16, 0.04), glow)
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
		if part:IsA("BasePart") and part.Transparency < 1 and not GEM_PARTS[part.Name] then
			if part.Material == Enum.Material.Neon and part.Name ~= "SkinSeam" then
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

-- A gem in a piece of gear shows as the stone itself, set into the piece
-- (gemSocket: bezel, prongs, a glowing core under a faceted crown), in the
-- gem's own shade: on the brow of a helmet, the front of each forearm and
-- shin, the centre of the chest, the shield's face and the weapon's hilt.
-- Real parts, so the stone shows the same everywhere: in the world, in first
-- person, in the Inventory and the Store. Then its element, from the stone:
--   * the piece's glowing trims turn the element's colour (unless a suit
--     colours them);
--   * a soft light in the stone, moving the element's way;
--   * a small effect coming off the stone, busier the rarer the gem:
--       Thermal    a flicker of flame and a few embers
--       Cryo       frost crystals round the setting, snow drifting off it,
--                  a breath of cold mist
--       Ion        sparks crackling over it, the odd bright flash
--       Corrosive  bubbles rising off it, a thin wisp of gas
--   * an enchanted weapon's blade carries a little of it too.
-- (It was a coloured outline round the whole piece and clouds of flame,
-- smoke or gas off its biggest plate: busy in the world, and nothing at all
-- in a preview.)
-- How each element's light moves: seconds per pulse, and how far it dims.
local GEM_PULSE = {
	Fire = { 0.16, 0.55 }, -- flicker
	Frost = { 1.6, 0.7 }, -- slow and cold
	Shock = { 0.07, 0.25 }, -- strobe
	Poison = { 1.0, 0.5 }, -- sickly throb
}
-- What comes off a stone, per element: particle styles (sizes for a stone
-- 0.2 across; Rate at Common, + PerTier for each tier above).
local STONE_FX: { [string]: { any } } = {
	Fire = {
		{
			Texture = FIRE_TEXTURE,
			Colors = { Color3.fromRGB(255, 226, 130), Color3.fromRGB(255, 70, 20) },
			Size = 0.24,
			Lifetime = NumberRange.new(0.25, 0.45),
			Speed = NumberRange.new(0.3, 0.9),
			Acceleration = Vector3.new(0, 4, 0),
			Spread = 15,
			Transparency = 0.15,
			Light = 1,
			Rate = 6,
			PerTier = 2,
		},
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(255, 236, 160), Color3.fromRGB(255, 110, 40) },
			Size = 0.07,
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(0.8, 1.6),
			Acceleration = Vector3.new(0, 2, 0),
			Spread = 40,
			Transparency = 0,
			Light = 1,
			Rate = 2,
			PerTier = 1,
		},
	},
	Frost = {
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(245, 253, 255), Color3.fromRGB(130, 200, 255) },
			Size = 0.09,
			Lifetime = NumberRange.new(0.9, 1.5),
			Speed = NumberRange.new(0.1, 0.35),
			Acceleration = Vector3.new(0, -1, 0),
			Spread = 180,
			Transparency = 0,
			Light = 1,
			Rate = 3,
			PerTier = 1.2,
			Spin = true,
		},
		{
			Texture = SMOKE_TEXTURE,
			Colors = { Color3.fromRGB(225, 245, 255), Color3.fromRGB(150, 205, 255) },
			Size = 0.4,
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(0.05, 0.2),
			Acceleration = Vector3.new(0, -0.6, 0),
			Spread = 50,
			Transparency = 0.75,
			Light = 0.3,
			Rate = 1,
			PerTier = 0.5,
		},
	},
	Shock = {
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(255, 255, 235), Color3.fromRGB(255, 215, 30) },
			Size = 0.13,
			Lifetime = NumberRange.new(0.05, 0.12),
			Speed = NumberRange.new(2, 4),
			Acceleration = Vector3.zero,
			Spread = 180,
			Transparency = 0,
			Light = 1,
			Rate = 6,
			PerTier = 3,
			Locked = true,
		},
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(255, 255, 230), Color3.fromRGB(255, 240, 120) },
			Size = 0.36,
			Lifetime = NumberRange.new(0.04, 0.08),
			Speed = NumberRange.new(0),
			Acceleration = Vector3.zero,
			Spread = 0,
			Transparency = 0,
			Light = 1,
			Rate = 1.5,
			PerTier = 0.8,
			Locked = true,
		},
	},
	Poison = {
		{
			Texture = SPARK_TEXTURE,
			Colors = { Color3.fromRGB(215, 255, 160), Color3.fromRGB(70, 210, 80) },
			Size = 0.08,
			Lifetime = NumberRange.new(0.8, 1.4),
			Speed = NumberRange.new(0.2, 0.5),
			Acceleration = Vector3.new(0, 1.2, 0),
			Spread = 30,
			Transparency = 0.05,
			Light = 0.8,
			Rate = 2,
			PerTier = 1,
		},
		{
			Texture = SMOKE_TEXTURE,
			Colors = { Color3.fromRGB(200, 255, 140), Color3.fromRGB(70, 170, 60) },
			Size = 0.3,
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(0.2, 0.5),
			Acceleration = Vector3.new(0, 0.8, 0),
			Spread = 40,
			Transparency = 0.7,
			Light = 0.3,
			Rate = 1,
			PerTier = 0.5,
			Spin = true,
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
-- One element effect on `part`: `scale` sizes it (1 for a stone 0.2
-- across), `share` thins it (a blade's touch of it).
local function stoneParticles(
	part: BasePart,
	element: string,
	tier: number,
	scale: number,
	share: number,
	volume: boolean?
)
	for index, style in STONE_FX[element] or {} do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "GemEffect"
		emitter.Texture = style.Texture
		emitter.Color = ColorSequence.new(style.Colors[1], style.Colors[2])
		emitter.LightEmission = style.Light
		local size = style.Size * scale * (0.9 + tier * 0.05)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size * 0.5),
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
		emitter.Rate = (style.Rate + style.PerTier * (tier - 1)) * share
		emitter.LockedToPart = style.Locked == true
		if style.Spin then
			emitter.RotSpeed = NumberRange.new(-90, 90)
			emitter.Rotation = NumberRange.new(0, 360)
		end
		if volume then
			emitter.Shape = Enum.ParticleEmitterShape.Box
			emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		end
		emitter:SetAttribute("Layer", index)
		emitter.Parent = part
	end
end
-- Cryo: a ring of small ice crystals jutting out of the setting.
local function frostCrystals(core: BasePart, count: number)
	local weld = core:FindFirstChildOfClass("WeldConstraint")
	local anchor = weld and weld.Part0
	if not anchor then
		return
	end
	local radius = core.Size.X * 1.05
	for i = 1, count do
		local angle = (i - 0.5) / count * math.pi * 2 + 0.4
		local crystal = piece(
			core.Parent :: Instance,
			anchor,
			anchor.CFrame:ToObjectSpace(
				core.CFrame
					* CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, -core.Size.Z * 0.2)
					* CFrame.Angles(0, 0, angle - math.pi / 2)
					* CFrame.Angles(math.rad(-25), 0, 0)
			),
			Vector3.new(core.Size.X * 0.22, core.Size.X * (0.55 + (i % 2) * 0.25), core.Size.X * 0.22),
			Color3.fromRGB(205, 238, 255),
			Enum.Material.Glass
		)
		crystal.Name = "GemIce"
		crystal.Transparency = 0.2
		crystal.Reflectance = 0.25
		crystal.CastShadow = false
	end
end
-- Where a ray coming in from outside, back along `dir` toward `origin`,
-- first meets `parts`: the outside of the armour there (nil: it misses).
local function surfaceAt(parts: { BasePart }, origin: Vector3, dir: Vector3): Vector3?
	local start = origin + dir * 6
	local best = nil
	for _, part in parts do
		local o = part.CFrame:PointToObjectSpace(start)
		local d = part.CFrame:VectorToObjectSpace(-dir)
		local h = part.Size / 2
		local tmin, tmax, hit = -math.huge, math.huge, true
		for _, axis in { "X", "Y", "Z" } do
			local oa, da, ha = (o :: any)[axis], (d :: any)[axis], (h :: any)[axis]
			if math.abs(da) < 1e-6 then
				if oa < -ha or oa > ha then
					hit = false
					break
				end
			else
				local t1, t2 = (-ha - oa) / da, (ha - oa) / da
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin, tmax = math.max(tmin, t1), math.min(tmax, t2)
				if tmin > tmax then
					hit = false
					break
				end
			end
		end
		if hit and tmax >= 0 then
			local t = math.max(tmin, 0)
			if not best or t < best then
				best = t
			end
		end
	end
	return if best then start - dir * best else nil
end
-- Where each piece's stone is set: the body part (R15, R6), the spot on it
-- (as a share of its size, the stone facing out of its front) and the
-- stone's size. Gloves and boots have one on each side.
local STONE_SPOTS = {
	Helmet = { { "Head", "Head", Vector3.new(0, 0.2, 0), 0.2 } },
	Armor = { { "UpperTorso", "Torso", Vector3.new(0, 0.12, 0), 0.3 } },
	Gloves = {
		{ "RightLowerArm", "Right Arm", Vector3.new(0, 0.05, 0), 0.15 },
		{ "LeftLowerArm", "Left Arm", Vector3.new(0, 0.05, 0), 0.15 },
	},
	Boots = {
		{ "RightLowerLeg", "Right Leg", Vector3.new(0, 0.18, 0), 0.16 },
		{ "LeftLowerLeg", "Left Leg", Vector3.new(0, 0.18, 0), 0.16 },
	},
}
-- Sets `gem` into a worn armour piece, on the outside of the armour.
local function pieceStones(component: Instance, character: Model, slot: string, gem)
	local spots = STONE_SPOTS[slot]
	if not spots or not gem then
		return
	end
	local parts = {}
	for _, part in component:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and not part:GetAttribute("Visor") then
			table.insert(parts, part)
		end
	end
	for _, spot in spots do
		local body = bodyPart(character, spot[1], spot[2])
		if body then
			local on = spot[3] * body.Size
			local dir = body.CFrame.LookVector
			local origin = body.CFrame * on
			local surface = surfaceAt(parts, origin, dir)
			local depth = if surface then (surface - origin):Dot(dir) else body.Size.Z / 2
			gemSocket(component, body, CFrame.new(), on - Vector3.new(0, 0, depth + spot[4] * 0.12), gem, spot[4])
		end
	end
end
-- A helmet skin (HelmetLooks) sets its gem where its design says, on the
-- part marked StoneSeat: on the front of it, facing out as the head does.
-- False if the skin has no seat.
local function seatStone(component: Instance, character: Model, gem): boolean
	local head = bodyPart(character, "Head", "Head")
	if not head or not gem then
		return false
	end
	for _, seat in component:GetDescendants() do
		if seat:IsA("BasePart") and seat:GetAttribute("StoneSeat") then
			local forward = head.CFrame.LookVector
			local c, s = seat.CFrame, seat.Size
			-- How far the seat reaches forward from its middle.
			local reach = (
				math.abs(c.RightVector:Dot(forward)) * s.X
				+ math.abs(c.UpVector:Dot(forward)) * s.Y
				+ math.abs(c.LookVector:Dot(forward)) * s.Z
			) / 2
			local size = STONE_SPOTS.Helmet[1][4] * 0.8
			local at = c.Position + forward * (reach + size * 0.12)
			gemSocket(component, seat, c:ToObjectSpace(CFrame.lookAt(at, at + forward)), Vector3.zero, gem, size)
			return true
		end
	end
	return false
end
-- A helmet skin is built round the head inside it: the avatar's own head and
-- face are hidden under it, and shown again (as they were) once it comes off.
local function hideHead(character: Model)
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") or head:GetAttribute("SkinHid") ~= nil then
		return
	end
	head:SetAttribute("SkinHid", head.Transparency)
	head.Transparency = 1
	for _, decal in head:GetChildren() do
		if decal:IsA("Decal") then
			decal:SetAttribute("SkinHid", decal.Transparency)
			decal.Transparency = 1
		end
	end
end
local function showHead(character: Model)
	local head = character:FindFirstChild("Head")
	local was = head and head:GetAttribute("SkinHid")
	if not head or not head:IsA("BasePart") or type(was) ~= "number" then
		return
	end
	head.Transparency = was
	head:SetAttribute("SkinHid", nil)
	for _, decal in head:GetChildren() do
		local before = decal:GetAttribute("SkinHid")
		if decal:IsA("Decal") and type(before) == "number" then
			decal.Transparency = before
			decal:SetAttribute("SkinHid", nil)
		end
	end
end
-- The element on a piece with a set stone (or a weapon): see above.
-- `suited`: a suit colours the piece's trims, so they're left be.
local function gemLook(component: Instance, gem, suited: boolean?)
	local color = GemConfig.ElementColors[gem.Element]
	if not color then
		return
	end
	local tier = gemTier(gem)
	component:SetAttribute("GemColor", color)
	local cores, biggest, biggestSize = {}, nil, 0
	for _, part in component:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency >= 1 then
			continue
		end
		if part.Name == "SocketedGem" then
			table.insert(cores, part)
		elseif not GEM_PARTS[part.Name] and part.Name ~= "SkinSeam" then
			if part.Material == Enum.Material.Neon and not suited then
				part.Color = color -- trims glow in the element's colour
			end
			local size = part.Size.X * part.Size.Y * part.Size.Z
			if size > biggestSize then
				biggest, biggestSize = part, size
			end
		end
	end
	local pulse = GEM_PULSE[gem.Element] or { 1, 0.5 }
	for _, core in cores do
		local scale = math.clamp(core.Size.X / 0.124, 0.6, 1.6) -- (a 0.2 stone's core is 0.124)
		local light = core:FindFirstChildOfClass("PointLight")
		if not light then
			light = Instance.new("PointLight")
			light.Parent = core
		end
		local lamp = light :: PointLight
		lamp.Name = "GemGlow"
		lamp.Color = color
		lamp.Shadows = false
		lamp.Range = (3 + tier * 0.6) * scale
		lamp.Brightness = 0.55 + tier * 0.12
		-- It breathes the element's way on every client (GemLights): a tween
		-- here would send every stone's light to every player, every frame.
		lamp:SetAttribute("PulseBase", lamp.Brightness)
		lamp:SetAttribute("PulsePeriod", pulse[1])
		lamp:SetAttribute("PulseDim", pulse[2])
		CollectionService:AddTag(lamp, Tags.GemGlow)
		stoneParticles(core, gem.Element, tier, scale, 1)
		if gem.Element == "Frost" then
			frostCrystals(core, 3 + math.floor(tier / 2))
		end
	end
	-- A weapon's blade (its biggest piece) carries a touch of it along its length.
	if component.Name == "Weapon" and biggest then
		stoneParticles(biggest, gem.Element, tier, 0.8, 0.45, true)
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
	-- In a duel, its PvP rule (Shared.PvPRules): Ranked fights gear capped at
	-- Ultra Rare; even stats leave the Augment Tree out.
	local owner = Players:GetPlayerFromCharacter(character)
	local rules = owner
		and PvPRules.forAttributes(owner:GetAttribute("MatchStats"), owner:GetAttribute("MatchRarityCap"))
	if rules and rules.RarityCap then
		loadout = PvPRules.capLoadout(loadout, rules.RarityCap)
	end
	local ratings = Classes.ratings(loadout)
	-- Agile armor (Fleet) adds a little on top.
	local extra = Classes.effects(loadout).SpeedAdd or 0
	local augments = if rules and rules.Stats == "Even" then {} else Tree.effects(profile)
	humanoid.WalkSpeed = (Classes.walkSpeed(ratings.Speed.Base + ratings.Speed.Bonus) + extra)
		* (1 + (augments.Mobility or 0))
	local fraction = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	humanoid.MaxHealth = Classes.maxHealth(ratings.Health.Base + ratings.Health.Bonus)
		+ Tree.vitals(profile, rules and rules.Stats).Health
	humanoid.Health = humanoid.MaxHealth * fraction
end

-- Builds the gear folder for a loadout on a character (not parented yet).
-- `only` limits it to one slot, for item previews.
-- Visors (cosmetics, Kind "Visor") -----------------------------------------------------------

-- How a lit visor's light breathes (GemLights), for the looks that move:
-- seconds from bright to dim, and how dim.
local VISOR_PULSE = { Pulse = { 0.9, 0.35 }, Flicker = { 0.07, 0.3 } }
-- Looks that run across the lens: each band and lens piece is seeded by
-- where it sits, left to right (0 to this), so a sweep or a gradient flows
-- over the visor: a Scan's bar crosses it all (SeamVisibility reads 0-10),
-- an Aurora shows a colour and a half at once, a Rainbow nearly every hue.
-- The rest move as one.
local VISOR_ACROSS = { Scan = 10, Aurora = 15, Rainbow = 30 }

-- A visor's colour as a light: a glass visor's tint (often dark) lifted
-- until it glows, so an eye it lights is never put out.
local function visorGlow(look): Color3
	if look.Material ~= "Glass" then
		return look.Color
	end
	local h, s, v = look.Color:ToHSV()
	return Color3.fromHSV(h, s, math.max(v, 0.9))
end

-- A visor on a helmet skin (HelmetLooks): its faces say how they take one
-- (VisorFit). Each eye glows in the visor's colour and moves as it does (or,
-- for a visor that holds still, as the skin's own eyes did); each lens takes
-- the visor's tint and stays see-through to the eyes behind it. The skin's
-- shapes stay as they are: nothing is cut into bands or framed, and the
-- visor's particles, sparks and glow come off the eyes, both of them alike.
local function fitVisor(helmet: Instance, head: BasePart, faces: { BasePart }, look, where: (BasePart) -> number)
	local fx = look.Fx
	local glass = look.Material == "Glass"
	local glow = visorGlow(look)
	-- An eye, or a part lit by the same light: the visor's glow, moving
	-- as the visor does (or as the skin's own did).
	local function lightUp(part: BasePart)
		part.Color = glow
		part.Material = Enum.Material.Neon
		part.Reflectance = 0
		local own = part:GetAttribute("SeamFx")
		if fx or own then
			part:SetAttribute("SeamFx", fx or own)
			part:SetAttribute("SeamA", glow)
			part:SetAttribute("SeamB", if fx then look.Glow or glow else glow:Lerp(Color3.new(1, 1, 1), 0.45))
			part:SetAttribute("SeamC", if fx then look.Third else nil)
			if fx then
				part:SetAttribute("SeamSeed", where(part) * (VISOR_ACROSS[fx] or 0))
			end
			CollectionService:AddTag(part, Tags.SkinSeam)
		end
	end
	local eyes: { BasePart } = {}
	for _, part in faces do
		CollectionService:RemoveTag(part, Tags.Prismatic)
		part:SetAttribute("PrismaticBase", nil)
		if part:GetAttribute("VisorFit") == "Lens" then
			-- (Its see-through, the skin's own, is left as it is.)
			part.Color = if glass then look.Color else look.Color:Lerp(Color3.new(0, 0, 0), 0.55)
			part.Material = Enum.Material.Glass
			part.Reflectance = if glass then look.Reflect or 0.2 else 0.25
		else
			table.insert(eyes, part)
			lightUp(part)
		end
	end
	-- What the skin lights with its eyes (a pumpkin's lid cut, the lamps
	-- round them) takes the visor's colour too.
	for _, d in helmet:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("VisorTint") then
			lightUp(d)
		elseif d:IsA("Light") and d:GetAttribute("VisorLight") then
			(d :: Light).Color = glow
		end
	end
	if #eyes == 0 then
		eyes = faces
	end
	-- One unseen box round the eyes, for the visor's particles and glow.
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in eyes do
		local at = head.CFrame:PointToObjectSpace(part.CFrame.Position)
		local reach = Vector3.one * (math.min(part.Size.X, part.Size.Y, part.Size.Z) / 2 + 0.02)
		low, high = low:Min(at - reach), high:Max(at + reach)
	end
	local spot = piece(
		eyes[1].Parent :: Instance,
		head,
		CFrame.new((low + high) / 2),
		high - low,
		glow,
		Enum.Material.SmoothPlastic
	)
	spot.Name = "VisorSpot"
	spot.Transparency = 1
	spot.CastShadow = false
	if look.Element then
		stoneParticles(spot, look.Element, 4, 1.6, 0.6, true)
		for _, child in spot:GetChildren() do
			if child:IsA("ParticleEmitter") and child.Name == "GemEffect" then
				child.Name = "VisorEffect"
			end
		end
	end
	if look.Sparks then
		drift(spot, look.Sparks, 6)
	end
	local light = Instance.new("PointLight")
	light.Name = "VisorGlow"
	light.Color = glow
	light.Range = 5
	light.Brightness = 0.6
	light.Shadows = false
	local pulse = fx and VISOR_PULSE[fx]
	if pulse then
		light:SetAttribute("PulseBase", light.Brightness)
		light:SetAttribute("PulsePeriod", pulse[1])
		light:SetAttribute("PulseDim", pulse[2])
		CollectionService:AddTag(light, Tags.GemGlow)
	end
	light.Parent = spot
end

-- Lays a visor look (Cosmetics.VisorLook) on a helmet's lens: the parts its
-- builder marked VisorFace (ArmorKits), whatever the helmet. The dark well
-- round the lens and its lamps stay as they are. Moving looks carry the
-- seams' attributes (SeamFx, SeamA, SeamB, SeamC, SeamSeed) and tag, so
-- every client animates them, copies included (SeamVisibility, LiveLooks).
local function applyVisor(helmet: Instance, look)
	local faces: { BasePart } = {}
	for _, part in helmet:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("VisorFace") and part.Transparency < 1 then
			table.insert(faces, part)
		end
	end
	local head = faces[1] and anchorOf(faces[1], helmet)
	if not head then
		return
	end
	local right = (head :: BasePart).CFrame.RightVector
	-- A part's own axis (1-3) lying most across the face.
	local function crosswise(part: BasePart): number
		local axis, best = 1, -1
		for i, v in { part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector } do
			local d = math.abs(v:Dot(right))
			if d > best then
				axis, best = i, d
			end
		end
		return axis
	end
	local function across(part: BasePart): number
		return (head :: BasePart).CFrame:PointToObjectSpace(part.CFrame.Position).X
	end
	-- The main lens (the biggest face) and the visor's span, side to side.
	local main, mainArea = faces[1], 0
	local low, high = math.huge, -math.huge
	for _, part in faces do
		local s = part.Size
		local area = s.X * s.Y * s.Z / math.max(math.min(s.X, s.Y, s.Z), 0.001)
		if area > mainArea then
			main, mainArea = part, area
		end
		local half = ({ s.X, s.Y, s.Z })[crosswise(part)] / 2
		low, high = math.min(low, across(part) - half), math.max(high, across(part) + half)
	end
	local function where(part: BasePart): number
		return math.clamp((across(part) - low) / math.max(high - low, 0.01), 0, 1)
	end
	-- A helmet skin's eyes and lenses: fitted, not cut.
	if main:GetAttribute("VisorFit") then
		fitVisor(helmet, head :: BasePart, faces, look, where)
		return
	end
	local fx = look.Fx
	local glass = look.Material == "Glass"
	local function style(part: BasePart)
		part.Color = look.Color
		part.Material = if glass then Enum.Material.Glass else Enum.Material.Neon
		part.Reflectance = if glass then look.Reflect or 0.2 else 0
		part.CastShadow = false
		CollectionService:RemoveTag(part, Tags.Prismatic)
		part:SetAttribute("PrismaticBase", nil)
		if fx then
			part:SetAttribute("SeamFx", fx)
			part:SetAttribute("SeamA", look.Color)
			part:SetAttribute("SeamB", look.Glow or look.Color)
			part:SetAttribute("SeamC", look.Third)
			part:SetAttribute("SeamSeed", where(part) * (VISOR_ACROSS[fx] or 0))
			CollectionService:AddTag(part, Tags.SkinSeam)
		end
	end
	local banded = (look.Bands or 0) > 1
	for _, part in faces do
		if not (banded and part == main) then
			style(part)
		end
	end
	local n, side = outwardFace(main, head)
	local dims = { main.Size.X, main.Size.Y, main.Size.Z }
	if banded then
		-- The main lens cut into bands across, standing just proud of it,
		-- with the lens itself gone dark behind them.
		local runs = crosswise(main)
		if runs == n then
			runs = n % 3 + 1
		end
		local up = 6 - n - runs
		local count = look.Bands
		local width = dims[runs] / count
		local deep = 0.012
		local lift = AXES[n] * side * (dims[n] / 2 + deep / 2)
		for i = 1, count do
			local at = lift + AXES[runs] * (-dims[runs] / 2 + (i - 0.5) * width)
			local band = piece(
				main.Parent :: Instance,
				head,
				head.CFrame:ToObjectSpace(main.CFrame * CFrame.new(at)),
				sized(runs, width * 0.84, up, dims[up] * 0.8, n, deep),
				look.Color,
				Enum.Material.Neon
			)
			band.Name = "VisorLens"
			band:SetAttribute("Visor", true)
			style(band)
		end
		main.Color = look.Color:Lerp(Color3.new(0, 0, 0), 0.82)
		main.Material = Enum.Material.SmoothPlastic
		main.Reflectance = 0.1
		CollectionService:RemoveTag(main, Tags.Prismatic)
		main:SetAttribute("PrismaticBase", nil)
	end
	if look.Rim then
		-- A lit frame round the main lens, moving with it but half a turn
		-- out of step, so it stands out from the bands it frames.
		local _, strips = inlay(main, helmet, look.Color, 0.02, { SeamFx = fx, Glow = look.Glow or look.Color }, false)
		for _, part in strips do
			part:SetAttribute("Visor", true)
			if fx then
				local span = VISOR_ACROSS[fx] or 0
				part:SetAttribute("SeamC", look.Third)
				part:SetAttribute("SeamSeed", where(part) * span + (if fx == "Scan" then 0 else 16.7))
			end
		end
	end
	if look.Element then
		-- The element comes off the lens as it does off a gem's stone.
		stoneParticles(main, look.Element, 4, 1.6, 0.6, true)
		for _, child in main:GetChildren() do
			if child:IsA("ParticleEmitter") and child.Name == "GemEffect" then
				child.Name = "VisorEffect"
			end
		end
	end
	if look.Sparks then
		drift(main, look.Sparks, 6)
	end
	if not glass then
		-- A lit lens lights the face round it, breathing with it if it moves.
		local light = Instance.new("PointLight")
		light.Name = "VisorGlow"
		light.Color = look.Color
		light.Range = 5
		light.Brightness = 0.6
		light.Shadows = false
		local pulse = fx and VISOR_PULSE[fx]
		if pulse then
			light:SetAttribute("PulseBase", light.Brightness)
			light:SetAttribute("PulsePeriod", pulse[1])
			light:SetAttribute("PulseDim", pulse[2])
			CollectionService:AddTag(light, Tags.GemGlow)
		end
		light.Parent = main
	end
end

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

	-- A helmet skin (cosmetic): a whole new head built in place of the
	-- helmet's own (HelmetLooks); the helmet keeps its stats, rolls and gem.
	local helmetSkin = cosmetics and Cosmetics.get(cosmetics.Helmet)
	local skinLook = if helmetSkin
			and helmetSkin.Kind == "Helmet"
			and HelmetLooks.has(helmetSkin.Look)
		then helmetSkin.Look
		else nil
	if not only or only == "Helmet" then
		showHead(character)
	end

	removeHeadwear(character)
	local armorSlots = {}
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots" } do
		local gear = (not only or only == slot)
			and Classes.gear(loadout.Class, Slots.Definitions[slot].Kind, loadout[slot])
		if gear then
			-- A Model (not a Folder), as every piece is.
			local component = Instance.new("Model")
			component.Name = slot
			component.Parent = folder
			armorSlots[slot] = component
			local skinned = slot == "Helmet" and skinLook ~= nil and HelmetLooks.build(component, character, skinLook)
			if skinned then
				hideHead(character)
			else
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
			end
			affinityGlow(component, GearRolls.get(loadout, slot))
			-- Its gem, set in it (the chest's comes after its trim, below; a
			-- helmet skin's where its design seats it).
			local gem = loadout[slot .. "Gem"]
			if gem and slot ~= "Armor" then
				if not (skinned and seatStone(component, character, gem)) then
					pieceStones(component, character, slot, gem)
				end
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
	-- An armor gem glows at the centre of the chest, set into the chest piece.
	local torso = bodyPart(character, "UpperTorso", "Torso")
	if torso and loadout.ArmorGem and (not only or only == "Armor") then
		if armorSlots.Armor then
			pieceStones(armorSlots.Armor, character, "Armor", loadout.ArmorGem)
		else
			gemSocket(
				folder,
				torso,
				CFrame.new(),
				Vector3.new(0, torso.Size.Y * 0.12, -torso.Size.Z * 0.5 - 0.2),
				loadout.ArmorGem,
				0.3
			)
		end
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
	local weaponFolder = Instance.new("Model") -- (a Model, as the armour pieces are)
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
	-- An armor suit (cosmetic): every armor piece repainted in its palette,
	-- particles drifting off the chest. Gem glows still show over it.
	local suit = cosmetics and Cosmetics.get(cosmetics.Suit)
	if suit and suit.Kind == "Suit" and suit.Palette then
		for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield" } do
			local component = folder:FindFirstChild(slot)
			-- (Not a helmet skin: it's a look of its own.)
			if component and (not only or only == slot) and not component:GetAttribute("HelmetSkin") then
				local biggest = repaint(component, suit.Palette, nil, true)
				if slot == "Armor" and biggest and suit.Palette.Sparks then
					drift(biggest, suit.Palette.Sparks, 8)
				end
			end
		end
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
	-- element from its stone, more the rarer the gem (gemLook).
	local suited = suit ~= nil and suit.Kind == "Suit" and suit.Palette ~= nil
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield", "Weapon" } do
		local component = folder:FindFirstChild(slot)
		local gem = loadout[slot .. "Gem"]
		if component and gem and (not only or only == slot) then
			gemLook(component, gem, suited and slot ~= "Weapon")
		end
	end
	-- A Prismatic roll (about 1 in 100): its coloured plates shimmer through
	-- every hue (the client's Effects cycle them).
	for _, slot in { "Helmet", "Armor", "Gloves", "Boots", "Shield", "Weapon" } do
		local component = folder:FindFirstChild(slot)
		local roll = GearRolls.get(loadout, slot)
		local suited = suit and suit.Palette and slot ~= "Weapon"
		if component and roll and roll.Prismatic and not suited and (not only or only == slot) then
			for _, part in component:GetDescendants() do
				if
					part:IsA("BasePart")
					and part.Transparency < 1
					and part.Material ~= Enum.Material.Neon
					and not GEM_PARTS[part.Name]
				then
					local h, s, v = part.Color:ToHSV()
					if s > 0.2 and v > 0.25 then
						part:SetAttribute("PrismaticBase", Color3.fromHSV(h, s, v))
						CollectionService:AddTag(part, Tags.Prismatic)
					end
				end
			end
		end
	end
	-- A weapon skin (cosmetic) goes on last, over everything else.
	local skin = cosmetics and Cosmetics.get(cosmetics.Skin)
	local applySkin = skin and (skin.Look and SKINS[skin.Look] or (skin.Palette and SKINS.Palette))
	if applySkin and (not only or only == "Weapon") then
		applySkin(weaponFolder, skin.Color, skin.Palette)
	end
	-- A helmet skin keeps its own colours through the gem, rarity and
	-- Prismatic passes (their stones, lights and particles stay).
	local helmetPiece = folder:FindFirstChild("Helmet")
	if helmetPiece and helmetPiece:GetAttribute("HelmetSkin") then
		HelmetLooks.restore(helmetPiece)
	end
	-- A visor (cosmetic) goes on last, on whatever helmet is worn, under any
	-- suit (a helmet skin's eyes light in its colour: fitVisor).
	local visor = cosmetics and Cosmetics.get(cosmetics.Visor)
	if visor and visor.Kind == "Visor" and visor.Visor and helmetPiece and (not only or only == "Helmet") then
		applyVisor(helmetPiece, visor.Visor)
	end
	return folder
end

-- (For tests: the builder itself, `only` one slot as the Armory previews it.)
Equipment._dress = dress

-- Dresses any rig (the PvP Duelist) in a loadout, as a player would wear it.
function Equipment.dressModel(model: Model, loadout, seed: number, cosmetics: any?): Folder?
	local folder = dress(model, loadout, cosmetics, seed)
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
	Equipment.showTitle(character, profile and profile.Cosmetics and Cosmetics.get(profile.Cosmetics.Title))
end

-- A title (cosmetic) over the head, in its colour, for everyone to see.
function Equipment.showTitle(character: Model, title)
	local head = character:FindFirstChild("Head") :: BasePart?
	local existing = head and head:FindFirstChild("CosmeticTitle")
	if existing then
		existing:Destroy()
	end
	if not head or not title or title.Kind ~= "Title" then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "CosmeticTitle"
	board.Size = UDim2.fromOffset(220, 26)
	board.StudsOffset = Vector3.new(0, 2.9, 0)
	board.MaxDistance = 90
	board.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Text = title.Name
	text.TextColor3 = title.Color
	local edge = Instance.new("UIStroke")
	edge.Color, edge.Thickness, edge.Transparency = Color3.fromRGB(10, 10, 14), 2, 0.1
	edge.Parent = text
	text.Parent = board
	board.Parent = head
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

-- Group previews ("Slot|M:..." for the Market, "Slot|A:..." for Arena
-- Caches) belong to groupPreviews, not the bag.
local function isGroup(name: string, group: string?): boolean
	if group then
		return string.find(name, "|" .. group .. ":", 1, true) ~= nil
	end
	return string.match(name, "|%u:") ~= nil
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

-- Shop previews of skins and suits, shared by every player and built once:
-- ReplicatedStorage.CosmeticPreviews[<id>], a folder of anchored parts.
-- A suit is a whole miner in the standard kit wearing it; a skin, just the
-- sword. Glowing seams and edges (SelectionBoxes, which a ViewportFrame
-- can't draw) are baked into thin neon bars.
local PREVIEW_KIT = {
	Class = "Warrior",
	Weapon = "MatrixSwords1",
	Armor = "ArmorJuggernautArmor3",
	Helmet = "ArmorJuggernautHelmet3",
	Gloves = "ArmorJuggernautGloves3",
	Boots = "ArmorJuggernautBoots3",
}
local cosmeticBusy = false

local function bakeSeams(part: BasePart, box: SelectionBox, into: Instance)
	local t = math.max(box.LineThickness, 0.02)
	local size = part.Size
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			for _, bar in {
				{ Vector3.new(0, a * hy, b * hz), Vector3.new(size.X + t, t, t) },
				{ Vector3.new(a * hx, 0, b * hz), Vector3.new(t, size.Y + t, t) },
				{ Vector3.new(a * hx, b * hy, 0), Vector3.new(t, t, size.Z + t) },
			} do
				local line = Instance.new("Part")
				line.Name = "Seam"
				line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch = true, false, false, false
				line.Material, line.Color = Enum.Material.Neon, box.Color3
				line.Size = bar[2]
				line.CFrame = part.CFrame * CFrame.new(bar[1])
				line.Parent = into
			end
		end
	end
end

function Equipment.cosmeticPreview(id: string): boolean
	local cosmetic = Cosmetics.get(id)
	if not cosmetic or not Cosmetics.isMinerKind(cosmetic.Kind) then
		return false
	end
	local store = ReplicatedStorage:FindFirstChild("CosmeticPreviews")
	if not store then
		store = Instance.new("Folder")
		store.Name = "CosmeticPreviews"
		store.Parent = ReplicatedStorage
	end
	if store:FindFirstChild(id) then
		return true
	end
	if cosmetic.Kind == "Pick" then
		-- A pickaxe needs no mannequin: built standing, leaning, its head in
		-- profile (the spike along X; its particles and light don't show
		-- in a preview, so they go).
		local preview = Instance.new("Folder")
		preview.Name = id
		preview:SetAttribute("Kind", "Pick")
		local stand = CFrame.Angles(0, 0, math.rad(-30)) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, -1.3, 0)
		local parts = PickaxeLooks.build(preview, stand, id)
		for _, part in parts do
			for _, child in part:GetChildren() do
				child:Destroy()
			end
		end
		preview:SetAttribute("Parts", #parts)
		preview.Parent = store
		return true
	end
	while cosmeticBusy do
		task.wait()
	end
	if store:FindFirstChild(id) then
		return true
	end
	cosmeticBusy = true
	local rig = mannequin()
	if not rig then
		cosmeticBusy = false
		return false
	end
	task.wait()
	local origin = rig:GetPivot()
	local cosmetics = { Owned = {}, [cosmetic.Kind] = id }
	local ok, folder = pcall(dress, rig, PREVIEW_KIT, cosmetics, 0)
	local source = ok
		and folder
		and (
			if cosmetic.Kind == "Skin"
				then folder:FindFirstChild("Weapon")
				elseif cosmetic.Kind == "Visor" or cosmetic.Kind == "Helmet" then folder:FindFirstChild("Helmet")
				else folder
		)
	if source then
		local preview = Instance.new("Folder")
		preview.Name = id
		preview:SetAttribute("Kind", cosmetic.Kind)
		local parts = {}
		for _, part in source:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				table.insert(parts, part)
			end
		end
		if cosmetic.Kind == "Suit" then
			-- Whatever of the body the suit leaves showing.
			for _, part in rig:GetChildren() do
				if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
					table.insert(parts, part:Clone())
				end
			end
		end
		for _, part in parts do
			local box = part:FindFirstChildOfClass("SelectionBox")
			if box then
				bakeSeams(part, box, preview)
			end
			-- Its shape and surface stay (a mesh makes the domes, eggs and
			-- tubes of a helmet skin or a weapon: without it each is a box);
			-- welds, lights, particles and the rest go.
			for _, child in part:GetChildren() do
				if not (child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance")) then
					child:Destroy()
				end
			end
			part.Anchored = true
			part.Parent = preview
		end
		for _, part in preview:GetChildren() do
			(part :: BasePart).CFrame = origin:ToObjectSpace((part :: BasePart).CFrame)
		end
		-- How many parts make it whole: a client shows it only once they've
		-- all replicated (framed on the first few, a suit was one dark plate).
		preview:SetAttribute("Parts", #preview:GetChildren())
		preview.Parent = store
	end
	if ok and folder then
		folder:Destroy()
	end
	rig:Destroy()
	cosmeticBusy = false
	return source ~= nil
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
		elseif not isGroup(child.Name) then
			child:Destroy()
		end
	end
	if next(wanted) == nil then
		return true
	end
	return buildPreviews(player, store :: Instance, loadout, wanted)
end

-- Previews of gear that isn't yours, from the piece itself, in a group: "M"
-- for Market listings and offers, "A" for Arena Cache pieces.
-- items[tag] = { Slot, Id, Quality, Roll, Gem }. Each is built as
-- "Slot|<group>:<tag>" (GearArt.draw(view, slot, group .. ":" .. tag)); the
-- group's previews no longer asked for are dropped (other groups are kept).
function Equipment.groupPreviews(player: Player, group: string, items): (boolean, number?)
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
			wanted[item.Slot .. "|" .. group .. ":" .. tag] = {
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
		if isGroup(child.Name, group) then
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

-- The Market's previews ("Slot|M:<listing>[:<offer>]").
function Equipment.marketPreviews(player: Player, items): (boolean, number?)
	return Equipment.groupPreviews(player, "M", items)
end

local function watch(player: Player)
	local function dressWhenReady(character)
		-- The profile may still be loading on the first spawn.
		for _ = 1, 20 do
			if PlayerData.character(player) then
				break
			end
			task.wait(0.5)
		end
		if player.Character == character then
			Equipment.apply(player)
		end
	end
	player.CharacterAppearanceLoaded:Connect(function(character)
		dressWhenReady(character)
	end)
	-- Every body is the rival's rig (FighterRig) with no avatar appearance
	-- loaded, so the appearance event may never come: dress on spawn too
	-- (dressing twice just replaces the gear).
	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		dressWhenReady(character)
	end)
	-- A duel's PvP rule (set at the match start, cleared at the end) changes
	-- health and speed, so restat the body when it does.
	for _, key in { "MatchStats", "MatchRarityCap", "MinerLevel" } do
		player:GetAttributeChangedSignal(key):Connect(function()
			local character = player.Character
			local loadout = PlayerData.character(player)
			if character and loadout then
				applyStats(character, loadout, PlayerData.get(player))
			end
		end)
	end
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
	-- The Shop asks for the skins and suits it's showing.
	Shop.register("CosmeticPreviews", function(_player, ids)
		if typeof(ids) ~= "table" then
			return Shop.reply(false, "Nothing to preview.")
		end
		local built = 0
		for i, id in ids do
			if i > 60 then
				break
			end
			if typeof(id) == "string" and Equipment.cosmeticPreview(id) then
				built += 1
			end
		end
		return Shop.reply(true, "", { Built = built })
	end)
	-- The Armory asks for previews when it opens and when the gear changes.
	Shop.register("GearPreviews", function(player)
		local done = Equipment.previews(player)
		return Shop.reply(true, "", { Done = done })
	end)
	local rosterBusy, rosterKeys = {}, {}
	Players.PlayerRemoving:Connect(function(player)
		rosterBusy[player], rosterKeys[player] = nil, nil
	end)
	Shop.register("MinerPreviews", function(player)
		local profile = PlayerData.get(player)
		local gui = player:FindFirstChildOfClass("PlayerGui")
		if not profile or not profile.Miners or not gui or rosterBusy[player] then
			return Shop.reply(false, "Preview loading.")
		end
		rosterBusy[player] = true
		local ok = pcall(function()
			local store = gui:FindFirstChild("MinerPreviews")
			if not store then
				store = Instance.new("ScreenGui")
				store.Name, store.Enabled, store.ResetOnSpawn = "MinerPreviews", false, false
				store.Parent = gui
			end
			rosterKeys[player] = rosterKeys[player] or {}
			for index, miner in profile.Miners.Slots do
				local loadout = table.clone(if profile.Miners.Active == index then profile.Character else miner.Character)
				loadout.GearRolls = profile.Character.GearRolls
				loadout.ItemGems = profile.Character.ItemGems
				local keys = {}
				for _, slot in Slots.Order do
					local id = loadout[slot]
					if id then table.insert(keys, id .. ":" .. previewKey(loadout, slot, id, loadout[slot .. "Quality"] or 1)) end
				end
				-- What it wears over the gear (a suit, a weapon skin...) too.
				local look = if profile.Miners.Active == index
					then profile.Cosmetics or {}
					else Cosmetics.forMiner(profile.Cosmetics, miner.Character)
				table.insert(
					keys,
					string.format(
						"look:%s/%s/%s/%s/%s/%s",
						tostring(look.Suit),
						tostring(look.Skin),
						tostring(look.Back),
						tostring(look.Trim),
						tostring(look.Helmet),
						tostring(look.Visor)
					)
				)
				-- ("fist" marks previews held the fighting way: rebuilt once from older ones)
				local key = "fist|" .. table.concat(keys, "|")
				local name = tostring(index)
				if rosterKeys[player][index] ~= key or not store:FindFirstChild(name) then
					local rig = mannequin()
					if rig then
						-- Held as a player holds it (FistGrip): the Inventory poses
						-- these in the fighting stances, which are shaped for the
						-- sword in the fist and the shield on end across the forearm.
						-- Without it the blade lay along the arm, across the body,
						-- and the shield stood edge-on.
						rig:SetAttribute("FistGrip", true)
						Equipment.dressModel(rig, loadout, player.UserId, look)
						for _, child in rig:GetDescendants() do
							if child:IsA("BaseScript") or child:IsA("Sound") then child:Destroy()
							elseif child:IsA("BasePart") then child.Anchored = true end
						end
						local old = store:FindFirstChild(name)
						if old then old:Destroy() end
						rig.Name, rig.Parent = name, store
						rosterKeys[player][index] = key
					end
				end
			end
		end)
		rosterBusy[player] = nil
		return Shop.reply(ok, "")
	end)
end

return Equipment
