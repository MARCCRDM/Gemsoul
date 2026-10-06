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
local cmt = {}
local CFrame = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, cmt)
	end,
}
cmt.__mul = function(a, b)
	return CFrame.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
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
	local o = { ClassName = class, Parent = workspace, AncestryChanged = signal() }
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
	local hum = object("Humanoid")
	hum.Died = signal()
	function m:FindFirstChild(name)
		return if name == "HumanoidRootPart" then root else nil
	end
	function m:FindFirstChildOfClass(name)
		return if name == "Humanoid" then hum else nil
	end
	function m:GetDescendants()
		return { root, armor, particles }
	end
	return m, root, armor, particles, hum
end
local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
-- MODULES HERE
local a, ar, armor, particles = actor()
local b, br = actor()
local player = object("Player")
owners[a] = player
player:SetAttribute("CombatSession", "Training")
local duration = Drop.begin({ a, b }, { player })
check(ar.Anchored and br.Anchored, "actors not staged")
check(armor.Transparency == 1 and not particles.Enabled, "actor visible before hatch release")
check(player:GetAttribute("ArenaDropUntil") == now + duration, "viewer protection mismatch")
check(
	math.abs(math.abs(a:GetAttribute("ArenaDropStart") - b:GetAttribute("ArenaDropStart")) - Motion.Spacing) < 0.00001,
	"entries not staggered"
)
advance(duration - 0.1)
check(armor.Transparency == 0.35 and particles.Enabled, "actor not restored after exit")
check(ar.CFrame.Z == -3 and br.CFrame.Z == -3, "exit did not reach authoritative endpoint")
advance(0.2)
check(not ar.Anchored and not br.Anchored, "normal finish left actors frozen")
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
Drop.begin({ a, b }, { player }, { b })
check(a:GetAttribute("ArenaDropStart") == nil and armor.Transparency == 0.35, "survivor was hidden or dropped again")
check(b:GetAttribute("ArenaDropStart") ~= nil, "replacement did not receive insertion")
Drop.cancel(a)
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
print("PASS: " .. checks .. " real insertion lifecycle checks")
