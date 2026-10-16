-- GUI doubles for the lobby's board and feed (Modules/LobbyBoard, LobbyFeed).
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, callback)
			table.insert(callbacks, callback)
			return { Disconnect = function() end }
		end,
		Fire = function(_, ...)
			for _, callback in callbacks do
				callback(...)
			end
		end,
	}
end
local Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
local UDim2 = {
	new = function(xs, xo, ys, yo)
		return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
	end,
}
UDim2.fromOffset = function(x, y)
	return UDim2.new(0, x, 0, y)
end
UDim2.fromScale = function(x, y)
	return UDim2.new(x, 0, y, 0)
end
local Color3 = {
	new = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
}
local ColorSequence = {
	new = function(...)
		return { ... }
	end,
}
local TweenInfo = {
	new = function()
		return {}
	end,
}
local Enum = setmetatable({}, {
	__index = function(self, key)
		local t = setmetatable({}, {
			__index = function(_, k)
				return k
			end,
		})
		rawset(self, key, t)
		return t
	end,
})
local objects = {}
local function new(class, props, parent)
	local values =
		{ ClassName = class, children = {}, attributes = {}, Visible = true, Activated = signal(), Enabled = true }
	local methods = {}
	function methods:GetChildren()
		return table.clone(values.children)
	end
	function methods:GetDescendants()
		local out = {}
		local function walk(node)
			for _, child in node.children do
				table.insert(out, child)
				walk(child)
			end
		end
		walk(values)
		return out
	end
	function methods:SetAttribute(key, value)
		values.attributes[key] = value
	end
	function methods:GetAttribute(key)
		return values.attributes[key]
	end
	function methods:IsA(key)
		return values.ClassName == key
	end
	function methods:FindFirstChild(name)
		for _, child in values.children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods:Destroy()
		values.Destroyed = true
		if values.Parent then
			local siblings = values.Parent.children
			local index = table.find(siblings, values.self)
			if index then
				table.remove(siblings, index)
			end
		end
		values.Parent = nil
	end
	local object = setmetatable({}, {
		__index = function(_, key)
			return methods[key] or values[key]
		end,
		__newindex = function(_, key, value)
			if key == "Parent" and value then
				table.insert(value.children, values.self)
			end
			values[key] = value
		end,
	})
	values.self = object
	for key, value in props or {} do
		object[key] = value
	end
	if parent then
		object.Parent = parent
	end
	table.insert(objects, object)
	return object
end
local tweens = {}
local TweenService = {
	Create = function(_, target, _, goal)
		local completed = signal()
		local tween = { Completed = completed }
		function tween:Play()
			for key, value in goal do
				target[key] = value
			end
			completed:Fire()
		end
		table.insert(tweens, tween)
		return tween
	end,
}
local spawned = {}
local task = {
	spawn = function(fn)
		table.insert(spawned, fn)
	end,
	defer = function(fn, ...)
		fn(...)
	end,
	delay = function(_, fn)
		table.insert(spawned, fn)
	end,
	wait = function() end,
}
local playerGui = new("PlayerGui", {})
local player = new("Player", { Name = "Marc", DisplayName = "Marc", UserId = 1, PlayerGui = playerGui })
local Players = { LocalPlayer = player, PlayerAdded = signal() }
local remoteFolder = new("Folder", { Name = "Remotes" })
local miningRoll = new("RemoteEvent", { Name = "MiningRoll", Parent = remoteFolder })
miningRoll.OnClientEvent = signal()
local social = new("RemoteEvent", { Name = "Social", Parent = remoteFolder })
social.OnClientEvent = signal()
local ReplicatedStorage = {
	FindFirstChild = function(_, name)
		return if name == "Remotes" then remoteFolder else nil
	end,
}
local IronUi = {
	Colors = {
		Text = Color3.new(1, 1, 1),
		Dim = Color3.new(0.7, 0.7, 0.7),
		Gold = Color3.new(1, 0.8, 0.3),
		Teal = Color3.new(0.2, 0.8, 0.9),
	},
	Heading = "heading",
	Body = "body",
	new = new,
	juice = function() end,
	outline = function() end,
}
local UiKit = {
	round = function() end,
	list = function(parent)
		return new("UIListLayout", {}, parent)
	end,
}
local GemClient = { Profile = nil, Changed = signal(), ChallengesChanged = signal() }
local GemConfig = {
	TierRank = { Common = 1, Uncommon = 2, Rare = 3, UltraRare = 4, Legendary = 5 },
	TierColors = {
		Rare = Color3.new(0.3, 0.6, 1),
		UltraRare = Color3.new(1, 0.35, 0.86),
		Legendary = Color3.new(1, 0.69, 0.24),
	},
	elementName = function(element)
		return ({ Fire = "Thermal", Frost = "Cryo" })[element] or element
	end,
}
