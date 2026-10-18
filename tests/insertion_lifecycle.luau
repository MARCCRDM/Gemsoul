-- Service doubles exercise scheduling/cancellation, not visual fidelity.
local now, pending = 100, {}
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			local entry = { fn, true }
			table.insert(callbacks, entry)
			return {
				Disconnect = function()
					entry[2] = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in callbacks do
				if entry[2] then
					entry[1](...)
				end
			end
		end,
	}
end
local vmt = {}
local function vec(x, y, z)
	return setmetatable({ X = x, Y = y, Z = z }, vmt)
end
vmt.__add = function(a, b)
	return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vmt.__div = function(a, b)
	return vec(a.X / b, a.Y / b, a.Z / b)
end
vmt.__sub = function(a, b)
	return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vmt.__index = function(a, key)
	if key == "Magnitude" then
		return math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
	end
end
local Vector3 = { zero = vec(0, 0, 0), new = vec }
local Vector2 = { zero = {} }
local cmt = {}
local CFrame = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, cmt)
	end,
}
cmt.__mul = function(a, b)
	local cf = CFrame.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	cf.Facing = a.Facing
	return cf
end
CFrame.lookAt = function(position, target)
	local cf = CFrame.new(position.X, position.Y, position.Z)
	cf.Facing = target
	return cf
end
local Color3 = {
	fromRGB = function(...)
		return { ... }
	end,
}
local Enum = { Material = { Neon = "Neon" }, HighlightDepthMode = { Occluded = "Occluded" } }
local workspace = {
	GetServerTimeNow = function()
		return now
	end,
}
local created = {}
local function object(class)
	local attrs, signals = {}, {}
	local o = { ClassName = class, Parent = workspace, AncestryChanged = signal(), DescendantAdded = signal() }
	table.insert(created, o)
	function o:SetAttribute(k, v)
		attrs[k] = v
		if signals[k] then
			signals[k]:Fire()
		end
	end
	function o:GetAttribute(k)
		return attrs[k]
	end
	function o:GetAttributeChangedSignal(k)
		signals[k] = signals[k] or signal()
		return signals[k]
	end
	function o:IsA(k)
		return k == class or k == "BasePart" and class == "Part"
	end
	function o:Destroy()
		self.Parent = nil
		self.AncestryChanged:Fire(self, nil)
	end
	return o
end
local Instance = { new = object }
local owners = {}
local heartbeat = signal()
local Players = {
	GetPlayerFromCharacter = function(_, model)
		return owners[model]
	end,
}
local game = {
	GetService = function(_, name)
		return if name == "Players" then Players else { Heartbeat = heartbeat }
	end,
}
local task = {
	delay = function(delay, fn)
		table.insert(pending, { now + delay, fn })
	end,
}
local function advance(dt)
	now += dt
	heartbeat:Fire()
	for i = #pending, 1, -1 do
		if pending[i][1] <= now then
			local fn = pending[i][2]
			table.remove(pending, i)
			fn()
		end
	end
end
local function actor(anchored)
	local m = object("Model")
	local root = object("Part")
	root.CFrame = CFrame.new()
	root.Position = Vector3.zero
	root.Anchored = anchored or false
	root.Transparency = 0.1
	local armor = object("Part")
	armor.Transparency = 0.35
	local particles = object("ParticleEmitter")
	particles.Enabled = true
	local board = object("BillboardGui")
	board.Enabled = true
	local hum = object("Humanoid")
	hum.Health = 100
	hum.NameDisplayDistance, hum.HealthDisplayDistance = 100, 100
	hum.Died = signal()
	function m:FindFirstChild(name)
		return if name == "HumanoidRootPart" then root else nil
	end
	function m:FindFirstChildOfClass(name)
		return if name == "Humanoid" then hum else nil
	end
	function m:GetDescendants()
		return { root, armor, particles, board }
	end
	function m:GetScale()
		return self.Scale or 1
	end
	return m, root, armor, particles, hum, board
