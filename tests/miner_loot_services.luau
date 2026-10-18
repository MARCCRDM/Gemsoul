-- Service doubles for MinerLoot with a clock the cases drive; no Roblox
-- rendering is claimed (tools render the real thing).
colorMt.__index.ToHex = function(self)
	return string.format("%02X%02X%02X", math.floor(self.R * 255 + 0.5), math.floor(self.G * 255 + 0.5), math.floor(self.B * 255 + 0.5))
end
local now, objects, sounds, completions, ticks = 0, {}, {}, {}, 0
local viewport = { X = 1366, Y = 710 }
local os = { clock = function() return now end }
local function signal()
	local listeners = {}
	local event = { Listeners = listeners }
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
	function event:Fire(...) for _, l in table.clone(listeners) do if l[2].Connected then l[1](...) end end end
	function event:Count()
		local n = 0
		for _, l in listeners do if l[2].Connected then n += 1 end end
		return n
	end
	return event
end
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim2 = { new = function(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end }
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
local NumberSequence = { new = function(...) return { ... } end }
local NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
local TweenInfo = { new = function() return {} end }
local Random = { new = function()
	local r = {}
	function r:NextNumber() return math.random() end
	function r:NextInteger(a, b) return math.random(a, b) end
	return r
end }
local methods = {}
local function new(class, props, parent)
	local values = { ClassName = class, Children = {}, Signals = {}, AbsoluteSize = table.clone(viewport),
		Destroying = signal(), Visible = true, Enabled = true }
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
function methods:GetDescendants()
	local result = {}
	for _, child in self:GetChildren() do
		table.insert(result, child)
		for _, d in child:GetDescendants() do table.insert(result, d) end
	end
	return result
end
function methods:IsA(class) return self.ClassName == class end
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
function methods:PivotTo() end
local root = new("PlayerGui")
local Instance = { new = new }
local render = signal()
-- The miner: MechPilot set while they drive a mech.
local pilotChanged = signal()
local localPlayer = { Attributes = {} }
function localPlayer:GetAttribute(name) return self.Attributes[name] end
function localPlayer:SetAttribute(name, value)
	self.Attributes[name] = value
	if name == "MechPilot" then pilotChanged:Fire() end
end
function localPlayer:GetAttributeChangedSignal(name)
	assert(name == "MechPilot", "Unexpected attribute watched: " .. name)
	return pilotChanged
end
local services = {
	ReplicatedStorage = {}, RunService = { RenderStepped = render }, Players = { LocalPlayer = localPlayer },
	UserInputService = { TouchEnabled = false },
	TweenService = { Create = function(_, object, _, goal)
		local done = signal()
		return { Completed = done, Play = function()
			for k, v in goal do object[k] = v end
			table.insert(completions, done)
		end }
	end },
}
local game = { GetService = function(_, id) return services[id] end }
local P = {}
for _, key in { "Edge", "Text", "Dim", "Bad", "Teal" } do P[key] = Color3.fromRGB(200, 200, 200) end
local IronUi = { new = new, Heading = "GothamBold", Colors = P }
local UiKit = { gui = function(name) return new("ScreenGui", { Name = name }, root) end, round = function() end }
local GemArt = {
	viewport = function(parent, gem)
		local view = new("ViewportFrame", { Gem = gem }, parent)
		new("Camera", {}, view)
		return view
	end,
	pose = function() return CFrame.new() end,
}
local LotterySound = { tick = function() ticks += 1 end, reveal = function(rank) table.insert(sounds, rank) end }
-- Frames at 60 a second; tweens finish at the end of the frame they start in.
local function step(seconds)
	for _ = 1, math.ceil(seconds * 60) do
		now += 1 / 60
		render:Fire(1 / 60)
		local done = completions
		completions = {}
		for _, event in done do event:Fire() end
	end
end
local function live(name)
	local found = {}
	for _, o in objects do if not o.Destroyed and o.Name == name then table.insert(found, o) end end
	return found
end
local function texts(under)
	local found = {}
	for _, o in under:GetDescendants() do if o.ClassName == "TextLabel" then table.insert(found, o.Text) end end
	return table.concat(found, "\n")
end
