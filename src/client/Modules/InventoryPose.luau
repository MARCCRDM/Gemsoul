--[[
	Still poses for the Inventory's miners (cloned, anchored rigs).

	The poses are the game's own fighting stances (Shared.RivalPose), bent
	the same way RivalPose bends a live rig, so the sword sits in the fist
	and the shield stands on the forearm exactly as they do in a fight:

	  Prospector   the ready stance: sword out, shield before the belly
	  Skirmisher   an aggressive lean: blade raised, weight forward
	  Juggernaut   the shield guard: shield up across the chest, sword
	               stood up at the side

	The previews are built held as a player holds them (FistGrip, see
	Equipment's MinerPreviews), which these stances are shaped for.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RivalPose = require(ReplicatedStorage.Shared.RivalPose)

local InventoryPose = {}

local READY = RivalPose.Stances.Ready
local GUARD = RivalPose.Stances.Guard

-- The ready stance pushed forward: blade high, weight on the front foot.
local LUNGE = table.clone(READY)
LUNGE.Waist = { -0.14, -0.3, 0 }
LUNGE.Neck = { 0.06, 0.18, 0 }
LUNGE.RightShoulder = { 0.95, 0.15, 0.25 }
LUNGE.RightElbow = { 1.1, 0, 0 }
LUNGE.RightHip = { 0.45, 0, 0.05 }
LUNGE.LeftHip = { -0.15, 0, -0.08 }
LUNGE.RightKnee = { -0.55, 0, 0 }
LUNGE.LeftKnee = { -0.2, 0, 0 }

-- The guard with the shield held at the chest, so the helmet still shows,
-- and the sword stood up at the side (cocked back it pointed at the camera
-- and hid behind the body).
local BRACE = table.clone(GUARD)
BRACE.LeftShoulder = { 1.85, -0.85, 1.15 }
BRACE.LeftElbow = { 0.9, 0.15, 0 }
BRACE.RightShoulder = READY.RightShoulder
BRACE.RightElbow = READY.RightElbow

local POSES = { Prospector = READY, Skirmisher = LUNGE, Juggernaut = BRACE }

-- A joint bent RivalPose's way: turned about where it sits in the parent part.
local function bent(offset: CFrame, angles): CFrame
	return CFrame.new(offset.Position) * CFrame.Angles(angles[1], angles[2], angles[3]) * offset.Rotation
end

function InventoryPose.apply(model: Model, family: string?)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local pose = POSES[family or ""] or READY
	local links = {}
	local function connect(a, b, relative)
		if not a or not b or not a:IsA("BasePart") or not b:IsA("BasePart") then
			return
		end
		links[a] = links[a] or {}
		links[b] = links[b] or {}
		table.insert(links[a], { Part = b, Offset = relative })
		table.insert(links[b], { Part = a, Offset = relative:Inverse() })
	end
	-- Snapshot every link before moving anything, welded gear included.
	for _, joint in model:GetDescendants() do
		local angles = pose[joint.Name]
		if joint:IsA("Motor6D") then
			local c0 = if angles then bent(joint.C0, angles) else joint.C0
			connect(joint.Part0, joint.Part1, c0 * joint.C1:Inverse())
		elseif joint:IsA("Weld") then
			connect(joint.Part0, joint.Part1, joint.C0 * joint.C1:Inverse())
		elseif joint:IsA("WeldConstraint") and joint.Part0 and joint.Part1 then
			connect(joint.Part0, joint.Part1, joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame))
		elseif joint:IsA("AnimationConstraint") then
			local a, b = joint.Attachment0, joint.Attachment1
			if a and b then
				local at = if angles then bent(a.CFrame, angles) else a.CFrame
				connect(a.Parent, b.Parent, at * b.CFrame:Inverse())
			end
		end
	end
	-- Anchored parts don't follow motors through physics: solve the
	-- hierarchy from the root so blades, shields and sockets stay on limbs.
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
