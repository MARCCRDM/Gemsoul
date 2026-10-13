-- Item art shared by the inventory and the Market: 3D thumbnails of gear
-- (worn pieces come from the avatar, spare ones from the server's previews)
-- and light drawn silhouettes as a stand-in.
local Players = game:GetService("Players")
local IronUi = require(script.Parent.IronUi)

local GearArt = {}
local player = Players.LocalPlayer
local P = IronUi.Colors
local new = IronUi.new

-- Draws one item's parts in a viewport, framed for a thumbnail. `anchorOf`
-- names the body part a piece is worn on; `placeOf` gives its CFrame
-- relative to the wearer.
function GearArt.frame(
	view: ViewportFrame,
	key: string,
	parts: { BasePart },
	anchorOf: (BasePart) -> string,
	placeOf: (BasePart) -> CFrame
)
	view:ClearAllChildren()
	local world = new("WorldModel", {}, view)
	local model = new("Model", {}, world)
	for _, part in parts do
		if part.Transparency >= 1 then
			continue
		end
		local anchorName = anchorOf(part)
		-- Show one glove/boot and just the chest assembly, keeping thumbnails readable.
		if (key == "Gloves" or key == "Boots") and string.find(anchorName, "Right") then
			continue
		end
		if key == "Armor" and (string.find(anchorName, "Arm") or string.find(anchorName, "Leg")) then
			continue
		end
		local clone = part:Clone()
		for _, child in clone:GetChildren() do
			child:Destroy()
		end
		clone.Anchored = true
		clone.CFrame = placeOf(part)
		clone.Parent = model
	end
	if key == "Shield" and #model:GetChildren() > 0 then
		-- A shield follows its forearm's pose, so frame it from its own back
		-- plate (the biggest part, square to the shield, face towards -Z):
		-- upright and face on, however the arm was held.
		local plate, biggest = nil, 0
		for _, part in model:GetChildren() do
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			if volume > biggest then
				plate, biggest = part, volume
			end
		end
		local square = (plate :: BasePart).CFrame
		for _, part in model:GetChildren() do
			part.CFrame = square:ToObjectSpace(part.CFrame)
		end
		model.WorldPivot = CFrame.new()
		local frame, size = model:GetBoundingBox()
		local camera = new("Camera", { FieldOfView = 30 }, view)
		local direction = Vector3.new(0.3, 0.12, -1).Unit
		local distance = math.max(size.X, size.Y) * 2.25 + size.Z
		camera.CFrame = CFrame.lookAt(frame.Position + direction * distance, frame.Position)
		view.CurrentCamera = camera
		return true
	end
	if #model:GetChildren() > 0 then
		local frame, size = model:GetBoundingBox()
		local camera = new("Camera", { FieldOfView = 30 }, view)
		-- Shields and guns (held pointing forward) read best from the side.
		local sideways = key == "Shield" or (key == "Weapon" and size.Z > size.Y)
		local direction = if sideways then Vector3.new(1, 0.15, -0.1).Unit else Vector3.new(0.22, 0.1, -1).Unit
		local distance = math.max(size.X, size.Y, size.Z) * 2.3 + 0.2
		camera.CFrame = CFrame.lookAt(frame.Position + direction * distance, frame.Position)
		view.CurrentCamera = camera
		return true
	end
	return false
end

-- 3D previews of spare items arrive from the server in a hidden ScreenGui.
local function previewStore(): Instance?
	return player:FindFirstChildOfClass("PlayerGui")
		and (player:FindFirstChildOfClass("PlayerGui") :: PlayerGui):FindFirstChild("GearPreviews")
end

function GearArt.preview(slotName: string, id: string): Instance?
	local store = previewStore()
	return store and store:FindFirstChild(slotName .. "|" .. id)
end

-- Lightweight drawn icons keep a large reserve bag cheap to render (no 3D).
-- Each is drawn on a 64 x 64 canvas and scaled into the usual 28 x 26 box:
-- shapes lit from above (a gradient), a soft shadow under the silhouette,
-- a lighter edge on top and darker details (visor, plates, fingers, fuller).
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
-- The vector icons (tools/gear_icons/*.svg, baked by tools/make_gear_icons.js
-- into assets/images/gear_icons.png): one 256 px cell per slot, grey so the
-- item's colour tints them. Upload the PNG once (Creator Hub, Images) and put
-- its id here; until then the drawn icons below stand in.
GearArt.IconSheet = {
	ImageId = 0,
	Cell = 256,
	Order = { Helmet = 0, Armor = 1, Gloves = 2, Boots = 3, Weapon = 4, Shield = 5 },
}
function GearArt.icon(parent, slotName, gear, color)
	local icon = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(28, 26) },
		parent
	)
	local sheet = GearArt.IconSheet
	local cell = sheet.Order[slotName] or sheet.Order.Weapon
	if sheet.ImageId ~= 0 then
		new("ImageLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(28, 28),
			Image = "rbxassetid://" .. sheet.ImageId,
			ImageRectOffset = Vector2.new(cell * sheet.Cell, 0),
			ImageRectSize = Vector2.new(sheet.Cell, sheet.Cell),
			ImageColor3 = color,
			ScaleType = Enum.ScaleType.Fit,
		}, icon)
		return icon
	end
	local art = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
	}, icon)
	new("UIScale", { Scale = 27 / 64 }, art)
	local light, dark, deep = color:Lerp(WHITE, 0.45), color:Lerp(BLACK, 0.45), color:Lerp(BLACK, 0.72)
	local shadows, shapes = {}, {}
	-- One lit shape (and its shadow, drawn first so it sits underneath).
	local function shape(x, y, w, h, radius, angle, fill)
		local rotation = angle or 0
		local shadow = new("Frame", {
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x + 1.5, y + 2.5),
			Size = UDim2.fromOffset(w, h),
			Rotation = rotation,
			ZIndex = 1,
		}, art)
		new("UICorner", { CornerRadius = UDim.new(0, radius or 0) }, shadow)
		table.insert(shadows, shadow)
		local frame = new("Frame", {
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = rotation,
			ZIndex = 2,
		}, art)
		new("UICorner", { CornerRadius = UDim.new(0, radius or 0) }, frame)
		local base = fill or color
		new("UIGradient", {
			Rotation = 90 - rotation,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, base:Lerp(WHITE, 0.35)),
				ColorSequenceKeypoint.new(0.45, base),
				ColorSequenceKeypoint.new(1, base:Lerp(BLACK, 0.3)),
			}),
		}, frame)
		table.insert(shapes, frame)
		return frame
	end
	-- A flat detail on top (no shadow): seams, visors, highlights.
	local function detail(x, y, w, h, fill, radius, angle, transparency)
		local frame = new("Frame", {
			BackgroundColor3 = fill,
			BackgroundTransparency = transparency or 0,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = angle or 0,
			ZIndex = 3,
		}, art)
		if radius then
			new("UICorner", { CornerRadius = UDim.new(0, radius) }, frame)
		end
		return frame
	end
	if slotName == "Helmet" then
		-- A sealed helm: domed shell, cheek guards, a wide visor with a glint.
		shape(13, 6, 38, 44, 19)
		shape(8, 24, 10, 18, 4)
		shape(46, 24, 10, 18, 4)
		shape(20, 44, 24, 12, 5)
		detail(17, 20, 30, 13, deep, 6)
		detail(20, 22, 12, 3, light, 2, -8, 0.15)
		detail(31, 8, 2, 11, dark, 1, 0, 0.3)
		detail(24, 47, 16, 2, dark, 1)
		detail(24, 51, 16, 2, dark, 1)
	elseif slotName == "Armor" then
		-- A breastplate with pauldrons, a neck notch, a centre ridge and ab plates.
		shape(17, 12, 30, 44, 9)
		shape(3, 10, 20, 16, 7, -18)
		shape(41, 10, 20, 16, 7, 18)
		detail(25, 9, 14, 8, deep, 4)
		detail(31, 20, 2, 32, dark, 1, 0, 0.2)
		detail(21, 36, 22, 2, dark, 1, 0, 0.25)
		detail(22, 44, 20, 2, dark, 1, 0, 0.25)
		detail(20, 16, 9, 3, light, 2, 0, 0.35)
	elseif slotName == "Gloves" then
		-- A gauntlet: four fingers, a thumb, the back plate and a flared cuff.
		for i, height in { 20, 23, 22, 18 } do
			shape(15 + (i - 1) * 8, 30 - height, 7, height + 4, 3)
		end
		shape(14, 22, 34, 22, 7)
		shape(4, 26, 10, 20, 5, -35)
		shape(12, 44, 38, 14, 4)
		detail(18, 28, 26, 2, dark, 1, 0, 0.3)
		detail(15, 49, 32, 2, dark, 1, 0, 0.2)
		detail(17, 25, 10, 3, light, 2, 0, 0.35)
	elseif slotName == "Boots" then
		-- A greave and boot: shaft, cuff, the foot with a rounded toe, a sole.
		shape(14, 8, 24, 36, 5)
		shape(12, 34, 42, 18, 9)
		shape(40, 38, 16, 14, 7)
		shape(10, 50, 48, 7, 3, 0, deep:Lerp(color, 0.3))
		shape(11, 4, 30, 9, 3)
		detail(18, 18, 16, 2, dark, 1, 0, 0.3)
		detail(18, 26, 16, 2, dark, 1, 0, 0.3)
		detail(38, 40, 2, 10, dark, 1, 0, 0.35)
		detail(16, 38, 12, 3, light, 2, 0, 0.35)
	elseif slotName == "Shield" then
		-- A heater shield: flat top, the point below, a raised rim and a boss.
		local point = shape(16, 20, 32, 32, 6, 45)
		point.ZIndex = 2
		shape(10, 6, 44, 30, 8)
		detail(14, 10, 36, 3, light, 2, 0, 0.35)
		detail(31, 12, 2, 38, dark, 1, 0, 0.35)
		detail(14, 22, 36, 2, dark, 1, 0, 0.35)
		local boss = shape(25, 21, 14, 14, 7, 0, color:Lerp(WHITE, 0.2))
		boss.ZIndex = 4
		detail(28, 23, 5, 3, WHITE, 2, 0, 0.3).ZIndex = 5
	else
		-- A sword, point up and leaning: blade with its fuller, guard, grip,
		-- pommel. Each piece is turned about the centre (rotation doesn't
		-- reach a frame's children).
		local lean = math.rad(35)
		local function turned(x, y, w, h)
			local cx, cy = x + w / 2 - 32, y + h / 2 - 32
			local rx = cx * math.cos(lean) - cy * math.sin(lean)
			local ry = cx * math.sin(lean) + cy * math.cos(lean)
			return rx + 32 - w / 2, ry + 32 - h / 2
		end
		local function piece(x, y, w, h, radius, extra, fill)
			local px, py = turned(x, y, w, h)
			return shape(px, py, w, h, radius, 35 + (extra or 0), fill)
		end
		local function line(x, y, w, h, fill, transparency)
			local px, py = turned(x, y, w, h)
			return detail(px, py, w, h, fill, 1, 35, transparency)
		end
		local steel = color:Lerp(WHITE, 0.25)
		piece(27, 3, 10, 10, 2, 45, steel)
		piece(27, 8, 10, 34, 2, 0, steel)
		line(31, 10, 2, 30, dark, 0.25)
		line(28.5, 11, 1.5, 28, WHITE, 0.45)
		piece(15, 41, 34, 7, 3)
		piece(28, 48, 8, 10, 2, 0, dark)
		piece(25, 56, 14, 8, 4)
		line(29, 50, 6, 2, deep, 0.2)
		line(29, 54, 6, 2, deep, 0.2)
	end
	return icon
end

-- Draws an owned item into `view`: the worn piece from the avatar, or a spare
-- one from the server's previews. False when no 3D art is available yet.
function GearArt.draw(view: ViewportFrame, slotName: string, id: string, worn: boolean): boolean
	local parts, anchorOf, placeOf = {}, nil, nil
	local character = player.Character
	local equipment = character and character:FindFirstChild("GemsoulGear")
	local source = if worn then equipment and equipment:FindFirstChild(slotName) else GearArt.preview(slotName, id)
	if source then
		for _, part in source:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end
	if worn and character then
		local origin = character:GetPivot()
		anchorOf = function(part)
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			local anchor = weld and weld.Part0
			return if anchor then anchor.Name else ""
		end
		placeOf = function(part)
			return origin:ToObjectSpace(part.CFrame)
		end
	else
		anchorOf = function(part)
			return part:GetAttribute("Anchor") or ""
		end
		placeOf = function(part)
			return part.CFrame
		end
	end
	return #parts > 0 and GearArt.frame(view, slotName, parts, anchorOf, placeOf)
end

return GearArt
