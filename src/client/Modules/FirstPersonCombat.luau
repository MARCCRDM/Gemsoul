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
-- The shield's own frame: its main board (the broadest flat piece), whose -Z
-- is the shield's face.
local function shieldFrame(shield)
	local board, area = nil, 0
	for _, part in shield:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Size.Z < math.min(part.Size.X, part.Size.Y) then
			if part.Size.X * part.Size.Y > area then
				board, area = part, part.Size.X * part.Size.Y
			end
		end
	end
	return board and board.CFrame
end
-- In view the shield is smaller than the sword, and has a back worth seeing:
-- a leather arm strap and grip (the real shield's back is a plain board).
local SHIELD_SCALE = 0.5
local function shieldBack(holder, board)
	local pieces = {}
	local half = board.Size.Z / 2
	for _, spec in
		{
			{ Vector3.new(0.16, 0.95, 0.14), Vector3.new(0, -0.05, half + 0.07) }, -- grip
			{ Vector3.new(1.0, 0.16, 0.06), Vector3.new(0, 0.42, half + 0.03) }, -- arm strap
			{ Vector3.new(1.0, 0.16, 0.06), Vector3.new(0, -0.5, half + 0.03) }, -- arm strap
		}
	do
		local part = Instance.new("Part")
		part.Name = "ShieldStrap"
		part.Material = Enum.Material.Leather
		part.Color = Color3.fromRGB(92, 62, 40) -- leather
		part.Size = spec[1] * SHIELD_SCALE
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
		part.Parent = holder
		table.insert(pieces, { Part = part, Shield = true, Offset = CFrame.new(spec[2] * SHIELD_SCALE) })
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
	local shieldSource = equipment:FindFirstChild("Shield")
	local board = shieldSource and shieldFrame(shieldSource)
	-- (Facing set as yaw then pitch: its face turned 30 degrees out to the
	-- left and tipped a little down at rest; square ahead when raised.)
	shieldRest = CFrame.new(-1.25, -0.82, -1.9)
		* CFrame.Angles(0, math.rad(30), 0)
		* CFrame.Angles(math.rad(-7), 0, math.rad(-8))
	shieldRaised = CFrame.new(-0.55, -0.32, -1.6) * CFrame.Angles(0, math.rad(4), 0)
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
			if slot == "Shield" and board then
				local boardPart
				for _, part in source:GetDescendants() do
					if part:IsA("BasePart") and part.CFrame == board then
						boardPart = part
					end
				end
				for _, strap in shieldBack(holder, boardPart or { Size = Vector3.new(1, 1, 0.22) }) do
					table.insert(pieces, strap)
				end
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
					elseif slot == "Shield" and board then
						local copy = viewCopy(part, holder, SHIELD_SCALE)
						local offset = scaled(board:ToObjectSpace(part.CFrame), SHIELD_SCALE)
						table.insert(pieces, { Part = copy, Shield = true, Offset = offset })
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
