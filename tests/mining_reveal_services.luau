-- Service doubles with a resumable clock; no Roblox rendering is claimed.
local now, pending, objects, sounds = 0, {}, {}, {}
local viewport = { X = 1000, Y = 700 }
local os = { clock = function() return now end }
local function resume(thread)
	local ok, delay = coroutine.resume(thread)
	assert(ok, delay)
	if coroutine.status(thread) ~= "dead" then table.insert(pending, { thread, now + (delay or 1 / 60) }) end
end
local task = {
	spawn = function(fn) resume(coroutine.create(fn)) end,
	wait = function(seconds) return coroutine.yield(seconds or 1 / 60) end,
}
local function step(seconds)
	for _ = 1, math.ceil(seconds * 60) do
		now += 1 / 60
		local ready = pending
		pending = {}
		for _, entry in ready do
			if entry[2] <= now then resume(entry[1]) else table.insert(pending, entry) end
		end
	end
end
local function signal()
	local listeners = {}
	local event = {}
	function event:Connect(fn)
		local c = { Connected = true }
		function c:Disconnect() self.Connected = false end
		table.insert(listeners, { fn, c })
		return c
	end
	function event:Once(fn)
		local c
		c = self:Connect(function(...) c:Disconnect(); fn(...) end)
		return c
	end
	function event:Fire(...) for _, l in listeners do if l[2].Connected then l[1](...) end end end
	function event:Wait() return coroutine.yield(1 / 60) end
	return event
end
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim2 = { new = function(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end }
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
local ColorSequence = { new = function(...) return { ... } end }
local NumberSequence = { new = function(...) return { ... } end }
local NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
local TweenInfo = { new = function() return {} end }
local Random = { new = function() return { NextNumber = function() return 0.01 end } end }
local methods = {}
local function new(class, props, parent)
	local values = { ClassName = class, Children = {}, Signals = {}, AbsoluteSize = table.clone(viewport),
		Activated = signal(), Destroying = signal(), Visible = true }
	local object
	object = setmetatable({}, {
		__index = function(_, key) return methods[key] or values[key] end,
		__newindex = function(_, key, value)
			assert(not values.Destroyed or key == "Parent", "Wrote to destroyed " .. class .. ": " .. key)
			if key == "Parent" and value then table.insert(value.Children, object) end
			values[key] = value
		end,
	})
	for key, value in props or {} do object[key] = value end
	object.Parent = parent
	table.insert(objects, object)
	return object
end
function methods:GetChildren()
	local result = {}
	for _, child in self.Children do if child.Parent == self and not child.Destroyed then table.insert(result, child) end end
	return result
end
function methods:FindFirstChildOfClass(class)
	for _, child in self:GetChildren() do if child.ClassName == class then return child end end
end
function methods:GetPropertyChangedSignal(key)
	self.Signals[key] = self.Signals[key] or signal()
	return self.Signals[key]
end
function methods:Destroy()
	if self.Destroyed then return end
	self.Destroying:Fire()
	self:ClearAllChildren()
	self.Parent = nil
	self.Destroyed = true
end
function methods:ClearAllChildren() for _, child in self:GetChildren() do child:Destroy() end end
function methods:Clone()
	local copy = new(self.ClassName, { Gem = self.Gem, Name = self.Name })
	for _, child in self:GetChildren() do child:Clone().Parent = copy end
	return copy
end
local root = new("PlayerGui")
local Instance = { new = new }
local services = {
	ReplicatedStorage = {}, RunService = { RenderStepped = signal() },
	TweenService = { Create = function(_, object, _, goal)
		return { Play = function() for k, v in goal do object[k] = v end end }
	end },
}
local game = { GetService = function(_, id) return services[id] end }
local IronUi = { new = new, Bold = "GothamBold" }
local UiKit = { gui = function(name) return new("ScreenGui", { Name = name }, root) end, round = function() end }
local GemArt = { viewport = function(parent, gem)
	local view = new("ViewportFrame", { Gem = gem }, parent)
	new("Camera", {}, view)
	return view
end }
local LotterySound = { tick = function() end, reveal = function(rank) table.insert(sounds, rank) end }
local function find(name, class)
	for _, o in objects do if not o.Destroyed and o.Name == name and (not class or o.ClassName == class) then return o end end
end
local function labelWith(value)
	for _, o in objects do if not o.Destroyed and o.ClassName == "TextLabel" and o.Text == value then return o end end
end
local function liveCount(class)
	local n = 0
	for _, o in objects do if not o.Destroyed and o.ClassName == class then n += 1 end end
	return n
end
