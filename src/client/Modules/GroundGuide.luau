--[[
	Yellow arrows on the ground, leading you where to go: a short trail of
	chevrons from your feet toward a spot, laid on the floor, drifting the
	way to go and fading at both ends, quiet enough to ignore. They take
	the way round walls (PathfindingService; straight at it if there's no
	path) and go as you get there.

	Where they lead (the first that wants you somewhere):
	  - Downstairs, in the Kaiju Arena: to the free pad across from someone
	    waiting for a challenger, or, just arrived, to the nearest open
	    court's pad. Not once you're on a pad or in a battle.
	  - In the Shelter: to the stairs down, for a while after someone starts
	    waiting for a challenger down there.
	  - In the Rift: through a wall of fire that's just gone out, into the
	    next cave (its "Into", Server.RiftWorld), and no more once you're
	    through it: never back the way you came. To the way home once the
	    boss is down.

	  GroundGuide.start()                 once (Lobby.client)
	  GroundGuide.set(key, where, rank?)  `where() -> Vector3?` (nil: not
	                                      now); the lowest rank wins
	  GroundGuide.clear(key)
	  GroundGuide.trail(from, to, count, spacing) -> { CFrame }   where the
	                                      chevrons go along a straight run (pure)
	  GroundGuide.arms(at) -> { CFrame }  a chevron's two arms at `at` (pure)
	  GroundGuide.through(gate, into, at) -> Vector3?   where to lead `at`
	                                      through a gate at `gate` to `into`:
	                                      nil once it's through (pure)
]]
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GroundGuide = {}

local YELLOW = Color3.fromRGB(255, 212, 58)
GroundGuide.Count = 7 -- chevrons at once
GroundGuide.Spacing = 3.4 -- studs between them
GroundGuide.Ahead = 3.5 -- the first, this far in front of you
GroundGuide.Arrive = 7 -- this near and they're gone
GroundGuide.Transparency = 0.42 -- at their brightest (subtle)
GroundGuide.Speed = 2.2 -- studs a second they drift

type Want = { Where: () -> Vector3?, Rank: number }
local wants: { [string]: Want } = {}

function GroundGuide.set(key: string, where: () -> Vector3?, rank: number?)
	wants[key] = { Where = where, Rank = rank or 10 }
end

function GroundGuide.clear(key: string)
	wants[key] = nil
end

-- Where `count` chevrons go along the polyline `points` (from its start),
-- `spacing` apart, starting `offset` along it: each a CFrame on the line,
-- facing along it, and how far along the whole line it is (0 to 1).
function GroundGuide.along(
	points: { Vector3 },
	count: number,
	spacing: number,
	offset: number
): { { CFrame: CFrame, Share: number } }
	local out = {}
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	if total <= 0.01 then
		return out
	end
	for k = 0, count - 1 do
		local distance = offset + k * spacing
		if distance > total then
			break
		end
		local walked = 0
		for i = 2, #points do
			local a, b = points[i - 1], points[i]
			local leg = (b - a).Magnitude
			if leg > 0 and walked + leg >= distance then
				local at = a + (b - a) * ((distance - walked) / leg)
				local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
				local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
				table.insert(out, { CFrame = CFrame.lookAt(at, at + facing), Share = distance / total })
				break
			end
			walked += leg
		end
	end
	return out
end

-- The same along a straight run from `from` to `to` (tests use it).
function GroundGuide.trail(from: Vector3, to: Vector3, count: number, spacing: number): { CFrame }
	local out = {}
	for _, entry in GroundGuide.along({ from, to }, count, spacing, 0) do
		table.insert(out, entry.CFrame)
	end
	return out
end

-- A chevron's two arms on the floor at `base` (facing the way to go): they
-- meet in front, so it points along the way.
function GroundGuide.arms(base: CFrame): { CFrame }
	local out = {}
	for _, s in { -1, 1 } do
		table.insert(out, base * CFrame.new(s * 0.48, 0, 0) * CFrame.Angles(0, s * math.rad(40), 0))
	end
	return out
end

