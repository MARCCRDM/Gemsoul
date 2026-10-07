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

-- Lightweight category silhouettes keep a large reserve bag cheap to render.
function GearArt.icon(parent, slotName, gear, color)
	local icon = new(
		"Frame",
		{ BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(28, 26) },
		parent
	)
	local function part(x, y, w, h, angle)
		new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = angle or 0,
		}, icon)
	end
	if slotName == "Helmet" then
		part(4, 3, 20, 19)
		part(7, 22, 14, 3)
		new(
			"Frame",
			{ BackgroundColor3 = P.Frame, Position = UDim2.fromOffset(7, 9), Size = UDim2.fromOffset(14, 6) },
			icon
		)
	elseif slotName == "Armor" then
		part(7, 7, 15, 17)
		part(1, 4, 8, 9, 12)
		part(21, 4, 7, 9, -12)
	elseif slotName == "Gloves" then
		part(7, 9, 14, 14)
		part(7, 3, 4, 10)
		part(13, 2, 4, 10)
		part(19, 4, 3, 10)
		part(2, 12, 6, 8, -20)
	elseif slotName == "Boots" then
		part(6, 3, 11, 17)
		part(6, 18, 19, 7)
	elseif slotName == "Shield" then
		part(5, 3, 19, 14)
		part(8, 13, 13, 11, 45)
	elseif gear.Look == "Standard" then
		part(5, 0, 3, 26)
		part(8, 3, 16, 12)
		part(8, 15, 7, 5)
		part(17, 15, 7, 5)
	elseif gear.Look == "FrontierSword" then
		part(12, 0, 5, 18)
		part(6, 17, 17, 3)
		part(12, 20, 5, 6)
	else
		part(3, 6, 23, 8)
		part(7, 13, 8, 12, 12)
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
