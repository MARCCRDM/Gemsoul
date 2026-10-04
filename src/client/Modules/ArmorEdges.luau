--[[
	Glowing armor edges at night in the Arena: every block of a fighter's
	armor, weapon and body gets its edges traced in a bright line in its own
	colour (a SelectionBox per part), so the plates, pauldrons, helmet panels
	and limbs read clearly in the dark instead of as one silhouette. Your own
	character is left alone. Purely local.

	  ArmorEdges.setEnabled(on)  ArenaNight turns it on and off
	  ArmorEdges.traceable(part) which parts get edges
	  ArmorEdges.edgeColor(c)    the line colour for a part of colour c
]]
local Players = game:GetService("Players")

local ArmorEdges = {}
ArmorEdges.Thickness = 0.03 -- studs
ArmorEdges.Transparency = 0.1
ArmorEdges.Range = 140 -- fighters further than this from the camera aren't traced
ArmorEdges.MaxBoxes = 700 -- across everyone, to keep it cheap
ArmorEdges.MinSize = 0.12 -- smaller details are skipped (they'd just be noise)

local player = Players.LocalPlayer
local enabled = false
local boxes: { [BasePart]: SelectionBox } = {}
local folder: Folder? = nil

-- Blocks and wedges, visible and big enough. Balls, cylinders and meshes
-- are skipped: a box around them wouldn't follow their shape.
function ArmorEdges.traceable(part: BasePart): boolean
	if part.Name == "HumanoidRootPart" or part.Transparency >= 0.9 or part:IsA("MeshPart") then
		return false
	end
	if part:FindFirstChildOfClass("SpecialMesh") then
		return false
	end
	if part:IsA("Part") and (part.Shape == Enum.PartType.Ball or part.Shape == Enum.PartType.Cylinder) then
		return false
	end
	local size = part.Size
	return math.max(size.X, size.Y, size.Z) >= ArmorEdges.MinSize
end

-- The part's own hue, lit up: dark steel glows a cool white, gold glows gold.
function ArmorEdges.edgeColor(color: Color3): Color3
	local h, s, _ = color:ToHSV()
	if s < 0.12 then
		return Color3.fromRGB(196, 226, 255)
	end
	return Color3.fromHSV(h, math.min(1, s * 0.85), 1)
end

local function fighters(): { Model }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(list, other.Character)
		end
	end
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
			table.insert(list, model)
		end
	end
	return list
end

local function clear()
	for _, box in boxes do
		box:Destroy()
	end
	table.clear(boxes)
end

local function refresh()
	local camera = workspace.CurrentCamera
	if not enabled or not camera then
		return
	end
	if not folder or not folder.Parent then
		local made = Instance.new("Folder")
		made.Name = "ArmorEdges"
		made.Parent = camera
		folder = made
	end
	local eye = camera.CFrame.Position
	local seen, count = {}, 0
	for _, model in fighters() do
		local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
		if root and root:IsA("BasePart") and (root.Position - eye).Magnitude <= ArmorEdges.Range then
			for _, part in model:GetDescendants() do
				if count >= ArmorEdges.MaxBoxes then
					break
				end
				if part:IsA("BasePart") and ArmorEdges.traceable(part) then
					count += 1
					seen[part] = true
					local box = boxes[part]
					if not box then
						box = Instance.new("SelectionBox")
						box.Name = "ArmorEdge"
						box.LineThickness = ArmorEdges.Thickness
						box.SurfaceTransparency = 1
						box.Transparency = ArmorEdges.Transparency
						box.Adornee = part
						box.Parent = folder
						boxes[part] = box
					end
					box.Color3 = ArmorEdges.edgeColor(part.Color) -- follows recolours and shimmer
				end
			end
		end
	end
	for part, box in boxes do
		if not seen[part] then
			box:Destroy()
			boxes[part] = nil
		end
	end
end

local looping = false
function ArmorEdges.setEnabled(on: boolean)
	enabled = on
	if not on then
		clear()
		return
	end
	refresh()
	if not looping then
		looping = true
		-- New fighters, swapped gear and anyone walking into range.
		task.spawn(function()
			while enabled do
				task.wait(0.5)
				refresh()
			end
			looping = false
		end)
	end
end

return ArmorEdges
