--[[
	Skin seams and glowing edges are SelectionBoxes (tagged SkinSeam by the
	server, Equipment.outline). Roblox draws a SelectionBox even round a part
	that is hidden, so without this the outlines of your own suit filled the
	first-person view (your helmet and chest plates are hidden round the
	camera, their outlines weren't), and a staged or stowed piece left its
	outline floating in the air. Each box shows only while its part does.
	Purely local.

	  SeamVisibility.shows(box)  pure: whether the box's part is showing
	  SeamVisibility.start()
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tags = require(ReplicatedStorage.Shared.Tags)

local SeamVisibility = {}

function SeamVisibility.shows(box: SelectionBox): boolean
	local part = box.Adornee
	return part ~= nil and part:IsA("BasePart") and part.Transparency < 0.99 and part.LocalTransparencyModifier < 0.99
end

function SeamVisibility.start()
	local boxes: { [SelectionBox]: boolean } = {}
	local function add(instance: Instance)
		if instance:IsA("SelectionBox") then
			boxes[instance] = true
		end
	end
	for _, instance in CollectionService:GetTagged(Tags.SkinSeam) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.SkinSeam):Connect(add)
	CollectionService:GetInstanceRemovedSignal(Tags.SkinSeam):Connect(function(instance)
		boxes[instance :: SelectionBox] = nil
	end)
	-- Just after the camera (and the first-person view, which hides your own
	-- parts at Camera + 3), so a box never shows for a frame round the camera.
	RunService:BindToRenderStep("SkinSeams", Enum.RenderPriority.Camera.Value + 4, function()
		for box in boxes do
			local shows = SeamVisibility.shows(box)
			if box.Visible ~= shows then
				box.Visible = shows
			end
		end
	end)
end

return SeamVisibility
