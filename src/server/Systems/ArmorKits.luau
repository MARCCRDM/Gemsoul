--[[
	Armor designs, built from a few chunky low-poly parts welded to the avatar:
	oversized layered pauldrons, full helms and hoods that hide the face
	behind glowing eyes, gauntlets, greaves, tabards and capes.

	Every set covers the whole head. Sizes follow the avatar's own body
	parts, so it fits R15 and R6 avatars of any proportions.

	ArmorKits.build(folder, character, look, accent) builds one armor set.
	`look` comes from Classes (e.g. "Plate", "Robe"), `accent` is the class colour.
]]
local ArmorKits = {}

-- A body segment: the part to weld to, where on it, and how big it is.
type Segment = { Part: BasePart, Offset: CFrame, Size: Vector3 }
type Body = { [string]: Segment }

local STEEL = Color3.fromRGB(150, 156, 168)
local DARK_STEEL = Color3.fromRGB(70, 74, 84)
local BRASS = Color3.fromRGB(196, 152, 72)
local LEATHER = Color3.fromRGB(96, 62, 38)
local DARK_LEATHER = Color3.fromRGB(52, 36, 26)
local VOID = Color3.fromRGB(8, 8, 12)

-- Body map ---------------------------------------------------------------------------

local function segment(part: BasePart?, offset: CFrame?, size: Vector3?): Segment?
	if not part then
		return nil
	end
	return { Part = part, Offset = offset or CFrame.identity, Size = size or part.Size }
end

-- The visible head: R6 heads are a 2x1x1 part drawn by a rounder mesh.
local function headSize(head: BasePart): Vector3
	if head:FindFirstChildOfClass("SpecialMesh") then
		local s = head.Size.Y * 1.25
		return Vector3.new(s, s, s)
	end
	local s = head.Size
	return Vector3.new(math.min(s.X, s.Y * 1.3), s.Y, math.min(s.Z, s.Y * 1.3))
end

function ArmorKits.body(character: Model): Body
	local function find(name: string): BasePart?
		return character:FindFirstChild(name) :: BasePart?
	end
	local body: Body = {}
	local head = find("Head")
	if head then
		body.Head = segment(head, CFrame.identity, headSize(head)) :: Segment
	end
	if find("UpperTorso") then
		-- R15: every segment is its own part.
		local map = {
			Torso = "UpperTorso",
			Waist = "LowerTorso",
			LeftUpperArm = "LeftUpperArm",
			RightUpperArm = "RightUpperArm",
			LeftLowerArm = "LeftLowerArm",
			RightLowerArm = "RightLowerArm",
			LeftHand = "LeftHand",
			RightHand = "RightHand",
			LeftUpperLeg = "LeftUpperLeg",
			RightUpperLeg = "RightUpperLeg",
			LeftLowerLeg = "LeftLowerLeg",
			RightLowerLeg = "RightLowerLeg",
			LeftFoot = "LeftFoot",
			RightFoot = "RightFoot",
		}
		for key, name in map do
			body[key] = segment(find(name)) :: Segment
		end
	else
		-- R6: one part per limb, split into upper, lower and end.
		local torso = find("Torso")
		if torso then
			local t = torso.Size
			body.Torso = segment(torso, CFrame.new(0, t.Y * 0.2, 0), Vector3.new(t.X, t.Y * 0.6, t.Z)) :: Segment
			body.Waist = segment(torso, CFrame.new(0, -t.Y * 0.4, 0), Vector3.new(t.X, t.Y * 0.2, t.Z)) :: Segment
		end
		for _, side in { "Left", "Right" } do
			local arm, leg = find(side .. " Arm"), find(side .. " Leg")
			if arm then
				local a = arm.Size
				body[side .. "UpperArm"] =
					segment(arm, CFrame.new(0, a.Y * 0.25, 0), Vector3.new(a.X, a.Y * 0.5, a.Z)) :: Segment
				body[side .. "LowerArm"] =
					segment(arm, CFrame.new(0, -a.Y * 0.2, 0), Vector3.new(a.X, a.Y * 0.4, a.Z)) :: Segment
				body[side .. "Hand"] =
					segment(arm, CFrame.new(0, -a.Y * 0.42, 0), Vector3.new(a.X, a.Y * 0.16, a.Z)) :: Segment
			end
			if leg then
				local l = leg.Size
				body[side .. "UpperLeg"] =
					segment(leg, CFrame.new(0, l.Y * 0.25, 0), Vector3.new(l.X, l.Y * 0.5, l.Z)) :: Segment
				body[side .. "LowerLeg"] =
					segment(leg, CFrame.new(0, -l.Y * 0.2, 0), Vector3.new(l.X, l.Y * 0.4, l.Z)) :: Segment
				body[side .. "Foot"] =
					segment(leg, CFrame.new(0, -l.Y * 0.43, -0.1), Vector3.new(l.X, l.Y * 0.14, l.Z * 1.2)) :: Segment
			end
		end
	end
	return body
end

-- Primitives ------------------------------------------------------------------------------

