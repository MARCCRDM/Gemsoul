-- Attach creature silhouettes to the existing R15 combat rig. Motor6Ds,
-- RivalPose actions and locomotion remain the same as the Arena rival.
local Skins = {}
local function add(rig, anchor, name, size, offset, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = anchor.CFrame * CFrame.new(offset)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
	if shape then
		p.Shape = shape
	end
	p.Parent = rig
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = anchor, p, p
	return p
end
function Skins.apply(rig, spec, accent, boss)
	local head, torso = rig.Head, rig.UpperTorso
	local body = if spec.Shape == "Shark"
		then Color3.fromRGB(74, 119, 156)
		elseif spec.Shape == "Crocodile" then Color3.fromRGB(71, 107, 62)
		else Color3.fromRGB(120, 79, 43)
	for _, p in rig:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			p.Color = body
		end
	end
	-- Recognizable oversized face, eyes and element core; all welded to animated bones.
	add(rig, head, "CreatureHead", Vector3.new(1.65, 1.65, 1.45), Vector3.zero, body, Enum.PartType.Ball)
	for _, x in { -0.46, 0.46 } do
		add(
			rig,
			head,
			"EyeWhite",
			Vector3.new(0.4, 0.45, 0.18),
			Vector3.new(x, 0.18, -0.73),
			Color3.new(1, 1, 1),
			Enum.PartType.Ball
		)
		add(
			rig,
			head,
			"Pupil",
			Vector3.new(0.17, 0.24, 0.12),
			Vector3.new(x, 0.15, -0.84),
			Color3.fromRGB(12, 18, 23),
			Enum.PartType.Ball
		)
	end
	local core = add(rig, torso, "ElementCore", Vector3.new(0.55, 0.65, 0.15), Vector3.new(0, 0.25, -0.57), accent)
	core.Material = Enum.Material.Neon
	if spec.Shape == "Wood" then
		for _, x in { -0.7, -0.3, 0.3, 0.7 } do
			add(
				rig,
				torso,
				"BarkRidge",
				Vector3.new(0.1, 1.8, 0.14),
				Vector3.new(x, 0, -0.57),
				Color3.fromRGB(70, 42, 22)
			)
		end
		add(
			rig,
			rig.RightHand,
			"SahurBat",
			Vector3.new(0.4, 2.7, 0.4),
			Vector3.new(0, 1, -0.4),
			body,
			Enum.PartType.Cylinder
		)
	elseif spec.Shape == "Tree" then
		add(rig, head, "LongNose", Vector3.new(0.48, 0.85, 0.8), Vector3.new(0, -0.1, -0.9), body)
		for _, x in { -1, 1 } do
			add(rig, torso, "Branch", Vector3.new(0.3, 2, 0.3), Vector3.new(x * 1.1, 1.5, 0.25), body)
			add(
				rig,
				torso,
				"Canopy",
				Vector3.new(1.8, 1.3, 1.4),
				Vector3.new(x * 1.1, 2.3, 0.25),
				Color3.fromRGB(56, 125, 58),
				Enum.PartType.Ball
			)
		end
	elseif spec.Shape == "Shark" then
		add(
			rig,
			head,
			"SharkMuzzle",
			Vector3.new(1.4, 0.65, 0.9),
			Vector3.new(0, -0.45, -0.6),
			Color3.fromRGB(192, 211, 216)
		)
		add(rig, torso, "DorsalFin", Vector3.new(0.22, 1.6, 1.3), Vector3.new(0, 0.7, 0.9), body)
		for _, foot in { rig.LeftFoot, rig.RightFoot } do
			add(
				rig,
				foot,
				"Sneaker",
				Vector3.new(1.15, 0.55, 1.7),
				Vector3.new(0, 0, -0.3),
				Color3.fromRGB(55, 126, 226)
			)
			add(rig, foot, "Sole", Vector3.new(1.2, 0.16, 1.75), Vector3.new(0, -0.3, -0.3), Color3.new(1, 1, 1))
		end
	else
		add(rig, head, "CrocSnout", Vector3.new(1.35, 0.5, 1.6), Vector3.new(0, -0.3, -1), body)
		for i = -2, 2 do
			add(
				rig,
				head,
				"Tooth",
				Vector3.new(0.12, 0.2, 0.14),
				Vector3.new(i * 0.23, -0.56, -1.7),
				Color3.new(1, 1, 1)
			)
		end
		add(
			rig,
			torso,
			"BomberWings",
			Vector3.new(5.6, 0.2, 1.1),
			Vector3.new(0, 0.4, 0.75),
			Color3.fromRGB(99, 115, 101)
		)
		for _, x in { -1.8, 1.8 } do
			add(rig, torso, "Engine", Vector3.new(0.6, 0.6, 1.3), Vector3.new(x, 0.15, 0.7), accent)
		end
	end
	if boss then
		rig:ScaleTo(1.8)
	end
	rig:SetAttribute("BrainrotCharacter", spec.Id)
	rig:SetAttribute("DungeonBoss", boss)
end
return Skins
