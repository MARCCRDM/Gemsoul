-- Item art shared by the inventory and the Market: 3D thumbnails of gear
-- (worn pieces come from the avatar, spare ones from the server's previews)
-- and light drawn silhouettes as a stand-in.
local Players = game:GetService("Players")
local IronUi = require(script.Parent.IronUi)
local LiveLooks = require(script.Parent.LiveLooks)

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
	LiveLooks.watch(model) -- (animated skins move here as they do when worn)
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
	-- Flat, one-colour silhouettes (the original look), drawn on a 64 px
	-- canvas and scaled into the box. Dark slits mark the few details that
	-- make each one read: a visor, a neck, a knuckle line, a sole, a seam.
	local art = new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
	}, icon)
	new("UIScale", { Scale = 27 / 64 }, art)
	local function shape(x, y, w, h, radius, angle)
		local frame = new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = angle or 0,
			ZIndex = 2,
		}, art)
		if radius then
			new("UICorner", { CornerRadius = UDim.new(0, radius) }, frame)
		end
		return frame
	end
	local function slit(x, y, w, h, radius, angle)
		local frame = new("Frame", {
			BackgroundColor3 = BLACK,
			BackgroundTransparency = 0.45,
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
		shape(13, 6, 38, 42, 19)
		shape(13, 26, 38, 22, 6)
		shape(20, 44, 24, 12, 5)
		slit(18, 24, 28, 9, 4)
		slit(31, 46, 2, 8, 1)
	elseif slotName == "Armor" then
		shape(18, 14, 28, 42, 8)
		shape(5, 12, 20, 15, 7, -16)
		shape(39, 12, 20, 15, 7, 16)
		slit(26, 10, 12, 8, 4)
		slit(31, 24, 2, 26, 1)
	elseif slotName == "Gloves" then
		for i, top in { 12, 8, 10, 16 } do
			shape(17 + (i - 1) * 8, top, 7, 30 - top + 6, 3)
		end
		shape(16, 26, 33, 22, 7)
		shape(6, 28, 10, 19, 5, -32)
		shape(18, 47, 29, 10, 3)
		slit(17, 30, 31, 2, 1)
	elseif slotName == "Boots" then
		shape(18, 6, 22, 38, 4)
		shape(16, 32, 38, 16, 8)
		shape(14, 46, 42, 9, 3)
		slit(15, 45, 40, 2, 1)
	elseif slotName == "Shield" then
		shape(17, 21, 30, 30, 6, 45)
		shape(11, 7, 42, 28, 7)
		slit(31, 12, 2, 38, 1)
	else
		-- A sword, point up and leaning. Each piece is turned about the
		-- centre (rotation doesn't reach a frame's children).
		local lean = math.rad(35)
		local function piece(x, y, w, h, radius, extra)
			local cx, cy = x + w / 2 - 32, y + h / 2 - 32
			local rx = cx * math.cos(lean) - cy * math.sin(lean)
			local ry = cx * math.sin(lean) + cy * math.cos(lean)
			return shape(rx + 32 - w / 2, ry + 32 - h / 2, w, h, radius, 35 + (extra or 0))
		end
		piece(28, 4, 8, 8, 1, 45)
		piece(28, 8, 8, 34, 1)
		piece(16, 41, 32, 6, 3)
		piece(29, 47, 6, 10, 2)
		piece(26, 55, 12, 8, 4)
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