end
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
-- MODULES HERE
do
	-- Entering a match while seated must sever physics before the root anchors.
	local model, root, _, _, hum = actor()
	local rider = object("Player")
	rider.Character = model
	owners[model] = rider
	local seat, chassis, weld, unrelated = object("VehicleSeat"), object("Part"), object("Weld"), object("Weld")
	local characterOwnershipReturned = false
	function root:SetNetworkOwnershipAuto()
		check(weld.Parent == nil, "Character ownership restored before breaking the seat weld")
		characterOwnershipReturned = true
	end
	seat.Parent = { PrimaryPart = chassis }
	weld.Name, weld.Part0, weld.Part1 = "SeatWeld", seat, root
	unrelated.Name, unrelated.Part0, unrelated.Part1 = "SeatWeld", seat, chassis
	function root:IsDescendantOf(other) return other == model end
	function seat:IsDescendantOf() return false end
	function chassis:IsDescendantOf() return false end
	function seat:GetChildren() return { weld, unrelated } end
	function weld:Destroy()
		check(not root.Anchored, "Seated assembly anchored before unseating")
		check(rider:GetAttribute("ArenaDropPreparing") ~= nil, "Reseat guard not active before detach")
		self.Parent = nil
	end
	hum.SeatPart, hum.Sit = seat, true
	Enum.HumanoidStateType = { GettingUp = "GettingUp" }
	function hum:ChangeState(state) self.State = state end
	Drop.prepare(rider)
	check(weld.Parent == nil and unrelated.Parent ~= nil, "Wrong seat weld removed")
	check(not hum.Sit and hum.State == "GettingUp", "Humanoid left seated")
	check(root.Anchored and root.AssemblyLinearVelocity == Vector3.zero, "Character not ready for insertion")
	check(characterOwnershipReturned, "The rider kept someone else's ownership after leaving the seat")
	Drop.cancel(model)
	check(not root.Anchored and rider:GetAttribute("ArenaDropPreparing") == nil, "Cancelled seated entry stayed locked")
end
do
	-- Entering a match while piloting a mech (no seat: a weld holds the pilot
	-- in its cockpit, Server OutpostVehicles) lets go of them first.
	local model, root, _, _, hum = actor()
	local rider = object("Player")
	rider.Character = model
	owners[model] = rider
	rider:SetAttribute("MechPilot", "Mole3")
	local cockpit, weld, unrelated = object("Part"), object("Weld"), object("Weld")
	weld.Name, weld.Part0, weld.Part1, weld.Parent = "PilotWeld", cockpit, root, cockpit
	unrelated.Name, unrelated.Part0, unrelated.Part1, unrelated.Parent = "RootJoint", root, cockpit, model
	function root:GetJoints()
		return { weld, unrelated }
	end
	function weld:Destroy()
		check(not root.Anchored, "The pilot was anchored before the cockpit let go")
		check(rider:GetAttribute("ArenaDropPreparing") ~= nil, "Reseat guard not active before letting go of the pilot")
		self.Parent = nil
	end
	local returned = false
	function root:SetNetworkOwnershipAuto()
		check(weld.Parent == nil, "Ownership restored before the cockpit let go")
		returned = true
	end
	hum.Sit = true
	Enum.HumanoidStateType = { GettingUp = "GettingUp" }
	function hum:ChangeState(state)
		self.State = state
	end
	Drop.prepare(rider)
	check(weld.Parent == nil and unrelated.Parent ~= nil, "The wrong weld was let go")
	check(rider:GetAttribute("MechPilot") == nil, "Still a mech's pilot on the way into a match")
	check(not hum.Sit and hum.State == "GettingUp", "The pilot was left sat down")
	check(root.Anchored and returned, "The pilot wasn't ready for insertion")
	Drop.cancel(model)
end
local a, ar, armor, particles, ah, ab = actor()
local b, br = actor()
local player = object("Player")
owners[a] = player
player:SetAttribute("CombatSession", "Training")
local duration = Drop.begin({ a, b }, { player })
check(ar.Anchored and br.Anchored, "actors not staged")
check(
	not ab.Enabled and ah.NameDisplayDistance == 0 and ah.HealthDisplayDistance == 0,
	"Name/health visible before landing"
)
local streamedBoard = object("BillboardGui")
streamedBoard.Enabled = true
a.DescendantAdded:Fire(streamedBoard)
check(not streamedBoard.Enabled, "Late streamed nameplate visible during insertion")
check(armor.Transparency == 1 and not particles.Enabled, "actor visible before hatch release")
check(player:GetAttribute("ArenaDropUntil") == now + duration, "viewer protection mismatch")
check(
	math.abs(math.abs(a:GetAttribute("ArenaDropStart") - b:GetAttribute("ArenaDropStart")) - Motion.Spacing) < 0.00001,
	"entries not staggered"
)
advance(duration - 0.1)
check(armor.Transparency == 0.35 and particles.Enabled, "actor not restored after exit")
check(ar.CFrame.Z == 0 and br.CFrame.Z == 0, "exit moved fighter away from default spawn")
advance(0.2)
check(not ar.Anchored and not br.Anchored, "normal finish left actors frozen")
check(
	ab.Enabled and streamedBoard.Enabled and ah.NameDisplayDistance == 100 and ah.HealthDisplayDistance == 100,
	"Names/health not restored at combat start"
)
check(player:GetAttribute("ArenaDropUntil") == nil, "normal finish retained input lock")
check(a:GetAttribute("ArenaDropOrigin") == nil, "normal finish retained camera origin")
local lingering = {}
for _, item in created do
	if item:GetAttribute("InsertionResidual") and item.Parent then
		table.insert(lingering, item)
	end