local function make(
	folder: Instance,
	seg: Segment?,
	className: string,
	cframe: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart?
	if not seg then
		return nil
	end
	local part = Instance.new(className) :: BasePart
	part.Name = "Armor"
	part.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	-- Small trim doesn't need a shadow; it's a big share of the shadow cost.
	part.CastShadow = math.max(size.X, size.Y, size.Z) > 0.6
	part.CFrame = seg.Part.CFrame * seg.Offset * cframe
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = seg.Part
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function box(folder, seg, cframe, size, color, material)
	return make(folder, seg, "Part", cframe, size, color, material or Enum.Material.Metal)
end

-- WedgePart: full-height edge at the back (+Z), sloping down to the front.
local function wedge(folder, seg, cframe, size, color, material)
	return make(folder, seg, "WedgePart", cframe, size, color, material or Enum.Material.Metal)
end

-- Cylinder along the local X axis.
local function cylinder(folder, seg, cframe, size, color, material)
	local part = make(folder, seg, "Part", cframe, size, color, material or Enum.Material.Metal)
	if part then
		(part :: Part).Shape = Enum.PartType.Cylinder
	end
	return part
end

local function glow(folder, seg, cframe, size, color)
	local part = make(folder, seg, "Part", cframe, size, color, Enum.Material.Neon)
	if part then
		part.CastShadow = false
	end
	return part
end

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function sides(): { number }
	return { -1, 1 }
end

-- Shared pieces -------------------------------------------------------------------------

type Kit = {
	Metal: Color3,
	Trim: Color3,
	Cloth: Color3,
	Material: Enum.Material,
	Accent: Color3,
}

-- The shell every helm starts from: a box around the whole head.
local function shell(folder, head: Segment, kit: Kit, scale: Vector3, material: Enum.Material?, color: Color3?)
	local h = head.Size
	return box(folder, head, CFrame.new(0, h.Y * 0.04, 0), h * scale, color or kit.Metal, material or kit.Material)
end

-- A pair of glowing eyes (or one slit) on the front of the head.
local function eyes(folder, head: Segment, kit: Kit, depth: number, spread: number, size: Vector3)
	local h = head.Size
	for _, side in sides() do
		glow(folder, head, CFrame.new(side * h.X * spread, h.Y * 0.08, -h.Z * depth), size, kit.Accent)
	end
end

-- Sleeves or rerebraces on the upper arms, so no skin shows.
local function sleeves(folder, body: Body, color: Color3, material: Enum.Material)
	for _, side in sides() do
		local upper = body[side == -1 and "LeftUpperArm" or "RightUpperArm"]
		if upper then
			box(
				folder,
				upper,
				CFrame.new(0, -upper.Size.Y * 0.05, 0),
				upper.Size * Vector3.new(1.16, 0.95, 1.16),
				color,
				material
			)
		end
	end
end

-- Cuisses or trousers on the upper legs.
local function legs(folder, body: Body, color: Color3, material: Enum.Material)
	for _, side in sides() do
		local upper = body[side == -1 and "LeftUpperLeg" or "RightUpperLeg"]
		if upper then
			box(folder, upper, CFrame.identity, upper.Size * Vector3.new(1.14, 1.02, 1.14), color, material)
		end
	end
end

local function gauntlets(folder, body: Body, kit: Kit, heavy: boolean)
	sleeves(
		folder,
		body,
		if heavy then kit.Trim else darken(kit.Metal, 0.2),
		if heavy then kit.Material else Enum.Material.Leather
	)
	for _, side in sides() do
		local hand, lower =
			body[side == -1 and "LeftHand" or "RightHand"], body[side == -1 and "LeftLowerArm" or "RightLowerArm"]
		if hand then
			box(
				folder,
				hand,
				CFrame.new(0, 0.02, 0),
				hand.Size * Vector3.new(1.3, 1.5, 1.3),
				if heavy then kit.Metal else kit.Trim,
				if heavy then kit.Material else Enum.Material.Leather
			)
		end
		if lower then
			local l = lower.Size
			local cuff = if heavy then 1.38 else 1.24
			box(
				folder,
				lower,
				CFrame.new(0, -l.Y * 0.02, 0),
				Vector3.new(l.X * cuff, l.Y * 0.98, l.Z * cuff),
				if heavy then kit.Metal else kit.Trim,
				if heavy then kit.Material else Enum.Material.Leather
			)
			if heavy then
				glow(
					folder,
					lower,
					CFrame.new(0, l.Y * 0.13, 0),
					Vector3.new(l.X * cuff + 0.02, 0.06, l.Z * cuff + 0.02),
					kit.Accent
				)
			end
		end
	end
end

local function boots(folder, body: Body, kit: Kit, heavy: boolean)
	legs(
		folder,
		body,
		if heavy then kit.Trim else darken(kit.Trim, 0.1),
		if heavy then kit.Material else Enum.Material.Leather
	)
	for _, side in sides() do
		local lower = body[side == -1 and "LeftLowerLeg" or "RightLowerLeg"]
		local foot = body[side == -1 and "LeftFoot" or "RightFoot"]
		if lower then
			local l = lower.Size
			local wide = if heavy then 1.3 else 1.16
			box(
				folder,
				lower,
				CFrame.new(0, -l.Y * 0.05, 0),
				Vector3.new(l.X * wide, l.Y * 0.95, l.Z * wide),
				if heavy then kit.Metal else kit.Trim,
				if heavy then kit.Material else Enum.Material.Leather
			)
			if heavy then
				-- Knee guard.
				wedge(
					folder,
					lower,
					CFrame.new(0, l.Y * 0.45, -l.Z * 0.62) * CFrame.Angles(0, math.pi, 0),
					Vector3.new(l.X * 0.9, l.Y * 0.4, l.Z * 0.35),
					kit.Metal,
					kit.Material
				)
			end
		end
		if foot then
			local f = foot.Size
			box(
				folder,
				foot,
				CFrame.new(0, 0.02, -f.Z * 0.05),
				f * Vector3.new(1.25, 1.4, 1.25),
				darken(kit.Trim, 0.2),
				Enum.Material.Leather
			)
		end
	end
end

local function belt(folder, body: Body, kit: Kit)
	local waist = body.Waist
	if not waist then
		return
	end
	local w = waist.Size
	box(
		folder,
		waist,
		CFrame.new(0, w.Y * 0.2, 0),
		Vector3.new(w.X * 1.14, math.max(w.Y * 0.8, 0.3), w.Z * 1.34),
		DARK_LEATHER,
		Enum.Material.Leather
	)
	box(folder, waist, CFrame.new(0, w.Y * 0.2, -w.Z * 0.68), Vector3.new(0.5, 0.4, 0.08), BRASS, Enum.Material.Metal)
	glow(
		folder,
		waist,
		CFrame.new(0, w.Y * 0.2, -w.Z * 0.73) * CFrame.Angles(0, 0, math.rad(45)),
		Vector3.new(0.18, 0.18, 0.04),
		kit.Accent
	)
end

-- Plates hanging from the belt over the hips.
local function faulds(folder, body: Body, kit: Kit)
	local waist = body.Waist
	if not waist then
		return
	end
	local w = waist.Size
	for _, x in { -0.34, 0, 0.34 } do
		box(
			folder,
			waist,
			CFrame.new(w.X * x, -w.Y * 0.5 - 0.35, -w.Z * 0.6) * CFrame.Angles(math.rad(-8), 0, 0),
			Vector3.new(w.X * 0.32, 0.8, 0.1),
			kit.Metal,
			kit.Material
		)
	end
	for _, side in sides() do
		box(
			folder,
			waist,
			CFrame.new(side * w.X * 0.6, -w.Y * 0.5 - 0.3, 0) * CFrame.Angles(0, 0, math.rad(side * 10)),
			Vector3.new(0.1, 0.7, w.Z * 1.1),
			kit.Metal,
			kit.Material
		)
	end
end

-- Cloth panel down the front, with a glowing emblem.
local function tabard(folder, body: Body, kit: Kit, length: number)
	local waist = body.Waist
	if not waist then
		return
	end
	local w = waist.Size
	box(
		folder,
		waist,
		CFrame.new(0, -length / 2, -w.Z * 0.7),
		Vector3.new(w.X * 0.5, length, 0.06),
		kit.Cloth,
		Enum.Material.Fabric
	)
	glow(
		folder,
		waist,
		CFrame.new(0, -0.5, -w.Z * 0.74) * CFrame.Angles(0, 0, math.rad(45)),
		Vector3.new(0.3, 0.3, 0.02),
		kit.Accent
	)
end

local function cape(folder, body: Body, kit: Kit, length: number)
	local torso = body.Torso
	if not torso then
		return
	end
	local t = torso.Size
	local top = CFrame.new(0, t.Y * 0.45, t.Z * 0.62)
	box(
		folder,
		torso,
		top * CFrame.Angles(math.rad(8), 0, 0) * CFrame.new(0, -length / 2, 0),
		Vector3.new(t.X * 0.95, length, 0.08),
		kit.Cloth,
		Enum.Material.Fabric
	)
	glow(folder, torso, top * CFrame.new(0, 0.05, 0), Vector3.new(t.X * 0.96, 0.08, 0.1), kit.Accent)
end

-- Breastplate with an angled keel and a glowing seam.
local function breastplate(folder, body: Body, kit: Kit, bulk: number)
	local torso = body.Torso
	if not torso then
		return
	end
	local t = torso.Size
	box(
		folder,
		torso,
		CFrame.new(0, t.Y * 0.04, 0),
		Vector3.new(t.X * (1.06 + bulk * 0.06), t.Y * 0.98, t.Z * (1.22 + bulk * 0.12)),
		kit.Metal,
		kit.Material
	)
	for _, side in sides() do
		-- Chest plates angled outward from the centre keel.
		box(
			folder,
			torso,
			CFrame.new(side * t.X * 0.24, t.Y * 0.16, -t.Z * (0.66 + bulk * 0.06))
				* CFrame.Angles(0, math.rad(side * -14), 0),
			Vector3.new(t.X * 0.5, t.Y * 0.5, 0.14),
			kit.Metal,
			kit.Material
		)
	end
	box(
		folder,
		torso,
		CFrame.new(0, t.Y * 0.16, -t.Z * (0.74 + bulk * 0.06)),
		Vector3.new(0.14, t.Y * 0.55, 0.14),
		BRASS,
		Enum.Material.Metal
	)
	glow(
		folder,
		torso,
		CFrame.new(0, -t.Y * 0.22, -t.Z * (0.66 + bulk * 0.06)),
		Vector3.new(t.X * 0.7, 0.07, 0.06),
		kit.Accent
	)
	-- Gorget: a raised collar that hides the neck.
	box(folder, torso, CFrame.new(0, t.Y * 0.52, 0), Vector3.new(t.X * 0.62, 0.28, t.Z * 1.05), kit.Metal, kit.Material)
end

-- Pauldrons ----------------------------------------------------------------------------------

type PauldronStyle = "Layered" | "Spiked" | "Dome" | "Slab" | "Leather"

local function pauldron(folder, body: Body, kit: Kit, side: number, style: PauldronStyle, scale: number)
	local arm = body[side == -1 and "LeftUpperArm" or "RightUpperArm"]
	if not arm then
		return
	end
	local a = arm.Size
	local w = a.X * scale
	local top = CFrame.new(side * a.X * 0.12, a.Y * 0.5, 0)
	if style == "Dome" then
		-- A great rounded shoulder with a glowing rim just inside each face.
		local dome = top * CFrame.new(0, -0.05, 0) * CFrame.Angles(0, math.rad(90), 0)
		cylinder(folder, arm, dome, Vector3.new(a.Z * 1.5, w * 0.9, w * 0.9), kit.Metal, kit.Material)
		for _, face in sides() do
			-- A thin neon disc just wider than the dome reads as a glowing ring.
			local rim = cylinder(
				folder,
				arm,
				dome * CFrame.new(face * (a.Z * 0.75 - 0.08), 0, 0),
				Vector3.new(0.06, w * 0.98, w * 0.98),
				kit.Accent,
				Enum.Material.Neon
			)
			if rim then
				rim.CastShadow = false
			end
		end
		box(
			folder,
			arm,
			top * CFrame.new(side * w * 0.2, -w * 0.45, 0) * CFrame.Angles(0, 0, math.rad(side * 18)),
			Vector3.new(w * 0.9, 0.18, a.Z * 1.45),
			kit.Trim,
			kit.Material
		)
	elseif style == "Leather" then
		box(
			folder,
			arm,
			top * CFrame.Angles(0, 0, math.rad(side * 18)),
			Vector3.new(w, 0.3, a.Z * 1.35),
			LEATHER,
			Enum.Material.Leather
		)
		box(
			folder,
			arm,
			top * CFrame.new(side * 0.08, -0.25, 0) * CFrame.Angles(0, 0, math.rad(side * 26)),
			Vector3.new(w * 0.85, 0.22, a.Z * 1.2),
			DARK_LEATHER,
			Enum.Material.Leather
		)
	elseif style == "Slab" then
		box(folder, arm, top * CFrame.new(0, 0.1, 0), Vector3.new(w, 0.55, a.Z * 1.55), kit.Metal, kit.Material)
		box(folder, arm, top * CFrame.new(0, 0.42, 0), Vector3.new(w * 0.7, 0.18, a.Z * 1.25), kit.Trim, kit.Material)
		glow(folder, arm, top * CFrame.new(0, -0.18, 0), Vector3.new(w + 0.02, 0.07, a.Z * 1.57), kit.Accent)
	else
		-- A thick shoulder plate with two lames stepping down beneath it.
		box(folder, arm, top * CFrame.new(0, 0.08, 0), Vector3.new(w, 0.5, a.Z * 1.5), kit.Metal, kit.Material)
		for i, step in { 0.92, 0.8 } do
			box(
				folder,
				arm,
				top * CFrame.new(side * i * 0.06, -i * 0.3, 0) * CFrame.Angles(0, 0, math.rad(side * (6 + i * 5))),
				Vector3.new(w * step, 0.22, a.Z * (1.44 - i * 0.08)),
				kit.Trim,
				kit.Material
			)
		end
		box(
			folder,
			arm,
			top * CFrame.new(0, 0.36, 0),
			Vector3.new(w * 0.8, 0.12, a.Z * 1.3),
			BRASS,
			Enum.Material.Metal
		)
		glow(folder, arm, top * CFrame.new(0, -0.14, 0), Vector3.new(w * 1.01, 0.06, a.Z * 1.52), kit.Accent)
		if style == "Spiked" then
			wedge(
				folder,
				arm,
				top * CFrame.new(side * w * 0.1, 0.6, 0) * CFrame.Angles(0, math.rad(side * 90), 0),
				Vector3.new(0.3, 0.7, 0.5),
				BRASS,
				Enum.Material.Metal
			)
		end
	end
end

local function pauldrons(folder, body: Body, kit: Kit, style: PauldronStyle, scale: number)
	for _, side in sides() do
		pauldron(folder, body, kit, side, style, scale)
	end
end

-- Helms and hoods ---------------------------------------------------------------------------

-- Great helm: full shell, a T-shaped glowing visor and a crest.
-- A heavy brow over the eyes gives metal helms a sculpted, scowling look.
local function brow(folder, head: Segment, kit: Kit)
	local h = head.Size
	wedge(
		folder,
		head,
		CFrame.new(0, h.Y * 0.36, -h.Z * 0.66),
		Vector3.new(h.X * 1.12, h.Y * 0.22, 0.24),
		kit.Trim,
		kit.Material
	)
end

local function greatHelm(folder, head: Segment, kit: Kit, crest: boolean)
	local h = head.Size
	shell(folder, head, kit, Vector3.new(1.16, 1.14, 1.18))
	brow(folder, head, kit)
	box(
		folder,
		head,
		CFrame.new(0, -h.Y * 0.05, -h.Z * 0.6),
		Vector3.new(h.X * 0.9, h.Y * 0.95, 0.12),
		kit.Metal,
		kit.Material
	)
	glow(folder, head, CFrame.new(0, h.Y * 0.12, -h.Z * 0.67), Vector3.new(h.X * 0.72, 0.09, 0.04), kit.Accent)
	glow(folder, head, CFrame.new(0, -h.Y * 0.1, -h.Z * 0.67), Vector3.new(0.09, h.Y * 0.42, 0.04), kit.Accent)
	box(
		folder,
		head,
		CFrame.new(0, -h.Y * 0.05, -h.Z * 0.68),
		Vector3.new(0.08, h.Y * 0.9, 0.08),
		BRASS,
		Enum.Material.Metal
	)
	if crest then
		wedge(
			folder,
			head,
			CFrame.new(0, h.Y * 0.72, 0.05),
			Vector3.new(0.18, h.Y * 0.45, h.Z * 1.2),
			kit.Cloth,
			Enum.Material.Fabric
		)
	end
end

local function hornedHelm(folder, head: Segment, kit: Kit)
	local h = head.Size
	shell(folder, head, kit, Vector3.new(1.16, 1.14, 1.18))
	brow(folder, head, kit)
	eyes(folder, head, kit, 0.6, 0.22, Vector3.new(h.X * 0.22, 0.08, 0.04))
	wedge(
		folder,
		head,
		CFrame.new(0, -h.Y * 0.2, -h.Z * 0.62) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(h.X * 0.5, h.Y * 0.5, 0.25),
		kit.Metal,
		kit.Material
	)
	for _, side in sides() do
		local base = CFrame.new(side * h.X * 0.6, h.Y * 0.35, 0)
		box(
			folder,
			head,
			base * CFrame.Angles(0, 0, math.rad(side * -30)),
			Vector3.new(0.5, 0.26, 0.26),
			BRASS,
			Enum.Material.Metal
		)
		wedge(
			folder,
			head,
			base * CFrame.new(side * 0.35, 0.35, 0) * CFrame.Angles(0, math.rad(side * -90), math.rad(side * -20)),
			Vector3.new(0.24, 0.8, 0.26),
			Color3.fromRGB(226, 214, 190),
			Enum.Material.SmoothPlastic
		)
	end
end

-- Chain hood with an iron mask.
local function coifMask(folder, head: Segment, kit: Kit)
	local h = head.Size
	shell(folder, head, kit, Vector3.new(1.18, 1.16, 1.2), Enum.Material.CorrodedMetal, Color3.fromRGB(120, 124, 130))
	box(
		folder,
		head,
		CFrame.new(0, -h.Y * 0.02, -h.Z * 0.61),
		Vector3.new(h.X * 0.84, h.Y * 0.78, 0.14),
		DARK_STEEL,
		Enum.Material.Metal
	)
	eyes(folder, head, kit, 0.69, 0.2, Vector3.new(h.X * 0.2, 0.08, 0.04))
end

-- Tall bucket helm with a cross visor, domed top and plume.
local function bucketHelm(folder, head: Segment, kit: Kit)
	local h = head.Size
	box(folder, head, CFrame.new(0, h.Y * 0.1, 0), h * Vector3.new(1.2, 1.3, 1.22), kit.Metal, kit.Material)
	glow(folder, head, CFrame.new(0, h.Y * 0.12, -h.Z * 0.62), Vector3.new(h.X * 0.8, 0.1, 0.04), kit.Accent)
	glow(folder, head, CFrame.new(0, -h.Y * 0.08, -h.Z * 0.62), Vector3.new(0.1, h.Y * 0.5, 0.04), kit.Accent)
	cylinder(
		folder,
		head,
		CFrame.new(0, h.Y * 0.78, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.18, h.X * 1.1, h.Z * 1.1),
		kit.Trim,
		kit.Material
	)
	wedge(
		folder,
		head,
		CFrame.new(0, h.Y * 1.02, 0.2),
		Vector3.new(0.2, h.Y * 0.5, h.Z * 1.1),
		kit.Cloth,
		Enum.Material.Fabric
	)
end

-- Fortress helm with a jutting, angled beak.
local function monolithHelm(folder, head: Segment, kit: Kit)
	local h = head.Size
	box(folder, head, CFrame.new(0, h.Y * 0.08, 0.02), h * Vector3.new(1.26, 1.26, 1.24), kit.Metal, kit.Material)
	for _, side in sides() do
		wedge(
			folder,
			head,
			CFrame.new(side * h.X * 0.22, -h.Y * 0.08, -h.Z * 0.72) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(h.X * 0.44, h.Y * 0.7, 0.3),
			kit.Trim,
			kit.Material
		)
	end
	glow(folder, head, CFrame.new(0, h.Y * 0.22, -h.Z * 0.64), Vector3.new(h.X * 0.9, 0.08, 0.04), kit.Accent)
	box(folder, head, CFrame.new(0, h.Y * 0.72, 0), Vector3.new(h.X * 0.3, 0.3, h.Z * 1.26), BRASS, Enum.Material.Metal)
end

-- Sleek knight helm with a swept-back crest.
local function knightHelm(folder, head: Segment, kit: Kit)
	local h = head.Size
	shell(folder, head, kit, Vector3.new(1.14, 1.12, 1.16))
	brow(folder, head, kit)
	wedge(
		folder,
		head,
		CFrame.new(0, -h.Y * 0.05, -h.Z * 0.66) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(h.X * 0.9, h.Y * 0.7, 0.3),
		kit.Metal,
		kit.Material
	)
	eyes(folder, head, kit, 0.64, 0.2, Vector3.new(h.X * 0.24, 0.07, 0.04))
	wedge(
		folder,
		head,
		CFrame.new(0, h.Y * 0.62, h.Z * 0.2) * CFrame.Angles(math.rad(-20), 0, 0),
		Vector3.new(0.14, h.Y * 0.5, h.Z * 1.3),
		kit.Accent,
		Enum.Material.Metal
	)
end

-- Deep hood over a dark void where the face should be, with glowing eyes.
local function hood(folder, head: Segment, kit: Kit, peaked: boolean, color: Color3?)
	local h = head.Size
	local cloth = color or kit.Cloth
	box(
		folder,
		head,
		CFrame.new(0, h.Y * 0.1, h.Z * 0.06),
		h * Vector3.new(1.26, 1.24, 1.2),
		cloth,
		Enum.Material.Fabric
	)
	box(
		folder,
		head,
		CFrame.new(0, -h.Y * 0.02, -h.Z * 0.56),
		Vector3.new(h.X * 0.84, h.Y * 0.84, 0.06),
		VOID,
		Enum.Material.SmoothPlastic
	)
	-- Hood rim framing the face.
	box(
		folder,
		head,
		CFrame.new(0, h.Y * 0.47, -h.Z * 0.6),
		Vector3.new(h.X * 1.1, 0.16, 0.14),
		darken(cloth, 0.25),
		Enum.Material.Fabric
	)
	if peaked then
		wedge(
			folder,
			head,
			CFrame.new(0, h.Y * 0.95, h.Z * 0.25),
			Vector3.new(h.X * 1.0, h.Y * 0.7, h.Z * 0.95),
			cloth,
			Enum.Material.Fabric
		)
	end
end

local function scarfMask(folder, head: Segment, _kit: Kit, color: Color3)
	local h = head.Size
	box(
		folder,
		head,
		CFrame.new(0, -h.Y * 0.28, -h.Z * 0.56),
		Vector3.new(h.X * 1.02, h.Y * 0.44, h.Z * 0.2),
		color,
		Enum.Material.Fabric
	)
end

-- Kits ------------------------------------------------------------------------------------

local BUILDERS: { [string]: (Instance, Body, Kit) -> () } = {}

-- Warrior -------------------------------------------------------------------------------

BUILDERS.Plate = function(folder, body, kit)
	if body.Head then
		greatHelm(folder, body.Head, kit, true)
	end
	breastplate(folder, body, kit, 1)
	pauldrons(folder, body, kit, "Layered", 1.9)
	faulds(folder, body, kit)
	tabard(folder, body, kit, 1.6)
	cape(folder, body, kit, 3.2)
	gauntlets(folder, body, kit, true)
	boots(folder, body, kit, true)
end

BUILDERS.Scale = function(folder, body, kit)
	if body.Head then
		hornedHelm(folder, body.Head, kit)
	end
	breastplate(folder, body, kit, 0.5)
	pauldrons(folder, body, kit, "Spiked", 1.75)
	faulds(folder, body, kit)
	tabard(folder, body, kit, 1.4)
	gauntlets(folder, body, kit, true)
	boots(folder, body, kit, true)
end

BUILDERS.Chain = function(folder, body, kit)
	if body.Head then
		coifMask(folder, body.Head, kit)
	end
	breastplate(folder, body, kit, 0)
	-- One heavy pauldron on the weapon arm, leather on the other.
	pauldron(folder, body, kit, 1, "Layered", 1.8)
	pauldron(folder, body, kit, -1, "Leather", 1.4)
	tabard(folder, body, kit, 1.3)
	gauntlets(folder, body, kit, false)
	boots(folder, body, kit, false)
end

-- Tank -----------------------------------------------------------------------------------

BUILDERS.Bulwark = function(folder, body, kit)
	if body.Head then
		bucketHelm(folder, body.Head, kit)
	end
	breastplate(folder, body, kit, 2)
	pauldrons(folder, body, kit, "Dome", 1.9)
	faulds(folder, body, kit)
	tabard(folder, body, kit, 1.7)
	cape(folder, body, kit, 3.4)
	gauntlets(folder, body, kit, true)
	boots(folder, body, kit, true)
end

BUILDERS.TowerPlate = function(folder, body, kit)
	if body.Head then
		monolithHelm(folder, body.Head, kit)
	end
	breastplate(folder, body, kit, 2.5)
	pauldrons(folder, body, kit, "Slab", 2.2)
	faulds(folder, body, kit)
	cape(folder, body, kit, 3.4)
	gauntlets(folder, body, kit, true)
	boots(folder, body, kit, true)
end

BUILDERS.Vanguard = function(folder, body, kit)
	if body.Head then
		knightHelm(folder, body.Head, kit)
	end
	breastplate(folder, body, kit, 1)
	pauldrons(folder, body, kit, "Layered", 1.6)
	faulds(folder, body, kit)
	tabard(folder, body, kit, 1.5)
	gauntlets(folder, body, kit, true)
	boots(folder, body, kit, true)
end

-- Wizard ----------------------------------------------------------------------------------

local function robe(folder, body: Body, kit: Kit, skirt: number)
	sleeves(folder, body, kit.Cloth, Enum.Material.Fabric)
	local torso, waist = body.Torso, body.Waist
	if torso then
		local t = torso.Size
		box(
			folder,
			torso,
			CFrame.new(0, t.Y * 0.02, 0),
			Vector3.new(t.X * 1.08, t.Y * 0.98, t.Z * 1.2),
			kit.Cloth,
			Enum.Material.Fabric
		)
		-- High collar and a shoulder mantle.
		box(
			folder,
			torso,
			CFrame.new(0, t.Y * 0.56, 0.05),
			Vector3.new(t.X * 0.8, 0.5, t.Z * 1.15),
			darken(kit.Cloth, 0.2),
			Enum.Material.Fabric
		)
		box(
			folder,
			torso,
			CFrame.new(0, t.Y * 0.4, 0),
			Vector3.new(t.X * 1.5, 0.22, t.Z * 1.35),
			darken(kit.Cloth, 0.3),
			Enum.Material.Fabric
		)
		glow(folder, torso, CFrame.new(0, t.Y * 0.4, -t.Z * 0.69), Vector3.new(t.X * 1.2, 0.05, 0.04), kit.Accent)
		glow(folder, torso, CFrame.new(0, -t.Y * 0.05, -t.Z * 0.61), Vector3.new(0.1, t.Y * 0.8, 0.04), kit.Accent)
	end
	if waist and skirt > 0 then
		local w = waist.Size
		box(
			folder,
			waist,
			CFrame.new(0, -skirt / 2 + 0.1, 0),
			Vector3.new(w.X * 1.18, skirt, w.Z * 1.4),
			kit.Cloth,
			Enum.Material.Fabric
		)
		glow(folder, waist, CFrame.new(0, -skirt + 0.14, 0), Vector3.new(w.X * 1.2, 0.07, w.Z * 1.42), kit.Accent)
	end
	belt(folder, body, kit)
	for _, side in sides() do
		local lower = body[side == -1 and "LeftLowerArm" or "RightLowerArm"]
		if lower then
			-- Wide sleeves.
			box(
				folder,
				lower,
				CFrame.new(0, -lower.Size.Y * 0.2, 0),
				lower.Size * Vector3.new(1.45, 0.8, 1.45),
				darken(kit.Cloth, 0.15),
				Enum.Material.Fabric
			)
		end
	end
	boots(folder, body, kit, false)
end

BUILDERS.Robe = function(folder, body, kit)
	if body.Head then
		hood(folder, body.Head, kit, true)
		eyes(folder, body.Head, kit, 0.6, 0.2, Vector3.new(0.14, 0.1, 0.04))
	end
	robe(folder, body, kit, 2.4)
end

BUILDERS.WardedRobe = function(folder, body, kit)
	local head = body.Head
	if head then
		local h = head.Size
		hood(folder, head, kit, false)
		-- Metal rune mask and a halo of floating runes.
		box(
			folder,
			head,
			CFrame.new(0, -h.Y * 0.02, -h.Z * 0.6),
			Vector3.new(h.X * 0.78, h.Y * 0.8, 0.1),
			BRASS,
			Enum.Material.Metal
		)
		eyes(folder, head, kit, 0.66, 0.18, Vector3.new(0.18, 0.06, 0.04))
		glow(folder, head, CFrame.new(0, -h.Y * 0.2, -h.Z * 0.66), Vector3.new(0.08, 0.3, 0.04), kit.Accent)
		for i = 0, 5 do
			local angle = i / 6 * 2 * math.pi
			glow(
				folder,
				head,
				CFrame.new(0, h.Y * 0.95, 0)
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(0, 0, -h.X * 0.75)
					* CFrame.Angles(0, 0, math.rad(45)),
				Vector3.new(0.16, 0.16, 0.04),
				kit.Accent
			)
		end
	end
	robe(folder, body, kit, 2.6)
	local torso = body.Torso
	if torso then
		for _, y in { 0.15, -0.2 } do
			glow(
				folder,
				torso,
				CFrame.new(0, torso.Size.Y * y, -torso.Size.Z * 0.61),
				Vector3.new(torso.Size.X * 0.9, 0.05, 0.04),
				kit.Accent
			)
		end
	end
end

BUILDERS.Wraps = function(folder, body, kit)
	local head = body.Head
	if head then
		local h = head.Size
		hood(folder, head, kit, false, Color3.fromRGB(196, 190, 210))
		scarfMask(folder, head, kit, Color3.fromRGB(150, 140, 180))
		glow(folder, head, CFrame.new(0, h.Y * 0.1, -h.Z * 0.6), Vector3.new(h.X * 0.62, 0.07, 0.04), kit.Accent)
	end
	robe(folder, body, kit, 1.1)
	local torso = body.Torso
	if torso then
		-- A long scarf trailing down the back.
		box(
			folder,
			torso,
			CFrame.new(torso.Size.X * 0.2, -0.2, torso.Size.Z * 0.66) * CFrame.Angles(math.rad(10), 0, math.rad(-6)),
			Vector3.new(0.4, 2.4, 0.06),
			Color3.fromRGB(150, 140, 180),
			Enum.Material.Fabric
		)
	end
end

-- Archer ---------------------------------------------------------------------------------

local function leatherBody(folder, body: Body, kit: Kit)
	local torso = body.Torso
	if torso then
		local t = torso.Size
		box(
			folder,
			torso,
			CFrame.new(0, t.Y * 0.03, 0),
			Vector3.new(t.X * 1.08, t.Y * 0.98, t.Z * 1.2),
			kit.Metal,
			Enum.Material.Leather
		)
		-- Cross strap for the quiver, and a short cowl.
		box(
			folder,
			torso,
			CFrame.new(0, 0, -t.Z * 0.62) * CFrame.Angles(0, 0, math.rad(40)),
			Vector3.new(0.22, t.Y * 1.25, 0.06),
			DARK_LEATHER,
			Enum.Material.Leather
		)
		box(
			folder,
			torso,
			CFrame.new(0, t.Y * 0.45, 0.05),
			Vector3.new(t.X * 1.2, 0.3, t.Z * 1.3),
			kit.Cloth,
			Enum.Material.Fabric
		)
		glow(folder, torso, CFrame.new(-t.X * 0.25, t.Y * 0.2, -t.Z * 0.62), Vector3.new(0.14, 0.14, 0.04), kit.Accent)
		-- Quiver on the back with glowing fletching.
		local quiver = CFrame.new(t.X * 0.2, t.Y * 0.1, t.Z * 0.75) * CFrame.Angles(0, 0, math.rad(-20))
		cylinder(
			folder,
			torso,
			quiver * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(1.8, 0.55, 0.55),
			LEATHER,
			Enum.Material.Leather
		)
		for i = -1, 1 do
			box(
				folder,
				torso,
				quiver * CFrame.new(i * 0.12, 1.05, 0),
				Vector3.new(0.05, 0.5, 0.05),
				Color3.fromRGB(120, 90, 60),
				Enum.Material.Wood
			)
			glow(folder, torso, quiver * CFrame.new(i * 0.12, 1.3, 0), Vector3.new(0.12, 0.18, 0.04), kit.Accent)
		end
	end
	belt(folder, body, kit)
	gauntlets(folder, body, kit, false)
	boots(folder, body, kit, false)
end

BUILDERS.Leather = function(folder, body, kit)
	if body.Head then
		hood(folder, body.Head, kit, false)
		scarfMask(folder, body.Head, kit, darken(kit.Cloth, 0.3))
		eyes(folder, body.Head, kit, 0.6, 0.2, Vector3.new(0.18, 0.07, 0.04))
	end
	leatherBody(folder, body, kit)
	pauldron(folder, body, kit, -1, "Leather", 1.6)
end

BUILDERS.StuddedLeather = function(folder, body, kit)
	local head = body.Head
	if head then
		local h = head.Size
		hood(folder, head, kit, false)
		box(
			folder,
			head,
			CFrame.new(0, -h.Y * 0.22, -h.Z * 0.6),
			Vector3.new(h.X * 0.9, h.Y * 0.5, 0.12),
			LEATHER,
			Enum.Material.Leather
		)
		for _, x in { -0.25, 0, 0.25 } do
			box(
				folder,
				head,
				CFrame.new(h.X * x, -h.Y * 0.22, -h.Z * 0.67),
				Vector3.new(0.1, 0.1, 0.06),
				STEEL,
				Enum.Material.Metal
			)
		end
		eyes(folder, head, kit, 0.6, 0.2, Vector3.new(0.18, 0.07, 0.04))
	end
	leatherBody(folder, body, kit)
	pauldrons(folder, body, kit, "Leather", 1.5)
end

BUILDERS.ShadowLeather = function(folder, body, kit)
	local head = body.Head
	if head then
		local h = head.Size
		hood(folder, head, kit, true, Color3.fromRGB(30, 30, 38))
		scarfMask(folder, head, kit, Color3.fromRGB(18, 18, 24))
		glow(folder, head, CFrame.new(0, h.Y * 0.1, -h.Z * 0.6), Vector3.new(h.X * 0.55, 0.05, 0.04), kit.Accent)
	end
	leatherBody(folder, body, kit)
	local waist = body.Waist
	if waist then
		-- Long coat tails behind the legs.
		for _, side in sides() do
			box(
				folder,
				waist,
				CFrame.new(side * waist.Size.X * 0.25, -1.1, waist.Size.Z * 0.55) * CFrame.Angles(math.rad(6), 0, 0),
				Vector3.new(waist.Size.X * 0.46, 2.2, 0.08),
				Color3.fromRGB(30, 30, 38),
				Enum.Material.Fabric
			)
		end
	end
end

-- Colours for each look: metal, trim, cloth and the material the metal uses.
local KITS: { [string]: { Metal: Color3, Trim: Color3, Cloth: Color3?, Material: Enum.Material } } = {
	Plate = { Metal = STEEL, Trim = DARK_STEEL, Material = Enum.Material.Metal },
	Scale = { Metal = Color3.fromRGB(128, 134, 144), Trim = DARK_STEEL, Material = Enum.Material.DiamondPlate },
	Chain = { Metal = Color3.fromRGB(116, 120, 128), Trim = LEATHER, Material = Enum.Material.CorrodedMetal },
	Bulwark = { Metal = Color3.fromRGB(120, 130, 150), Trim = DARK_STEEL, Material = Enum.Material.Metal },
	TowerPlate = { Metal = Color3.fromRGB(88, 94, 108), Trim = DARK_STEEL, Material = Enum.Material.Metal },
	Vanguard = { Metal = Color3.fromRGB(188, 194, 206), Trim = DARK_STEEL, Material = Enum.Material.Metal },
	Robe = { Metal = BRASS, Trim = DARK_LEATHER, Cloth = Color3.fromRGB(64, 40, 110), Material = Enum.Material.Metal },
	WardedRobe = {
		Metal = BRASS,
		Trim = DARK_LEATHER,
		Cloth = Color3.fromRGB(34, 28, 70),
		Material = Enum.Material.Metal,
	},
	Wraps = {
		Metal = BRASS,
		Trim = DARK_LEATHER,
		Cloth = Color3.fromRGB(200, 196, 214),
		Material = Enum.Material.Metal,
	},
	Leather = {
		Metal = LEATHER,
		Trim = DARK_LEATHER,
		Cloth = Color3.fromRGB(46, 70, 44),
		Material = Enum.Material.Leather,
	},
	StuddedLeather = {
		Metal = Color3.fromRGB(84, 56, 36),
		Trim = DARK_LEATHER,
		Cloth = Color3.fromRGB(60, 50, 40),
		Material = Enum.Material.Leather,
	},
	ShadowLeather = {
		Metal = Color3.fromRGB(40, 40, 48),
		Trim = Color3.fromRGB(24, 24, 30),
		Cloth = Color3.fromRGB(30, 30, 38),
		Material = Enum.Material.Leather,
	},
}

-- Better-made gear looks it: Fine is polished, Superior is mithril
-- blue-silver, Masterwork is blackened steel with gold trim.
local GOLD = Color3.fromRGB(214, 172, 72)
function ArmorKits.tint(color: Color3, quality: number?, isTrim: boolean?): Color3
	local q = quality or 1
	if q == 2 then
		return color:Lerp(Color3.new(1, 1, 1), 0.15)
	elseif q == 3 then
		return color:Lerp(Color3.fromRGB(175, 212, 240), 0.45)
	elseif q >= 4 then
		return if isTrim then GOLD else color:Lerp(Color3.fromRGB(38, 36, 46), 0.6)
	end
	return color
end

function ArmorKits.build(folder: Instance, character: Model, look: string, accent: Color3, quality: number?)
	local palette = KITS[look] or KITS.Plate
	local kit: Kit = {
		Metal = ArmorKits.tint(palette.Metal, quality),
		Trim = ArmorKits.tint(palette.Trim, quality, true),
		-- Tabards and capes are the class colour, deepened like dyed cloth.
		Cloth = palette.Cloth or darken(accent, 0.45),
		Material = palette.Material,
		Accent = accent,
	}
	local build = BUILDERS[look] or BUILDERS.Plate
	build(folder, ArmorKits.body(character), kit)
end

ArmorKits.Looks = KITS

return ArmorKits
