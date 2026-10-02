local colorMt = { __index = {
	Lerp = function(self, other, amount)
 return setmetatable({R=self.R*(1-amount)+other.R*amount,G=self.G*(1-amount)+other.G*amount,B=self.B*(1-amount)+other.B*amount,kind="Color3"},getmetatable(self))
 end,
} }
local Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r, G = g, B = b, kind = "Color3" }, colorMt)
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
local vmt = {}
local Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, vmt)
	end,
}
vmt.__mul = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

local cmt = {}
local CFrame = {}
function CFrame.new(x,y,z)
 return setmetatable({t={x or 0,y or 0,z or 0},r={1,0,0,0,1,0,0,0,1}},cmt)
end
function CFrame.Angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local a=CFrame.new(); a.r={cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy}; return a
end
cmt.__mul=function(a,b)
 local c=CFrame.new()
 for i=1,3 do
  c.t[i]=a.t[i]
  for k=1,3 do c.t[i]+=a.r[(i-1)*3+k]*b.t[k] end
  for j=1,3 do
   local v=0
   for k=1,3 do v+=a.r[(i-1)*3+k]*b.r[(k-1)*3+j] end
   c.r[(i-1)*3+j]=v
  end
 end
 return c
end
CFrame.identity=CFrame.new()
local enumMt = {
	__index = function(_self, key)
		return key
	end,
}
local Enum = setmetatable({}, {
	__index = function(self, key)
		local t = setmetatable({}, enumMt)
		rawset(self, key, t)
		return t
	end,
})
local built = 0
local builtParts = {}
local Instance = {
	new = function(className)
		local values = { ClassName = className }
		return setmetatable({}, {
			__index = values,
			__newindex = function(_self, key, value)
				if key == "Color" then
					assert(
						type(value) == "table" and value.kind == "Color3",
						"Invalid Color assignment: " .. type(value)
					)
				end
				if key == "Size" then
					assert(value.X > 0 and value.Y > 0 and value.Z > 0, "Invalid part size")
				end
				values[key] = value
				if key == "Parent" and (className == "Part" or className == "WedgePart") then
					built += 1
					table.insert(builtParts, values)
				end
			end,
		})
	end,
}

local randomSeed = 123
local Random = {
	new = function(seed)
		randomSeed += 1
		local state = seed or randomSeed
		return {
			NextNumber = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return (low or 0) + state / 2147483647 * ((high or 1) - (low or 0))
			end,
			NextInteger = function(_self, low, high)
				state = (state * 48271) % 2147483647
				return low + state % (high - low + 1)
			end,
		}
	end,
}