end
check(#lingering == 4, "Smoke markers and silhouettes did not survive combat unlock")
advance(Motion.SmokeAfter + 0.1)
for _, item in lingering do
	check(item.Parent == nil, "Residual effect did not expire")
end

-- Session exit before landing restores properties and disconnects future movement.
Drop.begin({ a, b }, { player })
player:SetAttribute("CombatSession", nil)
local cancelledZ = ar.CFrame.Z
check(not ar.Anchored and armor.Transparency == 0.35 and particles.Enabled, "cancel did not restore actor")
advance(20)
check(ar.CFrame.Z == cancelledZ, "cancelled staging still moved actor")
-- Replacing an active insertion must not let its old timeout clear the new one.
player:SetAttribute("CombatSession", "PvP")
Drop.begin({ a, b }, { player })
advance(0.2)
local second = Drop.begin({ a, b }, { player })
local newEnds = player:GetAttribute("ArenaDropUntil")
advance(second - 0.1)
check(player:GetAttribute("ArenaDropUntil") == newEnds and ar.Anchored, "old cleanup cancelled replacement")
advance(0.2)
check(not ar.Anchored, "replacement cleanup failed")
-- The survivor does not descend again when only a replacement rival arrives.
local survivorFacing = CFrame.new(4, 3, 2)
ar.CFrame = survivorFacing
Drop.begin({ a, b }, { player }, { b })
check(ar.CFrame == survivorFacing, "Replacement forcibly turned grounded survivor")
check(a:GetAttribute("ArenaDropStart") == nil and armor.Transparency == 0.35, "survivor was hidden or dropped again")
check(b:GetAttribute("ArenaDropStart") ~= nil, "replacement did not receive insertion")
local turnedWhileWaiting = CFrame.new(4, 3, 3)
ar.CFrame = turnedWhileWaiting
Drop.cancel(a)
check(ar.CFrame == turnedWhileWaiting, "Rival cleanup snapped survivor back to old POV")
Drop.cancel(b)
local fixed, fr, _, _, fh = actor(true)
Drop.begin({ fixed }, {})
fh.Died:Fire()
check(fr.Anchored, "cleanup lost preexisting anchored state")
check(fixed:GetAttribute("ArenaDropUntil") == nil, "death retained protection")
local left, lr = actor()
local right, rr = actor()
lr.Position, rr.Position = vec(-20, 3, 7), vec(20, 6, -8)
Drop.begin({ left, right }, {})
local lf, rf = left:GetAttribute("ArenaDropOrigin").Facing, right:GetAttribute("ArenaDropOrigin").Facing
check(lf.X == 20 and lf.Z == -8 and lf.Y == 3, "First fighter not facing opponent horizontally")
check(rf.X == -20 and rf.Z == 7 and rf.Y == 6, "Second fighter not facing opponent horizontally")
Drop.cancel(left)
Drop.cancel(right)
local staged, sr, sa, se = actor()
local entrant = object("Player")
entrant.Character = staged
owners[staged] = entrant
Drop.prepare(entrant)
check(sr.Anchored and sa.Transparency == 1 and not se.Enabled, "Preparation exposed character before teleport")
check(entrant:GetAttribute("ArenaDropPreparing") > now, "Preparation did not cover loading")
local duration2 = Drop.begin({ staged }, { entrant })
check(sa:GetAttribute("InsertionTransparency") == 0.35, "Preparation-to-drop lost original armor visibility")
check(entrant:GetAttribute("ArenaDropPreparing") == nil, "Preparation cover did not release to pod")
advance(duration2 + 0.1)
check(not sr.Anchored and sa.Transparency == 0.35 and se.Enabled, "Prepared fighter failed to restore after insertion")
Drop.prepare(entrant)
Drop.cancel(staged)
check(not sr.Anchored and entrant:GetAttribute("ArenaDropPreparing") == nil, "Failed entry left preparation frozen")
Drop.prepare(entrant)
advance(15.1)
check(not sr.Anchored and entrant:GetAttribute("ArenaDropUntil") == nil, "Preparation timeout retained protection")
-- Gear shown or hidden while staged (the Outpost brings a duellist's weapon
-- back out for the fight a moment after the pod has saved it hidden) changes
-- the staged record, and the reveal restores that, not the stale value.
local outpost, _, oa = actor()
local duellist = object("Player")
duellist.Character = outpost
owners[outpost] = duellist
oa.Transparency = 1 -- put away while mining
Drop.prepare(duellist)
local duration3 = Drop.begin({ outpost }, { duellist })
check(oa.Transparency == 1 and oa:GetAttribute("InsertionTransparency") == 1, "Pod did not stage the put-away weapon")
oa:SetAttribute("InsertionTransparency", 0) -- as OutpostServer does while staged
check(oa.Transparency == 1, "Weapon showed mid-drop")
advance(duration3 + 0.1)
check(
	oa.Transparency == 0 and oa:GetAttribute("InsertionTransparency") == nil,
	"Reveal restored a stale value: weapon left invisible"
)
-- Cooperative formations face the enemy, never the average of their own squad.
local ally, allyRoot = actor()
local mate = object("Player")
mate.Character = ally
owners[ally] = mate
sr.Position, allyRoot.Position = vec(-10, 4, -22), vec(10, 4, -22)
local boss, bossRoot = actor()
bossRoot.Position = vec(14, 7, 0)
boss.Scale = 1.8
local squadTime = Drop.encounter({ entrant, mate }, { boss }, true)
check(
	staged:GetAttribute("ArenaDropStart") ~= nil and ally:GetAttribute("ArenaDropStart") ~= nil,
	"Squad missed first insertion"
)
check(boss:GetAttribute("ArenaDropStart") ~= nil, "Boss did not drop with squad")
check(
	staged:GetAttribute("ArenaDropOrigin").Facing.X == 14 and ally:GetAttribute("ArenaDropOrigin").Facing.X == 14,
	"Squad aimed at teammates"
)
check(
	boss:GetAttribute("ArenaDropOrigin").Facing.X == 0 and boss:GetAttribute("ArenaDropOrigin").Facing.Z == -22,
	"Boss did not face squad"
)
local scaled = false
for _, item in created do
	if item.ClassName == "Folder" and item:GetAttribute("Scale") == 1.8 then
		scaled = true
	end
end
check(scaled, "Boss pod did not inherit model scale")
advance(squadTime + 0.1)
check(not sr.Anchored and not allyRoot.Anchored and not bossRoot.Anchored, "Squad insertion failed to unlock")
Drop.encounter({ entrant, mate }, { boss }, false)
check(
	staged:GetAttribute("ArenaDropStart") == nil
		and ally:GetAttribute("ArenaDropStart") == nil
		and sa.Transparency == 0.35,
	"Next wave redropped/hid survivors"
)
check(boss:GetAttribute("ArenaDropStart") ~= nil, "Next wave lacked boss pod")
Drop.cancel(staged)
Drop.cancel(ally)
Drop.cancel(boss)
-- Dungeon defenders remain visible on the ground while players deploy.
local createdBefore = #created
local groundDuration = Drop.encounter({ entrant, mate }, { boss }, true, false, true)
check(
	boss:GetAttribute("ArenaDropStart") == nil and bossRoot.Transparency == 0.1,
	"Dungeon enemy hidden or given a pod"
)
check(
	bossRoot.Anchored and boss:GetAttribute("ArenaDropUntil") > now,
	"Dungeon enemy could attack before squad deployment"
)
check(
	staged:GetAttribute("ArenaDropStart") ~= nil and ally:GetAttribute("ArenaDropStart") ~= nil,
	"Dungeon squad lost its pods"
)
local newMarkers = 0
for i = createdBefore + 1, #created do
	if created[i].ClassName == "Folder" and created[i].Name == "OrbitalInsertion" then
		newMarkers += 1
	end
end
check(newMarkers == 2, "Dungeon spawned more pods than players")
advance(groundDuration + 0.1)
check(
	not bossRoot.Anchored and boss:GetAttribute("ArenaDropUntil") == nil,
	"Grounded enemy did not activate after deployment"
)
local ambientTime = Drop.encounter({ entrant, mate }, { boss }, false, true)
check(
	not sr.Anchored and not allyRoot.Anchored and entrant:GetAttribute("ArenaDropUntil") == nil,
	"Ambient pod stole player controls"
)
check(bossRoot.Anchored and boss:GetAttribute("ArenaDropStart") ~= nil, "Ambient actor failed to stage")
boss:Destroy()
check(boss:GetAttribute("ArenaDropUntil") == nil and not bossRoot.Anchored, "Destroyed encounter kept staging active")
advance(ambientTime + 0.1)
check(Drop.encounter({ entrant }, {}, false) == 0 and not sr.Anchored, "Empty wave locked party")
print("PASS: " .. checks .. " real insertion lifecycle checks")
