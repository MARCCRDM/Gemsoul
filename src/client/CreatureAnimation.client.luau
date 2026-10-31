-- Supplement the shared combat skeleton with creature-only detail joints.
-- Far creatures are reset and skipped. A creature's joints are gathered once,
-- when it arrives, and as streaming brings in the rest of its body (not by
-- rescanning every body twice a second: dozens of moon bugs made that a
-- stutter).
-- Kaiju (wild ones in workspace.Enemies, yours in workspace.Kaiju) walk the
-- same way, and fight with their whole body: each kind's wind-ups and
-- blows, guard, hops and staggers (CreatureMotion.fight, from KaijuFighter's
-- attributes), eased so a combo's next blow flows on from the last; out of a
-- fight, a wild one's mood (sniffing, looking about, resting, asleep, a roar:
-- KaijuWilds' KaijuMood), its roar heard in its kind's voice (CombatSound;
-- a roster kind borrows one of the first four's, Kaiju.Species' Voice).
-- Its whole body walks (CreatureMotion.gait: its weight on each foot, a lean
-- into a run, a bank into a turn), its feet kick up dust as they land, a
-- cast gathers at its mouth before it's let go (KaijuMotionFx), and any
-- creature flashes as a blow lands on it (HitFlash).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Motion = require(ReplicatedStorage.Shared.CreatureMotion)
local Kaiju = require(ReplicatedStorage.Shared.Kaiju)
local CombatSound = require(script.Parent.Modules.CombatSound)
local KaijuMotionFx = require(script.Parent.Modules.KaijuMotionFx)
local FxSize = require(script.Parent.Modules.FxSize)
local HitFlash = require(script.Parent.Modules.HitFlash)
local GemConfig = require(ReplicatedStorage.Shared.GemConfig)
-- Studs from the camera a creature's joints are animated out to: kaiju
-- further, moon bugs only near (there can be a dozen of them, and a far
-- one's legs aren't worth the frame).
local FAR, BUG_FAR = 180, 100
local STEP_FAR = 90 -- (footsteps' dust only this close)
local CASTS = { Bolt = true, Nova = true }
local rigs = {}
local scanAt = 0

local function reset(rig)
	for _, entry in rig.Joints do
		if entry.Joint.Parent then entry.Joint.C0 = entry.Rest end
	end
	rig.Active = false
	KaijuMotionFx.clear(rig)
	rig.Charging = nil
end

local function learn(rig, joint)
	if joint:IsA("Motor6D") and joint:GetAttribute("CreatureMotion") and not rig.Known[joint] then
		rig.Known[joint] = true
		local kind = joint:GetAttribute("CreatureMotion")
		table.insert(rig.Joints, { Joint = joint, Rest = joint:GetAttribute("CreatureRest"),
			Kind = kind, Side = joint:GetAttribute("CreatureSide") or 1 })
		-- (Its mouth: where a cast gathers.)
		if kind == "Jaw" and not rig.Mouth and joint.Part1 then
			rig.Mouth = joint.Part1
		end
	end
end

local function colorOf(model)
	local element = model:GetAttribute("ActionElement") or model:GetAttribute("KaijuElement")
	return GemConfig.ElementColors[element] or Color3.fromRGB(255, 220, 140)
end

-- Its turn this frame, radians a second (+ to its left), eased.
local function turning(rig, step)
	local look = rig.Root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local turn = 0
	if rig.Yaw and step > 0 then
		local d = (yaw - rig.Yaw + math.pi) % (2 * math.pi) - math.pi
		turn = d / step
	end
	rig.Yaw = yaw
	rig.Turn = (rig.Turn or 0) + (turn - (rig.Turn or 0)) * (1 - math.exp(-8 * step))
	return rig.Turn
end

RunService.PreSimulation:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	if now >= scanAt then
		scanAt = now + 0.5
		local found = {}
		-- (creatures and wild kaiju; kaiju out with their players; the
		-- Kaiju Kennel's and the Daycare's, drawn by this client alone:
		-- Client.KennelLife, Client.DaycarePen)
		for _, name in { "Enemies", "Kaiju", "KaijuKennel", "KaijuDaycare" } do
			local folder = workspace:FindFirstChild(name)
			for _, model in if folder then folder:GetChildren() else {} do
				table.insert(found, model)
			end
		end
		for _, model in found do
			if not model:GetAttribute("CreatureShape") then continue end
			local root = model:FindFirstChild("HumanoidRootPart")
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid then continue end
			local rig = rigs[model]
			if not rig then
				rig = {
					Root = root,
					Humanoid = humanoid,
					Joints = {},
					Known = {},
					Phase = 0,
					Amount = 0,
					Species = model:GetAttribute("KaijuSpecies"),
					Far = if model:GetAttribute("MoonBug") then BUG_FAR else FAR,
				}
				rigs[model] = rig
				for _, joint in model:GetDescendants() do
					learn(rig, joint)
				end
				rig.Arrivals = model.DescendantAdded:Connect(function(joint)
					learn(rig, joint)
				end)
			end
		end
		for model, rig in rigs do
			if not model:IsDescendantOf(workspace) or rig.Root.Parent == nil then
				reset(rig)
				rig.Arrivals:Disconnect()
				rigs[model] = nil
			end
		end
	end
	local camera = workspace.CurrentCamera
	for model, rig in rigs do
		local far = camera and (rig.Root.Position - camera.CFrame.Position).Magnitude > rig.Far
		if not camera or rig.Humanoid.Health <= 0 or far then
			if rig.Active then reset(rig) end
			continue
		end
		rig.Active = true
		-- (A kennel kaiju is moved, not pushed: it says how fast it walks.)
		local paced = model:GetAttribute("PacedSpeed")
		local v = rig.Root.AssemblyLinearVelocity
		local speed = if type(paced) == "number" then paced else Vector2.new(v.X, v.Z).Magnitude
		local step = math.min(dt, 0.1)
		local scale = model:GetScale()
		rig.Amount += (math.clamp(speed / 8, 0, 1) - rig.Amount) * (1 - math.exp(-10 * step))
		local before = rig.Phase
		rig.Phase = (rig.Phase + speed * step * math.pi * 2 / (3.5 * scale)) % (math.pi * 2)
		local at = model:GetAttribute("ActionAt")
		-- A foot lands each half stride (a kaiju on the ground, near enough to see the dust).
		if
			rig.Species
			and rig.Amount > 0.35
			and math.floor(rig.Phase / math.pi) ~= math.floor(before / math.pi)
			and (model:GetAttribute("KaijuHover") or 0) <= 0
			and (rig.Root.Position - camera.CFrame.Position).Magnitude < STEP_FAR
		then
			KaijuMotionFx.footstep(model, rig.Root, rig.Humanoid, if rig.Phase < math.pi then 1 else -1)
		end
		-- A blow landing on it: it flashes.
		local hurtAt = model:GetAttribute("HurtAt")
		if hurtAt ~= rig.HurtAt then
			local fresh = rig.HurtAt ~= nil and type(hurtAt) == "number" and now - hurtAt < 0.3
			rig.HurtAt = hurtAt
			if fresh then
				HitFlash.flash(model, Color3.fromRGB(255, 120, 90), 1)
			end
		end
		-- A cast gathers at its mouth over its wind-up, and bursts as it's let go.
		if rig.Species then
			local kind, start = model:GetAttribute("ActionKind"), model:GetAttribute("ActionStart")
			if CASTS[kind] and type(start) == "number" and type(at) == "number" and now >= start and now < at then
				rig.Charging = at
				KaijuMotionFx.charge(rig, model, rig.Root, (now - start) / math.max(at - start, 0.05), colorOf(model), at - start)
			elseif rig.Charging then
				if CASTS[kind] and at == rig.Charging and now >= at and now < at + 0.5 then
					KaijuMotionFx.release(rig, model, rig.Root, colorOf(model))
				else
					KaijuMotionFx.clear(rig) -- (cut off: hit out of it, or another move)
				end
				rig.Charging = nil
			end
		end
		local pose
		-- A roar is heard, once, in its kind's voice.
		local moodAt = model:GetAttribute("KaijuMoodAt")
		if rig.Species and moodAt ~= rig.MoodAt then
			rig.MoodAt = moodAt
			if model:GetAttribute("KaijuMood") == "Roar" then
				local kind = Kaiju.Species[rig.Species]
				CombatSound.play("Roar" .. (kind and kind.Voice or rig.Species), rig.Root.Position)
			end
		end
		if rig.Species then
			pose = Motion.fight(rig.Species, {
				Kind = model:GetAttribute("ActionKind"),
				Start = model:GetAttribute("ActionStart"),
				At = at,
				Side = model:GetAttribute("ActionSide"),
				GuardUntil = model:GetAttribute("GuardUntil"),
				BlockedAt = model:GetAttribute("BlockedAt"),
				HurtAt = model:GetAttribute("HurtAt"),
				HurtSide = model:GetAttribute("HurtSide"),
				Mood = model:GetAttribute("KaijuMood"),
				MoodAt = model:GetAttribute("KaijuMoodAt"),
			}, now)
			-- (A fight's blows snap in; getting up from a nap takes a moment.)
			local rate = if model:GetAttribute("ActionKind") then 24 else 6
			rig.Pose = Motion.blend(rig.Pose, pose, 1 - math.exp(-rate * step))
			-- Its walk on top (not eased: it's already smooth, and a lag would float).
			local shown = rig.Shown or {}
			for field, value in rig.Pose do
				shown[field] = value
			end
			rig.Shown = shown
			pose = Motion.gait(shown, rig.Phase, rig.Amount, now, turning(rig, step))
			-- Jumping after its owner, in line (KaijuServer's hops): it
			-- crouches, springs (a whoosh off its feet), tucks and lands with a
			-- thud and a puff of dust, each sound sized to it (FxSize).
			local hopAt = model:GetAttribute("KaijuHopAt")
			if type(hopAt) == "number" then
				local air = 2 * math.sqrt(2 * Kaiju.Hop.Height / math.max(workspace.Gravity, 1))
				pose = Motion.hop(pose, now - hopAt, air)
				local size = FxSize.ofModel(model)
				local voice = { Pitch = math.clamp(size ^ -0.2, 0.85, 1.2) }
				if rig.JumpedFrom ~= hopAt and now >= hopAt then
					rig.JumpedFrom = hopAt
					if now - hopAt < 0.25 then
						FxSize.run(size, CombatSound.play, "KaijuJump", rig.Root.Position, voice)
					end
				end
				if rig.LandedFrom ~= hopAt and now - hopAt >= air then
					rig.LandedFrom = hopAt
					if now - hopAt < air + 0.3 then
						FxSize.run(size, CombatSound.play, "KaijuLand", rig.Root.Position, voice)
						if (rig.Root.Position - camera.CFrame.Position).Magnitude < STEP_FAR then
							KaijuMotionFx.footstep(model, rig.Root, rig.Humanoid, 0)
						end
					end
				end
			end
			-- Leaping into its team's HYPERBEAM formation (KaijuBeamServer:
			-- BeamLeapAt, BeamLandAt; KaijuBeamFx carries it through the air
			-- and slams it down): the same crouch, spring, tuck and landing.
			local leapAt, landAt = model:GetAttribute("BeamLeapAt"), model:GetAttribute("BeamLandAt")
			if type(leapAt) == "number" and type(landAt) == "number" then
				pose = Motion.hop(pose, now - leapAt, math.max(landAt - leapAt, 0.1))
			end
		end
		for i = #rig.Joints, 1, -1 do
			local entry = rig.Joints[i]
			if not entry.Joint.Parent then
				rig.Known[entry.Joint] = nil
				table.remove(rig.Joints, i)
			elseif pose then
				local x, y, z = Motion.angles(entry.Kind, now, rig.Phase, rig.Amount, entry.Side, nil)
				local lift, push
				x, y, z, lift, push = Motion.apply(pose, entry.Kind, entry.Side, x, y, z)
				entry.Joint.C0 = entry.Rest * CFrame.new(0, lift * scale, -push * scale) * CFrame.Angles(x, y, z)
			else
				entry.Joint.C0 = entry.Rest * CFrame.Angles(Motion.angles(entry.Kind, now, rig.Phase, rig.Amount, entry.Side, at))
			end
		end
	end
end)
