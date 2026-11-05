-- Personal pods: the rules (Shared.Pods) and the real Server.PodServer on
-- Roblox instances (lune's roblox library), on the settlement's real pads
-- (Shared.Outpost.padSpots), with a clock and Players we drive.
-- Run by tests/run_pods.py (needs lune).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local R = roblox
local ROOT = process.args[1] or "."
-- (lune's CFrame.lookAt turns the wrong way off the axes: a correct one)
local FixedCFrame = setmetatable({
	lookAt = function(pos, target)
		local f = (target - pos).Unit
		local r = f:Cross(R.Vector3.new(0, 1, 0))
		r = if r.Magnitude < 1e-4 then R.Vector3.new(1, 0, 0) else r.Unit
		return R.CFrame.fromMatrix(pos, r, r:Cross(f), -f)
	end,
}, { __index = R.CFrame })

local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end

local now = 0
local delayed = {}
local fakeTask = {
	delay = function(seconds, fn, ...)
		table.insert(delayed, { now + seconds, fn, table.pack(...) })
	end,
	spawn = function(fn, ...)
		local thread = coroutine.create(fn)
		local ok, problem = coroutine.resume(thread, ...)
		assert(ok, problem)
	end,
}
local function signal()
	local fns = {}
	return {
		Connect = function(_, fn)
			table.insert(fns, fn)
		end,
		Fire = function(_, ...)
			for _, fn in fns do
				fn(...)
			end
		end,
	}
end
local Heartbeat = signal()
local function advance(seconds, step)
	step = step or 1 / 30
	local t = 0
	while t < seconds - 1e-9 do
		local dt = math.min(step, seconds - t)
		t += dt
		now += dt
		Heartbeat:Fire(dt)
		for i = #delayed, 1, -1 do
			local d = delayed[i]
			if now >= d[1] then
				table.remove(delayed, i)
				d[2](table.unpack(d[3], 1, d[3].n))
			end
		end
	end
end

local Rand = {}
Rand.__index = Rand
function Rand.new(seed)
	return setmetatable({ x = (seed or 7) % 2147483647 + 1 }, Rand)
end
function Rand:_n()
	self.x = (self.x * 48271) % 2147483647
	return self.x / 2147483647
end
function Rand:NextNumber(a, b)
	a, b = a or 0, b or 1
	return a + (b - a) * self:_n()
end
function Rand:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_n())
end

local function load(path, name, env)
	local base = setmetatable(env or {}, { __index = _G })
	base.CFrame, base.Vector3, base.Color3 = R.CFrame, R.Vector3, R.Color3
	return luau.load(fs.readFile(ROOT .. "/" .. path), { debugName = name, environment = base })()
end
local Outpost = load("src/shared/Outpost.luau", "Outpost")
local Pods = load("src/shared/Pods.luau", "Pods")

-- The rules ----------------------------------------------------------------------------------
-- A beacon colour each, the same every time.
check(Pods.colorFor(12345) == Pods.colorFor(12345), "A beacon changes colour")
local colours = {}
for id = 1, #Pods.Colors do
	colours[tostring(Pods.colorFor(id))] = true
end
local distinct = 0
for _ in colours do
	distinct += 1
end
check(distinct == #Pods.Colors, "Neighbouring players share a beacon colour")
-- Down from on high, braking onto the pad; up and away the same.
check(Pods.altitude(0) == Pods.Landing.Height and Pods.altitude(Pods.Landing.Fall) == 0, "The landing doesn't start high and end on the pad")
local last = math.huge
for i = 0, 40 do
	local h = Pods.altitude(i / 40 * Pods.Landing.Fall)
	check(h <= last, "The pod goes back up while landing")
	last = h
end
check(Pods.altitude(Pods.Landing.Fall * 0.9) < 1, "The pod hits the pad hard (no braking)")
check(Pods.lift(0) == 0 and Pods.lift(Pods.Landing.LiftOff) == Pods.Landing.Height, "The lift-off doesn't go from the pad up out of sight")
check(Pods.Landing.Failsafe > Pods.Landing.Fall, "The failsafe lands it before the landing ends")

-- The settlement's pads, each facing the Heart (as Server.World.OutpostWorld turns them).
local at = R.CFrame.new(0, 0, 7000)
local mid = at.Position
local pads = {}
for index, spot in Outpost.padSpots() do
	local p = (at * R.CFrame.new(spot.Offset.X, 0, spot.Offset.Z)).Position
	local yaw = math.atan2(-(mid.X - p.X), -(mid.Z - p.Z))
	local frame = R.CFrame.new(p) * R.CFrame.Angles(0, yaw, 0)
	local model = R.Instance.new("Model")
	model.Name = "Pad" .. index
	table.insert(pads, { Index = index, Tier = spot.Tier, CFrame = frame * R.CFrame.new(0, 1.1, 0), Model = model })
end
check(#pads == 50, "Not 50 pads")
local function flat(v)
	return R.Vector3.new(v.X, 0, v.Z).Magnitude
end
-- The ramp's foot: in front of the pod toward the Heart, off the pad, clear of the hull.
for _, pad in pads do
	local foot = Pods.spawnAt(pad.CFrame)
	local fromPad = flat(foot.Position - pad.CFrame.Position)
	check(fromPad > Pods.Hull + Pods.Ramp and fromPad < Outpost.Settlement.Pad + 6, "The spawn isn't at the foot of the ramp")
	check(flat(foot.Position - mid) < flat(pad.CFrame.Position - mid) - Pods.Hull, "The ramp doesn't face the Heart")
	check(foot.Position.Y > pad.CFrame.Position.Y, "The spawn is under the pad")
	-- (and you stand facing the Heart)
	local ahead = foot * R.CFrame.new(0, 0, -10)
	check(flat(ahead.Position - mid) < flat(foot.Position - mid), "You don't stand facing the Heart")
end
-- choose: the inner tier first, then a friend's neighbour, never a taken pad.
local rng = Rand.new(3)
local taken = {}
local first = Pods.choose(pads, taken, {}, rng)
check(first and pads[first].Tier == 1, "The first pod isn't on the inner tier")
for _ = 1, 30 do
	local i = Pods.choose(pads, taken, {}, rng)
	check(i and not taken[i], "Two pods on one pad")
	taken[i] = true
end
local tierOneLeft = 0
for _, pad in pads do
	if pad.Tier == 1 and not taken[pad.Index] then
		tierOneLeft += 1
	end
end
check(tierOneLeft == 0, "The outer tier filled before the inner")
local friend = nil
for _, pad in pads do
	if taken[pad.Index] and pad.Tier == 1 then
		friend = pad.Index
		break
	end
end
local beside = Pods.choose(pads, taken, { friend }, rng)
local bestGap = math.huge
for _, pad in pads do
	if not taken[pad.Index] then
		bestGap = math.min(bestGap, (pad.CFrame.Position - pads[friend].CFrame.Position).Magnitude)
	end
end
check((pads[beside].CFrame.Position - pads[friend].CFrame.Position).Magnitude == bestGap, "A friend's pod isn't next to theirs")
for _, pad in pads do
	taken[pad.Index] = true
end
check(Pods.choose(pads, taken, {}, rng) == nil, "A pod with every pad taken")

-- The server ---------------------------------------------------------------------------------
local playerList = {}
local friendsOf = {}
local Players = {
	PlayerAdded = signal(),
	PlayerRemoving = signal(),
	GetPlayers = function()
		return playerList
	end,
	GetFriendsAsync = function(_, userId)
		local list = {}
		for _, id in friendsOf[userId] or {} do
			table.insert(list, { Id = id })
		end
		return {
			IsFinished = true,
			GetCurrentPage = function()
				return list
			end,
		}
	end,
}
local replicated = { Shared = { Pods = "Pods" } }
local moved = {}
local workspaceRoot = R.Instance.new("Folder")
local env = setmetatable({
	game = {
		GetService = function(_, name)
			return ({ Players = Players, ReplicatedStorage = replicated, RunService = { Heartbeat = Heartbeat } })[name]
		end,
	},
	workspace = workspaceRoot,
	Instance = R.Instance,
	CFrame = FixedCFrame,
	Vector3 = R.Vector3,
	Vector2 = R.Vector2,
	Color3 = R.Color3,
	UDim2 = R.UDim2,
	Enum = R.Enum,
	ColorSequence = R.ColorSequence,
	NumberSequence = R.NumberSequence,
	NumberSequenceKeypoint = R.NumberSequenceKeypoint,
	NumberRange = R.NumberRange,
	Random = Rand,
	task = fakeTask,
	typeof = R.typeof or typeof,
	require = function(m)
		return ({ Pods = Pods })[m]
	end,
	__now = function()
		return now
	end,
	__moveTo = function(humanoid, at)
		moved[humanoid.Parent.Name] = at -- (by name: lune's instances aren't the same table twice)
	end,
}, { __index = _G })
-- lune's Model has no PivotTo/GetPivot: move every part by the same step
-- (a character by its root).
env.__getPivot = function(model)
	return model.PrimaryPart.CFrame
end
env.__pivot = function(model, cframe)
	local step = cframe * model.PrimaryPart.CFrame:Inverse()
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = step * p.CFrame
		end
	end
end
local source = fs.readFile(ROOT .. "/src/server/Systems/PodServer.luau")
source = string.gsub(source, "workspace:GetServerTimeNow%(%)", "__now()")
-- (lune's Humanoid has no MoveTo: where they were sent, by character)
source = string.gsub(source, "humanoid:MoveTo%(", "__moveTo(humanoid, ")
source = string.gsub(source, "([%w_%.]+):PivotTo%(", "__pivot(%1, ")
source = string.gsub(source, "([%w_%.]+):GetPivot%(%)", "__getPivot(%1)")
local Server = luau.load(source, { debugName = "PodServer", environment = env })()

local function makePlayer(id, name)
	local character = R.Instance.new("Model")
	character.Name = name
	local root = R.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	character.PrimaryPart = root
	R.Instance.new("Humanoid").Parent = character
	local p = { UserId = id, DisplayName = name, Name = name, Parent = Players, Attributes = {}, Character = character }
	function p:GetAttribute(k)
		return self.Attributes[k]
	end
	function p:SetAttribute(k, v)
		self.Attributes[k] = v
	end
	p.Attributes.Outpost = true
	table.insert(playerList, p)
	Players.PlayerAdded:Fire(p)
	return p, root
end
local function leave(p)
	table.remove(playerList, table.find(playerList, p))
	p.Parent = nil
	Players.PlayerRemoving:Fire(p)
end
-- (lune won't read a destroyed instance's Parent: gone is gone)
local function gone(model)
	local ok, parent = pcall(function()
		return model.Parent
	end)
	return not ok or parent == nil
end
local function podModel(p)
	local index = p:GetAttribute("PodIndex")
	return index and pads[index].Model:FindFirstChild("Pod")
end
local REST = Pods.Base + 2.3 * Pods.Scale -- (the hull's middle over the pad, landed)
local function hullHeight(p)
	local model = podModel(p)
	return model.PrimaryPart.CFrame.Position.Y - pads[p:GetAttribute("PodIndex")].CFrame.Position.Y
end
local function local_(p, part)
	return pads[p:GetAttribute("PodIndex")].CFrame:PointToObjectSpace(part.CFrame.Position)
end
local function firstNamed(model, name)
	local list = {}
	for _, c in model:GetChildren() do
		if c.Name == name then
			table.insert(list, c)
		end
	end
	return list
end
local L = Pods.Landing

-- Joining keeps a pad (someone already here when it starts too); no pod yet.
local early = makePlayer(10, "Early")
Server.start({ Pads = pads })
check(typeof(early:GetAttribute("PodIndex")) == "number", "A player already here has no pad")
local ana, anaRoot = makePlayer(1, "Ana")
local index = ana:GetAttribute("PodIndex")
check(type(index) == "number" and index ~= early:GetAttribute("PodIndex"), "Two players share a pad")
check(Server.spawnFor(ana) == Pods.spawnAt(pads[index].CFrame), "No spawn at the pod's stair")
check(podModel(ana) == nil, "A pod landed before they came into the Outpost")

-- In the Outpost: it lands with them inside, up overhead until the descent starts.
check(Server.land(ana) == true, "The pod didn't come down")
check(Server.land(ana) == false, "The pod came down twice")
check(math.abs(ana:GetAttribute("PodLanding") - (now + L.Lead)) < 1e-6, "No time for the client's cinematic")
local pod = podModel(ana)
check(pod and pod.PrimaryPart and pod.PrimaryPart.Name == "Hull", "No pod built")
check(pod:GetAttribute("OwnerId") == ana.UserId, "The pod doesn't say whose it is")
local plate = pod.PrimaryPart:FindFirstChild("Nameplate")
check(plate and plate:FindFirstChildOfClass("TextLabel").Text == "Ana", "No nameplate with their name")
local beacon = pod:FindFirstChild("Beacon")
check(beacon and beacon.Color == Pods.colorFor(ana.UserId) and beacon:FindFirstChildOfClass("PointLight"), "No beacon in their colour")
check(hullHeight(ana) > L.Height * 0.99, "The pod doesn't start up in the sky")
check(pod.Thruster.Transparency < 1, "No thrusters on the way down")
local function inside()
	local q = pod.PrimaryPart.CFrame:PointToObjectSpace(anaRoot.CFrame.Position)
	return anaRoot.Anchored and math.abs(q.X) < Pods.Width / 2 and math.abs(q.Z) < Pods.Hull and math.abs(q.Y) < 3
end
check(inside(), "The rider isn't inside the pod")
-- stowed for the flight: the stair under the doors, the doors shut, the wings folded, the legs up
local ramp = pod:FindFirstChild("Ramp")
check(local_(ana, ramp).Z > -Pods.Hull - 1, "The stair is out in flight")
local leaves = firstNamed(pod, "DoorLeaf")
check(#leaves == 2 and math.abs(local_(ana, leaves[1]).X) < 1.3, "The doors are open in flight")
local wings = firstNamed(pod, "Wing")
check(#wings == 2 and math.abs(local_(ana, wings[1]).X) < Pods.Width / 2, "The wings are out in flight")
advance(L.Lead * 0.9)
check(hullHeight(ana) > L.Height * 0.99, "It came down before the cinematic's start")
advance(L.Lead * 0.1 + L.Fall / 2)
local h1 = hullHeight(ana)
check(h1 < L.Height * 0.5 and h1 > REST, "The pod isn't on its way down")
check(inside(), "The rider was left behind")
local legs = firstNamed(pod, "Leg")
check(#legs == 4, "No landing legs")
-- Touchdown: on its pad, the thrusters off, dust, the stall waiting under the pad.
advance(L.Fall / 2 + 0.05)
check(math.abs(hullHeight(ana) - REST) < 0.01, "The pod didn't land on its pad")
check(pod.Thruster.Transparency == 1, "The thrusters are still lit on the pad")
check(math.abs(local_(ana, legs[1]).Y - legs[1].Size.Y / 2) < 0.1, "The legs didn't come down onto the pad")
local stall = pads[index].Model:FindFirstChild("Display")
check(stall and stall.Counter and local_(ana, stall.Counter).Y < 0, "No stall waiting under the pad")
check(ana:GetAttribute("PodLanding") ~= nil and inside(), "Let out before it opened up")
-- Deploying: doors apart, wings out, the stair down, the stall up; then out they come.
advance(L.Deploy / 2)
check(not pod:GetAttribute("Landed"), "Open already")
advance(L.Deploy / 2 + 0.05)
check(pod:GetAttribute("Landed") == true, "It never finished opening")
check(math.abs(local_(ana, leaves[1]).X) > 1.9, "The doors didn't open")
check(math.abs(local_(ana, wings[1]).X) > Pods.Width / 2 + 0.5, "The wings didn't swing out")
check(local_(ana, ramp).Z < -Pods.Hull - 0.5, "The stair didn't fold out")
check(ramp.CanCollide and pod.PrimaryPart.CanCollide, "You can walk through the pod or fall through its stair")
check(local_(ana, stall.Counter).Y > 0, "The stall didn't rise")
check(ana:GetAttribute("PodLanding") == nil and not anaRoot.Anchored, "The rider wasn't let out")
local out = local_(ana, anaRoot)
check(out.Z < -Pods.Hull and out.Z > -(Pods.Hull + Pods.Ramp) and out.Y > Pods.Base, "Not let out at the top of the stair")
check(moved.Ana and (moved.Ana - Server.spawnFor(ana).Position).Magnitude < 0.01, "Not walked down to the foot of the stair")

-- A friend's pad is beside yours.
friendsOf[2] = { 1 }
local ben = makePlayer(2, "Ben")
local benIndex = ben:GetAttribute("PodIndex")
local gap = (pads[benIndex].CFrame.Position - pads[index].CFrame.Position).Magnitude
check(gap < 40, "A friend's pod landed far away (" .. math.floor(gap) .. " studs)")

-- The failsafe: no heartbeat at all, it's down, open and they're out all the same.
local cara, caraRoot = makePlayer(3, "Cara")
Server.land(cara)
now += L.Lead + L.Fall + L.Deploy + 2.1
for i = #delayed, 1, -1 do
	local d = delayed[i]
	if now >= d[1] then
		table.remove(delayed, i)
		d[2](table.unpack(d[3], 1, d[3].n))
	end
end
check(math.abs(hullHeight(cara) - REST) < 0.01 and podModel(cara):GetAttribute("Landed"), "The failsafe didn't land the pod")
check(cara:GetAttribute("PodLanding") == nil and not caraRoot.Anchored, "The failsafe left them inside")

-- Leaving: packed up, up and away, then the pad's free again (not before).
local anaPod = podModel(ana)
leave(ana)
check(gone(stall), "The display stall stayed behind")
check(local_({ GetAttribute = function() return index end }, ramp).Z > -Pods.Hull - 1, "It took off with the stair out")
advance(L.LiftOff / 2)
check(not gone(anaPod) and anaPod.PrimaryPart.CFrame.Position.Y - pads[index].CFrame.Position.Y > REST + 1, "The pod didn't lift off")
check(Server._taken[index] ~= nil, "The pad was freed with the pod still on it")
advance(L.LiftOff / 2 + 0.2)
check(gone(anaPod), "The pod never left")
check(Server._taken[index] == nil, "The pad was never freed")
-- Leaving mid-landing: it goes back up from where it was, and the failsafe doesn't put it back.
local dan = makePlayer(4, "Dan")
Server.land(dan)
local danPod = podModel(dan)
local danIndex = dan:GetAttribute("PodIndex")
advance(L.Lead + 1)
leave(dan)
advance(0.2)
check(danPod.PrimaryPart.CFrame.Position.Y - pads[danIndex].CFrame.Position.Y > 20, "A pod leaving mid-landing dropped onto its pad")
advance(L.Lead + L.Fall + L.Deploy + 3)
check(gone(danPod) and Server._taken[danIndex] == nil, "A pod leaving mid-landing stayed")
-- Never came into the Outpost: the pad's free as soon as they go.
local eve = makePlayer(6, "Eve")
local eveIndex = eve:GetAttribute("PodIndex")
leave(eve)
check(Server._taken[eveIndex] == nil, "A pad kept for someone gone who never landed")
-- Someone gone before their pad was picked gets none.
local ghost = { UserId = 5, DisplayName = "Ghost", Parent = nil, Attributes = {} }
function ghost:GetAttribute(k)
	return self.Attributes[k]
end
function ghost:SetAttribute(k, v)
	self.Attributes[k] = v
end
Server._reserve(ghost)
check(ghost:GetAttribute("PodIndex") == nil, "A pad for someone who'd already left")

-- The cinematic's camera (Client.PodArrival): looking up at it coming down, then round to the doors.
local Arrival = luau.load(fs.readFile(ROOT .. "/src/client/Modules/PodArrival.luau"), {
	debugName = "PodArrival",
	environment = setmetatable({
		game = { GetService = function(_, name)
			return ({ Players = { LocalPlayer = {} }, ReplicatedStorage = replicated, RunService = {}, TweenService = {} })[name]
		end },
		CFrame = FixedCFrame,
		Vector3 = R.Vector3,
		require = function(m)
			return ({ Pods = Pods })[m]
		end,
	}, { __index = _G }),
})()
local padCF = pads[1].CFrame
local function shotLook(t)
	local eye, focus = Arrival.shot(t, padCF)
	return eye, focus
end
local e0, f0 = shotLook(0)
check((f0 - padCF.Position).Y > L.Height * 0.9, "The camera isn't on the pod up in the sky")
check((e0.Position - padCF.Position).Y < 10, "The camera isn't down on the pad looking up")
local e1, f1 = shotLook(L.Fall + L.Deploy)
local doors = (padCF * R.CFrame.new(0, 4, 0)).Position
check((f1 - doors).Magnitude < 0.5, "The camera doesn't end on the doors")
check(padCF:PointToObjectSpace(e1.Position).Z < -10, "The camera doesn't end in front of the doors")
-- Handing back: never inside the pod or its stall, and the look runs past you to the field.
local hand = padCF:PointToObjectSpace(Arrival.endEye(padCF))
check(math.abs(hand.X) > Pods.Width / 2 + 2 or hand.Z < -(Pods.Hull + Pods.Ramp + 1), "The camera hands back inside the pod")
check(hand.X < 0, "The camera hands back over the display stall")
local foot = padCF:PointToObjectSpace(Pods.spawnAt(padCF).Position)
check(foot.Z < hand.Z, "The camera hands back looking at the pod, not past you to the field")
-- (and the line from you to it clears the pod's front)
local t = (-(Pods.Width / 2) - foot.X) / (hand.X - foot.X)
check(foot.Z + (hand.Z - foot.Z) * t < -Pods.Hull - 0.6, "The pod's corner is between you and the camera")

print("PASS: " .. checks .. " pod checks (pads kept on joining, landing with you inside, touchdown, deploying, out down the stair, the cinematic's shots, failsafe, lift-off)")
