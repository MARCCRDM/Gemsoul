--[[
	Swing trails on the real blades: every fighter's weapon (players and
	rivals) and your own first-person sword leave a streak while the blade
	is moving fast, so a swing reads as a cut instead of a pose. The streak
	takes the weapon's enchantment colour (its gem's outline), else a pale
	steel white. Purely local; the server never sees it.

	A fighter's blow also leaves the slash itself (CombatVfx.cut): a glowing
	band traced along the blade's real path through the cut, frame by frame,
	so the slash always sits where the sword went, for the rival and every
	player alike (the swing effect at the server's aim used to sweep its own
	arc, at its own height, whichever way the body swung).

	  BladeTrails.bladeOf(weapon)  the blade part: the weapon's longest piece
	  BladeTrails.speedOn(speed)   pure: whether a blade tip moving at
	    `speed` studs per second should streak
	  BladeTrails.cutsAt(position) whether a fighter standing at `position`
	    draws its own slash (a visible blade): the swing effect skips its arc
	  BladeTrails.start()          scans twice a second, steps every frame
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RivalPose = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RivalPose"))

local CombatVfx = require(script.Parent.CombatVfx)

local BladeTrails = {}

-- Studs per second at the tip, measured against the body (or the camera for
-- your first-person sword), before it streaks: walking never does.
BladeTrails.Threshold = 18
BladeTrails.ViewThreshold = 7
-- Tip speed (studs per second, against the body) through a blow (while
-- RivalPose has it striking) that draws the slash.
BladeTrails.CutThreshold = 40
local STEEL = Color3.fromRGB(225, 236, 248)

function BladeTrails.speedOn(speed: number, viewModel: boolean?): boolean
	return speed >= (if viewModel then BladeTrails.ViewThreshold else BladeTrails.Threshold)
end

-- The longest visible part of a weapon model: its blade.
function BladeTrails.bladeOf(weapon: Instance): BasePart?
	local best, length = nil, 0
	for _, part in weapon:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 0.9 and part.Name ~= "SocketedGem" then
			local size = part.Size
			local longest = math.max(size.X, size.Y, size.Z)
			if longest > length then
				best, length = part, longest
			end
		end
	end
	return if length >= 0.8 then best else nil
end

-- [blade] = { Trail, Tip, Inner, Last, ViewModel, Weapon, Root, Color, Path }
local tracked = {}

local function colorOf(weapon: Instance): Color3
	local highlight = weapon:FindFirstChild("GemHighlight")
	if highlight and highlight:IsA("Highlight") then
		return highlight.OutlineColor
	end
	return STEEL
end

local function attach(blade: BasePart, weapon: Instance, viewModel: boolean, root: BasePart?)
	if tracked[blade] then
		return
	end
	-- Attachments at the two ends of the blade's long axis.
	local size = blade.Size
	local axis = if size.Y >= size.X and size.Y >= size.Z
		then Vector3.new(0, 1, 0)
		elseif size.X >= size.Z then Vector3.new(1, 0, 0)
		else Vector3.new(0, 0, 1)
	local half = math.max(size.X, size.Y, size.Z) / 2
	local base, tip = Instance.new("Attachment"), Instance.new("Attachment")
	base.Name, tip.Name = "TrailBase", "TrailTip"
	base.Position, tip.Position = -axis * half * 0.55, axis * half
	base.Parent, tip.Parent = blade, blade
	-- The slash band runs from here (near the middle of the blade) to the tip.
	local inner = Instance.new("Attachment")
	inner.Name = "CutInner"
	inner.Position = -axis * half * 0.1
	inner.Parent = blade
	local color = colorOf(weapon)
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0, trail.Attachment1 = base, tip
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.4, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = if viewModel then 0.12 else 0.16
	trail.MinLength = 0.05
	trail.LightEmission = 0.7
	trail.LightInfluence = 0.2
	trail.WidthScale = NumberSequence.new(1, 0.3)
	trail.Enabled = false
	trail.Parent = blade
	tracked[blade] = {
		Trail = trail,
		Tip = tip,
		Inner = inner,
		Last = nil,
		ViewModel = viewModel,
		Weapon = weapon,
		Root = root,
		Color = color,
		Path = {},
	}
end

