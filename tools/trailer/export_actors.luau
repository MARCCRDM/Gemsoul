-- lune run export_actors.luau <gemsoul root> <clips.json> <out dir>
-- Every character in the trailer, posed frame by frame by the game's own
-- animation code: kaiju (Shared.CreatureMotion, as CreatureAnimation runs
-- it), moon bugs (Shared.RivalPose, as BodyPoses runs it), mechs
-- (Shared.MechMotion and MechAnimation's strike) and a miner in a suit with
-- the Outpost pick (MineScene's swing). Each clip is written as
-- <out>/<id>.json: { parts = { s, c, shape, mat, tr }, frames = { flat 12 floats
-- per part: position, then right/up/back columns }, dist = { studs walked } },
-- relative to the model's root at the origin facing -Z.
local fs, luau, roblox, serde, process = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox"), require("@lune/serde"), require("@lune/process")
local R = roblox
local ROOT, CLIPS, OUTDIR = process.args[1], process.args[2], process.args[3]
local CFrame, Vector3, Color3 = R.CFrame, R.Vector3, R.Color3

local Rand = {}
Rand.__index = Rand
function Rand.new(seed)
	local s = { x = (seed or 1) % 2147483647 }
	if s.x <= 0 then s.x += 2147483646 end
	return setmetatable(s, Rand)
end
function Rand:_n() self.x = (self.x * 48271) % 2147483647 return self.x / 2147483647 end
function Rand:NextNumber(a, b) a, b = a or 0, b or 1 return a + (b - a) * self:_n() end
function Rand:NextInteger(a, b) return math.floor(a + (b - a + 1) * self:_n()) end

local loaded = {}
local env
local PATHS = {
	ArmorFamilies = "/src/shared/ArmorFamilies.luau",
	Tags = "/src/shared/Tags.luau",
	ElementMatchup = "/src/shared/ElementMatchup.luau",
}
local function load(path, name)
	return luau.load(fs.readFile(ROOT .. path), { debugName = name, environment = env })()
end
local function req(m)
	local name = if type(m) == "table" then m.__module else tostring(m)
	if not loaded[name] then
		local path = PATHS[name]
		if not path then
			for _, dir in { "/src/shared/", "/src/server/Systems/", "/src/client/Modules/" } do
				if fs.isFile(ROOT .. dir .. name .. ".luau") then
					path = dir .. name .. ".luau"
					break
				end
			end
		end
		assert(path, "no path for module " .. name)
		loaded[name] = load(path, name)
	end
	return loaded[name]
end
local modProxy = setmetatable({}, { __index = function(_, k) return { __module = k } end })
env = setmetatable({
	Instance = R.Instance, CFrame = CFrame, Vector3 = Vector3, Vector2 = R.Vector2, Color3 = Color3, Enum = R.Enum,
	UDim2 = R.UDim2, UDim = R.UDim, NumberRange = R.NumberRange, NumberSequence = R.NumberSequence,
	NumberSequenceKeypoint = R.NumberSequenceKeypoint, ColorSequence = R.ColorSequence,
	ColorSequenceKeypoint = R.ColorSequenceKeypoint, PhysicalProperties = R.PhysicalProperties, Font = R.Font,
	Random = Rand,
	game = { GetService = function() return { Shared = modProxy } end },
	script = { Parent = modProxy },
	require = req,
	warn = function() end,
}, { __index = _G })

local KaijuModels = load("/src/shared/KaijuModels.luau", "KaijuModels")
local Motion = load("/src/shared/CreatureMotion.luau", "CreatureMotion")
local RivalPose = load("/src/shared/RivalPose.luau", "RivalPose")
local MechMotion = load("/src/shared/MechMotion.luau", "MechMotion")
local Machines = load("/src/server/World/OutpostMachines.luau", "OutpostMachines")
local Skins = load("/src/server/Systems/BrainrotSkins.luau", "BrainrotSkins")
local ArmorKits = load("/src/server/Systems/ArmorKits.luau", "ArmorKits")
local PickaxeLooks = load("/src/shared/PickaxeLooks.luau", "PickaxeLooks")
local Dungeon = load("/src/shared/DungeonRules.luau", "DungeonRules")
local GemConfig = (function()
	local ok, m = pcall(load, "/src/shared/GemConfig.luau", "GemConfig")
	return if ok then m else nil
end)()

-- Duelist's body (BODY, JOINTS, buildBody), cut out of the server module.
local Body = (function()
	local src = fs.readFile(ROOT .. "/src/server/Systems/Duelist.luau")
	local a = string.find(src, "local BODY = {", 1, true)
	local b = string.find(src, "-- A brainrot creature's bare body", 1, true)
	local chunk = string.sub(src, a, b - 1) .. "\nreturn { build = buildBody, BODY = BODY, JOINTS = JOINTS }"
	return luau.load(chunk, { debugName = "DuelistBody", environment = env })()
end)()

local nextId = 0
-- Posing --------------------------------------------------------------------------------------
-- Each joint's world CFrame for Part1 from Part0, by kind; `override[joint]`
-- replaces a Motor6D's C0, `transform[joint]` is its Transform.
local function idOf(part)
	local id = part:GetAttribute("PoseId")
	if not id then
		nextId += 1
		id = nextId
		part:SetAttribute("PoseId", id)
	end
	return id
end

local function snapshot(model, root, override, transform)
	local edges = {}
	local buildCF = {}
	local all = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local id = idOf(d)
			buildCF[id] = d.CFrame
			table.insert(all, id)
		end
	end
	local function link(p0, p1, rel)
		edges[p0] = edges[p0] or {}
		edges[p1] = edges[p1] or {}
		table.insert(edges[p0], { p1, rel })
		table.insert(edges[p1], { p0, rel:Inverse() })
	end
	for _, d in model:GetDescendants() do
		local k = d:GetAttribute("JointId")
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			local c0 = (k and override[k]) or d.C0
			local t = (k and transform[k]) or CFrame.identity
			link(idOf(d.Part0), idOf(d.Part1), c0 * t * d.C1:Inverse())
		elseif (d:IsA("Weld") or d.ClassName == "ManualWeld") and d.Part0 and d.Part1 then
			link(idOf(d.Part0), idOf(d.Part1), d.C0 * d.C1:Inverse())
		elseif d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
			local a, b = idOf(d.Part0), idOf(d.Part1)
			if buildCF[a] and buildCF[b] then
				link(a, b, buildCF[a]:Inverse() * buildCF[b])
			end
		end
	end
	local rootId = idOf(root)
	local placed = { [rootId] = CFrame.identity }
	local queue = { rootId }
	local head = 1
	while queue[head] do
		local p = queue[head]
		head += 1
		for _, e in edges[p] or {} do
			if not placed[e[1]] then
				placed[e[1]] = placed[p] * e[2]
				table.insert(queue, e[1])
			end
		end
	end
	local rootInv = buildCF[rootId]:Inverse()
	for _, id in all do
		if not placed[id] then
			placed[id] = rootInv * buildCF[id]
		end
	end
	return placed
end

-- A joint's key in `override` / `transform` tables.
local function jointKey(joint)
	local k = joint:GetAttribute("JointId")
	if not k then
		nextId += 1
		k = nextId
		joint:SetAttribute("JointId", k)
	end
	return k
end

local function shapeOf(d)
	if d.ClassName == "WedgePart" then return "Wedge" end
	if d.ClassName == "CornerWedgePart" then return "CornerWedge" end
	local mesh = d:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		if mesh.MeshType == R.Enum.MeshType.Sphere then return "MeshSphere" end
		if mesh.MeshType == R.Enum.MeshType.Cylinder then return "MeshCylinder" end
		if mesh.MeshType == R.Enum.MeshType.Wedge then return "Wedge" end
	end
	if d.ClassName == "Part" then return d.Shape.Name end
	return "Block"
end

local function r3(x) return math.floor(x * 1000 + 0.5) / 1000 end

-- A clip writer: the visible parts once, then a frame per call.
local function recorder(model, root)
	local visible = {}
	local meta = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(visible, idOf(d))
			table.insert(meta, { s = { r3(d.Size.X), r3(d.Size.Y), r3(d.Size.Z) }, c = { r3(d.Color.R), r3(d.Color.G), r3(d.Color.B) },
				shape = shapeOf(d), mat = d.Material.Name, tr = d.Transparency })
		end
	end
	local frames = {}
	return {
		frame = function(override, transform)
			local placed = snapshot(model, root, override, transform)
			local flat = {}
			for _, id in visible do
				local cf = placed[id]
				local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
				-- columns: right (r00 r10 r20), up (r01 r11 r21), back (r02 r12 r22)
				for _, v in { px, py, pz, r00, r10, r20, r01, r11, r21, r02, r12, r22 } do
					table.insert(flat, r3(v))
				end
			end
			table.insert(frames, flat)
		end,
		write = function(id, extra)
			local out = { parts = meta, frames = frames }
			for k, v in extra or {} do out[k] = v end
			fs.writeFile(OUTDIR .. "/" .. id .. ".json", serde.encode("json", out))
			print(id, #meta, "parts", #frames, "frames")
		end,
	}
end

-- A value at `t` from { {t, v}, ... } (linear, held at the ends).
local function curve(keys, t)
	if type(keys) == "number" then return keys end
	if not keys or #keys == 0 then return 0 end
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		if t <= keys[i][1] then
			local a, b = keys[i - 1], keys[i]
			return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
		end
	end
	return keys[#keys][2]
end

-- The latest event in `list` that has started by `t` (by its `Start` or `t`).
local function latest(list, t, key)
	local found
	for _, e in list or {} do
		if (e[key] or e.t or 0) <= t then found = e end
	end
	return found
end

-- Kaiju: CreatureAnimation's loop ---------------------------------------------------------------
local function kaijuClip(clip)
	local model = KaijuModels.build(clip.species, clip.element)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d:GetAttribute("CreatureMotion") then
			table.insert(joints, { Joint = d, Kind = d:GetAttribute("CreatureMotion"), Side = d:GetAttribute("CreatureSide") or 1, Rest = d.C0 })
		end
	end
	local rec = recorder(model, root)
	local fps = clip.fps or 30
	local dt = 1 / fps
	local rig = { Phase = 0, Amount = 0, Pose = nil }
	local dist, dists = 0, {}
	local scale = 1
	for i = 0, clip.frames - 1 do
		local now = i * dt + (clip.t0 or 0)
		local speed = curve(clip.speed, now)
		rig.Amount += (math.clamp(speed / 8, 0, 1) - rig.Amount) * (1 - math.exp(-10 * dt))
		rig.Phase = (rig.Phase + speed * dt * math.pi * 2 / (3.5 * (clip.scale or 1))) % (math.pi * 2)
		dist += speed * dt
		table.insert(dists, r3(dist))
		local act = latest(clip.actions, now, "Start") or {}
		local mood = latest(clip.moods, now, "MoodAt") or {}
		local pose = Motion.fight(clip.species, {
			Kind = act.Kind, Start = act.Start, At = act.At, Side = act.Side,
			GuardUntil = act.GuardUntil, HurtAt = act.HurtAt, HurtSide = act.HurtSide,
			Mood = mood.Mood, MoodAt = mood.MoodAt,
		}, now)
		local rate = if act.Kind then 24 else 6
		rig.Pose = Motion.blend(rig.Pose, pose, 1 - math.exp(-rate * dt))
		local override = {}
		for _, entry in joints do
			local x, y, z = Motion.angles(entry.Kind, now, rig.Phase, rig.Amount, entry.Side, nil)
			local lift, push
			x, y, z, lift, push = Motion.apply(rig.Pose, entry.Kind, entry.Side, x, y, z)
			override[jointKey(entry.Joint)] = entry.Rest * CFrame.new(0, lift * scale, -push * scale) * CFrame.Angles(x, y, z)
		end
		rec.frame(override, {})
	end
	rec.write(clip.id, { dist = dists, hip = model:GetAttribute("KaijuHipHeight") })
end

-- Humanoid bodies (Duelist's rig): RivalPose.update's loop ----------------------------------------
local JOINT_PARTS = {}
for _, j in Body.JOINTS do JOINT_PARTS[j[1]] = j end

local function bodyJoints(rig)
	local out = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") and JOINT_PARTS[d.Name] then
			out[d.Name] = { Joint = d, Rest = d.C0, Angles = { 0, 0, 0 } }
		end
	end
	return out
end

local function poseBody(joints, target, alpha)
	local override = {}
	for name, entry in joints do
		local to = target[name] or { 0, 0, 0 }
		for i = 1, 3 do
			entry.Angles[i] += (to[i] - entry.Angles[i]) * alpha
		end
		local a = entry.Angles
		override[jointKey(entry.Joint)] = CFrame.new(entry.Rest.Position) * CFrame.Angles(a[1], a[2], a[3]) * entry.Rest.Rotation
	end
	return override
end

local function addPose(base, layer, w)
	local out = {}
	for k, v in base do out[k] = { v[1], v[2], v[3] } end
	for k, v in layer do
		local o = out[k] or { 0, 0, 0 }
		out[k] = { o[1] + v[1] * w, o[2] + v[2] * w, o[3] + v[3] * w }
	end
	return out
end

local function bugClip(clip)
	local spec
	for _, s in Dungeon.Roster do
		if s.Id == clip.critter then spec = s end
	end
	assert(spec, "no critter " .. tostring(clip.critter))
	local color = Color3.new(1, 1, 1)
	if GemConfig and GemConfig.ElementColors and GemConfig.ElementColors[spec.Element] then
		color = GemConfig.ElementColors[spec.Element]
	end
	local rig = Body.build(Color3.fromRGB(150, 130, 110))
	Skins.apply(rig, spec, color, false, 0, false)
	if not clip.full then Skins.thin(rig) end
	local root = rig:FindFirstChild("HumanoidRootPart")
	local joints = bodyJoints(rig)
	local rec = recorder(rig, root)
	local fps = clip.fps or 30
	local dt = 1 / fps
	local shape = spec.Shape
	local scale = clip.scale or 1
	local strideLength = (if shape == "Tree" then 6.5 elseif shape == "Shark" then 3.5 else 4.5) * scale
	local phase, stride = 0, 0
	local dist, dists = 0, {}
	for i = 0, clip.frames - 1 do
		local now = i * dt + (clip.t0 or 0)
		local pace = curve(clip.speed, now)
		dist += pace * dt
		table.insert(dists, r3(dist))
		local act = latest(clip.actions, now, "ActionStart") or {}
		local attrs = { CreatureShape = shape, ActionKind = act.ActionKind, ActionStart = act.ActionStart, ActionAt = act.ActionAt,
			ActionSide = act.ActionSide, HurtAt = act.HurtAt, HurtSide = act.HurtSide }
		local target, speed = RivalPose.pose(attrs, now, false)
		stride += (math.min(1, pace / 6) - stride) * (1 - math.exp(-10 * dt))
		phase = (phase + pace * dt * 2 * math.pi / strideLength) % (2 * math.pi)
		if stride > 0.01 then
			local attacking = type(attrs.ActionAt) == "number" and type(attrs.ActionStart) == "number"
				and now >= attrs.ActionStart and now < attrs.ActionAt + 0.9
			if not attacking then
				target = addPose(target, RivalPose.creatureStep(shape, phase, 1, stride), 1)
			end
		end
		rec.frame(poseBody(joints, target, 1 - math.exp(-speed * dt)), {})
	end
	rec.write(clip.id, { dist = dists })
end

-- The miner: a suit over the body, the Outpost pick in the right hand.
local function minerClip(clip)
	local rig = Body.build(Color3.fromRGB(204, 170, 140))
	local folder = R.Instance.new("Folder")
	folder.Name = "Armor"
	folder.Parent = rig
	local accent = Color3.fromRGB(table.unpack(clip.accent or { 255, 184, 72 }))
	ArmorKits.build(folder, rig, clip.suit or "SuitCrusader", accent, clip.quality or 4, nil)
	local hand = rig:FindFirstChild("RightHand")
	local pickModel = R.Instance.new("Model")
	pickModel.Parent = rig
	local grip = hand.CFrame * CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-120), 0, 0)
	PickaxeLooks.build(pickModel, grip, clip.skin, Color3.fromRGB(table.unpack(clip.pick or { 255, 202, 91 })), hand, true)
	local root = rig:FindFirstChild("HumanoidRootPart")
	local joints = bodyJoints(rig)
	local shoulder = joints.RightShoulder.Joint
	local rec = recorder(rig, root)
	local fps = clip.fps or 30
	local dt = 1 / fps
	local phase, amount = 0, 0
	local dist, dists = 0, {}
	for i = 0, clip.frames - 1 do
		local now = i * dt + (clip.t0 or 0)
		local pace = curve(clip.speed, now)
		dist += pace * dt
		table.insert(dists, r3(dist))
		amount += (math.min(1, pace / 12) - amount) * (1 - math.exp(-10 * dt))
		phase = (phase + pace * dt * 2 * math.pi / 7) % (2 * math.pi)
		-- A plain run (Roblox's own walk does this in game) plus a breath.
		local s, c = math.sin(phase), math.cos(phase)
		local target = {
			RightHip = { 0.75 * s * amount, 0, 0 }, LeftHip = { -0.75 * s * amount, 0, 0 },
			RightKnee = { -0.9 * amount * math.max(0, c), 0, 0 }, LeftKnee = { -0.9 * amount * math.max(0, -c), 0, 0 },
			RightShoulder = { -0.6 * s * amount, 0, 0.05 }, LeftShoulder = { 0.6 * s * amount, 0, -0.05 },
			RightElbow = { 0.4 * amount + 0.1, 0, 0 }, LeftElbow = { 0.4 * amount + 0.1, 0, 0 },
			Waist = { -0.08 * amount + math.sin(now * 2) * 0.015, 0.06 * s * amount, 0 },
		}
		local override = poseBody(joints, target, 1 - math.exp(-18 * dt))
		-- MineScene's swing: wind up over the shoulder, strike down, recover.
		local transform = {}
		for _, at in clip.swings or {} do
			local t = (now - at) / 0.42
			if t >= 0 and t < 1 then
				local angle
				if t < 0.35 then
					angle = 130 * (t / 0.35)
				elseif t < 0.6 then
					angle = 130 - 85 * ((t - 0.35) / 0.25)
				else
					angle = 45 * (1 - (t - 0.6) / 0.4)
				end
				transform[jointKey(shoulder)] = CFrame.Angles(math.rad(angle), 0, 0)
			end
		end
		rec.frame(override, transform)
	end
	rec.write(clip.id, { dist = dists })
end

-- Mechs: MechAnimation's loop, with its SLAM strike.
local SLAM = {
	{ 0, 0, -0.18, 0, 0, 0 },
	{ 0.18, 3.25, 1.3, -0.32, 0.12, 0.55 },
	{ 0.27, 0.6, -0.05, 0.3, -0.3, 0.75 },
	{ 0.42, 0.62, -0.08, 0.26, -0.26, 0.7 },
}
local THRUST = {
	{ 0, 0, -0.18, 0, 0, 0 },
	{ 0.14, -0.6, 1.5, -0.22, 0.06, 0.4 },
	{ 0.24, 1.4, 0.05, 0.22, -0.14, 0.6 },
	{ 0.55, 1.35, 0.03, 0.2, -0.12, 0.6 },
}
local STRIKE_END = 0.8
local function sample(keys, t)
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if t <= b[1] then
			local k = math.clamp((t - a[1]) / (b[1] - a[1]), 0, 1)
			k = k * k * (3 - 2 * k)
			local out = {}
			for j = 2, #a do out[j - 1] = a[j] + (b[j] - a[j]) * k end
			return out
		end
	end
	local last = keys[#keys]
	return { last[2], last[3], last[4], last[5], last[6] }
end
local function strike(poses, t, drill, now)
	local v = sample(if drill then THRUST else SLAM, t)
	local hold = if drill then THRUST[#THRUST][1] else SLAM[#SLAM][1]
	local weight = math.clamp(t / 0.05, 0, 1) * (1 - math.clamp((t - hold) / (STRIKE_END - hold), 0, 1))
	local shake = if drill and t > 0.24 and t < hold then math.sin(now * 90) * 0.03 else 0
	local target = {
		RightShoulder = CFrame.Angles(v[1] + shake, 0, 0.08),
		RightElbow = CFrame.Angles(v[2], 0, 0),
		Waist = CFrame.Angles(v[4], v[3], 0),
		LeftShoulder = CFrame.Angles(v[5], 0, -0.08),
		LeftElbow = CFrame.Angles(-0.18 + v[5] * 1.2, 0, 0),
	}
	for name, cf in target do
		poses[name] = poses[name]:Lerp(cf, weight)
	end
	if drill then poses.ToolRotor = CFrame.Angles(0, now * 40, 0) end
end

local function mechClip(clip)
	local model = Machines.build(clip.mech, CFrame.new())
	local root = model:FindFirstChild("Chassis")
	local joints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d:GetAttribute("MechRest") then
			joints[d.Name] = { Joint = d, Inverse = d:GetAttribute("MechRest"):Inverse() }
		end
	end
	local scale = model:GetAttribute("MechScale") or 1
	local rec = recorder(model, root)
	local fps = clip.fps or 30
	local dt = 1 / fps
	local state = MechMotion.new()
	local dist, dists = 0, {}
	for i = 0, clip.frames - 1 do
		local now = i * dt + (clip.t0 or 0)
		local speed = curve(clip.speed, now)
		dist += speed * dt
		table.insert(dists, r3(dist))
		MechMotion.step(state, dt, speed / scale, 0, true)
		local poses = MechMotion.pose(state, scale, now, true)
		for _, at in clip.strikes or {} do
			local t = now - at
			if t >= 0 and t < STRIKE_END then strike(poses, t, clip.mech == "Mole", now) end
		end
		local transform = {}
		for name, j in joints do
			if poses[name] then transform[jointKey(j.Joint)] = j.Inverse * poses[name] end
		end
		rec.frame({}, transform)
	end
	rec.write(clip.id, { dist = dists, chassisY = 6 * scale + 0.2 })
end


-- A frontier rift tear (RiftTear.pieces), splitting open: every frame its own parts.
local function tearClip(clip)
	local RiftTear = load("/src/client/Modules/RiftTear.luau", "RiftTear")
	local Frontier = req("Frontier")
	local shape = Frontier.tear(clip.seed or 41, clip.height or 6.5)
	local plane = CFrame.new(0, (clip.height or 6.5) / 2 + 0.4, 0) * CFrame.Angles(0, 0, shape.Tilt)
	local fps = clip.fps or 30
	local frames = {}
	for i = 0, clip.frames - 1 do
		local now = i / fps + (clip.t0 or 0)
		local open = curve(clip.open, now)
		local parts = {}
		if open > 0.001 then
			for _, piece in RiftTear.pieces(shape, open, plane, now, curve(clip.crackle or 0, now)) do
				if piece.Transparency < 1 then
					local cf = piece.CFrame
					local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
					table.insert(parts, { s = { r3(piece.Size.X), r3(piece.Size.Y), r3(piece.Size.Z) }, p = { r3(px), r3(py), r3(pz) },
						r = { r3(r00), r3(r10), r3(r20), r3(r01), r3(r11), r3(r21), r3(r02), r3(r12), r3(r22) },
						c = { r3(piece.Color.R), r3(piece.Color.G), r3(piece.Color.B) }, shape = "Block", mat = "Neon", tr = r3(piece.Transparency) })
				end
			end
		end
		table.insert(frames, parts)
	end
	fs.writeFile(OUTDIR .. "/" .. clip.id .. ".json", serde.encode("json", { dynamic = true, frames = frames }))
	print(clip.id, #frames, "frames (tear)")
end

local clips = serde.decode("json", fs.readFile(CLIPS))
local only = process.args[4]
for _, clip in clips do
	if not only or string.find(clip.id, only, 1, true) then
		if clip.kind == "kaiju" then kaijuClip(clip)
		elseif clip.kind == "bug" then bugClip(clip)
		elseif clip.kind == "miner" then minerClip(clip)
		elseif clip.kind == "mech" then mechClip(clip)
		elseif clip.kind == "tear" then tearClip(clip)
		end
	end
end
