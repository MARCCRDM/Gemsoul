-- Static presentation poses for cloned, anchored inventory rigs only.
local InventoryPose = {}
local poses = {
	Prospector = {
		Waist = { -4, -12, 2 }, Neck = { 2, 10, -2 },
		RightShoulder = { 22, -8, 12 }, RightElbow = { 36, 0, 0 },
		LeftShoulder = { 18, 10, -12 }, LeftElbow = { 40, 0, 0 },
		RightHip = { -8, -8, 5 }, LeftHip = { 12, 10, -5 },
		RightKnee = { -8, 0, 0 }, LeftKnee = { -14, 0, 0 },
	},
	Skirmisher = {
		Waist = { -8, -20, -3 }, Neck = { 5, 16, 3 },
		RightShoulder = { 32, -15, 22 }, RightElbow = { 48, 0, 0 },
		LeftShoulder = { 26, 12, -18 }, LeftElbow = { 55, 0, 0 },
		RightHip = { -16, -12, 9 }, LeftHip = { 22, 12, -9 },
		RightKnee = { -18, 0, 0 }, LeftKnee = { -26, 0, 0 },
	},
	Juggernaut = {
		Waist = { -3, 10, 0 }, Neck = { 0, -10, 0 },
		RightShoulder = { 12, -10, 18 }, RightElbow = { 30, 0, 0 },
		LeftShoulder = { 42, 15, -14 }, LeftElbow = { 65, 0, 0 },
		RightHip = { -6, -10, 10 }, LeftHip = { 10, 12, -10 },
		RightKnee = { -10, 0, 0 }, LeftKnee = { -14, 0, 0 },
	},
}

function InventoryPose.apply(model: Model, family: string?)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return end
	local pose = poses[family] or poses.Prospector
	local links = {}
	local function connect(a, b, relative)
		if not a or not b or not a:IsA("BasePart") or not b:IsA("BasePart") then return end
		links[a] = links[a] or {}
		links[b] = links[b] or {}
		table.insert(links[a], { Part = b, Offset = relative })
		table.insert(links[b], { Part = a, Offset = relative:Inverse() })
	end
	-- Snapshot links before moving anything, including every welded armor part.
	for _, joint in model:GetDescendants() do
		local angles = pose[joint.Name]
		local rotation = if angles then CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3])) else CFrame.new()
		if joint:IsA("Motor6D") or joint:IsA("Weld") then
			connect(joint.Part0, joint.Part1, joint.C0 * rotation * joint.C1:Inverse())
		elseif joint:IsA("WeldConstraint") and joint.Part0 and joint.Part1 then
			connect(joint.Part0, joint.Part1, joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame))
		elseif joint:IsA("AnimationConstraint") then
			local a, b = joint.Attachment0, joint.Attachment1
			if a and b then connect(a.Parent, b.Parent, a.CFrame * rotation * b.CFrame:Inverse()) end
		end
	end
	-- Anchored preview parts do not follow motors through physics. Solve the
	-- hierarchy explicitly so blades, shields and sockets stay on their limbs.
	local seen = { [root] = true }
	local function place(part)
		for _, link in links[part] or {} do
			if not seen[link.Part] then
				seen[link.Part] = true
				link.Part.CFrame = part.CFrame * link.Offset
				place(link.Part)
			end
		end
	end
	place(root)
end

return InventoryPose
