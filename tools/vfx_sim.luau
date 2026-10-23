-- Runs the client combat VFX modules (CombatVfx, CombatFx, ElementalDeath)
-- on a virtual clock: tweens, task scheduling, particles, Debris and a
-- simple physics step are simulated; snapshots of every part, particle and
-- light are written as JSON for vfxrender.py.
--   lune run tools/vfx_sim.luau <repo> <outdir> [scenario]
-- then: python3 tools/vfx_render.py <outdir>  (needs numpy, pillow)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Instance = roblox.Instance
local V3, CF, C3 = roblox.Vector3, roblox.CFrame, roblox.Color3
local ROOT, OUT = process.args[1], process.args[2]
fs.writeDir(OUT)

-- Virtual time and a scheduler -------------------------------------------------
local now = 0
local queue = {}
local errors = {}
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		table.insert(errors, tostring(err) .. "\n" .. debug.traceback(co))
	end
end
local fakeTask = {}
function fakeTask.spawn(fn, ...)
	local co = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(co, ...)
	return co
end
fakeTask.defer = fakeTask.spawn
function fakeTask.delay(t, fn, ...)
	local args = table.pack(...)
	table.insert(queue, { At = now + (t or 0), Fn = function()
		fakeTask.spawn(fn, table.unpack(args, 1, args.n))
	end })
end
function fakeTask.wait(t)
	local co = coroutine.running()
	local start = now
	table.insert(queue, { At = now + (t or 1 / 60), Co = co })
	coroutine.yield()
	return now - start
end
local fakeOs = setmetatable({ clock = function() return now end }, { __index = os })

-- Tweens -------------------------------------------------------------------------
local tweens = {}
local function ease(style, dir, t)
	local name = style and style.Name or "Quad"
	local function easeIn(x)
		if name == "Linear" then return x
		elseif name == "Sine" then return 1 - math.cos(x * math.pi / 2)
		elseif name == "Quad" then return x * x
		elseif name == "Cubic" then return x ^ 3
		elseif name == "Quart" then return x ^ 4
		elseif name == "Quint" then return x ^ 5
		elseif name == "Back" then local s = 1.70158; return x * x * ((s + 1) * x - s)
		elseif name == "Exponential" then return if x == 0 then 0 else 2 ^ (10 * (x - 1))
		end
		return x * x
	end
	local d = dir and dir.Name or "Out"
	if d == "In" then return easeIn(t) end
	if d == "InOut" then
		if t < 0.5 then return easeIn(t * 2) / 2 end
		return 1 - easeIn((1 - t) * 2) / 2
	end
	return 1 - easeIn(1 - t)
end
local function lerp(a, b, t)
	local ty = typeof(a)
	if ty == "number" then return a + (b - a) * t end
	if ty == "Vector3" or ty == "CFrame" or ty == "Color3" or ty == "Vector2" then return a:Lerp(b, t) end
	if ty == "UDim2" then return a:Lerp(b, t) end
	return if t >= 1 then b else a
end
local TweenInfoFake = { new = function(time, style, dir) return { Time = time or 1, Style = style, Dir = dir } end }
local TweenServiceFake = {
	Create = function(_, object, info, goal)
		local tween = { Object = object, Info = info, Goal = goal }
		function tween.Play()
			-- A newer tween takes over the properties it sets.
			for _, other in tweens do
				if other.Object == object then
					for k in goal do other.From[k] = nil; other.Goal2[k] = nil end
				end
			end
			tween.Start = now
			tween.From, tween.Goal2 = {}, {}
			for k, v in goal do
				local okF, value = pcall(function() return object[k] end)
				tween.From[k] = if okF then value else v
				tween.Goal2[k] = v
			end
			table.insert(tweens, tween)
		end
		tween.Cancel = function() tween.Dead = true end
		tween.Completed = { Connect = function() return { Disconnect = function() end } end, Wait = function() end }
		return tween
	end,
}
local function stepTweens()
	for i = #tweens, 1, -1 do
		local tw = tweens[i]
		local object = tw.Object
		local alive = not tw.Dead and pcall(function() return object.Parent end)
		if not alive then
			table.remove(tweens, i)
			continue
		end
		local t = math.clamp((now - tw.Start) / math.max(tw.Info.Time, 1e-3), 0, 1)
		local a = ease(tw.Info.Style, tw.Info.Dir, t)
		for k, to in tw.Goal2 do
			pcall(function() object[k] = lerp(tw.From[k], to, a) end)
		end
		if t >= 1 then table.remove(tweens, i) end
	end
end

-- Stable keys for instances (Lune hands back a new userdata per access).
local nextKey = 0
local function keyOf(instance)
	local key = instance:GetAttribute("_simKey")
	if not key then
		nextKey += 1
		key = nextKey
		instance:SetAttribute("_simKey", key)
	end
	return key
end

