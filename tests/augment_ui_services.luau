local function signal()
	local callbacks = {}
	return { Connect = function(_, callback) table.insert(callbacks, callback) end, Fire = function(...) for _, callback in callbacks do callback(...) end end }
end
local v2mt = {}
v2mt.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y }, v2mt) end
v2mt.__index = function(v, key) if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end end
local Vector2 = { new = function(x, y) return setmetatable({ X = x, Y = y }, v2mt) end }
local UDim2 = { new = function(xs, xo, ys, yo) return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } } end }
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
local UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end }
local ColorSequence = { new = function(...) return { ... } end }
local objects = {}
local function new(class, props, parent)
	local values = { ClassName = class, children = {}, signals = {}, Activated = signal(), AbsoluteSize = { X = 1000, Y = 700 }, Active = true }
	local methods = {}
	function methods:GetChildren() return table.clone(values.children) end
	function methods:SetAttribute(key, value) values["@" .. key] = value end
	function methods:IsA(key)
		if key == "GuiObject" then return string.sub(values.ClassName, 1, 2) ~= "UI" end
		return values.ClassName == key
	end
	function methods:GetPropertyChangedSignal(key)
		values.signals[key] = values.signals[key] or signal()
		return values.signals[key]
	end
	function methods:FindFirstChildOfClass(key)
		for _, child in values.children do if child.ClassName == key and not child.Destroyed then return child end end
	end
	function methods:Destroy()
		values.Destroyed = true
		for _, child in table.clone(values.children) do child:Destroy() end
		if values.Parent then
			for i, child in values.Parent.children do if child == self then table.remove(values.Parent.children, i); break end end
		end
	end
	local object = setmetatable({}, {
		__index = function(_, key) return methods[key] or values[key] end,
		__newindex = function(_, key, value)
			if key == "Active" or key == "Enabled" then assert(typeof(value) == "boolean", key .. " must be a boolean") end
			values[key] = value
		end,
	})
	for key, value in props or {} do object[key] = value end
	object.Parent = parent
	if parent then table.insert(parent.children, object) end
	table.insert(objects, object)
	return object
end
local Instance = { new = function(class) return new(class, {}) end }
local UiKit = { Colors = { Bad = "bad" }, round = function() end, toast = function() end }
UiKit.list = function(parent) return new("UIListLayout", {}, parent) end
UiKit.gui = function(name) return new("ScreenGui", { Name = name }) end
local palette = {}
for _, key in { "Frame", "Inset", "Slot", "Edge", "Gold", "Text", "Dim", "Good", "Bad", "Teal", "Ink" } do
	palette[key] = Color3.new(0.5, 0.5, 0.5)
end
local IronUi = { Colors = palette, Bold = "bold", Heading = "heading", Body = "body", new = new }
IronUi.text = function(parent, value) return new("TextLabel", { Text = value }, parent) end
IronUi.juice = function() end
IronUi.clear = function(parent)
	for _, child in parent:GetChildren() do child:Destroy() end
end
-- The shared modal window: a ScreenGui with a panel, title, subtitle, close button and backdrop.
IronUi.window = function(name)
	local gui = UiKit.gui(name)
	local panel = new("Frame", { Size = UDim2.fromOffset(1100, 700) }, gui)
	return {
		Gui = gui,
		Panel = panel,
		Title = new("TextLabel", {}, panel),
		Subtitle = new("TextLabel", {}, panel),
		Close = new("TextButton", { Text = "X" }, panel),
		Shade = new("TextButton", { Text = "" }, gui),
	}
end
local GemConfig = { ElementColors = {}, elementName = function(element) return element end }
local GemClient = { Profile = { Season = { XP = 0 } }, Changed = signal() }
GemClient.request = function(action, id)
	local ok, message
	if action == "LearnAugment" then ok, message = Tree.learn(GemClient.Profile, id)
	elseif action == "UpgradeAugment" then ok, message = Tree.upgrade(GemClient.Profile, id)
	else ok, message = Tree.respec(GemClient.Profile) end
	return { Ok = ok, Message = message, Augments = GemClient.Profile.Augments }
end
local player = { attributes = {}, events = {} }
function player:GetAttribute(key) return self.attributes[key] end
function player:GetAttributeChangedSignal(key)
	self.events[key] = self.events[key] or signal()
	return self.events[key]
end
local Players = { LocalPlayer = player }
local game = { GetService = function(_, key) return if key == "Players" then Players else {} end }
local Combat = { canFight = function() return false end }
local task = { spawn = function(callback) callback() end }
