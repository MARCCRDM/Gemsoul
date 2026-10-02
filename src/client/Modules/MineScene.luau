--[[
	The 3D side of an expedition (menu-only mode): while the Mine is open the
	camera flies to the terraformed mining site (Scenes.miningSite) and your
	miner stands at the crystal cliff, wearing your gear.

	Every strike swaps the weapon for the mining laser: the arm comes up, a
	beam cuts into the rock with sparks and a flash, then the laser is put
	away and the weapon comes back.

	MineScene.enter() / MineScene.leave()   fly in and out
	MineScene.strike(color?)                 one laser shot (color: a gem's glow)
	MineScene.isActive()                     for the menu camera
	Everything here is built on the client; nobody else sees it.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Scenes = require(script.Parent.Scenes)

local player = Players.LocalPlayer

local MineScene = {}

local SITE_AT = CFrame.new(3000, 300, 0)
local LASER = Color3.fromRGB(90, 210, 255)
local GUN_HOLD = 0.7 -- seconds the laser stays out after the last strike

local active = false
local site: Scenes.Site? = nil
local miner: Model? = nil
local shoulder: Motor6D? = nil
local weaponParts: { [BasePart]: number } = {}
local gunParts: { BasePart } = {}
local muzzle: BasePart? = nil
local gunUntil = 0
local aim = 0 -- 0 = arm down, 1 = aiming
local shake = 0
local hiddenGui: ScreenGui? = nil
local started = 0

function MineScene.isActive(): boolean
	return active
end

local function tween(object: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

-- Shows the laser and hides the weapon, or the other way round.
local function holdLaser(on: boolean)
	for part, transparency in weaponParts do
		if part.Parent then
			part.Transparency = if on then 1 else transparency
		end
	end
	for _, part in gunParts do
		part.Transparency = if on then 0 else 1
	end
end

-- A copy of your character, gear and all, standing at the cliff.
local function placeMiner()
	local character = player.Character
	local s = site
	if not character or not s then
		return
	end
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = false
	if not copy then
		return
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("Animator") then
			d:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		copy:Destroy()
		return
	end
	-- Stand on the ground: lift by the root's height above the feet.
	local lowest = math.huge
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
		end
	end
	local rise = if lowest < math.huge then root.Position.Y - lowest else 3
	root.Anchored = true
	copy:PivotTo(s.Stand * CFrame.new(0, rise, 0))
	copy.Parent = workspace

	-- The weapon (put away while the laser is out) and the right shoulder.
	weaponParts = {}
	local gear = copy:FindFirstChild("GemsoulGear")
	local weapon = gear and gear:FindFirstChild("Weapon")
	for _, d in (weapon and weapon:GetDescendants() or {}) do
		if d:IsA("BasePart") then
			weaponParts[d] = d.Transparency
		end
	end
	local upperArm = copy:FindFirstChild("RightUpperArm")
	shoulder = upperArm and upperArm:FindFirstChild("RightShoulder") :: Motor6D?
	local hand = copy:FindFirstChild("RightHand") :: BasePart?
	gunParts, muzzle = {}, nil
	if hand then
		gunParts, muzzle = Scenes.miningGun(hand, LASER)
	end
	miner = copy
	holdLaser(false)
end

function MineScene.enter()
	if active then
		return
	end
	active = true
	started = os.clock()
	if not site then
		site = Scenes.miningSite(SITE_AT)
	end
	Scenes.terraformLighting()
	placeMiner()
	-- The dashboard's backdrop would hide the scene; put it away while mining.
	local dashboard = player.PlayerGui:FindFirstChild("Dashboard")
	if dashboard and dashboard:IsA("ScreenGui") and dashboard.Enabled then
		dashboard.Enabled = false
		hiddenGui = dashboard
	end
end

function MineScene.leave()
	if not active then
		return
	end
	active = false
	if miner then
		miner:Destroy()
		miner = nil
	end
	shoulder, muzzle = nil, nil
	weaponParts, gunParts = {}, {}
	aim, gunUntil = 0, 0
	Scenes.spaceLighting()
	if hiddenGui then
		hiddenGui.Enabled = true
		hiddenGui = nil
	end
end

-- One shot of the mining laser into the cliff.
function MineScene.strike(color: Color3?)
	local s = site
	if not active or not s or not miner then
		return
	end
	gunUntil = os.clock() + GUN_HOLD
	holdLaser(true)
	local glow = color or LASER
	-- A spot on the working face.
	local target = (s.Face * CFrame.new((math.random() - 0.5) * s.FaceSize.X, (math.random() - 0.5) * s.FaceSize.Y, 0)).Position
	task.delay(0.08, function()
		local from = if muzzle and muzzle.Parent then muzzle.Position else target + Vector3.new(0, 0, 6)
		local length = (target - from).Magnitude
		local beam = Scenes.part(
			workspace,
			CFrame.lookAt((from + target) / 2, target),
			Vector3.new(0.22, 0.22, length),
			glow,
			Enum.Material.Neon
		)
		beam.CastShadow = false
		tween(beam, 0.28, { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) })
		-- The hit: a flash, a burst of sparks and a chip of rock.
		local flash = Scenes.part(workspace, CFrame.new(target), Vector3.one * 1.2, glow, Enum.Material.Neon, "Ball")
		flash.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = 14
		light.Brightness = 4
		light.Parent = flash
		tween(flash, 0.35, { Transparency = 1, Size = Vector3.one * 3 })
		tween(light, 0.35, { Brightness = 0 })
		local normal = s.Face.LookVector
		for _ = 1, 8 do
			local spark = Scenes.part(workspace, CFrame.new(target), Vector3.one * 0.18, glow, Enum.Material.Neon)
			spark.CastShadow = false
			local out = (normal + Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)).Unit
			tween(spark, 0.45, { Position = target + out * (2 + math.random() * 2), Transparency = 1 })
			task.delay(0.5, function()
				spark:Destroy()
			end)
		end
		local chip = Scenes.part(
			workspace,
			CFrame.new(target + normal * 0.4) * CFrame.Angles(math.random() * 3, math.random() * 3, 0),
			Vector3.one * (0.4 + math.random() * 0.4),
			Color3.fromRGB(120, 116, 124),
			Enum.Material.Slate
		)
		local ground = s.Stand.Position.Y + 0.3
		tween(chip, 0.6, { Position = Vector3.new(target.X, ground, target.Z) + normal * (1.5 + math.random()) })
		shake = 0.15
		task.delay(0.5, function()
			beam:Destroy()
			flash:Destroy()
		end)
		task.delay(3, function()
			chip:Destroy()
		end)
	end)
end

-- Each frame: the camera, the aiming arm and putting the laser away.
RunService.RenderStepped:Connect(function(dt)
	if not active or not site then
		return
	end
	local s = site :: Scenes.Site
	local now = os.clock()
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	-- Ease in from above on arrival, then a slow drift; a small kick on each hit.
	local arrive = math.clamp((now - started) / 1.2, 0, 1)
	arrive = 1 - (1 - arrive) ^ 3
	local drift = Vector3.new(math.sin(now * 0.25) * 0.6, math.sin(now * 0.33) * 0.3, 0)
	local eye = s.Eye + drift + Vector3.new(0, (1 - arrive) * 18, (1 - arrive) * 10)
	local kick = Vector3.zero
	if shake > 0 then
		shake = math.max(0, shake - dt)
		kick = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake * 0.6
	end
	camera.CFrame = CFrame.lookAt(eye + kick, s.Look)
	-- Raise the arm while the laser is out; lower it and swap back after.
	local want = if now < gunUntil then 1 else 0
	aim += (want - aim) * math.min(1, dt * 14)
	if want == 0 and aim < 0.05 and #gunParts > 0 and gunParts[1].Transparency < 1 then
		holdLaser(false)
	end
end)

-- The arm pose goes on after animation and before physics.
RunService.Stepped:Connect(function()
	if active and shoulder and shoulder.Parent then
		shoulder.Transform = CFrame.Angles(math.rad(90) * aim, 0, 0)
	end
end)

-- A new character (respawn) means a new miner next time.
player.CharacterAdded:Connect(function()
	if active then
		if miner then
			miner:Destroy()
		end
		task.wait(1)
		if active then
			placeMiner()
		end
	end
end)

return MineScene