-- Through a gate at `gate` to `into` beyond it: there, from `at` on the
-- near side; nil once `at` is through (a stride past the gate's line), so
-- the way never turns back behind you.
GroundGuide.Past = 2
function GroundGuide.through(gate: Vector3, into: Vector3, at: Vector3): Vector3?
	local on = Vector3.new(into.X - gate.X, 0, into.Z - gate.Z)
	if on.Magnitude < 0.01 then
		return nil
	end
	local past = Vector3.new(at.X - gate.X, 0, at.Z - gate.Z):Dot(on.Unit)
	return if past < GroundGuide.Past then into else nil
end

-- The chevrons --------------------------------------------------------------------------------------------

local folder: Folder? = nil
local chevrons: { { Model: Model, Parts: { BasePart } } } = {}

local function chevron(): { Model: Model, Parts: { BasePart } }
	local model = Instance.new("Model")
	model.Name = "Chevron"
	local parts = {}
	for _ = 1, 2 do
		local arm = Instance.new("Part")
		arm.Anchored, arm.CanCollide, arm.CanQuery, arm.CanTouch = true, false, false, false
		arm.CastShadow = false
		arm.Material = Enum.Material.Neon
		arm.Color = YELLOW
		arm.Size = Vector3.new(0.32, 0.05, 1.5)
		arm.Transparency = 1
		arm.Parent = model
		table.insert(parts, arm)
	end
	return { Model = model, Parts = parts }
end

local function ensure()
	if folder and folder.Parent then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "GroundGuide"
	f.Parent = workspace
	folder = f
	table.clear(chevrons)
	for i = 1, GroundGuide.Count do
		local c = chevron()
		c.Model.Parent = f
		chevrons[i] = c
	end
end

local function hide()
	for _, c in chevrons do
		for _, arm in c.Parts do
			arm.Transparency = 1
		end
	end
end

-- The ground under a point (what you'd stand on), or the point.
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local function ground(at: Vector3): Vector3
	local skip: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(skip, other.Character)
		end
	end
	for _, name in { "Kaiju", "Enemies", "GroundGuide", "KaijuBattleField" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(skip, f)
		end
	end
	params.FilterDescendantsInstances = skip
	local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 2.9, 0)
end

-- The way: a path round the walls, kept a while; straight there without one.
local route = { Points = nil :: { Vector3 }?, For = nil :: Vector3?, From = nil :: Vector3?, At = 0 }
local computing = false
local function plan(from: Vector3, to: Vector3)
	local now = os.clock()
	local stale = not route.For
		or (route.For - to).Magnitude > 2
		or not route.From
		or (route.From - from).Magnitude > 6
		or now - route.At > 3
	if not stale or computing then
		return
	end
	computing = true
	route.At = now
	task.spawn(function()
		local points = { from, to }
		local ok = pcall(function()
			local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
			path:ComputeAsync(from, to)
			if path.Status == Enum.PathStatus.Success then
				local waypoints = path:GetWaypoints()
				if #waypoints >= 2 then
					points = {}
					for _, w in waypoints do
						table.insert(points, w.Position)
					end
				end
			end
		end)
		if not ok then
			points = { from, to }
		end
		route.Points, route.For, route.From = points, to, from
		computing = false
	end)
end

-- Where you're wanted now (the lowest rank that has somewhere).
local function target(): Vector3?
	local best, rank = nil, math.huge
	for _, want in wants do
		if want.Rank < rank then
			local ok, at = pcall(want.Where)
			if ok and typeof(at) == "Vector3" then
				best, rank = at, want.Rank
			end
		end
	end
	return best
end

local phase = 0
local function draw(dt: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local to = root and target()
	if not root or not to then
		hide()
		return
	end
	local from = root.Position
	if (Vector3.new(to.X - from.X, 0, to.Z - from.Z)).Magnitude < GroundGuide.Arrive then
		hide()
		return
	end
	ensure()
	plan(from, to)
	local points = route.Points
	if not points or not route.For or (route.For - to).Magnitude > 2 then
		points = { from, to }
	else
		-- (From where you are now to the path's next point ahead of you.)
		local trimmed = { from }
		local best, bestIndex = math.huge, 2
		for i = 2, #points do
			local d = (points[i] - from).Magnitude
			if d < best then
				best, bestIndex = d, i
			end
		end
		for i = bestIndex, #points do
			table.insert(trimmed, points[i])
		end
		points = trimmed
	end
	phase = (phase + dt * GroundGuide.Speed) % GroundGuide.Spacing
	local spots = GroundGuide.along(points, GroundGuide.Count, GroundGuide.Spacing, GroundGuide.Ahead + phase)
	for i, c in chevrons do
		local spot = spots[i]
		if not spot then
			for _, arm in c.Parts do
				arm.Transparency = 1
			end
		else
			local floor = ground(spot.CFrame.Position)
			local base = CFrame.new(floor + Vector3.new(0, 0.08, 0)) * (spot.CFrame - spot.CFrame.Position)
			-- (Faint as they appear and as they near the end of the trail.)
			local k = (i - 1 + phase / GroundGuide.Spacing) / GroundGuide.Count
			local fade = math.clamp(math.min(k * 3, (1 - k) * 2.2), 0, 1)
			local alpha = 1 - (1 - GroundGuide.Transparency) * fade
			local arms = GroundGuide.arms(base)
			for j, arm in c.Parts do
				arm.CFrame = arms[j]
				arm.Transparency = alpha
			end
		end
	end
end

-- Where to go ----------------------------------------------------------------------------------------------

local function pitCourts(): { Model }
	local hall = workspace:FindFirstChild("KaijuPit")
	local courts = hall and hall:FindFirstChild("Courts")
	return if courts then courts:GetChildren() :: { any } else {}
end

local function padOf(court: Model, side: string): Vector3?
	local ring = court:FindFirstChild("Pad" .. side) :: BasePart?
	return ring and ring.Position
end

local arrivedAt = -math.huge
local waitingSeen: { [Model]: number } = {}

-- Downstairs: across from someone waiting, or (just arrived) the nearest open court.
local function arenaWant(): Vector3?
	local me = Players.LocalPlayer
	if me:GetAttribute("KaijuPit") ~= true or me:GetAttribute("KaijuBattle") then
		return nil
	end
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	-- (On a pad already: nowhere.)
	for _, court in pitCourts() do
		for _, side in { "A", "B" } do
			local pad = padOf(court, side)
			if pad and Vector3.new(pad.X - root.Position.X, 0, pad.Z - root.Position.Z).Magnitude < 3.6 then
				return nil
			end
		end
	end
	local best, bestDistance = nil, math.huge
	local function consider(at: Vector3?)
		if at then
			local d = (at - root.Position).Magnitude
			if d < bestDistance then
				best, bestDistance = at, d
			end
		end
	end
	for _, court in pitCourts() do
		if court:GetAttribute("State") == "Waiting" then
			local aId, bId = court:GetAttribute("AId"), court:GetAttribute("BId")
			if aId ~= me.UserId and bId ~= me.UserId then
				consider(padOf(court, if aId then "B" else "A"))
			end
		end
	end
	if best then
		return best
	end
	if os.clock() - arrivedAt < 18 then
		for _, court in pitCourts() do
			if (court:GetAttribute("State") or "Open") == "Open" then
				consider(padOf(court, "A"))
			end
		end
	end
	return best
end

-- Upstairs: the stairs down, a while after someone starts waiting below.
local stairs: BasePart? = nil
local function stairsWant(): Vector3?
	local me = Players.LocalPlayer
	if me:GetAttribute("KaijuPit") or me:GetAttribute("RiftRun") or me:GetAttribute("Outpost") ~= true then
		return nil
	end
	local now = os.clock()
	local fresh = false
	for court, at in waitingSeen do
		if now - at < 25 and court:GetAttribute("State") == "Waiting" then
			fresh = true
		end
	end
	if not fresh then
		return nil
	end
	if not stairs or not stairs.Parent then
		stairs = workspace:FindFirstChild("ArenaDoor", true) :: BasePart?
	end
	return stairs and stairs.Position
end

-- The Rift: through a wall of fire that's just gone out; to the way home.
local gateOpenedAt: { [Instance]: number } = setmetatable({}, { __mode = "k" }) -- (a run's gates go with it)
local function riftWant(): Vector3?
	local me = Players.LocalPlayer
	local run = me:GetAttribute("RiftRun")
	if not run then
		return nil
	end
	local world = workspace:FindFirstChild("Rift_" .. tostring(run))
	if not world then
		return nil
	end
	if me:GetAttribute("RiftWon") then
		local home = world:FindFirstChild("WayHome", true)
		local opening = home and home:FindFirstChild("Opening") :: BasePart?
		return opening and opening.Position
	end
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local now, best, bestAt = os.clock(), nil, -math.huge
	for _, gate in world:GetDescendants() do
		if gate.Name == "FireGate" and gate:GetAttribute("Open") then
			local at = gateOpenedAt[gate]
			if not at then
				at = now
				gateOpenedAt[gate] = now
			end
			if now - at < 15 and at > bestAt then
				-- (Into the next cave, and no more once you're through.)
				local wall = gate:FindFirstChild("Wall") :: BasePart?
				local into = gate:GetAttribute("Into")
				local lead = if wall and typeof(into) == "Vector3"
					then GroundGuide.through(wall.Position, into, root.Position)
					else nil
				if lead then
					best, bestAt = lead, at
				end
			end
		end
	end
	return best
end

local started = false
function GroundGuide.start()
	if started then
		return
	end
	started = true
	GroundGuide.set("Arena", arenaWant, 1)
	GroundGuide.set("Rift", riftWant, 2)
	GroundGuide.set("Stairs", stairsWant, 5)
	local me = Players.LocalPlayer
	me:GetAttributeChangedSignal("KaijuPit"):Connect(function()
		if me:GetAttribute("KaijuPit") then
			arrivedAt = os.clock()
		end
	end)
	-- (A court where someone's just started waiting: the stairs, a while.)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, court in pitCourts() do
				local waiting = court:GetAttribute("State") == "Waiting"
				if waiting and not waitingSeen[court] then
					waitingSeen[court] = os.clock()
				elseif not waiting then
					waitingSeen[court] = nil
				end
			end
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local ok = pcall(draw, dt)
		if not ok then
			hide()
		end
	end)
end

return GroundGuide