local ArmorKits=(function()
--[[
	Armor designs welded to the avatar. Current miner assets use three compact families:
	stepped helmets, layered plates and tapered human proportions. Legacy fantasy builders
	are retained for other classes.

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
	Traits: any?,
	HelmetDesign: number?,
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

-- Chain hood with an iron mask.
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

-- Saga Miners (the Warrior) -----------------------------------------------------------------
--[[
	Saga Miners wear spacesuits: a ladder of four, from a patched Scrap Suit up
	to the Crusader Exo. Every suit is one simple figure (about 35-50 smooth
	parts: stepped armor plates and utility blocks) that covers the whole body, so the
	avatar underneath is hidden (see ArmorKits.build). Helmets have a dark
	glass visor. The glowing bits (chest light, wrist displays, pack lights)
	are Neon in the kit's accent colour, so trims and enchantments light them.
]]

-- Native block geometry gives the suits a crisp voxel silhouette.
-- These helpers are local to the miner suits; other classes keep their builders.
local function suitBlock(folder, seg, cframe, size, color, material)
	return box(folder, seg, cframe, size, color, material or Enum.Material.SmoothPlastic)
end
local function light(folder, seg, cframe, size, color)
	local part = box(folder, seg, cframe, size, color, Enum.Material.Neon)
	if part then
		part.CastShadow = false
	end
	return part
end

local VISOR = Color3.fromRGB(18, 26, 40)
local FABRIC = Enum.Material.Fabric
local SMOOTH = Enum.Material.SmoothPlastic

type Suit = {
	Helmet: "Bubble" | "Miner" | "Ranger" | "Crusader",
	Plates: boolean, -- armour plates over the suit (chest, knees, shoulders)
	Pauldrons: boolean,
	Pack: "Pack" | "Tanks" | "Jet",
	Stripes: boolean, -- hi-vis bands on arms and legs
	Cape: boolean,
}

-- The head the helmet is built around: a person's, a bit smaller than an
-- avatar's big blocky head (which is hidden anyway).
local function humanHead(head: Segment): Segment
	return { Part = head.Part, Offset = head.Offset * CFrame.new(0, -head.Size.Y * 0.06, 0), Size = head.Size * 0.72 }
end

local function helmet(folder, head: Segment, kit: Kit, style: Suit)
	local h = head.Size
	local shellColor = kit.Metal
	-- Stepped crown and cheek guards frame a flat, readable visor.
	box(folder, head, CFrame.new(0, 0, 0.05), h * Vector3.new(1.12, 1.06, 1.12), kit.Trim, SMOOTH)
	box(folder, head, CFrame.new(0, h.Y * 0.36, 0), h * Vector3.new(1.22, 0.34, 1.16), shellColor, SMOOTH)
	box(folder, head, CFrame.new(0, h.Y * 0.57, 0.04), h * Vector3.new(0.88, 0.14, 0.98), shellColor, SMOOTH)
	box(folder, head, CFrame.new(0, h.Y * 0.08, -h.Z * 0.59), h * Vector3.new(0.92, 0.5, 0.08), VISOR, SMOOTH)
	box(
		folder,
		head,
		CFrame.new(0, h.Y * 0.1, -h.Z * 0.64),
		h * Vector3.new(0.74, 0.38, 0.03),
		if kit.Traits then kit.Traits.VisorColor else Color3.fromRGB(20, 139, 184),
		SMOOTH
	)
	light(
		folder,
		head,
		CFrame.new(-h.X * 0.23, h.Y * 0.1, -h.Z * 0.665),
		h * Vector3.new(0.08, 0.34, 0.02),
		Color3.fromRGB(100, 232, 248)
	)
	box(folder, head, CFrame.new(0, -h.Y * 0.36, -h.Z * 0.5), h * Vector3.new(0.84, 0.24, 0.34), shellColor, SMOOTH)
	for _, side in sides() do
		box(
			folder,
			head,
			CFrame.new(side * h.X * 0.52, -h.Y * 0.12, -h.Z * 0.24),
			h * Vector3.new(0.24, 0.7, 0.76),
			shellColor,
			SMOOTH
		)
		box(folder, head, CFrame.new(side * h.X * 0.65, 0, 0.05), h * Vector3.new(0.16, 0.42, 0.48), kit.Trim, SMOOTH)
		box(
			folder,
			head,
			CFrame.new(side * h.X * 0.72, 0.03, 0.05),
			h * Vector3.new(0.05, 0.16, 0.22),
			kit.Accent,
			SMOOTH
		)
	end
	if kit.Traits then
		local tier = kit.Traits.Helmet or 1
		for i = 1, tier - 1 do
			box(
				folder,
				head,
				CFrame.new((i - tier / 2) * h.X * 0.16, h.Y * 0.64, 0.08),
				Vector3.new(h.X * 0.1, h.Y * (0.08 + tier * 0.025), h.Z * 0.52),
				kit.Metal,
				SMOOTH
			)
		end
	end
	for _, side in sides() do
		wedge(
			folder,
			head,
			CFrame.new(side * h.X * 0.52, h.Y * 0.3, -h.Z * 0.32) * CFrame.Angles(0, 0, math.rad(side * 18)),
			Vector3.new(h.X * 0.18, h.Y * 0.3, h.Z * 0.7),
			shellColor,
			SMOOTH
		)
		box(
			folder,
			head,
			CFrame.new(side * h.X * 0.4, -h.Y * 0.27, -h.Z * 0.65),
			Vector3.new(0.06, 0.15, 0.04),
			kit.Trim,
			SMOOTH
		)
	end
	-- Respirator vents, rather than a featureless round face.
	for x = -1, 1 do
		box(
			folder,
			head,
			CFrame.new(x * h.X * 0.17, -h.Y * 0.35, -h.Z * 0.685),
			h * Vector3.new(0.08, 0.12, 0.025),
			kit.Trim,
			SMOOTH
		)
	end
	box(folder, head, CFrame.new(0, -h.Y * 0.59, 0.02), h * Vector3.new(0.94, 0.16, 0.94), kit.Trim, SMOOTH)
	if style.Helmet == "Miner" or style.Helmet == "Bubble" then
		box(folder, head, CFrame.new(0, h.Y * 0.42, -h.Z * 0.61), h * Vector3.new(0.28, 0.2, 0.14), kit.Trim, SMOOTH)
		light(
			folder,
			head,
			CFrame.new(0, h.Y * 0.42, -h.Z * 0.695),
			h * Vector3.new(0.17, 0.11, 0.03),
			Color3.fromRGB(255, 229, 166)
		)
	elseif style.Helmet == "Ranger" then
		box(folder, head, CFrame.new(h.X * 0.55, h.Y * 0.58, 0.16), Vector3.new(0.06, 0.55, 0.06), kit.Trim, SMOOTH)
	else
		box(folder, head, CFrame.new(0, h.Y * 0.65, 0.02), h * Vector3.new(0.2, 0.22, 0.92), kit.Trim, SMOOTH)
	end
end

local function torsoPieces(folder, parts: Body, kit: Kit, style: Suit)
	local torso, waist = parts.Torso, parts.Waist
	if torso then
		local t = torso.Size
		suitBlock(folder, torso, CFrame.new(0, t.Y * 0.08, 0), t * Vector3.new(0.96, 1.02, 1.04), kit.Cloth, FABRIC)
		suitBlock(folder, torso, CFrame.new(0, t.Y * 0.3, 0), t * Vector3.new(1.08, 0.32, 1.08), kit.Cloth, FABRIC)
		suitBlock(folder, torso, CFrame.new(0, -t.Y * 0.38, 0), t * Vector3.new(0.88, 0.3, 1.0), kit.Cloth, FABRIC)
		if style.Plates then
			suitBlock(
				folder,
				torso,
				CFrame.new(0, t.Y * 0.14, -t.Z * 0.2),
				t * Vector3.new(0.86, 0.78, 0.9),
				kit.Metal,
				kit.Material
			)
		end
		-- Twin shoulder straps and a stepped chest plate.
		for _, side in sides() do
			box(
				folder,
				torso,
				CFrame.new(side * t.X * 0.32, t.Y * 0.12, -t.Z * 0.55),
				Vector3.new(t.X * 0.12, t.Y * 0.78, 0.08),
				kit.Trim,
				SMOOTH
			)
		end
		box(
			folder,
			torso,
			CFrame.new(0, t.Y * 0.31, -t.Z * 0.56),
			Vector3.new(t.X * 0.5, t.Y * 0.14, 0.1),
			kit.Metal,
			SMOOTH
		)
		-- Chest light, and a panel for it.
		box(folder, torso, CFrame.new(0, t.Y * 0.16, -t.Z * 0.62), Vector3.new(0.5, 0.36, 0.1), kit.Trim, kit.Material)
		light(folder, torso, CFrame.new(0, t.Y * 0.16, -t.Z * 0.68), Vector3.new(0.26, 0.2, 0.08), kit.Accent)
		-- Life support on the back.
		if style.Pack == "Pack" then
			box(
				folder,
				torso,
				CFrame.new(0, t.Y * 0.08, t.Z * 0.72),
				Vector3.new(t.X * 0.62, t.Y * 0.8, 0.44),
				kit.Trim,
				kit.Material
			)
			light(folder, torso, CFrame.new(0, t.Y * 0.3, t.Z * 0.95), Vector3.new(0.3, 0.1, 0.06), kit.Accent)
		else
			for _, side in sides() do
				suitBlock(
					folder,
					torso,
					CFrame.new(side * t.X * 0.18, t.Y * 0.04, t.Z * 0.78),
					Vector3.new(0.5, t.Y * 0.95, 0.5),
					if style.Pack == "Jet" then kit.Metal else kit.Trim,
					kit.Material
				)
				light(
					folder,
					torso,
					CFrame.new(side * t.X * 0.18, -t.Y * 0.44 - (if style.Pack == "Jet" then 0.1 else 0), t.Z * 0.78),
					Vector3.new(0.34, 0.14, 0.34),
					kit.Accent
				)
			end
		end
		if style.Cape then
			for _, side in sides() do
				box(
					folder,
					torso,
					CFrame.new(side * t.X * 0.24, t.Y * 0.45, t.Z * 1.06)
						* CFrame.Angles(math.rad(-6), math.rad(side * 10), 0)
						* CFrame.new(0, -1.7, 0),
					Vector3.new(t.X * 0.46, 3.4, 0.06),
					Color3.fromRGB(150, 36, 40),
					FABRIC
				)
			end
		end
	end
	if waist then
		local w = waist.Size
		suitBlock(folder, waist, CFrame.identity, w * Vector3.new(0.9, 1.3, 1.0), kit.Cloth, FABRIC)
		suitBlock(
			folder,
			waist,
			CFrame.new(0, w.Y * 0.2, 0),
			Vector3.new(w.X * 0.95, 0.24, w.Z * 1.08),
			kit.Trim,
			kit.Material
		)
		for _, side in sides() do
			-- Utility pouches on the belt.
			box(
				folder,
				waist,
				CFrame.new(side * w.X * 0.34, w.Y * 0.05, -w.Z * 0.5),
				Vector3.new(0.34, 0.3, 0.2),
				kit.Trim,
				kit.Material
			)
		end
		suitBlock(
			folder,
			waist,
			CFrame.new(0, -w.Y * 1.0, 0),
			Vector3.new(w.X * 1.0, 0.5, w.Z * 1.08),
			kit.Cloth,
			FABRIC
		)
	end
end

local function limbs(folder, parts: Body, kit: Kit, style: Suit)
	local stripe = Color3.fromRGB(242, 173, 65)
	for _, side in sides() do
		local L = if side == -1 then "Left" else "Right"
		-- Arm pieces sit a little in from the avatar's arms, closing the gap
		-- a blocky rig leaves between arm and chest.
		local inward = CFrame.new(-side * 0.1, 0, 0)
		local upper, lower, hand = parts[L .. "UpperArm"], parts[L .. "LowerArm"], parts[L .. "Hand"]
		if upper then
			local a = upper.Size
			suitBlock(folder, upper, inward, a * Vector3.new(0.84, 1.0, 0.88), kit.Cloth, FABRIC)
			if style.Pauldrons then
				local top = inward
					* CFrame.new(side * a.X * 0.06, a.Y * 0.34, 0)
					* CFrame.Angles(0, 0, math.rad(side * -14))
				suitBlock(folder, upper, top, Vector3.new(a.X * 1.4, a.Y * 0.74, a.Z * 1.34), kit.Metal, kit.Material)
				suitBlock(folder, upper, top, Vector3.new(a.X * 1.44, 0.07, a.Z * 1.38), kit.Trim, kit.Material)
			else
				suitBlock(
					folder,
					upper,
					inward * CFrame.new(0, a.Y * 0.38, 0),
					a * Vector3.new(1.06, 0.42, 1.06),
					kit.Cloth,
					FABRIC
				)
			end
			if style.Stripes then
				suitBlock(
					folder,
					upper,
					inward * CFrame.new(0, -a.Y * 0.15, 0),
					a * Vector3.new(0.88, 0.1, 0.92),
					stripe,
					SMOOTH
				)
			end
		end
		if lower then
			local l = lower.Size
			suitBlock(
				folder,
				lower,
				inward * CFrame.new(0, l.Y * 0.46, 0),
				l * Vector3.new(0.86, 0.46, 0.9),
				kit.Trim,
				kit.Material
			)
			suitBlock(
				folder,
				lower,
				inward * CFrame.new(0, -l.Y * 0.06, 0),
				l * Vector3.new(0.8, 0.9, 0.84),
				kit.Cloth,
				FABRIC
			)
			-- A chunky cuff with a glowing wrist display.
			suitBlock(
				folder,
				lower,
				inward * CFrame.new(0, -l.Y * 0.36, 0),
				l * Vector3.new(0.94, 0.32, 0.98),
				if style.Plates then kit.Metal else kit.Trim,
				kit.Material
			)
			light(
				folder,
				lower,
				inward * CFrame.new(0, -l.Y * 0.36, -l.Z * 0.46),
				Vector3.new(0.3, 0.14, 0.08),
				kit.Accent
			)
		end
		if hand then
			suitBlock(
				folder,
				hand,
				inward * CFrame.new(0, -hand.Size.Y * 0.3, 0),
				hand.Size * Vector3.new(0.86, 1.3, 0.94),
				kit.Trim,
				kit.Material
			)
		end
		if hand then
			local h = hand.Size
			box(
				folder,
				hand,
				inward * CFrame.new(0, 0, -h.Z * 0.48),
				h * Vector3.new(0.74, 0.5, 0.2),
				kit.Metal,
				SMOOTH
			)
			for knuckle = -1, 1 do
				box(
					folder,
					hand,
					inward * CFrame.new(knuckle * h.X * 0.2, -h.Y * 0.18, -h.Z * 0.58),
					Vector3.new(h.X * 0.13, h.Y * 0.15, 0.06),
					kit.Trim,
					SMOOTH
				)
			end
		end
		local thigh, shin, foot = parts[L .. "UpperLeg"], parts[L .. "LowerLeg"], parts[L .. "Foot"]
		if thigh then
			suitBlock(
				folder,
				thigh,
				CFrame.new(0, thigh.Size.Y * 0.05, 0),
				thigh.Size * Vector3.new(0.92, 1.1, 0.92),
				kit.Cloth,
				FABRIC
			)
			if style.Stripes then
				suitBlock(
					folder,
					thigh,
					CFrame.new(0, -thigh.Size.Y * 0.2, 0),
					thigh.Size * Vector3.new(0.95, 0.1, 0.95),
					stripe,
					SMOOTH
				)
			end
		end
		if shin then
			local l = shin.Size
			suitBlock(
				folder,
				shin,
				CFrame.new(0, l.Y * 0.44, -l.Z * 0.12),
				l * Vector3.new(0.84, 0.5, 0.82),
				if style.Plates then kit.Metal else kit.Trim,
				kit.Material
			)
			suitBlock(folder, shin, CFrame.new(0, -l.Y * 0.04, 0), l * Vector3.new(0.82, 0.96, 0.84), kit.Cloth, FABRIC)
		end
		if foot then
			local f = foot.Size
			-- Chunky magnetic boots.
			suitBlock(
				folder,
				foot,
				CFrame.new(0, f.Y * 0.6, 0.02),
				Vector3.new(f.X * 0.9, 0.5, f.Z * 0.94),
				kit.Trim,
				kit.Material
			)
			suitBlock(
				folder,
				foot,
				CFrame.new(0, f.Y * 0.1, -f.Z * 0.16),
				Vector3.new(f.X * 0.9, f.Y * 1.8, f.Z * 1.36),
				kit.Trim,
				kit.Material
			)
			box(
				folder,
				foot,
				CFrame.new(0, -f.Y * 0.48, -f.Z * 0.12),
				Vector3.new(f.X * 0.98, f.Y * 0.22, f.Z * 1.4),
				Color3.fromRGB(20, 27, 35),
				SMOOTH
			)
			wedge(
				folder,
				foot,
				CFrame.new(0, f.Y * 0.24, -f.Z * 0.51),
				Vector3.new(f.X * 0.9, f.Y * 0.75, f.Z * 0.5),
				kit.Metal,
				SMOOTH
			)
			light(folder, foot, CFrame.new(0, f.Y * 0.4, -f.Z * 0.78), Vector3.new(f.X * 0.46, 0.06, 0.04), kit.Accent)
		end
	end
end

local function suit(style: Suit)
	return function(folder, parts: Body, kit: Kit)
		if parts.Head then
			helmet(folder, humanHead(parts.Head), kit, style)
		end
		torsoPieces(folder, parts, kit, style)
		limbs(folder, parts, kit, style)
	end
end

-- Looks that cover the whole figure: the avatar underneath is hidden.
local FULL_BODY =
	{ SuitScrap = true, SuitMiner = true, SuitRanger = true, SuitCrusader = true, SuitZeroG = true, SuitThermal = true }

-- Tier 1, the starter: a patched white suit, amber helmet and a small pack.
BUILDERS.SuitScrap = suit({
	Helmet = "Bubble",
	Plates = false,
	Pauldrons = false,
	Pack = "Pack",
	Stripes = false,
	Cape = false,
})

-- Tier 2: a hi-vis mining suit with a headlamp and twin air tanks.
BUILDERS.SuitMiner = suit({
	Helmet = "Miner",
	Plates = false,
	Pauldrons = false,
	Pack = "Tanks",
	Stripes = true,
	Cape = false,
})

-- Tier 3: armour plates, pauldrons and a glowing visor strip.
BUILDERS.SuitRanger = suit({
	Helmet = "Ranger",
	Plates = true,
	Pauldrons = true,
	Pack = "Tanks",
	Stripes = false,
	Cape = false,
})

-- Tier 4: white and gold exo-armour, a jet pack and a crusader's cape.
BUILDERS.SuitCrusader = suit({
	Helmet = "Crusader",
	Plates = true,
	Pauldrons = true,
	Pack = "Jet",
	Stripes = false,
	Cape = true,
})

BUILDERS.SuitZeroG =
	suit({ Helmet = "Ranger", Plates = false, Pauldrons = false, Pack = "Jet", Stripes = true, Cape = false })
BUILDERS.SuitThermal =
	suit({ Helmet = "Miner", Plates = true, Pauldrons = true, Pack = "Tanks", Stripes = true, Cape = false })

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

-- Three expedition families with faceted plates and exposed flex joints.
-- Built on body segments so individual pieces support both R6 and R15 rigs.
local CLEAN_LOOKS = { UtilityMiner = true, FrontierRanger = true, HeavyVanguard = true }
local CLEAN_ALIASES = {
	SuitScrap = "UtilityMiner",
	SuitMiner = "UtilityMiner",
	SuitZeroG = "FrontierRanger",
	SuitRanger = "FrontierRanger",
	SuitThermal = "HeavyVanguard",
	SuitCrusader = "HeavyVanguard",
}
-- Shape the visible armor independently of the collision rig. Keep joint heights
-- unchanged so equipped pieces still follow both R6 and R15 animations.
local function humanBody(parts: Body): Body
	local result: Body = {}
	for name, seg in parts do
		local scale = Vector3.new(1, 1, 1)
		if name == "Torso" then
			scale = Vector3.new(0.87, 1, 0.8)
		elseif name == "Waist" then
			scale = Vector3.new(0.67, 1, 0.76)
		elseif string.find(name, "UpperArm") then
			scale = Vector3.new(0.67, 1, 0.68)
		elseif string.find(name, "LowerArm") then
			scale = Vector3.new(0.61, 1, 0.64)
		elseif string.find(name, "Hand") then
			scale = Vector3.new(0.58, 1, 0.63)
		elseif string.find(name, "UpperLeg") then
			scale = Vector3.new(0.78, 1, 0.79)
		elseif string.find(name, "LowerLeg") then
			scale = Vector3.new(0.66, 1, 0.7)
		elseif string.find(name, "Foot") then
			scale = Vector3.new(0.69, 1, 0.82)
		end
		result[name] = { Part = seg.Part, Offset = seg.Offset, Size = seg.Size * scale }
	end
	return result
end

-- Purpose-built expedition armor. Plates follow anatomy, leaving joints exposed.
local function frontierSuit(family: number)
	return function(folder, raw: Body, kit: Kit)
		local body = humanBody(raw)
		local rarity = math.clamp(kit.Traits and kit.Traits.Rarity or 1, 1, 5)
		local metal = kit.Metal
		local edge = metal:Lerp(Color3.fromRGB(214, 229, 232), 0.32)
		local trim = kit.Trim
		local cloth = kit.Cloth
		local ornament = if rarity == 5 then BRASS else edge
		local helmetVariant = math.clamp(kit.Traits and kit.Traits.Helmet or 1, 1, 5)
		-- Catalog identity is stable across saved cosmetic rolls.
		local design = kit.HelmetDesign or helmetVariant
		local function block(seg, x, y, z, sx, sy, sz, color, tilt)
			box(
				folder,
				seg,
				CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(tilt or 0)),
				Vector3.new(sx, sy, sz),
				color,
				SMOOTH
			)
		end
		local function lit(seg, x, y, z, sx, sy, sz)
			light(folder, seg, CFrame.new(x, y, z), Vector3.new(sx, sy, sz), kit.Accent)
		end
		local function plate(seg, x, y, z, sx, sy, sz, color)
			block(seg, x, y, z, sx * 0.72, sy, sz, color)
			for _, sign in { -1, 1 } do
				block(seg, x + sign * sx * 0.38, y, z + sz * 0.18, sx * 0.23, sy * 0.86, sz * 0.72, color, sign * -12)
			end
		end
		local head = body.Head
		if head then
			head = humanHead(head)
			local s = head.Size
			local x, y, z = s.X, s.Y, s.Z
			-- Recessed wrap visor inside an angular brow and sloped cheek armor.
			block(head, 0, 0, 0.04, x * 0.86, y * 0.92, z * 0.88, trim)
			plate(head, 0, y * 0.34, 0.015, x * 1.02, y * 0.34, z * 0.98, metal)
			block(head, 0, y * 0.53, 0.055, x * (0.6 + helmetVariant * 0.025), y * 0.12, z * 0.8, edge)
			block(head, 0, y * 0.03, -z * 0.5, x * 0.79, y * 0.4, 0.045, Color3.fromRGB(8, 20, 30))
			local visor = kit.Traits and kit.Traits.VisorColor or Color3.fromRGB(238, 174, 57)
			block(head, 0, y * 0.065, -z * 0.535, x * 0.68, y * 0.24, 0.025, visor)
			for _, side in { -1, 1 } do
				block(head, side * x * 0.385, y * 0.06, -z * 0.47, x * 0.17, y * 0.25, 0.1, visor, side * -8)
				block(head, side * x * 0.4, -y * 0.19, -z * 0.39, x * 0.2, y * 0.45, z * 0.32, metal, side * -18)
				block(head, side * x * 0.52, 0, 0.04, x * 0.16, y * 0.34, z * 0.4, trim)
			end
			plate(head, 0, -y * 0.36, -z * 0.37, x * 0.65, y * 0.18, z * 0.38, metal)
			block(head, 0, -y * 0.36, -z * 0.58, x * 0.31, y * 0.085, 0.03, trim)
			block(head, 0, -y * 0.56, 0.02, x * 0.58, y * 0.17, z * 0.6, cloth)

			-- Keep the wrap visor and faceted shell; each helm has its own face
			-- frame and crown equipment rather than a recolor of the same shape.
			if design == 1 then -- Zero-G: sealed center ridge and compact respirator.
				block(head, 0, y * 0.43, 0.04, x * 0.15, y * 0.21, z * 0.88, metal)
				block(head, 0, -y * 0.25, -z * 0.58, x * 0.34, y * 0.16, z * 0.13, edge)
			elseif design == 2 then -- Platon: split tactical goggles and brow guards.
				block(head, 0, y * 0.06, -z * 0.56, x * 0.095, y * 0.3, 0.04, metal)
				for _, side in sides() do
					block(head, side * x * 0.25, y * 0.26, -z * 0.54, x * 0.4, y * 0.1, 0.1, edge, side * -10)
				end
			elseif design == 3 then -- Asterois: enclosed T-face and filtered jaw.
				for _, side in sides() do
					block(head, side * x * 0.27, -y * 0.02, -z * 0.565, x * 0.22, y * 0.27, 0.06, metal)
				end
				block(head, 0, -y * 0.19, -z * 0.59, x * 0.13, y * 0.2, 0.045, visor)
				for i = -1, 1 do
					block(head, i * x * 0.12, -y * 0.35, -z * 0.61, x * 0.065, y * 0.065, 0.035, edge)
				end
			elseif design == 4 then -- Intableed: sweeping visor and angular temples.
				for _, side in sides() do
					block(head, side * x * 0.27, y * 0.19, -z * 0.57, x * 0.4, y * 0.085, 0.065, edge, side * 14)
					block(head, side * x * 0.47, y * 0.27, 0, x * 0.12, y * 0.37, z * 0.52, metal, side * -12)
				end
			elseif design == 5 then -- Jutaim: command crest, gilt jaw and crown rails.
				plate(head, 0, y * 0.62, 0.06, x * 0.22, y * 0.22, z * 0.7, metal)
				for _, side in sides() do
					block(head, side * x * 0.4, y * 0.46, 0.06, x * 0.08, y * 0.22, z * 0.62, ornament, side * -16)
					block(head, side * x * 0.2, -y * 0.28, -z * 0.58, x * 0.24, y * 0.065, 0.045, ornament, side * 22)
				end
			elseif design == 6 then -- Qutany: projecting FPV optics under a sun hood.
				block(head, 0, y * 0.24, -z * 0.56, x * 0.8, y * 0.1, z * 0.25, metal)
				for _, side in sides() do
					block(head, side * x * 0.2, y * 0.04, -z * 0.59, x * 0.27, y * 0.23, z * 0.14, trim)
					block(head, side * x * 0.2, y * 0.04, -z * 0.675, x * 0.19, y * 0.14, 0.025, visor)
				end
			elseif design == 7 then -- Watten: swept crown fins and narrow speed visor.
				block(head, 0, y * 0.18, -z * 0.57, x * 0.76, y * 0.1, 0.06, metal)
				for _, side in sides() do
					block(head, side * x * 0.31, y * 0.46, z * 0.15, x * 0.1, y * 0.23, z * 0.74, edge, side * -20)
				end
			elseif design == 8 then -- Photon: shield-shaped face surround and emitters.
				for _, side in sides() do
					block(head, side * x * 0.37, -y * 0.05, -z * 0.55, x * 0.1, y * 0.46, 0.075, edge, side * -18)
					block(head, side * x * 0.54, -y * 0.08, 0.02, x * 0.14, y * 0.26, z * 0.28, metal)
					lit(head, side * x * 0.62, -y * 0.08, 0.02, 0.025, y * 0.12, z * 0.12)
				end
			elseif design == 9 then -- Photrin: precision monocle and asymmetric sensor rail.
				block(head, -x * 0.23, y * 0.04, -z * 0.6, x * 0.28, y * 0.26, 0.12, edge)
				block(head, -x * 0.23, y * 0.04, -z * 0.675, x * 0.17, y * 0.15, 0.025, visor)
				block(head, x * 0.3, y * 0.48, 0.04, x * 0.18, y * 0.18, z * 0.75, metal)
				for i = 1, 2 do
					lit(head, x * 0.3, y * 0.48, -z * (0.25 + i * 0.1), x * 0.08, y * 0.07, 0.025)
				end
			else -- Metron: interlocking neural lattice over the visor and crown.
				for _, side in sides() do
					block(head, side * x * 0.2, y * 0.06, -z * 0.575, x * 0.055, y * 0.33, 0.04, ornament, side * 30)
					block(head, side * x * 0.19, y * 0.56, 0.06, x * 0.065, y * 0.16, z * 0.78, ornament, side * 20)
					lit(head, side * x * 0.39, y * 0.32, -z * 0.52, x * 0.065, y * 0.12, 0.03)
				end
			end

			if family == 1 then
				-- Survey lamp defines the working miner silhouette.
				block(head, 0, y * 0.38, -z * 0.54, x * 0.24, y * 0.16, 0.1, trim)
				lit(head, 0, y * 0.38, -z * 0.6, x * 0.14, y * 0.08, 0.025)
			elseif family == 2 then
				block(head, -x * 0.55, y * 0.16, 0.1, 0.09, y * 0.55, 0.1, metal)
				block(head, -x * 0.55, y * 0.43, 0.1, 0.045, y * 0.18, 0.045, edge)
			else
				-- Heavy suits frame the visor with a deeper armored brow.
				for _, side in { -1, 1 } do
					block(head, side * x * 0.32, y * 0.28, -z * 0.48, x * 0.27, y * 0.16, 0.16, metal, side * -12)
				end
			end
			if rarity >= 2 then
				for _, side in { -1, 1 } do
					block(head, side * x * 0.53, y * 0.02, -z * 0.08, 0.06, y * 0.2, 0.16, edge)
					block(head, side * x * 0.34, -y * 0.27, -z * 0.54, x * 0.13, y * 0.055, 0.045, edge, side * -18)
					-- Flush temple rivets and recessed rebreather vents.
					block(head, side * x * 0.46, y * 0.24, -z * 0.42, 0.05, 0.05, 0.035, edge)
					for vent = 1, 2 do
						block(head, side * x * 0.43, -y * (0.17 + vent * 0.075), -z * 0.47, x * 0.09, 0.025, 0.04, trim)
					end
				end
			end
			if rarity >= 3 then
				block(head, x * 0.48, y * 0.36, 0.12, 0.07, y * 0.5, 0.08, trim)
				block(head, 0, y * 0.33, -z * 0.53, x * 0.5, 0.045, 0.055, ornament)
				block(head, 0, -y * 0.29, z * 0.5, x * 0.48, y * 0.12, 0.05, edge)
			end
			if rarity >= 4 then
				plate(head, 0, y * 0.4, z * 0.4, x * 0.7, y * 0.22, z * 0.14, edge)
				lit(head, 0, -y * 0.29, z * 0.54, x * 0.23, 0.035, 0.025)
				lit(head, -x * 0.53, y * 0.06, -z * 0.18, 0.04, 0.075, 0.06)
				lit(head, x * 0.53, y * 0.06, -z * 0.18, 0.04, 0.075, 0.06)
			end
			if rarity >= 5 then
				block(head, 0, y * 0.36, -z * 0.62, x * 0.13, y * 0.14, 0.05, BRASS)
				for _, side in sides() do
					block(head, side * x * 0.27, -y * 0.38, -z * 0.56, x * 0.12, 0.035, 0.035, BRASS, side * 18)
				end
				lit(head, 0, y * 0.36, -z * 0.655, x * 0.065, y * 0.065, 0.025)
				for _, side in { -1, 1 } do
					block(head, side * x * 0.24, y * 0.46, 0.03, 0.08, y * 0.11, z * 0.7, BRASS)
				end
			end
		end
		local torso = body.Torso
		if torso then
			local s = torso.Size
			local x, y, z = s.X, s.Y, s.Z
			block(torso, 0, 0, 0, x * 0.88, y * 0.92, z * 0.84, cloth)
			-- A narrow abdomen joins the ribcage to the belt instead of a square slab.
			block(torso, 0, -y * 0.56, 0, x * 0.61, y * 0.47, z * 0.76, cloth)
			for i = 1, 3 do
				block(torso, 0, -y * (0.27 + i * 0.13), -z * 0.43, x * (0.66 - i * 0.055), y * 0.105, 0.1, trim)
			end
			for _, side in { -1, 1 } do
				block(torso, side * x * 0.22, y * 0.14, -z * 0.45, x * 0.43, y * 0.46, z * 0.29, metal, side * -10)
				block(torso, side * x * 0.38, -y * 0.18, -z * 0.36, x * 0.2, y * 0.34, z * 0.25, metal, side * 14)
				block(torso, side * x * 0.29, y * 0.41, -z * 0.31, x * 0.23, y * 0.12, z * 0.48, edge, side * -10)
			end
			-- Armored collar, flush central reactor and separate life-support unit.
			block(torso, 0, y * 0.48, 0.02, x * 0.5, y * 0.12, z * 0.78, trim)
			block(torso, 0, y * 0.04, -z * 0.64, x * 0.17, y * 0.29, 0.1, trim)
			lit(torso, 0, y * 0.08, -z * 0.702, x * 0.08, y * 0.1, 0.035)
			plate(torso, 0, y * 0.02, z * 0.62, x * 0.53, y * 0.84, 0.27, trim)
			block(torso, 0, y * 0.19, z * 0.79, x * 0.28, y * 0.25, 0.08, metal)
			for i = 1, 3 do
				block(torso, 0, -y * (0.02 + i * 0.1), z * 0.83, x * 0.32, 0.045, 0.05, edge)
			end

			if family == 1 then
				block(torso, x * 0.34, -y * 0.18, z * 0.46, x * 0.16, y * 0.35, 0.2, metal)
				block(torso, x * 0.34, -y * 0.18, z * 0.575, x * 0.08, 0.06, 0.025, edge)
			elseif family == 2 then
				block(torso, 0, y * 0.39, z * 0.85, x * 0.4, 0.065, 0.09, metal)
				block(torso, 0, -y * 0.42, z * 0.85, x * 0.4, 0.065, 0.09, metal)
			else
				for _, side in { -1, 1 } do
					plate(torso, side * x * 0.28, -y * 0.02, z * 0.72, x * 0.2, y * 0.7, 0.22, metal)
				end
			end
			if rarity >= 2 then
				for _, side in { -1, 1 } do
					block(torso, side * x * 0.3, y * 0.06, -z * 0.64, 0.06, y * 0.18, 0.04, edge, side * -10)
					block(torso, side * x * 0.21, -y * 0.06, -z * 0.61, x * 0.25, 0.04, 0.035, edge, side * -10)
					block(torso, side * x * 0.29, y * 0.33, -z * 0.6, 0.055, 0.055, 0.04, trim)
					block(torso, side * x * 0.19, y * 0.19, z * 0.845, 0.045, 0.045, 0.025, edge)
				end
			end
			if rarity >= 3 then
				for vent = 1, 3 do
					block(torso, 0, y * (0.15 + vent * 0.07), z * 0.845, x * 0.18, 0.025, 0.025, trim)
				end
				for _, side in { -1, 1 } do
					block(torso, side * x * 0.34, -y * 0.35, -z * 0.4, x * 0.2, y * 0.18, 0.15, metal, side * 16)
					block(torso, side * x * 0.39, y * 0.14, -z * 0.56, 0.045, y * 0.27, 0.045, edge, side * -10)
					block(torso, side * x * 0.28, y * 0.32, -z * 0.64, x * 0.2, 0.04, 0.035, ornament, side * -10)
				end
			end
			if rarity >= 4 then
				for _, side in { -1, 1 } do
					lit(torso, side * x * 0.29, y * 0.31, -z * 0.67, x * 0.13, 0.025, 0.025)
					lit(torso, side * x * 0.16, y * 0.2, z * 0.865, 0.03, y * 0.17, 0.025)
				end
			end
			if rarity >= 5 then
				for _, side in { -1, 1 } do
					block(torso, side * x * 0.13, y * 0.26, -z * 0.66, x * 0.14, 0.045, 0.025, BRASS, side * -25)
					block(torso, side * x * 0.24, y * 0.02, z * 0.86, 0.065, y * 0.54, 0.06, BRASS)
				end
			end
		end
		local waist = body.Waist
		if waist then
			local s = waist.Size
			block(waist, 0, 0, 0, s.X * 0.96, s.Y * 1.12, s.Z * 0.84, cloth)
			block(waist, 0, s.Y * 0.19, -0.015, s.X * 1.04, 0.16, s.Z * 0.95, trim)
			block(waist, 0, s.Y * 0.19, -s.Z * 0.54, 0.21, 0.16, 0.075, ornament)
			if rarity >= 2 then
				block(waist, 0, s.Y * 0.19, -s.Z * 0.59, 0.12, 0.075, 0.025, trim)
			end
			for _, side in { -1, 1 } do
				block(waist, side * s.X * 0.39, -s.Y * 0.12, -s.Z * 0.4, s.X * 0.24, s.Y * 0.62, 0.18, metal, side * 8)
			end
		end
		for _, side in { -1, 1 } do
			local prefix = if side == -1 then "Left" else "Right"
			local upper = body[prefix .. "UpperArm"]
			if upper then
				local s = upper.Size
				local inward = -side * 0.12
				block(upper, inward, -s.Y * 0.08, 0, s.X * 0.74, s.Y * 0.94, s.Z * 0.76, cloth)
				-- Sloping shoulder shell; heavier families have more coverage, not wider arms.
				local span = if family == 3 then 1.42 elseif family == 2 then 1.26 else 1.08
				block(upper, inward, s.Y * 0.32, 0, s.X * span, s.Y * 0.3, s.Z * 1.16, metal, side * -17)
				block(
					upper,
					inward + side * s.X * 0.4,
					s.Y * 0.12,
					0,
					s.X * 0.19,
					s.Y * 0.3,
					s.Z * 0.93,
					metal,
					side * -14
				)
				if rarity >= 2 then
					block(upper, inward, s.Y * 0.36, -s.Z * 0.58, s.X * span, 0.055, 0.045, edge, side * -17)
				end
				if rarity >= 3 then
					block(
						upper,
						inward + side * s.X * 0.15,
						-s.Y * 0.035,
						0,
						s.X * 1.13,
						s.Y * 0.18,
						s.Z * 1.01,
						metal,
						side * -12
					)
				end
				if rarity >= 4 then
					lit(upper, inward + side * s.X * 0.33, s.Y * 0.17, -s.Z * 0.57, 0.05, s.Y * 0.13, 0.025)
					for vent = 1, 2 do
						block(
							upper,
							inward + side * s.X * 0.31,
							s.Y * (0.1 - vent * 0.07),
							-s.Z * 0.5,
							s.X * 0.15,
							0.025,
							0.035,
							trim
						)
					end
				end
				if rarity >= 5 then
					block(upper, inward, s.Y * 0.43, 0, s.X * 1.03, 0.055, s.Z * 0.88, BRASS, side * -17)
				end
			end
			local fore = body[prefix .. "LowerArm"]
			if fore then
				local s = fore.Size
				local inward = -side * 0.1
				block(fore, inward, 0, 0, s.X * 0.75, s.Y * 0.94, s.Z * 0.72, cloth)
				plate(fore, inward, -s.Y * 0.05, -s.Z * 0.34, s.X * 0.86, s.Y * 0.7, s.Z * 0.34, metal)
				block(fore, inward, s.Y * 0.43, 0, s.X * 0.7, s.Y * 0.16, s.Z * 0.73, trim)
				block(fore, inward, -s.Y * 0.41, 0, s.X * 0.83, s.Y * 0.14, s.Z * 0.87, trim)
				if rarity >= 2 then
					block(fore, inward, -s.Y * 0.29, -s.Z * 0.56, s.X * 0.61, 0.055, 0.05, edge)
					block(fore, inward, s.Y * 0.28, -s.Z * 0.56, s.X * 0.33, s.Y * 0.17, 0.055, trim)
				end
				if rarity >= 3 then
					for i = 1, 2 do
						block(fore, inward, s.Y * (0.3 - i * 0.16), -s.Z * 0.55, s.X * 0.55, 0.06, 0.07, trim)
						block(fore, inward, s.Y * (0.3 - i * 0.16) + 0.04, -s.Z * 0.56, s.X * 0.46, 0.025, 0.035, edge)
					end
				end
				if rarity >= 4 then
					lit(fore, inward, s.Y * 0.17, -s.Z * 0.6, s.X * 0.27, 0.04, 0.025)
					lit(fore, inward, s.Y * 0.28, -s.Z * 0.6, s.X * 0.22, s.Y * 0.09, 0.025)
				end
				if rarity >= 5 then
					for _, edgeSide in { -1, 1 } do
						block(fore, inward + edgeSide * s.X * 0.29, 0, -s.Z * 0.52, 0.04, s.Y * 0.45, 0.04, BRASS)
					end
				end
			end
			local hand = body[prefix .. "Hand"]
			if hand then
				local s = hand.Size
				local inward = -side * 0.1
				block(hand, inward, -s.Y * 0.12, 0, s.X * 0.72, s.Y * 1.13, s.Z * 0.66, trim)
				block(hand, inward, 0, -s.Z * 0.35, s.X * 0.62, s.Y * 0.48, 0.08, metal)
				if rarity >= 2 then
					block(hand, inward, s.Y * 0.23, -s.Z * 0.41, s.X * 0.53, 0.045, 0.04, edge)
					for knuckle = -1, 1 do
						block(
							hand,
							inward + knuckle * s.X * 0.19,
							-s.Y * 0.12,
							-s.Z * 0.42,
							s.X * 0.13,
							s.Y * 0.28,
							0.035,
							metal
						)
					end
				end
				if rarity >= 4 then
					lit(hand, inward, 0, -s.Z * 0.43, s.X * 0.21, 0.035, 0.025)
				end
				block(
					hand,
					inward - side * s.X * 0.37,
					-s.Y * 0.08,
					-s.Z * 0.08,
					s.X * 0.18,
					s.Y * 0.65,
					s.Z * 0.3,
					cloth,
					side * -18
				)
			end
			local thigh = body[prefix .. "UpperLeg"]
			if thigh then
				local s = thigh.Size
				block(thigh, 0, 0, 0, s.X * 0.85, s.Y * 1.02, s.Z * 0.8, cloth)
				block(
					thigh,
					side * s.X * 0.11,
					s.Y * 0.12,
					-s.Z * 0.37,
					s.X * 0.69,
					s.Y * 0.58,
					s.Z * 0.25,
					metal,
					side * 6
				)
				if rarity >= 3 then
					block(thigh, side * s.X * 0.35, -s.Y * 0.13, 0, s.X * 0.22, s.Y * 0.44, s.Z * 0.73, trim, side * 5)
					block(thigh, side * s.X * 0.1, -s.Y * 0.13, -s.Z * 0.52, s.X * 0.44, 0.04, 0.035, edge, side * 6)
				end
			end
			local shin = body[prefix .. "LowerLeg"]
			if shin then
				local s = shin.Size
				block(shin, 0, 0, 0, s.X * 0.78, s.Y, s.Z * 0.77, cloth)
				-- Diamond knee cap and tapered shin shell expose the flex joint.
				block(shin, 0, s.Y * 0.45, -s.Z * 0.37, s.X * 0.47, s.Y * 0.34, s.Z * 0.32, edge, 45)
				plate(shin, 0, -s.Y * 0.08, -s.Z * 0.37, s.X * 0.76, s.Y * 0.67, s.Z * 0.29, metal)
				if rarity >= 2 then
					block(shin, 0, -s.Y * 0.37, -s.Z * 0.56, s.X * 0.6, 0.055, 0.05, edge)
					for _, fastener in sides() do
						block(shin, fastener * s.X * 0.2, s.Y * 0.44, -s.Z * 0.56, 0.045, 0.045, 0.035, trim)
					end
				end
				if rarity >= 3 then
					for _, edgeSide in { -1, 1 } do
						block(shin, edgeSide * s.X * 0.28, -s.Y * 0.02, -s.Z * 0.48, 0.04, s.Y * 0.42, 0.08, trim)
						block(shin, edgeSide * s.X * 0.24, -s.Y * 0.02, -s.Z * 0.54, 0.025, s.Y * 0.36, 0.035, edge)
					end
				end
				if rarity >= 4 then
					lit(shin, 0, s.Y * 0.4, -s.Z * 0.56, s.X * 0.19, 0.04, 0.035)
				end
				if rarity >= 5 then
					block(shin, 0, -s.Y * 0.07, -s.Z * 0.55, 0.055, s.Y * 0.43, 0.04, BRASS)
				end
			end
			local foot = body[prefix .. "Foot"]
			if foot then
				local s = foot.Size
				block(foot, 0, 0, -s.Z * 0.09, s.X * 0.86, s.Y * 1.1, s.Z * 0.98, trim)
				block(foot, 0, -s.Y * 0.47, -s.Z * 0.09, s.X * 0.92, 0.07, s.Z * 1.05, cloth)
				wedge(
					folder,
					foot,
					CFrame.new(0, s.Y * 0.25, -s.Z * 0.3),
					Vector3.new(s.X * 0.81, s.Y * 0.7, s.Z * 0.5),
					metal,
					SMOOTH
				)
				block(foot, 0, s.Y * 0.42, s.Z * 0.13, s.X * 0.79, s.Y * 0.6, s.Z * 0.48, metal)
				if rarity >= 2 then
					block(foot, 0, s.Y * 0.15, -s.Z * 0.55, s.X * 0.67, 0.045, 0.04, edge)
					for tread = 1, 2 do
						block(foot, 0, -s.Y * 0.47, -s.Z * (0.12 + tread * 0.17), s.X * 0.87, 0.085, 0.055, trim)
					end
				end
				if rarity >= 3 then
					block(foot, 0, s.Y * 0.72, s.Z * 0.12, s.X * 0.49, 0.035, s.Z * 0.24, trim)
				end
				if rarity >= 4 then
					lit(foot, 0, s.Y * 0.35, s.Z * 0.4, s.X * 0.24, 0.035, 0.025)
				end
				if rarity >= 5 then
					block(foot, 0, s.Y * 0.7, s.Z * 0.12, s.X * 0.59, 0.035, s.Z * 0.35, BRASS)
				end
			end
		end
	end
end
BUILDERS.UtilityMiner = frontierSuit(1)
BUILDERS.FrontierRanger = frontierSuit(2)
BUILDERS.HeavyVanguard = frontierSuit(3)

for old, current in CLEAN_ALIASES do
	BUILDERS[old] = BUILDERS[current]
end
for look in CLEAN_LOOKS do
	FULL_BODY[look] = true
end

-- Colours for each look: metal, trim, cloth and the material the metal uses.
local KITS: { [string]: { Metal: Color3, Trim: Color3, Cloth: Color3?, Material: Enum.Material } } = {
	-- Saga Miner suits: Metal is the armour plates, Trim the dark fittings,
	-- Cloth the suit itself.
	SuitScrap = {
		Metal = Color3.fromRGB(218, 146, 59),
		Trim = Color3.fromRGB(72, 76, 86),
		Cloth = Color3.fromRGB(48, 65, 83),
		Material = Enum.Material.SmoothPlastic,
	},
	SuitMiner = {
		Metal = Color3.fromRGB(150, 154, 162),
		Trim = Color3.fromRGB(58, 60, 68),
		Cloth = Color3.fromRGB(222, 116, 38),
		Material = Enum.Material.SmoothPlastic,
	},
	SuitRanger = {
		Metal = Color3.fromRGB(64, 138, 150),
		Trim = Color3.fromRGB(40, 44, 54),
		Cloth = Color3.fromRGB(70, 76, 88),
		Material = Enum.Material.Metal,
	},
	SuitCrusader = {
		Metal = Color3.fromRGB(228, 230, 234),
		Trim = Color3.fromRGB(206, 164, 76),
		Cloth = Color3.fromRGB(90, 94, 104),
		Material = Enum.Material.SmoothPlastic,
	},
	SuitZeroG = {
		Metal = Color3.fromRGB(190, 218, 230),
		Trim = Color3.fromRGB(44, 64, 85),
		Cloth = Color3.fromRGB(43, 82, 101),
		Material = Enum.Material.SmoothPlastic,
	},
	SuitThermal = {
		Metal = Color3.fromRGB(211, 132, 69),
		Trim = Color3.fromRGB(58, 48, 44),
		Cloth = Color3.fromRGB(72, 62, 58),
		Material = Enum.Material.SmoothPlastic,
	},
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
KITS.UtilityMiner = {
	Metal = Color3.fromRGB(185, 131, 62),
	Trim = Color3.fromRGB(44, 51, 60),
	Cloth = Color3.fromRGB(48, 65, 78),
	Material = SMOOTH,
}
KITS.FrontierRanger = {
	Metal = Color3.fromRGB(72, 117, 129),
	Trim = Color3.fromRGB(32, 44, 55),
	Cloth = Color3.fromRGB(53, 64, 73),
	Material = SMOOTH,
}
KITS.HeavyVanguard = {
	Metal = Color3.fromRGB(82, 108, 139),
	Trim = Color3.fromRGB(35, 42, 52),
	Cloth = Color3.fromRGB(45, 53, 62),
	Material = SMOOTH,
}

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

function ArmorKits.build(
	folder: Instance,
	character: Model,
	look: string,
	accent: Color3,
	quality: number?,
	traits: any?,
	slot: string?,
	itemId: string?
)
	local cleanLook = CLEAN_ALIASES[look] or (if CLEAN_LOOKS[look] then look else nil)
	local palette = KITS[cleanLook or look] or KITS.Plate
	local kit: Kit = {
		Metal = ArmorKits.tint(
			if traits then palette.Metal:Lerp(traits.FinishColor, if cleanLook then 0.18 else 0.8) else palette.Metal,
			if cleanLook then math.min(quality or 1, 2) else quality
		),
		Trim = ArmorKits.tint(palette.Trim, if cleanLook then 1 else quality, true),
		-- Tabards and capes are the class colour, deepened like dyed cloth.
		Cloth = palette.Cloth or darken(accent, 0.45),
		Material = palette.Material,
		Accent = accent,
		Traits = traits,
		HelmetDesign = if itemId then tonumber(string.match(itemId, "^MatrixHelmets(%d+)$")) else nil,
	}
	local build = BUILDERS[look] or BUILDERS.Plate
	local body = ArmorKits.body(character)
	if slot then
		local groups = {
			Helmet = { Head = true },
			Armor = {
				Torso = true,
				Waist = true,
				LeftUpperArm = true,
				RightUpperArm = true,
				LeftUpperLeg = true,
				RightUpperLeg = true,
			},
			Gloves = { LeftLowerArm = true, RightLowerArm = true, LeftHand = true, RightHand = true },
			Boots = { LeftLowerLeg = true, RightLowerLeg = true, LeftFoot = true, RightFoot = true },
		}
		for key in body do
			if not (groups[slot] and groups[slot][key]) then
				body[key] = nil
			end
		end
	end
	if traits and traits.Variant and not cleanLook then
		local variant = traits.Variant
		for key, bodySegment in body do
			if
				key == "Torso"
				or key == "LeftLowerLeg"
				or key == "RightLowerLeg"
				or key == "LeftLowerArm"
				or key == "RightLowerArm"
			then
				local size = bodySegment.Size
				for panel = 1, variant do
					box(
						folder,
						bodySegment,
						CFrame.new(0, size.Y * (0.35 - panel * 0.15), -size.Z * 0.58),
						Vector3.new(size.X * 0.7, 0.07, 0.1),
						kit.Metal,
						SMOOTH
					)
				end
			end
		end
	end
	build(folder, body, kit)
	if FULL_BODY[look] then
		ArmorKits.hideAvatar(character)
	end
end

-- Full-body armor replaces the avatar's look: its blocky body, face and
-- accessories are hidden, so only the armored figure shows.
function ArmorKits.hideAvatar(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = 1
			for _, decal in child:GetChildren() do
				if decal:IsA("Decal") then
					decal.Transparency = 1
				end
			end
		elseif child:IsA("Accessory") then
			child:Destroy()
		end
	end
end

ArmorKits.Looks = KITS
-- Trim colour: enchanting lights it up in the gem's element.
ArmorKits.Brass = BRASS

return ArmorKits

end)()

local Assets=(function()
-- Shared geometry builders for runtime equipment and offline asset previews.
local Assets = {}
local dark = Color3.fromRGB(30, 38, 52)
local steel = Color3.fromRGB(166, 190, 205)
local gold = Color3.fromRGB(218, 164, 70)

local function part(folder, anchor, mount, at, size, color, material)
	local p = Instance.new("Part")
	p.Name = "Gear"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CFrame = anchor.CFrame * mount * at
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.Massless = true
	p.CastShadow = math.max(size.X, size.Y, size.Z) > 0.5
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = anchor, p, p
	p.Parent = folder
	return p
end

-- Preserve the compact pistol silhouette and the original barrel/socket mount.
-- The same builder is used by equipped weapons and item previews.
function Assets.sidearm(folder, hand, mount, rarity, accent, finish)
	rarity = math.clamp(rarity or 1, 1, 5)
	local function add(x, y, z, sx, sy, sz, color, material)
		return part(folder, hand, mount, CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, material)
	end
	add(0, 0, -0.06, 0.2, 0.3, 0.48, dark)
	add(0, 0.28, 0.23, 0.28, 0.76, 0.27, Color3.fromRGB(118, 132, 146))
	local muzzle = part(
		folder,
		hand,
		mount,
		CFrame.new(0, 0.73, 0.23) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.18, 0.23, 0.23),
		dark,
		Enum.Material.Metal
	)
	muzzle.Shape = Enum.PartType.Cylinder
	add(0, 0.3, 0.39, 0.09, 0.15, 0.045, accent)
	-- Inset muzzle, barrel spine, rear sight and grip heel.
	local bore = part(
		folder,
		hand,
		mount,
		CFrame.new(0, 0.827, 0.23) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.025, 0.12, 0.12),
		Color3.fromRGB(8, 12, 18),
		Enum.Material.Metal
	)
	bore.Shape = Enum.PartType.Cylinder
	add(0, 0.32, 0.08, 0.12, 0.53, 0.045, dark)
	add(0, 0.58, 0.065, 0.1, 0.07, 0.07, steel)
	add(0, -0.14, -0.06, 0.23, 0.055, 0.42, dark)
	if rarity >= 2 then
		for _, side in { -1, 1 } do
			add(side * 0.151, 0.26, 0.23, 0.025, 0.42, 0.16, finish)
			for i = 1, 2 do
				add(side * 0.11, -0.1 + i * 0.09, -0.08, 0.025, 0.025, 0.28, steel)
			end
		end
	end
	if rarity >= 3 then
		for _, side in { -1, 1 } do
			for i = 1, 3 do
				add(side * 0.168, 0.34 + i * 0.07, 0.23, 0.025, 0.028, 0.13, dark)
			end
			add(side * 0.168, 0.12, 0.23, 0.03, 0.055, 0.055, steel, Enum.Material.Metal)
		end
	end
	if rarity >= 4 then
		for _, side in { -1, 1 } do
			add(side * 0.17, 0.26, 0.23, 0.025, 0.14, 0.035, accent, Enum.Material.Neon)
		end
		add(0, 0.59, 0.075, 0.045, 0.025, 0.04, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for _, side in { -1, 1 } do
			add(side * 0.153, 0.28, 0.13, 0.03, 0.4, 0.025, gold, Enum.Material.Metal)
			add(side * 0.153, 0.28, 0.33, 0.03, 0.4, 0.025, gold, Enum.Material.Metal)
		end
		add(0, -0.18, -0.06, 0.17, 0.025, 0.28, gold, Enum.Material.Metal)
	end
end

function Assets.sword(folder, hand, mount, rarity, accent, finish)
	rarity = math.clamp(rarity or 1, 1, 5)
	local function add(x, y, z, sx, sy, sz, color, material)
		return part(folder, hand, mount, CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, material)
	end
	-- Wrapped grip, balanced guard, broad fuller, and stepped cutting tip.
	add(0, 0, 0, 0.2, 0.65, 0.22, dark)
	add(0, -0.38, 0, 0.29, 0.15, 0.28, finish)
	add(0, 0.38, 0, 0.82, 0.14, 0.26, finish)
	add(0, 1.6, 0, 0.32, 2.3, 0.12, steel, Enum.Material.Metal)
	add(0, 1.56, -0.07, 0.1, 2.12, 0.035, dark)
	-- Metal edge bevels and a ferrule separate blade, guard and grip.
	for _, side in { -1, 1 } do
		add(side * 0.147, 1.6, 0, 0.026, 2.25, 0.14, steel, Enum.Material.Metal)
	end
	add(0, 0.49, 0, 0.36, 0.11, 0.16, dark)
	for step = 1, 4 do
		add(0, 2.72 + step * 0.09, 0, 0.32 - step * 0.06, 0.1, 0.12, steel, Enum.Material.Metal)
	end
	if rarity >= 2 then
		for _, face in { -1, 1 } do
			add(0, 0.38, face * 0.145, 0.12, 0.065, 0.025, steel, Enum.Material.Metal)
		end
		for i = -1, 1 do
			add(0, i * 0.18, 0, 0.23, 0.045, 0.25, finish)
		end
		for _, side in { -1, 1 } do
			add(side * 0.4, 0.45, 0, 0.13, 0.3, 0.28, dark)
		end
	end
	if rarity >= 3 then
		for _, face in { -1, 1 } do
			add(0, 0.67, face * 0.092, 0.19, 0.15, 0.025, finish)
		end
		for _, side in { -1, 1 } do
			add(side * 0.19, 0.83, 0, 0.09, 0.65, 0.15, finish)
			add(side * 0.28, 0.49, -0.16, 0.12, 0.1, 0.05, steel)
		end
	end
	if rarity >= 4 then
		for _, side in { -1, 1 } do
			add(0, 1.6, side * 0.085, 0.045, 1.8, 0.025, accent, Enum.Material.Neon)
		end
		add(0, -0.4, -0.16, 0.12, 0.07, 0.04, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for _, face in { -1, 1 } do
			add(0, -0.38, face * 0.16, 0.13, 0.07, 0.025, gold, Enum.Material.Metal)
		end
		for _, side in { -1, 1 } do
			add(side * 0.48, 0.48, 0, 0.1, 0.4, 0.2, gold, Enum.Material.Metal)
			for i = 1, 3 do
				add(side * 0.1, 0.55 + i * 0.32, -0.09, 0.08, 0.045, 0.025, gold)
			end
		end
	end
end

function Assets.shield(folder, arm, mount, rarity, accent, finish)
	rarity = math.clamp(rarity or 1, 1, 5)
	local function add(x, y, z, sx, sy, sz, color, material)
		return part(folder, arm, mount, CFrame.new(x, y, z), Vector3.new(sx, sy, sz), color, material)
	end
	-- Stepped kite silhouette replaces the smooth oval; plates float over a dark frame.
	add(0, 0.18, 0, 1.35, 1.55, 0.22, dark)
	add(0, -0.7, 0, 0.95, 0.3, 0.22, dark)
	add(0, -0.92, 0, 0.55, 0.16, 0.22, dark)
	add(0, 0.16, -0.14, 1.15, 1.38, 0.12, finish)
	add(0, -0.63, -0.14, 0.76, 0.25, 0.12, finish)
	-- Recessed central socket housing; leave the gemstone's face clear.
	add(0, 0.1, -0.215, 0.46, 0.48, 0.035, dark)
	add(0, -0.43, -0.215, 0.65, 0.035, 0.035, steel)
	for _, side in { -1, 1 } do
		add(side * 0.46, 0.7, -0.22, 0.055, 0.055, 0.035, steel, Enum.Material.Metal)
	end
	if rarity >= 2 then
		for _, side in { -1, 1 } do
			add(side * 0.47, -0.38, -0.22, 0.055, 0.055, 0.035, steel, Enum.Material.Metal)
		end
		for _, side in { -1, 1 } do
			add(side * 0.59, 0.16, -0.19, 0.065, 1.35, 0.07, steel)
		end
		add(0, 0.83, -0.19, 1.23, 0.065, 0.07, steel)
	end
	if rarity >= 3 then
		add(0, 0.69, -0.225, 0.67, 0.075, 0.055, dark)
		add(0, -0.63, -0.235, 0.38, 0.08, 0.055, steel)
		for _, side in { -1, 1 } do
			add(side * 0.4, 0.1, -0.24, 0.26, 0.85, 0.1, dark)
			for i = 1, 3 do
				add(side * 0.4, i * 0.2 - 0.3, -0.3, 0.16, 0.055, 0.035, steel)
			end
		end
	end
	if rarity >= 4 then
		add(0, -0.47, -0.25, 0.29, 0.035, 0.025, accent, Enum.Material.Neon)
		for _, side in { -1, 1 } do
			add(side * 0.54, 0.17, -0.25, 0.035, 0.98, 0.035, accent, Enum.Material.Neon)
		end
		add(0, 0.59, -0.23, 0.34, 0.045, 0.04, accent, Enum.Material.Neon)
	end
	if rarity >= 5 then
		for _, side in { -1, 1 } do
			add(side * 0.15, 0.39, -0.245, 0.045, 0.23, 0.035, gold, Enum.Material.Metal)
		end
		for _, side in { -1, 1 } do
			add(side * 0.64, 0.73, -0.15, 0.17, 0.39, 0.15, gold)
			add(side * 0.27, -0.63, -0.25, 0.08, 0.25, 0.08, gold)
		end
		add(0, -0.83, -0.18, 0.32, 0.12, 0.09, gold)
	end
end

return Assets

end)()

local anchor={Size=Vector3.new(1,1,1),CFrame=CFrame.identity,FindFirstChildOfClass=function() return nil end}
local function dump(label)
 print("MODEL|"..label)
 for _,p in builtParts do
  local row={p.ClassName,p.Shape or "Block",p.Material,tostring(p.Size.X),tostring(p.Size.Y),tostring(p.Size.Z),tostring(p.Color.R),tostring(p.Color.G),tostring(p.Color.B)}
  for _,n in p.CFrame.t do table.insert(row,tostring(n)) end
  for _,n in p.CFrame.r do table.insert(row,tostring(n)) end
  print(table.concat(row,"|"))
 end
 table.clear(builtParts)
end
local traits={Rarity=5,Helmet=1,VisorColor=Color3.fromRGB(168,99,246),FinishColor=Color3.fromRGB(211,176,84)}
for _,slot in {"Helmet","Armor","Gloves","Boots"} do
 local target=if slot=="Helmet" then "Head" elseif slot=="Armor" then "Torso" elseif slot=="Gloves" then "RightLowerArm" else "RightFoot"
 local rig={GetChildren=function() return {} end,FindFirstChild=function(_,name) if name==target or name=="UpperTorso" then return anchor end return nil end}
 ArmorKits.build({},rig,"HeavyVanguard",Color3.fromRGB(72,207,226),1,traits,slot,"MatrixHelmets10")
 dump(slot)
end
Assets.sidearm({},anchor,CFrame.identity,5,Color3.fromRGB(72,207,226),Color3.fromRGB(82,108,139)); dump("Pistol")
Assets.shield({},anchor,CFrame.identity,5,Color3.fromRGB(72,207,226),Color3.fromRGB(82,108,139)); dump("Shield")
