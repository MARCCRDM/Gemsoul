local colorMt = { __index = {
	Lerp = function(self, _other, _amount)
		return self
	end,
} }
local Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r, G = g, B = b, kind = "Color3" }, colorMt)
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
local vmt = {}
local Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, vmt)
	end,
}
vmt.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local cmt = {
	__mul = function(a, _b)
		return a
	end,
}
local CFrame = {
	new = function(...)
		return setmetatable({}, cmt)
	end,
}
CFrame.Angles = CFrame.new
CFrame.identity = CFrame.new()
local enumMt = {
	__index = function(_self, key)
		return key
	end,
}
local Enum = setmetatable({}, {
	__index = function(self, key)
		local t = setmetatable({}, enumMt)
		rawset(self, key, t)
		return t
	end,
})
local built = 0
local Instance = {
	new = function(className)
		local values = { ClassName = className }
		return setmetatable({}, {
			__index = values,
			__newindex = function(_self, key, value)
				if key == "Color" then
					assert(
						type(value) == "table" and value.kind == "Color3",
						"Invalid Color assignment: " .. type(value)
					)
				end
				if key == "Size" then
					assert(value.X > 0 and value.Y > 0 and value.Z > 0, "Invalid part size")
				end
				values[key] = value
				if key == "Parent" and (className == "Part" or className == "WedgePart") then
					built += 1
				end
			end,
		})
	end,
}

local randomSeed = 123
local Random = {
	new = function(seed)
		randomSeed += 1
		local state = seed or randomSeed
		return {
			NextNumber = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return (low or 0) + state / 2147483647 * ((high or 1) - (low or 0))
			end,
			NextInteger = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return low + state % (high - low + 1)
			end,
		}
	end,
}