-- Particles ----------------------------------------------------------------------
local particles = {}
local function seqAt(seq, t)
	local kps = seq.Keypoints
	for i = 1, #kps - 1 do
		local a, b = kps[i], kps[i + 1]
		if t <= b.Time then
			local f = (t - a.Time) / math.max(b.Time - a.Time, 1e-6)
			return lerp(a.Value, b.Value, f)
		end
	end
	return kps[#kps].Value
end
local function worldOf(instance)
	if instance:IsA("Attachment") then
		local parent = instance.Parent
		if parent and parent:IsA("BasePart") then
			local ok, offset = pcall(function() return instance.Position end)
			return (parent.CFrame * CF.new(if ok then offset else V3.zero)), parent
		end
	elseif instance:IsA("BasePart") then
		return instance.CFrame, instance
	end
	return nil
end
local function randomDir(spread, frame)
	-- Within `spread` degrees of the emitter's up direction.
	local s = math.rad(math.min(spread, 180))
	local cosT = 1 - math.random() * (1 - math.cos(s))
	local sinT = math.sqrt(1 - cosT * cosT)
	local phi = math.random() * math.pi * 2
	local localDir = V3.new(math.cos(phi) * sinT, cosT, math.sin(phi) * sinT)
	return (frame - frame.Position) * localDir
end
local function emit(emitter, count, spec)
	local frame, part = worldOf(emitter.Parent)
	if not frame then return end
	for _ = 1, count do
		local p = frame.Position
		if spec and spec.Box then
			local s = part.Size
			p = (frame * CF.new((math.random() - 0.5) * s.X, (math.random() - 0.5) * s.Y, (math.random() - 0.5) * s.Z)).Position
		end
		local speed = spec and spec.Speed or emitter.Speed
		local life = spec and spec.Life or emitter.Lifetime
		local v = randomDir(spec and spec.Spread or emitter.SpreadAngle.X, frame) * (speed.Min + math.random() * (speed.Max - speed.Min))
		table.insert(particles, {
			Born = now,
			Life = life.Min + math.random() * (life.Max - life.Min),
			P = p,
			V = v,
			A = spec and spec.Accel or emitter.Acceleration,
			Drag = spec and spec.Drag or emitter.Drag,
			Size = spec and spec.Size or emitter.Size,
			Color = spec and spec.Color or emitter.Color,
			Transparency = spec and spec.Transparency or emitter.Transparency,
			Light = spec and spec.Light or emitter.LightEmission,
		})
	end
end
roblox.implementMethod("ParticleEmitter", "Emit", function(emitter, count)
	emit(emitter, count or 16)
end)
local function stepParticles(dt)
	for i = #particles, 1, -1 do
		local p = particles[i]
		if now - p.Born > p.Life then
			table.remove(particles, i)
		else
			p.V = (p.V + p.A * dt) * (2 ^ (-p.Drag * dt))
			p.P = p.P + p.V * dt
		end
	end
end
-- Continuous emitters: Fire and Smoke instances, emitters with a Rate.
local emitDebt = {}
local function stepContinuous(dt, workspace)
	for _, d in workspace:GetDescendants() do
		local rate, spec
		if d:IsA("Fire") and d.Enabled then
			rate = 26
			spec = {
				Speed = NumberRange.new(1, 2 + d.Heat * 0.2), Life = NumberRange.new(0.3, 0.6),
				Spread = 25, Accel = V3.new(0, d.Heat, 0), Drag = 1,
				Size = roblox.NumberSequence.new(d.Size * 0.35, d.Size * 0.1),
				Color = roblox.ColorSequence.new(d.Color, d.SecondaryColor), Transparency = roblox.NumberSequence.new(0.2, 1), Light = 1,
				Box = true,
			}
		elseif d:IsA("Smoke") and d.Enabled then
			rate = 8
			spec = {
				Speed = NumberRange.new(0.5, 1.5), Life = NumberRange.new(0.8, 1.4), Spread = 30,
				Accel = V3.new(0, d.RiseVelocity, 0), Drag = 1, Size = roblox.NumberSequence.new(d.Size * 0.5, d.Size * 1.5),
				Color = roblox.ColorSequence.new(d.Color), Transparency = roblox.NumberSequence.new(1 - d.Opacity * 2, 1), Light = 0,
			}
		elseif d:IsA("ParticleEmitter") and d.Enabled and d.Rate > 0 then
			rate = d.Rate
			spec = d.Shape == roblox.Enum.ParticleEmitterShape.Box and { Box = true } or nil
			if spec then
				for k, v in { Speed = d.Speed, Life = d.Lifetime, Spread = d.SpreadAngle.X, Accel = d.Acceleration, Drag = d.Drag, Size = d.Size, Color = d.Color, Transparency = d.Transparency, Light = d.LightEmission } do
					spec[k] = v
				end
			end
		end
		if rate then
			local owner = if d:IsA("ParticleEmitter") then d else d
			local key = keyOf(owner)
			emitDebt[key] = (emitDebt[key] or 0) + rate * dt
			local n = math.floor(emitDebt[key])
			if n > 0 then
				emitDebt[key] -= n
				if d:IsA("ParticleEmitter") then
					emit(d, n, spec)
				else
					local fakeEmitter = { Parent = d.Parent }
					emit(fakeEmitter, n, spec)
				end
			end
		end
	end
end

-- Trails: each frame, where its two attachments are (kept for its Lifetime).
local trailSamples = {}
local function stepTrails(workspace)
	for _, d in workspace:GetDescendants() do
		if d:IsA("Trail") and d.Enabled and d.Attachment0 and d.Attachment1 then
			local a = worldOf(d.Attachment0)
			local b = worldOf(d.Attachment1)
			if a and b then
				local key = keyOf(d)
				local list = trailSamples[key] or { Trail = d }
				trailSamples[key] = list
				table.insert(list, { T = now, A = a.Position, B = b.Position })
			end
		end
	end
	for key, list in trailSamples do
		local trail = list.Trail
		local life = trail.Lifetime
		while list[1] and now - list[1].T > life do
			table.remove(list, 1)
		end
		if #list == 0 then
			trailSamples[key] = nil
		end
	end
end

-- Physics for unanchored parts --------------------------------------------------
local bodies = {}
local GRAVITY = 196.2
local function stepPhysics(dt, workspace)
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and not d.Anchored and d.Name ~= "Ground" and d.Parent and d.Parent.Name ~= "StatusAura" then
			local key = keyOf(d)
			local body = bodies[key]
			if not body then
				body = { V = d.AssemblyLinearVelocity, W = d.AssemblyAngularVelocity }
				bodies[key] = body
			end
			body.V = body.V + V3.new(0, -GRAVITY * dt, 0)
			local cf = d.CFrame
			local pos = cf.Position + body.V * dt
			local rot = cf - cf.Position
			local w = body.W
			if w.Magnitude > 1e-3 then
				rot = CF.fromAxisAngle(w.Unit, w.Magnitude * dt) * rot
			end
			local half = (d.Size.X + d.Size.Y + d.Size.Z) / 6
			if d.CanCollide and pos.Y - half < 0 then
				pos = V3.new(pos.X, half, pos.Z)
				if body.V.Y < 0 then
					body.V = V3.new(body.V.X * 0.7, -body.V.Y * 0.4, body.V.Z * 0.7)
					body.W = body.W * 0.6
				end
			end
			d.CFrame = CF.new(pos) * rot
		end
	end
end

-- The world ----------------------------------------------------------------------
local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local sources = {}
local function mount(dir, parent)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			local f = Instance.new("Folder"); f.Name = name; f.Parent = parent; mount(path, f)
		else
			local base = name:match("^(.-)%.client%.luau$") or name:match("^(.-)%.luau$")
			if base then
				local s = Instance.new("ModuleScript"); s.Name = base; s.Parent = parent
				sources[s:GetFullName()] = path
			end
		end
	end
end
local shared = Instance.new("Folder"); shared.Name = "Shared"; shared.Parent = RS
mount(ROOT .. "/src/shared", shared)
local client = Instance.new("Folder"); client.Name = "Client"; client.Parent = RS
mount(ROOT .. "/src/client", client)

local heartbeat = {}
local function signal(list)
	return {
		Connect = function(_, fn)
			local entry = { Fn = fn }
			table.insert(list, entry)
			return { Disconnect = function() entry.Dead = true end }
		end,
	}
end
local localPlayer = Instance.new("Player"); localPlayer.Name = "Tester"; localPlayer.Parent = game:GetService("Players")
local camera = Instance.new("Camera"); camera.Parent = workspace; workspace.CurrentCamera = camera
local services = {
	TweenService = TweenServiceFake,
	Debris = { AddItem = function(_, item, t) fakeTask.delay(t or 10, function() pcall(function() item.Parent = nil end) end) end },
	RunService = {
		Heartbeat = signal(heartbeat), RenderStepped = signal(heartbeat), Stepped = signal(heartbeat),
		BindToRenderStep = function() end, UnbindFromRenderStep = function() end, IsClient = function() return true end,
	},
	Players = setmetatable({
		LocalPlayer = localPlayer,
		GetPlayers = function()
			return { localPlayer }
		end,
		GetPlayerFromCharacter = function(_, model)
			return if model and model == localPlayer.Character then localPlayer else nil
		end,
		PlayerAdded = signal({}),
	}, {
		__index = function(_, k)
			return game:GetService("Players")[k]
		end,
	}),
	PhysicsService = {
		IsCollisionGroupRegistered = function()
			return true
		end,
	},
	CollectionService = {
		-- (Prismatic parts take their own colour, as the shimmer gives them.)
		AddTag = function(_, instance, tag)
			local base = tag == "Prismatic" and instance:GetAttribute("PrismaticBase")
			if base then
				instance.Color = base
			end
		end,
		GetTagged = function() return {} end,
	},
}
local gameProxy = { GetService = function(_, n) return services[n] or game:GetService(n) end }
roblox.implementMethod("Workspace", "Raycast", function(_, origin, direction)
	local target = origin + direction
	if origin.Y >= 0 and target.Y <= 0 then
		local t = origin.Y / (origin.Y - target.Y)
		return { Position = origin:Lerp(target, t), Normal = V3.new(0, 1, 0), Instance = workspace:FindFirstChild("Ground") }
	end
	return nil
end)
-- Roblox lets you read a destroyed instance (Parent is nil); Lune doesn't,
-- so destroying only unparents here.
roblox.implementMethod("Instance", "Destroy", function(instance) instance.Parent = nil end)
roblox.implementMethod("Instance", "WaitForChild", function(instance, name) return instance:FindFirstChild(name) end)

local soundStub = {
	play = function() end, element = function() end,
}
local cache = {}
local env
-- Lune keeps Position and CFrame apart: new parts get a Position, and every
-- part's Position is synced from its CFrame before each scheduled step.
local FakeInstance = {
	new = function(class, parent)
		local object = Instance.new(class)
		if object:IsA("BasePart") then
			object.Position = V3.zero
		end
		if parent then object.Parent = parent end
		return object
	end,
}
function syncPositions()
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") then
			d.Position = d.CFrame.Position
		end
	end
end
local function requireScript(s)
	local key = s:GetFullName()
	if cache[key] ~= nil then return cache[key] end
	if s.Name == "CombatSound" then
		local GemConfig = requireScript(shared.GemConfig)
		soundStub.elementOf = GemConfig.elementOfColor
		cache[key] = soundStub
		return soundStub
	end
	local result = luau.load(fs.readFile(sources[key]), { debugName = sources[key], environment = env(s) })()
	cache[key] = result
	return result
end
NumberRange = roblox.NumberRange
-- Lune's CFrame.lookAt points the wrong way (and gives NaN straight up):
-- the modules get Roblox's.
local function lookAt(at, target, up)
	local look = target - at
	look = if look.Magnitude > 1e-6 then look.Unit else V3.new(0, 0, -1)
	up = up or V3.new(0, 1, 0)
	if math.abs(look:Dot(up.Unit)) > 0.999 then
		up = V3.new(0, 0, 1)
	end
	local right = look:Cross(up).Unit
	return CF.fromMatrix(at, right, right:Cross(look), -look)
end
local CFrameFixed = setmetatable({ lookAt = lookAt }, { __index = CF })
function env(s)
	return setmetatable({
		script = s, require = requireScript, game = gameProxy, workspace = workspace, task = fakeTask, os = fakeOs,
		Instance = FakeInstance, Vector3 = V3, Vector2 = roblox.Vector2, CFrame = CFrameFixed, Color3 = C3,
		Enum = roblox.Enum, UDim = roblox.UDim, UDim2 = roblox.UDim2, ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, NumberRange = roblox.NumberRange,
		TweenInfo = TweenInfoFake, PhysicalProperties = roblox.PhysicalProperties,
		RaycastParams = { new = function() return {} end },
		typeof = typeof, warn = function(...) print("WARN", ...) end,
	}, { __index = _G })
end

local CombatVfx = requireScript(client.Modules.CombatVfx)
local CombatFx = requireScript(client.Modules.CombatFx)
local ElementalDeath = requireScript(client.Modules.ElementalDeath)
local GemConfig = requireScript(shared.GemConfig)

-- A dummy fighter.
local function rig(name, at, tint)
	local model = Instance.new("Model"); model.Name = name
	local function add(partName, size, offset, color)
		local p = Instance.new("Part"); p.Name = partName; p.Size = size; p.Anchored = true
		p.CFrame = CF.new(at) * offset; p.Position = p.CFrame.Position; p.Color = color or tint; p.Material = roblox.Enum.Material.Metal; p.Parent = model
		return p
	end
	local root = add("HumanoidRootPart", V3.new(2, 2, 1), CF.new(0, 0, 0)); root.Transparency = 1
	add("Torso", V3.new(2, 2, 1), CF.new(0, 0, 0))
	add("Chest", V3.new(2.2, 1, 1.2), CF.new(0, 0.6, 0), C3.fromRGB(200, 170, 90))
	add("Head", V3.new(1.2, 1.2, 1.2), CF.new(0, 1.6, 0), C3.fromRGB(220, 190, 160))
	add("Helm", V3.new(1.3, 0.5, 1.3), CF.new(0, 2.1, 0), C3.fromRGB(90, 95, 110))
	add("LeftArm", V3.new(0.9, 2, 0.9), CF.new(-1.5, 0, 0))
	add("RightArm", V3.new(0.9, 2, 0.9), CF.new(1.5, 0, 0))
	add("LeftLeg", V3.new(0.9, 2, 0.9), CF.new(-0.5, -2, 0), C3.fromRGB(60, 62, 72))
	add("RightLeg", V3.new(0.9, 2, 0.9), CF.new(0.5, -2, 0), C3.fromRGB(60, 62, 72))
	add("Sword", V3.new(0.2, 0.2, 3.4), CF.new(1.6, -0.6, -1.4), C3.fromRGB(210, 215, 225))
	local h = Instance.new("Humanoid"); h.Parent = model
	return model
end

local function reset()
	for _, child in workspace:GetChildren() do
		if child ~= camera then child.Parent = nil end
	end
	table.clear(queue); table.clear(tweens); table.clear(particles); table.clear(bodies); table.clear(heartbeat); table.clear(trailSamples)
	now = 0
	local ground = Instance.new("Part"); ground.Name = "Ground"; ground.Anchored = true
	ground.Size = V3.new(120, 1, 120); ground.CFrame = CF.new(0, -0.5, 0); ground.Position = V3.new(0, -0.5, 0); ground.Parent = workspace
	local enemies = Instance.new("Folder"); enemies.Name = "Enemies"; enemies.Parent = workspace
	local me = rig("Attacker", V3.new(0, 3, 0), C3.fromRGB(70, 110, 170)); me.Parent = workspace
	localPlayer.Character = me
	local foe = rig("Foe", V3.new(0, 3, -16), C3.fromRGB(150, 70, 70)); foe.Parent = enemies
	return me, foe
end

local function snapshot()
	local parts, lights, ps = {}, {}, {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Ground" and d.Name ~= "HumanoidRootPart" then
			local okL, ltm = pcall(function() return d.LocalTransparencyModifier end)
			local t = math.max(d.Transparency, if okL then ltm else 0)
			if t < 0.99 and d.Size.Magnitude > 0.01 then
				local cf = d.CFrame
				local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
				local c = d.Color
				table.insert(parts, {
					cf.X, cf.Y, cf.Z, r.X, r.Y, r.Z, u.X, u.Y, u.Z, l.X, l.Y, l.Z,
					d.Size.X, d.Size.Y, d.Size.Z, c.R, c.G, c.B,
					if d:FindFirstChildOfClass("SpecialMesh") and d:FindFirstChildOfClass("SpecialMesh").MeshType.Name == "Sphere" then "Ellipsoid"
						elseif d:IsA("WedgePart") then "Wedge"
						elseif d:IsA("Part") then d.Shape.Name else "Block", t, d.Material.Name,
				})
			end
		elseif d:IsA("PointLight") and d.Enabled and d.Brightness > 0.05 then
			local frame = worldOf(d.Parent)
			if frame then
				table.insert(lights, { frame.X, frame.Y, frame.Z, d.Color.R, d.Color.G, d.Color.B, d.Brightness, d.Range })
			end
		end
	end
	for _, p in particles do
		local f = (now - p.Born) / p.Life
		local c = seqAt(p.Color, f)
		table.insert(ps, { p.P.X, p.P.Y, p.P.Z, seqAt(p.Size, f), c.R, c.G, c.B, 1 - seqAt(p.Transparency, f), p.Light })
	end
	local trails = {}
	for _, list in trailSamples do
		local trail = list.Trail
		for i = 1, #list - 1 do
			local s1, s2 = list[i], list[i + 1]
			local age = math.clamp((now - s2.T) / trail.Lifetime, 0, 1)
			local c = seqAt(trail.Color, age)
			local alpha = 1 - seqAt(trail.Transparency, age)
			local width = seqAt(trail.WidthScale, age)
			local function squeeze(sample)
				local mid = (sample.A + sample.B) / 2
				return mid + (sample.A - mid) * width, mid + (sample.B - mid) * width
			end
			local a1, b1 = squeeze(s1)
			local a2, b2 = squeeze(s2)
			table.insert(trails, { a1.X, a1.Y, a1.Z, b1.X, b1.Y, b1.Z, b2.X, b2.Y, b2.Z, a2.X, a2.Y, a2.Z, c.R, c.G, c.B, alpha, trail.LightEmission })
		end
	end
	return { Parts = parts, Lights = lights, Particles = ps, Trails = trails }
end

local function run(seconds, frames)
	local shots = {}
	local nextFrame = 1
	local dt = 1 / 60
	local maxParts = 0
	while now < seconds do
		now += dt
		table.sort(queue, function(a, b) return a.At < b.At end)
		while queue[1] and queue[1].At <= now do
			local item = table.remove(queue, 1)
			syncPositions()
			if item.Co then resume(item.Co) else item.Fn() end
		end
		syncPositions()
		for _, entry in table.clone(heartbeat) do
			if not entry.Dead then
				local ok, err = pcall(entry.Fn, dt)
				if not ok then table.insert(errors, "heartbeat: " .. tostring(err)) end
			end
		end
		stepTweens()
		stepPhysics(dt, workspace)
		stepTrails(workspace)
		stepContinuous(dt, workspace)
		stepParticles(dt)
		local count = 0
		for _, d in workspace:GetDescendants() do if d:IsA("BasePart") then count += 1 end end
		maxParts = math.max(maxParts, count)
		if frames[nextFrame] and now >= frames[nextFrame] - 1e-6 then
			table.insert(shots, snapshot())
			nextFrame += 1
		end
	end
	return shots, maxParts
end

local ELEMENTS = { "Fire", "Frost", "Shock", "Poison" }
local scenarios = {}

scenarios.Bolt = {
	Frames = { 0.06, 0.12, 0.2, 0.3, 0.45, 0.7 },
	Rows = ELEMENTS,
	Run = function(element, me, foe)
		local color = GemConfig.ElementColors[element]
		local from, to = V3.new(0.8, 4.5, -1.2), V3.new(0, 4, -16)
		CombatVfx.beam(from, to, color, 0)
		fakeTask.delay(0.2, function()
			CombatVfx.impact(to, color, false, true)
			CombatVfx.element(to, element, 1)
		end)
	end,
}
scenarios.Blast = {
	Frames = { 0.08, 0.18, 0.3, 0.45, 0.7, 1.1 },
	Rows = ELEMENTS,
	Run = function(element, me, foe)
		local color = GemConfig.ElementColors[element]
		CombatVfx.beam(V3.new(0, 4.5, -1), V3.new(0, 1, -14), color, 8)
	end,
}
scenarios.Aura = {
	Frames = { 0.05, 0.12, 0.22, 0.35, 0.5, 0.8 },
	Rows = ELEMENTS,
	Run = function(element, me)
		CombatVfx.aura(me.HumanoidRootPart, GemConfig.ElementColors[element])
	end,
}
scenarios.Hit = {
	Frames = { 0.03, 0.08, 0.15, 0.25, 0.4, 0.6 },
	Rows = ELEMENTS,
	Run = function(element, me, foe)
		local at = V3.new(0, 3.6, -15.3)
		CombatVfx.impact(at, GemConfig.ElementColors[element], true, true)
		CombatVfx.element(at, element, 1.4)
	end,
}
scenarios.Death = {
	Frames = { 0.2, 0.5, 0.75, 0.95, 1.3, 2.4 },
	Rows = { "Fire", "Frost", "Shock", "Poison", "None" },
	Run = function(element, me, foe)
		local ok = ElementalDeath.play(foe, if element == "None" then nil else element, C3.fromRGB(255, 180, 120))
		if not ok then table.insert(errors, "death did not play " .. element) end
	end,
}

-- The starter moves' own looks (MoveVfx), four per element: each row one
-- move, landing on the foe 16 studs ahead.
local MoveVfx = requireScript(client.Modules.MoveVfx)
local MOVE_FRAMES = { 0.1, 0.25, 0.45, 0.7, 1.1, 1.6 }
local foeAt, meAt = V3.new(0, 3, -16), V3.new(0, 3, 0)
local function show(...)
	MoveVfx.show(nil, ...)
end
local MOVES = {
	MovesFire = {
		{ "Meteor Leap", function(me)
			MoveVfx.show(localPlayer, "MeteorLeapJump", meAt, V3.new(0, 3, -12), 0.4)
			fakeTask.delay(0.4, function()
				show("MeteorLeap", V3.new(0, 3, -12), V3.new(0, 3, -12), 9.6)
				show("Crater", V3.new(0, 3, -12), 5, 3)
			end)
		end },
		{ "Flame Tornado", function()
			show("FlameTornado", V3.new(0, 3, -3), V3.new(0, 3, -22), 1.4, 4.5)
			fakeTask.delay(1.4, function()
				show("VortexEnd", V3.new(0, 3, -22), 6)
			end)
		end },
		{ "Magma Fault", function()
			show("MagmaFault", V3.new(0, 4.5, -1), V3.new(0, 4.5, -15), 2)
		end },
		{ "Supernova", function(me)
			MoveVfx.cast(localPlayer, "E_Supernova", 0.3)
			fakeTask.delay(0.3, function()
				show("Supernova", V3.new(0, 4.5, -1), foeAt, 15)
			end)
		end },
	},
	MovesFrost = {
		{ "Frost Chakram", function()
			MoveVfx.show(localPlayer, "FrostChakram", V3.new(0, 3, -1.5), V3.new(0, 3, -17.5), 1.1, 3)
		end },
		{ "Hailstorm", function()
			show("Hailstorm", foeAt, 9, 1.5)
		end },
		{ "Permafrost Spire", function()
			show("PermafrostSpire", V3.new(0, 4.5, -1), foeAt, 9)
		end },
		{ "Absolute Zero", function()
			show("AbsoluteZero", V3.new(0, 4.5, -1), foeAt, 15)
		end },
	},
	MovesShock = {
		{ "Thunder Dash", function()
			show("ThunderDash", meAt, V3.new(0, 3, -13), 0.14)
		end },
		{ "Skybreaker", function()
			MoveVfx.cast(localPlayer, "Q_Skybreaker", 0.2)
			fakeTask.delay(0.2, function()
				show("Skybreaker", V3.new(0, 4.5, -1), foeAt, 9)
			end)
		end },
		{ "Storm Call", function()
			show("StormCall", foeAt, 11, 1.5)
			for n = 0, 2 do
				fakeTask.delay(0.1 + n * 0.45, function()
					local at = foeAt + V3.new(n - 1, 0, 0)
					show("StormWarn", at, 3.2, 0.4)
					fakeTask.delay(0.4, function()
						show("StormBolt", at, 3.2, if n == 2 then 1 else 0)
					end)
				end)
			end
		end },
		{ "Ion Cannon", function()
			MoveVfx.cast(localPlayer, "E_IonCannon", 0.3)
			fakeTask.delay(0.3, function()
				show("IonCannon", V3.new(0, 4.5, -1), V3.new(0, 4.5, -46), 3.5)
			end)
		end },
	},
	MovesPoison = {
		{ "Viper Lash", function()
			show("ViperLash", V3.new(0.6, 4.5, -1), V3.new(0, 4, -16), 1)
		end },
		{ "Toxic Flask", function()
			show("ToxicFlaskThrow", V3.new(0.6, 4.5, -1), foeAt, 0.4)
			fakeTask.delay(0.4, function()
				show("ToxicFlask", V3.new(0, 4.5, -1), foeAt, 9)
				show("Puddle", foeAt, 5, 3)
			end)
		end },
		{ "Toxic Tide", function()
			show("ToxicTide", meAt, V3.new(0, 3, -24), 1.2, 11)
		end },
		{ "Maneater", function()
			show("Maneater", V3.new(0, 4.5, -1), foeAt, 9)
		end },
	},
}
for name, rows in MOVES do
	local labels, byLabel = {}, {}
	for _, row in rows do
		table.insert(labels, row[1])
		byLabel[row[1]] = row[2]
	end
	scenarios[name] = {
		Frames = MOVE_FRAMES,
		Rows = labels,
		Run = function(label, me, foe)
			byLabel[label](me, foe)
		end,
	}
end

-- The starter R moves (TriadVfx): each element's barrier and its escape,
-- cast where you stand, facing the foe.
local TriadVfx = requireScript(client.Modules.TriadVfx)
local facing = CF.lookAt(meAt, foeAt)
local DEFENSE_FRAMES = { 0.1, 0.25, 0.5, 1, 1.8, 2.6 }
local DEFENSES = {
	DefenseFireFrost = {
		{ "Fire Wall", function()
			TriadVfx.wall(localPlayer, "Fire", facing * CF.new(0, 0, -5), 10, 2.4, "Fire")
		end },
		{ "Ring of Fire", function()
			TriadVfx.ring(localPlayer, 7, 2.4, "Fire")
		end },
		{ "Frozen Wall", function()
			TriadVfx.wall(localPlayer, "Ice", facing * CF.new(0, 0, -3.5), 8, 2.4, "Frost")
		end },
		{ "Ice Pillar", function()
			TriadVfx.pillar(localPlayer, V3.new(0, 0, 0), 9, 2.4, "Frost")
		end },
	},
	DefenseShockPoison = {
		{ "Tesla Fence", function()
			TriadVfx.wall(localPlayer, "Tesla", facing * CF.new(0, 0, -5), 10, 2.4, "Shock")
		end },
		{ "Hologram Decoy", function()
			TriadVfx.decoy(localPlayer, V3.new(0, 3, -6), 3, "Shock")
			fakeTask.delay(1.6, function()
				TriadVfx.decoyPop(localPlayer, V3.new(0, 3, -6), 6)
			end)
		end },
		{ "Spore Wall", function()
			TriadVfx.wall(localPlayer, "Spore", facing * CF.new(0, 0, -5), 10, 2.4, "Poison")
		end },
		{ "Acid Slick", function()
			TriadVfx.slick(V3.new(0, 3, -4), 7, 2.4, "Poison")
		end },
	},
}
for name, rows in DEFENSES do
	local labels, byLabel = {}, {}
	for _, row in rows do
		table.insert(labels, row[1])
		byLabel[row[1]] = row[2]
	end
	scenarios[name] = {
		Frames = DEFENSE_FRAMES,
		Rows = labels,
		Run = function(label, me, foe)
			byLabel[label](me, foe)
		end,
	}
end

-- A kaiju's move at its size (FxSize, as the server's "Sized" sends it):
-- each move as you cast it, then as a pet kaiju (knee high, Kaiju.size of
-- its scale) does, its area shrunk by the server as KaijuAbilities does.
-- The largest camera shake each one asks for is printed.
local FxSize = requireScript(client.Modules.FxSize)
local Kaiju = requireScript(shared.Kaiju)
local PET = Kaiju.size(Kaiju.Scale.Pet)
local shook = 0
local shake = CombatFx.shake
CombatFx.shake = function(strength, seconds)
	local k = FxSize.get()
	shook = math.max(shook, strength * k * k)
	shake(strength, seconds)
end
local function stand(size)
	-- A stand-in for the kaiju casting it, as tall as it stands.
	local body = Instance.new("Part")
	body.Name = "Kaiju"
	body.Anchored = true
	body.Size = V3.new(1.4, 4, 2.2) * size
	body.Color = C3.fromRGB(60, 64, 80)
	body.Material = roblox.Enum.Material.Metal
	body.CFrame = CF.new(0, 2 * size, 0)
	body.Position = body.CFrame.Position
	body.Parent = workspace
end
local SIZED = {
	{
		"Supernova (you)",
		1,
		function(k)
			show("Supernova", V3.new(0, 4.5, -1), foeAt, 10 * k)
		end,
	},
	{
		"Supernova (pet kaiju)",
		PET,
		function(k)
			show("Supernova", V3.new(0, 2, -1), V3.new(0, 1, -8), 10 * k)
		end,
	},
	{
		"Toxic Tide (you)",
		1,
		function(k)
			show("ToxicTide", meAt, V3.new(0, 3, -24 * k), 1.2, 8 * k)
		end,
	},
	{
		"Toxic Tide (pet kaiju)",
		PET,
		function(k)
			show("ToxicTide", V3.new(0, 1, 0), V3.new(0, 1, -24 * k), 1.2, 8 * k)
		end,
	},
}
local sizedRows, sizedBy = {}, {}
for _, row in SIZED do
	table.insert(sizedRows, row[1])
	sizedBy[row[1]] = row
end
scenarios.Sized = {
	Frames = { 0.1, 0.25, 0.45, 0.7, 1.1 },
	Rows = sizedRows,
	Run = function(label, me)
		local row = sizedBy[label]
		shook = 0
		if row[2] ~= 1 then
			me.Parent = nil
			stand(row[2])
		end
		FxSize.run(row[2], row[3], row[2])
		fakeTask.delay(1.1, function()
			print(string.format("Sized  %-24s shake %.3f", label, shook))
		end)
	end,
}

-- Pickaxe skins (Shared.PickaxeLooks): each one swung down through an arc,
-- side on, its particles drifting and its trail streaking through the swing.
local PickaxeLooks = requireScript(shared.PickaxeLooks)
local PickImpacts = requireScript(client.Modules.PickImpacts)
local PICKS = { "PickMagma", "PickStorm", "PickVoid", "PickGlacier", "PickPrism", "PickNeon", "PickGilded", "PickGeode", "PickBone", "PickTwinStar", "Standard" }
scenarios.Picks = {
	Frames = { 0.12, 0.34, 0.42, 0.5, 0.62 },
	Rows = PICKS,
	Run = function(id, me, foe)
		me.Parent, foe.Parent = nil, nil
		local shoulder = CF.new(0, 4.2, 0)
		local function swing(t)
			-- Held back, then down through the rock in a fifth of a second.
			local k = math.clamp((t - 0.3) / 0.2, 0, 1)
			local angle = 0.7 - k * k * 2.6
			return shoulder * CF.Angles(angle, 0, 0) * CF.new(0, 0.9, 0)
		end
		local model = Instance.new("Model"); model.Parent = workspace
		local start = swing(0)
		local parts = if id == "Standard"
			then PickaxeLooks.build(model, start, nil, C3.fromRGB(110, 200, 255), nil, true)
			else PickaxeLooks.build(model, start, id)
		local offsets = {}
		for _, part in parts do
			offsets[part] = start:ToObjectSpace(part.CFrame)
		end
		table.insert(heartbeat, { Fn = function()
			local frame = swing(now)
			for part, offset in offsets do
				part.CFrame = frame * offset
			end
		end })
	end,
}
-- Close up, turning on a stand: the profile, three-quarters, the far side.
scenarios.PickLineup = {
	Frames = { 0.1, 0.55, 2.1 },
	Rows = PICKS,
	Run = function(id, me, foe)
		me.Parent, foe.Parent = nil, nil
		local function stand(t)
			return CF.new(0, 4.4, 0) * CF.Angles(0, t * 1.4, 0) * CF.Angles(0, 0, math.rad(-30))
				* CF.Angles(0, -math.pi / 2, 0) * CF.new(0, -1.3, 0)
		end
		local model = Instance.new("Model"); model.Parent = workspace
		local start = stand(0)
		local parts = if id == "Standard"
			then PickaxeLooks.build(model, start, nil, C3.fromRGB(110, 200, 255), nil, true)
			else PickaxeLooks.build(model, start, id)
		local offsets = {}
		for _, part in parts do
			offsets[part] = start:ToObjectSpace(part.CFrame)
		end
		table.insert(heartbeat, { Fn = function()
			local frame = stand(now)
			for part, offset in offsets do
				part.CFrame = frame * offset
			end
		end })
	end,
}
-- Each skin's hit on a rock (PickImpacts), and the critical hits.
local IMPACTS = { "Magma", "Frost", "Storm", "Void", "Gold", "Prism", "Neon", "Bone", "Geode", "TwinStar", "Storm crit", "Magma crit" }
scenarios.PickHits = {
	Frames = { 0.05, 0.12, 0.2, 0.3, 0.45, 0.7 },
	Rows = IMPACTS,
	Run = function(row, me, foe)
		foe.Parent = nil
		local rock = Instance.new("Part"); rock.Name = "Rock"; rock.Anchored = true
		rock.Size = V3.new(5, 4.4, 5); rock.Color = C3.fromRGB(118, 112, 122); rock.Material = roblox.Enum.Material.Slate
		rock.CFrame = CF.new(0, 2.2, -8.5) * CF.Angles(0.15, 0.6, 0.1); rock.Parent = workspace
		local kind, crit = row:match("^(%a+)( ?c?r?i?t?)$")
		PickImpacts.play(kind, V3.new(0, 3, -5.9), V3.new(0, 3, 0), 0.7, crit == " crit", 1)
	end,
}

-- The elements on the ground (ElementFx), at a wild kaiju's size: its
-- blast warned of and going off, the ground a move leaves, a heavy blow's
-- stomp, its bolt, and a critter's bomb. "before" rows replay what a
-- blast was before: rings, then a pillar of light out of the ground.
local ElementFx = requireScript(client.Modules.ElementFx)
local WILD = Kaiju.size(Kaiju.Scale.Wild)
local GROUND_AT = V3.new(0, 0.15, -8)
local function oldNova(color, radius, delay, k)
	-- (Combat.client's Nova as it was: a red ring, then a dome, waves and a pillar.)
	local function neon(size, cf, c, shape, t)
		local p = Instance.new("Part"); p.Anchored = true; p.Material = roblox.Enum.Material.Neon; p.Color = c
		p.Size = size; p.CFrame = cf; p.Position = cf.Position; p.Transparency = t or 0
		if shape then p.Shape = shape end
		p.Parent = workspace
		return p
	end
	local function ring(r, c, t)
		return neon(V3.new(0.2, r * 2, r * 2), CF.new(GROUND_AT) * CF.Angles(0, 0, math.rad(90)), c, roblox.Enum.PartType.Cylinder, t)
	end
	local function fadeOut(part, seconds, grow)
		TweenServiceFake:Create(part, TweenInfoFake.new(seconds), { Transparency = 1, Size = grow or part.Size }):Play()
		fakeTask.delay(seconds, function() part.Parent = nil end)
	end
	local warn = ring(radius, C3.fromRGB(255, 60, 40), 0.55)
	fakeTask.delay(delay, function()
		warn.Parent = nil
		local dome = neon(V3.one * radius * 0.4, CF.new(GROUND_AT), color, roblox.Enum.PartType.Ball, 0.15)
		fadeOut(dome, 0.35, V3.one * radius * 2)
		local wave = ring(1, color, 0.05)
		fadeOut(wave, 0.3, V3.new(0.3, radius * 2.1, radius * 2.1))
		local pillar = neon(V3.new(2, 40, 2) * k, CF.new(GROUND_AT + V3.new(0, 20 * k, 0)), color)
		fadeOut(pillar, 0.45, V3.new(radius * 0.8, 46 * k, radius * 0.8))
		FxSize.run(k, function()
			CombatFx.burst(GROUND_AT + V3.new(0, 1, 0), color, "Embers", 1.8 + radius / 6)
			CombatFx.burst(GROUND_AT + V3.new(0, 0.5, 0), C3.fromRGB(120, 110, 100), "Smoke", 1.8 + radius / 10)
		end)
	end)
end
local function kaijuRows(withBefore)
	local rows = {}
	for _, element in ELEMENTS do
		if withBefore then
			table.insert(rows, element .. " before")
		end
		table.insert(rows, element)
	end
	return rows
end
local function asKaiju(me, foe)
	me.Parent, foe.Parent = nil, nil
	stand(WILD)
end
scenarios.KaijuBlast = {
	Frames = { 0.3, 0.8, 0.98, 1.08, 1.25, 1.6 },
	Rows = kaijuRows(true),
	Run = function(row, me, foe)
		asKaiju(me, foe)
		local element = row:match("^(%a+)")
		local color = GemConfig.ElementColors[element]
		local radius = 8 * WILD
		if row:find("before") then
			oldNova(color, radius, 0.9, WILD)
			return
		end
		FxSize.run(WILD, function()
			ElementFx.telegraph(GROUND_AT, radius, color, 0.9)
			fakeTask.delay(0.9, FxSize.keep(function()
				ElementFx.erupt(GROUND_AT, radius, color)
			end))
		end)
	end,
}
scenarios.KaijuField = {
	Frames = { 0.15, 0.5, 1.0, 1.6, 2.2 },
	Rows = ELEMENTS,
	Run = function(element, me, foe)
		asKaiju(me, foe)
		FxSize.run(WILD, function()
			ElementFx.field(GROUND_AT, 8 * WILD, 2.5, GemConfig.ElementColors[element])
		end)
	end,
}
scenarios.KaijuStomp = {
	Frames = { 0.6, 0.85, 1.0, 1.12, 1.3, 1.55 },
	Rows = ELEMENTS,
	Run = function(element, me, foe)
		asKaiju(me, foe)
		local color = GemConfig.ElementColors[element]
		local feet = V3.new(0, 0.15, 0)
		FxSize.run(WILD, function()
			-- A heavy: its warning, then the stomp as it lands.
			ElementFx.telegraph(feet, 3.5, color, 0.9)
			fakeTask.delay(0.9, FxSize.keep(function()
				ElementFx.stomp(feet, 3.5, color)
			end))
		end)
	end,
}
scenarios.KaijuBolt = {
	Frames = { 0.04, 0.09, 0.15, 0.22, 0.32, 0.5 },
	Rows = ELEMENTS,
	Run = function(element, me, foe)
		asKaiju(me, foe)
		FxSize.run(WILD, function()
			ElementFx.bolt(V3.new(0, 2.6, -0.6), V3.new(0, 1.5, -15), GemConfig.ElementColors[element])
		end)
	end,
}
scenarios.KaijuSpine = {
	Frames = { 0.04, 0.1, 0.17, 0.24, 0.32, 0.5 },
	Rows = ELEMENTS,
	Run = function(element, me, foe)
		asKaiju(me, foe)
		local color = GemConfig.ElementColors[element]
		FxSize.run(WILD, function()
			-- (A volley: three spines, Gap apart, at a foe 14 studs off.)
			for i = 0, 2 do
				fakeTask.delay(i * 0.15, FxSize.keep(function()
					ElementFx.spine(V3.new(0, 2.4, -0.8), V3.new((i - 1) * 0.6, 1.4, -14), color)
				end))
			end
		end)
	end,
}
scenarios.KaijuBomb = {
	Frames = { 0.2, 0.45, 0.7, 0.85, 1.0, 1.3 },
	Rows = ELEMENTS,
	Run = function(element, me, foe)
		asKaiju(me, foe)
		local color = GemConfig.ElementColors[element]
		local bug = Kaiju.Bug.Size
		FxSize.run(bug, function()
			-- (KaijuWilds' lob: the bomb's Shot and the Nova it lands as.)
			ElementFx.lob(V3.new(0, 2, 0), GROUND_AT, color, 0.75)
			ElementFx.telegraph(GROUND_AT, 5 * bug, color, 0.75)
			fakeTask.delay(0.75, FxSize.keep(function()
				ElementFx.erupt(GROUND_AT, 5 * bug, color)
			end))
		end)
	end,
}

local only = process.args[3]
local summary = {}
for name, scenario in scenarios do
	if only and only ~= name then continue end
	local sheet = { Name = name, Frames = scenario.Frames, Rows = {} }
	for _, element in scenario.Rows do
		local me, foe = reset()
		local before = #errors
		syncPositions()
		scenario.Run(element, me, foe)
		local shots, maxParts = run(scenario.Frames[#scenario.Frames] + 0.05, scenario.Frames)
		table.insert(sheet.Rows, { Label = element, Shots = shots })
		table.insert(summary, string.format("%-6s %-7s peak parts %4d  errors %d", name, element, maxParts, #errors - before))
	end
	fs.writeFile(OUT .. "/" .. name .. ".json", serde.encode("json", sheet))
end
print(table.concat(summary, "\n"))
for _, e in errors do print("ERROR", e) end
