--[[
	A kaiju's body effects (client only), driven by CreatureAnimation as it
	poses one:

	  footstep(model, root, humanoid, side)
	      a foot landing: dust kicked up round it and a ring along the
	      ground; a big one thuds, and a giant's shakes your screen when it's
	      close (all at its size, FxSize)
	  charge(rig, model, root, progress, color, seconds?)
	      a cast gathering (each frame of its wind-up, progress 0..1): an orb
	      of its element swelling at its mouth, motes drawn in to it, its
	      light growing, a tremble as it peaks; a whine climbing with it,
	      timed to peak as it's let go (`seconds`, the wind-up's length)
	  release(rig, model, root, color)
	      the cast let go: the orb bursts, a flash and a ring
	  clear(rig)  any charge it held, gone (the cast was cut off)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatFx = require(script.Parent.CombatFx)
local CombatSound = require(script.Parent.CombatSound)
local FxSize = require(script.Parent.FxSize)

local KaijuMotionFx = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local DUST = Color3.fromRGB(176, 166, 150)
local WHITE = Color3.new(1, 1, 1)

local folder: Folder? = nil
local function fxFolder(): Folder
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "KaijuMotionFx"
		made.Parent = workspace
		folder = made
	end
	return folder :: Folder
end

local function part(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = fxFolder()
	return p
end

-- Where its feet meet the ground (the middle of them).
local function feet(root: BasePart, humanoid: Humanoid): Vector3
	return root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
end

function KaijuMotionFx.footstep(model: Model, root: BasePart, humanoid: Humanoid, side: number)
	local size = FxSize.ofModel(model)
	if size < 0.45 then
		return -- (a little one's patter isn't worth a puff)
	end
	local at = feet(root, humanoid) + root.CFrame.RightVector * side * root.Size.X * 0.3
	-- A ring of dust along the ground, spreading.
	local ring = part(
		Vector3.new(0.1, 1.2 * size, 1.2 * size),
		CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		DUST,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0.55
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 4 * size, 4 * size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
	FxSize.run(size, function()
		CombatFx.burst(at + Vector3.new(0, 0.2, 0), DUST, "Smoke", 0.35)
		if size >= 1.1 then
			CombatSound.play("Stomp", at, { Volume = math.clamp(size * 0.45, 0.3, 1) })
		end
		if size >= 1.5 then
			CombatFx.shakeNear(at, 0.01, 0.18, 22)
		end
	end)
end

-- Its mouth, or failing that its head's height, a little in front of it.
local function mouth(rig, root: BasePart): Vector3
	local jaw = rig.Mouth
	if jaw and jaw.Parent then
		return jaw.Position + root.CFrame.LookVector * jaw.Size.Z * 0.6
	end
	return root.Position + Vector3.new(0, root.Size.Y * 0.4, 0) + root.CFrame.LookVector * root.Size.Z * 0.6
end

local function newCharge(color: Color3, size: number)
	local holder = part(Vector3.one * 3 * size, CFrame.new(), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	holder.Transparency = 1
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = SPARKLE
	motes.Shape = Enum.ParticleEmitterShape.Sphere
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	motes.Color = ColorSequence.new(WHITE, color)
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15 * size), NumberSequenceKeypoint.new(1, 0.35 * size) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(1, 0.6) })
	motes.Speed = NumberRange.new(4 * size, 6 * size)
	motes.Lifetime = NumberRange.new(0.25, 0.3)
	motes.Rate = 0
	motes.Parent = holder
	local core = part(Vector3.one * 0.1, CFrame.new(), color, Enum.Material.Neon, Enum.PartType.Ball)
	core.Transparency = 0.1
	local heart = part(Vector3.one * 0.05, CFrame.new(), WHITE, Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Shadows = false
	light.Brightness = 0
	light.Range = 8 * size
	light.Parent = core
	return { Holder = holder, Motes = motes, Core = core, Heart = heart, Light = light, Size = size }
end

function KaijuMotionFx.clear(rig)
	local c = rig.Charge
	if c then
		c.Holder:Destroy()
		c.Core:Destroy()
		c.Heart:Destroy()
		rig.Charge = nil
	end
end

function KaijuMotionFx.charge(rig, model: Model, root: BasePart, progress: number, color: Color3, seconds: number?)
	local c = rig.Charge
	if not c then
		c = newCharge(color, FxSize.ofModel(model))
		rig.Charge = c
		-- The whine climbs over its wind-up (the sound is a second long),
		-- unless we've only come in on the end of it.
		if progress < 0.35 then
			local size = c.Size
			local at = mouth(rig, root)
			FxSize.run(size, function()
				CombatSound.play("Charge", at, {
					Volume = math.clamp(0.4 + size * 0.4, 0.4, 1),
					Pitch = math.clamp(1 / math.max(seconds or 1, 0.1), 0.7, 1.6),
				})
			end)
		end
	end
	local size = c.Size
	local at = mouth(rig, root)
	local k = math.clamp(progress, 0, 1)
	local pulse = 1 + math.sin(os.clock() * (18 + 20 * k)) * 0.1 * k
	local d = (0.3 + 1.7 * k * k) * size * pulse
	c.Holder.CFrame = CFrame.new(at)
	c.Core.CFrame = CFrame.new(at)
	c.Core.Size = Vector3.one * d
	c.Heart.CFrame = CFrame.new(at)
	c.Heart.Size = Vector3.one * d * 0.5
	c.Light.Brightness = 1 + 4 * k
	c.Light.Range = (6 + 10 * k) * size
	c.Motes.Rate = 30 + 90 * k
end

function KaijuMotionFx.release(rig, model: Model, root: BasePart, color: Color3)
	local c = rig.Charge
	local size = if c then c.Size else FxSize.ofModel(model)
	local at = mouth(rig, root)
	KaijuMotionFx.clear(rig)
	-- The orb bursts: a white-hot flash, its element's sparks and a ring.
	local flash = part(Vector3.one * 0.6 * size, CFrame.new(at), WHITE, Enum.Material.Neon, Enum.PartType.Ball)
	TweenService:Create(flash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * 3 * size,
		Transparency = 1,
		Color = color,
	}):Play()
	Debris:AddItem(flash, 0.25)
	local look = root.CFrame.LookVector
	local ring = part(
		Vector3.new(0.08, 1 * size, 1 * size),
		CFrame.lookAt(at, at + look) * CFrame.Angles(0, math.rad(90), 0),
		color:Lerp(WHITE, 0.3),
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	ring.Transparency = 0.2
	TweenService:Create(ring, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.02, 5 * size, 5 * size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.35)
	FxSize.run(size, function()
		CombatFx.burst(at, color, "Sparks", 1.2)
		CombatFx.flash(at, color, 4, 14, 0.3)
	end)
end

return KaijuMotionFx
