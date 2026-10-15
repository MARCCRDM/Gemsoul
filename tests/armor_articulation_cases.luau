-- Capture local geometry and weld ownership. R15 waist/hip joints move independently;
-- a rigid upper-torso apron below the joint is the regression this test prevents.
local transforms = {}
transforms.__mul = function(a, b)
	return setmetatable(
		{ X = (a.X or 0) + (b.X or 0), Y = (a.Y or 0) + (b.Y or 0), Z = (a.Z or 0) + (b.Z or 0), Roll = (a.Roll or 0)
			+ (b.Roll or 0) },
		transforms
	)
end
CFrame.new = function(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, Roll = 0 }, transforms)
end
CFrame.Angles = function(x, y, z)
	return setmetatable({ X = 0, Y = 0, Z = 0, Roll = z or 0 }, transforms)
end
CFrame.identity = CFrame.new()
local originalNew = Instance.new
local welds = {}
Instance.new = function(kind)
	local object = originalNew(kind)
	if kind == "WeldConstraint" then
		table.insert(welds, object)
	end
	return object
end
local checked = 0
for _, look in { "UtilityMiner", "FrontierRanger", "HeavyVanguard" } do
	for rarity = 1, 5 do
		for _, scale in { 0.75, 1, 1.35 } do
			local character = rig(true)
			local upper = character:FindFirstChild("UpperTorso")
			local lower = character:FindFirstChild("LowerTorso")
			upper.Size = Vector3.new(2, 1.6, 1) * scale
			lower.Size = Vector3.new(2, 0.4, 1) * scale
			welds = {}
			ArmorKits.build(
				{},
				character,
				look,
				Color3.fromRGB(80, 200, 220),
				rarity,
				{ Rarity = rarity, FinishColor = Color3.fromRGB(100, 120, 140) },
				"Armor"
			)
			local pelvis = 0
			for _, weld in welds do
				local part = weld.Part1
				if weld.Part0 == upper then
					local cf = part.CFrame
					local half = (math.abs(math.cos(cf.Roll)) * part.Size.Y + math.abs(math.sin(cf.Roll)) * part.Size.X)
						/ 2
					assert(
						cf.Y - half >= -upper.Size.Y * 0.51,
						look .. " chest geometry crosses waist joint at rarity " .. rarity
					)
				elseif weld.Part0 == lower then
					pelvis += 1
					assert(part.Massless and not part.CanCollide, "Pelvis armor affects walking physics")
				end
			end
			assert(pelvis >= 8, "Missing articulated waist coverage")
			checked += 1
		end
	end
end
print(
	"PASS: "
		.. checked
		.. " chest configurations: 3 families, 5 rarities, 3 body scales; upper plates clear waist, pelvis independently welded"
)

-- Boot armor must stay on its side of the knee/ankle joint. In particular,
-- a rotated cap can exceed the joint even if its unrotated size would fit.
local bootChecks = 0
for _, look in { "UtilityMiner", "FrontierRanger", "HeavyVanguard" } do
	for rarity = 1, 5 do
		for _, scale in { 0.75, 1, 1.35 } do
			for _, r15 in { false, true } do
				local character = rig(r15)
				local allowed, attached = {}, {}
				for _, side in { "Left", "Right" } do
					if r15 then
						local shin = character:FindFirstChild(side .. "LowerLeg")
						local foot = character:FindFirstChild(side .. "Foot")
						shin.Size = Vector3.new(1, 1.1, 1) * scale
						foot.Size = Vector3.new(1, 0.3, 1) * scale
						allowed[shin] = { Top = shin.Size.Y * 0.5, Bottom = -shin.Size.Y * 0.5 }
						-- The sole may sit slightly below the foot, but the collar
						-- must not penetrate the separately animated shin.
						allowed[foot] = { Top = foot.Size.Y * 0.5, Bottom = -foot.Size.Y * 0.58 }
					else
						local leg = character:FindFirstChild(side .. " Leg")
						leg.Size = Vector3.new(1, 2, 1) * scale
						allowed[leg] = { Top = 0, Bottom = -leg.Size.Y * 0.515 }
					end
				end
				welds = {}
				ArmorKits.build(
					{},
					character,
					look,
					Color3.fromRGB(80, 200, 220),
					rarity,
					{ Rarity = rarity, FinishColor = Color3.fromRGB(100, 120, 140) },
					"Boots"
				)
				for _, weld in welds do
					local part, owner = weld.Part1, weld.Part0
					local bounds = allowed[owner]
					assert(bounds, "Boot detail welded outside the lower leg/foot")
					local cf = part.CFrame
					local half = (math.abs(math.cos(cf.Roll)) * part.Size.Y + math.abs(math.sin(cf.Roll)) * part.Size.X)
						/ 2
					assert(
						cf.Y + half <= bounds.Top + 0.001,
						look .. " boot detail crosses flex joint at rarity " .. rarity
					)
					assert(cf.Y - half >= bounds.Bottom - 0.001, look .. " boot detail extends below its segment")
					assert(
						part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery,
						"Boot detail changes physics or combat raycasts"
					)
					attached[owner] = true
				end
				for owner in allowed do
					assert(attached[owner], "Missing boot geometry on " .. owner.Name)
				end
				bootChecks += 1
			end
		end
	end
end
print(
	"PASS: "
		.. bootChecks
		.. " boot configurations: R6/R15, 3 families, 5 rarities, 3 scales; joint clearance and weld ownership"
)

-- Visors are marked (the Visor attribute) so a suit leaves them their own
-- colour (Equipment's repaint skips them): every part in the visor's colour
-- is marked, and so is the dark well it sits in.
local visorChecks = 0
for _, look in { "UtilityMiner", "FrontierRanger", "HeavyVanguard" } do
	for rarity = 1, 5 do
		local character = rig(true)
		local visorTint = Color3.fromRGB(30, 140, 220)
		table.clear(builtParts)
		ArmorKits.build(
			{},
			character,
			look,
			Color3.fromRGB(80, 200, 220),
			rarity,
			{ Rarity = rarity, VisorColor = visorTint, FinishColor = Color3.fromRGB(100, 120, 140) },
			"Helmet"
		)
		local marked, tinted = 0, 0
		for _, part in builtParts do
			if part.Color == visorTint then
				tinted += 1
				assert(part.Attributes.Visor == true, look .. " left a visor part unmarked at rarity " .. rarity)
			end
			if part.Attributes.Visor then
				marked += 1
			end
		end
		assert(tinted >= 1 and marked > tinted, look .. "'s visor (and its well) aren't marked at rarity " .. rarity)
		visorChecks += 1
	end
end
print("PASS: " .. visorChecks .. " helmets: every visor part marked, so suits leave visors their own colour")
