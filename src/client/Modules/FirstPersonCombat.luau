-- Local camera presentation only; the real equipped geometry and all damage stay on the server.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local View = {}
local saved, model, gear, connection, removalConnection
local pieces, hidden = {}, {}
local raised, charge, swingAt, swingSide = 0, 0, -10, "Right"
local cursorFree = false
local fireAt, smoothedRaised, smoothedCharge = -10, 0, 0
local dirty = true
local function clearModel()
	if model then
		model:Destroy()
	end
	model, gear = nil, nil
	table.clear(pieces)
end
-- A copy of one piece of gear for the view: its element effects thinned out
-- (they'd cover the view up close), anchored, unclickable, 65% size.
local function viewCopy(part, holder, scale: number?)
	local copy = part:Clone()
	for _, descendant in copy:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Rate *= 0.45
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
local function buildViewShield(holder, source)
	local pieces = {}
	-- Its metal: the worn shield's largest metal-looking plate, else steel;
	-- its glow: the gem's highlight colour, else its trim, else teal.
	local metal, area = Color3.fromRGB(150, 156, 166), 0
	local glow
	local emitters = {}
	for _, part in source:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "SocketedGem" then
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
	for _, emitter in emitters do
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
		if part:IsA("BasePart") and part.Transparency < 1 and part.Size.Y > length then
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
	-- raised, it covers the left half, short of the centre line.
	shieldRest = CFrame.new(-1.2, -0.62, -1.85)
		* CFrame.Angles(0, math.rad(28), 0)
		* CFrame.Angles(math.rad(-6), 0, math.rad(-10))
	-- Raised it stays angled (turned 25 degrees, tipped back) so it reads as
	-- a shield held up, not a wall, and keeps the centre of the view clear.
	shieldRaised = CFrame.new(-0.72, -0.25, -1.95)
		* CFrame.Angles(0, math.rad(25), 0)
		* CFrame.Angles(math.rad(-10), 0, math.rad(-10))
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
			for _, part in source:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					local weld = part:FindFirstChildWhichIsA("WeldConstraint")
					local anchor = weld and weld.Part0
					local anchorName = anchor and anchor.Name or ""
					if slot == "Gloves" then
						-- Only the right hand's gauntlet, held with the sword.
						if frame and (anchorName == "RightHand" or anchorName == "RightGrip") then
							local copy = viewCopy(part, holder)
							local offset = hold * scaled(frame:ToObjectSpace(part.CFrame))
							table.insert(pieces, { Part = copy, Left = false, Offset = offset })
						end
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
		end
	end
end
function View.setPose(blocking, progress)
	raised = if blocking then 1 else 0
	charge = math.clamp(progress or 0, 0, 1)
end
function View.swing(side)
	swingAt, swingSide = os.clock(), side or "Right"
end
function View.fire()
	fireAt = os.clock()
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
	fireAt, smoothedRaised, smoothedCharge, swingAt = -10, 0, 0, -10
end
function View.start()
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
	local function track(part)
		dirty = true
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
			dirty = true
			if hidden[part] ~= nil then
				part.LocalTransparencyModifier = hidden[part]
				hidden[part] = nil
			end
		end)
	end
	RunService:BindToRenderStep("SagaFirstPerson", Enum.RenderPriority.Camera.Value + 2, function(dt)
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
		if equipment and (dirty or equipment ~= gear or not model or model.Parent ~= current) then
			rebuild(character, equipment)
			dirty = false
		end
		if not equipment and model then
			clearModel()
		end
		local elapsed = os.clock() - swingAt
		local swing = if elapsed >= 0 and elapsed < 0.34 then math.sin(elapsed / 0.34 * math.pi) else 0
		local direction = if swingSide == "Left" then -1 else 1
		local breathe = math.sin(os.clock() * 2) * 0.012
		smoothedRaised += (raised - smoothedRaised) * (1 - math.exp(-(dt or 1 / 60) * 18))
		smoothedCharge += (charge - smoothedCharge) * (1 - math.exp(-(dt or 1 / 60) * 22))
		local fireElapsed = os.clock() - fireAt
		local recoil = if fireElapsed >= 0 and fireElapsed < 0.24
			then math.sin(math.min(1, fireElapsed / 0.045) * math.pi / 2) * math.exp(-fireElapsed * 16)
			else 0
		for _, piece in pieces do
			local pose = if piece.Shield
				then shieldRest:Lerp(shieldRaised, smoothedRaised) * CFrame.new(0, breathe, 0)
				elseif piece.Left then CFrame.new(
					-0.72 + smoothedRaised * 0.4,
					-0.8 + smoothedRaised * 0.45 + breathe,
					-1.35
				) * CFrame.Angles(0, 0, math.rad(-12 + smoothedRaised * 25))
				else CFrame.new(
					0.83 - swing * direction * 0.85,
					-0.78 + smoothedCharge * 0.18 + breathe,
					-1.25 - swing * 0.35 + recoil * 0.18
				) * CFrame.Angles(
					math.rad(-smoothedCharge * 15 - recoil * 9),
					0,
					math.rad(12 + smoothedCharge * 20 - swing * direction * 85)
				)
			piece.Part.CFrame = current.CFrame * pose * piece.Offset
		end
	end)
end
return View