-- A point on the smooth curve through four samples (Catmull-Rom), between
-- the middle two: the blade moves a long way between frames in a blow, and
-- straight pieces would show the corners.
function BladeTrails.curve(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

-- Draws the stretch of slash between the last frame and this one.
local function traceCut(entry, tip: Vector3, inner: Vector3, heavy: boolean)
	local path = entry.Path
	local last = path[#path]
	if not last then
		return
	end
	local before = path[#path - 1] or last
	-- Ahead of this frame: carry on the way it was going.
	local aheadTip, aheadInner = tip + (tip - last.Tip), inner + (inner - last.Inner)
	local steps = math.clamp(math.ceil((tip - last.Tip).Magnitude / 0.7), 1, 5)
	local fromTip, fromInner = last.Tip, last.Inner
	for i = 1, steps do
		local t = i / steps
		local toTip = BladeTrails.curve(before.Tip, last.Tip, tip, aheadTip, t)
		local toInner = BladeTrails.curve(before.Inner, last.Inner, inner, aheadInner, t)
		CombatVfx.cut(fromTip, toTip, fromInner, toInner, entry.Color, heavy)
		fromTip, fromInner = toTip, toInner
	end
end

-- Whether a fighter at `position` (its root) has a visible blade drawing its
-- own slash.
function BladeTrails.cutsAt(position: Vector3): boolean
	for blade, entry in tracked do
		local root = entry.Root
		if
			not entry.ViewModel
			and root
			and root.Parent
			and blade.LocalTransparencyModifier <= 0.5
			and (root.Position - position).Magnitude < 4
		then
			return true
		end
	end
	return false
end

local function scan()
	local found = {}
	local function weaponsIn(model: Instance?)
		local gear = model and model:FindFirstChild("GemsoulGear")
		local weapon = gear and gear:FindFirstChild("Weapon")
		if weapon then
			local blade = BladeTrails.bladeOf(weapon)
			if blade then
				attach(blade, weapon, false, model:FindFirstChild("HumanoidRootPart") :: BasePart?)
				found[blade] = true
			end
		end
	end
	for _, other in Players:GetPlayers() do
		weaponsIn(other.Character)
	end
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		weaponsIn(model)
	end
	-- Your first-person sword (built under the camera).
	local camera = workspace.CurrentCamera
	local view = camera and camera:FindFirstChild("FirstPersonLoadout")
	local viewWeapon = view and view:FindFirstChild("Weapon")
	if viewWeapon then
		local blade = BladeTrails.bladeOf(viewWeapon)
		if blade then
			attach(blade, viewWeapon, true)
			found[blade] = true
		end
	end
	for blade, entry in tracked do
		if not found[blade] or not blade.Parent then
			entry.Trail:Destroy()
			tracked[blade] = nil
		end
	end
end

local started = false
function BladeTrails.start()
	if started then
		return
	end
	started = true
	local nextScan = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 0.5
			scan()
		end
		local camera = workspace.CurrentCamera
		if not camera or dt <= 0 then
			return
		end
		for blade, entry in tracked do
			-- The view-model sword moves with the camera: measure it in camera
			-- space so turning your head doesn't streak it.
			local tip = entry.Tip.WorldPosition
			local frame = if entry.ViewModel then camera.CFrame elseif entry.Root then entry.Root.CFrame else nil
			local at = if frame then frame:PointToObjectSpace(tip) else tip
			local speed = if entry.Last then (at - entry.Last).Magnitude / dt else 0
			entry.Last = at
			-- Your own third-person weapon is hidden in first person.
			local hidden = not entry.ViewModel and blade.LocalTransparencyModifier > 0.5
			entry.Trail.Enabled = not hidden and BladeTrails.speedOn(speed, entry.ViewModel)
			-- The blow itself: the slash, traced along where the blade went.
			if not entry.ViewModel then
				local tipAt, innerAt = tip, entry.Inner.WorldPosition
				local body = entry.Root and entry.Root.Parent
				if
					not hidden
					and speed >= BladeTrails.CutThreshold
					and body
					and body:IsA("Model")
					and RivalPose.striking(body)
				then
					traceCut(entry, tipAt, innerAt, body ~= nil and body:GetAttribute("ActionKind") == "Heavy")
				end
				local path = entry.Path
				table.insert(path, { Tip = tipAt, Inner = innerAt })
				if #path > 2 then
					table.remove(path, 1)
				end
			end
		end
	end)
end

return BladeTrails
