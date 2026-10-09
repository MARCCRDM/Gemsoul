-- Local camera presentation only; the real equipped geometry and all damage stay on the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Motion = require(game:GetService("ReplicatedStorage").Shared.InsertionMotion)
local player = Players.LocalPlayer
local View = {}
local saved, model, gear, connection, removalConnection
local pieces, hidden = {}, {}
local raised, charge, swingAt, swingSide, swingHeavy = 0, 0, -10, "Right", false
local cursorFree = false
local fireAt, smoothedRaised, smoothedCharge = -10, 0, 0
local dirty = true
-- How many of the gear's parts were showing at the last look (see the render step).
local shownParts, nextShownCheck = -1, 0
-- A surge being cast (View.cast): when it began, how long it takes, its colour.
local castAt, castFor, castColor, castOrb = -10, 0, nil, nil
local castAnimation = nil
local function clearModel()
	if model then
		model:Destroy()
	end
	model, gear = nil, nil
	table.clear(pieces)
end
-- A staged character is invisible in the world; its viewmodel still uses authored materials.
local function authoredTransparency(part)
	local staged = part:GetAttribute("InsertionTransparency")
	return if type(staged) == "number" then staged else part.Transparency
end
-- A copy of one piece of gear for the view: its element effects thinned out
-- (they'd cover the view up close), anchored, unclickable, 65% size.
local function viewCopy(part, holder, scale: number?)
	local copy = part:Clone()
	copy.Transparency = authoredTransparency(part)
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Rate *= 0.45
			local enabled = descendant:GetAttribute("InsertionEnabled")
			if type(enabled) == "boolean" then
				descendant.Enabled = enabled
			end
		elseif descendant:IsA("PointLight") then
			descendant.Range *= 0.6
		end
		if
			descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("Beam")
		then
			descendant:Destroy()
		end
	end
	copy.Anchored, copy.CanCollide, copy.CanTouch, copy.CanQuery, copy.CastShadow = true, false, false, false, false
	copy.LocalTransparencyModifier = 0
	-- Preserve authored neon and colors; give metal panels a restrained highlight.
	if copy.Material == Enum.Material.Metal then
		copy.Reflectance = math.max(copy.Reflectance, 0.08)
	end
	copy.Size *= scale or 0.65
	copy.Parent = holder
	return copy
end
local function scaled(offset, scale: number?)
	return CFrame.new(offset.Position * (scale or 0.65)) * offset.Rotation
end
--[[
	The shield as you see it in your own hands, Elder Scrolls / Blades style:
	a big kite shield whose back faces you. The worn shield's back is a plain
	board, so the view builds its own, as armoured tech to match the game: a
	gunmetal shell inside a rim of the shield's own metal, a glowing accent
	line just inside the rim, an inset lip for depth, a raised spine with
	recessed vented panels either side, the glowing back of its gem socket
	with energy conduits running out to the corners, and a forearm brace
	(padded cuff and a grip bar with a lit strip). The glow is the shield
	gem's element colour (else the shield's trim colour). Its gem's
	highlight and element effects ride along. Sizes in studs, in the
	shield's frame (its face is -Z, away from you; its back +Z, toward you).
]]
local SHIELD_W, SHIELD_H = 1.15, 1.0 -- the board's width, and its height above the point
local function shieldPart(holder, pieces, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = "ViewShield"
	part.Size = size
	part.Color = color
	part.Material = material
	if shape then
		part.Shape = shape
	end
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.Parent = holder
	table.insert(pieces, { Part = part, Shield = true, Offset = cframe })
	return part
end
-- A bar from a to b (in the shield's plane) at depth z.
local function strut(holder, pieces, a: Vector2, b: Vector2, width, depth, z, color, material)
	local mid = (a + b) / 2
	local delta = b - a
	return shieldPart(
		holder,
		pieces,
		Vector3.new(delta.Magnitude + width * 0.5, width, depth),
		CFrame.new(mid.X, mid.Y, z) * CFrame.Angles(0, 0, math.atan2(delta.Y, delta.X)),
		color,
		material
	)
end
local function hasVisibleParts(source): boolean
	for _, part in if source then source:GetDescendants() else {} do
		if part:IsA("BasePart") and authoredTransparency(part) < 1 then
			return true
		end
	end
	return false
end
-- `plain`: no copied effects (a weapon's own, which its blade already shows).
local function buildViewShield(holder, source, plain: boolean?)
	local pieces = {}
	-- Its metal: the worn shield's largest metal-looking plate, else steel;
	-- its glow: the gem's highlight colour, else its trim, else teal.
	local metal, area = Color3.fromRGB(150, 156, 166), 0
	local glow
	local emitters = {}
	for _, part in source:GetDescendants() do
		if part:IsA("BasePart") and authoredTransparency(part) < 1 and part.Name ~= "SocketedGem" then
			local flat = part.Size.X * part.Size.Y
			if part.Material == Enum.Material.Neon then
				glow = glow or part.Color
			elseif flat > area and flat < 1.9 then
				metal, area = part.Color, flat
			end
		elseif part:IsA("ParticleEmitter") then
			table.insert(emitters, part)
		end
	end
	local highlight = source:FindFirstChild("GemHighlight")
	if highlight and highlight:IsA("Highlight") then
		glow = highlight.OutlineColor
	end
	glow = glow or Color3.fromRGB(80, 220, 235)
	local W, H = SHIELD_W, SHIELD_H
	local P = Vector2.new
	local shell = Color3.fromRGB(46, 50, 58):Lerp(metal, 0.2)
	local recess = Color3.fromRGB(28, 31, 37)
	local pad = Color3.fromRGB(34, 34, 38)
	local Metal, Plate, Neon, Fabric =
		Enum.Material.Metal, Enum.Material.DiamondPlate, Enum.Material.Neon, Enum.Material.Fabric

	-- The shell: a rectangle on a diamond, so it tapers to a point below.
	local board = shieldPart(holder, pieces, Vector3.new(W, H, 0.07), CFrame.new(), shell, Metal)
	local side = W / math.sqrt(2)
	shieldPart(
		holder,
		pieces,
		Vector3.new(side, side, 0.07),
		CFrame.new(0, -H / 2, 0) * CFrame.Angles(0, 0, math.rad(45)),
		shell,
		Metal
	)
	-- The outline, corner to corner: top-left, top-right, right shoulder,
	-- the point, left shoulder.
	local corners = { P(-W / 2, H / 2), P(W / 2, H / 2), P(W / 2, -H / 2), P(0, -H / 2 - W / 2), P(-W / 2, -H / 2) }
	local function inset(k: number)
		local out = {}
		for i, c in corners do
			out[i] = c * (1 - k) + P(0, -H * 0.12) * k
		end
		return out
	end
	local function loop(points, width, depth, z, color, material)
		for i = 1, #points do
			strut(holder, pieces, points[i], points[i % #points + 1], width, depth, z, color, material)
		end
	end
	-- The rim in the shield's metal, a glowing line inside it, and an inset
	-- lip a little further in, for depth.
	loop(corners, 0.085, 0.14, 0, metal, Metal)
	loop(inset(0.09), 0.022, 0.02, 0.045, glow, Neon)
	loop(inset(0.17), 0.05, 0.05, 0.05, recess, Metal)
	-- The spine down the middle, and recessed vented panels either side.
	strut(
		holder,
		pieces,
		P(0, H / 2 - 0.08),
		P(0, -H / 2 - W / 2 + 0.16),
		0.11,
		0.08,
		0.06,
		metal:Lerp(shell, 0.4),
		Metal
	)
	for _, sx in { -1, 1 } do
		shieldPart(
			holder,
			pieces,
			Vector3.new(W * 0.28, H * 0.5, 0.02),
			CFrame.new(sx * W * 0.24, 0.12, 0.045),
			recess,
			Plate
		)
		for i = 0, 2 do
			shieldPart(
				holder,
				pieces,
				Vector3.new(W * 0.2, 0.025, 0.02),
				CFrame.new(sx * W * 0.24, 0.27 - i * 0.07, 0.058),
				Color3.fromRGB(14, 15, 18),
				Metal
			)
		end
	end
	-- The back of the gem socket: a glowing core in a metal ring, with
	-- conduits running out to the corners.
	shieldPart(
		holder,
		pieces,
		Vector3.new(0.05, 0.34, 0.34),
		CFrame.new(0, -0.12, 0.06) * CFrame.Angles(0, math.rad(90), 0),
		metal,
		Metal,
		Enum.PartType.Cylinder
	)
	shieldPart(
		holder,
		pieces,
		Vector3.new(0.06, 0.2, 0.2),
		CFrame.new(0, -0.12, 0.075) * CFrame.Angles(0, math.rad(90), 0),
		glow,
		Neon,
		Enum.PartType.Cylinder
	)
	local core = P(0, -0.12)
	for _, target in { P(-W * 0.38, H * 0.38), P(W * 0.38, H * 0.38), P(0, -H / 2 - W / 2 + 0.22) } do
		local from = core + (target - core).Unit * 0.17
		strut(holder, pieces, from, target, 0.02, 0.015, 0.068, glow, Neon)
	end
	-- The forearm brace: a padded cuff across the upper half, and a grip bar
	-- on two posts with a lit strip.
	shieldPart(holder, pieces, Vector3.new(0.5, 0.2, 0.08), CFrame.new(0, 0.3, 0.1), pad, Fabric)
	shieldPart(holder, pieces, Vector3.new(0.56, 0.06, 0.1), CFrame.new(0, 0.4, 0.13), metal, Metal)
	shieldPart(holder, pieces, Vector3.new(0.56, 0.06, 0.1), CFrame.new(0, 0.2, 0.13), metal, Metal)
	for _, sx in { -1, 1 } do
		shieldPart(holder, pieces, Vector3.new(0.06, 0.06, 0.16), CFrame.new(sx * 0.17, -0.42, 0.12), metal, Metal)
	end
	shieldPart(
		holder,
		pieces,
		Vector3.new(0.4, 0.08, 0.08),
		CFrame.new(0, -0.42, 0.2) * CFrame.Angles(0, 0, 0),
		Color3.fromRGB(30, 30, 34),
		Fabric,
		Enum.PartType.Cylinder
	)
	shieldPart(holder, pieces, Vector3.new(0.26, 0.018, 0.02), CFrame.new(0, -0.42, 0.245), glow, Neon)
	-- A few rivets at the rim's corners.
	for _, c in corners do
		shieldPart(
			holder,
			pieces,
			Vector3.one * 0.05,
			CFrame.new(c.X * 0.93, c.Y * 0.93 + (if c.Y < 0 then 0.03 else -0.03), 0.075),
			metal:Lerp(Color3.new(1, 1, 1), 0.2),
			Metal,
			Enum.PartType.Ball
		)
	end
	-- Its gem's element effects, thinned out up close.
	for _, emitter in if plain then {} else emitters do
		local copy = emitter:Clone()
		copy.Rate *= 0.45
		copy.Parent = board
	end
	return pieces
end
-- Where the shield sits in view: at rest low in the bottom-left corner,
-- angled toward the enemy so you see its back and rim; raised to block, it
-- swings up square in front of the left half of the view.
local shieldRest, shieldRaised
-- The weapon's own frame: its grip point, with +Y running up its longest
-- piece (the blade), so it can be held at a set angle however it's mounted.
local function weaponFrame(weapon)
	local grip = weapon:FindFirstChild("RightGrip")
	local blade, length = nil, 0
	for _, part in weapon:GetDescendants() do
        local weld = part:IsA("BasePart") and part:FindFirstChildWhichIsA("WeldConstraint")
        -- Only the right-hand blade defines its frame, never a built-in shield
        -- or the offhand blade of a dual-wield model.
        if part:IsA("BasePart") and weld and weld.Part0 == grip and authoredTransparency(part) < 1 and part.Size.Y > length then
			if part.Size.Y >= math.max(part.Size.X, part.Size.Z) then
				blade, length = part, part.Size.Y
			end
		end
	end
	if not grip or not blade then
		return nil
	end
	-- Which way along the blade is the tip (away from the grip).
	local rotation = blade.CFrame.Rotation
	if (blade.CFrame.Position - grip.CFrame.Position):Dot(blade.CFrame.UpVector) < 0 then
		rotation *= CFrame.Angles(0, 0, math.pi)
	end
	return CFrame.new(grip.CFrame.Position) * rotation
end
local function rebuild(character, equipment)
	clearModel()
	gear = equipment
	model = Instance.new("Model")
	model.Name = "FirstPersonLoadout"
	model.Parent = workspace.CurrentCamera
	-- The sword is held low in the right fist, blade angled forward and up:
	-- the hilt and gauntlet low on the right, the tip up and in at about a
	-- third of the way up the screen, clear of the crosshair. Only the gauntlet that grips it shows with it, in its real
	-- place around the hilt; forearm plates and the left glove (behind the
	-- shield) would only be blocks filling the bottom of the view.
	local weapon = equipment:FindFirstChild("Weapon")
	local frame = weapon and weaponFrame(weapon)
	local hold = CFrame.Angles(0, 0, math.rad(-14)) * CFrame.Angles(math.rad(-40), 0, 0)
	-- (Facing set as yaw then pitch: its face turned 28 degrees out to the
	-- left and tipped a little down at rest; square ahead when raised.)
	-- At rest it fills the lower-left (its point running off the bottom);
	-- raised, it moves across the centre line to protect the chest.
	shieldRest = CFrame.new(-1.2, -0.62, -1.85)
		* CFrame.Angles(0, math.rad(28), 0)
		* CFrame.Angles(math.rad(-6), 0, math.rad(-10))
	-- Square the shield toward incoming blows; its upper edge leaves sight over it.
	shieldRaised = CFrame.new(-0.18, -0.3, -1.95)
		* CFrame.Angles(0, math.rad(8), 0)
		* CFrame.Angles(math.rad(-5), 0, math.rad(-3))
	for _, slot in { "Weapon", "Shield", "Gloves" } do
		local source = equipment:FindFirstChild(slot)
		if source then
			-- Each piece in its own model, wearing its gem's highlight (element
			-- colour, bolder the rarer the gem) just as others see it.
			local holder = Instance.new("Model")
			holder.Name = slot
			holder.Parent = model
			local highlight = source:FindFirstChild("GemHighlight")
			if highlight then
				highlight:Clone().Parent = holder
			end
			if slot == "Shield" then
				for _, piece in buildViewShield(holder, source) do
					table.insert(pieces, piece)
				end
				continue
			end
			local builtInShield = false
			for _, part in source:GetDescendants() do
				if part:IsA("BasePart") and authoredTransparency(part) < 1 then
					local weld = part:FindFirstChildWhichIsA("WeldConstraint")
					local anchor = weld and weld.Part0
					local anchorName = anchor and anchor.Name or ""
					if slot == "Gloves" then
						-- Only the right hand's gauntlet, held with the sword.
						if character:GetAttribute("CombatWeaponType") == "TwinBlades" and anchorName == "LeftHand" then
							local copy = viewCopy(part, holder)
							table.insert(
								pieces,
								{ Part = copy, Left = true, Offset = scaled(anchor.CFrame:ToObjectSpace(part.CFrame)) }
							)
						elseif frame and character:GetAttribute("WeaponBlock") and anchorName == "LeftHand" then
							local copy = viewCopy(part, holder)
							local offset = hold
								* CFrame.new(0, 0.6, 0)
								* scaled(anchor.CFrame:ToObjectSpace(part.CFrame))
							table.insert(pieces, { Part = copy, Left = false, Support = true, Offset = offset })
						elseif frame and (anchorName == "RightHand" or anchorName == "RightGrip") then
							local copy = viewCopy(part, holder)
							local offset = hold * scaled(frame:ToObjectSpace(part.CFrame))
							table.insert(pieces, { Part = copy, Left = false, Offset = offset })
						end
					elseif slot == "Weapon" and (anchorName == "LeftLowerArm" or anchorName == "Left Arm") then
						-- A shield built into the weapon's look (Sword and Shield)
						-- rides the forearm: shown as the view's shield below, never
						-- copied up against the camera.
						builtInShield = true
					elseif slot == "Weapon" and frame and not string.find(anchorName, "Left") then
						local copy = viewCopy(part, holder)
						local offset = hold * scaled(frame:ToObjectSpace(part.CFrame))
						table.insert(pieces, { Part = copy, Left = false, Offset = offset })
					else
						local left = slot == "Shield" or string.find(anchorName, "Left") ~= nil
						anchor = anchor
							or source:FindFirstChild("RightGrip")
							or character:FindFirstChild("RightHand")
							or character:FindFirstChild("Right Arm")
						if anchor then
							local copy = viewCopy(part, holder)
							local offset = scaled(anchor.CFrame:ToObjectSpace(part.CFrame))
							if slot == "Shield" then
								-- On the real arm the shield faces out to the side; held
								-- up in view it turns to face the enemy ahead.
								offset = CFrame.Angles(0, math.rad(-70), 0) * offset
							end
							table.insert(pieces, { Part = copy, Left = left, Offset = offset })
						end
					end
				end
			end
			if builtInShield and not hasVisibleParts(equipment:FindFirstChild("Shield")) then
				for _, piece in buildViewShield(holder, source, true) do
					table.insert(pieces, piece)
				end
			end
		end
	end
end
function View.setPose(blocking, progress)
	raised = if blocking then 1 else 0
	charge = math.clamp(progress or 0, 0, 1)
end
-- `heavy`: a charged blow, a bigger overhead chop.
function View.swing(side, heavy)
	swingAt, swingSide, swingHeavy = os.clock(), side or "Right", heavy == true
end

local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
-- The weapon in view, keyframed (camera space). At rest it's held low on
-- the right, blade up and a little forward; charging a heavy draws it up
-- and back over the shoulder.
-- (Built on first use: CFrame isn't touched while the module loads.)
local REST, RAISED, SWINGS
local function keyframes()
	if SWINGS then
		return
	end
	REST = CFrame.new(0.83, -0.78, -1.25) * CFrame.Angles(0, 0, math.rad(12))
	RAISED = CFrame.new(0.62, -0.2, -1.1) * CFrame.Angles(math.rad(38), math.rad(-8), math.rad(-6))
	local function pose(x, y, z, pitch, yaw, roll)
		return CFrame.new(x, y, z) * CFrame.Angles(math.rad(pitch), math.rad(yaw), math.rad(roll))
	end
	-- A swing: { time, pose } keys, eased from one to the next. A light cut
	-- winds up over the shoulder, cuts across the middle of the view with the
	-- tip leading, follows through low on the far side and comes back; the
	-- backhand mirrors it. A heavy starts from the raised charge and chops
	-- straight down through the centre.
	SWINGS = {
		Right = {
			{ 0, REST },
			{ 0.07, pose(1.12, -0.48, -1.12, 12, -16, -28) },
			{ 0.15, pose(0.1, -0.42, -1.45, -16, 18, 58) },
			{ 0.23, pose(-0.25, -0.66, -1.4, -24, 18, 72) },
			{ 0.46, REST },
		},
		Left = {
			{ 0, REST },
			{ 0.07, pose(-0.22, -0.42, -1.18, 10, 18, 62) },
			{ 0.15, pose(0.68, -0.55, -1.45, -18, -18, -52) },
			{ 0.23, pose(1.0, -0.72, -1.4, -26, -18, -70) },
			{ 0.46, REST },
		},
		Heavy = {
			{ 0, RAISED },
			{ 0.05, RAISED * CFrame.new(0, 0.06, 0.05) * CFrame.Angles(math.rad(8), 0, 0) },
			{ 0.12, pose(0.3, 0.0, -1.25, 12, -4, 14) },
			{ 0.21, pose(0.2, -0.55, -1.2, -36, 0, 22) },
			{ 0.34, pose(0.26, -0.78, -1.2, -48, 4, 26) },
			{ 0.62, REST },
		},
	}
end
-- The pose `e` seconds into a swing (nil once it's over). Into the hit it
-- snaps (fast, slowing into the blow); everywhere else it eases.
local function sample(keys, e)
	if e <= 0 or e >= keys[#keys][1] then
		return nil
	end
	for i = 2, #keys do
		if e <= keys[i][1] then
			local a, b = keys[i - 1], keys[i]
			local p = (e - a[1]) / (b[1] - a[1])
			local hit = if keys == SWINGS.Heavy then i == 3 or i == 4 else i == 3
			local w = if hit then 1 - (1 - p) ^ 3 else p * p * (3 - 2 * p)
			return a[2]:Lerp(b[2], w)
		end
	end
	return nil
end
-- A reaction's weight `d` seconds after it happens: up fast, then fades.
local function impulse(d, length)
	if type(d) ~= "number" or d < 0 or d >= length then
		return 0
	end
	return if d < 0.05 then d / 0.05 else (1 - (d - 0.05) / (length - 0.05)) ^ 2
end
function View.fire()
	fireAt = os.clock()
end
-- A surge's cast, as everyone else sees your body cast it: the shield
-- lowers, the sword arm draws back and energy gathers into an orb in front
-- of you over `duration`; then it throws forward and bursts. (A cast with no
-- wind-up just throws.)
function View.cast(duration, color, animation)
	castAnimation = animation or "Bolt"
	castAt, castFor, castColor = os.clock(), math.max(0, duration or 0), color or Color3.fromRGB(255, 190, 80)
	if castOrb then
		castOrb:Destroy()
	end
	local orb = Instance.new("Part")
	orb.Name = "CastOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Material = Enum.Material.Neon
	orb.Color = castColor
	orb.Anchored, orb.CanCollide, orb.CanQuery, orb.CanTouch, orb.CastShadow = true, false, false, false, false
	orb.Size = Vector3.new(0.05, 0.05, 0.05)
	orb.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = castColor, 8, 0
	light.Parent = orb
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Color = Color3.new(1, 1, 1)
	core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow = true, false, false, false, false
	core.Size = Vector3.new(0.03, 0.03, 0.03)
	core.Parent = orb
	orb.Parent = workspace.CurrentCamera
	castOrb = orb
end
function View.setCursorFree(value)
	cursorFree = value
end
function View.stop()
	if not saved then
		return
	end
	RunService:UnbindFromRenderStep("SagaFirstPerson")
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if removalConnection then
		removalConnection:Disconnect()
		removalConnection = nil
	end
	clearModel()
	for part, transparency in hidden do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	table.clear(hidden)
	player.CameraMaxZoomDistance = saved.Max
	player.CameraMinZoomDistance = saved.Min
	player.CameraMode = saved.Mode
	UserInputService.MouseBehavior, UserInputService.MouseIconEnabled = saved.Mouse, saved.Icon
	if saved.Camera.Parent then
		saved.Camera.FieldOfView = saved.Fov
	end
	saved = nil
	cursorFree, raised, charge = false, 0, 0
	if castOrb then
		castOrb:Destroy()
		castOrb = nil
	end
	castAt = -10
	fireAt, smoothedRaised, smoothedCharge, swingAt, swingHeavy = -10, 0, 0, -10, false
end
function View.start()
	shownParts, nextShownCheck = -1, 0
	if saved then
		return
	end
	local camera = workspace.CurrentCamera
	saved = {
		Mode = player.CameraMode,
		Min = player.CameraMinZoomDistance,
		Max = player.CameraMaxZoomDistance,
		Camera = camera,
		Fov = camera.FieldOfView,
		Mouse = UserInputService.MouseBehavior,
		Icon = UserInputService.MouseIconEnabled,
	}
	player.CameraMinZoomDistance, player.CameraMaxZoomDistance = 0.5, 0.5
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.FieldOfView = 75
	-- Only a change to the gear's own parts rebuilds the view model: hit
	-- effects, sounds, trails and shields come and go on the character all
	-- fight long, and rebuilding for each of them stuttered.
	local function gearPart(part): boolean
		if not part:IsA("BasePart") then
			return false
		end
		local gearFolder = player.Character and player.Character:FindFirstChild("GemsoulGear")
		return gearFolder ~= nil and part:IsDescendantOf(gearFolder)
	end
	local function track(part)
		if gearPart(part) then
			dirty = true
		end
		if part:IsA("BasePart") and hidden[part] == nil then
			hidden[part] = part.LocalTransparencyModifier
		end
	end
	local character = player.Character
	if character then
		for _, part in character:GetDescendants() do
			track(part)
		end
		connection = character.DescendantAdded:Connect(track)
		removalConnection = character.DescendantRemoving:Connect(function(part)
			if gearPart(part) or part.Name == "GemsoulGear" then
				dirty = true
			end
			if hidden[part] ~= nil then
				part.LocalTransparencyModifier = hidden[part]
				hidden[part] = nil
			end
		end)
	end
	RunService:BindToRenderStep("SagaFirstPerson", Enum.RenderPriority.Camera.Value + 3, function(dt)
		local current = workspace.CurrentCamera
		for part in hidden do
			if part.Parent then
				part.LocalTransparencyModifier = 1
			end
		end
		if UserInputService.MouseEnabled then
			UserInputService.MouseBehavior = if cursorFree
				then Enum.MouseBehavior.Default
				else Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = cursorFree
		end
		local equipment = character and character:FindFirstChild("GemsoulGear")
		-- The server hides and shows gear by its transparency, not by adding or
		-- removing parts (the Outpost puts your weapon away while you mine and
		-- brings it back for a fight), and only parts showing are copied into
		-- view: rebuild whenever that changes, or the sword never comes back.
		if equipment and os.clock() >= nextShownCheck then
			nextShownCheck = os.clock() + 0.25
			local shown = 0
			for _, part in equipment:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					shown += 1
				end
			end
			if shown ~= shownParts then
				shownParts, dirty = shown, true
			end
		end
		if equipment and (dirty or equipment ~= gear or not model or model.Parent ~= current) then
			rebuild(character, equipment)
			dirty = false
		end
		if not equipment and model then
			clearModel()
		end
		local swingElapsed = os.clock() - swingAt
		-- How far a swing is under way (0..1..0): the shield leans into it.
		local swingPose, swingWeight = nil, 0
		if #pieces > 0 then
			keyframes()
			local swingKeys = if swingHeavy
				then SWINGS.Heavy
				elseif swingSide == "Left" then SWINGS.Left
				else SWINGS.Right
			swingPose = sample(swingKeys, swingElapsed)
			if swingPose then
				swingWeight = math.sin(math.clamp(swingElapsed / swingKeys[#swingKeys][1], 0, 1) * math.pi)
			end
		end
		local breathe = math.sin(os.clock() * 2) * 0.012
		-- Walking bobs the arms; a blow on your shield knocks it back; a hit
		-- that gets through jolts the whole view (server-set, see RivalPose).
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local moving = if humanoid then math.clamp(humanoid.MoveDirection.Magnitude, 0, 1) else 0
		local bobY = math.abs(math.sin(os.clock() * 8)) * 0.035 * moving
		local bobX = math.sin(os.clock() * 4) * 0.025 * moving
		local serverNow = workspace:GetServerTimeNow()
		local insertionStart = character and character:GetAttribute("ArenaDropStart")
		local insertionUntil = player:GetAttribute("ArenaDropUntil")
		local insertion = if type(insertionStart) == "number"
				and type(insertionUntil) == "number"
				and insertionUntil > serverNow
			then Motion.sample(serverNow - insertionStart, character:GetAttribute("ArenaDropReleaseDelay") or 0)
			else nil
		local draw = if insertion then 1 - insertion.Draw else 0
		local insertionPose = if #pieces > 0
			then CFrame.new(0, -0.85 * draw, 0.35 * draw) * CFrame.Angles(-0.3 * draw, 0, 0)
			else nil
		local blockedAt = character and character:GetAttribute("BlockedAt")
		local hurtAt = character and character:GetAttribute("HurtAt")
		local jolt = impulse(if type(blockedAt) == "number" then serverNow - blockedAt else nil, 0.24)
		local hurt = impulse(if type(hurtAt) == "number" then serverNow - hurtAt else nil, 0.3)
		local hurtSide = if character and character:GetAttribute("HurtSide") == -1 then -1 else 1
		-- A charged heavy strains: the blade trembles near full charge.
		local strain = if smoothedCharge > 0.8 then math.sin(os.clock() * 50) * 0.006 else 0
		local flinch = if #pieces > 0
			then CFrame.new(0.05 * hurtSide * hurt + bobX, -0.1 * hurt - bobY, 0.14 * hurt) * CFrame.Angles(
				math.rad(-7 * hurt),
				0,
				math.rad(6 * hurtSide * hurt)
			)
			else nil
		smoothedRaised += (raised - smoothedRaised) * (1 - math.exp(-(dt or 1 / 60) * 18))
		smoothedCharge += (charge - smoothedCharge) * (1 - math.exp(-(dt or 1 / 60) * 22))
		local fireElapsed = os.clock() - fireAt
		local recoil = if fireElapsed >= 0 and fireElapsed < 0.24
			then math.sin(math.min(1, fireElapsed / 0.045) * math.pi / 2) * math.exp(-fireElapsed * 16)
			else 0
		-- Casting: `gather` builds 0..1 over the wind-up, `throw` snaps
		-- forward and fades after it.
		local castElapsed = os.clock() - castAt
		local gather = if castFor > 0 then math.clamp(castElapsed / castFor, 0, 1) else 1
		local after = castElapsed - castFor
		local release = if castAnimation == "Nova" or castAnimation == "Erupt" then 0.1 else 0.085
		local throw = if after >= 0 and after < release
			then ease(after / release)
			elseif after >= release and after < 0.18 then 1
			elseif after >= 0.18 and after < 0.46 then 1 - ease((after - 0.18) / 0.28)
			else 0
		-- Retain the gathered pose at release, then blend into the strike: no pop to idle.
		local casting = if castElapsed >= 0 and after < 0
			then math.sin(gather * math.pi / 2)
			elseif after >= 0 and after < release and castFor > 0 then 1 - ease(after / release)
			else 0
		local castPose = casting + throw
		if castOrb then
			if after >= 0.3 then
				castOrb:Destroy()
				castOrb = nil
			else
				-- Gathers low in front, pulsing; flies out and swells as it bursts.
				local pulse = 1 + math.sin(os.clock() * 28) * 0.08
				local size = if after < 0 then (0.08 + gather * 0.32) * pulse else 0.4 + after * 3.2
				local fade = if after < 0 then 0.15 else math.clamp(0.15 + after / 0.3, 0, 1)
				local at = current.CFrame * CFrame.new(-0.05, -0.42 + gather * 0.06, -1.6 - math.max(0, after) * 9)
				castOrb.Size = Vector3.new(size, size, size)
				castOrb.Transparency = fade
				castOrb.CFrame = at
				local core = castOrb:FindFirstChild("Core") :: BasePart?
				if core then
					core.Size = castOrb.Size * 0.55
					core.Transparency = fade
					core.CFrame = at
				end
				local light = castOrb:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = (1 - fade) * (if after < 0 then 1 + gather * 2 else 4)
				end
			end
		end
		for _, piece in pieces do
			local pose = if piece.Shield
				-- (A swing dips the shield down and out of the blade's way.)
				then CFrame.new(-0.2 * swingWeight, -0.32 * swingWeight, 0.04 * swingWeight) * shieldRest:Lerp(
					shieldRaised,
					smoothedRaised
				) * CFrame.new(-0.25 * castPose + 0.05 * jolt, -0.3 * castPose + breathe - 0.08 * jolt, 0.28 * jolt) * CFrame.Angles(
					math.rad(14 * jolt),
					0,
					math.rad(8 * swingWeight)
				)
				elseif piece.Left then CFrame.new(
					-0.72 + smoothedRaised * 0.4,
					-0.8 + smoothedRaised * 0.45 + breathe,
					-1.35
				) * CFrame.Angles(0, 0, math.rad(-12 + smoothedRaised * 25))
				else CFrame.new(
					casting * 0.12 - throw * 0.2 + strain,
					breathe + casting * 0.08,
					recoil * 0.18 + casting * 0.2 - throw * 0.35
				) * (swingPose or REST:Lerp(RAISED, ease(smoothedCharge))) * CFrame.Angles(
					math.rad(-recoil * 9 + casting * 14 - throw * 22 + strain * 300),
					0,
					0
				)
			-- Tuck the weapon and its gauntlet below the shield during a shield guard.
			-- Weapon-only guards below retain their raised two-hand bracing pose.
			if not piece.Shield and not piece.Left and character and not character:GetAttribute("WeaponBlock") then
				local lowered = CFrame.new(1.02, -1.3 + breathe, -1.12)
					* CFrame.Angles(math.rad(-32), math.rad(12), math.rad(28))
				pose = pose:Lerp(lowered, smoothedRaised)
			end
			if character and character:GetAttribute("WeaponBlock") and not piece.Shield then
				local kind = character:GetAttribute("CombatWeaponType")
				local twin = kind == "TwinBlades"
				local side = if piece.Left then -1 else 1
				local weaponGuard = if twin
					then CFrame.new(side * 0.35, -0.28, -1.55) * CFrame.Angles(math.rad(-12), 0, math.rad(-side * 42))
					else CFrame.new(0.35, -0.28, -1.65) * CFrame.Angles(
						math.rad(-12),
						0,
						math.rad(if kind == "Lance" then 72 else 62)
					)
				pose = pose:Lerp(weaponGuard, smoothedRaised)
					* CFrame.new(0, -0.06 * jolt * smoothedRaised, 0.22 * jolt * smoothedRaised)
					* CFrame.Angles(math.rad(10 * jolt * smoothedRaised), 0, 0)
			end
			if castAnimation and castPose > 0 then
				local side = if piece.Left or piece.Shield then -1 else 1
				local motion = CFrame.new()
				if castAnimation == "Bolt" then
					motion = CFrame.new(
						side * 0.18 * casting,
						0.14 * casting - 0.08 * throw,
						0.3 * casting - 0.55 * throw
					) * CFrame.Angles(
						-0.2 * casting + 0.2 * throw,
						side * (0.2 * casting - 0.15 * throw),
						side * 0.18 * casting
					)
				elseif castAnimation == "Buff" then
					motion = CFrame.new(
						-side * 0.15 * casting + side * 0.2 * throw,
						0.12 * casting + 0.3 * throw,
						-0.15 * throw
					) * CFrame.Angles(-0.18 * throw, 0, side * (0.2 * casting - 0.3 * throw))
				elseif castAnimation == "Drill" then
					motion = CFrame.new(0.1 * side * casting, 0.08 * casting, 0.25 * casting - 0.7 * throw)
						* CFrame.Angles(0, 0, side * (casting * 0.3 - throw * 0.2))
				elseif castAnimation == "Sweep" then
					motion = CFrame.new(side * 0.3 * casting - 0.8 * throw, 0.12 * castPose, -0.2 * throw)
						* CFrame.Angles(0, 0.45 * casting - 0.7 * throw, -0.35 * throw)
				elseif castAnimation == "Erupt" or castAnimation == "Nova" then
					motion = CFrame.new(0, 0.52 * casting - 0.68 * throw, -0.18 * throw)
						* CFrame.Angles(-0.4 * casting + 0.6 * throw, 0, side * 0.12 * castPose)
				elseif castAnimation == "Cross" then
					motion = CFrame.new(-side * 0.28 * casting + side * 0.3 * throw, 0.22 * castPose, -0.38 * throw)
						* CFrame.Angles(0, 0, side * (0.45 * casting - 0.5 * throw))
				end
				pose = motion * pose
			end
			piece.Part.CFrame = current.CFrame * insertionPose * flinch * pose * piece.Offset
		end
	end)
end
return View
