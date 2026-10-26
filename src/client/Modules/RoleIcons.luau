--[[
	Role symbols for the kaiju (Shared.KaijuRoles), drawn from plain frames
	so they never fall back to a missing font glyph:
	  Tank      a shield
	  Warrior   two crossed blades
	  Ranged    a crosshair
	  Assassin  a dagger
	  Breaker   a hammer
	  Warden    a plus (the support)
	RoleIcons.draw(parent, role, size, color, zindex) puts one in a square
	box `size` px across (its Position is left to the caller) and returns it.
]]
local RoleIcons = {}

RoleIcons.Roles = { "Tank", "Warrior", "Ranged", "Assassin", "Breaker", "Warden" }

local function piece(box: Frame, x: number, y: number, w: number, h: number, color: Color3, rotation: number?, corner: number?)
	local frame = Instance.new("Frame")
	frame.Name = "Piece"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.Rotation = rotation or 0
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.ZIndex = box.ZIndex
	if corner then
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(corner, 0)
		round.Parent = frame
	end
	frame.Parent = box
	return frame
end

-- Each role's drawing, in a unit box.
local DRAW = {
	Tank = function(box, color, _size)
		-- (A heater shield: a broad flat top, the sides running down to a
		-- point, split down the middle by a dark line.)
		piece(box, 0.5, 0.29, 0.86, 0.42, color, 0, 0.12)
		piece(box, 0.5, 0.5, 0.61, 0.61, color, 45, 0.08)
		piece(box, 0.5, 0.48, 0.12, 0.62, color:Lerp(Color3.new(0, 0, 0), 0.6))
	end,
	Warrior = function(box, color, _size)
		-- (Blades from the bottom corners up to the top ones, each with a
		-- crossguard across it near the hilt and a pommel at the end.)
		piece(box, 0.55, 0.45, 0.13, 0.86, color, 45, 0.5)
		piece(box, 0.45, 0.45, 0.13, 0.86, color, -45, 0.5)
		piece(box, 0.28, 0.72, 0.44, 0.13, color, 45, 0.5)
		piece(box, 0.72, 0.72, 0.44, 0.13, color, -45, 0.5)
		piece(box, 0.12, 0.88, 0.2, 0.2, color, 0, 0.5)
		piece(box, 0.88, 0.88, 0.2, 0.2, color, 0, 0.5)
	end,
	Ranged = function(box, color, size)
		local ring = piece(box, 0.5, 0.5, 0.66, 0.66, color, 0, 0.5)
		ring.BackgroundTransparency = 1
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = math.max(1.5, size * 0.12)
		stroke.Parent = ring
		piece(box, 0.5, 0.5, 0.22, 0.22, color, 0, 0.5)
		piece(box, 0.5, 0.06, 0.13, 0.24, color)
		piece(box, 0.5, 0.94, 0.13, 0.24, color)
		piece(box, 0.06, 0.5, 0.24, 0.13, color)
		piece(box, 0.94, 0.5, 0.24, 0.13, color)
	end,
	Assassin = function(box, color, _size)
		-- (A broad blade to a point, a short guard, the grip and pommel.)
		piece(box, 0.5, 0.4, 0.32, 0.46, color)
		piece(box, 0.5, 0.17, 0.32, 0.32, color, 45)
		piece(box, 0.5, 0.67, 0.74, 0.14, color, 0, 0.5)
		piece(box, 0.5, 0.82, 0.16, 0.2, color)
		piece(box, 0.5, 0.94, 0.26, 0.12, color, 0, 0.5)
	end,
	Breaker = function(box, color, _size)
		piece(box, 0.5, 0.27, 0.86, 0.36, color, 0, 0.15)
		piece(box, 0.5, 0.68, 0.2, 0.64, color, 0, 0.4)
	end,
	Warden = function(box, color, _size)
		piece(box, 0.5, 0.5, 0.9, 0.3, color, 0, 0.2)
		piece(box, 0.5, 0.5, 0.3, 0.9, color, 0, 0.2)
	end,
}

function RoleIcons.has(role: string?): boolean
	return role ~= nil and DRAW[role] ~= nil
end

function RoleIcons.draw(parent: Instance, role: string?, size: number, color: Color3, zindex: number?): Frame
	local box = Instance.new("Frame")
	box.Name = "RoleIcon"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(size, size)
	box.ZIndex = zindex or 1
	box:SetAttribute("Role", role)
	box.Parent = parent
	local draw = role and DRAW[role]
	if draw then
		draw(box, color, size)
	end
	return box
end

return RoleIcons
