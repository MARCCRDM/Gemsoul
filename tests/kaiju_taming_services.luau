-- Service doubles for KaijuTaming: a clock the cases drive, a world of wild
-- kaiju models, the local player and their attributes. No Roblox rendering
-- is claimed.
vmt.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
vmt.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
vmt.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return nil
end
Vector3.one = Vector3.new(1, 1, 1)
Vector3.zero = Vector3.new(0, 0, 0)
local now, serverClock = 0, 1000
local os = { clock = function() return now end }
local function signal()
	local listeners = {}
	local event = {}
	function event:Connect(fn)
		local c = { Connected = true }
		function c:Disconnect() c.Connected = false end
		table.insert(listeners, { fn, c })
		return c
	end
	function event:Fire(...)
		for _, l in table.clone(listeners) do
			if l[2].Connected then l[1](...) end
		end
	end
	return event
end
local Vector2 = { new = function(x, y) return { X = x, Y = y } end }
local UDim2 = { new = function(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end }
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
local ColorSequence = { new = function(...) return { ... } end }
local NumberSequence = { new = function(...) return { ... } end }

local objects = {}
local methods = {}
local function make(class, props, parent)
	local values = { ClassName = class, Children = {}, Attributes = {}, AttrSignals = {} }
	local object
	object = setmetatable({}, {
		__index = function(_, key) return methods[key] or values[key] end,
		__newindex = function(_, key, value)
			if key == "Parent" and value then table.insert(value.Children, object) end
			values[key] = value
		end,
	})
	for key, value in props or {} do object[key] = value end
	if parent then object.Parent = parent end
	table.insert(objects, object)
	return object
end
function methods:GetChildren()
	local out = {}
	for _, child in self.Children do
		if child.Parent == self and not child.Destroyed then table.insert(out, child) end
	end
	return out
end
function methods:FindFirstChild(name)
	for _, child in self:GetChildren() do if child.Name == name then return child end end
	return nil
end
function methods:FindFirstChildOfClass(class)
	for _, child in self:GetChildren() do if child.ClassName == class then return child end end
	return nil
end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:IsA(class) return self.ClassName == class end
function methods:Destroy()
	self.Destroyed = true
	self.Parent = nil
	for _, child in self.Children do if child.Parent == self then child:Destroy() end end
end
function methods:GetAttribute(name) return self.Attributes[name] end
function methods:SetAttribute(name, value)
	self.Attributes[name] = value
	local s = self.AttrSignals[name]
	if s then s:Fire() end
end
function methods:GetAttributeChangedSignal(name)
	self.AttrSignals[name] = self.AttrSignals[name] or signal()
	return self.AttrSignals[name]
end
function methods:GetExtentsSize() return self.Extents or Vector3.new(8, 8, 10) end

local Instance = { new = function(class) return make(class) end }
local workspaceRoot = make("Workspace", { Name = "Workspace" })
function workspaceRoot:GetServerTimeNow() return serverClock end
local workspace = workspaceRoot
local enemiesFolder = make("Folder", { Name = "Enemies" }, workspaceRoot)

local playerGui = make("PlayerGui", { Name = "PlayerGui" })
local character = make("Model", { Name = "Me" })
local myRoot = make("Part", { Name = "HumanoidRootPart", Position = Vector3.new(0, 3, 0), Size = Vector3.new(2, 2, 1) }, character)
local myHand = make("Part", { Name = "RightHand", Position = Vector3.new(1, 3, 0), Size = Vector3.new(1, 1, 1) }, character)
character.PrimaryPart = myRoot
local localPlayer = make("Player", { Name = "Me", UserId = 7, Character = character })
playerGui.Parent = localPlayer
localPlayer:SetAttribute("Outpost", true)
local Players = {
	LocalPlayer = localPlayer,
	GetPlayerByUserId = function(_, id) return if id == 7 then localPlayer else nil end,
}
local heartbeat = signal()
local RunService = { Heartbeat = heartbeat }
local game = { GetService = function(_, name)
	if name == "Players" then return Players end
	if name == "RunService" then return RunService end
	return {}
end }
local ReplicatedStorage = {}

-- What the module draws with.
local sounds = {}
local CombatSound = { play = function(name) table.insert(sounds, name) end }
local IronUi = {
	Colors = setmetatable({}, { __index = function() return Color3.new(1, 1, 1) end }),
	new = function(class, props, parent) return make(class, props, parent) end,
	Bold = "GothamBold",
	Body = "Gotham",
}
-- (A phone or not: the ready words' size, like the wild kaiju plate.)
local phoneMode = false
local WildBars = { phone = function() return phoneMode end }
local UiKit = {
	gui = function(name, order) return make("ScreenGui", { Name = name, DisplayOrder = order, Enabled = true }, playerGui) end,
	round = function() end,
}

-- A wild kaiju out at `at`, at `share` of its health.
local function wildKaiju(name, at, share)
	local model = make("Model", { Name = name }, enemiesFolder)
	local root = make("Part", { Name = "HumanoidRootPart", Position = at, Size = Vector3.new(4, 4, 4) }, model)
	model.PrimaryPart = root
	make("Humanoid", { Health = 300 * share, MaxHealth = 300 }, model)
	model:SetAttribute("KaijuWild", true)
	return model
end
local function frames(seconds)
	local steps = math.max(1, math.floor(seconds / 0.05 + 0.5))
	for _ = 1, steps do
		now += 0.05
		serverClock += 0.05
		heartbeat:Fire(0.05)
	end
end
