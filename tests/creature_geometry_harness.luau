-- Hierarchy and matrix support for executing the real cosmetic builder.
function CFrame.Inverse(a)
	local b = CFrame.new()
	for i = 1, 3 do for j = 1, 3 do b.r[(i-1)*3+j] = a.r[(j-1)*3+i] end end
	for i = 1, 3 do
		b.t[i] = 0
		for j = 1, 3 do b.t[i] -= b.r[(i-1)*3+j] * a.t[j] end
	end
	return b
end
cmt.__index = function(a, k)
	if k == "Inverse" then return CFrame.Inverse end
	if k == "Position" then return Vector3.new(unpack(a.t)) end
	if k == "PointToObjectSpace" then return function(c, p) return (c:Inverse() * CFrame.new(p)).Position end end
end
local instances = {}
local newInstance = Instance.new
Instance.new = function(class)
	local obj = newInstance(class)
	table.insert(instances, obj)
	obj.IsA = function(_, name) return name == class or (name == "BasePart" and (class == "Part" or class == "WedgePart")) end
	obj.GetChildren = function(self)
		local out = {}
		for _, other in instances do if other.Parent == self then table.insert(out, other) end end
		return out
	end
	obj.GetDescendants = function(self)
		local out = {}
		for _, child in self:GetChildren() do
			table.insert(out, child)
			for _, descendant in child:GetDescendants() do table.insert(out, descendant) end
		end
		return out
	end
	obj.FindFirstChild = function(self, name)
		for _, child in self:GetChildren() do if child.Name == name then return child end end
		return nil
	end
	obj.ScaleTo = function(self, scale)
		for _, child in self:GetDescendants() do
			if child:IsA("BasePart") then
				child.Size *= scale
				for i = 1, 3 do child.CFrame.t[i] *= scale end
			elseif child:IsA("Motor6D") then
				for _, frame in {child.C0, child.C1} do
					for i = 1, 3 do frame.t[i] *= scale end
				end
			end
		end
	end
	return obj
end
local function sequence(...) return {...} end
local ColorSequence = {new=sequence}
local NumberSequence = {new=sequence}
local NumberSequenceKeypoint = {new=sequence}
local NumberRange = {new=sequence}
local Vector2 = {new=sequence}
